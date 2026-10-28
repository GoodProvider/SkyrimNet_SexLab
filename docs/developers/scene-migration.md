# Scene migration inventory

Every function in the Papyrus scene layer, mapped to its C++ owner, a thin Papyrus shell, or removal. This is the base for the strangler steps in [anim-engine.md](anim-engine.md) §8 and §9.

**Status:** inventory only (checkpoint `anim-engine/05`, 2026-10-25). No code has moved yet.

## 1. Scope and counts

| Script | Functions + events | Role |
|--------|-------------------:|------|
| `SkyrimNet_SexLab_Scene_Interface.psc` | 9 | Base class (`extends Quest`) shared by Scene and Creator: `sid`, style, status, names, intent properties |
| `SkyrimNet_SexLab_Scene_Creator.psc` | 60 | One pooled quest per pending start (`Scene_Creator_00`–`09`, `000813`–`00081C`) |
| `SkyrimNet_SexLab_Scene_Manager.psc` | 77 | Singleton: pool, lookup, SexLab hooks, WebUI entry points, actions |
| `SkyrimNet_SexLab_Scene.psc` | 216 | One pooled quest per running scene (`Scene_00`–`09` + `Scene_Generic` `000812`) |
| **Total** | **362** | |

anim-engine.md §8 used earlier counts (217 / 62 / 66). The counts above come from a case-insensitive listing of the `Function` / `Event` declarations in the current source. Several declarations use a lowercase `function` or `event`.

### Targets

| Target | Meaning |
|--------|---------|
| **Registry** | `Scenes::Registry`: the pool, lookup by sid / thread / actor, save / restore through the co-save |
| **Creator** | `Scenes::Creator`: the cast, locks, tag resolve, animation select, start |
| **Scene** | `Scenes::Scene`, built on AnimEngine (stage cursor) + OrgasmEngine (enjoyment, gates, endings) |
| **Narration** | NarrationQueue / NarrationTiming / the SkyrimNet C++ API |
| **WebUI** | Direct C++ WebUI handlers. This removes the round trip `WebUI.cpp` → `DispatchManagerMethod*` → Papyrus |
| **Shell** | Stays in Papyrus as a thin forwarder (needed by Papyrus-only mods, ModEvents or SexLab APIs) |
| **Drop** | Goes away with the SexLab thread path (`sslThreadController`, `sslBaseAnimation`, the `TM_*` bridge) |
| **Debug** | Trace helpers. These map to `logger::` in C++ |

## 2. Callers from outside the scene scripts

These are the entry points that must keep working (or move with a shim) at each strangler step.

### Papyrus

| Caller | Calls |
|--------|-------|
| `Main.psc:130,219` | `Manager.Setup` |
| `Actions.psc` | `Manager.IsBusy`, `Manager.GetSceneByActor` (×18). On the scene: `GetThread`, `StageStep`, `StageGoTo`, `BuildWebUISceneMenuState`, `TM_SetStageDescription`, `PPlus_BeginActorChange`, `PPlus_SwitchScene`, `CheckAnimationChange`, `TM_ApplyVictim`, `TM_ApplyOrgasmMode`, `SexLabForceOrgasm`, `SetDenyOrgasm`, `TM_ApplySpeaking`, `ApplyDressedToActor`, `TM_ApplyClothed`, `TM_SaveAnimationSettings` |
| `Menu.psc` | `Manager.GetThreadByActor`, `GetSceneByActor`, `WebUI_TakeCancelSnapshots`, `BuildAllSceneInfosJson`, `CreateCreator`, `GetSceneSettings`. On the scene: `GetThread`, `GetThreadInScene`, `BuildWebUISceneMenuState`, `TogglePause`, `ToggleDenyOrgasm`, `HotkeyChangePositions`. On the creator: `LockAllActorLock`, `SetVictim`, `StartScene`, `Release` |
| `OrgasmEngine.psc:196-288` | `Manager.GetSceneByActor`, `EndExhausted`. On the scene: `Orgasm_ApplyGroup`, `Engine_GatePassed`, `Engine_AdvanceToFinal`, `Mirror_Apply` |
| `Handler_DOM.psc` | `Manager.GetSceneByActor`, `IsNoOrgasmPersisted`, `OrgasmCustom`, `PushDomThreads` |

