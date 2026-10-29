#pragma once

#include "PCH.h"

#include <nlohmann/json.hpp>
#include <string>
#include <string_view>

/// SexGraph: the developer-only AnimEngine settings in SKSE/Plugins/SkyrimNet_SexLab/sex-graph.json, edited from the
/// WebUI "Sex Graph" main panel (listed only while the file exists, MainPanels/1050_sex_graph.json requiresFile).
/// The file never ships (make release removes it from core). No file, or one that does not parse: every key reads
/// false, so AnimEngine is off and SexLab runs every scene. See docs/developers/anim-engine.md.
namespace SexGraph
{
    /// File name under AnimationDB::PluginDataDir().
    inline constexpr const char* kFileName = "sex-graph.json";

    /// The file exists (checked on every call).
    bool Present();
    /// anim_engine.<key>: enabled, orgasm_engine, approach, slsb_registry. def applies only to a key missing from a
    /// readable file.
    bool GetBool(std::string_view key, bool def);
    /// Writes anim_engine.<key> (creates the file when missing). False when the write failed.
    bool SetBool(std::string_view key, bool value);
    /// {present, anim_engine:{...}, animEngineScene} for JS configureSexGraphPanel.
    nlohmann::json PanelJson();
    /// Drops the cached parse (game load / new game), so a hand edit applies.
    void Reload();
}
