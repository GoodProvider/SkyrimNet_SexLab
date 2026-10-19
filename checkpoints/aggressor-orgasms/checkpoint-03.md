# Checkpoint 03: Skadi × Bob player scene: the victim-hold jump is lost (SLSO advanced first)

Written from `C:\Skyrim\dev\mods\SkyrimNet_SexLab`, branch `main`, baseline commit `b0c73dd5`, on top of the
uncommitted 0.36.1 work and [checkpoint-01.md](checkpoint-01.md) / [checkpoint-02.md](checkpoint-02.md). The code
has not changed since checkpoint 01 and is not committed.

Logs: [logs/2026-10-18-22-16-11/](logs/2026-10-18-22-16-11/), from the 22:13–22:16 session (see `MANIFEST.txt`).
There is no new crash log. Unlike checkpoint 02, `Papyrus.0.log` matters here: its SexLab `Event Hook` lines show
when SexLab really changes stage. **SLSO.esp is active** in this profile (`Lover-s-Ledger` has `*SLSO.esp`).

---

## 1. Goal

Check the victim hold in a player-victim scene: Skadi `0xfe04b83c` (aggressor, futa, ending target 1) and
Bob `0x14` (player, victim, male), `B_B_Amazon`, 5 stages, no gate.

## 2. Results

`SL` = [SkyrimNet_SexLab.log](logs/2026-10-18-22-16-11/SkyrimNet_SexLab.log), `PAP` =
[Papyrus.0.log](logs/2026-10-18-22-16-11/Papyrus.0.log) (1 s resolution).

| Time | Line | Event |
|------|------|-------|
| 22:14:39.7 | SL 220–221 | `Ending_RollTarget` Skadi target 1. |
| 22:14:40.7 / 22:15:02.8 | SL 226 / 385 | Stages 1 and 2 run their normal timers (~22 s and ~21 s). |
| 22:15:23.651 | SL 569, PAP 1209 | `StageStart 3/5`. Engine `SetStage 3/5` only at 25.551 (SL 589): the ~1.9 s lag from checkpoint 02. |
| 22:15:26.437 | SL 603–605 | Skadi orgasms (`source=engine`, 94.5 → fire). Bob joins the group (88.6 ≥ 85). Both orgasm **in stage 3**. |
| 10:15:26PM | PAP 1210–1211 | SexLab logs Skadi's orgasm, then **`StageEnd` in the same second**: stage 3 ends after ~3 s. |
| 22:15:27.068–27.118 | SL 609, 611 | `sla_relief … pending (stage 4)`; stage-4 `Change` event (thread.Stage is already 4). |
| 22:15:27.835 | SL 620 | `Orgasm_ApplyGroup … ending jump: stash folds into the next stage DN`. |
| 22:15:28.002–28.035 | SL 622–623 | `Ending_Check victim hold: aggressor orgasmed at stage 4/5` → `Ending_ToFinal GoToStage 4 -> 5`. |
| 22:15:28.118 | SL 624, PAP 1214 | `StageStart 4/5 last:4`: the 3→4 advance only now reaches Animating. **The jump to 5 never happens.** |
| 22:15:29.768 | SL 634 | `SetEndingTarget … target 0` (ending done). |
| 22:15:31.852 | SL 646 | One DN: "Skadi and Bob are orgasming. …" (the stash fold worked, nothing doubled). |
| 22:15:45.370 | SL 725, PAP 1229–1232 | Stage 4 ran its full timer (~17 s). `StageStart 5/5`, then `OrgasmStart` and `Ending_Hold holding final stage:5 max:30` (SL 735). |
| 22:16:03.671 | SL 779, PAP 1233–1234 | SexLab `StageEnd` → `StageStart 5/5 last:5` again, then `AnimationEnding` at 22:16:04. |
| 22:16:07.4–07.6 | SL 807, 811 | `EndScene`; afterglow DN "Skadi and Bob finish. … 1 orgasms" (both). |

`SkyrimNet.log` has no `[E]` lines for this session.

## 3. Findings

