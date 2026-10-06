Scriptname SkyrimNet_SexLab_Menu extends Quest
SkyrimNet_SexLab_MCM Property mcm Auto
SkyrimNet_SexLab_Main Property main Auto
SkyrimNet_SexLab_AnimDb Property animdb Auto
SkyrimNet_SexLab_Scene_Manager Property manager Auto
SkyrimNet_SexLab_Actions Property actions Auto
Function Trace(String func, String msg, Bool notification=False) global Native
Function OpenSkyrimNetDashboard() Native
Function Setup() Native
Bool Function Setup_CheckLinks() Native
Function ProcessHotkey(int key_code) Native
Function Hud_OnKey(String control, Actor focus = None) Native
Function Open_WebUI_Target(Actor target) Native
Function WebUI_OnControlActorFocus(Actor target) Native
Function WebUI_ConfigureFocusScene() Native
Function WebUI_SeedSceneInfos() Native
Function Target_Menu_Selection(Actor target, Actor player) Native
Function EventSend_OstimNet(String type, Actor speaker, Actor target, String tag) Native
Function EventSend_UDNG(String type, Actor target) Native
Function EventSend_LeashedOpen() Native
Function MultiTarget_Menu_Selection(Actor player) Native
String Function SexRapeSelection(String current) Native
bool Function IsAvailableActor(Actor akActor) Native
Function WebUI_PushAvailableNearby(String formIdCsv) Native
