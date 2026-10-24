#pragma once

#include "PCH.h"

#include <cstdint>
#include <string>

/// SkyrimNet decorator callbacks (registered in Config.cpp RegisterDecorators, the only file that
/// may include PublicAPI.h) and the C++ state behind them. Callbacks run on SkyrimNet worker
/// threads: they read only mutex-guarded state here, the JSON store and OrgasmEngine.
/// Papyrus surface: SkyrimNet_SexLab_Decorators.psc (scenes push thread_obj, cum is recorded here).
namespace Decorators
{
    /// sexlab_get_threads: {"counter","threads":[...]} for every listed SexLab scene + DOM thread,
    /// with live OrgasmEngine fields and this speaker's speaker_name / speaker_distance / speaker_los.
    std::string GetThreads(RE::Actor* speaker);
    /// sexlab_activities: {"activity": stage description of the actor's scene, "" when none}.
    std::string Activities(RE::Actor* actor);
    /// sexlab_cum: {"warm","drying","warm_mouth","drying_mouth"} (0416_sexlab_cum.prompt).
    std::string Cum(RE::Actor* actor);
    /// sexlab_has_cum: "1" when any place on the actor still has cum, else "0".
    std::string HasCum(RE::Actor* actor);
    /// sexlab_cum_count: number of actors with cum (SexLab_Clean_Cum eligibility). Actor ignored.
    std::string CumCount(RE::Actor* actor);
    /// sexlab_has_stripped_items: "1" when the actor has stored stripped clothing (outfit_dress /
    /// outfit_undress eligibility), else "0". Mirrored from Papyrus via SetStrippedItems.
    std::string HasStrippedItems(RE::Actor* actor);

    /// TargetMenu eligibility (ActionCatalog EvalCondition).
    bool ActorHasCum(RE::Actor* actor);

    /// Thread registry + LOS cache: SexLab drops every scene on load.
    void ClearOnGameLoad();

    /// Cum state co-save record.
    void Save(SKSE::SerializationInterface* intfc);
    void Load(SKSE::SerializationInterface* intfc, std::uint32_t version, std::uint32_t length);
    void Revert();
    constexpr std::uint32_t kRecord = 'SCUM';
    constexpr std::uint32_t kRecordVersion = 1;

    /// Stripped-items mirror co-save record.
    void SaveStripped(SKSE::SerializationInterface* intfc);
    void LoadStripped(SKSE::SerializationInterface* intfc, std::uint32_t version, std::uint32_t length);
    constexpr std::uint32_t kStrippedRecord = 'SSTR';
    constexpr std::uint32_t kStrippedRecordVersion = 1;

    /// Natives for SkyrimNet_SexLab_Decorators.psc.
    bool Register_Papyrus(RE::BSScript::IVirtualMachine* a_vm);
}
