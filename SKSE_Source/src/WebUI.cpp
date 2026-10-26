#include "WebUI.h"
#include "JsonUtil.h"
#include "Papyrus_WebUI.h"
#include "WebUI_Log.h"
#include "ActionCatalog.h"
#include "Aid.h"
#include "ActionDispatch.h"
#include "Config.h"
#include "AnimationDB.h"
#include "AnimEngine.h"
#include "Hud.h"
#include "OrgasmEngine.h"
#include "InjuryEngine.h"
#include "StrategyDecision.h"
#include "Profiler.h"
#include "RE/Skyrim.h"

#include <Windows.h>
#include <algorithm>
#include <charconv>
#include <cstring>
#include <deque>
#include <filesystem>
#include <fstream>
#include <mutex>
#include <sstream>
#include <string>
#include <string_view>
#include <thread>
#include <vector>
#include <nlohmann/json.hpp>

static PRISMA_UI_API::IVPrismaUI1* PrismaUI = nullptr;
static PrismaView g_view = 0;
static std::atomic<bool> g_gameReady{false};
static std::atomic<bool> g_domReady{false};
static std::atomic<bool> g_webuiGamePaused{true};
static std::mutex g_invokeMutex;
static std::deque<std::string> g_pendingInvokes;
static std::atomic<uint32_t> g_menuHotkey{0};
static std::mutex g_rebuildTsMutex;
static std::string g_lastRebuildTimestamp;
static int g_sexlabAnimCount = -1;  // -1 = not yet reported by Papyrus
static std::mutex g_logFileMutex;
static std::uintmax_t g_logFileOffset = 0;
// Show held while another PrismaUI view (e.g. the SkyrimNet dashboard) has focus. The generation
// changes on each save load, so a held Show from the previous game is dropped.
static std::atomic<bool> g_showPending{false};
static std::atomic<bool> g_showPendingControlPanel{true};
static std::atomic<uint32_t> g_showGeneration{0};

namespace {

class EmptyArgs : public RE::BSScript::IFunctionArguments
{
public:
    bool operator()(RE::BSScrapArray<RE::BSScript::Variable>& a_dst) const override
    {
        a_dst.resize(0);
        return true;
    }
};

/// Runs a PrismaUI listener body. An exception escaping a listener ends the game, so any throw
/// (bad payload type, json::value() mismatch, ...) is logged and the call is dropped.
template <class Body>
void RunGuarded(const char* listener, Body&& body) noexcept
{
    try {
        body();
    } catch (const std::exception& e) {
        webui_log::error("{}: {}", listener, e.what());
    } catch (...) {
        webui_log::error("{}: unknown exception", listener);
    }
}

std::string ReadPluginVersionFromInfoJson()
{
    try {
        std::ifstream f("Data/SKSE/Plugins/SkyrimNet_SexLab/info.json");
        if (!f)
            return SexLabNet::Config::kPluginVersion;
        auto j = nlohmann::json::parse(f, nullptr, false);
        if (j.is_discarded())
            return SexLabNet::Config::kPluginVersion;
        if (j.contains("version") && j["version"].is_string())
            return j["version"].get<std::string>();
    } catch (...) {
    }
    return SexLabNet::Config::kPluginVersion;
}

std::filesystem::path ResolvePluginLogPath()
{
    if (auto dir = SKSE::log::log_directory())
        return *dir / "SkyrimNet_SexLab.log";
    return {};
}

std::vector<std::string> SplitLogLines(std::string_view text)
{
    std::vector<std::string> lines;
    std::size_t start = 0;
    while (start < text.size()) {
        auto end = text.find('\n', start);
        if (end == std::string_view::npos) {
            lines.emplace_back(text.substr(start));
            break;
        }
        auto line = text.substr(start, end - start);
        if (!line.empty() && line.back() == '\r')
            line.remove_suffix(1);
        lines.emplace_back(line);
        start = end + 1;
    }
    return lines;
}

void PushLogChunk(bool reset, const std::vector<std::string>& lines, const std::string& pathHint)
{
    nlohmann::json j;
    j["reset"] = reset;
    j["lines"] = lines;
    j["path"] = pathHint;
    WebUI_Invoke("appendLogLines(" + SafeDump(j) + ");");
}

/// Caller must hold g_logFileMutex.
void ReadLogTailUnlocked(bool resetFromStart)
{
    if (resetFromStart)
        g_logFileOffset = 0;
    const auto path = ResolvePluginLogPath();
    if (path.empty() || !std::filesystem::exists(path)) {
        PushLogChunk(true, {}, path.empty() ? std::string{} : path.string());
        return;
    }
    std::ifstream f(path, std::ios::binary);
    if (!f) {
        PushLogChunk(true, {}, path.string());
        return;
    }
    f.seekg(0, std::ios::end);
    const auto size = static_cast<std::uintmax_t>(f.tellg());
    constexpr std::uintmax_t kTailBytes = 128 * 1024;
    std::uintmax_t start = 0;
    if (size > kTailBytes)
        start = size - kTailBytes;
    f.seekg(static_cast<std::streamoff>(start));
    std::string buf((std::istreambuf_iterator<char>(f)), std::istreambuf_iterator<char>());
    g_logFileOffset = size;
    auto lines = SplitLogLines(buf);
    if (start > 0 && !lines.empty())
        lines.erase(lines.begin());
    PushLogChunk(true, lines, path.string());
}

void DispatchHandlerBondageClosed()
{
    SKSE::GetTaskInterface()->AddTask([]() {
        auto* vm = RE::BSScript::Internal::VirtualMachine::GetSingleton();
        if (!vm) {
            webui_log::error("DispatchHandlerBondageClosed: no VM");
            return;
        }
        auto* quest = RE::TESDataHandler::GetSingleton()
            ->LookupForm<RE::TESQuest>(0x800, "SkyrimNet_SexLab_Handler_UDNG.esp");
        if (!quest) {
            webui_log::info("DispatchHandlerBondageClosed: handler ESP not loaded");
            return;
        }
        auto handle = vm->GetObjectHandlePolicy()->GetHandleForObject(
            static_cast<RE::VMTypeID>(quest->GetFormType()), quest);
        RE::BSTSmartPointer<RE::BSScript::Object> scriptObject;
        vm->FindBoundObject(handle, "SkyrimNet_SexLab_Handler_UDNG", scriptObject);
        if (!scriptObject) {
            webui_log::warn("DispatchHandlerBondageClosed: Handler script not bound");
            return;
        }
        auto* raw = new EmptyArgs();
        RE::BSTSmartPointer<RE::BSScript::IStackCallbackFunctor> callback;
        vm->DispatchMethodCall(scriptObject, RE::BSFixedString("TM_BondageOnWebUIClosed"), raw, callback);
        webui_log::info("DispatchHandlerBondageClosed: dispatched");
    });
}

void Call_RebuildAnimDb()
{
    SKSE::GetTaskInterface()->AddTask([]() {
        auto* vm = RE::BSScript::Internal::VirtualMachine::GetSingleton();
        if (!vm) {
            webui_log::error("Call_RebuildAnimDb: no VM");
            return;
        }
        RE::TESQuest* quest = RE::TESForm::LookupByEditorID<RE::TESQuest>("SkyrimNet_SexLab");
        if (!quest)
            quest = RE::TESDataHandler::GetSingleton()->LookupForm<RE::TESQuest>(0x800, "SkyrimNet_SexLab.esp");
        if (!quest) {
            webui_log::error("Call_RebuildAnimDb: quest not found");
            return;
        }
        auto handle = vm->GetObjectHandlePolicy()->GetHandleForObject(
            static_cast<RE::VMTypeID>(quest->GetFormType()), quest);
        RE::BSTSmartPointer<RE::BSScript::Object> scriptObject;
        vm->FindBoundObject(handle, "SkyrimNet_SexLab_AnimDb", scriptObject);
        if (!scriptObject) {
            webui_log::error("Call_RebuildAnimDb: AnimDb script not bound");
            return;
        }
        auto* raw = new EmptyArgs();
        RE::BSTSmartPointer<RE::BSScript::IStackCallbackFunctor> callback;
        vm->DispatchMethodCall(scriptObject, RE::BSFixedString("RebuildDatabase"), raw, callback);
        webui_log::info("Call_RebuildAnimDb: dispatched");
    });
}

// Settings → AnimEngine (debug): the nearest loaded, living NPC within 400 units of the player.
RE::Actor* NearestNpc(RE::PlayerCharacter* player)
{
    RE::Actor* best = nullptr;
    float best_d = 400.f * 400.f;
    auto* lists = RE::ProcessLists::GetSingleton();
    if (!lists || !player)
        return nullptr;
    const auto pp = player->GetPosition();
    for (auto& h : lists->highActorHandles) {
        auto ap = h.get();
        RE::Actor* a = ap.get();
        if (!a || a == player || a->IsDead() || !a->Is3DLoaded() || a->IsInCombat())
            continue;
        const float d = a->GetPosition().GetSquaredDistance(pp);
        if (d < best_d) {
            best_d = d;
            best = a;
        }
    }
    return best;
}

/// {"cmd":"start|next|back|pause|resume|end","registry":"...","victim":-1}; start uses the player + nearest NPC.
/// victim: position (after OrderForRegistry) played as the victim, the others as aggressors; -1 none.
void AnimEngineDebug(const std::string& payload)
{
    nlohmann::json j = nlohmann::json::parse(payload, nullptr, false);
    if (!j.is_object())
        return;
    const std::string cmd = j.value("cmd", "");
    const std::string reg = j.value("registry", "");
    const int victim = j.contains("victim") && j["victim"].is_number_integer() ? j["victim"].get<int>() : -1;
    if (cmd == "start") {
        ActionCatalog::ClearMainPanelSelection();
        PapyrusBindings_WebUI::ClearTargetMenuSession();
        WebUI_Visibility_Hide();
        SKSE::GetTaskInterface()->AddTask([reg, victim]() {
            auto* player = RE::PlayerCharacter::GetSingleton();
            std::vector<RE::Actor*> actors{ player };
            auto pb = AnimationDB::GetPlayback(reg);
            if (pb && pb->positions.size() >= 2) {
                RE::Actor* npc = NearestNpc(player);
                if (!npc) {
                    webui_log::warn("AnimEngine debug: no NPC within 400 units");
                    PapyrusBindings_WebUI::HandleNotify(R"({"msg":"AnimEngine: no NPC nearby"})");
                    return;
                }
                actors.push_back(npc);
            }
            std::vector<std::int32_t> roles;
            if (victim >= 0 && victim < static_cast<int>(actors.size())) {
                roles.assign(actors.size(), 1);
                roles[victim] = 2;
            }
            const int id = AnimEngine::StartScene(AnimEngine::OrderForRegistry(actors, reg), reg, nullptr, roles);
            webui_log::info("AnimEngine debug: start '{}' victim {} -> scene {}", reg, victim, id);
            PapyrusBindings_WebUI::HandleNotify(id >= 0 ? R"({"msg":"AnimEngine: scene started"})"
                                                     : R"j({"msg":"AnimEngine: start failed (see log)"})j");
        });
        return;
    }
    const int id = AnimEngine::LatestScene();
    bool ok = false;
    if (cmd == "next")
        ok = AnimEngine::Advance(id);
    else if (cmd == "back")
        ok = AnimEngine::Back(id);
    else if (cmd == "pause" || cmd == "resume")
        ok = AnimEngine::SetPaused(id, cmd == "pause");
    else if (cmd == "end")
        ok = AnimEngine::EndScene(id);
    webui_log::info("AnimEngine debug: {} scene {} -> {} {}", cmd, id, ok, AnimEngine::DescribeJson(id));
}

void Call_OpenSkyrimNetDashboard()
{
    ActionCatalog::ClearMainPanelSelection();
    WebUI_Invoke("hidePanel('target_menu_panel');");
    WebUI_Invoke("hidePanel('sex_menu_panel');");
    WebUI_Invoke("hidePanel('yesno_panel');");
    PapyrusBindings_WebUI::ClearTargetMenuSession();
    WebUI_Visibility_Hide();
    DispatchMenuNoArg("OpenSkyrimNetDashboard");
}

}  // namespace

