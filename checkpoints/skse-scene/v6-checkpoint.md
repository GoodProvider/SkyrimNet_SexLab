# Checkpoint v6: JContainers replacement + DLL deploy fix committed (`12c0ca4`) — still needs in-game verification

Supersedes [v5-checkpoint.md](v5-checkpoint.md), which shipped S0+S1 but had the DLL silently
deploying to a disabled mod folder so none of it actually reached the game. That deploy bug is now
found, fixed, and committed. **Nothing in this checkpoint has been confirmed working in-game yet —
that is the entire remaining task.**

Written from `c:\Skyrim\dev\mods\SkyrimNet_SexLab`, branch `skse-scene`, HEAD `12c0ca4`
("Replace JContainers with a C++ JSON store; fix DLL deploy target").

---

## 1. What happened between v5 and v6

v5 reported the JSON store as code-complete, compiled, and deployed — with a verification list
for the next in-game session. That next session (same day) booted the game and the pulldown was
**still empty**. Root cause was not the JSON store logic; it was that the store never loaded:

- `SkyrimNet_SexLab.log`'s boot block registered only four Papyrus modules
  (WebUI/Utilities/API/AnimationDB) — no `Json Papyrus functions registered` line.
- `SKSE_Source/CMakeLists.txt`'s `MOD_FOLDER_NAME` was `"SkyrimNet SexLab"` **(with a space)** —
  the MO2 profile's `-SkyrimNet SexLab` entry, i.e. **disabled**. The enabled mod is
  `+SkyrimNet_SexLab` (no space) — this repo.
- This repo ships its own **git-tracked** `SKSE/Plugins/SkyrimNet_SexLab.dll`, which was three
  days stale (built before the JSON store existed) and is what actually loaded.
- Binary grep confirmed it: the fresh build artifact contained `SNSL_JMap` and
  `JsonStore self-test`; the checked-in `SKSE/Plugins/SkyrimNet_SexLab.dll` contained neither.
- The symptom this produced was distinctive and is worth remembering: the `BuildWebUISceneMenuState`
  trace showed `stage:0/0` (a native-default value) and the build finished in 83ms instead of the
  old ~9s — proof the *new, fast* Papyrus code was running, just against a DLL that never
  registered the natives it was calling. No `JsonLowerCaseKeys: parse failed` at all, because the
  slow walker wasn't even on the path anymore.

This is the mirror image of the mistake in `v4-checkpoint.md` §1 (which wrongly blamed the
*Papyrus* `.pex` deploy). `.pex` files compile **into** this repo (enabled → always live). The DLL
was building **out** to a different, disabled folder. Both directions matter and must be checked
independently when something "doesn't take effect."

**Fix:** `SKSE_Source/CMakeLists.txt`'s `MOD_FOLDER_NAME` is now `"SkyrimNet_SexLab"` (no space).
Rebuilt; confirmed `SKSE/Plugins/SkyrimNet_SexLab.dll` has a fresh timestamp and binary-greps for
`SNSL_JMap` / `JsonStore self-test`. Corrected the stale deploy notes in `KNOWLEDGEBASE.md` (new
entry: "The .pex and the .dll deploy in opposite directions"), `v3-checkpoint.md` §6, and
`v5-checkpoint.md` §4.

## 2. Everything from v5 still applies

The JSON store design, the S1 migration (`BuildInThreadAnims`, `BuildWebUISceneMenuObject`,
`BuildAllSceneInfosJson`), the `retainCount` fix for `last_ended_obj`, and the staged S2-S5 plan
are all unchanged — see `v5-checkpoint.md` §2-§3 for the full design writeup. Only the deployment
mechanism was broken; the code itself was never re-reviewed or changed in this pass beyond the one
`CMakeLists.txt` line.

## 3. Committed this session

`git log -1`:
```
12c0ca4 Replace JContainers with a C++ JSON store; fix DLL deploy target
```
Contains: the full S0+S1 JSON store work from v5 (`JsonStore.{h,cpp}`, `Papyrus_Json.{h,cpp}`,
`SNSL_J*.psc` + compiled `.pex`, the `Scene.psc`/`Scene_Manager.psc` migration, corrected KB
entries) **plus** the `CMakeLists.txt` deploy fix and its own KB/checkpoint corrections, all as one
commit. This was committed directly by the user, not by an agent — normally this repo's standing
rule is not to commit until in-game verification passes; that rule was intentionally not followed
here, so **the burden is now on actually verifying in-game before doing anything else**, not on
whether to commit.

Working tree at this checkpoint: clean except `extern/JContainers/` (a separate, pre-existing
nested git checkout, unrelated to this work, never staged).

## 4. Verification — CONFIRMED IN-GAME 2026-09-23 (high-level outcome; granular log checks not captured)

The user booted the game and confirmed: **the Description Editor's dressed toggle live-applies
clothing to a live scene actor.** That outcome implies the pulldown populated (Stage 0's toggle
can't be exercised without picking a live scene first) and that the JSON store's scene-menu build
path is working end-to-end — the actual bug this whole investigation (v4→v6) was chasing is fixed.
`v3-checkpoint.md` §5 has been ticked for Stage 0 accordingly.

**Not individually confirmed** (no log excerpts were captured/reviewed this round) — worth a quick
pass next time the game is booted, mainly as due diligence rather than because anything is in
doubt:
1. `SkyrimNet_SexLab.log` boot block: five `... Papyrus functions registered` lines including
   `Json`, and `JsonStore self-test passed`.
2. `BuildWebUISceneMenuState` trace shows a real `stage:N/M` (M ≥ 1), not `0/0`.
3. `JContainers64.log` has no new `access to non-existing object` warnings.
4. Save/reload mid-scene, reopen the editor — no dead-handle errors (exercises the session-tag
   invalidation in `JsonStore.cpp`).

None of these block anything — they're the kind of thing worth glancing at only if something looks
off later, not a gate before proceeding.

## 5. Next session checklist

- [x] Boot the game and confirm the pulldown/Stage 0 works — **done 2026-09-23**, dressed toggle
      confirmed live-applying clothing. Stage 0 ticked in `v3-checkpoint.md` §5.
- [ ] Proceed to **S2** (rest of `Scene.psc`, ~359 remaining JContainers call sites, plus its four
      holder members — `position_objs`/`actors_objs`/`victim_faction_forms`/`user_anim_defaults`)
      per the staged design in `v5-checkpoint.md` §3, dropping the S1 bridges once done.
- [ ] If something in `JsonStore.cpp` genuinely misbehaves during S2: every failure path logs a
      specific `webui_log::error` reason (dead handle with slot/gen/session, reparent-copy count,
      dump failure) — start from those log lines, not from re-deriving the design from scratch.
- [ ] If a future C++ change "doesn't seem to take effect" again: check DLL deployment first
      (registration-line count in the boot log, binary grep of the loaded DLL for a new symbol)
      before assuming the logic is wrong — this exact failure mode is now twice confirmed as the
      most likely culprit in this repo.
