# Checkpoint v01: ongoing-sex block missing from an NPC-only scene; Verbose logging added (built, not in-game tested)

Written from `C:\Skyrim\dev\mods\SkyrimNet_SexLab`, branch `main`, baseline commit `b0c73dd5`, on top of the
uncommitted 0.36.1 work. Not committed. Evidence is the live logs from the 18:45 game session; they were read in place and not snapshotted:
`C:\Skyrim\dev\overwrite\SKSE\Plugins\SkyrimNet\logs\openrouter_input.log`, and `SkyrimNet.log` /
`SkyrimNet_SexLab.log` under `%USERPROFILE%\OneDrive\Documents\my games\Skyrim Special Edition\SKSE\`.
Plan: `C:\Users\bhuff\.claude\plans\in-openrouter-input-log-there-should-memoized-puddle.md`.

---

## 1. Goal

`openrouter_input.log:8847` (Skadi's request at 18:47:31.826) should have described the ongoing Angi + Skadi
scene (`- On the floor, Angi rides Skadi's cock…`, Speaking Rules, enjoyment, strategy). Instead the final
user message starts at `**COMBAT STRENGTH ASSESSMENT:**`. Find out why and fix it. On the way, add a
dashboard **Verbose logging** option (user request) so template state can be seen.

## 2. Findings

- **Every request in the scene is missing it**, not just one: the GenerateStreaming requests at 18:47:27.3, 28.4, 30.9 and 31.8.
  `0050_sexlab_activity` printed nothing at all, not even the `- On …` line.
- **The data was there.** SkyrimNet logged "Got result back from Papyrus" for `sexlab_get_threads` with the
  Angi + Skadi thread at 25.390, 26.106 and 28.823. `threads.json` (counter 14) has it. No `cache miss` for Skadi
  (`16E3AB4F55781B5F`) after 23.800.
- **Skadi was in `SexLabAnimatingFaction`.** The same prompt offered `SexLab_DenyOrgasm`, `SexLab_Arouse` and
  `SexLab_Calm`, whose YAML eligibility is `is_in_faction(currentActor, SexLabAnimatingFaction)`.
- **No template errors** in `SkyrimNet.log`. 0050 is listed as rendered.
- **Not a template change.** The `_thread_live` gate dates from 0.34.1. It rendered for Angi + Bob at 17:20
  (`openrouter_input.log:185`), and for an NPC-only Angi + Skadi scene at 12:33
  (`openrouter_input.2026-10-18_04-41-05.log`, "Angi stands with Skadi fingering Skadi", 4×). No overrides
  of 0050 in `overwrite\…\prompts` or in other mods.
- **What changed:** Scripts were rebuilt at 18:41 from the uncommitted tree (TNG futa: Skadi is now
  `is_hermaphrodiate:1`). The thread JSON shape and the uuid string format are unchanged from the 10-08 snapshots.
  SkyrimNet.dll is unchanged (10-15).
- **Conclusion so far:** with that data, the only empty path through 0050 is `_thread_live == false`,
  i.e. `is_in_faction(to_number(actor_record.uuid), …)` false for both actors. The cause is not known.
  `to_number` on a 19-digit uuid may lose precision as a double (Skadi `0x16E3AB4F55781B5F` → `…1B00`), but
  that would not explain the 12:33 success. No `GetActorByUUID` warnings for those values either.
- **Side finding:** SkyrimNet serves Papyrus decorators from an async per-actor cache. The 18:47:30.691 batch
  only returned at 32.457–32.641, after the 30.9 and 31.8 renders. Stale data is possible but isn't this bug.

## 3. Changes

