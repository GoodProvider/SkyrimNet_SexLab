#include "OrgasmEngine.h"

#include "AnimSpeed.h"
#include "Config.h"
#include "Hud.h"
#include "NarrationQueue.h"
#include "WebUI_Log.h"

#include <algorithm>
#include <atomic>
#include <chrono>
#include <cmath>
#include <map>
#include <mutex>
#include <random>
#include <thread>
#include <unordered_map>

namespace OrgasmEngine
{
    namespace
    {
        constexpr const char* kShellScript = "SkyrimNet_SexLab_OrgasmEngine";
        constexpr auto kTickInterval = std::chrono::milliseconds(250);
        constexpr float kMaxEnjoyment = 100.0f;
        constexpr float kEdgeThreshold = 90.0f;
        constexpr double kFlashSeconds = 3.0;
        constexpr double kMirrorInterval = 1.0;
        constexpr double kMirrorRefresh = 3.0;
        constexpr double kRollInterval = 1.0;
        constexpr double kStaleSceneSeconds = 10.0;
        constexpr float kBreakAt = 0.10f;
        constexpr float kRecoverAt = 0.25f;
        constexpr double kDomSyncInterval = 1.0;
        constexpr double kDomRefresh = 2.0;
        constexpr float kDomMeterPossible = 50.0f;  // DOM meter >= this: DOM's values could produce an orgasm
        constexpr float kFallbackRate = 0.5f;       // per second, when the scene sent no stage timers
        constexpr float kFinalShare = 0.9f;         // target: stages 1..N-1 + this x the final stage
        constexpr float kLeadInStretch = 1.5f;      // LeadIn target: all stages x this (never reaches 100)
        constexpr float kSafetyAt = 0.9f;           // safety net: this share of the final stage's timer
        constexpr float kSafetyMin = 90.0f;         // safety net: enjoyment needed to fire
        constexpr float kDomStep = 10.0f;           // DOM slave: progress points per arousal push
        constexpr float kDomStepShare = 0.1f;       // DOM slave: step roll share of one full DOM roll

        struct Settings
        {
            bool miniGame = false;
            // Role multipliers on the scene's timed base rate.
            float passiveRate = 0.4f;
            float aggressorRate = 0.45f;
            float victimRate = 0.3f;
            float jitterMin = 0.95f;
            float jitterMax = 1.1f;
            float domArousalScale = 0.2f;        // DOM amount per progress point (MOD_Daring)
            float domArousalScalePlayer = 0.2f;  // player scenes: extra per point (MOD_Naivety)
            float arouseAmount = 3.0f;
            float calmAmount = 4.0f;
            float staminaCost = 8.0f;
            float magickaCost = 8.0f;
            float edgeSeconds = 4.0f;
            bool mentalBreak = false;
            float breakDrain = 6.0f;
            float randomBonus = 10.0f;
            float narrateWindow = 3.0f;
            float groupJoin = 95.0f;  // someone orgasms: others at this enjoyment or more join them
        };

        struct ActorState
        {
            RE::FormID id = 0;
            std::int32_t sid = 0;
            float enjoyment = 0.0f;
            double lastOrgasm = -1.0;
            double edgeUntil = 0.0;
            std::int32_t orgasmCount = 0;
            Role role = Role::kNormal;
            std::int32_t skill = 0;
            std::int32_t lewd = 0;
            bool broken = false;
            bool sceneBlocked = false;
            bool orgasmExpected = true;  // position's orgasm_expected; false: no passive gain
            std::map<std::string, bool> blocks;
            std::map<std::string, float> rateMods;
            bool pending = false;
            bool pendingForce = false;
            std::string pendingSource;
            std::int32_t lastMirrored = -1000;
            double lastMirrorAt = 0.0;
            double lastRollAt = 0.0;
            double flashUntil = 0.0;
            bool deniedSent = false;
            float cooldown = 10.0f;
            std::int32_t ownOrgasmsInFlight = 0;  // fired by us, SexLabOrgasm not seen yet
            float jitter = 1.0f;                  // per-actor rate factor, rolled at BeginScene
            double lastCalmAt = -1.0;
            // DOM slave: passive gain is progress pushed to DOM in steps; enjoyment is a meter computed
            // by DOM (SetDomMeter).
            bool dom = false;
            float domDelta = 0.0f;  // mini-game arouse / calm, pushed as before
            float domShare = 0.0f;  // step-roll share from Arouse
            float domProgress = 0.0f;
            float domStepAcc = 0.0f;
            bool domPrepaid = false;  // DOM's own recurring adds cancelled for this scene
            double lastDomSyncAt = 0.0;
            bool domSyncNow = false;
        };

        struct SceneState
        {
            std::int32_t sid = 0;
            std::vector<RE::FormID> actors;
            bool hasPlayer = false;
            std::int32_t stage = 1;
            std::int32_t stageCount = 0;
            bool finalDone = false;
            float speedScale = 1.0f;
            double staleSince = 0.0;
            // Stage timers (SexLab's GetTimer rule) from SetStageTimers.
            std::vector<float> stageSecs;
            float targetSecs = 0.0f;
            float baseRate = 0.0f;  // 0: no timers, kFallbackRate
            bool leadIn = false;
            bool paused = false;
            double finalStageAt = 0.0;  // Now() on entering the final stage
            double finalElapsed = 0.0;  // animating, unpaused seconds in the final stage
        };

        // Work collected under the lock, run after it is released (Papyrus dispatch / events / HUD).
        // One orgasm moment in a scene: everyone who fired together, narrated as one message.
        struct OrgasmGroupFx
        {
            std::vector<RE::FormID> actors;
            std::vector<std::int32_t> forced;  // per actor: 1 = forced by the player (WebUI)
            bool individual = false;           // false: only safety-net / external joins (stash + window)
            std::string source;
            RE::FormID allower = 0;  // AllowOrgasm: "<allower> allows <allowed> to orgasm."
            RE::FormID allowed = 0;
            std::string extras;  // pending arouse / calm narrations folded into the orgasm message
        };
        struct MirrorFx
        {
            RE::FormID actor;
            std::int32_t value;
        };
        struct NarrateFx
        {
            std::string eventType;
            std::string msg;
            RE::FormID source;
            RE::FormID target;
        };
        struct EventFx
        {
            SKYRIMNET_SEXLAB_API::EngineEventType type;
            RE::FormID target;
            RE::FormID source;
            std::string sourceId;
            float value;
            std::int32_t count;
        };
        struct DomSyncFx
        {
            RE::FormID actor;
            float miniDelta;  // mini-game arouse / calm
            float daring;     // IncreaseArousal amount, MOD_Daring
            float naivety;    // IncreaseArousal amount, MOD_Naivety (player scenes)
            float share;      // > 0: step roll with this share of a full DOM roll
            bool prepay;      // first sync of the scene: cancel DOM's own recurring adds
            bool hasPlayer;
        };
        struct Effects
        {
            std::vector<OrgasmGroupFx> orgasms;
            std::vector<MirrorFx> mirrors;
            std::vector<NarrateFx> narrations;
            std::vector<EventFx> events;
            std::vector<DomSyncFx> domSyncs;
            bool empty() const
            {
                return orgasms.empty() && mirrors.empty() && narrations.empty() && events.empty() && domSyncs.empty();
            }
        };

        // Calm/arouse narration coalescing: one narration per (who, target, action) window.
        struct NarrateKey
        {
            RE::FormID who;
            RE::FormID target;
            bool arouse;
            bool operator<(const NarrateKey& o) const
            {
                return std::tie(who, target, arouse) < std::tie(o.who, o.target, o.arouse);
            }
        };

        std::recursive_mutex g_lock;
        Settings g_settings;
        bool g_ratesOverridden = false;
        std::unordered_map<RE::FormID, ActorState> g_actors;
        std::map<std::int32_t, SceneState> g_scenes;
        std::map<NarrateKey, double> g_narrateDue;
        std::map<std::uint32_t, SKYRIMNET_SEXLAB_API::EngineEventCallback> g_callbacks;
        std::uint32_t g_nextCallback = 1;
        double g_lastTick = 0.0;
        std::mt19937 g_rng{ std::random_device{}() };
        RE::TESFaction* g_animatingFaction = nullptr;

        double Now()
        {
            using namespace std::chrono;
            static const auto start = steady_clock::now();
            return duration<double>(steady_clock::now() - start).count();
        }

        RE::Actor* ActorFor(RE::FormID id)
        {
            return id ? RE::TESForm::LookupByID<RE::Actor>(id) : nullptr;
        }

        std::string NameOf(RE::Actor* actor)
        {
            if (!actor) {
                return "";
            }
            const char* name = actor->GetDisplayFullName();
            return name ? name : "";
        }

        bool IsPlayer(RE::Actor* actor)
        {
            return actor && actor == RE::PlayerCharacter::GetSingleton();
        }

