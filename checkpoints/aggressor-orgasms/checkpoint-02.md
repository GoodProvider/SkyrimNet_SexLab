# Checkpoint 02: first in-game test of the victim hold (works; one stage-sync race)

Written from `C:\Skyrim\dev\mods\SkyrimNet_SexLab`, branch `main`, baseline commit `b0c73dd5`, on top of the
uncommitted 0.36.1 work and [checkpoint-01.md](checkpoint-01.md) (code unchanged since then, not committed).

Logs: [logs/2026-10-18-10-47-20/](logs/2026-10-18-10-47-20/). The folder is named after the crash log, but the
SexLab / SkyrimNet / Papyrus logs are from the 21:51–21:56 session, which ran after the 21:39 build (see
`MANIFEST.txt`). The crash log (10:47) is from an earlier session and is not related. `Papyrus.0.log` has no
victim-hold lines; Scene traces go to `SkyrimNet_SexLab.log`.

---

## 1. Goal

Check that the code from checkpoint 01 works in game: an aggressor's orgasm ends the second-to-last stage hold in
victim scenes.

## 2. Results

All line numbers are in [SkyrimNet_SexLab.log](logs/2026-10-18-10-47-20/SkyrimNet_SexLab.log).

### Scene 0: NPC only, AI gate (Skadi `0xfe04b83c` aggressor, Angi `0xcab2e` victim): works

| Time | Line | Event |
|------|------|-------|
| 21:52:38 | 420 | Skadi orgasms in stage 2, reaches target 1/1: "not second-to-last: no jump", so the scene goes on. |
| 21:53:17 | 544 | `Victim_Hold holding stage:4/5 … gate:TRUE`. |
| 21:53:17–21:54:23 | 536–658 | Skadi climbs from 44 to 100 over about 66 s, past the stage timer, with no 98 cap. |
| 21:54:23.8 | 659 | Angi calms Skadi at 100 (`(edge)`): the edge blocks `CanOrgasmNow`, so the gate waits. This is expected, not a bug. |
| 21:54:27.8 | 666–668 | `victim hold: aggressor … at 100, gate`; Angi skipped (`expected=false`); Skadi `pass=true aggressor=true`. |
| 21:54:28.9 | 677 | `victim hold handed to the gate hold`. |
| 21:54:29.5–29.8 | 682–688 | Gate voice started → `Ending_ToFinal GoToStage 4 -> 5`. |
| 21:54:33 | 747 | Gate orgasm fires in stage 5 (`source=gate`, count 2); `Ending_Hold` holds the final stage. |

### Scene 1: player scene (Bob `0x14` = player, victim; Skadi aggressor; no gate): works, with a race

| Time | Line | Event |
|------|------|-------|
| 21:56:17.567 | 1153 | SexLab `StageStart stage:4/5`. Skadi is at 94.5. |
| 21:56:18.836 | 1162–1163 | Skadi orgasms (`source=engine`). The engine still has `sc.stage` 3, so it ran a normal group roll for Bob (7.1, fail) and no final roll. |
| 21:56:19.200 | 1167 | Engine `SetStage 4/5` (about 1.6 s after SexLab's StageStart), stage spike +5 applied to Skadi after her reset. |
| 21:56:19.267 | 1168 | `Victim_Hold holding stage:4/5 … gate:False`. |
| 21:56:19.667–19.767 | 1174–1178 | `ending jump: stash folds`; `Ending_Check victim hold: aggressor orgasmed at stage 4/5`; `GoToStage 4 -> 5`. |
| 21:56:20.7–21.4 | 1184–1187 | One DN: the stage-5 change plus "Skadi is orgasming." |

## 3. Finding: the engine learns the stage about 1.6 s after SexLab starts it

- **Cause:** `Scene.StageStart` does a lot of work (NECRO-DBG snapshot, `Engine_BeginScene`, skills, voices)
  before `Engine_SetStage` reaches `OrgasmEngine::SetStage`. In scene 1 that was 17.567 → 19.200.
- **Effect:** an aggressor orgasm in that window counts as the second-to-last stage on the Papyrus side
  (`thread.Stage` 4, so the jump works) but as the stage before on the engine side.
  - `JoinGroup`'s early final roll is skipped (`sc.stage != sc.stageCount - 1`), so the others get only the
    normal group roll. They can miss their chance to finish with the aggressor.
  - In this log the outcome was the same: Bob was at 7 and not expected to orgasm.
  - The stage spike lands on the aggressor after the orgasm reset.
- **Proposed fix (preferred):** a native the Scene calls from `Ending_Check` when it jumps for the victim hold.
  Example: `OrgasmEngine.VictimHoldFinalRoll(sid, aggressor)`, which runs the final roll for everyone still out,
  into a new group. Each passer would then need its own DN or a fold into the stage-5 DN.
- **Alternative:** move `Engine_SetStage` to the top of `StageStart`. This touches more code and timing.

## 4. Not yet tested

- The early "aggressor ends" rule's removal in a **non-gate** scene: scene 1 had no aggressor orgasm before
  stage 4, and scene 0 is a gate scene, where the old rule didn't apply either.
- The cap (`victim_hold_max`): neither hold reached 120 s.
- A partner expected to orgasm, to see the final roll or gate roll actually fire for someone else.
- Pause / resume, manual Next, an animation change mid-hold, stepping back, SexLab P+, a consensual scene,
  Together mode.

## 5. Next

1. Decide on the race fix (section 3) and implement it.
2. Test what section 4 lists, focusing on a scene with a victim who is expected to orgasm.
3. Then commit with the rest of 0.36.1.
