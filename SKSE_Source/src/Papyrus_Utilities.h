#pragma once

#include "PCH.h"

namespace PapyrusBindings_Utilities {
    /// Papyrus native: recursively lowercase all JSON object keys; return compact JSON string.
    RE::BSFixedString JsonLowerCaseKeys(RE::StaticFunctionTag*, RE::BSFixedString json);

    /// Papyrus native: JSON string literal (quoted, escaped). Replaces the per-character Papyrus loop.
    RE::BSFixedString JsonQuote(RE::StaticFunctionTag*, RE::BSFixedString s);

    /// Papyrus native: hex entity UUID -> decimal string; decimal input returned unchanged.
    RE::BSFixedString UuidToDecimalString(RE::StaticFunctionTag*, RE::BSFixedString entityUuid);

    /// SkyrimNet `type: hotkey` stores a virtual-key code. RegisterForKey wants DX.
    std::int32_t VkToDxScanCode(RE::StaticFunctionTag*, std::int32_t vk);

    /// Registers SkyrimNet_SexLab_Utilities natives on the Papyrus VM.
    bool Register_Utilities_Functions(RE::BSScript::IVirtualMachine* a_vm);
}
