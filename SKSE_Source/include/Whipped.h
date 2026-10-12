#pragma once

#include "PCH.h"

#include <functional>
#include <string>

/// Soft dependency on SkyrimNet_Whipped (SkyrimNet_Whipped_Main External_* globals). When installed, Punish goes through
/// torture types or whipping and heal-type Aid goes through External_Heal; Whipped sends the narration line.
/// Game thread only.
namespace Whipped
{
    /// SkyrimNet_Whipped.esp loaded and its script has External_Strike (an older Whipped counts as not installed).
    bool Installed();
    /// Whipped setting whip.body.include_sexual_parts.
    bool SexualParts();
    /// Pulldown term -> Whipped part name: cock -> penis, ass -> ass hole; body / custom text / "" -> "" (random).
    std::string PartName(const std::string& part);
    /// One whip hit on part; Whipped narrates line plus the injury. False when not installed.
    bool Strike(RE::Actor* attacker, RE::Actor* victim, const std::string& line, const std::string& part);
    /// Punish hit: slap/pinch/punch/pull use their torture types; a weak spell (spell != 0) uses fire/frost/shock by its
    /// damage effect's resist; free text uses Strike. location is the body part pulldown ("body" or "" = no named
    /// part). False when not installed, or for a spell with no fire/frost/shock effect.
    bool PunishHit(RE::Actor* attacker, RE::Actor* victim, const std::string& line, const std::string& method,
        const std::string& location, RE::FormID spell = 0);
    /// Punish hit that Whipped does not narrate: same routing as PunishHit, through External_TortureText. done gets
    /// the feeling text ("" when no hit landed) on a Papyrus VM thread; hop to the game thread before using it.
    /// False (done never called) when not installed, Whipped has no External_TortureText, or the spell has no
    /// fire / frost / shock effect: the caller narrates without feeling text.
    bool PunishText(RE::Actor* attacker, RE::Actor* victim, const std::string& method, const std::string& location,
        RE::FormID spell, std::function<void(std::string)> done);
    /// Heals health worth of whip wounds on part; Whipped narrates line when narrate. False when not installed.
    bool Heal(RE::Actor* caster, RE::Actor* target, const std::string& line, float health, const std::string& part,
        bool narrate = true);
    /// Turns whip.body.include_sexual_parts on in Whipped.
    void EnableSexualParts();
}
