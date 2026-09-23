#include <Windows.h>
#include <spdlog/sinks/basic_file_sink.h>
#include <spdlog/spdlog.h>

#include "PCH.h"
#include "WebUI.h"
#include "Papyrus_WebUI.h"
#include "Papyrus_Utilities.h"
#include "Papyrus_API.h"
#include "Papyrus_AnimationDB.h"
#include "Papyrus_Json.h"
#include "JsonStore.h"
#include "AnimationDB.h"
#include "TargetMenuRegistry.h"
#include "WebUI_Log.h"
#include "Config.h"

using namespace SKSE;

namespace {

/// Exercises the JSON store's map/array/nesting/dump/release paths once at load. Cheap (a
/// handful of ops) and catches a broken build before any scene depends on it; see JsonStore.h.
void JsonStore_SelfTest() {
    using namespace SexLabNet::Json;
    const Handle root = NewMap();
    MapSetStr(root, "_Mode", "creator");
    MapSetInt(root, "count", 2);
    const Handle arr = NewArray();
    ArrayAddStr(arr, "a", -1);
    ArrayAddStr(arr, "b", -1);
    MapSetObj(root, "items", arr);
    const std::string json = Dump(root);
    const bool lowered = json.find("\"_mode\":\"creator\"") != std::string::npos && json.find("_Mode") == std::string::npos;
    const bool hasArr = json.find("\"items\":[\"a\",\"b\"]") != std::string::npos;
    Release(root);
    if (lowered && hasArr) {
        webui_log::info("JsonStore self-test passed: {}", json);
    } else {
        webui_log::error("JsonStore self-test FAILED: {}", json);
    }
    webui_log::info("JsonStore {}", Stats());
}

SKSEPluginLoad(const SKSE::LoadInterface *skse) {
    SKSE::Init(skse);

    SexLabNet::InitSkyrimNetAPI();

    SKSE::GetMessagingInterface()->RegisterListener([](SKSE::MessagingInterface::Message *message) {
        if (message->type == SKSE::MessagingInterface::kDataLoaded) {
            RE::ConsoleLog::GetSingleton()->Print("SkyrimNet_SexLab: SKSE listening!");
            AnimationDB::Open();
            InitWebUI();
            SexLabNet::Config::GetSingleton().ApplyFromConfig();
            JsonStore_SelfTest();
        } else if (message->type == SKSE::MessagingInterface::kPostLoadGame ||
                   message->type == SKSE::MessagingInterface::kNewGame) {
            TargetMenuRegistry::Clear();
            WebUI_SetGameReady();
            SexLabNet::Config::GetSingleton().ApplyFromConfig();
            SexLabNet::Json::OnNewSession();
        }
    });

    webui_log::info("SkyrimNet_SexLab: Trying to load WebUI plugin...");
    if (auto papyrus = SKSE::GetPapyrusInterface()) {
        if (!papyrus->Register(PapyrusBindings_WebUI::Register_WebUI_Functions)) {
            webui_log::error("Failed to register WebUI Papyrus functions");
        } else {
            webui_log::info("WebUI Papyrus functions registered");
        }
        if (!papyrus->Register(PapyrusBindings_Utilities::Register_Utilities_Functions)) {
            webui_log::error("Failed to register Utilities Papyrus functions");
        } else {
            webui_log::info("Utilities Papyrus functions registered");
        }
        if (!papyrus->Register(PapyrusBindings_API::Register_API_Functions)) {
            webui_log::error("Failed to register API Papyrus functions");
        } else {
            webui_log::info("API Papyrus functions registered");
        }
        if (!papyrus->Register(PapyrusBindings_AnimationDB::Register_AnimationDB_Functions)) {
            webui_log::error("Failed to register AnimationDB Papyrus functions");
        } else {
            webui_log::info("AnimationDB Papyrus functions registered");
        }
        if (!papyrus->Register(PapyrusBindings_Json::Register_Json_Functions)) {
            webui_log::error("Failed to register Json Papyrus functions");
        } else {
            webui_log::info("Json Papyrus functions registered");
        }
    } else {
        webui_log::info("Failed to get Papyrus interface.");
    }

    return true;
}

}
