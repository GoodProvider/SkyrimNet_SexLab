# Checkpoint v16: retain-before-attach fix + Stage S3a — compiled clean, not yet in-game tested

Supersedes [v15-checkpoint.md](v15-checkpoint.md). Written from `c:\Skyrim\dev\mods\SkyrimNet_SexLab`,
branch `skse-scene`, baseline commit `b8e5470`. Nothing committed. `extern/JContainers/` is still
untracked and unrelated; leave it alone.

---

## 1. S3 scoping pass (v15 §2): results

| File | JC calls | Member-held JC handles | Missing SNSL natives | Cross-file handle coupling |
|------|----------|------------------------|----------------------|----------------------------|
| `Scene_Manager.psc` | 190 in 11 functions (now 116 after S3a) | `group_info` only | none | `group_info` (read by Creator + Scene), 3 JC handoffs (`ApplyWebUIState`, `ApplyWebUICommit`, `WebUI_ApplyLivePositions`), `creator.BuildWebUIObject()` return, DOM `GetThreads()` (external mod, always bridged) |
| `Scene_Creator.psc` | 140 | none (all temporaries) | `JArray.asIntArray` (1004, 1036; replace with count+getInt loop) | same as above |
| `Handler_UDNG.psc` | 51 | `group_devices`, `actor_bondage` | `JMap.allKeysPArray`, `JFormMap.hasKey` | none |

**Scope decision (user):** S3a = the four self-contained `Scene_Manager` functions (done, §3).
S3b = `group_info` + all of `Scene_Creator.psc` + the three JC handoffs with their `Scene.psc`
receivers, together. `Handler_UDNG.psc` moves to S4.

Notes for S3b:
- `group_info`'s guard at Scene_Manager:133 is `== 0` only; add `isExists` when migrating.
- Creator's `BuildWebUIObject` `setObj`s borrowed `group_info` subtrees; in SNSL that is an
  already-owned attach (copy + error log). Build its own copy instead.
- `Scene_Manager:944` never releases the JC `st` (relies on JC GC); with SNSL, release explicitly.
- `Scene_Creator.psc:899` checks `setting_id < 0`, which can't fire (store returns 0). Should be `< 1`.
- `Scene_Creator.psc:1841` `arr` is never released (leaks under SNSL).
- SNSL `writeToFile` writes compact JSON and doesn't create folders (`scenes/` ships, so fine).

## 2. Bug fix: `position_objs` retained before attach (v13 bug class)

Found by the audit and confirmed against `AttachChild` (`JsonStore.cpp:294`). `position_objs[i]`
was retained at creation and then `setObj`'d into `actors_objs`. Retained + unowned deep-copies, so
`actors_objs`/`thread_obj.actors` only ever held copies:
- the dumped `thread_obj.actors` was one refresh behind (`GetThreadObj` relinked before `updateactor`);
- `OrgasmMessagesToNarration`/`MarkOrgasmNarrated` wrote `orgasm_narrated` to the copy, and the next
  `AlignActors` relink discarded it. On the Dom Combined fallback that could re-narrate.
- `Release` (`clear(thread_obj)` + re-`setObj`) and `Initialize`'s legacy `removeKey("actors")`
  scrub did the same to `actors_objs` itself.

Fix (user chose "position_objs canonical"), all in `SkyrimNet_SexLab_Scene.psc`:
- New `ResetActorsObjs(size)` (release, create, attach, then retain) replaces the three inline
  resize blocks, `Release`'s re-attach, and `Initialize`'s scrub + `elseif` re-attach.
  `Initialize` now recreates when `getObj(thread_obj,"actors") != actors_objs`.
- New `RelinkActorsObjs(size)` snapshots `position_objs` into `actors_objs`. Called at the end of
  `AlignActors` and in `GetThreadObj` after its `updateactor` loop. `SetActor` no longer writes
  `actors_objs`.
- `OrgasmMessagesToNarration` reads/writes `position_objs[k]` instead of `actors_objs[k]`.
- `GetObjFromActor`: the StorageUtil-cached handle survives a load; if dead, fall back to the
  actor's live `position_objs` slot (else 0). `UpdateActor` compares the **raw** StorageUtil value
  so a dead handle still triggers the `SetActor` rebind (keeps the v10 self-heal).
