#include "StrategyDecision.h"

#include "Aid.h"
#include "Config.h"
#include "Hud.h"
#include "OrgasmEngine.h"
#include "WebUI_Log.h"
#include "InjuryEngine.h"

#include <algorithm>
#include <string_view>

#include <nlohmann/json.hpp>

#include <atomic>
#include <chrono>
#include <functional>
#include <map>
#include <memory>
#include <string>
#include <unordered_map>
#include <vector>

// Defined in PublicAPI.h (included once from Config.cpp).
extern "C" {
extern int (*PublicGetVersion)();
extern uint64_t (*PublicFormIDToUUID)(uint32_t formId);
extern uint64_t (*PublicRegisterEventCallback)(const char* eventType, std::function<void(const char*)> callback);
extern std::string (*PublicGetRecentEvents)(uint32_t formId, int maxCount, const char* eventTypeFilter);
extern bool (*PublicSendCustomDecisionToLLM)(const char* templateName, const char* contextJson, int maxProbabilities,
    std::function<void(const char* answer, const char* resultJson, int success)> callback);
}

namespace StrategyDecision
{
    namespace
    {
        constexpr const char* kTemplate = "sexlab/minigame_strategy";
        // Auto play: the player's turn (strategy, whether to speak, which HUD key to press and what to pick in
        // the Aid / Punish dialogs).
        constexpr const char* kPlayerTemplate = "sexlab/minigame_player_turn";
        constexpr int kMaxProbabilities = 3;
        constexpr double kSpeakInterval = 5.0;    // seconds between auto-play player lines
        constexpr double kHotkeyInterval = 5.0;   // seconds between auto-play key presses
        constexpr double kEndConfidence = 0.8;    // ending the scene can't be undone
        constexpr std::size_t kMaxAidOptions = 20;
        // Aid / Punish part pulldown (index.html BODY_PARTS without "custom"); the sexual ones as SEXUAL_PARTS.
        constexpr const char* kBodyParts[] = { "body", "face", "lips", "nipples", "back", "left arm", "right arm",
            "left leg", "right leg", "pussy", "cock", "ass" };
        constexpr std::string_view kSexualParts[] = { "lips", "nipples", "pussy", "cock", "ass" };

        // With Injury Engine's sexual parts off there is no player to ask to turn them on: leave them out.
        std::vector<std::string> OfferedParts()
        {
            const bool skipSexual = InjuryEngine::Installed() && !InjuryEngine::SexualParts();
            std::vector<std::string> out;
            for (const char* p : kBodyParts) {
                if (!skipSexual || std::find(std::begin(kSexualParts), std::end(kSexualParts), p) == std::end(kSexualParts)) {
                    out.emplace_back(p);
                }
            }
            return out;
        }
        constexpr int kMinApiVersion = 12;
        constexpr int kTimelineEvents = 30;  // events asked for; thoughts and speech are split into more lines
        constexpr int kTimelineLines = 15;   // lines kept, newest
        // SkyrimNet event types for a spoken NPC line (originator = speaker).
        constexpr const char* kDialogueEvents[] = { "dialogue", "dialogue_npc", "dialogue_background" };

        std::atomic<bool> g_installed{ false };
        bool g_noRouteWarned = false;  // game thread
        bool g_noRoute = false;        // no decisions provider: stop asking until the next load

        // Called once with the outcome of an asked / ordered / punished request (RequestAnswer).
        using Done = std::function<void(OrgasmEngine::DecisionResult)>;

        // Game thread only. One request in flight per NPC; a line arriving meanwhile is kept for one follow-up.
        // A punishment waiting for the follow-up (done set) keeps its trigger and line over later dialogue.
        struct Pending
        {
            bool inFlight = false;
            bool dirty = false;
            std::string trigger;
            std::string line;
            Done active;  // the in-flight request's
            Done done;    // the follow-up's
        };
        std::unordered_map<RE::FormID, Pending> g_pending;

        bool ApiReady()
        {
            return SexLabNet::CrossDllStdStringSafe() && PublicGetVersion && PublicGetVersion() >= kMinApiVersion &&
                   PublicRegisterEventCallback && PublicSendCustomDecisionToLLM;
        }

        std::uint64_t UuidOf(RE::FormID id)
        {
            return PublicFormIDToUUID ? PublicFormIDToUUID(id) : 0;
        }