### C++ → Papyrus (method dispatch by name)

| Source | Target script | Methods |
|--------|---------------|---------|
| `WebUI.cpp:1075-1620` via `PapyrusBindings_WebUI::DispatchManagerMethod*` (`Papyrus_WebUI.cpp:1307,1341,1383`) | Manager | `WebUI_OnYesNoExplain`, `WebUI_OnYesNoResult`, `WebUI_OnSceneCreatorHandoff`, `WebUI_OnSceneCreatorResult`, `WebUI_OnSceneCreatorLoad`, `WebUI_OnSceneCreatorSave`, `WebUI_OnAnimationMenuClose`, `WebUI_OnAnimationMenuLiveUpdate`, `WebUI_OnAnimationMenuPrevNext`, `WebUI_OnAnimationMenuStop`, `WebUI_OnSceneConnectionChange`, `WebUI_OnSceneConnectionsRefresh`, `WebUI_OnSceneAnimUpdate`, `WebUI_OnAnimRegistrySave`, `WebUI_OnResolveActorMeta`, `WebUI_OnSceneInfoCommit`, `WebUI_OnSceneNarrate` |
| `Papyrus_WebUI.cpp:1275-1283` | Scene | `WebUI_ExportAnimationMenuState` |
| `ActionDispatch.cpp:420` | (action script) | treats `StartScene*` / `WebUI_StartScene*` names specially (tags argument) |

### ModEvents and SexLab hooks (registered in `Manager.RegisterEventsActions` / `RegisterEventsSexlab`, `Scene_Manager.psc:1237-1481`)

| Event | Handler |
|-------|---------|
| `SkyrimNet_SexLab_Action_Start` / `_Stop` / `_Style` | `Action_Start` / `Action_Stop` / `Action_Style` |
| `HookAnimationStarting`, `HookAnimationStart`, `HookStageStart`, `HookAnimationChange`, `HookAnimationEnd`, `HookActorChangeStart`, `HookActorChangeEnd`, `HookLeadInEnd`, `HookOrgasmStart` | `AnimationStarting`, `AnimationStart`, `StageStart`, `AnimationChange`, `AnimationEnd`, `ActorChangeStart`, `TraceActorChangeEnd`, `TraceLeadInEnd`, `OrgasmCombined` |
| `SexLabOrgasm` | `OrgasmIndividual` |
| `SkyrimNet_SexLab_AnimationChanged` (own) | `AnimationChangedStage` |

Polling: the Manager's `OnUpdate` (`StartAnimationPoll`, `ANIMATION_POLL_SECONDS`). The Scene's `OnUpdate` (`Scene.psc:4687`) is a 1 s tick re-armed by the Gate / Victim / Ending / Pause / orgasm-window code.

Nothing under `SKSE/Plugins/SkyrimNet/` (action YAML, prompts) names a scene script directly. Actions reach the scene layer through `Actions.psc` or the `Action_*` ModEvents.

## 3. Scene_Interface (9)

| Function | Line | Target | Notes |
|----------|-----:|--------|-------|
| `Trace` | 73 | Debug | |
| `GetString` | 81 | Registry | debug description |
| `Initialize` | 90 | Registry | pool slot bind (`sid`, manager, generic) |
| `Release` | 103 | Registry | slot return |
| `SetStyle`, `GetStyle` | 123, 132 | Scene | style is scene state |
| `IsActive` | 136 | Registry | `status != INACTIVE` |
| `TryClaim` | 142 | Registry | slot claim; the C++ registry replaces the quest-pool race |
| `SetStyleDialog` | 154 | Shell | UIExtensions dialog |

Once the pool is in C++, the Interface becomes a property bag. Its properties (`style`, `status`, names, `has_player`, `intent`) become getters on the native scene.

## 4. Scene_Creator (60)

