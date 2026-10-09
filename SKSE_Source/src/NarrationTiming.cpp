#include "NarrationTiming.h"
#include "WebUI_Log.h"

#include <algorithm>
#include <atomic>
#include <chrono>
#include <cmath>
#include <mutex>
#include <numeric>
#include <optional>
#include <span>
#include <string>
#include <unordered_map>
#include <vector>

namespace NarrationTiming
{
    namespace
    {
        using Clock = std::chrono::steady_clock;

        constexpr auto kTimeout = std::chrono::seconds(60);
        constexpr std::size_t kPreviewLen = 60;
        constexpr std::size_t kEstimateSamples = 20;  // EstimateSeconds: median of the latest samples
        constexpr std::size_t kEstimateMin = 3;       // fewer clean samples: the caller's fallback

        struct Pending
        {
            Clock::time_point sent;
            std::string preview;
            bool busy = false;        // speech was already playing when the narration was sent
            int extra_sends = 0;      // more narrations sent before the first speech
        };

        std::mutex g_lock;
        std::optional<Pending> g_pending;
        // SpeechStarted fires per sentence, SpeechComplete once per response: a flag, not a count.
        bool g_speaking = false;
        std::vector<double> g_clean;  // seconds; samples with busy == false and extra_sends == 0
        int g_busy = 0;
        int g_overlapped = 0;
        int g_missed = 0;
        std::atomic<std::uint64_t> g_speechStarts{ 0 };
        std::atomic<std::uint64_t> g_completions{ 0 };
        // The paired response now playing (its Completions() index, 0 = none) and its speaker; the last one
        // whose SpeechComplete arrived (ResponseDoneSince).
        std::uint64_t g_openResponse = 0;
        RE::FormID g_openSpeaker = 0;
        std::atomic<std::uint64_t> g_lastDoneResponse{ 0 };

        // Per-speaker responses, so a scene waits only for its own actors' voices (two scenes narrating
        // together paired the other scene's reply, 2026-10-08). g_seq bumps on every non-player
        // SpeechStarted; a speaker's response opens at its first sentence and closes at its SpeechComplete.
        struct Speaker
        {
            std::uint64_t openStart = 0;  // seq of the open response's first sentence (0 = none open)
            std::uint64_t lastStart = 0;  // seq of the latest sentence
            std::uint64_t lastDone = 0;   // first-sentence seq of the latest completed response
        };
        std::uint64_t g_seq = 0;
        std::unordered_map<RE::FormID, Speaker> g_speakers;

        // Caller holds g_lock.
        void ExpireStale(Clock::time_point now)
        {
            if (!g_pending || now - g_pending->sent < kTimeout)
                return;
            ++g_missed;
            webui_log::info("NarrationTiming: missed, no speech within {}s \"{}\" | missed {}",
                kTimeout.count(), g_pending->preview, g_missed);
            g_pending.reset();
        }

        // Caller holds g_lock.
        std::string StatsLine()
        {
            std::string out = std::format("clean n={}", g_clean.size());
            if (!g_clean.empty()) {
                auto sorted = g_clean;
                std::sort(sorted.begin(), sorted.end());
                const auto n = sorted.size();
                const double mean = std::accumulate(sorted.begin(), sorted.end(), 0.0) / n;
                const double median = n % 2 ? sorted[n / 2] : (sorted[n / 2 - 1] + sorted[n / 2]) / 2.0;
                const auto p90_idx = static_cast<std::size_t>(std::ceil(0.9 * n)) - 1;
                out += std::format(" mean {:.2f} median {:.2f} p90 {:.2f} min {:.2f} max {:.2f}", mean, median,
                    sorted[p90_idx], sorted.front(), sorted.back());
            }
            out += std::format(" | busy {} overlapped {} missed {}", g_busy, g_overlapped, g_missed);
            return out;
        }

        // Caller holds g_lock.
        void OnSpeechStarted(RE::TESForm* sender)
        {
            const auto now = Clock::now();
            g_speaking = true;
            ExpireStale(now);
            // The player's own voiced line is not the response to the narration.
            if (sender && sender->GetFormID() == 0x14)
                return;
            g_speechStarts.fetch_add(1);
            if (sender) {
                auto& sp = g_speakers[sender->GetFormID()];
                ++g_seq;
                if (sp.openStart == 0)
                    sp.openStart = g_seq;
                sp.lastStart = g_seq;
            }
            if (!g_pending)
                return;

            const double secs = std::chrono::duration<double>(now - g_pending->sent).count();
            if (g_pending->busy)
                ++g_busy;
            else if (g_pending->extra_sends > 0)
                ++g_overlapped;
            else
                g_clean.push_back(secs);

            auto* actor = sender ? sender->As<RE::Actor>() : nullptr;
            const char* name = actor ? actor->GetDisplayFullName() : nullptr;
            webui_log::info("NarrationTiming: DN->speech {:.2f}s speaker={}({:08X}) busy={} extra={} \"{}\" | {}",
                secs, name && name[0] ? name : "?", sender ? sender->GetFormID() : 0u, g_pending->busy ? 1 : 0,
                g_pending->extra_sends,
                g_pending->preview, StatsLine());
            g_pending.reset();
            g_openResponse = g_completions.fetch_add(1) + 1;
            g_openSpeaker = sender ? sender->GetFormID() : 0;
        }

