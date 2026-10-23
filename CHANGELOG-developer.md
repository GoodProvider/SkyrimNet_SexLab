https://github.com/GoodProvider/SkyrimNet_SexLab/releases/tag/0.36.5

Requires SkyrimNet 0.25.0 or later (built against SkyrimNet beta26 rc4).

## Unreleased (branch `profile`)

### Profiling (first in-game runs: `checkpoints/profile/checkpoint-06.md`)
- WebUI **Profile** main panel (`webui/MainPanels/1100_profile.json`, builtin `profile_panel`) drives a run: Start Calibration → Start Profiling → Stop Profiling. See `docs/developers/webui.md` (Profile panel) and `checkpoints/profile/checkpoint-04.md`.
- `SKSE_Source/src/Profiler.h/.cpp`: raw event recorder (B/E/X/M, 112-byte events, two 200,000-event buffers, 80% swap, drop only at 100%), part writer thread with one retry, `[Profiler] run:<key>` markers, pending-note queue, `SNSL_PROF("key")` scope timer.
- New `SkyrimNet_SexLab_WebUI` natives (tasklet-callable, record the VM stack id): `Prof_Begin`, `Prof_End`, `Prof_Mark`, `Prof_CalibMark`, `Prof_SetRecording`, `Prof_EnterProfiling`, `Prof_CalibrateCpp`; Papyrus globals `Prof_Calibrate(n)` and `Prof_Wait(secs, probe_key)` (no call sites). `TraceLog` now takes the VM stack id and adds one `X` event (source `trace`) while recording.
- Probes: Scene_Manager (11 events), Scene (9 functions; `prof_tid` caches `thread.tid`, set in `SetThread`), `Scene_Creator.StartScene`, `Actions.StartScene_Event`, AnimDb (5). Marks `action.received`, `scene.action_start` (detail = intent), `scene.animation_start`, `narration.queue` (`queued`/`immediate`, from `QueueDirectNarration`), `narration.sent` (`immediate`/`flush`).
- SKSE timers: AnimationDB `ResolveTags`, `QueryTopNAnims`, `QueryTopNTags`, `GetStageDescription`, `SubstituteActors`; `QueueDirectNarration`; the `sexlab_npc_stop_allowed` / `sexlab_verbose` decorators.
- `python_scripts/profile_report.py` (stdlib, `uv run`): `ingest` copies a run into `checkpoints/<name>/profiles/<run key>/` and runs `report`, which writes `report.md` (and `events.csv` with `--csv`). `report` adds a per-phase **Player input and scenes** table (minigame input and OrgasmEngine actor counts from the log). `compare <profiles dir>` reports every run and writes `compare.md`; it excludes runs where the minigame was played only during profiling (`--keep-all` keeps them). Overhead gaps also start at `Scene_Manager.CreateCreator` (Scene Creator), the end match ignores case, and the cross-check is skipped when a phase has fewer than two gaps.

## 0.36.5

### WebUI
- `WebUI_Visibility_Show` closes foreign PrismaUI views first: `ForeignViews()` reads view ids from `PrismaUI.log`; `CloseForeignViews()` toggles the dashboard via `SkyrimNetApi.TriggerToggleDashboard` (only when `DashboardOpen()`) and `Unfocus` + `Hide`s other focused views. A 250 ms watcher then calls `WebUI_ShowNow` once no foreign view has focus (dashboard-hidden wait capped at 3 s; "SexLab: request waiting - close the open menu" if focus is held). Fixes the paused-game lock-up after Accept with the dashboard open.

## 0.36.4

### Lover's Ledger
- Lover's Ledger's SexLab refactor (handlers moved from `TTLL_MainController` to `TTLL_SexlabIntegration`) keeps every signature we call. Header stubs gain `TTLL_SexlabIntegration.IsPPlus()` and `TTLL_SexlabPPlus.GetCount(Actor, int)`.
- Lover's Ledger `DescribeFirstTimes` no longer writes virgin blood (`loversledger.first_time.virgin_blood` is gone). `LoversLedger.FirstTimesParts` → `FirstTimes(positions, tags)` (one string, lines joined by " ").
- New config `sexlab.narration.virgin_blood` (bool, default false). `LoversLedger.VirginBloodSentences(positions, vaginal, anal)` is appended to the start `desc` in `Scene.StageStart_NarrateStart`: "This is <name>'s first time having vaginal|anal sex; there is some bleeding and their pussy|ass is a little sore."
- `LoversLedger.FirstGot(a, act)` replaces `NeverGot`: ledger received count 0 **and** `SexLabCount(a, act)` (P+ statistic 10 / 11, AE `VaginalCount` / `AnalCount`) ≤ ledger given count, the "seeded" test of Lover's Ledger `FirstTimes.cpp`. Used by the blood sentences and `Scene.Engine_SetSkills` first-time marks.
- FOMOD option "First vaginal or anal sex causes soreness and bleeding" (`option_virgin_blood/`, added to the `make release` 7z) installs `SKSE/Plugins/SkyrimNet_SexLab/fomod/virgin_blood.txt`. `MCM.VirginBlood_FomodApply` (Setup) sets `sexlab.narration.virgin_blood` true via `PatchConfig` once and writes `fomod/virgin_blood_applied.txt`.

