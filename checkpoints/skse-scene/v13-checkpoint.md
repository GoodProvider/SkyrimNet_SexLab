# Checkpoint v13: speaking/orgasm/pulldown bug fully fixed and confirmed in-game

Supersedes [v12-checkpoint.md](v12-checkpoint.md). The Scene Creator → Description Editor bug chain
that spanned v11/v12 is now **confirmed fixed in-game by the user**: dressed, orgasm, and speaking
modifiers all transfer correctly. v10's `position_objs`/`actors_objs`/`thread_obj` JsonStore migration
is still not separately verified against its own checklist — no update this session; still pending.

Written from `C:\Skyrim\dev\mods\SkyrimNet_SexLab`, branch `skse-scene`, baseline commit `2c5f505`.

---

## 1. Full bug chain and how each layer was found and fixed

The original report ("speaking modifier set in Scene Creator doesn't reach the Description Editor")
turned out to be three independent, stacked bugs. Fixing the first two was necessary but not
sufficient to actually observe or fix the third — each layer had been masking the next.

### Layer 1 — DE scene pulldown empty (blocked all verification)

Fixed in v12, confirmed in-game this session's predecessor. `ActionCatalog::SwitchMainPanel()`'s
"already selected" early-return path (`SKSE_Source/src/ActionCatalog.cpp`) never called
`WebUI_Invoke("mainPanelDidOpen();")`, so reopening the Description Editor on an already-selected
panel never re-resolved which scene to show in the pulldown. Fixed by adding that call to the
early-return branch too, mirroring the full-switch path. Required a native rebuild (Release), DLL
redeployed to `SKSE/Plugins/SkyrimNet_SexLab.dll`. **User confirmed fixed.** An earlier hypothesis
this session (a supposedly-dead `WebUI_SeedSceneInfos()` Papyrus call site) was investigated and
found wrong before being applied — the function is invoked via a native `DispatchMenuNoArg` dispatch
that a `.psc`-scoped grep couldn't see. No Papyrus change was needed or made for this layer.

### Layer 2 — JSON store handles dead after every save load (silently dropped all writes)

Once the pulldown worked, the user's log showed `dead handle 0x6D`/`0x6E (slot N out of range)` and
`AttachChild: attaching a dead handle .., storing no-value instead` firing right at `SetPosition`,
and `SetPosition` traces confirmed the value was already lost (`speaking_modifiers: {}`) at the very
first write after Scene Creator handoff. Root cause: `SexLabNet::Json::OnNewSession()` invalidates
every JSON-store handle held in a Papyrus member variable on every save load (by design — see
`JsonStore.h:138-141`). `EnsureActorArraysLargeEnough()` (`Scene.psc`) had an early-return shortcut
that skipped its own per-slot `isExists`-recreate loop whenever `position_objs`/`orgasm_messages`
were already the right length — true again immediately after a load — so `position_objs[]` stayed
full of dead handles for the rest of that scene's life, and every write to it silently no-op'd.
`Scene_Manager.psc`'s `last_ended_obj` had the same class of gap (no `isExists` check at all before
being attached into `BuildAllSceneInfosJson()`'s `_scenes` array).

**Fixed:** `EnsureActorArraysLargeEnough()` now only skips the *resize* step when arrays are already
long enough — the per-slot `isExists`-recreate loop always runs. `last_ended_obj` now checks
`isExists` before being attached and resets to `0` when dead. Documented as a KNOWLEDGEBASE.md quirk
("JSON store handles die on every save load") per the standing rule in AGENTS.md, since this class of
bug can recur anywhere else a retained handle is held across a save boundary.

This fix alone got dressed and orgasm transferring correctly (both are plain `SNSL_JMap.setInt`
writes with no further indirection). **Speaking still didn't** — a third, distinct bug, layer 3.

### Layer 3 — retain-before-attach silently orphaned the speaking-modifiers array

`SetSpeakingObj()` (`Scene.psc`) built a fresh `SNSL_JArray` for the speaking modifiers, called
`SNSL_JValue.retain(speaking_obj)`, *then* attached it via `SNSL_JMap.setObj(obj, "speaking_modifiers",
speaking_obj)`, and only after that wrote the actual modifier strings into `speaking_obj`. Under the
new C++ JSON store's single-ownership rules (`SKSE_Source/src/JsonStore.cpp` `AttachChild`), attaching
an already-retained-but-unparented handle makes a **deep copy** rather than embedding the original —
so `MapSetObj` embedded an empty copy into `obj`, and the subsequent string writes landed on the now-
orphaned original, which nothing ever read again. This is exactly why speaking silently vanished while
`no_orgasm`/`dressed` (plain int writes, no retain/attach dance) worked fine even before this fix.

**Fixed:** reordered to attach-before-retain, matching the pattern already used correctly elsewhere in
the same file for `actors_objs`'s two resize sites. Found and fixed the identical wrong-order bug in
`Initialize()`'s own `actors_objs` setup while in there (same file, same root cause, not yet reported
by the user but structurally identical and cheap to fix alongside — could otherwise silently detach
`actors_objs` from `thread_obj.actors` on every session start).

**User confirmed: dressed, orgasm, and speaking modifiers all now transfer correctly from Scene
Creator to the Description Editor, including across a mid-scene animation change.**

---

## 2. Cleanup done this session

- All `TEMP-DIAG v12` temporary `Trace()` calls (added in v12 to diagnose layers 2/3) have been
  removed from `Scene.psc` now that the bug is confirmed fixed. Compiled clean after removal.
- `orgasm_locked`/`speaking_locked` guard logic from v11/v12 remains in place (still needed —
  it's what protects an explicit choice from `SeedOverlayFromAnimDb()`'s AnimDB re-derivation on a
  mid-scene animation change; only the diagnostic logging around it was removed).

---

## 3. NOT yet done / open for next session

- **v10's Stage S2 migration** (`position_objs`/`actors_objs`/`thread_obj` JsonStore migration)
  still has no dedicated in-game verification pass against its own checklist in `v10-checkpoint.md`,
  independent of the bugs fixed here. Worth revisiting given how much of this session's chain lived
  in exactly that migrated code.
- **Backlog, unscoped**, from the user's own `z-plan.md` (carried forward unchanged):
  - "WebUI:Scene Menu: default none selected; clicking on a" (sentence cut off — needs clarification).
  - `SpeakingDefaultFromOrgasmExpected`'s AnimDB inference may be producing surprising results for
    certain tag combinations (e.g. "cunnilingus without tag 69" inferring `['', '_pleasure_']`) —
    flagged as an observation, not necessarily a bug.
- No further open items from the speaking/orgasm/pulldown bug chain — it is closed.

## 4. Next session checklist

- [ ] Committed this session (see commit below) — verify it landed clean, working tree is otherwise
      clear of unrelated changes going forward.
- [ ] Consider a dedicated in-game pass on v10's Stage S2 migration checklist.
- [ ] Backlog items above, not yet scoped — only revisit if the user raises them.
