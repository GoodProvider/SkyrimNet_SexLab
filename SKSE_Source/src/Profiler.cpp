#include "Profiler.h"

#include "ActionCatalog.h"
#include "JsonUtil.h"
#include "WebUI.h"
#include "WebUI_Log.h"

#include <Windows.h>

#include <chrono>
#include <condition_variable>
#include <cstring>
#include <ctime>
#include <deque>
#include <filesystem>
#include <format>
#include <fstream>
#include <memory>
#include <mutex>
#include <thread>
#include <unordered_map>
#include <vector>

#include <nlohmann/json.hpp>

namespace Profiler
{
    std::atomic<bool> g_recording{ false };

    namespace
    {
#pragma pack(push, 1)
        struct Event
        {
            std::uint8_t type;
            std::uint8_t source;
            std::uint16_t key;
            std::uint32_t id;
            std::uint32_t os_tid;
            std::int32_t sl_thread;
            std::uint64_t qpc;
            std::uint64_t dur;
            std::uint32_t stack_id;
            char detail[76];
        };

        struct FileHeader
        {
            char magic[4];
            std::uint16_t version;
            std::uint16_t header_bytes;
            char run_key[32];
            std::uint32_t part;
            std::uint64_t qpc_freq;
            std::uint64_t t0;
            std::uint32_t dropped;
            std::uint32_t event_count;
            std::uint32_t key_count;
            std::uint32_t event_bytes;
        };
#pragma pack(pop)
        static_assert(sizeof(Event) == 112, "profile event layout is pinned at 112 bytes");
        static_assert(sizeof(FileHeader) == 76, "profile header layout is pinned at 76 bytes");

        constexpr std::size_t kCapacity = 200000;
        constexpr std::size_t kSwapAt = kCapacity * 8 / 10;
        constexpr std::size_t kMaxKeys = 1024;
        constexpr std::uint16_t kOtherKey = 0xFFFF;

        struct StringHash
        {
            using is_transparent = void;
            std::size_t operator()(std::string_view s) const noexcept { return std::hash<std::string_view>{}(s); }
        };

        using Buffer = std::vector<Event>;

        struct Job
        {
            std::unique_ptr<Buffer> events;
            std::vector<std::string> keys;
            std::string run;
            std::filesystem::path dir;
            std::uint32_t part = 0;
            std::uint32_t dropped = 0;
            std::uint64_t t0 = 0;
            bool final = false;
        };

        struct PendingNote
        {
            std::string run;
            std::filesystem::path dir;
            std::uint32_t part = 0;
        };

        std::uint64_t g_qpcFreq = 0;

        // Run control. g_ctl serializes transitions; g_state is read without it.
        std::mutex g_ctl;
        std::atomic<State> g_state{ State::kIdle };
        std::string g_run;
        std::filesystem::path g_dir;
        std::atomic<std::uint32_t> g_partsWritten{ 0 };

        // Recorder. Lock order: g_ctl -> g_rec -> g_wq.
        std::mutex g_rec;
        std::unique_ptr<Buffer> g_active;
        std::uint32_t g_dropped = 0;
        std::uint32_t g_nextId = 1;
        std::uint32_t g_nextPart = 1;
        std::uint64_t g_t0 = 0;
        std::unordered_map<std::string, std::uint16_t, StringHash, std::equal_to<>> g_keyIndex;
        std::vector<std::string> g_keys;

        // Part writer.
        std::mutex g_wq;
        std::condition_variable g_wcv;
        std::deque<Job> g_jobs;
        std::atomic<bool> g_writerBusy{ false };
        std::once_flag g_workerOnce;
        std::once_flag g_tickerOnce;

        std::mutex g_notesMutex;
        std::deque<PendingNote> g_notes;

        const char* StateName(State s)
        {
            switch (s) {
            case State::kCalibrating:
                return "calibrating";
            case State::kStarting:
                return "starting";
            case State::kProfiling:
                return "profiling";
            default:
                return "idle";
            }
        }

