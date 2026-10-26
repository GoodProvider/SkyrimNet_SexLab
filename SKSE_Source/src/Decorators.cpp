#include "Decorators.h"

#include "Config.h"
#include "JsonStore.h"
#include "JsonUtil.h"
#include "OrgasmEngine.h"
#include "Profiler.h"
#include "SceneRegistry.h"
#include "WebUI_Log.h"

#include <algorithm>
#include <atomic>
#include <filesystem>
#include <fstream>
#include <map>
#include <mutex>
#include <unordered_map>
#include <unordered_set>
#include <vector>

namespace Decorators
{
    namespace
    {
        using nlohmann::json;

        constexpr const char* kThreadsPath = "Data/SKSE/Plugins/SkyrimNet_SexLab/threads.json";
        constexpr float kUnitsToMeters = 0.0142875f;
        // Actors this far (game units) from a scene get their LOS to it primed on every push.
        constexpr float kLosPrimeRange = 6000.0f;

        std::string Str(const RE::BSFixedString& s) { return s.c_str() ? s.c_str() : ""; }

        std::string Name(RE::Actor* a)
        {
            if (!a)
                return "";
            const char* n = a->GetDisplayFullName();
            return n ? n : "";
        }

        // ---- LOS cache ----------------------------------------------------------------------
        // HasLineOfSight raycasts: main thread only. Decorators read the cache and queue a refresh;
        // Threads_Set primes nearby actors so the first prompt after a push is already current.
        std::mutex g_losMutex;
        std::unordered_map<std::uint64_t, bool> g_los;
        std::unordered_set<std::uint64_t> g_losPending;

        std::uint64_t LosKey(RE::FormID from, RE::FormID to)
        {
            return (static_cast<std::uint64_t>(from) << 32) | to;
        }

        void QueueLos(const std::vector<std::pair<RE::FormID, RE::FormID>>& pairs)
        {
            std::vector<std::pair<RE::FormID, RE::FormID>> todo;
            {
                std::lock_guard lock(g_losMutex);
                for (const auto& p : pairs) {
                    if (g_losPending.insert(LosKey(p.first, p.second)).second)
                        todo.push_back(p);
                }
            }
            auto* tasks = SKSE::GetTaskInterface();
            if (todo.empty() || !tasks)
                return;
            tasks->AddTask([todo]() {
                for (const auto& [fromId, toId] : todo) {
                    auto* from = RE::TESForm::LookupByID<RE::Actor>(fromId);
                    auto* to = RE::TESForm::LookupByID<RE::Actor>(toId);
                    bool ignored = false;
                    const bool los = from && to && from->HasLineOfSight(to, ignored);
                    std::lock_guard lock(g_losMutex);
                    g_los[LosKey(fromId, toId)] = los;
                    g_losPending.erase(LosKey(fromId, toId));
                }
            });
        }

        /// Cached LOS (false until the first main-thread check lands), refreshed for the next call.
        bool GetLos(RE::Actor* from, RE::Actor* to)
        {
            if (!from || !to)
                return false;
            bool los = false;
            {
                std::lock_guard lock(g_losMutex);
                if (auto it = g_los.find(LosKey(from->GetFormID(), to->GetFormID())); it != g_los.end())
                    los = it->second;
            }
            QueueLos({ { from->GetFormID(), to->GetFormID() } });
            return los;
        }

        /// Player + loaded actors near `anchor`: LOS to it, queued for the main thread.
        void PrimeLos(RE::Actor* anchor)
        {
            if (!anchor)
                return;
            std::vector<std::pair<RE::FormID, RE::FormID>> pairs;
            const auto anchorId = anchor->GetFormID();
            const auto anchorPos = anchor->GetPosition();
            if (auto* player = RE::PlayerCharacter::GetSingleton(); player && player != anchor)
                pairs.emplace_back(player->GetFormID(), anchorId);
            if (auto* pl = RE::ProcessLists::GetSingleton()) {
                for (auto& h : pl->highActorHandles) {
                    auto a = h.get();
                    if (!a || a.get() == anchor || a->GetPosition().GetDistance(anchorPos) > kLosPrimeRange)
                        continue;
                    pairs.emplace_back(a->GetFormID(), anchorId);
                }
            }
            QueueLos(pairs);
        }

