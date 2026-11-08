#pragma once

#include <algorithm>
#include <cctype>
#include <nlohmann/json.hpp>
#include <string>

/// json::dump that never throws on invalid UTF-8. Game strings (translated names, DD device names)
/// can be cp1251/cp1252 bytes; a plain dump() throws type_error.316 out of a PrismaUI listener or a
/// Papyrus native, which ends the game. Bad bytes become U+FFFD instead.
inline std::string SafeDump(const nlohmann::json& j, int indent = -1)
{
    return j.dump(indent, ' ', false, nlohmann::json::error_handler_t::replace);
}

/// Recursively rebuilds JSON with all object keys converted to lowercase (ASCII).
/// Case-only key collisions use last-wins. Arrays and scalars are left structurally intact.
inline nlohmann::json LowerCaseKeys(const nlohmann::json& in)
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
