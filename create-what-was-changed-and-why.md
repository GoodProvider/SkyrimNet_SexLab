# What changed and why (agent handoff)

Follow-up to the **uncommitted code review** of punish-spell + 1.6x animation-stage work. The Injury Engine punish-spell routing (`Aid::PunishSpells`, `InjuryEngine::RequireWhip`, HUD / `PunishNarrated` wiring) is already on the branch in earlier commits; **this document is the delta still in the working tree** when the review fixes were applied.

Do not commit unless the user asks. Rebuild after edits: VS Code task **`compile: papyrus`** (plus `compile: pyro (P+ bridge)` if the bridge changed) and the SKSE release preset under `SKSE_Source/` (copy `SkyrimNet_SexLab.dll` to `SKSE/Plugins/`).

## Problem the review found

**SexLab 1.6x keeps stage on `SetAnimation`.** The mod wanted mid-scene animation switches (hotkey, Scene Menu, Description Editor, SL Tools) to start at **stage 1**, like SexLab P+.

The first implementation (`RestartStageOnAnimationChange`) only called `GoToStage(1)` when the thread was still in state **`Animating`** and `Stage > 1`. That missed the common case:

1. Player on the **last stage** of animation A (or any stage where `Stage >= StageCount` after `SetAnimation` updates `StageCount`).
2. SexLab `SetAnimation` runs `GoToStage(StageCount - 1)` and enters **`Advancing`**.
3. `CheckAnimationChange` could not restart; it queued a **synthetic** `StageStart` via `SkyrimNet_SexLab_AnimationChanged`.
4. Narration and orgasm-engine stage state ran at the wrong stage; the scene often stayed on `count - 1` instead of 1.

**Scene Menu** (`WebUI_SwitchToRegistry` with `reseed = false`) only called `NoteSeededRegistry`, which queued narration but never restarted stage.

**Punish spell display:** narration stripped ` (torture)` from Injury Engine spell names, but the mini-game player-turn options still sent the full name to the LLM.

## What we changed (by area)

### Papyrus — [`Scripts/Source/SkyrimNet_SexLab_Scene.psc`](Scripts/Source/SkyrimNet_SexLab_Scene.psc)

| Change | Why |
|--------|-----|
| `pending_stage_restart` flag | When an animation change needs stage 1 but SexLab is not `Animating` yet, defer `GoToStage(1)` to the next real `StageStart` instead of queuing a fake one. |
| `ApplyRestartStageOnAnimationChange(from_desc)` replaces `RestartStageOnAnimationChange` | Sets `pending_animation_change` / `animation_change_from`. If `Animating` and `Stage > 1`: `GoToStage(1)` now. Else: `pending_stage_restart = true` and **no** `QueueAnimationChangeStage`. Returns true when restart was issued or deferred (caller skips queue). |
| `CheckAnimationChange` | Uses `ApplyRestart…`; only queues synthetic stage when restart does not apply (e.g. already stage 1). |
| `NoteSeededRegistry` | Same restart path as `CheckAnimationChange` so **Scene Menu** animation picks get stage 1 when `Stage > 1`. |
| `StageStart` | Handles `pending_stage_restart` at entry (`GoToStage(1)`, early return). After `SyncAnimationDefaults`, calls `ApplyRestart…` before setting pending narration flags for the non-restart path. |
| `WebUI_SwitchToRegistry` (1.6x) | If still `Animating` and `Stage > 1`, `GoToStage(1)` **before** `SetAnimation` so the new animation plays from stage 1 instead of the old stage index. (The thread is then `Advancing`, so SetAnimation's `ResetPositions` is a no-op; `Advancing → Animating` plays the new animation's stage 1.) |
| Clear `pending_stage_restart` in `Setup`, `Release`, `AnimationStart`, `WebUI_RestoreCancelSnapshot` | Same lifecycle as `pending_animation_change`. |