        float OrgasmCooldown(RE::Actor* actor)
        {
            // SexLab's rule: (IsMale + IsCreature + 1) x 10 s.
            float seconds = 10.0f;
            if (!actor) {
                return seconds;
            }
            if (const auto* base = actor->GetActorBase(); base && base->GetSex() == RE::SEX::kMale) {
                seconds += 10.0f;
            }
            if (!actor->HasKeywordString("ActorTypeNPC")) {
                seconds += 10.0f;
            }
            return seconds;
        }

        ActorState* Find(RE::Actor* actor)
        {
            if (!actor) {
                return nullptr;
            }
            const auto it = g_actors.find(actor->GetFormID());
            return it != g_actors.end() ? &it->second : nullptr;
        }

        SceneState* SceneOf(const ActorState& st)
        {
            const auto it = g_scenes.find(st.sid);
            return it != g_scenes.end() ? &it->second : nullptr;
        }

        // Target = stages 1..N-1 + kFinalShare x the final stage (LeadIn: all x kLeadInStretch);
        // baseRate reaches 100 at the target. Fixed per animation.
        void ApplyStageTimers(SceneState& sc, const std::vector<float>& stageSecs, bool leadIn)
        {
            float total = 0.0f;
            float target = 0.0f;
            for (std::size_t i = 0; i < stageSecs.size(); ++i) {
                const float secs = std::max(0.0f, stageSecs[i]);
                total += secs;
                target += i + 1 < stageSecs.size() ? secs : kFinalShare * secs;
            }
            if (leadIn) {
                target = total * kLeadInStretch;
            }
            sc.stageSecs = stageSecs;
            sc.leadIn = leadIn;
            sc.targetSecs = target;
            sc.baseRate = target > 0.0f ? kMaxEnjoyment / target : 0.0f;
        }

        float RoleMult(Role role)
        {
            switch (role) {
            case Role::kAggressor:
                return g_settings.aggressorRate;
            case Role::kVictim:
                return g_settings.victimRate;
            default:
                return g_settings.passiveRate;
            }
        }

        bool AnyBlock(const ActorState& st)
        {
            if (st.sceneBlocked) {
                return true;
            }
            for (const auto& [src, on] : st.blocks) {
                if (on) {
                    return true;
                }
            }
            return false;
        }

        float CurrentAv(RE::Actor* actor, RE::ActorValue av)
        {
            auto* owner = actor ? actor->AsActorValueOwner() : nullptr;
            return owner ? owner->GetActorValue(av) : 0.0f;
        }

        float MaxAv(RE::Actor* actor, RE::ActorValue av)
        {
            auto* owner = actor ? actor->AsActorValueOwner() : nullptr;
            if (!owner) {
                return 0.0f;
            }
            return owner->GetPermanentActorValue(av) +
                   actor->GetActorValueModifier(RE::ACTOR_VALUE_MODIFIER::kTemporary, av);
        }

        void DamageAv(RE::Actor* actor, RE::ActorValue av, float amount)
        {
            if (auto* owner = actor ? actor->AsActorValueOwner() : nullptr; owner && amount > 0.0f) {
                owner->DamageActorValue(av, amount);
            }
        }

        float ArouseCost(const ActorState* who)
        {
            const float skill = who ? static_cast<float>(who->skill) : 0.0f;
            return g_settings.staminaCost * 10.0f / (10.0f + skill);
        }

        float CalmCost(const ActorState* who)
        {
            const float lewd = who ? static_cast<float>(who->lewd) : 0.0f;
            return std::max(0.5f, g_settings.magickaCost * (1.0f + 0.05f * lewd));
        }

        // Caller holds g_lock. Magicka thresholds with hysteresis.
        void UpdateBroken(ActorState& st, RE::Actor* actor, RE::FormID sourceId, const std::string& source,
            Effects& fx)
        {
            bool broken = st.broken;
            if (!g_settings.mentalBreak || !actor) {
                broken = false;
            } else {
                const float max = MaxAv(actor, RE::ActorValue::kMagicka);
                const float pct = max > 0.0f ? CurrentAv(actor, RE::ActorValue::kMagicka) / max : 1.0f;
                if (!st.broken && pct <= kBreakAt) {
                    broken = true;
                } else if (st.broken && pct > kRecoverAt) {
                    broken = false;
                }
            }
            if (broken != st.broken) {
                st.broken = broken;
                fx.events.push_back({ SKYRIMNET_SEXLAB_API::EngineEventType::kMentalBreak, st.id, sourceId, source,
                    0.0f, broken ? 1 : 0 });
                webui_log::info("OrgasmEngine: {:#x} mental break {}", st.id, broken ? "on" : "off");
            }
        }

        // Caller holds g_lock. Counts the orgasm and adds the actor to group (the caller emits the group).
        void Fire(ActorState& st, OrgasmGroupFx& group, bool individual, const std::string& source, double now,
            Effects& fx)
        {
            // Forced by the player (WebUI button): narrated "<name> is forced to orgasm by <player>.".
            // Other forced sources have no known forcer and narrate as a normal orgasm.
            const bool forced = st.pending && st.pendingForce && st.pendingSource == "webui";
            if (group.actors.empty()) {
                group.source = source;
            }
            group.actors.push_back(st.id);
            group.forced.push_back(forced ? 1 : 0);
            group.individual = group.individual || individual;
            st.enjoyment = 0.0f;
            st.orgasmCount += 1;
            st.lastOrgasm = now;
            st.flashUntil = now + kFlashSeconds;
            st.pending = false;
            st.pendingForce = false;
            st.deniedSent = false;
            // SexLab's QuitEnjoyment resets inside ForceOrgasm; re-mirror soon after.
            st.lastMirrored = -1000;
            st.lastMirrorAt = now;
            st.ownOrgasmsInFlight += 1;
            fx.events.push_back({ SKYRIMNET_SEXLAB_API::EngineEventType::kOrgasm, st.id, st.id, source, 0.0f,
                st.orgasmCount });
            webui_log::info("OrgasmEngine: orgasm {:#x} source={} individual={} forced={} count={}", st.id, source,
                individual, forced, st.orgasmCount);
        }

        bool IsCooling(const ActorState& st, double now)
        {
            return st.lastOrgasm >= 0.0 && now - st.lastOrgasm < st.cooldown;
        }

        // Caller holds g_lock. Not DOM, no block, not edging, not cooling down.
        bool CanOrgasmNow(const ActorState& st, double now)
        {
            return !st.dom && !AnyBlock(st) && now >= st.edgeUntil && !IsCooling(st, now);
        }

        // Caller holds g_lock. Someone in the scene orgasmed: everyone else at groupJoin or more joins them.
        void JoinGroup(const SceneState& sc, OrgasmGroupFx& group, double now, Effects& fx)
        {
            for (const auto id : sc.actors) {
                if (std::find(group.actors.begin(), group.actors.end(), id) != group.actors.end()) {
                    continue;
                }
                auto at = g_actors.find(id);
                if (at == g_actors.end()) {
                    continue;
                }
                ActorState& st = at->second;
                if (!CanOrgasmNow(st, now) || st.enjoyment < g_settings.groupJoin) {
                    continue;
                }
                webui_log::info("OrgasmEngine: {:#x} joins the group orgasm enjoyment={:.1f}", id, st.enjoyment);
                Fire(st, group, false, "group", now, fx);
            }
        }

        std::string NarrationText(const NarrateKey& key)
        {
            const std::string a = NameOf(ActorFor(key.who));
            const std::string b = NameOf(ActorFor(key.target));
            if (a.empty() || b.empty()) {
                return "";
            }
            return key.arouse ? a + " arouses " + b + ", pushing them closer to orgasm."
                              : a + " calms " + b + ", keeping them further from orgasm.";
        }

        // Caller holds g_lock. Folds pending arouse / calm narrations about the group into it (no separate DN
        // racing the orgasm DN) and queues the group's single Papyrus dispatch.
        void EmitGroup(OrgasmGroupFx&& group, Effects& fx)
        {
            if (group.actors.empty()) {
                return;
            }
            const auto inGroup = [&](RE::FormID id) {
                return std::find(group.actors.begin(), group.actors.end(), id) != group.actors.end();
            };
            for (auto it = g_narrateDue.begin(); it != g_narrateDue.end();) {
                if (!inGroup(it->first.who) && !inGroup(it->first.target)) {
                    ++it;
                    continue;
                }
                const std::string text = NarrationText(it->first);
                if (!text.empty()) {
                    group.extras += group.extras.empty() ? text : " " + text;
                }
                it = g_narrateDue.erase(it);
            }
            fx.orgasms.push_back(std::move(group));
        }

        // Caller holds g_lock. Queue one coalesced calm/arouse narration.
        void NoteNarration(RE::FormID who, RE::FormID target, bool arouse, double now)
        {
            if (!who || !target || who == target) {
                return;
            }
            const NarrateKey key{ who, target, arouse };
            if (g_narrateDue.find(key) == g_narrateDue.end()) {
                g_narrateDue[key] = now + std::max(0.0f, g_settings.narrateWindow);
            }
        }

