#include "SceneRegistry.h"

#include "WebUI_Log.h"

#include <algorithm>
#include <map>
#include <mutex>
#include <nlohmann/json.hpp>

namespace Scenes::Registry
{
    namespace
    {
        using Key = std::pair<Kind, int>;

        std::mutex g_mutex;
        std::map<Key, std::vector<RE::FormID>> g_scenes;

        const char* KindName(Kind kind)
        {
            return kind == Kind::SexLab ? "sexlab" : "animengine";
        }

        bool Contains(const std::vector<RE::FormID>& actors, RE::FormID id)
        {
            return std::find(actors.begin(), actors.end(), id) != actors.end();
        }
    }

    void Register(Kind kind, int id, const std::vector<RE::FormID>& actors)
    {
        std::lock_guard lock(g_mutex);
        auto [it, added] = g_scenes.insert_or_assign(Key{ kind, id }, actors);
        if (added) {
            webui_log::info("Registry: register {} {} ({} actor(s))", KindName(kind), id, actors.size());
        }
    }

    void Unregister(Kind kind, int id)
    {
        std::lock_guard lock(g_mutex);
        if (g_scenes.erase(Key{ kind, id })) {
            webui_log::info("Registry: unregister {} {}", KindName(kind), id);
        }
    }

    void ClearKind(Kind kind)
    {
        std::lock_guard lock(g_mutex);
        std::erase_if(g_scenes, [kind](const auto& e) { return e.first.first == kind; });
    }

    int SidOf(RE::Actor* actor)
    {
        if (!actor)
            return -1;
        const auto id = actor->GetFormID();
        std::lock_guard lock(g_mutex);
        for (const auto& [key, actors] : g_scenes) {
            if (key.first == Kind::SexLab && Contains(actors, id))
                return key.second;
        }
        return -1;
    }

    bool IsBusy(RE::Actor* actor)
    {
        if (!actor)
            return false;
        const auto id = actor->GetFormID();
        std::lock_guard lock(g_mutex);
        return std::any_of(g_scenes.begin(), g_scenes.end(), [id](const auto& e) { return Contains(e.second, id); });
    }

    std::string DescribeJson()
    {
        std::lock_guard lock(g_mutex);
        nlohmann::json out = nlohmann::json::array();
        for (const auto& [key, actors] : g_scenes) {
            std::vector<std::string> ids;
            for (const auto id : actors)
                ids.push_back(std::format("{:08X}", id));
            out.push_back({ { "kind", KindName(key.first) }, { "id", key.second }, { "actors", ids } });
        }
        return out.dump();
    }

    void Save(SKSE::SerializationInterface* intfc)
    {
        std::lock_guard lock(g_mutex);
        if (!intfc->OpenRecord(kRecord, kRecordVersion)) {
            webui_log::error("Registry: failed to open co-save record");
            return;
        }
        intfc->WriteRecordData(static_cast<std::uint32_t>(g_scenes.size()));
        for (const auto& [key, actors] : g_scenes) {
            intfc->WriteRecordData(static_cast<std::uint32_t>(key.first));
            intfc->WriteRecordData(static_cast<std::int32_t>(key.second));
            intfc->WriteRecordData(static_cast<std::uint32_t>(actors.size()));
            for (const auto id : actors)
                intfc->WriteRecordData(id);
        }
    }

    void Load(SKSE::SerializationInterface* intfc, std::uint32_t version, std::uint32_t)
    {
        {
            std::lock_guard lock(g_mutex);
            g_scenes.clear();
        }
        if (version != kRecordVersion) {
            webui_log::warn("Registry: co-save version {} (want {}), skipped", version, kRecordVersion);
            return;
        }
        std::uint32_t n = 0;
        if (!intfc->ReadRecordData(n))
            return;
        for (std::uint32_t i = 0; i < n; ++i) {
            std::uint32_t kind = 0, count = 0;
            std::int32_t id = 0;
            if (!intfc->ReadRecordData(kind) || !intfc->ReadRecordData(id) || !intfc->ReadRecordData(count))
                return;
            for (std::uint32_t j = 0; j < count; ++j) {
                RE::FormID actor = 0;
                if (!intfc->ReadRecordData(actor))
                    return;
            }
            webui_log::info("Registry: saved {} {} ({} actor(s)) not restored", KindName(static_cast<Kind>(kind)),
                id, count);
        }
        if (n != 0)
            webui_log::info("Registry: dropped {} scene(s) from save", n);
    }

    void Revert()
    {
        std::lock_guard lock(g_mutex);
        g_scenes.clear();
    }
}
