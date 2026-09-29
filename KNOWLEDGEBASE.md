# Knowledgebase

## SexLab `AddAnimation` overwrites index 0 (2026-09-29)

**Symptom:** after adding an animation in the Description Editor and reopening, the loaded list still had 3 rows. Log: `WebUI_SwitchToRegistry B_B_CCG idx:0`, while `WebUI_TakeCancelSnapshot anims:4`.

**Cause:** `sslThreadModel.AddAnimation` calls `sslUtility.MergeAnimationLists(PrimaryAnimations, [new])`. It grows the array with a trailing `None`, then writes the new entries from `Output[Count-1]` down to `Output[0]`, overwriting List1's first entries. `[A,B,C]` + D becomes `[D,B,C,None]`. It also only writes `PrimaryAnimations`, which `thread.Animations` hides whenever forced (`CustomAnimations`) are set.

**Rule:** never call `thread.AddAnimation` or `MergeAnimationLists`. Build the array yourself (skip `None`) and apply it with `SetForcedAnimations` if `GetForcedAnimations()` is non-empty, else `SetAnimations`. See `Scene.WebUI_SwitchToRegistry`.

## Live undress no-op after a clothed start: SetNoStripping override (2026-09-27)

**Symptom:** a scene started clothed (`ApplyMajorityClothed ... clothed_majority:1`). The user set both actors to undressed in the Description Editor. `WebUI_ApplyLivePositions` ran and the thread JSON showed `dressed:0 dressed_locked:1`, but nobody stripped.

**Cause:** `sslThreadModel.SetNoStripping` installs an all-false 33-slot `StripOverride` on the alias. `sslActorAlias.Strip()` uses that override whenever its length is 33, so it strips nothing. `OverrideStrip` rejects any array whose length isn't 33, so the override can't be cleared, only replaced.

**Rule:** before a mid-scene `slot.Strip()`, replace the override with SexLab's normal set: `slot.OverrideStrip(thread.Config.GetStrip(is_female, thread.UseLimitedStrip(), thread.IsAggressive, thread.IsVictim(actor)))`. This is done in `Scene.ApplyDressedToActor`. See also "Description Editor dressed toggle used wrong strip API" below.

## `style` parameter shadowed by Scene_Interface property (2026-09-27)

**Symptom:** custom stop reason never narrated ("Bob stops the scene." instead of the reason); `silent` stops still narrated. Log showed `Action_Stop … style: explain:<reason>` reaching `AnimationEnd`.

**Cause:** `Scene_Interface` has `String Property style Auto`. In `Scene.AnimationEnd(Actor speaker, String style)`, `style` resolved to the property (scene style `normally`), not the parameter — pyro compiles it without a warning.

**Rule:** in `SkyrimNet_SexLab_Scene` (and anything extending `Scene_Interface`) never name a parameter/local `style`, `intent`, or another parent property; use e.g. `stop_style`. `AnimationEnd` now takes `stop_style` (default `""` = SexLab end event, finish text only).

## Duplicate intent-less scene on a WebUI-started thread (2026-09-27)

**Symptom:** Cuddle started from TargetMenu; a later stop narrated "Bob and Camilla Valerius finish." (no intent). Log: `CreateCreator intent:  … speaker: None` right after `Scene_Creator.StartScene sid:0`, then `Setup sid:1` and both sid:0 / sid:1 doing `SetPosition` for thread 0; `Action_Stop` → `AnimationEnd sid:1`.

**Cause:** `Creator.StartScene` → `model.StartThread()` takes ~1 s before `CreateSceneByCreator` sets `thread_scene[tid]`. Any `GetSceneByActor` / `GetSceneByThread` in that window saw an animating/prepare thread with no bound scene and adopted it via `CreateCreator("", …)`.

**Fix:** `GetSceneByThread` create branch returns None while any thread actor still has the creator lock (`main.storage_actor_lock_key`, held until `Creator.Release()` after `CreateSceneByCreator`) — `ThreadHasCreatorLockedActor`.

## TargetMenu stop did nothing / explain never opened (2026-09-27)

- **explain:** `window.prompt` (and likely `window.confirm`) does not show anything in PrismaUI (Ultralight), so the handler returned as if cancelled. Text entry goes through the shared `#stop-dialog-overlay` (`stopDialogOpen(owner, onPick, explainOnly)`).
- **stop / silent:** `tmFireStop` used `applySceneMenuDraftToSceneInfo`, which copies the SC draft (`mode`, `scene_sid`) into `selectedSceneInfo()`. When SC was a creator draft, the commit carried `_scene_sid:-1` and `WebUI_OnSceneInfoCommit` silently skipped it. Stops now set `pendingStop` directly on the target actor's live SceneInfo (`tmLiveSceneInfo`).

## Scene view sticky `show_scene_panel` (2026-09-27, reworked 2026-09-28)

- One **Scene** main panel (`scene_panel`) replaces the separate Scene Menu / Description Editor entries: C++ shows the Description Editor when the ControlPanel target is in SexLabAnimatingFaction, else Scene Creator. The old `scene_creator_panel` / `description_editor_panel` keys are aliases.
- C++ `ActionCatalog` `g_showScenePanel` is set by every `SwitchMainPanel` to the Scene view and cleared **only** by the shared main-panel **Close** on it (`onSceneCreatorResult` `_action:"close"` for Scene Creator, `onScenePanelClose` for the Description Editor). `"cancel"` (Escape release of a Papyrus creator), Escape, Cancel and overlay hide/reset leave it set. In-memory only — resets on game restart, not saved.
- While set, `WebUI_MaybeRestoreScenePanel` (hotkey open + ControlPanel actor change) opens the Scene view for any focus actor. With it cleared, the hotkey no longer opens the Description Editor mid-scene (pick **Scene** from the views pulldown once).
- Picking another main panel / None from the pulldown does not clear it — the Scene view returns on the next target selection by design.
- Scene start/end inside `AnimationStart` / `AnimationEnd` cannot rely on the faction check (it may not have changed yet), so the scene tells C++ which panel to show (`WebUI_RerouteScenePanel(inScene)`).

## Description Editor animation filter lists one animation (2026-09-29)

- An active scene push's `_tags` (`Scene.psc` `JMap.setStr(obj, "_tags", GetTagsString(anim))`) are the **playing animation's** tags, not the include-tag filter. `SceneInfo.mergeFromState` copied them into `info.tags` → `copySceneInfoToSC` → `SC.tags`, and `scBuildFilter` sent `_must_tags` with `_require_all`, so the animDB matched only that animation.
- **Rule:** `mergeFromState` takes `_tags` as filter tags only for creator states; the scene push handler puts active `_tags` on the playing animation's `lastAnims` row.

## Papyrus runs while the WebUI pauses the game (2026-09-28)

**Symptom trap:** "apply this when the game unpauses" cannot be done by sending the commit right away and relying on the pause: the overlay pause stops game time, not the Papyrus VM (seed and commits run while paused). Only SexLab work that needs game time (`GoToStage` → `Advancing`, playback) waits.

**Rule:** hold a deferred change in JS and send it on unpause (Description Editor **play**) or a commit close — the Description Editor's pending animation pick (`DE.pendingSwitch`, `deSendPendingSwitch`) works this way. Cancel then only has to drop it (or restore the Cancel snapshot if it was already sent).

## Description Editor actor-table edits never reach a live scene (2026-09-26)

**Symptom:** Start a scene, open the Description Editor, toggle a live actor's `O` (orgasm) or
`dressed` cell in the actor table, Save. The animation's `_local_/<registry>.json` file is written
correctly, but the running scene's own state does not change, and closing/reopening WebUI shows the
toggle reverted. No speaking-modifier chip added the same way survives either. `SkyrimNet_SexLab.log`
shows `onAnimRegistrySave` → `AnimationDB::SaveAnimLocal` on every save, but no
`skyrimnet_sexlab_scene.SetPosition` trace, which only fires from `WebUI_ApplyLivePositions`.

**Cause:** `deSaveToDisk()` only attaches `_scene_sid` to the save payload (so Papyrus's
`WebUI_OnAnimRegistrySave` will call `sl_scene.WebUI_ApplyLivePositions`) when
`deActiveSceneForRegistry(DE.focusRegistry)` finds a match. Its scene-bound branch required
`picked.activeRegistry === reg`, a strict string compare — `reg` (`DE.focusRegistry`) can carry
AnimDB casing (lowercase, e.g. `ace_headpat`) while a live scene's `activeRegistry` keeps SexLab's
own casing (e.g. `Ace_Headpat`), so the match silently failed and `_scene_sid` was never sent. Every
DE actor-table edit then only ever reached the animation's own DB defaults, never the running scene
— exactly the documented "unbound" behavior, but happening even when the editor was scene-bound.

