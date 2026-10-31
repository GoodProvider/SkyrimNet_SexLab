#pragma once

#include <nlohmann/json.hpp>
#include <string>

/// json::dump that never throws on invalid UTF-8. Game strings (translated names, DD device names)
/// can be cp1251/cp1252 bytes; a plain dump() throws type_error.316 out of a PrismaUI listener or a
/// Papyrus native, which ends the game. Bad bytes become U+FFFD instead.
inline std::string SafeDump(const nlohmann::json& j, int indent = -1)
{
    return j.dump(indent, ' ', false, nlohmann::json::error_handler_t::replace);
}