        // Skyrim relationship rank between two actors (Papyrus GetRelationshipRank: 4 lover .. -4 archnemesis).
        // The leveled-actor case falls back to the template bases. No relationship form: strangers, 0.
        std::pair<std::string, int> Relationship(RE::Actor* a, RE::Actor* b)
        {
            if (!a || !b) {
                return { "strangers", 0 };
            }
            RE::BGSRelationship* rel = RE::BGSRelationship::GetRelationship(a->GetActorBase(), b->GetActorBase());
            if (!rel) {
                auto* ta = a->GetTemplateBase();
                auto* tb = b->GetTemplateBase();
                if (ta && tb && (ta != a->GetActorBase() || tb != b->GetActorBase())) {
                    rel = RE::BGSRelationship::GetRelationship(ta, tb);
                }
            }
            if (!rel) {
                return { "strangers", 0 };
            }
            static constexpr const char* kLabels[] = { "lovers", "allies", "confidants", "friends", "acquaintances",
                "rivals", "foes", "enemies", "archnemeses" };
            const auto level = static_cast<int>(rel->level.get());
            if (level < 0 || level > 8) {
                return { "strangers", 0 };
            }
            return { kLabels[level], 4 - level };
        }

        std::string Trim(const std::string& s)
        {
            const auto b = s.find_first_not_of(" \t\r\n");
            if (b == std::string::npos) {
                return "";
            }
            return s.substr(b, s.find_last_not_of(" \t\r\n") - b + 1);
        }

        // A narration line from a *...* span: first letter upper case, ends with a period.
        std::string NarrationLine(std::string s)
        {
            s = Trim(s);
            if (s.empty()) {
                return s;
            }
            s[0] = static_cast<char>(std::toupper(static_cast<unsigned char>(s[0])));
            if (const char last = s.back(); last != '.' && last != '!' && last != '?') {
                s.push_back('.');
            }
            return s;
        }

        // "kiss me *bob leans in*" by Bob -> "Bob said: kiss me", "Bob leans in." (order kept; a *...* span is
        // narration, the rest is speech).
        void SplitSpeech(const std::string& speaker, const std::string& text, std::vector<std::string>& out)
        {
            std::size_t pos = 0;
            while (pos < text.size()) {
                const auto open = text.find('*', pos);
                const std::string spoken = Trim(text.substr(pos, open == std::string::npos ? open : open - pos));
                if (!spoken.empty()) {
                    out.push_back((speaker.empty() ? std::string("Someone") : speaker) + " said: " + spoken);
                }
                if (open == std::string::npos) {
                    break;
                }
                const auto close = text.find('*', open + 1);
                const std::string narrated =
                    NarrationLine(text.substr(open + 1, close == std::string::npos ? close : close - open - 1));
                if (!narrated.empty()) {
                    out.push_back(narrated);
                }
                if (close == std::string::npos) {
                    break;
                }
                pos = close + 1;
            }
        }

        // The focus actor's recent events as one timeline, oldest first, one line each: speech ("Bob said: ..."),
        // thoughts ("Nina thought: ..."), direct narrations and other events as their text. Narration inside
        // speech is pulled out into its own line.
        std::vector<std::string> BuildTimeline(const OrgasmEngine::DecisionInput& in)
        {
            std::vector<std::string> out;
            if (!PublicGetRecentEvents) {
                return out;
            }
            nlohmann::json events;
            try {
                events = nlohmann::json::parse(PublicGetRecentEvents(in.id, kTimelineEvents, ""), nullptr, false);
            } catch (...) {
                return out;
            }
            if (!events.is_array()) {
                return out;
            }
            std::vector<nlohmann::json> list(events.begin(), events.end());
            std::stable_sort(list.begin(), list.end(), [](const nlohmann::json& a, const nlohmann::json& b) {
                return a.value("gameTime", 0.0) < b.value("gameTime", 0.0);
            });
            for (const auto& e : list) {
                if (!e.is_object()) {
                    continue;
                }
                const std::string type = e.value("type", std::string{});
                const std::string text = Trim(e.value("text", std::string{}));
                const std::string who = e.value("originatingActorName", std::string{});
                if (text.empty() || type == "spell" || type == "hit" || type == "combat" ||
                    type == "gamemaster_dialogue") {
                    continue;
                }
                if (type.rfind("dialogue", 0) == 0) {
                    SplitSpeech(who, text, out);
                } else if (type == "npc_thoughts") {
                    if (who == in.name) {  // other actors' thoughts (telepathy) are not this actor's
                        out.push_back(who + " thought: " + text);
                    }
                } else {
                    out.push_back(text);
                }
            }
            if (out.size() > static_cast<std::size_t>(kTimelineLines)) {
                out.erase(out.begin(), out.end() - kTimelineLines);
            }
            return out;
        }

