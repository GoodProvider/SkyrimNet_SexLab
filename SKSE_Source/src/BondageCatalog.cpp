#include "PCH.h"
#include "BondageCatalog.h"
#include "Config.h"
#include "DeviousDevicesNG/API.h"
#include "WebUI_Log.h"

#include <nlohmann/json.hpp>
#include <filesystem>
#include <fstream>
#include <mutex>
#include <unordered_map>
#include <unordered_set>

namespace BondageCatalog
{
    namespace
    {
        constexpr const char* kFallbackRel = "SKSE/Plugins/SkyrimNet_SexLab/bondage/group-devices.json";

        const std::pair<const char*, const char*> kKeywordGroups[] = {
            {"zad_DeviousHood", "Hood"},
            {"zad_DeviousBlindfold", "Blindfold"},
            {"zad_DeviousGagPanel", "Gag"},
            {"zad_DeviousGagLarge", "Gag"},
            {"zad_DeviousGag", "Gag"},
            {"zad_DeviousCollar", "Collar"},
            {"zad_DeviousPiercingsNipple", "Piercing Nipple"},
            {"zad_DeviousBra", "Body"},
            {"zad_DeviousHarness", "Body"},
            {"zad_DeviousCorset", "Body"},
            {"zad_DeviousArmbinderElbow", "Arms"},
            {"zad_DeviousArmbinder", "Arms"},
            {"zad_DeviousElbowTie", "Arms"},
            {"zad_DeviousYokeBB", "Arms"},
            {"zad_DeviousYoke", "Arms"},
            {"zad_DeviousCuffsFront", "Arms"},
            {"zad_DeviousArmCuffs", "Arms"},
            {"zad_DeviousBondageMittens", "Arms"},
            {"zad_DeviousGloves", "Arms"},
            {"zad_DeviousBelt", "Belt"},
            {"zad_DeviousPiercingsVaginal", "Piercing Vaginal"},
            {"zad_DeviousPlugVaginal", "Plug Vaginal"},
            {"zad_DeviousPlugAnal", "Plug Anal"},
            {"zad_DeviousPlug", "Plug Anal"},
            {"zad_DeviousAnkleShackles", "Legs"},
            {"zad_DeviousLegCuffs", "Legs"},
            {"zad_DeviousBoots", "Boots"},
            {"zad_DeviousStraitJacket", "Suit"},
            {"zad_DeviousHobbleSkirt", "Suit"},
            {"zad_DeviousPetSuit", "Suit"},
            {"zad_DeviousSuit", "Suit"},
            {"zad_DeviousHeavyBondage", "Arms"},
        };

        const char* kGroupOrder[] = {
            "Blindfold",
            "Gag",
            "Hood",
            "Collar",
            "Piercing Nipple",
            "Body",
            "Arms",
            "Belt",
            "Piercing Vaginal",
            "Plug Vaginal",
            "Plug Anal",
            "Legs",
            "Boots",
            "Suit",
        };

        std::mutex g_mutex;
        nlohmann::json g_fileGroups = nlohmann::json::array();
        nlohmann::json g_apiGroups = nlohmann::json::array();
        bool g_fileLoaded = false;
        bool g_apiLoaded = false;

        std::string Lower(std::string s)
        {
            for (auto& c : s) {
                if (c >= 'A' && c <= 'Z')
                    c = static_cast<char>(c - 'A' + 'a');
            }
            return s;
        }

        bool LooksUnlocked(const char* edid)
        {
            if (!edid || !*edid)
                return false;
            std::string s = Lower(edid);
            if (s.find("locking") != std::string::npos)
                return false;
            return s.find("unlock") != std::string::npos;
        }

        const RE::TESFile* OriginFile(const RE::TESForm* form)
        {
            if (!form)
                return nullptr;
            return form->GetFile();
        }

        uint32_t LocalId(const RE::TESForm* form, const RE::TESFile* file)
        {
            if (!form)
                return 0;
            const uint32_t id = form->GetFormID();
            if (file && file->IsLight())
                return id & 0xFFFu;
            return id & 0xFFFFFFu;
        }

        std::string FormData(RE::TESForm* form)
        {
            if (!form)
                return "";
            const auto* file = OriginFile(form);
            const char* name = file ? file->GetFilename().data() : "";
            return std::format("__formData|{}|0x{:x}", name ? name : "", LocalId(form, file));
        }

        std::string DeviceId(RE::TESForm* form)
        {
            if (!form)
                return "";
            const auto* file = OriginFile(form);
            const char* name = file ? file->GetFilename().data() : "";
            return std::format("{}:0x{:x}", name ? name : "", LocalId(form, file));
        }

