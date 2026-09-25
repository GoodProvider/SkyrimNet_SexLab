# Checkpoint v11: Stage S2 migration done + three speaking-modifier lock fixes — STILL BROKEN per latest test, needs fresh eyes

Supersedes [v10-checkpoint.md](v10-checkpoint.md). v10's `position_objs`/`actors_objs`/`thread_obj`
JsonStore migration is code-complete and compiled clean, but **not yet confirmed in-game** — no
new information on it this session; still pending.

Written from `c:\Skyrim\dev\mods\SkyrimNet_SexLab`, branch `skse-scene`, baseline commit `2c5f505`.

---

## 1. This session's four WebUI bug reports — three confirmed fixed, one still broken after three attempts

User tested v10's build and reported four issues. Three are **confirmed fixed** by the user
in-game:
- Scene Menu > Animations description column now regenerates actor names on a position swap
  (`dePreviewNamesFor`, `PrismaUI/views/SkyrimNet_SexLab/index.html` ~8617-8646 — added a branch
  reading `SC.positions[i]._name` before falling back to the stale target/player snapshot).
- Scene Creator's actor-table orgasm column now shows `O`/`-` matching the Description Editor's
  convention (`scRenderPositions`, `index.html` ~8323-8325).
- Description Editor's scene pulldown no longer gets stuck on "Any" after a full overlay
  close + hotkey reopen (`discardSceneInfos()`, `index.html` ~7563-7572 — now also resets
  `DE.scenePick`/`DE.scenePickAuto` to a neutral auto-default on close, so a deliberate "Any" pick
  can't outlive the overlay session it was made in).

**Still BROKEN, three fix attempts so far, most recent one untested:** "speaking modifier (and now
also orgasm flag, per the latest report) set in Scene Creator doesn't reach the Description Editor."
Latest user report (this session, after fix attempt 3 was already compiled but not yet confirmed):
*"orgasm and speaking flags didn't make it to Description Editor."* This is a **new detail** —
earlier reports only mentioned speaking; now orgasm is implicated too. **Not investigated yet** —
see §3.

---

## 2. Three speaking-modifier fix attempts made this session, in order

All three follow the same pattern: a writer sets a fresh `no_orgasm`/`speaking` value into
`position_objs[i]` via `SetPosition()`/`SetSpeakingObj()`, but never marks `speaking_locked`, so
`StageStart()`'s `ApplyAnimDbSpeaking()` (Scene.psc ~627-639) or `TM_SetAnimationIndex`'s
`SeedOverlayFromAnimDb()` (Scene.psc ~2978-3070) later overwrites it from the animation registry's
own stored/default data. `speaking_locked` is the guard flag that's supposed to protect an explicit
user choice; each fix found one more writer that didn't set it.

1. **`Setup()`** (`Scene.psc` ~250-257): when Scene Creator hands off `creator.speaking_modifiers[i]`
   to a freshly-created scene, now also sets `SNSL_JMap.setInt(position_objs[i], "speaking_locked",
   1)`. Fixes the very first hand-off.
2. **`WebUI_ApplyLivePositions()`** (`Scene.psc` ~2270-2274): a second, structurally identical writer
   reachable via `ApplyWebUICommit()` on every WebUI dirty-flush against an active scene — now also
   locks after its own `SetPosition()` call.
3. **`SeedOverlayFromAnimDb()`** (`Scene.psc` ~3025-3043 and ~3065-3082, both the `cached` and
   uncached branches): called by `TM_SetAnimationIndex` (`Actions.psc` ~582-601) on every mid-scene
   animation change — this unconditionally reset `speaking_locked` back to `0` for every position
   and re-derived `speaking` from the AnimDB registry, silently discarding a Scene-Creator or WebUI
   lock the instant the LLM/game advances to a new animation (a routine, frequent event in this
   mod, not an edge case). Now skips re-deriving speaking (and skips resetting the lock) for a
   position that's already locked, using the exact same guard `ApplyAnimDbSpeaking()` already uses.
   `orgasm_mode`/`dressed`/`deny_orgasm` still update from the new animation regardless of lock
   state — only the speaking value is protected.

**Evidence trail for fix 3** (not a guess — traced through real data): the live
`C:\Skyrim\dev\overwrite\SKSE\Plugins\SkyrimNet\logs\conversation_log.log` showed the reported
repro's actual scene (Nina + Camilla) had a mid-scene animation change ~30 minutes in (dialogue
stops at `08:16:40`, a new "facesitting"/cunnilingus-tagged animation starts at `08:49:19`). The
user's own `z-plan.md` working notes independently logged: *"speaking modifiers inference: tag
cunnilingus without tag 69 infers speaking modifiers ['', '_pleasure_']"* — a direct, personally-
observed instance of AnimDB's default inference overwriting a chosen value at exactly this kind of
transition. This matched the `SeedOverlayFromAnimDb` code path precisely.