| Area | Functions (line) | Target | Notes |
|------|------------------|--------|-------|
| Debug | `Trace` 91, `DbgEnter` 100, `DbgReturn` 110, `DbgEnd` 120, `DbgMsg` 126, `GetString` 133 | Debug | |
| Pool | `Initialize` 149, `Release` 288, `Setup_CheckLinks` 270 | Registry | `Release` called by Menu.psc |
| Setup | `Setup` 165, `SetMethod` 770, `SetStyle` 920, `GetStyle` 925, `SetEventHook` 929, `GetSpeaker` 939, `GetTarget` 945 | Creator | `Setup` called by `Manager.CreateCreator` |
| Cast arrays | `EnsureActorsArraysLargeEnough` 584, `ShiftActorsLeft` 598, `SetMasks` 625, `SetNames` 651, `RealignActorMasksFromPositions` 539 | Creator | Plain vectors in C++ |
| Victims | `SetVictim` 710, `SetVictims` 732, `RebuildVictimsFromMask` 666 | Creator | `SetVictim` called by Menu.psc |
| Tags | `RemapTag` 784, `RemapAllTags` 797, `SetTag` 805, `SetTagSuppress` 812, `AddTag` 819, `AddTagSuppress` 839, `SetTags` 861, `SetTagsSuppress` 867, `SetTags_Helper` 873 | Creator | Reuse `ResolveTags` + tag synonyms ([tag-synonyms.md](../reference/tag-synonyms.md)) |
| Actor validity / locks | `ValidateActorReason` 1186, `EnsureSexLabActorsValid` 1216, `LockAllActorLock` 1263, `UnLockAllActorLock` 1283, `IsActorLocked` 1297, `LockActorLock` 1303, `UnlockActorLock` 1333 | Creator | Reuse `ActorLocker` (already C++). `EnsureSexLabActorsValid` keeps a SexLab-validity check only while the SexLab path lives |
| Animation select | `SelectAnimations` 1826, `SelectAnimationsFromAnimDb` 1912, `QuerySexLabAnimsFromAnimDb` 1979, `ResolveAnimationsFromUI` 1784, `ResolveAnimationsFromTags` 1806, `HasAnimList` 1902 | Creator | Reuse `QueryTopNAnims`. The results become AnimEngine scene ids instead of `sslBaseAnimation[]` |
| Select dialog | `SelectAnimationsDialog` 2099, `AddGroupTags` 2236, `GroupDialog` 2253, `YesNoDialog` 1815 | Shell | UIExtensions list menus. Candidate for Drop if the WebUI creator fully replaces them |
| Start | `StartScene` 326, `FinishStartScene` 372, `ApplyMajorityClothed` 518 | Creator | `StartScene` called by Menu.psc. `FinishStartScene` builds the `sslThreadModel`: replaced by `AnimEngine::Start`. `ApplyMajorityClothed` becomes a scene setting |
| Consent | `BuildYesNoQuestion` 1342, `ContinueAfterYesNo` 1390, `RejectWithReason` 1425 | Creator | Reached from `Manager.WebUI_OnYesNo*` |
| WebUI creator | `TryOpenSceneCreatorMenu` 312, `ContinueAfterSceneCreator` 1444, `BuildWebUIObject` 1471, `BuildWebUIState` 1525, `ApplyWebUIState` 1532 | WebUI | JSON is built in Papyrus today; C++ builds it directly |
| Presets | `LoadSetting` 954, `SaveSetting` 1736, `ReadSettingFlags` 1682, `LoadPresetFromWebUI` 1706, `SavePresetFromWebUI` 1716 | Creator | The file format is in [scene-settings.md](../reference/scene-settings.md); keep it |

## 5. Scene_Manager (77)