        // Caller holds g_lock. SpeechComplete: once per response. The player's own line (or another speaker's)
        // does not end the paired response.
        void OnSpeechComplete(RE::TESForm* sender)
        {
            g_speaking = false;
            const RE::FormID id = sender ? sender->GetFormID() : 0;
            if (const auto it = g_speakers.find(id); id != 0 && it != g_speakers.end()) {
                it->second.lastDone = it->second.openStart ? it->second.openStart : it->second.lastStart;
                it->second.openStart = 0;
            }
            if (g_openResponse == 0) {
                return;
            }
            if (id != 0 && g_openSpeaker != 0 && id != g_openSpeaker) {
                return;
            }
            g_lastDoneResponse.store(g_openResponse);
            webui_log::info("NarrationTiming: response {} complete speaker={:08X}", g_openResponse, id);
            g_openResponse = 0;
            g_openSpeaker = 0;
        }

        class SpeechSink : public RE::BSTEventSink<SKSE::ModCallbackEvent>
        {
        public:
            static SpeechSink* GetSingleton()
            {
                static SpeechSink sink;
                return &sink;
            }

            // Runs on the sender's thread (SkyrimNet's ModEventSender), not the game thread.
            RE::BSEventNotifyControl ProcessEvent(const SKSE::ModCallbackEvent* a_event,
                RE::BSTEventSource<SKSE::ModCallbackEvent>*) override
            {
                if (!a_event)
                    return RE::BSEventNotifyControl::kContinue;
                const std::string_view name = a_event->eventName.c_str() ? a_event->eventName.c_str() : "";
                if (name == "SkyrimNet_SpeechStarted") {
                    std::lock_guard lock(g_lock);
                    OnSpeechStarted(a_event->sender);
                } else if (name == "SkyrimNet_SpeechComplete") {
                    std::lock_guard lock(g_lock);
                    OnSpeechComplete(a_event->sender);
                }
                return RE::BSEventNotifyControl::kContinue;
            }
        };
    }

    void Install()
    {
        auto* source = SKSE::GetModCallbackEventSource();
        if (!source) {
            webui_log::error("NarrationTiming: no mod event source, latency not tracked");
            return;
        }
        source->AddEventSink(SpeechSink::GetSingleton());
        webui_log::info("NarrationTiming: listening for SkyrimNet_SpeechStarted");
    }

    void MarkSent(std::string_view msg)
    {
        if (msg.empty())
            return;
        const auto now = Clock::now();
        std::lock_guard lock(g_lock);
        ExpireStale(now);
        if (g_pending) {
            ++g_pending->extra_sends;
            return;
        }
        std::string preview(msg.substr(0, kPreviewLen));
        if (msg.size() > kPreviewLen)
            preview += "...";
        g_pending = Pending{ now, std::move(preview), g_speaking, 0 };
    }

    void Clear()
    {
        std::lock_guard lock(g_lock);
        g_pending.reset();
        g_speaking = false;
        g_openResponse = 0;
        g_openSpeaker = 0;
        g_speakers.clear();
    }

    double EstimateSeconds(double fallback)
    {
        double est = fallback;
        {
            std::lock_guard lock(g_lock);
            if (g_clean.size() >= kEstimateMin) {
                const auto first = g_clean.size() > kEstimateSamples ? g_clean.end() - kEstimateSamples
                                                                     : g_clean.begin();
                std::vector<double> recent(first, g_clean.end());
                std::sort(recent.begin(), recent.end());
                const auto n = recent.size();
                est = n % 2 ? recent[n / 2] : (recent[n / 2 - 1] + recent[n / 2]) / 2.0;
            }
        }
        return std::clamp(est, 1.0, 30.0);
    }

    std::uint64_t SpeechStarts()
    {
        return g_speechStarts.load();
    }

    std::uint64_t Completions()
    {
        return g_completions.load();
    }

    bool ResponseDoneSince(std::uint64_t mark)
    {
        return g_lastDoneResponse.load() > mark;
    }

    std::uint64_t SpeakerMark()
    {
        std::lock_guard lock(g_lock);
        return g_seq;
    }

    bool StartedSince(std::uint64_t mark, std::span<const RE::FormID> speakers)
    {
        std::lock_guard lock(g_lock);
        for (const auto id : speakers) {
            const auto it = g_speakers.find(id);
            if (it != g_speakers.end() && it->second.lastStart > mark)
                return true;
        }
        return false;
    }

    bool DoneSince(std::uint64_t mark, std::span<const RE::FormID> speakers)
    {
        std::lock_guard lock(g_lock);
        for (const auto id : speakers) {
            const auto it = g_speakers.find(id);
            if (it != g_speakers.end() && it->second.lastDone > mark)
                return true;
        }
        return false;
    }

    bool DoneSinceMostRecentStarted(std::uint64_t mark, std::span<const RE::FormID> speakers)
    {
        std::lock_guard lock(g_lock);
        std::uint64_t bestStart = 0;
        RE::FormID bestId = 0;
        for (const auto id : speakers) {
            const auto it = g_speakers.find(id);
            if (it == g_speakers.end())
                continue;
            const std::uint64_t start = it->second.lastStart;
            if (start > mark && start >= bestStart) {
                bestStart = start;
                bestId = id;
            }
        }
        if (bestStart == 0 || bestId == 0)
            return false;
        const auto it = g_speakers.find(bestId);
        if (it == g_speakers.end())
            return false;
        const Speaker& sp = it->second;
        if (sp.openStart != 0)
            return false;
        return sp.lastDone >= bestStart && sp.lastDone > mark;
    }
}
