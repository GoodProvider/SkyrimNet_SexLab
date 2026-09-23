# Checkpoint v5: JContainers replaced with a C++ JSON store (Stage S0+S1) — code-complete, needs in-game verification

Supersedes [v4-checkpoint.md](v4-checkpoint.md)'s open question: the pulldown-corruption root
cause is now proven and fixed, not just theorized. v3's architecture is otherwise unchanged.

Written from `c:\Skyrim\dev\mods\SkyrimNet_SexLab`, branch `skse-scene`, baseline commit `41cd7cb`.
Nothing has been committed this session — see §5.

---

## 1. What v4 got wrong, and the actual root cause

v4 (and the KB entry it was chasing) blamed the Papyrus VM itself silently failing calls under
overlay pause. That's refuted — see `KNOWLEDGEBASE.md`'s "JContainers garbage-collects
mid-serialization, not a VM fault" entry for the full evidence chain. Short version: the old
Papyrus JSON walker (`SkyrimNet_SexLab_Utilities.psc`) took **~9 seconds** to serialize a live
scene payload (hundreds of VM↔native round trips), JContainers garbage-collects unowned temporary
objects on a ~10s timer, and nothing on that path was ever retained — so JC destroyed the object
tree mid-walk. `JContainers64.log`'s `access to non-existing object` warning counts matched the
corrupt-element counts exactly, proving it.

## 2. The fix: a C++ JSON store, not a JC lifetime patch

Per the user's explicit direction, this is a full replacement of JContainers with a store written
in this repo's own SKSE plugin — not a retain/cache patch on top of JC.

**New files:**
- `SKSE_Source/include/JsonStore.h` / `SKSE_Source/src/JsonStore.cpp` — the store itself. An arena
  of nodes (not a live `nlohmann::json` tree, since ~50 call sites mutate a child after attaching
  it). No garbage collector: a node lives until its owning root is explicitly released or the game
  exits. Handles are `(session, generation, slot)`-tagged 32-bit ints — a handle held across a
  save/load (Papyrus member variable serialized into the save) fails `IsValid()` deterministically
  instead of aliasing whatever now occupies that slot. Keys are lowercased on both insert and
  lookup. `Dump()` serializes the whole tree in one native call — this is the actual fix, since it
  replaces the ~9s Papyrus walk with something that can't take long enough for anything to expire
  mid-build.
