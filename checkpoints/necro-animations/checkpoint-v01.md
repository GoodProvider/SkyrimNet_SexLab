# Checkpoint v01: necro / corpse scenes end right after they start on SexLab 1.6x (built, not in-game tested)

Written from `C:\Skyrim\dev\mods\SkyrimNet_SexLab`, branch `main`, baseline commit `f38504f`, on top of the
uncommitted 0.36.1 work. Committed 2026-10-17 together with the P+ AnimDB fix (see section 6). Evidence: one user log,
`bug-logs/SkyrimNet_SexLab-funnybuz-corpse.log` (their machine; no Papyrus log).

---

## 1. Goal

A user reports that FunnyBizness necro animations with a corpse "try to start, but get cancelled
automatically". Find the cause from the log, fix it, and add removable instrumentation to confirm it.

## 2. Decisions

- **SexLab ended the thread, not us.** Setup: SexLab 1.66 + SLSO, no P+. Scene 1 (FB_MolagNecroDoggy) logs
  `StageStart stage:1/5 state:Animating`, then 10 s later `AnimationStart stage:5/5 state:Ending`, then
  `AnimationEnd status:Frozen`. Scene 2 (FB_NecroAnalDog) logs `stage:5/5` at its first StageStart.
  `sslThreadController.EndAnimation` (extern/Source_SexLab/sslThreadController.psc:856) sets
  `Stage = StageCount`, waits 0.5 s, then switches to `Ending`, which matches both scenes. Each of our own
  `EndAnimation` callers (Scene.psc Ending_Poll / Ending_Watch / PPlus_StageStart, Scene_Creator orphan
  thread) writes a Trace first, and none of those traces appear.
- **Most likely trigger:** `sslActorAlias` OnUpdate in Prepare and Animating (sslActorAlias.psc:591, 772;
  the same in SLSO) calls `Thread.EndAnimation(true)` when an actor is
  `!Is3DLoaded() || IsDisabled() || (IsDead() && Health < 1.0)`. A corpse normally has Health ≤ 0.
- **Fix approach:** keep a dead actor at Health 2 for the scene. That is the exception SexLab's own check
  allows; the actor stays dead. Restore the saved value at the end. 1.6x only: P+ records dead actors at
  `SetActor` (`_livestatus`) and kills them silently again on `Clear`.
- **Restore point:** `Scene.AnimationEnd`, which runs from HookAnimationEnd, after SexLab's actor reset
  (dead actors get `IdleSoupDeath` / ragdoll). Also on a failed start (AddActor / StartThread / no scene).
- The user chose fix + instrumentation over instrumentation only.

## 3. Changes

| File | Change |
|------|--------|
| `Scripts/Source/SkyrimNet_SexLab_Utilities.psc` | `CorpseHealthKey`, `CorpseHealth_Floor(actor)` (IsDead and Health < 1 → save, `RestoreActorValue` to 2, `ForceActorValue` as fallback, Trace), `CorpseHealth_Restore(actor)` (damage back to the saved value, unset). **NECRO-DBG:** `NecroDbg()` flag (returns true), `NecroDbgSnapshot(func, actors, extra)`: one line per actor with dead / health / base / 3d / disabled / unconscious / saved. |
| `Scripts/Source/SkyrimNet_SexLab_Scene_Creator.psc` | StartScene: floor every actor before the AddActor loop; `RestoreCorpseHealth()` on AddActor failure, `StartThread` None, and orphan thread. **NECRO-DBG:** snapshots before and after the floor; "AddActor ok" lines. |
| `Scripts/Source/SkyrimNet_SexLab_Scene.psc` | StageStart: floor dead positions (backstop). AnimationEnd: restore every ended actor. **NECRO-DBG:** snapshots in StageStart, AnimationStart, AnimationEnd; SetPosition logs index plus `thread.Positions` and state. |
| `Scripts/Source/SkyrimNet_SexLab_Scene_Manager.psc` | **NECRO-DBG:** registers `HookAnimationEnding` → `NecroDbg_AnimationEnding` (snapshot with tid / stage / state / auto / anim), sent as SexLab enters Ending. |
| `Scripts/*.pex` | Rebuilt with pyro `--no-incremental-build` (27 ok) plus the P+ bridge; `check_pex_escapes.py`: 28 checked, 0 bad. |
| `CHANGELOG.md`, `CHANGELOG-player.md`, `CHANGELOG-developer.md`, `KNOWLEDGEBASE.md` | 0.36.1 entries; KNOWLEDGEBASE entry with the "stage N/N, Ending" fingerprint. |

