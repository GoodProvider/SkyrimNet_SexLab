#include "Papyrus_ActorLocker.h"

#include "ActorLocker.h"
#include "WebUI_Log.h"

#include <vector>

namespace PapyrusBindings_ActorLocker
{
    namespace
    {
        bool Lock(RE::StaticFunctionTag*, RE::Actor* a) { return ActorLocker::TryLock(a); }
        void Unlock(RE::StaticFunctionTag*, RE::Actor* a) { ActorLocker::Unlock(a); }
        bool IsLocked(RE::StaticFunctionTag*, RE::Actor* a) { return ActorLocker::IsLocked(a); }

        /// All-or-nothing: on any failure, unlocks the ones this call locked.
        bool LockAll(RE::StaticFunctionTag*, std::vector<RE::Actor*> actors)
        {
            std::vector<RE::Actor*> done;
            for (auto* a : actors) {
                if (!a)
                    continue;
                if (!ActorLocker::TryLock(a)) {
                    for (auto* d : done)
                        ActorLocker::Unlock(d);
                    return false;
                }
                done.push_back(a);
            }
            return !done.empty();
        }

        void UnlockAll(RE::StaticFunctionTag*, std::vector<RE::Actor*> actors)
        {
            for (auto* a : actors)
                ActorLocker::Unlock(a);
        }
    }

    bool Register_ActorLocker_Functions(RE::BSScript::IVirtualMachine* a_vm)
    {
        if (!a_vm) {
            webui_log::error("Couldn't get Papyrus Virtual Machine.");
            return false;
        }
        constexpr std::string_view s = "SkyrimNet_SexLab_Locker";
        a_vm->RegisterFunction("Lock", s, Lock);
        a_vm->RegisterFunction("Unlock", s, Unlock);
        a_vm->RegisterFunction("IsLocked", s, IsLocked);
        a_vm->RegisterFunction("LockAll", s, LockAll);
        a_vm->RegisterFunction("UnlockAll", s, UnlockAll);
        return true;
    }
}
