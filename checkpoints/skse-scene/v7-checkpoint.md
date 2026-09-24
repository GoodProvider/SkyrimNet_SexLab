# Checkpoint v7: `victim_faction_forms` migrated + JsonStore native gaps filled; Description Editor dressed/victim bugs fixed — CONFIRMED IN-GAME 2026-09-24

Supersedes [v6-checkpoint.md](v6-checkpoint.md). Everything in this checkpoint has been confirmed
working in-game by the user ("verified").

Written from `c:\Skyrim\dev\mods\SkyrimNet_SexLab`, branch `skse-scene`, baseline commit `12c0ca4`
("Replace JContainers with a C++ JSON store; fix DLL deploy target"). Nothing committed yet this
session — see §6.

---

## 1. Stage S2, Pass 1 (partial): `victim_faction_forms` migrated to JsonStore

Per the staged S0-S5 JContainers migration plan (`v5-checkpoint.md` §3), S2 covers the rest of
`Scene.psc`'s ~315 remaining JContainers call sites. Scoped down mid-session to just one of the
five persisted "holder" handles — `victim_faction_forms` — because converting a holder's storage
type requires converting every function that reads/writes it in the same pass (JContainers and
SNSL handles aren't interchangeable — a JContainers native given an SNSL handle just fails
silently), and the other four holders (`position_objs`, `actors_objs`, `thread_obj`,
`user_anim_defaults`) have far more readers scattered through the file. `victim_faction_forms` was
the one small enough to fully convert in one safe slice — only touched by `Initialize`,
`ReconcileVictimFactions`, `Release`.

- Widened its `< 1` creation guard to also check `SNSL_JValue.isExists()` — the actual save/load
  fix. SNSL handles don't survive a save/load (no co-save integration, by design), unlike
  JContainers handles which do. `Initialize()` already reruns on every load (via the existing
  `OnPlayerLoadGame → main.Setup() → manager.Setup() → sl_scenes[i].Initialize()` cascade), so the
  widened guard alone is enough to correctly rebuild on load — no new event wiring needed.
- Migrated `Initialize`, `ReconcileVictimFactions`, `Release` to `SNSL_JArray`/`SNSL_JValue`.
- Deleted dead code: `GetVictimsNamesJsonObj` (zero callers found anywhere in `Scripts/Source`,
  leaked handle).

### New JsonStore natives (required, not optional)

Discovered mid-migration that `SNSL_JArray`/`SNSL_JMap` were missing natives that
`ReconcileVictimFactions`/`Release` actually need: `eraseIndex`, `findForm` (JArray), `hasKey`,
`removeKey`, `clear` (JMap), `clear` (JArray). None of these existed in `JsonStore.h`/`.cpp` at
all — not just missing from the `.psc` wrapper. Added:
- `JsonStore.h`/`JsonStore.cpp`: `MapHasKey`, `MapRemoveKey`, `MapClear`, `ArrayEraseIndex`,
  `ArrayFindForm`, `ArrayClear`.
- `Papyrus_Json.cpp`: bindings + registration for all six.
- `SNSL_JMap.psc`/`SNSL_JArray.psc`: Papyrus native declarations.

C++ rebuilt clean (`cmake --build build/release --target SkyrimNet_SexLab --config Release`), DLL
confirmed deployed to the correct (no-space) enabled mod folder with the new symbols present
(binary grep for `eraseIndex`/`findForm`/`hasKey`/`removeKey`).

**Remaining S2 scope** (not done this session): `position_objs`, `actors_objs`, `thread_obj`,
`user_anim_defaults` and their ~25+ reader/writer functions. Each needs its own full-slice
treatment (holder + every accessor, migrated together) for the same reason `victim_faction_forms`
did. Expect more missing JsonStore natives to surface — e.g. `SNSL_JFormMap` has no scalar
accessors beyond `getObj`/`setObj` today.

---

## 2. Description Editor bugs found and fixed during in-game testing

Three separate, real bugs surfaced while verifying §1 — none caused by the JsonStore migration
itself (all pre-existing, in code untouched until now).

**a. Dressed column showed AnimDB template defaults, not live state.** `deLoadPosDraft()`
(`index.html`) always built the Description Editor's actor table from the animation registry's
generic saved defaults (`a._pos_clothed` etc.), even when bound to a live scene. Fixed: when
`deIsSceneBound()`, source `_dressed`/`_no_orgasm`/`_speaking` from `SC.positions` (the live
per-position state `BuildWebUISceneMenuObject` already sends) instead of the AnimDB row.

**b. Victim flag from Scene Creator clobbered on WebUI commit.** `Scene_Creator.psc`'s
`ApplyWebUIState` called `SetNames()` — which internally calls `SetMasks()`, recomputing
`victim_mask` from the *old* `victims[]` array — immediately after writing the fresh
`victim_mask[i]` from the WebUI payload, silently discarding a first-time victim flag before
`RebuildVictimsFromMask()` ever ran. Fixed by deleting the redundant `SetNames()` call;
`RebuildVictimsFromMask()` (already called later in the same function) refreshes the same name
strings without the destructive side effect.

