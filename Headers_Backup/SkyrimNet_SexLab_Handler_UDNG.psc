Scriptname SkyrimNet_SexLab_Handler_UDNG extends Quest
Function Trace(String func, String msg, Bool notification=False) global Native
Function Setup() Native
Bool Function Setup_CheckLinks() Native
Bool Function EnsureReady() Native
Function OpenMenu(Actor target) Native
String Function DeviceStr(int device, String key1, String key2) Native
String Function DeviceIdOf(int device) Native
String Function DeviceNameOf(int device) Native
int Function HexToInt(String s) Native
Armor Function ArmorFromWantedId(String wantedId) Native
Keyword Function DeviceKeywordOf(int device) Native
Bool Function DeviceIsWorn(Actor target, int device) Native
int Function WornDeviceInGroup(Actor target, int devices) Native
int Function FindDeviceById(int devices, String deviceId) Native
Function AddKeys(Actor target, Key z_key, int num) Native
Function ReleaseAll() Native
int Function SessionOf(Actor target) Native
Function EnsureSession(Actor target) Native
int Function BondageWantedMap(int payload) Native
int Function BondageOriginalMap(int payload) Native
String Function OriginalIdForGroup(int origMap, int session, int index, String gname) Native
Function PushBondageState(Actor target) Native
Function TM_BondageRefresh(Actor target) Native
String Function OriginalIdAt(int session, int index) Native
String Function CurrentIdForGroup(int wantedMap, String groupName, String fallback) Native
Bool Function UnlockWornInGroup(Actor target, int devices) Native
Bool Function SetGroupToId(Actor target, int devices, String wantedId) Native
Function TM_BondageApply(Actor target, String deviceId) Native
Function TM_BondageOnWebUIClosed() Native
Function TM_BondageFinish(Actor speaker, Actor target, String style, String currentJson) Native
String Function GetDisplayNameSafe(Actor a) Native
