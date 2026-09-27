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

    /// Papyrus natives: actor animation playback multiplier (0.1..3.0; 1.0 clears). Speed only.
    void SetAnimSpeed(RE::StaticFunctionTag*, RE::Actor* akActor, float speed);
    void ClearAnimSpeed(RE::StaticFunctionTag*, RE::Actor* akActor);
    float GetAnimSpeed(RE::StaticFunctionTag*, RE::Actor* akActor);

    /// Papyrus native: queue a DirectNarration while the game is paused (joined + sent on unpause).
    /// False when not paused: the caller sends it now.
    bool QueueDirectNarration(RE::StaticFunctionTag*, RE::BSFixedString msg, RE::Actor* source,
        RE::Actor* target, bool purgeDialogue);

    /// Registers SkyrimNet_SexLab_Utilities natives on the Papyrus VM.
    bool Register_Utilities_Functions(RE::BSScript::IVirtualMachine* a_vm);
}