// Declared in WebUI.h (external linkage) — must live outside the anonymous namespace.
void DispatchMenuNoArg(const char* functionName)
{
    SKSE::GetTaskInterface()->AddTask([functionName]() {
        auto* vm = RE::BSScript::Internal::VirtualMachine::GetSingleton();
        if (!vm) {
            webui_log::error("DispatchMenuNoArg: no VM");
            return;
        }
        RE::TESQuest* quest = RE::TESForm::LookupByEditorID<RE::TESQuest>("SkyrimNet_SexLab");
        if (!quest)
            quest = RE::TESDataHandler::GetSingleton()->LookupForm<RE::TESQuest>(0x800, "SkyrimNet_SexLab.esp");
        if (!quest) {
            webui_log::error("DispatchMenuNoArg: quest not found");
            return;
        }
        auto handle = vm->GetObjectHandlePolicy()->GetHandleForObject(
            static_cast<RE::VMTypeID>(quest->GetFormType()), quest);
        RE::BSTSmartPointer<RE::BSScript::Object> scriptObject;
        vm->FindBoundObject(handle, "SkyrimNet_SexLab_Menu", scriptObject);
        if (!scriptObject) {
            webui_log::error("DispatchMenuNoArg: Menu script not bound");
            return;
        }
        auto* raw = new EmptyArgs();
        RE::BSTSmartPointer<RE::BSScript::IStackCallbackFunctor> callback;
        vm->DispatchMethodCall(scriptObject, RE::BSFixedString(functionName), raw, callback);
        webui_log::info("DispatchMenuNoArg: {}", functionName);
    });
}

namespace SexLabNet {

void SetLastRebuildTimestamp(std::string ts)
{
    std::lock_guard lock(g_rebuildTsMutex);
    g_lastRebuildTimestamp = std::move(ts);
}

std::string GetLastRebuildTimestamp()
{
    std::lock_guard lock(g_rebuildTsMutex);
    return g_lastRebuildTimestamp;
}

void SetSexLabAnimCount(int sexlabCount)
{
    std::lock_guard lock(g_rebuildTsMutex);
    g_sexlabAnimCount = sexlabCount;
}

void InvokeConfigureSettingsPanel()
{
    nlohmann::json j;
    j["version"] = ReadPluginVersionFromInfoJson();
    j["docsUrl"] = Config::kDocsUrl;
    const int dbCount = static_cast<int>(AnimationDB::TotalCount());
    {
        std::lock_guard lock(g_rebuildTsMutex);
        j["lastRebuild"] = g_lastRebuildTimestamp.empty() ? "never" : g_lastRebuildTimestamp;
        j["animdbCount"] = dbCount;
        j["sexlabCount"] = g_sexlabAnimCount;
        // Empty DB is always a mismatch, even before Papyrus has reported the SexLab count (-1).
        j["dbEmpty"] = dbCount == 0;
        j["countMismatch"] = dbCount == 0 || (g_sexlabAnimCount >= 0 && dbCount != g_sexlabAnimCount);
    }
    j["animEngineEnabled"] = GetConfigBool("sexlab.anim_engine.enabled", false);
    WebUI_Invoke("configureSettingsPanel(" + SafeDump(j) + ");");
}

void InvokeLogPanelOpen()
{
    std::lock_guard lock(g_logFileMutex);
    ReadLogTailUnlocked(true);
}

void PushLogPanelPoll()
{
    std::lock_guard lock(g_logFileMutex);
    const auto path = ResolvePluginLogPath();
    if (path.empty() || !std::filesystem::exists(path))
        return;
    std::error_code ec;
    const auto size = std::filesystem::file_size(path, ec);
    if (ec)
        return;
    if (size < g_logFileOffset) {
        ReadLogTailUnlocked(true);
        return;
    }
    if (size == g_logFileOffset)
        return;
    std::ifstream f(path, std::ios::binary);
    if (!f)
        return;
    f.seekg(static_cast<std::streamoff>(g_logFileOffset));
    std::string buf((std::istreambuf_iterator<char>(f)), std::istreambuf_iterator<char>());
    g_logFileOffset = size;
    auto lines = SplitLogLines(buf);
    if (lines.empty())
        return;
    if (!buf.empty() && buf.back() != '\n') {
        const auto& last = lines.back();
        g_logFileOffset -= last.size();
        lines.pop_back();
    }
    if (!lines.empty())
        PushLogChunk(false, lines, path.string());
}

}  // namespace SexLabNet

/// Returns the process-wide KeyHandler singleton used for WebUI hotkeys.
KeyHandler* KeyHandler::GetSingleton()
{
    static KeyHandler singleton;
    return &singleton;
}

/// Move this sink to index 0 of BSInputDeviceManager (Remove + Prepend; Prepend alone is a no-op if already registered).
void KeyHandler::PromoteSink()
{
    auto* inputMgr = RE::BSInputDeviceManager::GetSingleton();
    if (!inputMgr)
        return;
    auto* self = GetSingleton();
    inputMgr->RemoveEventSink(self);
    inputMgr->PrependEventSink(self);
}

/// Registers this KeyHandler as a BSInputDeviceManager event sink.
/// Required before Escape / backslash (and other) hotkeys can fire.
void KeyHandler::RegisterSink()
{
    auto inputMgr = RE::BSInputDeviceManager::GetSingleton();
    if (inputMgr) {
        PromoteSink();
        webui_log::info("KeyHandler sink registered (prepended).");
    } else {
        webui_log::critical("Failed to get InputDeviceManager.");
    }
}

/// Binds a DX scancode to a callback for WebUI keyboard shortcuts.
/// Replaces any previous callback for the same key.
void KeyHandler::Register(uint32_t dxScanCode, KeyCallback callback)
{
    std::unique_lock lock(_mutex);
    _callbacks[dxScanCode] = std::move(callback);
}

/// Removes any callback bound to dxScanCode.
void KeyHandler::Unregister(uint32_t dxScanCode)
{
    std::unique_lock lock(_mutex);
    _callbacks.erase(dxScanCode);
}

void KeyHandler::SetHudKeys(std::map<uint32_t, KeyCallback> keys)
{
    std::unique_lock lock(_mutex);
    _hudKeys = std::move(keys);
}

void KeyHandler::SetHudActive(bool active)
{
    _hudActive.store(active);
}

void KeyHandler::SetAnimKeys(std::map<uint32_t, KeyCallback> keys)
{
    std::unique_lock lock(_mutex);
    _animKeys = std::move(keys);
}

void KeyHandler::SetAnimActive(bool active)
{
    _animActive.store(active);
}

