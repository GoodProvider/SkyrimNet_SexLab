#pragma once

#include "PCH.h"

#include <cstdint>
#include <string>
#include <vector>

#include "OrgasmEngineAPI.h"

/// Owns enjoyment and orgasms for every SexLab scene. SexLab's own trigger is off
/// (thread.DisableAllOrgasms); Papyrus is a shell that forwards scene facts in and performs
/// SexLab side effects (ForceOrgasm, AdjustEnjoyment mirror, narration) when the engine asks.
/// See docs/developers/orgasm-engine.md.
namespace OrgasmEngine
{
    enum class Role : std::int32_t
    {
        kNormal = 0,
        kAggressor = 1,
        kVictim = 2,
    };

    /// Mini-game NPC strategy (Papyrus SetStrategy id). The engine plays the mini-game for the NPC.
    /// Order matches strategies.json (the source of truth for keys and wording).
    enum class Strategy : std::int32_t
    {
        kPassive = 0,    // no presses
        kMutual = 1,     // arouse the lowest-enjoyment actor (self included)
        kSelfish = 2,    // arouse self
        kSelfless = 3,   // arouse the lowest-enjoyment other actor
        kDenySelf = 4,   // calm self
        kDenyAll = 5,    // calm every actor in the scene, self included
        kDeny = 6,       // calm the target
        kTease = 7,      // arouse the target below 90, calm (edge) them at 90+
        kFocused = 8,    // arouse the target
        kNonSexual = 9,  // no presses; the default when no actor expects orgasm
        kCount = 10,
    };

    /// Starts the tick thread. Call once at kDataLoaded.
    void Install();

    /// Re-reads the sexlab.enjoyment.* / sexlab.minigame.* dashboard values.
    void ReloadConfig();
    bool IsMiniGameEnabled();
    /// sexlab.enjoyment.engine_disabled: SexLab owns enjoyment and orgasms (thread.DisableAllOrgasms off).
    bool IsEngineDisabled();

