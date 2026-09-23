# Checkpoint v4: `_in_thread_anims` JSON corruption — still unresolved, root-cause theory was wrong

Supersedes nothing architecturally — [v3-checkpoint.md](v3-checkpoint.md)'s design is still
believed correct. This is a narrow, urgent handoff on one blocking bug that two rounds of fixes
in this session failed to resolve, plus one important correction to a wrong deployment theory
from earlier in the session. Read this before touching Stage 0 again.

Written from `c:\Skyrim\dev\mods\SkyrimNet_SexLab`, branch `skse-scene`, baseline commit `41cd7cb`
(unchanged — still nothing committed).

---

## 1. Corrected: this is NOT a deployment problem

Earlier in this session I (wrongly) concluded the game was loading a stale, disabled release mod
instead of this dev repo, and "fixed" it by copying compiled `.pex` files into
`C:\Skyrim\dev\mods\SkyrimNet SexLab` (note the space). **That was wrong and that copy is a
no-op.** The user corrected this from `C:\Skyrim\dev\profiles\SkyrimNet SexLab\modlist.txt`:

- `+SkyrimNet_SexLab` (no space, this git repo) — **enabled**.
- `-SkyrimNet SexLab` (space) — **disabled**. Not loaded by the game at all.

Confirmed independently before the correction arrived:
- Only one **enabled** mod ships `Scripts/SkyrimNet_SexLab_Scene.pex` — this repo (checked every
  `+` line in `modlist.txt` for that file).
- MO2's `overwrite/` folder (`C:\Skyrim\dev\overwrite\`, always highest priority in the VFS merge
  regardless of profile order) has no stale copy of any of this mod's `.pex` files.
- The game session that reproduced the bug again booted at `12:41:10`
  (`SkyrimNet_SexLab.log:1`, `SkyrimNet_SexLab v0-0-1-0` / `SkyrimNet PublicAPI loaded`) — **after**
  the last relevant compile at `12:18:44`. So the freshly-compiled, actually-fixed script was
  what the game loaded.

**Conclusion: the compiled fix from this session's first round genuinely was live in-game, and
the bug still reproduced.** The fix is incomplete or wrong, not undeployed.

