#pragma once

#include <nlohmann/json.hpp>
#include <string>
#include <vector>

namespace BondageCatalog
{
    /// True when SKSE has already loaded DeviousDevices.dll (BondagePanel only).
    bool DllPresent();

    /// Delay-load GetAPI. Never call from core plugin init as a hard fail.
    bool EnsureAPI();

    /// Cached group-devices.json. Does not call LoadAPI.
    nlohmann::json FileGroups();

    /// GetDatabase catalog after LoadAPI. Empty if API missing or scan failed.
    nlohmann::json ApiGroups();

    /// True when GetDatabase has already been attempted and cached non-empty.
    bool ApiCatalogReady();

    /// Groups JSON (API if cached non-empty, else file).
    nlohmann::json Groups();

    /// Slim payload: catalog groups + equippedId. wornFromApi uses GetWornDevices.
    nlohmann::json BuildState(RE::Actor* target, const nlohmann::json& papyrusHint,
        const nlohmann::json& groups, bool wornFromApi);

    /// Worn DD heavy bondage → SexLab animation tags for the cast, ordered armbinder, yoke, cuffs, bound
    /// (specific first, so callers drop from the end). Empty when sexlab.tags.filter_by_devious_devices is off.
    /// Worn-keyword scan only (no DD API). Main thread.
    std::vector<std::string> WornAnimationTags(const std::vector<RE::Actor*>& actors);
}
