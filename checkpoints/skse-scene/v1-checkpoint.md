# Checkpoint v1: SkyrimNet_SexLab_Scene → C++ migration (pilot) + clothing-sync bug fix

Handoff doc for continuing this work in another process/session. Written from
`c:\Skyrim\dev\mods\SkyrimNet_SexLab` on branch `dom`.

## How this started

Original ask: only auto-open the WebUI "Description Editor" panel when the
focused actor's active SexLab scene doesn't already have a description authored.
While scoping that, the user redirected to a larger goal: turn
`SkyrimNet_SexLab_Scene.psc` into a thin Papyrus interface, moving as much state
and logic as possible into the C++ SKSE plugin, keeping Papyrus only for calls
that must go through it (SexLab Framework's own Papyrus API — confirmed SexLab
ships no native DLL, so Papyrus is the only way to invoke its scripts).

Given the file's size (3173 lines, 82 functions), the user chose to **pilot one
subsystem** first rather than migrate everything: the description/tracked-flag
logic, which also delivers the original ask.

## Standing architecture rule (user-stated, must hold for this and all future work)

**WebUI → `SkyrimNet_SexLab_Scene` (Papyrus) → SexLab** is the only allowed call
direction. `SkyrimNet_SexLab_Scene` is the single required hop between the WebUI
and SexLab's live thread state. Nothing — WebUI JS, new C++ state — may reach
SexLab directly or bypass Scene as the source of truth. Any new C++ state must be
reachable only through Scene's existing Papyrus entry points (e.g.
`ApplyWebUICommit`, `BuildWebUISceneMenuObject`, `Release`), never called directly
by WebUI or other C++ modules.

While reviewing this, the user pointed out a live bug that violates exactly this
rule today (item 0 below) — fixing it is in scope alongside the pilot.

## Persistence decision (user-confirmed)

C++-owned state for this pilot gets **no SKSE co-save serialization**. It's
treated as session-scoped / derivable:
- The auto-computed part (does every stage have a description) is recomputed
  on-demand from already-persisted AnimDb data — nothing to lose.
- The only thing that doesn't survive a save/reload is a user's *manual override*
  of that flag (set via the new WebUI toggle) — acceptable per the user, falls
  back to the auto-computed value on reload rather than crashing or going stale.

## Investigation findings to reuse (don't re-derive)

- **No native SexLab bridge exists anywhere in `SKSE_Source/`** — exhaustive grep
  of VM-object lookups (`FindBoundObject` etc.) shows C++ only ever binds to this
  mod's *own* Papyrus scripts, never SexLab's. `extern/Source_SexLab/*.psc` are
  vendored read-only reference copies of SexLab.esm's scripts (no DLL). All
  AnimDb/WebUI natives take only primitives (`BSFixedString`, `int32`, JSON
  strings) in/out — confirmed via `Papyrus_AnimationDB.cpp:192-311`,
  `Papyrus_WebUI.cpp:1718-1746`. So: any function in `Scene.psc` that calls
  `thread.*`/`sexlab.*`/`actorLib.*`/`sslBaseAnimation` methods directly is
  unavoidably Papyrus-bound; only a brand-new native↔SexLab VM bridge (not
  attempted here) could change that.
- `Scene.psc` function categorization (82 total): **~48 functions call SexLab's
  Papyrus API directly** (can't move without a new bridge — includes
  `AlignActors`, `StageStart`, `AnimationEnd`, the orgasm pipeline, `ApplyWebUICommit`,
  `BuildWebUIAnimationMenuState`); **~34 are pure bookkeeping** (JMap/JArray/string
  math, no SexLab calls — e.g. `GetUUID`, `GetDescription`, `GetIntentMessage`,
  the `Dbg*`/`Trace` helpers, orgasm-message bookkeeping) — these are the next
  migration candidates after this pilot, using the same thin-wrapper pattern.
  `SkyrimNet_SexLab_Scene_Interface.psc` (174 lines, the parent class) is
  entirely in the pure-bookkeeping category too.
