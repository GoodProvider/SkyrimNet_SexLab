#pragma once

#include "PCH.h"

#include <string_view>

/// Measures how long SkyrimNet takes from a DirectNarration being sent to the first speech it
/// plays (SkyrimNet_SpeechStarted mod event). Each sample and the running stats are logged to
/// SkyrimNet_SexLab.log as "NarrationTiming:" lines; used to size the window between narration
/// generation and first vocalization.
namespace NarrationTiming
{
    /// Adds the mod event sink (kDataLoaded).
    void Install();

    /// A DirectNarration was handed to SkyrimNet. Starts the timer unless one is already running.
    void MarkSent(std::string_view msg);

    /// Drops the running timer and speech state (load / new game). Run stats are kept.
    void Clear();

    /// Expected DN -> first speech seconds: median of the last clean samples, or fallback while there
    /// are too few. Clamped to [1, 30].
    double EstimateSeconds(double fallback);

    /// Count of non-player SkyrimNet_SpeechStarted events this session (any thread).
    std::uint64_t SpeechStarts();
}