        nlohmann::json BuildContext(const OrgasmEngine::DecisionInput& in, RE::Actor* focus, const std::string& trigger,
            const std::string& line)
        {
            nlohmann::json ctx;
            ctx["trigger"] = trigger;
            ctx["focus_uuid"] = UuidOf(in.id);
            ctx["focus_name"] = in.name;
            ctx["last_line_text"] = line;
            ctx["role"] = in.role;
            ctx["arousal"] = in.arousal;
            ctx["orgasms"] = in.orgasms;
            ctx["expects_orgasm"] = in.expectsOrgasm;
            ctx["timeline"] = BuildTimeline(in);
            auto partners = nlohmann::json::array();
            for (const auto& p : in.partners) {
                const auto [label, rank] = Relationship(focus, RE::TESForm::LookupByID<RE::Actor>(p.id));
                partners.push_back({ { "uuid", UuidOf(p.id) }, { "name", p.name }, { "is_player", p.isPlayer },
                    { "role", p.role }, { "arousal", p.arousal }, { "orgasms", p.orgasms },
                    { "relationship", label }, { "relationship_rank", rank } });
            }
            ctx["partners"] = std::move(partners);
            auto options = nlohmann::json::array();
            for (const auto& o : in.options) {
                options.push_back({ { "key", o.key }, { "text", o.text } });
            }
            ctx["options"] = std::move(options);
            return ctx;
        }

        void Request(RE::FormID id, const std::string& trigger, const std::string& line, Done done = {});

        // Game thread. Applies a strategy answer.
        OrgasmEngine::DecisionResult ApplyStrategyAnswer(RE::FormID id, const OrgasmEngine::DecisionInput& in,
            const std::string& key, double confidence)
        {
            using R = OrgasmEngine::DecisionResult;
            RE::Actor* actor = RE::TESForm::LookupByID<RE::Actor>(id);
            return actor && !key.empty() ? OrgasmEngine::ApplyStrategyDecision(actor, in, key, confidence)
                                         : R::kDropped;
        }

        // The outcome for the log.
        const char* ResultText(OrgasmEngine::DecisionResult result)
        {
            using R = OrgasmEngine::DecisionResult;
            return result == R::kChanged       ? "changed"
                   : result == R::kKept          ? "kept"
                   : result == R::kLowConfidence ? "low confidence, kept current"
                   : result == R::kUnknown       ? "unknown key"
                                                 : "dropped: scene ended or roster changed";
        }

        // Failed request: no-provider latch, else a warning.
        void NoteFailure(RE::FormID id, const std::string& json)
        {
            std::string code;
            try {
                code = nlohmann::json::parse(json).value("error", std::string{});
            } catch (...) {
            }
            if (code == "no_decisions_route") {
                g_noRoute = true;
                if (!g_noRouteWarned) {
                    g_noRouteWarned = true;
                    webui_log::warn("StrategyDecision: no decisions provider set up in SkyrimNet; NPCs keep "
                                    "their role default strategies");
                }
            } else {
                webui_log::warn("StrategyDecision: {:#x} failed: {}", id, json);
            }
        }

