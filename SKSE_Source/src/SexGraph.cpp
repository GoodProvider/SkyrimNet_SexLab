#include "SexGraph.h"

#include "AnimEngine.h"
#include "AnimationDB.h"
#include "WebUI_Log.h"

#include <filesystem>
#include <fstream>
#include <mutex>
#include <optional>
#include <sstream>

namespace SexGraph
{
    namespace
    {
        struct Default
        {
            const char* key;
            bool value;
        };
        // Written to a new file; also the values for keys a readable file lacks.
        constexpr Default kDefaults[] = {
            { "enabled", false },
            { "orgasm_engine", true },
            { "approach", true },
            { "slsb_registry", false },
        };

        std::mutex g_mutex;
        // nullopt: not read yet. A null json: no file, or it did not parse.
        std::optional<nlohmann::json> g_cache;

        std::filesystem::path FilePath()
        {
            return AnimationDB::PluginDataDir() / kFileName;
        }

        nlohmann::json ReadLocked()
        {
            if (g_cache)
                return *g_cache;
            nlohmann::json j;  // null
            const auto path = FilePath();
            std::error_code ec;
            if (std::filesystem::exists(path, ec)) {
                std::ifstream in(path, std::ios::binary);
                std::stringstream ss;
                ss << in.rdbuf();
                const std::string raw = ss.str();
                // An empty file counts as {} (present, every key at its default).
                j = raw.find_first_not_of(" \t\r\n") == std::string::npos ? nlohmann::json::object()
                                                                           : nlohmann::json::parse(raw, nullptr, false);
                if (!j.is_object()) {
                    webui_log::warn("SexGraph: {} does not parse; AnimEngine stays off", path.string());
                    j = nullptr;
                }
            }
            g_cache = j;
            return j;
        }

        bool ValueLocked(const nlohmann::json& file, std::string_view key, bool def)
        {
            if (!file.is_object())
                return false;
            const auto ae = file.find("anim_engine");
            if (ae == file.end() || !ae->is_object())
                return def;
            const auto it = ae->find(std::string(key));
            if (it == ae->end())
                return def;
            if (it->is_boolean())
                return it->get<bool>();
            if (it->is_number())
                return it->get<double>() != 0;
            return def;
        }
    }

    bool Present()
    {
        std::error_code ec;
        return std::filesystem::exists(FilePath(), ec);
    }

    bool GetBool(std::string_view key, bool def)
    {
        std::lock_guard lock(g_mutex);
        return ValueLocked(ReadLocked(), key, def);
    }

    bool SetBool(std::string_view key, bool value)
    {
        std::lock_guard lock(g_mutex);
        nlohmann::json file = ReadLocked();
        if (!file.is_object())
            file = nlohmann::json::object();
        auto& ae = file["anim_engine"];
        if (!ae.is_object())
            ae = nlohmann::json::object();
        for (const auto& d : kDefaults) {
            if (!ae.contains(d.key))
                ae[d.key] = d.value;
        }
        ae[std::string(key)] = value;
        const auto path = FilePath();
        std::ofstream out(path, std::ios::binary | std::ios::trunc);
        if (!out) {
            webui_log::error("SexGraph: cannot write {}", path.string());
            return false;
        }
        out << file.dump(2) << '\n';
        out.close();
        g_cache = file;
        webui_log::info("SexGraph: anim_engine.{} = {}", key, value);
        return true;
    }

    nlohmann::json PanelJson()
    {
        nlohmann::json j;
        j["present"] = Present();
        nlohmann::json ae = nlohmann::json::object();
        {
            std::lock_guard lock(g_mutex);
            const auto file = ReadLocked();
            for (const auto& d : kDefaults)
                ae[d.key] = ValueLocked(file, d.key, d.value);
        }
        j["anim_engine"] = std::move(ae);
        j["animEngineScene"] = AnimEngine::LatestScene();
        return j;
    }

    void Reload()
    {
        std::lock_guard lock(g_mutex);
        g_cache.reset();
    }
}
