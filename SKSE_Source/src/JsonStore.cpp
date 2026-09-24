#include "JsonStore.h"
#include "WebUI_Log.h"

#include <algorithm>
#include <cctype>
#include <fstream>
#include <mutex>
#include <sstream>
#include <vector>

#include <nlohmann/json.hpp>

// See JsonStore.h for the "why" (JContainers GC destroying in-flight payloads mid-walk).
//
// Handle layout (int32, never 0 for a real allocation -- slot 0 is a permanently reserved dummy):
//   bits 31..26  session (6 bits) -- bumped on kPostLoadGame/kNewGame; invalidates every handle
//                                    that was serialized into a save (Papyrus member variables).
//   bits 25..18  generation (8 bits) -- bumped whenever a slot is freed and reused.
//   bits 17..0   slot index (18 bits, up to 262143 concurrent live nodes).
//
// A container node is either a root (caller-owned, freed explicitly) or parented (owned by
// exactly one container that holds it as a value). There is no refcounting and no GC: Release()
// on a parented handle is a no-op (matches JContainers' behavior of never destroying an object a
// live container still references), and Release() on a root frees the whole subtree.
namespace SexLabNet::Json
{
    namespace
    {
        constexpr std::uint32_t kSessionBits = 6;
        constexpr std::uint32_t kGenBits = 8;
        constexpr std::uint32_t kSlotBits = 18;
        constexpr std::uint32_t kSlotMask = (1u << kSlotBits) - 1u;
        constexpr std::uint32_t kGenMask = (1u << kGenBits) - 1u;
        constexpr std::uint32_t kSessionMask = (1u << kSessionBits) - 1u;

        struct FormRef
        {
            std::uint32_t localId = 0;
            std::string file;

            bool IsNone() const { return localId == 0 && file.empty(); }
            bool operator==(const FormRef& o) const { return localId == o.localId && file == o.file; }
        };

        struct Value
        {
            ValueType type = ValueType::kNoValue;
            std::int64_t i = 0;
            double f = 0.0;
            std::string s;
            FormRef form;
            Handle obj = kInvalidHandle;
        };

        struct Node
        {
            bool alive = false;
            bool isArray = false;
            bool isFormMap = false;
            std::vector<Value> arr;                               // isArray
            std::vector<std::pair<std::string, Value>> map;        // !isArray && !isFormMap
            std::vector<std::pair<FormRef, Value>> formMap;        // isFormMap

            std::int32_t parentSlot = -1;
            std::uint32_t gen = 0;
            std::uint32_t session = 0;
            /// Set by Retain(), cleared by Release(). Protects a root that is *also* meant to be
            /// embedded in a container it doesn't own the lifetime of -- e.g. Scene_Manager.psc's
            /// last_ended_obj: retained once, then re-embedded into a fresh, short-lived array on
            /// every BuildAllSceneInfosJson call. Without this, AttachChild's plain reparent-on-
            /// attach would hand last_ended_obj's ownership to that temporary array, and releasing
            /// the temporary root would destroy last_ended_obj on the very next call.
            std::uint16_t retainCount = 0;
        };

        std::recursive_mutex g_mutex;
        std::vector<Node> g_slots;
        std::vector<std::int32_t> g_freeSlots;
        std::uint32_t g_session = 1;
        std::uint64_t g_reparentCopies = 0;

        void EnsureDummySlot()
        {
            if (g_slots.empty()) {
                g_slots.emplace_back();  // slot 0: permanently dead, never issued
            }
        }

        Handle EncodeHandle(std::uint32_t session, std::uint32_t gen, std::uint32_t slot)
        {
            return static_cast<Handle>(((session & kSessionMask) << (kGenBits + kSlotBits)) |
                                        ((gen & kGenMask) << kSlotBits) | (slot & kSlotMask));
        }

        struct HandleParts
        {
            std::uint32_t session;
            std::uint32_t gen;
            std::uint32_t slot;
        };

        HandleParts DecodeHandle(Handle h)
        {
            const auto u = static_cast<std::uint32_t>(h);
            return HandleParts{
                (u >> (kGenBits + kSlotBits)) & kSessionMask,
                (u >> kSlotBits) & kGenMask,
                u & kSlotMask,
            };
        }

        /// Resolves a handle to its live node, or nullptr (logged) if the handle is stale,
        /// out of range, or from a prior save/load session.
        Node* Resolve(Handle h)
        {
            if (h == kInvalidHandle) {
                return nullptr;
            }
            const auto parts = DecodeHandle(h);
            if (parts.slot == 0 || parts.slot >= g_slots.size()) {
                webui_log::error("dead handle 0x{:X} (slot {} out of range)", static_cast<std::uint32_t>(h), parts.slot);
                return nullptr;
            }
            Node& n = g_slots[parts.slot];
            if (!n.alive || n.gen != parts.gen || n.session != parts.session) {
                webui_log::error("dead handle 0x{:X} (slot={} alive={} gen={}/{} session={}/{})",
                    static_cast<std::uint32_t>(h), parts.slot, n.alive, parts.gen, n.gen, parts.session, n.session);
                return nullptr;
            }
            return &n;
        }

        std::int32_t AllocSlot()
        {
            EnsureDummySlot();
            if (!g_freeSlots.empty()) {
                const std::int32_t slot = g_freeSlots.back();
                g_freeSlots.pop_back();
                return slot;
            }
            if (g_slots.size() > kSlotMask) {
                webui_log::critical("JSON store exhausted ({} live slots) -- leaking roots somewhere", g_slots.size());
                return 0;
            }
            g_slots.emplace_back();
            return static_cast<std::int32_t>(g_slots.size() - 1);
        }

