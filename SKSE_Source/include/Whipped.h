#pragma once

#include "PCH.h"

#include <string>

/// Soft dependency on SkyrimNet_Whipped (SkyrimNet_Whipped_Main External_* globals). When installed, Force goes through
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
    /// Force hit: slap/pinch/punch/pull use External_Torture; cover mouth, free text, and weak spells use Strike.
    /// location is the HUD pulldown ("body" or "" = no named part). False when not installed.
    bool ForceHit(RE::Actor* attacker, RE::Actor* victim, const std::string& line, const std::string& method,
        const std::string& location);
    /// Heals health worth of whip wounds on part; Whipped narrates line. False when not installed.
    bool Heal(RE::Actor* caster, RE::Actor* target, const std::string& line, float health, const std::string& part);
    /// Turns whip.body.include_sexual_parts on in Whipped.
    void EnableSexualParts();
}