| Area | Functions (line) | Target | Notes |
|------|------------------|--------|-------|
| Debug | `Trace` 45, `TraceThreadStage` 1684, `TraceActorChangeEnd` 1676, `TraceLeadInEnd` 1680 | Debug | the last two are SexLab hook handlers that only log |
| Init | `Setup` 52, `Setup_CheckLinks` 145, `RegisterEventsActions` 1237, `RegisterEventsSexlab` 1447 | Registry | `Setup` called by Main.psc. SexLab hook registration → Drop with the SexLab path |
| Create | `CreateCreator` 175, `CreateSceneByCreator` 196, `CreateSceneWithoutCreator` 214 | Registry | `CreateCreator` called by Menu.psc |
| Lookup | `GetSceneByActor` 465, `GetSceneBySid` 638, `GetCreatorBySid` 627, `GetSceneByThread` 234, `GetSceneByThreadId` 307, `GetThreadByActor` 481, `FindSceneByActorInThreadScene` 507, `GetSceneInactive` 405, `EnsureSceneForThread` 321, `ThreadHasCreatorLockedActor` 292, `IsBusy` 2017 | Registry | `GetSceneByActor` is the busiest external call (Actions ×18, OrgasmEngine ×4, Menu ×5, DOM ×2). Thread-keyed lookups → Drop with the SexLab path, actor / sid lookups stay |
| Pool | `RebuildScenePool` 329, `ResolveSceneGeneric` 390, `UnsetThread_Scene` 563, `EnsureThreadSceneLargeEnough` 569 | Registry | Thread-index map → Drop |
| Settings files | `GetSceneSettingFilename` 587, `GetSceneSettings` 590 (called by Menu.psc and `Creator.BuildWebUIObject`), `SceneSettingNameIsValid` 793, `SaveSceneSettingFromWebUIJson` 809 | Creator | Shares the preset code with Creator |
| WebUI: creator | `WebUI_OnYesNoResult` 645, `WebUI_OnYesNoExplain` 657, `WebUI_OnSceneCreatorResult` 666, `WebUI_OnSceneCreatorHandoff` 680, `WebUI_OnSceneCreatorLoad` 786, `WebUI_OnSceneCreatorSave` 883 | WebUI | C++ dispatch targets today (§2) |
| WebUI: scene | `WebUI_OnAnimationMenuClose` 892, `WebUI_OnAnimationMenuPrevNext` 899, `WebUI_OnAnimationMenuStop` 906, `WebUI_OnAnimationMenuLiveUpdate` 913, `WebUI_OnSceneAnimUpdate` 1102, `WebUI_OnSceneNarrate` 1109 | WebUI | Forward by `scene_sid` to the Scene's `WebUI_*` |
| WebUI: connections / infos | `WebUI_PushSceneConnections` 920, `BuildSceneConnectionsJson` 924, `WebUI_TakeCancelSnapshots` 950, `BuildAllSceneInfosJson` 961, `WebUI_OnSceneInfoCommit` 1009, `WebUI_OnSceneConnectionsRefresh` 1042, `WebUI_OnSceneConnectionChange` 1046 | WebUI | `WebUI_TakeCancelSnapshots` and `BuildAllSceneInfosJson` are also called by Menu.psc |
| WebUI: registry / meta | `WebUI_OnAnimRegistrySave` 1116, `WebUI_OnResolveActorMeta` 1178 | WebUI | AnimDB writes; already mostly C++ |
| Actions | `Action_Style` 1248, `Action_Stop` 1267, `Action_Start` 1361, `EndExhausted` 1345 | Shell | ModEvent entry points stay in Papyrus and forward to native. `EndExhausted` called by OrgasmEngine.psc → Scene |
| SexLab hooks | `AnimationStarting` 1488, `AnimationStart` 1560, `StageStart` 1616, `AnimationChange` 1644, `ActorChangeStart` 1666, `AnimationChangedStage` 1695, `AnimationEnd` 1718 | Drop | AnimEngine stage events replace them. Keep while the SexLab path lives |
| Packages / camera | `HoldScenePackages` 1507, `ReleaseIdlePackageHolds` 1529, `RestoreCameraAfterScene` 1545 | Scene | AnimEngine `Lock` / `Unlock` already covers packages. Check camera parity |
| Poll | `StartAnimationPoll` 1593, `OnUpdate` 1597 | Drop | AnimEngine tick |
| Orgasm | `OrgasmCombined` 1791, `OrgasmIndividual` 1817, `GettotalOrgasms` 1870, `IsNoOrgasmPersisted` 1880, `OrgasmCustom` 1884 | Scene | The first two are SexLab events → Drop. `IsNoOrgasmPersisted` and `OrgasmCustom` are called by Handler_DOM.psc: keep as Shell forwarders |
| Thread JSON | `SaveThreadsJson` 1907, `PushDomThreads` 1913, `EnrichActorObjForJson` 1962, `AddStrIfNotDefined` 1997 | Registry | `PushDomThreads` called by Handler_DOM.psc. Becomes a native JSON snapshot |
| Dialog | `GetStyleDialog` 2004 (global) | Shell | UIExtensions |

## 6. Scene (216)

Grouped by the prefix map in anim-engine.md §8.

