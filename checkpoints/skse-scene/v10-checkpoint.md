# Checkpoint v10: `position_objs` + `actors_objs` + `thread_obj` migrated to JsonStore — compiled clean, not yet in-game tested

Supersedes [v9-checkpoint.md](v9-checkpoint.md). v9's DE scene-pulldown fix + v8's `user_anim_defaults`
migration are both already committed as `2c5f505` (confirmed via `git log` this session — v9's
"not yet committed" note was stale).

Written from `c:\Skyrim\dev\mods\SkyrimNet_SexLab`, branch `skse-scene`, baseline commit `2c5f505`.

---

## 1. Stage S2 completed: `position_objs`, `actors_objs`, `thread_obj` migrated to JsonStore

Per the staged S0-S5 JContainers migration plan (`v5-checkpoint.md` §3 / `v7`/`v8-checkpoint.md`),
this was the last remaining S2 scope: the three holders left after `victim_faction_forms` (v7) and
`user_anim_defaults` (v8/v9). Unlike those two, research this session confirmed the three **must
migrate together** — `Initialize`/`Setup`/`Release`/`AlignActors` touch all three in the same
blocks, and `AlignActors` re-links every `position_objs[i]` into `actors_objs` in one pass, so a
partial migration would mix handle spaces in the same array. User confirmed doing all three as one
combined slice rather than bridging (research found **no missing SNSL natives** for any of the
three — every JContainers call they use already has a bound SNSL equivalent — so a temporary
bridge would only have added throwaway code with no risk reduction).

- Widened the same three creation guards as v7/v8, `< 1` → `< 1 || !SNSL_JValue.isExists(...)`:
  `thread_obj`/`actors_objs` in `Initialize` (~162-178), `position_objs[i]` per-slot in
  `EnsureActorArraysLargeEnough` (~559-561).
- Mechanically renamed every remaining `JMap.`/`JArray.`/`JValue.` call touching these three
  holders to `SNSL_JMap.`/`SNSL_JArray.`/`SNSL_JValue.`, across ~25 functions in
  `SkyrimNet_SexLab_Scene.psc`: `Setup`, `Release`, `EnsureActorArraysLargeEnough`, `SetPosition`,
  `SetSpeakingObj`, `ApplyAnimDbSpeaking`, `SpeakingCsvFromIndex`, `SetActor`, `UpdateActor`,
  `AlignActors`, `GetNames`, `AnimationEnd`, `OrgasmCombined`, `OrgasmIndividual`, `OrgasmCustom`,
  `SetTotalOrgasms`, `OrgasmMessagesToNarration`, `MarkOrgasmNarrated`, `ThreadHasDomSlave`,
  `BuildWebUIAnimationMenuState`, `WebUI_ApplyLivePositions`, `BuildWebUISceneMenuObject` (dropped
  its stale "still a JContainers map" comment), `CacheUserDefaultsForRegistry`,
  `SeedOverlayFromAnimDb`, `TM_ApplyOrgasmMode`, `TM_ApplySpeaking`, `TM_ApplyClothed`,
  `TM_SaveAnimationSettings`, `GetThreadObj`. Included every indirect touch via
  `GetObjFromActor(akActor)` (a `StorageUtil`-cached `position_objs[i]` handle) in
  `OrgasmIndividual`/`OrgasmCustom`/`SetTotalOrgasms`, and via `actors_objs[k]` lookups in
  `OrgasmMessagesToNarration`/`MarkOrgasmNarrated` — same handle space as `position_objs`, easy to
  miss since the parameter isn't literally named `position_objs`.
- Left untouched (confirmed genuinely unrelated, standalone JContainers temporaries, not part of
  these three holders): `BuildWebUIAnimationMenuState`'s own `obj`/`po`/`pos_arr`,
  `BuildWebUISceneMenuState`'s `payload`, `TM_SaveAnimationSettings`'s `payload`/`orgasm_arr`/
  `speak_arr`/`clothed_arr`, `AnimationEnd`'s `glow_obj`, `AddCum`'s `cum_obj`, and all of
  `Scene_Manager.psc`'s own JContainers-only structures (`manager.group_info`, DOM's
  `threads_dom`).

### Two JSON-serialization consumers fixed (logic changes, not mechanical renames)

Both `thread_obj`'s dump paths previously walked it with the legacy Papyrus JSON walker
(`SkyrimNet_SexLab_Utilities.ObjectToLowerCaseKeyJson`), which only understands JContainers
handles — now dead code for an SNSL handle (would silently produce garbage/empty output, not an
error):
- `Scene.psc`'s own `GetThreadJson` (~1750): `ObjectToLowerCaseKeyJson(thread_obj)` →
  `SNSL_JValue.dump(thread_obj)`.