namespace {

/// DX code of a button event: keyboard scancode, or 256 + button for the mouse (SKSE convention).
/// 0 for anything else (wheel, gamepad).
uint32_t HudCode(const RE::ButtonEvent* btn)
{
    if (!btn)
        return 0;
    const auto device = btn->GetDevice();
    if (device == RE::INPUT_DEVICE::kKeyboard)
        return btn->GetIDCode();
    if (device == RE::INPUT_DEVICE::kMouse && btn->GetIDCode() < 8)
        return 256 + btn->GetIDCode();
    return 0;
}

/// Unlink every button event whose code is a live HUD key (down, held and up alike).
void StripHudInputEvents(RE::InputEvent* const* a_eventList, const std::map<uint32_t, KeyCallback>& keys)
{
    auto*& head = const_cast<RE::InputEvent*&>(*a_eventList);
    RE::InputEvent* prev = nullptr;
    for (auto* cur = head; cur;) {
        const bool match = cur->eventType == RE::INPUT_EVENT_TYPE::kButton &&
                           keys.contains(HudCode(cur->AsButtonEvent()));
        auto* next = cur->next;
        if (!match) {
            prev = cur;
        } else if (prev) {
            prev->next = next;
        } else {
            head = next;
        }
        cur = next;
    }
}

bool ShouldSwallowSkseInputEvent(const RE::InputEvent* event)
{
    switch (event->GetEventType()) {
    case RE::INPUT_EVENT_TYPE::kChar:
        return true;
    case RE::INPUT_EVENT_TYPE::kButton:
        {
            const auto device = event->GetDevice();
            return device == RE::INPUT_DEVICE::kKeyboard ||
                   device == RE::INPUT_DEVICES::VirtualKeyboard();
        }
    default:
        return false;
    }
}

/// Remove keyboard/char events from the SKSE input list so downstream sinks (Papyrus RegisterForKey) do not see them.
void StripSwallowedInputEvents(RE::InputEvent* const* a_eventList)
{
    auto*& head = const_cast<RE::InputEvent*&>(*a_eventList);
    RE::InputEvent* prev = nullptr;
    for (auto* cur = head; cur;) {
        if (!ShouldSwallowSkseInputEvent(cur)) {
            prev = cur;
            cur = cur->next;
            continue;
        }
        auto* next = cur->next;
        if (prev)
            prev->next = next;
        else
            head = next;
        cur = next;
    }
}

}  // namespace

/// Input sink: on keyboard key-down, runs any registered WebUI hotkey callbacks.
/// Callbacks run outside the shared lock so they may mutate handler state safely.
RE::BSEventNotifyControl KeyHandler::ProcessEvent(RE::InputEvent* const* a_eventList,
                                                   [[maybe_unused]] RE::BSTEventSource<RE::InputEvent*>* a_eventSource)
{
    if (!a_eventList)
        return RE::BSEventNotifyControl::kContinue;

    std::vector<KeyCallback> toRun;
    // Scene HUD keys: only while the HUD is up and the overlay is closed. Otherwise the AnimEngine scene keys.
    const bool overlayHidden = WebUI_IsHidden();
    const bool hudUp = _hudActive.load() && overlayHidden;
    const bool hud = hudUp || (_animActive.load() && overlayHidden);
    std::map<uint32_t, KeyCallback> hudKeys;

    {
        std::shared_lock lock(_mutex);
        if (hud)
            hudKeys = hudUp ? _hudKeys : _animKeys;
        for (auto event = *a_eventList; event; event = event->next) {
            if (event->eventType != RE::INPUT_EVENT_TYPE::kButton)
                continue;
            const auto btn = event->AsButtonEvent();
            if (!btn || !btn->IsDown())
                continue;
            if (hud) {
                const auto hit = hudKeys.find(HudCode(btn));
                if (hit != hudKeys.end()) {
                    toRun.push_back(hit->second);
                    continue;
                }
            }
            if (btn->GetDevice() != RE::INPUT_DEVICE::kKeyboard)
                continue;
            auto it = _callbacks.find(btn->GetIDCode());
            if (it != _callbacks.end())
                toRun.push_back(it->second);
        }
    }

    if (hud && !hudKeys.empty())
        StripHudInputEvents(a_eventList, hudKeys);

    for (const auto& cb : toRun)
        cb();

    // Overlay visible: strip keyboard/char from the SKSE list (block mod hotkeys) but always kContinue
    // so mouse-move and mouse clicks still reach PrismaUI. PrismaUI text fields use Win32 directly.
    if (!WebUI_IsHidden())
        StripSwallowedInputEvents(a_eventList);

    return RE::BSEventNotifyControl::kContinue;
}

/// Marks that a save is loaded so Show / hotkeys are allowed to open the WebUI.
/// Reloads ActionCatalog so actions_index / TargetMenu / MainPanels pick up file changes.
void WebUI_SetGameReady()
{
    g_gameReady = true;
    ++g_showGeneration;
    g_showPending = false;
    if (!ActionCatalog::Load()) {
        webui_log::error("Game ready — ActionCatalog reload failed.");
    } else {
        webui_log::info("Game ready — WebUI input enabled; ActionCatalog reloaded.");
        auto panels = ActionCatalog::BuildMainPanelsCatalog();
        WebUI_Invoke("configureControlPanel(" + SafeDump(panels) + ");");
    }
}

/// Pushes the OStimNet-gated SexLab/OStim ControlPanel pulldown.
/// Prefer live ostim_player global; fall back to control store.
void WebUI_InvokeFrameworkToggle()
{
    auto* dh = RE::TESDataHandler::GetSingleton();
    const bool ostimnet = dh && dh->LookupModByName("TT_OStimNet.esp") != nullptr;
    const char* fw = SexLabNet::Config::GetSingleton().FrameworkPlayerIndex() == 1 ? "ostim" : "sexlab";
    if (auto* g = RE::TESForm::LookupByEditorID<RE::TESGlobal>("skyrimnet_sexlab_ostim_player")) {
        if (g->value == 1.0f)
            fw = "ostim";
        else if (g->value == 0.0f)
            fw = "sexlab";
    }
    WebUI_Invoke(std::string("setFrameworkToggle(") + (ostimnet ? "true" : "false") + ", '" + fw + "');");
}

/// True when the PrismaUI view exists and DomReady has fired (safe to Show/Focus).
bool WebUI_IsReady()
{
    if (!PrismaUI || !g_domReady.load())
        return false;
    return PrismaUI->IsValid(g_view);
}

/// True when some other PrismaUI view (SkyrimNet dashboard / chat, another mod) holds focus.
static bool WebUI_ForeignFocus()
{
    return PrismaUI && PrismaUI->HasAnyActiveFocus() && !PrismaUI->HasFocus(g_view);
}

namespace {

constexpr std::string_view kDashboardPath = "SkyrimNet/dashboard/index.html";
constexpr int kDeferTimeoutTicks = 12;  // 12 × 250 ms

struct ForeignView
{
    std::string path;  // relative to file:///views/
    PrismaView id;
};

/// Other mods' PrismaUI views. PrismaUI has no view list and its ids change each session, but
/// PrismaUI.log records "View [<id>] creation requested for path: file:///views/<path> ...".
/// The last id per path wins; our own views are skipped. Empty when the log is missing.
std::vector<ForeignView> ForeignViews()
{
    std::vector<ForeignView> out;
    auto dir = SKSE::log::log_directory();
    std::ifstream f;
    if (dir)
        f.open(*dir / "PrismaUI.log");
    if (!f) {
        static std::atomic<bool> warned{false};
        if (!warned.exchange(true))
            webui_log::warn("ForeignViews: PrismaUI.log not readable; other views can't be closed");
        return out;
    }
    constexpr std::string_view kId = "View [";
    constexpr std::string_view kPath = "creation requested for path: file:///views/";
    std::string line;
    while (std::getline(f, line)) {
        const auto p = line.find(kPath);
        auto i = line.find(kId);
        if (p == std::string::npos || i == std::string::npos || i > p)
            continue;
        i += kId.size();
        const auto close = line.find(']', i);
        PrismaView id = 0;
        if (close == std::string::npos ||
            std::from_chars(line.data() + i, line.data() + close, id).ptr != line.data() + close)
            continue;
        const auto ps = p + kPath.size();
        const auto pe = line.find(' ', ps);
        std::string path = line.substr(ps, pe == std::string::npos ? std::string::npos : pe - ps);
        if (id == g_view || path.starts_with("SkyrimNet_SexLab/"))
            continue;
        auto it = std::find_if(out.begin(), out.end(), [&](const ForeignView& v) { return v.path == path; });
        if (it != out.end())
            it->id = id;
        else
            out.push_back({ std::move(path), id });
    }
    return out;
}

bool DashboardOpen(const std::vector<ForeignView>& views)
{
    for (const auto& v : views)
        if (v.path == kDashboardPath)
            return PrismaUI->IsValid(v.id) && (!PrismaUI->IsHidden(v.id) || PrismaUI->HasFocus(v.id));
    return false;
}

/// SkyrimNet's own close path, so its open/closed state stays in sync. Only call when open.
void ToggleSkyrimNetDashboard()
{
    auto* vm = RE::BSScript::Internal::VirtualMachine::GetSingleton();
    if (!vm)
        return;
    RE::BSTSmartPointer<RE::BSScript::IStackCallbackFunctor> callback;
    vm->DispatchStaticCall(RE::BSFixedString("SkyrimNetApi"), RE::BSFixedString("TriggerToggleDashboard"),
                           new EmptyArgs(), callback);
}

/// Closes the SkyrimNet dashboard (via SkyrimNet) and unfocuses + hides any other focused view.
/// Unfocused overlays (HUDs, Injury Engine) are left alone.
void CloseForeignViews(const std::vector<ForeignView>& views)
{
    for (const auto& v : views) {
        if (!PrismaUI->IsValid(v.id))
            continue;
        const bool hidden = PrismaUI->IsHidden(v.id);
        const bool focus = PrismaUI->HasFocus(v.id);
        const char* action = "none";
        if (v.path == kDashboardPath) {
            if (!hidden || focus) {
                ToggleSkyrimNetDashboard();
                action = "TriggerToggleDashboard";
            }
        } else if (focus) {
            PrismaUI->Unfocus(v.id);
            PrismaUI->Hide(v.id);
            action = "Unfocus+Hide";
        }
        webui_log::info("CloseForeignViews: {} [{}] hidden={} focus={} -> {}", v.path, v.id, hidden, focus, action);
    }
}

}  // namespace

