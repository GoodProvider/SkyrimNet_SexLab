#include "RE/Skyrim.h"
#include "SKSE/SKSE.h"
#include "WebUI_Log.h"
#include "WebUI.h"
#include "ActionCatalog.h"
#include "AnimationDB.h"
#include "BondageCatalog.h"
#include "Config.h"
#include "RE/V/VirtualMachine.h"
#include <nlohmann/json.hpp>
#include <algorithm>
#include <cmath>
#include <cstdint>
#include <string>
#include <unordered_set>
#include <vector>

// Defined in PublicAPI.h (included once from Config.cpp).
extern "C" {
extern uint64_t (*PublicFormIDToUUID)(uint32_t formId);
extern std::string (*PublicGetActorNameByUUID)(uint64_t uuid);
}

namespace PapyrusBindings_WebUI
{
    namespace
    {
        /// configureTargetMenu plus a loader so Custom/punish use C++-shipped scenes/*.json.
        /// PrismaUI cannot fetch ../../../SKSE/... from the overlay HTML.
        std::string ConfigureTargetMenuScript(const nlohmann::json& catalog)
        {
            return "configureTargetMenu(" + catalog.dump() + ");"
                   "(function(){"
                   "var S=(typeof TARGET_CATALOG!=='undefined'&&TARGET_CATALOG&&(TARGET_CATALOG.sceneSettings||TARGET_CATALOG.scenesettings))||{};"
                   "window.SCENE_SETTINGS=S;"
                   "if(typeof ssAdoptSceneSettings==='function')ssAdoptSceneSettings(S);"
                   "if(typeof ssLoadSetting!=='function'||ssLoadSetting._fromCatalog)return;"
                   "var orig=ssLoadSetting;"
                   "ssLoadSetting=async function(n){"
                   "n=String(n||'').trim();"
                   "if(!n)n='default';"
                   "var C=(typeof ssSceneSettingsCatalog==='function'&&ssSceneSettingsCatalog())||window.SCENE_SETTINGS||{};"
                   "if(C&&C[n])return C[n];"
                   "return orig.apply(this,arguments);"
                   "};"
                   "ssLoadSetting._fromCatalog=true;"
                   "})();";
        }

        std::uint32_t ParseFormIdJson(const nlohmann::json& v)
        {
            if (v.is_number()) {
                std::int64_t n = 0;
                if (v.is_number_float())
                    n = static_cast<std::int64_t>(v.get<double>());
                else
                    n = v.get<std::int64_t>();
                return static_cast<std::uint32_t>(n);
            }
            if (v.is_string()) {
                const auto s = v.get<std::string>();
                if (s.empty())
                    return 0;
                try {
                    return static_cast<std::uint32_t>(std::stoll(s, nullptr, 0));
                } catch (...) {
                    return 0;
                }
            }
            if (v.is_object()) {
                for (auto it = v.begin(); it != v.end(); ++it) {
                    std::string k = it.key();
                    for (auto& c : k) {
                        if (c >= 'A' && c <= 'Z')
                            c = static_cast<char>(c - 'A' + 'a');
                    }
                    if (k == "formid" || k == "form_id" || k == "_form_id" || k == "target")
                        return ParseFormIdJson(it.value());
                }
            }
            return 0;
        }

        std::uint32_t FormIdFromHint(const nlohmann::json& hint)
        {
            if (!hint.is_object())
                return 0;
            std::uint32_t fid = 0;
            for (auto it = hint.begin(); it != hint.end(); ++it) {
                std::string k = it.key();
                for (auto& c : k) {
                    if (c >= 'A' && c <= 'Z')
                        c = static_cast<char>(c - 'A' + 'a');
                }
                if (k == "target" || k == "formid" || k == "form_id" || k == "_form_id") {
                    fid = ParseFormIdJson(it.value());
                    if (fid)
                        return fid;
                }
            }
            return 0;
        }

        void SendBondageChunks(RE::Actor* target, const nlohmann::json& hint,
            const nlohmann::json& groupsIn, bool wornFromApi, const char* source)
        {
            auto state = BondageCatalog::BuildState(target, hint, groupsIn, wornFromApi);
            nlohmann::json groups = nlohmann::json::array();
            if (state.contains("groups") && state["groups"].is_array())
                groups = state["groups"];

            nlohmann::json header = nlohmann::json::object();
            if (state.contains("target"))
                header["target"] = state["target"];
            else
                header["target"] = 0;
            header["source"] = source ? source : "";
            nlohmann::json headerGroups = nlohmann::json::array();
            std::size_t device_n = 0;
            for (const auto& g : groups) {
                nlohmann::json hg = nlohmann::json::object();
                if (g.is_object() && g.contains("name"))
                    hg["name"] = g["name"];
                else
                    hg["name"] = "";
                if (g.is_object() && g.contains("equippedId"))
                    hg["equippedId"] = g["equippedId"];
                else
                    hg["equippedId"] = "";
                hg["devices"] = nlohmann::json::array();
                headerGroups.push_back(std::move(hg));
                if (g.is_object() && g.contains("devices") && g["devices"].is_array())
                    device_n += g["devices"].size();
            }
            header["groups"] = std::move(headerGroups);
            const auto headerDump = header.dump();
            const auto tid = target ? target->GetFormID() : 0u;
            webui_log::info("Bondage_Configure {} target={:08X} groups={} devices={} bytes={}", source ? source : "",
                tid, header["groups"].size(), device_n, headerDump.size());
            WebUI_Invoke(std::string("bondageConfigure(") + headerDump + ");");

            for (std::size_t i = 0; i < groups.size(); ++i) {
                const auto& g = groups[i];
                nlohmann::json chunk = nlohmann::json::object();
                chunk["index"] = i;
                chunk["devices"] = (g.is_object() && g.contains("devices") && g["devices"].is_array())
                    ? g["devices"]
                    : nlohmann::json::array();
                const auto dumped = chunk.dump();
                webui_log::info("Bondage_Configure {} chunk {}/{} devices={} bytes={}", source ? source : "",
                    i + 1, groups.size(), chunk["devices"].size(), dumped.size());
                WebUI_Invoke(std::string("bondageConfigureDevices(") + dumped + ");");
            }
        }
    }
    RE::Actor* Target_Current = nullptr;
    std::string FocusKind;
    std::int32_t YesNo_Creator_Sid = -1;
    bool EditTagsPlayer = true;
    bool EditTagsNonPlayer = false;
    bool SceneCreatorOpenedForPending = false;
    bool TargetMenuSessionActive = false;
    bool SkipSceneCreatorOnce = false;

    void ClearSceneCreatorPending()
    {
        SceneCreatorOpenedForPending = false;
    }

    void ClearTargetMenuSession()
    {
        TargetMenuSessionActive = false;
        Target_Current = nullptr;
        FocusKind.clear();
    }

    bool ConsumeSkipSceneCreator(RE::StaticFunctionTag*)
    {
        const bool skip = SkipSceneCreatorOnce;
        SkipSceneCreatorOnce = false;
        return skip;
    }

    static AnimationDB::FilterSpec ParseFilterJson(const char* json)
    {
        AnimationDB::FilterSpec spec;
        if (!json || !json[0])
            return spec;
        try {
            auto j = nlohmann::json::parse(json);
            if (j.contains("_actor_count") && j["_actor_count"].is_number())
                spec.actor_count = j["_actor_count"].get<int>();
            auto read_tags = [&](const char* k, std::vector<std::string>& out) {
                if (j.contains(k) && j[k].is_array()) {
                    for (const auto& el : j[k]) {
                        if (el.is_string())
                            out.push_back(AnimationDB::ToLower(el.get<std::string>()));
                    }
                }
            };
            read_tags("_must_tags", spec.must_tags);
            read_tags("_suppress_tags", spec.suppress_tags);
            if (j.contains("_require_all") && j["_require_all"].is_boolean())
                spec.require_all = j["_require_all"].get<bool>();
            else if (!spec.must_tags.empty())
                spec.require_all = true;
            if (j.contains("_creature") && j["_creature"].is_string()) {
                auto c = AnimationDB::ToLower(j["_creature"].get<std::string>());
                if (c == "require")
                    spec.creature = 1;
                else if (c == "exclude")
                    spec.creature = 2;
            }
            if (j.contains("_enabled_only") && j["_enabled_only"].is_boolean())
                spec.enabled_only = j["_enabled_only"].get<bool>();
            if (j.contains("_position_match") && j["_position_match"].is_boolean())
                spec.position_match = j["_position_match"].get<bool>();
            if (j.contains("_pos_genders") && j["_pos_genders"].is_array()) {
                for (const auto& el : j["_pos_genders"]) {
                    if (el.is_number_integer())
                        spec.pos_genders.push_back(el.get<int>());
                }
            }
            if (j.contains("_pos_race_keys") && j["_pos_race_keys"].is_array()) {
                for (const auto& el : j["_pos_race_keys"]) {
                    if (el.is_string())
                        spec.pos_race_keys.push_back(AnimationDB::ToLower(el.get<std::string>()));
                }
            }
            if (j.contains("_has_description") || j.contains("has_description"))
                spec.has_description = AnimationDB::ParseHasDescriptionMode(j);
            if (j.contains("_gender_match") && j["_gender_match"].is_boolean())
                spec.gender_match = j["_gender_match"].get<bool>();
            if (j.contains("_males") && j["_males"].is_number_integer())
                spec.males = j["_males"].get<int>();
            if (j.contains("_females") && j["_females"].is_number_integer())
                spec.females = j["_females"].get<int>();
            if (j.contains("_male_creatures") && j["_male_creatures"].is_number_integer())
                spec.male_creatures = j["_male_creatures"].get<int>();
            if (j.contains("_female_creatures") && j["_female_creatures"].is_number_integer())
                spec.female_creatures = j["_female_creatures"].get<int>();
        } catch (...) {
            webui_log::warn("ParseFilterJson failed");
        }
        return spec;
    }

