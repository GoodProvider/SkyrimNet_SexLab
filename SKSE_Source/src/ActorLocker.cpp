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

        // SkyrimNet action YAML and TargetMenu still gate on this StorageUtil key.
        constexpr const char* kStorageLockKey = "skyrimnet_sexlab_scene_actor_lock";

        void MirrorStorageUtilLock(RE::TESForm* form, bool locked)
        {
            if (!form)
                return;
            auto* vm = RE::BSScript::Internal::VirtualMachine::GetSingleton();
            if (!vm)
                return;
            RE::BSFixedString key(kStorageLockKey);
            RE::BSTSmartPointer<RE::BSScript::IStackCallbackFunctor> cb;
            if (locked) {
                auto* args =
                    RE::MakeFunctionArguments(static_cast<RE::TESForm*>(form), std::move(key), static_cast<std::int32_t>(1));
                vm->DispatchStaticCall(
                    RE::BSFixedString("StorageUtil"), RE::BSFixedString("SetIntValue"), args, cb);
            } else {
                auto* args = RE::MakeFunctionArguments(static_cast<RE::TESForm*>(form), std::move(key));
                vm->DispatchStaticCall(
                    RE::BSFixedString("StorageUtil"), RE::BSFixedString("UnsetIntValue"), args, cb);
            }
        }

        void MirrorStorageUtilUnlock(RE::Actor* actor)
        {
            MirrorStorageUtilLock(actor, false);
        }

        void MirrorStorageUtilLock(RE::Actor* actor)
        {
            MirrorStorageUtilLock(static_cast<RE::TESForm*>(actor), true);
        }
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
        if (inserted) {
            MirrorStorageUtilLock(actor);
            webui_log::info("ActorLocker: locked {:08X}", actor->GetFormID());
        }
        return inserted;
    }

    void Unlock(RE::Actor* actor)
    {
        if (!actor)
            return;
        std::lock_guard lock(g_mutex);
        if (g_locked.erase(actor->GetFormID())) {
            MirrorStorageUtilUnlock(actor);
            webui_log::info("ActorLocker: unlocked {:08X}", actor->GetFormID());
        }
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
        for (const auto id : g_locked) {
            if (auto* actor = RE::TESForm::LookupByID<RE::Actor>(id))
                MirrorStorageUtilUnlock(actor);
        }
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
        for (const auto id : g_locked) {
            if (auto* actor = RE::TESForm::LookupByID<RE::Actor>(id))
                MirrorStorageUtilUnlock(actor);
        }
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
            if (intfc->ResolveFormID(oldId, newId)) {
                g_locked.insert(newId);
                if (auto* actor = RE::TESForm::LookupByID<RE::Actor>(newId))
                    MirrorStorageUtilLock(actor);
            }
        }
        webui_log::info("ActorLocker: loaded {} lock(s)", g_locked.size());
    }

    void Revert()
    {
        Clear();
    }
}
