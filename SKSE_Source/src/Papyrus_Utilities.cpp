#include "Papyrus_Utilities.h"
#include "JsonUtil.h"
#include "AnimSpeed.h"
#include "NarrationQueue.h"
#include "NarrationTiming.h"
#include "WebUI_Log.h"

#include <Windows.h>
#include <algorithm>
#include <chrono>
#include <cctype>
#include <cstring>
#include <mutex>
#include <string>
#include <string_view>
#include <unordered_map>
#include <vector>
#include <nlohmann/json.hpp>

namespace PapyrusBindings_Utilities
{
    /// Recursively rebuilds JSON with all object keys converted to lowercase (ASCII).
    /// Case-only key collisions use last-wins. Arrays and scalars are left structurally intact.
    static nlohmann::json LowerCaseKeys(const nlohmann::json& in)
    {
        if (in.is_object()) {
            nlohmann::json out = nlohmann::json::object();
            for (auto it = in.begin(); it != in.end(); ++it) {
                std::string key = it.key();
                std::transform(key.begin(), key.end(), key.begin(),
                    [](unsigned char c) { return static_cast<char>(std::tolower(c)); });
                out[key] = LowerCaseKeys(it.value());
            }
            return out;
        }
        if (in.is_array()) {
            nlohmann::json out = nlohmann::json::array();
            for (const auto& el : in) {
                out.push_back(LowerCaseKeys(el));
            }
            return out;
        }
        return in;
    }

    /// Parses json, lowercases all object keys recursively, returns compact dump.
    /// Invalid or empty input returns "" and logs a warning.
    RE::BSFixedString JsonLowerCaseKeys(RE::StaticFunctionTag*, RE::BSFixedString json)
    {
        const char* raw = json.c_str() ? json.c_str() : "";
        if (!raw[0]) {
            webui_log::warn("JsonLowerCaseKeys: empty input");
            return RE::BSFixedString("");
        }

        try {
            auto parsed = nlohmann::json::parse(raw);
            auto lowered = LowerCaseKeys(parsed);
            return RE::BSFixedString(SafeDump(lowered));
        } catch (const nlohmann::json::exception& e) {
            webui_log::warn("JsonLowerCaseKeys: parse failed: {}", e.what());
            return RE::BSFixedString("");
        } catch (...) {
            webui_log::warn("JsonLowerCaseKeys: unexpected failure");
            return RE::BSFixedString("");
        }
    }

    /// JSON string literal: wraps in quotes, escapes " \ \n \r \t, other bytes < 0x20 as \u00XX.
    /// Bytes >= 0x80 pass through verbatim (payload is already UTF-8).
    static void AppendQuoted(std::string& out, const char* raw, std::size_t len)
    {
        static constexpr char kHex[] = "0123456789abcdef";
        out.push_back('"');
        for (std::size_t i = 0; i < len; ++i) {
            const auto c = static_cast<unsigned char>(raw[i]);
            switch (c) {
            case '"':  out += "\\\""; break;
            case '\\': out += "\\\\"; break;
            case '\n': out += "\\n";  break;
            case '\r': out += "\\r";  break;
            case '\t': out += "\\t";  break;
            default:
                if (c < 0x20) {
                    out += "\\u00";
                    out.push_back(kHex[c >> 4]);
                    out.push_back(kHex[c & 0xF]);
                } else {
                    out.push_back(static_cast<char>(c));
                }
            }
        }
        out.push_back('"');
    }

    RE::BSFixedString JsonQuote(RE::StaticFunctionTag*, RE::BSFixedString s)
    {
        const char* raw = s.c_str() ? s.c_str() : "";
        std::string out;
        const std::size_t len = std::strlen(raw);
        out.reserve(len + 2);
        AppendQuoted(out, raw, len);
        return RE::BSFixedString(out);
    }

