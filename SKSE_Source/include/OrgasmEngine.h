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
    enum class Strategy : std::int32_t
    {
        kPassive = 0,       // no presses
        kMutual = 1,        // arouse the lowest-enjoyment actor (self included)
        kSelfish = 2,       // arouse self
        kSelfless = 3,      // arouse the lowest-enjoyment other actor
        kTogether = 4,      // calm self when ahead, arouse self when behind
        kTease = 5,         // arouse the target below 90, calm (edge) them at 90+
        kReject = 6,        // calm self (victims; or forced via RejectForce)
        kCumQuick = 7,      // arouse the aggressor (victims)
        kGreedy = 8,        // arouse self; the target is forced to arouse the speaker
        kForcedOrgasm = 9,  // arouse the target; the target is forced to arouse self
        kAcceptForce = 10,  // forced: play the forced action
        kNonSexual = 11,    // no presses; the default when no actor expects orgasm
        kCount = 12,
    };

    /// What a forced actor's AcceptForce plays.
    enum class ForcedAction : std::int32_t
    {
        kNone = 0,
        kArouseForcer = 1,  // Greedy
        kArouseSelf = 2,    // ForcedOrgasm
        kPlayStrategy = 3,  // player Force (HUD): play the strategy the player chose
    };

    /// Starts the tick thread. Call once at kDataLoaded.
    void Install();

    /// Re-reads the sexlab.enjoyment.* / sexlab.minigame.* dashboard values.
    void ReloadConfig();
    bool IsMiniGameEnabled();

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
    /// final stage (Effect_AdvanceToFinal).
    void GateNarrationSent(std::int32_t sid);
    /// Scene ending lead and orgasm target (0 = off). The lead reaching it in the second-to-last stage
    /// triggers the early final roll in the group join (the Scene jumps to the final stage).
    void SetEndingTarget(std::int32_t sid, RE::Actor* lead, std::int32_t target);
    // Seconds left on the timed final stage (unpaused, animating); -1 when not in one.
    float FinalStageRemaining(std::int32_t sid);
    bool IsPlayerScenePaused();
    /// Player scene stage (1-based) and stage count; false (0/0) when not in a scene.
    bool GetPlayerSceneStage(int& stage, int& count);
    void SetSceneBlocked(RE::Actor* actor, bool blocked);
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
    /// Mini-game: the NPC's strategy (and its target for Tease / Greedy / ForcedOrgasm). Narrated, and a
    /// notification in player scenes. False when not allowed for the actor (mode, role, forced state).
    bool SetStrategy(RE::Actor* actor, Strategy strategy, RE::Actor* target);
    Strategy GetStrategy(RE::Actor* actor);
    /// Third-person phrase for the current strategy ("focuses on self enjoyment"), "" when none / Together mode.
    std::string GetStrategyText(RE::Actor* actor);
    // Stamina regen, percent of the actor's default (100 when unmanaged or fatigue is off).
    float GetStaminaRegen(RE::Actor* actor);
    RE::Actor* GetForcedBy(RE::Actor* actor);
    /// How the forcer forced the actor ("a slap to the face"), shown in AcceptForce / RejectForce narration.
    /// Kept until the forced state ends. "" clears.
    void SetForceMethod(RE::Actor* actor, const std::string& method);

    /// Player Force (HUD key): a victim the player can force and the strategies it can be forced into.
    struct ForceVictim
    {
        RE::FormID id = 0;
        std::string name;
        std::vector<std::pair<std::string, std::string>> strategies;  // key, panel label ("please you")
    };
    /// False when the player is not an aggressor in a managed mini-game scene. victims: non-player victims.
    bool GetPlayerForceInfo(std::vector<ForceVictim>& victims);
    /// The player forces victim into strategyKey by method (preset key or free text). Starts the fear
    /// cooldown (only AcceptForce offered). Returns the narration line, "" when refused.
    std::string PlayerForce(RE::FormID victim, const std::string& strategyKey, const std::string& method);
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
    bool IsMentallyBroken(RE::Actor* actor);
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
        bool broken = false;
        bool dom = false;  // DOM slave: bar is DOM's orgasm meter, DOM decides
        bool denied = false;  // player's deny_orgasm (SetSceneBlocked)
        std::string strategy;  // mini-game NPC strategy label ("selfish", "forced"), "" when none
        float magicka = 0.0f;  // 0..100 % of max (calm cost, mental break)
        float stamina = 0.0f;  // 0..100 % of max (arouse cost)
    };
    /// Actors of the scene the player is in, in SexLab position order. False when none.
    bool GetPlayerScene(std::vector<ActorView>& out);
    /// Speed levels match the scene styles: gentle, normal, forceful.
    inline constexpr int kSpeedLevelCount = 3;
    inline constexpr float kSpeedLevels[kSpeedLevelCount] = { 0.75f, 1.0f, 1.25f };
    inline constexpr const char* kSpeedLevelNames[kSpeedLevelCount] = { "gentle", "normal", "forceful" };
    /// Level closest to an effective animation speed.
    int NearestSpeedLevel(float speed);
    /// Moves the player's scene one speed level up (dir > 0) or down (dir < 0), clamped to the ends.
    /// Returns the new level, -1 when the player is in no managed scene.
    int StepPlayerSceneSpeed(int dir);
    /// Current speed level of the player's scene, -1 when none.
    int GetPlayerSceneSpeedLevel();

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
    // 6: + stamina regen per actor. 7: + mini-game rates per scene (CalibrateMiniGame). Older still load.
    constexpr std::uint32_t kRecordVersion = 7;

    /// The exported C++ interface (RequestOrgasmEngineAPI).
    SKYRIMNET_SEXLAB_API::IOrgasmEngineV2* GetInterface();
}
