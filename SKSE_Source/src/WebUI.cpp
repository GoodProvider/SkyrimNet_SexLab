#include "WebUI.h"
#include "JsonUtil.h"
#include "Papyrus_WebUI.h"
#include "WebUI_Log.h"
#include "ActionCatalog.h"
#include "ActionDispatch.h"
#include "Config.h"
#include "RE/Skyrim.h"

#include <Windows.h>
#include <cstring>
#include <deque>
#include <filesystem>
#include <fstream>
#include <mutex>
#include <sstream>
#include <string>
#include <string_view>
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
static std::atomic<uint32_t> g_styleHotkey{0};
static std::mutex g_rebuildTsMutex;
static std::string g_lastRebuildTimestamp;
static std::mutex g_logFileMutex;
static std::uintmax_t g_logFileOffset = 0;

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

void InvokeConfigureSettingsPanel()
{
    nlohmann::json j;
    j["version"] = ReadPluginVersionFromInfoJson();
    j["docsUrl"] = Config::kDocsUrl;
    {
        std::lock_guard lock(g_rebuildTsMutex);
        j["lastRebuild"] = g_lastRebuildTimestamp.empty() ? "never" : g_lastRebuildTimestamp;
    }
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
    // Scene HUD keys: only while the HUD is up and the overlay is closed.
    const bool hud = _hudActive.load() && WebUI_IsHidden();
    std::map<uint32_t, KeyCallback> hudKeys;

    {
        std::shared_lock lock(_mutex);
        if (hud)
            hudKeys = _hudKeys;
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

/// Shows and focuses the PrismaUI overlay after refreshing nearby actors for the menu.
/// No-ops if PrismaUI is missing, no game is loaded, DomReady has not fired, or the view is invalid.
void WebUI_Visibility_Show()
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

    PapyrusBindings_WebUI::PopulateNearbyActors();
    WebUI_InvokeFrameworkToggle();

    webui_log::info("WebUI Show + Focus.");
    PrismaUI->Show(g_view);
    PrismaUI->Focus(g_view, true);
    KeyHandler::PromoteSink();
    g_webuiGamePaused = true;
    WebUI_Invoke("setGamePaused(true);");
    // Start / Cancel hide ControlPanel in JS. Show must restore it — same-actor
    // Target_Menu_Open used to skip showPanel and left a blank left column.
    WebUI_Invoke("showControlPanel();");
    DispatchMenuNoArg("WebUI_SeedSceneInfos");
}

static void WebUI_Visibility_HideImpl(bool commit)
{
    if (commit)
        WebUI_Invoke("flushSceneInfos();");
    else
        WebUI_Invoke("discardSceneInfos();");
    WebUI_Invoke("bondageReleaseAll();");
    DispatchHandlerBondageClosed();
    if (!PrismaUI) return;
    PrismaUI->Unfocus(g_view);
    PrismaUI->Hide(g_view);
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
                    webui_log::info("onYesNoResult button={} creator_sid={}", button, creator_sid);
                    WebUI_Invoke("hidePanel('yesno_panel');");
                    // Yes (0) opens SceneCreator next — keep overlay focused. Random/No hide unless TargetMenu stays.
                    if (button != 0 && !PapyrusBindings_WebUI::TargetMenuSessionActive)
                        WebUI_Visibility_HideWithoutCommit();
                    PapyrusBindings_WebUI::DispatchManagerMethodIntInt("WebUI_OnYesNoResult", creator_sid, button);
                } catch (...) {
                    webui_log::warn("onYesNoResult: bad JSON");
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
        PrismaUI->RegisterJSListener(g_view, "onLeashStatus", [](const char* value) {
            RunGuarded("onLeashStatus", [&] {
                PapyrusBindings_WebUI::HandleLeashStatus(value);
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
                Call_RebuildAnimDb();
                ActionCatalog::SwitchMainPanel("log_panel");
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

/// Dashboard enable/remap: bind dxScanCode to Menu.CycleStyleHotkey, or clear when disabled.
/// KeyHandler keeps one callback per key, so a key shared with the menu hotkey is refused.
void WebUI_SetStyleHotkey(uint32_t dxScanCode, bool enabled)
{
    const uint32_t prev = g_styleHotkey.exchange(0);
    if (prev != 0 && prev != 0x01 && prev != g_menuHotkey.load())
        KeyHandler::GetSingleton()->Unregister(prev);

    if (!enabled || dxScanCode == 0 || dxScanCode == 0x01) {
        webui_log::info("Style hotkey disabled (prev={:#x}).", prev);
        return;
    }
    if (dxScanCode == g_menuHotkey.load()) {
        webui_log::error("Style hotkey dx={:#x} is the menu hotkey; style hotkey not registered.", dxScanCode);
        return;
    }

    g_styleHotkey = dxScanCode;
    KeyHandler::GetSingleton()->Register(dxScanCode, []() {
        if (!g_gameReady) {
            return;
        }
        // Overlay open (typing) or a game menu/console pausing the game: leave the key alone.
        if (!WebUI_IsHidden()) {
            return;
        }
        if (auto* ui = RE::UI::GetSingleton(); ui && ui->GameIsPaused()) {
            return;
        }
        PapyrusBindings_WebUI::Call_CycleStyleHotkey();
    });
    webui_log::info("Style hotkey registered dx={:#x}.", dxScanCode);
}