        // Game thread. The decision for `id` arrived (or failed).
        void OnAnswer(RE::FormID id, std::shared_ptr<OrgasmEngine::DecisionInput> in, int success,
            const std::string& answer, const std::string& json)
        {
            using R = OrgasmEngine::DecisionResult;
            Pending& p = g_pending[id];
            p.inFlight = false;
            Done done = std::exchange(p.active, nullptr);
            if (!success) {
                NoteFailure(id, json);
                Done queued = std::exchange(p.done, nullptr);
                g_pending.erase(id);
                if (done) {
                    done(R::kDropped);
                }
                if (queued) {
                    queued(R::kDropped);
                }
                return;
            }
            std::string key = answer;
            double confidence = -1.0;
            try {
                const auto j = nlohmann::json::parse(json);
                const auto& a = j.at("answers").at("strategy");
                key = a.value("choice", key);
                confidence = a.value("confidence", -1.0);
            } catch (...) {
            }
            const R result = ApplyStrategyAnswer(id, *in, key, confidence);
            webui_log::info("StrategyDecision: {:#x} answer {} p={:.2f} ({})", id, key, confidence, ResultText(result));
            if (p.dirty) {
                p.dirty = false;
                const std::string trigger = p.trigger;
                const std::string next = p.line;
                Done queued = std::exchange(p.done, nullptr);
                if (done) {
                    done(result);
                }
                Request(id, trigger, next, std::move(queued));
            } else {
                g_pending.erase(id);
                if (done) {
                    done(result);
                }
            }
        }

        // Game thread. done (punished requests) is called exactly once: with the answer, or kDropped right away
        // when no decision is sent.
        void Request(RE::FormID id, const std::string& trigger, const std::string& line, Done done)
        {
            using R = OrgasmEngine::DecisionResult;
            const auto skip = [&done]() {
                if (done) {
                    done(R::kDropped);
                }
            };
            if (g_noRoute || !g_installed || !OrgasmEngine::IsStrategyDecisionEnabled()) {
                skip();
                return;
            }
            RE::Actor* actor = RE::TESForm::LookupByID<RE::Actor>(id);
            auto in = std::make_shared<OrgasmEngine::DecisionInput>();
            if (!actor || !OrgasmEngine::GetStrategyDecisionInput(actor, *in) || in->options.size() < 2) {
                skip();
                return;
            }
            Pending& p = g_pending[id];
            if (p.inFlight) {
                if (done) {
                    // Punishments waiting together get the same follow-up answer; the newest line asks.
                    p.done = p.done ? Done([a = std::move(p.done), b = std::move(done)](R r) {
                        a(r);
                        b(r);
                    })
                                    : std::move(done);
                } else if (p.done) {
                    return;  // a punishment is waiting: its trigger and line ask the follow-up
                }
                p.dirty = true;
                p.trigger = trigger;
                p.line = line;
                return;
            }
            const std::string ctx = BuildContext(*in, actor, trigger, line).dump();
            p.inFlight = true;
            p.active = std::move(done);
            const bool queued = PublicSendCustomDecisionToLLM(kTemplate, ctx.c_str(), kMaxProbabilities,
                [id, in](const char* answer, const char* resultJson, int success) {
                    // SkyrimNet ThreadPool: copy, then do the work on the game thread.
                    std::string a = answer ? answer : "";
                    std::string j = resultJson ? resultJson : "";
                    SKSE::GetTaskInterface()->AddTask([id, in, success, a = std::move(a), j = std::move(j)]() {
                        OnAnswer(id, in, success, a, j);
                    });
                });
            if (!queued) {
                webui_log::warn("StrategyDecision: {:#x} request not queued", id);
                Done d = std::exchange(g_pending[id].active, nullptr);
                g_pending.erase(id);
                if (d) {
                    d(R::kDropped);
                }
                return;
            }
            webui_log::info("StrategyDecision: send {:#x} trigger={} current={} options={}", id, trigger,
                in->currentKey, in->options.size());
        }

        // ---- Auto play: the player's turn ----

        double Seconds()
        {
            using namespace std::chrono;
            static const auto start = steady_clock::now();
            return duration<double>(steady_clock::now() - start).count();
        }

        struct AidChoice
        {
            RE::FormID target = 0;
            RE::FormID form = 0;
        };
        // What the player's turn may pick, by option key. The decision's question ids: strategy, speak, hotkey,
        // aid_option, aid_part, punish_option, punish_method, punish_part.
        struct TurnInput
        {
            OrgasmEngine::DecisionInput strategy;
            bool askSpeak = false;
            std::vector<OrgasmEngine::DecisionOption> hotkeys;  // "none" first
            std::map<std::string, RE::FormID> denyTargets;      // deny_p<slot> / allow_p<slot>
            std::vector<OrgasmEngine::DecisionOption> aidOptions;
            std::map<std::string, AidChoice> aid;
            std::vector<OrgasmEngine::DecisionOption> punishOptions;
            std::map<std::string, RE::FormID> punish;  // punish_options key -> target
            std::vector<OrgasmEngine::DecisionOption> punishMethods;
            std::map<std::string, std::string> methodOf;  // punish_methods key -> the method Punish takes
        };