### Dead actors can join scenes (untested)
- `SexLabNet::IsDeadAllowed()` (C++) and `SkyrimNet_SexLab_WebUI.IsDeadAllowed()` (Papyrus) are false until `CorpsePatch::Recheck` finds the patch (or P+).
- Removed: `Utilities.CorpseHealthKey` / `CorpseHealth_Floor` / `CorpseHealth_Restore`, `Scene_Creator.RestoreCorpseHealth`. Nothing in the mod changes a corpse's Health.
- SexLab 1.66 corpse patch: `patch_sexlab166/Source/sslActorAlias.psc` + `sslActorLibrary.psc` (copies of SexLabFrameworkAE 1.66.01 with three `; SkyrimNet_SexLab patch:` edits) → `patch_sexlab166/Scripts`. `make corpse-patch` compiles them and rewrites `SKSE_Source/include/CorpsePatchHashes.h` (`python_scripts/corpse-patch-hashes.py`). A pex embeds its compile time, so rebuild the DLL after every patch compile. `make check-pex` fails on a stale header.
- New global native `SkyrimNet_SexLab_WebUI.CorpsePatchMismatch(Bool pplus)`: first missing / mismatched file, or "". `MCM.CorpsePatch_Check()` (Setup, `OnPluginConfigSaved`) sends mod event `SkyrimNet_SexLab_CorpsePatchOff` to `CorpsePatch_TurnOff`, which runs `Utility.Wait(0.1)`, then `PatchConfig` `sexlab.actors.dead_allowed` false, then `SkyMessage.Show(…, "Close")`.

### Scenes (untested)
- `Scene_Manager.HoldScenePackages(thread)` / `ReleaseIdlePackageHolds()`: SkyrimNet `HoldPackages` / `ReleaseHeldPackages` with owner `"SkyrimNet_SexLab"`, list in StorageUtil `SkyrimNet_SexLab_PackageHold` (form list on None). Hold on `AnimationStarting` + `AnimationStart`; release on `AnimationEnd` and `Setup` for listed actors that are dead or not `SexLab.IsActorActive`.

### Build
- `make release` packs `patch_sexlab166/Scripts` and `option_virgin_blood`; `make check-pex` also checks the patch pex and `CorpsePatchHashes.h`.

## 0.36.3

### Scene narration
- **`Scene.StageStart`** sets `STATUS_ACTIVE` and calls `StageStart_NarrateStart(GetDescription())` before `AlignActors` / `SyncAnimationDefaults`, recording `started_now`. The later branch only hands `start_orgasm_narration` (or a stash that arrived since) to the orgasm DN block. If StageStart now wins the race with `AnimationStart`, AnimationStart skips its Setup reset, because `Setup()` already set `animating_started_at` and the stash is empty for a new scene.
- **Silence nudge**: config `sexlab.narration.silence_seconds` (float, 8, 0 = off). `Scene.PollAnimationChange` → `SilenceTick` → `SilenceNudge_IfQuiet`, which rotates `silence_turn` over the non-player `thread.Positions`. `Utilities.SilenceAllows(source, silence)`: no mod DN within `silence`, `GetSpeechQueueSize() == 0`, `GetTimeSinceLastAudioEnded()` 0 or ≥ `silence`, `NarrationNearby`. `Utilities.SilenceNudge(speaker, partner)` → `SendDirectNarration("continue scene", …)` (no CheckDuplicate). The devkit (beta28-rc2) has no scene-scoped continue API: `TriggerContinueNarration` and continuous mode are global, and CppAPI has no audio or queue query.
- `DirectNarration_Optional`: a `dropped` result clears StorageUtil `sexlab_narration_last_msg` on the source (or the player).
- `GetDescriptionFromTags`: passive receiver verbs for anal, vaginal, cunnilingus and the fallback.

### Scene start messages
- `Scene.StageStart_NarrateStart`: before the start narration it sends `NarrateBelowDirect(min(start_level, 2), "sexlab start info", IntersexSentence() + first times, sender, receiver, force=True)`. Virgin-blood sentences are appended to `desc`, so they ride with the start in every branch (hold stash, orgasm stash, DN / event).
- `SkyrimNet_SexLab_LoversLedger.FirstTimesParts(positions, tags)` returns `String[2]` (first times, blood) and replaces `FirstTimesSentence`. Blood is matched on " is a little sore and is bleeding": keep it in sync with Lover's Ledger `FirstTimes.cpp`.

### Dead actors can join scenes
- Config `sexlab.actors.dead_allowed` (bool, default false): `SexLabNet::IsDeadAllowed()` in C++, `SkyrimNet_SexLab_WebUI.IsDeadAllowed()` (global native) in Papyrus.
- On: the nearby list, `IsAvailableActor` and `ActorLocker::TryLock` stop rejecting `IsDead()`. `Menu.IsAvailableActor` skips `sexlab.IsValidActor` for a corpse, and `EnsureSexLabActorsValid` treats `ValidateActor` -13 as OK.
- `CorpseHealth_Floor` is gated by the toggle and lifts a corpse under 5 Health to 10. `Scene_Manager.CorpseHealth_FloorThread(tid)` runs from `HookAnimationStarting`, so it covers threads other mods start. Floored actors go in StorageUtil form list `skyrimnet_sexlab_corpses_tid_<tid>` on the manager. `CorpseHealth_RestoreThread(tid)` runs from `HookAnimationEnd`.