static void WebUI_ShowNow(bool showControlPanel);

/// Polls off the game thread; on the game thread, runs the held Show once other views are closed.
/// After the timeout a still-focused view gets a notification and the Show keeps waiting on focus.
static void WebUI_StartDeferredShowWatcher()
{
    const auto generation = g_showGeneration.load();
    std::thread([generation]() {
        for (int tick = 1; g_showPending.load() && g_showGeneration.load() == generation; ++tick) {
            std::this_thread::sleep_for(std::chrono::milliseconds(250));
            SKSE::GetTaskInterface()->AddTask([generation, tick]() {
                if (g_showGeneration.load() != generation || !g_showPending.load())
                    return;
                const bool focus = WebUI_ForeignFocus();
                if (focus || (tick < kDeferTimeoutTicks && DashboardOpen(ForeignViews()))) {
                    if (focus && tick == kDeferTimeoutTicks) {
                        webui_log::info("WebUI_Visibility_Show: another view still has focus after close");
                        PapyrusBindings_WebUI::HandleNotify("SexLab: request waiting - close the open menu");
                    }
                    return;
                }
                if (!g_showPending.exchange(false))
                    return;
                webui_log::info("WebUI_Visibility_Show: other views released focus, showing held overlay");
                if (g_gameReady && WebUI_IsReady())
                    WebUI_ShowNow(g_showPendingControlPanel.load());
            });
        }
    }).detach();
}

/// Shows and focuses the PrismaUI overlay after refreshing nearby actors for the menu.
/// No-ops if PrismaUI is missing, no game is loaded, DomReady has not fired, or the view is invalid.
/// Other PrismaUI views are closed first and the Show waits for them: focusing over the SkyrimNet
/// dashboard (same order 101) left the game paused with no cursor once we hid.
void WebUI_Visibility_Show(bool showControlPanel)
{
    if (!PrismaUI) return;
    if (!g_gameReady) {
        webui_log::info("WebUI blocked — no game loaded.");
        return;
    }
    if (!WebUI_IsReady()) {
        webui_log::critical(
            "WebUI_Visibility_Show: DomReady not reached (missing PrismaUI/views/SkyrimNet_SexLab/index.html?).");
        return;
    }

    if (g_showPending.load()) {
        g_showPendingControlPanel = showControlPanel;
        return;
    }
    if (const auto views = ForeignViews(); WebUI_ForeignFocus() || DashboardOpen(views)) {
        webui_log::info("WebUI_Visibility_Show deferred: closing other PrismaUI views first");
        g_showPendingControlPanel = showControlPanel;
        g_showPending = true;
        CloseForeignViews(views);
        WebUI_StartDeferredShowWatcher();
        return;
    }
    WebUI_ShowNow(showControlPanel);
}

static void WebUI_ShowNow(bool showControlPanel)
{
    PapyrusBindings_WebUI::PopulateNearbyActors();
    WebUI_InvokeFrameworkToggle();
    SexLabNet::InvokeConfigureSettingsPanel();  // AnimDB mismatch → ControlPanel Rebuild DB button

    webui_log::info("WebUI Show + Focus. anyFocus={} ourFocus={}", PrismaUI->HasAnyActiveFocus(),
                    PrismaUI->HasFocus(g_view));
    PrismaUI->Show(g_view);
    PrismaUI->Focus(g_view, true);
    KeyHandler::PromoteSink();
    g_webuiGamePaused = true;
    WebUI_Invoke("setGamePaused(true);");
    // Start / Cancel hide ControlPanel in JS. Show must restore it — same-actor
    // Target_Menu_Open used to skip showPanel and left a blank left column.
    if (showControlPanel)
        WebUI_Invoke("showControlPanel();");
    DispatchMenuNoArg("WebUI_SeedSceneInfos");
    Profiler::OnOverlayShown();
}

static void WebUI_Visibility_HideImpl(bool commit)
{
    if (commit)
        WebUI_Invoke("flushSceneInfos();");
    else
        WebUI_Invoke("discardSceneInfos();");
    WebUI_Invoke("bondageReleaseAll();");
    WebUI_Invoke("clearYesNoSolo();");
    DispatchHandlerBondageClosed();
    if (!PrismaUI) return;
    PrismaUI->Unfocus(g_view);
    PrismaUI->Hide(g_view);
    webui_log::info("WebUI Unfocus + Hide. anyFocus={}", PrismaUI->HasAnyActiveFocus());
    g_webuiGamePaused = true;
    WebUI_Invoke("setGamePaused(true);");
}

/// Unfocuses and hides the PrismaUI overlay without clearing the focus actor.
/// Commits confirmed SceneInfos, restores uncommitted ActorBondage on the handler, then drops the JS map.
void WebUI_Visibility_Hide()
{
    WebUI_Visibility_HideImpl(true);
}

/// Hide without applying SceneInfo (Cancel / Escape). Drops drafts.
void WebUI_Visibility_HideWithoutCommit()
{
    WebUI_Visibility_HideImpl(false);
}

/// True when PrismaUI is missing, the view is invalid, or the overlay is hidden.
bool WebUI_IsHidden()
{
    if (!PrismaUI || !PrismaUI->IsValid(g_view))
        return true;
    return PrismaUI->IsHidden(g_view);
}

bool WebUI_IsGamePaused()
{
    return g_webuiGamePaused.load() && !WebUI_IsHidden();
}

/// Shows the overlay if hidden, otherwise hides it.
void WebUI_Visibility_Toggle()
{
    webui_log::info("WebUI visibility toggled.");
    if (WebUI_IsHidden()) {
        WebUI_Visibility_Show();
    } else {
        WebUI_Visibility_Hide();
    }
}

/// Runs a JS snippet on the WebUI view, or queues it until DomReady.
/// Early invokes before the HTML loads are flushed by FlushPendingInvokes.
void WebUI_Invoke(const std::string& script)
{
    if (!PrismaUI) return;

    // Queue until DomReady — CreateView callbacks may not have run yet.
    if (!g_domReady.load()) {
        std::scoped_lock lock(g_invokeMutex);
        g_pendingInvokes.push_back(script);
        return;
    }

    PrismaUI->Invoke(g_view, script.c_str());
}

void WebUI_InteropCall(const char* functionName, const std::string& jsonArgument)
{
    if (!functionName || !*functionName)
        return;
    const std::string quoted = SafeDump(nlohmann::json(jsonArgument));
    WebUI_Invoke(std::string(functionName) + "(JSON.parse(" + quoted + "));");
}

/// Drains the DomReady queue and Invokes each pending script on the live view.
static void FlushPendingInvokes()
{
    std::deque<std::string> pending;
    {
        std::scoped_lock lock(g_invokeMutex);
        pending.swap(g_pendingInvokes);
    }
    if (!PrismaUI) return;
    for (const auto& script : pending) {
        PrismaUI->Invoke(g_view, script.c_str());
    }
    if (!pending.empty()) {
        webui_log::info("Flushed {} queued WebUI Invoke(s) after DomReady.", pending.size());
    }
}

/// Hides all menu panels in JS and closes the overlay.
void WebUI_Reset()
{
    ActionCatalog::ClearMainPanelSelection();
    WebUI_Invoke("hidePanel('control_panel');");
    WebUI_Invoke("hidePanel('target_menu_panel');");
    WebUI_Invoke("hidePanel('sex_menu_panel');");
    WebUI_Invoke("hidePanel('yesno_panel');");
    WebUI_Invoke("hidePanel('scene_creator_panel');");
    WebUI_Invoke("hidePanel('description_editor_panel');");
    WebUI_Visibility_Hide();
}

/// Clears the current target actor and resets panels / visibility to a closed UI.
void Reset_To_Default()
{
    PapyrusBindings_WebUI::ClearTargetMenuSession();
    WebUI_Reset();
}