        void Marker(const std::string& run, const std::string& what)
        {
            SKSE::log::info("[Profiler] run:{} {}", run, what);
        }

        std::string PartName(std::uint32_t part) { return std::format("{:03}", part); }

        /// HUD line through Debug.Notification on the game thread (safe from the writer thread).
        void Notify(std::string msg)
        {
            SKSE::GetTaskInterface()->AddTask([msg = std::move(msg)]() {
                auto* vm = RE::BSScript::Internal::VirtualMachine::GetSingleton();
                if (!vm)
                    return;
                auto* args = RE::MakeFunctionArguments(RE::BSFixedString(msg.c_str()));
                RE::BSTSmartPointer<RE::BSScript::IStackCallbackFunctor> callback;
                vm->DispatchStaticCall(RE::BSFixedString("Debug"), RE::BSFixedString("Notification"), args, callback);
            });
        }

        void PushPanelSoon()
        {
            SKSE::GetTaskInterface()->AddTask([]() { PushPanel(); });
        }

        std::string RunKeyNow()
        {
            const std::time_t t = std::time(nullptr);
            std::tm tm{};
            localtime_s(&tm, &t);
            char buf[32];
            std::strftime(buf, sizeof(buf), "%Y-%m-%d-%H-%M-%S", &tm);
            return buf;
        }

        /// Caller holds g_rec. Only a key's first intern allocates; past kMaxKeys a key records as other.
        std::uint16_t InternLocked(std::string_view key)
        {
            if (auto it = g_keyIndex.find(key); it != g_keyIndex.end())
                return it->second;
            if (g_keys.size() >= kMaxKeys)
                return kOtherKey;
            const auto idx = static_cast<std::uint16_t>(g_keys.size());
            g_keys.emplace_back(key);
            g_keyIndex.emplace(g_keys.back(), idx);
            return idx;
        }

        void CopyDetail(char (&dst)[76], std::string_view src)
        {
            std::size_t n = (std::min)(src.size(), sizeof(dst));
            // Cut on a UTF-8 character boundary.
            if (n < src.size())
                while (n > 0 && (static_cast<unsigned char>(src[n]) & 0xC0) == 0x80)
                    --n;
            std::memset(dst, 0, sizeof(dst));
            if (n)
                std::memcpy(dst, src.data(), n);
        }

        void StartWorker();

        /// Caller holds g_rec. Hands the active buffer to the writer and starts a fresh one.
        void SwapLocked()
        {
            Job job;
            job.events = std::move(g_active);
            job.keys = g_keys;
            job.run = g_run;
            job.dir = g_dir;
            job.part = g_nextPart++;
            job.dropped = g_dropped;
            job.t0 = g_t0;
            g_dropped = 0;
            g_active = std::make_unique<Buffer>();
            g_active->reserve(kCapacity);
            {
                std::lock_guard wl(g_wq);
                g_writerBusy = true;
                g_jobs.push_back(std::move(job));
            }
            {
                std::lock_guard nl(g_notesMutex);
                g_notes.push_back({ g_run, g_dir, g_nextPart - 1 });
            }
            g_wcv.notify_one();
            Event e{};
            e.type = kMark;
            e.source = kSrcMark;
            e.key = InternLocked("prof.part_write.start");
            e.os_tid = GetCurrentThreadId();
            e.sl_thread = -1;
            e.qpc = Now();
            g_active->push_back(e);
        }

        /// Caller holds g_rec. Stores one event: swap at 80% when the writer is free, drop only at 100%.
        bool PushLocked(const Event& e)
        {
            if (!g_active)
                return false;
            const auto size = g_active->size();
            if (size >= kSwapAt && !g_writerBusy.load())
                SwapLocked();
            else if (size >= kCapacity) {
                ++g_dropped;
                return false;
            }
            g_active->push_back(e);
            return true;
        }

