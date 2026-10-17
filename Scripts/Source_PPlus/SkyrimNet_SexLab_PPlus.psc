Scriptname SkyrimNet_SexLab_PPlus

; SexLab P+ bridge: every call into the P+ API (SexlabRegistry, SexLabThread, sslThreadModel P+ functions,
; sslAnimationSlots.CreateProxyArray) lives here. Compiled by skyrimse-pplus.ppj against the P+ sources; the main
; project compiles against SexLab 1.6x and sees Headers_Source/SkyrimNet_SexLab_PPlus.psc (same signatures, empty
; bodies). Keep both files' signatures identical. Call only when SkyrimNet_SexLab_Utilities.IsSexLabPPlus().
;
; Two stage numberings (docs/developers/sexlab-pplus.md):
;   legacy  = GetAllStages(scene).Find(stage) + 1 of GetNumStages(scene): narration, AnimDB, stage keys, editor.
;   path    = GetStageHistory() + GetPathMax(scene_id, active)[1..]: index = history length, count = path length,
;             equal exactly at a sink. Orgasm engine only.

Function Trace(String func, String msg) global
    SkyrimNet_SexLab_WebUI.TraceLog("SkyrimNet_SexLab_PPlus", func, msg)
EndFunction

sslThreadModel Function Model(Quest thread) global
    return thread as sslThreadModel
EndFunction

; ---- Scene / stage identity ----
String Function ActiveScene(Quest thread) global
    sslThreadModel t = Model(thread)
    if t == None
        return ""
    endif
    return t.GetActiveScene()
EndFunction

String Function ActiveStage(Quest thread) global
    sslThreadModel t = Model(thread)
    if t == None
        return ""
    endif
    return t.GetActiveStage()
EndFunction

String[] Function StageHistory(Quest thread) global
    sslThreadModel t = Model(thread)
    if t == None
        return Utility.CreateStringArray(0)
    endif
    return t.GetStageHistory()
EndFunction

int Function LegacyStage(Quest thread) global
    sslThreadModel t = Model(thread)
    if t == None
        return 0
    endif
    return t.GetLegacyStageNum()
EndFunction

int Function LegacyStageCount(Quest thread) global
    sslThreadModel t = Model(thread)
    if t == None
        return 0
    endif
    return t.GetLegacyStagesCount()
EndFunction

; Outgoing edges of the active stage; 0 at a sink.
int Function NumBranches(Quest thread) global
    sslThreadModel t = Model(thread)
    if t == None
        return 0
    endif
    return SexLabRegistry.GetNumBranches(t.GetActiveScene(), t.GetActiveStage())
EndFunction

; ---- Orgasm engine path ----
; Played history (active stage last) + the longest path from the active stage to a sink.
String[] Function ProjectedPath(Quest thread) global
    sslThreadModel t = Model(thread)
    if t == None
        return Utility.CreateStringArray(0)
    endif
    String scene_id = t.GetActiveScene()
    String active = t.GetActiveStage()
    String[] hist = t.GetStageHistory()
    String[] rest = SexLabRegistry.GetPathMax(scene_id, active)
    ; GetPathMax is [active, ..., sink]; skip its first entry when it is the active stage.
    int skip = 0
    if rest.Length > 0 && rest[0] == active
        skip = 1
    endif
    int n = hist.Length + rest.Length - skip
    String[] path = Utility.CreateStringArray(n)
    int i = 0
    while i < hist.Length
        path[i] = hist[i]
        i += 1
    endwhile
    int j = skip
    while j < rest.Length
        path[i] = rest[j]
        i += 1
        j += 1
    endwhile
    return path
EndFunction

; Seconds per path node by P+'s own rule (sslThreadModel GetTimer / GetStageTimer): a fixed-length stage plays
; its fixed length; a climax stage takes the last timer; else Timers[history length] up to Timers[len - 2].
float[] Function StageSeconds(Quest thread, String[] path, float[] timers) global
    sslThreadModel t = Model(thread)
    float[] secs = Utility.CreateFloatArray(path.Length)
    if t == None
        return secs
    endif
    String scene_id = t.GetActiveScene()
    int last_idx = timers.Length - 2
    if last_idx < 0
        last_idx = 0
    endif
    int i = 0
    while i < path.Length
        float fixed = SexLabRegistry.GetFixedLength(scene_id, path[i])
        if fixed > 0.0
            secs[i] = fixed
        elseif timers.Length > 0
            if SexLabRegistry.GetClimaxingActors(scene_id, path[i]).Length > 0
                secs[i] = timers[timers.Length - 1]
            elseif i + 1 < last_idx
                secs[i] = timers[i + 1]
            else
                secs[i] = timers[last_idx]
            endif
        endif
        i += 1
    endwhile
    return secs