| Area | Functions (line) | Target | Notes |
|------|------------------|--------|-------|
| Debug | `Trace` 189, `DbgEnter` 198, `DbgReturn` 208, `DbgEnd` 218, `DbgMsg` 228, `GetString` 239, `TraceStageState` 3406, `DbgAnimList` 6108 | Debug | |
| Lifecycle | `Initialize` 248, `Setup` 282, `Setup_CheckLinks` 436, `Release` 579, `SetGeneric` 1739, `IsGeneric` 1742 | Registry | |
| Cast / actors | `PickNonVictimInitiator` 468, `ReconcileVictimFactions` 516, `EnsureActorArraysLargeEnough` 688, `ResetActorsObjs` 733, `RelinkActorsObjs` 745, `SetPosition` 1076, `SetActor` 1213, `UpdateActor` 1343, `GetUUID` 1318, `GetObjFromActor` 1325, `AlignActors` 1371, `FirstOtherPosition` 3103 | Scene | `AlignActors` → AnimEngine `Snap` |
| Position persistence | `ClearPositionLocks` 991, `PersistPositions` 1017, `RestorePosition` 1042, `ClearPersistedPosition` 1058 | Scene | |
| Names / text | `SetNames` 1404, `GetNames` 1415, `GetCreatureDescriptions` 1448, `PossessivePronoun` 1482, `JoinNames` 1495, `NamesClause` 1513, `IntersexSentence` 3602, `SentenceEnd` 3087, `ReplaceAll` 1608, `GetIntentMessage` 1750 | Narration | String helpers; C++ already has equivalents in the prompt / decorator code |
| Speaking / voice | `SetSpeakingObj` 1088, `ApplyAnimDbSpeaking` 1132, `SpeakingCsvFromIndex` 1146, `ApplySexLabVoice` 1172, `Voice_BelowGate` 1197, `ApplySexLabVoices` 1201 | Scene | `ApplySexLabVoice*` → Drop (SexLab voice) |
| Dress | `ApplyDressedToActor` 937, `SetUndressedFlag` 968 | Scene | `ApplyDressedToActor` called by Actions.psc |
| Animation change | `CheckAnimationChange` 776, `ApplyRestartStageOnAnimationChange` 789, `PollAnimationChange` 810, `QueueAnimationChangeStage` 873, `SyncAnimationDefaults` 886, `ReloadAnimationDefaults` 909, `NoteSeededRegistry` 981 | Scene | Mostly SexLab-thread polling; with AnimEngine the switch is a direct call. `CheckAnimationChange` called by Actions.psc |
| Silence | `SilenceTick` 824, `SilenceNudge_IfQuiet` 838 | Narration | NarrationTiming |
| Thread bridge | `SetThread` 1715, `GetThread` 1729, `GetThreadActive` 1782, `GetThreadInScene` 1809, `RefreshThreadObj` 4843, `PushThread` 4833, `BuildInThreadAnims` 5080, `SexLab_Thread_LOS` 5000, `PlayerSeesScene` 4996 | Drop | `GetThread` / `GetThreadInScene` are called by Actions.psc and Menu.psc. Those callers need a native "is active / in scene" replacement first. `PlayerSeesScene` → Scene (LOS stays useful) |
| Animation info | `AnimTag` 5022 (global), `AnimHasTag` 5032, `AnimRawTags` 5039 (global), `AnimName` 5049 (global), `GetTagsString` 5059 (global), `GetDescription` 4817, `GetDescriptionFromTags` 5128, `GetLocation` 4898 | Scene | The `sslBaseAnimation` globals → Drop; AnimDB / AnimEngine registry give tags and names |
| Engine (OrgasmEngine wiring) | `Engine_BeginScene` 1842, `Engine_SetSkills` 1904, `Engine_SetBonusInputs` 1965, `Engine_SetStage` 1993, `Engine_StageSeconds` 2023, `Engine_StageCount` 2054, `Engine_SetEndingTarget` 2240, `Engine_GatePassed` 2326, `Engine_AdvanceToFinal` 2601, `SetOrgasmDisabled` 1830 | Scene | **This is the OrgasmEngine stage wiring**: feed AnimEngine stage changes into these directly. `Engine_GatePassed` and `Engine_AdvanceToFinal` are called by OrgasmEngine.psc. Native for AnimEngine scenes (`AnimEngineOrgasm`, step 2); the Endings, Gates and Victim rows below are too |
| Timers | `Timer_SyncHold` 2083, `IsFinalStage` 3012, `StageRemaining` 3018 | Scene | AnimEngine owns the stage timer |
| Endings | `Ending_Reset` 2096, `Ending_HoldMax` 2157, `Ending_IsExpected` 2175, `Ending_PickLead` 2183, `Ending_RollTarget` 2201, `Ending_WillJump` 2272, `Ending_Check` 2292, `Ending_ToFinal` 2614, `Ending_StageStart` 2637, `Ending_Hold` 2674, `Ending_Poll` 2700, `Ending_TimerState` 2781, `Ending_Watch` 2792 | Scene | Hold / Poll pairs re-arm `OnUpdate`; in C++ they run on the AnimEngine tick |
| Gates | `Gate_Hold` 2401, `Gate_Release` 2418, `Gate_Poll` 2439 | Scene | |
| Victim | `Victim_AggressorFinished` 2250, `Victim_Hold` 2473, `Victim_Release` 2497, `Victim_Drop` 2512, `Victim_StageStart` 2524, `Victim_Poll` 2554, `RefreshVictimRoles` 5476, `Consent_Sync` 5505, `NarrateVictimToggle` 5540 | Scene | `NarrateVictimToggle` → Narration |
| Pause | `IsPaused` 2840, `TogglePause` 2844, `Pause_Hold` 2867 | Scene | `TogglePause` called by Menu.psc. AnimEngine already has Pause / Resume |
| Orgasm | `SexLabForceOrgasm` 2889, `Orgasm_ApplyGroup` 2908, `OrgasmCombined` 4126, `OrgasmIndividual` 4160, `OrgasmCustom` 4196, `GetTotalOrgasms` 1476, `SetTotalOrgasms` 1623, `SetExhausted` 1564, `ToggleDenyOrgasm` 5994, `SetDenyOrgasm` 6013, `ThreadHasDomSlave` 4514 | Scene | `Orgasm_ApplyGroup` called by OrgasmEngine.psc; `SexLabForceOrgasm` / `SetDenyOrgasm` by Actions.psc; `ToggleDenyOrgasm` by Menu.psc |
| Enjoyment text | `FatigueText` 1524, `LiveEnjoyment` 1569, `EnjoymentBand` 1586, `BandLeadIn` 1597 | Narration | |
| Orgasm narration | `StashOrgasm` 1648, `ClearOrgasmStash` 1677, `MeltKey` 1699, `StageStart_HoldStash` 3047, `StageStart_TakeStash` 3068, `OrgasmDNRecent` 3079, `NarrationMaxChars` 4233, `FitOrOverflow` 4241, `OrgasmMessagesToNarration` 4264, `MarkOrgasmNarrated` 4497, `GetOrgasmDelay` 4529, `ArmOrgasmWindow` 4540, `FlushOrgasmWindow` 4566, `NarrateOrgasmStash` 4600, `SendOrgasmOverflow` 4641, `OrgasmWindow_HoldForFinish` 4652, `OrgasmWindow_HoldForStage` 4671, `AddCum` 4735 | Narration | Contract in [orgasm-narration.md](../reference/orgasm-narration.md) |
| SexLab mirror | `Mirror_Rebaseline` 3139, `Mirror_RebaselineAll` 3148, `Mirror_Apply` 3161, `Mirror_ApplyLocked` 3185 | Drop | `Mirror_Apply` called by OrgasmEngine.psc; remove that call first |
| Arousal | `Arousal_Floor` 3273 | Shell | SLA is Papyrus-only |
| SLA | `SLA_ReliefBegin` 3319, `SLA_ReliefActive` 3327, `SLA_WillCover` 3344, `SLA_Relieve` 3357, `SLA_EngineOrgasm` 3363, `SLA_FlushPending` 3383 | Shell | Via ModEvents |
| P+ | `PPlus_RefreshPath` 2069, `PPlus_BeginActorChange` 3443, `PPlus_StageStart` 3569, `PPlus_SwitchScene` 5704 | Scene | Over the AnimEngine graph cursor (SLSB scenes). Called by Actions.psc. Deferred with P+ testing |
| Actor change | `ActorChange_KeepScene` 3459, `ActorChange_Started` 3474, `ActorChange_Poll` 3494 | Scene | |
| Stage flow | `AnimationStart` 3520, `StageStart` 3693, `StageStart_NarrateStart` 3623, `AnimationEnd` 3947, `StopMessage` 3929, `StageStep` 5651, `StageGoTo` 5688, `HotkeyChangePositions` 5952, `OnUpdate` 4687 | Scene | `StageStart` (236 lines) is the core. Split it into an AnimEngine stage callback + Narration. `StageStep` / `StageGoTo` called by Actions.psc; `HotkeyChangePositions` by Menu.psc. `StageStart_NarrateStart` / `StopMessage` → Narration |
| Style / speed | `SetStyle` 5217, `GetStyleSpeed` 5222, `GetSpeedLevel` 5236, `GetSpeedName` 5248, `GetSpeedAdverb` 5258, `ApplyStyleSpeed` 5269, `ClearStyleSpeed` 5285, `ChangeStyle` 5300, `NarrateStyleChange` 5318, `SetStyleDialog` 5327 | Scene | AnimEngine playback rate. `NarrateStyleChange` → Narration; `SetStyleDialog` → Shell |
| Registry play log | `NotePlayedRegistry` 5727, `WasRegistryPlayed` 5751 | Scene | |
| User anim defaults | `EnsureUserAnimDefaultsMap` 6703, `ClearUserAnimDefaults` 6710, `CacheUserDefaultsForRegistry` 6718, `MarkUserDefaultsDirty` 6760, `SeedOverlayFromAnimDb` 6767 | Scene | AnimDB-backed; already near C++ |
| WebUI: menus | `WebUI_ExportAnimationMenuState` 5350, `BuildWebUIAnimationMenuState` 5359, `WebUI_OnMenuClose` 5366, `WebUI_OnMenuLiveUpdate` 5387, `WebUI_ApplyLivePositions` 5404, `WebUI_SaveMenuState` 5569, `WebUI_OnMenuPrevNext` 5634, `WebUI_OnMenuStop` 5717, `BuildWebUISceneMenuObject` 5765, `BuildWebUISceneMenuState` 5903, `WebUI_OnNarrate` 5912, `WebUI_ForceOrgasm` 6055, `WebUI_OnAnimUpdate` 6077 | WebUI | `BuildWebUISceneMenuState` called by Actions.psc and Menu.psc; `WebUI_ExportAnimationMenuState` by C++ |
| WebUI: switch / snapshot / commit | `WebUI_SwitchToRegistry` 6143, `WebUI_TakeCancelSnapshot` 6328, `WebUI_RestoreCancelSnapshot` 6394, `ApplyWebUICommit` 6499, `WebUI_RerouteForFocus` 7046, `WebUI_ConfigureIfOverlayVisible` 7057, `WebUI_PushStage` 7071 | WebUI | `WebUI_SwitchToRegistry` (185 lines) → `AnimEngine` scene switch |
| TM bridge | `TM_ApplyVictim` 5523, `TM_ApplyOrgasmMode` 6894, `TM_ApplySpeaking` 6948, `TM_ApplyClothed` 6971, `TM_SaveAnimationSettings` 6992, `TM_SetStageDescription` 7085 | Drop | All are called by Actions.psc. Each needs a native setter on the scene before its caller moves |

