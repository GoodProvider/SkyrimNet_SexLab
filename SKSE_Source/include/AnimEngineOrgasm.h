#pragma once

#include "PCH.h"

#include "AnimEngine.h"

#include <cstdint>
#include <string>
#include <vector>

/// AnimEngine scenes in the OrgasmEngine without SexLab: the native port of the Scene script's Engine_* / Ending_* /
/// Gate_* / Victim_* block and Orgasm_ApplyGroup (strangler step 2, docs/developers/scene-migration.md §8).
/// AnimEngine posts stage / pause / end notes (game thread, no AnimEngine lock held); the OrgasmEngine routes its
/// effects for these scenes' actors here instead of to the Papyrus shell. Gated by sexlab.anim_engine.orgasm_engine
/// (read at a scene's first stage). Narration is step 5: the seam below only logs.
/// Locking: one leaf mutex; no OrgasmEngine / AnimEngine call is made while it is held.
namespace AnimEngineOrgasm
{
    /// OrgasmEngine sid of an AnimEngine scene: offset past the SexLab pool sids (AnimEngine ids start at 1).
    constexpr std::int32_t kSidBase = 100000;
    inline std::int32_t SidOf(int ae_id) { return kSidBase + ae_id; }
    inline bool IsAnimEngineSid(std::int32_t sid) { return sid > kSidBase; }

    /// Bumped by Clear (load / revert): notes posted before it are dropped.
    std::uint64_t Epoch();

    struct StageNote
    {
        std::uint64_t epoch = 0;
        int ae_id = 0;
        std::string registry;
        std::vector<RE::FormID> actors;
        std::vector<std::int32_t> roles;
        bool first = false;
        AnimEngine::StageView view;
        std::string node_id;
    };

    // ---- AnimEngine notes (game thread tasks) ----
    void OnStage(const StageNote& note);
    void OnPause(std::uint64_t epoch, int ae_id, bool paused);
    void OnEnd(std::uint64_t epoch, int ae_id, const std::string& why);
    /// AnimEngine::ClearAll: forget every scene (the OrgasmEngine drops its own on load / revert).
    void Clear();

    // ---- OrgasmEngine side ----
    /// The actor is in a wired AnimEngine scene.
    bool OwnsActor(RE::FormID actor);
    /// The bridge still has this sid (the OrgasmEngine's stale-scene check).
    bool IsLive(std::int32_t sid);
    /// Effects (OrgasmEngine::RunEffects, game thread, no engine lock held).
    void OnOrgasmGroup(const std::vector<RE::Actor*>& actors, const std::vector<std::int32_t>& forced, bool individual,
        const std::string& source, RE::Actor* allower, RE::Actor* allowed, const std::string& extras);
    void OnGatePassed(const std::vector<RE::Actor*>& actors, bool hold_stage);
    void OnAdvanceToFinal(RE::Actor* actor);
    void OnExhausted(const std::vector<RE::Actor*>& actors);
    /// End of each OrgasmEngine tick (game thread). dt: unpaused game seconds. Gate wait, victim cap, ending hold.
    void Tick(double dt);

    /// HUD deny key on an AnimEngine scene actor: deny, or allow (AllowOrgasm) when denied. False: not wired.
    bool ToggleDeny(RE::Actor* target, RE::Actor* by);
    /// Bridge state of an AnimEngine scene as JSON ("null" when not wired).
    std::string DescribeJson(int ae_id);

    /// Narration seam (step 5 ports orgasm-narration.md). Step 2 stubs log and send nothing.
    namespace Narration
    {
        enum class GateResult
        {
            kNoVoice,  // nothing sent: no voice will start, so the gate does not hold for one
            kSent,     // sent now; mark: NarrationTiming::SpeakerMark() taken just before
            kPending,  // queued; the narration notifies the bridge once it goes out
        };
        void OrgasmGroup(int ae_id, const std::vector<RE::Actor*>& actors, const std::vector<std::int32_t>& forced,
            bool individual, RE::Actor* allower, RE::Actor* allowed, const std::string& extras);
        GateResult GatePassed(int ae_id, const std::vector<RE::Actor*>& actors, std::int64_t& mark);
        void Deny(RE::Actor* target, RE::Actor* by);
        void Allow(RE::Actor* target, RE::Actor* by);
        /// The ending dialogue hold has a narration to wait for (Ending_HoldMax > 0).
        bool EndingDialogue();
    }
}