    // ---- Shell (our Scene script) ----
    void BeginScene(std::int32_t sid, const std::vector<RE::Actor*>& actors, const std::vector<std::int32_t>& roles,
        const std::vector<float>& seeds, bool hasPlayer);
    void SetStage(std::int32_t sid, std::int32_t stage, std::int32_t stageCount);
    /// Seconds per stage (SexLab's GetTimer rule) for the current animation. Sets the fixed base rate:
    /// 100 over stages 1..N-1 + 0.9 x the final stage (LeadIn: all x 1.5). Empty: fallback rate.
    /// Mini-game: the first main animation also fixes the scene's rates, so every NPC on Mutual reaches
    /// sexlab.enjoyment.mutual_target at the end of the second-to-last stage (stage spikes included).
    void SetStageTimers(std::int32_t sid, const std::vector<float>& stageSecs, bool leadIn);
    /// Pause hotkey state: HUD label; the safety-net clock stops. Passive gain keeps running.
    void SetScenePaused(std::int32_t sid, bool paused);
    /// Gate pass narration was just sent: the next non-player speech start pushes the scene to its
    /// final stage (Effect_AdvanceToFinal). mark: SpeakerMark() taken just before the DN went out, so a
    /// fast voice is not missed; < 0 takes it now.
    void GateNarrationSent(std::int32_t sid, std::int64_t mark = -1);
    /// The engine plays this scene's ending gate (mini-game, every non-DOM actor AI driven, timed, no
    /// LeadIn): its last orgasm lands at the end of the second-to-last stage.
    /// The scene's actors (empty when unknown).
    std::vector<RE::FormID> SceneActors(std::int32_t sid);
    bool IsGateScene(std::int32_t sid);
    /// Scene ending lead and orgasm target (0 = off). The lead reaching it in the second-to-last stage
    /// triggers the early final roll in the group join (the Scene jumps to the final stage).
    void SetEndingTarget(std::int32_t sid, RE::Actor* lead, std::int32_t target);
    // Seconds left on the timed final stage (unpaused, animating); -1 when not in one.
    float FinalStageRemaining(std::int32_t sid);
    bool IsPlayerScenePaused();
    /// Pause state of the anchor actor's scene (HUD: the player, or the NPC the player took control of).
    bool IsScenePaused(RE::Actor* anchor);
    /// Player scene stage (1-based) and stage count; false (0/0) when not in a scene.
    bool GetPlayerSceneStage(int& stage, int& count);
    bool GetSceneStage(RE::Actor* anchor, int& stage, int& count);
    void SetSceneBlocked(RE::Actor* actor, bool blocked);
    /// Current animation's act tags (Vaginal / Anal / Oral or Blowjob) for the anchor's scene; Papyrus sends them on
    /// start and animation change. Not saved.
    void SetSceneActs(RE::Actor* anchor, bool vaginal, bool anal, bool oral);
    /// False (all false) when the anchor is in no managed scene.
    bool GetSceneActs(RE::Actor* anchor, bool& vaginal, bool& anal, bool& oral);
    /// This scene is the actor's first vaginal / anal (Lover's Ledger, from Papyrus on start and animation change).
    /// Sticky: a false never clears a flag for the rest of the scene. Not saved.
    void SetFirstTimes(RE::Actor* actor, bool vaginal, bool anal);
    /// The Punish / Aid panel parts of the actor's first times this scene: "pussy" (vaginal), "ass" (anal).
    std::vector<std::string> GetFirstTimes(RE::FormID actor);
    // Position's orgasm_expected; false: no passive gain (mini-game Arouse / Calm only).
    void SetOrgasmExpected(RE::Actor* actor, bool expected);
    /// DOM slave: passive progress goes to DOM's arousal in steps (Effect_DomSync) and DOM decides the orgasm.
    void SetDomSlave(RE::Actor* actor, bool dom);
    /// DOM slave: the 0-100 meter Papyrus computed from DOM's orgasm values (HUD bar + SexLab mirror).
    void SetDomMeter(RE::Actor* actor, float meter);
    void SetActorSkills(RE::Actor* actor, std::int32_t skill, std::int32_t lewd);
    /// SexLab's starting-enjoyment inputs (sslActorAlias StartAnimating): GetSkillLevels arrays of the actor
    /// and of the partner SexLab bases skills on (empty: unskilled, e.g. creatures), the lowest / highest
    /// present relationship rank, and the act skill index (0 foreplay, 1 vaginal, 2 anal, 3 oral).
    /// The engine turns them into the actor's bonus (SexLab's formula, see ComputeBonus).
    void SetBonusInputs(RE::Actor* actor, const std::vector<float>& ownSkills, const std::vector<float>& partnerSkills,
        std::int32_t lowestRank, std::int32_t highestRank, std::int32_t actSkill);
    /// Who changed a strategy. kDecision (the decision model): a short-term event ("<name> appears to be ...")
    /// instead of narration. Both show a notification.
    enum class StrategySource : std::int32_t
    {
        kAction = 0,
        kDecision = 1,
    };

    /// Mini-game: the NPC's strategy (and its target for Deny / Tease / Focused). Announced (see
    /// StrategySource). False when not allowed for the actor (mode, scene).
    bool SetStrategy(RE::Actor* actor, Strategy strategy, RE::Actor* target,
        StrategySource source = StrategySource::kAction);
    Strategy GetStrategy(RE::Actor* actor);