    static nlohmann::json AnimRowToJson(const AnimationDB::AnimRow& row)
    {
        nlohmann::json j;
        j["_registry"] = row.registry;
        j["_name"] = row.name;
        j["_enabled"] = row.enabled;
        j["_position_count"] = row.position_count;
        j["_stage_count"] = row.stage_count;
        j["_tags"] = row.tags;
        j["_pos_genders"] = row.pos_genders;
        j["_pos_no_orgasm"] = row.pos_no_orgasm;
        j["_pos_speaking_modifiers"] = row.pos_speaking_modifiers;
        j["_clothed"] = row.pos_clothed;
        j["_stage_has_description"] = row.stage_has_description;
        nlohmann::json sd = nlohmann::json::object();
        for (const auto& [k, v] : row.stage_descriptions)
            sd[std::to_string(k)] = v;
        j["_stage_descriptions"] = sd;
        nlohmann::json ss = nlohmann::json::object();
        for (const auto& [k, v] : row.stage_speaking)
            ss[std::to_string(k)] = v;
        j["_stage_speaking"] = ss;
        nlohmann::json sc = nlohmann::json::object();
        for (const auto& [k, v] : row.stage_clothed)
            sc[std::to_string(k)] = v;
        j["_stage_clothed"] = sc;
        nlohmann::json st = nlohmann::json::object();
        for (const auto& [k, v] : row.stage_tags)
            st[std::to_string(k)] = v;
        j["_stage_tags"] = st;
        j["_transitions"] = row.transitions.is_object() ? row.transitions : nlohmann::json::object();
        j["_file_tags"] = row.file_tags;
        if (!row.creator.empty())
            j["_creator"] = row.creator;
        return j;
    }

    static void InvokeAnimDbQueryResult(const char* request_id, const nlohmann::json& payload)
    {
        nlohmann::json out = payload;
        out["_request_id"] = request_id ? request_id : "";
        WebUI_Invoke("animDbQueryResult(" + out.dump() + ");");
    }

    void WebUI_HideAllPanels(RE::StaticFunctionTag*)
    {
        if (!TargetMenuSessionActive)
            WebUI_Invoke("hidePanel('target_menu_panel');");
        ActionCatalog::ClearMainPanelSelection();
        WebUI_Invoke("hidePanel('sex_menu_panel');");
        WebUI_Invoke("hidePanel('yesno_panel');");
        WebUI_Invoke("hidePanel('scene_creator_panel');");
        WebUI_Invoke("hidePanel('description_editor_panel');");
        WebUI_Invoke("hidePanel('settings_panel');");
        WebUI_Invoke("hidePanel('log_panel');");
    }

    void WebUI_CloseOverlay(RE::StaticFunctionTag*)
    {
        ClearTargetMenuSession();
        ActionCatalog::ClearMainPanelSelection();
        WebUI_Invoke("hidePanel('control_panel');");
        WebUI_Invoke("hidePanel('target_menu_panel');");
        WebUI_Invoke("hidePanel('sex_menu_panel');");
        WebUI_Invoke("hidePanel('yesno_panel');");
        WebUI_Invoke("hidePanel('scene_creator_panel');");
        WebUI_Invoke("hidePanel('description_editor_panel');");
        WebUI_Invoke("hidePanel('settings_panel');");
        WebUI_Invoke("hidePanel('log_panel');");
        WebUI_Visibility_Hide();
    }

    /// Escapes backslash and single quote so actor names are safe inside JS string literals.
    static std::string EscapeJsString(std::string_view s)
    {
        std::string out;
        out.reserve(s.size() + 8);
        for (char c : s) {
            if (c == '\\' || c == '\'')
                out.push_back('\\');
            out.push_back(c);
        }
        return out;
    }

    static RE::TESQuest* FindMainQuest()
    {
        RE::TESQuest* quest = RE::TESForm::LookupByEditorID<RE::TESQuest>("SkyrimNet_SexLab");
        if (!quest) {
            quest = RE::TESDataHandler::GetSingleton()
                ->LookupForm<RE::TESQuest>(0x800, "SkyrimNet_SexLab.esp");
        }
        return quest;
    }

    void DispatchAnimationMenuExportState(RE::TESForm* thread, RE::TESForm* sl_scene);

    /// Opens the target menu for the given actor and focuses the PrismaUI view.
    /// Overlay already visible → hide (hotkey toggle), any focus actor.
    /// Returns false when the overlay cannot show (no DomReady / invalid view).
    bool Target_Menu_Open(RE::StaticFunctionTag*, RE::Actor* Target_Input, bool hasStrippedItems,
        bool editTagsPlayer, bool editTagsNonPlayer)
    {
        if (!Target_Input) {
            webui_log::warn("Target_Menu_Open called with null Actor.");
            return false;
        }

        if (!WebUI_IsReady()) {
            webui_log::critical(
                "Target_Menu_Open: overlay not ready (missing PrismaUI/views/SkyrimNet_SexLab/index.html?).");
            return false;
        }

        EditTagsPlayer = editTagsPlayer;
        EditTagsNonPlayer = editTagsNonPlayer;

        if (!WebUI_IsHidden()) {
            webui_log::info("Target_Menu_Open: overlay visible — hide");
            WebUI_Visibility_Hide();
            return true;
        }

        if (Target_Current == Target_Input) {
            // Rebuild catalog so eligibilityRules re-evaluate against live focus state.
            if (!ActionCatalog::IsLoaded())
                ActionCatalog::Load();
            auto catalog = ActionCatalog::BuildUICatalog(hasStrippedItems);
            WebUI_Invoke(ConfigureTargetMenuScript(catalog));
            WebUI_Invoke("configureControlPanel(" + ActionCatalog::BuildMainPanelsCatalog().dump() + ");");
            WebUI_Invoke("showPanel('target_menu_panel');");
            WebUI_Visibility_Show();
            return true;
        }

        Reset_To_Default();
        Target_Current = Target_Input;
        TargetMenuSessionActive = true;

        if (!ActionCatalog::IsLoaded())
            ActionCatalog::Load();

        const auto targetFormId = Target_Current->GetFormID();
        uint64_t uuid = (PublicFormIDToUUID) ? PublicFormIDToUUID(targetFormId) : 0;
        std::string skyrimNetName = (uuid && SexLabNet::CrossDllStdStringSafe() && PublicGetActorNameByUUID)
            ? PublicGetActorNameByUUID(uuid)
            : "";
        const char* targetName = !skyrimNetName.empty() ? skyrimNetName.c_str() : Target_Current->GetName();
        const char* name = (targetName && targetName[0]) ? targetName : "Unknown";

        webui_log::info(
            "Target_Menu_Open triggered. Target: {} hasStrippedItems={} editTagsPlayer={} editTagsNonPlayer={}",
            name,
            hasStrippedItems,
            editTagsPlayer,
            editTagsNonPlayer);

        auto catalog = ActionCatalog::BuildUICatalog(hasStrippedItems);
        WebUI_Invoke(ConfigureTargetMenuScript(catalog));
        WebUI_Invoke("configureControlPanel(" + ActionCatalog::BuildMainPanelsCatalog().dump() + ");");
        const std::string uuidStr =
            uuid ? std::to_string(uuid) : std::to_string(static_cast<unsigned>(targetFormId));
        WebUI_Invoke(std::format("setTargetActor('{}', '{}', {});", uuidStr, EscapeJsString(name),
            static_cast<unsigned>(targetFormId)));

        WebUI_Invoke("showPanel('target_menu_panel');");
        WebUI_Visibility_Show();
        return true;
    }

