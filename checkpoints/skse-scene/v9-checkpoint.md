# Checkpoint v9: Description Editor scene-pulldown "stuck on Any" fix — compiled/edited, not yet in-game tested

Supersedes [v8-checkpoint.md](v8-checkpoint.md). v8's `user_anim_defaults` JsonStore migration was
tested in-game: checklist items 1 (cache round-trip), 2 (clear/reset), 4 (no regressions) all
**verified** by the user. Item 3 (save mid-scene) is untestable — SexLab blocks saves mid-scene.

Written from `c:\Skyrim\dev\mods\SkyrimNet_SexLab`, branch `skse-scene`, baseline commit `5c8ccf4`.

---

## 1. New regression found during v8 testing, now fixed: scene pulldown stuck on "Any"

**Symptom reported:** pressing the 2nd-to-last hotkey action ("Add/edit per-stage description,"
opens the Description Editor) failed to detect the active scene. The scene pulldown showed "Any"
selected; the only real entry in the list was a cached/stale scene labeled "... (ended)".

**Confirmed not caused by the `user_anim_defaults` migration** — none of that migration's
functions touch thread state, `GetThreadActive()`, or scene enumeration. Also not a recurrence of
the `v3-checkpoint.md` JContainers-GC JSON-corruption bug: `BuildAllSceneInfosJson()`
(`Scene_Manager.psc:930-978`) is already fully `SNSL_JValue`/JsonStore-backed — that bug class is
architecturally closed.

**Actual root cause — a timing race between two independent "is this actor mid-scene" checks:**
- C++ `IsSexLabAnimatingActor` (`Papyrus_WebUI.cpp:749`, via `WebUI_MaybeRestoreAnimationPanel`)
  opens the Description Editor panel based on SexLab's own "Animating" faction membership.
- Papyrus `GetThreadActive` (`Scene.psc:1009`, via `BuildAllSceneInfosJson` →
  `WebUI_SeedSceneInfos`) decides what to seed based on `thread.GetState()` being
  `"animating"`/`"prepare"` + non-empty positions.
- When the panel opens before Papyrus's check catches up, zero live scenes get seeded, and JS
  `deResolveDefaultScenePick()` (`index.html:9255`) falls back to `'any'`.

**Compounding bug that made it "stuck":** once `DE.scenePick` became `'any'`, nothing ever
re-checked it — `deRenderScenePulldown()`'s only reconciliation (`index.html:9291-9295`) only
re-resolves when the *current* pick becomes invalid, and `'any'` is always a hard-coded valid
option, so the real live scene appearing in a later seed never displaced it.

**Fix chosen (JS auto-recovery only — the native timing race itself is untouched, by user's
choice, to avoid a riskier rebuild/redeploy for what the UI-side fix already resolves):**
`PrismaUI/views/SkyrimNet_SexLab/index.html` only, three edits:
1. Added `DE.scenePickAuto` flag (~9113): true when the current `scenePick` came from an
   automatic fallback, false when the user picked it via the pulldown click handler.
2. `deApplyScenePick(pick, opts)` (~9367): now sets `DE.scenePickAuto = !opts.userInitiated;` on
   every apply. No new call-site auditing needed — `opts.userInitiated: true` was already unique
   to the pulldown's own click handler; every other existing call site already omitted it.
3. `seedSceneInfos()`'s auto-apply guard (~7550-7559): broadened to also re-resolve when
   `DE.scenePickAuto` is true, `DE.scenePick` is `'any'`/`'last'`, and a live scene now exists —
   letting `deResolveDefaultScenePick()`'s existing (unmodified) registry/target-actor matching
   silently correct the wrong guess. A user's deliberate "Any" pick is untouched
   (`scenePickAuto` stays `false` for it, so the new branch never fires).

No Papyrus/C++ changes, no rebuild — pure WebUI JS. Confirmed via `git diff --stat` that only
`index.html` changed (+14/-2 lines).

---

## 2. NOT yet done this session

- **Not tested in-game.** None of §1's fix has been verified against a running game yet.
- **Not committed.** Working tree has `index.html` modified from this session, plus v8's
  still-uncommitted `SkyrimNet_SexLab_Scene.psc`/`.pex` (see v8-checkpoint §2).

---

## 3. Remaining S2 scope (unchanged from v7/v8)

`position_objs`, `actors_objs`, `thread_obj` and their ~25+ reader/writer functions — see
`v7-checkpoint.md` §1 / `v8-checkpoint.md` §3.

---

## 4. Next session checklist

- [ ] In-game test the checklist below; get user confirmation before considering this fix done.
- [ ] Once confirmed, commit together: v8's `SkyrimNet_SexLab_Scene.psc`/`.pex`
      (`user_anim_defaults` migration) + this session's `index.html` (scene-pulldown fix).
- [ ] Continue Stage S2 with `position_objs`, `actors_objs`, or `thread_obj` next.

### In-game verification checklist for this fix

1. **Reproduce → self-correct.** Trigger the Description Editor hotkey right as a scene starts
   animating (the timing window that previously produced "Any" + only the "(ended)" entry).
   Expect: pulldown may briefly show "Any"/the ended entry, then **self-corrects** to the real
   live scene shortly after (next seed), with no need to close/reopen the panel or manually
   reselect.
2. **No clobbering of a deliberate "Any" pick.** With a live scene already present (or one that
   appears shortly after), manually pick "Any" from the pulldown. Expect: it **stays** on "Any" —
   does not get silently switched back to a scene key.
3. **Stale-pick reconciliation unaffected.** Let a bound scene actually end while the editor has
   it selected. Expect: same pre-existing behavior — falls back via
   `deResolveDefaultScenePick()` as before (this path was not logically changed, only now also
   tags `scenePickAuto`).
4. **Re-check v8's checklist items 1, 2, 4** (per `v8-checkpoint.md` §"In-game verification
   checklist") once more after this change, to confirm nothing else shifted. Item 3 (save
   mid-scene) remains untestable.
