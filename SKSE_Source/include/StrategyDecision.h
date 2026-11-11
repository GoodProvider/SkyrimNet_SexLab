#pragma once

#include "PCH.h"

#include "OrgasmEngine.h"

#include <cstdint>
#include <functional>

/// SkyrimNet's decision model (e.g. Jev) picks mini-game NPC strategies: every NPC when a scene becomes
/// ready for NPC steps, and the speaker after each line an NPC in a managed scene speaks. One decision
/// request per NPC (prompts/decisions/sexlab/minigame_strategy.prompt).
/// Auto play (HUD take-control key in the player's scene): after each line in the player's scene, one player-turn
/// request (prompts/decisions/sexlab/minigame_player_turn.prompt) picks the player's strategy, whether the player
/// speaks, which HUD key the player presses and what the player picks in the Aid / Punish dialogs.
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
    /// Game thread. target was just asked, ordered or punished (trigger "asked" | "ordered" | "punished"; line: that
    /// narration, already sent, the decision's last_line). The decision waits for target's LLM reply to the narration
    /// (its next thought or line, or a timeout) and replaces the dialogue decision that reply would send; then done
    /// is called with the outcome (kDropped when no decision was made: none set up, not AI-driven, failed). done is
    /// always called exactly once, possibly before this returns. orderKey (a punishment that also orders a strategy):
    /// the option ordered, sent as ordered_key; an answer picking it skips the confidence gate.
    void RequestAnswer(RE::FormID target, const std::string& trigger, const std::string& line,
        std::function<void(OrgasmEngine::DecisionResult)> done, const std::string& orderKey = "");
    /// Game thread. Like RequestAnswer (same wait for target's reply), but then asks the decision model only whether
    /// that reply complies with one request by `by` (prompts/decisions/sexlab/minigame_comply.prompt). requestKey: the
    /// option asked for (e.g. focused_p2), "" for a free-text request; requestText: "focus on Bob's pleasure".
    /// comply + key: the key is applied with no confidence gate (kChanged, or kKept when already on it); comply with
    /// no key: kChanged; refuse: kKept; nothing sent or failed: kDropped. done is called exactly once.
    void RequestComply(RE::FormID target, const std::string& trigger, const std::string& line, RE::FormID by,
        const std::string& requestKey, const std::string& requestText,
        std::function<void(OrgasmEngine::DecisionResult)> done);
    /// Game thread, every OrgasmEngine tick: sends the asked / ordered / punished decisions whose reply arrived or
    /// timed out.
    void Tick();
    /// Game thread. The receiver NPC is offered giver's potion (how "drink" | "lips"; potionKind "healing" |
    /// "stamina"): asks the decision model (prompts/decisions/sexlab/aid_accept.prompt) whether it accepts, then calls
    /// done(accepted) on the game thread, exactly once. No decisions provider or a failed request: accepted.
    void RequestAidAccept(RE::FormID receiver, RE::FormID giver, const std::string& how, const std::string& potionKind,
        const std::string& potionName, std::function<void(bool)> done);
    /// Game thread. Last stage of a scene: the caller NPC picks the next line (prompts/decisions/sexlab/last_stage.prompt).
    /// done(line) on the game thread, exactly once. 0 stop, 1 cuddle, 2 vaginal, 3 oral, 4 anal.
    /// No provider, a failed request, or an unknown answer: 0. Not gated by sexlab.minigame.decision_strategy.
    void RequestLastStage(std::int32_t sid, RE::FormID caller, bool playerInScene, const std::string& castNames,
        std::function<void(int)> done);
    /// Skyrim relationship rank between two actors (Papyrus GetRelationshipRank: 4 lover .. -4 archnemesis; 0 none).
    int RelationshipRank(RE::Actor* a, RE::Actor* b);
}