### Actor Info layout
- `#actor-info-panel` sets `flex-direction: column`, so the header (source title, name, gender) spans the top instead of a left column.

## 0.36.2

### Victim scene ending
- **Victim hold**: `OrgasmEngine::VictimHoldScene(sc)` = mini-game, engine on, timed, no LeadIn, a `Role::kVictim` and a non-DOM `Role::kAggressor` expected to orgasm. The Scene holds the second-to-last stage at its `StageStart` (`Victim_StageStart` → `Victim_Hold`, once per (animation, stage), `UpdateTimer` or P+ `PauseTimer` via `Timer_SyncHold`).
- **Free mini-game**: `JoinGroup`'s early final roll also runs when an aggressor is in the group in the second-to-last stage (log `victim_hold=true`), whatever the ending target. `Ending_Check` / `Ending_WillJump` (`Victim_AggressorFinished`) then release the hold and call `Ending_ToFinal`, so the stash folds into the final-stage DN.
- **Gate scenes**: the `gateHeld` 98 cap skips aggressors, and the gate fires when an aggressor with `CanOrgasmNow` reaches 100, or on `VictimHoldExpired(sid)` (new `SceneState::victimHoldExpired`, not saved, cleared with `gateDone`), instead of `penultElapsed`. `Engine_GatePassed` hands the victim hold to `gate_holding` without touching the timer.
- **Cap**: `Victim_Poll` (1 s, frozen while paused, skipped while the orgasm window is open) reads `sexlab.ending.victim_hold_max` (120, 0 = none). Gate scene: `VictimHoldExpired`, release 3 s later if nobody passed. Else `Victim_Release` (`UpdateTimer(-PAUSE_HOLD_SECONDS)`, no held time). A stage move drops the hold (`Victim_Drop`).
- New natives `IsVictimHoldScene(int sid)` and `VictimHoldExpired(int sid)` on `SkyrimNet_SexLab_OrgasmEngine`.
- **Removed** the no-gate "aggressor ends" rule (`ending_end_after`, `EndAnimation` from `Ending_Poll`).

### NPC-only ending hold
- **`Ending_HoldMax()`** returns half of `sexlab.ending.dialogue_hold_max` (after the `ENDING_HOLD_CAP` clamp) when `!thread.HasPlayer`. It is the only cap source for `Ending_Hold` / `Ending_Poll` on 1.6x and P+, so NPC-only scenes release the final-stage hold at 15 s by default (log `Ending_Hold ... max:15`). The response-played / speech-queue release is unchanged.

### Actor Info view
- **MainPanels `0800_actor_info.json`** (`actor_info_panel`) replaces `0800_lovers_ledger.json`. `SkyrimNet_SexLab_ActorInfo.BuildPanelJson` → `{panel:"actor_info", name, gender, genderEditable, genderNote, source, sourceTitle, ledger | sexlab, empty}`: `ledger` from `LoversLedger.LedgerJson` (renamed from `BuildPanelJson`, the only script that references `TTLL_Store`) when TT Lover's Ledger is loaded, else `sexlab` from `sslActorStats`. JS `renderActorInfo`; `Menu.WebUI_OnControlActorFocus` re-pushes while `WebUI_IsMainPanelOpen("actor_info_panel")`.
- **Gender pulldown**: `fireStatusApply` → `Menu.WebUI_ActorInfoApply(control "gender")` → `Utilities.SetGenderChoice` (StorageUtil `SkyrimNet_SexLab_ChosenSex`; P+ `TreatAsSex` / `ClearForcedSex`, 1.6x `TreatAsGender` / `ClearForcedGender`). OStim has no gender setter.
- Builtins may set `plugin` / `questFormId` / `scriptName` / `openFunction` / `closeFunction`; `OpenMainPanelEntry` / `CloseMainPanelEntry` dispatch them through `DispatchEntryFunction`. `WebUI_MaybeRestoreScenePanel` returns early when a main panel other than Scene is selected (`ActionCatalog::HasMainPanelSelection()`).
- **`Utilities.ActorFromBase(ActorBase)`** (Papyrus_Utilities.cpp): player base → player, otherwise a TESNPC → Actor index from `TESForm::GetAllForms()`, rebuilt on a miss (at most every 5 s). `TTLL_Store.GetAllLovers` returns TESNPC bases while the lover getters take `RE::Actor*`. Compile-only header `Headers_Source/LoversLedger/TTLL_Store.psc`.

### Futa / intersex
- **TNG futa (P+)**: `Utilities.HasTNGPenis` (`TNG_PapyrusUtil.GetActorAddon`, stub `Headers_Source/TNG_PapyrusUtil.psc`); `EnsureFutaSex` (`TreatAsSex 2`, StorageUtil `SkyrimNet_SexLab_ForcedFuta`) in `EnsureSexLabActorsValid`, `ClearFutaSex` in `Scene.AnimationEnd` (marked overwrites only). Bridge stubs `GetSex` / `TreatAsSex` / `ClearForcedSex` in `Headers_Source/SkyrimNet_SexLab_PPlus.psc`.
- **AnimDB**: per-position `_intersex` (Scene Creator, Scene) → `spec.pos_intersex` / `spec.intersex` (Papyrus_AnimationDB.cpp); an intersex position matches male or female rows, and the human slot total must equal the cast.

