#pragma once

#include <atomic>
#include <functional>
#include <map>
#include <vector>
#include <shared_mutex>

#include "PrismaUI_API.h"


using KeyCallback = std::function<void()>;

class KeyHandler : public RE::BSTEventSink<RE::InputEvent*>
{
public:
    static KeyHandler* GetSingleton();
    static void RegisterSink();
    /// Move this sink to the front of BSInputDeviceManager so we run before Papyrus/other plugins.
    static void PromoteSink();
    void Register(uint32_t dxScanCode, KeyCallback callback);
    void Unregister(uint32_t dxScanCode);
    /// Scene HUD keys (DX scancodes; mouse buttons are 256 + button). Only live while
    /// SetHudActive(true); matched events (down, held and up) are unlinked from the input list so
    /// SexLab hotkeys, favorites and attacks never see them.
    void SetHudKeys(std::map<uint32_t, KeyCallback> keys);
    void SetHudActive(bool active);

private:
    KeyHandler() = default;
    ~KeyHandler() override = default;
    KeyHandler(const KeyHandler&) = delete;
    KeyHandler(KeyHandler&&) = delete;
    KeyHandler& operator=(const KeyHandler&) = delete;
    KeyHandler& operator=(KeyHandler&&) = delete;

    RE::BSEventNotifyControl ProcessEvent(RE::InputEvent* const* a_eventList,
                                          RE::BSTEventSource<RE::InputEvent*>* a_eventSource) override;

    std::map<uint32_t, KeyCallback> _callbacks;
    std::map<uint32_t, KeyCallback> _hudKeys;
    std::atomic<bool> _hudActive{ false };
    std::shared_mutex _mutex;
};

void InitWebUI();
void WebUI_SetGameReady();
void WebUI_Visibility_Show();
void WebUI_Visibility_Hide();
/// Hide overlay without applying SceneInfo drafts (Cancel / Escape).
void WebUI_Visibility_HideWithoutCommit();
void WebUI_Visibility_Toggle();
/// True when PrismaUI is missing, the view is invalid, or the overlay is hidden.
bool WebUI_IsHidden();
/// Overlay visible and pausing the game (Focus pauseGame; DE play/pause can release it).
bool WebUI_IsGamePaused();
/// True when the PrismaUI view exists and DomReady has fired (safe to Show/Focus).
bool WebUI_IsReady();
void WebUI_Invoke(const std::string& script);
/// Dispatch a no-arg function on SkyrimNet_SexLab_Menu (Papyrus VM).
void DispatchMenuNoArg(const char* functionName);
/// C++ → JS: Invoke(fn(JSON.parse("..."))). Do not use PrismaUI InteropCall
/// (empty/bad args after a good parse wiped BondagePanel groups to []).
void WebUI_InteropCall(const char* functionName, const std::string& jsonArgument);
/// Push OStimNet-gated SexLab/OStim ControlPanel pulldown (setFrameworkToggle).
void WebUI_InvokeFrameworkToggle();
void WebUI_Reset();
void Reset_To_Default();
/// MCM-driven menu hotkey: register dxScanCode when enabled, else unregister.
void WebUI_SetMenuHotkey(uint32_t dxScanCode, bool enabled);
