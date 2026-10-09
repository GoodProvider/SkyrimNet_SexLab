#pragma once

#include "PCH.h"

#include <cstdint>

/// Pre-start scene lock: an actor held by a Scene_Creator cannot be claimed by another
/// creator and is excluded from the Scene Creator actor table. State persists in the co-save.
/// Papyrus surface: SkyrimNet_SexLab_Locker.psc.
namespace ActorLocker
{
    /// Locks `actor`. False when None/dead/combat/already locked/in SexLab or OStim.
    bool TryLock(RE::Actor* actor);
    void Unlock(RE::Actor* actor);
    bool IsLocked(RE::Actor* actor);
    void Clear();

    /// SexLab.esm AnimatingFaction (0xE50F); nullptr if missing.
    RE::TESFaction* SexLabAnimatingFaction();
    /// Ostim.esp ActorCount faction (0xECA); nullptr if OStim is not loaded.
    RE::TESFaction* OstimActorCountFaction();

    void Save(SKSE::SerializationInterface* intfc);
    void Load(SKSE::SerializationInterface* intfc, std::uint32_t version, std::uint32_t length);
    void Revert();
    constexpr std::uint32_t kRecord = 'ALCK';
    constexpr std::uint32_t kRecordVersion = 1;
}
