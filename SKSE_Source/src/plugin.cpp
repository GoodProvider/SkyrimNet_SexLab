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
#include "AnimSpeed.h"
#include "NarrationQueue.h"
#include "OrgasmEngine.h"
#include "Hud.h"
#include "Papyrus_OrgasmEngine.h"

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

    // ReleaseAndRetain(h, h) must keep h alive.
    const Handle kept = Retain(NewMap());
    ReleaseAndRetain(kept, kept);
    const bool sameRetain = IsValid(kept);
    Release(kept);

    // Setting an array element to the object already there must keep it alive.
    const Handle outer = NewArray();
    ArrayAddObj(outer, NewMap(), -1);
    const Handle inner = ArrayGetObj(outer, 0, kInvalidHandle);
    ArraySetObj(outer, 0, inner);
    const bool sameArraySet = inner != kInvalidHandle && IsValid(inner) &&
                              ArrayGetObj(outer, 0, kInvalidHandle) == inner;
    Release(outer);

    // A cp1252 byte (not UTF-8) must still dump, as U+FFFD.
    const Handle ansi = NewMap();
    MapSetStr(ansi, "name", "J\xF6rgen");
    const bool ansiDumps = !Dump(ansi).empty();
    Release(ansi);

    if (lowered && hasArr && sameRetain && sameArraySet && ansiDumps) {
        webui_log::info("JsonStore self-test passed: {}", json);
    } else {
        webui_log::error("JsonStore self-test FAILED: {} sameRetain={} sameArraySet={} ansiDumps={}", json,
            sameRetain, sameArraySet, ansiDumps);
    }
    webui_log::info("JsonStore {}", Stats());
}

// Co-save record: the JSON store session a save was made in, so the next load never reuses it
// (see Json::OnNewSession). Revert fires before every load and on new game.
namespace {
    constexpr std::uint32_t kCoSaveId = 'SNSX';
    constexpr std::uint32_t kJsonSessionRecord = 'JSES';
    constexpr std::uint32_t kJsonSessionVersion = 1;

    void CoSave_OnSave(SKSE::SerializationInterface *intfc) {
        if (!intfc->WriteRecord(kJsonSessionRecord, kJsonSessionVersion, SexLabNet::Json::CurrentSession())) {
            webui_log::error("co-save: failed to write JSON store session");
        }
        OrgasmEngine::Save(intfc);
    }

    void CoSave_OnLoad(SKSE::SerializationInterface *intfc) {
        std::uint32_t type = 0, version = 0, length = 0;
        while (intfc->GetNextRecordInfo(type, version, length)) {
            if (type == kJsonSessionRecord) {
                std::uint32_t session = 0;
                if (intfc->ReadRecordData(session)) {
                    SexLabNet::Json::SetLoadedSaveSession(session);
                }
            } else if (type == OrgasmEngine::kRecord) {
                OrgasmEngine::Load(intfc, version, length);
            }
        }
    }

    void CoSave_OnRevert(SKSE::SerializationInterface *) {
        SexLabNet::Json::SetLoadedSaveSession(0);
        OrgasmEngine::Revert();
    }
}

SKSEPluginLoad(const SKSE::LoadInterface *skse) {
    SKSE::Init(skse);

    if (auto *ser = SKSE::GetSerializationInterface()) {
        ser->SetUniqueID(kCoSaveId);
        ser->SetSaveCallback(CoSave_OnSave);
        ser->SetLoadCallback(CoSave_OnLoad);
        ser->SetRevertCallback(CoSave_OnRevert);
    }

    SexLabNet::InitSkyrimNetAPI();
    AnimSpeed::Install();

    SKSE::GetMessagingInterface()->RegisterListener([](SKSE::MessagingInterface::Message *message) {
        if (message->type == SKSE::MessagingInterface::kDataLoaded) {
            RE::ConsoleLog::GetSingleton()->Print("SkyrimNet_SexLab: SKSE listening!");
            AnimationDB::Open();
            InitWebUI();
            Hud::Init();
            SexLabNet::Config::GetSingleton().ApplyFromConfig();
            OrgasmEngine::Install();
            JsonStore_SelfTest();
        } else if (message->type == SKSE::MessagingInterface::kPostLoadGame ||
                   message->type == SKSE::MessagingInterface::kNewGame) {
            TargetMenuRegistry::Clear();
            AnimationDB::LoadSynonyms();
            PapyrusBindings_WebUI::ClearOnGameLoad();
            AnimSpeed::ClearAll();
            NarrationQueue::Clear();
            Hud::Reset();
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
        if (!papyrus->Register(PapyrusBindings_OrgasmEngine::Register_OrgasmEngine_Functions)) {
            webui_log::error("Failed to register OrgasmEngine Papyrus functions");
        } else {
            webui_log::info("OrgasmEngine Papyrus functions registered");
        }
    } else {
        webui_log::info("Failed to get Papyrus interface.");
    }

    return true;
}

}