        // Caller holds g_lock.
        void FlushNarrations(double now, bool all, Effects& fx)
        {
            for (auto it = g_narrateDue.begin(); it != g_narrateDue.end();) {
                if (!all && it->second > now) {
                    ++it;
                    continue;
                }
                const auto [who, target, arouse] = it->first;
                std::string msg = NarrationText(it->first);
                if (!msg.empty()) {
                    fx.narrations.push_back({ arouse ? "sexlab_arouse" : "sexlab_calm", std::move(msg), who, target });
                }
                it = g_narrateDue.erase(it);
            }
        }

        void DispatchShell(const char* fn, RE::BSScript::IFunctionArguments* args)
        {
            auto* vm = RE::BSScript::Internal::VirtualMachine::GetSingleton();
            if (!vm) {
                webui_log::error("OrgasmEngine: no VM for {}", fn);
                delete args;
                return;
            }
            RE::BSTSmartPointer<RE::BSScript::IStackCallbackFunctor> callback;
            vm->DispatchStaticCall(kShellScript, fn, args, callback);
        }

        void SendModEvent(const EventFx& e)
        {
            const char* name = "SkyrimNet_SexLab_Orgasm";
            switch (e.type) {
            case SKYRIMNET_SEXLAB_API::EngineEventType::kOrgasmDenied:
                name = "SkyrimNet_SexLab_OrgasmDenied";
                break;
            case SKYRIMNET_SEXLAB_API::EngineEventType::kEdge:
                name = "SkyrimNet_SexLab_Edge";
                break;
            case SKYRIMNET_SEXLAB_API::EngineEventType::kMentalBreak:
                name = "SkyrimNet_SexLab_MentalBreak";
                break;
            default:
                break;
            }
            auto* source = SKSE::GetModCallbackEventSource();
            if (!source) {
                return;
            }
            // strArg "<source>|<acting actor FormID>" so Papyrus listeners get both.
            const std::string str = e.sourceId + "|" + std::to_string(e.source);
            const float num = e.type == SKYRIMNET_SEXLAB_API::EngineEventType::kEdge ? e.value
                                                                                    : static_cast<float>(e.count);
            SKSE::ModCallbackEvent ev{ name, str.c_str(), num, ActorFor(e.target) };
            source->SendEvent(&ev);
        }

        // Game thread. Runs everything collected under the lock.
        void RunEffects(Effects& fx)
        {
            for (const auto& g : fx.orgasms) {
                std::vector<RE::Actor*> actors;
                std::vector<std::int32_t> forced;
                for (std::size_t i = 0; i < g.actors.size(); ++i) {
                    if (auto* a = ActorFor(g.actors[i])) {
                        actors.push_back(a);
                        forced.push_back(i < g.forced.size() ? g.forced[i] : 0);
                    }
                }
                if (actors.empty()) {
                    continue;
                }
                DispatchShell("Effect_OrgasmGroup",
                    RE::MakeFunctionArguments(std::move(actors), std::move(forced), static_cast<bool>(g.individual),
                        RE::BSFixedString(g.source.c_str()), ActorFor(g.allower), ActorFor(g.allowed),
                        RE::BSFixedString(g.extras.c_str())));
            }
            for (const auto& m : fx.mirrors) {
                if (auto* a = ActorFor(m.actor)) {
                    DispatchShell("Effect_Mirror",
                        RE::MakeFunctionArguments(std::move(a), static_cast<std::int32_t>(m.value)));
                }
            }
            for (const auto& d : fx.domSyncs) {
                if (auto* a = ActorFor(d.actor)) {
                    DispatchShell("Effect_DomSync",
                        RE::MakeFunctionArguments(std::move(a), static_cast<float>(d.miniDelta),
                            static_cast<float>(d.daring), static_cast<float>(d.naivety), static_cast<float>(d.share),
                            static_cast<bool>(d.prepay), static_cast<bool>(d.hasPlayer)));
                }
            }
            for (const auto& n : fx.narrations) {
                Narrate(n.eventType, n.msg, ActorFor(n.source), ActorFor(n.target));
            }
            std::vector<SKYRIMNET_SEXLAB_API::EngineEventCallback> callbacks;
            {
                std::lock_guard lock(g_lock);
                for (const auto& [h, cb] : g_callbacks) {
                    callbacks.push_back(cb);
                }
            }
            for (const auto& e : fx.events) {
                SendModEvent(e);
                const SKYRIMNET_SEXLAB_API::EngineEvent ev{ e.type, ActorFor(e.target), ActorFor(e.source),
                    e.sourceId.c_str(), e.value, e.count };
                for (auto* cb : callbacks) {
                    try {
                        cb(ev);
                    } catch (...) {
                        webui_log::error("OrgasmEngine: event callback threw");
                    }
                }
            }
        }

        // Effects produced off the game thread (Papyrus natives, C++ API callers).
        void PostEffects(Effects&& fx)
        {
            if (fx.empty()) {
                return;
            }
            auto shared = std::make_shared<Effects>(std::move(fx));
            SKSE::GetTaskInterface()->AddTask([shared]() { RunEffects(*shared); });
        }

        bool AnyAnimating(const SceneState& sc)
        {
            if (!g_animatingFaction) {
                g_animatingFaction = RE::TESForm::LookupByEditorID<RE::TESFaction>("SexLabAnimatingFaction");
                if (!g_animatingFaction) {
                    return true;  // cannot tell; keep the scene
                }
            }
            for (const auto id : sc.actors) {
                if (auto* a = ActorFor(id); a && a->IsInFaction(g_animatingFaction)) {
                    return true;
                }
            }
            return false;
        }

        void DropSceneLocked(std::int32_t sid)
        {
            const auto it = g_scenes.find(sid);
            if (it == g_scenes.end()) {
                return;
            }
            for (const auto id : it->second.actors) {
                AnimSpeed::SetScale(ActorFor(id), 1.0f);
                const auto at = g_actors.find(id);
                if (at != g_actors.end() && at->second.sid == sid) {
                    g_actors.erase(at);
                }
            }
            for (auto n = g_narrateDue.begin(); n != g_narrateDue.end();) {
                if (!g_actors.contains(n->first.target)) {
                    n = g_narrateDue.erase(n);
                } else {
                    ++n;
                }
            }
            g_scenes.erase(it);
        }