## 7. Reused C++

| Need | Existing code |
|------|---------------|
| Actor locks | `ActorLocker` (`TryLock` / unlock) |
| Tag resolve, synonyms | `ResolveTags` |
| Animation select | `QueryTopNAnims` (AnimationDB) |
| Stage playback, placement, pause, Next / Previous, end | `AnimEngine` (`SKSE_Source/src/AnimEngine.cpp`) |
| Enjoyment, gates, endings, orgasm events | `OrgasmEngine` ([orgasm-engine.md](orgasm-engine.md)) |
| Narration timing | NarrationQueue / NarrationTiming |
| JSON | `JsonStore` (`SNSL_JMap` etc.) for any Papyrus shell that still needs maps |

## 8. Order (strangler)

1. **Registry.** Native pool keyed by sid + actor, co-saved. `Manager.GetSceneByActor`, `GetSceneBySid` and `IsBusy` become native-backed shells. Behind a setting, with the Papyrus pool as fallback. No caller changes.
   **Built (checkpoint 10, untested in game):**
   - `Scenes::Registry` (`SceneRegistry.cpp`) keys entries by `(kind, id)`: `(sexlab, sid)` and `(animengine, scene id)`, each with its actor FormIDs.
   - Feeds: SexLab scenes come from Decorators `Threads_Set` / `Threads_Remove` (`Scene.PushThread`: AnimationStart, StageStart, PollAnimationChange, AnimationEnd; `Scene.Release`). AnimEngine scenes come from `StartScene` / `EndLocked` / `ClearAll`. There are no Papyrus feed changes.
   - Natives on `SkyrimNet_SexLab_Registry.psc`: `Registry_SidOf`, `Registry_IsBusy`, `Registry_Describe`.
   - Shells, behind `sexlab.scene_registry.enabled` (Debug, default off):
     - `GetSceneByActor` tries the registry first and accepts a hit only when that slot's thread is in scene and has the actor. Otherwise it uses the old path, renamed `GetSceneByActor_Scan`.
     - Each lookup also runs the scan and traces `registry miss` / `registry disagrees`.
     - `IsBusy` also returns true for an actor in an AnimEngine scene.
     - `GetSceneBySid` was already a plain pool index and is unchanged.
   - Co-save record `SREG` v1 holds a count, then per entry kind, id, actor count and actor FormIDs. Load reads it, logs `Registry: dropped N scene(s) from save` and keeps nothing. SexLab cancels its threads on load and AnimEngine releases its actors.
