#pragma once

#include "AnimationDB.h"

#include <string>
#include <vector>

namespace AniDescriber
{
    /// Fill missing stage text from HKX. Samples the whole animation on cache miss.
    /// Empty if creature, no clips, sample failure, or SKYRIMNET_ANIDESCRIBER_HKX=0 (caller may use tags).
    std::string Describe(const std::string& registry, int stage);

    /// Warm the Animation Information cache (orgasm_expected + generated stages).
    void Ensure(const AnimationDB::AnimRow& row);

    std::string Dump(const std::string& registry);

    void Invalidate(const std::string& registry);
    void InvalidateAll();
    void Close();
}
