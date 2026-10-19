# Review v01 — 1.6x animation-change stage restart + punish spell display name

Reviewed: [`create-what-was-changed-and-why.md`](../../create-what-was-changed-and-why.md) against the working-tree diff (2026-10-15).
SexLab 1.6x behavior checked against `extern/Source_SexLab/sslThreadController.psc`.

## Verdict

**Ready for in-game testing.** The handoff doc describes the diff accurately: every table row matches the code. There are no blocking bugs. Three minor findings are listed below. One doc sentence was corrected.

## Verified SexLab 1.6x call flow

| Fact | Source |
|------|--------|
| `GoToStage` exists only in state `Animating`. In every other state it is the empty stub. | sslThreadController.psc:204, :1080 |
| `Advancing.OnUpdate` calls `Action("Animating")` **before** `SendThreadEvent("StageStart")`. As a result, our `StageStart` handler always sees `Animating`, and the deferred `GoToStage(1)` works. | :144-147 |
| `SetAnimation`: if `Stage >= StageCount`, it calls `GoToStage(StageCount-1)` (which enters `Advancing`). Otherwise, at `Stage == 1` it calls `ResetPositions()`. | :766-777 |
| `ChangeAnimation` (hotkey): `SetAnimation`, then `SendThreadEvent("AnimationChange")`. When the stage is clamped, our `CheckAnimationChange` sees `Advancing`, defers, and the clamp `StageStart` applies `GoToStage(1)`. | :226-252 |
| `ResetPositions` is overridden only in `Prepare`, `Animating` and `Refresh`. | :108, :698, :710 |

## C++ (`PunishSpellDisplayName`)

- The case-insensitive suffix strip is correct. `_stricmp` is given `kTorture.data()`, which comes from a literal and is therefore null-terminated.
- In `StrategyDecision`, the option text uses the display name, while `methodOf[k]` keeps the full spell name, so `FindWeakSpell` still matches.
- `Hud.cpp:371` still lists the raw `sp.name`. This is consistent with the doc's "HUD unchanged". If the HUD should also show "Sparks", that is a one-line follow-up.

## Findings

1. **Doc inaccuracy (fixed in the handoff doc).** The doc said the `GoToStage(1)` in `WebUI_SwitchToRegistry` before `SetAnimation` lets SexLab run `ResetPositions`. It does not. After `GoToStage(1)` the thread is in `Advancing`, which has no `ResetPositions` override, so the call does nothing. This is harmless: `Advancing → Animating.FireAction` plays stage 1 of the new animation through `PlayStageAnimations`. Watch for actor alignment drift after Scene Menu switches.
2. **Double `StageStart` on the WebUI path (low).** After the pre-`GoToStage(1)`, `thread.Stage == 1`. `CheckAnimationChange` / `NoteSeededRegistry` then skip the restart and call `QueueAnimationChangeStage`, which sends a synthetic `StageStart` in addition to SexLab's real one.
   - The change is narrated only once: the second pass sees `desc == description_last`.
   - `Engine_BeginScene`, `Pause_Hold`, `Ending_StageStart` and `SaveThreadsJson` run twice.
   - The same behavior already existed when a hotkey switch clamps a 2-stage animation to stage 1.
   - Optional fix: when `WebUI_SwitchToRegistry` issued its own `GoToStage(1)`, set `pending_animation_change` / `animation_change_from` directly and skip the queue.
3. **Stale defer (rare).** A restart deferred while the thread is in a state other than `Animating` or `Advancing` (`Refresh`, `Frozen`) waits for the next real `StageStart`. With auto-advance off, that is the player's next manual advance, which then jumps to stage 1 instead of moving forward.

## Build (2026-10-15 23:51)

| Target | Result |
|--------|--------|
| Papyrus main (`skyrimse.ppj`, pyro) | 2 succeeded, 0 failed (`SkyrimNet_SexLab_Scene`, `_Scene_Manager`). `Scene.pex` 23:51 |
| Papyrus P+ bridge (`skyrimse-pplus.ppj`) | 1 succeeded, 0 failed |
| SKSE `build-release` | Up to date. `SKSE/Plugins/SkyrimNet_SexLab.dll` is byte-identical to `build/release/Release/` (23:42, newer than all edited `.cpp` files) |

Tooling note: the `compile: pyro` tasks in `.vscode/tasks.json` point at `joelday.papyrus-lang-vscode-2024.578.1412/pyro/pyro.exe`, which no longer exists. The extension updated to 2026.x, which does not ship pyro. This build used `C:\Skyrim\tools\Pyro\pyro.exe`.

## In-game test checklist

Traces to search for in the Papyrus log / `SkyrimNet_SexLab.log`: `RestartStageOnAnimationChange`, `defer stage`, `deferred: stage`, `WebUI_SwitchToRegistry`, `StageStart`.

| # | Setup | Expect |
|---|-------|--------|
| 1 | 1.6x. Advance to the **last stage**, then change animation with the SexLab hotkey. | Trace `defer stage N -> 1 state:Advancing`, then `deferred: stage N-1 -> 1`. The scene plays stage 1. One "Scene changes to '…'" narration. |
| 2 | 1.6x. Middle stage (still `Animating`), then change animation. | Trace `animation change: stage N -> 1` with no defer. Stage 1. One narration. |
| 3 | Scene Menu: pick a different animation at stage > 1 (with and without reseed). | Stage 1 after apply. One narration. Note whether `StageStart` traces twice (finding 2) and whether actors are misaligned (finding 1). |
| 4 | Injury Engine on, player-turn punish options and auto-play. | Options read "hit them with the Sparks spell". The narration line says "with Sparks", not "Sparks (torture)". The spell actually fires. |
| 5 | SexLab P+ scene: switch animation. | No `RestartStageOnAnimationChange` trace. P+ reset behaves as before. |
| 6 | (Finding 3) Auto-advance off, switch at last stage. | Restart happens immediately on the clamp `StageStart`, not on the next manual advance. |
