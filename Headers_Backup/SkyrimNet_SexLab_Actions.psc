Scriptname SkyrimNet_SexLab_Actions extends Quest
SkyrimNet_SexLab_Main Property main Auto
SkyrimNet_SexLab_Scene_Manager Property manager Auto
SexLabFramework Property sexlab Auto
Idle Property pa_HugA Auto
Function Trace(String func, String msg, Bool notification=False) global Native
Function Setup() Native
Bool Function Setup_CheckLinks() Native
Bool Function StartScene_Consensual_One(String intent, Actor speaker, string style="", String method="", String setting_name="") Native
Bool Function StartScene_Nonconsensual_One(String intent, Actor speaker, string style="", String method="", String setting_name="") Native
Bool Function StartScene_Consensual_Two(String intent, Actor speaker, Actor target, string style="", string method="", String direction="", String setting_name="") Native
Bool Function StartScene_Nonconsensual_Two(String intent, Actor speaker, Actor target=None, Actor victim,string style="", string method="", String direction="", String setting_name="") Native
Bool Function StartScene_Nonconsensual_Two_SpeakerVictim(String intent, Actor speaker, Actor target, string style="", string method="", String direction="", String setting_name="") Native
Bool Function StartScene_Nonconsensual_Two_TargetVictim(String intent, Actor speaker, Actor target, string style="", string method="", String direction="", String setting_name="") Native
Bool Function StartScene_Consensual_Three(String intent, Actor speaker, Actor target, string style="", string method="", String direction="", String setting_name="", Actor participate) Native
Bool Function StartScene_Nonconsensual_Three(String intent, Actor speaker, Actor target, Actor victim, string style="", string method="", String direction="", String setting_name="", Actor participate) Native
Function SceneStop(Actor speaker, String style) Native
Function SceneStop_Target(Actor speaker, Actor target, String style) Native
Function SceneChangeStyle(Actor speaker, String style) Native
Function StartScene_Refused_Two(String intent, Actor speaker, Actor target, string style="", string method="", string direction="") Native
Function SceneStop_Event(Actor speaker, Actor target, String style) Native
Bool Function StartScene_Event(String intent, Actor speaker, Actor target=None, Actor victim=None,      string style="", string tags="", String direction="", String event_hook="", String setting_name="",     Actor participate_3=None) Native
Bool Function IsHugGiverPose(String intent, String tags) Native
Bool Function CalmForPairedIdle(Actor akActor) Native
Function Outfit_Narrate(Actor Speaker, Actor Target, String style, String token, String narration) Native
Function Outfit_RefreshWebUI(Actor Target) Native
Function Outfit_Dress(Actor Speaker, Actor Target, String style, String narration) Native
Function Outfit_Undress(Actor Speaker, Actor Target, String style, String narration) Native
bool Function BodyAnimation_IsEligible(Actor akActor, string contextJson, string paramsJson) Native
Function TM_Outfit(Actor speaker, Actor target, String style) Native
Function TM_SceneOutfit(Actor speaker, Actor target, String style, String how) Native
Function TM_StopSilent(Actor speaker, Actor target) Native
Function TM_Stop(Actor speaker, Actor target) Native
Function TM_StopExplain(Actor speaker, Actor target, String narration) Native
Function TM_StagePrev(Actor speaker, Actor target) Native
Function TM_StageNext(Actor speaker, Actor target) Native
Function TM_GoToStage(Actor speaker, Actor target, String stageStr) Native
Function TM_SetStageDescription(Actor speaker, Actor target, String stageStr, String description) Native
Function TM_RotatePositions(Actor speaker, Actor target) Native
Function TM_ChangeActors(Actor speaker, Actor target, String formIdsCsv) Native
Function TM_SetAnimationIndex(Actor speaker, Actor target, String indexStr) Native
Function TM_SyncSceneState(Actor speaker, Actor target) Native
Function TM_SetVictim(Actor speaker, Actor target, String formIdStr, String isVictimStr) Native
Function TM_SetOrgasmMode(Actor speaker, Actor target, String formIdStr, String mode) Native
Function TM_ForceOrgasm(Actor speaker, Actor target, String formIdStr) Native
Function MiniGame_Arouse(Actor speaker, Actor target) Native
Function MiniGame_Calm(Actor speaker, Actor target) Native
Function MiniGame_Act(Actor speaker, Actor target, bool arouse) Native
Function LLM_DenyOrgasm(Actor speaker, Actor target) Native
Function LLM_AllowOrgasm(Actor speaker, Actor target) Native
Function LLM_SetDenyOrgasm(Actor speaker, Actor target, bool deny) Native
Function TM_SetSpeaking(Actor speaker, Actor target, String formIdStr, String speaking) Native
Function TM_SetClothed(Actor speaker, Actor target, String formIdStr, String clothedStr) Native
Function TM_SaveAnimationSettings(Actor speaker, Actor target) Native