        Handle NewNode(bool isArray, bool isFormMap)
        {
            std::lock_guard lock(g_mutex);
            const std::int32_t slot = AllocSlot();
            if (slot == 0) {
                return kInvalidHandle;
            }
            Node& n = g_slots[slot];
            n.alive = true;
            n.isArray = isArray;
            n.isFormMap = isFormMap;
            n.arr.clear();
            n.map.clear();
            n.formMap.clear();
            n.parentSlot = -1;
            n.session = g_session;
            return EncodeHandle(n.session, n.gen, static_cast<std::uint32_t>(slot));
        }

        void ToLowerAscii(std::string& s)
        {
            std::transform(s.begin(), s.end(), s.begin(), [](unsigned char c) { return static_cast<char>(std::tolower(c)); });
        }

        void FreeSlotRecursive(std::int32_t slot);

        /// Called when a slot is overwritten or a container is freed. Ownership is exclusive, so
        /// this normally tears an owned child down -- unless that child is *also* explicitly
        /// retained (retainCount > 0), in which case it just detaches (parentSlot = -1) and
        /// leaves it alive: something else still explicitly owns its lifetime. Not currently hit
        /// by any call site (retain-then-embed always goes through AttachChild's copy path
        /// instead), but a container freeing a still-retained child must never destroy it.
        void FreeValueChild(const Value& v)
        {
            if (v.type != ValueType::kObject || v.obj == kInvalidHandle) {
                return;
            }
            const auto parts = DecodeHandle(v.obj);
            if (parts.slot == 0 || parts.slot >= g_slots.size() || !g_slots[parts.slot].alive) {
                return;
            }
            if (g_slots[parts.slot].retainCount > 0) {
                g_slots[parts.slot].parentSlot = -1;
                return;
            }
            FreeSlotRecursive(static_cast<std::int32_t>(parts.slot));
        }

        void FreeSlotRecursive(std::int32_t slot)
        {
            if (slot <= 0 || static_cast<std::size_t>(slot) >= g_slots.size()) {
                return;
            }
            Node& n = g_slots[slot];
            if (!n.alive) {
                return;
            }
            for (auto& v : n.arr) FreeValueChild(v);
            for (auto& kv : n.map) FreeValueChild(kv.second);
            for (auto& kv : n.formMap) FreeValueChild(kv.second);
            n.alive = false;
            n.retainCount = 0;
            n.arr.clear();
            n.map.clear();
            n.formMap.clear();
            n.parentSlot = -1;
            n.gen = (n.gen + 1) & kGenMask;
            g_freeSlots.push_back(slot);
        }

        /// Deep-copies a live subtree into fresh slots. Used when a handle already owned by one
        /// container is attached to a second container -- JContainers would share that object by
        /// reference (refcounting); this store has single ownership, so it copies instead and the
        /// caller logs why. Kept rare in practice: audit every log hit during migration.
        Handle DeepCopy(std::int32_t srcSlot)
        {
            if (srcSlot <= 0 || static_cast<std::size_t>(srcSlot) >= g_slots.size() || !g_slots[srcSlot].alive) {
                return kInvalidHandle;
            }
            // Snapshot by value before doing anything that can recurse: DeepCopy -> NewNode ->
            // g_slots.emplace_back() can reallocate the whole g_slots vector, so a live reference
            // or iterator into g_slots[srcSlot]'s vectors would dangle mid-loop otherwise.
            const bool srcIsArray = g_slots[srcSlot].isArray;
            const bool srcIsFormMap = g_slots[srcSlot].isFormMap;
            const std::vector<Value> srcArr = g_slots[srcSlot].arr;
            const std::vector<std::pair<std::string, Value>> srcMap = g_slots[srcSlot].map;
            const std::vector<std::pair<FormRef, Value>> srcFormMap = g_slots[srcSlot].formMap;

            const Handle dst = NewNode(srcIsArray, srcIsFormMap);
            if (dst == kInvalidHandle) {
                return kInvalidHandle;
            }
            const std::int32_t dstSlot = DecodeHandle(dst).slot;

            auto copyValue = [](const Value& v) -> Value {
                Value out = v;
                if (v.type == ValueType::kObject && v.obj != kInvalidHandle) {
                    out.obj = DeepCopy(DecodeHandle(v.obj).slot);
                    if (out.obj != kInvalidHandle) {
                        g_slots[DecodeHandle(out.obj).slot].parentSlot = -1;  // set by caller below
                    }
                }
                return out;
            };

            {
                std::vector<Value> arrCopy;
                std::vector<std::pair<std::string, Value>> mapCopy;
                std::vector<std::pair<FormRef, Value>> formMapCopy;
                arrCopy.reserve(srcArr.size());
                for (auto& v : srcArr) arrCopy.push_back(copyValue(v));
                mapCopy.reserve(srcMap.size());
                for (auto& kv : srcMap) mapCopy.emplace_back(kv.first, copyValue(kv.second));
                formMapCopy.reserve(srcFormMap.size());
                for (auto& kv : srcFormMap) formMapCopy.emplace_back(kv.first, copyValue(kv.second));

                Node& dstNode = g_slots[dstSlot];
                dstNode.arr = std::move(arrCopy);
                dstNode.map = std::move(mapCopy);
                dstNode.formMap = std::move(formMapCopy);
                for (auto& v : dstNode.arr) if (v.type == ValueType::kObject && v.obj != kInvalidHandle) g_slots[DecodeHandle(v.obj).slot].parentSlot = dstSlot;
                for (auto& kv : dstNode.map) if (kv.second.type == ValueType::kObject && kv.second.obj != kInvalidHandle) g_slots[DecodeHandle(kv.second.obj).slot].parentSlot = dstSlot;
                for (auto& kv : dstNode.formMap) if (kv.second.type == ValueType::kObject && kv.second.obj != kInvalidHandle) g_slots[DecodeHandle(kv.second.obj).slot].parentSlot = dstSlot;
            }
            return dst;
        }