- New native `.cpp` files are picked up automatically by
  `file(GLOB "src/*.cpp")` in `SKSE_Source/CMakeLists.txt:60-61` — just needs a
  CMake re-configure, not a manual project-file edit.
- Native function registration pattern to copy exactly: see
  `Papyrus_AnimationDB.cpp:288-311` (`RegisterFunction(name, scriptName, fn)`,
  `constexpr std::string_view scriptName = "SkyrimNet_SexLab_AnimDb"`) and its
  `.psc` side `Scripts/Source/SkyrimNet_SexLab_AnimDb.psc:17`
  (`String Function AnimDb_GetByRegistry(String registry) global native`).
  Registration is wired up in `SKSE_Source/src/plugin.cpp:40-63`
  (`papyrus->Register(PapyrusBindings_X::Register_X_Functions)` per module); the
  same file's `kPostLoadGame`/`kNewGame` branch (`plugin.cpp:31-36`) already calls
  `TargetMenuRegistry::Clear()` — the new pilot's session-scoped override map
  should clear there too.

## Item 0 — Bug fix: Description Editor "dressed" toggle never reaches SexLab

**Root cause:** the Description Editor panel's actor table keeps its own draft
state (`DE.posDraft`, `PrismaUI/views/SkyrimNet_SexLab/index.html:9111`/`9481-9497`,
seeded from AnimDb's per-registry *defaults*, not live scene positions). Toggling
"dressed" (`deTogglePosDressed`, `index.html:9584-9589`) only stages a draft
change (`dePosEdited`, `:9571-9575`). On save, `deSaveToDisk()`
(`index.html:9895-9926`) sends the draft through `window.onAnimRegistrySave` →
`SKSE_Source/src/WebUI.cpp:812-822` →
`Scripts/Source/SkyrimNet_SexLab_Scene_Manager.psc:1079-1138`
`WebUI_OnAnimRegistrySave`. That function has **no `scene_sid`, no reference to
`SkyrimNet_SexLab_Scene`/`thread` at all** — it only reshapes `_positions` and
calls `animdb.SaveAnimLocal(registry, ...)` (the animation's saved *default*
clothed flag). So toggling "dressed" while editing a scene that's actually
running has **zero effect on the live actor** — this bypasses the WebUI → Scene →
SexLab rule (goes WebUI → AnimDb directly instead of through Scene).

Separately, even the scene-aware code path —
`WebUI_ApplyLivePositions(int obj)` (`Scripts/Source/SkyrimNet_SexLab_Scene.psc:2226-2255`,
already called from `ApplyWebUICommit`, and from two now-dead legacy functions
`WebUI_OnMenuClose`/`WebUI_OnMenuLiveUpdate` at lines 2190-2224 that nothing in
the current JS calls anymore — confirmed via grep, no `onMenuClose`/
`onMenuLiveUpdate` references in `index.html`) — only bookkeeps `dressed` into
`position_objs[i]` and never calls the actual clothing action. The only place
that currently calls `actions.Outfit_Dress`/`Outfit_Undress`/`TM_ApplyClothed` is
a separate, duplicate block inline at the tail of `ApplyWebUICommit`
(`SkyrimNet_SexLab_Scene.psc:2733-2764`), which the Description Editor's save
path never reaches.

### Fix (4 small, surgical edits — reuse existing functions/patterns, no new architecture)

1. **`WebUI_ApplyLivePositions`** (`SkyrimNet_SexLab_Scene.psc:2226-2255`) — add
   the actual clothing application, index-matched to `thread.Positions` exactly
   like its existing `no_orgasm`/`speaking` handling:
   ```papyrus
   Bool clothed = dressed == 1
   SkyrimNet_SexLab_Actions actions = (manager as Quest) as SkyrimNet_SexLab_Actions
   if actions
       if clothed
           actions.Outfit_Dress(Game.GetPlayer(), positions[i], "silently", "silent")
       else
           actions.Outfit_Undress(Game.GetPlayer(), positions[i], "silently", "silent")
       endif
   endif
   TM_ApplyClothed(positions[i], clothed)
   ```
   Insert right after the existing `thread.DisableOrgasm(positions[i], no_org == 1)`
   line, inside the same `while i < n` loop, same `if po > 0` block. This fixes
   the gap for **every** existing caller of `WebUI_ApplyLivePositions`.
2. **`ApplyWebUICommit`** (`SkyrimNet_SexLab_Scene.psc:~2733-2764`) — remove the
   now-duplicate lines from the tail loop:
   ```papyrus
   Bool clothed = JMap.getInt(po, "_dressed", 0) == 1
   SkyrimNet_SexLab_Actions actions = (manager as Quest) as SkyrimNet_SexLab_Actions
   if actions
       if clothed
           actions.Outfit_Dress(Game.GetPlayer(), a, "silently", "silent")
       else
           actions.Outfit_Undress(Game.GetPlayer(), a, "silently", "silent")
       endif
   endif
   TM_ApplyClothed(a, clothed)
   ```
   Leave `Bool isVictim`/`thread.SetVictim`/`deny`/`mode`/`TM_ApplyOrgasmMode`
   untouched — `WebUI_ApplyLivePositions` doesn't handle that victim/deny-orgasm
   nuance, only clothing. `WebUI_ApplyLivePositions(obj)` is already called
   earlier in the same function (line 2732), so after step 1 the clothing action
   would otherwise fire twice per commit.
3. **`WebUI_OnAnimRegistrySave`**
   (`Scripts/Source/SkyrimNet_SexLab_Scene_Manager.psc:1079-1138`) — route live
   updates through Scene when the editor is bound to the scene actually playing
   this registry. Add near the top, after the `registry == ""` bail-out:
   ```papyrus
   int scene_sid = JMap.getInt(obj, "_scene_sid", -1)
   if scene_sid >= 0 && JMap.hasKey(obj, "_positions")
       SkyrimNet_SexLab_Scene sl_scene = GetSceneBySid(scene_sid)
       if sl_scene && sl_scene.GetThreadActive()
           sl_scene.WebUI_ApplyLivePositions(obj)
       endif
   endif
   ```
   `obj` already carries `_positions` in exactly the shape
   `WebUI_ApplyLivePositions` expects (`{_no_orgasm, _speaking, _dressed}` per
   entry) — no reshaping needed. `GetSceneBySid` already exists and is used the
   same way at line 1073 (`WebUI_OnSceneNarrate`).
4. **JS `deSaveToDisk()`** (`index.html:9895-9926`) — attach `_scene_sid` only
   when this registry is actually the one playing in a bound scene:
   ```js
   if (DE.posDirty) {
       payload._positions = DE.posDraft.map(p => ({ _no_orgasm: p._no_orgasm ? 1 : 0, _speaking: p._speaking || '', _dressed: p._dressed ? 1 : 0 }));
       const boundScene = deActiveSceneForRegistry(DE.focusRegistry);
       if (boundScene) payload._scene_sid = boundScene.scene_sid;
   }
   ```
   `deActiveSceneForRegistry` (`index.html:9154-9159`) already resolves the
   active `SceneInfo` for a registry, gated by `deIsSceneBound()`
   (`index.html:9145-9147`, checks `DE.scenePick`).

This keeps the animation-default save (`animdb.SaveAnimLocal`) exactly as-is and
purely *adds* the live-thread push alongside it — editing a registry that isn't
currently playing anywhere behaves identically to today (no `_scene_sid`
attached, no live actor touched).

## Item 1-6 — Pilot: description/tracked-flag logic moved to C++

### 1. C++: real native "all stages described" check

`AnimationDB` already owns `AnimRow::stage_has_description`
(`SKSE_Source/include/AnimationDB.h:37`, `std::vector<int>`) and
`GetByRegistry(registry)` (`AnimationDB.h:89`, returns `std::optional<AnimRow>`).
Add:
```cpp
// AnimationDB.h
bool AllStagesHaveDescription(const std::string& registry);

// AnimationDB.cpp
bool AllStagesHaveDescription(const std::string& registry)
{
    auto row = GetByRegistry(registry);
    if (!row || row->stage_has_description.empty())
        return false;
    for (int v : row->stage_has_description)
        if (v != 1) return false;
    return true;
}
```
Real C++ loop over data already held in memory — no JSON/JContainers round-trip.

### 2. C++: new `SceneTracking` module (per-scene manual override)

New `SKSE_Source/include/SceneTracking.h` / `SKSE_Source/src/SceneTracking.cpp`,
mirroring the `AnimationDB.h/.cpp` pairing:
```cpp
namespace SceneTracking
{
    bool IsTracked(int sid, const std::string& registry); // override if set, else !AllStagesHaveDescription
    void SetOverride(int sid, bool value);
    void ClearOverride(int sid);
    void Clear(); // full reset, called on load/new game
}
```
Backed by a small mutex-guarded `std::unordered_map<int, bool>` keyed by scene
`sid` (the same int already used everywhere as `_scene_sid`). `IsTracked` checks
the override first; if absent, computes
`!AnimationDB::AllStagesHaveDescription(registry)`.

### 3. C++: Papyrus bindings

New `SKSE_Source/src/Papyrus_SceneTracking.cpp` (+ header), registered against
`SkyrimNet_SexLab_Scene`, following `Papyrus_AnimationDB.cpp:288-309`'s exact
`RegisterFunction(name, scriptName, fn)` pattern:
- `bool Scene_IsTracked(int sid, BSFixedString registry)`
- `void Scene_SetTrackedOverride(int sid, bool value)`
- `void Scene_ClearTracked(int sid)`

Wire registration into `SKSE_Source/src/plugin.cpp` alongside the existing
`papyrus->Register(PapyrusBindings_AnimationDB::Register_AnimationDB_Functions)`
call (~line 56). Also call `SceneTracking::Clear()` next to the existing
`TargetMenuRegistry::Clear()` in the `kPostLoadGame`/`kNewGame` branch
(`plugin.cpp:31-36`).

### 4. Papyrus: `SkyrimNet_SexLab_Scene.psc` becomes a thin pass-through

No new stored property. Add one wrapper function:
```papyrus
Bool Function IsTracked()
    if thread == None || thread.animation == None
        return false
    endif
    return Scene_IsTracked(sid, thread.animation.Registry)
EndFunction
```
(Declare `Scene_IsTracked`/`Scene_SetTrackedOverride`/`Scene_ClearTracked` as
`global native`, same style as `SkyrimNet_SexLab_AnimDb.psc:17`.)

- `ApplyWebUICommit` (`SkyrimNet_SexLab_Scene.psc:2639+`, alongside the existing
  `_style`/`_intent` scalar reads at lines 2726-2731): add
  `if JMap.hasKey(obj, "_tracked") / Scene_SetTrackedOverride(sid, JMap.getInt(obj, "_tracked", 0) == 1) / endif`.
- `BuildWebUISceneMenuObject()` (`SkyrimNet_SexLab_Scene.psc:2381+`, alongside
  `_intent`/`_style` at lines 2387-2388): add
  `JMap.setInt(obj, "_tracked", IsTracked() as int)` so the WebUI reflects
  current state on panel open/refresh.
- `Release()` (`SkyrimNet_SexLab_Scene.psc:451+`): call `Scene_ClearTracked(sid)`
  during teardown — `sid` is retained across pool reuse (see comment at line
  449), so the next scene assigned to this `sid` must start with no stale
  override.

Note: there is a pre-existing, unrelated `bool Property tracking` (line 64) — a
debug/print toggle for `StageStart()`'s `Debug.Notification` logging (reads
`animdb.GetHasDescriptionOrgasmExpected(thread)`, which only evaluates the
*current* stage, not "every stage"). Leave it untouched; don't confuse it with
the new `IsTracked()`/`_tracked` toggle — different concept, similar name.