The "Recompiled Papyrus scripts did not reach the live game (2026-09-22)" entry already in
`KNOWLEDGEBASE.md` is **wrong** and needs to be corrected or removed — do that as part of the
next fix, not as a prerequisite (see §5). The `.pex` files manually copied into the **disabled**
`C:\Skyrim\dev\mods\SkyrimNet SexLab\Scripts\` folder this session are inert (mod is disabled)
and can be left alone or cleaned up — they have no effect either way.

## 2. The bug, restated with fresh evidence

Symptom unchanged: Description Editor's "scene:" pulldown never lists the live Bob+Nina scene.
`SkyrimNet_SexLab.log` still shows `JsonLowerCaseKeys: parse failed` with an uppercase, unquoted
`NULL` token where valid JSON should be — now reproduced **5 times in ~2 minutes** of the same
play session (much more reliable repro than the original single capture):

```
[12:47:04.279] ... last read: '"B_B_BLaySideBJ"},N'
[12:47:24.267] ... last read: '"B_B_Amazon2"},N'
[12:47:42.277] ... last read: '"B_B_BDog"},N'
[12:48:12.280] ... last read: '"Billyy Bed Missionary Over Edge"},N'
[12:48:42.295] ... last read: '"Facial, CumOnChest, CumOnBody, AirCum, InvisFurn, Bed, Boobjob, Laying, MF, Straight, sex, Billyy, FM, "},N'
```

That last one is the important new data point. `"...FM, "}` is a **complete, well-formed** `ao`
map — `_registry`, `_name`, `_tags` all present, closing on `_tags` (alphabetically last, matches
JContainers' known sorted-key iteration order). The corruption isn't in *that* entry at all —
it's the **next** array element immediately after it (`,N...`) that renders as raw `NULL`
instead of a JSON value.

## 3. What this session tried, and why it didn't work

Two guards were added this session, both compiled and confirmed live (per §1):

1. `Scripts/Source/SkyrimNet_SexLab_Scene.psc`'s new `BuildInThreadAnims` helper (replacing the
   duplicated anim-loop that was at the old `:2115`/`:2481`) hoists `anims[ai].Registry` into a
   local and **skips** the entry if that local is `""`, `Trace`-ing a skip count.
2. `Scripts/Source/SkyrimNet_SexLab_Utilities.psc`'s four JSON walkers (`JMapToJson`/
   `JArrayToJson`/`JFormMapToJson`/`JIntMapToJson`) capture each value-piece into a local and
   substitute the literal `null` if that local is `""`, with `JArrayToJson` additionally
   `Trace`-ing a substitution count.

**Neither `Trace` fired even once across all 5 fresh repros.** That means:
- `BuildInThreadAnims` never saw an empty `Registry` this time (its guard's premise — "the
  failing call is `.Registry`" — doesn't match this new evidence anyway; see the `_tags`-closing
  example above, where registry/name/tags were all clearly non-empty for that entry).
- The walker's `piece == ""` check **never matched**, yet the final string still contains raw
  `NULL`. **This means the aborted call's result is not an empty string `""`.** The original
  theory (a failed Papyrus call's String return coerces to `""`, and concatenating that is
  invisible) is contradicted by direct evidence and should be considered wrong, not just
  incomplete.

Two live possibilities, neither confirmed:
- The failing value is a literal 4-character string `"NULL"` already (not `""`, and not
  Papyrus's own `None`-to-string rendering, which would print `"None"` not `"NULL"`). This smells
  like a **JContainers native** (`JMap.getStr`/`JArray.getObj`/etc.) returning that literal
  string when handed a stale/invalid object handle, rather than a Papyrus-VM-level call failure
  at all.
- Or the corruption happens at a level neither guard instruments — e.g. inside
  `ObjectToLowerCaseKeyJson`'s native `JsonLowerCaseKeys` call itself, or in how
  `JArray.count`/`JMap.nextKey` iterate a container that's being concurrently mutated by another
  Papyrus call stack (this payload is built from a WebUI-triggered dispatch while the game may
  still be ticking scene-update events on the same thread object).

## 4. Do this first, before any more guessing

Add unconditional (not just on-failure) instrumentation immediately after computing `piece` in
`JArrayToJson` and `JMapValueToJson`/`JArrayValueToJson` (`Utilities.psc`), logging the piece's
exact length and raw content, e.g.:
```papyrus
Trace("JArrayToJson-debug", "i="+i+" len="+StringUtil.GetLength(piece)+" val=["+piece+"]")
```
Reproduce once (this bug now reproduces roughly every 20-30 seconds of active scene play per the
timestamps above — cheap to iterate on) and read the log around the next `JsonLowerCaseKeys
failed` line to see the **exact** non-empty-but-invalid value flowing through, rather than
guessing further. Once that's known:
- If it's literally `"NULL"` (4 chars): widen the guard to
  `if piece == "" || piece == "NULL"` and/or trace which specific native call in
  `JArrayValueToJson`/`JMapValueToJson` (`JMap.getStr`, `JArray.getObj` → `JValueToJsonString`,
  etc.) is the source, and fix at that call site.
- If it's something else entirely, follow the evidence rather than this document's guesses.

Remove the temporary debug `Trace` once the real shape is confirmed and the actual fix lands.

## 5. Also needed, lower priority

- Fix/remove the wrong "Recompiled Papyrus scripts did not reach the live game (2026-09-22)"
  entry in `KNOWLEDGEBASE.md` — the deployment-gap theory it documents is refuted by §1 above.
  Keep the factual MO2 layout notes (active profile, `modlist.txt` path, `overwrite/` folder
  location) if useful as reference, but the conclusion is wrong and must not mislead a future
  session into repeating that dead end.
- **Stage 0's dressed-toggle fix (`thread.ActorAlias(...).Strip()/.UnStrip()` in
  `WebUI_ApplyLivePositions`) is still completely untested in-game** — the pulldown corruption
  in §2 has blocked ever reaching the UI state needed to test it. Do not consider that part of
  Stage 0 done until the pulldown works and the dressed-toggle test from `v3-checkpoint.md`'s
  Stage 0 section actually passes end-to-end.
- Once the real fix lands: retest Stage 0 fully (pulldown populates; dressed toggle visibly
  dresses/undresses a live actor; non-playing-registry edits stay isolated; no WebUI
  click-lockout regression), then commit everything together (Stage 0's original 4 edits + all
  hardening from this session + corrected KB entries) and tick Stage 0 in
  [v3-checkpoint.md](v3-checkpoint.md) §5.

## 6. Reference — MO2 layout (for any future deployment question)

- MO2 instance root: `C:\Skyrim\dev\`
- Mods: `C:\Skyrim\dev\mods\<mod name>\` (dev repo is `SkyrimNet_SexLab`, no space)
- Active profile: `SkyrimNet SexLab`, its modlist at
  `C:\Skyrim\dev\profiles\SkyrimNet SexLab\modlist.txt` — `+` prefix = enabled, `-` = disabled.
- `C:\Skyrim\dev\overwrite\` — MO2's always-highest-priority virtual mod; checked empty of any
  relevant stale files this session.
- Game logs: paths already listed in `v3-checkpoint.md` §6, unchanged.

## 7. Working tree state at handoff

Uncommitted (same files as `v3-checkpoint.md`'s §0, plus this session's additions on top):
```
 M KNOWLEDGEBASE.md
 M PrismaUI/views/SkyrimNet_SexLab/index.html
 M Scripts/SkyrimNet_SexLab_Scene.pex
 M Scripts/SkyrimNet_SexLab_Scene_Manager.pex
 M Scripts/SkyrimNet_SexLab_Utilities.pex
 M Scripts/Source/SkyrimNet_SexLab_Scene.psc
 M Scripts/Source/SkyrimNet_SexLab_Scene_Manager.psc
 M Scripts/Source/SkyrimNet_SexLab_Utilities.psc
?? checkpoints/
```
All Papyrus changes compile clean (`compile: pyro`). Nothing has been committed. Do not commit
until the pulldown corruption is actually fixed and Stage 0 is verified end-to-end per §5.

## 8. Handoff checklist for the next session

- [ ] Read this file in full before touching anything; read `v3-checkpoint.md` for design
      context if needed, but the architecture there is unchanged.
- [ ] Add the unconditional debug `Trace` from §4 to `Utilities.psc`'s walkers, compile
      (`compile: pyro`), reproduce (should take under a minute of active scene play per the
      timestamps in §2), and read the exact value that's actually flowing through.
- [ ] Fix the guard/root cause based on that evidence, not on this document's guesses.
- [ ] Remove the debug `Trace` once confirmed fixed.
- [ ] Correct the wrong KB entry per §5.
- [ ] Retest Stage 0 end-to-end (now finally unblocked) per `v3-checkpoint.md`'s Stage 0 Test
      section.
- [ ] Commit Stage 0 + all hardening + corrected KB entries together, tick Stage 0 in
      `v3-checkpoint.md` §5, write `v5-checkpoint.md` if another handoff is needed, otherwise
      proceed to Stage 1.