    /// Re-resolve actionSwitch while the target menu stays open on Target_Current.
    void Target_Menu_Refresh(RE::StaticFunctionTag*, bool hasStrippedItems)
    {
        if (!Target_Current && FocusKind.empty()) {
            // LLM / non-WebUI Outfit_* calls refresh harmlessly when menu is closed.
            return;
        }
        if (!ActionCatalog::IsLoaded())
            ActionCatalog::Load();

        webui_log::info("Target_Menu_Refresh hasStrippedItems={}", hasStrippedItems);
        auto catalog = ActionCatalog::BuildUICatalog(hasStrippedItems);
        WebUI_Invoke(ConfigureTargetMenuScript(catalog));
    }

    /// Resets the overlay and shows the sex_menu_panel for an active sex thread.
    void Sex_Menu_Open(RE::StaticFunctionTag*, RE::TESForm* thread, bool has_player)
    {
        webui_log::info("Sex_Menu_Open triggered. has_player={}", has_player);
        Reset_To_Default();
        WebUI_Invoke("showPanel('sex_menu_panel');");
        WebUI_Visibility_Show();
    }

    void YesNo_Open(RE::StaticFunctionTag*, RE::BSFixedString question, std::int32_t creator_sid)
    {
        YesNo_Creator_Sid = creator_sid;
        webui_log::info("YesNo_Open creator_sid={}", creator_sid);
        WebUI_HideAllPanels(nullptr);
        nlohmann::json cfg;
        cfg["_question"] = question.c_str() ? question.c_str() : "";
        cfg["_creator_sid"] = creator_sid;
        WebUI_Invoke("configureYesNo(" + cfg.dump() + ");");
        WebUI_Invoke("showPanel('yesno_panel');");
        WebUI_Visibility_Show();
    }

    void SceneCreator_Open(RE::StaticFunctionTag*, RE::BSFixedString state_json)
    {
        webui_log::info("SceneCreator_Open");
        WebUI_HideAllPanels(nullptr);
        const char* raw = state_json.c_str() ? state_json.c_str() : "{}";
        std::string dumped = "{}";
        try {
            auto parsed = nlohmann::json::parse(raw);
            dumped = parsed.dump();
            webui_log::info("SceneCreator_Open state bytes={}", dumped.size());
        } catch (const std::exception& e) {
            webui_log::error("SceneCreator_Open: bad state_json ({}); using {{}}", e.what());
        } catch (...) {
            webui_log::error("SceneCreator_Open: bad state_json; using {{}}");
        }
        SceneCreatorOpenedForPending = true;
        WebUI_Invoke(std::string("configureSceneCreator(") + dumped + ");");
        WebUI_Invoke("showPanel('scene_creator_panel');");
        WebUI_Visibility_Show();
    }

    void SceneCreator_Configure(RE::StaticFunctionTag*, RE::BSFixedString state_json)
    {
        const char* raw = state_json.c_str() ? state_json.c_str() : "{}";
        std::string dumped = "{}";
        try {
            dumped = nlohmann::json::parse(raw).dump();
        } catch (const std::exception& e) {
            webui_log::error("SceneCreator_Configure: bad state_json ({}); using {{}}", e.what());
        } catch (...) {
            webui_log::error("SceneCreator_Configure: bad state_json; using {{}}");
        }
        WebUI_Invoke(std::string("configureSceneCreator(") + dumped + ");");
    }

    void Bondage_Configure(RE::StaticFunctionTag*, RE::BSFixedString state_json)
    {
        const char* raw = state_json.c_str() ? state_json.c_str() : "{}";
        nlohmann::json hint = nlohmann::json::object();
        try {
            hint = nlohmann::json::parse(raw);
        } catch (const std::exception& e) {
            webui_log::error("Bondage_Configure: bad state_json ({}); using {{}}", e.what());
            hint = nlohmann::json::object();
        } catch (...) {
            webui_log::error("Bondage_Configure: bad state_json; using {{}}");
            hint = nlohmann::json::object();
        }

        RE::Actor* target = nullptr;
        const std::uint32_t fid = FormIdFromHint(hint);
        if (fid) {
            if (auto* form = RE::TESForm::LookupByID(fid))
                target = form->As<RE::Actor>();
        }
        webui_log::info("Bondage_Configure hint target={:08X} actor={} json={}", fid, target ? "ok" : "null",
            hint.dump());

        if (BondageCatalog::ApiCatalogReady()) {
            SendBondageChunks(target, hint, BondageCatalog::ApiGroups(), true, "api");
            return;
        }

        SendBondageChunks(target, hint, BondageCatalog::FileGroups(), false, "file");
        auto api = BondageCatalog::ApiGroups();
        if (!api.empty())
            SendBondageChunks(target, hint, api, true, "api");
    }

    void ActorAnimMeta_Result(RE::StaticFunctionTag*, RE::BSFixedString json)
    {
        const char* raw = json.c_str() ? json.c_str() : "{}";
        std::string dumped = "{}";
        try {
            dumped = nlohmann::json::parse(raw).dump();
        } catch (...) {
            webui_log::warn("ActorAnimMeta_Result: bad json");
        }
        WebUI_Invoke(std::string("actorAnimMetaResult(") + dumped + ");");
    }

    void WebUI_SetHotkey(RE::StaticFunctionTag*, std::int32_t dxScanCode, bool enabled)
    {
        webui_log::info("WebUI_SetHotkey dx={:#x} enabled={}", static_cast<uint32_t>(dxScanCode), enabled);
        WebUI_SetMenuHotkey(static_cast<uint32_t>(dxScanCode), enabled);
    }

    void WebUI_SetLastRebuildTimestamp(RE::StaticFunctionTag*, RE::BSFixedString timestamp)
    {
        const char* ts = timestamp.c_str();
        SexLabNet::SetLastRebuildTimestamp(ts ? ts : "");
        SexLabNet::InvokeConfigureSettingsPanel();
    }

    void Animation_Menu_Open(RE::StaticFunctionTag*, RE::TESForm* thread, RE::TESForm* sl_scene)
    {
        if (!thread || !sl_scene) {
            webui_log::warn("Animation_Menu_Open: null thread or scene");
            return;
        }
        webui_log::info("Animation_Menu_Open");
        ClearTargetMenuSession();
        WebUI_HideAllPanels(nullptr);
        DispatchAnimationMenuExportState(thread, sl_scene);
    }

    void Animation_Menu_Show(RE::StaticFunctionTag*, RE::BSFixedString state_json)
    {
        const char* raw = state_json.c_str() ? state_json.c_str() : "{}";
        std::string dumped = "{}";
        try {
            dumped = nlohmann::json::parse(raw).dump();
        } catch (...) {
            webui_log::warn("Animation_Menu_Show: bad state_json");
        }
        WebUI_Invoke(std::string("configureAnimationMenu(") + dumped + ");");
        WebUI_Invoke("showPanel('description_editor_panel');");
        WebUI_Visibility_Show();
    }

    void Animation_Menu_Configure(RE::StaticFunctionTag*, RE::BSFixedString state_json)
    {
        const char* raw = state_json.c_str() ? state_json.c_str() : "{}";
        std::string dumped = "{}";
        try {
            dumped = nlohmann::json::parse(raw).dump();
        } catch (...) {
            webui_log::warn("Animation_Menu_Configure: bad state_json");
        }
        WebUI_Invoke(std::string("configureAnimationMenu(") + dumped + ");");
    }

    void SceneConnections_Show(RE::StaticFunctionTag*, RE::BSFixedString state_json)
    {
        const char* raw = state_json.c_str() ? state_json.c_str() : "{}";
        std::string dumped = "{}";
        try {
            dumped = nlohmann::json::parse(raw).dump();
        } catch (...) {
            webui_log::warn("SceneConnections_Show: bad state_json");
        }
        WebUI_Invoke(std::string("configureSceneConnections(") + dumped + ");");
    }

    void SceneInfos_Seed(RE::StaticFunctionTag*, RE::BSFixedString state_json)
    {
        const char* raw = state_json.c_str() ? state_json.c_str() : "{}";
        std::string dumped = "{}";
        try {
            dumped = nlohmann::json::parse(raw).dump();
        } catch (...) {
            webui_log::warn("SceneInfos_Seed: bad state_json");
        }
        WebUI_Invoke(std::string("seedSceneInfos(") + dumped + ");");
    }

    /// Formats [script.func] msg, logs it through SKSE, and returns the same string to Papyrus.
    RE::BSFixedString TraceLog(RE::StaticFunctionTag*, RE::BSFixedString script_name,
        RE::BSFixedString func, RE::BSFixedString msg)
    {
        const char* script = script_name.c_str() ? script_name.c_str() : "";
        const char* fn = func.c_str() ? func.c_str() : "";
        const char* body = msg.c_str() ? msg.c_str() : "";
        std::string formatted = std::format("[{}.{}] {}", script, fn, body);
        SKSE::log::info("{}", formatted);
        return RE::BSFixedString(formatted);
    }

