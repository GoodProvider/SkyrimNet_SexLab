#pragma once

#include "PCH.h"

// Papyrus bindings for the C++ JSON store (JsonStore.h). Registered under script names that
// mirror JContainers' own (SNSL_JMap / SNSL_JArray / SNSL_JValue / SNSL_JFormMap) so existing
// call sites migrate with a mechanical `JMap.` -> `SNSL_JMap.` rename. See
// checkpoints/skse-scene/ and KNOWLEDGEBASE.md for why this store exists.
namespace PapyrusBindings_Json
{
    /// Registers SNSL_JMap, SNSL_JArray, SNSL_JValue, SNSL_JFormMap natives on the Papyrus VM.
    bool Register_Json_Functions(RE::BSScript::IVirtualMachine* a_vm);
}
