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
    void SetStageTimers(std::int32_t sid, const std::vector<float>& stageSecs, bool leadIn);
    /// Pause hotkey state: HUD label; the safety-net clock stops. Passive gain keeps running.
    void SetScenePaused(std::int32_t sid, bool paused);
    /// Gate pass narration was just sent: the next non-player speech start pushes the scene to its
    /// final stage (Effect_AdvanceToFinal).
    void GateNarrationSent(std::int32_t sid);
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
    void EndScene(std::int32_t sid);
    /// SexLabOrgasm arrived: true (and consumed) when the engine fired it itself.
    bool ConsumeOwnOrgasm(RE::Actor* actor);
    /// SexLabOrgasm the engine did not fire (another plugin called SexLab): record it like our own
    /// (reset, count, cooldown, flash, events). Returns the new count, 0 when unmanaged.
    std::int32_t NoteExternalOrgasm(RE::Actor* actor, const std::string& source);
    /// deny_orgasm 1 -> 0: unblock the actor and, in the same lock, fire everyone in the scene at 100 (plus
    /// the group join). The group carries allower / allowed for the "allows ... to orgasm." prefix.
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
        float magicka = 0.0f;  // 0..100 % of max (calm cost, mental break)
        float stamina = 0.0f;  // 0..100 % of max (arouse cost)
    };
    /// Actors of the scene the player is in, in SexLab position order. False when none.
    bool GetPlayerScene(std::vector<ActorView>& out);
    /// Speed levels extend the scene style: slow and gentle, gentle, normal, forceful, fast and forceful.
    inline constexpr int kSpeedLevelCount = 5;
    inline constexpr float kSpeedLevels[kSpeedLevelCount] = { 0.5f, 0.75f, 1.0f, 1.25f, 1.5f };
    inline constexpr const char* kSpeedLevelNames[kSpeedLevelCount] = { "slow and gentle", "gentle", "normal",
        "forceful", "fast and forceful" };
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

    // ---- Co-save ----
    void Save(SKSE::SerializationInterface* intfc);
    void Load(SKSE::SerializationInterface* intfc, std::uint32_t version, std::uint32_t length);
    void Revert();
    constexpr std::uint32_t kRecord = 'ORGE';
    // 2: + per-actor dom flag. 3: + stage timers, pause, final clock; jitter, DOM step state.
    // 4: + gateDone/gateAwait per scene, rushing per actor (a mid-hold save no longer re-rolls the
    // gate on load). Older still load.
    constexpr std::uint32_t kRecordVersion = 4;

    /// The exported C++ interface (RequestOrgasmEngineAPI).
    SKYRIMNET_SEXLAB_API::IOrgasmEngineV1* GetInterface();
}