        // Game thread only. One player-turn request in flight; a line arriving meanwhile is kept for one follow-up.
        struct PlayerTurn
        {
            bool inFlight = false;
            bool dirty = false;
            std::string trigger;
            std::string line;
            std::string speaker;
            bool askSpeak = false;
            double lastSpeak = -1000.0;
            double lastHotkey = -1000.0;
        };
        PlayerTurn g_turn;

        // Game thread. The keys the player may press now, as the HUD shows them, and the Aid / Punish dialog
        // choices. False when the player is not in auto play in a mini-game scene.
        bool BuildTurn(RE::Actor* player, bool askSpeak, TurnInput& t)
        {
            if (!OrgasmEngine::IsAutoPlay() || !OrgasmEngine::GetStrategyDecisionInput(player, t.strategy)) {
                return false;
            }
            t.askSpeak = askSpeak;
            const std::string self = t.strategy.name;
            std::vector<OrgasmEngine::ActorView> actors;
            OrgasmEngine::GetActorScene(player, actors);

            auto& keys = t.hotkeys;
            keys.push_back({ "none", "press nothing; let the scene go on as it is" });
            int stage = 0, count = 0;
            OrgasmEngine::GetSceneStage(player, stage, count);
            if (stage > 1) {
                keys.push_back({ "previous", "go back to the previous stage of the act" });
            }
            if (stage < count) {
                keys.push_back({ "next", "move on to the next stage of the act" });
            }
            if (actors.size() > 1) {
                keys.push_back({ "pos_up", "swap roles with the partners (forward)" });
                keys.push_back({ "pos_down", "swap roles with the partners (back)" });
            }
            const int level = OrgasmEngine::GetSceneSpeedLevel(player);
            if (level > 0) {
                keys.push_back({ "slower", std::string("slow the pace to ") + OrgasmEngine::kSpeedLevelNames[level - 1] });
            }
            if (level >= 0 && level + 1 < OrgasmEngine::kSpeedLevelCount) {
                keys.push_back({ "faster", std::string("pick up the pace to ") + OrgasmEngine::kSpeedLevelNames[level + 1] });
            }
            if (OrgasmEngine::IsScenePaused(player)) {
                keys.push_back({ "pause", "resume the act" });
            } else {
                keys.push_back({ "pause", "hold still and pause the act" });
            }
            for (std::size_t i = 0; i < actors.size(); ++i) {
                const auto& a = actors[i];
                if (a.id == player->GetFormID()) {
                    continue;
                }
                const std::string slot = "_p" + std::to_string(i + 1);
                if (a.denied) {
                    keys.push_back({ "allow" + slot, "allow " + a.name + " to orgasm" });
                    t.denyTargets["allow" + slot] = a.id;
                } else {
                    keys.push_back({ "deny" + slot, "forbid " + a.name + " from orgasming without permission" });
                    t.denyTargets["deny" + slot] = a.id;
                }
            }
            keys.push_back({ "end", "end the scene now" });

            // Aid: the player's affordable healing / stamina spells and potions, on anyone in the scene.
            for (const auto& o : Aid::ListOptions(player)) {
                if (!o.affordable) {
                    continue;
                }
                for (const auto& a : actors) {
                    if (t.aidOptions.size() >= kMaxAidOptions) {
                        break;
                    }
                    const std::string key = "aid_" + std::to_string(t.aidOptions.size() + 1);
                    const std::string on = a.id == player->GetFormID() ? self + " (self)" : a.name;
                    t.aidOptions.push_back({ key, (o.potion ? "use " : "cast ") + o.name + " on " + on });
                    t.aid[key] = { a.id, o.form };
                }
            }
            if (!t.aidOptions.empty()) {
                keys.push_back({ "aid", "heal or restore someone with a spell or potion" });
            }

            // Punish: anyone else in the scene.
            std::vector<OrgasmEngine::PunishTarget> targets;
            if (OrgasmEngine::GetPunishInfo(player, targets)) {
                for (const auto& v : targets) {
                    const std::string k = "punish_" + std::to_string(t.punishOptions.size() + 1);
                    t.punishOptions.push_back({ k, "punish " + v.name });
                    t.punish[k] = v.id;
                }
            }
            if (!t.punishOptions.empty()) {
                keys.push_back({ "punish", "hurt someone in the scene to punish them" });
                for (const char* m : { "slap", "pinch", "punch", "pull" }) {
                    t.punishMethods.push_back({ m, m });
                    t.methodOf[m] = m;
                }
                for (const auto& sp : Aid::PunishSpells(player)) {
                    const std::string k = "spell_" + std::to_string(t.methodOf.size() - 3);
                    const std::string shown = Aid::PunishSpellDisplayName(sp.name);
                    t.punishMethods.push_back({ k, "hit them with the " + shown + " spell" });
                    t.methodOf[k] = sp.name;
                }
            }
            return true;
        }