**c. WebUI's `_victim` field read a lagging faction proxy instead of live thread state.**
`BuildWebUISceneMenuObject()` and `BuildWebUIAnimationMenuState()` both computed `_victim` from
`ak.IsInFaction(SkyrimNet_SexLab_Faction_Victim)` — a custom faction only re-synced by
`ReconcileVictimFactions()` at specific lifecycle events (Setup/AlignActors on stage/animation/
orgasm changes), not immediately after a live `thread.SetVictim()` call. Fixed both to read
`thread.IsVictim(ak)` directly, matching what `SetActor()` and the `sexlab_get_threads` decorator
already did.

---

## 3. New feature: Description Editor victim (V) column + narration on toggle

Per user request, since (b)/(c) above made live victim toggling correct but there was nowhere in
the Description Editor to actually toggle it:

- Added a V column to the Description Editor's actor table (`index.html`): header, CSS,
  `deLoadPosDraft` (`_victim` from `SC.positions` when scene-bound, `0` when unbound — victim is a
  per-scene role, not an animation-registry template property, so there's nothing to seed from
  AnimDB), `deRenderActors` (toggle cell), `deTogglePosVictim`, `deSaveToDisk` (`_victim` included
  in the live-push payload).
- Papyrus: `WebUI_ApplyLivePositions` (`Scene.psc`) now applies `_victim` via
  `thread.SetVictim(...)` when present in the payload (gated on `JMap.hasKey`, so callers that
  don't send `_victim` can't accidentally clear it).
- New `NarrateVictimToggle(Actor victim, Bool becameVictim)`: fires a `DirectNarration` whenever a
  save actually flips a position's victim status (compares `thread.IsVictim()` before/after
  `SetVictim`, not just "payload contains `_victim`", so a same-value resave doesn't spam
  narration). Aggressor = first other position that is not itself a victim (checked fresh via
  `thread.IsVictim()`; does **not** touch the separate `initiator` field, which has its own
  lifecycle and is explicitly excluded from live-`SetVictim` recomputation elsewhere in this file
  — see `PickNonVictimInitiator`'s own doc comment). Text:
  - Toggled to victim: `"{Aggressor} starts sexually assaulting {Victim}."`
  - Toggled from victim: `"{Aggressor} switches from sexual assault to sex with {Victim}."`
  - No non-victim aggressor found (solo scene, everyone flagged victim): skipped, logged via
    `Trace`, not guessed.

**Not extended to `ApplyWebUICommit`'s own, separate victim-apply loop** (Scene Creator's
commit-to-a-live-thread path, pre-existing, distinct from the Description Editor's
`WebUI_ApplyLivePositions` path) — narration wasn't requested there.

---

## 4. Verified in-game 2026-09-24

User confirmed all of the above ("verified") after testing:
- `victim_faction_forms` save/reload mid-scene (no dead-handle log lines, faction tracking intact
  after load).
- Dressed column matches live actor nudity when scene-bound.
- Victim flag correctly reaches the live thread from Scene Creator.
- Description Editor's new V column shows/toggles live victim state correctly.
- `DirectNarration` fires with correct wording/direction on toggle.

---

## 5. Known, deferred issue (not fixed, not blocking)

`position_objs[i]["victim"]`/`"assailant"` (a *different* store from the faction proxy fixed in
§2c) — written only in `SetActor`/`UpdateActor` when an actor is first bound to a position slot —
feeds `SetNames()` → `victim_names`/`assailant_names` → `GetIntentMessage()` → scene narration text
(scene-start/end messages, **not** the new toggle narration in §3, which builds its own names
fresh each time). Has the same "only refreshed on actor-binding change" staleness: a live victim
toggle can still produce a stale victim/assailant name in *that* generated narration text. Not
reported by the user as broken; noted here so a future session doesn't have to rediscover it.

---

## 6. Working tree state at handoff

Uncommitted (`git status`):
```
 M PrismaUI/views/SkyrimNet_SexLab/index.html
 M SKSE/Plugins/SkyrimNet_SexLab.dll
 M SKSE_Source/include/JsonStore.h
 M SKSE_Source/src/JsonStore.cpp
 M SKSE_Source/src/Papyrus_Json.cpp
 M Scripts/SNSL_JArray.pex
 M Scripts/SNSL_JMap.pex
 M Scripts/SkyrimNet_SexLab_Scene.pex
 M Scripts/SkyrimNet_SexLab_Scene_Creator.pex
 M Scripts/Source/SNSL_JArray.psc
 M Scripts/Source/SNSL_JMap.psc
 M Scripts/Source/SkyrimNet_SexLab_Scene.psc
 M Scripts/Source/SkyrimNet_SexLab_Scene_Creator.psc
 M checkpoints/skse-scene/v3-checkpoint.md
?? checkpoints/skse-scene/v6-checkpoint.md
?? extern/JContainers/          (pre-existing, unrelated, never staged)
```
Baseline: `12c0ca4`. C++ compiles clean; Papyrus compiles clean (`compile: pyro`).

## 7. Next session checklist

- [ ] Commit everything in §6 together.
- [ ] Continue Stage S2 with the remaining four holders (`position_objs`, `actors_objs`,
      `thread_obj`, `user_anim_defaults`) — each needs its holder-lifecycle functions *and* every
      accessor migrated together, per §1's note. Add any further missing JsonStore natives
      properly (C++ + Papyrus binding + `.psc` declaration + rebuild + confirm DLL deploy) rather
      than working around gaps in Papyrus if the workaround would be ugly.
- [ ] Consider fixing §5's narration staleness if it's ever actually reported as a symptom (not
      speculative work now).