    /// Strategy decision (StrategyDecision.cpp): the engine's facts about one NPC and the options it may pick.
    struct DecisionPartner
    {
        RE::FormID id = 0;
        std::string name;
        bool isPlayer = false;
        std::string role;     // partner | aggressor | victim
        std::string arousal;  // 0050 bands: barely aroused ... on the verge of orgasm
        std::int32_t orgasms = 0;
    };
    struct DecisionOption
    {
        std::string key;  // strategy key, "<key>_p<slot>" for a target strategy
        std::string text;
    };
    struct DecisionInput
    {
        std::int32_t sid = 0;
        std::uint64_t generation = 0;  // ApplyStrategyDecision drops the answer when it changed
        RE::FormID id = 0;
        std::string name;
        std::string role;
        std::string arousal;
        std::int32_t orgasms = 0;
        bool expectsOrgasm = true;
        std::string currentKey;  // C++ only (kept / changed); never sent to the prompt
        std::vector<DecisionPartner> partners;  // everyone else, SexLab position order
        std::vector<DecisionOption> options;    // only what the engine allows now
        std::vector<std::pair<std::string, RE::FormID>> slots;  // "p<slot>" -> actor (target suffixes)
    };
    /// False when the actor is unmanaged, not AI-driven (the player outside auto play, an NPC the player took
    /// control of), or not in mini-game mode.
    bool GetStrategyDecisionInput(RE::Actor* actor, DecisionInput& out);
    enum class DecisionResult
    {
        kChanged,
        kKept,           // same key and target as now
        kDropped,        // scene ended, roster changed or mini-game off
        kLowConfidence,  // under sexlab.minigame.decision_min_confidence
        kUnknown,        // key not a strategy
    };
    /// Applies a decision answer key from `in` (same scene and generation, still allowed). Quiet when the key
    /// equals the current strategy. `confidence` < 0 = not reported (no floor).
    DecisionResult ApplyStrategyDecision(RE::Actor* actor, const DecisionInput& in, const std::string& key,
        double confidence);
    /// sexlab.minigame.decision_strategy and mini-game mode.
    bool IsStrategyDecisionEnabled();
    /// sexlab.minigame.decision_min_confidence.
    double GetDecisionMinConfidence();
    /// AI-driven actors of a managed scene (NPCs the player does not control, the player in auto play),
    /// position order.
    std::vector<RE::FormID> SceneNpcs(std::int32_t sid);
    /// Third-person phrase for the current strategy ("focuses on self enjoyment"), "" when none / Together mode.
    std::string GetStrategyText(RE::Actor* actor);
    // Stamina regen, percent of the actor's default (100 when unmanaged or fatigue is off).
    float GetStaminaRegen(RE::Actor* actor);