        // Game thread, every kTickInterval.
        void Tick()
        {
            const double now = Now();
            const bool paused = NarrationQueue::IsPaused();
            const double dt = paused ? 0.0 : std::clamp(now - g_lastTick, 0.0, 1.0);
            g_lastTick = now;

            Effects fx;
            if (!paused) {
                std::lock_guard lock(g_lock);
                std::vector<std::int32_t> stale;
                for (auto& [sid, sc] : g_scenes) {
                    if (!AnyAnimating(sc)) {
                        if (sc.staleSince <= 0.0) {
                            sc.staleSince = now;
                        } else if (now - sc.staleSince > kStaleSceneSeconds) {
                            stale.push_back(sid);
                        }
                        continue;
                    }
                    sc.staleSince = 0.0;

                    RE::Actor* first = sc.actors.empty() ? nullptr : ActorFor(sc.actors.front());
                    const float speed = first ? AnimSpeed::Get(first) : 1.0f;
                    const bool finalStage = sc.stageCount > 0 && sc.stage >= sc.stageCount;
                    if (finalStage && !sc.paused) {
                        sc.finalElapsed += dt;
                    }
                    const float sceneRate = sc.baseRate > 0.0f ? sc.baseRate : kFallbackRate;
                    // Everyone who orgasms in this scene this tick: one group, one message.
                    OrgasmGroupFx group;

                    for (const auto id : sc.actors) {
                        auto at = g_actors.find(id);
                        if (at == g_actors.end()) {
                            continue;
                        }
                        ActorState& st = at->second;
                        RE::Actor* actor = ActorFor(id);

                        // 1. Passive gain: fixed rate from the stage timers, so extra time (repeated stage) or
                        // speed adds enjoyment; a paused stage holds. Not expected to orgasm: mini-game only.
                        float rate = st.orgasmExpected && !sc.paused ? sceneRate * RoleMult(st.role) * st.jitter
                                                                     : 0.0f;
                        for (const auto& [src, m] : st.rateMods) {
                            rate *= m;
                        }
                        const float gain = static_cast<float>(rate * dt) * speed;
                        if (st.dom) {
                            st.domProgress += gain;
                            st.domStepAcc += gain;
                        } else {
                            st.enjoyment = std::clamp(st.enjoyment + gain, 0.0f, kMaxEnjoyment);
                        }

                        // Mental break recovers as magicka regenerates.
                        if (st.broken || g_settings.mentalBreak) {
                            UpdateBroken(st, actor, 0, "minigame", fx);
                        }

                        // 2. Orgasm test.
                        if (st.pending && st.pendingForce) {
                            Fire(st, group, true, st.pendingSource, now, fx);
                        } else if (st.dom) {
                            // DOM decides: push progress to DOM's arousal in steps (vanilla total spread over
                            // the animation), with a light step roll after each rise. DOM's own full roll
                            // still comes from the OrgasmStart hook or AnimationEnd.
                            st.pending = false;
                            const bool cooling = st.lastOrgasm >= 0.0 && now - st.lastOrgasm < st.cooldown;
                            const bool edging = now < st.edgeUntil;
                            const bool blocked = AnyBlock(st);
                            if (blocked && st.enjoyment >= kDomMeterPossible && !st.deniedSent) {
                                st.deniedSent = true;
                                fx.events.push_back({ SKYRIMNET_SEXLAB_API::EngineEventType::kOrgasmDenied, st.id,
                                    st.id, "dom", st.enjoyment, st.orgasmCount });
                            }
                            if (st.enjoyment < kDomMeterPossible) {
                                st.deniedSent = false;
                            }
                            const double since = now - st.lastDomSyncAt;
                            const bool due = st.domSyncNow || !st.domPrepaid ||
                                             (since >= kDomSyncInterval && (st.domStepAcc >= kDomStep ||
                                                                             st.domDelta != 0.0f ||
                                                                             since >= kDomRefresh));
                            if (due) {
                                int steps = 0;
                                while (st.domStepAcc >= kDomStep) {
                                    st.domStepAcc -= kDomStep;
                                    ++steps;
                                }
                                const float points = static_cast<float>(steps) * kDomStep;
                                const float daring = points * g_settings.domArousalScale;
                                const float naivety = sc.hasPlayer ? points * g_settings.domArousalScalePlayer : 0.0f;
                                const bool rising = steps > 0 || st.domDelta > 0.0f;
                                const bool allowRoll = rising && !blocked && !cooling && !edging;
                                const float share =
                                    allowRoll ? static_cast<float>(steps) * kDomStepShare + st.domShare : 0.0f;
                                const bool prepay = !st.domPrepaid;
                                st.domPrepaid = true;
                                fx.domSyncs.push_back({ id, st.domDelta, daring, naivety, share, prepay, sc.hasPlayer });
                                if (steps > 0 || prepay || st.domDelta != 0.0f) {
                                    webui_log::info(
                                        "OrgasmEngine: dom step {:#x} steps={} progress={:.1f} daring={} naivety={} "
                                        "mini={} share={} prepay={}",
                                        id, steps, st.domProgress, daring, naivety, st.domDelta, share, prepay);
                                }
                                st.domDelta = 0.0f;
                                st.domShare = 0.0f;
                                st.domSyncNow = false;
                                st.lastDomSyncAt = now;
                            }
                        } else {
                            float test = st.enjoyment;
                            if (g_settings.miniGame && now - st.lastRollAt >= kRollInterval) {
                                st.lastRollAt = now;
                                std::uniform_real_distribution<float> roll(0.0f, std::max(0.0f, g_settings.randomBonus));
                                test += roll(g_rng);
                            }
                            const bool wants = test >= kMaxEnjoyment || st.pending;
                            const bool cooling = st.lastOrgasm >= 0.0 && now - st.lastOrgasm < st.cooldown;
                            const bool edging = now < st.edgeUntil;
                            if (wants && !cooling && !edging) {
                                if (AnyBlock(st)) {
                                    if (!st.deniedSent) {
                                        st.deniedSent = true;
                                        fx.events.push_back({ SKYRIMNET_SEXLAB_API::EngineEventType::kOrgasmDenied,
                                            st.id, st.id, st.pending ? st.pendingSource : "engine", st.enjoyment,
                                            st.orgasmCount });
                                    }
                                    st.pending = false;
                                } else {
                                    const std::string source = st.pending ? st.pendingSource : "engine";
                                    Fire(st, group, true, source, now, fx);
                                }
                            }
                            if (st.enjoyment < kEdgeThreshold) {
                                st.deniedSent = false;
                            }
                        }

                        // 3. Mirror into SexLab.
                        const auto rounded = static_cast<std::int32_t>(std::lround(st.enjoyment));
                        if (now - st.lastMirrorAt >= kMirrorInterval &&
                            (rounded != st.lastMirrored || now - st.lastMirrorAt >= kMirrorRefresh)) {
                            st.lastMirrored = rounded;
                            st.lastMirrorAt = now;
                            fx.mirrors.push_back({ id, rounded });
                        }
                    }

                    // 4. Safety net: at 90% of the final stage's timer (animating, unpaused time), fire
                    // each non-DOM actor who has not finished. Mini-game off: every non-victim who is
                    // expected to orgasm fires (one orgasm each). Victims and the mini-game need
                    // kSafetyMin (below: the natural miss). No LeadIn. Without timers: at final-stage entry.
                    if (finalStage && !sc.finalDone && !sc.leadIn) {
                        const float finalSecs = sc.stageSecs.empty() ? 0.0f : sc.stageSecs.back();
                        const bool timed = sc.baseRate > 0.0f && finalSecs > 0.0f;
                        if (!timed || sc.finalElapsed >= kSafetyAt * finalSecs) {
                            sc.finalDone = true;
                            for (const auto id : sc.actors) {
                                auto at = g_actors.find(id);
                                if (at == g_actors.end()) {
                                    continue;
                                }
                                ActorState& st = at->second;
                                const bool edging = now < st.edgeUntil;
                                const bool calmed = st.lastCalmAt >= sc.finalStageAt;
                                const bool sure =
                                    !g_settings.miniGame && st.orgasmExpected && st.role != Role::kVictim;
                                if (st.dom || st.orgasmCount != 0 || AnyBlock(st) || edging || calmed ||
                                    st.enjoyment < (sure ? 0.0f : kSafetyMin)) {
                                    webui_log::info("OrgasmEngine: safety net skips {:#x} enjoyment={:.1f} "
                                                    "count={} dom={} edging={} calmed={}",
                                        id, st.enjoyment, st.orgasmCount, st.dom, edging, calmed);
                                    continue;
                                }
                                Fire(st, group, false, "final_stage", now, fx);
                            }
                        }
                    }

                    // 5. Group: anyone orgasmed -> everyone else close (groupJoin) joins, one dispatch.
                    if (!group.actors.empty()) {
                        JoinGroup(sc, group, now, fx);
                        EmitGroup(std::move(group), fx);
                    }
                }
                for (const auto sid : stale) {
                    webui_log::info("OrgasmEngine: scene {} no longer animating, dropped", sid);
                    DropSceneLocked(sid);
                }
                FlushNarrations(now, false, fx);
            }
            RunEffects(fx);
            Hud::Tick();
        }

        class Interface final : public SKYRIMNET_SEXLAB_API::IOrgasmEngineV1
        {
        public:
            float GetEnjoyment(RE::Actor* a) noexcept override { return OrgasmEngine::GetEnjoyment(a); }
            void SetEnjoyment(RE::Actor* a, float v, const char* s) noexcept override
            {
                OrgasmEngine::SetEnjoyment(a, v, s ? s : "");
            }
            void AddEnjoyment(RE::Actor* a, float d, const char* s) noexcept override
            {
                OrgasmEngine::AddEnjoyment(a, d, s ? s : "");
            }
            bool Arouse(RE::Actor* w, RE::Actor* t, float m) noexcept override { return OrgasmEngine::Arouse(w, t, m); }
            bool Calm(RE::Actor* w, RE::Actor* t, float m) noexcept override { return OrgasmEngine::Calm(w, t, m); }
            void Edge(RE::Actor* a, float sec, const char* s) noexcept override { OrgasmEngine::Edge(a, sec, s ? s : ""); }
            void SetRateModifier(RE::Actor* a, const char* s, float m) noexcept override
            {
                OrgasmEngine::SetRateModifier(a, s ? s : "", m);
            }
            void ClearRateModifier(RE::Actor* a, const char* s) noexcept override
            {
                OrgasmEngine::ClearRateModifier(a, s ? s : "");
            }
            void SetOrgasmBlocked(RE::Actor* a, const char* s, bool b) noexcept override
            {
                OrgasmEngine::SetOrgasmBlocked(a, s ? s : "", b);
            }
            bool IsOrgasmAllowed(RE::Actor* a) noexcept override { return OrgasmEngine::IsOrgasmAllowed(a); }
            void RequestOrgasm(RE::Actor* a, bool f, const char* s) noexcept override
            {
                OrgasmEngine::RequestOrgasm(a, f, s ? s : "");
            }
            std::int32_t GetOrgasmCount(RE::Actor* a) noexcept override { return OrgasmEngine::GetOrgasmCount(a); }
            float GetSecondsSinceOrgasm(RE::Actor* a) noexcept override
            {
                return OrgasmEngine::GetSecondsSinceOrgasm(a);
            }
            bool IsManaged(RE::Actor* a) noexcept override { return OrgasmEngine::IsManaged(a); }
            bool IsMentallyBroken(RE::Actor* a) noexcept override { return OrgasmEngine::IsMentallyBroken(a); }
            void SetRates(float p, float ag, float v) noexcept override { OrgasmEngine::SetRates(p, ag, v); }
            std::uint32_t RegisterEventCallback(SKYRIMNET_SEXLAB_API::EngineEventCallback cb) noexcept override
            {
                return OrgasmEngine::RegisterEventCallback(cb);
            }
            void UnregisterEventCallback(std::uint32_t h) noexcept override { OrgasmEngine::UnregisterEventCallback(h); }
        };

