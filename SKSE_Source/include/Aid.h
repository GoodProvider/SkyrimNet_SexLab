#pragma once

#include "PCH.h"

#include <cstdint>
#include <string>
#include <string_view>
#include <vector>

/// Healing / stamina aid (HUD Aid key, SexLab_Aid action) and the weak attack spells the Force key offers.
/// A spell is applied as its restore effects (magnitude x duration, a concentration spell as kConcentrationSeconds
/// of casting) and costs its magicka; a potion is removed from the caster and its restore effects applied.
/// Nothing is engine-cast (no combat / bounty); the item's casting art, effect shader, hit art and sounds are played.
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
    /// location: body part ("" / "body": none). Returns the narration line, "" when refused.
    /// With Injury Engine installed a health option heals whip wounds on the part through Injury Engine, which also
    /// narrates the line: *injuryEngine is set true and the caller must not narrate it. callerNarrates (HUD Aid):
    /// Injury Engine heals silently, *injuryEngine stays false and the caller always narrates the line.
    /// A potion's location may also be "drink" (no body part) or lips / ass / pussy / cock with their own lines:
    /// when the scene's act (OrgasmEngine::GetSceneActs) carries the potion between two actors (a dick thrust into
    /// an ass / pussy / mouth) the effect is split half to caster, half to target; otherwise the target gets it all.
    /// Drink / lips on someone else need consent first (NeedsConsent); Apply assumes it was given.
    std::string Apply(RE::Actor* caster, RE::Actor* target, RE::FormID form, const std::string& location = "",
        bool* injuryEngine = nullptr, bool callerNarrates = false);
    /// A carried potion offered to someone else to drink or on the lips: the target accepts or refuses first
    /// (NPC: decision model; player: Yes / No dialogue).
    bool NeedsConsent(RE::Actor* caster, RE::Actor* target, RE::FormID form, const std::string& location);
    /// Name and kind ("healing" / "stamina") of a potion the caster carries. False when not carried.
    bool PotionInfo(RE::Actor* caster, RE::FormID form, std::string& name, std::string& kind);
    /// "Amy refused Bob's stamina potion" (no period; a punish reason), "" when the potion is not carried.
    std::string RefusalReason(RE::Actor* caster, RE::Actor* target, RE::FormID form);
    /// Aid panel: keeps spell form going from caster to target at its normal rate (a concentration spell every second,
    /// a fire-and-forget spell recast every max(1, charge + 0.5) s) until points are restored (health; stamina for a
    /// stamina-only spell), the caster lacks the magicka for the next tick, the target is full, an actor is gone, or
    /// a newer channel from the caster replaces it. A potion or points <= 0 is a one-shot Apply. Returns the line for
    /// the caller to narrate once ("" when refused); *injuryEngine and callerNarrates as for Apply (Injury Engine
    /// narrates on the first tick unless callerNarrates).
    std::string StartChannel(RE::Actor* caster, RE::Actor* target, RE::FormID form, const std::string& location,
        float points, bool* injuryEngine = nullptr, bool callerNarrates = false);

    struct WeakSpell
    {
        RE::FormID form = 0;
        std::string name;
        float minDamage = 0.0f;  // smallest Damage Health magnitude among the spell's effects
    };
    /// Novice / Apprentice spells with a hostile Damage Health effect, by name.
    std::vector<WeakSpell> WeakAttackSpells(RE::Actor* actor);
    /// Injury Engine's Flames / Frostbite / Sparks (torture) that knower knows (nullptr: all three), by name
    /// (minDamage 0: Injury Engine takes the damage).
    std::vector<WeakSpell> TortureSpells(RE::Actor* knower);
    /// Punish spell methods. With Injury Engine installed: the player gets the torture spells it knows; an NPC gets all
    /// three when Injury Engine's require_whip is off, else none. Without Injury Engine: the weak attack spells.
    std::vector<WeakSpell> PunishSpells(RE::Actor* punisher);
    /// The weak spell named name (case-insensitive), nullptr when the actor has none by that name.
    const WeakSpell* FindWeakSpell(const std::vector<WeakSpell>& spells, std::string_view name);
    /// Spell name for narration / decisions (strips Injury Engine's " (torture)" suffix, case-insensitive).
    std::string PunishSpellDisplayName(std::string_view spellName);
    /// Queues a direct health hit of dmg on the victim, never below 1 health, and plays the spell's casting art on the
    /// forcer and its shader / hit art / sounds on the victim (no cast: no combat, no bounty). dmg 0: visuals only.
    void QueueWeakSpellHit(RE::Actor* forcer, RE::Actor* victim, RE::FormID spell, float dmg);
}
