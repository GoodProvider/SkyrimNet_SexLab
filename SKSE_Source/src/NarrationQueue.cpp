#include "NarrationQueue.h"
#include "NarrationTiming.h"
#include "WebUI.h"
#include "WebUI_Log.h"

#include <atomic>
#include <chrono>
#include <memory>
#include <mutex>
#include <thread>
#include <vector>

namespace NarrationQueue
{
    namespace
    {
        struct Entry
        {
            std::string msg;
            RE::FormID source = 0;
            RE::FormID target = 0;
            bool purge = false;
        };

        std::mutex g_lock;
        std::vector<Entry> g_entries;
        std::atomic<bool> g_watching{ false };
        // Bumped by Clear so a watcher from the previous session never flushes into this one.
        std::atomic<std::uint32_t> g_generation{ 0 };

        constexpr auto kPollInterval = std::chrono::milliseconds(250);

        bool EndsSentence(const std::string& s)
        {
            const auto last = s.find_last_not_of(" \t\r\n");
            if (last == std::string::npos)
                return true;
            const char c = s[last];
            return c == '.' || c == '!' || c == '?' || c == '"' || c == '\'' || c == '*';
        }

        RE::Actor* ActorFor(RE::FormID id)
        {
            return id ? RE::TESForm::LookupByID<RE::Actor>(id) : nullptr;
        }

        // Game thread: join the queue into one narration and hand it to Papyrus.
        void Flush()
        {
            std::vector<Entry> entries;
            {
                std::lock_guard lock(g_lock);
                entries.swap(g_entries);
            }
            if (entries.empty())
                return;

            std::string joined;
            RE::FormID source = 0;
            RE::FormID target = 0;
            bool purge = false;
            for (const auto& e : entries) {
                if (e.msg.empty())
                    continue;
                if (!joined.empty())
                    joined += EndsSentence(joined) ? " " : ". ";
                joined += e.msg;
                if (!source && e.source) {
                    source = e.source;
                    target = e.target;
                }
                if (!target && e.target)
                    target = e.target;
                purge = purge || e.purge;
            }
            if (joined.empty())
                return;

            auto* vm = RE::BSScript::Internal::VirtualMachine::GetSingleton();
            if (!vm) {
                webui_log::error("NarrationQueue: no VM, dropped {} narration(s)", entries.size());
                return;
            }
            auto* args = RE::MakeFunctionArguments(RE::BSFixedString(joined.c_str()),
                ActorFor(source), ActorFor(target), static_cast<bool>(purge));
            RE::BSTSmartPointer<RE::BSScript::IStackCallbackFunctor> callback;
            vm->DispatchStaticCall("SkyrimNet_SexLab_Utilities", "DirectNarration_Flush", args, callback);
            NarrationTiming::MarkSent(joined);
            webui_log::info("NarrationQueue: flushed {} narration(s): {}", entries.size(), joined);
        }

        // Sleeps off the game thread and posts a pause check each tick; the check (PrismaUI / UI
        // state) and the flush run on the game thread. SKSE tasks still run while paused.
        void StartWatcher()
        {
            bool expected = false;
            if (!g_watching.compare_exchange_strong(expected, true))
                return;
            const auto generation = g_generation.load();
            auto done = std::make_shared<std::atomic<bool>>(false);
            std::thread([generation, done]() {
                while (!done->load() && g_generation.load() == generation) {
                    std::this_thread::sleep_for(kPollInterval);
                    SKSE::GetTaskInterface()->AddTask([generation, done]() {
                        if (done->load() || g_generation.load() != generation || IsPaused())
                            return;
                        done->store(true);
                        g_watching = false;
                        Flush();
                    });
                }
                // g_watching was reset by the flush task, or by Clear on a generation change.
            }).detach();
        }
    }

    bool IsPaused()
    {
        if (WebUI_IsGamePaused())
            return true;
        auto* ui = RE::UI::GetSingleton();
        return ui && ui->GameIsPaused();
    }

    bool Enqueue(const std::string& msg, RE::Actor* source, RE::Actor* target, bool purge_dialogue)
    {
        if (msg.empty() || !IsPaused())
            return false;
        {
            std::lock_guard lock(g_lock);
            // A repeat (e.g. the same line from two paths) adds nothing to the joined narration.
            for (const auto& e : g_entries) {
                if (e.msg == msg)
                    return true;
            }
            g_entries.push_back(Entry{ msg, source ? source->GetFormID() : 0, target ? target->GetFormID() : 0,
                purge_dialogue });
        }
        webui_log::info("NarrationQueue: queued while paused: {}", msg);
        StartWatcher();
        return true;
    }

    void Clear()
    {
        g_generation.fetch_add(1);
        g_watching = false;
        std::lock_guard lock(g_lock);
        g_entries.clear();
    }
}