        Interface g_interface;

        // ---- co-save helpers ----
        bool WriteString(SKSE::SerializationInterface* intfc, const std::string& s)
        {
            const auto len = static_cast<std::uint32_t>(s.size());
            return intfc->WriteRecordData(len) && (len == 0 || intfc->WriteRecordData(s.data(), len));
        }

        bool ReadString(SKSE::SerializationInterface* intfc, std::string& s)
        {
            std::uint32_t len = 0;
            if (!intfc->ReadRecordData(len) || len > 4096) {
                return false;
            }
            s.resize(len);
            return len == 0 || intfc->ReadRecordData(s.data(), len) == len;
        }
    }

    void Install()
    {
        static std::once_flag once;
        std::call_once(once, []() {
            g_lastTick = Now();
            std::thread([]() {
                while (true) {
                    std::this_thread::sleep_for(kTickInterval);
                    if (auto* tasks = SKSE::GetTaskInterface()) {
                        tasks->AddTask([]() { Tick(); });
                    }
                }
            }).detach();
            webui_log::info("OrgasmEngine: tick installed ({} ms)", kTickInterval.count());
        });
    }

    void ReloadConfig()
    {
        using SexLabNet::GetConfigBool;
        using SexLabNet::GetConfigFloat;
        Settings s;
        s.miniGame = GetConfigBool("sexlab.minigame.enabled", false);
        s.passiveRate = GetConfigFloat("sexlab.enjoyment.passive_mult", 0.4f);
        s.aggressorRate = GetConfigFloat("sexlab.enjoyment.aggressor_mult", 0.45f);
        s.victimRate = GetConfigFloat("sexlab.enjoyment.victim_mult", 0.3f);
        s.jitterMin = GetConfigFloat("sexlab.enjoyment.jitter_min", 0.95f);
        s.jitterMax = std::max(s.jitterMin, GetConfigFloat("sexlab.enjoyment.jitter_max", 1.1f));
        s.domArousalScale = GetConfigFloat("sexlab.dom.arousal_scale", 0.2f);
        s.domArousalScalePlayer = GetConfigFloat("sexlab.dom.arousal_scale_player", 0.2f);
        s.arouseAmount = static_cast<float>(SexLabNet::GetConfigInt("sexlab.minigame.arouse_amount", 3));
        s.calmAmount = static_cast<float>(SexLabNet::GetConfigInt("sexlab.minigame.calm_amount", 4));
        s.staminaCost = GetConfigFloat("sexlab.minigame.stamina_cost", 8.0f);
        s.magickaCost = GetConfigFloat("sexlab.minigame.magicka_cost", 8.0f);
        s.edgeSeconds = GetConfigFloat("sexlab.minigame.edge_seconds", 4.0f);
        s.mentalBreak = GetConfigBool("sexlab.minigame.mental_break", false);
        s.breakDrain = GetConfigFloat("sexlab.minigame.break_drain", 6.0f);
        s.randomBonus = GetConfigFloat("sexlab.minigame.random_bonus", 10.0f);
        s.narrateWindow = GetConfigFloat("sexlab.minigame.narrate_window", 3.0f);
        s.groupJoin = std::clamp(GetConfigFloat("sexlab.enjoyment.group_join", 95.0f), 0.0f, kMaxEnjoyment);
        {
            std::lock_guard lock(g_lock);
            g_settings = s;
            g_ratesOverridden = false;
        }
        webui_log::info(
            "OrgasmEngine: config minigame={} role mults={}/{}/{} jitter={}-{} dom scale={}/{} arouse={} calm={} "
            "cost={}/{} edge={}s break={} drain={} random={} window={}s group_join={}",
            s.miniGame, s.passiveRate, s.aggressorRate, s.victimRate, s.jitterMin, s.jitterMax, s.domArousalScale,
            s.domArousalScalePlayer, s.arouseAmount, s.calmAmount, s.staminaCost, s.magickaCost, s.edgeSeconds,
            s.mentalBreak, s.breakDrain, s.randomBonus, s.narrateWindow, s.groupJoin);
    }

    bool IsMiniGameEnabled()
    {
        std::lock_guard lock(g_lock);
        return g_settings.miniGame;
    }

    void BeginScene(std::int32_t sid, const std::vector<RE::Actor*>& actors, const std::vector<std::int32_t>& roles,
        const std::vector<float>& seeds, bool hasPlayer)
    {
        std::lock_guard lock(g_lock);
        SceneState& sc = g_scenes[sid];
        const bool resumed = !sc.actors.empty();
        sc.sid = sid;
        sc.hasPlayer = hasPlayer;
        sc.staleSince = 0.0;

        std::vector<RE::FormID> ids;
        for (std::size_t i = 0; i < actors.size(); ++i) {
            RE::Actor* a = actors[i];
            if (!a) {
                continue;
            }
            const RE::FormID id = a->GetFormID();
            ids.push_back(id);
            auto [it, inserted] = g_actors.try_emplace(id);
            ActorState& st = it->second;
            if (!inserted && st.sid != sid) {
                // Moved from another scene: start fresh here.
                st = ActorState{};
                inserted = true;
            }
            st.id = id;
            st.sid = sid;
            st.role = i < roles.size() ? static_cast<Role>(std::clamp(roles[i], 0, 2)) : Role::kNormal;
            st.cooldown = OrgasmCooldown(a);
            if (inserted) {
                st.enjoyment = std::clamp(i < seeds.size() ? seeds[i] : 0.0f, 0.0f, kMaxEnjoyment);
                std::uniform_real_distribution<float> jitter(g_settings.jitterMin, g_settings.jitterMax);
                st.jitter = jitter(g_rng);
                webui_log::info("OrgasmEngine: {:#x} jitter {:.3f}", id, st.jitter);
            }
            if (sc.speedScale != 1.0f) {
                AnimSpeed::SetScale(a, sc.speedScale);
            }
        }
        // Actors that left the scene.
        for (const auto old : sc.actors) {
            if (std::find(ids.begin(), ids.end(), old) == ids.end()) {
                const auto at = g_actors.find(old);
                if (at != g_actors.end() && at->second.sid == sid) {
                    AnimSpeed::SetScale(ActorFor(old), 1.0f);
                    g_actors.erase(at);
                }
            }
        }
        sc.actors = std::move(ids);
        webui_log::info("OrgasmEngine: {} scene {} actors={} player={}", resumed ? "resumed" : "began", sid,
            sc.actors.size(), hasPlayer);
    }

    void SetStage(std::int32_t sid, std::int32_t stage, std::int32_t stageCount)
    {
        std::lock_guard lock(g_lock);
        const auto it = g_scenes.find(sid);
        if (it == g_scenes.end()) {
            return;
        }
        SceneState& sc = it->second;
        const bool changed = sc.stage != stage || sc.stageCount != stageCount;
        sc.stage = stage;
        sc.stageCount = stageCount;
        if (stageCount > 0 && stage < stageCount) {
            sc.finalDone = false;
        }
        if (changed && stageCount > 0 && stage >= stageCount) {
            sc.finalStageAt = Now();
            sc.finalElapsed = 0.0;
        }
    }

    void SetStageTimers(std::int32_t sid, const std::vector<float>& stageSecs, bool leadIn)
    {
        std::lock_guard lock(g_lock);
        const auto it = g_scenes.find(sid);
        if (it == g_scenes.end()) {
            return;
        }
        SceneState& sc = it->second;
        if (sc.stageSecs == stageSecs && sc.leadIn == leadIn) {
            return;
        }
        ApplyStageTimers(sc, stageSecs, leadIn);
        webui_log::info("OrgasmEngine: scene {} stages={} leadIn={} targetSecs={:.1f} baseRate={:.3f}/s{}", sid,
            stageSecs.size(), leadIn, sc.targetSecs, sc.baseRate > 0.0f ? sc.baseRate : kFallbackRate,
            sc.baseRate > 0.0f ? "" : " (fallback)");
    }