- `SNSL_JValue.psc`: the `retain` doc comment claimed no-op; corrected.
- KNOWLEDGEBASE.md: new entry "JSON store: a retained handle is copied, not linked, when attached".

## 3. Stage S3a: four `Scene_Manager.psc` functions migrated to SNSL

- `SaveSceneSettingFromWebUIJson`, `BuildSceneConnectionsJson`, `WebUI_OnResolveActorMeta`: fully
  SNSL (mechanical rename, `ObjectToLowerCaseKeyJson` → `SNSL_JValue.dump`).
- `WebUI_OnAnimRegistrySave`: only the `payload` half (the output sent to `animdb.SaveAnimLocal`).
  `obj` stays JC because it's passed to `Scene.WebUI_ApplyLivePositions` (S3b).

Compiled clean via `compile: pyro` (Scene + SNSL_JValue: 2 succeeded; Scene_Manager: 1 succeeded).

## 4. First in-game test (09:00-09:04) and the follow-up fixes

User report: (1) dressed didn't reach the Description Editor, (2) the Dom orgasm wasn't blocked,
(3) `b_b_lyfacesit1.json` didn't get `clothed:[1,0]` / `orgasm_expected:[0,1]`.

From `SkyrimNet_SexLab.log` (in `OneDrive\Documents\my games\...\SKSE\`):
- Before the reload, the handoff and §2 fix worked: thread JSON at 09:00:31 had Nina
  `dressed:1, no_orgasm:1`, Camilla `["_pleasure_"]`.
- The user reloaded mid-scene at 09:01:50 (on purpose; this was my wrong checklist item 3, which
  claimed `no_orgasm` would survive a reload). SexLab ended the thread itself on load (`Frozen`,
  SexLab's own `AnimationEnd` event), and the ended-scene snapshot was built from freshly reset
  `position_objs`, so the DE showed defaults.
- The Dom orgasm at 09:03:23 was `Handler_DOM`'s delayed-melt fallback (queued 09:01:53 while
  the scene was unreachable), which narrates directly and never checks `no_orgasm`.
- The DE save at 09:02:23 went to `ace_cuddlefrombehind`, not the scene's animation: case-sensitive
  registry comparisons in the DE focus logic (AnimDB lowercase vs SexLab casing).
- S3a's `WebUI_OnAnimRegistrySave` itself worked (it wrote the payload correctly, to the wrong file).

Fixes (user chose StorageUtil persistence; compiled clean, 3 succeeded):
- `Scene.psc`: per-position settings (`no_orgasm`, `deny_orgasm`, `dressed`, `orgasm_locked`,
  `speaking_locked`, speaking CSV) mirrored per actor in StorageUtil under `skyrimnet_sexlab_pos_*`
  (outside `storage_prefix`, which `Initialize` clears every load), tagged with `thread.tid`.
  - `PersistPositions()` at the end of `Setup`, `SeedOverlayFromAnimDb` (both exits),
    `TM_SaveAnimationSettings`, and inside `MarkUserDefaultsDirty` (covers `WebUI_ApplyLivePositions`
    and the three `TM_Apply*`). Only persists slots whose actor is bound, so an unrestored slot
    can't overwrite saved values.
  - `RestorePosition(i, actor)` runs in `EnsureActorArraysLargeEnough` when a dead slot is
    recreated, i.e. before `SeedOverlayFromAnimDb`/`SetPosition` can read it.
  - `Release` clears the keys.
- `Scene_Manager.IsNoOrgasmPersisted(actor)` + `Handler_DOM.DOMSlave_Orgasmed`: when the scene is
  unreachable, drop the delayed melt if the actor has `no_orgasm`.
- `index.html`: `deResolveDefaultScenePick` and `deEnsureFocus` compare registries with `deRegEq`
  and focus the list's own spelling.

- `dressed_locked` (user: speaking, orgasm and dressed must be consistent). `SeedOverlayFromAnimDb`
  used to reset `dressed` from AnimDB on every animation change, so a Scene Creator dressed choice
  was lost at the next animation. Now set wherever the other two locks are set (`Setup` creator
  block, `WebUI_ApplyLivePositions`) plus `TM_ApplyClothed`; honored in both `SeedOverlayFromAnimDb`
  loops; cleared in `TM_SaveAnimationSettings`; persisted/restored/cleared with the others.
  Compiled clean.
- **Lock rule (user): locks hold only within one animation. Changing animation reloads the new
  animation's defaults.** New `SyncAnimationDefaults()` compares `thread.animation.Registry` with
  `seeded_registry`; on a change it clears all three locks (`ClearPositionLocks`) and runs
  `SeedOverlayFromAnimDb`. Called from `StageStart` (catches SexLab-native changes), both
  `WebUI_OnAnimUpdate` switch paths, and `Actions.TM_SetAnimationIndex` (was a lock-respecting
  `SeedOverlayFromAnimDb`). `ApplyWebUICommit` only records the new registry
  (`NoteSeededRegistry`) because it has just applied the Description Editor's positions for that
  animation. `Setup` sets the baseline to the starting animation; `Release` resets it.
  After reseeding it also strips/re-dresses each actor to the new `dressed` value via the new
  `ApplyDressedToActor` (sslActorAlias.Strip/UnStrip, extracted from `WebUI_ApplyLivePositions`).

## 4b. Second in-game test (09:58-10:01): JSON store session collision (C++ fix)

User: started with a cuddle (dressed 1, orgasm 0), switched to cowgirl (dressed 0, orgasm 1,
`_pleasure_`); nothing changed. The log shows `"Threads":[NULL]` from scene start and
`dead handle ... session=2/2` errors: handles loaded from the save aliased new objects, because
the store's session counter restarts at the same value every game run (see KNOWLEDGEBASE "JSON
store handles from a save can alias new objects after a game restart"). Everything on
`position_objs`/`thread_obj` was unreliable in this test, so it says nothing about the lock logic.
No `SyncAnimationDefaults` line, no `AnimationChange` hook, and no `StageStart` after 10:00:00
appear in the logs (the Papyrus log ends at 10:00:55), so how the switch was made is still unknown.

Fix (C++, built and deployed to `SKSE/Plugins/SkyrimNet_SexLab.dll` 10:05): `Json::OnNewSession`
empties the store and never reuses the loaded save's session (recorded in the co-save via
`plugin.cpp` serialization callbacks); sessions start at 32. Look for
`JsonStore: new session N (loaded save session M), freed K nodes` in the log after each load.

Follow-up: the user switches animations with SL Tools on SexLab 1.66b + SLSO (not P+). SLSO's
`SetAnimation` sends no hook (SL Tools' list menu calls it directly); `ChangeAnimation` sends
`HookAnimationChange`. Added: `Scene_Manager` handles `HookAnimationChange` ->
`SyncAnimationDefaults`, and `Scene` polls `SyncAnimationDefaults` in `GetThreadObj` (runs every few
seconds via Get_Threads) and at the start of both WebUI menu-state builders. Compiled clean.

Animation change = stage start (user): `SyncAnimationDefaults` now returns True on a change.
`StageStart` calls it directly and, on a change, narrates (DN, or event if dedupe drops it)
"Scene changes from <old stage description> to <new stage description>" (no anidata transition
lookup across animations). All other detection points call `CheckAnimationChange()`, which reloads
defaults immediately and queues StageStart via our mod event `SkyrimNet_SexLab_AnimationChanged`
(Scene_Manager `AnimationChangedStage`), so nothing narrates from inside `GetThreadObj`.
`NoteSeededRegistry` (Description Editor commit) queues the same narration without reseeding.

Third test (16:42-16:44): cuddle -> anal (SL Tools list) not detected. Session fix confirmed working
(`new session 33`). Cause: nothing ran the check. No LLM prompt was built (no `GetThreadObj`), SLSO
`SetAnimation` sends no `StageStart`, and the menu seed path (`BuildAllSceneInfosJson` ->
`BuildWebUISceneMenuObject`) skips the check. Fix: `Scene_Manager` polls every 2 s while any scene
is animating (`OnUpdate` -> `Scene.PollAnimationChange` -> `CheckAnimationChange`), started from the
`AnimationStart` and `StageStart` handlers, stopping when nothing animates.
Open: `RestorePosition` fired 5 times mid-scene (live `position_objs` slots recreated). Cause not
found; possibly Papyrus interleaving across native calls. Added trace "recreating dead slot N old
handle:H" (active scenes only) to catch it next test.

Fourth test (16:55-16:59): still failing. The user asked for this checkpoint update only; nothing
else was changed. Log findings (`SkyrimNet_SexLab.log`):
- No `SyncAnimationDefaults` line anywhere, including switches to `APAnal` (16:56:10, 16:58:56)
  and `Ace_Headpat` (16:58:31). The 16:56:04 narration is the ordinary StageStart
  "Scene changes to ..." (event `Change`), not the new "from ... to" form.
- No "recreating dead slot" trace, yet `RestorePosition` fires ~20 times, always Bob, index 1,
  both before and after the 16:57:34 load.
- **Probably not testing the latest scripts.** The 16:57:34 load logged `new session 34 (loaded
  save session 33)`, so it is the same game process as the 16:42 run (session 33). That process
  started after the 16:36 compile but before the 16:50 compiles (poll + trace), and Skyrim keeps
  loaded script definitions for the life of the process. Restart the game before the next test.

Next session:
1. Confirm the game was restarted after the last compile (the first load logs `new session 33`).
2. If `SyncAnimationDefaults` still never logs with the poll loaded, add a Trace in
   `Scene_Manager.OnUpdate` and `Scene.PollAnimationChange` (thread state, registry,
   `seeded_registry`) to see whether the poll runs and what it compares.
3. Bob's slot 1 is recreated repeatedly with no "dead slot" trace, so `position_objs[1] < 1` (zero,
   not a dead handle), or status was not ACTIVE. Suspects: `position_objs` replaced by a shorter or
   fresh array (`EnsureIntsLargeEnough` in `EnsureActorArraysLargeEnough`), or Papyrus interleaving
   between threads (many thread IDs call it). Trace `position_objs.length` and the old value on
   every recreate, regardless of status.

## 5. In-game checklist

1. **Thread JSON is current:** start a 2+ actor scene; in the LLM thread JSON, `actors[]` shows
   correct names/uuid/enjoyment/notice_level/dressed/no_orgasm with no `NULL` entries. (Passed in
   the first test.)
2. **Orgasm narration:** each orgasm is narrated once, not repeated on the next flush.
3. **Save/reload mid-scene:** set dressed + no-orgasm on an actor in the Scene Creator, start, save,
   reload. SexLab will end the scene on load. Expect `RestorePosition` lines in the log, and the
   Description Editor (ended scene) to show the dressed/no-orgasm choices. A DOM orgasm for that
   actor right after the load should log "has no_orgasm, dropping delayed melt".
4. **DE focus after reload:** with no live scene, opening the DE picks the ended scene's animation
   (`B_B_LYFaceSit1`), and Save writes that animation's file.
5. **Animation change reloads defaults:** start a Scene Creator scene with dressed + no-orgasm set,
   then switch to a different animation (Animation Menu, Target Menu, SexLab hotkey, SL Tools list). The log
   shows `SyncAnimationDefaults ... reloading its defaults`, and thread JSON `dressed`/`no_orgasm`/
   speaking match the new animation's defaults (e.g. a cuddle: no orgasm). Actors are
   physically stripped or re-dressed to match the new animation's `clothed`. Stage changes within the
   same animation keep the choices. A narration "Scene changes from <cuddle stage text> to <cowgirl
   stage text>" follows each switch.
6. **Release/reuse:** end the scene and start another in the same slot; `actors[]` is fresh and
   no settings carry over from the previous scene.
7. **S3a — Scene Creator save:** save a scene preset from the WebUI, reload it in the Scene Creator.
   Style/tags/per-position dressed/no-orgasm/speaking/victim round-trip.
8. **S3a — Scene connections pulldown:** lists "new" plus the active scenes.
9. **S3a — actor meta:** adding an actor in Scene Creator fills gender/race.
10. **S3a — Animation registry save:** the saved file has stage descriptions, `orgasm_expected`,
   `speaking_modifiers`, `clothed` (confirmed working for `ace_cuddlefrombehind`).

## 6. Next session checklist

- [ ] Run §5; get user confirmation.
- [ ] Commit `Scene.psc`/`.pex`, `Scene_Manager.psc`/`.pex`, `Handler_DOM.psc`/`.pex`, `Actions.psc`/`.pex`, `SNSL_JValue.psc`/`.pex`, `index.html`, `SKSE_Source/src/JsonStore.cpp`, `SKSE_Source/include/JsonStore.h`, `SKSE_Source/src/plugin.cpp`, the DLL,
      `KNOWLEDGEBASE.md` (and this checkpoint dir if the user wants it tracked).
- [ ] Start S3b per §1.
- Backlog from v15 §3 is carried forward unchanged.
