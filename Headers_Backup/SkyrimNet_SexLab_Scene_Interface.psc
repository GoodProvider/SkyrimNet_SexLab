Scriptname SkyrimNet_SexLab_Scene_Interface extends Quest
SkyrimNet_SexLab_Main Property main Auto
SkyrimNet_SexLab_AnimDb Property animdb Auto
SkyrimNet_SexLab_Scene_Manager Property manager Auto
int Property sid = 0 Auto
String Property STYLE_FORCEFULLY = "forcefully" AutoREadOnly
String Property STYLE_NORMALLY = "normally" AutoREadOnly
String Property STYLE_GENTLY = "gently" AutoREadOnly
String Property STYLE_DEFAULT = "normally" AutoREadOnly
String Property style Auto
String Property speaking_modifiers_DEFAULT = "_pleasure_" AUTOReadOnly
int Property num_victims = 0 Auto
String Property actor_names = "" Auto
String Property actor_names_json = ""Auto
String Property victim_names = ""Auto
String Property victim_names_json = ""Auto
String Property assailant_names = "" Auto
String Property creature_descriptions = "" Auto
String Property hermaphrodiate_names = "" Auto
String Property strapon_names = "" Auto
String Property STATUS_INACTIVE = "INACTIVE" AutoReadOnly
String Property STATUS_SETUP = "SETUP" AutoReadOnly
String Property STATUS_ACTIVE = "ACTIVE" AutoReadOnly
String Property status = "INACTIVE" Auto
bool property has_player = False Auto
bool property player_is_victim = False Auto
String Property intent = "sexual_activities" Auto
String Property INTENT_DEFAULT = "sexual activities" Auto
Function Trace(String func, String msg="", Bool notification=False) Native
String Function GetString() Native
Function Initialize(int _sid, SkyrimNet_SexLab_Scene_Manager _manager, bool _is_generic = false) Native
Function Release() Native
Function SetStyle(String _style) Native
String Function GetStyle() Native
bool Function IsActive() Native
bool Function TryClaim() Native
Function SetStyleDialog() Native
