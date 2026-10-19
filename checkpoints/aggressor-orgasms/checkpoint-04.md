# Checkpoint 04: victim hold accepted as tested, committed with 0.36.1

Written from `C:\Skyrim\dev\mods\SkyrimNet_SexLab`, branch `main`, after [checkpoint-03.md](checkpoint-03.md).
The 0.36.1 work (including the victim hold and the NPC-only ending hold) is now committed. No code changed in
this session.

## 1. What changed

- The user accepted the victim hold as tested on the checkpoint 03 run (Skadi × Bob, SLSO on).
- `CHANGELOG.md`, `CHANGELOG-developer.md`, `CHANGELOG-player.md`: `### NPC-only ending hold` and
  `### Victim scene ending` no longer carry `(untested)`. The other 0.36.1 topics keep their tag.
- `make check-pex`: 30 pex, 0 bad.
- Committed: all tracked changes, the ActorInfo view (`0800_actor_info.json`,
  `SkyrimNet_SexLab_ActorInfo.psc/.pex`), `Headers_Source/TNG_PapyrusUtil.psc`, and the checkpoint markdown.
  Checkpoint `logs/` folders, `bug-logs/`, `extern/` downloads and the handoff notes were left out.

## 2. Still open (known, not fixed)

1. **SLSO advance races our jump** (checkpoint 03 §3a): SLSO `game_male_orgasm_endanim` calls `AdvanceStage()`
   after a male non-lead orgasm in a duo; our `thread.GoToStage(5)` then lands outside `Animating` and is a
   no-op. Fix: use the orgasm-time stage in `Ending_Check` / `Ending_WillJump`, and defer `Ending_ToFinal`'s
   jump to the next `StageStart` when the thread is not `Animating`. Add the quirk to KNOWLEDGEBASE.md.
2. **Engine stage lag** (checkpoint 02 §3): engine `SetStage` ~1.9 s after `StageStart`.
3. Untested (checkpoint 03 §4): early "aggressor ends" rule removal in a non-gate scene, `victim_hold_max` cap,
   a partner missing the group join, pause / resume, manual Next, animation change mid-hold, stepping back,
   SexLab P+, consensual scene, Together mode, a victim scene without SLSO's male-orgasm advance.

## 3. Next

1. Implement fixes 2.1 and 2.2, retest with SLSO on and off.
2. Work through the 2.3 list.