        std::string FullName(RE::TESForm* form)
        {
            if (!form)
                return "";
            const char* n = form->GetName();
            return n && *n ? std::string(n) : "";
        }

        const char* GroupForArmor(RE::TESObjectARMO* inv, RE::TESObjectARMO* rendered, RE::BGSKeyword* kwd)
        {
            auto match = [](RE::TESForm* f) -> const char* {
                if (!f)
                    return nullptr;
                auto* kw = f->As<RE::BGSKeyword>();
                const char* edid = kw ? kw->GetFormEditorID() : f->GetFormEditorID();
                if (!edid || !*edid)
                    return nullptr;
                for (const auto& [key, group] : kKeywordGroups) {
                    if (_stricmp(edid, key) == 0)
                        return group;
                }
                return nullptr;
            };
            if (const char* g = match(kwd))
                return g;
            auto scan = [&](RE::TESObjectARMO* a) -> const char* {
                if (!a)
                    return nullptr;
                for (const auto& [key, group] : kKeywordGroups) {
                    if (a->HasKeywordString(key))
                        return group;
                }
                return nullptr;
            };
            if (const char* g = scan(rendered))
                return g;
            return scan(inv);
        }

        nlohmann::json DeviceObject(RE::TESObjectARMO* inv)
        {
            nlohmann::json d = nlohmann::json::object();
            const std::string name = FullName(inv);
            d["id"] = DeviceId(inv);
            d["name"] = name.empty() ? DeviceId(inv) : name;
            return d;
        }

        nlohmann::json GroupsFromMap(std::unordered_map<std::string, nlohmann::json>& byGroup)
        {
            nlohmann::json groups = nlohmann::json::array();
            for (const char* name : kGroupOrder) {
                auto it = byGroup.find(name);
                if (it == byGroup.end() || it->second.empty())
                    continue;
                nlohmann::json g = nlohmann::json::object();
                g["name"] = name;
                g["devices"] = std::move(it->second);
                groups.push_back(std::move(g));
            }
            return groups;
        }

        bool SkipQuestOrUnlocked(RE::TESObjectARMO* inv, RE::TESObjectARMO* rendered)
        {
            auto* api = DeviousDevicesAPI::g_API;
            if (!inv)
                return true;
            if (LooksUnlocked(inv->GetFormEditorID()))
                return true;
            if (inv->HasKeywordString("zad_QuestItem"))
                return true;
            if (rendered && rendered->HasKeywordString("zad_QuestItem"))
                return true;
            return api && api->GetPropertyBool(inv, "zad_QuestItem", false, 0);
        }

        nlohmann::json GroupsFromDatabase()
        {
            auto* api = DeviousDevicesAPI::g_API;
            if (!api)
                return nlohmann::json::array();

            std::unordered_map<std::string, nlohmann::json> byGroup;
            std::size_t kept = 0;
            try {
                for (const auto& [invKey, unit] : api->GetDatabase()) {
                    if (!unit.lockable)
                        continue;
                    auto* inv = unit.deviceInventory ? unit.deviceInventory : invKey;
                    auto* rendered = unit.deviceRendered;
                    if (!inv || !rendered)
                        continue;
                    if (SkipQuestOrUnlocked(inv, rendered))
                        continue;
                    const char* group = GroupForArmor(inv, rendered, unit.kwd);
                    if (!group)
                        continue;
                    byGroup[group].push_back(DeviceObject(inv));
                    ++kept;
                }
            } catch (const std::exception& e) {
                webui_log::error("BondageCatalog GetDatabase: {}", e.what());
                return nlohmann::json::array();
            } catch (...) {
                webui_log::error("BondageCatalog GetDatabase: unknown exception");
                return nlohmann::json::array();
            }
            auto groups = GroupsFromMap(byGroup);
            webui_log::info("BondageCatalog GetDatabase groups={} devices={}", groups.size(), kept);
            return groups;
        }

        nlohmann::json GroupsFromArmorScan()
        {
            auto* api = DeviousDevicesAPI::g_API;
            auto* dh = RE::TESDataHandler::GetSingleton();
            if (!api || !dh)
                return nlohmann::json::array();

            std::unordered_map<std::string, nlohmann::json> byGroup;
            std::size_t kept = 0;
            for (auto* armor : dh->GetFormArray<RE::TESObjectARMO>()) {
                if (!armor || !armor->HasKeywordString("zad_InventoryDevice"))
                    continue;
                auto* rendered = api->GetDeviceRender(armor);
                if (!rendered)
                    continue;
                if (!rendered->HasKeywordString("zad_Lockable") && !armor->HasKeywordString("zad_Lockable"))
                    continue;
                if (SkipQuestOrUnlocked(armor, rendered))
                    continue;
                auto* kwdForm = api->GetPropertyForm(armor, "zad_DeviousDevice", nullptr, 0);
                auto* kwd = kwdForm ? kwdForm->As<RE::BGSKeyword>() : nullptr;
                const char* group = GroupForArmor(armor, rendered, kwd);
                if (!group)
                    continue;
                byGroup[group].push_back(DeviceObject(armor));
                ++kept;
            }
            auto groups = GroupsFromMap(byGroup);
            webui_log::info("BondageCatalog armor-scan groups={} devices={}", groups.size(), kept);
            return groups;
        }

