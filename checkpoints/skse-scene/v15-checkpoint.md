# Checkpoint v15: v10 Stage S2 verification closed; scope Stage S3 next

Supersedes [v14-checkpoint.md](v14-checkpoint.md). The user ran the v14 §2 active in-game
checklist and confirmed it looks good. **v10 Stage S2 is closed.** This checkpoint hands off
straight into scoping Stage S3 of the JContainers → JsonStore migration.

Written from `C:\Skyrim\dev\mods\SkyrimNet_SexLab`, branch `skse-scene`, baseline commit
`b8e5470`. Working tree is clean apart from the pre-existing, unrelated untracked
`extern/JContainers/`. Leave it alone.

---

## 1. Status: v10 Stage S2 verification closed

All six items of the v10-checkpoint.md §4 checklist are now confirmed:

| # | Item | Status |
|---|------|--------|
| 1 | Basic scene lifecycle (names/uuids/dressed/victim in DE and Scene Menu) | Confirmed (v11-v13) |
| 2 | Live per-position toggles, including `deny_orgasm` | Confirmed |
| 3 | Orgasm/narration flow (`OrgasmCombined`, `OrgasmMessagesToNarration`, `MarkOrgasmNarrated`) | Confirmed |
| 4 | `GetThreadJson`/`GetThreadsJson` produce valid JSON | Confirmed |
| 5 | Save/reload mid-scene | Confirmed |
| 6 | `Release()` and reuse of a pool slot | Confirmed |

No code changes came out of this pass. The bug chain fixed in `b8e5470` (see v13 §1, v14 §1)
stands as the final state for Layers 1-3.

**Standing rules for all new or migrated code** (recorded in KNOWLEDGEBASE.md, unchanged):
- Any handle held in a Papyrus member variable must be `isExists`-checked after a save load.
- Always **attach, then retain**. Never retain an unparented handle before attaching it.

---

## 2. Next work: scope Stage S3

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

## 3. Backlog (unscoped, carried forward)

From the user's `z-plan.md`:
- Scene Menu: "default none selected; clicking on a". The sentence is cut off, so ask the user
  for clarification before doing anything.
- `SpeakingDefaultFromOrgasmExpected` inference: `cunnilingus` without `69` infers
  `['', '_pleasure_']`. This is an observation, not a confirmed bug.
- Suggestion for the user: `z-plan.md` still lists "Scene Creator to Description Editor speaking
  modifiers" under BROKEN, and it can move to FIXED. That file is the user's, so don't edit it.

Still deferred: narration staleness in `position_objs[i]["victim"]`/`"assailant"` (v7 §5).

---

## 4. Next session checklist

- [ ] Start the Stage S3 Explore pass (§2), including the audit for the v13 bug classes.
- [ ] Revisit backlog items only if the user raises them.