    namespace
    {
        constexpr float kDefaultNearbyRadius = 1600.f;
        float g_nearbyRadius = kDefaultNearbyRadius;

        constexpr float kAllowedRadii[] = { 1600.f, 2400.f, 3200.f, 4000.f, 4800.f };

        RE::TESFaction* ResolveSexLabAnimatingFaction()
        {
            static RE::TESFaction* cached = nullptr;
            static bool resolved = false;
            if (!resolved) {
                resolved = true;
                cached = RE::TESDataHandler::GetSingleton()->LookupForm<RE::TESFaction>(0xE50F, "SexLab.esm");
            }
            return cached;
        }

        RE::TESFaction* ResolveOstimActorCountFaction()
        {
            static RE::TESFaction* cached = nullptr;
            static bool resolved = false;
            if (!resolved) {
                resolved = true;
                auto* dh = RE::TESDataHandler::GetSingleton();
                if (dh && dh->LookupModByName("Ostim.esp"))
                    cached = dh->LookupForm<RE::TESFaction>(0xECA, "Ostim.esp");
            }
            return cached;
        }

        /// 0 male, 1 female — SexLab human mapping. Papyrus GetGender overwrites (creatures 2/3).
        int ActorSex(RE::Actor* actor)
        {
            if (!actor)
                return 0;
            if (auto* base = actor->GetActorBase())
                return static_cast<int>(base->GetSex());
            return 0;
        }

        std::string ActorDisplayNameLocal(RE::Actor* actor)
        {
            if (!actor)
                return "Unknown";
            uint64_t uuid = PublicFormIDToUUID ? PublicFormIDToUUID(actor->GetFormID()) : 0;
            if (uuid && SexLabNet::CrossDllStdStringSafe() && PublicGetActorNameByUUID) {
                std::string n = PublicGetActorNameByUUID(uuid);
                if (!n.empty())
                    return n;
            }
            const char* dn = actor->GetDisplayFullName();
            if (dn && dn[0])
                return dn;
            const char* n = actor->GetName();
            return (n && n[0]) ? n : "Unknown";
        }

        struct NearbyClassify {
            std::string status;  // sexlab | ok | reason (<=5)
            bool selectable = false;
            int sortRank = 2;  // 0 sexlab, 1 ok, 2 ineligible
        };

        NearbyClassify ClassifyNearbyActor(RE::Actor* actor)
        {
            NearbyClassify out;
            out.status = "gone";
            out.selectable = false;
            out.sortRank = 2;
            if (!actor || actor->IsDeleted())
                return out;
            if (actor->IsChild()) {
                out.status = "child";
                return out;
            }
            if (actor->IsDead()) {
                out.status = "dead";
                return out;
            }
            if (actor->IsInCombat()) {
                out.status = "cmbt";
                return out;
            }
            if (auto* ostim = ResolveOstimActorCountFaction()) {
                if (actor->IsInFaction(ostim)) {
                    out.status = "ostim";
                    return out;
                }
            }
            if (auto* anim = ResolveSexLabAnimatingFaction()) {
                if (actor->IsInFaction(anim)) {
                    out.status = "sexlab";
                    out.selectable = true;
                    out.sortRank = 0;
                    return out;
                }
            }
            if (!actor->Is3DLoaded()) {
                out.status = "load";
                return out;
            }
            out.status = "ok";
            out.selectable = true;
            out.sortRank = 1;
            return out;
        }

        std::string CropActorLabelName(const std::string& name, std::size_t maxLen = 10)
        {
            if (name.size() <= maxLen)
                return name;
            return name.substr(0, maxLen);
        }

        std::string MakeNearbyLabel(const std::string& name, const NearbyClassify& cls)
        {
            const std::string cropped = CropActorLabelName(name);
            if (cls.status == "ok")
                return cropped;
            std::string reason = cls.status;
            if (reason.size() > 5)
                reason = reason.substr(0, 5);
            return cropped + " (" + reason + ")";
        }

        bool IsSexLabAnimatingActor(RE::Actor* actor)
        {
            if (!actor)
                return false;
            if (auto* anim = ResolveSexLabAnimatingFaction())
                return actor->IsInFaction(anim);
            return false;
        }

        void PushNearbyJsonEntry(nlohmann::json& nearby, RE::Actor* actor, RE::Actor* distAnchor, bool isPlayer)
        {
            if (!actor)
                return;
            const auto formId = actor->GetFormID();
            uint64_t uuid = PublicFormIDToUUID ? PublicFormIDToUUID(formId) : 0;
            const std::string uuidStr =
                uuid ? std::to_string(uuid) : std::to_string(static_cast<unsigned>(formId));

            float dist = 0.f;
            if (distAnchor)
                dist = actor->GetPosition().GetDistance(distAnchor->GetPosition());

            const std::string name = ActorDisplayNameLocal(actor);
            const NearbyClassify cls = ClassifyNearbyActor(actor);

            nearby.push_back({
                { "name", name },
                { "label", MakeNearbyLabel(name, cls) },
                { "uuid", uuidStr },
                { "formId", static_cast<std::uint32_t>(formId) },
                { "dist", dist },
                { "status", cls.status },
                { "selectable", cls.selectable },
                { "sortRank", cls.sortRank },
                { "isPlayer", isPlayer },
                { "gender", ActorSex(actor) }
            });
        }

        class BoolVmCallback : public RE::BSScript::IStackCallbackFunctor
        {
        public:
            void operator()(RE::BSScript::Variable a_result) override
            {
                if (a_result.IsBool())
                    value = a_result.GetBool();
                done = true;
            }
            void SetObject(const RE::BSTSmartPointer<RE::BSScript::Object>&) override {}

            bool value = false;
            bool done = false;
        };

        class ActorVmCallback : public RE::BSScript::IStackCallbackFunctor
        {
        public:
            void operator()(RE::BSScript::Variable a_result) override
            {
                if (a_result.IsObject() && !a_result.IsNoneObject())
                    actor = a_result.Unpack<RE::Actor*>();
                done = true;
            }
            void SetObject(const RE::BSTSmartPointer<RE::BSScript::Object>&) override {}

            RE::Actor* actor = nullptr;
            bool done = false;
        };

        bool PumpVm(RE::BSScript::Internal::VirtualMachine* vm, bool& done)
        {
            if (!vm)
                return false;
            for (int i = 0; i < 64 && !done; ++i)
                vm->Update(0.0f);
            return done;
        }

        bool FactionIsLeashed(RE::Actor* actor)
        {
            auto* dh = RE::TESDataHandler::GetSingleton();
            if (!dh || !actor)
                return false;
            if (!dh->LookupModByName("Leash.esm"))
                return false;
            auto* fac = dh->LookupForm<RE::TESFaction>(0xD6A, "Leash.esm");
            return fac && actor->IsInFaction(fac);
        }

        bool NativeIsLeashed(RE::Actor* actor, bool& nativeOk)
        {
            nativeOk = false;
            auto* vm = RE::BSScript::Internal::VirtualMachine::GetSingleton();
            if (!vm || !actor)
                return false;
            auto cbPtr = RE::BSTSmartPointer<RE::BSScript::IStackCallbackFunctor>{ new BoolVmCallback() };
            auto* cb = static_cast<BoolVmCallback*>(cbPtr.get());
            auto* args = RE::MakeFunctionArguments(static_cast<RE::Actor*>(actor));
            if (!vm->DispatchStaticCall(
                    RE::BSFixedString("LeashFramework"), RE::BSFixedString("IsLeashed"), args, cbPtr)) {
                return false;
            }
            if (!PumpVm(vm, cb->done))
                return false;
            nativeOk = true;
            return cb->value;
        }

        RE::Actor* NativeGetLeashHolder(RE::Actor* actor)
        {
            auto* vm = RE::BSScript::Internal::VirtualMachine::GetSingleton();
            if (!vm || !actor)
                return nullptr;
            auto cbPtr = RE::BSTSmartPointer<RE::BSScript::IStackCallbackFunctor>{ new ActorVmCallback() };
            auto* cb = static_cast<ActorVmCallback*>(cbPtr.get());
            auto* args = RE::MakeFunctionArguments(static_cast<RE::Actor*>(actor));
            if (!vm->DispatchStaticCall(
                    RE::BSFixedString("LeashFramework"),
                    RE::BSFixedString("GetLeashHolder"),
                    args,
                    cbPtr)) {
                return nullptr;
            }
            PumpVm(vm, cb->done);
            return cb->actor;
        }
    }

    bool SetNearbyRadius(float radius)
    {
        for (float allowed : kAllowedRadii) {
            if (std::fabs(radius - allowed) < 0.5f) {
                g_nearbyRadius = allowed;
                return true;
            }
        }
        return false;
    }

