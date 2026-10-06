Scriptname SkyrimNet_SexLab_MCM extends SKI_ConfigBase
SkyrimNet_SexLab_Main Property main Auto
SkyrimNet_SexLab_AnimDb Property animdb Auto
SkyrimNet_SexLab_Scene_Manager Property manager Auto
SkyrimNet_SexLab_Actions Property actions Auto
SkyrimNet_SexLab_Menu Property menu Auto
GlobalVariable Property skyrimnet_sexlab_ostim_player Auto
int Property sexlab_ostim_player AutoReadonly
int Function Get() Native
Function Set(int value) Native
GlobalVariable Property sexlab_public_sex_accepted Auto
GlobalVariable Property skyrimnet_sexlab_hide_hermaphrodites Auto
String[] Property sexlab_ostim_options Auto
bool Property udng_found = false Auto
bool Property leashed_found = false Auto
Function Trace(String func, String msg, Bool notification=False) global Native
Function Setup() Native
Bool Function Setup_CheckLinks() Native
Function ApplyPluginConfig() Native
Function ApplyRapeActions() Native
Function ApplyMiniGameActions() Native
Function ApplyHotkey() Native
Function PageOptions() Native
