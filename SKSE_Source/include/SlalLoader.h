#pragma once

#include <string>

/// Loads SLAL animation packs straight from disk into AnimationDB (registry rows + AnimEngine playback data).
/// Sources: Data/SLAnims/json/*.json (SLAL_SE's format), SKSE/Plugins/SkyrimNet_SexLab/slal/*.json (our packs,
/// e.g. the SexLab built-ins export), FNIS lists under Data/meshes/actors/**/animations/<pack>/FNIS_*_List.txt
/// (stage event → hkx, AnimObjects, animvars) and, when present, PPA's ppa-animation-tagging/*.json (per-stage
/// penetration targets). No SexLab code. See docs/developers/anim-engine.md.
namespace SlalLoader
{
    /// Runs the load on a worker thread. force: reparse and rebuild rows even when no source file changed.
    /// drop_legacy: afterwards delete Papyrus-pushed rows (source 0/1, the old SexLab registry walk); set on
    /// SexLab AE, where AnimDB is the registry. Returns false when a load is already running (the request is
    /// then queued and runs right after).
    bool StartAsync(bool force, bool drop_legacy = false);
    /// Synchronous load (worker body). Returns the number of animations stored, -1 when skipped (unchanged).
    int Run(bool force, bool drop_legacy = false);
    bool IsRunning();
    /// One-line status of the last load (WebUI / Papyrus).
    std::string LastSummary();
}