        /// Caller holds g_ctl. Hands the active buffer to the writer as the run's last part.
        void WriteFinalPartLocked()
        {
            std::lock_guard lock(g_rec);
            if (!g_active)
                return;
            Job job;
            job.events = std::move(g_active);
            job.keys = g_keys;
            job.run = g_run;
            job.dir = g_dir;
            job.part = g_nextPart++;
            job.dropped = g_dropped;
            job.t0 = g_t0;
            job.final = true;
            g_dropped = 0;
            {
                std::lock_guard wl(g_wq);
                g_writerBusy = true;
                g_jobs.push_back(std::move(job));
            }
            {
                std::lock_guard nl(g_notesMutex);
                g_notes.push_back({ g_run, g_dir, g_nextPart - 1 });
            }
            g_wcv.notify_one();
        }

        bool WriteFile(const Job& job, const std::filesystem::path& path)
        {
            try {
                std::ofstream f(path, std::ios::binary | std::ios::trunc);
                if (!f)
                    return false;
                FileHeader h{};
                std::memcpy(h.magic, "SLPF", 4);
                h.version = 1;
                h.header_bytes = sizeof(FileHeader);
                std::memcpy(h.run_key, job.run.data(), (std::min)(job.run.size(), sizeof(h.run_key)));
                h.part = job.part;
                h.qpc_freq = g_qpcFreq;
                h.t0 = job.t0;
                h.dropped = job.dropped;
                h.event_count = static_cast<std::uint32_t>(job.events->size());
                h.key_count = static_cast<std::uint32_t>(job.keys.size());
                h.event_bytes = sizeof(Event);
                f.write(reinterpret_cast<const char*>(&h), sizeof(h));
                for (const auto& k : job.keys) {
                    const auto len = static_cast<std::uint16_t>(k.size());
                    f.write(reinterpret_cast<const char*>(&len), sizeof(len));
                    f.write(k.data(), len);
                }
                if (!job.events->empty())
                    f.write(reinterpret_cast<const char*>(job.events->data()),
                        static_cast<std::streamsize>(job.events->size() * sizeof(Event)));
                f.flush();
                return f.good();
            } catch (...) {
                return false;
            }
        }

        void RemovePendingNote(const std::string& run, std::uint32_t part)
        {
            std::lock_guard nl(g_notesMutex);
            std::erase_if(g_notes, [&](const PendingNote& n) { return n.run == run && n.part == part; });
        }

        void WriterLoop()
        {
            for (;;) {
                Job job;
                {
                    std::unique_lock wl(g_wq);
                    g_wcv.wait(wl, [] { return !g_jobs.empty(); });
                    job = std::move(g_jobs.front());
                    g_jobs.pop_front();
                }
                const auto name = PartName(job.part);
                const auto path = job.dir / ("part-" + name + ".bin");
                bool ok = WriteFile(job, path);
                if (!ok)
                    ok = WriteFile(job, path);  // one retry
                const auto events = job.events->size();
                job.events.reset();  // free the standby
                if (ok) {
                    ++g_partsWritten;
                    Marker(job.run, std::format("part:{} written events:{} dropped:{}", name, events, job.dropped));
                    if (!job.final)
                        Notify("SexLab profile part " + name + " written; open the SexLab menu to describe it");
                } else {
                    std::error_code ec;
                    std::filesystem::remove(path, ec);
                    RemovePendingNote(job.run, job.part);
                    Marker(job.run, "part:" + name + " write_failed");
                    Notify("SexLab profile part " + name + " could not be written");
                }
                bool idle;
                {
                    std::lock_guard wl(g_wq);
                    idle = g_jobs.empty();
                    if (idle)
                        g_writerBusy = false;
                }
                {
                    std::lock_guard lock(g_rec);
                    if (g_active && g_run == job.run) {
                        Event e{};
                        e.type = kMark;
                        e.source = kSrcMark;
                        e.key = InternLocked("prof.part_write.end");
                        e.os_tid = GetCurrentThreadId();
                        e.sl_thread = -1;
                        e.qpc = Now();
                        PushLocked(e);
                    }
                }
                PushPanelSoon();
            }
        }