        /// Attaches `child` as an owned value. Reparents it if unowned and not independently
        /// retained (the common build-and-forget idiom: cheap, no copy). Deep-copies (and logs)
        /// if it already has an owner, OR if it's unowned but explicitly retained -- a caller
        /// that retained a handle keeps it independently alive across being embedded elsewhere
        /// (matches JContainers refcounting for that pattern; see Node::retainCount and
        /// Scene_Manager.psc's last_ended_obj). Returns the handle actually stored (== child,
        /// unless copied).
        Handle AttachChild(std::int32_t parentSlot, Handle child, const char* where)
        {
            if (child == kInvalidHandle) {
                return kInvalidHandle;
            }
            const auto parts = DecodeHandle(child);
            if (parts.slot == 0 || parts.slot >= g_slots.size() || !g_slots[parts.slot].alive ||
                g_slots[parts.slot].gen != parts.gen || g_slots[parts.slot].session != parts.session) {
                webui_log::error("{}: attaching a dead handle 0x{:X}, storing no-value instead", where, static_cast<std::uint32_t>(child));
                return kInvalidHandle;
            }
            if (g_slots[parts.slot].parentSlot == -1 && g_slots[parts.slot].retainCount == 0) {
                g_slots[parts.slot].parentSlot = parentSlot;
                return child;
            }
            if (g_slots[parts.slot].parentSlot == -1) {
                // Unowned but explicitly retained: give the container an independent copy and
                // leave the original alone (no log -- this is the expected, intended path).
                const Handle copy = DeepCopy(static_cast<std::int32_t>(parts.slot));
                if (copy != kInvalidHandle) {
                    g_slots[DecodeHandle(copy).slot].parentSlot = parentSlot;
                }
                return copy;
            }
            if (g_slots[parts.slot].parentSlot == parentSlot) {
                return child;  // already attached here (e.g. re-set the same key to the same handle)
            }
            ++g_reparentCopies;
            webui_log::error("{}: handle 0x{:X} already owned by slot {}; deep-copying into slot {} ({} copies so far)",
                where, static_cast<std::uint32_t>(child), g_slots[parts.slot].parentSlot, parentSlot, g_reparentCopies);
            const Handle copy = DeepCopy(static_cast<std::int32_t>(parts.slot));
            if (copy != kInvalidHandle) {
                g_slots[DecodeHandle(copy).slot].parentSlot = parentSlot;
            }
            return copy;
        }

        // --- Form token formatting: must match BondageCatalog.cpp's FormData() exactly, since
        // creatures.json / group-devices.json already contain "__formData|Plugin|0xID" tokens
        // written by that code and read back by this store's Dump/parse paths. ---
        std::uint32_t LocalFormId(const RE::TESForm* form, const RE::TESFile* file)
        {
            if (!form) return 0;
            const std::uint32_t id = form->GetFormID();
            if (file && file->IsLight()) return id & 0xFFFu;
            return id & 0xFFFFFFu;
        }

        FormRef MakeFormRef(RE::TESForm* form)
        {
            if (!form) {
                return {};
            }
            const auto* file = form->GetFile();
            FormRef ref;
            ref.localId = LocalFormId(form, file);
            ref.file = file ? std::string(file->GetFilename()) : std::string();
            return ref;
        }

        RE::TESForm* ResolveFormRef(const FormRef& ref)
        {
            if (ref.IsNone()) {
                return nullptr;
            }
            auto* dh = RE::TESDataHandler::GetSingleton();
            if (!dh) {
                return nullptr;
            }
            return dh->LookupForm<RE::TESForm>(ref.localId, ref.file);
        }

        std::string FormToken(const FormRef& ref)
        {
            if (ref.IsNone()) {
                return "null";
            }
            std::ostringstream oss;
            oss << "__formData|" << ref.file << "|0x" << std::hex << ref.localId;
            return oss.str();
        }

        // --- Dump: Node graph -> nlohmann::json -> compact string. ---
        nlohmann::json ValueToJson(const Value& v);

        nlohmann::json NodeToJson(const Node& n)
        {
            if (n.isArray) {
                auto out = nlohmann::json::array();
                for (const auto& v : n.arr) out.push_back(ValueToJson(v));
                return out;
            }
            if (n.isFormMap) {
                auto out = nlohmann::json::object();
                for (const auto& kv : n.formMap) {
                    if (kv.first.IsNone()) {
                        webui_log::warn("FormMap entry with a None key skipped in Dump");
                        continue;
                    }
                    out[FormToken(kv.first)] = ValueToJson(kv.second);
                }
                return out;
            }
            auto out = nlohmann::json::object();
            for (const auto& kv : n.map) out[kv.first] = ValueToJson(kv.second);
            return out;
        }