namespace {

/// A potion offered to the player (drink): waiting for the Yes / No dialogue. Game thread only; one at a time.
struct AidOffer
{
    std::uint64_t token = 0;
    RE::FormID giver = 0;
    RE::FormID receiver = 0;
    RE::FormID form = 0;
    std::string location;
};
AidOffer g_aidOffer;
std::uint64_t g_aidOfferNext = 0;

/// Game thread. The receiver took (Aid::Apply) or refused the potion: "Amy refused Bob's stamina potion." is kept as
/// a punish reason and the potion stays with the giver. A HUD Aid result: either line is NarratePlayer'd.
void AidFinishConsent(RE::FormID giverId, RE::FormID receiverId, RE::FormID form, const std::string& location,
    bool accepted)
{
    auto* giver = RE::TESForm::LookupByID<RE::Actor>(giverId);
    auto* receiver = RE::TESForm::LookupByID<RE::Actor>(receiverId);
    if (!giver || !receiver)
        return;
    if (!accepted) {
        const std::string reason = Aid::RefusalReason(giver, receiver, form);
        if (reason.empty())
            return;
        OrgasmEngine::NarratePlayer(reason + ".", receiver, giver);
        OrgasmEngine::AddPunishReason(giver, receiver, reason);
        return;
    }
    const std::string line = Aid::Apply(giver, receiver, form, location, nullptr, true);
    OrgasmEngine::NarratePlayer(line, giver, receiver);
}

/// Game thread. Drink / lips on someone else (Aid::NeedsConsent): the player answers a Yes / No dialogue (drink);
/// an NPC asks the decision model (StrategyDecision::RequestAidAccept). Lips on the player needs no answer.
void AidAskConsent(RE::Actor* giver, RE::Actor* receiver, RE::FormID form, const std::string& location)
{
    std::string name;
    std::string kind;
    if (!Aid::PotionInfo(giver, form, name, kind))
        return;
    const RE::FormID giverId = giver->GetFormID();
    const RE::FormID receiverId = receiver->GetFormID();
    if (receiver->IsPlayerRef()) {
        if (location != "drink") {
            AidFinishConsent(giverId, receiverId, form, location, true);
            return;
        }
        g_aidOffer = { ++g_aidOfferNext, giverId, receiverId, form, location };
        const char* who = giver->GetDisplayFullName();
        nlohmann::json cfg;
        cfg["token"] = g_aidOffer.token;
        cfg["question"] = std::string(who ? who : "Someone") + " offers you a " + kind + " potion (" + name +
                          "). Drink it?";
        webui_log::info("Aid offer {} to the player: {:#x} '{}'", g_aidOffer.token, giverId, name);
        WebUI_Invoke("openAidOffer(" + cfg.dump(-1, ' ', false, nlohmann::json::error_handler_t::replace) + ");");
        WebUI_Visibility_Show(false);
        return;
    }
    StrategyDecision::RequestAidAccept(receiverId, giverId, location, kind, name,
        [giverId, receiverId, form, location](bool accepted) {
            AidFinishConsent(giverId, receiverId, form, location, accepted);
        });
}

}  // namespace