        void StartWorker()
        {
            std::call_once(g_workerOnce, [] { std::thread(WriterLoop).detach(); });
        }

        /// Once a second while the Profile panel is the open main panel and a run is active.
        void StartTicker()
        {
            std::call_once(g_tickerOnce, [] {
                std::thread([] {
                    for (;;) {
                        std::this_thread::sleep_for(std::chrono::seconds(1));
                        if (g_state.load() == State::kIdle)
                            continue;
                        SKSE::GetTaskInterface()->AddTask([]() {
                            if (!WebUI_IsHidden() && ActionCatalog::IsMainPanelOpen("profile_panel"))
                                PushPanel();
                        });
                    }
                }).detach();
            });
        }

        void OpenNextNote()
        {
            PendingNote next;
            std::size_t remaining = 0;
            {
                std::lock_guard nl(g_notesMutex);
                if (g_notes.empty())
                    return;
                next = g_notes.front();
                remaining = g_notes.size();
            }
            nlohmann::json j;
            j["run"] = next.run;
            j["part"] = next.part;
            j["remaining"] = remaining;
            WebUI_Invoke("openProfileNote(" + SafeDump(j) + ");");
        }

        class CalibrateCallback : public RE::BSScript::IStackCallbackFunctor
        {
        public:
            void operator()(RE::BSScript::Variable) override
            {
                std::lock_guard lock(g_ctl);
                if (g_state.load() != State::kStarting)
                    return;
                g_recording = false;
                {
                    std::lock_guard rl(g_rec);
                    if (g_active)
                        g_active->clear();
                }
                Marker(g_run, "profiling_start_failed");
                g_state = State::kCalibrating;
                PushPanelSoon();
            }
            void SetObject(const RE::BSTSmartPointer<RE::BSScript::Object>&) override {}
        };
    }

    std::uint64_t Now() noexcept
    {
        LARGE_INTEGER t;
        QueryPerformanceCounter(&t);
        return static_cast<std::uint64_t>(t.QuadPart);
    }

    std::uint32_t Begin(std::uint8_t source, std::string_view key, std::int32_t slThread, std::uint32_t stackId)
    {
        if (!Recording())
            return 0;
        Event e{};
        e.qpc = Now();
        e.type = kBegin;
        e.source = source;
        e.os_tid = GetCurrentThreadId();
        e.sl_thread = slThread;
        e.stack_id = stackId;
        std::lock_guard lock(g_rec);
        e.key = InternLocked(key);
        e.id = g_nextId++;
        if (g_nextId == 0)
            g_nextId = 1;
        PushLocked(e);
        return e.id;
    }

    void End(std::uint32_t id, std::string_view detail, std::uint32_t stackId)
    {
        if (id == 0)
            return;
        const auto t = Now();
        Event e{};
        e.type = kEnd;
        e.source = kSrcPapyrus;
        e.key = kOtherKey;  // unused on E: python takes the key from the matching B
        e.id = id;
        e.os_tid = GetCurrentThreadId();
        e.sl_thread = -1;
        e.qpc = t;
        e.stack_id = stackId;
        CopyDetail(e.detail, detail);
        std::lock_guard lock(g_rec);
        PushLocked(e);
    }

    void Mark(std::string_view key, std::int32_t slThread, std::string_view detail, std::uint32_t stackId)
    {
        if (!Recording())
            return;
        const auto t = Now();
        Event e{};
        e.type = kMark;
        e.source = kSrcMark;
        e.os_tid = GetCurrentThreadId();
        e.sl_thread = slThread;
        e.qpc = t;
        e.stack_id = stackId;
        CopyDetail(e.detail, detail);
        std::lock_guard lock(g_rec);
        e.key = InternLocked(key);
        PushLocked(e);
    }