    void SetScenePaused(std::int32_t sid, bool paused)
    {
        std::lock_guard lock(g_lock);
        const auto it = g_scenes.find(sid);
        if (it != g_scenes.end() && it->second.paused != paused) {
            it->second.paused = paused;
            webui_log::info("OrgasmEngine: scene {} {}", sid, paused ? "paused" : "resumed");
        }
    }

    bool IsPlayerScenePaused()
    {
        std::lock_guard lock(g_lock);
        const auto* st = Find(RE::PlayerCharacter::GetSingleton());
        const SceneState* sc = st ? SceneOf(*st) : nullptr;
        return sc && sc->paused;
    }

    bool GetPlayerSceneStage(int& stage, int& count)
    {
        std::lock_guard lock(g_lock);
        const auto* st = Find(RE::PlayerCharacter::GetSingleton());
        const SceneState* sc = st ? SceneOf(*st) : nullptr;
        stage = sc ? sc->stage : 0;
        count = sc ? sc->stageCount : 0;
        return sc != nullptr;
    }

    void SetSceneBlocked(RE::Actor* actor, bool blocked)
    {
        std::lock_guard lock(g_lock);
        if (auto* st = Find(actor)) {
            st->sceneBlocked = blocked;
        }
    }

    void SetOrgasmExpected(RE::Actor* actor, bool expected)
    {
        std::lock_guard lock(g_lock);
        if (auto* st = Find(actor); st && st->orgasmExpected != expected) {
            st->orgasmExpected = expected;
            webui_log::info("OrgasmEngine: {:#x} orgasm expected {}", st->id, expected);
        }
    }

    void SetDomSlave(RE::Actor* actor, bool dom)
    {
        std::lock_guard lock(g_lock);
        if (auto* st = Find(actor); st && st->dom != dom) {
            st->dom = dom;
            st->domDelta = 0.0f;
            st->domSyncNow = dom;
            webui_log::info("OrgasmEngine: {:#x} dom slave {}", st->id, dom ? "on (DOM decides)" : "off");
        }
    }

    void SetDomMeter(RE::Actor* actor, float meter)
    {
        std::lock_guard lock(g_lock);
        if (auto* st = Find(actor); st && st->dom) {
            const float value = std::clamp(meter, 0.0f, kMaxEnjoyment);
            if (std::lround(value) != std::lround(st->enjoyment)) {
                webui_log::info("OrgasmEngine: dom meter {:#x} -> {}", st->id, value);
            }
            st->enjoyment = value;
        }
    }

    void SetActorSkills(RE::Actor* actor, std::int32_t skill, std::int32_t lewd)
    {
        std::lock_guard lock(g_lock);
        if (auto* st = Find(actor)) {
            st->skill = std::clamp(skill, 0, 6);
            st->lewd = std::clamp(lewd, -6, 6);
        }
    }

    void EndScene(std::int32_t sid)
    {
        Effects fx;
        {
            std::lock_guard lock(g_lock);
            FlushNarrations(Now(), true, fx);
            DropSceneLocked(sid);
        }
        webui_log::info("OrgasmEngine: ended scene {}", sid);
        PostEffects(std::move(fx));
    }

    bool ConsumeOwnOrgasm(RE::Actor* actor)
    {
        std::lock_guard lock(g_lock);
        auto* st = Find(actor);
        if (!st || st->ownOrgasmsInFlight <= 0) {
            return false;
        }
        st->ownOrgasmsInFlight -= 1;
        return true;
    }

    std::int32_t NoteExternalOrgasm(RE::Actor* actor, const std::string& source)
    {
        Effects fx;
        std::int32_t count = 0;
        {
            std::lock_guard lock(g_lock);
            auto* st = Find(actor);
            if (!st) {
                return 0;
            }
            const double now = Now();
            st->enjoyment = 0.0f;
            st->orgasmCount += 1;
            st->lastOrgasm = now;
            st->flashUntil = now + kFlashSeconds;
            st->pending = false;
            st->pendingForce = false;
            st->deniedSent = false;
            st->lastMirrored = -1000;
            st->lastMirrorAt = now;
            count = st->orgasmCount;
            fx.events.push_back({ SKYRIMNET_SEXLAB_API::EngineEventType::kOrgasm, st->id, 0, source, 0.0f, count });
            webui_log::info("OrgasmEngine: external orgasm {:#x} source={} count={}", st->id, source, count);
            // Every orgasm checks all actors. The caller narrates this actor; the joiners go to the scene's
            // stash + window (individual=false), so both land in one DirectNarration.
            if (const SceneState* sc = SceneOf(*st)) {
                OrgasmGroupFx group;
                group.actors.push_back(st->id);  // marks the trigger as already in the group
                group.forced.push_back(0);
                JoinGroup(*sc, group, now, fx);
                group.actors.erase(group.actors.begin());
                group.forced.erase(group.forced.begin());
                group.individual = false;
                group.source = source;
                EmitGroup(std::move(group), fx);
            }
        }
        PostEffects(std::move(fx));
        return count;
    }

    bool AllowOrgasm(RE::Actor* actor, RE::Actor* allower)
    {
        Effects fx;
        bool fired = false;
        {
            std::lock_guard lock(g_lock);
            auto* st = Find(actor);
            if (!st) {
                return false;
            }
            // Unblock and check in one lock, so the tick cannot fire first without the allow prefix.
            st->sceneBlocked = false;
            const SceneState* sc = SceneOf(*st);
            if (!sc) {
                return false;
            }
            const double now = Now();
            OrgasmGroupFx group;
            for (const auto id : sc->actors) {
                auto at = g_actors.find(id);
                if (at == g_actors.end()) {
                    continue;
                }
                ActorState& other = at->second;
                if (CanOrgasmNow(other, now) && other.enjoyment >= kMaxEnjoyment) {
                    Fire(other, group, true, "allow", now, fx);
                }
            }
            fired = !group.actors.empty();
            if (fired) {
                JoinGroup(*sc, group, now, fx);
                group.allower = allower ? allower->GetFormID() : 0;
                group.allowed = st->id;
                EmitGroup(std::move(group), fx);
            }
            webui_log::info("OrgasmEngine: {:#x} allowed to orgasm by {:#x}, fired={}", st->id,
                allower ? allower->GetFormID() : 0, fired);
        }
        PostEffects(std::move(fx));
        return fired;
    }

    void ResetSpeedScale(RE::Actor* anyActorInScene)
    {
        std::lock_guard lock(g_lock);
        auto* st = Find(anyActorInScene);
        SceneState* sc = st ? SceneOf(*st) : nullptr;
        if (!sc || sc->speedScale == 1.0f) {
            return;
        }
        sc->speedScale = 1.0f;
        for (const auto id : sc->actors) {
            AnimSpeed::SetScale(ActorFor(id), 1.0f);
        }
    }

    float GetEnjoyment(RE::Actor* actor)
    {
        std::lock_guard lock(g_lock);
        const auto* st = Find(actor);
        return st ? st->enjoyment : 0.0f;
    }

    void SetEnjoyment(RE::Actor* actor, float value, const std::string& source)
    {
        std::lock_guard lock(g_lock);
        if (auto* st = Find(actor)) {
            st->enjoyment = std::clamp(value, 0.0f, kMaxEnjoyment);
            webui_log::info("OrgasmEngine: {} set {:#x} enjoyment {}", source, st->id, st->enjoyment);
        }
    }

    void AddEnjoyment(RE::Actor* actor, float delta, const std::string& source)
    {
        std::lock_guard lock(g_lock);
        if (auto* st = Find(actor)) {
            st->enjoyment = std::clamp(st->enjoyment + delta, 0.0f, kMaxEnjoyment);
            webui_log::info("OrgasmEngine: {} added {} to {:#x} -> {}", source, delta, st->id, st->enjoyment);
        }
    }

    bool Arouse(RE::Actor* who, RE::Actor* target, float mult)
    {
        if (!who || !target) {
            return false;
        }
        Effects fx;
        {
            std::lock_guard lock(g_lock);
            auto* tst = Find(target);
            if (!tst) {
                return false;
            }
            const auto* wst = Find(who);
            const float skill = wst ? static_cast<float>(wst->skill) : 0.0f;
            const float cost = ArouseCost(wst);
            if (CurrentAv(who, RE::ActorValue::kStamina) < cost) {
                return false;
            }
            DamageAv(who, RE::ActorValue::kStamina, cost);
            const float before = tst->enjoyment;
            const float amount = g_settings.arouseAmount * std::max(0.0f, mult) * (1.0f + 0.1f * skill);
            if (tst->dom) {
                tst->domDelta += amount;
                tst->domShare += amount / kMaxEnjoyment;
                tst->domSyncNow = true;
            } else {
                tst->enjoyment = std::clamp(before + amount, 0.0f, kMaxEnjoyment);
            }
            if (g_settings.mentalBreak && who != target) {
                const float drain = g_settings.breakDrain * (before / kMaxEnjoyment) * (1.0f + 0.1f * skill) *
                                    (1.0f + static_cast<float>(tst->orgasmCount));
                DamageAv(target, RE::ActorValue::kMagicka, drain);
                UpdateBroken(*tst, target, who->GetFormID(), "minigame", fx);
            }
            NoteNarration(who->GetFormID(), target->GetFormID(), true, Now());
            webui_log::info("OrgasmEngine: arouse {:#x}->{:#x} +{} cost={} -> {}", who->GetFormID(),
                target->GetFormID(), amount, cost, tst->enjoyment);
        }
        PostEffects(std::move(fx));
        return true;
    }

