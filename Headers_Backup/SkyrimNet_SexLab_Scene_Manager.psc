Scriptname SkyrimNet_SexLab_Scene_Manager extends Quest
SkyrimNet_SexLab_Main Property main Auto
SkyrimNet_SexLab_AnimDb Property animdb Auto
SexLabFramework Property sexlab Auto
sslThreadSlots Property threadSlots Auto
sslActorLibrary Property actorLib Auto
Faction Property OStimActorCountFaction = None Auto
SkyrimNet_SexLab_Scene Property sl_scene_generic = None Auto
SkyrimNet_SexLab_Scene[] Property sl_scenes Auto
SkyrimNet_SexLab_Scene_Creator[] Property creators Auto
Faction Property SkyrimNet_SexLab_Faction_Victim Auto
int Property group_info = 0 Auto
sslBaseAnimation[] Property empty = None Auto
sslBaseAnimation[] Property cancel = None Auto
sslBaseAnimation[] Property ui_pending = None Auto
Function Trace(String func, String msg="", Bool notification=False) Native
Function Setup() Native
Bool Function Setup_CheckLinks() Native
SkyrimNet_SexLab_Scene_Creator Function CreateCreator(String intent, Actor[] actors, Actor speaker, Actor target, String tags="", String setting_name="") Native
SkyrimNet_SexLab_Scene Function CreateSceneByCreator(SkyrimNet_SexLab_Scene_Creator creator, sslThreadController thread) Native
SkyrimNet_SexLab_Scene Function CreateSceneWithoutCreator(sslThreadController thread) Native
SkyrimNet_SexLab_Scene Function GetSceneByThread(sslThreadController thread, Bool any_state=False, Bool create_if_missing=True) Native
Bool Function ThreadHasCreatorLockedActor(sslThreadController thread) Native
SkyrimNet_SexLab_Scene Function GetSceneByThreadId(int tid, bool any_state=False, Bool create_if_missing=True) Native
SkyrimNet_SexLab_Scene Function EnsureSceneForThread(sslThreadController thread) Native
bool Function RebuildScenePool() Native
bool Function ResolveSceneGeneric() Native
SkyrimNet_SexLab_Scene Function GetSceneInactive(sslThreadController thread) Native
SkyrimNet_SexLab_Scene Function GetSceneByActor(Actor akActor) Native
sslThreadController Function GetThreadByActor(Actor akActor, bool any_state=False) Native
SkyrimNet_SexLab_Scene Function FindSceneByActorInThreadScene(Actor akActor) Native
Function UnsetThread_Scene(int tid) Native
Function EnsureThreadSceneLargeEnough(int tid) Native
String Function GetSceneSettingFilename(String setting_name) Native
String[] function GetSceneSettings() Native
SkyrimNet_SexLab_Scene_Creator Function GetCreatorBySid(int creator_sid) Native
SkyrimNet_SexLab_Scene Function GetSceneBySid(int scene_sid) Native
Function WebUI_OnYesNoResult(int creator_sid, int button) Native
Function WebUI_OnYesNoExplain(int creator_sid, String reason) Native
Function WebUI_OnSceneCreatorResult(int creator_sid, String json) Native
Function WebUI_OnSceneCreatorHandoff(String json) Native
Function WebUI_OnSceneCreatorLoad(int creator_sid, String setting_name) Native
Bool Function SceneSettingNameIsValid(String setting_name) Native
Function SaveSceneSettingFromWebUIJson(String json) Native
Function WebUI_OnSceneCreatorSave(int creator_sid, String json) Native
Function WebUI_OnAnimationMenuClose(int scene_sid, String json) Native
Function WebUI_OnAnimationMenuPrevNext(int scene_sid, int direction) Native
Function WebUI_OnAnimationMenuStop(int scene_sid, int direction) Native
Function WebUI_OnAnimationMenuLiveUpdate(int scene_sid, String json) Native
Function WebUI_PushSceneConnections() Native
String Function BuildSceneConnectionsJson() Native
Function WebUI_TakeCancelSnapshots() Native
String Function BuildAllSceneInfosJson() Native
Function WebUI_OnSceneInfoCommit(String json) Native
Function WebUI_OnSceneConnectionsRefresh(String unused) Native
Function WebUI_OnSceneConnectionChange(String json) Native
Function WebUI_OnSceneAnimUpdate(int scene_sid, String json) Native
Function WebUI_OnSceneNarrate(int scene_sid, String json) Native
Function WebUI_OnAnimRegistrySave(String json) Native
Function WebUI_OnResolveActorMeta(String json) Native
Function RegisterEventsActions() Native
Function RegisterEventsSexlab() Native
Function RestoreCameraAfterScene() Native
Function StartAnimationPoll() Native
int Function GettotalOrgasms(Actor akActor) Native
bool Function IsNoOrgasmPersisted(Actor akActor) Native
Function OrgasmCustom(Actor akActor, String msg) Native
Function SaveThreadsJson() Native
String Function GetThreadsJson(Actor speaker = None) Native
Function EnrichActorObjForJson(int actor_obj, Actor akActor) Native
Function AddStrIfNotDefined(int obj, String key_, String value) Native
String Function GetStyleDialog(String msg) global Native
bool Function IsBusy(Actor akActor) Native