### 5. Papyrus: auto-open gating (`SkyrimNet_SexLab_Menu.psc`)

`WebUI_OnControlActorFocus` (`Scripts/Source/SkyrimNet_SexLab_Menu.psc:113-122`)
currently calls `SkyrimNet_SexLab_WebUI.WebUI_MaybeRestoreAnimationPanel()`
unconditionally whenever focus changes — confirmed as the live auto-open path;
`SKSE_Source/src/Papyrus_WebUI.cpp:1689-1697` (`WebUI_MaybeRestoreAnimationPanel`)
only checks SexLab faction membership via `IsSexLabAnimatingActor`
(`Papyrus_WebUI.cpp:749-757`), nothing about descriptions. This is dispatched on
every ControlPanel focus change (hotkey via `ProcessHotkey`/`Open_WebUI_Target`,
or manual pulldown pick), documented at `docs/developers/webui.md:51`. Gate it:
```papyrus
Function WebUI_OnControlActorFocus(Actor target)
    if target == None
        Trace("WebUI_OnControlActorFocus", "target is None")
        return
    endif
    bool hasStripped = main.HasStrippedItems(target)
    Trace("WebUI_OnControlActorFocus", target.GetDisplayName()+" hasStripped:"+hasStripped)
    SkyrimNet_SexLab_WebUI.Target_Menu_Refresh(hasStripped)
    if ShouldAutoOpenDescriptionEditor(target)
        SkyrimNet_SexLab_WebUI.WebUI_MaybeRestoreAnimationPanel()
    endif
EndFunction

Function ShouldAutoOpenDescriptionEditor(Actor target) ; -> Bool, mirrors WebUI_ConfigureFocusScene's lookup at line 124-138
    if !manager
        return false
    endif
    SkyrimNet_SexLab_Scene sl = manager.GetSceneByActor(target)
    if sl == None || !sl.GetThreadActive()
        return false
    endif
    return sl.IsTracked()
EndFunction
```
(Note: `ShouldAutoOpenDescriptionEditor` needs a `Bool` return type — fix the
signature when implementing; typo carried over from drafting.)