### OStim TargetMenu
- **TargetMenu OStim row**: `webui/TargetMenu/Actor/options/0120_ostim.json` is a `scene_start` panel with `framework: "ostim"` and `requiresPlugin: TT_OStimNet.esp`. Start calls `SkyrimNet_SexLab_Actions.TM_StartScene_OStim(speaker, target, cast, victim_fid, intent, style, method, direction)`, which starts the scene through OStimNet's `TTON_OStimIntegration.StartOstimSex` / `StartOStimCaring`. Any catalog option can set `framework: "ostim"` to get the same panel without the scene setting row, AnimDB or Scene Creator.

### Aid panel potions
- **Remember**: `AID_LAST` / `aidRemember()` (Use and Cancel) restore subject, target, option (by form id, if still affordable), part (if still in the list and not dimmed), custom part text and typed points. Session only. Fixed in passing: `aidRenderPart` sets `AID.part` itself (`renderPartPulldown` only calls `onPick` when it changes the part).
- **Part lists**: `aidPartsFor(actor, option)`; `renderPartPulldown` takes an optional `partList`. Stamina-only potion: `drink, lips, ass, pussy, penis` (sex-filtered); other potion: `drink` + `bodyPartsFor`. `penis` is sent as `cock`. Sentence reads "… for <actor> to drink." for drink.
- **Scene acts**: native `OrgasmEngine.SetSceneActs(anchor, vaginal, anal, oral)` from `Scene.Engine_SetSkills` (start + animation change); `SceneState.actVaginal/actAnal/actOral` (not saved); `OrgasmEngine::GetSceneActs`.
- **`Aid::Apply`** potion locations `drink` / `lips` / `ass` / `pussy` / `cock` → `PotionLine`: with the matching act and a partner from `GetActorScene` (penis = male base sex) the "puts … on X's dick and it is thrust into Y's …" line and a 0.5 share to receiver and caster (`split`); else "pushes … lip up" / "pours … on penis" with the full effect. Style from `GetSceneSpeedLevel` (gently / forcefully / none). Injury Engine still heals the receiver's share and narrates.
- **Consent**: `Aid::NeedsConsent` (drink / lips on someone else). WebUI.cpp `AidAskConsent`: player receiver of a drink → `openAidOffer({token, question})` / `onAidOfferResult({token, accept})` (Escape = No; lips on the player needs no answer); NPC → `StrategyDecision::RequestAidAccept` with `prompts/decisions/sexlab/aid_accept.prompt` (question `accept`, keys `accept` / `refuse`; no provider / failure = accepted). `AidFinishConsent`: refusal narrates `Aid::RefusalReason` + "." and `AddPunishReason`s it; the potion is not used.
- **Zero-damage Aid spell**: `Aid::AdvanceChannel` skips the `missing < 0.5` "full" stop on the channel's first tick, so one normal cast runs (magicka cost, `PlaySpellVisuals`, `InjuryEngine::Heal` with `narrate`, which heals 0 points but narrates); the channel then stops "full". Before, the channel ended silently with no effect and, with Injury Engine, no narration.