Trace prefix for all restart paths: `RestartStageOnAnimationChange` (including `defer` / `deferred` lines). [`KNOWLEDGEBASE.md`](KNOWLEDGEBASE.md) already notes deliberate `GoToStage(1)` on animation change; only **untraced** drops to stage 1 remain the old “stuck at stage 1” bug.

**Not changed:** P+ (`IsSexLabPPlus()` bypass). Poll still only runs while `Animating`; SL Tools paths that never fire `AnimationChange` rely on poll + deferred restart on the eventual `StageStart`.

### C++ — Aid / orgasm engine / decisions

| File | Change | Why |
|------|--------|-----|
| [`SKSE_Source/include/Aid.h`](SKSE_Source/include/Aid.h), [`Aid.cpp`](SKSE_Source/src/Aid.cpp) | `Aid::PunishSpellDisplayName` | Single place to strip Injury Engine’s ` (torture)` suffix **case-insensitively** for UI and narration. |
| [`OrgasmEngine.cpp`](SKSE_Source/src/OrgasmEngine.cpp) | `PunishLocked` uses `PunishSpellDisplayName` | Removes duplicated suffix logic. |
| [`StrategyDecision.cpp`](SKSE_Source/src/StrategyDecision.cpp) | Player-turn punish method **text** uses display name; `methodOf` still maps to full spell name for `PunishNarrated` / `FindWeakSpell`. | LLM sees “Sparks”, execution still matches `Sparks (torture)`. |

### Docs / changelog

| File | Change |
|------|--------|
| [`docs/developers/orgasm-engine.md`](docs/developers/orgasm-engine.md) | Punish + HUD anchor: `Aid::PunishSpells` and `PunishSpellDisplayName` (was still `WeakAttackSpells` in two places). |
| [`CHANGELOG-developer.md`](CHANGELOG-developer.md) | New bullet for 1.6x `ApplyRestartStageOnAnimationChange` / `pending_stage_restart`; torture bullet mentions `PunishSpellDisplayName`. |

[`CHANGELOG-player.md`](CHANGELOG-player.md) player line for “animation at stage 1” was already accurate once this fix lands; no edit required for the review pass.

## Expected behavior after fix

- **1.6x, stage > 1, switch animation** (any route that calls `CheckAnimationChange` or `NoteSeededRegistry` after the registry changes): thread ends on **stage 1** of the new animation; one “Scene changes to …” style narration at that stage-1 `StageStart` (not at an intermediate clamp stage).
- **Final stage of old animation:** no synthetic `AnimationChanged` stage start at `count - 1` that steals narration; deferred restart runs on SexLab’s next `StageStart`.
- **Scene Menu** switch without reseed: stage restart when `Stage > 1`, same as Description Editor / hotkey paths.
- **Punish with Injury Engine torture spells:** HUD and narration unchanged from prior commit; auto-play punish spell options show base names without ` (torture)`.

## Suggested verification (in-game)

1. 1.6x scene, advance to **last stage**, change animation (SexLab hotkey or WebUI with reseed). Confirm stage **1** and sensible DN; Papyrus trace shows restart or defer then `deferred: stage … -> 1`.
2. Same at **middle stage** while `Animating`: trace `animation change: stage N -> 1` without defer.
3. Scene Menu **Update** with a different animation, `position_override` on, stage > 1: stage 1 after apply.
4. Injury Engine on, punish panel / auto-play: spell methods listed; line says “with Sparks” not “with Sparks (torture)”.
5. P+ scene: switching animation still uses P+ reset; no new `GoToStage(1)` from this path.

## Related symbols (quick lookup)

- `ApplyRestartStageOnAnimationChange`, `pending_stage_restart` — Scene.psc
- `Aid::PunishSpells`, `Aid::TortureSpells`, `InjuryEngine::RequireWhip` — prior commits; see [`CHANGELOG-developer.md`](CHANGELOG-developer.md) torture bullet
- Agent router: [`AGENTS.md`](AGENTS.md), [`llms.txt`](llms.txt)