    float GetNearbyRadius()
    {
        return g_nearbyRadius;
    }

    /// Soft session checks for the nearby scan. StorageUtil lock + SexLab IsValidActor applied in Papyrus.
    bool IsAvailableActor(RE::Actor* actor)
    {
        if (!actor || actor->IsDeleted())
            return false;
        if (!actor->Is3DLoaded())
            return false;
        if (actor->IsDead())
            return false;
        if (actor->IsInCombat())
            return false;
        if (auto* anim = ResolveSexLabAnimatingFaction()) {
            if (actor->IsInFaction(anim))
                return false;
        }
        if (auto* ostim = ResolveOstimActorCountFaction()) {
            if (actor->IsInFaction(ostim))
                return false;
        }
        return true;
    }

    void SetNearbyActorsJson(RE::StaticFunctionTag*, RE::BSFixedString json)
    {
        const char* raw = json.c_str() ? json.c_str() : "[]";
        try {
            auto arr = nlohmann::json::parse(raw);
            if (!arr.is_array()) {
                webui_log::warn("SetNearbyActorsJson: not an array — keeping prior nearby list");
                return;
            }
            if (arr.empty()) {
                // Non-destructive: Papyrus tighten found nobody; keep C++ soft sync list.
                webui_log::warn("SetNearbyActorsJson: empty tighten — keeping prior nearby list");
                return;
            }
            auto* player = RE::PlayerCharacter::GetSingleton();
            nlohmann::json nearby = nlohmann::json::array();
            for (auto& item : arr) {
                if (!item.is_object())
                    continue;
                uint32_t formId = 0;
                if (item.contains("formId") && item["formId"].is_number())
                    formId = item["formId"].get<uint32_t>();
                else if (item.contains("_form_id") && item["_form_id"].is_number())
                    formId = item["_form_id"].get<uint32_t>();
                auto* ak = formId ? RE::TESForm::LookupByID<RE::Actor>(formId) : nullptr;
                if (!ak)
                    continue;
                const bool isPlayer = player && ak == player;
                PushNearbyJsonEntry(nearby, ak, player, isPlayer);
            }
            if (nearby.empty()) {
                webui_log::warn("SetNearbyActorsJson: no resolvable actors — keeping prior nearby list");
                return;
            }
            std::sort(nearby.begin(), nearby.end(), [](const nlohmann::json& a, const nlohmann::json& b) {
                const bool ap = a.value("isPlayer", false);
                const bool bp = b.value("isPlayer", false);
                if (ap != bp)
                    return ap && !bp;
                const int ar = a.value("sortRank", 2);
                const int br = b.value("sortRank", 2);
                if (ar != br)
                    return ar < br;
                return a.value("dist", 0.f) < b.value("dist", 0.f);
            });
            webui_log::info("SetNearbyActorsJson: tightened count={}", nearby.size());
            WebUI_Invoke("setNearbyActors(" + nearby.dump() + ");");
        } catch (...) {
            webui_log::warn("SetNearbyActorsJson: bad JSON — keeping prior nearby list");
        }
    }

    void PopulateNearbyActors(float radius)
    {
        if (radius > 0.f && SetNearbyRadius(radius)) {
            // updated
        } else if (radius > 0.f) {
            webui_log::warn("PopulateNearbyActors: invalid radius {}, keeping {}", radius, g_nearbyRadius);
        }

        auto* player = RE::PlayerCharacter::GetSingleton();
        if (player) {
            const auto formId = player->GetFormID();
            uint64_t playerUUID = PublicFormIDToUUID ? PublicFormIDToUUID(formId) : 0;
            const std::string uuidStr =
                playerUUID ? std::to_string(playerUUID) : std::to_string(static_cast<unsigned>(formId));
            std::string playerName = ActorDisplayNameLocal(player);
            WebUI_Invoke(std::format("setPlayerActor('{}', '{}', {}, {});", uuidStr, EscapeJsString(playerName),
                static_cast<unsigned>(formId), ActorSex(player)));
        }

        if (!player) {
            WebUI_Invoke("setNearbyActors([]);");
            return;
        }

        const float radiusSq = g_nearbyRadius * g_nearbyRadius;
        const auto playerPos = player->GetPosition();
        std::vector<RE::Actor*> scanned;
        scanned.reserve(64);
        int considered = 0;
        int distSkip = 0;
        std::vector<std::string> distSkipSamples;

        auto addUnique = [&](RE::Actor* actor) {
            if (!actor || actor->IsDeleted())
                return;
            const auto id = actor->GetFormID();
            for (auto* existing : scanned) {
                if (existing && existing->GetFormID() == id)
                    return;
            }
            scanned.push_back(actor);
        };

        // Player always listed (status may grey them).
        addUnique(player);

        if (auto* lists = RE::ProcessLists::GetSingleton()) {
            lists->ForEachHighActor([&](RE::Actor* actor) {
                if (!actor || actor == player)
                    return RE::BSContainer::ForEachResult::kContinue;
                if (actor->IsDeleted())
                    return RE::BSContainer::ForEachResult::kContinue;
                ++considered;
                const float distSq = actor->GetPosition().GetSquaredDistance(playerPos);
                if (distSq > radiusSq) {
                    ++distSkip;
                    if (distSkipSamples.size() < 8) {
                        const float dist = std::sqrt(distSq);
                        distSkipSamples.push_back(
                            std::format("{}@{:.0f}", ActorDisplayNameLocal(actor), dist));
                    }
                    return RE::BSContainer::ForEachResult::kContinue;
                }
                addUnique(actor);
                return RE::BSContainer::ForEachResult::kContinue;
            });
        }

        // Keep current focus in the list even outside radius.
        if (Target_Current && Target_Current != player && !Target_Current->IsDeleted())
            addUnique(Target_Current);

        nlohmann::json nearby = nlohmann::json::array();
        for (auto* ak : scanned)
            PushNearbyJsonEntry(nearby, ak, player, ak == player);

        std::sort(nearby.begin(), nearby.end(), [](const nlohmann::json& a, const nlohmann::json& b) {
            const bool ap = a.value("isPlayer", false);
            const bool bp = b.value("isPlayer", false);
            if (ap != bp)
                return ap && !bp;
            const int ar = a.value("sortRank", 2);
            const int br = b.value("sortRank", 2);
            if (ar != br)
                return ar < br;
            return a.value("dist", 0.f) < b.value("dist", 0.f);
        });

        std::string distSkipDetail;
        for (std::size_t i = 0; i < distSkipSamples.size(); ++i) {
            if (i)
                distSkipDetail += ", ";
            distSkipDetail += distSkipSamples[i];
        }
        if (distSkip > 0) {
            webui_log::info(
                "PopulateNearbyActors: radius={} considered={} listed={} distSkip={}{}",
                g_nearbyRadius,
                considered,
                scanned.size(),
                distSkip,
                distSkipDetail.empty() ? "" : std::format(" [{}]", distSkipDetail));
        } else {
            webui_log::info(
                "PopulateNearbyActors: radius={} considered={} listed={} distSkip=0",
                g_nearbyRadius,
                considered,
                scanned.size());
        }

        WebUI_Invoke("setNearbyActors(" + nearby.dump() + ");");
    }

    void Call_MultiTarget_Menu_Selection()
    {
        auto* player = RE::PlayerCharacter::GetSingleton();
        if (!player) {
            webui_log::warn("Call_MultiTarget_Menu_Selection: no player");
            return;
        }

        webui_log::info("Call_MultiTarget_Menu_Selection: dispatching Papyrus MultiTarget_Menu_Selection");

        SKSE::GetTaskInterface()->AddTask([player]() {
            auto* vm = RE::BSScript::Internal::VirtualMachine::GetSingleton();
            if (!vm) {
                webui_log::error("Call_MultiTarget_Menu_Selection: no VM");
                return;
            }

            RE::TESQuest* quest = FindMainQuest();
            if (!quest) {
                webui_log::error("Call_MultiTarget_Menu_Selection: quest SkyrimNet_SexLab not found");
                return;
            }

            auto handle = vm->GetObjectHandlePolicy()->GetHandleForObject(
                static_cast<RE::VMTypeID>(quest->GetFormType()), quest);
            RE::BSTSmartPointer<RE::BSScript::Object> scriptObject;
            vm->FindBoundObject(handle, "SkyrimNet_SexLab_Menu", scriptObject);
            if (!scriptObject) {
                webui_log::error("Call_MultiTarget_Menu_Selection: bound script SkyrimNet_SexLab_Menu not found");
                return;
            }

            auto* args = RE::MakeFunctionArguments(static_cast<RE::Actor*>(player));
            RE::BSTSmartPointer<RE::BSScript::IStackCallbackFunctor> callback;
            vm->DispatchMethodCall(scriptObject, RE::BSFixedString("MultiTarget_Menu_Selection"), args, callback);
            webui_log::info("Call_MultiTarget_Menu_Selection: dispatched");
        });
    }