EndFunction

float Function ActiveFixedLength(Quest thread) global
    sslThreadModel t = Model(thread)
    if t == None
        return 0.0
    endif
    return SexLabRegistry.GetFixedLength(t.GetActiveScene(), t.GetActiveStage())
EndFunction

; ---- Navigation ----
Function SkipTo(Quest thread, String stage) global
    sslThreadModel t = Model(thread)
    if t == None || stage == ""
        return
    endif
    t.SkipTo(stage)
EndFunction

; Jump to legacy stage n (1-based position in GetAllStages). False when out of range.
bool Function SkipToLegacy(Quest thread, int n) global
    sslThreadModel t = Model(thread)
    if t == None
        return false
    endif
    String[] stages = SexLabRegistry.GetAllStages(t.GetActiveScene())
    if n < 1 || n > stages.Length
        return false
    endif
    if stages[n - 1] == t.GetActiveStage()
        return true
    endif
    Trace("SkipToLegacy", "stage "+n+" -> "+stages[n - 1])
    t.SkipTo(stages[n - 1])
    return true
EndFunction

; Jump to the sink at the end of path (fallback: the scene's first ending stage). False when already there / none.
bool Function SkipToSink(Quest thread, String[] path) global
    sslThreadModel t = Model(thread)
    if t == None
        return false
    endif
    String target = ""
    if path.Length > 0
        target = path[path.Length - 1]
    endif
    if target == ""
        String[] endings = SexLabRegistry.GetEndingStages(t.GetActiveScene())
        if endings.Length > 0
            target = endings[0]
        endif
    endif
    if target == "" || target == t.GetActiveStage()
        return false
    endif
    Trace("SkipToSink", t.GetActiveStage()+" -> "+target)
    t.SkipTo(target)
    return true
EndFunction

; Plays scene_id instead of the active one (history reset, actors re-sorted). False when invalid for these actors.
bool Function ResetScene(Quest thread, String scene_id) global
    sslThreadModel t = Model(thread)
    if t == None || scene_id == ""
        return false
    endif
    bool ok = t.ResetScene(scene_id)
    Trace("ResetScene", scene_id+" ok:"+ok)
    return ok
EndFunction

; Holds the stage timer (the P+ way: UpdateTimer would set _ForceAdvance).
Function PauseTimer(Quest thread, bool pause) global
    sslThreadModel t = Model(thread)
    if t == None
        return
    endif
    t.PauseTimer(pause)
EndFunction

; Cum id (sslObjectFactory: 1 vaginal 2 oral 3 anal 4 V+O 5 V+A 6 O+A 7 all) for position in the active stage. P+
; GetCumID is always 0: derive it from the stage's tags, for a receiving position only (one that can be filled by a
; female or female creature). 0 = none.
int Function CumId(Quest thread, int position) global
    sslThreadModel t = Model(thread)
    if t == None
        return 0
    endif
    String scene_id = t.GetActiveScene()
    String stage = t.GetActiveStage()
    int flags = SexLabRegistry.GetPositionSex(scene_id, position)
    if Math.LogicalAnd(flags, 0x12) == 0
        return 0
    endif
    bool v = SexLabRegistry.IsStageTag(scene_id, stage, "Vaginal")
    bool o = SexLabRegistry.IsStageTag(scene_id, stage, "Oral") || SexLabRegistry.IsStageTag(scene_id, stage, "Blowjob")
    bool a = SexLabRegistry.IsStageTag(scene_id, stage, "Anal")
    if v && o && a
        return 7
    elseif o && a
        return 6
    elseif v && a
        return 5
    elseif v && o
        return 4
    elseif a
        return 3
    elseif o
        return 2
    elseif v
        return 1
    endif
    return 0
EndFunction

; ---- Consent ----
; false adds the "Aggressive" context (thread.IsAggressive); SetVictim alone does not.
Function SetConsent(Quest thread, bool consent) global
    sslThreadModel t = Model(thread)
    if t == None
        return
    endif
    t.SetConsent(consent)
EndFunction

; ---- Registry ----
String Function SceneName(String id) global
    return SexLabRegistry.GetSceneName(id)
EndFunction

bool Function SceneEnabled(String id) global
    return SexLabRegistry.IsSceneEnabled(id)