    bool Calm(RE::Actor* who, RE::Actor* target, float mult)
    {
        if (!who || !target) {
            return false;
        }
        Effects fx;
        {
            std::lock_guard lock(g_lock);
            auto* tst = Find(target);
            if (!tst) {
                return false;
            }
            const auto* wst = Find(who);
            if (wst && wst->broken) {
                return false;
            }
            const float cost = CalmCost(wst);
            if (CurrentAv(who, RE::ActorValue::kMagicka) < cost) {
                return false;
            }
            DamageAv(who, RE::ActorValue::kMagicka, cost);
            const double now = Now();
            tst->lastCalmAt = now;
            const float before = tst->enjoyment;
            const float amount = g_settings.calmAmount * std::max(0.0f, mult);
            if (tst->dom) {
                tst->domDelta -= amount;
                tst->domSyncNow = true;
            } else {
                tst->enjoyment = std::max(0.0f, before - amount);
            }
            if (before >= kEdgeThreshold) {
                tst->edgeUntil = now + g_settings.edgeSeconds;
                fx.events.push_back({ SKYRIMNET_SEXLAB_API::EngineEventType::kEdge, tst->id, who->GetFormID(),
                    "minigame", g_settings.edgeSeconds, tst->orgasmCount });
            }
            NoteNarration(who->GetFormID(), target->GetFormID(), false, now);
            webui_log::info("OrgasmEngine: calm {:#x}->{:#x} cost={} {} -> {}{}", who->GetFormID(),
                target->GetFormID(), cost, before, tst->enjoyment, before >= kEdgeThreshold ? " (edge)" : "");
        }
        PostEffects(std::move(fx));
        return true;
    }

    void Edge(RE::Actor* actor, float seconds, const std::string& source)
    {
        Effects fx;
        {
            std::lock_guard lock(g_lock);
            auto* st = Find(actor);
            if (!st) {
                return;
            }
            st->edgeUntil = std::max(st->edgeUntil, Now() + std::max(0.0f, seconds));
            fx.events.push_back({ SKYRIMNET_SEXLAB_API::EngineEventType::kEdge, st->id, 0, source, seconds,
                st->orgasmCount });
        }
        PostEffects(std::move(fx));
    }

    void SetRateModifier(RE::Actor* actor, const std::string& source, float mult)
    {
        std::lock_guard lock(g_lock);
        if (auto* st = Find(actor)) {
            st->rateMods[source] = std::max(0.0f, mult);
        }
    }

    void ClearRateModifier(RE::Actor* actor, const std::string& source)
    {
        std::lock_guard lock(g_lock);
        if (auto* st = Find(actor)) {
            st->rateMods.erase(source);
        }
    }

    void SetOrgasmBlocked(RE::Actor* actor, const std::string& source, bool blocked)
    {
        std::lock_guard lock(g_lock);
        if (auto* st = Find(actor)) {
            if (blocked) {
                st->blocks[source] = true;
            } else {
                st->blocks.erase(source);
            }
        }
    }

    bool IsOrgasmAllowed(RE::Actor* actor)
    {
        std::lock_guard lock(g_lock);
        const auto* st = Find(actor);
        return st && !AnyBlock(*st);
    }

    void RequestOrgasm(RE::Actor* actor, bool force, const std::string& source)
    {
        std::lock_guard lock(g_lock);
        if (auto* st = Find(actor)) {
            st->pending = true;
            st->pendingForce = st->pendingForce || force;
            st->pendingSource = source.empty() ? "request" : source;
            webui_log::info("OrgasmEngine: {} requested orgasm {:#x} force={}", st->pendingSource, st->id, force);
        } else {
            webui_log::warn("OrgasmEngine: RequestOrgasm for unmanaged actor {:#x}",
                actor ? actor->GetFormID() : 0);
        }
    }

    std::int32_t GetOrgasmCount(RE::Actor* actor)
    {
        std::lock_guard lock(g_lock);
        const auto* st = Find(actor);
        return st ? st->orgasmCount : 0;
    }

    float GetSecondsSinceOrgasm(RE::Actor* actor)
    {
        std::lock_guard lock(g_lock);
        const auto* st = Find(actor);
        if (!st || st->lastOrgasm < 0.0) {
            return -1.0f;
        }
        return static_cast<float>(Now() - st->lastOrgasm);
    }

    bool IsManaged(RE::Actor* actor)
    {
        std::lock_guard lock(g_lock);
        return Find(actor) != nullptr;
    }

    bool IsMentallyBroken(RE::Actor* actor)
    {
        std::lock_guard lock(g_lock);
        const auto* st = Find(actor);
        return st && st->broken;
    }

    void SetRates(float passive, float aggressor, float victim)
    {
        std::lock_guard lock(g_lock);
        g_settings.passiveRate = std::max(0.0f, passive);
        g_settings.aggressorRate = std::max(0.0f, aggressor);
        g_settings.victimRate = std::max(0.0f, victim);
        g_ratesOverridden = true;
    }

    std::uint32_t RegisterEventCallback(SKYRIMNET_SEXLAB_API::EngineEventCallback callback)
    {
        if (!callback) {
            return 0;
        }
        std::lock_guard lock(g_lock);
        const auto handle = g_nextCallback++;
        g_callbacks[handle] = callback;
        return handle;
    }

    void UnregisterEventCallback(std::uint32_t handle)
    {
        std::lock_guard lock(g_lock);
        g_callbacks.erase(handle);
    }

    bool CanArouse(RE::Actor* who)
    {
        std::lock_guard lock(g_lock);
        return who && CurrentAv(who, RE::ActorValue::kStamina) >= ArouseCost(Find(who));
    }

    bool CanCalm(RE::Actor* who)
    {
        std::lock_guard lock(g_lock);
        if (!who) {
            return false;
        }
        const auto* st = Find(who);
        if (st && st->broken) {
            return false;
        }
        return CurrentAv(who, RE::ActorValue::kMagicka) >= CalmCost(st);
    }

    bool GetPlayerScene(std::vector<ActorView>& out)
    {
        out.clear();
        auto* player = RE::PlayerCharacter::GetSingleton();
        std::lock_guard lock(g_lock);
        const auto* pst = Find(player);
        if (!pst) {
            return false;
        }
        const auto it = g_scenes.find(pst->sid);
        if (it == g_scenes.end()) {
            return false;
        }
        const double now = Now();
        for (const auto id : it->second.actors) {
            const auto at = g_actors.find(id);
            if (at == g_actors.end()) {
                continue;
            }
            auto* actor = ActorFor(id);
            const auto pct = [actor](RE::ActorValue av) {
                const float max = MaxAv(actor, av);
                return max > 0.0f ? std::clamp(CurrentAv(actor, av) / max * 100.0f, 0.0f, 100.0f) : 0.0f;
            };
            ActorView v;
            v.id = id;
            v.name = NameOf(actor);
            v.enjoyment = at->second.enjoyment;
            v.flashing = now < at->second.flashUntil;
            v.broken = at->second.broken;
            v.dom = at->second.dom;
            v.denied = at->second.sceneBlocked;
            v.magicka = pct(RE::ActorValue::kMagicka);
            v.stamina = pct(RE::ActorValue::kStamina);
            out.push_back(std::move(v));
        }
        return !out.empty();
    }

    int NearestSpeedLevel(float speed)
    {
        int best = 0;
        for (int i = 1; i < kSpeedLevelCount; ++i) {
            if (std::abs(kSpeedLevels[i] - speed) < std::abs(kSpeedLevels[best] - speed)) {
                best = i;
            }
        }
        return best;
    }

    int StepPlayerSceneSpeed(int dir)
    {
        auto* player = RE::PlayerCharacter::GetSingleton();
        std::lock_guard lock(g_lock);
        auto* st = Find(player);
        SceneState* sc = st ? SceneOf(*st) : nullptr;
        if (!sc) {
            return -1;
        }
        // Scale = level speed / style speed, so the effective speed lands exactly on the level.
        const float current = AnimSpeed::Get(player);
        const float base = std::max(0.01f, current / std::max(0.01f, sc->speedScale));
        const int level = NearestSpeedLevel(current);
        const int next = std::clamp(level + (dir > 0 ? 1 : dir < 0 ? -1 : 0), 0, kSpeedLevelCount - 1);
        const float target = std::clamp(kSpeedLevels[next], AnimSpeed::kMin, AnimSpeed::kMax);
        sc->speedScale = target / base;
        for (const auto id : sc->actors) {
            AnimSpeed::SetScale(ActorFor(id), sc->speedScale);
        }
        webui_log::info("OrgasmEngine: scene {} speed level {} ({}) scale {}", sc->sid, next,
            kSpeedLevelNames[next], sc->speedScale);
        return next;
    }

