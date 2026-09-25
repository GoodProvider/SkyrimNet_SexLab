# Checkpoint v8: `user_anim_defaults` migrated to JsonStore — compiled clean, not yet in-game tested

Supersedes [v7-checkpoint.md](v7-checkpoint.md). v7's slice (`victim_faction_forms` + the three
Description Editor bugs + the V column feature) was committed at `5c8ccf4` and confirmed working
in-game before this session started.

Written from `c:\Skyrim\dev\mods\SkyrimNet_SexLab`, branch `skse-scene`, baseline commit `5c8ccf4`.

---

## 1. Stage S2, Pass 1 continued: `user_anim_defaults` migrated to JsonStore

Per the staged S0-S5 JContainers migration plan (`v5-checkpoint.md` §3 / `v7-checkpoint.md` §1),
picked `user_anim_defaults` as the next holder slice — smallest of the four remaining
(`position_objs`, `actors_objs`, `thread_obj`, `user_anim_defaults`), only touched by
`EnsureUserAnimDefaultsMap`, `ClearUserAnimDefaults`, `CacheUserDefaultsForRegistry`,
`SeedOverlayFromAnimDb` (`Scripts/Source/SkyrimNet_SexLab_Scene.psc` ~2905–3070).

- Widened the `< 1` creation guard to also check `SNSL_JValue.isExists()`, same fix as
  `victim_faction_forms` in v7 — SNSL handles don't survive save/load, but `Initialize()` reruns on
  every load so the widened guard is enough (no new event wiring).
- Migrated all four functions' `user_anim_defaults` reads/writes and the per-registry `payload`
  object's own reads/writes (`orgasm_expected`/`speaking_modifiers`/`clothed` arrays) to
  `SNSL_JMap`/`SNSL_JArray`. `position_objs[i]` reads inside `CacheUserDefaultsForRegistry` and
  `position_objs[i]` writes inside `SeedOverlayFromAnimDb` **stay JContainers** — that holder isn't
  migrated yet.
- Simplified `ClearUserAnimDefaults` and the "replace old entry" block in
  `CacheUserDefaultsForRegistry`: confirmed from `JsonStore.cpp` (`MapRemoveKey` → `FreeValueChild`
  at :680/:181; `MapSetObj`'s replace-path free at :613; unretained-child reparent-without-copy in
  `AttachChild` at :276) that an unretained child payload is freed automatically on `removeKey` and
  on `setObj` overwrite — the old JContainers-style `getObj`-then-`release` dance and the
  `JValue.retain(payload)` call are unnecessary with this store and were deleted, not just renamed.
- No new JsonStore natives needed — every call used already exists in `SNSL_JMap.psc`/
  `SNSL_JArray.psc`/`SNSL_JValue.psc`.

**Behavior change accepted by user:** per-registry orgasm/speaking/clothed overrides cached in
`user_anim_defaults` now reset to AnimDB defaults after a save/load (SNSL has no co-save
integration), same as the `victim_faction_forms` tradeoff in v7. Not persisted to a file — out of
scope for this slice.

Compiled clean via `compile: pyro`. Only `Scripts/Source/SkyrimNet_SexLab_Scene.psc` and its
`.pex` changed (confirmed via `git diff --stat`) — no other files touched.

---

## 2. NOT yet done this session

- **Not tested in-game.** Unlike v7, none of this has been verified against a running game yet.
  Before committing/moving on, confirm:
  - Start a scene, change orgasm/speaking/clothed in WebUI, switch animation away and back →
    overrides reapplied (cache hit path in `SeedOverlayFromAnimDb`).
  - Reset/clear path (call sites at old line ~2401/~3192 pre-edit — re-check current line numbers)
    → defaults return to AnimDB values.
  - Save, reload mid-scene → no dead-handle warnings in logs; overlay falls back to AnimDB
    defaults; editing again re-caches correctly.
- **Not committed.** Working tree has the two files above modified; nothing staged.

---

## 3. Remaining S2 scope (unchanged from v7 §1)

`position_objs`, `actors_objs`, `thread_obj` and their ~25+ reader/writer functions — each needs
its own full-slice treatment (holder + every accessor migrated together). Expect more missing
JsonStore natives to surface, e.g. `SNSL_JFormMap` has no scalar accessors beyond `getObj`/`setObj`
today (noted in v7, still true).

---

## 4. Known, deferred issue (unchanged from v7 §5)

`position_objs[i]["victim"]`/`"assailant"` staleness — see `v7-checkpoint.md` §5. Not touched this
session.

---

## 5. Next session checklist

- [ ] In-game test §2's three scenarios; get user confirmation before considering this slice done.
- [ ] Commit this slice (`SkyrimNet_SexLab_Scene.psc`/`.pex`) once verified.
- [ ] Continue Stage S2 with `position_objs`, `actors_objs`, or `thread_obj` next.
