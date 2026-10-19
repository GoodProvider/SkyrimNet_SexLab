# Checkpoint 02: "Dead actors can join scenes" toggle; necro scenes from other mods (built, not in-game tested)

Written from `C:\Skyrim\dev\mods\SkyrimNet_SexLab`, branch `main`, baseline commit `7382d93` (0.36.2 released), 2026-10-19.
Uncommitted. Supersedes [01-checkpoint.md](01-checkpoint.md).

Evidence: user logs (SexLab 1.66 + SLSO, no P+) in [logs/2026-10-19-08-10-57/](logs/2026-10-19-08-10-57/)
(`02-SkyrimNet_SexLab.log`, `02-Papyrus.0.log`, moved there from `logs/`; see `MANIFEST.txt`).

---

## 1. Goal

User report: "the necro anims with corpse keep getting cancelled even with the update 0.36.2". The maintainer asked for a
settings-dashboard toggle that makes dead actors eligible: they appear in the target list, and the animation is not cancelled.

## 2. Findings (from the 0.36.2 logs)

- Same cause as checkpoint 01. [02-Papyrus.0.log:14579](logs/2026-10-19-08-10-57/02-Papyrus.0.log#L14579)
  `ActorAlias[Dark Seducer] - Actor is out of cell, disabled, or has no health - Unable to continue animating` at `SLSO_StartAnimating`.
- **The 0.36.1 fix never ran.** The log has no `StartScene [NECRO-DBG]` and no `CorpseHealth_Floor` line. The scene was **started by another mod**:
  SexLab `AnimCache: MISS -- 2:["Necro"]` ([:14110](logs/2026-10-19-08-10-57/02-Papyrus.0.log#L14110)), thread in Making at 04:41:09.
  We only adopted it: `CreateCreator intent: ""` ([02-SkyrimNet_SexLab.log:111](logs/2026-10-19-08-10-57/02-SkyrimNet_SexLab.log#L111)) comes from
  `Scene_Manager.GetSceneByThread`. `Scene.StageStart` (the backstop) never fired, because SexLab ended the thread on entering Animating.
- The other mod lifted the corpse to about 1 Health. `ValidateActor(Dark Seducer) -- TRUE` at [:14022](logs/2026-10-19-08-10-57/02-Papyrus.0.log#L14022).
  `AnimationEnding [NECRO-DBG]` printed `dead:True health:1.000000/282` ([02-SkyrimNet_SexLab.log:115](logs/2026-10-19-08-10-57/02-SkyrimNet_SexLab.log#L115)),
  yet SexLab's `Health < 1.0` check still fired, so the value was just under 1. This settles checkpoint 01 §5.1: the ValidateActor
  contradiction was the other mod's lift.
- Timeline: `HookAnimationStarting` at 04:41:20, Prepare at 04:41:29, the thread ended at 04:41:38. `HookAnimationStarting` is early enough to floor.
- At `AnimationStart`/teardown, `thread.Positions` already reads `None` ([02-SkyrimNet_SexLab.log:126](logs/2026-10-19-08-10-57/02-SkyrimNet_SexLab.log#L126)), so a
  restore at `HookAnimationEnd` cannot rely on `Positions`.
- Our own TargetMenu could not pick corpses at all: C++ `ClassifyNearbyActor`/`IsAvailableActor` reject `IsDead()`, and 1.6x `IsValidActor` /
  `ValidateActor` (-13) reject Health < 1.

## 3. Changes

| File | Change |
|------|--------|
| `SKSE/Plugins/SkyrimNet/config/plugins/SkyrimNet_SexLab/manifest.yaml` | New bool **Dead actors can join scenes**, `sexlab.actors.dead_allowed`, default false, category Actions. |
| `SKSE_Source/include/Config.h`, `src/Config.cpp` | `SexLabNet::IsDeadAllowed()` (live `GetBool`). |
| `SKSE_Source/src/Papyrus_WebUI.cpp` | Native `IsDeadAllowed` on `SkyrimNet_SexLab_WebUI`. `ClassifyNearbyActor` and `IsAvailableActor` skip the dead rejection when on. |
| `SKSE_Source/src/ActorLocker.cpp` | `TryLock` accepts a dead actor when on. |
| `Scripts/Source/SkyrimNet_SexLab_WebUI.psc` | `Bool Function IsDeadAllowed() global native`. |
| `Scripts/Source/SkyrimNet_SexLab_Menu.psc` | `IsAvailableActor`: a corpse passes without `sexlab.IsValidActor` when on. `MultiTarget_Menu_Selection` falls back to `IsAvailableActor` for corpses. |
| `Scripts/Source/SkyrimNet_SexLab_Scene_Creator.psc` | `EnsureSexLabActorsValid`: `ValidateActor` -13 on a corpse counts as OK when on. (Plan deviation: the plan floored here, but a cancelled Scene Creator would then leave the corpse lifted. `StartScene` already floors before `AddActor`.) |
| `Scripts/Source/SkyrimNet_SexLab_Utilities.psc` | `CorpseHealth_Floor` gated by the toggle; threshold `< 5`, target 10 (was `< 1` → 2), `ForceActorValue` fallback below 2. |
| `Scripts/Source/SkyrimNet_SexLab_Scene_Manager.psc` | `AnimationStarting` → `CorpseHealth_FloorThread(tid)`: floors dead `Positions` and adds them to StorageUtil form list `skyrimnet_sexlab_corpses_tid_<tid>` on the manager. `AnimationEnd` → `CorpseHealth_RestoreThread(tid)` first. |
| `CHANGELOG*.md` (new `0.36.3 (unreleased)`), `KNOWLEDGEBASE.md`, `docs/players/overview.md` | Entries for the toggle and the follow-up cause. |

LLM action eligibility (`Actions.BodyAnimation_IsEligible`, `Scene_Manager.IsBusy`) is unchanged, so NPC dialogue never picks a corpse.
NECRO-DBG instrumentation is kept (`grep -rn NECRO-DBG Scripts/Source`).

Build: pyro main (5 ok) + P+ bridge (1 ok); `make check-pex`: 30 checked, 0 bad. Release DLL built (`cmake --build --preset build-release`,
one pre-existing C4100 warning) and copied to `SKSE/Plugins/SkyrimNet_SexLab.dll`.

## 4. Not yet tested

Nothing in game. On P+ the toggle only affects the target list. Whether P+ `AddActor` accepts a corpse from our TargetMenu is unverified.

## 5. Open questions / risks

1. **Toggle off = old behavior.** A necro scene from another mod is still cancelled on 1.6x unless the user turns the toggle on. Players must be told.
2. A corpse lifted to 10 Health during the scene: a mod reading `IsDead && Health > 0` as revivable could react. A crash mid-scene leaves 10
   (harmless for a corpse). The form list lives on the manager in the save; a stale entry is cleared at the next `AnimationEnd` of that tid.
3. If another mod's `HookAnimationStarting` handler (or SexLab's Prepare `OnUpdate`) runs before ours, the floor could still be late. Prepare
   OnUpdate passed in this log because the corpse was at about 1, but a corpse at 0 could fail in Prepare. If so, also floor from `HookAnimationPrepare`.
4. Still open from 01: position mix-up in SetPosition, JSON dead handles after AnimationEnd
   ([02-SkyrimNet_SexLab.log:143](logs/2026-10-19-08-10-57/02-SkyrimNet_SexLab.log#L143)), and necro narration roles: both actors are listed as assailants,
   and the afterglow says "None and None Finish" ([:142](logs/2026-10-19-08-10-57/02-SkyrimNet_SexLab.log#L142)).

## 6. Next

1. Deploy the new DLL and pex (SexLab 1.66 + SLSO). In the SkyrimNet dashboard, turn on **Actions > Dead actors can join scenes**.
2. Toggle off: a corpse shows as "(dead)" in the TargetMenu and can't be picked.
3. Toggle on, our TargetMenu: pick a corpse, start a necro scene. Expect `CorpseHealth_Floor … -> 10`, the scene past stage 1, then
   `CorpseHealth_Restore` and the corpse lying dead.
4. Toggle on, the other mod's start (the user's path): expect `CorpseHealth_Floor` right after `AnimationStarting`, no "has no health" line in
   `Papyrus.0.log`, and the scene running to the end.
5. Send the user the new build. Reply draft:
   > Thanks, the new log showed the scene was started by another mod, so our corpse fix never got a chance to run. The next build adds a
   > SkyrimNet dashboard option, **Actions > Dead actors can join scenes**. Turn it on: corpses then show in the TargetMenu, and a necro scene
   > (also one another mod starts) keeps the corpse at a little Health so SexLab doesn't cancel it. If it still ends, please send
   > `SkyrimNet_SexLab.log` and `Papyrus.0.log` again.
6. Once verified: remove the NECRO-DBG lines, rebuild with pyro, drop "(untested)" from the changelogs.
