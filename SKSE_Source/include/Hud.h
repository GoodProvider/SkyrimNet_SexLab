#pragma once

#include "PCH.h"

#include <cstdint>
#include <string>
#include <nlohmann/json.hpp>

/// Scene HUD: a second PrismaUI view (PrismaUI/views/SkyrimNet_SexLab/hud.html) shown without Focus
/// (no pause, no input capture) while the player is in a scene the OrgasmEngine manages.
/// Groups (sexlab.hud.enjoyment / sexlab.hud.controls / sexlab.minigame.enabled) toggle rows and keys.
namespace Hud
{
    /// Creates the view. Call once at kDataLoaded, after InitWebUI.
    void Init();

    /// Re-reads groups and hotkeys from the dashboard and rebinds the HUD keys.
    void ApplyConfig();

    /// Game thread, every OrgasmEngine tick: visibility, focus, push, speed narration debounce.
    void Tick();

    /// Load / new game: focus and pending narration belong to the previous session.
    void Reset();

    /// Short key name for a DX scancode (SKSE mouse codes 256+ -> LMB / RMB / MMB).
    std::string DxLabel(std::uint32_t dx);

    /// hotkey-map.json entries for the HUD keys (dashboard bindings + fixed focus 1-4), as last applied.
    nlohmann::json HotkeyMapJson();
}
