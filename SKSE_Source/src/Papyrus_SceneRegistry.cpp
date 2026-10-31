#include "Papyrus_SceneRegistry.h"

#include "SceneRegistry.h"

namespace PapyrusBindings_SceneRegistry
{
    namespace
    {
        std::int32_t Registry_SidOf(RE::StaticFunctionTag*, RE::Actor* actor)
        {
            return Scenes::Registry::SidOf(actor);
        }

        bool Registry_IsBusy(RE::StaticFunctionTag*, RE::Actor* actor)
        {
            return Scenes::Registry::IsBusy(actor);
        }

        RE::BSFixedString Registry_Describe(RE::StaticFunctionTag*)
        {
            return RE::BSFixedString(Scenes::Registry::DescribeJson());
        }
    }

    bool Register_SceneRegistry_Functions(RE::BSScript::IVirtualMachine* a_vm)
    {
        if (!a_vm)
            return false;
        constexpr std::string_view scriptName = "SkyrimNet_SexLab_Registry";
        a_vm->RegisterFunction("Registry_SidOf", scriptName, Registry_SidOf, true);
        a_vm->RegisterFunction("Registry_IsBusy", scriptName, Registry_IsBusy, true);
        a_vm->RegisterFunction("Registry_Describe", scriptName, Registry_Describe, true);
        return true;
    }
}
