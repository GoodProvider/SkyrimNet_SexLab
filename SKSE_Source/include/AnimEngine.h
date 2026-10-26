#pragma once

#include "PCH.h"

#include <cstdint>
#include <string>
#include <vector>

/// AnimEngine: drives actors through AnimDB playback data (SLAL or SLSB stage graphs) without SexLab's thread.
/// Playback is NotifyAnimationGraph(stage event); FNIS/Pandora generate the behaviors. Actor lock / placement hold
/// run through the thin Papyrus shell SkyrimNet_SexLab_AnimEngine.psc. Gated by sexlab.anim_engine.enabled.
/// Scenes do not survive a save load. See docs/developers/anim-engine.md §4.
namespace AnimEngine
{
    /// Starts a scene; actors are in position order. center: placement reference (nullptr = first actor).
    /// roles: OrgasmEngine roles per position (0 normal, 1 aggressor, 2 victim); empty = all normal.
    /// Returns the scene id, or -1 (disabled, unknown registry, wrong actor count, actor busy). Any thread: the game
    /// work runs as a task.
    int StartScene(const std::vector<RE::Actor*>& actors, const std::string& registry, RE::TESObjectREFR* center,
        const std::vector<std::int32_t>& roles = {});
    /// Follows the node's first edge; at a sink, ends the scene.
    bool Advance(int scene_id);
    /// Jumps to a node id (SLSB stage id, SLAL "1".."N").
    bool GoToNode(int scene_id, const std::string& node_id);
    /// Jumps to the final stage of the projected path (see StageView); no-op at a sink.
    bool GoToFinal(int scene_id);
    /// Back one step in the played history.
    bool Back(int scene_id);
    bool EndScene(int scene_id);
    /// Paused scenes keep their stage until Advance / GoToNode. Resume continues the stage's elapsed time.
    bool SetPaused(int scene_id, bool paused);
    bool TogglePaused(int scene_id);

    /// Stage holds (AnimEngineOrgasm: gate voice, victim, ending dialogue). A held stage does not auto-advance;
    /// its elapsed time keeps counting, so a release advances at the later of the timer and the hold. Entering a
    /// stage clears every hold. node: apply only while the scene is at this node index (-1 = any).
    enum class Hold : std::uint32_t
    {
        kGate = 1,
        kVictim = 2,
        kEnding = 4,
    };
    bool SetHold(int scene_id, Hold hold, bool on, int node = -1);

    /// The stage numbering OrgasmEngine works with. A linear graph (every SLAL animation): node index + 1 of all
    /// nodes. A branching graph (SLSB): the played history + the current node + its first-edge chain to a sink
    /// (what auto-advance plays; the P+ adapter model).
    struct StageView
    {
        int node = -1;                  // index into the playback nodes
        int stage = 0;                  // 1-based
        int count = 0;
        std::vector<float> secs;        // seconds per stage of the path
        bool at_sink = false;
        bool linear = true;
    };
    /// Scene id the actor is in, -1 when none.
    int SceneOf(RE::Actor* actor);
    /// Newest running scene id, -1 when none.
    int LatestScene();
    /// Debug state of a scene as JSON ("" when unknown).
    std::string DescribeJson(int scene_id);

    /// Orders two actors by the registry's position genders (female / male slots), creatures last; debug start.
    std::vector<RE::Actor*> OrderForRegistry(const std::vector<RE::Actor*>& actors, const std::string& registry);

    /// Tick thread (100 ms, game-thread work via AddTask). Call once at kDataLoaded.
    void Install();
    /// Drops every scene without touching actors (load / new game: the game state is being replaced).
    void ClearAll();

    void Save(SKSE::SerializationInterface* intfc);
    void Load(SKSE::SerializationInterface* intfc, std::uint32_t version, std::uint32_t length);
    void Revert();
    constexpr std::uint32_t kRecord = 'ANME';
    constexpr std::uint32_t kRecordVersion = 1;
}