### 3a. SLSO advances the stage on Bob's orgasm, and our GoToStage is then lost (bug)

- **Cause (high confidence):** SLSO's `SLSO_SpellGameScript` (`game_male_orgasm_endanim`) calls
  `controller.AdvanceStage()` once a male actor who is not position 0, in a duo, has `GetOrgasmCount() > 0`.
  Bob qualifies as soon as our group orgasm reaches him. SexLab's `GoToStage` (via `AdvanceStage`) sets
  `Stage = 4` at once and enters the `Advancing` state. `sslThreadController.GoToStage` is only defined in the
  `Animating` state. The base-state `GoToStage` is empty, so our `thread.GoToStage(5)` from `Ending_ToFinal`
  (28.035), which came before the stage-4 Animating (28.118), was a silent no-op.
- **Effect:**
  - Our log claims "aggressor orgasmed at stage 4/5" because `thread.Stage` was already 4. In fact the
    orgasm came in stage 3 (third-to-last), where the victim hold shouldn't jump at all.
  - `ending_done` / `ending_hold_pending` are set, but the jump never happens, so stage 4 plays its full timer
    and only then the final stage. The scene still ended correctly, about 17 s later than intended.
  - `StageStart 4/5 last:4` means `last_stage` was already updated to 4 when that StageStart ran.
- **Not certain:** why the second `StageStart 5/5` (22:16:03) comes before `AnimationEnding`. It is probably
  `Ending_Hold` releasing, then SexLab's end-of-stage handling. Check it in the next test.
- **Proposed fix:**
  1. In `Ending_Check` / `Ending_WillJump`, use the stage the orgasm happened in, not `thread.Stage` at check
     time. For example, record `thread.Stage` (or the engine's `sc.stage`) when `Orgasm_ApplyGroup` starts. An
     orgasm in stage 3 of 5 then gives the normal "not second-to-last: no jump".
  2. In `Ending_ToFinal`, don't fire `GoToStage` into a thread that isn't `Animating`. If
     `thread.GetState() != "Animating"`, set a pending flag and do the jump from the next `StageStart` (or
     `Ending_StageStart`), the way `ending_hold_pending` already defers the hold. That also covers manual Next
     / SLSO / P+ advances racing the jump.
  3. Add to KNOWLEDGEBASE: SLSO `game_male_orgasm_endanim` advances the stage after a male non-lead orgasm in a
     duo, and `GoToStage` outside `Animating` is a no-op on SexLab 1.6x.

### 3b. Engine stage lag again (same as checkpoint 02 §3)

`StageStart 3/5` at 23.651 and engine `SetStage 3/5` at 25.551 (1.9 s). The orgasm came after it here, so the
lag did no harm this time. The fix in checkpoint 02 is still open.

### 3c. Worked

- Bob, the victim, got his orgasm with the aggressor through the group join. Both orgasms folded into one DN,
  and the afterglow counted 1 each.
- No 98 cap, no doubled DN, no errors.

## 4. Not yet tested

Carried over from checkpoint 02, all still open:

- The early "aggressor ends" rule's removal in a non-gate scene. This scene did end in stage 3, but through
  SLSO, not our rule.
- The cap (`victim_hold_max`): no hold reached 120 s, and the victim hold never held here.
- A partner expected to orgasm who misses the group join, to see the final roll or gate roll fire for someone
  else.
- Pause / resume, manual Next, an animation change mid-hold, stepping back, SexLab P+, a consensual scene,
  Together mode.
- New: a victim scene **without SLSO** (or with `game_male_orgasm_endanim` off), to see the victim hold
  without SLSO's advance.

## 5. Next

1. Decide on and implement the fix in §3a (orgasm-time stage plus a deferred jump when not `Animating`), and the
   stage-lag fix from checkpoint 02 §3.
2. Add the SLSO / `GoToStage` quirk to KNOWLEDGEBASE.md.
3. Retest this scene (SLSO on), then the same scene with SLSO's male-orgasm advance off, then the §4 list.
4. Then commit with the rest of 0.36.1.