    void DispatchAnimationMenuExportState(RE::TESForm* thread, RE::TESForm* sl_scene)
    {
        if (!thread || !sl_scene) {
            webui_log::warn("DispatchAnimationMenuExportState: null args");
            return;
        }

        SKSE::GetTaskInterface()->AddTask([thread, sl_scene]() {
            auto* vm = RE::BSScript::Internal::VirtualMachine::GetSingleton();
            if (!vm) {
                webui_log::error("DispatchAnimationMenuExportState: no VM");
                return;
            }

            RE::TESQuest* quest = FindMainQuest();
            if (!quest) {
                webui_log::error("DispatchAnimationMenuExportState: quest not found");
                return;
            }

            auto handle = vm->GetObjectHandlePolicy()->GetHandleForObject(
                static_cast<RE::VMTypeID>(sl_scene->GetFormType()), sl_scene);
            RE::BSTSmartPointer<RE::BSScript::Object> scriptObject;
            vm->FindBoundObject(handle, "SkyrimNet_SexLab_Scene", scriptObject);
            if (!scriptObject) {
                webui_log::error("DispatchAnimationMenuExportState: Scene script not bound");
                return;
            }

            auto* args = RE::MakeFunctionArguments(static_cast<RE::TESForm*>(thread));
            RE::BSTSmartPointer<RE::BSScript::IStackCallbackFunctor> callback;
            vm->DispatchMethodCall(scriptObject, RE::BSFixedString("WebUI_ExportAnimationMenuState"), args,
                callback);
            webui_log::info("DispatchAnimationMenuExportState: dispatched");
        });
    }

    static void DispatchManagerMethod(const char* method, std::int32_t a, std::int32_t b)
    {
        SKSE::GetTaskInterface()->AddTask([method, a, b]() {
            auto* vm = RE::BSScript::Internal::VirtualMachine::GetSingleton();
            if (!vm) {
                webui_log::error("DispatchManagerMethod: no VM");
                return;
            }

            RE::TESQuest* quest = FindMainQuest();
            if (!quest) {
                webui_log::error("DispatchManagerMethod: quest not found");
                return;
            }

            auto handle = vm->GetObjectHandlePolicy()->GetHandleForObject(
                static_cast<RE::VMTypeID>(quest->GetFormType()), quest);
            RE::BSTSmartPointer<RE::BSScript::Object> scriptObject;
            vm->FindBoundObject(handle, "SkyrimNet_SexLab_Scene_Manager", scriptObject);
            if (!scriptObject) {
                webui_log::error("DispatchManagerMethod: Manager script not bound");
                return;
            }

            int arg_a = static_cast<int>(a);
            int arg_b = static_cast<int>(b);
            auto* args = RE::MakeFunctionArguments(std::move(arg_a), std::move(arg_b));
            RE::BSTSmartPointer<RE::BSScript::IStackCallbackFunctor> callback;
            vm->DispatchMethodCall(scriptObject, RE::BSFixedString(method), args, callback);
        });
    }

    static void DispatchManagerMethodStr(const char* method, std::int32_t a, const std::string& b)
    {
        std::string methodName = method ? method : "";
        std::string payload = b;
        SKSE::GetTaskInterface()->AddTask([methodName, a, payload]() {
            auto* vm = RE::BSScript::Internal::VirtualMachine::GetSingleton();
            if (!vm) {
                webui_log::error("DispatchManagerMethodIntStr: no VM");
                return;
            }

            RE::TESQuest* quest = FindMainQuest();
            if (!quest) {
                webui_log::error("DispatchManagerMethodIntStr: quest not found");
                return;
            }

            auto handle = vm->GetObjectHandlePolicy()->GetHandleForObject(
                static_cast<RE::VMTypeID>(quest->GetFormType()), quest);
            RE::BSTSmartPointer<RE::BSScript::Object> scriptObject;
            vm->FindBoundObject(handle, "SkyrimNet_SexLab_Scene_Manager", scriptObject);
            if (!scriptObject) {
                webui_log::error("DispatchManagerMethodIntStr: Manager script not bound");
                return;
            }

            int arg_a = static_cast<int>(a);
            RE::BSFixedString arg_b(payload.c_str());
            auto* args = RE::MakeFunctionArguments(std::move(arg_a), std::move(arg_b));
            RE::BSTSmartPointer<RE::BSScript::IStackCallbackFunctor> callback;
            vm->DispatchMethodCall(scriptObject, RE::BSFixedString(methodName.c_str()), args, callback);
            webui_log::info("DispatchManagerMethodIntStr: {}", methodName);
        });
    }
    void DispatchManagerMethodIntInt(const char* method, std::int32_t a, std::int32_t b)
    {
        DispatchManagerMethod(method, a, b);
    }

    void DispatchManagerMethodIntStr(const char* method, std::int32_t a, const std::string& b)
    {
        DispatchManagerMethodStr(method, a, b);
    }

    void DispatchManagerMethodStrOnly(const char* method, const std::string& b)
    {
        std::string methodName = method ? method : "";
        std::string payload = b;
        SKSE::GetTaskInterface()->AddTask([methodName, payload]() {
            auto* vm = RE::BSScript::Internal::VirtualMachine::GetSingleton();
            if (!vm) {
                webui_log::error("DispatchManagerMethodStrOnly: no VM");
                return;
            }
            RE::TESQuest* quest = FindMainQuest();
            if (!quest) {
                webui_log::error("DispatchManagerMethodStrOnly: quest not found");
                return;
            }
            auto handle = vm->GetObjectHandlePolicy()->GetHandleForObject(
                static_cast<RE::VMTypeID>(quest->GetFormType()), quest);
            RE::BSTSmartPointer<RE::BSScript::Object> scriptObject;
            vm->FindBoundObject(handle, "SkyrimNet_SexLab_Scene_Manager", scriptObject);
            if (!scriptObject) {
                webui_log::error("DispatchManagerMethodStrOnly: Manager script not bound");
                return;
            }
            auto* args = RE::MakeFunctionArguments(RE::BSFixedString(payload.c_str()));
            RE::BSTSmartPointer<RE::BSScript::IStackCallbackFunctor> callback;
            vm->DispatchMethodCall(scriptObject, RE::BSFixedString(methodName.c_str()), args, callback);
            webui_log::info("DispatchManagerMethodStrOnly: {}", methodName);
        });
    }

    void HandleAnimDbQuery(const char* value)
    {
        if (!value)
            return;
        try {
            auto j = nlohmann::json::parse(value);
            const std::string request_id = j.value("_request_id", "");
            const std::string query_type = j.value("_type", "tags");
            const std::string filter_raw = j.contains("_filter") ? j["_filter"].dump() : "{}";
            const int n = j.value("_n", 20);
            auto spec = ParseFilterJson(filter_raw.c_str());

            if (query_type == "anims") {
                nlohmann::json rows = nlohmann::json::array();
                std::unordered_set<std::string> seen;
                for (const auto& row : AnimationDB::QueryTopNAnims(spec, n)) {
                    rows.push_back(AnimRowToJson(row));
                    seen.insert(row.registry);
                }
                if (j.contains("_also_registries") && j["_also_registries"].is_array()) {
                    for (const auto& el : j["_also_registries"]) {
                        if (!el.is_string())
                            continue;
                        const std::string reg = el.get<std::string>();
                        if (reg.empty() || seen.contains(reg))
                            continue;
                        if (auto row = AnimationDB::GetByRegistry(reg)) {
                            if (spec.has_description != 0) {
                                const bool any = AnimationDB::RowHasAnyDescription(*row);
                                if (spec.has_description == 1 && !any)
                                    continue;
                                if (spec.has_description == 2 && any)
                                    continue;
                            }
                            rows.push_back(AnimRowToJson(*row));
                        } else if (spec.has_description == 0)
                            rows.push_back(nlohmann::json{ { "_registry", reg } });
                        seen.insert(reg);
                    }
                }
                webui_log::info(
                    "HandleAnimDbQuery anims id={} actor_count={} gender_match={} has_description={} results={} total={}",
                    request_id,
                    spec.actor_count ? *spec.actor_count : -1,
                    spec.gender_match,
                    spec.has_description,
                    rows.size(),
                    AnimationDB::TotalEnabledCount());
                nlohmann::json payload;
                payload["_anims"] = rows;
                payload["_total_enabled"] = AnimationDB::TotalEnabledCount();
                InvokeAnimDbQueryResult(request_id.c_str(), payload);
            } else {
                nlohmann::json tags = nlohmann::json::array();
                for (const auto& tc : AnimationDB::QueryTopNTags(spec, n)) {
                    tags.push_back({ { "_tag", tc.tag }, { "_count", tc.count } });
                }
                nlohmann::json payload;
                payload["_tags"] = tags;
                payload["_total_enabled"] = AnimationDB::TotalEnabledCount();
                InvokeAnimDbQueryResult(request_id.c_str(), payload);
            }
        } catch (...) {
            webui_log::warn("HandleAnimDbQuery: parse failed");
        }
    }

