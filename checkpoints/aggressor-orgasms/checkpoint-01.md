# Checkpoint 01: victim scenes hold the second-to-last stage until an aggressor orgasms (built, not in-game tested)

Written from `C:\Skyrim\dev\mods\SkyrimNet_SexLab`, branch `main`, baseline commit `b0c73dd5`, on top of the
uncommitted 0.36.1 work (not committed yet). Plan: `C:\Users\bhuff\.claude\plans\if-there-is-a-humming-harp.md`.

---

## 1. Goal

Maintainer rule: "if there is a victim, the aggressor will hold the animation on the second to last scene until
they orgasm which will trigger the orgasm check for everyone and advance to the last stage as normal."

## 2. Before

- **AI-gate scenes** (mini-game, engine plays everyone, `IsGateScene`): the gate fired on the **stage timer**
  (`penultElapsed >= gateSecs − lead − kGateDispatchMargin`). From the second-to-last stage on, everyone was
  capped at `kRushHover` (98), aggressors included. Aggressors always passed the gate.
- **Scenes under the player's hand** (no gate): an NPC aggressor lead who reached the ending target at **any**
  stage held the stage and then ended the animation (`ending_end_after`, `EndAnimation` from `Ending_Poll`).

## 3. Decisions (maintainer, via questions)

- Gate scenes: the aggressor's orgasm (reaching 100) **replaces the timer** as the gate trigger.
- The early "aggressor ends" rule is **replaced** (removed).
- With several aggressors, the **first** aggressor's orgasm releases the hold.
- **Configurable cap**: `sexlab.ending.victim_hold_max`, default 120 s, 0 = no cap. Manual Next still works.
- Scope: Multi-Orgasm Mini-game only. Together mode (its gate already passes everyone expected), the disabled
  engine, LeadIn and untimed scenes are unchanged.
- "Aggressor" = not a victim in a scene that has one. This matches `Engine_BeginScene` roles (2 victim,
  1 aggressor when `any_victim`), so Papyrus `!thread.IsVictim(a)` agrees with the engine's `Role::kAggressor`.

## 4. Changes

| File | Change |
|------|--------|
| `SKSE_Source/src/OrgasmEngine.cpp` | `VictimHoldScene(sc)` (mini-game, engine on, timed, no LeadIn, a victim and a non-DOM aggressor with `orgasmExpected`). Tick: `gateHeld` 98 cap skips aggressors when `victimHold`. The gate trigger in the second-to-last stage under `aiGate && victimHold` is "an aggressor with `CanOrgasmNow` at ≥ 100" or `sc.victimHoldExpired`, not the timer (logs `victim hold: aggressor … at 100, gate` / `victim hold expired, gate`). `JoinGroup` early final roll also runs when an aggressor is in the group in the second-to-last stage, whatever the ending target (log `final roll … victim_hold=`). New `SceneState::victimHoldExpired` (not saved, cleared with `gateDone` in `SetStage`). Public `IsVictimHoldScene(sid)` and `VictimHoldExpired(sid)`. |
| `SKSE_Source/include/OrgasmEngine.h`, `SKSE_Source/src/Papyrus_OrgasmEngine.cpp`, `Scripts/Source/SkyrimNet_SexLab_OrgasmEngine.psc` | Declarations, registration and natives for the two new functions. |
| `Scripts/Source/SkyrimNet_SexLab_Scene.psc` | New state `victim_holding`, `victim_hold_timer`, `victim_hold_expired`, `victim_hold_started`, `victim_hold_stage`, `victim_hold_anim` (reset in `Ending_Reset`). New `Victim_StageStart` (called first in `Ending_StageStart`: drops a stale hold, holds the second-to-last stage once per (animation, stage), re-arms after stepping back), `Victim_Hold`, `Victim_Release` (`UpdateTimer(-PAUSE_HOLD_SECONDS)`, no held time), `Victim_Drop`, `Victim_Poll` (cap; gate scene → `VictimHoldExpired`, release 3 s later if nobody passed), `Victim_AggressorFinished`. `Ending_Check` / `Ending_WillJump`: an aggressor in the group in the second-to-last stage → `Victim_Release` + `Ending_ToFinal` (stash folds into the final-stage DN). `Engine_GatePassed`: hands the victim hold to `gate_holding` as is; releases it on the no-hold paths. `victim_holding` added to `Timer_SyncHold`, `StageRemaining`, `StageStart_HoldStash`, `FlushOrgasmWindow` and the `OnUpdate` guards. `Victim_Poll` is skipped while the orgasm window is open, and `Victim_Hold` does not register over an open window. Removed `ending_end_after` and both "aggressive NPC lead" branches. |
| `SKSE/Plugins/SkyrimNet/config/plugins/SkyrimNet_SexLab/manifest.yaml` | "Longest wait for the aggressor", `sexlab.ending.victim_hold_max` (float 0–600, default 120, Scene ending). |
| `docs/developers/orgasm-engine.md`, `docs/reference/orgasm-narration.md` | Gate step (victim hold trigger), early final roll, Scene ending "Victim hold" bullet replaces "Aggressor ends", natives list. |
| `CHANGELOG.md`, `CHANGELOG-player.md`, `CHANGELOG-developer.md` | 0.36.1 "Victim scene ending (untested)". |
| Build | `cmake --build --preset build-release` OK, DLL copied to `SKSE/Plugins/`. Pyro main (Scene, OrgasmEngine) and P+ bridge OK. `check_pex_escapes.py`: 30 checked, 0 bad. Headers regenerated. |

## 5. Known edge cases (by design, reconsider if they show up)

- Gate scene, cap reached and nobody passes the gate: the hold is released 3 s after `VictimHoldExpired`.
- A forced (WebUI) aggressor orgasm in the second-to-last stage also counts as the trigger.
- Pause during the hold stacks a second `UpdateTimer` push, the same as the gate hold. Both are undone on resume and release.
- Papyrus vars survive a save, but SexLab stops scenes on load; `held < 0` (clock reset) counts as the cap reached.

## 6. Verification (to do in game)

Logs: `SkyrimNet_SexLab.log` (engine) and the Papyrus trace (Scene).

1. **NPC-only aggressive scene (AI gate):** `Victim_Hold holding stage:N-1/N`. The stage runs past its timer and
   the aggressor bar passes 98 to 100. `victim hold: aggressor … at 100, gate`, then `gate … aggressor=true`,
   then `victim hold handed to the gate hold`, the gate DN and the voice, then the final stage.
2. **Player victim, NPC aggressor (no gate):** an aggressor orgasm before the second-to-last stage does not end
   the scene. In the second-to-last stage, the aggressor orgasm logs `final roll … victim_hold=true` for the
   others, then `Ending_Check victim hold: aggressor orgasmed`, `Ending_ToFinal`, and one folded DN.
3. **Player aggressor:** the stage holds until the player orgasms (mini-game keys), or until the cap.
4. **Cap:** `victim_hold_max` 10 with a Passive aggressor. Gate scene: `asking the gate`, then the gate runs.
   Otherwise: `releasing stage`, and SexLab advances.
5. **Edge cases:** pause and resume mid-hold; manual Next (`Victim_Drop … stage changed`); animation change
   mid-hold; step back and forward (hold re-arms); SexLab P+ (one `PauseTimer`); consensual scene (no
   `Victim_Hold`); Together mode (unchanged).

## 7. Next

- In-game test (section 6), then commit with the rest of 0.36.1.
- Consider a KNOWLEDGEBASE entry if testing turns up a quirk (e.g. a gate/timer race).