### 6. WebUI: manual toggle in the Scene Creator panel

Follow the existing scalar round-trip pattern used for `style`/`intent`
end-to-end (`PrismaUI/views/SkyrimNet_SexLab/index.html`):
- `SceneInfo` class (`index.html:7351+`): add `this.tracked = false` to the
  constructor (~7359), `if (state._tracked != null) this.tracked = !!state._tracked;`
  to `mergeFromState` (~7412), and `_tracked: this.tracked ? 1 : 0` to
  `toCommitJson()` (~7468).
- `copySceneInfoToSC(info)` (~7594-7619): add `SC.tracked = !!info.tracked;`.
- `applySceneMenuDraftToSceneInfo(extra)` (~7621-7648): add
  `info.tracked = !!SC.tracked;`.
- Markup: add a toggle control near the existing style pulldown
  (`<div id="sc-style-pulldown"></div>` at `index.html:1738`), a
  `.cell-toggle`-style span (this UI never uses native checkboxes — every
  boolean control is a custom `.cell-toggle`/`.option` div with `onclick`; see
  `.cell-toggle`/`.on` CSS at `index.html:862-875` and `scTogglePos` at
  `index.html:8395-8403` for the pattern to copy) — one scene-scalar toggle, not
  per-position.
- Wire its `onclick` to flip `SC.tracked` and mark the current `SceneInfo` dirty
  the same way other scalar fields already do, so it flows through the existing
  `flushSceneInfos()` → `onSceneInfoCommit` → `WebUI_OnSceneInfoCommit` →
  `ApplyWebUICommit` pipeline (already wired end-to-end — see
  `Scripts/Source/SkyrimNet_SexLab_Scene_Manager.psc:973-1004` for the
  `WebUI_OnSceneInfoCommit` → `sl_scene.ApplyWebUICommit(info)` hop — no
  native/JS bridge changes needed beyond the field itself).