EndFunction

String[] Function SceneTags(String id) global
    return SexLabRegistry.GetSceneTags(id)
EndFunction

bool Function SceneHasTag(String id, String tag) global
    return SexLabRegistry.IsSceneTag(id, tag)
EndFunction

String[] Function StageTags(String id, String stage) global
    return SexLabRegistry.GetStageTags(id, stage)
EndFunction

int Function ActorCount(String id) global
    return SexLabRegistry.GetActorCount(id)
EndFunction

int Function NumStages(String id) global
    return SexLabRegistry.GetNumStages(id)
EndFunction

; Per position, 1.6x GetGender coding: 0 male (or futa), 1 female, 2 male creature, 3 female creature.
; GetPositionSexA is a bit flag per position: Male 0x1 | Female 0x2 | Futa 0x4 | CrtMale 0x8 | CrtFemale 0x10.
int[] Function PositionGenders(String id) global
    int[] flags = SexLabRegistry.GetPositionSexA(id)
    int[] out = Utility.CreateIntArray(flags.Length)
    int i = 0
    while i < flags.Length
        int f = flags[i]
        bool human = Math.LogicalAnd(f, 0x7) != 0
        if human
            if Math.LogicalAnd(f, 0x5) == 0
                out[i] = 1
            else
                out[i] = 0
            endif
        elseif Math.LogicalAnd(f, 0x8) == 0 && Math.LogicalAnd(f, 0x10) != 0
            out[i] = 3
        else
            out[i] = 2
        endif
        i += 1
    endwhile
    return out
EndFunction

; Per position race key; "" for humans (this mod's convention).
String[] Function PositionRaceKeys(String id) global
    String[] keys = SexLabRegistry.GetRaceKeyPositionA(id)
    int i = 0
    while i < keys.Length
        if keys[i] == "humans" || keys[i] == "Humans"
            keys[i] = ""
        endif
        i += 1
    endwhile
    return keys
EndFunction

; Every registered scene id (no proxy alias cap). creature: 0 humans only, 1 creatures only.
String[] Function AllSceneIds(int creature) global
    String[] ids = sslAnimationSlots.CreateProxyArray(0, creature)
    ; DEBUG-DELETE(pplus-animdb)
    if ids.Length == 0
        Trace("AllSceneIds", "DEBUG creature="+creature+" CreateProxyArray returned 0 ids")
    else
        Trace("AllSceneIds", "DEBUG creature="+creature+" ids="+ids.Length+" first='"+ids[0]+"'")
    endif
    ; DEBUG-DELETE(pplus-animdb) end
    return ids
EndFunction

; DEBUG-DELETE(pplus-animdb): one line describing a scene as SexlabRegistry reports it (raw GetPositionSexA flags, race keys, tags).
String Function SceneDebug(String id) global
    int[] flags = SexLabRegistry.GetPositionSexA(id)
    String[] keys = SexLabRegistry.GetRaceKeyPositionA(id)
    String[] tags = SexLabRegistry.GetSceneTags(id)
    String out = "id='"+id+"' name='"+SexLabRegistry.GetSceneName(id)+"' enabled="+SexLabRegistry.IsSceneEnabled(id)
    out += " actors="+SexLabRegistry.GetActorCount(id)+" stages="+SexLabRegistry.GetNumStages(id)+" sex_flags=["
    int i = 0
    while i < flags.Length
        if i > 0
            out += ","
        endif
        out += flags[i]
        i += 1
    endwhile
    out += "] race_keys=["
    i = 0
    while i < keys.Length
        if i > 0
            out += ","
        endif
        out += keys[i]
        i += 1
    endwhile
    out += "] tags="+tags.Length
    return out
EndFunction
; DEBUG-DELETE(pplus-animdb) end

; ---- Actors ----
; 1.6x GetGender coding from P+ GetSex (0 male, 1 female, 2 futa, 3 creature male, 4 creature female):
; futa -> 0 (has a penis; base sex still gives the pussy), creatures -> 2 / 3.
int Function LegacyGender(Actor akActor) global
    if akActor == None
        return 0
    endif
    int sex = SexLabRegistry.GetSex(akActor, false)
    if sex == 1
        return 1
    elseif sex == 3
        return 2
    elseif sex == 4
        return 3
    endif
    return 0
EndFunction

bool Function IsFuta(Actor akActor) global
    if akActor == None
        return false
    endif
    return SexLabRegistry.GetSex(akActor, false) == 2
EndFunction