| File | Change |
|------|--------|
| `SKSE/Plugins/SkyrimNet/config/plugins/SkyrimNet_SexLab/manifest.yaml` | New field **Verbose logging**, `sexlab.debug.verbose`, bool, default false, category `Debug`. |
| `SKSE_Source/include/Config.h`, `SKSE_Source/src/Config.cpp` | `IsVerbose()` (read live). `Config::ApplyLogLevel()`: spdlog debug/info plus `flush_on`; called from `ApplyFromConfig` and `ApplyHudConfig` (dashboard save path). New C++ decorator `sexlab_verbose` (`"1"`/`"0"`) next to `sexlab_npc_stop_allowed`. |
| `SKSE_Source/src/Papyrus_WebUI.cpp`, `Scripts/Source/SkyrimNet_SexLab_WebUI.psc` | Natives `IsVerbose()` and `DebugLog(script, func, msg)`. `DebugLog` writes `[V] [script.func] msg` at info level, and only when verbose. |
| `Scripts/Source/SkyrimNet_SexLab_Utilities.psc` | `DebugTrace(func, msg)` → `DebugLog`. |
| `Scripts/Source/SkyrimNet_SexLab_Scene_Manager.psc` | `GetThreadsJson`: when verbose, `DebugTraceThread` logs one `[V]` line per SexLab thread with speaker, slot, tid, kept, and each actor's name / formid / uuid / `IsInFaction(SexLab.esm 0xE50F)` / rank. |
| `Scripts/Source/SkyrimNet_SexLab_Decorators.psc` | `Get_Threads`: full JSON only when verbose (`[V]`). Otherwise a one-line `speaker / chars` trace. |
| `…/user_final_instructions/0050_sexlab_activity.prompt` | `_verbose = sexlab_verbose(npc.UUID) == "1"`. `[SNSL DEBUG 0050]` lines: npc / paused / source / thread count / `is_in_faction(npc.UUID)`. Per actor: uuid, `to_number(uuid)`, is_speaker, animating. Per thread: description / status / live / los / distance. Result line: `speaker.active` / `notice_level`. |
| `…/user_final_instructions/0550_sexlab_narration.prompt` | `[SNSL DEBUG 0550]` per thread: source, live, the speaker's AnimatingFaction rank. |
| `docs/authors/prompts.md`, `docs/authors/actions.md`, `docs/players/overview.md` | Verbose logging and the `sexlab_verbose` decorator; a new "Reporting a bug" section for players. |
| `CHANGELOG.md`, `CHANGELOG-developer.md`, `CHANGELOG-player.md` | 0.36.1 "Verbose logging (untested)". |
| `KNOWLEDGEBASE.md` | Top entry (open): findings, plus the DLL ↔ prompt dependency. |
| `Scripts/*.pex`, `SKSE/Plugins/SkyrimNet_SexLab.dll` | Pyro main: 4 succeeded. P+ bridge: 1 succeeded. `make check-pex`: 30 checked, 0 bad. Release DLL built (only the existing C4100 warning) and copied. |

**Dependency:** 0050 and 0550 call `sexlab_verbose`. A DLL without it will likely make those sections fail
to render, so ship the DLL and prompts together.

## 4. Verification (in game)

1. **Verbose off:** no `[V]` lines in `SkyrimNet_SexLab.log`, and `Get_Threads` logs `speaker:… chars:N`.
   No `[SNSL DEBUG` in `openrouter_input.log`.
2. **Verbose on** (dashboard, then save; the log level applies on save and on load):
   - `ApplyLogLevel: verbose=true level=debug`
   - `[V] [SkyrimNet_SexLab_Scene_Manager.GetThreadsJson] speaker:… | Angi formid:… uuid:… animating:…`
   - `[SNSL DEBUG 0050]` / `[SNSL DEBUG 0550]` lines in each scene-participant request.
3. **Repro:** an NPC-only Angi + Skadi scene, plus an Angi + Bob control. Compare `animating:` per actor in
   `[SNSL DEBUG 0050]` (from `to_number(uuid)`) with `speaker_animating:` (from `npc.UUID`) and the `[V]`
   line (live Papyrus faction).

## 5. Next (Part B)

- If `to_number(uuid)` → `is_in_faction` is false while `npc.UUID` is true: in 0050 and 0550, find the speaker
  in the thread first (the existing `to_number(uuid) == npc.UUID` match), then set `_thread_live` from
  `is_in_faction(npc.UUID, SexLab | OStim | DOM faction)`. Observers keep the per-actor check, or whatever form
  the debug lines show works.
- If the debug lines show something else (no threads, a paused file fallback, a stale cache), fix that path instead.
- Then: update `docs/authors/prompts.md` "Activity flow" step 2, close the KNOWLEDGEBASE entry, and add a changelog line.
- Once the bug is fixed, keep the Verbose logging feature.