    /// Literal backslash+n -> LF. compile: papyrus stores "\n" as two characters, so text bound
    /// for SkyrimNet's Inja parse is fixed here first. Input without the pair is returned as-is.
    RE::BSFixedString InjaPrepare(RE::StaticFunctionTag*, RE::BSFixedString s)
    {
        const char* raw = s.c_str() ? s.c_str() : "";
        if (!std::strstr(raw, "\\n")) {
            return s;
        }
        const std::size_t len = std::strlen(raw);
        std::string out;
        out.reserve(len);
        for (std::size_t i = 0; i < len; ++i) {
            if (raw[i] == '\\' && i + 1 < len && raw[i + 1] == 'n') {
                out.push_back('\n');
                ++i;
            } else {
                out.push_back(raw[i]);
            }
        }
        return RE::BSFixedString(out);
    }

    /// Hex entity UUID -> arbitrary-precision decimal string. Strings with no a-f/A-F letter are
    /// already decimal and returned unchanged. A leading 0x/0X is stripped and non-hex characters
    /// are skipped, matching the former Papyrus implementation.
    RE::BSFixedString UuidToDecimalString(RE::StaticFunctionTag*, RE::BSFixedString entityUuid)
    {
        const char* raw = entityUuid.c_str() ? entityUuid.c_str() : "";
        std::string_view in(raw);
        if (in.empty()) {
            return RE::BSFixedString("");
        }
        const bool isHex = std::any_of(in.begin(), in.end(), [](char c) {
            return (c >= 'a' && c <= 'f') || (c >= 'A' && c <= 'F');
        });
        if (!isHex) {
            return entityUuid;
        }
        if (in.size() >= 2 && in[0] == '0' && (in[1] == 'x' || in[1] == 'X')) {
            in.remove_prefix(2);
        }
        std::vector<std::uint8_t> dec{ 0 };  // little-endian decimal digits
        for (const char c : in) {
            int digit;
            if (c >= '0' && c <= '9') digit = c - '0';
            else if (c >= 'a' && c <= 'f') digit = c - 'a' + 10;
            else if (c >= 'A' && c <= 'F') digit = c - 'A' + 10;
            else continue;
            int carry = digit;
            for (auto& d : dec) {
                const int v = d * 16 + carry;
                d = static_cast<std::uint8_t>(v % 10);
                carry = v / 10;
            }
            while (carry > 0) {
                dec.push_back(static_cast<std::uint8_t>(carry % 10));
                carry /= 10;
            }
        }
        std::string out;
        out.reserve(dec.size());
        for (auto it = dec.rbegin(); it != dec.rend(); ++it) {
            out.push_back(static_cast<char>('0' + *it));
        }
        return RE::BSFixedString(out);
    }

    std::int32_t VkToDxScanCode(RE::StaticFunctionTag*, std::int32_t vk)
    {
        if (vk < 1 || vk > 255) {
            return 0x2B;
        }
        const UINT dx = MapVirtualKeyA(static_cast<UINT>(vk), MAPVK_VK_TO_VSC);
        return dx != 0 ? static_cast<std::int32_t>(dx) : 0x2B;
    }

    void SetAnimSpeed(RE::StaticFunctionTag*, RE::Actor* akActor, float speed)
    {
        AnimSpeed::Set(akActor, speed);
    }

    void ClearAnimSpeed(RE::StaticFunctionTag*, RE::Actor* akActor)
    {
        AnimSpeed::Clear(akActor);
    }

    float GetAnimSpeed(RE::StaticFunctionTag*, RE::Actor* akActor)
    {
        return AnimSpeed::Get(akActor);
    }

    bool QueueDirectNarration(RE::StaticFunctionTag*, RE::BSFixedString msg, RE::Actor* source,
        RE::Actor* target, bool purgeDialogue)
    {
        const char* raw = msg.c_str() ? msg.c_str() : "";
        if (NarrationQueue::Enqueue(raw, source, target, purgeDialogue))
            return true;
        // Not paused: Papyrus sends it to SkyrimNet right after this returns.
        NarrationTiming::MarkSent(raw);
        return false;
    }