- `SKSE_Source/src/Papyrus_Json.{h,cpp}` — Papyrus native bindings, registered in `plugin.cpp`.
- `Scripts/Source/SNSL_JMap.psc`, `SNSL_JArray.psc`, `SNSL_JValue.psc`, `SNSL_JFormMap.psc` —
  Papyrus-side native declarations, signatures mirroring JContainers' own so a call site migrates
  with a mechanical `JMap.` → `SNSL_JMap.` rename (see each file's own doc comment).

**One correctness fix worth flagging explicitly:** `AttachChild` (the function that attaches a
child object into a map/array/formmap) originally just reparented any unowned handle for free.
That silently breaks `Scene_Manager.psc`'s `last_ended_obj` — a handle that is both explicitly
retained (`SNSL_JValue.retain`) *and* re-embedded into a fresh, short-lived array on every
`BuildAllSceneInfosJson` call. Reparenting it into that temporary array means releasing the
temporary root would destroy `last_ended_obj` on the very next call. Fixed by giving `Node` a
`retainCount` (set by `Retain`, cleared by `Release`): attaching an unowned-but-retained handle now
deep-copies instead of reparenting, so the original stays alive under its retainer until they
release it themselves, matching JContainers' actual refcounting behavior for this specific pattern.
A plain build-and-forget handle (the overwhelming majority of call sites) is unaffected and still
reparents for free. See the comments on `Node::retainCount` and `AttachChild` in `JsonStore.cpp`.

## 3. Stage S1: migrated the actual failing path

Per the plan (`C:\Users\bhuff\.claude\plans\continue-the-work-spicy-plum.md`, approved this
session), only the reported-bug's call chain moved to the new store; everything else in the ~870
JContainers call sites across this mod stays on JContainers and coexists via small JSON-string
bridges (`SNSL_JValue.objectFromPrototype(ObjectToLowerCaseKeyJson(jcHandle))` and back):

- `SkyrimNet_SexLab_Scene.psc`:
  - `BuildInThreadAnims` — fully SNSL now (the ~65-entry loop that was the actual corruption site).
  - `BuildWebUISceneMenuObject` — fully SNSL. Bridges `manager.group_info`'s `group_tags`/`groups`
    subtrees (still JC, small) across via JSON round-trip.
  - `BuildWebUISceneMenuState` — serializes via `SNSL_JValue.dump` instead of
    `ObjectToLowerCaseKeyJson`.
  - `BuildWebUIAnimationMenuState` (the *other* caller of `BuildInThreadAnims`, for the in-scene
    Animation Menu rather than the Description Editor's Scene Menu) — `obj` stays JC; bridges the
    two SNSL arrays `BuildInThreadAnims` now produces back into it via JSON round-trip.
  - `AnimationEnd`'s end-of-scene snapshot (`ended_obj = BuildWebUISceneMenuObject()`) — updated to
    use `SNSL_JMap.setStr` for the one field it sets directly.
- `SkyrimNet_SexLab_Scene_Manager.psc`:
  - `SetLastEndedScene` / `last_ended_obj` — fully SNSL (its only producer, `BuildWebUISceneMenuObject`,
    is now SNSL).
  - `BuildAllSceneInfosJson` — fully SNSL. Bridges `creator.BuildWebUIObject()` (Scene_Creator.psc,
    not migrated) across via JSON round-trip.

**Not touched this stage** (still pure JContainers, by design — S2-S5 per the plan):
`Scene_Creator.psc` (140 call sites), most of `Scene.psc` (359 total, ~40 touched), most of
`Scene_Manager.psc` (206 total, ~20 touched), `Handler_UDNG.psc`, `AnimDb.psc`, `Decorators.psc`,
`Creatures.psc`, `Handler_DOM.psc`, `Main.psc`, and the JSON walker in `Utilities.psc` itself
(still used by everything not yet migrated, and by the bridges above).

## 4. Verified so far — and what's NOT verified

**Verified this session:**
- C++ side: `cmake --build build/release --target SkyrimNet_SexLab --config Release` — clean
  build, `JsonStore.cpp`/`Papyrus_Json.cpp` compiled with no warnings or errors.
- **Correction (2026-09-23, next session):** the sentence that used to be here claimed the DLL
  deploying to the space-named `SkyrimNet SexLab` folder was correct. **That was wrong** — that
  folder is `-SkyrimNet SexLab` (disabled) in `modlist.txt`; the DLL never reached the game, only
  the `.pex` files did (those compile into this repo, which is the enabled mod). See
  KNOWLEDGEBASE.md "The .pex and the .dll deploy in opposite directions" for the full diagnosis
  and `v3-checkpoint.md` §6 for the corrected deploy path
  (`SKSE_Source/CMakeLists.txt`'s `MOD_FOLDER_NAME` is now `"SkyrimNet_SexLab"`, no space).
- Papyrus side: `compile: pyro` — clean, "6 succeeded, 0 failed" (the 4 new `SNSL_*` scripts +
  `SkyrimNet_SexLab_Scene` + `SkyrimNet_SexLab_Scene_Manager`).
- A self-test (`JsonStore_SelfTest` in `plugin.cpp`, runs at `kDataLoaded`) exercises map/array/
  nesting/dump/release and checks key-lowercasing + array-dump shape; logs pass/fail via
  `webui_log`. **Not yet observed to actually run** — needs a game boot.

**NOT verified — needs the next in-game session, per the plan's verification section:**
1. Boot the game, check `SkyrimNet_SexLab.log` for `JsonStore self-test passed` (or `FAILED`,
   which would mean stop and debug before doing anything else).
2. Live 2-actor scene with ~65 animations, open Description Editor: **scene:** pulldown should
   list the live scene; no `JsonLowerCaseKeys: parse failed` in the log; no `NULL` or missing keys
   in the raw payload if it ever does fail; no new `access to non-existing object` warnings in
   `JContainers64.log`.
3. Log the dump duration if convenient — expect well under 100ms against the ~9s baseline.
4. Save, reload mid-scene, reopen the editor — confirm handles rebuild cleanly (this exercises the
   session-tag invalidation; `BuildWebUISceneMenuObject` is called fresh each time so there's no
   persisted-handle risk on this particular path, but worth confirming nothing logs a dead-handle
   error right after a load).
5. Only after all of the above passes: retest Stage 0's dressed-toggle fix end-to-end (still
   blocked/untested per `v4-checkpoint.md` §5 — the pulldown corruption blocked ever reaching that
   UI state).

## 5. Working tree state at handoff

Uncommitted (same files as v4's §7, plus this session's additions):
```
 M KNOWLEDGEBASE.md
 M PrismaUI/views/SkyrimNet_SexLab/index.html
 M SKSE_Source/src/plugin.cpp
 M Scripts/SkyrimNet_SexLab_Scene.pex
 M Scripts/SkyrimNet_SexLab_Scene_Manager.pex
 M Scripts/SkyrimNet_SexLab_Utilities.pex          (unchanged this session, from before)
 M Scripts/Source/SkyrimNet_SexLab_Scene.psc
 M Scripts/Source/SkyrimNet_SexLab_Scene_Manager.psc
 M Scripts/Source/SkyrimNet_SexLab_Utilities.psc    (unchanged this session, from before)
?? SKSE_Source/include/JsonStore.h
?? SKSE_Source/src/JsonStore.cpp
?? SKSE_Source/src/Papyrus_Json.{h,cpp}
?? Scripts/SNSL_J{Array,FormMap,Map,Value}.pex
?? Scripts/Source/SNSL_J{Array,FormMap,Map,Value}.psc
?? checkpoints/
?? extern/JContainers/          (pre-existing, unrelated to this work)
```
`Utilities.psc`'s two dead-theory guards (`piece == ""` substitution, the `BuildInThreadAnims`
empty-registry skip) are still in the tree from the prior session. They're harmless (never fire,
now definitively explained why) but are candidates for removal alongside a future cleanup pass —
not done this session to keep the diff focused on the actual fix.

Do not commit until §4's in-game verification passes.

## 6. Next session checklist

- [ ] Boot the game, confirm the self-test passes, then do the full §4 verification pass.
- [ ] If it passes: retest Stage 0's dressed-toggle fix per `v3-checkpoint.md`, then commit
      everything together (S0+S1 + Stage 0's original 4 edits + prior session's hardening + the
      corrected KB entries), tick Stage 0 in `v3-checkpoint.md` §5.
- [ ] If it doesn't pass: read whatever `webui_log::error` lines fire — every failure path in
      `JsonStore.cpp` logs a specific reason (dead handle with slot/gen/session, reparent-copy
      count, dump failure) rather than failing silently. Start there, not from scratch.
- [ ] Once S1 is confirmed good in-game: proceed to S2 (rest of `Scene.psc`) per the plan file
      referenced in §3, or write `v6-checkpoint.md` if handing off again first.