Remove the instrumentation later: `grep -rn NECRO-DBG Scripts/Source`. Delete the tagged lines and the
`NECRO-DBG begin … end` blocks in Utilities and Scene_Manager, keep the `UnRegisterForModEvent("HookAnimationEnding")`
line or drop it too, then rebuild with pyro.

## 4. Verification (to do in game, SexLab 1.66 + SLSO)

1. Kill an NPC and start a FunnyBizness necro animation on the corpse with the player.
   `SkyrimNet_SexLab.log` should show:
   - `StartScene [NECRO-DBG] … dead:True health:<=0 … before corpse floor`
   - `CorpseHealth_Floor … health X -> 2`
   - `after corpse floor … health:2`, then `AddActor ok`.
2. The scene goes past stage 1 on its normal timers. `StageStart [NECRO-DBG]` keeps health ≥ 1.
3. At the end: `AnimationEnding [NECRO-DBG]` shows `stage:N` normally, `CorpseHealth_Restore … -> X`, and the
   corpse lies dead (not standing / not revived).
4. To confirm the cause: temporarily make `CorpseHealth_Floor` return false at the top. `AnimationEnding
   [NECRO-DBG]` right after the start should then show the corpse `dead:True health:<1`.
5. On P+: no `CorpseHealth_*` lines; necro scenes behave as before.

## 5. Known risks / open questions

1. **ValidateActor contradiction:** stock 1.6x `ValidateActor` returns -13 for `IsDead && Health < 1`, yet the
   user's `AddActor` succeeded. Possible explanations: the corpse had Health ≥ 1 when added and something
   lowered it, their SexLab/SLSO build is patched for necro, or the failing check was 3D / disabled instead.
   The `before corpse floor` and `AnimationEnding` snapshots settle it. If health was already ≥ 1 and the
   snapshot shows `3d:False` or `disabled:True`, this fix is not enough.
2. **Position mix-up in scene 2:** SetPosition logged index 0 and 1 both as "Dark Seducer", and both afterglow
   lines were "Lilith Bloodthorn". It probably comes from reading `thread.Positions` while SexLab is tearing
   the thread down. The new SetPosition `[NECRO-DBG]` line shows the positions array each time. Not fixed.
3. **JSON dead handles** (`SexLabNet::Json … dead handle`) right after AnimationEnd in both scenes. Probably
   the same teardown race. Not investigated.
4. **Narration roles:** the start narration said "Dark Seducer is sexually assaulting Lilith Bloodthorn" (the
   corpse as assailant; both actors listed as assailants). Necro wording/roles are not handled. Not fixed.
5. Corpse Health 2 during the scene: a mod that reads `IsDead && Health > 0` as "revivable" could react.
   Restore runs at the end; a crash or load mid-scene leaves Health at 2, which is harmless for a corpse.
6. `compile: papyrus` (papyrus.exe) was run once by mistake before the pyro rebuild. CLAUDE.md / AGENTS.md
   still say `compile: papyrus`, but 0.36.1 made pyro the default because papyrus.exe breaks `"\""`. The
   pex files were rebuilt with pyro and checked clean afterwards.

## 6. Log review 2026-10-17 (this machine, snapshot `review-logs/2026-10-17_082702/`)

User reported "no bug appears". The snapshot shows only a game load, not a necro test:

- `SkyrimNet_SexLab.log` (52 lines, 08:23:02–08:23:27): plugin load, AnimationDB opened (762 rows), WebUI /
  Hud DomReady. No scene, no `StartScene`, no `CorpseHealth_*`, no `[NECRO-DBG]` lines. The only warnings
  are the known `strategies.json` unknown-key / no-entry lines.
- `SkyrimNet.log`: 0 error lines. `Papyrus.0.log`: missing-script lines from other mods, plus
  `Unknown property type 97/101 … SkyrimNet_SexLab_Handler_UDNG_PR`, which has been there since the 10-08
  snapshots (not new).
- No crash log newer than `crash-2026-10-11-23-22-12.log`.

Result: the 0.36.1 build loads cleanly. The corpse fix is **still unverified**. Section 4 is still to do.

## 7. Draft reply to the reporting user

> Thanks for the log. It shows SexLab itself ending the scene a few seconds after it starts, not
> SkyrimNet_SexLab. On SexLab 1.6x (and SLSO), an actor that is dead and has under 1 Health is treated as
> "unable to continue animating", so the thread is ended right away. The next build keeps the corpse at a
> sliver of Health for the scene (it stays dead) and puts it back afterwards. If it still happens with that
> build, please send `SkyrimNet_SexLab.log` again (it has extra `[NECRO-DBG]` lines now) plus `Papyrus.0.log`
> from `Documents/My Games/Skyrim Special Edition/Logs/Script/`. SexLab's own line there reads "Actor is out
> of cell, disabled, or has no health".
