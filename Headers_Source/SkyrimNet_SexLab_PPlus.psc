Scriptname SkyrimNet_SexLab_PPlus

; HEADER ONLY (main project, SexLab 1.6x headers). The real script is Scripts/Source_PPlus/SkyrimNet_SexLab_PPlus.psc,
; compiled by skyrimse-pplus.ppj against the P+ sources. Keep signatures identical; bodies here are never compiled
; into Scripts/. Call only when SkyrimNet_SexLab_Utilities.IsSexLabPPlus().

Function Trace(String func, String msg) global
EndFunction

String Function ActiveScene(Quest thread) global
    return ""
EndFunction
String Function ActiveStage(Quest thread) global
    return ""
EndFunction
String[] Function StageHistory(Quest thread) global
    return None
EndFunction
int Function LegacyStage(Quest thread) global
    return 0
EndFunction
int Function LegacyStageCount(Quest thread) global
    return 0
EndFunction
int Function NumBranches(Quest thread) global
    return 0
EndFunction

String[] Function ProjectedPath(Quest thread) global
    return None
EndFunction
float[] Function StageSeconds(Quest thread, String[] path, float[] timers) global
    return None
EndFunction
float Function ActiveFixedLength(Quest thread) global
    return 0.0
EndFunction

Function SkipTo(Quest thread, String stage) global
EndFunction
bool Function SkipToLegacy(Quest thread, int n) global
    return false
EndFunction
bool Function SkipToSink(Quest thread, String[] path) global
    return false
EndFunction
bool Function ResetScene(Quest thread, String scene_id) global
    return false
EndFunction
Function PauseTimer(Quest thread, bool pause) global
EndFunction

int Function CumId(Quest thread, int position) global
    return 0
EndFunction

Function SetConsent(Quest thread, bool consent) global
EndFunction

String Function SceneName(String id) global
    return ""
EndFunction
bool Function SceneEnabled(String id) global
    return false
EndFunction
String[] Function SceneTags(String id) global
    return None
EndFunction
bool Function SceneHasTag(String id, String tag) global
    return false
EndFunction
String[] Function StageTags(String id, String stage) global
    return None
EndFunction
int Function ActorCount(String id) global
    return 0
EndFunction
int Function NumStages(String id) global
    return 0
EndFunction
int[] Function PositionGenders(String id) global
    return None
EndFunction
String[] Function PositionRaceKeys(String id) global
    return None
EndFunction
String[] Function AllSceneIds(int creature) global
    return None
EndFunction
String Function SceneDebug(String id) global ; DEBUG-DELETE(pplus-animdb)
    return ""
EndFunction

int Function LegacyGender(Actor akActor) global
    return 0
EndFunction
bool Function IsFuta(Actor akActor) global
    return false
EndFunction
