#pragma once

#include "PCH.h"

#include <cstdint>
#include <string>
#include <nlohmann/json.hpp>

/// Scene HUD: a second PrismaUI view (PrismaUI/views/SkyrimNet_SexLab/hud.html) shown without Focus
/// (no pause, no input capture) while the player is in a scene the OrgasmEngine manages, or drives an NPC of one
/// (take-control key on a crosshair NPC).
/// Groups (sexlab.hud.enjoyment / sexlab.hud.controls / sexlab.enjoyment.mode) toggle rows and keys.
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

    /// The actor HUD keys act as: the NPC the player took control of (take-control key), else the player.
    RE::Actor* ActingActor();

    /// Game thread. Presses a HUD key as the acting actor (auto play): slower / faster, or a Papyrus
    /// Menu.Hud_OnKey control (previous, next, pause, end, pos_up, pos_down, deny with focus, speak).
    void PressKey(const std::string& control, RE::FormID focus = 0);
}
