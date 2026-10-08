#pragma once

#include "PCH.h"

#include <cstdint>
#include <string>
#include <string_view>
#include <vector>

/// Healing / stamina aid (HUD Aid key, SexLab_Aid action) and the weak attack spells the Force key offers.
/// A spell is applied as its restore effects (magnitude x duration, a concentration spell as kConcentrationSeconds
/// of casting) and costs its magicka; a potion is removed from the caster and its restore effects applied.
namespace Aid
{
    struct Option
    {
        RE::FormID form = 0;
        std::string name;
        bool potion = false;
        std::int32_t count = 0;  // potions in the inventory, 0 for a spell
        float cost = 0.0f;       // magicka, 0 for a potion
        bool affordable = true;  // potion, or a spell the caster has the magicka for
        float health = 0.0f;     // amount restored
        float stamina = 0.0f;
    };

    /// Healing / stamina spells the caster knows and potions it carries, spells first, by name.
    std::vector<Option> ListOptions(RE::Actor* caster);
    /// Any affordable spell or any potion.
    bool HasOptions(RE::Actor* caster);
    /// Best option for kind ("heal" / "stamina"): the strongest affordable spell, else the strongest potion. 0 when none.
    RE::FormID PickBest(RE::Actor* caster, std::string_view kind);
    /// Applies option form from caster to target (re-validated). Game state changes are queued on the main thread.
    /// Returns the narration line, "" when refused.
    std::string Apply(RE::Actor* caster, RE::Actor* target, RE::FormID form);

    struct WeakSpell
    {
        RE::FormID form = 0;
        std::string name;
        float minDamage = 0.0f;  // smallest Damage Health magnitude among the spell's effects
    };
    /// Novice / Apprentice spells with a hostile Damage Health effect, by name.
    std::vector<WeakSpell> WeakAttackSpells(RE::Actor* actor);
    /// The weak spell named name (case-insensitive), nullptr when the actor has none by that name.
    const WeakSpell* FindWeakSpell(const std::vector<WeakSpell>& spells, std::string_view name);
    /// Queues a direct health hit of dmg on the victim, never below 1 health (no cast: no combat, no bounty).
    void QueueWeakSpellHit(RE::Actor* victim, float dmg);
}