        nlohmann::json GroupsFromApi()
        {
            auto groups = GroupsFromDatabase();
            if (!groups.empty())
                return groups;
            return GroupsFromArmorScan();
        }

        nlohmann::json GroupsFromFile()
        {
            std::filesystem::path path = "Data";
            path /= kFallbackRel;
            std::ifstream in(path);
            if (!in) {
                webui_log::warn("BondageCatalog fallback missing {}", path.string());
                return nlohmann::json::array();
            }
            try {
                auto parsed = nlohmann::json::parse(in);
                if (parsed.is_array())
                    return parsed;
                if (parsed.is_object() && parsed.contains("groups") && parsed["groups"].is_array())
                    return parsed["groups"];
            } catch (const std::exception& e) {
                webui_log::error("BondageCatalog fallback parse: {}", e.what());
            }
            return nlohmann::json::array();
        }

        nlohmann::json DevicesOf(const nlohmann::json& g)
        {
            if (!g.is_object())
                return nlohmann::json::array();
            const nlohmann::json* d = nullptr;
            if (g.contains("devices"))
                d = &g["devices"];
            else if (g.contains("Devices"))
                d = &g["Devices"];
            if (!d)
                return nlohmann::json::array();
            if (d->is_array())
                return *d;
            if (d->is_object()) {
                nlohmann::json arr = nlohmann::json::array();
                for (auto it = d->begin(); it != d->end(); ++it)
                    arr.push_back(it.value());
                return arr;
            }
            return nlohmann::json::array();
        }

        std::string GroupNameOf(const nlohmann::json& g, std::size_t index)
        {
            if (g.is_object()) {
                if (g.contains("name") && g["name"].is_string() && !g["name"].get<std::string>().empty())
                    return g["name"].get<std::string>();
                if (g.contains("Name") && g["Name"].is_string() && !g["Name"].get<std::string>().empty())
                    return g["Name"].get<std::string>();
            }
            if (index < std::size(kGroupOrder))
                return kGroupOrder[index];
            return "group";
        }

        std::string DeviceIdOf(const nlohmann::json& d)
        {
            if (!d.is_object())
                return "";
            if (d.contains("id") && d["id"].is_string())
                return d["id"].get<std::string>();
            if (d.contains("Id") && d["Id"].is_string())
                return d["Id"].get<std::string>();
            return "";
        }

        nlohmann::json SlimDevice(const nlohmann::json& d)
        {
            nlohmann::json s = nlohmann::json::object();
            const std::string id = DeviceIdOf(d);
            s["id"] = id;
            std::string name;
            if (d.is_object()) {
                if (d.contains("name") && d["name"].is_string())
                    name = d["name"].get<std::string>();
                else if (d.contains("Name") && d["Name"].is_string())
                    name = d["Name"].get<std::string>();
            }
            s["name"] = name.empty() ? id : name;
            return s;
        }

        void ApplyEquipped(nlohmann::json& groups, const std::unordered_map<std::string, std::string>& wornById,
            const nlohmann::json& wornHint)
        {
            for (std::size_t i = 0; i < groups.size(); ++i) {
                auto& g = groups[i];
                if (!g.is_object())
                    continue;
                auto devices = DevicesOf(g);
                g["devices"] = devices;
                g["name"] = GroupNameOf(g, i);
                std::string equipped;
                const std::string gname = g["name"].get<std::string>();
                if (wornHint.is_object()) {
                    if (wornHint.contains(gname) && wornHint[gname].is_string())
                        equipped = wornHint[gname].get<std::string>();
                    else {
                        auto low = Lower(gname);
                        for (auto it = wornHint.begin(); it != wornHint.end(); ++it) {
                            if (Lower(it.key()) == low && it.value().is_string()) {
                                equipped = it.value().get<std::string>();
                                break;
                            }
                        }
                    }
                }
                if (equipped.empty()) {
                    for (const auto& d : devices) {
                        const auto id = DeviceIdOf(d);
                        if (!id.empty() && wornById.contains(Lower(id))) {
                            equipped = id;
                            break;
                        }
                    }
                }
                g["equippedId"] = equipped;
                nlohmann::json slim = nlohmann::json::array();
                for (const auto& d : devices)
                    slim.push_back(SlimDevice(d));
                g["devices"] = std::move(slim);
            }
        }
    }

