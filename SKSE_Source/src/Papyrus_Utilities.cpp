#include "Papyrus_Utilities.h"
#include "JsonUtil.h"
#include "AnimSpeed.h"
#include "NarrationQueue.h"
#include "NarrationTiming.h"
#include "WebUI_Log.h"

#include <Windows.h>
#include <algorithm>
#include <cctype>
#include <cstring>
#include <string>
#include <string_view>
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
        a_vm->RegisterFunction("SetAnimSpeed", scriptName, SetAnimSpeed);
        a_vm->RegisterFunction("ClearAnimSpeed", scriptName, ClearAnimSpeed);
        a_vm->RegisterFunction("GetAnimSpeed", scriptName, GetAnimSpeed);
        a_vm->RegisterFunction("QueueDirectNarration", scriptName, QueueDirectNarration);
        webui_log::info("Successfully registered Papyrus functions for {}", scriptName);
        return true;
    }
}