- Render the toggle's `.on` state from `SC.tracked` wherever the style pulldown
  is (re)rendered (`index.html:7873-7879` and the second render path at
  `8907-8911`).

## Files touched (summary)

- `SKSE_Source/include/AnimationDB.h`, `SKSE_Source/src/AnimationDB.cpp` — add `AllStagesHaveDescription`.
- `SKSE_Source/include/SceneTracking.h` (new), `SKSE_Source/src/SceneTracking.cpp` (new).
- `SKSE_Source/src/Papyrus_SceneTracking.cpp` (new) + header — Papyrus bindings.
- `SKSE_Source/src/plugin.cpp` — register new bindings; clear `SceneTracking` state on load/new game.
- `Scripts/Source/SkyrimNet_SexLab_Scene.psc` — bug fix (`WebUI_ApplyLivePositions` clothing action, `ApplyWebUICommit` dedup); pilot (`IsTracked()` wrapper, native decls, `ApplyWebUICommit` `_tracked` read, `BuildWebUISceneMenuObject`, `Release`).
- `Scripts/Source/SkyrimNet_SexLab_Scene_Manager.psc` — bug fix (`WebUI_OnAnimRegistrySave` routes live positions to `sl_scene` when `_scene_sid` present).
- `Scripts/Source/SkyrimNet_SexLab_Menu.psc` — gate `WebUI_OnControlActorFocus`.
- `PrismaUI/views/SkyrimNet_SexLab/index.html` — bug fix (`deSaveToDisk()` attaches `_scene_sid`); pilot (`SceneInfo` scalar + toggle control).

