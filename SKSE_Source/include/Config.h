#pragma once

#include <cstdint>
#include <string>

namespace SexLabNet {

/// Debug CRT (`/MTd`) must not consume `std::string` returned by SkyrimNet (`/MD`).
inline bool CrossDllStdStringSafe()
{
#ifdef _DEBUG
    return false;
#else
    return true;
#endif
}

/// Resolve SkyrimNet PublicAPI pointers. Include PublicAPI.h from Config.cpp only.
void InitSkyrimNetAPI();

void SetLastRebuildTimestamp(std::string ts);
std::string GetLastRebuildTimestamp();
void SetSexLabAnimCount(int sexlabCount);
void InvokeConfigureSettingsPanel();
void InvokeLogPanelOpen();
void PushLogPanelPoll();

/// Dashboard values from manifest.yaml (control store). `def` when unset or unreadable.
bool GetConfigBool(const char* path, bool def);
int GetConfigInt(const char* path, int def);
float GetConfigFloat(const char* path, float def);
/// VK (dashboard type:hotkey) -> DX scancode. Mouse VKs map to SKSE's 256+ codes
/// (VK_LBUTTON 256, VK_RBUTTON 257, VK_MBUTTON 258). 0 when unmapped.
std::uint32_t HotkeyVkToDx(int vk);

class Config
{
public:
    static constexpr const char* kPluginVersion = "0.34.1";
    static constexpr const char* kDocsUrl = "https://github.com/GoodProvider/SkyrimNet_SexLab";

    static Config& GetSingleton();

    void ApplyFromConfig();
    /// Scene HUD + mini-game keys and OrgasmEngine tuning (sexlab.hud.* / sexlab.minigame.* / sexlab.enjoyment.*).
    /// Ends with WriteHotkeyMap, so game start, load and dashboard save all refresh hotkey-map.json.
    void ApplyHudConfig();
    int FrameworkPlayerIndex() const { return frameworkPlayerIndex_; }

private:
    Config() = default;

    void ApplyGlobals();
    void ApplyMenuHotkey();
    /// Data/SKSE/Plugins/SkyrimNet_SexLab/hotkey-map.json: every live binding (menu, Escape, HUD keys).
    void WriteHotkeyMap();

    int frameworkPlayerIndex_ = 0;
};

}  // namespace SexLabNet