    bool DllPresent()
    {
        return DeviousDevicesAPI::DllLoaded();
    }

    bool EnsureAPI()
    {
        if (DeviousDevicesAPI::g_API)
            return true;
        if (!DllPresent())
            return false;
        const bool ok = DeviousDevicesAPI::LoadAPI();
        if (!ok)
            webui_log::warn("BondageCatalog LoadAPI failed (GetAPI null or version != {})", DD_APIVERSION);
        else
            webui_log::info("BondageCatalog LoadAPI ok version={}", DeviousDevicesAPI::g_API->GetVersion());
        return ok;
    }

    nlohmann::json FileGroups()
    {
        std::lock_guard lock(g_mutex);
        if (!g_fileLoaded) {
            g_fileGroups = GroupsFromFile();
            g_fileLoaded = true;
            webui_log::info("BondageCatalog file groups={}", g_fileGroups.size());
        }
        return g_fileGroups;
    }

    nlohmann::json ApiGroups()
    {
        std::lock_guard lock(g_mutex);
        if (g_apiLoaded)
            return g_apiGroups;
        if (!EnsureAPI())
            return nlohmann::json::array();
        g_apiGroups = GroupsFromApi();
        g_apiLoaded = true;
        webui_log::info("BondageCatalog api groups={}", g_apiGroups.size());
        return g_apiGroups;
    }

    bool ApiCatalogReady()
    {
        std::lock_guard lock(g_mutex);
        return g_apiLoaded && !g_apiGroups.empty();
    }

    nlohmann::json Groups()
    {
        auto api = ApiGroups();
        if (!api.empty())
            return api;
        return FileGroups();
    }

    nlohmann::json BuildState(RE::Actor* target, const nlohmann::json& papyrusHint,
        const nlohmann::json& groupsIn, bool wornFromApi)
    {
        nlohmann::json state = nlohmann::json::object();
        state["target"] = target ? target->GetFormID() : 0;
        nlohmann::json groups = groupsIn.is_array() ? groupsIn : nlohmann::json::array();

        std::unordered_map<std::string, std::string> wornById;
        nlohmann::json wornHint = nlohmann::json::object();
        if (papyrusHint.is_object() && papyrusHint.contains("worn") && papyrusHint["worn"].is_object())
            wornHint = papyrusHint["worn"];

        if (wornFromApi && target && EnsureAPI() && DeviousDevicesAPI::g_API) {
            for (auto* rendered : DeviousDevicesAPI::g_API->GetWornDevices(target)) {
                auto* inv = DeviousDevicesAPI::g_API->GetDeviceInventory(rendered);
                if (!inv)
                    continue;
                wornById[Lower(DeviceId(inv))] = DeviceId(inv);
            }
        }

        ApplyEquipped(groups, wornById, wornHint);
        state["groups"] = std::move(groups);
        return state;
    }

    std::vector<std::string> WornAnimationTags(const std::vector<RE::Actor*>& actors)
    {
        // Worn-keyword scan only: no DeviousDevicesAPI / zadLibs, so the core never depends on DD.
        static const std::pair<const char*, const char*> kDeviousTagKeywords[] = {
            {"zad_DeviousArmbinderElbow", "armbinder"},
            {"zad_DeviousArmbinder", "armbinder"},
            {"zad_DeviousYokeBB", "yoke"},
            {"zad_DeviousYoke", "yoke"},
            {"zad_DeviousCuffsFront", "cuffs"},
        };
        static const char* kTagOrder[] = { "armbinder", "yoke", "cuffs", "bound" };

        std::vector<std::string> out;
        if (!SexLabNet::GetConfigBool("sexlab.tags.filter_by_devious_devices", true))
            return out;
        std::unordered_set<std::string> found;
        for (auto* actor : actors) {
            if (!actor)
                continue;
            auto inv = actor->GetInventory([](RE::TESBoundObject& o) { return o.IsArmor(); });
            for (const auto& [obj, data] : inv) {
                if (!data.second || !data.second->IsWorn())
                    continue;
                auto* armo = obj ? obj->As<RE::TESObjectARMO>() : nullptr;
                if (!armo)
                    continue;
                bool matched = false;
                for (const auto& [kw, tag] : kDeviousTagKeywords) {
                    if (armo->HasKeywordString(kw)) {
                        found.insert(tag);
                        matched = true;
                        break;
                    }
                }
                if (!matched && armo->HasKeywordString("zad_DeviousHeavyBondage"))
                    found.insert("bound");
            }
        }
        for (const char* tag : kTagOrder) {
            if (found.contains(tag))
                out.emplace_back(tag);
        }
        return out;
    }
}