        nlohmann::json OptionsJson(const std::vector<OrgasmEngine::DecisionOption>& options)
        {
            auto out = nlohmann::json::array();
            for (const auto& o : options) {
                out.push_back({ { "key", o.key }, { "text", o.text } });
            }
            return out;
        }

        void RequestPlayerTurn(const std::string& trigger, const std::string& line, const std::string& speaker,
            bool askSpeak);

        // Game thread. Answer key and confidence of a choice question ("" when missing).
        std::pair<std::string, double> Choice(const nlohmann::json& answers, const char* q)
        {
            const auto it = answers.find(q);
            if (it == answers.end() || !it->is_object()) {
                return { "", -1.0 };
            }
            return { it->value("choice", std::string{}), it->value("confidence", -1.0) };
        }

        // Game thread. Presses the chosen HUD key as the player; Aid / Punish use the dialog answers.
        // Returns the key pressed, or "" when none / skipped.
        std::string PressChosenKey(RE::Actor* player, const TurnInput& t, const nlohmann::json& answers)
        {
            const auto [key, conf] = Choice(answers, "hotkey");
            if (key.empty() || key == "none") {
                return "";
            }
            const double floor = key == "end" ? kEndConfidence : OrgasmEngine::GetDecisionMinConfidence();
            if (conf >= 0.0 && conf < floor) {
                webui_log::info("StrategyDecision: player key {} p={:.2f} under {:.2f}, not pressed", key, conf, floor);
                return "";
            }
            if (Seconds() - g_turn.lastHotkey < kHotkeyInterval) {
                webui_log::info("StrategyDecision: player key {} skipped (pressed one {:.1f}s ago)", key,
                    Seconds() - g_turn.lastHotkey);
                return "";
            }
            const auto valid = [&](const std::string& k) {
                for (const auto& o : t.hotkeys) {
                    if (o.key == k) {
                        return true;
                    }
                }
                return false;
            };
            if (!valid(key)) {
                webui_log::warn("StrategyDecision: player key '{}' not offered", key);
                return "";
            }
            const auto part = [&](const char* q) {
                const std::string p = Choice(answers, q).first;
                for (const char* known : kBodyParts) {
                    if (p == known) {
                        return p;
                    }
                }
                return std::string("body");
            };
            if (const auto d = t.denyTargets.find(key); d != t.denyTargets.end()) {
                Hud::PressKey("deny", d->second);
            } else if (key == "aid") {
                const auto a = t.aid.find(Choice(answers, "aid_option").first);
                if (a == t.aid.end()) {
                    webui_log::warn("StrategyDecision: player aid without a valid aid_option");
                    return "";
                }
                RE::Actor* target = RE::TESForm::LookupByID<RE::Actor>(a->second.target);
                bool injuryEngine = false;
                const std::string line = Aid::Apply(player, target, a->second.form, part("aid_part"), &injuryEngine);
                if (!line.empty() && !injuryEngine) {
                    OrgasmEngine::NarrateDirect(line, player, target);
                }
            } else if (key == "punish") {
                const auto f = t.punish.find(Choice(answers, "punish_option").first);
                if (f == t.punish.end()) {
                    webui_log::warn("StrategyDecision: player punish without a valid punish_option");
                    return "";
                }
                const auto m = t.methodOf.find(Choice(answers, "punish_method").first);
                const std::string method = m != t.methodOf.end() ? m->second : "slap";
                // A decision can't write free text: no reason.
                OrgasmEngine::PunishNarrated(player, f->second, method, part("punish_part"), "");
            } else {
                Hud::PressKey(key);
            }
            g_turn.lastHotkey = Seconds();
            webui_log::info("StrategyDecision: player pressed {} p={:.2f}", key, conf);
            return key;
        }