        // ---- Thread registry --------------------------------------------------------------------
        // One entry per listed SexLab scene (sid): its thread_obj root in the JSON store, kept current
        // by Papyrus (Scene.PushThread), and the positions in slot order (thread_obj.actors order).
        struct ThreadEntry
        {
            SexLabNet::Json::Handle obj = SexLabNet::Json::kInvalidHandle;
            std::vector<RE::FormID> actors;
        };

        std::mutex g_threadsMutex;
        std::map<std::int32_t, ThreadEntry> g_threads;
        json g_domThreads = json::array();
        std::atomic<std::int64_t> g_counter{ 0 };
        std::string g_lastWritten;  // threads array last written to threads.json

        void ApplySpeakerFields(json& thread, RE::Actor* speaker, RE::Actor* anchor, bool speakerInThread,
            float inThreadDistance)
        {
            float distance = 0.0f;
            bool los = false;
            if (speaker) {
                if (speakerInThread) {
                    distance = inThreadDistance;
                    los = true;
                } else if (anchor) {
                    distance = kUnitsToMeters * speaker->GetPosition().GetDistance(anchor->GetPosition());
                    los = GetLos(speaker, anchor);
                }
            }
            thread["speaker_distance"] = distance;
            thread["speaker_los"] = los ? 1 : 0;
        }

        /// Scene thread: thread_obj copy + live OrgasmEngine fields + speaker fields.
        bool BuildSceneThread(const ThreadEntry& e, RE::Actor* speaker, json& out)
        {
            const std::string dumped = SexLabNet::Json::Dump(e.obj);
            if (dumped.empty())
                return false;
            out = json::parse(dumped, nullptr, false);
            if (out.is_discarded() || !out.is_object())
                return false;

            auto& actors = out["actors"];
            if (actors.is_array()) {
                for (std::size_t i = 0; i < actors.size() && i < e.actors.size(); ++i) {
                    auto* a = RE::TESForm::LookupByID<RE::Actor>(e.actors[i]);
                    if (!a || !actors[i].is_object() || !OrgasmEngine::IsManaged(a))
                        continue;
                    actors[i]["enjoyment"] = static_cast<int>(OrgasmEngine::GetEnjoyment(a));
                    // Mini-game NPC strategy phrase ("focuses on self enjoyment"); "" in Together mode.
                    actors[i]["strategy"] = OrgasmEngine::GetStrategyText(a);
                    // Stamina regen, percent of default (0550 tiredness tiers).
                    actors[i]["stamina_regen"] = static_cast<int>(OrgasmEngine::GetStaminaRegen(a));
                }
            }

            const bool inThread = speaker &&
                std::find(e.actors.begin(), e.actors.end(), speaker->GetFormID()) != e.actors.end();
            RE::Actor* anchor = e.actors.empty() ? nullptr : RE::TESForm::LookupByID<RE::Actor>(e.actors[0]);
            out["speaker_name"] = speaker ? Name(speaker) : "none";
            ApplySpeakerFields(out, speaker, anchor, inThread, 0.0f);
            return true;
        }

        RE::FormID ParseFormId(const json& v)
        {
            try {
                if (v.is_string())
                    return static_cast<RE::FormID>(std::stoll(v.get<std::string>()));
                if (v.is_number_integer())
                    return static_cast<RE::FormID>(v.get<std::int64_t>());
            } catch (...) {
            }
            return 0;
        }

        /// DOM thread (pushed already enriched by Handler_DOM): speaker fields only.
        void ApplyDomSpeaker(json& thread, RE::Actor* speaker)
        {
            RE::Actor* anchor = nullptr;
            bool inThread = false;
            if (auto it = thread.find("actors"); it != thread.end() && it->is_array()) {
                for (const auto& a : *it) {
                    if (!a.is_object() || !a.contains("formid"))
                        continue;
                    const auto id = ParseFormId(a["formid"]);
                    if (!id)
                        continue;
                    if (speaker && id == speaker->GetFormID())
                        inThread = true;
                    if (!anchor)
                        anchor = RE::TESForm::LookupByID<RE::Actor>(id);
                }
            }
            if (!thread.contains("location"))
                thread["location"] = "floor";
            if (!thread.contains("style"))
                thread["style"] = "normal";
            ApplySpeakerFields(thread, speaker, anchor, inThread, 1.0f);
        }