        nlohmann::json ValueToJson(const Value& v)
        {
            switch (v.type) {
            case ValueType::kInt: return v.i;
            case ValueType::kFloat: return v.f;
            case ValueType::kString: return v.s;
            case ValueType::kForm: return v.form.IsNone() ? nlohmann::json(nullptr) : nlohmann::json(FormToken(v.form));
            case ValueType::kObject: {
                if (v.obj == kInvalidHandle) return nullptr;
                const auto parts = DecodeHandle(v.obj);
                if (parts.slot == 0 || parts.slot >= g_slots.size() || !g_slots[parts.slot].alive) return nullptr;
                return NodeToJson(g_slots[parts.slot]);
            }
            case ValueType::kNone:
            case ValueType::kNoValue:
            default:
                return nullptr;
            }
        }

        // --- Parse: nlohmann::json -> Node graph, lowercasing object keys as it goes. ---
        Handle BuildFromJson(const nlohmann::json& j);

        void SetMapValueFromJson(Handle mapHandle, std::string key, const nlohmann::json& v);
        void AddArrayValueFromJson(Handle arrHandle, const nlohmann::json& v);

        Handle BuildFromJson(const nlohmann::json& j)
        {
            if (j.is_object()) {
                const Handle h = NewMap();
                for (auto it = j.begin(); it != j.end(); ++it) {
                    std::string key = it.key();
                    ToLowerAscii(key);
                    SetMapValueFromJson(h, std::move(key), it.value());
                }
                return h;
            }
            if (j.is_array()) {
                const Handle h = NewArray();
                for (const auto& v : j) {
                    AddArrayValueFromJson(h, v);
                }
                return h;
            }
            webui_log::warn("FromJsonPrototype: top-level scalar has no container representation");
            return kInvalidHandle;
        }
    }

    // ============================================================================================
    // Public API
    // ============================================================================================

    Handle NewMap() { return NewNode(false, false); }
    Handle NewArray() { return NewNode(true, false); }
    Handle NewFormMap() { return NewNode(false, true); }

    Handle NewArrayWithSize(std::int32_t size)
    {
        std::lock_guard lock(g_mutex);
        const Handle h = NewNode(true, false);
        if (h == kInvalidHandle || size <= 0) {
            return h;
        }
        Node* n = Resolve(h);
        if (!n) return h;
        n->arr.assign(static_cast<std::size_t>(size), Value{ ValueType::kNone });
        return h;
    }

    bool IsValid(Handle h) { std::lock_guard lock(g_mutex); return Resolve(h) != nullptr; }
    bool IsMap(Handle h) { std::lock_guard lock(g_mutex); auto* n = Resolve(h); return n && !n->isArray && !n->isFormMap; }
    bool IsArray(Handle h) { std::lock_guard lock(g_mutex); auto* n = Resolve(h); return n && n->isArray; }
    bool IsFormMap(Handle h) { std::lock_guard lock(g_mutex); auto* n = Resolve(h); return n && n->isFormMap; }

    std::int32_t Count(Handle h)
    {
        std::lock_guard lock(g_mutex);
        auto* n = Resolve(h);
        if (!n) return 0;
        if (n->isArray) return static_cast<std::int32_t>(n->arr.size());
        if (n->isFormMap) return static_cast<std::int32_t>(n->formMap.size());
        return static_cast<std::int32_t>(n->map.size());
    }

    Handle Retain(Handle h)
    {
        std::lock_guard lock(g_mutex);
        auto* n = Resolve(h);
        if (!n) {
            webui_log::warn("Retain on dead handle 0x{:X}", static_cast<std::uint32_t>(h));
            return h;
        }
        // There is no GC here, so this isn't protecting against collection like it does in
        // JContainers -- it protects against AttachChild reparenting this handle out from under
        // an independent owner when it's *also* embedded in a container (see Node::retainCount).
        if (n->retainCount < 0xFFFFu) {
            ++n->retainCount;
        }
        return h;
    }

    Handle Release(Handle h)
    {
        std::lock_guard lock(g_mutex);
        auto* n = Resolve(h);
        if (!n) {
            return kInvalidHandle;
        }
        if (n->retainCount > 0) {
            --n->retainCount;
            if (n->retainCount > 0) {
                return kInvalidHandle;  // still retained elsewhere
            }
        }
        if (n->parentSlot != -1) {
            // Matches JContainers: releasing an object a live container still references does not
            // destroy it. It goes away when the owning root is released.
            return kInvalidHandle;
        }
        FreeSlotRecursive(static_cast<std::int32_t>(DecodeHandle(h).slot));
        return kInvalidHandle;
    }

    Handle ReleaseAndRetain(Handle previous, Handle next)
    {
        Release(previous);
        return Retain(next);
    }

    // --- Map ---

    std::int64_t MapGetInt(Handle h, const std::string& key, std::int64_t def)
    {
        std::lock_guard lock(g_mutex);
        auto* n = Resolve(h);
        if (!n || n->isArray || n->isFormMap) return def;
        std::string k = key; ToLowerAscii(k);
        for (auto& kv : n->map) if (kv.first == k) return kv.second.type == ValueType::kInt ? kv.second.i : def;
        return def;
    }

    double MapGetFlt(Handle h, const std::string& key, double def)
    {
        std::lock_guard lock(g_mutex);
        auto* n = Resolve(h);
        if (!n || n->isArray || n->isFormMap) return def;
        std::string k = key; ToLowerAscii(k);
        for (auto& kv : n->map) if (kv.first == k) return kv.second.type == ValueType::kFloat ? kv.second.f : def;
        return def;
    }

