#include "NarrationTiming.h"
#include "WebUI_Log.h"

#include <algorithm>
#include <atomic>
#include <chrono>
#include <cmath>
#include <mutex>
#include <numeric>
#include <optional>
#include <string>
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
                    g_speaking = false;
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
}
