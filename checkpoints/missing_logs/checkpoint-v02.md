# Checkpoint v02: ongoing-sex block drops out at scene start; speaker-field race fixed (built, not in-game tested)

Written from `C:\Skyrim\dev\mods\SkyrimNet_SexLab`, branch `main`, baseline commit `b0c73dd5`, on top of the
uncommitted 0.36.1 work and [checkpoint-v01](checkpoint-v01.md). Not committed.

Evidence is from the 19:05 game session (Verbose logging **off**). The logs were read in place and not snapshotted:
- `C:\Skyrim\dev\overwrite\SKSE\Plugins\SkyrimNet\logs\openrouter_input.log`, lines 9242–22166.
- `%USERPROFILE%\OneDrive\Documents\my games\Skyrim Special Edition\SKSE\SkyrimNet.2026-10-19_02-05-09.log` (19:05–19:13).

That session's `SkyrimNet_SexLab.log` is gone: the 19:15 relaunch overwrote it.
Plan: `C:\Users\bhuff\.claude\plans\check-the-logs-it-iridescent-dusk.md`.

---

## 1. Goal

Unchanged from v01: the ongoing Angi + Skadi scene should appear in every participant request.

The user reported "it appears to be there". It is, but only for part of each scene.

## 2. Findings

| Scene | Block missing | Block present |
|---|---|---|
| 1 (Angi + Skadi, Bob watching) | 19:06:53, :54, :55, 19:07:00, :03, :04, :21, :22, :24 | 19:08:49, 19:08:57 |
| 2 | 19:10:09, :10, :21 | 19:11:05 → 19:13:11 (7 requests) |

- `SexLab_DenyOrgasm` (faction-gated on `currentActor`) was offered in every one of those requests.
- **Explained misses:** SkyrimNet renders 0050 from the per-actor async decorator cache and only then
  refreshes it.
  - At 19:06:53, 19:07:00, 19:10:09 and 19:10:10, the render ran before that scene's first
    `sexlab_get_threads` result. The cache held `threads:[]` and the `threads.json` fallback was empty or
    still in Setup.
  - At 19:10:21 the cache held `status:Setup` snapshots (counters 35 and 37).
- **Unexplained misses:** 19:07:03–19:07:24. Active data was already cached (counters 12–20, both actors,
  uuids `5849773615788089185` / `1649350245772434271`). Either `_thread_live` or the uuid match failed;
  the verbose lines are needed to tell which.
- **Race (now fixed):** `speaker_name` in the results didn't match the entity each call was made for. At
  19:07:01 all three results said Bob; at 19:08:51 they said Bob, Skadi, Skadi.
  - Cause: `GetThreadObj(speaker)` wrote the speaker fields into the scene's shared `thread_obj`, and
    `GetThreadsJson` dumped that root afterwards.
  - Effect: participants are unaffected (they match by uuid). Observers could get another actor's LOS and
    distance.
  - `SaveThreadsJson()` → `GetThreadsJson(None)` → `speaker_last` also overwrites those fields.

## 3. Changes (this step)

| File | Change |
|------|--------|
| `Scripts/Source/SkyrimNet_SexLab_Scene.psc` | New `ApplySpeakerFields(int obj, Actor speaker)`. It computes `speaker_name` / `speaker_distance` / `speaker_los` in locals and writes them to `obj`. "Speaker in thread" now uses `thread.positions.Find`, with the same values as before (in thread: distance 0, los 1; None: distance 1, "none"). `GetThreadObj` drops its inline version and calls it on `thread_obj`. |
| `Scripts/Source/SkyrimNet_SexLab_Scene_Manager.psc` | `GetThreadsJson` keeps the copy as `thread_copy`, then calls `sl_scene.ApplySpeakerFields(thread_copy, speaker)` before `addObj`. |
| `KNOWLEDGEBASE.md` | Top entry (still open): the 19:05 timeline, the cache-timing explanation, the unexplained window, and the race fix. |
| `CHANGELOG.md`, `CHANGELOG-developer.md`, `CHANGELOG-player.md` | One race-fix line each, under 0.36.1 "Verbose logging (untested)". |
| `Scripts/*.pex` | Pyro main: 2 succeeded, 0 failed. `make check-pex`: 30 checked, 0 bad. The P+ bridge didn't change and wasn't rebuilt. No DLL or prompt change. |

## 4. Verification (in game)

1. **Race fix:** in `SkyrimNet.log`, each 3-entity `sexlab_get_threads` batch should return
   `"speaker_name"` once each for Bob, Angi and Skadi, not repeats.
2. **Repro (Verbose ON):**
   - Turn on dashboard Verbose logging and save.
   - Run an NPC-only Angi + Skadi scene with Bob nearby. Keep it going until the block appears (~2 min), then end it.
   - **Snapshot with the `review-logs` skill before relaunching the game.**
3. In the snapshot, compare the `[SNSL DEBUG 0050]` lines between missing-block and present-block requests:
   `source`, `threads`, per-actor `animating:` (from `to_number(uuid)`) against `speaker_animating:`,
   `is_speaker`, `live`, and `result speaker_active`.

## 5. Next

- **Only stale or empty cache at scene start:** in 0050 and 0550, when the decorator data has no thread
  containing the speaker but `is_in_faction(npc.UUID, SexLabAnimatingFaction)` is true, read `threads.json`.
  Also make sure the scene-start `manager.SaveThreadsJson()` (`Scene.psc`, after `ActorChange_Started`)
  runs once the thread is active, so the file isn't in Setup.
- **`animating:false` from `to_number(uuid)` while `speaker_animating:true`:** v01 Part B. Gate
  `_thread_live` on `npc.UUID` for the speaker's own thread.
- **Then:** update `docs/authors/prompts.md` "Activity flow" step 2, close the KNOWLEDGEBASE entry, and add a changelog line.
- Keep Verbose logging.
