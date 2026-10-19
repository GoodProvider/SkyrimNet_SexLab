# Checkpoint v03: race fix verified; scene-start gap fixed by listing Advancing threads (built, not in-game tested)

Written from `C:\Skyrim\dev\mods\SkyrimNet_SexLab`, branch `main`, baseline commit `b0c73dd5`, on top of the
uncommitted 0.36.1 work and [checkpoint-v02](checkpoint-v02.md). Not committed.

Evidence is from the 19:32 game session (Verbose logging **on**, scene 19:33–19:35), snapshotted to
`review-logs/2026-10-18_193636/` (`SkyrimNet.log`, `SkyrimNet_SexLab.log`, `openrouter_input.log`).
Plan: `C:\Users\bhuff\.claude\plans\pasted-content-id-b0a3-the-starry-comet.md`.

---

## 1. Goal

Unchanged from v01/v02: the ongoing Angi + Skadi scene should appear in every participant request.

## 2. Findings

- **Race fix verified.** Each `sexlab_get_threads` batch returned Angi, Skadi and Bob once each at
  19:34:51–52, 19:35:19–20 and 19:35:28 (`SkyrimNet.log:8490`, `:11714`, `:12930`).
- **Block missing: 3 of 9 participant renders**, all at scene start (19:33:02.7, 03.7, 04.7; `SkyrimNet.log:4713`):
  1. SkyrimNet reported a decorator cache miss ("warmup may not have completed"), so 0050/0550 fell back to `threads.json`.
  2. `threads.json` had no threads. The `AnimationStart` save (19:33:02.670) wrote no per-slot `[V]` line
     (`SkyrimNet_SexLab.log:228`).
  3. **Code-confirmed cause:** `GetThreadsJson` used `GetSceneByThread(t, False, False)`, which returns None
     unless SexLab's state is `animating` / `prepare` (`Scene_Manager.psc:246-251`). The thread was in
     `Advancing` (`SkyrimNet_SexLab.log:237`, 19:33:03.506). The early return happens before `DebugTraceThread`,
     so the skip was silent.
  4. The `StageStart` save (thread animating) finished writing at 19:33:04.8, just after the third render read the file.
     The first decorator results arrived at 19:33:04.8 too.
- **Block present: the other 6 renders** (19:34:50–19:35:36). All had `source:sexlab_get_threads`, `to_number(uuid) == uuid`,
  `animating:true` for both actors and `live:true`. v02's unexplained window (19:07:03–24, cached data but no
  render) didn't recur, and there was no sign of a `_thread_live` or uuid-match bug. v02 §5's "gate `_thread_live` on `npc.UUID`"
  isn't needed on this evidence.
- **Same filter mid-scene:** `GetThreadActive` drops the thread during each stage change (`Advancing` at
  19:34:52.127, `SkyrimNet_SexLab.log:427`). It didn't cause a miss here.
- **Open (not blocking):** Skadi's renders still showed `status:Setup` at 19:35:36 while Angi's showed active.
  Nothing gates on `status`, so the block still rendered. Skadi's decorator cache entry may be stale.

## 3. Changes (this step)

| File | Change |
|------|--------|
| `Scripts/Source/SkyrimNet_SexLab_Scene_Manager.psc` | `GetThreadsJson`: lookup is `GetSceneByThread(threads[i], True, False)` (any state, still read-only). It is gated on `sl_scene.GetThreadInScene()` (animating / prepare / advancing / refresh, with positions; the existing listing check) instead of `GetThreadActive()`. The local is renamed `thread_listed`. `DebugTraceThread` adds `state:<SexLab state>` and now also logs skipped bound slots (`kept:FALSE`). |
| `Scripts/Source/SkyrimNet_SexLab_Scene.psc` | `GetThreadObj`: the `CheckAnimationChange()` poll runs only when the state is `animating` / `prepare`, the only states that reached it before. A dump mid-`Advancing` can't trigger an animation-change restart. This matches `PollAnimationChange`. |
| `KNOWLEDGEBASE.md` | Top entry marked fixed (not verified in game): the cause, the fix, and the parked items. |
| `docs/authors/prompts.md` | "Activity flow" step 1: when the fallback is used, and which SexLab states are listed. |
| `CHANGELOG.md`, `CHANGELOG-developer.md`, `CHANGELOG-player.md` | One line each under 0.36.1 "Verbose logging (untested)". |
| `Scripts/*.pex` | Pyro main: 2 succeeded, 0 failed. `make check-pex`: 30 checked, 0 bad. P+ bridge, DLL and prompts unchanged. |

**No prompt change:** 0050 / 0550 already re-read `threads.json` whenever the decorator returns no threads
(`0050:10-13`, `0550:4-7`). **No extra save:** `StageStart` already rewrites the file once animating. The
earlier `AnimationStart` save now includes the thread.

`thread.active` (`GetThreadActive`) is still 0 while Advancing. No prompt reads it.

## 4. Verification (in game, Verbose ON)

1. Run an NPC-only Angi + Skadi scene with Bob nearby. Talk to them within the first ~3 seconds.
2. In `SkyrimNet_SexLab.log`, the `AnimationStart` save is followed by a `[V] … GetThreadsJson … kept:TRUE state:Advancing`
   line, not a lone `dom threads:0 kept:0`.
3. In `openrouter_input.log`, scene-start renders with `[SNSL DEBUG 0050] … source:file` show `threads:1` and
   `live:true`, and the block (`- On the floor, …` plus Speaking Rules) is present in every participant request.
4. No regression: no extra `RestartStageOnAnimationChange` or animation-change narration at scene start or on
   stage changes. Compare the `SyncAnimationDefaults` traces with the 19:33 session.
5. **Snapshot with the `review-logs` skill before relaunching the game.**

## 5. Next

- If §4 passes, close the KNOWLEDGEBASE entry. Consider removing the `[SNSL DEBUG]` prompt lines, or keep them
  behind Verbose as they are now.
- Skadi's `status:Setup` late in the scene: compare per-entity `counter` values in `Get_Threads` results to see
  whether Skadi's decorator cache entry is stale.
- Keep Verbose logging on until both are settled.