### Punish panel
- **Custom reason**: `punishReasonDialogOk` no longer calls `punishAccept`; it sets `PUNISH.reason` / `reasonCustom`, closes the dialog and re-renders.
- **`GetPunishReasons`** appends `NameOf(actor) + " " + ObservedPhrase(st)` for an `AiDriven` actor while `g_settings.miniGame`, after the held `PunishRecord`s (deduplicated).
- **Part pulldown**: `renderPartPulldown` sorts with `sortPartsByDamage(actor, parts)` (drink / body, damaged by points desc, undamaged, custom). `partDamage` / `partDamaged` combine `injuryFor` and `actor.firstTimes`. `decorateDisplay` adds `.part-damaged` (`var(--danger)`) and, on options, hover handlers for one fixed `#part-damage-pop` (torture-meter markup), hidden by `closeAllPulldowns`.
- **First times**: native `OrgasmEngine.SetFirstTimes(Actor, bool vaginal, bool anal)` → `ActorState.firstVaginal/firstAnal` (sticky OR, reset with the actor's scene, not saved); `OrgasmEngine::GetFirstTimes(FormID)` → `"pussy"` / `"ass"`. Called from `Scene.Engine_SetSkills` only when `LoversLedger.IsInstalled()`; new `LoversLedger.NeverGot(actor, act)` reads `TTLL_Store.GetActionCount(actor, false, act)`. `Hud::OnPunish` / `OnAid` add `firstTimes` to each actor.

### Verbose logging
- Dashboard `sexlab.debug.verbose`: `Config::ApplyLogLevel` (spdlog debug/info, on load and in `ApplyHudConfig`), C++ decorator `sexlab_verbose`, natives `SkyrimNet_SexLab_WebUI.IsVerbose` / `DebugLog`, `Utilities.DebugTrace`. `GetThreadsJson` per-thread `[V]` line (uuid, formid, AnimatingFaction); `Get_Threads` full JSON only when verbose. `0050` / `0550` emit `[SNSL DEBUG]` prompt lines for the `_thread_live` gate.
- `Scene.ApplySpeakerFields(obj, speaker)`: speaker fields are computed in locals; `GetThreadObj` applies them to `thread_obj`, and `GetThreadsJson` re-applies them to its copy. Fixes cross-actor speaker fields from concurrent `sexlab_get_threads` calls.
- `GetThreadsJson`: `GetSceneByThread(t, True, False)` + `GetThreadInScene()` (was the animating/prepare-only lookup + `GetThreadActive()`), so `threads.json` keeps the thread while SexLab is `Advancing` / `Refresh` (scene start, stage changes). `GetThreadObj` skips the `CheckAnimationChange` poll outside animating / prepare. `DebugTraceThread` logs `state:`.

### Scene start messages (untested)
- `Scene_Creator.ValidateActorReason(code)` maps SexLab `ValidateActor` codes to text; `EnsureSexLabActorsValid` notifies and logs it.

### Recursion warning bug (untested)
- **`GetThreadsJson` is off JContainers**: it held an unretained `JMap`/`JArray` across a multi-second loop. JC collected them and handed the ids to another mod, so the thread JSON contained that mod's data, `setObj` created a cycle, and the walker overflowed the Papyrus stack. A third-party recursion detector turned that into a repeating dialog. The function now builds on `SNSL_JMap`/`SNSL_JArray` and serializes with `SNSL_JValue.dump` + `JsonLowerCaseKeys`. The DOM threads array (JC, from SkyrimNet_DOM) is `retain`ed for the duration and bridged per thread with `objectFromPrototype(ObjectToLowerCaseKeyJson(...))`. Rule: never `JValue.release` a JC object you did not `retain`.
- **JC walker depth cap**: `JValueToJsonString(obj, depth = 0)` and the map/array/form-map/int-map helpers pass `depth + 1` per level and return `null` (with a trace) past 32.
- **Dead SNSL handles after a load**: `Mirror_Apply` / `ApplySexLabVoice` check `isExists` on the `GetObjFromActor` handle. `JsonStore::Resolve` logs each dead handle once per session. All `SNSL_*` natives are registered through `WithCaller<Fn>` (`IVirtualMachine*`, `VMStackID` prefix), so the first error for a handle also calls `TraceStack`, which puts the calling script and function in `Papyrus.0.log`.

### Enjoyment runaway bug
- **`Scene.Mirror_Apply`**: one per position at a time (`Mirror_ApplyLocked`, `mirror_busy_at`), external fold only for 3..`MIRROR_EXTERNAL_MAX` (25), wait up to `MIRROR_WAIT_TICKS` while SexLab still reads `sl_mirror_pre`. `Arousal_Floor` tracks `sla_floor_last` so a gap is added once.

### Slow P+ start bug (untested)
- **`Utilities.ResolveAnimation(sexlab, id)`**: P+ → bridge `ResolveAnimation` (`AnimSlots` / `CreatureSlots.GetSetAnimation`), 1.6x → `GetAnimationByRegistry` then `GetCreatureAnimationByRegistry`. Never call `GetAnimationByRegistry` on P+ (`SyncBackEnd` twice per call, ~1 s each). `QuerySexLabAnimsFromAnimDb` resolves one random row on P+.

### Build
- `DEBUG-DELETE(pplus-animdb)` instrumentation removed; the unescape retry and the `EndSync` error (keyed on `g_rows.empty()`) stay.

## 0.36.1

### AnimDB bug
- **AnimDB empty on 0.36.0 (SexLab P+ and 1.6x)**: the 0.36.0 `Scripts/*.pex` were built with `compile: papyrus` (papyrus.exe), which stores the Papyrus literal `"\""` as backslash+quote. Every JSON string built in Papyrus broke, including every `AnimDb_PushAnimBatch` batch, so `EndSync` kept 0 rows. The pex files are rebuilt with pyro, and **`compile: pyro` is the default build task again**. It now uses `C:/Skyrim/tools/Pyro/pyro.exe`; the VS Code extension no longer ships pyro.
- **`make check-pex`** (`python_scripts/check_pex_escapes.py`) fails on any pex with a literal `\"`. `make release` runs it first.
- **`AnimDb_PushAnimBatch`** now logs the parse error, byte offset and nearby text. On a parse failure it retries once with `\"` unescaped, so a bad build still fills the DB. `EndSync` errors when every batch failed to parse.
- `FinishSourceOrDone` notifies "AnimDB build failed" when 0 rows are stored, and its misleading `duplicates=` is renamed `not_stored=`.
- Temporary P+ / AnimDB instrumentation is tagged **`DEBUG-DELETE(pplus-animdb)`**: per-sync batch/row counters, `AnimDb_LastSyncFailures`, `SkyrimNet_SexLab_PPlus.SceneDebug`, first-batch JSON trace, and skipped-id traces. See `checkpoints/pplus_animdb/checkpoint_v01.md`.

### Dead Actor bug (untested)
- **Corpses on SexLab 1.6x**: `sslActorAlias` OnUpdate ends the thread (`EndAnimation(true)`) for an actor that `IsDead() && Health < 1`. `Utilities.CorpseHealth_Floor` raises a corpse to Health 2 before `AddActor` and at each `StageStart`; `CorpseHealth_Restore` puts it back in `Scene.AnimationEnd` (StorageUtil float `skyrimnet_sexlab_corpse_health`). No-op on P+. Temporary instrumentation is tagged **`NECRO-DBG`**; see `checkpoints/necro-animations/checkpoint-v01.md`.

## 0.36.0

### Injury Engine
- **Injury Engine** (optional, formerly SkyrimNet_Whipped): Punish wounds the chosen body part, Aid heals it, and the panels show a torture bar per part. With Injury Engine the spell methods are Flames, Frostbite and Sparks (torture), and a Hits box lands several hits.

### SexLab P+
- **SexLab P+ support**: the animation database fills from P+, scenes end after the orgasms instead of looping, pause and stage keys work, and animation / actor changes keep the scene going. See docs/developers/sexlab-pplus.md.

### Force/Punish/Ask/Order
- **Force is now Ask / Order / Punish** (Num .): ask or order someone in the scene to change how they play; they agree or refuse, and a refusal can be punished. Anyone can punish anyone in any scene, with or without the mini-game. Punish sets no strategy: the punished NPC's decision picks the reaction. NPCs punish with the new `SexLab_Scene_Punish` action; `SexLab_Force` is gone.

### Aid
- **Aid** moves to Num Enter: pick caster and target, and healing spells channel up to a chosen number of points.

### NPC strategy
- **Strategies come from `strategies.json`**: passive, mutual, selfish, selfless, deny self, deny all, deny, tease, focused, nonsexual, open to every role. Together, Greedy, Forced orgasm, Accept force, Hold back, Cum quick, the forced state and mental break are gone. **API break** in `OrgasmEngineAPI.h` (Strategy ids, `IsMentallyBroken`, `kMentalBreak`).
- **Decision prompts** read one timeline of recent speech, thoughts and events instead of the current approach.

### Disable OrgasmEngine
- **Engine off switch** (`sexlab.enjoyment.engine_disabled`): SexLab / SLSO decide enjoyment and orgasms again; the mod only narrates.

### SLO Arouse
- **Arousal and orgasm fixes**: SLO Aroused NG now gets relief for every engine orgasm in Combined mode; SLSO edging no longer swallows our orgasms.

### Bug Fixes
- **Locks cleared on load**: SexLab cancels every scene when a save loads, so actor locks and half-started Scene Creator sessions from the save are released instead of restored.

### WebUI
- **Scenes**: an animation change on SexLab 1.6x restarts at stage 1; animation favorites; Description Editor Start button; Clean Cum option and `sexlab_clean_cum` action; Bondage panel Start handles devices outside `group-devices.json`.
- **Install**: the legacy pre-Beta-25 `config/actions` and `prompts` copies are removed; everything ships in `external/goodprovider.sexlab/`.

### Narration
- **One start narration**: `Scene.AnimationStart` no longer sends a "sexlab update" event with the stage description; the following StageStart's start / change narration is the only one. An NPC-only start the player can see (`Scene.PlayerSeesScene`: within `sexlab.narration.max_distance` and in line of sight) is always a DirectNarration, skipping the cooldown.
- **Narration levels**: start, stage, orgasm, end, position, style and strategy / request narrations can each be Direct, Event, ShortEvent or Silent.

### Inja
- **Inja line breaks**: text sent to SkyrimNet's `ParseString` now goes through `Utilities.ParseInja`, which calls the new native `InjaPrepare` to turn a literal backslash+`n` (how `compile: papyrus` stores a Papyrus newline escape) into a real line break. Do not call `SkyrimNetApi.ParseString` directly.

## 0.35.2

- **Quieter Arouse / Calm**: arousing or calming someone no longer makes anyone speak or adds a line to the orgasm narration; NPCs just briefly know it happened.
- **Simpler sex / affection picks**: animations with any sex act are now tagged *sexual* (the list is in `sex_tags.json`). The TargetMenu's *sex* is now *sexual*, with no sub-choices. *Affection* and *platonic* just leave out sexual animations, and platonic leaves out kissing too. While Scene Creator is open, clicking *sexual*, *affection* or *platonic* sets the creator's tag filters instead of opening their panel. *Custom* opens Scene Creator already filtered to *sexual*.
- **Scene Creator only lists free actors**: actors already in a scene, or just picked for one that is starting, are no longer offered. In the Control Panel they show as *Name (SexLab)* or *Name (locked)*. Nearby actors you can't pick are greyed out with the reason, e.g. *Name (Ostim)*, *Name (Dead)*, *Name (Combat)*.
  - **Scene Creator adding actors**: clicking a nearby actor adds them again. Before, an actor could fail to join (for example as a third actor) and then stay unclickable until the menu was reopened.
- **Take control (Num \*)**: a new key, shown above Num - on the HUD.
  - **Auto play**: in your own scene, press it to let the AI play you (the cell then reads *control*). It picks how you behave, presses the HUD keys for you (stage, speed, pause, deny, end, aid, force, including what to pick in the Aid and Force panels), and after someone speaks it may have you answer. You can still press any key yourself. Press again to take back control. Needs the Multi-Orgasm Mini-game and a SkyrimNet decisions provider.
  - **Control an NPC**: aim at someone in a scene you're not in and press it. The HUD shows that scene "as *name*", and your keys act as that NPC (their stamina and magicka pay). Press again to let go.
- **NPC strategies by the decision model**: in the Multi-Orgasm Mini-game, SkyrimNet's decision model (for example Jev) now picks how each NPC plays: for everyone when a scene starts, and again for an NPC after each line they speak. It weighs the NPC's personality, role, what was just said, how the scene came about, and their Skyrim relationship with each partner. The old strategy actions are gone. Others in the scene may notice a change ("Lydia appears to be focused on her own enjoyment."); there is no popup notification. Needs a **decisions** provider in SkyrimNet; without one, NPCs keep the default strategies. Turn off with **Decision model picks NPC strategies** (Mini-game settings). The model only changes a strategy when it is fairly sure; set how sure with **Decision minimum confidence** (Mini-game settings, default 0.6).
- **Mini-game pacing**: orgasms no longer come in the first half of a scene. Each scene's pace is set from its SexLab stage timers, so when everyone plays Mutual, both partners are close (87%) just before the last stage. Pausing, going back a stage or long dialogue add more, so more orgasms are possible. In your own scenes you have to play your part. New settings **Mini-game Mutual target** and **Mini-game passive share** (Enjoyment).
  - **Orgasm rolls fixed**: partners only climax together when close to the edge (enjoyment plus a small random bonus reaches 100). Before, someone at 30% enjoyment had a 30% chance. **Orgasm roll random bonus** is now under Enjoyment settings.
  - **Paused time**: arousal, orgasm cooldowns and edging no longer advance while the game is paused or a menu is open.
- **Endings when the AI plays everyone**: in the mini-game, when no one is under your control (NPC scenes, or you on auto play), there can still be orgasms along the way, but the last one now comes at the end of the second-to-last stage, and the last stage waits until the reaction to it has been spoken. Uses **Orgasm check before the last stage** (Scene ending settings).
  - The last stage now ends as soon as the reply to the orgasm has been spoken, never more than 30 s later (**Hold last stage for orgasm dialogue**, now 30 s at most).
  - **Auto play stays on** for your later scenes, and across saves, until you press Num \* again. On auto play you no longer always play passive.
  - With a victim, the aggressor always climaxes at the end of the second-to-last stage, even after an earlier orgasm. Whether the victim does depends on the aggressor: forcing an orgasm makes them, teasing holds them back, otherwise it's a roll.
  - Fixed a scene that could stay on its last stage forever after the orgasm reply: it now ends at most 15 s after the last stage's normal time (unless you paused it).
- **Orgasm modes**: new **Orgasm mode** pulldown (Enjoyment settings, and the SkyrimNet_SexLab MCM; changing one changes the other).
  - **Always Orgasm Together at the end**: SexLab's skill, Lewd/Pure, victim/aggressor and relationship rank now matter. A skilled lover or a loved partner gets aroused faster and stays high; an unwilling victim starts slow. Everyone still finishes together at the end.
  - **Multi-Orgasm Mini-game** (default): the same bonus is a constant boost. Nobody is guaranteed an orgasm: several, or none. NPCs play the mini-game themselves using a strategy the AI picks: mutual, selfish, selfless, finish together, tease, passive; victims can reject or try to make it end quickly; aggressors can be greedy or force an orgasm, and a forced partner can give in or resist. Strategies show on the scene HUD.
  - **Enable orgasm mini-game** is replaced by the pulldown. New installs start in Multi-Orgasm Mini-game; a saved choice is kept.
- **Aid and Force keys**:
  - **Aid (Num 0)**: in the mini-game, a new *aid* cell under Num 1 opens a panel: "*You* *spell or potion* on *actor*". Cast one of your healing or stamina spells (it costs its magicka) or use a healing or stamina potion on yourself or anyone in the scene. It is narrated. Greyed out when you have none.
  - **Force (Num .)**: when you are the aggressor, a new *force* cell under Num 3 opens a panel: "You force *victim* to *strategy* by *method*" (slap, pinch, punch, pull, or your own words). It is narrated, and for the **Fear cooldown** (default 2 s) the victim can only give in. Greyed out when the scene has no victim besides you. NPC aggressors who force someone now say how, and giving in or resisting mentions it.
  - **Where in Aid and Force**: both panels add a body-part pulldown (body, pussy, ass, nipples, or your own words). The effect is the same; the narration says where ("Bob casts Healing on Nina's pussy.", "Bob slaps Nina's ass and forces Nina to please him."). *body* keeps the old wording. Force methods are now slap, pinch, punch and pull (cover mouth is gone); the body part says where.
  - **Weak spells in Force**: the Force panel also lists your Novice and Apprentice attack spells (Flames, Sparks, …). The victim takes the spell's smallest damage, never enough to kill, and doesn't turn hostile.
  - **You can see Aid and Force spells**: healing glows, fire / frost / shock flashes, the caster's hand effects and the spell sounds now play on the actors. The spell still never starts a fight.
  - **NPCs aid and force too**: the AI can have an actor heal or restore someone in the scene with their own spells or potions, and have an aggressor force a victim, with the same rules as your keys.
- **Shift in the mini-game**: hold **Shift** while arousing or calming to act on the next actor in the list (1→2, 2→1) without changing your focus, so you can arouse your partner and calm yourself without switching back and forth. The HUD shows ⇧ next to who the press hits.
- **Arousal follows enjoyment** (with SLO Aroused NG or OSL Aroused): during a scene, arousal never stays below enjoyment, so characters read as aroused in conversation. Arousal is only raised, never lowered. Turn off with **Arousal never below enjoyment** (Enjoyment settings).
- **Animation database check**: Settings shows how many animations the database has next to SexLab's count, and warns when they differ. The control panel title turns into a **Rebuild DB** button (**Build DB** on a new game with no database). Either button closes the menu and starts the rebuild.
  - **Mismatch warning on first open**: the first time you press the menu hotkey on a save, a mismatch shows a dialog offering to rebuild. Press the hotkey again to open the menu.
- **Hugs and stage keys**:
  - **Hug narration**: names the right hugger. When Nina hugs you, it says "Nina hugs Bob", not "Bob hugs Nina".
  - **Hugs no longer break scenes**: an NPC can't hug, kiss or start a scene with someone who is already in a SexLab or OStim scene. Before, a bystander hugging a scene partner pulled them out of the animation.
  - **Next / previous stage keys**: a press while SexLab is still switching stages is now ignored instead of acting on the old stage. The log also records more about stage changes, to track down a report of scenes falling back to stage 1.
- **Menus**:
  - **Faster menu**: the menu and the Description Editor open much faster during a scene, and stage changes refresh without lag.
  - **TargetMenu no longer flickers**: a panel opened by hovering now stays open for a second while you move the mouse toward it. Hovering another entry in the same list still switches right away. Moving down a panel's fields no longer makes the panel itself blink.
  - **Simpler title**: the control panel title is plain "SkyrimNet SexLab" unless extra control modes are installed.
  - **Description Editor actors**: the orgasm, dressed, victim and speaking toggles now change only the scene you're in, right away. They're saved as the animation's defaults only when you press **Save**. Stage descriptions still save as you go.
  - **Load button**: new **Load** next to Save puts the scene back to the animation's saved defaults.
- **Leash panel**: now ships with SkyrimNet_Leashed. Update SkyrimNet_Leashed together with this version, or the Leash option shows "Unknown panel: leash".

---- 
## 0.35.1 

- **Position hotkeys**: new **PgUp / PgDn** scene keys swap the actors' roles forward / back (rebindable in the Plugin settings). The hotkey overlay grows a column to show them.
- **Narrate position changes**: new option (on by default) narrates the new stage description with the actors in their new roles.
- **Description Editor**: **continue scene** now closes the WebUI after sending its narration.
- **TargetMenu cleanup**: the Stop / Stage / Position / Animation entries are gone from the in-scene Scene menu; the Description Editor and the new position hotkeys cover them. If you install by hand (not a mod manager), delete the four old files `0100_stop`, `0200_stage`, `0300_position` and `0400_animation` from the TargetMenu Scene folder.
- **Deny / allow orgasm**: the Transform option is gone. Denying and allowing are plain events again: "Bob forbids Nina from orgasming without permission." / "Bob permits Nina to orgasm."
- **Hug fix**: a single hug no longer leaves you unable to attack with your weapon (e.g. a whip) afterward. Both people now put their weapons away before hugging.
- **Newer Skyrim support**: the SKSE plugin is rebuilt for Skyrim 1.7.x / 1.7.99 and works with SkyrimNet beta26 rc4.
- **Camera**: locking the free camera (Num 3) mid-scene returns the normal third-person camera with mouse look enabled, and when a scene ends the camera goes back to the mode it was in when the scene began (first person stays first person).
- **Mouse mini-game**: right mouse now arouses and left mouse calms during mini-game scenes by default. Turn **Allow right mouse to arouse and left mouse to calm** off in the Mini-game settings to go back to keys only.

---- 
## 0.35.0 

- **Prisma Hotkey**: new Prisma hotkey overlay with improved ability to animation and control a scene
- **Scene hotkeys**: when a scene is active the user will be able to effect it using the num lock hotkeys. You can change this mapping in the Plugin seetings. 
    - **hotkey overlay**: there is an optional hotkey overlay which show the current hotkey mapping during a scene
    - **NPCs can play the arousal mini-game** (when the mini-game is on): they can arouse or calm someone, and an aggressor can allow or deny orgasm. Narration now says how close someone was ("Though aroused…", "Although on the edge…").
- **orgasm minigame**: there is now an optional mini-game that allows the user to delay or encourage other actors from orgasming.
- **Style sets animation speed**: gentle, normal and forceful play slower or faster. Change it with slower / faster, the WebUI style control, or let an NPC change it (new LLM action). The old style hotkey is gone.