    void CalibMark(std::string_view key, std::uint32_t stackId)
    {
        const auto t = Now();
        Event e{};
        e.type = kMark;
        e.source = kSrcMark;
        e.os_tid = GetCurrentThreadId();
        e.sl_thread = -1;
        e.qpc = t;
        e.stack_id = stackId;
        std::lock_guard lock(g_rec);
        if (!g_active)
            return;
        e.key = InternLocked(key);
        PushLocked(e);
    }

    void Complete(std::uint8_t source, std::string_view key, std::uint64_t startQpc, std::uint64_t durTicks,
        std::uint32_t stackId)
    {
        Event e{};
        e.type = kComplete;
        e.source = source;
        e.os_tid = GetCurrentThreadId();
        e.sl_thread = -1;
        e.qpc = startQpc;
        e.dur = durTicks;
        e.stack_id = stackId;
        std::lock_guard lock(g_rec);
        e.key = InternLocked(key);
        PushLocked(e);
    }

    State GetState() noexcept { return g_state.load(); }

    std::string PanelJson()
    {
        nlohmann::json j;
        j["state"] = StateName(g_state.load());
        double fill = 0.0;
        {
            std::lock_guard lock(g_rec);
            j["run"] = g_run;
            if (g_active)
                fill = 100.0 * static_cast<double>(g_active->size()) / static_cast<double>(kCapacity);
        }
        j["fill_pct"] = fill;
        j["parts"] = g_partsWritten.load();
        {
            std::lock_guard nl(g_notesMutex);
            j["pending_notes"] = g_notes.size();
        }
        return SafeDump(j);
    }

    void PushPanel()
    {
        WebUI_Invoke("configureProfilePanel(" + PanelJson() + ");");
    }

    void StartCalibration()
    {
        {
            std::lock_guard lock(g_ctl);
            if (g_state.load() != State::kIdle)
                return;
            const auto logDir = SKSE::log::log_directory();
            if (!logDir) {
                Notify("SexLab profile: no SKSE log directory");
                return;
            }
            const auto key = RunKeyNow();
            const auto dir = *logDir / "SkyrimNet_SexLab" / key;
            std::error_code ec;
            if (std::filesystem::exists(dir, ec)) {
                Notify("SexLab profile run " + key + " already exists; try again in a second");
                return;
            }
            std::filesystem::create_directories(dir, ec);
            if (ec) {
                Notify("SexLab profile: cannot create " + dir.string());
                return;
            }
            if (!g_qpcFreq) {
                LARGE_INTEGER f;
                QueryPerformanceFrequency(&f);
                g_qpcFreq = static_cast<std::uint64_t>(f.QuadPart);
            }
            StartWorker();
            StartTicker();
            {
                std::lock_guard rl(g_rec);
                g_run = key;
                g_dir = dir;
                g_active = std::make_unique<Buffer>();
                g_active->reserve(kCapacity);
                g_dropped = 0;
                g_nextId = 1;
                g_nextPart = 1;
                g_keyIndex.clear();
                g_keys.clear();
                g_t0 = Now();
            }
            g_partsWritten = 0;
            g_recording = false;
            Marker(key, "calibration_start");
            g_state = State::kCalibrating;
        }
        PushPanel();
    }

    void Cancel()
    {
        {
            std::lock_guard lock(g_ctl);
            if (g_state.load() != State::kCalibrating)
                return;
            std::filesystem::path dir;
            {
                std::lock_guard rl(g_rec);
                g_active.reset();
                dir = g_dir;
            }
            Marker(g_run, "calibration_cancel");
            std::error_code ec;
            if (std::filesystem::is_directory(dir, ec) && std::filesystem::is_empty(dir, ec))
                std::filesystem::remove(dir, ec);
            g_state = State::kIdle;
        }
        PushPanel();
    }

