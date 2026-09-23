#pragma once

#include "PCH.h"

#include <cstdint>
#include <string>
#include <vector>

// C++ replacement for JContainers, scoped to this mod's own Papyrus scripts.
//
// Why this exists: the old design built payloads in JContainers (JC) and serialized them with a
// hand-rolled Papyrus walker (SkyrimNet_SexLab_Utilities.psc's JMapToJson/JArrayToJson/...). That
// walk took ~9s for a ~65-entry scene payload (hundreds of Papyrus<->native round trips). JC
// garbage-collects unowned temporary objects on a ~10s lifetime, and nothing on that path was
// retained, so JC destroyed the object tree mid-walk. Calls on the resulting dead handles
// returned a None *string*, which Papyrus renders as the literal text "NULL" -- not equal to ""
// -- producing invalid JSON that no existing guard could catch. See KNOWLEDGEBASE.md.
//
// This store has no garbage collector: a node lives until its owning root is explicitly freed or
// the game exits. Handles are (session, generation, slot)-tagged so a stale or cross-save handle
// fails loudly and deterministically instead of aliasing a live node.
namespace SexLabNet::Json
{
    using Handle = std::int32_t;
    inline constexpr Handle kInvalidHandle = 0;

    /// Matches JContainers' valueType encoding so ported Papyrus call sites need no changes:
    /// 0 - no value, 1 - none, 2 - int, 3 - float, 4 - form, 5 - object, 6 - string.
    enum class ValueType : std::int32_t
    {
        kNoValue = 0,
        kNone = 1,
        kInt = 2,
        kFloat = 3,
        kForm = 4,
        kObject = 5,
        kString = 6,
    };

    // --- Construction ---------------------------------------------------------------------
    Handle NewMap();
    Handle NewArray();
    Handle NewArrayWithSize(std::int32_t size);
    Handle NewFormMap();

    // --- Introspection ----------------------------------------------------------------------
    bool IsValid(Handle h);
    bool IsMap(Handle h);
    bool IsArray(Handle h);
    bool IsFormMap(Handle h);
    std::int32_t Count(Handle h);

    // --- Lifetime ---------------------------------------------------------------------------
    // There is no garbage collector, so Retain/Release aren't protecting against collection like
    // they do in JContainers. What they protect against: a root that is *also* embedded as a
    // value in some other container (e.g. a long-lived "last snapshot" handle re-attached into a
    // fresh, short-lived payload on every poll) needs to survive that container's Release. Retain
    // marks a root as independently owned; attaching an unowned-but-retained handle elsewhere then
    // copies it in rather than reparenting it, so the original stays alive under the retainer
    // until they Release it themselves. A plain "build it and attach it once, never call Retain"
    // handle is unaffected and still reparents for free (no copy).
    Handle Retain(Handle h);
    Handle Release(Handle h);
    Handle ReleaseAndRetain(Handle previous, Handle next);

    // --- Map (string-keyed) ops --------------------------------------------------------------
    std::int64_t MapGetInt(Handle h, const std::string& key, std::int64_t def);
    double MapGetFlt(Handle h, const std::string& key, double def);
    std::string MapGetStr(Handle h, const std::string& key, const std::string& def);
    Handle MapGetObj(Handle h, const std::string& key, Handle def);
    RE::TESForm* MapGetForm(Handle h, const std::string& key, RE::TESForm* def);

    void MapSetInt(Handle h, const std::string& key, std::int64_t v);
    void MapSetFlt(Handle h, const std::string& key, double v);
    void MapSetStr(Handle h, const std::string& key, const std::string& v);
    void MapSetObj(Handle h, const std::string& key, Handle child);
    void MapSetForm(Handle h, const std::string& key, RE::TESForm* v);

    std::int32_t MapValueType(Handle h, const std::string& key);
    /// previousKey="" starts iteration; returns "" once iteration is exhausted (matches JMap.nextKey).
    std::string MapNextKey(Handle h, const std::string& previousKey, const std::string& endKey);
    std::vector<std::string> MapAllKeysPArray(Handle h);
    Handle MapAllKeys(Handle h);

    // --- Array (index-keyed) ops --------------------------------------------------------------
    std::int64_t ArrayGetInt(Handle h, std::int32_t index, std::int64_t def);
    double ArrayGetFlt(Handle h, std::int32_t index, double def);
    std::string ArrayGetStr(Handle h, std::int32_t index, const std::string& def);
    Handle ArrayGetObj(Handle h, std::int32_t index, Handle def);
    RE::TESForm* ArrayGetForm(Handle h, std::int32_t index, RE::TESForm* def);

    void ArraySetInt(Handle h, std::int32_t index, std::int64_t v);
    void ArraySetFlt(Handle h, std::int32_t index, double v);
    void ArraySetStr(Handle h, std::int32_t index, const std::string& v);
    void ArraySetObj(Handle h, std::int32_t index, Handle child);
    void ArraySetForm(Handle h, std::int32_t index, RE::TESForm* v);

    /// addToIndex=-1 appends; matches JArray.addXxx.
    void ArrayAddInt(Handle h, std::int64_t v, std::int32_t addToIndex);
    void ArrayAddFlt(Handle h, double v, std::int32_t addToIndex);
    void ArrayAddStr(Handle h, const std::string& v, std::int32_t addToIndex);
    void ArrayAddObj(Handle h, Handle child, std::int32_t addToIndex);
    void ArrayAddForm(Handle h, RE::TESForm* v, std::int32_t addToIndex);

    std::int32_t ArrayValueType(Handle h, std::int32_t index);

    // --- FormMap (form-keyed) ops --------------------------------------------------------------
    Handle FormMapGetObj(Handle h, RE::TESForm* key, Handle def);
    void FormMapSetObj(Handle h, RE::TESForm* key, Handle child);
    std::int32_t FormMapValueType(Handle h, RE::TESForm* key);
    /// previousKey=None starts iteration; returns None once exhausted (matches JFormMap.nextKey).
    RE::TESForm* FormMapNextKey(Handle h, RE::TESForm* previousKey, RE::TESForm* endKey);

    // --- Parse / serialize / file IO -----------------------------------------------------------
    /// Parses JSON, lowercasing object keys as it builds the tree (last-wins on collision).
    /// Returns kInvalidHandle on parse failure (logged).
    Handle FromJsonPrototype(const std::string& json);
    /// Serializes in one pass. Object keys are already lowercase (set on insert), so this is not
    /// a second lowering pass. Form values render as JContainers' own "__formData|Plugin|0xID"
    /// token so nothing downstream (creatures.json, bondage catalog) has to change.
    std::string Dump(Handle h);
    Handle ReadFromFile(const std::string& path);
    void WriteToFile(Handle h, const std::string& path);

    // --- Lifecycle ---------------------------------------------------------------------------
    /// Bumps the session tag so every handle held across a save/load (in a Papyrus member
    /// variable serialized into the save) fails IsValid() deterministically instead of aliasing
    /// whatever now occupies that slot. Call from kPostLoadGame / kNewGame.
    void OnNewSession();
    std::string Stats();
}