        json BuildThreadsArray(RE::Actor* speaker)
        {
            std::vector<ThreadEntry> entries;
            json dom;
            {
                std::lock_guard lock(g_threadsMutex);
                for (const auto& [sid, e] : g_threads)
                    entries.push_back(e);
                dom = g_domThreads;
            }
            json threads = json::array();
            for (const auto& e : entries) {
                json t;
                if (BuildSceneThread(e, speaker, t))
                    threads.push_back(std::move(t));
            }
            for (auto& t : dom) {
                if (!t.is_object())
                    continue;
                ApplyDomSpeaker(t, speaker);
                threads.push_back(std::move(t));
            }
            return threads;
        }

        std::string BuildThreadsJson(RE::Actor* speaker)
        {
            json out = json::object();
            out["counter"] = std::to_string(g_counter.fetch_add(1));
            out["threads"] = BuildThreadsArray(speaker);
            return SafeDump(out);
        }

        /// threads.json: 0050 / 0550 fallback when SkyrimNet cannot run decorators. Player view.
        /// Skipped when the threads are unchanged since the last write (Scene polls push every few seconds).
        void WriteThreadsFile()
        {
            auto* player = RE::PlayerCharacter::GetSingleton();
            json threads = BuildThreadsArray(player);
            const std::string body = SafeDump(threads);
            {
                std::lock_guard lock(g_threadsMutex);
                if (body == g_lastWritten)
                    return;
                g_lastWritten = body;
            }
            json out = json::object();
            out["counter"] = std::to_string(g_counter.fetch_add(1));
            out["threads"] = std::move(threads);
            std::error_code ec;
            std::filesystem::create_directories(std::filesystem::path(kThreadsPath).parent_path(), ec);
            std::ofstream f(kThreadsPath, std::ios::binary | std::ios::trunc);
            if (!f) {
                webui_log::error("could not open {} for writing", kThreadsPath);
                return;
            }
            f << SafeDump(out);
        }

        // ---- Cum ----------------------------------------------------------------------------------
        // Game-time day stamp per place (0 = none). Warm under 1 game hour, drying until
        // sexlab.cum.duration_hours; a swim (or duration 0) washes everything.
        struct CumEntry
        {
            float mouth = 0.0f;
            float pussy = 0.0f;
            float ass = 0.0f;
        };

        std::mutex g_cumMutex;
        std::unordered_map<RE::FormID, CumEntry> g_cum;

        // Mirror of StorageUtil skyrimnet_sexlab_storage_items (Main.psc Store/UnStore/HasStrippedItems):
        // decorator callbacks run off the main thread and cannot call StorageUtil.
        std::mutex g_strippedMutex;
        std::unordered_set<RE::FormID> g_stripped;

        float GameDays()
        {
            auto* cal = RE::Calendar::GetSingleton();
            return cal ? cal->GetCurrentGameTime() : 0.0f;
        }

        /// 0 = none (clears an expired stamp), 1 = warm, 2 = drying.
        int Age(float& stamp, float now, float duration, bool wash)
        {
            if (stamp <= 0.0f)
                return 0;
            const float hours = (now - stamp) * 24.0f;
            if (wash || hours >= duration || hours < 0.0f) {
                stamp = 0.0f;
                return 0;
            }
            return hours < 1.0f ? 1 : 2;
        }

        struct CumAges
        {
            int mouth = 0;
            int pussy = 0;
            int ass = 0;
            bool Any() const { return mouth || pussy || ass; }
        };