    std::string MapGetStr(Handle h, const std::string& key, const std::string& def)
    {
        std::lock_guard lock(g_mutex);
        auto* n = Resolve(h);
        if (!n || n->isArray || n->isFormMap) return def;
        std::string k = key; ToLowerAscii(k);
        for (auto& kv : n->map) if (kv.first == k) return kv.second.type == ValueType::kString ? kv.second.s : def;
        return def;
    }

    Handle MapGetObj(Handle h, const std::string& key, Handle def)
    {
        std::lock_guard lock(g_mutex);
        auto* n = Resolve(h);
        if (!n || n->isArray || n->isFormMap) return def;
        std::string k = key; ToLowerAscii(k);
        for (auto& kv : n->map) if (kv.first == k) return kv.second.type == ValueType::kObject ? kv.second.obj : def;
        return def;
    }

    RE::TESForm* MapGetForm(Handle h, const std::string& key, RE::TESForm* def)
    {
        std::lock_guard lock(g_mutex);
        auto* n = Resolve(h);
        if (!n || n->isArray || n->isFormMap) return def;
        std::string k = key; ToLowerAscii(k);
        for (auto& kv : n->map) if (kv.first == k) return kv.second.type == ValueType::kForm ? ResolveFormRef(kv.second.form) : def;
        return def;
    }

    namespace
    {
        template <typename UpdateFn>
        void MapUpsert(Handle h, const std::string& key, UpdateFn&& update)
        {
            std::lock_guard lock(g_mutex);
            auto* n = Resolve(h);
            if (!n || n->isArray || n->isFormMap) return;
            std::string k = key; ToLowerAscii(k);
            for (auto& kv : n->map) {
                if (kv.first == k) {
                    FreeValueChild(kv.second);
                    kv.second = Value{};
                    update(kv.second);
                    return;
                }
            }
            Value v{};
            update(v);
            n->map.emplace_back(std::move(k), std::move(v));
        }
    }

    void MapSetInt(Handle h, const std::string& key, std::int64_t v) { MapUpsert(h, key, [&](Value& out) { out.type = ValueType::kInt; out.i = v; }); }
    void MapSetFlt(Handle h, const std::string& key, double v) { MapUpsert(h, key, [&](Value& out) { out.type = ValueType::kFloat; out.f = v; }); }
    void MapSetStr(Handle h, const std::string& key, const std::string& v) { MapUpsert(h, key, [&](Value& out) { out.type = ValueType::kString; out.s = v; }); }
    void MapSetForm(Handle h, const std::string& key, RE::TESForm* v) { MapUpsert(h, key, [&](Value& out) { out.type = ValueType::kForm; out.form = MakeFormRef(v); }); }

    void MapSetObj(Handle h, const std::string& key, Handle child)
    {
        std::lock_guard lock(g_mutex);
        auto* n = Resolve(h);
        if (!n || n->isArray || n->isFormMap) return;
        const std::int32_t parentSlot = static_cast<std::int32_t>(DecodeHandle(h).slot);
        const Handle attached = AttachChild(parentSlot, child, "MapSetObj");
        n = Resolve(h);  // AttachChild may have reallocated g_slots via DeepCopy
        if (!n) return;
        std::string k = key; ToLowerAscii(k);
        for (auto& kv : n->map) {
            if (kv.first == k) {
                if (kv.second.type != ValueType::kObject || kv.second.obj != attached) FreeValueChild(kv.second);
                kv.second = Value{ ValueType::kObject };
                kv.second.obj = attached;
                return;
            }
        }
        Value v{ ValueType::kObject };
        v.obj = attached;
        n->map.emplace_back(std::move(k), std::move(v));
    }

    std::int32_t MapValueType(Handle h, const std::string& key)
    {
        std::lock_guard lock(g_mutex);
        auto* n = Resolve(h);
        if (!n || n->isArray || n->isFormMap) return 0;
        std::string k = key; ToLowerAscii(k);
        for (auto& kv : n->map) if (kv.first == k) return static_cast<std::int32_t>(kv.second.type);
        return 0;
    }

    std::string MapNextKey(Handle h, const std::string& previousKey, const std::string& endKey)
    {
        std::lock_guard lock(g_mutex);
        auto* n = Resolve(h);
        if (!n || n->isArray || n->isFormMap || n->map.empty()) return endKey;
        if (previousKey == endKey) {
            return n->map.front().first;
        }
        std::string prev = previousKey; ToLowerAscii(prev);
        for (std::size_t i = 0; i < n->map.size(); ++i) {
            if (n->map[i].first == prev) {
                return (i + 1 < n->map.size()) ? n->map[i + 1].first : endKey;
            }
        }
        return endKey;  // previousKey no longer present (e.g. removed mid-iteration)
    }

    std::vector<std::string> MapAllKeysPArray(Handle h)
    {
        std::lock_guard lock(g_mutex);
        std::vector<std::string> out;
        auto* n = Resolve(h);
        if (!n || n->isArray || n->isFormMap) return out;
        out.reserve(n->map.size());
        for (auto& kv : n->map) out.push_back(kv.first);
        return out;
    }

    Handle MapAllKeys(Handle h)
    {
        const auto keys = MapAllKeysPArray(h);
        const Handle arr = NewArray();
        for (auto& k : keys) ArrayAddStr(arr, k, -1);
        return arr;
    }

