#include "OrgasmEngine.h"

#include "Aid.h"
#include "AnimSpeed.h"
#include "Config.h"
#include "Hud.h"
#include "NarrationQueue.h"
#include "NarrationTiming.h"
#include "StrategyDecision.h"
#include "WebUI_Log.h"
#include "Whipped.h"

#include <algorithm>
#include <array>
#include <atomic>
#include <cctype>
#include <chrono>
#include <cmath>
#include <fstream>
#include <map>
#include <mutex>
#include <nlohmann/json.hpp>
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
        constexpr double kDomSyncInterval = 1.0;
        constexpr double kDomRefresh = 2.0;
        constexpr float kDomMeterPossible = 50.0f;  // DOM meter >= this: DOM's values could produce an orgasm
        constexpr float kFallbackRate = 0.5f;       // per second, when the scene sent no stage timers
        constexpr float kFinalShare = 0.9f;         // target: stages 1..N-1 + this x the final stage
        constexpr float kLeadInStretch = 1.5f;      // LeadIn target: all stages x this (never reaches 100)
        constexpr float kSafetyAt = 0.9f;           // safety net: this share of the final stage's timer
        constexpr float kSafetyMin = 90.0f;         // safety net: enjoyment needed to fire
        constexpr float kRushHover = 98.0f;         // gate pass: bar cap until the final stage starts
        constexpr double kGateDispatchMargin = 2.0;  // gate fires this much earlier: tick -> Papyrus -> stage hold
        constexpr float kRushFireAt = 97.0f;        // gate pass: orgasm (ForceOrgasm) at this in the final stage
        constexpr double kRushFinish = 1.0;         // gate pass: seconds to finish the climb in the final stage
        constexpr float kDomStep = 10.0f;           // DOM slave: progress points per arousal push
        constexpr float kDomStepShare = 0.1f;       // DOM slave: step roll share of one full DOM roll
        constexpr float kRegenFloor = -10.0f;       // Sex is hard work: regen floor; a non-victim here ends the scene
        constexpr double kUntimedGrace = 10.0;      // NPC steps start this long after BeginScene without timers

        struct Settings
        {
            bool miniGame = false;
            // sexlab.enjoyment.engine_disabled: SexLab owns enjoyment and orgasms; the engine reads SexLab's
            // value (Effect_Mirror pull), records SexLab's orgasms and fires only forced requests.
            bool engineOff = false;
            // Role multipliers on the scene's timed base rate.
            float passiveRate = 0.4f;
            float aggressorRate = 0.45f;
            float victimRate = 0.3f;
            float jitterMin = 0.95f;
            float jitterMax = 1.1f;
            float domArousalScale = 0.2f;        // DOM amount per progress point (MOD_Daring)
            float domArousalScalePlayer = 0.2f;  // player scenes: extra per point (MOD_Naivety)
            float arouseAmount = 2.4f;
            float calmAmount = 3.2f;
            float staminaCost = 8.0f;
            float magickaCost = 8.0f;
            float edgeSeconds = 4.0f;
            float randomBonus = 10.0f;
            float narrateWindow = 3.0f;
            float groupJoin = 85.0f;       // someone orgasmed: others at this enjoyment or more join outright
            float groupJoinFinal = 90.0f;  // gate pass: others at this enjoyment or more rush with the passers
            float stageSpike = 5.0f;  // enjoyment added on each stage advance
            bool gate = true;         // orgasm roll just before the final stage
            float gateLeadDefault = 5.0f;  // DN -> speech seconds until NarrationTiming has samples
            // SexLab bonus (skill, Lewd/Pure, victim/aggressor, relationship rank): see ComputeBonus.
            float bonusScale = 0.5f;
            float bonusClamp = 0.75f;
            float togetherK = 2.0f;          // Together: curve exponent k = 1 + togetherK x bonus
            float miniGameBonusMult = 1.0f;  // Mini-game: passive gain x (1 + this x bonus)
            float npcInterval = 2.0f;        // Mini-game: seconds between an NPC's strategy steps
            float npcStepMin = 4.0f;         // Mini-game: enjoyment per NPC step, random in [min, max]
            float npcStepMax = 8.0f;         // (timed scenes: only the spread around the calibrated step)
            float mutualTarget = 87.0f;      // Mini-game: all on Mutual reach this at the end of stage N-1
            float passiveShare = 0.3f;       // Mini-game: share of that budget from passive gain (rest: steps)
            Strategy defaultNormal = Strategy::kMutual;
            Strategy defaultAggressor = Strategy::kSelfish;
            Strategy defaultVictim = Strategy::kPassive;
            bool decisionStrategy = true;  // the decision model picks NPC strategies (StrategyDecision)
            float decisionMinConfidence = 0.6f;  // a strategy change needs at least this answer confidence
            // Sex is hard work: stamina regen (share of the actor's default) decays while animating.
            // Disabled for now: the sexlab.stamina.* settings were removed (0.35.2); code kept for later.
            bool staminaFatigue = false;
            float regenAtTarget = 45.0f;    // timed scenes: regen left at the scene's orgasm point (targetSecs)
            float regenDecay = 40.0f;       // untimed scenes: regen points lost per minute of animation
            float regenOrgasmCost = 10.0f;  // regen points lost per orgasm
        };

        // A reason the actor can be punished for this scene: a request it refused (type "refused_strategy"), or one
        // another mod supplied (type "external", e.g. SkyrimNet_DOM). Not saved.
        struct PunishRecord
        {
            RE::FormID by = 0;        // order_actor: who asked / ordered
            RE::FormID target = 0;    // target_actor: who refused (the list's owner)
            std::string reason;       // reason_narration: after "because" ("Nina refused Bob's order to ...")
            std::string strategyKey;  // the refused request's key ("focused_p1"); "" for a custom / external reason
            std::string request;      // the request's order text ("be passive and let things happen")
            std::string type = "refused_strategy";
        };
        constexpr std::size_t kPunishKept = 8;

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
            // Failed the early final roll (lead reached the target in the second-to-last stage): no more
            // orgasms this pass through the last two stages, except a forced request. Not saved.
            bool finalRollFailed = false;
            // Gate pass: narration already sent; the bar climbs at rushRate and the orgasm fires (no DN)
            // at kRushFireAt in the final stage. Not saved.
            bool rushing = false;
            float rushRate = 0.0f;
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
            // SexLab's starting-enjoyment terms as one factor, about -bonusClamp..+bonusClamp (ComputeBonus).
            float bonus = 0.0f;
            // Together: scene progress (0..1) already credited by the curve.
            float curveP = 0.0f;
            // Mini-game NPC strategy.
            Strategy strategy = Strategy::kPassive;
            RE::FormID strategyTarget = 0;
            double nextStepAt = 0.0;
            float regen = 100.0f;  // stamina regen, percent of the actor's default (staminaFatigue)
            // HUD take-control key. autoPlay (player): the engine plays the player's strategy like an NPC's.
            // playerDriven (NPC): the player drives this NPC with the HUD; its strategy stops. Not saved.
            bool autoPlay = false;
            bool playerDriven = false;
            std::vector<PunishRecord> reasons;  // punishment reasons held (last kPunishKept), oldest first
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
            double finalStageAt = 0.0;  // Now() (unpaused clock) on entering the final stage
            double finalElapsed = 0.0;  // animating, unpaused seconds in the final stage
            bool staged = false;        // SetStage seen once (no spike for the first stage)
            bool gateDone = false;      // gate rolled for this pass through the last two stages
            double penultElapsed = 0.0;  // animating, unpaused seconds in the second-to-last stage
            // Scene ending lead and orgasm target (SetEndingTarget; 0 = off). Not saved: the Scene re-sends
            // it on every BeginScene.
            RE::FormID endingLead = 0;
            std::int32_t endingTarget = 0;
            // Gate passed in the second-to-last stage (held by the Scene): one of this scene's actors
            // starting to speak after the gate narration (NarrationTiming::StartedSince(gateSpeechMark,
            // actors)) pushes the scene to its final stage. Scoped to the scene's actors: another scene's
            // reply must not advance this one (2026-10-08).
            bool gateAwait = false;
            bool gateMarked = false;  // GateNarrationSent seen
            std::uint64_t gateSpeechMark = 0;
            // Together: animating, unpaused seconds in the current stage (progress clock).
            double stageElapsed = 0.0;
            bool exhaustedSent = false;  // a non-victim gave out (regen at kRegenFloor): scene end sent
            float regenRate = 0.0f;      // regen points lost per second (ApplyStageTimers); 0: regenDecay. Not saved.
            double beganAt = 0.0;        // Now() at the first BeginScene (untimed NPC step grace). Not saved.
            // Strategy decisions (StrategyDecision): generation changes with the roster, so a late answer for
            // an older roster (or a reused sid) is dropped. decisionsStarted: scene-start decisions sent.
            std::uint64_t generation = 0;
            bool decisionsStarted = false;
            bool anyExpected = true;     // last tick: some actor expects orgasm (else Non-sexual defaults)
            // Mini-game rates (CalibrateMiniGame), per actor per second. Set once from the first main
            // animation's timers and never changed; a LeadIn sets them provisionally (calibrated false).
            bool ratesKnown = false;  // SetStageTimers seen (timed or not): NPC steps may start
            bool mgRates = false;     // mgPassiveRate / mgStepRate valid (else fallback rate, fixed steps)
            bool calibrated = false;
            float mgPassiveRate = 0.0f;
            float mgStepRate = 0.0f;
        };

        // Work collected under the lock, run after it is released (Papyrus dispatch / events / HUD).
        // One orgasm moment in a scene: everyone who fired together, narrated as one message.
        struct OrgasmGroupFx
        {
            std::vector<RE::FormID> actors;
            std::vector<std::int32_t> forced;  // per actor: 1 = forced by the player (WebUI)
            bool individual = false;           // false: only safety-net / external joins (stash + window)
            std::string source;
            RE::FormID allower = 0;  // AllowOrgasm: "<allower> allowed <allowed> to orgasm."
            RE::FormID allowed = 0;
            std::string extras;  // unused (arouse / calm now short-lived events); kept for the Papyrus signature
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
        // Gate passed: the Scene narrates these actors now (one DN) and holds the stage until the voice.
        struct GatePassFx
        {
            std::vector<RE::FormID> actors;
            bool holdStage;  // still in the second-to-last stage
        };
        // Strategy change: narrate: optional narration of msg; else (decision-made)
        // a short-term event with observed, how the change looks to others.
        struct StrategyFx
        {
            RE::FormID actor;
            RE::FormID target;
            std::string msg;
            std::string observed;
            bool narrate;
        };
        struct Effects
        {
            std::vector<OrgasmGroupFx> orgasms;
            std::vector<MirrorFx> mirrors;
            std::vector<NarrateFx> narrations;
            std::vector<EventFx> events;
            std::vector<DomSyncFx> domSyncs;
            std::vector<GatePassFx> gatePasses;
            std::vector<RE::FormID> advances;  // voice started after a gate pass: push the scene to its final stage
            std::vector<StrategyFx> strategies;
            std::vector<std::vector<RE::FormID>> exhausted;  // per scene: non-victims too tired to continue
            std::vector<std::pair<RE::FormID, std::string>> directs;  // DirectNarration: fatigue stages
            std::vector<std::int32_t> decisionScenes;  // scenes ready for NPC steps: scene-start decisions
            bool empty() const
            {
                return orgasms.empty() && mirrors.empty() && narrations.empty() && events.empty() &&
                       domSyncs.empty() && gatePasses.empty() && advances.empty() && strategies.empty() &&
                       exhausted.empty() && directs.empty() && decisionScenes.empty();
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
        // Auto play stays on for the player's later scenes until the take-control key turns it off (co-save v8).
        bool g_autoPlaySticky = false;

        // Wall clock: only the source of Tick's delta.
        double GameNow()
        {
            using namespace std::chrono;
            static const auto start = steady_clock::now();
            return duration<double>(steady_clock::now() - start).count();
        }

        // Engine clock: unpaused seconds, advanced only by Tick. Frozen while the game or the WebUI is paused,
        // so gain, cooldowns, edging and narration windows all run on unpaused game time. Starts high so
        // timestamps rebuilt from saved "seconds since" stay positive (negative = never).
        std::atomic<double> g_gameClock{ 100000.0 };

        double Now()
        {
            return g_gameClock.load();
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

        bool IsPlayerFormId(RE::FormID id)
        {
            if (id == 0x14)
                return true;
            const auto* player = RE::PlayerCharacter::GetSingleton();
            return player && player->GetFormID() == id;
        }

        bool IsFemale(RE::Actor* actor)
        {
            const auto* base = actor ? actor->GetActorBase() : nullptr;
            return base && base->GetSex() == RE::SEX::kFemale;
        }

        std::string Reflexive(RE::Actor* actor)
        {
            return IsFemale(actor) ? "herself" : "himself";
        }

        std::string Possessive(RE::Actor* actor)
        {
            return IsFemale(actor) ? "her" : "his";
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

        // The engine plays this actor's mini-game strategy: NPCs unless the player took control of them, the
        // player only in auto play.
        bool AiDriven(const ActorState& st)
        {
            return IsPlayerFormId(st.id) ? st.autoPlay : !st.playerDriven;
        }

        // Caller holds g_lock. Mini-game scene the engine plays alone: every non-DOM actor is AiDriven (no
        // one under the player's hand). Such a scene keeps the ending gate: its last orgasm lands at the end
        // of the second-to-last stage.
        bool SceneAiDriven(const SceneState& sc)
        {
            bool any = false;
            for (const auto id : sc.actors) {
                const auto at = g_actors.find(id);
                if (at == g_actors.end() || at->second.dom) {
                    continue;
                }
                if (!AiDriven(at->second)) {
                    return false;
                }
                any = true;
            }
            return any;
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
            // Sex is hard work: regen reaches regenAtTarget at the orgasm point; the orgasm cost makes it tired.
            sc.regenRate = target > 0.0f ? (100.0f - g_settings.regenAtTarget) / target : 0.0f;
        }

        // Caller holds g_lock. Mini-game rates from the timers: with every NPC on Mutual, each actor reaches
        // mutualTarget at the end of the second-to-last stage, counting the stage spikes on the way (stages
        // 2..N-1). Fixed per scene: the first main animation sets them, later ones keep them, so extra time
        // (pause, a stage back, long narration) adds enjoyment. LeadIn: provisional, all stages x
        // kLeadInStretch and no spikes, until a main animation calibrates. No timers: no rates.
        void CalibrateMiniGame(SceneState& sc)
        {
            if (sc.calibrated || sc.stageSecs.empty()) {
                return;
            }
            const std::size_t n = sc.stageSecs.size();
            const std::size_t upto = sc.leadIn ? n : std::max<std::size_t>(1, n - 1);
            float secs = 0.0f;
            for (std::size_t i = 0; i < upto; ++i) {
                secs += std::max(0.0f, sc.stageSecs[i]);
            }
            if (sc.leadIn) {
                secs *= kLeadInStretch;
            }
            if (secs <= 0.0f) {
                return;
            }
            const float target = g_settings.mutualTarget;
            const float spikes = sc.leadIn || n <= 2 ? 0.0f : static_cast<float>(n - 2) * g_settings.stageSpike;
            const float budget = std::clamp(target - spikes, 0.25f * target, target);
            const float rate = budget / secs;
            sc.mgPassiveRate = g_settings.passiveShare * rate;
            sc.mgStepRate = (1.0f - g_settings.passiveShare) * rate;
            sc.mgRates = true;
            sc.calibrated = !sc.leadIn;
            webui_log::info("OrgasmEngine: scene {} mini-game {} T={:.1f}s spikes={:.0f} budget={:.1f} "
                            "passive={:.3f}/s steps={:.3f}/s",
                sc.sid, sc.calibrated ? "calibration" : "provisional (LeadIn)", secs, spikes, budget,
                sc.mgPassiveRate, sc.mgStepRate);
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

        // Fatigue stage by regen: >90 fresh, 90-40 breathing hard, 40-0 tired, 0 or less (to kRegenFloor) exhausted.
        std::int32_t FatigueStage(float regen)
        {
            return regen > 90.0f ? 0 : regen > 40.0f ? 1 : regen > 0.0f ? 2 : 3;
        }

        // Caller holds g_lock. Regen only falls during a scene, so each stage crossing is narrated once.
        void SpendRegen(ActorState& st, float points, Effects& fx)
        {
            if (!g_settings.staminaFatigue) {
                return;
            }
            const std::int32_t before = FatigueStage(st.regen);
            st.regen = std::max(kRegenFloor, st.regen - points);
            const std::int32_t after = FatigueStage(st.regen);
            if (after > before) {
                static constexpr const char* kStageText[] = { "", "is breathing hard", "is tired", "is exhausted" };
                if (const std::string name = NameOf(ActorFor(st.id)); !name.empty()) {
                    fx.directs.push_back({ st.id, name + " " + kStageText[after] + "." });
                }
                webui_log::info("OrgasmEngine: {:#x} fatigue stage {} regen={:.1f}", st.id, after, st.regen);
            }
        }

        // Caller holds g_lock. Sex is hard work: decay regen (the scene's calibrated rate, else regenDecay) and
        // take back the decayed share of the actor's default regen (base StaminaRate x base StaminaRateMult;
        // potions and buffs still add on top). Below 0 regen drains stamina, even from full.
        void ApplyFatigue(const SceneState& sc, ActorState& st, RE::Actor* actor, double dt, Effects& fx)
        {
            if (!g_settings.staminaFatigue || !actor || dt <= 0.0) {
                return;
            }
            const float perSecDecay = sc.regenRate > 0.0f ? sc.regenRate : g_settings.regenDecay / 60.0f;
            SpendRegen(st, perSecDecay * static_cast<float>(dt), fx);
            auto* owner = actor->AsActorValueOwner();
            if (!owner || actor->IsInCombat()) {
                return;
            }
            const float max = MaxAv(actor, RE::ActorValue::kStamina);
            // At full stamina the game regenerates nothing: only the negative share drains.
            const float share = CurrentAv(actor, RE::ActorValue::kStamina) >= max ? std::max(0.0f, -st.regen / 100.0f)
                                                                                   : 1.0f - st.regen / 100.0f;
            if (share <= 0.0f) {
                return;
            }
            const float perSec = max * owner->GetBaseActorValue(RE::ActorValue::kStaminaRate) / 100.0f *
                                 owner->GetBaseActorValue(RE::ActorValue::kStaminaRateMult) / 100.0f;
            DamageAv(actor, RE::ActorValue::kStamina, perSec * share * static_cast<float>(dt));
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
            SpendRegen(st, g_settings.regenOrgasmCost, fx);
            st.lastOrgasm = now;
            st.flashUntil = now + kFlashSeconds;
            st.pending = false;
            st.pendingForce = false;
            st.deniedSent = false;
            st.rushing = false;
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

        // Caller holds g_lock. Not DOM, no block, not edging, not cooling down, not out after the final roll.
        bool CanOrgasmNow(const ActorState& st, double now)
        {
            return !st.dom && !AnyBlock(st) && !st.finalRollFailed && now >= st.edgeUntil && !IsCooling(st, now);
        }

        // Caller holds g_lock. The normal orgasm test: enjoyment (+ the mini-game random bonus, rolled once per
        // kRollInterval, or now with rollNow) reaches 100, or a pending request. Gates are CanOrgasmNow's.
        bool WantsOrgasm(ActorState& st, double now, bool rollNow)
        {
            float test = st.enjoyment;
            if (g_settings.miniGame && (rollNow || now - st.lastRollAt >= kRollInterval)) {
                st.lastRollAt = now;
                std::uniform_real_distribution<float> roll(0.0f, std::max(0.0f, g_settings.randomBonus));
                test += roll(g_rng);
            }
            return test >= kMaxEnjoyment || st.pending;
        }

        // Caller holds g_lock. Threshold roll (group, gate, final): enjoyment + random(0, random_bonus) + bonus
        // reaches 100. `rolled` is the random part, for the log.
        bool RollOrgasm(const ActorState& st, float bonus, float& rolled)
        {
            std::uniform_real_distribution<float> roll(0.0f, std::max(0.0f, g_settings.randomBonus));
            rolled = roll(g_rng);
            return st.enjoyment + rolled + bonus >= kMaxEnjoyment;
        }

        // Caller holds g_lock. Passive gain per second (before speed and pause): fixed rate from the stage
        // timers. Mini-game (not DOM): the scene's calibrated share, roles relative to the normal multiplier.
        // Not expected to orgasm: mini-game only.
        float PassiveRate(const SceneState& sc, const ActorState& st)
        {
            if (!st.orgasmExpected) {
                return 0.0f;
            }
            float rate = 0.0f;
            if (g_settings.miniGame && !st.dom && sc.mgRates) {
                const float normal = g_settings.passiveRate > 0.0f ? g_settings.passiveRate : 0.4f;
                rate = sc.mgPassiveRate * RoleMult(st.role) / normal;
            } else {
                rate = (sc.baseRate > 0.0f ? sc.baseRate : kFallbackRate) * RoleMult(st.role);
            }
            rate *= st.jitter;
            for (const auto& [src, m] : st.rateMods) {
                rate *= m;
            }
            // Mini-game: the SexLab bonus is a constant rate factor.
            if (g_settings.miniGame) {
                rate *= std::max(0.0f, 1.0f + g_settings.miniGameBonusMult * st.bonus);
            }
            return rate;
        }

        void NoteNarration(RE::FormID who, RE::FormID target, bool arouse, double now);

        // ---- SexLab bonus ----
        // sslActorAlias StartAnimating (SexLab 1.6x): BaseEnjoyment += S x RandomInt(1, 10), with S from the
        // relationship rank and Lewd/Pure, by victim / aggressor / normal branch; unskilled actors (creatures)
        // use the rank only. The random factor is replaced by its mean (5.5); 50 points = 1.0. The act skill
        // of the partner (SexLab bases skills on the partner, or the player when present) drives
        // CalcEnjoyment's growth there: (level - 2) / 6 here. Indices: GetSkillLevels (4 Pure, 5 Lewd).
        float ComputeBonus(const std::vector<float>& own, const std::vector<float>& partner, std::int32_t low,
            std::int32_t high, std::int32_t actSkill, Role role)
        {
            constexpr std::size_t kPure = 4;
            constexpr std::size_t kLewd = 5;
            const bool skilled = own.size() > kLewd && partner.size() > kLewd;
            float s = 0.0f;
            if (skilled) {
                const float ownLp = own[kLewd] - own[kPure];
                const float partnerLp = partner[kLewd] - partner[kPure];
                switch (role) {
                case Role::kVictim:
                    s = static_cast<float>(low - 3) + std::clamp(ownLp, -6.0f, 6.0f);
                    break;
                case Role::kAggressor:
                    s = -(static_cast<float>(high - 4) + std::clamp(partnerLp - ownLp, -6.0f, 6.0f));
                    break;
                default:
                    s = static_cast<float>(high) + std::clamp((partner[kLewd] + own[kLewd]) * 0.5f -
                                                                  (partner[kPure] + own[kPure]) * 0.5f,
                                                       0.0f, 6.0f);
                    break;
                }
            } else {
                switch (role) {
                case Role::kVictim:
                    s = static_cast<float>(low - 3);
                    break;
                case Role::kAggressor:
                    s = -static_cast<float>(high - 4);
                    break;
                default:
                    s = static_cast<float>(high + 3);
                    break;
                }
            }
            const float relation = std::clamp(s * 5.5f / 50.0f, -1.0f, 1.0f);
            float skill = 0.0f;
            if (skilled && actSkill >= 0 && static_cast<std::size_t>(actSkill) < partner.size()) {
                skill = (partner[static_cast<std::size_t>(actSkill)] - 2.0f) / 6.0f;
            }
            const float clampTo = std::max(0.0f, g_settings.bonusClamp);
            return std::clamp(g_settings.bonusScale * (relation + skill), -clampTo, clampTo);
        }

        // ---- Together: enjoyment follows a curve that reaches 100 at the end of the second-to-last stage ----
        // p: completed stages + this stage's share of its timer, over stages 1..N-1. A stage that runs long
        // waits at its boundary. Untimed: by stage index.
        float SceneProgress(const SceneState& sc)
        {
            const std::int32_t denom = std::max(1, sc.stageCount - 1);
            const std::int32_t stage = std::max(1, sc.stage);
            const std::int32_t completed = std::min(stage - 1, denom);
            float frac = 0.0f;
            if (stage <= denom && static_cast<std::size_t>(stage - 1) < sc.stageSecs.size()) {
                const float secs = sc.stageSecs[static_cast<std::size_t>(stage - 1)];
                frac = secs > 0.0f ? std::clamp(static_cast<float>(sc.stageElapsed / secs), 0.0f, 1.0f) : 0.0f;
            }
            return std::clamp((static_cast<float>(completed) + frac) / static_cast<float>(denom), 0.0f, 1.0f);
        }

        // Caller holds g_lock. E(p) = 1 - (1 - p)^k, k = 1 + togetherK x bonus: a positive bonus rises fast and
        // flattens, a negative one starts slow. Each step closes the matching share of the gap to the target,
        // so carried-over or external enjoyment still lands on the target at p = 1. Before the final stage the
        // curve stops at kRushHover, so nobody fires before the gate.
        void ApplyTogetherCurve(const SceneState& sc, ActorState& st, bool finalStage)
        {
            const float p = SceneProgress(sc);
            const float target = sc.leadIn ? kMaxEnjoyment / kLeadInStretch : kMaxEnjoyment;
            // Final stage, curve done and held at kRushHover (no gate rush): finish now. Not after an orgasm
            // (enjoyment back at 0), so the curve never makes a repeat orgasm.
            if (finalStage && p >= 1.0f && st.enjoyment >= kRushHover - 0.01f && st.enjoyment < target) {
                st.enjoyment = target;
                st.curveP = p;
                return;
            }
            if (p <= st.curveP) {
                st.curveP = p;  // stage back or a new animation: rebase
                return;
            }
            const float k = std::clamp(1.0f + g_settings.togetherK * st.bonus, 0.5f, 2.5f);
            const auto curve = [k](float x) { return 1.0f - std::pow(1.0f - x, k); };
            const float e0 = curve(st.curveP);
            const float e1 = curve(p);
            const float share = e0 < 1.0f ? std::clamp((e1 - e0) / (1.0f - e0), 0.0f, 1.0f) : 1.0f;
            st.curveP = p;
            if (st.enjoyment < target) {
                float next = st.enjoyment + (target - st.enjoyment) * share;
                if (!finalStage) {
                    next = std::min(next, std::max(st.enjoyment, kRushHover));
                }
                st.enjoyment = std::clamp(next, 0.0f, kMaxEnjoyment);
            }
        }

        // ---- Mini-game NPC strategies ----
        // The wording lives in Data/SKSE/Plugins/SkyrimNet_SexLab/strategies.json (LoadStrategies, matched by
        // key); the keys stay here, in Strategy enum order.
        constexpr const char* kStrategyKeys[] = {
            "passive", "mutual", "selfish", "selfless", "deny_self", "deny_all", "deny", "tease", "focused",
            "nonsexual",
        };
        constexpr std::size_t kStrategyCount = std::size(kStrategyKeys);
        static_assert(kStrategyCount == static_cast<std::size_t>(Strategy::kCount));

        struct StrategyInfo
        {
            std::string key;       // decision option / dashboard key
            std::string label;     // HUD tag: short name
            std::string text;      // third person, after the name; {target} / {name} filled in
            std::string option;    // decision option text (criteria line); also {self} / {his}
            std::string observed;  // how a decision-made change looks to others, after the name
            std::string order;     // infinitive phrase after "to": "Bob orders Nina to <order>."
        };
        using StrategyTable = std::array<StrategyInfo, kStrategyCount>;

        // Every text is its key until strategies.json provides it.
        StrategyTable FallbackStrategies()
        {
            StrategyTable t;
            for (std::size_t i = 0; i < kStrategyCount; ++i) {
                t[i].key = t[i].label = t[i].text = t[i].option = t[i].observed = t[i].order = kStrategyKeys[i];
            }
            return t;
        }
        StrategyTable g_strategies = FallbackStrategies();  // g_lock

        // Reads strategies.json (an array of objects, one per key). Unreadable / invalid: keeps the table in use.
        void LoadStrategies()
        {
            constexpr const char* kPath = "Data/SKSE/Plugins/SkyrimNet_SexLab/strategies.json";
            std::ifstream in(kPath);
            if (!in) {
                webui_log::warn("OrgasmEngine: {} missing; strategy texts stay as they were", kPath);
                return;
            }
            StrategyTable next = FallbackStrategies();
            std::array<bool, kStrategyCount> seen{};
            try {
                const auto j = nlohmann::json::parse(in);
                if (!j.is_array()) {
                    webui_log::warn("OrgasmEngine: {} is not an array; strategy texts stay as they were", kPath);
                    return;
                }
                const auto str = [](const nlohmann::json& o, const char* name) {
                    const auto it = o.find(name);
                    return it != o.end() && it->is_string() ? it->get<std::string>() : std::string();
                };
                for (const auto& item : j) {
                    const std::string key = item.is_object() ? str(item, "key") : "";
                    std::size_t i = 0;
                    while (i < kStrategyCount && key != kStrategyKeys[i]) {
                        ++i;
                    }
                    if (i == kStrategyCount) {
                        webui_log::warn("OrgasmEngine: strategies.json: unknown key '{}' ignored", key);
                        continue;
                    }
                    seen[i] = true;
                    StrategyInfo& t = next[i];
                    const std::pair<const char*, std::string*> required[] = {
                        { "label", &t.label }, { "text", &t.text }, { "option", &t.option },
                        { "observed", &t.observed }, { "order", &t.order },
                    };
                    for (const auto& [name, field] : required) {
                        if (const std::string v = str(item, name); !v.empty()) {
                            *field = v;
                        } else {
                            webui_log::warn("OrgasmEngine: strategies.json: '{}' has no {}", key, name);
                        }
                    }
                }
            } catch (const std::exception& e) {
                webui_log::warn("OrgasmEngine: {} unreadable ({}); strategy texts stay as they were", kPath, e.what());
                return;
            }
            for (std::size_t i = 0; i < kStrategyCount; ++i) {
                if (!seen[i]) {
                    webui_log::warn("OrgasmEngine: strategies.json: no entry for '{}'", kStrategyKeys[i]);
                }
            }
            std::lock_guard lock(g_lock);
            g_strategies = std::move(next);
        }

        const StrategyInfo& InfoOf(Strategy s)
        {
            const auto i = static_cast<std::size_t>(std::clamp(static_cast<std::int32_t>(s), 0,
                static_cast<std::int32_t>(Strategy::kCount) - 1));
            return g_strategies[i];
        }

        // Dashboard pulldown value ("Mutual", "Cum quick", ...) -> strategy; def when unknown.
        Strategy ParseStrategy(std::string value, Strategy def)
        {
            std::string v;
            for (const unsigned char c : value) {
                if (std::isalnum(c)) {
                    v.push_back(static_cast<char>(std::tolower(c)));
                }
            }
            for (std::int32_t i = 0; i < static_cast<std::int32_t>(Strategy::kCount); ++i) {
                std::string k = kStrategyKeys[i];  // "deny_self" matches the stripped "denyself"
                k.erase(std::remove(k.begin(), k.end(), '_'), k.end());
                if (v == k) {
                    return static_cast<Strategy>(i);
                }
            }
            return def;
        }

        bool NeedsTarget(Strategy s)
        {
            return s == Strategy::kDeny || s == Strategy::kTease || s == Strategy::kFocused;
        }

        // Caller holds g_lock. Some actor of the scene expects orgasm (position's orgasm_expected).
        bool AnyExpected(const SceneState& sc)
        {
            for (const auto id : sc.actors) {
                if (const auto at = g_actors.find(id); at != g_actors.end() && at->second.orgasmExpected) {
                    return true;
                }
            }
            return false;
        }

        // Caller holds g_lock. Mini-game mode, AI-driven actors only; no role gating.
        bool StrategyAllowed(const SceneState& sc, const ActorState& st, Strategy s)
        {
            if (!g_settings.miniGame || !AiDriven(st) || s < Strategy::kPassive || s >= Strategy::kCount) {
                return false;
            }
            const bool others = sc.actors.size() > 1;
            switch (s) {
            case Strategy::kNonSexual:
                return !AnyExpected(sc);
            case Strategy::kMutual:
            case Strategy::kSelfless:
            case Strategy::kDenyAll:
            case Strategy::kDeny:
            case Strategy::kTease:
            case Strategy::kFocused:
                return others;
            default:
                return true;
            }
        }

        // Role default, ignoring Non-sexual.
        Strategy RoleDefault(const SceneState& sc, const ActorState& st)
        {
            Strategy s = g_settings.defaultNormal;
            if (st.role == Role::kAggressor) {
                s = g_settings.defaultAggressor;
            } else if (st.role == Role::kVictim) {
                s = g_settings.defaultVictim;
            }
            // Role defaults never force anyone and need no target.
            if (NeedsTarget(s) || !StrategyAllowed(sc, st, s)) {
                return Strategy::kPassive;
            }
            return s;
        }

        // Non-sexual when no actor expects orgasm, else the role default.
        Strategy DefaultStrategy(const SceneState& sc, const ActorState& st)
        {
            return StrategyAllowed(sc, st, Strategy::kNonSexual) ? Strategy::kNonSexual : RoleDefault(sc, st);
        }

        void ReplaceAll(std::string& s, const std::string& from, const std::string& to)
        {
            for (std::size_t pos = s.find(from); pos != std::string::npos; pos = s.find(from, pos + to.size())) {
                s.replace(pos, from.size(), to);
            }
        }

        // Fills {target} / {name} / {self} / {his} in a strategy text for the actor `self`.
        void FillStrategyText(std::string& text, RE::FormID self, RE::FormID target)
        {
            RE::Actor* actor = ActorFor(self);
            ReplaceAll(text, "{target}", NameOf(ActorFor(target)));
            ReplaceAll(text, "{name}", NameOf(actor));
            ReplaceAll(text, "{self}", Reflexive(actor));
            ReplaceAll(text, "{his}", Possessive(actor));
        }

        // Caller holds g_lock. HUD tag: short name.
        std::string HudLabel(const ActorState& st)
        {
            std::string label = InfoOf(st.strategy).label;
            FillStrategyText(label, st.id, st.strategyTarget);
            return label;
        }

        // Caller holds g_lock. Third-person phrase for the actor's strategy (no leading name).
        std::string StrategyPhrase(const ActorState& st)
        {
            std::string text = InfoOf(st.strategy).text;
            FillStrategyText(text, st.id, st.strategyTarget);
            return text;
        }

        // Caller holds g_lock. How the actor's strategy looks to others ("appears to be focused on her own
        // enjoyment"), no leading name. The short-term event for a decision-made change.
        std::string ObservedPhrase(const ActorState& st)
        {
            std::string text = InfoOf(st.strategy).observed;
            FillStrategyText(text, st.id, st.strategyTarget);
            return text;
        }

        // Strategy change: narration (narrate) or, for a decision-made change, a short-term
        // event with observed (empty: the phrase itself).
        void Announce(const SceneState& sc, const ActorState& st, const std::string& phrase, Effects& fx,
            bool narrate = true, const std::string& observed = "")
        {
            const std::string name = NameOf(ActorFor(st.id));
            if (name.empty() || phrase.empty()) {
                return;
            }
            (void)sc;
            fx.strategies.push_back({ st.id, st.strategyTarget, name + " " + phrase + ".",
                name + " " + (observed.empty() ? phrase : observed) + ".", narrate });
        }

        // Caller holds g_lock. Sets the strategy (already allowed).
        // narrate false: a decision-made change (short-term event instead of narration).
        void ApplyStrategy(const SceneState& sc, ActorState& st, Strategy s, RE::FormID target, bool announce,
            Effects& fx, bool narrate = true)
        {
            st.strategy = s;
            st.strategyTarget = NeedsTarget(s) ? target : 0;
            st.nextStepAt = Now();
            webui_log::info("OrgasmEngine: {:#x} strategy {} target {:#x}", st.id, InfoOf(s).key, st.strategyTarget);
            if (announce) {
                Announce(sc, st, StrategyPhrase(st), fx, narrate, ObservedPhrase(st));
            }
        }

        // Caller holds g_lock. Mini-game press with an explicit base amount (skill factor, cost applied). narrate:
        // queue the coalesced "<A> arouses <B>" line (player keys / LLM / API).
        bool ArouseLocked(RE::Actor* who, RE::Actor* target, ActorState& tst, float base, bool narrate, Effects&)
        {
            const auto* wst = Find(who);
            const float skill = wst ? static_cast<float>(wst->skill) : 0.0f;
            const float cost = ArouseCost(wst);
            if (CurrentAv(who, RE::ActorValue::kStamina) < cost) {
                return false;
            }
            DamageAv(who, RE::ActorValue::kStamina, cost);
            const float before = tst.enjoyment;
            const float amount = std::max(0.0f, base) * (1.0f + 0.1f * skill);
            if (tst.dom) {
                tst.domDelta += amount;
                tst.domShare += amount / kMaxEnjoyment;
                tst.domSyncNow = true;
            } else {
                tst.enjoyment = std::clamp(before + amount, 0.0f, kMaxEnjoyment);
            }
            if (narrate) {
                NoteNarration(who->GetFormID(), target->GetFormID(), true, Now());
            }
            webui_log::info("OrgasmEngine: arouse {:#x}->{:#x} +{} cost={} -> {}", who->GetFormID(),
                target->GetFormID(), amount, cost, tst.enjoyment);
            return true;
        }

        bool CalmLocked(RE::Actor* who, RE::Actor* target, ActorState& tst, float base, bool narrate, Effects& fx)
        {
            const auto* wst = Find(who);
            const float cost = CalmCost(wst);
            if (CurrentAv(who, RE::ActorValue::kMagicka) < cost) {
                return false;
            }
            DamageAv(who, RE::ActorValue::kMagicka, cost);
            const double now = Now();
            tst.lastCalmAt = now;
            const float before = tst.enjoyment;
            const float amount = std::max(0.0f, base);
            if (tst.dom) {
                tst.domDelta -= amount;
                tst.domSyncNow = true;
            } else {
                tst.enjoyment = std::max(0.0f, before - amount);
            }
            if (before >= kEdgeThreshold) {
                tst.edgeUntil = now + g_settings.edgeSeconds;
                fx.events.push_back({ SKYRIMNET_SEXLAB_API::EngineEventType::kEdge, tst.id, who->GetFormID(),
                    "minigame", g_settings.edgeSeconds, tst.orgasmCount });
            }
            if (narrate) {
                NoteNarration(who->GetFormID(), target->GetFormID(), false, now);
            }
            webui_log::info("OrgasmEngine: calm {:#x}->{:#x} cost={} {} -> {}{}", who->GetFormID(),
                target->GetFormID(), cost, before, tst.enjoyment, before >= kEdgeThreshold ? " (edge)" : "");
            return true;
        }

        // Caller holds g_lock. Another actor of the scene by enjoyment (lowest or highest); 0 when none.
        // role: only that role (kNormal = any).
        RE::FormID PickOther(const SceneState& sc, RE::FormID self, bool lowest, bool includeSelf,
            Role role = Role::kNormal)
        {
            RE::FormID best = 0;
            float bestValue = 0.0f;
            for (const auto id : sc.actors) {
                if (id == self && !includeSelf) {
                    continue;
                }
                const auto at = g_actors.find(id);
                if (at == g_actors.end() || (role != Role::kNormal && at->second.role != role)) {
                    continue;
                }
                const float v = at->second.enjoyment;
                if (!best || (lowest ? v < bestValue : v > bestValue)) {
                    best = id;
                    bestValue = v;
                }
            }
            return best;
        }

        bool InScene(const SceneState& sc, RE::FormID id)
        {
            return id && std::find(sc.actors.begin(), sc.actors.end(), id) != sc.actors.end();
        }

        // Caller holds g_lock. Mean arouse skill factor (1 + 0.1 x skill) of the scene's NPCs, 1 when none.
        float MeanNpcSkillFactor(const SceneState& sc)
        {
            float sum = 0.0f;
            std::int32_t count = 0;
            for (const auto id : sc.actors) {
                const auto at = g_actors.find(id);
                if (at == g_actors.end() || IsPlayer(ActorFor(id))) {
                    continue;
                }
                sum += 1.0f + 0.1f * static_cast<float>(at->second.skill);
                ++count;
            }
            return count > 0 && sum > 0.0f ? sum / static_cast<float>(count) : 1.0f;
        }

        // Caller holds g_lock. One mini-game step for an NPC with a strategy, every npc_interval seconds.
        // Timed scenes: the step is the scene's calibrated step rate x the interval, spread by
        // random(npc_step_min, npc_step_max) / their mean, over the scene's mean NPC skill factor (arouse
        // re-applies the actor's own), so every NPC on Mutual lands on mutualTarget. Untimed: random(min,
        // max) as is. Costs and edging as for a player press. Not narrated (the strategy
        // choice is). No step until the scene's timers arrived (SexLab's are empty at first), or kUntimedGrace
        // after BeginScene for a scene that never sends any.
        void StrategyStep(const SceneState& sc, ActorState& st, double now, Effects& fx)
        {
            RE::Actor* self = ActorFor(st.id);
            const bool stepsReady = sc.ratesKnown || now - sc.beganAt >= kUntimedGrace;
            if (!g_settings.miniGame || !stepsReady || !self || !AiDriven(st) || now < st.nextStepAt) {
                return;
            }
            const float interval = std::max(0.25f, g_settings.npcInterval);
            st.nextStepAt = now + interval;

            const float lo = std::max(0.0f, std::min(g_settings.npcStepMin, g_settings.npcStepMax));
            const float hi = std::max(lo, g_settings.npcStepMax);
            std::uniform_real_distribution<float> roll(lo, hi);
            float amount = roll(g_rng);
            if (sc.mgRates) {
                const float mean = 0.5f * (lo + hi);
                const float spread = mean > 0.0f ? amount / mean : 1.0f;
                amount = sc.mgStepRate * interval * spread / MeanNpcSkillFactor(sc);
            }

            const auto arouse = [&](RE::FormID id) {
                auto at = g_actors.find(id);
                RE::Actor* target = ActorFor(id);
                if (at != g_actors.end() && target && InScene(sc, id)) {
                    ArouseLocked(self, target, at->second, amount, false, fx);
                }
            };
            const auto calm = [&](RE::FormID id) {
                auto at = g_actors.find(id);
                RE::Actor* target = ActorFor(id);
                if (at != g_actors.end() && target && InScene(sc, id)) {
                    CalmLocked(self, target, at->second, amount, false, fx);
                }
            };

            // The strategy's target, or another actor of the scene when it left.
            const auto targetOf = [&]() {
                return InScene(sc, st.strategyTarget) ? st.strategyTarget : PickOther(sc, st.id, true, false);
            };
            switch (st.strategy) {
            case Strategy::kMutual:
                arouse(PickOther(sc, st.id, true, true));
                break;
            case Strategy::kSelfish:
                arouse(st.id);
                break;
            case Strategy::kSelfless:
                arouse(PickOther(sc, st.id, true, false));
                break;
            case Strategy::kDenySelf:
                calm(st.id);
                break;
            case Strategy::kDenyAll:
                for (const auto id : sc.actors) {
                    calm(id);
                }
                break;
            case Strategy::kDeny:
                calm(targetOf());
                break;
            case Strategy::kFocused:
                arouse(targetOf());
                break;
            case Strategy::kTease: {
                const RE::FormID target = targetOf();
                const auto tt = g_actors.find(target);
                if (tt != g_actors.end()) {
                    if (tt->second.enjoyment < kEdgeThreshold) {
                        arouse(target);
                    } else {
                        calm(target);
                    }
                }
                break;
            }
            default:
                break;
            }
        }

        bool InGroup(const OrgasmGroupFx& group, RE::FormID id)
        {
            return std::find(group.actors.begin(), group.actors.end(), id) != group.actors.end();
        }

        // Caller holds g_lock. Someone in the scene orgasmed: everyone else at groupJoin or more joins outright,
        // the rest roll once (RollOrgasm, no bonus).
        // Second-to-last stage, and the lead just reached their target (the Scene jumps to the final
        // stage): everyone still out rolls again with the stage spike as bonus, so
        // whoever would finish in the final stage goes into this one DN. A fail there is final.
        void JoinGroup(const SceneState& sc, OrgasmGroupFx& group, double now, Effects& fx)
        {
            // Rushing: already gate-passed and narrated for this orgasm; a join would narrate it twice.
            const auto canJoin = [&](RE::FormID id) -> ActorState* {
                if (InGroup(group, id)) {
                    return nullptr;
                }
                auto at = g_actors.find(id);
                if (at == g_actors.end() || at->second.rushing || !CanOrgasmNow(at->second, now)) {
                    return nullptr;
                }
                return &at->second;
            };
            for (const auto id : sc.actors) {
                ActorState* st = canJoin(id);
                if (!st) {
                    continue;
                }
                if (st->enjoyment >= g_settings.groupJoin) {
                    webui_log::info("OrgasmEngine: group join {:#x} enjoyment={:.1f} threshold={:.1f}", id,
                        st->enjoyment, g_settings.groupJoin);
                    Fire(*st, group, false, "group", now, fx);
                    continue;
                }
                float r = 0.0f;
                const bool passed = RollOrgasm(*st, 0.0f, r);
                webui_log::info("OrgasmEngine: group roll {:#x} enjoyment={:.1f} roll=+{:.1f} pass={}", id,
                    st->enjoyment, r, passed);
                if (passed) {
                    Fire(*st, group, false, "group", now, fx);
                }
            }

            const bool timed = sc.baseRate > 0.0f && sc.stageSecs.size() >= 2 && sc.stageCount >= 2 && !sc.leadIn;
            if (!timed || sc.stage != sc.stageCount - 1 || sc.endingTarget <= 0 || !InGroup(group, sc.endingLead)) {
                return;
            }
            const auto lead = g_actors.find(sc.endingLead);
            if (lead == g_actors.end() || lead->second.orgasmCount < sc.endingTarget) {
                return;
            }
            for (const auto id : sc.actors) {
                ActorState* st = canJoin(id);
                if (!st) {
                    continue;
                }
                float r = 0.0f;
                const bool passed = RollOrgasm(*st, g_settings.stageSpike, r);
                webui_log::info("OrgasmEngine: final roll {:#x} enjoyment={:.1f} bonus={:.1f} roll=+{:.1f} pass={}",
                    id, st->enjoyment, g_settings.stageSpike, r, passed);
                if (passed) {
                    Fire(*st, group, false, "group", now, fx);
                } else {
                    st->finalRollFailed = true;
                }
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

        // Caller holds g_lock. Flushes pending arouse / calm narrations about the group as short-lived events
        // (no longer folded into the orgasm DN; extras stays empty) and queues the group's single Papyrus dispatch.
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
                const auto [who, target, arouse] = it->first;
                std::string msg = NarrationText(it->first);
                if (!msg.empty()) {
                    fx.narrations.push_back({ arouse ? "sexlab_arouse" : "sexlab_calm", std::move(msg), who, target });
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
            for (const auto& p : fx.gatePasses) {
                std::vector<RE::Actor*> actors;
                for (const auto id : p.actors) {
                    if (auto* a = ActorFor(id)) {
                        actors.push_back(a);
                    }
                }
                if (!actors.empty()) {
                    DispatchShell("Effect_GatePassed",
                        RE::MakeFunctionArguments(std::move(actors), static_cast<bool>(p.holdStage)));
                }
            }
            for (const auto id : fx.advances) {
                if (auto* a = ActorFor(id)) {
                    DispatchShell("Effect_AdvanceToFinal", RE::MakeFunctionArguments(std::move(a)));
                }
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
            for (const auto& [id, msg] : fx.directs) {
                NarrateDirect(msg, ActorFor(id), nullptr);
            }
            for (const auto& s : fx.strategies) {
                if (auto* a = ActorFor(s.actor)) {
                    DispatchShell("Effect_StrategyChanged",
                        RE::MakeFunctionArguments(std::move(a), ActorFor(s.target), RE::BSFixedString(s.msg.c_str()),
                            RE::BSFixedString(s.observed.c_str()), static_cast<bool>(s.narrate)));
                }
            }
            for (const auto sid : fx.decisionScenes) {
                StrategyDecision::OnSceneReady(sid);
            }
            for (const auto& group : fx.exhausted) {
                std::vector<RE::Actor*> actors;
                for (const auto id : group) {
                    if (auto* a = ActorFor(id)) {
                        actors.push_back(a);
                    }
                }
                if (!actors.empty()) {
                    DispatchShell("Effect_Exhausted", RE::MakeFunctionArguments(std::move(actors)));
                }
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

        void DropSceneLocked(std::int32_t sid, Effects& /*fx*/)
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
            const double wall = GameNow();
            const bool paused = NarrationQueue::IsPaused();
            // Clamp to two ticks so a save/load hitch credits little.
            const double dt = paused ? 0.0 : std::clamp(wall - g_lastTick, 0.0, 0.5);
            g_lastTick = wall;
            g_gameClock.store(g_gameClock.load() + dt);
            const double now = Now();

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
                    // Ready for NPC steps (StrategyStep's rule): the decision model picks every NPC's opening
                    // strategy now, replacing the role defaults.
                    if (!sc.decisionsStarted && g_settings.miniGame &&
                        (sc.ratesKnown || now - sc.beganAt >= kUntimedGrace)) {
                        sc.decisionsStarted = true;
                        fx.decisionScenes.push_back(sid);
                    }

                    RE::Actor* first = sc.actors.empty() ? nullptr : ActorFor(sc.actors.front());
                    const float speed = first ? AnimSpeed::Get(first) : 1.0f;
                    const bool finalStage = sc.stageCount > 0 && sc.stage >= sc.stageCount;
                    // Gate (4a): Together, or a mini-game scene the engine plays alone (aiGate), timed, no LeadIn.
                    const bool timedScene = sc.baseRate > 0.0f && sc.stageSecs.size() >= 2 && sc.stageCount >= 2;
                    const bool engineOff = g_settings.engineOff;
                    const bool together = !g_settings.miniGame && !engineOff;
                    const bool aiGate = g_settings.miniGame && SceneAiDriven(sc);
                    const bool useGate = (together || aiGate) && g_settings.gate && timedScene && !sc.leadIn;
                    // aiGate, last two stages: no orgasm but the gate's (or a forced one), so the gate's is last.
                    const bool gateHeld = aiGate && useGate && sc.stage >= sc.stageCount - 1;
                    if (finalStage && !sc.paused) {
                        sc.finalElapsed += dt;
                    }
                    if (sc.stageCount >= 2 && sc.stage == sc.stageCount - 1 && !sc.paused) {
                        sc.penultElapsed += dt;
                    }
                    // Together progress clock: SexLab's stage timer does not run while paused.
                    if (!sc.paused) {
                        sc.stageElapsed += dt;
                    }
                    // Orgasm expectation changed: unforced NPCs on the old default move to the new one.
                    if (const bool expected = AnyExpected(sc); expected != sc.anyExpected) {
                        sc.anyExpected = expected;
                        for (const auto id : sc.actors) {
                            auto at = g_actors.find(id);
                            if (at == g_actors.end() || !AiDriven(at->second)) {
                                continue;
                            }
                            ActorState& st = at->second;
                            const bool onDefault = expected ? st.strategy == Strategy::kNonSexual
                                                            : st.strategy == RoleDefault(sc, st) ||
                                                                  st.strategy == Strategy::kPassive;
                            if (const Strategy next = DefaultStrategy(sc, st); onDefault && next != st.strategy) {
                                ApplyStrategy(sc, st, next, 0, true, fx);
                            }
                        }
                    }
                    // Everyone who orgasms in this scene this tick: one group, one message.
                    OrgasmGroupFx group;
                    // Gate passers reaching kRushFireAt: already narrated, so their own group, no join.
                    OrgasmGroupFx rushGroup;
                    // Sex is hard work: a non-victim at the regen floor (-10) ends the scene.
                    std::vector<RE::FormID> exhausted;
                    for (const auto id : sc.actors) {
                        auto at = g_actors.find(id);
                        RE::Actor* actor = ActorFor(id);
                        if (at == g_actors.end() || !actor || sc.paused) {
                            continue;
                        }
                        // Nothing sexual expected: no fatigue until the actor's enjoyment reaches 50.
                        if (sc.anyExpected || at->second.enjoyment >= 50.0f) {
                            ApplyFatigue(sc, at->second, actor, dt, fx);
                        }
                        if (g_settings.staminaFatigue && !sc.exhaustedSent && at->second.role != Role::kVictim &&
                            at->second.regen <= kRegenFloor) {
                            exhausted.push_back(id);
                        }
                    }
                    if (!exhausted.empty()) {
                        sc.exhaustedSent = true;
                        webui_log::info("OrgasmEngine: scene {} ends, {} too tired to continue", sid, exhausted.size());
                        fx.exhausted.push_back(std::move(exhausted));
                    }

                    for (const auto id : sc.actors) {
                        auto at = g_actors.find(id);
                        if (at == g_actors.end()) {
                            continue;
                        }
                        ActorState& st = at->second;
                        if (st.rushing && AnyBlock(st)) {
                            st.rushing = false;
                            webui_log::info("OrgasmEngine: gate rush {:#x} cancelled (blocked) enjoyment={:.1f}", id,
                                st.enjoyment);
                        }
                        // Gate pass: the narration is already out. Climb to kRushHover by the expected voice
                        // start, then finish within kRushFinish in the final stage and fire there (no second
                        // DN). No passive gain or other test meanwhile; a forced request still wins.
                        if (engineOff) {
                            // SexLab owns enjoyment and decides orgasms: no gain, strategy steps or orgasm
                            // test. Only a forced request (WebUI button) fires.
                            st.rushing = false;
                            if (st.pending && st.pendingForce) {
                                Fire(st, group, true, st.pendingSource, now, fx);
                            } else {
                                st.pending = false;
                            }
                        } else if (st.rushing && !(st.pending && st.pendingForce)) {
                            if (finalStage) {
                                // Kept in rushRate so the finish is linear (max keeps the first tick's rate).
                                st.rushRate = std::max(st.rushRate,
                                    static_cast<float>((kRushFireAt - st.enjoyment) / kRushFinish));
                            }
                            st.enjoyment = std::clamp(st.enjoyment + static_cast<float>(st.rushRate * dt), 0.0f,
                                finalStage ? kMaxEnjoyment : kRushHover);
                            if (finalStage && st.enjoyment >= kRushFireAt) {
                                Fire(st, rushGroup, true, "gate", now, fx);
                            }
                        } else {
                            // 1. Passive gain. Together (mini-game off): the bonus-shaped curve that reaches 100
                            // at the end of the second-to-last stage. Mini-game (and DOM slaves): fixed rate from
                            // the stage timers, so extra time (repeated stage) or speed adds enjoyment; pausing
                            // the stage advance does not hold gain. Not expected to orgasm: no gain.
                            if (!g_settings.miniGame && !st.dom) {
                                if (st.orgasmExpected) {
                                    ApplyTogetherCurve(sc, st, finalStage);
                                } else {
                                    st.curveP = SceneProgress(sc);
                                }
                            } else {
                                const float rate = PassiveRate(sc, st);
                                const float gain = static_cast<float>(rate * dt) * speed;
                                if (st.dom) {
                                    st.domProgress += gain;
                                    st.domStepAcc += gain;
                                } else {
                                    st.enjoyment = std::clamp(st.enjoyment + gain, 0.0f, kMaxEnjoyment);
                                }
                            }

                            // Mini-game: NPCs play their strategy.
                            StrategyStep(sc, st, now, fx);
                            // aiGate: held below the threshold until the gate rolls (it starts the rush).
                            if (gateHeld && !st.dom) {
                                st.enjoyment = std::min(st.enjoyment, kRushHover);
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
                            } else if (gateHeld) {
                                // aiGate: the gate (end of the second-to-last stage) is the scene's last orgasm;
                                // a request waits for it (the gate passes a pending actor).
                            } else {
                                const bool wants = WantsOrgasm(st, now, false);
                                const bool cooling = st.lastOrgasm >= 0.0 && now - st.lastOrgasm < st.cooldown;
                                const bool edging = now < st.edgeUntil;
                                if (wants && !cooling && !edging) {
                                    if (st.finalRollFailed) {
                                        // Out after the final roll: not a deny, so no event; only force fires.
                                        st.pending = false;
                                    } else if (AnyBlock(st)) {
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
                        }

                        // 3. Mirror into SexLab. Engine off: every kMirrorInterval, so Mirror_Apply pulls
                        // SexLab's value back into the engine instead.
                        const auto rounded = static_cast<std::int32_t>(std::lround(st.enjoyment));
                        if (now - st.lastMirrorAt >= kMirrorInterval &&
                            (engineOff || rounded != st.lastMirrored || now - st.lastMirrorAt >= kMirrorRefresh)) {
                            st.lastMirrored = rounded;
                            st.lastMirrorAt = now;
                            fx.mirrors.push_back({ id, rounded });
                        }
                    }

                    // 4a. Gate (timed, no LeadIn): in the second-to-last stage, `lead` seconds (the measured
                    // DN -> speech time) before its timer ends, or on reaching the final stage first, each
                    // actor who has not orgasmed rolls once (RollOrgasm + stage spike). Passers rush (bars reach
                    // kRushHover by the expected voice) and the Scene narrates them at once and holds the
                    // stage; the voice starting pushes the final stage, where the rush fires the orgasm. All
                    // fail: SexLab advances as normal, no orgasm.
                    // Mini-game under the player's hand: no gate and no safety net, so several orgasms or none.
                    // Together: everyone expected passes the gate (no roll) and finishes together.
                    // aiGate (mini-game, engine plays everyone): earlier orgasms count too; the ending lead
                    // and every aggressor expected to orgasm pass outright (cooldown ignored), a pending
                    // request passes, the rest roll. A victim follows its aggressor's strategy: Force orgasm
                    // passes it, Tease keeps it out, anything else rolls.
                    // The gate fires lead + kGateDispatchMargin before the stage timer ends, so the Scene's
                    // hold (tick -> Papyrus -> UpdateTimer) lands before SexLab advances.
                    if (useGate && !sc.gateDone && sc.stage >= sc.stageCount - 1) {
                        const bool penultimate = sc.stage == sc.stageCount - 1;
                        const float gateSecs = sc.stageSecs[sc.stageSecs.size() - 2];
                        const double lead = NarrationTiming::EstimateSeconds(g_settings.gateLeadDefault);
                        if (!penultimate || sc.penultElapsed >= std::max(0.0, gateSecs - lead - kGateDispatchMargin)) {
                            sc.gateDone = true;
                            GatePassFx pass{ {}, penultimate };
                            // Victims an aggressor is set on forcing to orgasm, or teasing at the edge.
                            std::vector<RE::FormID> forcedVictims;
                            std::vector<RE::FormID> teasedVictims;
                            if (aiGate) {
                                for (const auto id : sc.actors) {
                                    const auto at = g_actors.find(id);
                                    if (at == g_actors.end() || at->second.role != Role::kAggressor ||
                                        at->second.strategyTarget == 0) {
                                        continue;
                                    }
                                    if (at->second.strategy == Strategy::kFocused) {
                                        forcedVictims.push_back(at->second.strategyTarget);
                                    } else if (at->second.strategy == Strategy::kTease ||
                                               at->second.strategy == Strategy::kDeny) {
                                        teasedVictims.push_back(at->second.strategyTarget);
                                    }
                                }
                            }
                            const auto has = [](const std::vector<RE::FormID>& v, RE::FormID id) {
                                return std::find(v.begin(), v.end(), id) != v.end();
                            };
                            for (const auto id : sc.actors) {
                                auto at = g_actors.find(id);
                                if (at == g_actors.end()) {
                                    continue;
                                }
                                ActorState& st = at->second;
                                const bool isLead = aiGate && id == sc.endingLead && sc.endingTarget > 0;
                                const bool isAggressor = aiGate && st.role == Role::kAggressor;
                                const bool victim = aiGate && st.role == Role::kVictim;
                                const bool outright = (isLead && penultimate) || isAggressor;
                                const bool canNow = outright ? !st.dom && !AnyBlock(st) && !st.finalRollFailed &&
                                                                   now >= st.edgeUntil
                                                             : CanOrgasmNow(st, now);
                                if ((st.orgasmCount != 0 && !together && !aiGate) || !st.orgasmExpected ||
                                    st.rushing || !canNow || (victim && has(teasedVictims, id)) ||
                                    std::find(group.actors.begin(), group.actors.end(), id) != group.actors.end() ||
                                    std::find(rushGroup.actors.begin(), rushGroup.actors.end(), id) !=
                                        rushGroup.actors.end()) {
                                    webui_log::info("OrgasmEngine: gate skips {:#x} enjoyment={:.1f} count={} "
                                                    "expected={} dom={} ai_gate={} teased={}",
                                        id, st.enjoyment, st.orgasmCount, st.orgasmExpected, st.dom, aiGate,
                                        victim && has(teasedVictims, id));
                                    continue;
                                }
                                const bool forcedVictim = victim && has(forcedVictims, id);
                                float r = 0.0f;
                                const bool passed = together || isLead || isAggressor || forcedVictim ||
                                                    (aiGate && st.pending) || RollOrgasm(st, g_settings.stageSpike, r);
                                webui_log::info("OrgasmEngine: gate {:#x} enjoyment={:.1f} bonus={:.1f} roll=+{:.1f} "
                                                "pass={} lead={:.2f}s penultimate={} together={} ai_gate={} ending_lead={} "
                                                "aggressor={} forced_victim={}",
                                    id, st.enjoyment, g_settings.stageSpike, r, passed, lead, penultimate, together,
                                    aiGate, isLead, isAggressor, forcedVictim);
                                if (passed) {
                                    st.rushing = true;
                                    st.rushRate = std::max(0.0f, kRushHover - st.enjoyment) / static_cast<float>(lead);
                                    pass.actors.push_back(id);
                                }
                            }
                            // Anyone close (groupJoinFinal) rushes with the passers, repeat orgasms too:
                            // one gate DN for everyone who finishes together.
                            if (!pass.actors.empty()) {
                                for (const auto id : sc.actors) {
                                    if (std::find(pass.actors.begin(), pass.actors.end(), id) != pass.actors.end()) {
                                        continue;
                                    }
                                    auto at = g_actors.find(id);
                                    if (at == g_actors.end()) {
                                        continue;
                                    }
                                    ActorState& st = at->second;
                                    if (!st.orgasmExpected || st.rushing || !CanOrgasmNow(st, now) ||
                                        st.enjoyment < g_settings.groupJoinFinal ||
                                        (st.role == Role::kVictim && has(teasedVictims, id)) ||
                                        std::find(group.actors.begin(), group.actors.end(), id) != group.actors.end() ||
                                        std::find(rushGroup.actors.begin(), rushGroup.actors.end(), id) !=
                                            rushGroup.actors.end()) {
                                        continue;
                                    }
                                    webui_log::info("OrgasmEngine: gate join {:#x} enjoyment={:.1f} count={}", id,
                                        st.enjoyment, st.orgasmCount);
                                    st.rushing = true;
                                    st.rushRate = std::max(0.0f, kRushHover - st.enjoyment) / static_cast<float>(lead);
                                    pass.actors.push_back(id);
                                }
                            }
                            if (!pass.actors.empty()) {
                                sc.gateAwait = penultimate;
                                sc.gateMarked = false;
                                fx.gatePasses.push_back(std::move(pass));
                            }
                        }
                    }
                    // The voice for the gate narration started: final stage now (the rush fires there).
                    if (sc.gateAwait && sc.gateMarked && !sc.paused && !sc.actors.empty() &&
                        NarrationTiming::StartedSince(sc.gateSpeechMark, sc.actors)) {
                        sc.gateAwait = false;
                        webui_log::info("OrgasmEngine: scene {} gate voice started, to the final stage", sid);
                        fx.advances.push_back(sc.actors.front());
                    }

                    // 4b. Safety net (gate off, or no timers): at 90% of the final stage's timer, each
                    // non-DOM actor at kSafetyMin or more who has not finished. Without timers: at
                    // final-stage entry, everyone when the mini-game is off (the old rule). No LeadIn.
                    if (together && !useGate && finalStage && !sc.finalDone && !sc.leadIn) {
                        const float finalSecs = sc.stageSecs.empty() ? 0.0f : sc.stageSecs.back();
                        const bool timed = sc.baseRate > 0.0f && finalSecs > 0.0f;
                        if (!timed || sc.finalElapsed >= kSafetyAt * finalSecs) {
                            sc.finalDone = true;
                            const float needed = timed || g_settings.miniGame ? kSafetyMin : 0.0f;
                            for (const auto id : sc.actors) {
                                auto at = g_actors.find(id);
                                if (at == g_actors.end()) {
                                    continue;
                                }
                                ActorState& st = at->second;
                                const bool edging = now < st.edgeUntil;
                                const bool calmed = st.lastCalmAt >= sc.finalStageAt;
                                if (st.dom || st.orgasmCount != 0 || AnyBlock(st) || st.finalRollFailed || edging || calmed ||
                                    st.enjoyment < (st.orgasmExpected ? needed : kSafetyMin)) {
                                    webui_log::info("OrgasmEngine: safety net skips {:#x} enjoyment={:.1f} "
                                                    "count={} dom={} edging={} calmed={}",
                                        id, st.enjoyment, st.orgasmCount, st.dom, edging, calmed);
                                    continue;
                                }
                                Fire(st, group, false, "final_stage", now, fx);
                            }
                        }
                    }

                    // 5. Group: anyone orgasmed -> everyone else rolls (JoinGroup), one dispatch.
                    if (!group.actors.empty()) {
                        if (!engineOff) {
                            JoinGroup(sc, group, now, fx);
                        }
                        EmitGroup(std::move(group), fx);
                    }
                    // Gate rush: narrated at the pass; ForceOrgasm only (Orgasm_ApplyGroup source "gate").
                    if (!rushGroup.actors.empty()) {
                        fx.orgasms.push_back(std::move(rushGroup));
                    }
                }
                for (const auto sid : stale) {
                    webui_log::info("OrgasmEngine: scene {} no longer animating, dropped", sid);
                    DropSceneLocked(sid, fx);
                }
                FlushNarrations(now, false, fx);
            }
            RunEffects(fx);
            Hud::Tick();
        }

        class Interface final : public SKYRIMNET_SEXLAB_API::IOrgasmEngineV2
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
            void SetRates(float p, float ag, float v) noexcept override { OrgasmEngine::SetRates(p, ag, v); }
            std::uint32_t RegisterEventCallback(SKYRIMNET_SEXLAB_API::EngineEventCallback cb) noexcept override
            {
                return OrgasmEngine::RegisterEventCallback(cb);
            }
            void UnregisterEventCallback(std::uint32_t h) noexcept override { OrgasmEngine::UnregisterEventCallback(h); }
            bool SetStrategy(RE::Actor* a, SKYRIMNET_SEXLAB_API::Strategy s, RE::Actor* t) noexcept override
            {
                return OrgasmEngine::SetStrategy(a, static_cast<Strategy>(s), t);
            }
            SKYRIMNET_SEXLAB_API::Strategy GetStrategy(RE::Actor* a) noexcept override
            {
                return static_cast<SKYRIMNET_SEXLAB_API::Strategy>(OrgasmEngine::GetStrategy(a));
            }
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
            g_lastTick = GameNow();
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
        LoadStrategies();
        using SexLabNet::GetConfigBool;
        using SexLabNet::GetConfigFloat;
        Settings s;
        s.engineOff = SexLabNet::IsOrgasmEngineDisabled();
        // Engine off: no mode at all, so every mini-game guard (strategies, decisions, gate) is off too.
        s.miniGame = !s.engineOff && SexLabNet::IsMiniGameMode();
        s.passiveRate = GetConfigFloat("sexlab.enjoyment.passive_mult", 0.4f);
        s.aggressorRate = GetConfigFloat("sexlab.enjoyment.aggressor_mult", 0.45f);
        s.victimRate = GetConfigFloat("sexlab.enjoyment.victim_mult", 0.3f);
        s.jitterMin = GetConfigFloat("sexlab.enjoyment.jitter_min", 0.95f);
        s.jitterMax = std::max(s.jitterMin, GetConfigFloat("sexlab.enjoyment.jitter_max", 1.1f));
        s.domArousalScale = GetConfigFloat("sexlab.dom.arousal_scale", 0.2f);
        s.domArousalScalePlayer = GetConfigFloat("sexlab.dom.arousal_scale_player", 0.2f);
        s.arouseAmount = std::max(0.0f, GetConfigFloat("sexlab.minigame.arouse_amount", 2.4f));
        s.calmAmount = std::max(0.0f, GetConfigFloat("sexlab.minigame.calm_amount", 3.2f));
        s.staminaCost = GetConfigFloat("sexlab.minigame.stamina_cost", 8.0f);
        s.magickaCost = GetConfigFloat("sexlab.minigame.magicka_cost", 8.0f);
        s.edgeSeconds = GetConfigFloat("sexlab.minigame.edge_seconds", 4.0f);
        s.randomBonus = GetConfigFloat("sexlab.minigame.random_bonus", 10.0f);
        s.narrateWindow = GetConfigFloat("sexlab.minigame.narrate_window", 3.0f);
        s.groupJoin = std::clamp(GetConfigFloat("sexlab.enjoyment.group_join", 85.0f), 0.0f, kMaxEnjoyment);
        s.groupJoinFinal =
            std::clamp(GetConfigFloat("sexlab.enjoyment.group_join_final", 90.0f), 0.0f, kMaxEnjoyment);
        s.stageSpike = std::max(0.0f, GetConfigFloat("sexlab.enjoyment.stage_spike", 5.0f));
        s.gate = GetConfigBool("sexlab.ending.gate", true);
        s.gateLeadDefault = std::clamp(GetConfigFloat("sexlab.ending.gate_lead_default", 5.0f), 1.0f, 30.0f);
        s.bonusScale = std::max(0.0f, GetConfigFloat("sexlab.enjoyment.bonus_scale", 0.5f));
        s.bonusClamp = std::clamp(GetConfigFloat("sexlab.enjoyment.bonus_clamp", 0.75f), 0.0f, 1.0f);
        s.togetherK = std::clamp(GetConfigFloat("sexlab.enjoyment.together_k_range", 2.0f), 0.0f, 5.0f);
        s.miniGameBonusMult = std::max(0.0f, GetConfigFloat("sexlab.enjoyment.minigame_bonus_mult", 1.0f));
        s.npcInterval = std::clamp(GetConfigFloat("sexlab.minigame.npc_interval", 2.0f), 0.25f, 60.0f);
        s.npcStepMin = std::clamp(GetConfigFloat("sexlab.minigame.npc_step_min", 4.0f), 0.0f, 100.0f);
        s.npcStepMax = std::clamp(GetConfigFloat("sexlab.minigame.npc_step_max", 8.0f), s.npcStepMin, 100.0f);
        s.mutualTarget = std::clamp(GetConfigFloat("sexlab.enjoyment.mutual_target", 87.0f), 50.0f, kMaxEnjoyment);
        s.passiveShare = std::clamp(GetConfigFloat("sexlab.enjoyment.passive_share", 0.3f), 0.0f, 1.0f);
        s.defaultNormal = ParseStrategy(SexLabNet::GetConfigString("sexlab.minigame.default_strategy_normal", "Mutual"),
            Strategy::kMutual);
        s.defaultAggressor = ParseStrategy(
            SexLabNet::GetConfigString("sexlab.minigame.default_strategy_aggressor", "Selfish"), Strategy::kSelfish);
        s.defaultVictim = ParseStrategy(SexLabNet::GetConfigString("sexlab.minigame.default_strategy_victim", "Passive"),
            Strategy::kPassive);
        s.decisionStrategy = GetConfigBool("sexlab.minigame.decision_strategy", true);
        s.decisionMinConfidence =
            std::clamp(GetConfigFloat("sexlab.minigame.decision_min_confidence", 0.6f), 0.0f, 1.0f);
        {
            std::lock_guard lock(g_lock);
            g_settings = s;
            g_ratesOverridden = false;
        }
        webui_log::info(
            "OrgasmEngine: config minigame={} role mults={}/{}/{} jitter={}-{} dom scale={}/{} arouse={} calm={} "
            "cost={}/{} edge={}s random={} window={}s group_join={} group_join_final={} stage_spike={} gate={} gate_lead={}",
            s.miniGame, s.passiveRate, s.aggressorRate, s.victimRate, s.jitterMin, s.jitterMax, s.domArousalScale,
            s.domArousalScalePlayer, s.arouseAmount, s.calmAmount, s.staminaCost, s.magickaCost, s.edgeSeconds,
            s.randomBonus, s.narrateWindow, s.groupJoin, s.groupJoinFinal, s.stageSpike, s.gate, s.gateLeadDefault);
        webui_log::info("OrgasmEngine: config engine_off={} mode={} bonus scale={} clamp={} together_k={} minigame_bonus={} npc "
                        "interval={}s step={}-{} mutual_target={} passive_share={} defaults={}/{}/{}",
            s.engineOff, s.engineOff ? "sexlab" : s.miniGame ? "minigame" : "together", s.bonusScale, s.bonusClamp, s.togetherK, s.miniGameBonusMult,
            s.npcInterval, s.npcStepMin, s.npcStepMax, s.mutualTarget, s.passiveShare, InfoOf(s.defaultNormal).key,
            InfoOf(s.defaultAggressor).key, InfoOf(s.defaultVictim).key);
    }

    bool IsMiniGameEnabled()
    {
        std::lock_guard lock(g_lock);
        return g_settings.miniGame;
    }

    bool IsEngineDisabled()
    {
        std::lock_guard lock(g_lock);
        return g_settings.engineOff;
    }

    void BeginScene(std::int32_t sid, const std::vector<RE::Actor*>& actors, const std::vector<std::int32_t>& roles,
        const std::vector<float>& seeds, bool hasPlayer)
    {
        Effects fx;
        std::lock_guard lock(g_lock);
        SceneState& sc = g_scenes[sid];
        const bool resumed = !sc.actors.empty();
        if (!resumed) {
            sc.beganAt = Now();
        }
        sc.sid = sid;
        sc.hasPlayer = hasPlayer;
        sc.staleSince = 0.0;

        std::vector<RE::FormID> ids;
        std::vector<RE::FormID> newcomers;
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
                newcomers.push_back(id);
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
        if (sc.actors != ids) {
            static std::uint64_t s_generation = 0;
            sc.generation = ++s_generation;
        }
        sc.actors = std::move(ids);
        // Role defaults for new actors (after the roster, so scene-size checks see everyone). Not announced.
        for (const auto id : newcomers) {
            if (auto at = g_actors.find(id); at != g_actors.end()) {
                // Sticky auto play: on before the default, so the player gets the role default, not Passive.
                if (g_autoPlaySticky && IsPlayerFormId(id)) {
                    at->second.autoPlay = true;
                    webui_log::info("OrgasmEngine: auto play on (scene {}, sticky)", sid);
                }
                at->second.strategy = DefaultStrategy(sc, at->second);
                webui_log::info("OrgasmEngine: {:#x} default strategy {}", id, InfoOf(at->second.strategy).key);
            }
        }
        PostEffects(std::move(fx));
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
        if (changed) {
            sc.stageElapsed = 0.0;
        }
        // Stage advance in the same animation: a small enjoyment spike (SexLab's stage term). Together: the
        // curve already holds the stage term (only DOM slaves, on the passive rate, still get it).
        if (sc.staged && stageCount == sc.stageCount && stage > sc.stage && g_settings.stageSpike > 0.0f) {
            for (const auto id : sc.actors) {
                auto at = g_actors.find(id);
                if (at == g_actors.end() || !at->second.orgasmExpected) {
                    continue;
                }
                ActorState& st = at->second;
                if (st.dom) {
                    st.domProgress += g_settings.stageSpike;
                    st.domStepAcc += g_settings.stageSpike;
                } else if (g_settings.miniGame) {
                    st.enjoyment = std::clamp(st.enjoyment + g_settings.stageSpike, 0.0f, kMaxEnjoyment);
                }
            }
            webui_log::info("OrgasmEngine: scene {} stage {}/{} stage spike +{}", sid, stage, stageCount,
                g_settings.stageSpike);
        }
        sc.staged = true;
        if (changed && stageCount >= 2 && stage == stageCount - 1) {
            sc.penultElapsed = 0.0;
        }
        if (stageCount >= 2 && stage < stageCount - 1) {
            // Back before the last two stages: the gate rolls again; a pending rush / wait and a failed
            // final roll are dropped.
            for (const auto id : sc.actors) {
                if (auto at = g_actors.find(id); at != g_actors.end()) {
                    if (sc.gateDone || sc.gateAwait) {
                        at->second.rushing = false;
                    }
                    at->second.finalRollFailed = false;
                }
            }
            sc.gateDone = false;
            sc.gateAwait = false;
        }
        if (stageCount > 0 && stage >= stageCount) {
            sc.gateAwait = false;  // final stage reached (voice, SexLab's timer or a manual advance)
        }
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
        // Real timers: NPC steps may start. SexLab's are empty at first (StrategyStep's untimed grace covers
        // scenes that never send any).
        if (!stageSecs.empty()) {
            sc.ratesKnown = true;
        }
        if (sc.stageSecs == stageSecs && sc.leadIn == leadIn) {
            return;
        }
        ApplyStageTimers(sc, stageSecs, leadIn);
        CalibrateMiniGame(sc);
        // New animation: the Together curve starts over from each actor's current enjoyment.
        sc.stageElapsed = 0.0;
        for (const auto id : sc.actors) {
            if (auto at = g_actors.find(id); at != g_actors.end()) {
                at->second.curveP = 0.0f;
            }
        }
        webui_log::info("OrgasmEngine: scene {} stages={} leadIn={} targetSecs={:.1f} baseRate={:.3f}/s{} regen={:.1f}/min",
            sid, stageSecs.size(), leadIn, sc.targetSecs, sc.baseRate > 0.0f ? sc.baseRate : kFallbackRate,
            sc.baseRate > 0.0f ? "" : " (fallback)",
            sc.regenRate > 0.0f ? sc.regenRate * 60.0f : g_settings.regenDecay);
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

    void GateNarrationSent(std::int32_t sid, std::int64_t mark)
    {
        std::lock_guard lock(g_lock);
        const auto it = g_scenes.find(sid);
        if (it == g_scenes.end() || !it->second.gateAwait) {
            return;
        }
        it->second.gateSpeechMark =
            mark >= 0 ? static_cast<std::uint64_t>(mark) : NarrationTiming::SpeakerMark();
        it->second.gateMarked = true;
        webui_log::info("OrgasmEngine: scene {} gate narration sent, waiting for speech (mark {})", sid,
            it->second.gateSpeechMark);
    }

    std::vector<RE::FormID> SceneActors(std::int32_t sid)
    {
        std::lock_guard lock(g_lock);
        const auto it = g_scenes.find(sid);
        return it == g_scenes.end() ? std::vector<RE::FormID>{} : it->second.actors;
    }

    bool IsGateScene(std::int32_t sid)
    {
        std::lock_guard lock(g_lock);
        const auto it = g_scenes.find(sid);
        if (it == g_scenes.end()) {
            return false;
        }
        const SceneState& sc = it->second;
        // Same test as Tick's aiGate && useGate.
        const bool timedScene = sc.baseRate > 0.0f && sc.stageSecs.size() >= 2 && sc.stageCount >= 2;
        return g_settings.miniGame && g_settings.gate && SceneAiDriven(sc) && timedScene && !sc.leadIn;
    }

    void SetEndingTarget(std::int32_t sid, RE::Actor* lead, std::int32_t target)
    {
        std::lock_guard lock(g_lock);
        const auto it = g_scenes.find(sid);
        if (it == g_scenes.end()) {
            return;
        }
        SceneState& sc = it->second;
        const RE::FormID id = lead ? lead->GetFormID() : 0;
        const std::int32_t value = id ? std::max(0, target) : 0;
        if (sc.endingLead != id || sc.endingTarget != value) {
            sc.endingLead = id;
            sc.endingTarget = value;
            webui_log::info("OrgasmEngine: scene {} ending lead {:#x} target {}", sid, id, value);
        }
    }

    float FinalStageRemaining(std::int32_t sid)
    {
        std::lock_guard lock(g_lock);
        const auto it = g_scenes.find(sid);
        if (it == g_scenes.end()) {
            return -1.0f;
        }
        const SceneState& sc = it->second;
        if (sc.stageCount <= 0 || sc.stage < sc.stageCount || sc.leadIn || sc.stageSecs.empty() ||
            sc.stageSecs.back() <= 0.0f) {
            return -1.0f;
        }
        return std::max(0.0f, static_cast<float>(sc.stageSecs.back() - sc.finalElapsed));
    }

    bool IsPlayerScenePaused()
    {
        return IsScenePaused(RE::PlayerCharacter::GetSingleton());
    }

    bool IsScenePaused(RE::Actor* anchor)
    {
        std::lock_guard lock(g_lock);
        const auto* st = Find(anchor);
        const SceneState* sc = st ? SceneOf(*st) : nullptr;
        return sc && sc->paused;
    }

    bool GetPlayerSceneStage(int& stage, int& count)
    {
        return GetSceneStage(RE::PlayerCharacter::GetSingleton(), stage, count);
    }

    bool GetSceneStage(RE::Actor* anchor, int& stage, int& count)
    {
        std::lock_guard lock(g_lock);
        const auto* st = Find(anchor);
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

    void SetBonusInputs(RE::Actor* actor, const std::vector<float>& ownSkills, const std::vector<float>& partnerSkills,
        std::int32_t lowestRank, std::int32_t highestRank, std::int32_t actSkill)
    {
        std::lock_guard lock(g_lock);
        if (auto* st = Find(actor)) {
            st->bonus = ComputeBonus(ownSkills, partnerSkills, lowestRank, highestRank, actSkill, st->role);
            webui_log::info("OrgasmEngine: {:#x} bonus {:.3f} (role {} ranks {}/{} act {} skilled {})", st->id,
                st->bonus, static_cast<std::int32_t>(st->role), lowestRank, highestRank, actSkill,
                ownSkills.size() > 5 && partnerSkills.size() > 5);
        }
    }

    namespace
    {
        // Caller holds g_lock. SetStrategy's checks (allowed, valid target; a missing target picks one), then
        // ApplyStrategy. narrate false: decision-made (short-term event instead of narration).
        bool SetStrategyLocked(const SceneState& sc, ActorState& st, Strategy strategy, RE::FormID targetId,
            bool narrate, Effects& fx)
        {
            if (!StrategyAllowed(sc, st, strategy)) {
                webui_log::info("OrgasmEngine: {:#x} strategy {} not allowed (role {} minigame {})", st.id,
                    InfoOf(strategy).key, static_cast<std::int32_t>(st.role), g_settings.miniGame);
                return false;
            }
            if (NeedsTarget(strategy)) {
                const auto valid = [&](RE::FormID id) {
                    const auto at = g_actors.find(id);
                    return id != st.id && InScene(sc, id) && at != g_actors.end();
                };
                if (!valid(targetId)) {
                    targetId = PickOther(sc, st.id, true, false);
                }
                if (!valid(targetId)) {
                    return false;
                }
            }
            ApplyStrategy(sc, st, strategy, targetId, true, fx, narrate);
            return true;
        }

        const char* RoleName(Role role)
        {
            switch (role) {
            case Role::kAggressor:
                return "aggressor";
            case Role::kVictim:
                return "victim";
            default:
                return "partner";
            }
        }

        // Same bands as the 0050 prompt.
        const char* ArousalBand(float enjoyment)
        {
            if (enjoyment >= 90.0f) {
                return "on the verge of orgasm";
            }
            if (enjoyment >= 75.0f) {
                return "close to orgasm";
            }
            if (enjoyment >= 50.0f) {
                return "very aroused";
            }
            if (enjoyment >= 25.0f) {
                return "aroused";
            }
            return "barely aroused";
        }

        // Decision option text for strategy s (target: Deny / Tease / Focused).
        std::string OptionText(const ActorState& st, Strategy s, RE::FormID target)
        {
            std::string text = InfoOf(s).option;
            FillStrategyText(text, st.id, target);
            return text;
        }
    }

    bool SetStrategy(RE::Actor* actor, Strategy strategy, RE::Actor* target, StrategySource source)
    {
        Effects fx;
        bool ok = false;
        {
            std::lock_guard lock(g_lock);
            auto* st = Find(actor);
            const SceneState* sc = st ? SceneOf(*st) : nullptr;
            if (!st || !sc) {
                webui_log::warn("OrgasmEngine: SetStrategy for unmanaged actor {:#x}", actor ? actor->GetFormID() : 0);
                return false;
            }
            ok = SetStrategyLocked(*sc, *st, strategy, target ? target->GetFormID() : 0,
                source != StrategySource::kDecision, fx);
        }
        PostEffects(std::move(fx));
        return ok;
    }

    bool GetStrategyDecisionInput(RE::Actor* actor, DecisionInput& out)
    {
        std::lock_guard lock(g_lock);
        const auto* st = Find(actor);
        const SceneState* sc = st ? SceneOf(*st) : nullptr;
        if (!st || !sc || !g_settings.miniGame || !AiDriven(*st)) {
            return false;
        }
        out = DecisionInput{};
        out.sid = sc->sid;
        out.generation = sc->generation;
        out.id = st->id;
        out.name = NameOf(actor);
        out.role = RoleName(st->role);
        out.arousal = ArousalBand(st->enjoyment);
        out.orgasms = st->orgasmCount;
        out.expectsOrgasm = st->orgasmExpected;
        out.currentKey = InfoOf(st->strategy).key;
        for (std::size_t i = 0; i < sc->actors.size(); ++i) {
            const RE::FormID id = sc->actors[i];
            out.slots.emplace_back("p" + std::to_string(i + 1), id);
            const auto at = g_actors.find(id);
            if (id == st->id || at == g_actors.end()) {
                continue;
            }
            RE::Actor* other = ActorFor(id);
            DecisionPartner p;
            p.id = id;
            p.name = NameOf(other);
            p.isPlayer = IsPlayer(other);
            p.role = RoleName(at->second.role);
            p.arousal = ArousalBand(at->second.enjoyment);
            p.orgasms = at->second.orgasmCount;
            out.partners.push_back(std::move(p));
        }
        for (std::int32_t i = 0; i < static_cast<std::int32_t>(Strategy::kCount); ++i) {
            const auto s = static_cast<Strategy>(i);
            if (!StrategyAllowed(*sc, *st, s)) {
                continue;
            }
            if (!NeedsTarget(s)) {
                out.options.push_back({ kStrategyKeys[i], OptionText(*st, s, 0) });
                continue;
            }
            // One option per valid target (SetStrategyLocked's rule).
            for (std::size_t j = 0; j < sc->actors.size(); ++j) {
                const RE::FormID id = sc->actors[j];
                const auto at = g_actors.find(id);
                if (id == st->id || at == g_actors.end()) {
                    continue;
                }
                out.options.push_back(
                    { std::string(kStrategyKeys[i]) + "_p" + std::to_string(j + 1), OptionText(*st, s, id) });
            }
        }
        return true;
    }

    DecisionResult ApplyStrategyDecision(RE::Actor* actor, const DecisionInput& in, const std::string& key,
        double confidence)
    {
        Effects fx;
        bool changed = false;
        {
            std::lock_guard lock(g_lock);
            auto* st = Find(actor);
            const SceneState* sc = st ? SceneOf(*st) : nullptr;
            if (!st || !sc || sc->sid != in.sid || sc->generation != in.generation || !g_settings.miniGame) {
                return DecisionResult::kDropped;
            }
            // "<key>_p<slot>": target strategy.
            std::string base = key;
            RE::FormID targetId = 0;
            if (const auto pos = key.rfind("_p"); pos != std::string::npos) {
                const std::string slot = key.substr(pos + 1);
                for (const auto& [name, id] : in.slots) {
                    if (name == slot) {
                        targetId = id;
                        base = key.substr(0, pos);
                    }
                }
            }
            const Strategy s = ParseStrategy(base, Strategy::kCount);
            if (s == Strategy::kCount) {
                webui_log::warn("OrgasmEngine: decision for {:#x}: unknown key '{}'", st->id, key);
                return DecisionResult::kUnknown;
            }
            if (s == st->strategy && (!NeedsTarget(s) || targetId == st->strategyTarget)) {
                return DecisionResult::kKept;
            }
            if (confidence >= 0.0 && confidence < g_settings.decisionMinConfidence) {
                return DecisionResult::kLowConfidence;
            }
            changed = SetStrategyLocked(*sc, *st, s, targetId, false, fx);
        }
        PostEffects(std::move(fx));
        return changed ? DecisionResult::kChanged : DecisionResult::kKept;
    }

    bool IsStrategyDecisionEnabled()
    {
        std::lock_guard lock(g_lock);
        return g_settings.miniGame && g_settings.decisionStrategy;
    }

    double GetDecisionMinConfidence()
    {
        std::lock_guard lock(g_lock);
        return g_settings.decisionMinConfidence;
    }

    std::vector<RE::FormID> SceneNpcs(std::int32_t sid)
    {
        std::vector<RE::FormID> out;
        std::lock_guard lock(g_lock);
        if (const auto it = g_scenes.find(sid); it != g_scenes.end()) {
            for (const auto id : it->second.actors) {
                if (const auto at = g_actors.find(id); at != g_actors.end() && AiDriven(at->second)) {
                    out.push_back(id);
                }
            }
        }
        return out;
    }

    Strategy GetStrategy(RE::Actor* actor)
    {
        std::lock_guard lock(g_lock);
        const auto* st = Find(actor);
        return st ? st->strategy : Strategy::kPassive;
    }

    std::string GetStrategyText(RE::Actor* actor)
    {
        std::lock_guard lock(g_lock);
        const auto* st = Find(actor);
        if (!st || !g_settings.miniGame || !AiDriven(*st)) {
            return "";
        }
        return StrategyPhrase(*st);
    }

    float GetStaminaRegen(RE::Actor* actor)
    {
        std::lock_guard lock(g_lock);
        const auto* st = Find(actor);
        return st && g_settings.staminaFatigue ? st->regen : 100.0f;
    }

    namespace
    {
        struct PunishMethod
        {
            const char* key;
            const char* act;  // "<punisher> punishes <target> by <act>"; {target}: "<target>" or "<target>'s <part>"
        };
        constexpr PunishMethod kPunishMethods[] = {
            { "slap", "slapping {target}" },
            { "pinch", "pinching {target}" },
            { "punch", "punching {target}" },
            { "pull", "pulling {target}" },
        };

        // Caller holds g_lock. The actor's managed scene (any role, any orgasm mode).
        const SceneState* PunisherScene(RE::Actor* punisher)
        {
            const auto* pst = Find(punisher);
            if (!pst) {
                return nullptr;
            }
            const auto it = g_scenes.find(pst->sid);
            return it != g_scenes.end() ? &it->second : nullptr;
        }

        std::string Trimmed(const std::string& s)
        {
            const auto b = s.find_first_not_of(" \t\r\n");
            if (b == std::string::npos) {
                return "";
            }
            const auto e = s.find_last_not_of(" \t\r\n.");
            return e == std::string::npos || e < b ? "" : s.substr(b, e - b + 1);
        }

        // Caller holds g_lock. The scene has the player, or the player drives one of its actors: its narrations are
        // DirectNarrations; any other scene's are DirectNarration_Optional.
        bool PlayerScene(const SceneState& sc)
        {
            if (sc.hasPlayer) {
                return true;
            }
            for (const auto id : sc.actors) {
                if (const auto at = g_actors.find(id); at != g_actors.end() && at->second.playerDriven) {
                    return true;
                }
            }
            return false;
        }

        // Ask / order / answer / punishment narration with the mod's scene rule (see PlayerScene).
        void NarrateRequest(const std::string& msg, RE::Actor* source, RE::Actor* target, bool direct)
        {
            if (msg.empty()) {
                return;
            }
            if (direct) {
                NarrateDirect(msg, source, target);
                return;
            }
            DispatchShell("Effect_NarrateOptional",
                RE::MakeFunctionArguments(RE::BSFixedString(msg.c_str()), std::move(source), std::move(target)));
        }

        // Caller holds g_lock. "<key>" or "<key>_p<slot>" of the actor's current strategy (a request's key).
        std::string CurrentRequestKey(const SceneState& sc, const ActorState& st)
        {
            std::string key = kStrategyKeys[static_cast<std::size_t>(st.strategy)];
            if (NeedsTarget(st.strategy)) {
                for (std::size_t i = 0; i < sc.actors.size(); ++i) {
                    if (sc.actors[i] == st.strategyTarget) {
                        return key + "_p" + std::to_string(i + 1);
                    }
                }
            }
            return key;
        }

        // Caller holds g_lock. A request key -> strategy and target; false when unknown, not allowed for the
        // actor or the target is not another actor of the scene.
        bool ParseRequest(const SceneState& sc, const ActorState& st, const std::string& key, Strategy& s,
            RE::FormID& target)
        {
            std::string base = key;
            target = 0;
            if (const auto pos = key.rfind("_p"); pos != std::string::npos) {
                const std::string digits = key.substr(pos + 2);
                if (!digits.empty() && std::all_of(digits.begin(), digits.end(), [](unsigned char c) {
                        return std::isdigit(c) != 0;
                    })) {
                    const auto slot = static_cast<std::size_t>(std::stoul(digits));
                    if (slot >= 1 && slot <= sc.actors.size()) {
                        target = sc.actors[slot - 1];
                        base = key.substr(0, pos);
                    }
                }
            }
            s = ParseStrategy(base, Strategy::kCount);
            if (s == Strategy::kCount || !StrategyAllowed(sc, st, s)) {
                return false;
            }
            if (!NeedsTarget(s)) {
                target = 0;
                return true;
            }
            return target != 0 && target != st.id && InScene(sc, target) && g_actors.count(target) != 0;
        }

        // Caller holds g_lock. The strategy's order phrase ("focus on Bob's pleasure"), {target} filled.
        std::string RequestText(const ActorState& st, Strategy s, RE::FormID target)
        {
            std::string text = InfoOf(s).order;
            FillStrategyText(text, st.id, target);
            return text;
        }

        // Caller holds g_lock. Keeps one reason per (by, strategyKey) for a keyed request; the last kPunishKept.
        void AddReasonLocked(ActorState& st, PunishRecord rec)
        {
            auto& list = st.reasons;
            if (!rec.strategyKey.empty() &&
                std::any_of(list.begin(), list.end(), [&](const PunishRecord& r) {
                    return r.by == rec.by && r.strategyKey == rec.strategyKey;
                })) {
                return;
            }
            list.push_back(std::move(rec));
            if (list.size() > kPunishKept) {
                list.erase(list.begin());
            }
        }

        // Game thread. The target's answer to a request arrived: "<target> agrees to|refuses <by>'s request to
        // <text>." as its own narration; a refusal is kept as a punishment reason, an agreement clears it. key "":
        // a custom request (agreed when the decision changed the strategy). Nothing when no decision was made.
        void FinishRequest(RE::FormID byId, RE::FormID targetId, bool order, const std::string& key,
            const std::string& text, bool direct, DecisionResult result)
        {
            if (result != DecisionResult::kChanged && result != DecisionResult::kKept &&
                result != DecisionResult::kLowConfidence) {
                return;
            }
            RE::Actor* by = ActorFor(byId);
            RE::Actor* target = ActorFor(targetId);
            if (!by || !target) {
                return;
            }
            bool agrees = false;
            {
                std::lock_guard lock(g_lock);
                const auto at = g_actors.find(targetId);
                const SceneState* sc = at != g_actors.end() ? SceneOf(at->second) : nullptr;
                if (!sc) {
                    return;
                }
                ActorState& st = at->second;
                agrees = key.empty() ? result == DecisionResult::kChanged : CurrentRequestKey(*sc, st) == key;
                if (agrees) {
                    auto& list = st.reasons;
                    list.erase(std::remove_if(list.begin(), list.end(),
                                   [&](const PunishRecord& r) {
                                       return r.by == byId && (key.empty() ? r.request == text : r.strategyKey == key);
                                   }),
                        list.end());
                } else {
                    PunishRecord rec;
                    rec.by = byId;
                    rec.target = targetId;
                    rec.reason = NameOf(target) + " refused " + NameOf(by) + "'s " + (order ? "order" : "request") +
                                 " to " + text;
                    rec.strategyKey = key;
                    rec.request = text;
                    AddReasonLocked(st, std::move(rec));
                }
            }
            const std::string line =
                NameOf(target) + (agrees ? " agrees to " : " refuses ") + NameOf(by) + "'s request to " + text + ".";
            webui_log::info("OrgasmEngine: request answer: {}", line);
            NarrateRequest(line, target, by, direct);
        }

        struct PunishPlan
        {
            std::string line;         // "Bob punishes Nina by pinching Nina's nipples, because ..."
            bool direct = false;      // PlayerScene
            // The refused request the reason came from (empty key: none).
            RE::FormID requestBy = 0;
            bool requestOrder = false;
            std::string requestKey;
            std::string requestText;
        };

        // Caller holds g_lock. "<punisher> punishes <target> by pinching <target>'s nipples, because <reason>."
        // Weak spell: "... by hitting <target>'s ass with Sparks". Free text is the method as typed
        // ("biting <target>'s lips"). location "body" / "" names no part. Empty line when refused.
        PunishPlan PunishLocked(RE::Actor* punisherActor, RE::FormID target, const std::string& method,
            const std::string& location, const std::string& reason, const Aid::WeakSpell* spell)
        {
            PunishPlan plan;
            const SceneState* sc = PunisherScene(punisherActor);
            RE::Actor* targetActor = ActorFor(target);
            if (!sc || !targetActor || targetActor == punisherActor || !InScene(*sc, target)) {
                webui_log::warn("OrgasmEngine: Punish refused for {:#x} (no punisher scene / not in it)", target);
                return plan;
            }
            const std::string part = location == "body" ? "" : location;
            const std::string name = NameOf(targetActor);
            const std::string on = part.empty() ? name : name + "'s " + part;
            const std::string how = Trimmed(method);
            std::string act;
            if (spell) {
                act = "hitting " + on + " with " + spell->name;
            } else {
                for (const auto& m : kPunishMethods) {
                    if (how == m.key) {
                        act = m.act;
                    }
                }
                if (act.empty()) {
                    act = how.empty() ? kPunishMethods[0].act : how + " {target}";
                }
                ReplaceAll(act, "{target}", on);
            }
            std::string why = Trimmed(reason);
            // The line adds "because": "because Nina refused ..." would read "because because Nina refused ...".
            if (why.size() > 8 && _strnicmp(why.c_str(), "because ", 8) == 0) {
                why = Trimmed(why.substr(8));
            }
            plan.line = NameOf(punisherActor) + " punishes " + name + " by " + act +
                        (why.empty() ? "" : ", because " + why) + ".";
            plan.direct = PlayerScene(*sc);
            if (const auto at = g_actors.find(target); at != g_actors.end() && !why.empty()) {
                for (const auto& r : at->second.reasons) {
                    if (r.reason == why && !r.strategyKey.empty()) {
                        plan.requestBy = r.by;
                        plan.requestOrder = r.reason.find(" order to ") != std::string::npos;
                        plan.requestKey = r.strategyKey;
                        plan.requestText = r.request;
                    }
                }
            }
            webui_log::info("OrgasmEngine: {:#x} punishes {:#x} by '{}' on '{}' because '{}'",
                punisherActor->GetFormID(), target, method, location, why);
            return plan;
        }

        // Game thread. The hit has landed (feeling: Whipped's text, "" when none): narrate the punishment, then
        // ask the target's strategy decision with that narration as last_line; a punishment for a refused request
        // gets the agree / refuse answer.
        void ContinuePunish(RE::FormID punisherId, RE::FormID targetId, const PunishPlan& plan,
            const std::string& method, const std::string& location, RE::FormID spell, float spellDamage,
            const std::string& feeling, bool feelingFromWhipped)
        {
            RE::Actor* punisher = ActorFor(punisherId);
            RE::Actor* target = ActorFor(targetId);
            if (!punisher || !target) {
                return;
            }
            const std::string text = feeling.empty() ? plan.line : plan.line + " " + feeling;
            webui_log::info("OrgasmEngine: punishment of {:#x} narrated: {}", targetId, text);
            bool whippedNarrates = false;
            if (!feelingFromWhipped) {
                // Older Whipped (no External_TortureText): the hit goes through External_Damage, which narrates.
                whippedNarrates = Whipped::PunishHit(punisher, target, text, method, location, spell);
            }
            if (!whippedNarrates) {
                NarrateRequest(text, punisher, target, plan.direct);
            }
            if (spell) {
                Aid::QueueWeakSpellHit(punisher, target, spell,
                    feelingFromWhipped || whippedNarrates ? 0.0f : spellDamage);
            }
            StrategyDecision::RequestAnswer(targetId, "punished", text,
                [plan, targetId](DecisionResult result) {
                    if (!plan.requestKey.empty()) {
                        FinishRequest(plan.requestBy, targetId, plan.requestOrder, plan.requestKey, plan.requestText,
                            plan.direct, result);
                    }
                });
        }
    }

    bool GetPunishInfo(RE::Actor* punisher, std::vector<PunishTarget>& targets)
    {
        targets.clear();
        std::lock_guard lock(g_lock);
        const SceneState* sc = punisher ? PunisherScene(punisher) : nullptr;
        if (!sc) {
            return false;
        }
        for (const auto id : sc->actors) {
            RE::Actor* actor = ActorFor(id);
            if (actor && actor != punisher) {
                targets.push_back({ id, NameOf(actor) });
            }
        }
        return true;
    }

    std::vector<RequestOption> GetRequestOptions(RE::FormID target)
    {
        std::vector<RequestOption> out;
        std::lock_guard lock(g_lock);
        const auto it = g_actors.find(target);
        const SceneState* sc = it != g_actors.end() ? SceneOf(it->second) : nullptr;
        if (!sc) {
            return out;
        }
        const ActorState& st = it->second;
        for (std::int32_t i = 0; i < static_cast<std::int32_t>(Strategy::kCount); ++i) {
            const auto s = static_cast<Strategy>(i);
            if (!StrategyAllowed(*sc, st, s)) {
                continue;
            }
            if (!NeedsTarget(s)) {
                if (s != st.strategy) {
                    out.push_back({ kStrategyKeys[i], RequestText(st, s, 0) });
                }
                continue;
            }
            // One per other actor (GetStrategyDecisionInput's rule).
            for (std::size_t j = 0; j < sc->actors.size(); ++j) {
                const RE::FormID id = sc->actors[j];
                if (id == st.id || g_actors.find(id) == g_actors.end() || (s == st.strategy && id == st.strategyTarget)) {
                    continue;
                }
                out.push_back({ std::string(kStrategyKeys[i]) + "_p" + std::to_string(j + 1), RequestText(st, s, id) });
            }
        }
        return out;
    }

    std::vector<std::string> GetPunishReasons(RE::FormID target)
    {
        std::vector<std::string> out;
        std::lock_guard lock(g_lock);
        if (const auto it = g_actors.find(target); it != g_actors.end() && SceneOf(it->second)) {
            for (const auto& r : it->second.reasons) {
                if (std::find(out.begin(), out.end(), r.reason) == out.end()) {
                    out.push_back(r.reason);
                }
            }
        }
        return out;
    }

    void AddPunishReason(RE::Actor* by, RE::Actor* target, const std::string& reason)
    {
        const std::string why = Trimmed(reason);
        if (why.empty()) {
            return;
        }
        std::lock_guard lock(g_lock);
        if (auto* st = Find(target); st && SceneOf(*st)) {
            PunishRecord rec;
            rec.by = by ? by->GetFormID() : 0;
            rec.target = st->id;
            rec.reason = why;
            rec.type = "external";
            auto& list = st->reasons;
            if (std::none_of(list.begin(), list.end(), [&](const PunishRecord& r) { return r.reason == why; })) {
                AddReasonLocked(*st, std::move(rec));
            }
        }
    }

    bool AskOrderNarrated(RE::Actor* by, RE::FormID target, bool order, const std::string& requestKey,
        const std::string& customText)
    {
        if (!by) {
            return false;
        }
        std::string text;
        bool direct = false;
        {
            std::lock_guard lock(g_lock);
            const SceneState* sc = PunisherScene(by);
            const auto at = g_actors.find(target);
            if (!sc || at == g_actors.end() || target == by->GetFormID() || !InScene(*sc, target)) {
                webui_log::warn("OrgasmEngine: ask / order refused for {:#x} (no scene / not in it)", target);
                return false;
            }
            if (!requestKey.empty()) {
                Strategy s = Strategy::kCount;
                RE::FormID t = 0;
                if (!ParseRequest(*sc, at->second, requestKey, s, t)) {
                    webui_log::warn("OrgasmEngine: ask / order refused: '{}' not allowed for {:#x}", requestKey, target);
                    return false;
                }
                text = RequestText(at->second, s, t);
            } else {
                text = Trimmed(customText);
            }
            direct = PlayerScene(*sc);
        }
        RE::Actor* targetActor = ActorFor(target);
        if (text.empty() || !targetActor) {
            return false;
        }
        const std::string line = NameOf(by) + (order ? " orders " : " asks ") + NameOf(targetActor) + " to " + text + ".";
        const RE::FormID byId = by->GetFormID();
        // The decision and the narrations run on the game thread (Papyrus calls this from a VM thread).
        SKSE::GetTaskInterface()->AddTask([byId, target, order, requestKey, text, line, direct]() {
            RE::Actor* asker = ActorFor(byId);
            RE::Actor* asked = ActorFor(target);
            if (!asker || !asked) {
                return;
            }
            NarrateRequest(line, asker, asked, direct);
            StrategyDecision::RequestAnswer(target, order ? "ordered" : "asked", line,
                [byId, target, order, requestKey, text, direct](DecisionResult result) {
                    FinishRequest(byId, target, order, requestKey, text, direct, result);
                });
        });
        return true;
    }

    bool PunishNarrated(RE::Actor* punisher, RE::FormID target, const std::string& method, const std::string& location,
        const std::string& reason)
    {
        if (!punisher) {
            return false;
        }
        // Weak attack spells read the punisher's spell lists outside the engine lock.
        const auto spells = Aid::WeakAttackSpells(punisher);
        const Aid::WeakSpell* spell = Aid::FindWeakSpell(spells, method);
        PunishPlan plan;
        {
            std::lock_guard lock(g_lock);
            plan = PunishLocked(punisher, target, method, location, reason, spell);
        }
        if (plan.line.empty()) {
            return false;
        }
        const RE::FormID punisherId = punisher->GetFormID();
        const RE::FormID spellForm = spell ? spell->form : 0;
        const float spellDamage = spell ? spell->minDamage : 0.0f;
        // The hit, the narrations and the decision run on the game thread.
        SKSE::GetTaskInterface()->AddTask([punisherId, target, plan, method, location, spellForm, spellDamage]() {
            RE::Actor* p = ActorFor(punisherId);
            RE::Actor* t = ActorFor(target);
            if (!p || !t) {
                return;
            }
            // Whipped lands the hit silently and returns the feeling text; narrate it with the line.
            const bool asked = Whipped::PunishText(p, t, method, location, spellForm,
                [punisherId, target, plan, method, location, spellForm, spellDamage](std::string feeling) {
                    SKSE::GetTaskInterface()->AddTask(
                        [punisherId, target, plan, method, location, spellForm, spellDamage, feeling]() {
                            ContinuePunish(punisherId, target, plan, method, location, spellForm, spellDamage, feeling,
                                true);
                        });
                });
            if (!asked) {
                ContinuePunish(punisherId, target, plan, method, location, spellForm, spellDamage, "", false);
            }
        });
        return true;
    }

    bool CanPunish(RE::Actor* actor)
    {
        std::lock_guard lock(g_lock);
        const SceneState* sc = actor ? PunisherScene(actor) : nullptr;
        if (!sc) {
            return false;
        }
        for (const auto id : sc->actors) {
            RE::Actor* a = ActorFor(id);
            if (a && a != actor) {
                return true;
            }
        }
        return false;
    }

    void EndScene(std::int32_t sid)
    {
        Effects fx;
        {
            std::lock_guard lock(g_lock);
            FlushNarrations(Now(), true, fx);
            DropSceneLocked(sid, fx);
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
            SpendRegen(*st, g_settings.regenOrgasmCost, fx);
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
            // stash + window (individual=false), so both land in one DirectNarration. Engine off: SexLab
            // sends each actor's own orgasm, so no join.
            const SceneState* sc = g_settings.engineOff ? nullptr : SceneOf(*st);
            if (sc) {
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
            // Engine off: unblock only; SexLab decides the orgasm and the caller narrates the allow.
            if (!sc || g_settings.engineOff) {
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
                // The allowed actor takes the normal orgasm test now, so a pass carries the allow prefix.
                const bool wants = id == st->id ? WantsOrgasm(other, now, true) : other.enjoyment >= kMaxEnjoyment;
                if (CanOrgasmNow(other, now) && wants) {
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
            const float next = std::clamp(value, 0.0f, kMaxEnjoyment);
            // Logged on change only: with the engine off, Mirror_Apply pulls SexLab's value every second.
            if (next != st->enjoyment) {
                st->enjoyment = next;
                webui_log::info("OrgasmEngine: {} set {:#x} enjoyment {}", source, st->id, st->enjoyment);
            }
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
        bool ok = false;
        {
            std::lock_guard lock(g_lock);
            auto* tst = Find(target);
            if (!tst || g_settings.engineOff) {
                return false;
            }
            ok = ArouseLocked(who, target, *tst, g_settings.arouseAmount * std::max(0.0f, mult), true, fx);
        }
        PostEffects(std::move(fx));
        return ok;
    }

    bool Calm(RE::Actor* who, RE::Actor* target, float mult)
    {
        if (!who || !target) {
            return false;
        }
        Effects fx;
        bool ok = false;
        {
            std::lock_guard lock(g_lock);
            auto* tst = Find(target);
            if (!tst || g_settings.engineOff) {
                return false;
            }
            ok = CalmLocked(who, target, *tst, g_settings.calmAmount * std::max(0.0f, mult), true, fx);
        }
        PostEffects(std::move(fx));
        return ok;
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
        return CurrentAv(who, RE::ActorValue::kMagicka) >= CalmCost(Find(who));
    }

    bool GetPlayerScene(std::vector<ActorView>& out)
    {
        return GetActorScene(RE::PlayerCharacter::GetSingleton(), out);
    }

    bool GetActorScene(RE::Actor* anchor, std::vector<ActorView>& out)
    {
        out.clear();
        std::lock_guard lock(g_lock);
        const auto* pst = Find(anchor);
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
            v.dom = at->second.dom;
            v.denied = at->second.sceneBlocked;
            if (g_settings.miniGame && AiDriven(at->second)) {
                v.strategy = HudLabel(at->second);
            }
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
        return StepSceneSpeed(RE::PlayerCharacter::GetSingleton(), dir);
    }

    int StepSceneSpeed(RE::Actor* anchor, int dir)
    {
        std::lock_guard lock(g_lock);
        auto* st = Find(anchor);
        SceneState* sc = st ? SceneOf(*st) : nullptr;
        if (!sc) {
            return -1;
        }
        // Scale = level speed / style speed, so the effective speed lands exactly on the level.
        const float current = AnimSpeed::Get(anchor);
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
        return GetSceneSpeedLevel(RE::PlayerCharacter::GetSingleton());
    }

    int GetSceneSpeedLevel(RE::Actor* anchor)
    {
        {
            std::lock_guard lock(g_lock);
            auto* st = Find(anchor);
            if (!st || !SceneOf(*st)) {
                return -1;
            }
        }
        return NearestSpeedLevel(AnimSpeed::Get(anchor));
    }

    bool SetAutoPlay(bool on)
    {
        Effects fx;
        {
            std::lock_guard lock(g_lock);
            auto* st = Find(RE::PlayerCharacter::GetSingleton());
            const SceneState* sc = st ? SceneOf(*st) : nullptr;
            if (!st || !sc) {
                return false;
            }
            g_autoPlaySticky = on;
            if (st->autoPlay == on) {
                return true;
            }
            st->autoPlay = on;
            if (on) {
                // The strategy BeginScene gave the player (Passive: none allowed then) is a placeholder: the
                // role default until the decision model picks one.
                st->strategy = DefaultStrategy(*sc, *st);
                st->strategyTarget = 0;
                st->nextStepAt = Now();
            }
            webui_log::info("OrgasmEngine: auto play {} (scene {}, strategy {})", on ? "on" : "off", sc->sid,
                InfoOf(st->strategy).key);
        }
        PostEffects(std::move(fx));
        return true;
    }

    bool IsAutoPlay()
    {
        std::lock_guard lock(g_lock);
        const auto* st = Find(RE::PlayerCharacter::GetSingleton());
        return st && SceneOf(*st) && st->autoPlay;
    }

    bool SetPlayerDriven(RE::Actor* actor, bool on)
    {
        Effects fx;
        {
            std::lock_guard lock(g_lock);
            auto* st = Find(actor);
            const SceneState* sc = st ? SceneOf(*st) : nullptr;
            if (!st || !sc || IsPlayer(actor)) {
                return false;
            }
            if (st->playerDriven == on) {
                return true;
            }
            st->playerDriven = on;
            if (!on && g_settings.miniGame && !StrategyAllowed(*sc, *st, st->strategy)) {
                st->strategy = DefaultStrategy(*sc, *st);
                st->strategyTarget = 0;
            }
            st->nextStepAt = Now();
            webui_log::info("OrgasmEngine: {:#x} player-driven {} (scene {})", st->id, on, sc->sid);
        }
        PostEffects(std::move(fx));
        return true;
    }

    bool SceneIdOf(RE::Actor* actor, std::int32_t& sid)
    {
        std::lock_guard lock(g_lock);
        const auto* st = Find(actor);
        if (!st || !SceneOf(*st)) {
            return false;
        }
        sid = st->sid;
        return true;
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

    void NarrateDirect(const std::string& msg, RE::Actor* source, RE::Actor* target)
    {
        if (msg.empty()) {
            return;
        }
        DispatchShell("Effect_NarrateDirect",
            RE::MakeFunctionArguments(RE::BSFixedString(msg.c_str()), std::move(source), std::move(target)));
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
            // v4: gate state, so a mid-hold save does not re-roll the gate for the same actors on load.
            intfc->WriteRecordData(sc.gateDone);
            intfc->WriteRecordData(sc.gateAwait);
            // v5: Together progress clock.
            intfc->WriteRecordData(sc.stageElapsed);
            // v7: mini-game rates (fixed per scene, so not recomputable from the current animation).
            intfc->WriteRecordData(sc.ratesKnown);
            intfc->WriteRecordData(sc.mgRates);
            intfc->WriteRecordData(sc.calibrated);
            intfc->WriteRecordData(sc.mgPassiveRate);
            intfc->WriteRecordData(sc.mgStepRate);
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
                intfc->WriteRecordData(false);  // was mental break; kept so the record layout is unchanged
                intfc->WriteRecordData(st.sceneBlocked);
                intfc->WriteRecordData(st.dom);
                intfc->WriteRecordData(st.jitter);
                intfc->WriteRecordData(st.domProgress);
                intfc->WriteRecordData(st.domStepAcc);
                intfc->WriteRecordData(st.domPrepaid);
                intfc->WriteRecordData(st.rushing);
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
                // v5: bonus, Together curve, mini-game strategy.
                intfc->WriteRecordData(st.bonus);
                intfc->WriteRecordData(st.curveP);
                intfc->WriteRecordData(static_cast<std::int32_t>(st.strategy));
                intfc->WriteRecordData(st.strategyTarget);
                intfc->WriteRecordData(static_cast<RE::FormID>(0));   // was forcedBy (removed)
                intfc->WriteRecordData(static_cast<std::int32_t>(0));  // was forcedAction (removed)
                // v6: stamina regen.
                intfc->WriteRecordData(st.regen);
            }
        }
        // v8: sticky auto play.
        intfc->WriteRecordData(g_autoPlaySticky);
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
        g_autoPlaySticky = false;
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
            sc.beganAt = Now();  // not saved: an untimed scene's NPC steps wait one more grace
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
            if (version >= 4) {
                if (!intfc->ReadRecordData(sc.gateDone) || !intfc->ReadRecordData(sc.gateAwait)) {
                    webui_log::error("OrgasmEngine: co-save truncated");
                    return;
                }
            }
            if (version >= 5 && !intfc->ReadRecordData(sc.stageElapsed)) {
                webui_log::error("OrgasmEngine: co-save truncated");
                return;
            }
            if (version >= 7) {
                if (!intfc->ReadRecordData(sc.ratesKnown) || !intfc->ReadRecordData(sc.mgRates) ||
                    !intfc->ReadRecordData(sc.calibrated) || !intfc->ReadRecordData(sc.mgPassiveRate) ||
                    !intfc->ReadRecordData(sc.mgStepRate)) {
                    webui_log::error("OrgasmEngine: co-save truncated");
                    return;
                }
            } else {
                // No saved rates: calibrate from the saved timers (SetStageTimers skips unchanged ones).
                sc.ratesKnown = true;
                CalibrateMiniGame(sc);
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
                bool legacyBroken = false;  // mental break was removed; the saved flag is read and dropped
                if (!intfc->ReadRecordData(oldId) || !intfc->ReadRecordData(st.enjoyment) ||
                    !intfc->ReadRecordData(st.orgasmCount) || !intfc->ReadRecordData(role) ||
                    !intfc->ReadRecordData(st.skill) || !intfc->ReadRecordData(st.lewd) ||
                    !intfc->ReadRecordData(legacyBroken) || !intfc->ReadRecordData(st.sceneBlocked) ||
                    (version >= 2 && !intfc->ReadRecordData(st.dom)) ||
                    (version >= 3 &&
                        (!intfc->ReadRecordData(st.jitter) || !intfc->ReadRecordData(st.domProgress) ||
                            !intfc->ReadRecordData(st.domStepAcc) || !intfc->ReadRecordData(st.domPrepaid))) ||
                    (version >= 4 && !intfc->ReadRecordData(st.rushing)) ||
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
                if (version >= 5) {
                    std::int32_t strategy = 0;
                    std::int32_t forcedAction = 0;
                    RE::FormID target = 0;
                    RE::FormID forcer = 0;
                    if (!intfc->ReadRecordData(st.bonus) || !intfc->ReadRecordData(st.curveP) ||
                        !intfc->ReadRecordData(strategy) || !intfc->ReadRecordData(target) ||
                        !intfc->ReadRecordData(forcer) || !intfc->ReadRecordData(forcedAction)) {
                        webui_log::error("OrgasmEngine: co-save truncated");
                        return;
                    }
                    // SexLab stops every scene on load, so no saved strategy is used: the fields are read to keep
                    // the record layout and dropped (a scene that starts later gets its own defaults).
                    (void)strategy;
                    (void)target;
                    (void)forcer;
                    (void)forcedAction;
                }
                if (version >= 6 && !intfc->ReadRecordData(st.regen)) {
                    webui_log::error("OrgasmEngine: co-save truncated");
                    return;
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
            if (version < 5) {
                // No saved curve progress: start it where the scene is, so the first tick does not jump.
                for (const auto id : sc.actors) {
                    g_actors[id].curveP = SceneProgress(sc);
                }
            }
            if (!sc.actors.empty()) {
                sc.decisionsStarted = true;  // strategies were saved: no scene-start decisions again
                g_scenes[sc.sid] = std::move(sc);
            }
        }
        if (version >= 8 && intfc->ReadRecordData(g_autoPlaySticky) && g_autoPlaySticky) {
            // A scene saved with the player in it resumes in auto play.
            if (auto* st = Find(RE::PlayerCharacter::GetSingleton()); st && SceneOf(*st)) {
                st->autoPlay = true;
            }
        }
        webui_log::info("OrgasmEngine: co-save loaded {} scene(s), {} actor(s) auto_play={}", g_scenes.size(),
            g_actors.size(), g_autoPlaySticky);
    }

    void Revert()
    {
        std::lock_guard lock(g_lock);
        g_scenes.clear();
        g_actors.clear();
        g_narrateDue.clear();
        g_autoPlaySticky = false;
    }

    SKYRIMNET_SEXLAB_API::IOrgasmEngineV2* GetInterface()
    {
        return &g_interface;
    }
}

extern "C" __declspec(dllexport) void* RequestOrgasmEngineAPI(SKYRIMNET_SEXLAB_API::InterfaceVersion a_version)
{
    // V2 extends V1 (same object, appended vtable), so V1 callers get it too.
    if (a_version == SKYRIMNET_SEXLAB_API::InterfaceVersion::V1) {
        return static_cast<SKYRIMNET_SEXLAB_API::IOrgasmEngineV1*>(OrgasmEngine::GetInterface());
    }
    if (a_version == SKYRIMNET_SEXLAB_API::InterfaceVersion::V2) {
        return OrgasmEngine::GetInterface();
    }
    return nullptr;
}
