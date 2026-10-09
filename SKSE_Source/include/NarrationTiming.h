#pragma once

#include "PCH.h"

#include <span>
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

    /// Count of non-player SkyrimNet_SpeechStarted events this session (any thread). Bumped on every
    /// sentence of any speech, so it is NOT a reliable "the narration I just sent was spoken" signal
    /// by itself (a response already playing bumps it too) — prefer Completions() for that.
    std::uint64_t SpeechStarts();

    /// Count of MarkSent() calls actually paired off with a following speech start (the one-shot
    /// pending/consumed latency sample, regardless of busy/overlap). Unlike SpeechStarts(), later
    /// sentences of an already-matched response do not bump this again, so "Completions() grew past
    /// the count taken right after a MarkSent()" means that specific narration's own response began.
    std::uint64_t Completions();

    /// The response paired after `mark` (a Completions() value taken before the narration was sent) has
    /// finished playing: its speaker's SkyrimNet_SpeechComplete arrived.
    bool ResponseDoneSince(std::uint64_t mark);

    /// Scene-scoped response tracking. SpeakerMark(): a counter bumped by every non-player
    /// SkyrimNet_SpeechStarted; take it just before sending a narration.
    std::uint64_t SpeakerMark();

    /// One of `speakers` started speaking after `mark`.
    bool StartedSince(std::uint64_t mark, std::span<const RE::FormID> speakers);

    /// A response by one of `speakers` that started after `mark` has finished (its SpeechComplete).
    bool DoneSince(std::uint64_t mark, std::span<const RE::FormID> speakers);
}