Fix 3 was compiled clean (`compile: pyro`, 1 succeeded, 0 failed) but **has not yet been tested
in-game** before this checkpoint was written — the "orgasm and speaking flags didn't make it"
report the user pasted just before asking for this checkpoint may or may not already reflect fix 3;
unclear which build the user was running when they observed it. Get this clarified in the next
session before doing anything else.

Ruled out this session, with evidence (do not re-investigate without new evidence):
- **Not a re-triggered `StartScene` action.** `LockActorLock()` (`Scene_Creator.psc` 1182-1214)
  checks `sexlab.IsActorActive(akActor)` and fails the lock if the actor is already animating, so
  `Action_Start`'s `creator.LockAllActorLock()` correctly blocks a second scene from being created
  for actors already in an active SexLab scene.
- **Not an ordering bug.** `ContinueAfterSceneCreator()` (`Scene_Creator.psc` 1291-1315) calls
  `ApplyWebUIState(obj)` before `FinishStartScene(animations)` → `Setup()`. `RealignActorMasksFromPositions()`
  (`Scene_Creator.psc` 472-511, runs in between) preserves `speaking_modifiers[i]` by actor-identity
  match — no bug found there.
- **Not the WebUI→`SC.positions[i]._speaking` write path.** `scSetMods()` (`index.html` 7977-7979)
  and `scStart()`'s payload (`index.html` 9088-9096, `_positions: SC.positions`) correctly carry the
  live per-actor `_speaking` value through to the create-scene commit.

---

## 3. NOT yet done / open for next session

- **The bug may still not be fully fixed** — the user's latest report ("orgasm and speaking flags
  didn't make it") arrived without confirming which build (pre- or post-fix-3) it was tested
  against, and now names **orgasm** as affected too, which none of the three fixes above directly
  address. **First step next session: clarify with the user which build was tested, then decide
  whether a fourth writer needs to be found for the orgasm-flag part specifically** — possibly
  `no_orgasm`/`orgasm_mode` has its own separate unlocked-writer problem structurally identical to
  the speaking one (worth checking whether `no_orgasm` has any lock concept at all, or whether it's
  simply expected to always follow the current animation's AnimDB default — re-examine intent before
  assuming it needs the same fix pattern).
- **Nothing from this session is committed.** Working tree (`git status`):
  ```
   M PrismaUI/views/SkyrimNet_SexLab/index.html
   M Scripts/SkyrimNet_SexLab_Scene.pex
   M Scripts/SkyrimNet_SexLab_Scene_Manager.pex
   M Scripts/Source/SkyrimNet_SexLab_Scene.psc
   M Scripts/Source/SkyrimNet_SexLab_Scene_Manager.psc
  ```
  (`Scene_Manager.psc`'s only change this session is the `GetThreadsJson` JSON-bridge fix from the
  v10 migration, not new this checkpoint.) Do not commit until the speaking/orgasm bug is confirmed
  actually fixed — the three confirmed-fixed `index.html` items could be committed separately if the
  user wants to stop blocking on the Papyrus fix, but nothing has been split out yet.
- **v10's Stage S2 migration itself is still unconfirmed in-game** — no update this session. Still
  needs the full checklist in `v10-checkpoint.md` §"In-game verification checklist" run before that
  part can be considered done, independent of this session's WebUI bug fixes.

## 4. Next session checklist

- [ ] Ask the user which exact build the "orgasm and speaking flags didn't make it" report was
      tested against (before or after fix 3 / `SeedOverlayFromAnimDb`'s guard).
- [ ] If still broken post-fix-3: investigate whether `no_orgasm`/`orgasm_mode` needs its own lock
      flag and guard, mirroring `speaking_locked`'s pattern across the same three writers
      (`Setup()`, `WebUI_ApplyLivePositions()`, `SeedOverlayFromAnimDb()`) — check whether such a
      flag already exists (`orgasm_mode` is already stored per-position, per
      `SeedOverlayFromAnimDb`'s `SNSL_JMap.setInt(position_objs[i], "orgasm_mode", expected)`) or
      needs to be added from scratch.
- [ ] Once the speaking/orgasm bug is confirmed fixed in-game: commit all of this session's changes
      together (or split `index.html`'s three confirmed fixes from the Papyrus fix, if the user
      prefers landing those separately).
- [ ] Separately, still pending: full in-game verification of v10's Stage S2 migration
      (`position_objs`/`actors_objs`/`thread_obj`) per its own checklist in `v10-checkpoint.md`.
- [ ] Backlog items noted in the user's own `z-plan.md`, not yet scoped or investigated:
      - "WebUI:Scene Menu: default none selected; clicking on a" (sentence cut off in the user's
        notes — needs clarification on what's actually being reported).
      - The speaking-modifier AnimDB inference itself (`SpeakingDefaultFromOrgasmExpected`) may be
        producing surprising results for certain tag combinations (e.g. "cunnilingus without tag
        69" inferring `['', '_pleasure_']`) — flagged by the user as an observation, not necessarily
        a bug; worth asking whether this is expected or should be revisited.