    bool MapHasKey(Handle h, const std::string& key)
    {
        std::lock_guard lock(g_mutex);
        auto* n = Resolve(h);
        if (!n || n->isArray || n->isFormMap) return false;
        std::string k = key; ToLowerAscii(k);
        for (auto& kv : n->map) if (kv.first == k) return true;
        return false;
    }

    void MapRemoveKey(Handle h, const std::string& key)
    {
        std::lock_guard lock(g_mutex);
        auto* n = Resolve(h);
        if (!n || n->isArray || n->isFormMap) return;
        std::string k = key; ToLowerAscii(k);
        for (auto it = n->map.begin(); it != n->map.end(); ++it) {
            if (it->first == k) {
                FreeValueChild(it->second);
                n->map.erase(it);
                return;
            }
        }
    }

    void MapClear(Handle h)
    {
        std::lock_guard lock(g_mutex);
        auto* n = Resolve(h);
        if (!n || n->isArray || n->isFormMap) return;
        for (auto& kv : n->map) FreeValueChild(kv.second);
        n->map.clear();
    }

    // --- Array ---

    namespace
    {
        std::int32_t NormalizeIndex(std::int32_t index, std::size_t size)
        {
            if (index < 0) index += static_cast<std::int32_t>(size);
            return index;
        }
    }

    std::int64_t ArrayGetInt(Handle h, std::int32_t index, std::int64_t def)
    {
        std::lock_guard lock(g_mutex);
        auto* n = Resolve(h);
        if (!n || !n->isArray) return def;
        index = NormalizeIndex(index, n->arr.size());
        if (index < 0 || static_cast<std::size_t>(index) >= n->arr.size()) return def;
        return n->arr[index].type == ValueType::kInt ? n->arr[index].i : def;
    }

    double ArrayGetFlt(Handle h, std::int32_t index, double def)
    {
        std::lock_guard lock(g_mutex);
        auto* n = Resolve(h);
        if (!n || !n->isArray) return def;
        index = NormalizeIndex(index, n->arr.size());
        if (index < 0 || static_cast<std::size_t>(index) >= n->arr.size()) return def;
        return n->arr[index].type == ValueType::kFloat ? n->arr[index].f : def;
    }

    std::string ArrayGetStr(Handle h, std::int32_t index, const std::string& def)
    {
        std::lock_guard lock(g_mutex);
        auto* n = Resolve(h);
        if (!n || !n->isArray) return def;
        index = NormalizeIndex(index, n->arr.size());
        if (index < 0 || static_cast<std::size_t>(index) >= n->arr.size()) return def;
        return n->arr[index].type == ValueType::kString ? n->arr[index].s : def;
    }

    Handle ArrayGetObj(Handle h, std::int32_t index, Handle def)
    {
        std::lock_guard lock(g_mutex);
        auto* n = Resolve(h);
        if (!n || !n->isArray) return def;
        index = NormalizeIndex(index, n->arr.size());
        if (index < 0 || static_cast<std::size_t>(index) >= n->arr.size()) return def;
        return n->arr[index].type == ValueType::kObject ? n->arr[index].obj : def;
    }

    RE::TESForm* ArrayGetForm(Handle h, std::int32_t index, RE::TESForm* def)
    {
        std::lock_guard lock(g_mutex);
        auto* n = Resolve(h);
        if (!n || !n->isArray) return def;
        index = NormalizeIndex(index, n->arr.size());
        if (index < 0 || static_cast<std::size_t>(index) >= n->arr.size()) return def;
        return n->arr[index].type == ValueType::kForm ? ResolveFormRef(n->arr[index].form) : def;
    }

    namespace
    {
        template <typename UpdateFn>
        void ArraySetAt(Handle h, std::int32_t index, UpdateFn&& update)
        {
            std::lock_guard lock(g_mutex);
            auto* n = Resolve(h);
            if (!n || !n->isArray) return;
            index = NormalizeIndex(index, n->arr.size());
            if (index < 0 || static_cast<std::size_t>(index) >= n->arr.size()) return;
            FreeValueChild(n->arr[index]);
            n->arr[index] = Value{};
            update(n->arr[index]);
        }
    }

    void ArraySetInt(Handle h, std::int32_t index, std::int64_t v) { ArraySetAt(h, index, [&](Value& out) { out.type = ValueType::kInt; out.i = v; }); }
    void ArraySetFlt(Handle h, std::int32_t index, double v) { ArraySetAt(h, index, [&](Value& out) { out.type = ValueType::kFloat; out.f = v; }); }
    void ArraySetStr(Handle h, std::int32_t index, const std::string& v) { ArraySetAt(h, index, [&](Value& out) { out.type = ValueType::kString; out.s = v; }); }
    void ArraySetForm(Handle h, std::int32_t index, RE::TESForm* v) { ArraySetAt(h, index, [&](Value& out) { out.type = ValueType::kForm; out.form = MakeFormRef(v); }); }

    void ArraySetObj(Handle h, std::int32_t index, Handle child)
    {
        std::lock_guard lock(g_mutex);
        auto* n = Resolve(h);
        if (!n || !n->isArray) return;
        index = NormalizeIndex(index, n->arr.size());
        if (index < 0 || static_cast<std::size_t>(index) >= n->arr.size()) return;
        const std::int32_t parentSlot = static_cast<std::int32_t>(DecodeHandle(h).slot);
        const Handle attached = AttachChild(parentSlot, child, "ArraySetObj");
        n = Resolve(h);
        if (!n || static_cast<std::size_t>(index) >= n->arr.size()) return;
        FreeValueChild(n->arr[index]);
        n->arr[index] = Value{ ValueType::kObject };
        n->arr[index].obj = attached;
    }

