#pragma once

#include "PCH.h"

namespace PapyrusBindings_OrgasmEngine
{
    /// Natives for SkyrimNet_SexLab_OrgasmEngine.psc (public API + our Scene's shell calls).
    bool Register_OrgasmEngine_Functions(RE::BSScript::IVirtualMachine* a_vm);
}