/// One-shot WebUI bootstrap: PrismaUI API, action catalog, view, JS listeners, hotkeys.
/// View path must exist under Data/PrismaUI/views/SkyrimNet_SexLab/index.html.
/// Escape hides UI; menu hotkey toggles ControlPanel (hide if visible, else ProcessHotkey).
void InitWebUI()
{
    static std::once_flag s_initFlag;
    std::call_once(s_initFlag, []() {

        PrismaUI = static_cast<PRISMA_UI_API::IVPrismaUI1*>(
            PRISMA_UI_API::RequestPluginAPI(PRISMA_UI_API::InterfaceVersion::V1));

        if (!PrismaUI) {
            webui_log::critical("Failed to acquire PrismaUI API.");
            return;
        }
        webui_log::info("PrismaUI API acquired successfully.");

        ActionCatalog::Load();

        g_domReady = false;
        // Resolves under Data/PrismaUI/views/, not SKSE/Plugins/.
        g_view = PrismaUI->CreateView("SkyrimNet_SexLab/index.html", [](PrismaView view) {
            g_view = view;
            g_domReady = true;
            webui_log::info("WebUI DomReady.");
            FlushPendingInvokes();
            RunGuarded("DomReady", [] {
                if (ActionCatalog::IsLoaded()) {
                    auto panels = ActionCatalog::BuildMainPanelsCatalog();
                    WebUI_Invoke("configureControlPanel(" + SafeDump(panels) + ");");
                }
            });
        });

        if (!PrismaUI->IsValid(g_view)) {
            webui_log::critical(
                "CreateView returned invalid view — ensure Data/PrismaUI/views/SkyrimNet_SexLab/index.html exists.");
        }

        PrismaUI->Hide(g_view);

        PrismaUI->RegisterJSListener(g_view, "onCancel", [](const char*) {
            RunGuarded("onCancel", [&] {
                WebUI_Invoke("hidePanel('target_menu_panel');");
                PapyrusBindings_WebUI::ClearTargetMenuSession();
                WebUI_Visibility_HideWithoutCommit();
            });
        });

        PrismaUI->RegisterJSListener(g_view, "onYesNoResult", [](const char* value) {
            RunGuarded("onYesNoResult", [&] {
                if (!value)
                    return;
                try {
                    auto j = nlohmann::json::parse(value);
                    const int button = j.value("button", 2);
                    const int creator_sid = j.value("creator_sid", PapyrusBindings_WebUI::YesNo_Creator_Sid);
                    const std::string reason = j.value("reason", std::string{});
                    const bool wasOpen = PapyrusBindings_WebUI::YesNo_OverlayWasOpen;
                    webui_log::info("onYesNoResult button={} creator_sid={} was_open={}", button, creator_sid, wasOpen);
                    // Yes (0) with the WebUI closed: JS keeps the dialogue as a placeholder until SceneCreator_Open.
                    if (button != 0 || wasOpen)
                        WebUI_Invoke("hidePanel('yesno_panel');");
                    // Random/No/explain close the overlay only if YesNo_Open opened it; an open WebUI stays as it was.
                    if (button != 0 && !wasOpen)
                        WebUI_Visibility_HideWithoutCommit();
                    if (button == 4)
                        PapyrusBindings_WebUI::DispatchManagerMethodIntStr("WebUI_OnYesNoExplain", creator_sid, reason);
                    else
                        PapyrusBindings_WebUI::DispatchManagerMethodIntInt("WebUI_OnYesNoResult", creator_sid, button);
                } catch (...) {
                    webui_log::warn("onYesNoResult: bad JSON");
                }
            });
        });

        // Ask / Order / Punish panel (HUD punish key): {cancel} or {verb, subject, object, ...}. verb "ask" | "order":
        // request (a request key) or text (free phrase). verb "punish": method, location, reason. The engine narrates
        // (source the subject, target the object; SkyrimNet picks who answers).
        PrismaUI->RegisterJSListener(g_view, "onPunishResult", [](const char* value) {
            RunGuarded("onPunishResult", [&] {
                WebUI_Invoke("hidePunishPanel();");
                WebUI_Visibility_HideWithoutCommit();
                if (!value)
                    return;
                try {
                    auto j = nlohmann::json::parse(value);
                    if (j.value("cancel", false))
                        return;
                    const std::string verb = j.value("verb", std::string("punish"));
                    const auto subject = j.value("subject", static_cast<RE::FormID>(0));
                    const auto object = j.value("object", static_cast<RE::FormID>(0));
                    const std::string request = j.value("request", std::string{});
                    const std::string text = j.value("text", std::string{});
                    const std::string method = j.value("method", std::string{});
                    const std::string location = j.value("location", std::string{});
                    const std::string reason = j.value("reason", std::string{});
                    const std::int32_t amount = j.value("amount", 1);
                    webui_log::info("onPunishResult verb={} subject={:#x} object={:#x} request='{}' text='{}' "
                                    "method='{}' location='{}' reason='{}' amount={}",
                        verb, subject, object, request, text, method, location, reason, amount);
                    SKSE::GetTaskInterface()->AddTask(
                        [verb, subject, object, request, text, method, location, reason, amount]() {
                            RE::Actor* by = RE::TESForm::LookupByID<RE::Actor>(subject);
                            // The player's own act: speech queue purged, always a DirectNarration.
                            if (verb == "punish")
                                OrgasmEngine::PunishNarrated(by, object, method, location, reason, amount, true);
                            else
                                OrgasmEngine::AskOrderNarrated(by, object, verb == "order", request, text, true);
                        });
                } catch (...) {
                    webui_log::warn("onPunishResult: bad JSON");
                }
            });
        });

        // Punish / Aid part pulldown: the player agreed to turn on Injury Engine's sexual body parts.
        PrismaUI->RegisterJSListener(g_view, "onInjuryEngineSexualParts", [](const char*) {
            RunGuarded("onInjuryEngineSexualParts", [&] {
                SKSE::GetTaskInterface()->AddTask([]() { InjuryEngine::EnableSexualParts(); });
            });
        });

        PrismaUI->RegisterJSListener(g_view, "onAidResult", [](const char* value) {
            RunGuarded("onAidResult", [&] {
                WebUI_Invoke("hideAidPanel();");
                WebUI_Visibility_HideWithoutCommit();
                if (!value)
                    return;
                try {
                    auto j = nlohmann::json::parse(value);
                    if (j.value("cancel", false))
                        return;
                    const auto target = j.value("target", static_cast<RE::FormID>(0));
                    const auto option = j.value("option", static_cast<RE::FormID>(0));
                    const auto subject = j.value("subject", static_cast<RE::FormID>(0));
                    const std::string location = j.value("location", std::string{});
                    const float points = j.value("points", 0.0f);
                    webui_log::info("onAidResult subject={:#x} target={:#x} option={:#x} location='{}' points={:.0f}",
                        subject, target, option, location, points);
                    // Inventory and spell lists are read on the game thread.
                    SKSE::GetTaskInterface()->AddTask([subject, target, option, location, points]() {
                        auto* caster = subject ? RE::TESForm::LookupByID<RE::Actor>(subject)
                                               : static_cast<RE::Actor*>(RE::PlayerCharacter::GetSingleton());
                        auto* actor = RE::TESForm::LookupByID<RE::Actor>(target);
                        if (Aid::NeedsConsent(caster, actor, option, location)) {
                            AidAskConsent(caster, actor, option, location);
                            return;
                        }
                        // The player's own act: Injury Engine heals silently; speech queue purged, DirectNarration.
                        const std::string line = Aid::StartChannel(caster, actor, option, location, points, nullptr, true);
                        OrgasmEngine::NarratePlayer(line, caster, actor);
                    });
                } catch (...) {
                    webui_log::warn("onAidResult: bad JSON");
                }
            });
        });

        // Aid offer dialogue (openAidOffer): the player answered an NPC's potion offer.
        PrismaUI->RegisterJSListener(g_view, "onAidOfferResult", [](const char* value) {
            RunGuarded("onAidOfferResult", [&] {
                WebUI_Invoke("hideAidOffer();");
                WebUI_Visibility_HideWithoutCommit();
                if (!value)
                    return;
                try {
                    auto j = nlohmann::json::parse(value);
                    const auto token = j.value("token", std::uint64_t{ 0 });
                    const bool accept = j.value("accept", false);
                    webui_log::info("onAidOfferResult token={} accept={}", token, accept);
                    SKSE::GetTaskInterface()->AddTask([token, accept]() {
                        if (token == 0 || token != g_aidOffer.token) {
                            webui_log::warn("onAidOfferResult: stale offer {}", token);
                            return;
                        }
                        const AidOffer offer = std::exchange(g_aidOffer, AidOffer{});
                        AidFinishConsent(offer.giver, offer.receiver, offer.form, offer.location, accept);
                    });
                } catch (...) {
                    webui_log::warn("onAidOfferResult: bad JSON");
                }
            });
        });

        PrismaUI->RegisterJSListener(g_view, "onSceneCreatorResult", [](const char* value) {
            RunGuarded("onSceneCreatorResult", [&] {
                if (!value)
                    return;
                try {
                    auto j = nlohmann::json::parse(value);
                    const std::string action = j.value("_action", "cancel");
                    const int creator_sid = j.value("_creator_sid", -1);
                    // creator_sid 0 is a valid pool slot — only _from_target_menu marks the C++ provisional path.
                    const bool fromTargetMenu = j.value("_from_target_menu", false);
                    webui_log::info("onSceneCreatorResult action={} creator_sid={} fromTargetMenu={}", action,
                        creator_sid, fromTargetMenu);
                    WebUI_Invoke("hidePanel('scene_creator_panel');");
                    PapyrusBindings_WebUI::ClearSceneCreatorPending();
                    if (action == "start") {
                        WebUI_Invoke("hidePanel('target_menu_panel');");
                        WebUI_Invoke("hidePanel('control_panel');");
                        PapyrusBindings_WebUI::ClearTargetMenuSession();
                        WebUI_Visibility_Hide();
                        if (fromTargetMenu) {
                            j["_from_target_menu"] = true;
                            PapyrusBindings_WebUI::DispatchManagerMethodStrOnly("WebUI_OnSceneCreatorHandoff", SafeDump(j));
                        } else {
                            PapyrusBindings_WebUI::DispatchManagerMethodIntStr("WebUI_OnSceneCreatorResult", creator_sid,
                                SafeDump(j));
                        }
                    } else {
                        // "close" = main-panel Close on Scene Creator; "cancel" (Escape on a Papyrus creator) keeps the flag.
                        if (action == "close")
                            ActionCatalog::SetShowScenePanel(false);
                        if (!PapyrusBindings_WebUI::TargetMenuSessionActive)
                            WebUI_Visibility_HideWithoutCommit();
                        if (fromTargetMenu) {
                            webui_log::info("onSceneCreatorResult: target-menu cancel");
                        } else {
                            PapyrusBindings_WebUI::DispatchManagerMethodIntStr("WebUI_OnSceneCreatorResult", creator_sid,
                                "{\"_action\":\"cancel\"}");
                        }
                    }
                } catch (...) {
                    webui_log::warn("onSceneCreatorResult: bad JSON");
                }
            });
        });

        // Main-panel Close on the Description Editor side of the Scene view: stop the Scene view from
        // auto-opening. JS then selects ControlPanel None (onMainPanelChange ''); the overlay stays open.
        // DEBUG-DELETE: temporary JS -> SkyrimNet_SexLab.log bridge (deDbg in index.html).
        PrismaUI->RegisterJSListener(g_view, "onDebugLog", [](const char* value) {
            webui_log::info("[JS DEBUG] {}", value ? value : "");
        });
        // DEBUG-DELETE end

        PrismaUI->RegisterJSListener(g_view, "onScenePanelClose", [](const char*) {
            RunGuarded("onScenePanelClose", [&] {
                ActionCatalog::SetShowScenePanel(false);
            });
        });

        PrismaUI->RegisterJSListener(g_view, "onSceneCreatorLoad", [](const char* value) {
            RunGuarded("onSceneCreatorLoad", [&] {
                if (!value)
                    return;
                try {
                    auto j = nlohmann::json::parse(value);
                    const int creator_sid = j.value("_creator_sid", -1);
                    const std::string name = j.value("_scene_preset", "");
                    webui_log::info("onSceneCreatorLoad creator_sid={} preset={}", creator_sid, name);
                    PapyrusBindings_WebUI::DispatchManagerMethodIntStr("WebUI_OnSceneCreatorLoad", creator_sid, name);
                } catch (...) {
                    webui_log::warn("onSceneCreatorLoad: bad JSON");
                }
            });
        });

        PrismaUI->RegisterJSListener(g_view, "onSceneCreatorSave", [](const char* value) {
            RunGuarded("onSceneCreatorSave", [&] {
                if (!value)
                    return;
                try {
                    auto j = nlohmann::json::parse(value);
                    const int creator_sid = j.value("_creator_sid", -1);
                    webui_log::info("onSceneCreatorSave creator_sid={}", creator_sid);
                    PapyrusBindings_WebUI::DispatchManagerMethodIntStr("WebUI_OnSceneCreatorSave", creator_sid, SafeDump(j));
                } catch (...) {
                    webui_log::warn("onSceneCreatorSave: bad JSON");
                }
            });
        });

        PrismaUI->RegisterJSListener(g_view, "onAnimationMenuClose", [](const char* value) {
            RunGuarded("onAnimationMenuClose", [&] {
                if (!value)
                    return;
                try {
                    auto j = nlohmann::json::parse(value);
                    const int scene_sid = j.value("_scene_sid", -1);
                    webui_log::info("onAnimationMenuClose scene_sid={}", scene_sid);
                    WebUI_Invoke("hidePanel('description_editor_panel');");
                    WebUI_Visibility_Hide();
                    PapyrusBindings_WebUI::DispatchManagerMethodIntStr("WebUI_OnAnimationMenuClose", scene_sid, SafeDump(j));
                } catch (...) {
                    webui_log::warn("onAnimationMenuClose: bad JSON");
                }
            });
        });

        PrismaUI->RegisterJSListener(g_view, "onAnimationMenuLiveUpdate", [](const char* value) {
            RunGuarded("onAnimationMenuLiveUpdate", [&] {
                if (!value)
                    return;
                try {
                    auto j = nlohmann::json::parse(value);
                    const int scene_sid = j.value("_scene_sid", -1);
                    PapyrusBindings_WebUI::DispatchManagerMethodIntStr("WebUI_OnAnimationMenuLiveUpdate", scene_sid, SafeDump(j));
                } catch (...) {
                    webui_log::warn("onAnimationMenuLiveUpdate: bad JSON");
                }
            });
        });

        PrismaUI->RegisterJSListener(g_view, "onAnimationMenuPrevNext", [](const char* value) {
            RunGuarded("onAnimationMenuPrevNext", [&] {
                if (!value)
                    return;
                try {
                    auto j = nlohmann::json::parse(value);
                    const int scene_sid = j.value("_scene_sid", -1);
                    const int direction = j.value("_direction", 0);
                    webui_log::info("onAnimationMenuPrevNext scene_sid={} direction={}", scene_sid, direction);
                    PapyrusBindings_WebUI::DispatchManagerMethodIntInt("WebUI_OnAnimationMenuPrevNext", scene_sid,
                        direction);
                } catch (...) {
                    webui_log::warn("onAnimationMenuPrevNext: bad JSON");
                }
            });
        });

        PrismaUI->RegisterJSListener(g_view, "onAnimationMenuStop", [](const char* value) {
            RunGuarded("onAnimationMenuStop", [&] {
                if (!value)
                    return;
                try {
                    auto j = nlohmann::json::parse(value);
                    const int scene_sid = j.value("_scene_sid", -1);
                    webui_log::info("onAnimationMenuStop scene_sid={}", scene_sid);
                    WebUI_Invoke("hidePanel('description_editor_panel');");
                    WebUI_Visibility_Hide();
                    PapyrusBindings_WebUI::DispatchManagerMethodIntInt("WebUI_OnAnimationMenuStop", scene_sid, 0);
                } catch (...) {
                    webui_log::warn("onAnimationMenuStop: bad JSON");
                }
            });
        });

        PrismaUI->RegisterJSListener(g_view, "onSceneConnectionChange", [](const char* value) {
            RunGuarded("onSceneConnectionChange", [&] {
                if (!value)
                    return;
                try {
                    auto j = nlohmann::json::parse(value);
                    webui_log::info("onSceneConnectionChange {}", SafeDump(j));
                    PapyrusBindings_WebUI::DispatchManagerMethodStrOnly("WebUI_OnSceneConnectionChange", SafeDump(j));
                } catch (...) {
                    webui_log::warn("onSceneConnectionChange: bad JSON");
                }
            });
        });

        PrismaUI->RegisterJSListener(g_view, "onSceneConnectionsRefresh", [](const char* value) {
            RunGuarded("onSceneConnectionsRefresh", [&] {
                PapyrusBindings_WebUI::DispatchManagerMethodStrOnly("WebUI_OnSceneConnectionsRefresh",
                    value ? value : "{}");
            });
        });

        PrismaUI->RegisterJSListener(g_view, "onSceneAnimUpdate", [](const char* value) {
            RunGuarded("onSceneAnimUpdate", [&] {
                if (!value)
                    return;
                try {
                    auto j = nlohmann::json::parse(value);
                    const int scene_sid = j.value("_scene_sid", -1);
                    webui_log::info("onSceneAnimUpdate scene_sid={}", scene_sid);
                    PapyrusBindings_WebUI::DispatchManagerMethodIntStr("WebUI_OnSceneAnimUpdate", scene_sid, SafeDump(j));
                } catch (...) {
                    webui_log::warn("onSceneAnimUpdate: bad JSON");
                }
            });
        });

        PrismaUI->RegisterJSListener(g_view, "onAnimRegistrySave", [](const char* value) {
            RunGuarded("onAnimRegistrySave", [&] {
                if (!value)
                    return;
                try {
                    auto j = nlohmann::json::parse(value);
                    webui_log::info("onAnimRegistrySave registry={}", j.value("_registry", ""));
                    PapyrusBindings_WebUI::DispatchManagerMethodStrOnly("WebUI_OnAnimRegistrySave", SafeDump(j));
                } catch (...) {
                    webui_log::warn("onAnimRegistrySave: bad JSON");
                }
            });
        });

        PrismaUI->RegisterJSListener(g_view, "onAnimDbQuery", [](const char* value) {
            RunGuarded("onAnimDbQuery", [&] {
                PapyrusBindings_WebUI::HandleAnimDbQuery(value);
            });
        });

        PrismaUI->RegisterJSListener(g_view, "onAnimFavoriteSet", [](const char* value) {
            RunGuarded("onAnimFavoriteSet", [&] {
                if (!value)
                    return;
                try {
                    auto j = nlohmann::json::parse(value);
                    const std::string reg = j.value("_registry", "");
                    if (!AnimationDB::SetFavorite(reg, j.value("_favorite", false)))
                        webui_log::warn("onAnimFavoriteSet: failed for '{}'", reg);
                } catch (...) {
                    webui_log::warn("onAnimFavoriteSet: bad JSON");
                }
            });
        });

        PrismaUI->RegisterJSListener(g_view, "onAnimDbResolveTags", [](const char* value) {
            RunGuarded("onAnimDbResolveTags", [&] {
                PapyrusBindings_WebUI::HandleAnimDbResolveTags(value);
            });
        });

        PrismaUI->RegisterJSListener(g_view, "onResolveDeviousTags", [](const char* value) {
            RunGuarded("onResolveDeviousTags", [&] {
                PapyrusBindings_WebUI::HandleResolveDeviousTags(value);
            });
        });
        PrismaUI->RegisterJSListener(g_view, "onNotify", [](const char* value) {
            RunGuarded("onNotify", [&] {
                PapyrusBindings_WebUI::HandleNotify(value);
            });
        });
        PrismaUI->RegisterJSListener(g_view, "onPapyrusQuery", [](const char* value) {
            RunGuarded("onPapyrusQuery", [&] {
                PapyrusBindings_WebUI::HandlePapyrusQuery(value);
            });
        });

        PrismaUI->RegisterJSListener(g_view, "onNearbyRangeChange", [](const char* value) {
            RunGuarded("onNearbyRangeChange", [&] {
                if (!value)
                    return;
                float range = 100.f;
                try {
                    auto j = nlohmann::json::parse(value);
                    if (j.is_object() && j.contains("_range") && j["_range"].is_number())
                        range = j["_range"].get<float>();
                    else if (j.is_number())
                        range = j.get<float>();
                } catch (...) {
                    try {
                        range = std::stof(value);
                    } catch (...) {
                        webui_log::warn("onNearbyRangeChange: bad payload {}", value);
                        return;
                    }
                }
                if (!PapyrusBindings_WebUI::SetNearbyRadius(range)) {
                    webui_log::warn("onNearbyRangeChange: invalid range {}", range);
                    return;
                }
                webui_log::info("onNearbyRangeChange range={}", PapyrusBindings_WebUI::GetNearbyRadius());
                PapyrusBindings_WebUI::PopulateNearbyActors(PapyrusBindings_WebUI::GetNearbyRadius());
            });
        });

        PrismaUI->RegisterJSListener(g_view, "onResolveActorMeta", [](const char* value) {
            RunGuarded("onResolveActorMeta", [&] {
                if (!value)
                    return;
                try {
                    auto j = nlohmann::json::parse(value);
                    PapyrusBindings_WebUI::DispatchManagerMethodStrOnly("WebUI_OnResolveActorMeta", SafeDump(j));
                } catch (...) {
                    webui_log::warn("onResolveActorMeta: bad JSON");
                }
            });
        });

        // JS "start" → Scene Creator (Tag Edit) or ActionCatalog::ExecuteAction.
        PrismaUI->RegisterJSListener(g_view, "onAction", [](const char* value) {
            RunGuarded("onAction", [&] {
                if (!value) return;

                auto* target = PapyrusBindings_WebUI::TargetCurrent();
                auto* player = RE::PlayerCharacter::GetSingleton();
                std::string payloadStr(value);

                nlohmann::json payload;
                try {
                    payload = nlohmann::json::parse(payloadStr);
                } catch (...) {
                    webui_log::warn("onAction: non-JSON payload ignored: {}", payloadStr);
                    return;
                }

                const std::string action = payload.value("action", "");
                const std::string name = payload.value("name", "");
                nlohmann::json params = payload.value("parameters", nlohmann::json::object());

                if (action == "custom") {
                    webui_log::info("onAction custom name={}", name);
                    if (!ActionCatalog::OpenSceneCreatorFromTargetMenu(name, params, player, target)) {
                        webui_log::error("onAction: OpenSceneCreatorFromTargetMenu failed for {}", name);
                    }
                    return;
                }

                if (action == "papyrus") {
                    webui_log::info("onAction papyrus label={}", payload.value("label", ""));
                    nlohmann::json opt = payload;
                    if (!opt.contains("parameters"))
                        opt["parameters"] = params;
                    // SceneStartPanel Start: player already clicked Start — skip YesNo / Scene Creator.
                    const std::string papyrusFn = payload.value("executionFunctionName", "");
                    const bool skipSceneCreator = payload.value("closeWebUI", false)
                        && ActionCatalog::IsSceneStartExecution(papyrusFn);
                    if (skipSceneCreator)
                        PapyrusBindings_WebUI::SkipSceneCreatorOnce = true;
                    bool ok = ActionCatalog::ExecutePapyrusOption(opt, player, target);
                    if (!ok) {
                        webui_log::error("onAction: ExecutePapyrusOption failed");
                        PapyrusBindings_WebUI::SkipSceneCreatorOnce = false;
                    }
                    // Stay open for live panels unless payload requests close.
                    if (payload.value("closeWebUI", false)) {
                        WebUI_Invoke("hidePanel('target_menu_panel');");
                        WebUI_Invoke("hidePanel('control_panel');");
                        PapyrusBindings_WebUI::ClearTargetMenuSession();
                        WebUI_Visibility_Hide();
                    }
                    return;
                }

                if (action != "start") {
                    webui_log::info("onAction: ignoring action={}", action);
                    return;
                }

                webui_log::info("onAction start name={}", name);

                // TargetMenu Start always ExecuteAction; skip Scene Creator only for scene-start actions.
                if (ActionCatalog::ShouldOpenSceneCreatorFromTargetMenu(
                        name, params, player, target, true, true)) {
                    PapyrusBindings_WebUI::SkipSceneCreatorOnce = true;
                }

                // Commit SceneInfos first (queued), then close overlay so StartThread runs unpaused.
                WebUI_Invoke("hidePanel('target_menu_panel');");
                PapyrusBindings_WebUI::ClearTargetMenuSession();
                WebUI_Visibility_Hide();
                bool ok = ActionCatalog::ExecuteAction(name, params, player, target);
                if (!ok) {
                    webui_log::error("onAction: ExecuteAction failed for {}", name);
                    PapyrusBindings_WebUI::SkipSceneCreatorOnce = false;
                }
            });
        });

        PrismaUI->RegisterJSListener(g_view, "onSceneInfoCommit", [](const char* value) {
            RunGuarded("onSceneInfoCommit", [&] {
                if (!value)
                    return;
                webui_log::info("onSceneInfoCommit bytes={}", std::strlen(value));
                PapyrusBindings_WebUI::DispatchManagerMethodStrOnly("WebUI_OnSceneInfoCommit", value);
            });
        });

        PrismaUI->RegisterJSListener(g_view, "onWebUIHide", [](const char* value) {
            RunGuarded("onWebUIHide", [&] {
                bool commit = true;
                // endSession (Escape): also end the TargetMenu session, like Cancel, but still commit.
                bool endSession = false;
                if (value) {
                    try {
                        auto j = nlohmann::json::parse(value);
                        commit = j.value("commit", true);
                        endSession = j.value("endSession", false);
                    } catch (...) {
                    }
                }
                webui_log::info("onWebUIHide commit={} endSession={}", commit, endSession);
                if (endSession) {
                    WebUI_Invoke("hidePanel('target_menu_panel');");
                    PapyrusBindings_WebUI::ClearTargetMenuSession();
                }
                if (commit)
                    WebUI_Visibility_Hide();
                else
                    WebUI_Visibility_HideWithoutCommit();
            });
        });

        PrismaUI->RegisterJSListener(g_view, "onGamePauseSet", [](const char* value) {
            RunGuarded("onGamePauseSet", [&] {
                const bool paused = !value || value[0] != '0';
                webui_log::info("onGamePauseSet paused={}", paused);
                g_webuiGamePaused = paused;
                if (PrismaUI && PrismaUI->IsValid(g_view) && !PrismaUI->IsHidden(g_view)) {
                    // A repeat Focus while already focused does not change the pause state; re-focus from scratch.
                    PrismaUI->Unfocus(g_view);
                    const bool ok = PrismaUI->Focus(g_view, paused);
                    KeyHandler::PromoteSink();
                    webui_log::info("onGamePauseSet Focus(pause={}) ok={} hasFocus={}", paused, ok,
                                    PrismaUI->HasFocus(g_view));
                }
            });
        });

        PrismaUI->RegisterJSListener(g_view, "onSceneNarrate", [](const char* value) {
            RunGuarded("onSceneNarrate", [&] {
                if (!value)
                    return;
                try {
                    auto j = nlohmann::json::parse(value);
                    const int scene_sid = j.value("_scene_sid", -1);
                    webui_log::info("onSceneNarrate scene_sid={}", scene_sid);
                    PapyrusBindings_WebUI::DispatchManagerMethodIntStr("WebUI_OnSceneNarrate", scene_sid, SafeDump(j));
                } catch (...) {
                    webui_log::warn("onSceneNarrate: bad JSON");
                }
            });
        });

        PrismaUI->RegisterJSListener(g_view, "onControlActorChange", [](const char* value) {
            RunGuarded("onControlActorChange", [&] {
                if (!value)
                    return;
                webui_log::info("onControlActorChange payload");
                PapyrusBindings_WebUI::ApplyControlActorFocusJson(value);
            });
        });

        PrismaUI->RegisterJSListener(g_view, "onControlModeChange", [](const char* value) {
            RunGuarded("onControlModeChange", [&] {
                if (!value)
                    return;
                try {
                    auto j = nlohmann::json::parse(value);
                    const std::string id = j.value("id", "");
                    webui_log::info("onControlModeChange id={}", id);
                    ActionCatalog::SwitchControlMode(id);
                } catch (...) {
                    webui_log::info("onControlModeChange id={}", value);
                    ActionCatalog::SwitchControlMode(value);
                }
            });
        });

        PrismaUI->RegisterJSListener(g_view, "onMainPanelRow", [](const char* value) {
            RunGuarded("onMainPanelRow", [&] {
                if (!value)
                    return;
                webui_log::info("onMainPanelRow");
                PapyrusBindings_WebUI::ApplyMainPanelRow(value);
            });
        });

        PrismaUI->RegisterJSListener(g_view, "onMainPanelChange", [](const char* value) {
            RunGuarded("onMainPanelChange", [&] {
                if (!value)
                    return;
                try {
                    auto j = nlohmann::json::parse(value);
                    const std::string key = j.value("key", "");
                    webui_log::info("onMainPanelChange key={}", key);
                    ActionCatalog::SwitchMainPanel(key);
                } catch (...) {
                    // Plain string key
                    webui_log::info("onMainPanelChange key={}", value);
                    ActionCatalog::SwitchMainPanel(value);
                }
            });
        });

        PrismaUI->RegisterJSListener(g_view, "onFrameworkChange", [](const char* value) {
            RunGuarded("onFrameworkChange", [&] {
                if (!value) return;
                auto* global = RE::TESForm::LookupByEditorID<RE::TESGlobal>("skyrimnet_sexlab_ostim_player");
                if (!global) {
                    webui_log::error("Could not find global skyrimnet_sexlab_ostim_player");
                    return;
                }
                if (std::string_view(value) == "ostim") {
                    global->value = 1.0f;
                    webui_log::info("Framework set to OStim");
                } else {
                    global->value = 0.0f;
                    webui_log::info("Framework set to SexLab");
                }
            });
        });

        PrismaUI->RegisterJSListener(g_view, "onSettingsRebuild", [](const char*) {
            RunGuarded("onSettingsRebuild", [&] {
                webui_log::info("onSettingsRebuild");
                // Close the WebUI so the game unpauses and the cooperative walk runs.
                ActionCatalog::ClearMainPanelSelection();
                WebUI_Invoke("hidePanel('target_menu_panel');");
                WebUI_Invoke("hidePanel('sex_menu_panel');");
                WebUI_Invoke("hidePanel('yesno_panel');");
                PapyrusBindings_WebUI::ClearTargetMenuSession();
                WebUI_Visibility_Hide();
                Call_RebuildAnimDb();
            });
        });

        PrismaUI->RegisterJSListener(g_view, "onAnimEngineDebug", [](const char* value) {
            RunGuarded("onAnimEngineDebug", [&] {
                if (value)
                    AnimEngineDebug(value);
            });
        });

        PrismaUI->RegisterJSListener(g_view, "onSettingsOpenSkyrimNet", [](const char*) {
            RunGuarded("onSettingsOpenSkyrimNet", [&] {
                webui_log::info("onSettingsOpenSkyrimNet");
                Call_OpenSkyrimNetDashboard();
            });
        });

        PrismaUI->RegisterJSListener(g_view, "onSettingsRefresh", [](const char*) {
            RunGuarded("onSettingsRefresh", [&] {
                SexLabNet::InvokeConfigureSettingsPanel();
            });
        });

        // Profile panel (Profiler state machine is the only writer; wrong-state presses are no-ops).
        PrismaUI->RegisterJSListener(g_view, "onProfileStartCalibration", [](const char*) {
            RunGuarded("onProfileStartCalibration", [&] { Profiler::StartCalibration(); });
        });

        PrismaUI->RegisterJSListener(g_view, "onProfileStartProfiling", [](const char*) {
            RunGuarded("onProfileStartProfiling", [&] { Profiler::StartProfiling(); });
        });

        PrismaUI->RegisterJSListener(g_view, "onProfileCancel", [](const char*) {
            RunGuarded("onProfileCancel", [&] { Profiler::Cancel(); });
        });

        PrismaUI->RegisterJSListener(g_view, "onProfileStop", [](const char*) {
            RunGuarded("onProfileStop", [&] { Profiler::Stop(); });
        });

        PrismaUI->RegisterJSListener(g_view, "onProfileNote", [](const char* value) {
            RunGuarded("onProfileNote", [&] { Profiler::Note(value ? value : ""); });
        });

        PrismaUI->RegisterJSListener(g_view, "onLogPanelOpen", [](const char*) {
            RunGuarded("onLogPanelOpen", [&] {
                SexLabNet::InvokeLogPanelOpen();
            });
        });

        PrismaUI->RegisterJSListener(g_view, "onLogPoll", [](const char*) {
            RunGuarded("onLogPoll", [&] {
                SexLabNet::PushLogPanelPoll();
            });
        });

        KeyHandler::RegisterSink();
        KeyHandler::GetSingleton()->Register(0x01 /* escape */, []() {
            if (!g_domReady.load()) {
                webui_log::info("Escape: DomReady missing — Unfocus/Hide");
                WebUI_Visibility_HideWithoutCommit();
                return;
            }
            webui_log::info("Escape key pressed.");
            WebUI_Invoke("handleGlobalEscape();");
        });
        // Menu hotkey: Config::ApplyMenuHotkey reads sexlab.editor.hotkey* (VK→DX).
    });
}

