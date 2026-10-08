#include "StrategyDecision.h"

#include "Config.h"
#include "OrgasmEngine.h"
#include "WebUI_Log.h"

#include <nlohmann/json.hpp>

#include <atomic>
#include <functional>
#include <memory>
#include <string>
#include <unordered_map>

// Defined in PublicAPI.h (included once from Config.cpp).
extern "C" {
extern int (*PublicGetVersion)();
extern uint64_t (*PublicFormIDToUUID)(uint32_t formId);
extern uint64_t (*PublicRegisterEventCallback)(const char* eventType, std::function<void(const char*)> callback);
extern bool (*PublicSendCustomDecisionToLLM)(const char* templateName, const char* contextJson, int maxProbabilities,
    std::function<void(const char* answer, const char* resultJson, int success)> callback);
}

namespace StrategyDecision
{
    namespace
    {
        constexpr const char* kTemplate = "sexlab/minigame_strategy";
        constexpr int kMaxProbabilities = 3;
        constexpr int kMinApiVersion = 12;
        // SkyrimNet event types for a spoken NPC line (originator = speaker).
        constexpr const char* kDialogueEvents[] = { "dialogue", "dialogue_npc", "dialogue_background" };

        std::atomic<bool> g_installed{ false };
        bool g_noRouteWarned = false;  // game thread
        bool g_noRoute = false;        // no decisions provider: stop asking until the next load

        // Game thread only. One request in flight per NPC; a line arriving meanwhile is kept for one follow-up.
        struct Pending
        {
            bool inFlight = false;
            bool dirty = false;
            std::string trigger;
            std::string line;
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

        nlohmann::json BuildContext(const OrgasmEngine::DecisionInput& in, RE::Actor* focus, const std::string& trigger,
            const std::string& line)
        {
            nlohmann::json ctx;
            ctx["trigger"] = trigger;
            ctx["focus_uuid"] = UuidOf(in.id);
            ctx["focus_name"] = in.name;
            ctx["last_line_text"] = line;
            ctx["progress"] = in.progress;
            ctx["role"] = in.role;
            ctx["arousal"] = in.arousal;
            ctx["orgasms"] = in.orgasms;
            ctx["expects_orgasm"] = in.expectsOrgasm;
            ctx["broken"] = in.broken;
            ctx["current_key"] = in.currentKey;
            ctx["approach"] = in.approach;
            ctx["forced_by"] = in.forcedBy;
            ctx["force_method"] = in.forceMethod;
            auto partners = nlohmann::json::array();
            for (const auto& p : in.partners) {
                const auto [label, rank] = Relationship(focus, RE::TESForm::LookupByID<RE::Actor>(p.id));
                partners.push_back({ { "uuid", UuidOf(p.id) }, { "name", p.name }, { "is_player", p.isPlayer },
                    { "role", p.role }, { "arousal", p.arousal }, { "orgasms", p.orgasms }, { "approach", p.approach },
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

        void Request(RE::FormID id, const std::string& trigger, const std::string& line);

        // Game thread. The decision for `id` arrived (or failed).
        void OnAnswer(RE::FormID id, std::shared_ptr<OrgasmEngine::DecisionInput> in, int success,
            const std::string& answer, const std::string& json)
        {
            Pending& p = g_pending[id];
            p.inFlight = false;
            if (!success) {
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
                g_pending.erase(id);
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
            using R = OrgasmEngine::DecisionResult;
            RE::Actor* actor = RE::TESForm::LookupByID<RE::Actor>(id);
            const R result = actor && !key.empty() ? OrgasmEngine::ApplyStrategyDecision(actor, *in, key, confidence)
                                                   : R::kDropped;
            const char* outcome = result == R::kChanged       ? "changed"
                                  : result == R::kKept          ? "kept"
                                  : result == R::kLowConfidence ? "low confidence, kept current"
                                  : result == R::kUnknown       ? "unknown key"
                                                                : "dropped: scene ended or roster changed";
            webui_log::info("StrategyDecision: {:#x} answer {} p={:.2f} ({})", id, key, confidence, outcome);
            if (p.dirty) {
                p.dirty = false;
                const std::string trigger = p.trigger;
                const std::string next = p.line;
                Request(id, trigger, next);
            } else {
                g_pending.erase(id);
            }
        }

        // Game thread.
        void Request(RE::FormID id, const std::string& trigger, const std::string& line)
        {
            if (g_noRoute || !g_installed || !OrgasmEngine::IsStrategyDecisionEnabled()) {
                return;
            }
            RE::Actor* actor = RE::TESForm::LookupByID<RE::Actor>(id);
            auto in = std::make_shared<OrgasmEngine::DecisionInput>();
            if (!actor || !OrgasmEngine::GetStrategyDecisionInput(actor, *in) || in->options.size() < 2) {
                return;
            }
            Pending& p = g_pending[id];
            if (p.inFlight) {
                p.dirty = true;
                p.trigger = trigger;
                p.line = line;
                return;
            }
            const std::string ctx = BuildContext(*in, actor, trigger, line).dump();
            p.inFlight = true;
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
                g_pending.erase(id);
                return;
            }
            webui_log::info("StrategyDecision: send {:#x} trigger={} current={} options={}", id, trigger,
                in->currentKey, in->options.size());
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
                if (!actor || actor == RE::PlayerCharacter::GetSingleton() || !OrgasmEngine::IsManaged(actor)) {
                    return;
                }
                Request(id, "dialogue", line);
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
        g_noRoute = false;
        g_noRouteWarned = false;
    }

    void OnSceneReady(std::int32_t sid)
    {
        for (const auto id : OrgasmEngine::SceneNpcs(sid)) {
            Request(id, "scene_start", "");
        }
    }
}