        // Game thread. The player's turn arrived (or failed): strategy, then key, then the line.
        void OnPlayerTurn(std::shared_ptr<TurnInput> t, int success, const std::string& json)
        {
            g_turn.inFlight = false;
            auto* player = RE::PlayerCharacter::GetSingleton();
            std::int32_t sid = 0;
            const bool current = OrgasmEngine::IsAutoPlay() && OrgasmEngine::SceneIdOf(player, sid) &&
                                 sid == t->strategy.sid;
            if (!success) {
                if (player)
                    NoteFailure(player->GetFormID(), json);
            } else if (!current) {
                webui_log::info("StrategyDecision: player turn dropped (auto play off or scene changed)");
            } else {
                nlohmann::json answers = nlohmann::json::object();
                try {
                    answers = nlohmann::json::parse(json).at("answers");
                } catch (...) {
                }
                if (t->strategy.options.size() >= 2) {
                    const auto [key, conf] = Choice(answers, "strategy");
                    const char* outcome = ResultText(ApplyStrategyAnswer(player->GetFormID(), t->strategy, key, conf));
                    webui_log::info("StrategyDecision: player strategy {} p={:.2f} ({})", key, conf, outcome);
                }
                const std::string hotkey = PressChosenKey(player, *t, answers);
                if (t->askSpeak && hotkey != "end") {
                    double yes = 0.0;
                    if (const auto it = answers.find("speak"); it != answers.end() && it->is_object()) {
                        yes = it->value("noul", 0.0);
                    }
                    const double since = Seconds() - g_turn.lastSpeak;
                    webui_log::info("StrategyDecision: player speak p={:.2f} (last line {:.1f}s ago)", yes, since);
                    if (yes >= 0.5 && since >= kSpeakInterval) {
                        g_turn.lastSpeak = Seconds();
                        Hud::PressKey("speak");
                    }
                }
            }
            if (g_turn.dirty && success) {
                g_turn.dirty = false;
                RequestPlayerTurn(g_turn.trigger, g_turn.line, g_turn.speaker, g_turn.askSpeak);
            } else {
                g_turn.dirty = false;
            }
        }

        // Game thread. Asks for the player's turn in auto play. trigger: auto_play | scene_start | dialogue.
        // speaker: who said `line` ("" for the player). askSpeak: also ask whether the player speaks now.
        void RequestPlayerTurn(const std::string& trigger, const std::string& line, const std::string& speaker,
            bool askSpeak)
        {
            if (g_noRoute || !g_installed || !OrgasmEngine::IsStrategyDecisionEnabled()) {
                return;
            }
            if (g_turn.inFlight) {
                g_turn.dirty = true;
                g_turn.trigger = trigger;
                g_turn.line = line;
                g_turn.speaker = speaker;
                g_turn.askSpeak = askSpeak;
                return;
            }
            auto* player = RE::PlayerCharacter::GetSingleton();
            auto t = std::make_shared<TurnInput>();
            if (!player || !BuildTurn(player, askSpeak, *t)) {
                return;
            }
            nlohmann::json ctx = BuildContext(t->strategy, player, trigger, line);
            ctx["last_speaker"] = speaker;
            ctx["has_strategy"] = t->strategy.options.size() >= 2;
            ctx["ask_speak"] = askSpeak;
            ctx["hotkeys"] = OptionsJson(t->hotkeys);
            ctx["aid_options"] = OptionsJson(t->aidOptions);
            ctx["punish_options"] = OptionsJson(t->punishOptions);
            ctx["punish_methods"] = OptionsJson(t->punishMethods);
            ctx["parts"] = OfferedParts();
            const std::string body = ctx.dump(-1, ' ', false, nlohmann::json::error_handler_t::replace);
            g_turn.inFlight = true;
            const bool queued = PublicSendCustomDecisionToLLM(kPlayerTemplate, body.c_str(), kMaxProbabilities,
                [t](const char* answer, const char* resultJson, int success) {
                    (void)answer;
                    std::string j = resultJson ? resultJson : "";
                    SKSE::GetTaskInterface()->AddTask(
                        [t, success, j = std::move(j)]() { OnPlayerTurn(t, success, j); });
                });
            if (!queued) {
                webui_log::warn("StrategyDecision: player turn not queued");
                g_turn.inFlight = false;
                return;
            }
            webui_log::info("StrategyDecision: send player turn trigger={} speak={} keys={} aid={} punish={}", trigger,
                askSpeak, t->hotkeys.size(), t->aidOptions.size(), t->punishOptions.size());
        }

