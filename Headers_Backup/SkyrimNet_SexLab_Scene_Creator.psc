Scriptname SkyrimNet_SexLab_Scene_Creator extends SkyrimNet_SexLab_Scene_Interface
SexLabFramework Property sexlab Auto
int Property num_actors = 0 Auto
Actor[] Property actors Auto
Actor[] Property victims Auto
int[] Property no_orgasm_mask Auto
int[] Property no_stripping_mask Auto
String Property speaking_modifiers_default_current = "_pleasure_" AUTO
String[] Property speaking_modifiers AUTO
bool Property scene_creator_menu_called = false Auto
bool Property position_override = false Auto
Function Trace(String func, String msg="", Bool notification=False) Native
Function DbgEnter(String func, String msg="") Native
Function DbgReturn(String func, String reason="") Native
Function DbgEnd(String func) Native
Function DbgMsg(String func, String msg) Native
String Function GetString() Native
Function Initialize(int _sid, SkyrimNet_SexLab_Scene_Manager _manager, bool _is_generic = false) Native
Bool Function Setup(String _intent, Actor[] _actors, Actor _speaker, Actor _target, String _tags="", String setting_name="") Native
Bool Function Setup_CheckLinks() Native
Function Release() Native
Bool Function TryOpenSceneCreatorMenu() Native
SkyrimNet_SexLab_Scene Function StartScene() Native
SkyrimNet_SexLab_Scene Function FinishStartScene(sslBaseAnimation[] animations) Native
Function ApplyMajorityClothed(sslThreadModel model, sslBaseAnimation[] animations) Native
Function RealignActorMasksFromPositions(Actor[] positions) Native
Function EnsureActorsArraysLargeEnough(int size) Native
Function ShiftActorsLeft() Native
Function SetMasks() Native
Function SetNames() Native
Function RebuildVictimsFromMask() Native
Function SetVictim(Actor victim) Native
Function SetVictims(Actor[] _victims) Native
Function SetMethod(String _method) Native
String Function RemapTag(String tag) Native
Function RemapAllTags() Native
function SetTag(String tag) Native
function SetTagSuppress(String tag) Native
function AddTag(String tag) Native
function AddTagSuppress(String tag) Native
function SetTags(String[] _tags) Native
function SetTagsSuppress(String[] _tags_suppress) Native
Function SetTags_Helper(bool is_tags, String[] _tags) Native
Function SetStyle(String _style) Native
String Function GetStyle() Native
Function SetEventHook(String _event_hook) Native
Actor Function GetSpeaker() Native
Actor Function GetTarget() Native
Function LoadSetting(String setting_name) Native
bool Function EnsureSexLabActorsValid() Native
bool Function LockAllActorLock() Native
Function UnLockAllActorLock() Native
Bool Function IsActorLocked(Actor akActor) Native
bool Function LockActorLock(Actor akActor) Native
Function UnlockActorLock(Actor akActor) Native
String Function BuildYesNoQuestion() Native
Function ContinueAfterYesNo(int button) Native
Function RejectWithReason(String reason) Native
Function ContinueAfterSceneCreator(String json) Native
int Function BuildWebUIObject() Native
String Function BuildWebUIState() Native
Function ApplyWebUIState(int obj) Native
Function ReadSettingFlags(String setting_name) Native
Function LoadPresetFromWebUI(String setting_name) Native
Function SavePresetFromWebUI(String json) Native
Function SaveSetting(String setting_name) Native
sslBaseAnimation[] Function ResolveAnimationsFromUI() Native
sslBaseAnimation[] Function ResolveAnimationsFromTags() Native
int function YesNoDialog() Native
sslBaseAnimation[] Function SelectAnimations() Native
bool Function HasAnimList(sslBaseAnimation[] anims) Native
sslBaseAnimation[] Function SelectAnimationsFromAnimDb() Native
sslBaseAnimation[] Function QuerySexLabAnimsFromAnimDb(int mustCount, int suppressCount) Native
sslBaseAnimation[] Function SelectAnimationsDialog() Native
Function AddGroupTags(uilistMenu listMenu, int group_tags, String group) Native
String Function GroupDialog(int group_tags, String group) Native
