#pragma once

#include "PCH.h"

namespace PapyrusBindings_Utilities {
    /// Papyrus native: recursively lowercase all JSON object keys; return compact JSON string.
    RE::BSFixedString JsonLowerCaseKeys(RE::StaticFunctionTag*, RE::BSFixedString json);

    /// SkyrimNet `type: hotkey` stores a virtual-key code. RegisterForKey wants DX.
    std::int32_t VkToDxScanCode(RE::StaticFunctionTag*, std::int32_t vk);

    /// Registers SkyrimNet_SexLab_Utilities natives on the Papyrus VM.
    bool Register_Utilities_Functions(RE::BSScript::IVirtualMachine* a_vm);
}