    void HandleAnimDbResolveTags(const char* value)
    {
        if (!value)
            return;
        try {
            auto j = nlohmann::json::parse(value);
            const std::string request_id = j.value("_request_id", "");
            const std::string tags = j.value("_tags", "");
            const int actor_count = j.value("_actor_count", 0);
            const std::string resolved = AnimationDB::ResolveTags(tags, actor_count);
            nlohmann::json payload;
            payload["_request_id"] = request_id;
            payload["_resolved"] = resolved;
            payload["_ok"] = !resolved.empty() || tags.empty();
            std::string js = "animDbResolveTagsResult(" + payload.dump() + ");";
            WebUI_Invoke(js);
        } catch (...) {
            webui_log::warn("HandleAnimDbResolveTags: parse failed");
        }
    }

    void HandleNotify(const char* value)
    {
        if (!value)
            return;
        std::string msg;
        try {
            auto j = nlohmann::json::parse(value);
            msg = j.value("msg", "");
        } catch (...) {
            if (value[0] != '\0' && value[0] != '{')
                msg = value;
            else {
                webui_log::warn("HandleNotify: parse failed");
                return;
            }
        }
        if (msg.empty())
            return;

        if (msg.rfind("bondageGot", 0) == 0) {
            webui_log::info("{}", msg);
            return;
        }

        std::string payload = std::move(msg);
        SKSE::GetTaskInterface()->AddTask([payload]() {
            auto* vm = RE::BSScript::Internal::VirtualMachine::GetSingleton();
            if (!vm) {
                webui_log::error("HandleNotify: no VM");
                return;
            }
            RE::BSFixedString text(payload.c_str());
            auto* args = RE::MakeFunctionArguments(std::move(text));
            RE::BSTSmartPointer<RE::BSScript::IStackCallbackFunctor> callback;
            const bool ok = vm->DispatchStaticCall(
                RE::BSFixedString("Debug"),
                RE::BSFixedString("Notification"),
                args,
                callback);
            if (!ok)
                webui_log::warn("HandleNotify: DispatchStaticCall failed");
        });
    }

    void HandleLeashStatus(const char* value)
    {
        std::uint32_t formId = 0;
        try {
            auto j = nlohmann::json::parse(value ? value : "");
            if (j.contains("formId") && j["formId"].is_number()) {
                if (j["formId"].is_number_unsigned())
                    formId = j["formId"].get<std::uint32_t>();
                else if (j["formId"].is_number_integer())
                    formId = static_cast<std::uint32_t>(j["formId"].get<std::int64_t>());
                else
                    formId = static_cast<std::uint32_t>(j["formId"].get<double>());
            }
        } catch (...) {
            webui_log::warn("HandleLeashStatus: parse failed");
            return;
        }

        SKSE::GetTaskInterface()->AddTask([formId]() {
            nlohmann::json out;
            out["formId"] = formId;
            out["isLeashed"] = false;
            out["holderFormId"] = 0;
            out["holderName"] = "";
            auto* actor = formId ? RE::TESForm::LookupByID<RE::Actor>(formId) : nullptr;
            if (actor) {
                bool nativeOk = false;
                bool leashed = NativeIsLeashed(actor, nativeOk);
                if (!nativeOk)
                    leashed = FactionIsLeashed(actor);
                out["isLeashed"] = leashed;
                if (leashed) {
                    if (auto* holder = NativeGetLeashHolder(actor)) {
                        out["holderFormId"] = holder->GetFormID();
                        out["holderName"] = ActorDisplayNameLocal(holder);
                    }
                }
            }
            WebUI_Invoke(std::string("leashStatusResult(") + out.dump() + ");");
        });
    }

    void Call_Open_WebUI_Target(RE::Actor* target)
    {
        if (!target) {
            webui_log::warn("Call_Open_WebUI_Target: null target");
            return;
        }

        SKSE::GetTaskInterface()->AddTask([target]() {
            auto* vm = RE::BSScript::Internal::VirtualMachine::GetSingleton();
            if (!vm) {
                webui_log::error("Call_Open_WebUI_Target: no VM");
                return;
            }

            RE::TESQuest* quest = FindMainQuest();
            if (!quest) {
                webui_log::error("Call_Open_WebUI_Target: quest not found");
                return;
            }

            auto handle = vm->GetObjectHandlePolicy()->GetHandleForObject(
                static_cast<RE::VMTypeID>(quest->GetFormType()), quest);
            RE::BSTSmartPointer<RE::BSScript::Object> scriptObject;
            vm->FindBoundObject(handle, "SkyrimNet_SexLab_Menu", scriptObject);
            if (!scriptObject) {
                webui_log::error("Call_Open_WebUI_Target: Menu script not bound");
                return;
            }

            auto* args = RE::MakeFunctionArguments(static_cast<RE::Actor*>(target));
            RE::BSTSmartPointer<RE::BSScript::IStackCallbackFunctor> callback;
            vm->DispatchMethodCall(scriptObject, RE::BSFixedString("Open_WebUI_Target"), args, callback);
            webui_log::info("Call_Open_WebUI_Target: dispatched");
        });
    }

    void Call_ProcessHotkey(std::int32_t keyCode)
    {
        SKSE::GetTaskInterface()->AddTask([keyCode]() {
            auto* vm = RE::BSScript::Internal::VirtualMachine::GetSingleton();
            if (!vm) {
                webui_log::error("Call_ProcessHotkey: no VM");
                return;
            }

            RE::TESQuest* quest = FindMainQuest();
            if (!quest) {
                webui_log::error("Call_ProcessHotkey: quest not found");
                return;
            }

            auto handle = vm->GetObjectHandlePolicy()->GetHandleForObject(
                static_cast<RE::VMTypeID>(quest->GetFormType()), quest);
            RE::BSTSmartPointer<RE::BSScript::Object> scriptObject;
            vm->FindBoundObject(handle, "SkyrimNet_SexLab_Menu", scriptObject);
            if (!scriptObject) {
                webui_log::error("Call_ProcessHotkey: Menu script not bound");
                return;
            }

            int arg = static_cast<int>(keyCode);
            auto* args = RE::MakeFunctionArguments(std::move(arg));
            RE::BSTSmartPointer<RE::BSScript::IStackCallbackFunctor> callback;
            vm->DispatchMethodCall(scriptObject, RE::BSFixedString("ProcessHotkey"), args, callback);
            webui_log::info("Call_ProcessHotkey: dispatched key={}", keyCode);
        });
    }

    bool IsAvailableActor_Native(RE::StaticFunctionTag*, RE::Actor* actor)
    {
        return IsAvailableActor(actor);
    }

    bool IsSexLabAnimatingFocus(RE::Actor* actor)
    {
        return IsSexLabAnimatingActor(actor);
    }

    void Call_ControlActorFocus(RE::Actor* target)
    {
        if (!target) {
            webui_log::warn("Call_ControlActorFocus: null target");
            return;
        }
        SKSE::GetTaskInterface()->AddTask([target]() {
            auto* vm = RE::BSScript::Internal::VirtualMachine::GetSingleton();
            if (!vm) {
                webui_log::error("Call_ControlActorFocus: no VM");
                return;
            }
            RE::TESQuest* quest = FindMainQuest();
            if (!quest) {
                webui_log::error("Call_ControlActorFocus: quest not found");
                return;
            }
            auto handle = vm->GetObjectHandlePolicy()->GetHandleForObject(
                static_cast<RE::VMTypeID>(quest->GetFormType()), quest);
            RE::BSTSmartPointer<RE::BSScript::Object> scriptObject;
            vm->FindBoundObject(handle, "SkyrimNet_SexLab_Menu", scriptObject);
            if (!scriptObject) {
                webui_log::error("Call_ControlActorFocus: Menu script not bound");
                return;
            }
            auto* args = RE::MakeFunctionArguments(static_cast<RE::Actor*>(target));
            RE::BSTSmartPointer<RE::BSScript::IStackCallbackFunctor> callback;
            vm->DispatchMethodCall(scriptObject, RE::BSFixedString("WebUI_OnControlActorFocus"), args, callback);
            webui_log::info("Call_ControlActorFocus: dispatched");
        });
    }