        /// Ages of the actor's places; drops the actor once nothing is left. Caller holds g_cumMutex.
        CumAges EvaluateLocked(RE::Actor* actor)
        {
            CumAges ages;
            auto it = g_cum.find(actor->GetFormID());
            if (it == g_cum.end())
                return ages;
            const float duration = SexLabNet::GetConfigFloat("sexlab.cum.duration_hours", 4.0f);
            const auto* state = actor->AsActorState();
            const bool wash = duration <= 0.0f || (state && state->IsSwimming());
            const float now = GameDays();
            ages.mouth = Age(it->second.mouth, now, duration, wash);
            ages.pussy = Age(it->second.pussy, now, duration, wash);
            ages.ass = Age(it->second.ass, now, duration, wash);
            if (!ages.Any())
                g_cum.erase(it);
            return ages;
        }

        CumAges Evaluate(RE::Actor* actor)
        {
            if (!actor)
                return {};
            std::lock_guard lock(g_cumMutex);
            return EvaluateLocked(actor);
        }

        /// "pussy", "pussy and mouth", "pussy, mouth, and ass" (pussy / mouth / ass order).
        std::string Places(bool mouth, bool pussy, bool ass)
        {
            std::vector<std::string> p;
            if (pussy)
                p.emplace_back("pussy");
            if (mouth)
                p.emplace_back("mouth");
            if (ass)
                p.emplace_back("ass");
            if (p.size() == 1)
                return p[0];
            if (p.size() == 2)
                return p[0] + " and " + p[1];
            if (p.size() == 3)
                return p[0] + ", " + p[1] + ", and " + p[2];
            return "";
        }

        /// Comma list of places that still have cum ("pussy,mouth,ass" order; "" when none).
        std::string PartsList(const CumAges& a)
        {
            std::string parts;
            auto add = [&](bool on, const char* name) {
                if (!on)
                    return;
                if (!parts.empty())
                    parts += ",";
                parts += name;
            };
            add(a.pussy > 0, "pussy");
            add(a.mouth > 0, "mouth");
            add(a.ass > 0, "ass");
            return parts;
        }

        // ---- Papyrus natives ----------------------------------------------------------------------
        void Threads_Set(RE::StaticFunctionTag*, std::int32_t sid, std::int32_t obj, std::vector<RE::Actor*> positions)
        {
            ThreadEntry e;
            e.obj = obj;
            for (auto* a : positions) {
                if (a)
                    e.actors.push_back(a->GetFormID());
            }
            RE::Actor* anchor = positions.empty() ? nullptr : positions[0];
            Scenes::Registry::Register(Scenes::Registry::Kind::SexLab, sid, e.actors);
            {
                std::lock_guard lock(g_threadsMutex);
                g_threads[sid] = std::move(e);
            }
            PrimeLos(anchor);
            WriteThreadsFile();
        }

        void Threads_Remove(RE::StaticFunctionTag*, std::int32_t sid)
        {
            Scenes::Registry::Unregister(Scenes::Registry::Kind::SexLab, sid);
            {
                std::lock_guard lock(g_threadsMutex);
                if (!g_threads.erase(sid))
                    return;
            }
            WriteThreadsFile();
        }

        void Threads_SetDom(RE::StaticFunctionTag*, RE::BSFixedString threadsJson)
        {
            json parsed = json::parse(Str(threadsJson), nullptr, false);
            if (parsed.is_discarded() || !parsed.is_array())
                parsed = json::array();
            {
                std::lock_guard lock(g_threadsMutex);
                g_domThreads = std::move(parsed);
            }
            WriteThreadsFile();
        }

        RE::BSFixedString Threads_Get(RE::StaticFunctionTag*, RE::Actor* speaker)
        {
            return BuildThreadsJson(speaker ? speaker : RE::PlayerCharacter::GetSingleton());
        }

        void RecordCum(RE::StaticFunctionTag*, RE::Actor* actor, bool onMouth, bool onPussy, bool onAss)
        {
            if (!actor || !(onMouth || onPussy || onAss))
                return;
            const float now = GameDays();
            std::lock_guard lock(g_cumMutex);
            auto& e = g_cum[actor->GetFormID()];
            if (onMouth)
                e.mouth = now;
            if (onPussy)
                e.pussy = now;
            if (onAss)
                e.ass = now;
        }

        RE::BSFixedString CumParts(RE::StaticFunctionTag*, RE::Actor* actor)
        {
            return PartsList(Evaluate(actor));
        }