    /// Punish (HUD key, SexLab_Scene_Punish action, auto play): someone in the scene the punisher can punish.
    struct PunishTarget
    {
        RE::FormID id = 0;
        std::string name;
    };
    /// False when the punisher is not in a managed scene. targets: everyone else in it, the player included.
    bool GetPunishInfo(RE::Actor* punisher, std::vector<PunishTarget>& targets);
    /// Ask / Order panel request: a strategy the target could be asked to take.
    struct RequestOption
    {
        std::string key;   // "<key>" or "<key>_p<slot>" (deny / tease / focused: the actor the request is about)
        std::string text;  // strategies.json "order" phrase after "to", {target} filled: "be passive and let things happen"
    };
    /// The strategies `target` may take now (decision rule; one per other actor for deny / tease / focused), its
    /// current one left out. Empty when unmanaged, not AI-driven (the player outside auto play, an NPC the player
    /// controls) or not in mini-game mode.
    std::vector<RequestOption> GetRequestOptions(RE::FormID target);
    /// What `target` can be punished for this scene, newest last: "Nina refused Bob's order to be passive" (a
    /// refused ask / order) or a reason a mod supplied (AddPunishReason), then an AI actor's current strategy as
    /// others see it ("Nina appears to be focused on her own enjoyment") while the mini-game is on.
    std::vector<std::string> GetPunishReasons(RE::FormID target);
    /// Another mod (SkyrimNet_DOM) supplies a reason `target` can be punished for ("Nina spoke without permission").
    void AddPunishReason(RE::Actor* by, RE::Actor* target, const std::string& reason);
    /// by asks or orders target to take a strategy: requestKey one of GetRequestOptions(target) keys, or "" with
    /// customText (a free phrase after "to"). Narrates "Bob orders Nina to <text>." (DirectNarration when the scene
    /// has the player or the player controls an actor of it, else DirectNarration_Optional), runs the target's
    /// strategy decision with that line as last_line, then narrates the answer on its own: "Nina agrees to|refuses
    /// Bob's request to <text>." A refusal is kept as a punishment reason. Any thread. False when refused.
    bool AskOrderNarrated(RE::Actor* by, RE::FormID target, bool order, const std::string& requestKey,
        const std::string& customText);
    /// The punisher hurts target: "Bob punishes Nina by pinching Nina's nipples, because Nina refused Bob's order to
    /// be passive." With Injury Engine (External_TortureText) the hit lands silently and its feeling text is
    /// appended to the narration; the narration is then sent and is last_line of the target's strategy decision
    /// (trigger "punished"); a punishment for a refused request gets the agree / refuse answer as its own narration.
    /// method: slap / pinch / punch / pull, one of Aid::PunishSpells (weak attack spells, a non-lethal hit; with Injury
    /// Engine, its torture spells) or a free
    /// phrase ("biting"). location: body part ("" / "body": none named). reason: "" drops the "because ..." clause.
    /// amount: hits (Injury Engine damage_amount, clamped to 1..its max_strikes); above 1 the line says "N times".
    /// Any thread. False when refused.
    bool PunishNarrated(RE::Actor* punisher, RE::FormID target, const std::string& method, const std::string& location,
        const std::string& reason, std::int32_t amount = 1);
    /// The actor is in a managed scene with someone else in it (SexLab_Scene_Punish eligibility).
    bool CanPunish(RE::Actor* actor);
    void EndScene(std::int32_t sid);
    /// SexLabOrgasm arrived: true (and consumed) when the engine fired it itself.
    bool ConsumeOwnOrgasm(RE::Actor* actor);
    /// SexLabOrgasm the engine did not fire (another plugin called SexLab): record it like our own
    /// (reset, count, cooldown, flash, events). Returns the new count, 0 when unmanaged.
    std::int32_t NoteExternalOrgasm(RE::Actor* actor, const std::string& source);
    /// deny_orgasm 1 -> 0: unblock the actor and, in the same lock, test them with the normal orgasm rule
    /// (enjoyment + mini-game bonus, pending request) and fire everyone else at 100 (plus the group join).
    /// The group carries allower / allowed for the "allowed ... to orgasm." prefix.
    /// True when anyone fired (Effect_OrgasmGroup narrates); false: the caller narrates the plain allow.
    bool AllowOrgasm(RE::Actor* actor, RE::Actor* allower);
    /// Scene style changed: faster/slower scale back to 1.0.
    void ResetSpeedScale(RE::Actor* anyActorInScene);

    // ---- API (Papyrus natives + C++ interface) ----
    float GetEnjoyment(RE::Actor* actor);
    void SetEnjoyment(RE::Actor* actor, float value, const std::string& source);
    void AddEnjoyment(RE::Actor* actor, float delta, const std::string& source);
    bool Arouse(RE::Actor* who, RE::Actor* target, float mult);
    bool Calm(RE::Actor* who, RE::Actor* target, float mult);
    void Edge(RE::Actor* actor, float seconds, const std::string& source);
    void SetRateModifier(RE::Actor* actor, const std::string& source, float mult);
    void ClearRateModifier(RE::Actor* actor, const std::string& source);
    void SetOrgasmBlocked(RE::Actor* actor, const std::string& source, bool blocked);
    bool IsOrgasmAllowed(RE::Actor* actor);
    void RequestOrgasm(RE::Actor* actor, bool force, const std::string& source);
    std::int32_t GetOrgasmCount(RE::Actor* actor);
    float GetSecondsSinceOrgasm(RE::Actor* actor);
    bool IsManaged(RE::Actor* actor);
    void SetRates(float passive, float aggressor, float victim);
    std::uint32_t RegisterEventCallback(SKYRIMNET_SEXLAB_API::EngineEventCallback callback);
    void UnregisterEventCallback(std::uint32_t handle);

    /// Mini-game costs `who` can pay right now (HUD greys the key otherwise).
    bool CanArouse(RE::Actor* who);
    bool CanCalm(RE::Actor* who);

