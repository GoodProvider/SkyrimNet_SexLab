#pragma once

#include "PCH.h"

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
}