    int GetPlayerSceneSpeedLevel()
    {
        auto* player = RE::PlayerCharacter::GetSingleton();
        {
            std::lock_guard lock(g_lock);
            auto* st = Find(player);
            if (!st || !SceneOf(*st)) {
                return -1;
            }
        }
        return NearestSpeedLevel(AnimSpeed::Get(player));
    }

    void Narrate(const std::string& eventType, const std::string& msg, RE::Actor* source, RE::Actor* target)
    {
        if (msg.empty()) {
            return;
        }
        DispatchShell("Effect_Narrate",
            RE::MakeFunctionArguments(RE::BSFixedString(eventType.c_str()), RE::BSFixedString(msg.c_str()),
                std::move(source), std::move(target)));
    }

    void Save(SKSE::SerializationInterface* intfc)
    {
        std::lock_guard lock(g_lock);
        if (!intfc->OpenRecord(kRecord, kRecordVersion)) {
            webui_log::error("OrgasmEngine: co-save open failed");
            return;
        }
        const double now = Now();
        intfc->WriteRecordData(static_cast<std::uint32_t>(g_scenes.size()));
        for (const auto& [sid, sc] : g_scenes) {
            intfc->WriteRecordData(sid);
            intfc->WriteRecordData(sc.hasPlayer);
            intfc->WriteRecordData(sc.stage);
            intfc->WriteRecordData(sc.stageCount);
            intfc->WriteRecordData(sc.finalDone);
            // v3: stage timers, pause, final-stage clock.
            intfc->WriteRecordData(static_cast<std::uint32_t>(sc.stageSecs.size()));
            for (const float secs : sc.stageSecs) {
                intfc->WriteRecordData(secs);
            }
            intfc->WriteRecordData(sc.leadIn);
            intfc->WriteRecordData(sc.paused);
            intfc->WriteRecordData(sc.finalElapsed);
            intfc->WriteRecordData(static_cast<std::uint32_t>(sc.actors.size()));
            for (const auto id : sc.actors) {
                const auto at = g_actors.find(id);
                const ActorState st = at != g_actors.end() ? at->second : ActorState{};
                intfc->WriteRecordData(id);
                intfc->WriteRecordData(st.enjoyment);
                intfc->WriteRecordData(st.orgasmCount);
                intfc->WriteRecordData(static_cast<std::int32_t>(st.role));
                intfc->WriteRecordData(st.skill);
                intfc->WriteRecordData(st.lewd);
                intfc->WriteRecordData(st.broken);
                intfc->WriteRecordData(st.sceneBlocked);
                intfc->WriteRecordData(st.dom);
                intfc->WriteRecordData(st.jitter);
                intfc->WriteRecordData(st.domProgress);
                intfc->WriteRecordData(st.domStepAcc);
                intfc->WriteRecordData(st.domPrepaid);
                const float since = st.lastOrgasm < 0.0 ? -1.0f : static_cast<float>(now - st.lastOrgasm);
                intfc->WriteRecordData(since);
                intfc->WriteRecordData(static_cast<std::uint32_t>(st.blocks.size()));
                for (const auto& [src, on] : st.blocks) {
                    WriteString(intfc, src);
                    intfc->WriteRecordData(on);
                }
                intfc->WriteRecordData(static_cast<std::uint32_t>(st.rateMods.size()));
                for (const auto& [src, m] : st.rateMods) {
                    WriteString(intfc, src);
                    intfc->WriteRecordData(m);
                }
            }
        }
    }

    void Load(SKSE::SerializationInterface* intfc, std::uint32_t version, std::uint32_t)
    {
        if (version < 1 || version > kRecordVersion) {
            webui_log::warn("OrgasmEngine: co-save version {} unsupported, skipped", version);
            return;
        }
        std::lock_guard lock(g_lock);
        g_scenes.clear();
        g_actors.clear();
        g_narrateDue.clear();
        const double now = Now();
        std::uint32_t sceneCount = 0;
        if (!intfc->ReadRecordData(sceneCount)) {
            return;
        }
        for (std::uint32_t s = 0; s < sceneCount; ++s) {
            SceneState sc;
            std::uint32_t actorCount = 0;
            if (!intfc->ReadRecordData(sc.sid) || !intfc->ReadRecordData(sc.hasPlayer) ||
                !intfc->ReadRecordData(sc.stage) || !intfc->ReadRecordData(sc.stageCount) ||
                !intfc->ReadRecordData(sc.finalDone)) {
                webui_log::error("OrgasmEngine: co-save truncated");
                return;
            }
            if (version >= 3) {
                std::uint32_t stageCount = 0;
                if (!intfc->ReadRecordData(stageCount) || stageCount > 256) {
                    webui_log::error("OrgasmEngine: co-save truncated");
                    return;
                }
                std::vector<float> secs(stageCount, 0.0f);
                for (auto& v : secs) {
                    if (!intfc->ReadRecordData(v)) {
                        return;
                    }
                }
                bool leadIn = false;
                if (!intfc->ReadRecordData(leadIn) || !intfc->ReadRecordData(sc.paused) ||
                    !intfc->ReadRecordData(sc.finalElapsed)) {
                    webui_log::error("OrgasmEngine: co-save truncated");
                    return;
                }
                ApplyStageTimers(sc, secs, leadIn);
            }
            if (!intfc->ReadRecordData(actorCount)) {
                webui_log::error("OrgasmEngine: co-save truncated");
                return;
            }
            for (std::uint32_t a = 0; a < actorCount; ++a) {
                ActorState st;
                RE::FormID oldId = 0;
                std::int32_t role = 0;
                float since = -1.0f;
                std::uint32_t n = 0;
                if (!intfc->ReadRecordData(oldId) || !intfc->ReadRecordData(st.enjoyment) ||
                    !intfc->ReadRecordData(st.orgasmCount) || !intfc->ReadRecordData(role) ||
                    !intfc->ReadRecordData(st.skill) || !intfc->ReadRecordData(st.lewd) ||
                    !intfc->ReadRecordData(st.broken) || !intfc->ReadRecordData(st.sceneBlocked) ||
                    (version >= 2 && !intfc->ReadRecordData(st.dom)) ||
                    (version >= 3 &&
                        (!intfc->ReadRecordData(st.jitter) || !intfc->ReadRecordData(st.domProgress) ||
                            !intfc->ReadRecordData(st.domStepAcc) || !intfc->ReadRecordData(st.domPrepaid))) ||
                    !intfc->ReadRecordData(since) || !intfc->ReadRecordData(n)) {
                    webui_log::error("OrgasmEngine: co-save truncated");
                    return;
                }
                for (std::uint32_t b = 0; b < n; ++b) {
                    std::string src;
                    bool on = false;
                    if (!ReadString(intfc, src) || !intfc->ReadRecordData(on)) {
                        return;
                    }
                    st.blocks[src] = on;
                }
                if (!intfc->ReadRecordData(n)) {
                    return;
                }
                for (std::uint32_t m = 0; m < n; ++m) {
                    std::string src;
                    float mult = 1.0f;
                    if (!ReadString(intfc, src) || !intfc->ReadRecordData(mult)) {
                        return;
                    }
                    st.rateMods[src] = mult;
                }
                RE::FormID id = 0;
                if (!intfc->ResolveFormID(oldId, id)) {
                    continue;
                }
                st.id = id;
                st.sid = sc.sid;
                st.role = static_cast<Role>(std::clamp(role, 0, 2));
                st.lastOrgasm = since < 0.0f ? -1.0 : now - since;
                st.cooldown = OrgasmCooldown(ActorFor(id));
                sc.actors.push_back(id);
                g_actors[id] = std::move(st);
            }
            if (!sc.actors.empty()) {
                g_scenes[sc.sid] = std::move(sc);
            }
        }
        webui_log::info("OrgasmEngine: co-save loaded {} scene(s), {} actor(s)", g_scenes.size(), g_actors.size());
    }

    void Revert()
    {
        std::lock_guard lock(g_lock);
        g_scenes.clear();
        g_actors.clear();
        g_narrateDue.clear();
    }

    SKYRIMNET_SEXLAB_API::IOrgasmEngineV1* GetInterface()
    {
        return &g_interface;
    }
}

extern "C" __declspec(dllexport) void* RequestOrgasmEngineAPI(SKYRIMNET_SEXLAB_API::InterfaceVersion a_version)
{
    if (a_version == SKYRIMNET_SEXLAB_API::InterfaceVersion::V1) {
        return OrgasmEngine::GetInterface();
    }
    return nullptr;
}
