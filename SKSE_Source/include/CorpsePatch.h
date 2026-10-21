#pragma once

#include <string>

/// SexLab 1.66 corpse patch (FOMOD option): Data/Scripts sslActorAlias.pex / sslActorLibrary.pex must match
/// CorpsePatchHashes.h (SHA-256) before Dead actors can join scenes works. P+ needs no patch.
namespace CorpsePatch
{
    /// Hashes the installed pex files again and caches the result. Returns the first file that is missing or
    /// does not match, or "" when the patch is installed (always "" when pplus).
    std::string Recheck(bool pplus);

    /// Cached result of the last Recheck: true when installed or on P+. False before the first Recheck.
    bool IsInstalled();
}
