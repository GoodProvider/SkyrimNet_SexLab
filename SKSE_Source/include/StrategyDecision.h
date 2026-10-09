#pragma once

#include "PCH.h"

#include <cstdint>

/// SkyrimNet's decision model (e.g. Jev) picks mini-game NPC strategies: every NPC when a scene becomes
/// ready for NPC steps, and the speaker after each line an NPC in a managed scene speaks. One decision
/// request per NPC (prompts/decisions/sexlab/minigame_strategy.prompt).
/// Auto play (HUD take-control key in the player's scene): after each line in the player's scene, one player-turn
/// request (prompts/decisions/sexlab/minigame_player_turn.prompt) picks the player's strategy, whether the player
/// speaks, which HUD key the player presses and what the player picks in the Aid / Force dialogs.
/// See docs/developers/orgasm-engine.md.
namespace StrategyDecision
{
    /// Registers the SkyrimNet dialogue event callbacks (once; retried until it succeeds). Needs SkyrimNet
    /// public API v12+. Call at kDataLoaded and again on game load.
    void Install();
    /// Game load / new game: forget pending requests and the no-provider warning.
    void Reset();
    /// Game thread. The scene is ready for NPC steps: decide every NPC's opening strategy.
    void OnSceneReady(std::int32_t sid);
    /// Game thread. Auto play just turned on: the player's first turn.
    void OnAutoPlay();
}