**Fix:** when `deIsSceneBound()` is true, `deActiveSceneForRegistry` now trusts the explicit pulldown
pick directly and drops the registry-casing check entirely (the user's binding IS the sync target).
Its unbound fallback (browsing the Animations list, no scene pulldown pick) still matches by
registry, now via `deRegEq` instead of `!==`, matching the case-insensitive convention used
everywhere else in this file (`deFindAnim`/`deEnsureFocus` already special-case this).

**Rule:** any DE/Scene Menu code that matches a scene by registry string must go through `deRegEq`
(SexLab casing vs AnimDB's lowercase), never `===`/`!==` directly — and when the user has explicitly
bound to a specific scene via a pulldown, prefer that explicit binding over any registry re-match.

## SkyrimNet "First argument to contains must be an array" (2026-09-26)

**Symptom:** SkyrimNet logs `First argument to contains must be an array` while a scene is running.
`threads.json` shows one actor (a DOM slave, after a load) with no `speaking_modifiers` key at all,
and no `no_orgasm`/`dressed` either; the other actor has `"speaking_modifiers":[]`.

**Cause:** `EnsureActorArraysLargeEnough()` recreates dead `position_objs[i]` as empty maps and relies
on `RestorePosition()` to refill them, but `RestorePosition()` returns early when the actor has no
persisted `tid`. The empty slot is then snapshotted into `thread_obj.actors`, and the prompts'
`set speaker = actor_record` followed by `contains(speaker.speaking_modifiers, ...)` fails.

**Fix:** a recreated slot gets `SetSpeakingObj(i, "")` before `RestorePosition()`. The activity and
narration prompts also set `speaker.speaking_modifiers = []` when it is missing or null.

**Rule:** any prompt field passed to `contains()` must always be an array. Seed it where the object
is created, and guard it in the prompt.

## JSON store handles from a save can alias new objects after a game restart (2026-09-26)

**Symptom:** right after loading a save, the LLM thread JSON is `"Threads":[NULL]`
(`JsonLowerCaseKeys failed, raw={"Counter":..,"Threads":[NULL]}`), and `SkyrimNet_SexLab.log` shows
`dead handle 0x.. (slot=N alive=true gen=1/0 session=2/2)`: the handle's session equals the slot's
but the generation doesn't. Per-position settings behave randomly for the rest of the scene.

**Cause:** the session tag in each handle was meant to make every handle saved into a Papyrus
member fail after a load. But `g_session` started at 1 in every game process and only counted
loads, so the first load of every run was session 2. A save made during session 2 of one run and
loaded as session 2 of the next run carries handles that pass `isExists` as soon as the same
slot/generation is reused. `thread_obj`/`position_objs[i]` then silently pointed at some other
object, which got freed or overwritten. `OnNewSession` also never freed anything, so every load
leaked the previous session's nodes.

**Fix:** `OnNewSession` now empties the store, and picks a session that is never the loaded save's.
The save's session is recorded in the SKSE co-save (`plugin.cpp`, unique ID `SNSX`, record `JSES`).
Sessions start at 32, so saves from older builds (sessions 1, 2, 3...) can't collide either.

**Rule:** a handle-validity scheme for anything persisted in a save must be unique across game
restarts, not just across loads within one run.

## JSON store: a retained handle is copied, not linked, when attached (2026-09-26)

**Symptom:** writes to a Papyrus-held handle never show up in the container it was attached to,
or show up one refresh late. No log line. Seen as `thread_obj.actors` in the LLM thread JSON lagging
one update behind `position_objs`, `orgasm_narrated` silently resetting on the Dom Combined
fallback (possible double narration), and earlier as Scene Creator speaking modifiers never reaching
the Description Editor (`SetSpeakingObj`).

**Cause:** `SNSL_JValue.retain` is not a no-op (its doc comment used to claim it was). In
`AttachChild` (`JsonStore.cpp`), an unowned handle with `retainCount > 0` is **deep-copied** into the
container, not reparented; this is intended for snapshot roots like `last_ended_obj`. Freeing or
clearing a container only *detaches* its retained children, so re-attaching one later copies again.
`position_objs[i]` was retained at creation and then `setObj`'d into `actors_objs`, so `actors_objs`
only ever held copies, and anything that read or wrote through `actors_objs` worked on a copy.
`Release`'s `clear(thread_obj)` + re-`setObj(actors_objs)` and `Initialize`'s legacy
`removeKey(thread_obj, "actors")` scrub did the same to `actors_objs` itself.

**Fix:** `position_objs[i]` is now the only live copy of each slot. `actors_objs` is a snapshot array
refreshed by `RelinkActorsObjs` (end of `AlignActors`, and in `GetThreadObj` after its
`updateactor` loop), and nothing reads or writes through it. `ResetActorsObjs` recreates `actors_objs`
(attach then retain) instead of re-attaching it.

**Rule:** attach first, then retain. Never `setObj`/`addObj` a retained handle and then expect later
writes to it to be visible in the container. If a retained root must appear inside another tree,
treat the embedded value as a snapshot and re-attach it after the last write. Also true for
`StorageUtil`-cached handles: `StorageUtil` survives a save load, so check them with `isExists`
(see `GetObjFromActor`).

## JSON store handles die on every save load (2026-09-25)

**Symptom:** Scene Creator sets an explicit speaking modifier / orgasm choice (visible correct in the
Scene Creator's own setup trace), but it never reaches the Description Editor — `SetPosition` traces
right after show the value already lost (`speaking_modifiers: {}`). `SkyrimNet_SexLab.log` around the
same timestamps is full of `dead handle 0x.. (slot N out of range)` and `AttachChild: attaching a
dead handle .., storing no-value instead`. The LLM thread JSON shows `"Actors":[NULL,NULL]` and
`Get_Threads json:{}`. Three separate lock-flag fixes for this bug (`speaking_locked`, then
`orgasm_locked`) landed and compiled clean but never actually took effect in-game, because the writes
they guarded were themselves landing on dead handles.

**Cause:** the C++ JSON store (`SKSE_Source/src/JsonStore.cpp`, `12c0ca4`) is in-memory only, with no
save-game serialization of its own. `OnNewSession()` (`JsonStore.h:138-141`) runs on every
`kPostLoadGame`/`kNewGame` and deliberately invalidates every handle that a Papyrus member variable
carried through the save (that member variable *is* serialized — it's just an int — so it survives as
a stale, now-meaningless handle). Most retained members in `SkyrimNet_SexLab_Scene.psc` /
`_Scene_Manager.psc` already re-check `SNSL_JValue.isExists(...)` before use and recreate on failure
(`thread_obj`, `actors_objs`, `victim_faction_forms`, `user_anim_defaults`). `position_objs[]` had the
same per-slot `isExists` recreate loop, but it lived inside `EnsureActorArraysLargeEnough()` behind an
early-return: `if position_objs && orgasm_messages && size <= position_objs.length && ...` — true
again as soon as a save reloads into a scene slot that's already the right length, so the recreate
loop never ran and every subsequent write silently no-op'd onto a dead handle for the rest of that
scene's life. `Scene_Manager.psc`'s `last_ended_obj` had no `isExists` check at all, so after a load
it could attach a dead handle into `BuildAllSceneInfosJson()`'s `_scenes` array as a `null` entry —
on the JS side `SceneInfo.keyFromState(null)` resolves to `'new'`, clobbering or corrupting the Scene
Creator draft.

**Fix:** `EnsureActorArraysLargeEnough()` no longer early-returns past the per-slot `isExists` loop —
only the *resize* step is skipped when the arrays are already long enough; the recreate loop always
runs. `last_ended_obj` now checks `isExists` before being attached, and resets to `0` when dead.

**Rule:** any handle a Papyrus **member variable** (something that survives across a save/load, not a
local built and consumed within one function call) holds from this JSON store must be re-validated
with `SNSL_JValue.isExists(...)` immediately before every use, and recreated if dead — never gated
behind a "we already have one of the right shape/size" shortcut, because "already have one" is exactly
the case a stale post-load handle satisfies. Grep `dead handle` / `attaching a dead handle` in
`SkyrimNet_SexLab.log` to confirm this class of bug; it only reproduces after a save load, not on a
fresh game, so always test lock/persistence fixes against a loaded save.

## The .pex and the .dll deploy in opposite directions (2026-09-23)

**Symptom:** the C++ JSON store (`SNSL_JMap`/`SNSL_JArray`/`SNSL_JValue`/`SNSL_JFormMap`,
`SKSE_Source/src/JsonStore.cpp`) compiled clean, the Papyrus side compiled clean and called the new
natives, but in-game the Description Editor **scene:** pulldown was still empty and
`BuildWebUISceneMenuState`'s trace showed `stage:0/0` — a value that can only come from a native
call silently returning its default. No `JsonLowerCaseKeys: parse failed` at all this time (the old
slow walker wasn't even on the path anymore), and the build finished in 83ms, not ~9s — both signs
the *new* code was running, just with dead natives underneath it.

**Cause:** this repo's `Scripts/Source/` compiles (`compile: pyro`) **into** the repo itself
(`skyrimse.ppj`'s `Output="Scripts"`), which is the git-tracked, MO2-**enabled** mod — so every
Papyrus change reaches the game immediately. But `SKSE_Source/CMakeLists.txt`'s
`MOD_FOLDER_NAME` was `"SkyrimNet SexLab"` (with a space) — a different, MO2-**disabled** release
mod (see the entry below). The DLL build was deploying **out** to a folder nothing loads, while the
`.pex` files were deploying **in** to the folder that does. `SkyrimNet_SexLab.log`'s boot block
only ever registered four Papyrus modules (WebUI/Utilities/API/AnimationDB) — no `Json Papyrus
functions registered` line — because the stale, three-day-old DLL checked into
`SKSE/Plugins/SkyrimNet_SexLab.dll` was what actually loaded. A binary grep confirmed it: the fresh
build artifact contained `SNSL_JMap`; the checked-in one didn't.

**Fix:** `MOD_FOLDER_NAME` is now `"SkyrimNet_SexLab"` (no space) — this repo's own folder, same
place `.pex` files land. `SKSE/Plugins/SkyrimNet_SexLab.dll` is therefore both the live path and
the checked-in shipping copy; expect it to show as modified after every C++ rebuild, exactly like
the `.pex` files do after a Papyrus recompile.

**Rule:** if a change to `SKSE_Source/` doesn't seem to take effect in-game, don't assume the logic
is wrong before checking deployment. Count the `... Papyrus functions registered` lines at the top
of `SkyrimNet_SexLab.log`'s boot block — there is one per `papyrus->Register(...)` call in
`plugin.cpp`; if one is missing, the loaded DLL predates that registration and no amount of C++
logic fixing will help until the deploy target is right. A binary grep for a distinctive string
from the new code (`grep -c "SomeNewSymbol" SKSE/Plugins/SkyrimNet_SexLab.dll`) confirms which
build actually loaded.

## Recompiled Papyrus scripts did not reach the live game — theory refuted (2026-09-22)

**Original (wrong) theory, kept here so a future session doesn't re-chase it:** it looked like the
game was loading a stale, disabled release mod (`C:\Skyrim\dev\mods\SkyrimNet SexLab`, with a
space) instead of this dev repo, because two rounds of fixes retested identically broken.

**Refuted:** checked every `+` (enabled) line in the active profile's
`C:\Skyrim\dev\profiles\SkyrimNet SexLab\modlist.txt` — only `+SkyrimNet_SexLab` (this repo, no
space) ships `Scripts/SkyrimNet_SexLab_Scene.pex`; `-SkyrimNet SexLab` (with space) is **disabled**
and not loaded at all. `C:\Skyrim\dev\overwrite\` (MO2's always-highest-priority folder) had no
stale copy either. The game session that reproduced the bug again booted (`SkyrimNet_SexLab.log`)
**after** the last relevant `compile: pyro` run, so the freshly compiled, actually-fixed script was
what the game loaded — and the bug still reproduced. The fix that round was genuinely live and
still wrong; see "JContainers garbage-collects mid-serialization" below for the real cause.

**MO2 layout reference** (still accurate, kept for any future deployment question):
- MO2 instance root: `C:\Skyrim\dev\`. Mods: `C:\Skyrim\dev\mods\<mod name>\` (dev repo is
  `SkyrimNet_SexLab`, no space).
- Active profile: `SkyrimNet SexLab`, modlist at
  `C:\Skyrim\dev\profiles\SkyrimNet SexLab\modlist.txt` — `+` = enabled, `-` = disabled.
- `C:\Skyrim\dev\overwrite\` — MO2's always-highest-priority virtual mod folder.

## Description Editor dressed toggle used wrong strip API (2026-09-22)

**Symptom:** Toggling **dressed** on a live scene position in the Description Editor and saving
did not change the actor's clothing in-game. `SkyrimNet_SexLab.log` showed
`Outfit_Dress ... style:silently narration:silent` immediately followed by
`UnStoreStrippedItems ... attempting to get stripped items: found none` and
`Outfit_Dress ... has no stripped items` — no error, just a clean no-op.

**Cause:** This mod has **two independent, non-interoperable dress/undress mechanisms**:
1. `main.StoreStrippedItems`/`UnStoreStrippedItems` (`SkyrimNet_SexLab_Main.psc`) +
   `Outfit_Dress`/`Outfit_Undress` (`SkyrimNet_SexLab_Actions.psc:356-387`), which call
   `sexlab.StripActor`/`UnStripActor` and cache the removed forms under our own `StorageUtil`
   key. This pair is for **out-of-scene** actions (Target Menu, chat-triggered "undress me")
   where no SexLab thread is managing the actor.
2. SexLab's own per-thread stripping: `sslActorAlias.Strip()`/`UnStrip()`
   (`SexLabFrameworkAE_v166b/scripts/Source/sslActorAlias.psc:1656-1764`), called automatically
   when a thread's animation starts, storing removed items in the alias's own private
   `Equipment` array. This is what actually undressed the actor for the scene.
`WebUI_ApplyLivePositions` (`Scripts/Source/SkyrimNet_SexLab_Scene.psc`) called mechanism (1)
for a **live scene actor**, whose clothes were stripped by mechanism (2) — mechanism (1)'s cache
was empty by construction, so it correctly detected "nothing to restore" and did nothing.

**Fix / rule:** Code that touches a live scene's clothing must go through
`thread.ActorAlias(actor).Strip()`/`.UnStrip()` (already used elsewhere in `Scene.psc`, e.g.
`:725`, `sslActorAlias actorAlias = thread.ActorAlias(akActor)`) — the same object that owns the
actor's current stripped state — not the standalone `main`/`Outfit_Dress`/`Outfit_Undress` pair,
which stays correct only for actors with no active thread. Note `sslActorAlias.UnStrip()` is a
no-op if `DoRedress` is false for that actor (victim + SexLab MCM "redress victim" off, or
`NoRedress` explicitly set) — that's existing SexLab MCM behavior, not a bug in this mod.

## JContainers garbage-collects mid-serialization, not a VM fault (2026-09-22, corrected 2026-09-23)

An earlier version of this entry ("Papyrus VM silently returns None under overlay pause") blamed
the Papyrus VM itself degrading under load/pause and shipped two guards
(`piece == ""` substitution in the JSON walkers, an empty-`Registry` skip in `BuildInThreadAnims`)
that **never fired across 5 fresh repros** and did not fix the bug. The real cause, found by
reading `JContainers64.log` instead of guessing further:

**Symptom:** Description Editor **scene:** pulldown never offered the live scene.
`SkyrimNet_SexLab.log` showed `JsonLowerCaseKeys: parse failed`, and the raw payload it was fed
contained an uppercase, unquoted `NULL` token repeated dozens of times as bare array elements —
and, in the worst captures, whole keys (`_in_thread_registries`, `_mode`, `_positions`) missing
from the object entirely.

**Cause:** the Papyrus JSON walker (`SkyrimNet_SexLab_Utilities.psc`'s `JMapToJson`/`JArrayToJson`/
`JFormMapToJson`/`JIntMapToJson`) took **~9 seconds** to serialize a ~65-animation scene payload —
hundreds of Papyrus↔native round trips plus repeated string `+=`. JContainers garbage-collects
**unowned** temporary objects on a ~10 second lifetime, and nothing on this build path was ever
retained (`BuildAllSceneInfosJson` even called `JValue.release(root)` with no matching retain). So
JC destroyed the object tree **while the walker was still reading it**. Proof:
`…\SKSE\JContainers64.log` showed `Warning: access to non-existing object with id 0x3064`
repeated (331 times across one session), and the per-object-id warning counts (59, 63, 57, 131)
matched the per-repro count of corrupt elements exactly. A call on a dead JC handle returns a
*None string*, which the Papyrus VM renders as the literal 4-character text `NULL` — which is
**not** `== ""`, so the existing "substitute null for an empty piece" guards could never catch it.
The same dead-handle failure made `JMap.nextKey` return a None string too, silently truncating the
enclosing map — hence the missing keys in the worst captures.

**Fix:** replaced JContainers with a C++ JSON store in this mod's own SKSE plugin
(`SKSE_Source/src/JsonStore.{h,cpp}`, Papyrus-facing as `SNSL_JMap`/`SNSL_JArray`/`SNSL_JValue`/
`SNSL_JFormMap`) for the scene-menu build path. No garbage collector — a node lives until its
owning root is explicitly released — and serialization is one native call (`SNSL_JValue.dump`)
instead of the Papyrus walker, so there is no multi-second window for anything to collect. See
`checkpoints/skse-scene/` for the staged migration (this fixes the reported pulldown bug; the rest
of this mod's ~870 remaining JContainers call sites migrate in later stages, with JContainers and
the new store coexisting via small JSON-string bridges until the last file moves over).

## WebUI script aborts at load: TDZ from hidePanel (2026-09-20)

**Symptom:** TargetMenu **Custom** no longer opened the Scene Selector; no panel logic after ~line 7286 of `index.html` existed.

**Cause:** `hidePanel('description_editor_panel')` runs **during script load**. `concealMainPanel` called `deSetLocked`, which read `let deLockTimer` declared ~1800 lines later → `ReferenceError` (temporal dead zone) → the whole inline script aborted, so `ssCustom`, `configureSceneCreator`, DE code and the `window.on*` handlers were never defined. A parse-only check (`new Function`) does not catch this.

**Fix / rule:** Anything reachable from load-time `hidePanel` / `concealMainPanel` / `revealMainPanel` must not touch `let`/`const` declared later in the script (use `var` or function declarations). Verify by *executing* the page (headless Chrome with `window.onerror` capture), not just parsing it.

## Description Editor scene pulldown anim-only / empty names (2026-09-19)

**Symptom:** Live Nina+Bob AP Anal scene; DE **scene:** option showed only **AP Anal**; names row hidden.

**Cause:** `BuildWebUISceneMenuState` used `Actor[] positions = None` then `positions = thread.Positions`. Papyrus cannot assign `None` to `Actor[]` (`Cannot cast from None to Actor[]` / mismatched `::temp410`). Seed still returned `_mode: active` with anim name and **empty `_positions`**. JS `deSceneOptionLabel` fell back to anim-only; `deRenderNames` hid the row.

**Fix:** Do not initialize `Actor[]` to `None`. Read `thread.Positions` only when truthy; if empty, still emit slots from `position_objs` (`name` / uuid / formid). Trace `positions` count + names on seed. Overlay: option label `Nina, Bob: AP Anal`; header `Description: AP Anal`; names row `names: … tags: ` chips (Tags section removed). Pyro-compile Scene (+ Menu for `WebUI_ConfigureFocusScene`).

## WebUI mouse freeze / text fields (2026-09-19)

**Symptom:** WebUI open blocks the mouse cursor; hard to click or type in Description Editor textareas.

**Cause:** `KeyHandler::ProcessEvent` returned `kStop` for the whole `InputEvent` batch while the overlay was visible. Skyrim delivers keyboard, mouse-move, and mouse buttons in one linked list per frame; `kStop` prevented downstream sinks (including cursor handling) from seeing mouse events.

**Fix:** While visible, run Escape/menu callbacks, **unlink** SKSE keyboard `kButton` and `kChar` only (block mod `RegisterForKey`), always return `kContinue`. PrismaUI mouse and text input use Win32; stripping SKSE keyboard does not block HTML field typing.

## Description Editor empty animation list (2026-09-19)

**Symptom:** Description Editor opens but the Animations table is empty (or clipped below the filter).

**Cause:** DE open did not arm filter downgrade or seed positions like Scene Menu. Default `gender` filter with `_actor_count: 0` and 0/0 gender totals matched no AnimationDB rows (`actor_count` optional treated `0` as set). `SC.filterBy` was already `gender`, so `scArmFilterDowngrade` never ran. In-thread stub rows were wiped on 0-result queries. CSS gave every `.de-section` `flex: 0 0 auto` inside `overflow: hidden`, clipping the anim list. In-scene hotkey only restored DE when `g_animationPanelPreferredOpen` (last selected main panel).

**Fix:** DE open calls `scArmFilterDowngrade`, seeds/enriches positions on creator/`new`, omits `_actor_count`/gender match when no positions. `MatchesFilter` ignores `actor_count ≤ 0`. Anim queries merge `_also_registries` via `GetByRegistry`. DE anim section fixed 50% height. `WebUI_MaybeRestoreAnimationPanel` always opens DE when focus is SexLab-animating. `SceneInfo.hasActor` uses `formIdU32` for ESL FormIDs.

## Description Editor Bob, Bob names / scene pulldown (2026-09-19)

**Symptom:** Names row showed **Bob, Bob** for a Nina+Bob scene, or Target+Player when browsing with no target.

**Cause:** DE used Target/Player fallbacks without live `thread.Positions`; `DE_FALLBACK_NAMES[1]` is literally `"Bob"`. Stale SceneInfo when overlay stayed open through AnimationStart (no Papyrus configure). No explicit scene pick — focus-based SceneInfo bind alone did not lock the in-thread animation.

**Fix:** DE **scene:** pulldown (None + active scenes labeled `pos0, pos1: anim`). Scene selected → hide Filter/Animations, names from scene positions, current = `activeRegistry`. None → show browse list; names Target+Player only with valid target, else Alice–Pat only. `WebUI_ConfigureFocusScene` before DE hotkey restore; `WebUI_ConfigureIfOverlayVisible` on AnimationStart/StageStart; `seedSceneInfos` merges live fields into existing `scene:sid` entries; animation-menu positions include `_form_id`. Placeholder names skip collisions with already-used names.

## AniDescriber HKX fill on hold (2026-09-17)

Runtime missing-stage fill is **authored anidata → earlier authored stage (Papyrus) → `GetDescriptionFromTags`**. `AnimationDB::GetStageDescription` does not call AniDescriber. No `Debug.Notification("Missing descriptions, inferring")`. AniDescriber / `HkxAnim` compile into the DLL with `SKYRIMNET_ANIDESCRIBER_HKX=0` (does not restore `anim_events`). Source stays in tree for offline spline work.

**Historical quirks (when HKX is resumed):** empty `anim_events` after schema ALTER → `AnimDb_NeedsEventBackfill` forces rebuild. XPMSE dual skeleton: pick NPC set (`bones_m` ≫ 18), not Ragdoll (~18). Debug `std::clamp` abort on inverted knot bounds in `ReadSplineVector` — guarded to fail clean (`hkx_sample_fail`). Spline decoder still returns `hkx_sample_fail`; tag narration expected until fixed offline.

## Start Sex hotkey DX 0 / unbound VkToDxScanCode (2026-09-15)

Enabled hotkey did nothing after `main`→`skse` merge. Papyrus: `Unbound native function "VkToDxScanCode"`. SKSE: `WebUI_SetHotkey dx=0x0 enabled=true` then `WebUI menu hotkey disabled`. No `ProcessHotkey`.

**Cause:** Dashboard `type:hotkey` stores VK (`220` = backslash). MCM `ApplyHotkey` converts with native `VkToDxScanCode` then `WebUI_SetHotkey` (DX). The loaded DLL had not registered that native, so Papyrus stored `0`. `WebUI_SetMenuHotkey` treats DX `0` as disable — it will also **unregister** a C++ bind. C++ `ApplyMenuHotkey` still read retired keys `sexlab.controls.editStageHotkey*`; manifest is `sexlab.editor.hotkey_enabled` / `sexlab.editor.hotkey`. `Config.h` / `Config.cpp` were missing from the tree so SKSE could not rebuild.

**Fix:** Restore Config. `ApplyMenuHotkey` reads `sexlab.editor.hotkey*`, leftover saved `43` → VK `220`, `MapVirtualKeyA` → `WebUI_SetMenuHotkey`. MCM: if `VkToDxScanCode` returns `0`, fallback DX `43` (`0x2B`) and do not call `WebUI_SetHotkey(0, true)`. Rebuild Release DLL. Expect `WebUI menu hotkey registered dx=0x2b` and no unbound native.

## Leash TargetMenu panel (2026-09-02)

- TargetMenu **leash** is `panel: leash`. The option JSON (`0700_leashed_panel.json`, `requiresPlugin: SkyrimNet_Leashed.esp`) ships in SkyrimNet_Leashed, not here; the panel renderer + `onLeashStatus` live in the core SKSE tree. The old `0700_sexlab_leash.json` (stale `SkyrimNet_Leash.esp`) and `0700_leash.json` (unhandled `type: handoff`) were removed (2026-09-28).
- Start-only ParameterPanel. Action pulldown is its own row (label column): not leashed → `tie to` / `give to`; leashed → `unleash` / `tie to` / `give to`. Control column: location if `tie to`, holder otherwise, empty if `unleash`.
- Status from C++ `onLeashStatus` → `LeashFramework.IsLeashed` / `GetLeashHolder` (faction 0xD6A fallback). Do not copy YAML leash decorators. Start dispatches `SkyrimNet_Leashed_Actions` (no YAML / `actions_index`). No refuses.

## AddActor -11 ForbiddenFaction after Edit Tags (2026-09-14)

Threesome Setup/locks/Yes/Edit Tags succeeded (35 Oral 3-actor anims). After the UI, `NewThread` + `AddActor(Nina)` failed. Papyrus: `ValidateActor(Nina) -- FALSE -- They are flagged as forbidden from animating` then `FATAL ... not a valid target for animation`. Edit Tags is not the failure — AddActor runs after the menu.

**Cause:** SexLab `ForbiddenFaction` (ValidateActor **-11**). A prior `CanAnimate` miss **adds** that faction; later checks hit “flagged as forbidden” first. MCM/manual forbid uses the same faction.

**Fix:** `EnsureSexLabActorsValid` before `SelectAnimations` and again before `NewThread`: `IsForbidden` → `AllowActor`, then `ValidateActor`. Still `< 0` aborts with name+code (no Yes/Edit Tags on a doomed start). AddActor failure logs `ValidateActor` again. If race/`CanAnimate` is the real reason, SexLab re-forbids and the code is no longer a sticky -11.

## Overlapping Action_Start shares creator sid:0 (2026-09-14)

SkyrimNet can queue the same start action twice (two LLM selections). Both `ModEvent`s run `CreateCreator`; `IsActive()` was still false until `Setup` finished latent `Game.GetPlayer()` and set `STATUS_ACTIVE`. Both claimed sid:0. The loser `Release()`d the shared creator (`num_actors = 0`, names/tags cleared). The winner called `StartThread` with no actors.

**Symptom:** `SexLab_Start_Giving` (or any start) logs Setup with actors, then `StartScene` with empty actors/tags. Papyrus: `SEXLAB - FATAL - Thread[0] - No valid actors available for animation`.

**Log trap:** `LockActorLock` `"X is locked"` used to mean **already locked** (failure). Success had no info trace.

**Fix:** `TryClaim()` sets `STATUS_SETUP` with no natives before `Setup`; second start gets the next pool slot. `StartScene` aborts before `NewThread` if `num_actors < 1`. `LockActorLock` sets StorageUtil immediately; `"already locked"` vs `"locked"`.

## Action eligibility cannot use Papyrus decorators (2026-09-14)

Category parents (`ShowComfort`, `ExpressPhysicallyNonsexually`, `Sexlab_Punish`, `SexLab_Sexual_Activities_One`/`Two`/`Three`) gated on Papyrus `sexlab_ostim_player == 0`. Eligibility `CallDecoratorDirect` does **not** live-call 1-arg Papyrus decorators: missing `arguments` logs `expects exactly 1 argument (EntityUUID), got 0`; with `currentActor` it logs `cache miss … returning empty`. Empty ≠ `0`, so the AND group fails and the whole tree (comfort / sex / punish / affection) stays hidden. Prompt-cache calls that pass an actor still return `'0'`.

**Symptom:** embedded eligible actions are only top-level native ones (`change_outfit`, DD lock/unlock, WAITHERE, DOM slave pack). Not Nina-specific.

**Fix:** native `get_global_value` / `skyrimnet_sexlab_ostim_player` on those six parents. `MCM.ApplyPluginConfig` `SetValue`s that global from `sexlab.ostim.player`. Keep `Ostim_Player` for prompts; do not use it in action YAML. Refresh Actions in Game Data Explorer.

## Hotkey SkyMessage: GetThreadByActor arity (2026-09-14)

Start Sex hotkey fired (`OnKeyDown` DX 43) but SkyMessage did not open when the crosshair target was already in SexLab. Papyrus: `Expected 2, got 1` for `GetThreadByActor(Actor akActor, bool any_state)` from `Menu.ProcessHotkey`. The VM never entered the function, so the log showed `failed to find thread` even though the SexLab thread existed.

**Cause:** `GetThreadByActor` gained `any_state`; Papyrus defaults are compile-time at the call site. `Menu.pex` still made a 1-arg call. Same trap: `Stages.EditDescriptions` / `SetOrgasmExpected` calling `GetSceneByThread(thread)` after that function gained two extra args.

**Fix:** cross-script callers pass every arg (`GetThreadByActor(target, true)` while `IsActorActive`; `GetSceneByThread(thread, false, true)`). Recompile callers after any signature change.

## MO2: installed release vs dev folder (2026-09-13)

Profiles can enable the packaged mod (`SkyrimNet SexLab`, space) while the git workspace (`SkyrimNet_SexLab`, underscore) is disabled. Compiling this repo then does **not** affect the running game.

**Symptom:** Dom melt DN works, but Combined last-stage still emits a second `" is orgasming."` for the slave (pre-`orgasm_narrated` / pre-window build). Or melt waits until the next StageStart (~tens of seconds) instead of flushing after `sexlab.orgasm.delay`.

**Tell from the log:** after a melt, expect `Combined stash`, `ArmOrgasmWindow`, then `OnUpdate` / `FlushOrgasmWindow`. Absence of those traces means the installed release `.pex` is loaded, not this repo.

**Fix:** enable the MO2 entry that maps to `C:\Skyrim\dev\mods\SkyrimNet_SexLab` (this workspace) and disable the installed-release folder for that profile.

## JValue.toJsonString is JC 4.2.13.1+ only (2026-09-13)

`JValue.toJsonString` landed in JContainers SE 4.2.13.1. Older `JValue.pex` (Wabbajack lists, Nefaram) logs `Static function toJsonString not found` and returns None; `ObjectToLowerCaseKeyJson` then fed `""` to `JsonLowerCaseKeys` and every decorator dumped `{}`. Papyrus cannot guard a missing native — the compiled `.pex` must not call it. Walk JMap/JArray/JFormMap/JIntMap in `JValueToJsonString`, then `JsonLowerCaseKeys`. Do not `writeToFile` a shared temp path (decorator spam + races).

## DOM masturbation is a synthetic thread, not SexLab (2026-09-13)

DOM solo masturbation is behaviour `masturbate` (idles / `DOMActionMasturbating`), not a SexLab `ThreadSlots` scene. `0050_sexlab_activity.prompt` presents it via `handler_dom.GetThreads()` merged in `GetThreadsJson`. DOM bio `0055` skips `masturbating.` on purpose so 0050 owns description + `_pleasure_` speaking rules.

SkyrimNet **blocks Papyrus decorators when any menu pauses the game** (`ExecuteDecorator: Blocking VM call … because game is paused`). That is not `isTimePaused`. `0050` then falls back to `threads.json`. `DOMOnBehaviourChange` is a queued ModEvent sent after `EnterWait()`, so the next paused prompt can still see the start dump. Skip a thread in `0050` / `0550` unless an actor is in `SexLabAnimatingFaction`, `OStimActorCountFaction`, or `DOMActionMasturbating`. Sibling start/stop actions dump `threads.json` synchronously; `Handler_DOM` still refreshes on behaviour change for wheel-menu / NPC stops.

Sibling `SkyrimNet_DOM_API.GetThreads` walks `DOM02.actorAliases` / `GetMaxActorCount` (same as capture scan). `GetActorCount` / `actorArray` lag until `UpdateActorArray`. Skip when `IsBusy` so a live SexLab scene is not double-listed.

## YAML `>` is not a comparison operator (2026-09-13)

Unquoted `comparisonOperator: >` is a YAML folded block scalar, so SkyrimNet stores a blank operator. `SEXLAB_STOP` then logs `blank comparisonOperator; the rule always evaluates false` and EligibilityChecker `Unknown comparison operator ''` on every pass — Stop never becomes eligible while animating. Quote it: `comparisonOperator: ">"`. `<` and `==` can stay unquoted; quoting `>` (and `<` for consistency) is required.

## Dom player-orgasm tease is not slave climax (2026-09-13)

`DOM_Mind` sends `{name} squirms under your grasp as your orgasm submerges you` when the **player** climaxes. That is not a Dom slave orgasm. `Handler_DOM.DOMSlave_Orgasmed` must refuse it (no `OrgasmCustom` / DN). Sibling Dom Events skips it in `OnNotifcationSkip` and only routes melt phrasing to the handler. Oral `orgasm_expected [0, 1]` plus Combined skip of `dom_slave` already omit the giver; do not let the tease override that.

## Dom slave orgasms despite orgasm_expected 0 (2026-09-20)

**Symptom:** `B_B_FFMLaySrv` (`orgasm_expected [0,1,1]`, Nina `no_orgasm:1`): log `DOMSlave_Orgasmed --- OrgasmCustom for Nina`, flush `Nina is orgasming.`, `total_orgasm` 0→1.

**Cause:** DOM registers `HookOrgasmStart_DOM<id>ORGASM` / `SexLabOrgasmSeparate` and rolls its own orgasm (`DOM_Mind.handleSexOrgasm` → `IsOrgasmingAfterArousal`). SexLab `DisableOrgasm` does not apply, and DOM has no per-scene disable; `should_be_noorgasm` only shifts the chance (can raise it). `Scene.OrgasmCombined` / `OrgasmIndividual` honored `no_orgasm`, `OrgasmCustom` did not.

**Fix:** `Scene.OrgasmCustom` returns early when `no_orgasm==1`. DOM's internal state still counts the orgasm.

## Start Sex hotkey live-reload (2026-09-13)

Dashboard `sexlab.editor.hotkey_enabled` / `sexlab.editor.hotkey` used to apply only from `MCM.Setup` (load) and `OnConfigOpen`. Enabling the hotkey in the SkyrimNet dashboard did not `RegisterForKey`, so SkyMessage never opened until MCM or reload. `SkyrimNet_OnPluginConfigSaved` (SKSE `SendModEvent`: `eventName`, `strArg`, `numArg`, `sender`) now calls `ApplyPluginConfig`. Pre-VK saves stored DX `43` for backslash; `ApplyHotkey` treats `43` as VK `220`. Do not enable this hotkey on the same key as SkyrimNet_Leashed’s panel (both default `\\`).

## SkyrimNet Beta 25 content plugin (2026-09-12)

Beta 25 does not read `prompts/`, `config/triggers/`, or `config/actions/`. Canonical LLM content is `SKSE/Plugins/SkyrimNet/external/goodprovider.sexlab/` (`manifest.json` `id` must equal the folder name). The same actions and prompts are also copied to `config/actions/` and `prompts/` so pre-0.25 SkyrimNet still loads them (`tools/sync_legacy_skyrimnet_content.py`; do not edit those copies by hand). Prompt paths inside the plugin are unchanged (`prompts/helpers/sexlab/…`, submodules). Action YAML filename (before `.yaml`) must equal the in-file `name` (case-insensitive); keep `name` casing. Settings schema stays at `config/plugins/SkyrimNet_SexLab/manifest.yaml` (`schema.fields` + `defaultValue`; `plugin.name` SkyrimNet_SexLab, `sexlab.*` keys) — that is not a content-plugin folder. Papyrus reads `Plugin_SkyrimNet_SexLab` via `GetConfig*` / `PatchConfig`. Ostim framework is `sexlab.ostim.player` (decorator `sexlab_ostim_player`); do not write `skyrimnet_sexlab_ostim_player`. Do not ship into `library/`. Upstream: SkyrimNet `docs/modding/MIGRATING_TO_BETA25.md`.

## SexLab P+ scene hop vs end (2026-09-10)

P+ `AdvanceFromTimer` does not end a player thread on the last stage when `ThreadWaitsForOrgasm()` is true (internal enjoyment + `HighEnjOrgasmWait` / `PlayerMustOrgasm` / `DomMustOrgasm`). It calls `FindSimilarSceneStage()` over `GetPlayingScenes()` (the `SetAnimations` list) and `ResetScene`s; if that list is empty it restarts the current scene. Vanilla still ends at `Stage > StageCount`.

**Do not** `SetAnimations` the full `GetAnimationsByTags` dump. Empty tags → skip lookup so SexLab picks internally (`SelectAnimations` and `SelectAnimationsDialog` both return `manager.empty`). On P+, cap a tagged match list to one random animation. `Scene.StageStart` also `EndAnimation()` after 120s real-time so enjoyment-wait cannot loop a single SLSB graph. Do not use `UpdateTimer` as an end mechanism on P+ — it sets `_ForceAdvance` and increases hopping.

MCM workaround: Climax type End/Legacy, or disable High Enj Orgasm Wait / Player Must Orgasm.

## Scene initiator vs victim (2026-08-30)

`Scene.initiator` is the speaker by default. If the thread has victims (`num_victims > 0`), a victim is never initiator: keep the current initiator only when they are not a victim; otherwise pick the first non-victim from positions 1…n then 0 (or None). Used for `"X initiates: …"` on first StageStart. Do not recompute on AlignActors / live SetVictim.

## BondagePanel / Devious Devices NG (2026-09-15)

- **Core SkyrimNet_SexLab does not require DD.** SexLab scenes, outfit, leash, and other TargetMenu panels load with no `DeviousDevices.dll`. BondagePanel / Handler_UDNG **does** require Devious Devices NG (`DeviousDevices.dll`) plus Assets.esm and Integration.esm. Legacy DD without NG is not supported for this panel.
- TargetMenu **bondage** is `panel: bondage` (`SKSE/Plugins/SkyrimNet_SexLab/webui/TargetMenu/Actor/options/0600_sexlab_bondage.json`). Catalog `requiresPlugin`: `Devious Devices - Assets.esm`; `requiresDll`: `DeviousDevices.dll` (row omitted if the DLL is not loaded). FOMOD optional “Devious Devices bondage”; Recommended when Assets **and** Integration are active. `make release` moves this JSON and `bondage/group-devices.json` into `handler_udng/` — see **Optional SKSE files / FOMOD split**.
- Handler `Setup_CheckLinks` fails (no BondagePanel) without Assets/Integration/`DeviousDevices` SKSE plugin / `zadLibs`. That does **not** fail the main quest.
- SKSE `SkyrimNet_SexLab.dll` never imports `DeviousDevices.dll`. `LoadAPI` / `GetProcAddress("GetAPI")` runs only on the BondagePanel path (first `bondageConfigure`). Vendor header: `SKSE_Source/lib/DeviousDevicesNG/API.h` (`DD_APIVERSION 2`). Do not include `DeviceReader.h` / `Export.h`.
- **Live catalog:** C++ `g_API->GetDatabase()` lockable inventory+rendered pairs (skip `zad_QuestItem` / unlocked), grouped by `unit.kwd`. Papyrus `PushBondageState` sends only `{target}` (number or string FormID). **ESL FormIDs are signed Papyrus ints** (`-33195884` = `0xFE057894`); C++ must `static_cast<uint32_t>` and match `Target` case-insensitively or `LookupByID` is 0, `GetWornDevices` never runs, and pulldowns stay `none`. JS payload is slim `{id,name}` + `equippedId`. **Do not** one-shot `Invoke` the full catalog (408KB object-literal never ran). **File first:** `Bondage_Configure` sends a small object-literal header (`bondageConfigure({...})`, same as `configureTargetMenu`) plus per-group `bondageConfigureDevices({...})` chunks from `group-devices.json`, then overlays `GetDatabase` when ready (`source: api`). Do **not** `PrismaUI->InteropCall`. Do **not** `TM_BondageRefresh` on ControlPanel actor focus unless BondagePanel is open (that flooded PrismaUI with ~27 Invokes + `onNotify` acks and TargetMenu never painted). JS paints `BONDAGE_GROUP_ORDER` body-area rows immediately (`none` until devices arrive); `bondageSortedGroups` ignores empty `ab.groups` (`[]` is truthy). Ack: one deferred `bondageGot source=… groups=N` per header (no per-chunk HUD/listener spam). Apply still uses the JC file + `plugin:0xhex`. Keep `ActorBondage.current` / `original` across catalog replace; empty `''` original is not a snapshot (re-seed from `equippedId`). Device `id` = `plugin:0xlocal` hex. **Start** sends `{current, original}` from JS `ActorBondage`; Finish skips unchanged groups.
- BondagePanel top aligns with ControlPanel (`.target-bondage-panel`). Each group is a stacked 75% `--text-base` **body-area** label (`bondageGroupName`) above nested pulldowns (`none` + material → color → leftover name, **≤20** items per menu; menus top-aligned with `#control-panel`, left edge = parent panel right + `--space-md`). Head-to-foot: Blindfold, Gag, Hood, Collar, Piercing Nipple, Body, Arms, Belt, Piercing Vaginal, Plug Vaginal, Plug Anal, Legs, Boots, Suit (`BONDAGE_GROUP_ORDER`).
- **ActorBondage** (JS class + Handler JFormMap original snapshot): seed original+current from worn the first time an actor is ControlPanel-current this overlay session. Later `TM_BondageRefresh` must not clobber `current`. Pulldowns write `ActorBondage.current` only (no Papyrus). `bondageConfigure` always rebuilds the device list from `current` (not worn) when the panel is open. **Start** (not Done) sends `currentJson` → `TM_BondageFinish` applies `SetGroupToId` per group from the JC file, narrates original vs wanted unless `silently`/`silent`, `ReleaseAll`, `WebUI_CloseOverlay`. **Cancel** closes BondagePanel only (Map kept so reopen shows pending `current`). Hide/Escape: `bondageReleaseAll()` + `TM_BondageOnWebUIClosed` **ReleaseAll only** — do not restore devices (the actor was never mutated until Start).
- `zadLibs` / device Forms live **only** on `SkyrimNet_SexLab_Handler_UDNG` (optional ESP). Do **not** put `zadLibs` on the main quest — the VM will not bind the type when DD is absent. Runtime: `GetFormFromFile(0x00F624, "Devious Devices - Integration.esm")`. Apply still uses `zadLibs.LockDevice` / `SwapDevices` / `UnLockDevice`.
- Compile import: `@ModsFolder\Devious Devices for SE-AE-VR\Scripts\Source` plus `PapyrusSourcesDD\SRC_SLA` (`slautilscr` on `zadLibs`). That tree’s `zadLibs.psc` is Headliner-stubbed; shipped DD `.pex` is used at runtime. Do not clone `PapyrusSourcesDD` into this repo / `Makefile` `dd:`.
- LLM lock/unlock stays in SkyrimNet_UDNG. `TM_BondageApply` can remain for other callers; BondagePanel must not use it.

## Scene Menu Start Control Panel new → Handoff (2026-08-16)

- Control Panel → Scene Menu → connection **new** seeds a provisional session (`_creator_sid:0`, `_from_target_menu:0`) with **no pooled** `Scene_Creator`. C++ Start then dispatches `WebUI_OnSceneCreatorResult(0, json)` because only `_from_target_menu` selects `WebUI_OnSceneCreatorHandoff`.
- `GetCreatorBySid(0)` misses → used to return with no Trace; SexLab never started. Result now Traces and falls through to Handoff (`CreateCreator` + `FinishStartScene`).
- Do **not** set `_from_target_menu` on Control Panel new — JS disables Load/Save presets when that flag is true. TargetMenu Custom keeps the flag; sid 0 is also a valid YesNo pool slot so C++ cannot infer provisional from sid alone.
- Same provisional seed in `Menu.WebUI_SeedSceneInfos` / `BuildAllSceneInfosJson` when there is no active `Scene_Creator` (`'new'` SceneInfo).

## Anidata schema 3.0 (2026-08-12)

- Contract: `docs/developers/anidata-schema.md` (+ accept/emit schemas under `docs/developers/schemas/`).
- Lookup: `<registry>.json` first, then display-name fallback (warn). Pack `_local_` last. No silent same-registrar merge.
- Port: `tools/port_anidata_v3.py --data-root <mods>` renames unambiguous display-name files; unmatched stay on display-name fallback.
- Stage change narration: `transitions["from-to"]` replaces `"Scene changes to "+desc` in `Scene.StageStart` when present.
- Rebuild AnimDB after upgrading so new SQLite columns / JSON packs are ingested.

## Nonsexual gender fallback / keep suppress (2026-08-10)

- **Policy / AnimDB none peel** (query-time; creator chips unchanged): after SexLab `GetAnimationsByTags` misses, (1) gender/position off with full must+suppress → (2) peel must-tags other than first (tail→front, keep `tags[0]`) → (3) peel suppress end→front with `tags[0]` → (4) drop front must-tag keeping full suppress (skip unconstrained 0+0). Never SexLab-random when original tags/suppress were set (`FinishStartScene` aborts).
- **`manager.empty` trap:** Scene Manager allocates `empty` as `sslBaseAnimation[2]` for identity compares. Never treat `anims.length > 0` alone as a hit — use `anims != manager.empty` (and `!= cancel`). Peel used to return after step1 miss because the sentinel looked non-empty.
- F/F + `nonsexual` often yields **0** from SexLab; AnimDB `_creature: exclude` + no gender/position finds F/M nonsexual while holding suppress as long as the peel allows.
- Callers: `SelectAnimations`, `ResolveAnimationsFromTags`, `SelectAnimationsDialog` final start.
- **SceneStart Custom:** C++ loads `scenes/*.json` into the TargetMenu catalog (`sceneSettings`). Overlay `ssLoadSetting` uses that cache (PrismaUI cannot fetch `../../../SKSE/...`). Custom applies **`default` then** `settingName` onto SceneInfo (speaking `""` clears `_pleasure_`; do not coerce empty through `filter(Boolean)` / `JArray.asStringArray`). Scene Menu setting pulldown stays **`none`** after Custom. Rapes / raped-by TargetMenu rows use `punish_pleasure_pain_rape`. Fallback hardcode still matches `nonsexual.json`. `filterByOnce='none'` for nonsexual/affection methods, otherwise Scene Creator default `gender`.
- **`SelectAnimationsDialog`:** probe/final miss never clears creator tags/suppress; peel is query-only then return to editor if still empty.

## Scene Menu filter-by downgrade (2026-08-10)

- Filter strictness in `MatchesFilter`: `positions` (per-slot `_pos_genders` + `_pos_race_keys`) ⊂ `gender` (aggregate counts, any arrangement) ⊂ `none` (`_actor_count` + tags + creature). Relaxing along that order can only gain animations.
- Each Scene Menu open arms the chain; `animDbQueryResult` steps one mode looser whenever the anim query returns zero and fallbacks remain. Tags query re-issues with the relaxed filter so available tags match the list.
- **Ordering trap:** in creator mode `scEnrichActorMeta()` resolves genders/race keys **after** the first query, so the opening `gender` pass runs on placeholder `_gender: 0`. Without re-arming on the `'e'` meta result the chain burns down to `none` before real genders exist. Re-arm from `SC.filterStart`, not the default mode, or the cuddle `none` seed flips back to `gender`.
- `animDbQueryResult` drops anim payloads whose `_request_id` != `'a' + SC.animQueryId`; C++ echoes the id verbatim and only `scRefreshAnims` issues `a`-prefixed queries, so a stale empty reply can no longer consume a chain step.
- Chain relaxes the **mode only** — actor count, tag chips, creature require/exclude, and **has description** still apply at `none`, so an empty list remains possible.

## StartScene tags CSV + SceneStartPanel (2026-08-13)

- Papyrus `StartScene_*` take **`tags`** (comma-separated), return **`Bool`**. Empty tags → skip AnimDB, still start. Non-empty → `AnimDb_ResolveTags` (sanitize + largest front-preferring subset, always lowercase); fail → False, no ModEvent.
- `AnimDb_CsvHasTag(csv, tag)` for membership checks (kissing → setting, etc.).
- YAML AI params stay named **`method`** (single value); ActionDispatch maps `method`↔`tags` positionally.
- TargetMenu inactive start rows share **`panel: scene_start`** (cuddle, punish, sex, masturbation, rapes). `panelDefaults` seed `participant2` / `participant3` / `victim` (player | currentActor | none) / intent / direction (default `random`) / method / style / setting; Target is always cast and the subject is the player only when **with** is the player. Root **Custom** (`type: scene_creator`, `0100_custom.json`) toggles Scene Creator on the creator SceneInfo (`new`) without applying a preset. **Start** probes `AnimDb_ResolveTags` — hit → close WebUI + existing `StartScene_One/Two/Three` (JS picks; Object `to victim` → TargetVictim / Nonconsensual_Three); miss → `onNotify`, stay open. Action-panel **Custom** closes SceneStartPanel, applies **`default` then** C++-shipped `scenes/{setting}.json` from the TargetMenu catalog (`sceneSettings`; PrismaUI cannot fetch `../../../SKSE/...`) (`tags_suppress`, `tags`, `array_defaults` / per-position `no_stripping`/`no_orgasm`/`speaking_modifiers`) onto creator SceneInfo `new`, shows Scene Creator with the setting pulldown on **`none`** (`SC.filterByOnce = 'none'` only for nonsexual/affection methods, otherwise `gender`). When Scene Creator is already visible, clicking cuddle/sex/etc. reapplies that row's `panelDefaults` (including default-then-setting overlay) to SceneInfo `new` instead of opening the Parameters panel. Nearby refresh still fills Include with all in-range actors except `child`/`dead`.
- Layout: Subject; `none|and` + optional third actor; direction (giving/getting vs fucking/fucked in filters method); Object relation `with|to victim|none` + Object actor; intent (custom opens IntentPanel); style; Scene Setting. UI intents `show affection` / `comfort` map to Papyrus `showing affection` / `comforting`. Hug-giver @ SexLab pos1 when intent is those labels **or** method is `cuddling|kissing|hug` (`StartScene_Event` + Custom JS). Selectable pool gates: only player → Object disabled; player+one → `and`/third disabled. **Custom** stays enabled whenever Subject is set (missing Object / third / duplicates still open Scene Creator); **Start** keeps the stricter cast gates.
- Third is `participate` only (never a second victim). Solo + assault/punish uses `StartScene_Nonconsensual_One`.

## Parameters Position formId on Start (2026-08-08)

- Position 0/1 pulldowns write `{ type: "Actor", formId }` into `paramDict` (target/speaker). Custom/scene-seed already used `ResolveActorDictEntry`.
- **Bug:** `ExecuteAction` / `ExecutePapyrusOption` ignored `formId` and always `ResolveSource` (player/focus) — picking Toy had no effect on Start.
- **Fix:** Both paths resolve Actor dict via `ResolveActorDictEntry` first, then fall back to `source`.
- **Also:** `ExecutePapyrusOption` must apply UI params **after** `defaultsParameters` (same as `ExecuteAction`). Defaults-last wiped Cuddle `speaker`/`target` formIds back to `playerActor`/`currentActor`.

## TargetMenu cascade label+pulldown rows (2026-08-23)

- Parameters, scene start (Cuddle), outfit, bondage, and stop put confirm buttons as the **first row** of the cascade panel (`Custom`/`Start`, `Cancel`/`Start` on BondagePanel, silent/stop/explain). The left TargetMenu option already names the panel (no title+buttons header).
- `.labeled-fields` is a 2-col grid (`max-content` + pulldown). Child `.dyn-field` uses `display: contents` so pulldown left edges align down the column. Bondage groups are stacked (75% label + 1em-indented pulldown), not this grid. `#right-dynamics` still scrolls; menus stay `position: fixed` so they are not clipped.

## TargetMenu Parameters pulldown clip (2026-08-08)

- `#right-dynamics { overflow-y: auto }` makes `overflow-x: visible` ineffective (CSS forces both axes). Right-opening `.pulldown-menu` children were clipped while Start/Custom (outside the scroller) still worked.
- Fix: `createPulldown` opens menus with `position: fixed` + `getBoundingClientRect` (`positionOpenPulldownMenu`); clear on close. Affects all action→Parameters paths (comfort/affection/punish/sex/masturbation/outfit), not cascade/papyrus option rows.

## Scratch files `z-*.*` (standing rule)

Always **ignore** files matching `z-*.*` (e.g. `z-plan.md`). Local scratch / notes only — not product docs or agent source of truth.

## Optional SKSE files / FOMOD split (standing rule)

- **One source of truth:** optional-handler files that the game reads at runtime live under `SKSE/Plugins/SkyrimNet_SexLab/` in the repo (Actor `options/`, `bondage/group-devices.json`, etc.). Do not keep a second copy under `optional/handler_udng/`.
- **Split at release:** `make release` copies `SKSE` into `core`, then **moves** those files into `handler_udng/` (same Data-relative paths) so Nexus FOMOD can install them only with the handler ESP. Dev/MO2 overlay uses the repo tree as-is.

## ControlPanel actor focus + active TargetMenu (2026-08-07)

- ControlPanel bottom `#control-actor-pulldown` owns focus for TargetMenu / Scene Menu / AnimationPanel. `#target-name` and Scene/Animation **scene** pulldowns removed. OStimNet framework pulldown (`#framework-row`) sits on ControlPanel above the actor row.
- Nearby list (C++ `PopulateNearbyActors`): default radius **1600** game units (~22 m; pulldown 100–1600). Only actors inside radius are listed; `Target_Current` is pinned even outside radius. Scene Menu Positions reads this JSON — not “everyone in the cell.” Log line includes `distSkip` + first 8 skipped names/distances when actors fail the radius check. Sort: player first; then status `sexlab` → `ok` → ineligible (`child`/`cmbt`/`ostim`/`dead`/`load`); then distance. Labels crop name to 10 + status suffix. Scene Menu Positions unselected rows = `selectable` and status `ok|sexlab` (ineligible stay off that table). Soft Sex Menu pool = `selectable && status==ok`.
- Hotkey **always toggles** overlay visibility: visible → C++ `WebUI_Visibility_Hide` (no Papyrus); hidden → `Open_WebUI_Target` (+ `WebUI_AfterTargetOpen` default pick). Close does not require the same focus actor. MultiTarget retired for this path. When focus is SexLab-animating, `WebUI_MaybeRestoreAnimationPanel` always opens Description Editor (not gated on last main-panel choice).
- Active panels: `stop` (speaker + silent/stop/explain → SceneInfo), `stage` / `position` (**Done** → SceneInfo), `animation` (AnimationPanel name picker; **Done** → SceneInfo).

## Active TargetMenu `type: papyrus` (2026-08-06, Actor/Scene split 2026-08-16)

- Mid-scene TargetMenu options under `webui/TargetMenu/Scene/options/*.json` use **`type: papyrus`** (no `name`, no YAML / `actions_index`). JS `onAction({action:"papyrus",...})` → C++ `ExecutePapyrusOption` → `SkyrimNet_SexLab_Actions.TM_*`. Actor (not animating) options live in `webui/TargetMenu/Actor/options/`. Catalog pick is ControlPanel focus `SexLabAnimatingFaction` — no per-option faction eligibility on Scene JSON. Actor **`panel: outfit`**: sentence `position_1` / style (`forcefully|normally|gently|silently`) / undresses|dresses / `position_0`; Start → `TM_Outfit`; no Custom; silently skips SkyrimNet narration.
- Storage: Animation JSON durable; AnimDB cache; Scene overlay this-thread only. Save (`TM_SaveAnimationSettings` / AnimationPanel Save) → SQL + JSON (`orgasm_expected`, `speaking_modifiers`, `clothed`). Victim/deny never durable; deny saves as expected=`1`. Full speaking token CSV is persisted (not token `[0]` only).
- Anim switch: `SeedOverlayFromAnimDb` — per-registry `user_anim_defaults` win, else AnimDB, else orgasm→speaking helper (`1`→`_pleasure_`, `0`→`""`).
- Stage start: `Scene.ApplyAnimDbSpeaking` (from `StageStart`) copies AnimDB speaking (stage-aware, as shown in the Description Editor) over Creator/setting speaking. `TM_ApplySpeaking` sets `speaking_locked` on the position so live edits survive stages; `SeedOverlayFromAnimDb` / `TM_SaveAnimationSettings` clear it. `no_orgasm` is untouched.
- Live Scene panels (`panel` on option JSON): `stop` / `stage` / `position` edit a panel draft; confirm (silent/stop/explain or **Done**) writes the selected SceneInfo. `animation` opens AnimationPanel; **Done** writes `activeRegistry`. SexLab `TM_*` / `ApplyWebUICommit` run on overlay commit, not live.

## Debug SKSE DLL + PublicGetPluginConfigValue CTD (2026-08-05, harden 2026-08-16)

- **Symptom:** CTD on load / `kDataLoaded` — Crash Logger `EXCEPTION_ACCESS_VIOLATION` in `SkyrimNet_SexLab.dll` during `std::string` teardown (`std::exchange`).
- **Stack:** `plugin.cpp` → `Config::ApplyFromConfig` → `ApplyMenuHotkey` → `EditStageHotkeyEnabled` → `GetValue` → SkyrimNet `PublicGetPluginConfigValue` (returns `std::string` by value across DLL). Same AV later from `PublicGetActorNameByUUID` in WebUI.
- **Cause:** Debug-built `SkyrimNet_SexLab.dll` (~7.96 MB, `/MTd`) against Release SkyrimNet (`/MD`) — `std::string` layout mismatch. Stack shows `0xCCCCCCCC` fill and path `sexlab.controls.editStageHotkeyEnabled`. AV is on return/destructor; memcpy / `.c_str()` after the call cannot help.
- **Also:** `CMake: Build SKSE (Debug)` copies over `SKSE/Plugins/` (e.g. 2026-08-16 2:39 PM overwrote a 2:17 PM Release). In-game config needs Release.
- **Fix:** `_DEBUG` skips all SkyrimNet exports that return `std::string` (`CrossDllStdStringSafe` in `Config.h`) and uses hardcoded fallbacks. Ship / test config with `CMake: Build SKSE (Release)` (~2.66 MB).
- **Crash logs (this machine):** `C:\Users\bhuff\OneDrive\Documents\my games\Skyrim Special Edition\SKSE\crash-*.log` (OneDrive Documents).

## Plugin config / control store (2026-08-04)

- **Source of truth:** `SKSE/Plugins/SkyrimNet/config/plugins/SkyrimNet_SexLab/manifest.yaml` (`schema.fields`). New settings always go in the manifest; MCM may mirror utilities only.
- **IDs:** C++ `PublicGetPluginConfigValue("SkyrimNet_SexLab", path, def)`; Papyrus `SkyrimNetApi.GetConfig*("Plugin_SkyrimNet_SexLab", path, def)`.
- **Practical split:** C++ owns plugin-config hotkey (`sexlab.editor.hotkey_enabled` / `sexlab.editor.hotkey` VK→DX via `MapVirtualKeyA`), WebUI Settings panel, and syncing `skyrimnet_sexlab_public_sex_accepted` / `hide_hermaphrodites` / `ostim_player` globals on load. MCM can also enable/remap the same KeyHandler via DX `WebUI_SetHotkey`. Papyrus only `GetConfig*` at Menu / Utilities / Scene / Creator / Manager call sites. No plugin `PatchConfig`.
- **ControlPanel framework toggle** still writes the ostim_player **global** for live eligibility; next load re-syncs from control store.
- **Settings main panel:** `webui/MainPanels/1000_settings.json` → `settings_panel` (rebuild → switches to Log, version from `info.json`, docs URL text, Open SkyrimNet dashboard). MCM shows redirect text + rebuild + last-rebuild timestamp.
- **Log main panel:** `webui/MainPanels/0900_log_panel.json` → `log_panel`. Source: `SKSE::log::log_directory()` + `SkyrimNet_SexLab.log`. JS regex filter; follow-tail until user scrolls away. Settings Rebuild AnimDB switches here so progress lines are visible.
- **No Prisma deep-link** to Plugins → SkyrimNet_SexLab; `TriggerToggleDashboard()` only toggles the SkyrimNet dashboard. **ShellExecute** for GitHub docs is unreliable in-game — show the URL as text instead.

## AnimationDB creature / race-key filter (2026-08-02)

- Scene Creator sets `_creature: require|exclude` from SexLab classification only (`GetGender` 2/3 + `sslCreatureAnimationSlots.GetRaceKey`). Do **not** treat non-creature as “human.”
- **Filter by pulldown** (`gender` / `none` / `positions`, default `gender`): `none` and `gender` apply `_creature` require/exclude without forcing `_position_match`. `gender` sends `_gender_match` + aggregate `_males`/`_females`/`_male_creatures`/`_female_creatures`. `positions` uses `_position_match` + `_pos_genders`; when any creature is present also `_pos_race_keys` (exact lowercase match vs AnimationDB `pos_race_keys`). Dog → only `"Dogs"` (primary GetRaceKey), not `creatures.json` display names.
- **`_gender: 0` is male, not unknown.** Scene Menu must not default unresolved positions to `0` (that queried male,male for a female+male cast). Use `null` until C++ nearby `gender` (`GetSex`) or Papyrus `GetGender` meta arrives; skip `_gender_match` / `_position_match` until every position is resolved. Persist enriched genders onto SceneInfo so `copySceneInfoToSC` does not wipe them. Match meta by `formIdU32`. Anim count shows cast letters (`F M`).
- Anim list sort: selected/active → has-description → gender-position string (`FFM` from `_pos_genders`, 0/2→M 1/3→F).
- Positions carry `_race_key` from Papyrus `BuildWebUIState` / `GetRaceKeyForActor`. TargetMenu C++ open and nearby-add enrich via `onResolveActorMeta` → `WebUI_OnResolveActorMeta` → `actorAnimMetaResult`.
- WebUI `ParseFilterJson` must accept `_creature`, `_pos_race_keys`, `_gender_match`, `_males`, `_females`, `_male_creatures`, `_female_creatures` (parity with Papyrus AnimationDB parse).

## AnimDB no auto-rebuild on load (2026-08-21)

- Load opens SQLite only (`AnimDb_Open`). Do **not** call `StartSync(False)` from `Main.Setup`.
- After SexLab is enabled, compare `AnimDb_TotalCount` vs human+creature `Slotted`. Match → no prompt. Mismatch → `Trace` + notification `SkyrimNet SexLab # animations doesn't match`, then SkyMessage **above everything** (`ShowArray_NonBlocking`, poll `OnUpdate` — do not latent-block `OnPlayerLoadGame`).
- Empty DB: body `AnimDB is empty`, buttons **Build AnimDB** / **Close**. Non-empty mismatch: `AnimDB has N, SexLab has M`, buttons **Rebuild AnimDB** / **Close**. Close / ESC does nothing. Build/Rebuild → `StartSync(True)` (MCM / Settings still use `RebuildDatabase`).

## AnimationDB + PrismaUI scene panels (2026-08-01)

- **DB file**: `Data/SKSE/Plugins/SkyrimNet_SexLab/animationdb.sql` (SQLite via vcpkg `unofficial-sqlite3`). Registry / tags / race keys stored lowercase for matching; PK = SexLab `registry`. Display `name` (and `animations/(name).json`) keep SexLab casing.
- **Ingest**: Papyrus `SkyrimNet_SexLab_AnimDb` walks `GetBySlot` in batches (not SexLab `GetByTags` — 125-cap lossy). C++ `InferOrgasmExpected` seeds `pos_no_orgasm` / speaking mods; stage descriptions from `animations/**/*.json` (`_local_` last wins). Rebuild is player-opt-in (load prompt / MCM / Settings), not automatic.
- **YesNo / SceneCreator are async**: PrismaUI cannot block like SkyMessage. `SelectAnimations` returns `manager.ui_pending`; C++ JS listeners dispatch `Scene_Manager.WebUI_OnYesNoResult` / `WebUI_OnSceneCreatorResult` → `ContinueAfterYesNo` / `ContinueAfterSceneCreator` → `FinishStartScene`.
- **Yes always opens SceneCreatorMenu**; **Yes (Random)** skips editor; NPC–NPC opens creator when config `sexlab.tagEdit.nonPlayerDialogs` is on. Escape on YesNo = No (Silent).
- **TargetMenu Custom / Start**: root panel only; each pulldown + Parameters are sibling panels in a row **above** Scene Creator. Action click opens Parameters (no immediate start). **Custom** / **Start** close the cascade then fire; Custom opens Scene Creator (`_from_target_menu`, `_creator_sid:0`); Start on SC → `WebUI_OnSceneCreatorHandoff`. **Start** always `ExecuteAction` then **closes WebUI** (clear session + hide; PrismaUI `Focus(..., pauseGame=true)` must not stay focused or SexLab `StartThread` fails). Scene Creator **Start** also closes WebUI even when TargetMenu session is still active (Custom path). For scene-start actions sets `SkipSceneCreatorOnce` → `ConsumeSkipSceneCreator` → `scene_creator_menu_called` so Papyrus skips Scene Creator **and** YesNo (Yes/Random). SceneStartPanel **Start** (`action:"papyrus"` + `closeWebUI` + `StartScene_*`, not `Refused`) sets the same flag; outfit/live papyrus rows do not. Tag Edit MCM no longer intercepts TargetMenu Start.
- **Cuddle tags**: LLM/general method `cuddle` → `cuddling` (`RemapTag` / `Actions` / C++ `RemapMethod`). Dedicated cuddle actions keep UI method `sitting|laying` for narration but `Setup` adds SexLab tag `cuddling` (not sitting/laying — those are position tags and miss Ace cuddle packs).
- **`scene_creator_menu_called`**: once per creator / SexLab thread; `TryOpenSceneCreatorMenu` gates Papyrus first-open; Load/Save refresh still calls `SceneCreator_Open` directly. TargetMenu Custom may re-`configureSceneCreator` while TargetMenu stays open (`TargetMenuSessionActive`; HideAllPanels spares TargetMenu until Cancel). **Do not** keep TargetMenu open across Start — paused overlay blocks SexLab.
- **Scene Creator anim list**: query cap is 125 (SexLab `GetList`). Do **not** embed `JSON.stringify(anim)` in each row `onclick` — with 125 rows that freezes CEF during `configureSceneCreator` and the panel never paints. Keep rows in `SC.lastAnims` and pass an index. Rendered as a 5-column table (genders / modifiers / name / num stages / description); WebUI `AnimRowToJson` includes `_stage_descriptions` so the description column can substitute `{{sl.actors.N}}` from Scene Creator positions. **Layout:** `#scene-creator-panel` fills `#main-panel-host`; `.sc-anims-section` is a fixed **50%** of the panel; only `#sc-anims-list` scrolls.
- **Scene settings pulldown:** Names and JSON bodies come from C++ `LoadSceneSettings` (`scenes/*.json`) on **both** TargetMenu and ControlPanel catalogs. A DLL whose ActionCatalog log line has no `N scene settings` count will leave the pulldown as only `none` and Custom/punish cannot overlay speaking. JS `ssAdoptSceneSettings` copies that object into `SCENE_SETTINGS` / `window.SCENE_SETTINGS` and refreshes the pulldown. Open still resets the pulldown to **`none`**. Picking a file applies `default.json` then that file without changing actors. **Save** dialogs write via Papyrus even when `creator_sid` is 0.
- **Victim mask:** After WebUI V toggles, call `RebuildVictimsFromMask` — never `SetNames`/`SetMasks` (those rebuild the mask from `victims[]` and wipe UI).
- **AnimationMenu:** hotkey opens TargetMenu + ControlPanel focus; Animation main panel restores only if preferred-open and focus is SexLab-animating. AnimationPanel is an in-thread **name picker** (filter + scrollable list, no 10-cap); **Done** writes SceneInfo. Stage/position/stop live on TargetMenu Scene. Escape cancels the overlay without committing SceneInfo.
- **Scene Menu dual-mode (2026-08-02 / 2026-08-07):** UI label Scene Menu; scene focus from ControlPanel actor (no duplicate scene pulldown). Active: A/N + Update (SexLab anim list cap **128** via `sslUtility.PushAnimation`). Tags stay UI filters — pool mutates only on Update.
- **Legacy**: `SkyrimNet_SexLab_Stages` is an empty stub for save compatibility; all callers use AnimDb.

## Caprica rejects formal param name `scriptName` (2026-07-29)

Caprica fails natives that declare a parameter named `scriptName` with `no viable alternative at input 'String'` (even a one-arg stub). Callers are unaffected (positional). Use a different formal name (e.g. `sName`) and document the slot in a comment — see `SkyrimNet_SexLab_API.RegisterTargetMenuOption`.

## TargetMenuRegistry external options (2026-07-29)

`SkyrimNet_SexLab_API.RegisterTargetMenuOption(Form quest, …)` appends runtime actions to the WebUI Target Menu (end of `options` + `actions` in `BuildUICatalog`). Stores the quest **FormID** (not EditorID) — EditorID lookup often fails for optional handler ESPs and `FindQuest` would fall back to the main quest. Cleared on `kPostLoadGame` / `kNewGame`; handlers must re-register in `Setup` with `self as Form`. Click dispatches via `ExecuteAction` with a single `target` Actor arg.

**Preferred (2026-08-02, dest 2026-08-16 / bondage 2026-08-21):** optional handlers ship filesystem `webui/TargetMenu/Actor/options/*.json` with `plugin` + `questFormId` + `scriptName` + `executionFunctionName` (+ optional `requiresPlugin`). Bondage is Actor `options/0600_sexlab_bondage.json` (`panel: bondage` → Handler_UDNG `TM_Bondage*`). Live under the repo SKSE tree; `make release` moves it into FOMOD `handler_udng/` (see **Optional SKSE files / FOMOD split**). `RegisterTargetMenuOption` is legacy (Actor catalog only).

## ControlPanel / MainPanels (2026-08-02, rename 2026-08-16)

Left column: ControlPanel (`#control-panel`: **mode pulldown** + **views** label + indented main_panel pulldown + OStimNet framework pulldown + **target** label + indented **actor focus pulldown**) above TargetMenu (10% top/left). Right: one main panel (10% top/bottom/right) from the **active mode** `MainPanels/` (`builtin`, `papyrus`, `data_table`, `actor_detail`). Pulldown → `onMainPanelChange` → `SwitchMainPanel`. Catalog invoke: `configureControlPanel`. Actor focus → `onControlActorChange` → `ApplyControlActorFocus` / `WebUI_OnControlActorFocus` (catalog refresh only) + JS `selectSceneInfoForActor`. `WebUI_Visibility_Show` pushes `setFrameworkToggle` and `WebUI_SeedSceneInfos`.

### ControlPanel modes + foreign hosts (2026-09-15)

- **Mode registry:** only `Data/SKSE/Plugins/SkyrimNet_SexLab/webui/ControlPanel/*.json` plus built-in `sexlab`. SexLab git does not vendor third-party JSON. `requiresPlugin` omits missing ESPs. `catalogRoot` loads that plugin’s own `TargetMenu/Actor` + `MainPanels` (not SexLab’s `webui/`). `SwitchControlMode` closes the current main panel, runs previous `closeFunction`, swaps catalogs, runs `openFunction`. Session remembers the last mode across overlay hide.
- **Pause:** overlay still `Focus(view, true)`. TargetMenu execute must `closeWebUI: true` or SexLab `StartThread` / other-mod packages stall. Foreign panel `openFunction` and config toggles stay `closeWebUI: false`.
- **Sentinel target:** pulldown entries with `id` and no FormID. Optional sentinel `mainPanel` / mode `rowClickMainPanel` drive `SwitchMainPanel`; omit them to leave the current panel. `Target_Current` is null; `FocusKind` holds the id. `webui_focus_kind` eligibility; `ExecutePapyrusOption` allows None target. `Target_Menu_Refresh` is valid with a sentinel. Do not treat player focus as group.
- **Foreign panels:** `data_table` / `actor_detail` paint HTML from `WebUI_PushMainPanelData`. Payload must include `plugin` / `scriptName` / `applyFunction` — JS has no plugin-name fallbacks. Cap table rows — a huge Invoke stalls PrismaUI. ESL FormIDs from Papyrus are signed; JS `formIdU32` / C++ accept signed-or-string `formId` on row click. Do not mix table and detail in one payload.
- **TargetMenu `panel: fields` (2026-09-18):** Start + labeled selects from `panelFields`/`panelDefaults`. `applyOnChange` fires on pick. `opensText` options show inline text; Ok adds to the pulldown (session-only). Live Push: `WebUI_PushCascadeChoices` → `setCascadeChoices` (`panel:"fields"` or button `options[]`). Catalog openers without static `panelFields` fire Papyrus first. DOM punish method `rape` embeds `scene_start` without Custom; Start → mind record then SexLab Nonconsensual.

- **SceneInfo (2026-08-22):** JS class + `sceneInfoByKey` (`'new'` + `scene:<sid>`). Seed on Show. Panel drafts copy SceneInfo on open. Start/Done/Update/Stop write into SceneInfo; Cancel does not. Overlay Cancel/Escape → `WebUI_Visibility_HideWithoutCommit` (drop dirty). Hotkey / Scene Start / TargetMenu Start → `flushSceneInfos` → `WebUI_OnSceneInfoCommit` then Hide. Do not live-call `TM_*` from Scene panels during the session.

- **Escape peel (2026-08-23):** Escape closes the highest UI layer first (open pulldowns → IntentPanel Cancel → YesNo silent → Sex menu → TargetMenu cascade/Parameters → main panel to ControlPanel **None**). Leftover TargetMenu/ControlPanel hides the overlay without SceneInfo commit. **Since 2026-09-27 Scene Menu is skipped by the peel:** Escape with Scene Menu open closes the overlay (a YesNo-origin creator without TargetMenu is still released with `_action:"cancel"` first). Root Custom closes an open Parameter panel before toggling Scene Creator.

- **Pause toggle (2026-08-22, revised 2026-09-20):** Overlay opens `Focus(view, true)`. The ControlPanel toggle was removed so live threads cannot drift from SceneInfo; the Description Editor play/pause button now unpauses on purpose (actors must move to test a stage). It re-focuses via `Unfocus` + `Focus(view, paused)`; a repeat `Focus` alone did not unpause. Log tail is file I/O. AnimDB rebuild that needs Papyrus updates waits until close.

- **ControlPanel missing after Start (2026-08-16):** Scene Creator / papyrus Start hide `#control-panel`. Same-actor `Target_Menu_Open` used to only `configureTargetMenu` + Show, skipping `showPanel`. Overlay came back with TargetMenu/ControlPanel still `display:none`. Fix: `WebUI_Visibility_Show` invokes `showControlPanel()`; same-actor open also `showPanel('target_menu_panel')`.

- **Scene Menu appear/disappear loop (2026-08-03):** Do **not** call `requestSceneConnectionChange` from `revealMainPanel`. Connection reload → `SceneCreator_Open` (`showPanel` → `onMainPanelChange` → `SwitchMainPanel` → reveal) loops. Soft path: bind selected SceneInfo (`mainPanelDidOpen` / `configureSceneCreator` merge, no HideAll/showPanel). `SwitchMainPanel` invokes `mainPanelDidOpen()` once on **key change** only. `showPanel` for SC/AM is idempotent when already selected.

## SKSE native params must use engine types (2026-07-25)

CommonLib `RegisterFunction` derives the Papyrus signature from C++ types (`RE::TESForm*` → `Form`, `RE::Actor*` → `Actor`, etc.) and refuses to bind if the `.pex` differs. Declaring a specific script type on a native (e.g. `sslThreadController`) causes: `Native static function … does not match existing signature … Function will not be bound.`

**Fix**: Use engine types in the Papyrus stub that match C++ — e.g. `Sex_Menu_Open(Form thread, bool has_player)` with `RE::TESForm*`. Callers may still pass `sslThreadController` (it is a Quest/Form).

## ModEvent PushForm actors must be received as Form (2026-07-25)

SexLab/SLSO `SexLabOrgasm` uses `ModEvent.PushForm(eid, ActorRef)`. Handlers that declare the first parameter as `Actor` fail type-check for unique NPCs whose **attached script** is an Actor subclass — e.g. vanilla `WIDeadBodyCleanupScript` on Camilla (`CamillaValeriusREF`). Papyrus reports `received incompatible arguments! Received types (WIDeadBodyCleanupScript,int,int) instead!` and the event never runs (orgasm narration dropped for that NPC).

**Fix**: Receive `Form`, then `akForm as Actor` (same pattern as this mod’s `Action_Stop` / `MenuOpen`). `WIDeadBodyCleanupScript` is often on living uniques — it is cleanup-on-death, not “already dead.”

## PrismaUI view path (2026-07-24)

`CreateView("SkyrimNet_SexLab/index.html")` loads from **`Data/PrismaUI/views/`**, not from `SKSE/Plugins/`. This mod ships the overlay at `PrismaUI/views/SkyrimNet_SexLab/index.html` (restored from commit `a8c9440`). **`make release` copies `PrismaUI/` into FOMOD `core`** so it installs under Data. Missing that file → valid-looking C++ open path (hotkey / `Target_Menu_Open`) but **no visible UI**. Do **not** `Show`/`Focus` until `g_domReady` — `Focus(view, true)` pauses the game; Escape is JS `handleGlobalEscape` which never runs if DomReady never fires (player stuck paused). C++ Escape and a refused open `Unfocus`/`Hide` instead. Papyrus `Open_WebUI_Target` notifies when `Target_Menu_Open` returns false. C++ Invokes use panel ids `target_menu_panel` / `sex_menu_panel`; the HTML maps those via `showPanel` / `hidePanel` adapters onto `#target-panel` / `#sex-menu-panel`.

**Display scale (2026-08-07):** Matches SkyrimNet dashboard scaling system. Design tokens are **px** (`--text-base: 15px`, `--space-*`, `--radius`, `--target-min: 44px`); global scale is `document.body.style.zoom = clamp(ui_scale,0.75–1.5) * resolutionBaseline()` where baseline is `1` at ≤~1080p height else `(innerHeight/1080)*0.85` (up-only; never shrinks from resolution). User `ui_scale` from `GET {__SN_BASE__||http://localhost:8080}/config?api=get&name=Dashboard`. Fit without crop: `#left-column` / target panels use `max-height` + `overflow-y: auto` (same pattern as SkyrimNet’s `.main` scroll). Re-applies on resize and Settings configure.

**Menu hotkey (2026-08-04, toggle 2026-08-16, DomReady guard 2026-08-21, keys 2026-09-15):** Plugin config `sexlab.editor.hotkey_enabled` + `sexlab.editor.hotkey` (VK→DX). MCM also has Enable + KeyMap (DX) → `WebUI_SetHotkey`. Escape stays always registered; if DomReady never fired, Escape is C++ `WebUI_Visibility_Hide` (Unfocus), not queued JS. Hotkey hides immediately when the overlay is visible (any actor); otherwise `Menu.ProcessHotkey` → `Open_WebUI_Target`. Same-actor reopen rebuilds catalog, `showPanel('target_menu_panel')`, and Show (ControlPanel included). Do not dispatch `AfterTargetOpen` on close. Do not Show/Focus until `g_domReady`. `WebUI_SetHotkey(0, true)` disables the KeyHandler — never pass DX 0 when enabled.

## WebUI target menu catalog (2026-07-28, outfit/actionSwitch 2026-07-31, split layout 2026-07-31)

Target panel UI is driven by:
- `Data/SKSE/Plugins/SkyrimNet_SexLab/webui/TargetMenu/Actor/defaults.json` — `{ "defaultsParameters": { ... } }` (legacy root key `defaults` still accepted).
- `Data/SKSE/Plugins/SkyrimNet_SexLab/webui/TargetMenu/Actor/options/*.json` — start-scene + outfit when focus is **not** in SexLabAnimatingFaction.
- `Data/SKSE/Plugins/SkyrimNet_SexLab/webui/TargetMenu/Scene/options/*.json` — live-scene group editors when focus **is** animating.
- `Data/SKSE/Plugins/SkyrimNet_SexLab/webui/actions_index.json` — generated from SkyrimNet action YAMLs (`tools/generate_actions_index.py`); `{ "actions": [...] }` only (no `by_category`).

**Order = lexicographic filename** (numeric prefixes). All JSON keys lowercase. Pulldowns / switches nest via `options[]`; each `action` needs `name` (SkyrimNet id) + `label` (WebUI display only). Optional `parameters` on `action`/`pulldown` overrides defaults. C++ loads both trees and `BuildUICatalog` picks Actor vs Scene.

**Actor sources** in `defaultsParameters`: prefer `playerActor` (player) and `currentActor` (menu focus). `ActionDispatch::ResolveSource` also accepts legacy `player` / `target` / `focus`.

**`actionSwitch`**: `options[]` of `action` children, each with SkyrimNet-shaped `eligibilityRules`. C++ evaluates in order, takes the **first** true branch, logs the winner. No match → emit disabled/greyed row using switch `label` or first child’s `label`. Menu focus is `currentActor` for `FormListCount` / strip storage.

**Outfit roles**: Papyrus `Outfit_Dress` / `Outfit_Undress(Speaker, Target, style, narration)` — Speaker performs, Target’s outfit changes; StorageUtil key `skyrimnet_sexlab_storage_items` is on **Target**. Narration `silent` → `RegisterEvent`. Style `silently`/`silent` skips both DirectNarration and RegisterEvent. TargetMenu dress/undress is papyrus `panel: outfit` → `TM_Outfit` (not YAML Start); FormListCount eligibility picks the undress vs dress left-row label; execute uses `HasStrippedItems` on selected position_0. Hotkey opens via `Menu.Open_WebUI_Target` (passes `HasStrippedItems`). LLM YAML files are `outfit_dress.yaml` / `outfit_undress.yaml` under `SKSE/Plugins/SkyrimNet/external/goodprovider.sexlab/actions/` (filename equals `name`).

Regenerate the index after editing action YAMLs (`tools/generate_actions_index.py` reads `external/goodprovider.sexlab/actions`). C++ `ActionCatalog` loads at WebUI init and **reloads on every `kPostLoadGame` / `kNewGame`** (`WebUI_SetGameReady`); Start merges dictionary onto YAML `parameterMapping` and `DispatchMethodCall`s `scriptName`/`executionFunctionName`. Do not change SkyrimNet YAML schema — only action content within existing fields.

Guideline: if a pulldown would have only one child, promote that child to a top-level `action`.

## TargetMenu hierarchical param store (2026-08-02)

Do **not** remember dynamic fields under flat `sns_tm_param:<name>` — shared names (`method`, `direction`) leaked across actions (e.g. comfort `hugging` onto fucking). JS builds a parent-linked tree from the catalog (synthetic root `id=0`; DFS creation ids; `path = parent.path + '.' + label`). Values live at `sns_tm_node:{id}.{path}.{key}` (empty path → `sns_tm_node:0.style`). Global `parameter` options (e.g. `style`) read/write the **root**. Action dynamics initialize fill-if-absent by walking parents for an **allowed** YAML pipe match (style synonyms `gently↔gentle`, `normally↔normal`, `forcefully↔forceful`), else first pipe / full non-pipe description; then store on that action node. `configureTargetMenu` clears legacy `sns_tm_param:*`.

## SexLab position slots and speaker_position (2026-07-23)

In this mod's sex / punish animations, **position_0 is submissive** and **position_1 is dominant**:
- position_0 gives oral to position_1; position_1 receives oral from position_0.
- position_1 fucks into position_0; position_0 is fucked by position_1.
- Punish scene JSON puts `_pain_` (and whipping `_gagged_`) on index 0.

The **Speaker is always the subject** of LLM-facing sentences. `speaker_position` places the Speaker into that slot:
- `StartScene_Nonconsensual_Two_TargetVictim` → speaker at **pos1** (target is victim).
- `StartScene_Nonconsensual_Two_SpeakerVictim` → speaker at **pos0** (speaker is victim).
- Consensual direction tokens (Speaker as subject): `fucking` / `fuck a` / `fucking a` / service `getting` → pos1; `fucked in` / service `giving` → pos0.
- **Cuddling intents** (`cuddling` / `showing affection` / `comforting`): opposite of oral — `giving` → pos1 (hug giver / male slot); `getting` → pos0.

## Intent start/finish mirror (2026-07-23)

`GetIntentMessage(START)` → `"A and B start <intent>."`; `GetIntentMessage(END)` → `"A and B finish <intent>."` (same actors + same static intent phrase). Intent is not always sexual — examples: `sexual activities`, `showing physical affection`, `physically comforting each other`, `physically punishing`, `sexual assault`, `cuddling`. YAML `intent` values must be static phrases that fit both templates.

## Orgasm totals via GetIsOrgasming (2026-07-24)

`Scene.GetIsOrgasming(Actor, total_orgasms=-1)` is the single place that both bumps per-actor totals (`StorageUtil` + `total_orgasm`) and returns the `" is orgasming."` prompt-gate clause. Call sites: `OrgasmCombined` (stash), `OrgasmIndividual` (SLSO absolute `num_orgasms`), `OrgasmCustom` (always increment; append only if substring missing). When `thread.Animation` has tag `tentacles`, `GetIsOrgasming` appends tentacles flavor on that orgasming actor only — do **not** force-orgasm all positions from `AnimationEnd`. `OrgasmMessagesToNarration` must not increment again on flush. "again" uses the post-update `GetTotalOrgasms` count (not the pre-increment `-1` local).

## Scene pool generic fallback (2026-07-26)

`GetSceneInactive` may bind `sl_scene_generic` only when `!GetThreadActive()`. Concurrent 11th+ scenes refuse allocate (`None`) rather than overwrite a live generic — avoids CK pool expansion. `Scene.Release` always `UnsetThread_scene(tid)` including generic.

## Creator.Setup returns Bool (2026-07-26)

`Scene_Creator.Setup` returns `False` on link/empty-actor failure (no `STATUS_ACTIVE`). `CreateCreator` returns `None` when Setup fails or pool exhausted; all callers must gate on `None` (Action_Start, Menu multitarget, CreateSceneWithoutCreator, GetSceneByThread).


## Pyro / UIExtensions import (2026-07-24)

`skyrimse.ppj` imports `@ModsFolder\UIExtensions\scripts\Source`. If that folder is empty, Caprica fails with `unable to locate script UIExtensions`. Restore real UIExtensions sources there (stubs only for compile smoke tests).

## Orgasm stash / AnimationEnd pipeline (2026-09-13)

1. `OrgasmCombined` / Combined `OrgasmCustom` stash into `orgasm_messages`.
2. **No Dom slave in thread:** `thread.UpdateTimer(4.0)`; next `StageStart` flushes via `OrgasmMessagesToNarration()` into one DirectNarration.
3. **Dom slave in thread:** do **not** `UpdateTimer` (P+ `_ForceAdvance` hops) and do **not** consume the stash on StageStart. `ArmOrgasmWindow` → `RegisterForSingleUpdate(sexlab.orgasm.delay)` (default 5s), restarted on every Combined/Custom event but capped at **2× delay** from `orgasm_window_started_at`. Scene `OnUpdate` waits out `IsInMenuMode`, then `FlushOrgasmWindow` (`AlignActors` then one DirectNarration of every `" is orgasming."` clause). Immediate `OrgasmHelper` on melt would be overwritten by a later player climax DN.
4. `SetStyleDialog` skips its DirectNarration while `orgasm_messages_set` (style is already in scene JSON).
5. `AnimationEnd`: leftover stash is prepended to the finish DirectNarration (must include `" is orgasming."`). Do not RegisterEvent-only leftover — 0550 gates on DirectNarration. Then `Release` (UnregisterForUpdate). SeparateOrgasms afterglow unchanged. Do not narrate ongoing activity at end.
6. `AnimationStart` (STATUS_SETUP): flush a pending stash before clearing — do not drop a melt that raced AnimationEnd→next start.
7. Handler delayed melt: after 1s, retry `manager.OrgasmCustom` if the scene is back; only DirectNarrate when still unreachable (keeps scene totals / Combined window in sync).

**Symptom (2026-09-13):** Dom HUD `Nina's brain melts…`, `total_orgasm` 0→1, no `" is orgasming."` DN; 0550 never gated. SexLab hotkey SkyMessage was open; Combined stash waited on StageStart/`UpdateTimer`; style DN (`Bob changes from 'forcefully' to 'gently'`) took the slot.

**Symptom (2026-09-13 later):** Melt DN correct (`Nina is orgasming`, total 0→1). Last-stage Combined then flushed `Nina is orgasming. Bob is orgasming.` even though DOM skipped the player-tease HUD and Nina’s total stayed 1.

**Cause:** `OrgasmMessagesToNarration` Combined slave fallback treated lifetime `total_orgasm > 0` as “orgasming now”. Also: MO2 profile was loading the installed release without `ArmOrgasmWindow` / `orgasm_narrated`.

**Fix:** Position JMap `orgasm_narrated` records how many orgasms were already spoken. Flush marks it when emitting a stash clause. Fallback only if `GetTotalOrgasms > orgasm_narrated`. Already-spoken slave gets `" is not orgasming right now."` (not denied). Enable the git workspace mod in MO2 when testing.

**Symptom (2026-09-13 StageEnd melt):** DOM HUD `Nina melt orgasm` between `HookStageEnd` and `HookStageStart`. `Get_Threads` stayed `total_orgasm: 0`. StageStart sent `continue activity`. No `"brain melts"` DN.

**Cause:** `GetThreadByActor` / `GetSceneByThread` require SexLab state `animating` or `prepare`. During StageEnd the controller is often neither, so `OrgasmCustom` aborts. Separately, first-stage melt flushed via `RegisterEvent` then `DirectNarration` of the same sentence; `CheckDuplicate` emptied the DN (0550 gates on DN only).

**Fix:** `GetSceneByActor` scans `thread_scene` (and `sl_scenes`) when the state filter misses. `OrgasmCustom` uses `GetThreadByActor(any_state)` + `GetSceneByThread(any_state, create_if_missing=false)`. Handler delays the melt 1s if scene is still None, then retries `OrgasmCustom` before falling back to DirectNarration. StageStart RegisterEvents the stage desc only, then DirectNarrates the orgasm sentence.

## Actor lock key (2026-07-23)

Creator locks with `skyrimnet_sexlab_scene_actor_lock`. Action YAML eligibility and `Main.storage_actor_lock_key` must use the same string (not `skyrimnet_sexlab_actor_lock`).

## Punish-rape setting_name must match scene file (2026-07-22)

`sexlab_punish_rape_target.yaml` / `sexlab_punish_rape_target_by_target.yaml` must use `setting_name: punish_pleasure_pain_rape` (file `scenes/punish_pleasure_pain_rape.json`). A swapped token order (`punish_pain_pleasure_rape`) fails to load the scene. Hotkey Menu.psc uses the correct name. See review-checkpoint `Y-RapeSettingName`.

## SkyrimNet action YAML practice (2026-07-18)

Full authoring guide: [docs/authors/actions.md](docs/authors/actions.md).

Actions live in `SKSE/Plugins/SkyrimNet/external/goodprovider.sexlab/actions/`. The YAML filename must equal the in-file `name`. Executable YAMLs dispatch to `SkyrimNet_SexLab_Actions` via positional `parameterMapping` — order and types must match the Papyrus signature; mapping `name` is LLM-facing only.

- **Hard limit: max 8 `parameterMapping` entries** per action YAML (SkyrimNet). Threesome actions already use all 8; do not add a 9th — fold into an existing dynamic, use `setting_name`, or a fixed-role Papyrus wrapper.
- `static` requires `value`; `dynamic` requires `description` (not `value`).
- Prefer Papyrus slot names in mappings (`method`, not `type`; `how` for outfit).
- Action `name` must be unique across all YAMLs.
- Fixed-role nonconsensual two-actor scenes use `StartScene_Nonconsensual_Two_TargetVictim` / `_SpeakerVictim`. Dynamic victim uses `StartScene_Nonconsensual_Two` with an explicit `victim` mapping. Do not pass obsolete `speaking_victim`.
- Eligibility rule groups that exist should set `logicalOperator` and `required: true` (`required: false` is ignored by SkyrimNet).
- Category parents: only `name` / `description` / `customCategory` / `enabled` / eligibility — no `description_` field; keep PARAMS JSON valid.

Upstream schema: [WORKFLOW_ACTIONS.md](https://github.com/MinLL/SkyrimNet-GamePlugin/blob/main/docs/modding/WORKFLOW_ACTIONS.md).

## StageStart scene-change must not wipe orgasm narration (2026-07-17)

**Symptom**: `OrgasmCombined` stashes `"bob is orgasming. "` and sets `orgasm_messages_set`, but final DirectNarration is only `"Scene changes to …"` + cum — no `" is orgasming."`, so `0550_sexlab_narration.prompt` never gates.

**Cause**: In `Scene.StageStart`, after building `narration` from `orgasm_messages`, `desc != description_last` did `narration = "Scene changes to "+desc`, which replaced the orgasm/denied block. `orgasm_happened` stayed true (cum still appended); only the orgasm text was lost.

**Fix**: When the stage description changes, lead with `"Scene changes to "+desc` and **append** any existing orgasm narration instead of assigning over it. Non-orgasm ChangePosition path (empty narration) is unchanged.

## EnsureActorArraysLargeEnough must check both arrays (2026-07-16)

**Symptom**: `OrgasmCombined` — `Cannot access an element of a None array` on `orgasm_messages[i]`.

**Cause**: `EnsureActorArraysLargeEnough` early-returned when only `position_objs` was large enough. After save/load (or when `orgasm_messages` was added later), `position_objs` can be restored while `orgasm_messages` stays None.

**Fix**: Early-return only when **both** `position_objs` and `orgasm_messages` exist and meet `size`. `OrgasmCombined` also calls `EnsureActorArraysLargeEnough(num_actors)` before indexing (same pattern as `OrgasmCustom`).

## Papyrus string literals do not treat `\n` as newline (2026-07-15)

`"\n"` / `"\r\n"` in Papyrus source are backslash + letter(s), not control characters. Use `StringUtil.AsChar(10)` (LF) and `StringUtil.AsChar(13)` (CR). This project already does that in `Stages.psc` / `MCM.psc` via a `newline` field.

## SexLab orgasm narration trigger (2026-07-14)

**Prompt**: `SKSE/Plugins/SkyrimNet/external/goodprovider.sexlab/prompts/submodules/user_final_instructions/0550_sexlab_narration.prompt` uses `contains(_direct_narration, " is orgasming.")`.

**Contract**:
- Orgasming actors’ clauses in Combined/custom narration must include `" is orgasming."`.
- Non-orgasming / denied clauses must not (e.g. Combined and Separate `name+" is not orgasming right now. "`, `HandleOrgasmDenied`, “did not orgasm”, afterglow “failed to orgasm”). Combined flush and `OrgasmIndividual` name every non-orgasming actor; do not use a generic “only listed actors” sentence.
- Dom custom path: `Handler_DOM.DOMSlave_Orgasmed` → `Scene_Manager.OrgasmCustom` appends `". "+name+" is orgasming."` before Scene stashes/sends. Required for the prompt gate.
- Dom Combined fallback: when `_dom_slave`, `orgasm_expected==1`, totals > 0, and custom message empty, Scene still appends `name+" is orgasming. "` so the prompt gate fires if Dom feed raced past Combined.
- Dom feed: sibling `SkyrimNet_DOM_Events.OnNotificationSent` (Ext3 on) routes **melt** phrasing (`brain melts` / `mind melts` / `overwhelmed by orgasm` / `submerged by orgasm`, not `your orgasm`) to `DOMSlave_Orgasmed`. Do not match bare `"orgasm"`. The player-climax tease (`squirms under your grasp as your orgasm submerges you`) is skipped in Dom `OnNotifcationSkip` and again in `Handler_DOM.DOMSlave_Orgasmed` (no OrgasmCustom / DN). Prefer notifications over `DOMOnOrgasm` (faster; leave Orgasm unregistered). Dom `SexLab_AnimationStart` may `DisableOrgasm` on Dom actors so SexLab hooks alone will not narrate them. If Ext3 is off: Dom melt HUD can fire while DN denies the slave or narrates other actors only — see SkyrimNet_DOM KNOWLEDGEBASE “Dom melt without DirectNarration”.

**SeparateOrgasms**: Manager skips Dom on `SexLabOrgasm`; `Scene.OrgasmCustom` must use `config.SeparateOrgasms` and call `OrgasmHelper` immediately when Separate is on; Combined stashes into `orgasm_messages` and, with a Dom slave, arms the Scene `OnUpdate` window instead of StageStart/`UpdateTimer`.

## Scene pool / GetSceneInactive None (2026-07-12)

**Symptom**: `Cannot call SetThread() on a None object` in `GetSceneInactive` after `Failed to find inactive sl_scene using generic`, even with **no active SexLab animations** (pool should be free).

**Causes**:
1. Property rename `scenes`/`scene_generic` → `sl_scenes`/`sl_scene_generic`: Auto property fills are **baked into saves**. Old saves keep empty new-name properties; `creators` (unchanged name) still works. Runtime pool looks empty → fallback to None generic → crash.
2. `sl_scene_generic` Auto property unresolved → fallback `SetThread` crashed (no None guard).
3. `STATUS_*` were `Auto` (not `AutoReadOnly`). Saves can corrupt constants so `IsActive()` stays true forever.
4. `Initialize` did not reset `status` / clear stale `thread`.

**Fixes**: `RebuildScenePool()` via `GetFormFromFile` every Setup; None-guard + generic recovery; `STATUS_*` → `AutoReadOnly`; reset `status`/`thread` on Initialize; reclaim by `GetThreadActive()` (not status alone).

## DOM / external thread scene bind race (2026-07-27)

**Symptom**: Native DOM SexLab threads log `[SkyrimNet_SexLab_Stages.GetStageDescription] thread is None` shortly after `SetPosition` during scene auto-create. SkyrimNet prompts may lack activity/description for that thread.

**Cause**: `GetSceneInactive` published `thread_scene[tid]` before `SetThread(thread)`. A reentrant `GetSceneByThread` (from `SaveThreadsJson` / decorators during first-frame Setup) saw `GetThread() == None`, failed reference equality, and `Release()`'d the scene mid-Setup. `SetPosition` could still finish; later `GetDescription` ran with `thread == None`.

**Fixes**: `SetThread` before `thread_scene[tid]` in `GetSceneInactive`; `GetSceneByThread` treats `thread_scene[tid]` as authoritative (rebind when `bound == None` or `bound.tid` matches — do **not** require `IsActive()`, because Setup only sets `STATUS_SETUP` at the end); `EnsureSceneForThread` on `HookAnimationStart` / `HookStageStart`; thread guards in `Scene.AnimationStart` / `GetDescription` / `GetThreadObj`. Release only on tid mismatch.

## Scene narration prompts (2026-09-09)

Only afterglow and cum go through `RenderSlPrompt` (`helpers/sexlab/afterglow.prompt`, `helpers/sexlab/cum.prompt`). That helper is `SkyrimNetApi.RenderTemplate` then `ParseString` with namespace `sl` JSON (same as Stages `ParseString`). Empty, error-looking, or leftover-`{{` renders fall back to the previous Papyrus sentence. A single name is string `sl.name` (`{{sl.name}}`), not a one-element array. All other scene DirectNarration strings are inline Papyrus. The `" is orgasming."` 0550 gate is still emitted by `GetIsOrgasming`; that function still bumps totals before wording.

## Description Editor actor table (2026-09-20)

Scene-pick anim rows are stubs: `_in_thread_anims` (`Scene.psc`) carries only `_registry/_name/_tags`, so `_pos_no_orgasm` / `_pos_speaking_modifiers` / `_position_count` are absent. The Description Editor fetches the DB row with `onAnimDbQuery {_type:"anim", _registry}` (stub detected by `_position_count == null`). `info.positions[i]._no_orgasm/_speaking` are live scene values, not anim defaults.

**Registry casing**: `AnimationDB` stores and returns registries lowercase (`_registry` in `onAnimDbQuery` replies), while scene-derived registries (`info.activeRegistry`, `_in_thread_anims`) keep SexLab casing (`B_B_3pFFMMis`). Joining a DB reply to a scene row must compare case-insensitively (`deRegEq`); a strict `===` silently dropped the row and the actor table never rendered.

## Description Editor stage step vs game pause (2026-09-20)

**Symptom**: after ◀/▶ while the overlay pauses the game, later steps show the notification `dropped (thread not active)`; `SkyrimNet_SexLab.log` has `GetThreadActive: thread is not animating or prepare 'Advancing'`.

**Cause**: vanilla SexLab `GoToStage` sets `Stage` and enters state `Advancing`, which finishes via `RegisterForSingleUpdate` (game time) → `Animating` + `StageStart`. With `Focus(view, pauseGame=true)` game time is frozen, so the thread stays `Advancing` and `GetThreadActive()` rejects every commit. `thread.stage` changes synchronously, so a push right after `GoToStage` looks like the thread reported back but it has not.

**Fix**: JS auto-unpauses for a step and re-pauses on the `_stage_started` push sent from `Scene.StageStart`; the `ApplyWebUICommit` push only moves the row.

## WebUI click-lockout from timer-driven pause toggle (2026-09-22)

**Symptom**: after a Description Editor autosave, the whole overlay stopped responding to clicks — cursor still moved, Escape still closed the overlay — but nothing was clickable. `SkyrimNet_SexLab.log` showed zero entries for the rest of that session: no click ever reached a native JS listener again.

**Cause**: a `deSaveToDisk()` change unpaused the game for a live "dressed" toggle save, then re-paused via a bare `setTimeout(deRepauseAfterStep, 500)`. Every other caller of the `onGamePauseSet` → C++ `Unfocus(g_view)` + `Focus(g_view, paused)` pair (`WebUI.cpp:976-988`) fires it from a real click (the pause button) or from a real click whose re-pause then waits on an actual completion push (`deStageStep` → `_stage_started`, see the entry above) — the 20s timer there is only ever a fallback, expected to be pre-empted by the push almost every time. This new call site had no completion signal to wait on (`Outfit_Dress`/`Outfit_Undress`/`WebUI_ApplyLivePositions` push nothing back to JS — `Target_Menu_Refresh` is unrelated and gated on TargetMenu focus, not Description Editor state) and no antecedent user-input-event in the timer callback's JS turn. That untested combination — native `Unfocus`+`Focus` fired from a bare timer with nothing else in flight — is the prime suspect for PrismaUI/CEF losing click hit-testing while OS-level cursor movement and the separate `KeyHandler` Escape sink kept working.

**Fix / rule**: reverted — `deSaveToDisk()` no longer touches pause state; the dressed-toggle live-apply just attaches `_scene_sid`, same as before. Going forward: never call `onGamePauseSet` from a bare timer. Either gate the re-pause on a real completion push (mirror `_stage_started`), or don't automate the pause toggle for an action that has no completion signal — let the user drive the existing manual pause button instead.

## Description Editor scene pulldown empty: `_in_thread_anims` JSON corruption (2026-09-22)

**Symptom**: a live scene (confirmed valid server-side — `BuildWebUISceneMenuObject` reports correct `positions`/`names`/`stage`) is not offered as an option in the Description Editor's "scene:" pulldown. Pre-existing, intermittent/data-dependent; unrelated to any change made the same day.

**Cause**: `WebUI_SeedSceneInfos` (`Menu.psc:140`) → `manager.BuildAllSceneInfosJson()` (`Scene_Manager.psc:928`, loop at `:954-963`) → `ObjectToLowerCaseKeyJson(root)` (`Scene_Manager.psc:968`) → native `JsonLowerCaseKeys` fails to parse the aggregate JSON it was handed → `ObjectToLowerCaseKeyJson` (`Utilities.psc:763-773`) downgrades **the entire payload**, not just the bad field, to `"{}"` on any parse failure → JS `seedSceneInfos({})` → `sceneInfoByKey` gets zero active entries → `deListActiveSceneKeys()` returns `[]` → pulldown never lists the scene. This also silently defeats live-apply saves that resolve their scene via `deActiveSceneForRegistry`'s no-pick fallback, since it iterates the same empty list.

A diagnostic `Trace` added to `ObjectToLowerCaseKeyJson` (dumping the raw pre-lowercase JSON on failure instead of swallowing it) captured an exact repro: the `_in_thread_anims` array (built in `BuildWebUISceneMenuObject`, `Scene.psc:2477-2504`, from `thread.Animations`) has a well-formed run of anim entries, then one entry missing its `_registry`/`_tags` fields (only `_name` present), then ~48 literal unquoted **uppercase** `NULL` tokens as raw array elements — not valid JSON, and not a string this codebase's own manual JSON walker (`Utilities.psc:635-694`) ever writes (audited: every path there returns valid JSON or lowercase `"null"`; grepping `Scripts/Source` for `"NULL"` finds nothing). Root mechanism not yet confirmed — leading theory is `thread.Animations` (SexLab's own array) containing trailing invalid/`None` entries past a real count, with some property getter on them (`.Registry`, `GetTagsString`) failing in a way that isn't going through this codebase's `JsonQuote`/`JsonForm`. See `checkpoints/skse-scene/v3-checkpoint.md` §0 for the full capture and suggested next instrumentation step.

**Fix**: not yet fixed — diagnostic only, landed to unblock the next debugging session with a precise repro instead of a guess.

## JsonStore handles went negative: session >= 32 (2026-09-26)

**Symptom**: Description Editor showed clothed `0,0` / orgasm `1,1` for an animation whose `_local_` file says `clothed [1,1]`, `orgasm_expected [0,0]`; actors stripped at scene start; DE Save wrote the file correctly but never re-dressed actors, and reopening the DE showed `0,0 / 1,1` again. Log: one actor's `RestorePosition` repeated many times in a single scene.

**Cause**: `JsonStore.cpp` started sessions at 32. The session sits in handle bits 31..26, so session >= 32 sets bit 31 and every handle is a negative int32. Papyrus guards handles with `> 0` / `< 1` (~40 sites): `EnsureActorArraysLargeEnough` recreated `position_objs[i]` on every call (losing state, re-running `RestorePosition`), and `SeedOverlayFromAnimDb` / `WebUI_ApplyLivePositions` skipped every `position_objs[i] > 0` write.

**Fix / rule**: sessions are restricted to 16..31 (`kLastSession = kSessionMask >> 1`) with a `static_assert` that the largest handle fits in a positive int32. Handles must always be in `(0, INT32_MAX]`; never widen the session/gen/slot layout into bit 31.

## Style-driven animation speed (2026-09-27)

SexLab 1.6x has no playback-speed API. `AnimSpeed.cpp` hooks `UpdateAnimation` (vfunc `0x7D`) on the `Character` and `PlayerCharacter` vtables and scales `a_delta` for actors in a FormID map (empty map → no lock, pass-through). **Rule**: this changes speed only. SexLab stage timers, the orgasm window and voices run on Papyrus real time and must stay untouched — never pair a style change with `UpdateTimer` / `AdvanceStage`. Every position in a thread gets the same multiplier (`Scene.ApplyStyleSpeed`), or paired animations drift apart. Speeds are set at `AnimationStart` and on `Scene.SetStyle` / `SetStyleDialog` / `ChangeStyle`, cleared at `AnimationEnd` / `Release`, and the whole map is cleared on load / new game. The style hotkey refuses the menu hotkey's scancode (`KeyHandler` keeps one callback per key). VR: vfunc index not verified (SE ≠ VR).

## SkyrimNet CppAPI include path (2026-09-27)

SkyrimNet's `PublicAPI.h` now lives in `c:\Skyrim\dev\mods\SkyrimNet devkit\CppAPI`. `SKSE_Source/CMakeLists.txt` includes `"../../SkyrimNet devkit/CppAPI"` (quoted — the folder name has a space). The old `../../SkyrimNet/CppAPI` no longer exists; `skyrimnet beta25 rc6\CppAPI` and `SkyrimNet Tester\CppAPI` are stale copies — do not point the build at them.

## DirectNarration while the game is paused (2026-09-27)

**Symptom**: changing style in the Description Editor narrated, but SkyrimNet logged `DialogueManager::GenerateResponse: NPC Nina failed to generate a response`. SkyrimNet.log showed every Papyrus decorator refused with `Blocking VM call for decorator … because game is paused` — the overlay pauses the game (Focus pauseGame), so the follow-up speaker had no decorator data.

**Rule**: never call `SkyrimNetApi.DirectNarration` directly; use `SkyrimNet_SexLab_Utilities.SendDirectNarration` (the `DirectNarration` / `DirectNarration_Optional` wrappers already do). While paused (`WebUI_IsGamePaused()` or `UI::GameIsPaused()`), native `QueueDirectNarration` stores it in `NarrationQueue.cpp`; a watcher posts a game-thread check every 250 ms and, once unpaused, joins the queue (sentence-joined, exact repeats dropped, first source/target, purge if any asked) into one `DirectNarration_Flush`. Load / new game clears the queue.

## New SKSE .cpp needs a CMake reconfigure (2026-09-27)

`CMakeLists.txt` collects `src/*.cpp` with `file(GLOB …)` at configure time. A new source file links as "unresolved external" until CMake reconfigures — touch `CMakeLists.txt` (or rerun the configure preset) before `cmake --build`.
