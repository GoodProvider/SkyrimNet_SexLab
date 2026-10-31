#pragma once

#include "PCH.h"

#include <atomic>
#include <cstdint>
#include <string>
#include <string_view>

/// Raw event recorder for profiling runs, driven from the WebUI Profile panel.
/// The game only records events; python_scripts/profile_report.py decodes, pairs and reports them.
/// One run = calibration phase (recording off) + profiling phase (recording on), written as
/// <log_directory>/SkyrimNet_SexLab/<run key>/part-NNN.bin. Contract: checkpoints/profile/checkpoint-04.md.
namespace Profiler
{
    enum class State : std::uint8_t { kIdle, kCalibrating, kStarting, kProfiling };

    enum EventType : std::uint8_t { kBegin = 1, kEnd = 2, kComplete = 3, kMark = 4 };
    enum Source : std::uint8_t { kSrcPapyrus = 1, kSrcWait = 2, kSrcSkse = 3, kSrcTrace = 4, kSrcMark = 5 };

    extern std::atomic<bool> g_recording;

    /// Gameplay probes record only while this is true (profiling phase, and the calib.on windows).
    inline bool Recording() noexcept { return g_recording.load(std::memory_order_relaxed); }

    /// Raw QueryPerformanceCounter ticks.
    std::uint64_t Now() noexcept;

    /// Papyrus span open; returns the span id, or 0 when recording is off.
    std::uint32_t Begin(std::uint8_t source, std::string_view key, std::int32_t slThread, std::uint32_t stackId);
    /// Papyrus span close; id 0 returns at once.
    void End(std::uint32_t id, std::string_view detail, std::uint32_t stackId);
    /// Instant event; recorded only while recording is on.
    void Mark(std::string_view key, std::int32_t slThread, std::string_view detail, std::uint32_t stackId);
    /// Instant event written whenever a run buffer exists, recording on or off (calibration brackets).
    void CalibMark(std::string_view key, std::uint32_t stackId);
    /// Complete span (C++ scopes, TraceLog); caller checks Recording(). stackId: Papyrus VMStackID, 0 for C++.
    void Complete(std::uint8_t source, std::string_view key, std::uint64_t startQpc, std::uint64_t durTicks,
        std::uint32_t stackId = 0);

    /// RAII timer behind SNSL_PROF. Off: one atomic load.
    class Scope
    {
    public:
        explicit Scope(const char* key) noexcept : key_(Recording() ? key : nullptr), t0_(key_ ? Now() : 0) {}
        ~Scope()
        {
            if (key_)
                Complete(kSrcSkse, key_, t0_, Now() - t0_);
        }
        Scope(const Scope&) = delete;
        Scope& operator=(const Scope&) = delete;

    private:
        const char* key_;
        std::uint64_t t0_;
    };

    // --- Run control (WebUI Profile panel) ---
    State GetState() noexcept;
    void StartCalibration();
    void StartProfiling();
    void Cancel();
    void Stop();
    /// JS onProfileNote({run, part, text}).
    void Note(const std::string& payload);

    // --- Gated natives used by SkyrimNet_SexLab_WebUI.Prof_Calibrate (no-ops outside `starting`) ---
    void SetRecordingFromCalibration(bool on);
    void EnterProfiling();
    void CalibrateCpp(std::int32_t n, bool on);

    /// kNewGame: profiling/starting writes the open part, ends the run and returns to idle.
    void OnNewGame();
    /// Overlay Show: asks for the next pending part note.
    void OnOverlayShown();
    /// Pushes configureProfilePanel({...}) to JS.
    void PushPanel();
    /// configureProfilePanel payload as JSON text.
    std::string PanelJson();
}

#define SNSL_PROF_CAT2(a, b) a##b
#define SNSL_PROF_CAT(a, b) SNSL_PROF_CAT2(a, b)
/// Times the enclosing scope as an X event (source skse) while recording; key must be a string literal.
#define SNSL_PROF(key) ::Profiler::Scope SNSL_PROF_CAT(snslProfScope_, __LINE__){ key }
