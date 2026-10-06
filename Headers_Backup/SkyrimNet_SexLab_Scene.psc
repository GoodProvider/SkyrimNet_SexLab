Scriptname SkyrimNet_SexLab_Scene extends SkyrimNet_SexLab_Scene_Interface
SexLabFramework Property sexlab Auto
sslThreadSlots Property threadSlots Auto
sslActorLibrary Property actorLib Auto
Faction Property SkyrimNet_SexLab_Faction_Victim Auto
float Property PAUSE_HOLD_SECONDS = 100000.0 AutoReadOnly
int Property INTENT_STAGE_START = 0 AutoReadOnly
int Property INTENT_STAGE_ONGOING = 1 AutoReadOnly
int Property INTENT_STAGE_END = 2 AutoReadOnly
float Property orgasm_delay = 5.0 Auto
float Property DURATION_CAP_SECONDS = 120.0 AutoReadOnly
bool Property tracking = False Auto
bool Property scene_creator_menu_called = False Auto
Function Trace(String func, String msg="", Bool notification=False) Native
Function DbgEnter(String func, String msg="") Native
Function DbgReturn(String func, String msg="") Native
Function DbgEnd(String func, String msg="") Native
Function DbgMsg(String func, String msg="") Native
String Function GetString() Native
Function Initialize(int _sid, SkyrimNet_SexLab_Scene_Manager _manager, bool _is_generic = false) Native
Bool Function Setup(SkyrimNet_SexLab_Scene_Creator creator) Native
Bool Function Setup_CheckLinks() Native
Function PickNonVictimInitiator() Native
Function ReconcileVictimFactions() Native
Function Release() Native
Function EnsureActorArraysLargeEnough(int size) Native
Function ResetActorsObjs(int size) Native
Function RelinkActorsObjs(int size) Native
Function CheckAnimationChange() Native
bool Function PollAnimationChange() Native
Function QueueAnimationChangeStage(String from_desc) Native
bool Function SyncAnimationDefaults() Native
Function ReloadAnimationDefaults(bool undress_only = true) Native
Function ApplyDressedToActor(Actor akActor, Bool clothed) Native
Function SetUndressedFlag(Actor akActor, Bool undressed) Native
Function NoteSeededRegistry(String reg) Native
Function ClearPositionLocks() Native
Function PersistPositions() Native
Function RestorePosition(int i, Actor akActor) Native
Function ClearPersistedPosition(Actor akActor) Native
Function SetPosition(int index, Actor akActor, int no_orgasm, String speaking_modifiers) Native
int Function SetSpeakingObj(int index, String speaking_modifiers) Native
Function ApplyAnimDbSpeaking() Native
String Function SpeakingCsvFromIndex(int i) Native
Function ApplySexLabVoice(int i) Native
bool Function Voice_BelowGate(Actor a) Native
Function ApplySexLabVoices() Native
bool Function SetActor(int i, Actor akActor) Native
String Function GetUUID(Actor akActor) Native
int Function GetObjFromActor(Actor akActor) Native
bool Function UpdateActor(int i , Actor akActor) Native
Function AlignActors() Native
Function SetNames() Native
String Function GetNames(String key_) Native
String Function GetCreatureDescriptions(Actor akActor) Native
int Function GetTotalOrgasms(Actor akActor) Native
String Function PossessivePronoun(Actor akActor) Native
String Function JoinNames(String[] names, int count) Native
String Function NamesClause(String[] names, int count, String single, String plural) Native
int Function LiveEnjoyment(Actor a) Native
int Function EnjoymentBand(int e) Native
String Function BandLeadIn(int band) Native
String Function ReplaceAll(String s, String find, String rep) Native
Function SetTotalOrgasms(Actor akActor, int total_orgasms) Native
int Property ORGASM_KIND_NONE = 0 AutoReadOnly
int Property ORGASM_KIND_ORGASM = 1 AutoReadOnly
int Property ORGASM_KIND_AGAIN = 2 AutoReadOnly
int Property ORGASM_KIND_FORCED = 3 AutoReadOnly
int Property ORGASM_KIND_MELT = 4 AutoReadOnly
Function StashOrgasm(int i, Actor akActor, int kind, String text = "", int total_orgasms = -1) Native
Function ClearOrgasmStash() Native
String Function MeltKey(Actor akActor, String msg) Native
Function SetThread(sslThreadController _thread) Native
sslThreadController Function GetThread() Native
Function SetGeneric() Native
bool Function IsGeneric() Native
String Function GetIntentMessage(int intent_stage = -1) Native
bool Function GetThreadActive() Native
Function SetOrgasmDisabled(Actor akActor, bool disabled) Native
Function Engine_BeginScene() Native
Function Engine_SetSkills() Native
Function Engine_SetStage() Native
float[] Function Engine_StageSeconds() Native
Function Ending_Reset() Native
Function Ending_RollTarget() Native
Function Engine_SetEndingTarget() Native
Function Ending_Check(Actor[] actors) Native
Function Engine_GatePassed(Actor[] actors, bool hold_stage) Native
Function Gate_Hold() Native
Function Gate_Release() Native
Function Gate_Poll() Native
Function Engine_AdvanceToFinal() Native
Function Ending_ToFinal() Native
Function Ending_StageStart() Native
Function Ending_Hold() Native
Function Ending_Poll() Native
bool Function IsPaused() Native
Function TogglePause() Native
Function Pause_Hold() Native
Function Orgasm_ApplyGroup(Actor[] actors, int[] forced, bool individual, String source, Actor allower, Actor allowed, String extras) Native
bool Function IsFinalStage() Native
Actor Function FirstOtherPosition(Actor akActor) Native
int Property MIRROR_EXTERNAL_THRESHOLD = 3 AutoReadOnly
int Property VOICE_GATE_ENJOYMENT = 50 AutoReadOnly
Function Mirror_Rebaseline(Actor akActor) Native
Function Mirror_RebaselineAll() Native
Function Mirror_Apply(Actor akActor, int value) Native
Function AnimationStart() Native
Function StageStart() Native
String Function StopMessage(Actor speaker, String stop_style, String reason="") Native
Function AnimationEnd(Actor speaker=None, String stop_style="") Native
Function OrgasmCombined() Native
Function OrgasmIndividual(Actor akActor, int full_enjoyment, int num_orgasms, bool from_engine = false) Native
Function OrgasmCustom(Actor akActor, String msg, bool ignore_no_orgasm = false) Native
int Function NarrationMaxChars() Native
String Function FitOrOverflow(String text, String part, int budget) Native
String Function OrgasmMessagesToNarration(int reserve = 0) Native
Function MarkOrgasmNarrated(int obj, Actor akActor) Native
bool Function ThreadHasDomSlave() Native
float Function GetOrgasmDelay() Native
Function ArmOrgasmWindow() Native
Function FlushOrgasmWindow() Native
bool Function NarrateOrgasmStash(Actor source, Actor target, bool force_direct = false) Native
Function SendOrgasmOverflow(Actor source, Actor target) Native
bool Function OrgasmWindow_HoldForFinish() Native
String Function AddCum(int position, Actor akActor, String name) Native
String Function GetDescription() Native
String Function GetThreadJson(Actor speaker) Native
int Function GetThreadObj(Actor speaker) Native
String Function GetLocation() Native
bool Function SexLab_Thread_LOS(Actor akActor) Native
String Function GetTagsString(sslBaseAnimation anim) global Native
Function BuildInThreadAnims(sslThreadController _thread, int in_thread, int in_thread_anims) Native
String Function GetDescriptionFromTags() Native
Function SetStyle(String _style) Native
float Function GetStyleSpeed() Native
int Function GetSpeedLevel() Native
String Function GetSpeedName() Native
String Function GetSpeedAdverb() Native
Function ApplyStyleSpeed() Native
Function ClearStyleSpeed() Native
Function ChangeStyle(Actor who, String _style) Native
Function SetStyleDialog() Native
Function WebUI_ExportAnimationMenuState(sslThreadController _thread) Native
String Function BuildWebUIAnimationMenuState() Native
Function WebUI_OnMenuClose(String json) Native
Function WebUI_OnMenuLiveUpdate(String json) Native
Function WebUI_ApplyLivePositions(int obj, bool apply_values = true) Native
Function RefreshVictimRoles() Native
Function TM_ApplyVictim(Actor akActor, Bool isVictim) Native
Function NarrateVictimToggle(Actor victim, Bool becameVictim) Native
Function WebUI_SaveMenuState(int obj) Native
Function WebUI_OnMenuPrevNext(int direction) Native
Function WebUI_OnMenuStop() Native
Function NotePlayedRegistry(String registry) Native
Bool Function WasRegistryPlayed(String registry) Native
int Function BuildWebUISceneMenuObject() Native
String Function BuildWebUISceneMenuState() Native
Function WebUI_OnNarrate(String json) Native
Function HotkeyChangePositions(bool backwards) Native
Function ToggleDenyOrgasm(Actor akActor) Native
bool Function SetDenyOrgasm(Actor akActor, bool deny, Actor denier, bool from_llm = false, bool narrate = true) Native
Function WebUI_ForceOrgasm(int pos) Native
Function WebUI_OnAnimUpdate(String json) Native
String Function DbgAnimList() Native
bool Function WebUI_SwitchToRegistry(String reg, bool reseed) Native
Function WebUI_TakeCancelSnapshot() Native
Function WebUI_RestoreCancelSnapshot() Native
Function ApplyWebUICommit(int obj) Native
Function EnsureUserAnimDefaultsMap() Native
Function ClearUserAnimDefaults(String registry) Native
Function CacheUserDefaultsForRegistry(String registry) Native
Function MarkUserDefaultsDirty() Native
Function SeedOverlayFromAnimDb() Native
Function TM_ApplyOrgasmMode(Actor akActor, String mode) Native
Function TM_ApplySpeaking(Actor akActor, String speaking) Native
Function TM_ApplyClothed(Actor akActor, Bool clothed) Native
Function TM_SaveAnimationSettings() Native
Function WebUI_RerouteForFocus(bool in_scene) Native
Function WebUI_ConfigureIfOverlayVisible() Native
Function WebUI_PushStage(Bool started = false) Native
Function TM_SetStageDescription(String stageStr, String description) Native
