#pragma once

#include "PCH.h"

/// Per-actor animation playback rate. Hooks Character/PlayerCharacter UpdateAnimation (vfunc 0x7D)
/// and scales a_delta for actors with an entry. Only the Havok graph is affected: Papyrus timers
/// (SexLab stage timers, orgasm window, voices) run on real time and keep their timing.
namespace AnimSpeed
{
    constexpr float kMin = 0.1f;
    constexpr float kMax = 3.0f;

    /// Installs the vtable hooks. Call once from SKSEPluginLoad.
    void Install();

    /// Sets actor's multiplier (clamped kMin..kMax). 1.0 removes the entry.
    void Set(RE::Actor* a_actor, float a_speed);

    /// Removes actor's multiplier (plays at 1.0).
    void Clear(RE::Actor* a_actor);

    /// Removes every multiplier. Called on load / new game so nothing leaks across saves.
    void ClearAll();

    /// Actor's effective multiplier (style speed x scale, clamped kMin..kMax), 1.0 when none is set.
    float Get(RE::Actor* a_actor);

    /// Scene HUD faster/slower: an extra factor on top of Set's style speed. 1.0 removes it.
    /// Clear / ClearAll drop it too.
    void SetScale(RE::Actor* a_actor, float a_scale);
}