2. **OrgasmEngine stage wiring.** AnimEngine stage events call the `Engine_*` logic natively, so AnimEngine scenes gain enjoyment, gates and endings. The SexLab path is unchanged.
   **Built (checkpoint 12, untested in game):**
   - `AnimEngineOrgasm` ports `Engine_*`, `Ending_*`, `Gate_*`, `Victim_*` and `Orgasm_ApplyGroup` for AnimEngine scenes. The setting is `sexlab.anim_engine.orgasm_engine` (Debug, default on).
   - The OrgasmEngine sid is `100000 + id`. `RunEffects` routes these scenes' effects to the bridge.
   - AnimEngine gained `SetHold`, `GoToFinal`, `StageView` and `StartScene` roles. Pause keeps the elapsed time.
   - Narration has a seam (`AnimEngineOrgasm::Narration`) that only logs until step 5.
   - Contract: [orgasm-engine.md](orgasm-engine.md#animengine-scenes).
3. **Creator.** Cast, locks, tags and select in C++; start goes through `AnimEngine::Start`. Menu.psc's creator calls and the WebUI creator handlers move to C++.
   **Pulled forward (checkpoint 13, untested in game):** only the start has moved. With `sexlab.anim_engine.enabled` on, `FinishStartScene` hands the Papyrus-chosen animations to the native `AnimEngine_StartFromCreator`; see [anim-engine.md §4](anim-engine.md). Cast, tags and select are still in Papyrus. The no-strip mask is passed (checkpoint 14); the no-orgasm mask is not yet. SexLab and AnimEngine scenes do not coexist: SkyrimNet_SexLab replaces SexLab, and several AnimEngine scenes run at once.
4. **Scene state + WebUI.** Replace the `TM_*` and `GetThread*` callers in Actions.psc / Menu.psc with native setters and queries. Move the `WebUI_*` handlers so `DispatchManagerMethod*` goes away.
5. **Narration**: orgasm / gate / deny narration fills the `AnimEngineOrgasm::Narration` seam. Started in checkpoint 15: `OrgasmGroup` narrates (no window / fold yet); gate / deny / allow are still stubs. Endings, victim and gate already run natively for AnimEngine scenes (step 2).
6. **Drop** the SexLab hooks, the poll, the mirror and the thread bridge once no AnimEngine scene needs them (row 05+ of the roadmap).

## 9. Open questions

- ~~**Co-save format** for the Registry~~ Settled (checkpoint 10): `SREG` v1, versioned, dropped on load (see §8 step 1). Per-scene state (stage, style, victim mask, orgasm counts) is added once a scene can survive a load.
- **External mods:** does any other mod call these scripts (Scene, Manager) or rely on their quest FormIDs `000802`–`00081C`? If so, those calls are the shell surface that must stay.
- **Dead code:** callers above cover cross-script and C++ entry points. Calls inside each script were not traced function by function. A scripted call-graph pass (for example `tools/scene_inventory.py`) should mark unused functions before the Scene moves.