    // ---- HUD support ----
    struct ActorView
    {
        RE::FormID id = 0;
        std::string name;
        float enjoyment = 0.0f;
        bool flashing = false;
        bool dom = false;  // DOM slave: bar is DOM's orgasm meter, DOM decides
        bool denied = false;  // player's deny_orgasm (SetSceneBlocked)
        std::string strategy;  // mini-game NPC strategy label ("selfish", "forced"), "" when none
        float magicka = 0.0f;  // 0..100 % of max (calm cost)
        float stamina = 0.0f;  // 0..100 % of max (arouse cost)
    };
    /// Actors of the scene the player is in, in SexLab position order. False when none.
    bool GetPlayerScene(std::vector<ActorView>& out);
    /// Actors of the anchor actor's scene, in SexLab position order. False when none.
    bool GetActorScene(RE::Actor* anchor, std::vector<ActorView>& out);
    /// Speed levels match the scene styles: gentle, normal, forceful.
    inline constexpr int kSpeedLevelCount = 3;
    inline constexpr float kSpeedLevels[kSpeedLevelCount] = { 0.75f, 1.0f, 1.25f };
    inline constexpr const char* kSpeedLevelNames[kSpeedLevelCount] = { "gentle", "normal", "forceful" };
    /// Level closest to an effective animation speed.
    int NearestSpeedLevel(float speed);
    /// Moves the player's scene one speed level up (dir > 0) or down (dir < 0), clamped to the ends.
    /// Returns the new level, -1 when the player is in no managed scene.
    int StepPlayerSceneSpeed(int dir);
    int StepSceneSpeed(RE::Actor* anchor, int dir);
    /// Current speed level of the player's scene, -1 when none.
    int GetPlayerSceneSpeedLevel();
    int GetSceneSpeedLevel(RE::Actor* anchor);

    // ---- HUD take-control key ----
    /// Auto play: the engine plays the player's mini-game strategy like an NPC's (decisions included).
    /// Sticky: stays on for the player's later scenes until turned off (saved). False when the player is in
    /// no managed scene.
    bool SetAutoPlay(bool on);
    bool IsAutoPlay();
    /// Take control of an NPC: its strategy stops and the player drives it with the HUD. Ends with the scene.
    /// False when unmanaged or the player.
    bool SetPlayerDriven(RE::Actor* actor, bool on);
    /// The actor's managed scene id; false when none.
    bool SceneIdOf(RE::Actor* actor, std::int32_t& sid);

    /// Shell narration with the mod's rule: DirectNarration when the player is source or target,
    /// else DirectNarration_Optional(event_type, ...) which falls back to RegisterEvent (never dropped).
    void Narrate(const std::string& eventType, const std::string& msg, RE::Actor* source, RE::Actor* target);
    /// Always DirectNarration (player Force: the player's own deliberate act).
    void NarrateDirect(const std::string& msg, RE::Actor* source, RE::Actor* target);

    // ---- Co-save ----
    void Save(SKSE::SerializationInterface* intfc);
    void Load(SKSE::SerializationInterface* intfc, std::uint32_t version, std::uint32_t length);
    void Revert();
    constexpr std::uint32_t kRecord = 'ORGE';
    // 2: + per-actor dom flag. 3: + stage timers, pause, final clock; jitter, DOM step state.
    // 4: + gateDone/gateAwait per scene, rushing per actor (a mid-hold save no longer re-rolls the
    // gate on load). 5: + stage clock per scene; bonus, curve progress, strategy, target, forcer per actor.
    // 6: + stamina regen per actor. 7: + mini-game rates per scene (CalibrateMiniGame). 8: + sticky auto play
    // (after the scenes). Older still load.
    constexpr std::uint32_t kRecordVersion = 9;  // 9: strategy ids renumbered (reject / cumquick removed)

    /// The exported C++ interface (RequestOrgasmEngineAPI).
    SKYRIMNET_SEXLAB_API::IOrgasmEngineV2* GetInterface();
}