        /// Clears one place (mouth|pussy|ass) or "all"; returns the places left (CumParts format).
        RE::BSFixedString CumClear(RE::StaticFunctionTag*, RE::Actor* actor, RE::BSFixedString part)
        {
            if (!actor)
                return "";
            const std::string p = Str(part);
            std::lock_guard lock(g_cumMutex);
            if (auto it = g_cum.find(actor->GetFormID()); it != g_cum.end()) {
                const bool all = p == "all";
                if (all || p == "mouth")
                    it->second.mouth = 0.0f;
                if (all || p == "pussy")
                    it->second.pussy = 0.0f;
                if (all || p == "ass")
                    it->second.ass = 0.0f;
            }
            return PartsList(EvaluateLocked(actor));
        }

        void SetStrippedItems(RE::StaticFunctionTag*, RE::Actor* actor, bool has)
        {
            if (!actor)
                return;
            std::lock_guard lock(g_strippedMutex);
            if (has)
                g_stripped.insert(actor->GetFormID());
            else
                g_stripped.erase(actor->GetFormID());
        }
    }

    // ---- Decorators -------------------------------------------------------------------------------
    std::string GetThreads(RE::Actor* speaker)
    {
        SNSL_PROF("decorator.sexlab_get_threads");
        if (!speaker)
            speaker = RE::PlayerCharacter::GetSingleton();
        std::string out = BuildThreadsJson(speaker);
        if (SexLabNet::IsVerbose())
            webui_log::debug("speaker:{} json:{}", Name(speaker), out);
        return out;
    }

    std::string Activities(RE::Actor* actor)
    {
        SNSL_PROF("decorator.sexlab_activities");
        std::string activity;
        if (actor) {
            SexLabNet::Json::Handle obj = SexLabNet::Json::kInvalidHandle;
            {
                std::lock_guard lock(g_threadsMutex);
                for (const auto& [sid, e] : g_threads) {
                    if (std::find(e.actors.begin(), e.actors.end(), actor->GetFormID()) != e.actors.end()) {
                        obj = e.obj;
                        break;
                    }
                }
            }
            if (obj != SexLabNet::Json::kInvalidHandle)
                activity = SexLabNet::Json::MapGetStr(obj, "description", "");
        }
        return SafeDump(json{ { "activity", activity } });
    }

    std::string Cum(RE::Actor* actor)
    {
        SNSL_PROF("decorator.sexlab_cum");
        if (!actor)
            return "{}";
        const auto a = Evaluate(actor);
        // warm / drying: every place; *_mouth: the only place still visible on a clothed actor.
        json out = {
            { "warm", Places(a.mouth == 1, a.pussy == 1, a.ass == 1) },
            { "drying", Places(a.mouth == 2, a.pussy == 2, a.ass == 2) },
            { "warm_mouth", a.mouth == 1 ? 1 : 0 },
            { "drying_mouth", a.mouth == 2 ? 1 : 0 },
        };
        return SafeDump(out);
    }

    bool ActorHasCum(RE::Actor* actor)
    {
        return Evaluate(actor).Any();
    }

    std::string HasCum(RE::Actor* actor)
    {
        SNSL_PROF("decorator.sexlab_has_cum");
        return ActorHasCum(actor) ? "1" : "0";
    }

    std::string CumCount(RE::Actor*)
    {
        SNSL_PROF("decorator.sexlab_cum_count");
        std::vector<RE::FormID> ids;
        {
            std::lock_guard lock(g_cumMutex);
            for (const auto& [id, e] : g_cum)
                ids.push_back(id);
        }
        int count = 0;
        for (auto id : ids) {
            auto* a = RE::TESForm::LookupByID<RE::Actor>(id);
            if (!a) {
                std::lock_guard lock(g_cumMutex);
                g_cum.erase(id);
                continue;
            }
            if (ActorHasCum(a))
                ++count;
        }
        return std::to_string(count);
    }

    std::string HasStrippedItems(RE::Actor* actor)
    {
        SNSL_PROF("decorator.sexlab_has_stripped_items");
        if (!actor)
            return "0";
        std::lock_guard lock(g_strippedMutex);
        return g_stripped.contains(actor->GetFormID()) ? "1" : "0";
    }

