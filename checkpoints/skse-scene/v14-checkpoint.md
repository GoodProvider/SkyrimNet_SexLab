# Checkpoint v14: bug chain committed; resume S2 verification, then scope S3

Supersedes [v13-checkpoint.md](v13-checkpoint.md). The speaking/orgasm/dressed/pulldown bug chain is
**closed and committed** in `b8e5470`. This checkpoint is a clean hand-off: finish the leftover v10
Stage S2 in-game verification, then scope Stage S3.

Written from `C:\Skyrim\dev\mods\SkyrimNet_SexLab`, branch `skse-scene`, baseline commit `b8e5470`.
Working tree is clean apart from the pre-existing, unrelated untracked `extern/JContainers/`. Leave it alone.

---

## 1. Status: bug chain closed

Commit `b8e5470` ("Fix speaking/orgasm modifiers never reaching Description Editor") contains the
fixes, the KNOWLEDGEBASE quirk, the rebuilt DLL, the Scene/Scene_Manager `.psc`/`.pex` files and the
v10–v13 checkpoints. The user confirmed all three layers fixed in-game. See v13 §1 for the full story:

- **Layer 1:** `ActionCatalog::SwitchMainPanel()`'s "already selected" path now calls
  `mainPanelDidOpen()`, so the DE scene pulldown resolves correctly when the editor is reopened.
- **Layer 2:** JSON store handles die on every save load. `EnsureActorArraysLargeEnough()` now always
  runs its per-slot `isExists`-recreate loop, and `Scene_Manager`'s `last_ended_obj` is checked with
  `isExists` before it is attached.
- **Layer 3:** retaining a handle before attaching it deep-copies the handle under the new store.
  `SetSpeakingObj()` and `Initialize()`'s `actors_objs` setup were reordered to attach before retain.

**Standing rules for all new or migrated code** (recorded in KNOWLEDGEBASE.md):
- Any handle held in a Papyrus member variable must be `isExists`-checked after a save load.
- Always **attach, then retain**. Never retain an unparented handle before attaching it.

---

## 2. v10 Stage S2 verification: partly covered

The six-item checklist in [v10-checkpoint.md](v10-checkpoint.md) §4 was never run as its own pass.
The v11–v13 debugging exercised part of it:

| # | Item | Status |
|---|------|--------|
| 1 | Basic scene lifecycle (names/uuids/dressed/victim in DE and Scene Menu) | Covered by the v11–v13 in-game confirmations |
| 2 | Live per-position toggles | Dressed, orgasm and speaking are covered. **`deny_orgasm` was not tested explicitly** |
| 3 | Orgasm/narration flow (`OrgasmCombined`, `OrgasmMessagesToNarration`, `MarkOrgasmNarrated`) | **Pending** |
| 4 | `GetThreadJson`/`GetThreadsJson` produce valid JSON (no `JsonLowerCaseKeys: parse failed`, no NULL fields) | **Pending** |
| 5 | Save/reload mid-scene | **Pending.** Behavior changed since v10: the Layer 2 recreate loop now always runs |
| 6 | `Release()` and reuse of a pool slot | **Pending** |

### Active in-game checklist

1. **deny_orgasm:** toggle it via WebUI mid-scene and confirm it applies and reads back.
2. **Orgasm narration:** trigger an orgasm and confirm narration fires once, with correct names. This
   exercises the `actors_objs`/`position_objs` shared-handle path.
3. **Thread JSON:** watch the log for `JsonLowerCaseKeys: parse failed` or empty/`NULL` thread fields
   wherever `GetThreadJson`/`GetThreadsJson` feed the LLM prompt or the WebUI.
4. **Save/reload mid-scene:** check for:
   - no `dead handle` / `AttachChild: attaching a dead handle` spam after the load;
   - names, dressed and victim reappearing by the next scene-state event;
   - `no_orgasm`/dressed/speaking/`deny_orgasm` resetting to defaults. This reset is the accepted
     tradeoff from v10 §1 and is the only regression that should be visible.
5. **Release/reuse:** end the scene and confirm there are no leaked-handle or log errors. Then start a
   new scene in the same pool slot and confirm it behaves normally.

---

## 3. Next work: scope Stage S3

The rest of the JContainers → JsonStore migration, per v5 §3 and v10 §3:
- `Scene_Creator.psc`: about 140 JContainers call sites, all untouched.
- The rest of `Scene_Manager.psc`: about 206 call sites, of which about 20 were touched in S1/S2.

Start with an Explore pass, like the one done for S2:
- measure the size of the holders;
- find any missing `SNSL_*` natives;
- map cross-holder and cross-file coupling.

In the same pass, **audit explicitly for the two v13 bug classes**:
- every handle held in a member variable that lacks a post-load `isExists` check;
- every place where `retain` is called before `setObj`/`addObj`.

Pick an approach only after that pass.

---

## 4. Backlog (unscoped, carried forward)

From the user's `z-plan.md`:
- Scene Menu: "default none selected; clicking on a". The sentence is cut off, so ask the user for
  clarification before doing anything.
- `SpeakingDefaultFromOrgasmExpected` inference: `cunnilingus` without `69` infers
  `['', '_pleasure_']`. This is an observation, not a confirmed bug.
- Suggestion for the user: `z-plan.md` still lists "Scene Creator to Description Editor speaking
  modifiers" under BROKEN, and it can move to FIXED. That file is the user's, so don't edit it.

Still deferred: narration staleness in `position_objs[i]["victim"]`/`"assailant"` (v7 §5).

---

## 5. Next session checklist

- [ ] Run §2's active in-game checklist and get user confirmation. That closes v10 Stage S2.
- [ ] Start the Stage S3 Explore pass (§3), including the audit for the v13 bug classes.
- [ ] Revisit backlog items only if the user raises them.
