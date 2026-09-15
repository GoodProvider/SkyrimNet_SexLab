#include "Config.h"
#include "PublicAPI.h"
#include "WebUI.h"
#include "WebUI_Log.h"

#include <Windows.h>
#include <algorithm>
#include <cctype>
#include <cstdio>
#include <cstdlib>
#include <string>
#include <string_view>

namespace SexLabNet {
namespace {

constexpr const char* kPluginName = "SkyrimNet_SexLab";

std::string GetRaw(const char* path, const char* def)
{
    if (!CrossDllStdStringSafe() || !PublicGetPluginConfigValue)
        return def ? def : "";
    return PublicGetPluginConfigValue(kPluginName, path, def);
}

bool ParseBool(std::string_view raw, bool def)
{
    std::string s(raw);
    std::transform(s.begin(), s.end(), s.begin(),
        [](unsigned char c) { return static_cast<char>(std::tolower(c)); });
    if (s == "true" || s == "1" || s == "yes")
        return true;
    if (s == "false" || s == "0" || s == "no")
        return false;
    return def;
}

int ParseInt(std::string_view raw, int def)
{
    if (raw.empty())
        return def;
    std::string s(raw);
    char* end = nullptr;
    const long v = std::strtol(s.c_str(), &end, 10);
    if (end == s.c_str())
        return def;
    return static_cast<int>(v);
}

bool GetBool(const char* path, bool def)
{
    return ParseBool(GetRaw(path, def ? "true" : "false"), def);
}

int GetInt(const char* path, int def)
{
    char buf[32];
    std::snprintf(buf, sizeof(buf), "%d", def);
    return ParseInt(GetRaw(path, buf), def);
}

void SetGlobalByEditorId(const char* editorId, float value)
{
    auto* form = RE::TESForm::LookupByEditorID(editorId);
    auto* glob = form ? form->As<RE::TESGlobal>() : nullptr;
    if (!glob) {
        webui_log::warn("Config: global {} not found", editorId);
        return;
    }
    glob->value = value;
    webui_log::info("Config: set {} = {}", editorId, value);
}

std::int32_t VkToDx(int vk)
{
    if (vk < 1 || vk > 255)
        return 0x2B;
    const UINT dx = MapVirtualKeyA(static_cast<UINT>(vk), MAPVK_VK_TO_VSC);
    return dx != 0 ? static_cast<std::int32_t>(dx) : 0x2B;
}

}  // namespace

void InitSkyrimNetAPI()
{
    if (!FindFunctions()) {
        webui_log::warn("SkyrimNet PublicAPI not found");
        return;
    }
    const int ver = PublicGetVersion ? PublicGetVersion() : 0;
    webui_log::info("SkyrimNet PublicAPI loaded (version={})", ver);
}

Config& Config::GetSingleton()
{
    static Config instance;
    return instance;
}

void Config::ApplyFromConfig()
{
    ApplyGlobals();
    ApplyMenuHotkey();
}

void Config::ApplyGlobals()
{
    const bool publicSex = GetBool("sexlab.prompt.public_sex_accepted", false);
    const bool hideHerm = GetBool("sexlab.prompt.hide_hermaphrodites", false);
    frameworkPlayerIndex_ = GetInt("sexlab.ostim.player", 0);
    if (frameworkPlayerIndex_ != 0)
        frameworkPlayerIndex_ = 1;

    SetGlobalByEditorId("skyrimnet_sexlab_public_sex_accepted", publicSex ? 1.0f : 0.0f);
    SetGlobalByEditorId("skyrimnet_sexlab_hide_hermaphrodites", hideHerm ? 1.0f : 0.0f);
    SetGlobalByEditorId("skyrimnet_sexlab_ostim_player", frameworkPlayerIndex_ == 1 ? 1.0f : 0.0f);
}

void Config::ApplyMenuHotkey()
{
    const bool enabled = GetBool("sexlab.editor.hotkey_enabled", false);
    int vk = GetInt("sexlab.editor.hotkey", 220);
    // Pre-VK dashboard saves stored DX 43 (backslash). type:hotkey now stores VK 220.
    if (vk == 43) {
        webui_log::info("ApplyMenuHotkey: leftover DX 43 mapped to VK 220");
        vk = 220;
    }
    const auto dx = static_cast<uint32_t>(VkToDx(vk));
    webui_log::info("ApplyMenuHotkey: enabled={} vk={} dx={:#x}", enabled, vk, dx);
    WebUI_SetMenuHotkey(dx, enabled);
}

}  // namespace SexLabNet