/// MCM enable/remap: bind dxScanCode to Menu.ProcessHotkey, or clear when disabled.
void WebUI_SetMenuHotkey(uint32_t dxScanCode, bool enabled)
{
    const uint32_t prev = g_menuHotkey.exchange(0);
    if (prev != 0 && prev != 0x01)
        KeyHandler::GetSingleton()->Unregister(prev);

    if (!enabled || dxScanCode == 0 || dxScanCode == 0x01) {
        webui_log::info("WebUI menu hotkey disabled (prev={:#x}).", prev);
        return;
    }

    g_menuHotkey = dxScanCode;
    KeyHandler::GetSingleton()->Register(dxScanCode, [dxScanCode]() {
        if (!g_gameReady) {
            webui_log::info("WebUI hotkey blocked — no game loaded.");
            return;
        }
        // Always toggle: visible overlay closes immediately (any focus actor).
        // Do not dispatch ProcessHotkey on close — AfterTargetOpen would reconfigure.
        if (!WebUI_IsHidden()) {
            webui_log::info("WebUI hotkey: hide overlay");
            WebUI_Visibility_Hide();
            return;
        }
        if (!WebUI_IsReady()) {
            webui_log::critical(
                "WebUI hotkey: overlay not ready (missing PrismaUI/views/SkyrimNet_SexLab/index.html?).");
            WebUI_Visibility_Hide();
            return;
        }
        PapyrusBindings_WebUI::Call_ProcessHotkey(static_cast<std::int32_t>(dxScanCode));
    });
    webui_log::info("WebUI menu hotkey registered dx={:#x}.", dxScanCode);
}
