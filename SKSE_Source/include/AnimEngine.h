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
    /// Returns the scene id, or -1 (disabled, unknown registry, wrong actor count, actor busy). Any thread: the game
    /// work runs as a task.
    int StartScene(const std::vector<RE::Actor*>& actors, const std::string& registry, RE::TESObjectREFR* center);
    /// Follows the node's first edge; at a sink, ends the scene.
    bool Advance(int scene_id);
    /// Jumps to a node id (SLSB stage id, SLAL "1".."N").
    bool GoToNode(int scene_id, const std::string& node_id);
    /// Back one step in the played history.
    bool Back(int scene_id);
    bool EndScene(int scene_id);
    /// Paused scenes keep their stage until Advance / GoToNode.
    bool SetPaused(int scene_id, bool paused);
    bool TogglePaused(int scene_id);
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
