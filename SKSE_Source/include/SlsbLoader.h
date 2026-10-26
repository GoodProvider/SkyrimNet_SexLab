#pragma once

#include <string>

/// Loads SexLab P+ scene packs straight from disk into AnimationDB (registry rows + AnimEngine playback graph),
/// replacing the Papyrus SexlabRegistry walk when sexlab.anim_engine.slsb_registry is on.
/// Sources: Data/SKSE/SexLab/Registry/Source/*.slsb.json (SLSB's project files, which P+'s binary .slr files are
/// built from) and the FNIS lists (events are <prefix_hash><event>). A .slr without a .slsb.json of the same
/// pack_name is counted and logged, not parsed. No SexLab code. See docs/developers/anim-engine.md §2.
namespace SlsbLoader
{
    /// Same contract as SlalLoader::StartAsync (worker thread; queued when one is running).
    bool StartAsync(bool force, bool drop_legacy = false);
    /// Synchronous load. Returns the number of scenes stored, -1 when skipped (unchanged).
    int Run(bool force, bool drop_legacy = false);
    bool IsRunning();
    std::string LastSummary();
}