- `Scene_Manager.psc`'s `GetThreadsJson` (~1595): `JArray.addObj(threads_array,
  sl_scene.GetThreadObj(speaker))` embedded a raw SNSL handle into a **legacy JContainers** array
  (`threads_array`), which would silently corrupt it once walked by `ObjectToLowerCaseKeyJson`. Fixed
  by bridging via a JSON round-trip instead of embedding the handle directly — same pattern already
  used in `BuildWebUIAnimationMenuState` for `group_info`'s subtrees:
  `JArray.addObj(threads_array, JValue.objectFromPrototype(SNSL_JValue.dump(sl_scene.GetThreadObj(speaker))))`.
  The DOM branch in the same function (a separate, unrelated JContainers structure from
  `main.handler_dom.GetThreads()`) was not touched.

### Mid-scene save/load tradeoff — accepted by user, same as v7/v8

`thread_obj`/`actors_objs` self-heal on the next `Initialize()` (reruns every load via the existing
`OnPlayerLoadGame → Main.Setup() → Scene_Manager.Setup() → sl_scenes[i].Initialize()` cascade,
confirmed by reading `Scene_Manager.psc:105-115`). `position_objs[i]` self-heals on the next
`AlignActors()` call (fires on essentially every scene-state-changing event — confirmed by reading
every call site). Between reload and that next call, `SetActor`/`UpdateActor` already re-derive
most fields fresh from live actor/thread state via the pre-existing `StorageUtil`-tracked
binding-mismatch check (confirmed by reading `SetActor`, Scene.psc:660-747) — unaffected. Only
`no_orgasm`/`dressed`/`speaking_modifiers`/`deny_orgasm` (set by `SetPosition`/WebUI, not by
`SetActor`) reset to defaults for a scene reloaded mid-animation, until the user re-sets them via
WebUI. **User explicitly accepted this** before implementation — no StorageUtil-backed persistence
work was done for these fields; out of scope for this slice.

Compiled clean via `compile: pyro` — "2 succeeded, 0 failed". `git diff --stat` confirms only
`SkyrimNet_SexLab_Scene.psc`/`.pex` and `SkyrimNet_SexLab_Scene_Manager.psc`/`.pex` changed.

---

## 2. NOT yet done this session

- **Not tested in-game.** None of §1's migration has been verified against a running game yet.
- **Not committed.** Working tree has the four files above modified; nothing staged.

---

## 3. Stage S2 is now fully complete

All five persisted "holder" handles in `Scene.psc` (`victim_faction_forms`, `user_anim_defaults`,
`position_objs`, `actors_objs`, `thread_obj`) are migrated to `SNSL_J*`/JsonStore. Per
`v5-checkpoint.md` §3, remaining stages: `Scene_Creator.psc` (140 JContainers call sites, entirely
untouched) and most of `Scene_Manager.psc` (206 total, ~20 touched across S1/S2 so far — mostly
just this session's `GetThreadsJson` bridge fix) — S3+ scope for a future session.

`position_objs[i]["victim"]`/`"assailant"` narration staleness (`v7-checkpoint.md` §5) remains
known, deferred, not currently reported — still out of scope.

---

## 4. Next session checklist

- [ ] In-game test the checklist below; get user confirmation before considering this slice done.
- [ ] Once confirmed, commit `SkyrimNet_SexLab_Scene.psc`/`.pex` +
      `SkyrimNet_SexLab_Scene_Manager.psc`/`.pex` together.
- [ ] Stage S2 is done after this — next session should scope S3 (`Scene_Creator.psc` and/or the
      rest of `Scene_Manager.psc`) per `v5-checkpoint.md` §3, likely starting with an Explore pass
      similar to this session's (size the holders, check for missing SNSL natives, check
      cross-holder/cross-file coupling) before committing to an approach.

### In-game verification checklist for this slice

1. **Basic scene lifecycle:** start a 2+ actor scene, confirm Description Editor/WebUI scene menu
   shows correct names/uuids/dressed/victim state (exercises `SetActor`/`UpdateActor`/
   `BuildWebUISceneMenuObject`/`BuildWebUIAnimationMenuState`).
2. **Live per-position toggles:** set `no_orgasm`/dressed/speaking modifiers/deny_orgasm via WebUI
   mid-scene, confirm they apply and read back correctly (`SetPosition`,
   `WebUI_ApplyLivePositions`, `TM_ApplyOrgasmMode`/`TM_ApplySpeaking`/`TM_ApplyClothed`).
3. **Orgasm/narration flow:** trigger an orgasm, confirm `OrgasmCombined`/
   `OrgasmMessagesToNarration`/`MarkOrgasmNarrated` still narrate correctly (exercises the
   `actors_objs`/`position_objs` shared-handle path) — this is the path most likely to have a
   missed rename (obj pulled from `actors_objs`, not literally named `position_objs`).
4. **GetThreadJson / GetThreadsJson still produce valid JSON:** check for `JsonLowerCaseKeys: parse
   failed` or empty/`NULL` thread fields wherever these feed the LLM prompt/WebUI — this is the one
   real logic change in the slice (§1's two consumer fixes), verify explicitly.
5. **Save/reload mid-scene:** confirm no dead-handle warnings spam the log, confirm the scene
   self-heals (names/dressed/victim reappear correctly within the next scene-state event), and that
   the accepted reset of `no_orgasm`/dressed/speaking/deny_orgasm to defaults is the only visible
   regression.
6. **Release/reuse:** end the scene, confirm `Release()` clears cleanly (no leaked handles/log
   errors) and a fresh scene in the same pool slot works normally afterward.