## Verification plan

1. Compile Papyrus via `pyro` (per `AGENTS.md`/`CLAUDE.md`); confirm no errors in
   `SkyrimNet_SexLab_Scene.psc`/`SkyrimNet_SexLab_Scene_Manager.psc`/
   `SkyrimNet_SexLab_Menu.psc`.
2. Re-run CMake configure + build for the SKSE plugin so the new `.cpp` files are
   picked up by the glob; confirm the DLL builds clean.
3. Clothing bug: start a scene, open the Description Editor on the currently
   playing registry, toggle "dressed" for a position, save/auto-save → confirm
   the actor's actual clothing state changes in-game immediately (previously: no
   effect on a live actor, only the animation's saved default changed). Confirm
   editing a registry that is *not* currently playing still only updates the
   AnimDb default (no `_scene_sid` attached, no live actor affected) — no
   regression to existing default-editing behavior.
4. In-game: start a SexLab scene using an animation registry with at least one
   stage missing an authored description → confirm the Description Editor
   auto-opens on WebUI focus (hotkey / pulldown select).
5. Author/pick an animation whose every stage already has a description →
   confirm the editor does **not** auto-open, and the WebUI opens to its normal
   default panel instead.
6. Flip the new toggle in the Scene panel both ways during an active scene →
   confirm it overrides the auto-computed behavior immediately (next focus
   event).
7. Save mid-scene, reload → confirm behavior falls back to the auto-computed
   value (override intentionally not preserved, per the chosen persistence
   tradeoff) rather than crashing or throwing stale data.

## Follow-up (explicitly not in this pilot)

This covers 2 of `SkyrimNet_SexLab_Scene.psc`'s 82 functions (plus the
clothing-sync bug fix, which touches existing functions rather than adding new
ones). The remaining ~34 pure-bookkeeping functions (JSON building, orgasm-
message bookkeeping, UUID/actor helpers, etc.) are candidates for the next
incremental migration using this same thin-wrapper pattern. The ~48 functions
that call SexLab's own Papyrus API directly (`AlignActors`, `StageStart`, the
orgasm pipeline, etc.) cannot move to C++ without inventing a new native bridge
into SexLab's Papyrus VM objects — a separate, much larger undertaking not
attempted here.

## Status

Planning only — **no code has been changed yet**. This checkpoint exists so a
different process/session can pick up implementation from here without
re-deriving the investigation above.
