#pragma once

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
void InvokeConfigureSettingsPanel();
void InvokeLogPanelOpen();
void PushLogPanelPoll();

class Config
{
public:
    static constexpr const char* kPluginVersion = "0.34.1";
    static constexpr const char* kDocsUrl = "https://github.com/GoodProvider/SkyrimNet_SexLab";

    static Config& GetSingleton();

    void ApplyFromConfig();
    int FrameworkPlayerIndex() const { return frameworkPlayerIndex_; }

private:
    Config() = default;

    void ApplyGlobals();
    void ApplyMenuHotkey();

    int frameworkPlayerIndex_ = 0;
};

}  // namespace SexLabNet
