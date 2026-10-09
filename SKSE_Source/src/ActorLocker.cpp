#include "ActorLocker.h"

#include "WebUI_Log.h"

#include <mutex>
#include <unordered_set>

namespace ActorLocker
{
    namespace
    {
        std::mutex g_mutex;
        std::unordered_set<RE::FormID> g_locked;
    }

    RE::TESFaction* SexLabAnimatingFaction()
    {
        static RE::TESFaction* cached = nullptr;
        static bool resolved = false;
        if (!resolved) {
            resolved = true;
            if (auto* dh = RE::TESDataHandler::GetSingleton())
                cached = dh->LookupForm<RE::TESFaction>(0xE50F, "SexLab.esm");
        }
        return cached;
    }

    RE::TESFaction* OstimActorCountFaction()
    {
        static RE::TESFaction* cached = nullptr;
        static bool resolved = false;
        if (!resolved) {
            resolved = true;
            auto* dh = RE::TESDataHandler::GetSingleton();
            if (dh && dh->LookupModByName("Ostim.esp"))
                cached = dh->LookupForm<RE::TESFaction>(0xECA, "Ostim.esp");
        }
        return cached;
    }

    bool TryLock(RE::Actor* actor)
    {
        if (!actor || actor->IsDeleted() || actor->IsDead() || actor->IsInCombat())
            return false;
        if (auto* f = SexLabAnimatingFaction(); f && actor->IsInFaction(f))
            return false;
        if (auto* f = OstimActorCountFaction(); f && actor->IsInFaction(f))
            return false;
        std::lock_guard lock(g_mutex);
        const bool inserted = g_locked.insert(actor->GetFormID()).second;
        if (inserted)
            webui_log::info("ActorLocker: locked {:08X}", actor->GetFormID());
        return inserted;
    }

    void Unlock(RE::Actor* actor)
    {
        if (!actor)
            return;
        std::lock_guard lock(g_mutex);
        if (g_locked.erase(actor->GetFormID()))
            webui_log::info("ActorLocker: unlocked {:08X}", actor->GetFormID());
    }

    bool IsLocked(RE::Actor* actor)
    {
        if (!actor)
            return false;
        std::lock_guard lock(g_mutex);
        return g_locked.contains(actor->GetFormID());
    }

    void Clear()
    {
        std::lock_guard lock(g_mutex);
        g_locked.clear();
    }

    void Save(SKSE::SerializationInterface* intfc)
    {
        std::lock_guard lock(g_mutex);
        if (!intfc->OpenRecord(kRecord, kRecordVersion)) {
            webui_log::error("ActorLocker: failed to open co-save record");
            return;
        }
        intfc->WriteRecordData(static_cast<std::uint32_t>(g_locked.size()));
        for (auto id : g_locked)
            intfc->WriteRecordData(id);
    }

    void Load(SKSE::SerializationInterface* intfc, std::uint32_t version, std::uint32_t)
    {
        std::lock_guard lock(g_mutex);
        g_locked.clear();
        if (version != kRecordVersion)
            return;
        std::uint32_t n = 0;
        if (!intfc->ReadRecordData(n))
            return;
        for (std::uint32_t i = 0; i < n; ++i) {
            RE::FormID oldId = 0, newId = 0;
            if (!intfc->ReadRecordData(oldId))
                return;
            if (intfc->ResolveFormID(oldId, newId))
                g_locked.insert(newId);
        }
        webui_log::info("ActorLocker: loaded {} lock(s)", g_locked.size());
    }

    void Revert()
    {
        Clear();
    }
}