    void ApplyControlActorFocus(std::uint32_t formId)
    {
        if (!formId) {
            webui_log::warn("ApplyControlActorFocus: formId 0");
            return;
        }
        auto* actor = RE::TESForm::LookupByID<RE::Actor>(formId);
        if (!actor) {
            webui_log::warn("ApplyControlActorFocus: actor not found {:08X}", formId);
            return;
        }

        Target_Current = actor;
        FocusKind.clear();
        TargetMenuSessionActive = true;

        const auto targetFormId = actor->GetFormID();
        uint64_t uuid = (PublicFormIDToUUID) ? PublicFormIDToUUID(targetFormId) : 0;
        std::string skyrimNetName = (uuid && SexLabNet::CrossDllStdStringSafe() && PublicGetActorNameByUUID)
            ? PublicGetActorNameByUUID(uuid)
            : "";
        const char* targetName = !skyrimNetName.empty() ? skyrimNetName.c_str() : actor->GetName();
        const char* name = (targetName && targetName[0]) ? targetName : "Unknown";
        const std::string uuidStr =
            uuid ? std::to_string(uuid) : std::to_string(static_cast<unsigned>(targetFormId));
        WebUI_Invoke(std::format("setTargetActor('{}', '{}', {});", uuidStr, EscapeJsString(name),
            static_cast<unsigned>(targetFormId)));

        Call_ControlActorFocus(actor);
        auto catalog = ActionCatalog::BuildUICatalog(false);
        WebUI_Invoke(ConfigureTargetMenuScript(catalog));
    }

    void ApplyControlActorFocusJson(const std::string& payload)
    {
        nlohmann::json j;
        try {
            j = nlohmann::json::parse(payload);
        } catch (...) {
            webui_log::warn("ApplyControlActorFocusJson: bad JSON");
            return;
        }
        const std::string sentinel = j.value("sentinel", "");
        const std::uint32_t formId = j.value("formId", 0u);
        if (!sentinel.empty()) {
            Target_Current = nullptr;
            FocusKind = sentinel;
            TargetMenuSessionActive = true;
            webui_log::info("ApplyControlActorFocus: sentinel={}", sentinel);
            auto catalog = ActionCatalog::BuildUICatalog(false);
            WebUI_Invoke(ConfigureTargetMenuScript(catalog));
            const auto panel = ActionCatalog::SentinelMainPanel(sentinel);
            if (!panel.empty())
                ActionCatalog::SwitchMainPanel(panel);
            return;
        }
        ApplyControlActorFocus(formId);
    }

    void ApplyMainPanelRow(const std::string& payload)
    {
        nlohmann::json j;
        try {
            j = nlohmann::json::parse(payload);
        } catch (...) {
            webui_log::warn("ApplyMainPanelRow: bad JSON");
            return;
        }
        std::uint32_t formId = 0;
        if (j.contains("formId")) {
            const auto& v = j["formId"];
            if (v.is_number_unsigned())
                formId = v.get<std::uint32_t>();
            else if (v.is_number_integer())
                formId = static_cast<std::uint32_t>(v.get<std::int64_t>());
            else if (v.is_string()) {
                try {
                    formId = static_cast<std::uint32_t>(std::stoul(v.get<std::string>(), nullptr, 0));
                } catch (...) {
                    formId = 0;
                }
            }
        }
        if (!formId) {
            webui_log::warn("ApplyMainPanelRow: missing formId");
            return;
        }
        ApplyControlActorFocus(formId);
        const auto panel = ActionCatalog::CurrentRowClickMainPanel();
        if (!panel.empty())
            ActionCatalog::SwitchMainPanel(panel);
    }

    void WebUI_PushMainPanelData(RE::StaticFunctionTag*, RE::BSFixedString json)
    {
        const char* raw = json.c_str();
        if (!raw || !raw[0])
            return;
        WebUI_Invoke(std::string("setMainPanelData(") + raw + ");");
    }

    void WebUI_PushCascadeChoices(RE::StaticFunctionTag*, RE::BSFixedString json)
    {
        const char* raw = json.c_str();
        if (!raw || !raw[0])
            return;
        const std::string payload(raw);
        const std::string preview =
            payload.size() > 80 ? payload.substr(0, 80) + "..." : payload;
        webui_log::info("WebUI_PushCascadeChoices: {} bytes preview={}", payload.size(), preview);
        // JSON.parse path — raw object-literal Invoke can silently no-op.
        WebUI_InteropCall("setCascadeChoices", payload);
    }

    RE::Actor* WebUI_GetFocusActor(RE::StaticFunctionTag*)
    {
        return Target_Current;
    }

    RE::BSFixedString WebUI_GetFocusKind(RE::StaticFunctionTag*)
    {
        return FocusKind.c_str();
    }

    void WebUI_AfterTargetOpen(RE::StaticFunctionTag*, RE::Actor* preferred, bool preferExplicit)
    {
        const unsigned fid =
            (preferExplicit && preferred) ? static_cast<unsigned>(preferred->GetFormID()) : 0u;
        WebUI_Invoke(std::format("selectControlActorDefault({});", fid));
    }

    void WebUI_MaybeRestoreAnimationPanel(RE::StaticFunctionTag*)
    {
        if (!Target_Current || !IsSexLabAnimatingActor(Target_Current))
            return;
        webui_log::info("WebUI_MaybeRestoreAnimationPanel: opening Description Editor for animating focus");
        DispatchMenuNoArg("WebUI_ConfigureFocusScene");
        ActionCatalog::SwitchMainPanel("description_editor_panel");
    }

    bool WebUI_IsOverlayVisible(RE::StaticFunctionTag*)
    {
        return !WebUI_IsHidden();
    }

    bool Register_WebUI_Functions(RE::BSScript::IVirtualMachine* a_vm)
    {
        if (!a_vm) {
            webui_log::error("Couldn't get Papyrus Virtual Machine.");
            return false;
        }

        constexpr std::string_view scriptName = "SkyrimNet_SexLab_WebUI";

        a_vm->RegisterFunction("Target_Menu_Open", scriptName, Target_Menu_Open);
        a_vm->RegisterFunction("Target_Menu_Refresh", scriptName, Target_Menu_Refresh);
        a_vm->RegisterFunction("Sex_Menu_Open", scriptName, Sex_Menu_Open);
        a_vm->RegisterFunction("YesNo_Open", scriptName, YesNo_Open);
        a_vm->RegisterFunction("SceneCreator_Open", scriptName, SceneCreator_Open);
        a_vm->RegisterFunction("SceneCreator_Configure", scriptName, SceneCreator_Configure);
        a_vm->RegisterFunction("Bondage_Configure", scriptName, Bondage_Configure);
        a_vm->RegisterFunction("Animation_Menu_Open", scriptName, Animation_Menu_Open);
        a_vm->RegisterFunction("Animation_Menu_Show", scriptName, Animation_Menu_Show);
        a_vm->RegisterFunction("Animation_Menu_Configure", scriptName, Animation_Menu_Configure);
        a_vm->RegisterFunction("SceneConnections_Show", scriptName, SceneConnections_Show);
        a_vm->RegisterFunction("SceneInfos_Seed", scriptName, SceneInfos_Seed);
        a_vm->RegisterFunction("WebUI_HideAllPanels", scriptName, WebUI_HideAllPanels);
        a_vm->RegisterFunction("WebUI_CloseOverlay", scriptName, WebUI_CloseOverlay);
        a_vm->RegisterFunction("WebUI_SetHotkey", scriptName, WebUI_SetHotkey);
        a_vm->RegisterFunction("WebUI_AfterTargetOpen", scriptName, WebUI_AfterTargetOpen);
        a_vm->RegisterFunction("WebUI_MaybeRestoreAnimationPanel", scriptName, WebUI_MaybeRestoreAnimationPanel);
        a_vm->RegisterFunction("WebUI_IsOverlayVisible", scriptName, WebUI_IsOverlayVisible);
        a_vm->RegisterFunction("WebUI_SetLastRebuildTimestamp", scriptName, WebUI_SetLastRebuildTimestamp);
        a_vm->RegisterFunction("ActorAnimMeta_Result", scriptName, ActorAnimMeta_Result);
        a_vm->RegisterFunction("ConsumeSkipSceneCreator", scriptName, ConsumeSkipSceneCreator);
        a_vm->RegisterFunction("TraceLog", scriptName, TraceLog);
        a_vm->RegisterFunction("SetNearbyActorsJson", scriptName, SetNearbyActorsJson);
        a_vm->RegisterFunction("IsAvailableActor", scriptName, IsAvailableActor_Native);
        a_vm->RegisterFunction("WebUI_PushMainPanelData", scriptName, WebUI_PushMainPanelData);
        a_vm->RegisterFunction("WebUI_PushCascadeChoices", scriptName, WebUI_PushCascadeChoices);
        a_vm->RegisterFunction("WebUI_GetFocusActor", scriptName, WebUI_GetFocusActor);
        a_vm->RegisterFunction("WebUI_GetFocusKind", scriptName, WebUI_GetFocusKind);

        webui_log::info("Successfully registered Papyrus functions for {}", scriptName);
        return true;
    }
}