    namespace
    {
        template <typename UpdateFn>
        void ArrayInsert(Handle h, std::int32_t addToIndex, UpdateFn&& update)
        {
            std::lock_guard lock(g_mutex);
            auto* n = Resolve(h);
            if (!n || !n->isArray) return;
            Value v{};
            update(v);
            if (addToIndex < 0) {
                n->arr.push_back(std::move(v));
                return;
            }
            const auto idx = std::min<std::size_t>(static_cast<std::size_t>(addToIndex), n->arr.size());
            n->arr.insert(n->arr.begin() + static_cast<std::ptrdiff_t>(idx), std::move(v));
        }
    }

    void ArrayAddInt(Handle h, std::int64_t v, std::int32_t addToIndex) { ArrayInsert(h, addToIndex, [&](Value& out) { out.type = ValueType::kInt; out.i = v; }); }
    void ArrayAddFlt(Handle h, double v, std::int32_t addToIndex) { ArrayInsert(h, addToIndex, [&](Value& out) { out.type = ValueType::kFloat; out.f = v; }); }
    void ArrayAddStr(Handle h, const std::string& v, std::int32_t addToIndex) { ArrayInsert(h, addToIndex, [&](Value& out) { out.type = ValueType::kString; out.s = v; }); }
    void ArrayAddForm(Handle h, RE::TESForm* v, std::int32_t addToIndex) { ArrayInsert(h, addToIndex, [&](Value& out) { out.type = ValueType::kForm; out.form = MakeFormRef(v); }); }

    void ArrayAddObj(Handle h, Handle child, std::int32_t addToIndex)
    {
        std::lock_guard lock(g_mutex);
        auto* n = Resolve(h);
        if (!n || !n->isArray) return;
        const std::int32_t parentSlot = static_cast<std::int32_t>(DecodeHandle(h).slot);
        const Handle attached = AttachChild(parentSlot, child, "ArrayAddObj");
        n = Resolve(h);
        if (!n) return;
        Value v{ ValueType::kObject };
        v.obj = attached;
        if (addToIndex < 0) {
            n->arr.push_back(std::move(v));
        } else {
            const auto idx = std::min<std::size_t>(static_cast<std::size_t>(addToIndex), n->arr.size());
            n->arr.insert(n->arr.begin() + static_cast<std::ptrdiff_t>(idx), std::move(v));
        }
    }

    std::int32_t ArrayValueType(Handle h, std::int32_t index)
    {
        std::lock_guard lock(g_mutex);
        auto* n = Resolve(h);
        if (!n || !n->isArray) return 0;
        index = NormalizeIndex(index, n->arr.size());
        if (index < 0 || static_cast<std::size_t>(index) >= n->arr.size()) return 0;
        return static_cast<std::int32_t>(n->arr[index].type);
    }

    void ArrayEraseIndex(Handle h, std::int32_t index)
    {
        std::lock_guard lock(g_mutex);
        auto* n = Resolve(h);
        if (!n || !n->isArray) return;
        index = NormalizeIndex(index, n->arr.size());
        if (index < 0 || static_cast<std::size_t>(index) >= n->arr.size()) return;
        FreeValueChild(n->arr[static_cast<std::size_t>(index)]);
        n->arr.erase(n->arr.begin() + index);
    }

    std::int32_t ArrayFindForm(Handle h, RE::TESForm* form)
    {
        std::lock_guard lock(g_mutex);
        auto* n = Resolve(h);
        if (!n || !n->isArray) return -1;
        const auto k = MakeFormRef(form);
        for (std::size_t i = 0; i < n->arr.size(); ++i) {
            if (n->arr[i].type == ValueType::kForm && n->arr[i].form == k) return static_cast<std::int32_t>(i);
        }
        return -1;
    }

    void ArrayClear(Handle h)
    {
        std::lock_guard lock(g_mutex);
        auto* n = Resolve(h);
        if (!n || !n->isArray) return;
        for (auto& v : n->arr) FreeValueChild(v);
        n->arr.clear();
    }

    // --- FormMap ---

    Handle FormMapGetObj(Handle h, RE::TESForm* key, Handle def)
    {
        std::lock_guard lock(g_mutex);
        auto* n = Resolve(h);
        if (!n || !n->isFormMap) return def;
        const auto k = MakeFormRef(key);
        for (auto& kv : n->formMap) if (kv.first == k) return kv.second.type == ValueType::kObject ? kv.second.obj : def;
        return def;
    }

    void FormMapSetObj(Handle h, RE::TESForm* key, Handle child)
    {
        std::lock_guard lock(g_mutex);
        auto* n = Resolve(h);
        if (!n || !n->isFormMap) return;
        const std::int32_t parentSlot = static_cast<std::int32_t>(DecodeHandle(h).slot);
        const Handle attached = AttachChild(parentSlot, child, "FormMapSetObj");
        n = Resolve(h);
        if (!n) return;
        const auto k = MakeFormRef(key);
        for (auto& kv : n->formMap) {
            if (kv.first == k) {
                if (kv.second.type != ValueType::kObject || kv.second.obj != attached) FreeValueChild(kv.second);
                kv.second = Value{ ValueType::kObject };
                kv.second.obj = attached;
                return;
            }
        }
        Value v{ ValueType::kObject };
        v.obj = attached;
        n->formMap.emplace_back(k, std::move(v));
    }

