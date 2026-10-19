# 01 — no-narration (Delicious Nuts report)

Repo `SkyrimNet_SexLab` · branch `main` · baseline `7382d93a` (uncommitted necro work also in the tree) · 2026-10-19

## Goal
Fix the report in [README.md](README.md):
- no direct narration at start / during the scene (the ending was fine);
- the player was in the giving position, but the dialogue had Hulda penetrating;
- also check the updated devkit for a better way to keep scene actors talking.

## Logs
[logs/2026-10-19-08-53-21/](logs/2026-10-19-08-53-21/) holds the user-submitted `SkyrimNet_SexLab.log` and `SkyrimNet.log` (moved; see MANIFEST.txt).

## Findings
1. **The start DN fired 66 s late.**
   - The animation started at 20:19:39 ([SkyrimNet_SexLab.log:668](logs/2026-10-19-08-53-21/SkyrimNet_SexLab.log#L668)); the start DN went out at 20:20:45 ([:798](logs/2026-10-19-08-53-21/SkyrimNet_SexLab.log#L798)).
   - The stage 2 and 3 StageStarts still show `status:Setup` ([:734](logs/2026-10-19-08-53-21/SkyrimNet_SexLab.log#L734), [:768](logs/2026-10-19-08-53-21/SkyrimNet_SexLab.log#L768)). The start branch ran only after the StageStart bookkeeping, on a slow VM.
2. **No silence timer existed.**
   - The stage-change continue was dropped by the 20 s any-audio cooldown, with bystander chatter at the inn ([:843](logs/2026-10-19-08-53-21/SkyrimNet_SexLab.log#L843)).
   - The retries were then blanked by CheckDuplicate, which had stored the dropped text ([:846](logs/2026-10-19-08-53-21/SkyrimNet_SexLab.log#L846), [:907](logs/2026-10-19-08-53-21/SkyrimNet_SexLab.log#L907)).
3. **Role wording.**
   - SexLab sorted Hulda (the receiver) to position 0 ([:660](logs/2026-10-19-08-53-21/SkyrimNet_SexLab.log#L660)), so the physical placement was correct.
   - Anim `jnxea0bq` has no AnimDb description. The tag fallback said "Hulda is … having anal sex with Prisoner" (receiver as subject, active verb).
4. **Tongue:** not this mod. There is no expression code; it comes from SexLab expressions or an expression mod.
5. **Devkit beta28-rc2:**
   - no signature changes;
   - no scene-scoped continue (`TriggerContinueNarration` and continuous mode are global, GameMaster-picked);
   - triggers have no interval;
   - CppAPI has no audio or queue query.

## Changes (compiled with pyro, `make check-pex` 0 bad; not tested in game)
- **`Scene.StageStart`:** claims `STATUS_ACTIVE` and calls the new `StageStart_NarrateStart(desc)` before the bookkeeping. It traces `start DN after Xs`.
- **Orgasm stash at start:** carried in `start_orgasm_narration` to the existing orgasm DN block.
- **Silence nudge.** New setting `sexlab.narration.silence_seconds` (default 8, 0 = off; manifest, Narration).
  - `Scene.PollAnimationChange` → `SilenceTick` → `SilenceNudge_IfQuiet` (the speaker rotates over non-player positions).
  - `Utilities.SilenceAllows`: no mod DN within N s, queue 0, last audio 0 or ≥ N s, player nearby.
  - `Utilities.SilenceNudge` sends `"continue scene"` via `SendDirectNarration` (no CheckDuplicate).
  - The stage-change continue uses the same nudge.
- **`DirectNarration_Optional`:** a drop clears the stored `sexlab_narration_last_msg`.
- **`GetDescriptionFromTags`:**
  - anal and vaginal now read "receiving … from";
  - cunnilingus has its own "receiving cunnilingus from" branch;
  - the generic fallback reads "being fucked by".
- **Docs:** three CHANGELOGs, `docs/players/overview.md`, and a KNOWLEDGEBASE entry.

## Risks / not yet tested
- StageStart can now claim ACTIVE before `AnimationStart` checks status, which skips AnimationStart's first-start stash reset. Setup already set `animating_started_at`, and a new scene's stash should be empty. Watch for a stale orgasm stash at the start.
- An 8 s nudge may talk over SexLab moans or crowd the orgasm/ending DNs. They are gated by `OrgasmDNRecent`, `gate_holding` and `ending_done`, but this is unverified.
- The cause of the slow Papyrus VM is unknown. Possible contributors: `GetThread` called every ~1 s, and the NECRO-DBG snapshots from the uncommitted necro work.

## Next
1. Deploy the new pex and manifest. Hotkey a scene with the player giving and an NPC, in a busy inn.
2. In `SkyrimNet_SexLab.log`, check:
   - `StageStart_NarrateStart start DN after` is a few seconds;
   - `SilenceNudge speaker:` lines appear about every 8 s of quiet, with the speaker rotating;
   - there are no `changing duplicate "continue activity` lines.
3. Check that the start text reads "… receiving anal sex from …" and that the NPC's lines get the roles right.
4. Check that `silence_seconds = 0` gives no nudges, and that `stage_level = Event` gives no nudges.
5. Check that the orgasm and ending replies are not cut off by a nudge.
6. Reply to Delicious Nuts (draft in the session summary) and ask them to retest with the new build.
