# Checkpoint v12: DE scene pulldown fixed (C++) + orgasm_locked guard added — speaking still unconfirmed

Supersedes [v11-checkpoint.md](v11-checkpoint.md). v10's `position_objs`/`actors_objs`/`thread_obj`
JsonStore migration is still code-complete and compiled clean, but **still not confirmed in-game** —
no new information on it this session; still pending (see `v10-checkpoint.md`'s own checklist).

Written from `C:\Skyrim\dev\mods\SkyrimNet_SexLab`, branch `skse-scene`, baseline commit `2c5f505`.

---

## 1. This session's two carried-over bug reports — one fixed and confirmed, one still open

v11 left two Description Editor reports open. Status now:

- **FIXED, confirmed by the user in-game:** "Description Editor didn't activate scene in
  scene_pulldown" — opening the overlay showed only `None`/`Any`, never the actual running scene
  (e.g. Nina+Camilla). Root cause was in the **native SKSE plugin**, not Papyrus or JS — see §2.
- **Still UNCHECKED / broken:** "Scene Creator → Description Editor: change speaking modifiers in
  Scene Creator, but didn't make it to Description Editor." This is the same speaking-modifier bug
  v11 attempted three Papyrus fixes for (`speaking_locked` guard), plus a fourth-fix candidate this
  session (`orgasm_locked`, for the related "orgasm flag didn't make it" report). **Never actually
  retestable until just now** — the pulldown bug above blocked selecting the live scene in the
  Description Editor at all, so every fix attempt since v11's fix 3 has been flying blind. Now that
  the pulldown is fixed, this needs a fresh in-game retest before doing anything else. The user's
  note mentions "(last animation in log)" — check `conversation_log.log` for the most recent
  animation change event as the repro's anchor point, the same evidence-trail technique that found
  v11's fix 3.

---

## 2. Root cause + fix: DE scene pulldown missing the active scene (C++, not Papyrus)

**A first hypothesis this session was wrong and is recorded here only as a warning against
repeating it:** grepping `Scripts/Source/*.psc` for `WebUI_SeedSceneInfos` found it defined once
(`Menu.psc:140-145`) and called nowhere, which looked like a dead call site from a refactor
(`71ab50b`, 2026-08-22, which deleted `SyncPanelsForActor()`'s two call sites without replacing them).
**That grep only covered `.psc` files.** A background Explore agent's independent investigation found
`WebUI_SeedSceneInfos` *is* invoked — via a native dispatch, `DispatchMenuNoArg("WebUI_SeedSceneInfos")`
at `SKSE_Source/src/WebUI.cpp:484`, inside `WebUI_Visibility_Show()`. No Papyrus change was made or
needed for this bug; the near-miss fix was caught before being applied.

**Actual root cause:** `ActionCatalog::SwitchMainPanel()` (`SKSE_Source/src/ActionCatalog.cpp:1210-1253`,
now ~1210-1260 after the fix) has two paths:
- A full panel switch (different `key` than currently selected) — for
  `scene_creator_panel`/`description_editor_panel`, calls `WebUI_Invoke("mainPanelDidOpen();")`
  (previously lines 1249-1252). That JS call (`index.html:7726` `mainPanelDidOpen()`) is what
  triggers `bindVisiblePanelsFromSceneInfo()` → `configureDescriptionEditorFromSceneInfo()` →
  `deApplyScenePick(deResolveDefaultScenePick())` — the logic that picks the currently-running scene
  into the pulldown.
- An **early-return "already selected" path** (previously lines 1221-1228,
  `key == g_currentMainPanelKey`) — only re-showed the panel DOM (`OpenMainPanelEntry`). It never
  called `mainPanelDidOpen()`.

So reopening the Description Editor while it was already the selected main panel (hotkey toggle on
the same actor, or reselecting it from the panel pulldown while already open) skipped the scene
auto-select entirely — the pulldown just kept whatever `DE.scenePick` it had from before. Distinct
from the earlier-fixed "stuck on Any after full close" bug (`2c5f505`, `discardSceneInfos()`), which
only handles the close path; this was a reopen-while-already-selected gap on the open path.

**Fix applied** (`SKSE_Source/src/ActionCatalog.cpp`, early-return branch): also call
`WebUI_Invoke("mainPanelDidOpen();")` when the already-selected panel is `scene_creator_panel` or
`description_editor_panel`, mirroring the full-switch path.

**This required a native rebuild**, not `compile: pyro` — confirmed with the user first (Release
build, matching how they run the game). `cmake --preset release` + `cmake --build --preset
build-release` succeeded clean; DLL copied to `SKSE/Plugins/SkyrimNet_SexLab.dll`. User confirmed
fixed in-game this session.

---

## 3. `orgasm_locked` guard added (Papyrus) — compiled, still not retested in-game

v11's three `speaking_locked` fixes only ever protected the `speaking` field on `position_objs[i]`;
research this session (Explore agent + direct code reading) found `no_orgasm`/`deny_orgasm` had **no
lock concept at all** anywhere in the codebase — `SeedOverlayFromAnimDb()` unconditionally clobbered
both on every mid-scene animation change (`TM_SetAnimationIndex`), regardless of any lock. Implemented
and compiled clean this session, in `Scripts/Source/SkyrimNet_SexLab_Scene.psc`:

- Added `orgasm_locked`, set alongside `speaking_locked` in `Setup()` (~257),
  `WebUI_ApplyLivePositions()` (~2275), `TM_ApplyOrgasmMode()` (~3118).
- `SeedOverlayFromAnimDb()` (both cached/uncached branches, ~3034-3043 / ~3072-3081) now respects
  `orgasm_locked`: preserves the stored `no_orgasm` value and skips the `deny_orgasm` reset when
  locked, mirroring how `applied_speaking` already protected the speaking value.
- `TM_SaveAnimationSettings()` (~3236-3242) now clears `orgasm_locked` alongside `speaking_locked`
  when settings are saved as the new per-animation default.
- Added `TEMP-DIAG v12`-tagged `Trace()` calls at every lock set/check/clear point (grep
  `TEMP-DIAG v12` to find every one) so the next in-game repro's Papyrus log shows exactly which
  guard (`speaking_locked`/`orgasm_locked`) was true/false at each mid-scene animation change, and
  whether `TM_SaveAnimationSettings` clears an active lock mid-scene. **These are temporary and must
  be removed before committing**, once the bug is confirmed fixed from log evidence.

**Why speaking was still broken as of the post-fix-3 build is not yet explained by code reading
alone.** The `speaking_locked` guard itself looks structurally correct on inspection. The one code
path that intentionally clears it outside that guard is `TM_SaveAnimationSettings()`, reachable via
the LLM-invokable action of the same name (`Actions.psc:692-699`) — plausible but unconfirmed; the
`TEMP-DIAG v12` logging should settle it once retested with a working pulldown.

This work compiled clean but has **never been retested in-game** — every attempt since v11's fix 3
was blocked by the pulldown bug in §2. That's now fixed, so this is next.

---

## 4. NOT yet done / open for next session

- **Retest speaking + orgasm in-game now that the pulldown works.** Reproduce: Scene Creator or
  TargetMenu sets a non-default speaking/orgasm choice, scene runs, a mid-scene animation change
  fires (`TM_SetAnimationIndex`), check the Description Editor still shows the explicit choice, not
  the AnimDB default. Pull the Papyrus log (grep `TEMP-DIAG v12`) alongside `conversation_log.log`
  (correlate with `TM_SaveAnimationSettings`/`TM_SetAnimationIndex` action calls) if still broken —
  use the log to find root cause directly instead of re-guessing from code reading.
- Also test the TargetMenu "deny orgasm" path (`TM_SetOrgasmMode` → `TM_ApplyOrgasmMode` with
  `mode == "deny"`) survives a subsequent animation change — the only path that ever sets
  `deny_orgasm = 1`.
- **Once speaking/orgasm is confirmed fixed:** strip all `TEMP-DIAG v12` lines from
  `SkyrimNet_SexLab_Scene.psc` before committing — do not ship temporary diagnostic logging.
- **Nothing from this session is committed.** Working tree (`git status`):
  ```
   M PrismaUI/views/SkyrimNet_SexLab/index.html
   M SKSE/Plugins/SkyrimNet_SexLab.dll
   M SKSE_Source/src/ActionCatalog.cpp
   M Scripts/SkyrimNet_SexLab_Scene.pex
   M Scripts/SkyrimNet_SexLab_Scene_Manager.pex
   M Scripts/Source/SkyrimNet_SexLab_Scene.psc
   M Scripts/Source/SkyrimNet_SexLab_Scene_Manager.psc
  ```
  (`Scene_Manager.psc`'s only change is the `GetThreadsJson` JSON-bridge fix from the v10 migration,
  carried over from before this session, not new here.) The `ActionCatalog.cpp` fix (confirmed
  working) and the three already-confirmed `index.html` fixes from v11 could be committed separately
  from the still-unverified `orgasm_locked`/speaking Papyrus work, if the user wants to stop blocking
  on that — ask which they prefer once speaking/orgasm is resolved either way.
- **Still separately pending:** full in-game verification of v10's Stage S2 migration
  (`position_objs`/`actors_objs`/`thread_obj`) per its own checklist in `v10-checkpoint.md`. No update
  this session.
- **Backlog, unscoped**, from the user's own `z-plan.md`:
  - "WebUI:Scene Menu: default none selected; clicking on a" (sentence cut off in the user's notes —
    needs clarification on what's actually being reported).
  - `SpeakingDefaultFromOrgasmExpected`'s AnimDB inference may be producing surprising results for
    certain tag combinations (e.g. "cunnilingus without tag 69" inferring `['', '_pleasure_']`) —
    flagged by the user as an observation, not necessarily a bug; worth asking whether this is
    expected or should be revisited.

## 5. Next session checklist

- [ ] Retest speaking + orgasm survives a mid-scene animation change, now that the DE pulldown works.
- [ ] If still broken: pull Papyrus log (`TEMP-DIAG v12`) + `conversation_log.log`, find root cause
      from evidence, fix.
- [ ] If fixed: strip all `TEMP-DIAG v12` lines, then commit — ask the user whether to split the
      confirmed `ActionCatalog.cpp`/`index.html` fixes from the `orgasm_locked`/speaking Papyrus work,
      or land everything together.
- [ ] Separately, still pending: full in-game verification of v10's Stage S2 migration.
- [ ] Backlog items above, not yet scoped — only revisit if the user raises them.