    namespace
    {
        // NPC base FormID -> reference FormID. Built from one walk over all forms; rebuilt on a miss.
        std::mutex g_baseRefLock;
        std::unordered_map<RE::FormID, RE::FormID> g_baseToRef;
        std::chrono::steady_clock::time_point g_baseToRefBuilt{};

        void RebuildBaseToRef()
        {
            g_baseToRef.clear();
            const auto [forms, lock] = RE::TESForm::GetAllForms();
            if (!forms)
                return;
            RE::BSReadLockGuard guard{ lock.get() };
            for (const auto& [id, form] : *forms) {
                auto* actor = form ? form->As<RE::Actor>() : nullptr;
                if (!actor)
                    continue;
                if (auto* raw = actor->data.objectReference)
                    g_baseToRef.emplace(raw->GetFormID(), actor->GetFormID());
                if (auto* npc = actor->GetActorBase())
                    g_baseToRef.emplace(npc->GetFormID(), actor->GetFormID());
            }
            webui_log::info("ActorFromBase: indexed {} NPC bases", g_baseToRef.size());
        }

        RE::Actor* LookupRef(RE::FormID baseId)
        {
            auto it = g_baseToRef.find(baseId);
            if (it == g_baseToRef.end())
                return nullptr;
            auto* actor = RE::TESForm::LookupByID<RE::Actor>(it->second);
            if (!actor)
                return nullptr;
            auto* npc = actor->GetActorBase();
            auto* raw = actor->data.objectReference;
            if ((npc && npc->GetFormID() == baseId) || (raw && raw->GetFormID() == baseId))
                return actor;
            return nullptr;
        }
    }

    RE::Actor* ActorFromBase(RE::StaticFunctionTag*, RE::TESNPC* base)
    {
        if (!base)
            return nullptr;
        auto* player = RE::PlayerCharacter::GetSingleton();
        if (player && player->GetActorBase() == base)
            return player;
        std::scoped_lock guard{ g_baseRefLock };
        if (auto* actor = LookupRef(base->GetFormID()))
            return actor;
        // A miss rebuilds the index, at most every 5 s (a panel asks for up to 25 lovers in a row).
        const auto now = std::chrono::steady_clock::now();
        if (!g_baseToRef.empty() && now - g_baseToRefBuilt < std::chrono::seconds(5))
            return nullptr;
        g_baseToRefBuilt = now;
        RebuildBaseToRef();
        return LookupRef(base->GetFormID());
    }

    /// Binds JsonLowerCaseKeys on SkyrimNet_SexLab_Utilities.
    bool Register_Utilities_Functions(RE::BSScript::IVirtualMachine* a_vm)
    {
        if (!a_vm) {
            webui_log::error("Couldn't get Papyrus Virtual Machine.");
            return false;
        }

        constexpr std::string_view scriptName = "SkyrimNet_SexLab_Utilities";

        a_vm->RegisterFunction("JsonLowerCaseKeys", scriptName, JsonLowerCaseKeys, true);
        a_vm->RegisterFunction("VkToDxScanCode", scriptName, VkToDxScanCode, true);
        a_vm->RegisterFunction("JsonQuote", scriptName, JsonQuote, true);
        a_vm->RegisterFunction("UuidToDecimalString", scriptName, UuidToDecimalString, true);
        a_vm->RegisterFunction("InjaPrepare", scriptName, InjaPrepare, true);
        a_vm->RegisterFunction("SetAnimSpeed", scriptName, SetAnimSpeed);
        a_vm->RegisterFunction("ClearAnimSpeed", scriptName, ClearAnimSpeed);
        a_vm->RegisterFunction("GetAnimSpeed", scriptName, GetAnimSpeed);
        a_vm->RegisterFunction("QueueDirectNarration", scriptName, QueueDirectNarration);
        a_vm->RegisterFunction("ActorFromBase", scriptName, ActorFromBase);
        webui_log::info("Successfully registered Papyrus functions for {}", scriptName);
        return true;
    }
}