    std::int32_t FormMapValueType(Handle h, RE::TESForm* key)
    {
        std::lock_guard lock(g_mutex);
        auto* n = Resolve(h);
        if (!n || !n->isFormMap) return 0;
        const auto k = MakeFormRef(key);
        for (auto& kv : n->formMap) if (kv.first == k) return static_cast<std::int32_t>(kv.second.type);
        return 0;
    }

    RE::TESForm* FormMapNextKey(Handle h, RE::TESForm* previousKey, RE::TESForm* endKey)
    {
        std::lock_guard lock(g_mutex);
        auto* n = Resolve(h);
        if (!n || !n->isFormMap || n->formMap.empty()) return endKey;
        const auto prev = MakeFormRef(previousKey);
        const auto end = MakeFormRef(endKey);
        if (prev == end) {
            return ResolveFormRef(n->formMap.front().first);
        }
        for (std::size_t i = 0; i < n->formMap.size(); ++i) {
            if (n->formMap[i].first == prev) {
                return (i + 1 < n->formMap.size()) ? ResolveFormRef(n->formMap[i + 1].first) : endKey;
            }
        }
        return endKey;
    }

    // --- Parse / serialize / IO ---

    namespace
    {
        void SetMapValueFromJson(Handle mapHandle, std::string key, const nlohmann::json& v)
        {
            if (v.is_object() || v.is_array()) {
                MapSetObj(mapHandle, key, BuildFromJson(v));
            } else if (v.is_boolean()) {
                MapSetInt(mapHandle, key, v.get<bool>() ? 1 : 0);
            } else if (v.is_number_float()) {
                MapSetFlt(mapHandle, key, v.get<double>());
            } else if (v.is_number()) {
                MapSetInt(mapHandle, key, v.get<std::int64_t>());
            } else if (v.is_string()) {
                MapSetStr(mapHandle, key, v.get<std::string>());
            } else {
                // null: leave as an explicit None entry (matches valueType()==1 on a present-but-null key).
                MapUpsert(mapHandle, key, [](Value& out) { out.type = ValueType::kNone; });
            }
        }

        void AddArrayValueFromJson(Handle arrHandle, const nlohmann::json& v)
        {
            if (v.is_object() || v.is_array()) {
                ArrayAddObj(arrHandle, BuildFromJson(v), -1);
            } else if (v.is_boolean()) {
                ArrayAddInt(arrHandle, v.get<bool>() ? 1 : 0, -1);
            } else if (v.is_number_float()) {
                ArrayAddFlt(arrHandle, v.get<double>(), -1);
            } else if (v.is_number()) {
                ArrayAddInt(arrHandle, v.get<std::int64_t>(), -1);
            } else if (v.is_string()) {
                ArrayAddStr(arrHandle, v.get<std::string>(), -1);
            } else {
                ArrayInsert(arrHandle, -1, [](Value& out) { out.type = ValueType::kNone; });
            }
        }
    }

    Handle FromJsonPrototype(const std::string& json)
    {
        if (json.empty()) {
            return kInvalidHandle;
        }
        try {
            const auto parsed = nlohmann::json::parse(json);
            std::lock_guard lock(g_mutex);
            return BuildFromJson(parsed);
        } catch (const nlohmann::json::exception& e) {
            webui_log::warn("FromJsonPrototype: parse failed: {}", e.what());
            return kInvalidHandle;
        }
    }

    std::string Dump(Handle h)
    {
        std::lock_guard lock(g_mutex);
        auto* n = Resolve(h);
        if (!n) {
            return "";
        }
        try {
            return NodeToJson(*n).dump();
        } catch (const std::exception& e) {
            webui_log::error("Dump failed for handle 0x{:X}: {}", static_cast<std::uint32_t>(h), e.what());
            return "";
        }
    }

    Handle ReadFromFile(const std::string& path)
    {
        std::ifstream f(path, std::ios::binary);
        if (!f) {
            webui_log::warn("ReadFromFile: could not open {}", path);
            return kInvalidHandle;
        }
        std::ostringstream buf;
        buf << f.rdbuf();
        return FromJsonPrototype(buf.str());
    }

    void WriteToFile(Handle h, const std::string& path)
    {
        const std::string json = Dump(h);
        std::ofstream f(path, std::ios::binary | std::ios::trunc);
        if (!f) {
            webui_log::error("WriteToFile: could not open {} for writing", path);
            return;
        }
        f << json;
    }

    // --- Lifecycle ---

    void OnNewSession()
    {
        std::lock_guard lock(g_mutex);
        g_session = (g_session + 1) & kSessionMask;
        if (g_session == 0) g_session = 1;  // keep 0 reserved / avoid an all-zero handle
    }

    std::string Stats()
    {
        std::lock_guard lock(g_mutex);
        std::size_t live = 0, roots = 0;
        for (std::size_t i = 1; i < g_slots.size(); ++i) {
            if (g_slots[i].alive) {
                ++live;
                if (g_slots[i].parentSlot == -1) ++roots;
            }
        }
        std::ostringstream oss;
        oss << "slots=" << g_slots.size() << " live=" << live << " roots=" << roots
            << " free=" << g_freeSlots.size() << " session=" << g_session << " reparentCopies=" << g_reparentCopies;
        if (roots > 4096) {
            webui_log::warn("JSON store has {} live roots -- likely a missing Release() somewhere", roots);
        }
        return oss.str();
    }
}
