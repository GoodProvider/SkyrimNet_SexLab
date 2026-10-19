# Checkpoint v04: block present in every v03 render; Advancing path not yet exercised; decorator empty during refresh

Written from `C:\Skyrim\dev\mods\SkyrimNet_SexLab`, branch `main`, baseline commit `b0c73dd5`, on top of the
uncommitted 0.36.1 work and [checkpoint-v03](checkpoint-v03.md). Not committed. No code changes in this step.

Snapshot: `review-logs/2026-10-18_212351/`. Line numbers below refer to these copies. The rotated
`SkyrimNet.2026-10-19_04-02-36.log` (21:02–21:06 session) was added to the snapshot by hand; see `MANIFEST.txt`.

---

## 1. Goal

Unchanged from v01–v03: the ongoing Angi + Skadi scene should appear in every participant request.

## 2. Sessions in these logs

| Session | Pex | Scene | Counts as a v03 test? |
|---------|-----|-------|------------------------|
| 21:02–21:06 | **Old.** `Scene_Manager.pex` was built at 21:09:41 and `Scene.pex` at 21:10:21 | ~21:04:16–21:05:59 | No. Only `SkyrimNet.2026-10-19_04-02-36.log` and `openrouter_input.log` survive for it; `SkyrimNet_SexLab.log` was overwritten |
| 21:15–21:19 | v03 | 21:18:05 (AnimationStart) to 21:19:20 (AnimationEnd), Angi + Skadi, Bob nearby | **Yes** |

## 3. Findings (21:18 session, v03)

- **The block was present in every participant render.** All four 21:18 renders were Angi's
  (`openrouter_input.log:12015`, `:12514`, `:13035`, `:13582`):

  | Time | Source | Threads | Live | Block |
  |------|--------|---------|------|-------|
  | 21:18:13.871 | `file` | 1 | `true` | Present (Speaking Rules plus 0550 thread line) |
  | 21:18:52.223 | `file` | 1 | `true` | Present |
  | 21:18:54.793 | `file` | 1 | `true` | Present |
  | 21:19:20.957 | `sexlab_get_threads` | 1 | `false` | Correctly absent (after AnimationEnd at 21:19:20.3) |

  The 21:18:13.871 render followed SkyrimNet's `sexlab_get_threads` cache miss for Angi (`512E921C31805F61`,
  `SkyrimNet.log:4252`). That is the v02/v03 failure case, and it is now covered by `threads.json`.
- **Every `GetThreadsJson` call during the scene listed the thread.** The 12 `--- dom threads:0 kept:0` summaries
  from 21:18:07 to 21:19:15 each pair with a `[V] … kept:TRUE` slot line (`SkyrimNet_SexLab.log:228`–`:586`).
  After AnimationEnd the slot line says `kept:False state:Frozen` (`:602`), as expected.
- **The Advancing path wasn't exercised.** The AnimationStart save ran in `state:Prepare`
  (`SkyrimNet_SexLab.log:228`, 21:18:07.708). The old `GetSceneByThread(t, False, False)` accepted Prepare too.
  `Advancing` appears only between saves (`:231`, `:235`, `:241`). So this run proves the outcome but not the v03
  change itself. Compared with 19:33 it got lucky on timing.
- **New finding: the decorator returns no threads while an async refresh for that entity is in flight.**
  The 21:18:52.2 and 21:18:54.8 renders fell back to the file with no cache-miss warning. SkyrimNet had scheduled a
  refresh at 21:18:51.944 (`SkyrimNet.log:5501`–`:5509`) and logged "Async operation already in progress" for Angi
  (`:5592`). The results landed at 21:18:53.861–54.294 (`:6191`–`:6292`), even though the cache had held thread data
  since 21:18:16 (`:5214`–`:5225`).
  - The old-pex 21:04 session shows the same pattern. Renders at 21:04:22.4, :23.2, :25.1 and :52.8
    (`openrouter_input.log:6428`, `:6920`, `:7418`, `:7892`) came while results were still landing
    (`SkyrimNet.2026-10-19_04-02-36.log:6705`–`:7860`, `:9740`). There the file was also empty
    (`threads:0`), so the block was dropped for about 36 s.
  - This is SkyrimNet DLL behaviour and outside this repo. It means the `threads.json` fallback carries the
    block for part of the scene, not only at scene start, so the file must stay current.
- **No regression.** A single `SyncAnimationDefaults … first:TRUE` (`SkyrimNet_SexLab.log:229`). No
  `RestartStageOnAnimationChange` and no animation-change narration. The newest crash log is
  `crash-2026-10-18-10-47-20.log`, which predates both sessions.
- **Still open:** Skadi never spoke in the 21:18 session, so Skadi's stale `status:Setup` can't be checked. The
  file copies show `status:Setup` for Angi too, while the decorator shows `active` (`openrouter_input.log:13582` area).
  The `status` in `threads.json` lags. Nothing gates on it.

## 4. Changes (this step)

| File | Change |
|------|--------|
| `checkpoints/missing_logs/checkpoint-v04.md` | This file. |
| `KNOWLEDGEBASE.md` | Top entry: what the 21:18 session verified, what is still unproven, and the in-flight-refresh quirk. |
| `review-logs/2026-10-18_212351/` | Snapshot, plus the rotated 21:04 SkyrimNet log. |

No script, prompt, DLL or pex changes.

## 5. Verification (next run, Verbose ON)

1. Start an NPC-only Angi + Skadi scene several times until an AnimationStart save logs
   `[V] … kept:TRUE state:Advancing`. That proves the v03 change itself.
2. In each such run, the scene-start renders with `source:file` show `threads:1 live:true` and the block is present.
3. Get Skadi to speak mid-scene. Compare the `status` of Skadi's renders with Angi's, and the decorator `counter`
   values in `Get_Threads` results.
4. **Snapshot with the `review-logs` skill before relaunching the game.**

## 6. Next

- If §5.1 passes, mark the KNOWLEDGEBASE entry verified and close it.
- The in-flight-refresh gap means fallback freshness matters. If renders mid-stage ever show a stale or empty file,
  consider writing `threads.json` on more events (for example on orgasm, or per stage-change event that currently
  skips the save).
- Decide whether `threads.json` should carry the live `status`.
- Keep Verbose on until both are settled.