    void ClearOnGameLoad()
    {
        {
            std::lock_guard lock(g_threadsMutex);
            g_threads.clear();
            g_domThreads = json::array();
            g_lastWritten.clear();
        }
        std::lock_guard lock(g_losMutex);
        g_los.clear();
        g_losPending.clear();
    }

    void Save(SKSE::SerializationInterface* intfc)
    {
        std::lock_guard lock(g_cumMutex);
        if (!intfc->OpenRecord(kRecord, kRecordVersion)) {
            webui_log::error("failed to open co-save record");
            return;
        }
        intfc->WriteRecordData(static_cast<std::uint32_t>(g_cum.size()));
        for (const auto& [id, e] : g_cum) {
            intfc->WriteRecordData(id);
            intfc->WriteRecordData(e.mouth);
            intfc->WriteRecordData(e.pussy);
            intfc->WriteRecordData(e.ass);
        }
    }

    void Load(SKSE::SerializationInterface* intfc, std::uint32_t version, std::uint32_t)
    {
        std::lock_guard lock(g_cumMutex);
        g_cum.clear();
        if (version != kRecordVersion)
            return;
        std::uint32_t n = 0;
        if (!intfc->ReadRecordData(n))
            return;
        for (std::uint32_t i = 0; i < n; ++i) {
            RE::FormID oldId = 0, newId = 0;
            CumEntry e;
            if (!intfc->ReadRecordData(oldId) || !intfc->ReadRecordData(e.mouth) ||
                !intfc->ReadRecordData(e.pussy) || !intfc->ReadRecordData(e.ass))
                return;
            if (intfc->ResolveFormID(oldId, newId))
                g_cum[newId] = e;
        }
        webui_log::info("loaded cum state for {} actor(s)", g_cum.size());
    }

    void SaveStripped(SKSE::SerializationInterface* intfc)
    {
        std::lock_guard lock(g_strippedMutex);
        if (!intfc->OpenRecord(kStrippedRecord, kStrippedRecordVersion)) {
            webui_log::error("failed to open stripped-items co-save record");
            return;
        }
        intfc->WriteRecordData(static_cast<std::uint32_t>(g_stripped.size()));
        for (auto id : g_stripped)
            intfc->WriteRecordData(id);
    }

    void LoadStripped(SKSE::SerializationInterface* intfc, std::uint32_t version, std::uint32_t)
    {
        std::lock_guard lock(g_strippedMutex);
        g_stripped.clear();
        if (version != kStrippedRecordVersion)
            return;
        std::uint32_t n = 0;
        if (!intfc->ReadRecordData(n))
            return;
        for (std::uint32_t i = 0; i < n; ++i) {
            RE::FormID oldId = 0, newId = 0;
            if (!intfc->ReadRecordData(oldId))
                return;
            if (intfc->ResolveFormID(oldId, newId))
                g_stripped.insert(newId);
        }
        webui_log::info("loaded stripped items state for {} actor(s)", g_stripped.size());
    }

    void Revert()
    {
        {
            std::lock_guard lock(g_cumMutex);
            g_cum.clear();
        }
        std::lock_guard lock(g_strippedMutex);
        g_stripped.clear();
    }

    bool Register_Papyrus(RE::BSScript::IVirtualMachine* a_vm)
    {
        if (!a_vm) {
            webui_log::error("Couldn't get Papyrus Virtual Machine.");
            return false;
        }
        constexpr std::string_view s = "SkyrimNet_SexLab_Decorators";
        a_vm->RegisterFunction("Threads_Set", s, Threads_Set);
        a_vm->RegisterFunction("Threads_Remove", s, Threads_Remove);
        a_vm->RegisterFunction("Threads_SetDom", s, Threads_SetDom);
        a_vm->RegisterFunction("Threads_Get", s, Threads_Get);
        a_vm->RegisterFunction("RecordCum", s, RecordCum);
        a_vm->RegisterFunction("CumParts", s, CumParts);
        a_vm->RegisterFunction("CumClear", s, CumClear);
        a_vm->RegisterFunction("SetStrippedItems", s, SetStrippedItems);
        return true;
    }
}