        // SkyrimNet ThreadPool: a spoken line. Copy what we need, then hop to the game thread.
        void OnDialogueEvent(const char* json)
        {
            if (!json) {
                return;
            }
            RE::FormID id = 0;
            std::string line;
            try {
                const auto j = nlohmann::json::parse(json);
                id = j.value("originatingActorFormId", static_cast<RE::FormID>(0));
                if (const auto it = j.find("data"); it != j.end()) {
                    nlohmann::json data = *it;
                    if (data.is_string()) {
                        const std::string raw = data.get<std::string>();
                        data = nlohmann::json::parse(raw, nullptr, false);
                        if (data.is_discarded()) {
                            line = raw;
                        }
                    }
                    if (data.is_object()) {
                        for (const char* k : { "text", "dialogue", "line" }) {
                            if (data.contains(k) && data[k].is_string()) {
                                line = data[k].get<std::string>();
                                break;
                            }
                        }
                    }
                }
            } catch (...) {
                return;
            }
            if (id == 0) {
                return;
            }
            SKSE::GetTaskInterface()->AddTask([id, line = std::move(line)]() {
                auto* actor = RE::TESForm::LookupByID<RE::Actor>(id);
                auto* player = RE::PlayerCharacter::GetSingleton();
                if (!actor || !OrgasmEngine::IsManaged(actor)) {
                    return;
                }
                // The speaker's own strategy (the player's comes with the player's turn below).
                if (actor != player) {
                    Request(id, "dialogue", line);
                }
                // Auto play: every line in the player's scene is the player's turn. The player's own line never
                // asks to speak again.
                std::int32_t sid = 0;
                std::int32_t playerSid = 0;
                if (OrgasmEngine::IsAutoPlay() && OrgasmEngine::SceneIdOf(actor, sid) &&
                    OrgasmEngine::SceneIdOf(player, playerSid) && sid == playerSid) {
                    const char* name = actor->GetDisplayFullName();
                    RequestPlayerTurn("dialogue", line, actor == player ? "" : (name ? name : ""), actor != player);
                }
            });
        }
    }

    void Install()
    {
        if (g_installed) {
            return;
        }
        if (!ApiReady()) {
            webui_log::warn("StrategyDecision: SkyrimNet public API v{}+ with decisions not available (version {}); "
                            "NPC strategies stay on role defaults",
                kMinApiVersion, PublicGetVersion ? PublicGetVersion() : 0);
            return;
        }
        int registered = 0;
        for (const char* type : kDialogueEvents) {
            if (PublicRegisterEventCallback(type, OnDialogueEvent) != 0) {
                ++registered;
            }
        }
        if (registered == 0) {
            webui_log::warn("StrategyDecision: dialogue event callbacks not registered; will retry on game load");
            return;
        }
        g_installed = true;
        webui_log::info("StrategyDecision: installed ({} dialogue event types)", registered);
    }

    void Reset()
    {
        g_pending.clear();
        g_turn = PlayerTurn{};
        g_noRoute = false;
        g_noRouteWarned = false;
    }

    void OnSceneReady(std::int32_t sid)
    {
        auto* player = RE::PlayerCharacter::GetSingleton();
        for (const auto id : OrgasmEngine::SceneNpcs(sid)) {
            if (player && id == player->GetFormID()) {
                RequestPlayerTurn("scene_start", "", "", false);  // auto play
            } else {
                Request(id, "scene_start", "");
            }
        }
    }

    void OnAutoPlay()
    {
        RequestPlayerTurn("auto_play", "", "", true);
    }

    void RequestAnswer(RE::FormID target, const std::string& trigger, const std::string& line,
        std::function<void(OrgasmEngine::DecisionResult)> done)
    {
        Request(target, trigger, line, std::move(done));
    }
}
