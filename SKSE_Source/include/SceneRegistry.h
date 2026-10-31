#pragma once

#include "PCH.h"

#include <cstdint>
#include <string>
#include <vector>

/// Scenes::Registry: native pool of the running scenes, keyed by (kind, id), with an actor index.
/// Strangler step 1 of docs/developers/scene-migration.md §8. SexLab scenes are fed by Decorators Threads_Set /
/// Threads_Remove (id = the Papyrus pool sid); AnimEngine scenes by AnimEngine (id = its scene id).
/// Manager.GetSceneByActor / IsBusy read it while sexlab.scene_registry.enabled is on.
namespace Scenes::Registry
{
    enum class Kind : std::uint32_t
    {
        SexLab = 0,
        AnimEngine = 1,
    };

    /// Adds or replaces the scene's actor list.
    void Register(Kind kind, int id, const std::vector<RE::FormID>& actors);
    void Unregister(Kind kind, int id);
    /// Drops every scene of one kind (AnimEngine::ClearAll).
    void ClearKind(Kind kind);
    /// Papyrus pool sid of the SexLab scene the actor is in, -1 when none.
    int SidOf(RE::Actor* actor);
    /// The actor is in any registered scene (SexLab or AnimEngine).
    bool IsBusy(RE::Actor* actor);
    std::string DescribeJson();

    void Save(SKSE::SerializationInterface* intfc);
    /// Scenes never survive a load (SexLab cancels its threads, AnimEngine releases its actors): the record is read,
    /// logged and dropped.
    void Load(SKSE::SerializationInterface* intfc, std::uint32_t version, std::uint32_t length);
    void Revert();
    constexpr std::uint32_t kRecord = 'SREG';
    constexpr std::uint32_t kRecordVersion = 1;
}