    void StartProfiling()
    {
        std::lock_guard lock(g_ctl);
        if (g_state.load() != State::kCalibrating)
            return;
        g_state = State::kStarting;
        PushPanel();
        Marker(g_run, "profiling_start");
        auto* vm = RE::BSScript::Internal::VirtualMachine::GetSingleton();
        RE::BSTSmartPointer<RE::BSScript::IStackCallbackFunctor> callback{ new CalibrateCallback() };
        auto* args = RE::MakeFunctionArguments(static_cast<std::int32_t>(1000));
        if (!vm || !vm->DispatchStaticCall(RE::BSFixedString("SkyrimNet_SexLab_WebUI"),
                       RE::BSFixedString("Prof_Calibrate"), args, callback)) {
            if (!vm)
                delete args;
            Marker(g_run, "profiling_start_failed");
            g_state = State::kCalibrating;
            PushPanelSoon();
        }
    }

    void Stop()
    {
        {
            std::lock_guard lock(g_ctl);
            if (g_state.load() != State::kProfiling)
                return;
            g_recording = false;
            Marker(g_run, "profiling_end");
            WriteFinalPartLocked();
            g_state = State::kIdle;
        }
        PushPanel();
        OpenNextNote();
    }

    void Note(const std::string& payload)
    {
        std::string run;
        std::uint32_t part = 0;
        std::string text;
        try {
            auto j = nlohmann::json::parse(payload);
            run = j.value("run", "");
            part = j.value("part", 0u);
            text = j.value("text", "");
        } catch (...) {
            webui_log::warn("Profiler::Note: bad JSON");
            return;
        }
        std::filesystem::path dir;
        {
            std::lock_guard nl(g_notesMutex);
            auto it = std::find_if(g_notes.begin(), g_notes.end(),
                [&](const PendingNote& n) { return n.run == run && n.part == part; });
            if (it == g_notes.end())
                return;
            dir = it->dir;
            g_notes.erase(it);
        }
        const auto name = PartName(part);
        try {
            std::ofstream f(dir / ("part-" + name + ".note.txt"), std::ios::binary | std::ios::trunc);
            f << text;
        } catch (...) {
            webui_log::warn("Profiler::Note: cannot write part {} note", name);
        }
        std::string oneLine = text;
        for (auto& c : oneLine)
            if (c == '\r' || c == '\n')
                c = ' ';
        Marker(run, "note part:" + name + " " + oneLine);
        PushPanel();
        OpenNextNote();
    }

    void SetRecordingFromCalibration(bool on)
    {
        if (g_state.load() != State::kStarting)
            return;
        g_recording = on;
    }

    void EnterProfiling()
    {
        {
            std::lock_guard lock(g_ctl);
            if (g_state.load() != State::kStarting)
                return;
            g_state = State::kProfiling;
        }
        PushPanelSoon();
    }

    void CalibrateCpp(std::int32_t n, bool on)
    {
        if (g_state.load() != State::kStarting)
            return;
        CalibMark(on ? "calib.cpp.on.start" : "calib.cpp.off.start", 0);
        for (std::int32_t i = 0; i < n; ++i) {
            SNSL_PROF("calib.cpp");
        }
        CalibMark(on ? "calib.cpp.on.end" : "calib.cpp.off.end", 0);
    }

    void OnNewGame()
    {
        {
            std::lock_guard lock(g_ctl);
            const auto s = g_state.load();
            if (s != State::kProfiling && s != State::kStarting)
                return;
            WriteFinalPartLocked();
            Marker(g_run, s == State::kProfiling ? "profiling_end" : "profiling_start_failed");
            g_recording = false;
            g_state = State::kIdle;
        }
        PushPanelSoon();
    }

    void OnOverlayShown()
    {
        if (g_state.load() == State::kStarting)
            return;
        OpenNextNote();
    }
}
