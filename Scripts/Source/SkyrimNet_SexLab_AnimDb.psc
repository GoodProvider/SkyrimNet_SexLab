Scriptname SkyrimNet_SexLab_AnimDb extends Quest

import JContainers

SkyrimNet_SexLab_Main Property main Auto
SexLabFramework Property sexlab Auto

; Native bindings (SKSE)
Function AnimDb_Open() global native
int Function AnimDb_BeginSync(Bool force_rebuild) global native
int Function AnimDb_PushAnimBatch(String json) global native
Bool Function AnimDb_EndSync() global native
String Function AnimDb_QueryTopNAnims(String filter_json, int n) global native
String Function AnimDb_QueryTopNTags(String filter_json, int n) global native
int Function AnimDb_TotalEnabled() global native
int Function AnimDb_TotalCount() global native
String Function AnimDb_GetByRegistry(String registry) global native
String Function AnimDb_GetStageDescription(String registry, int stage) global native
String Function AnimDb_GetTransition(String registry, int from_stage, int to_stage) global native
String Function AnimDb_SubstituteActors(String desc, String actors_json) global native
String Function AnimDb_GetStagesJson(String registry, int stage_count, String actors_json, int current_stage) global native
Bool Function AnimDb_SaveAnimLocal(String registry, String json) global native
; synonyms: "broad" | "strict" | "none" — which synonyms-*.json clusters count as a tag match.
String Function AnimDb_ResolveTags(String tags_csv, int actor_count, String synonyms = "broad") global native
Bool Function AnimDb_CsvHasTag(String tags_csv, String tag) global native
; Per position 1 when most registries default it to clothed (tie -> 0). See Scene_Creator.ApplyMajorityClothed.
int[] Function AnimDb_ClothedMajority(String[] registries, int position_count) global native

int BATCH_SIZE = 48
int walk_index = 0
int walk_source = 0 ; 0 human, 1 creature
int walk_total = 0
Bool walk_active = False
Bool walk_force = False
String batch_json = ""

; 0 idle, 1 waiting for SexLab, 2 walking slots
int sync_phase = 0
int walk_slots_human = 0
int walk_slots_creature = 0
int walk_slots_total = 0
float progress_last_time = 0.0

; Load-time alignment prompt (does not auto-rebuild)
Bool align_check_pending = False
int align_mbox_id = 0

Function Trace(String func, String msg, Bool notification=False) global
    String logged = SkyrimNet_SexLab_WebUI.TraceLog("SkyrimNet_SexLab_AnimDb", func, msg)
    if notification
        Debug.Notification(msg)
    endif
EndFunction

Function Setup()
    if main == None
        main = (self as Quest) as SkyrimNet_SexLab_Main
    endif
    if sexlab == None && main
        sexlab = main.sexlab
    endif
    AnimDb_Open()
EndFunction

; Compare AnimDB vs SexLab after load. Never auto-rebuilds; prompts if counts differ.
Function CheckAlignmentOnLoad()
    if walk_active || sync_phase != 0 || align_mbox_id != 0
        Trace("CheckAlignmentOnLoad", "skip pending walk_active="+walk_active+" phase="+sync_phase+" mbox="+align_mbox_id)
        return
    endif
    if sexlab == None
        Trace("CheckAlignmentOnLoad", "sexlab is None", True)
        return
    endif
    align_check_pending = True
    if !sexlab.Enabled
        Trace("CheckAlignmentOnLoad", "waiting for SexLab")
        RegisterForModEvent("SexLabEnabled", "OnSexLabEnabled")
        RegisterForSingleUpdate(1.0)
        return
    endif
    RegisterForSingleUpdate(0.5)
EndFunction

int Function RefreshSlotCounts()
    walk_slots_human = 0
    walk_slots_creature = 0
    if sexlab
        if sexlab.AnimSlots
            walk_slots_human = sexlab.AnimSlots.Slotted
        endif
        sslAnimationSlots creature_slots = sexlab.CreatureSlots as sslAnimationSlots
        if creature_slots
            walk_slots_creature = creature_slots.Slotted
        endif
    endif
    walk_slots_total = walk_slots_human + walk_slots_creature
    return walk_slots_total
EndFunction

; Pushes the SexLab slot count to the WebUI (Settings counts / warning, ControlPanel Rebuild DB button).
; No Enabled gate: Slotted reads 0 until SexLab registers animations.
int Function PushSexLabCount()
    int sl_count = RefreshSlotCounts()
    SkyrimNet_SexLab_WebUI.WebUI_SetSexLabAnimCount(sl_count)
    return sl_count
EndFunction

; Strict: True only when the DB row count equals SexLab's slot count.
Bool Function IsAligned()
    int sl_count = PushSexLabCount()
    int db_count = AnimDb_TotalCount()
    Trace("IsAligned", "db_count="+db_count+" registered="+sl_count)
    return db_count == sl_count
EndFunction

; Safe to compare/prompt: no sync running, no prompt open, SexLab enabled.
Bool Function CanCheckAlignment()
    return !walk_active && sync_phase == 0 && align_mbox_id == 0 && sexlab && sexlab.Enabled
EndFunction

; Load-time prompt keeps the explained-gap exemption (unchanged pair since last sync) so loads don't nag.
Function PromptAlignmentIfNeeded()
    align_check_pending = False
    UnregisterForModEvent("SexLabEnabled")
    if IsAligned()
        return
    endif
    int db_count = AnimDb_TotalCount()
    if db_count > 0 && walk_slots_total == last_sync_slots_total && db_count == last_sync_db_count
        Trace("PromptAlignmentIfNeeded", "explained gap from last sync db_count="+db_count+" slots="+walk_slots_total)
        return
    endif
    ShowMismatchPrompt(False)
EndFunction

; First hotkey use: warn that the DB likely needs updating.
Function PromptHotkeyMismatch()
    ShowMismatchPrompt(True)
EndFunction

Function ShowMismatchPrompt(Bool likely_problem)
    int sl_count = walk_slots_total
    int db_count = AnimDb_TotalCount()
    Trace("ShowMismatchPrompt", "SkyrimNet SexLab # animations doesn't match", True)
    String[] buttons = new String[2]
    String msg
    if db_count == 0
        msg = "AnimDB is empty"
        buttons[0] = "Build AnimDB"
        buttons[1] = "Close"
    else
        msg = "AnimDB has "+db_count+", SexLab has "+sl_count
        buttons[0] = "Rebuild AnimDB"
        buttons[1] = "Close"
    endif
    if likely_problem
        msg = "There is likely a problem. " + msg + ". Update the animation database."
    endif
    align_mbox_id = SkyMessage.ShowArray_NonBlocking(msg, buttons)
    if align_mbox_id == 0
        Trace("ShowMismatchPrompt", "SkyMessage failed", True)
        return
    endif
    RegisterForSingleUpdate(0.1)
EndFunction

Function FinishAlignmentPrompt()
    if align_mbox_id == 0
        return
    endif
    if !SkyMessage.IsMessageResultAvailable(align_mbox_id)
        RegisterForSingleUpdate(0.1)
        return
    endif
    String choice = SkyMessage.GetResultText(align_mbox_id)
    align_mbox_id = 0
    if choice == "Build AnimDB" || choice == "Rebuild AnimDB"
        StartSync(True)
    else
        Trace("FinishAlignmentPrompt", "closed without rebuild choice="+choice)
    endif
EndFunction

; Kick cooperative sync after SexLab is ready. Callers must opt in (MCM / Settings / alignment prompt).
Function StartSync(Bool force_rebuild=False)
    align_check_pending = False
    if align_mbox_id != 0
        SkyMessage.Delete(align_mbox_id)
        align_mbox_id = 0
    endif
    if sync_phase != 0
        Trace("StartSync", "already walking, requesting restart force="+force_rebuild)
        walk_force = force_rebuild
        return
    endif
    if sexlab == None
        Trace("StartSync", "sexlab is None", True)
        return
    endif
    walk_force = force_rebuild
    if !sexlab.Enabled
        sync_phase = 1
        walk_active = True
        Trace("StartSync", "SkyrimNet_SexLab is waiting for SexLab", True)
        RegisterForModEvent("SexLabEnabled", "OnSexLabEnabled")
        RegisterForSingleUpdate(1.0)
        return
    endif
    BeginWalk()
EndFunction

Function BeginWalk()
    UnregisterForModEvent("SexLabEnabled")
    RefreshSlotCounts()
    if !walk_force
        int db_count = AnimDb_TotalCount()
        if db_count == walk_slots_total
            walk_active = False
            sync_phase = 0
            Trace("BeginWalk", "skip reload db_count="+db_count+" registered="+walk_slots_total)
            return
        endif
    endif
    sync_phase = 2
    walk_active = True
    walk_source = 0
    walk_index = 0
    walk_total = 0
    walk_skip_null = 0
    walk_skip_unreg = 0
    walk_skip_empty = 0
    walk_skip_logged = 0
    progress_last_time = Utility.GetCurrentRealTime()
    AnimDb_BeginSync(walk_force)
    Trace("BeginWalk", "SkyrimNet SexLab loading", True)
    RegisterForSingleUpdate(0.05)
EndFunction

Function RebuildDatabase()
    StartSync(True)
EndFunction

Event OnSexLabEnabled()
    if align_check_pending
        RegisterForSingleUpdate(0.5)
        return
    endif
    if sync_phase == 1
        BeginWalk()
    endif
EndEvent

Event OnUpdate()
    if align_mbox_id != 0
        FinishAlignmentPrompt()
        return
    endif
    if align_check_pending
        if sexlab && sexlab.Enabled
            PromptAlignmentIfNeeded()
        else
            RegisterForSingleUpdate(1.0)
        endif
        return
    endif
    if sync_phase == 1
        if sexlab && sexlab.Enabled
            BeginWalk()
        else
            RegisterForSingleUpdate(1.0)
        endif
        return
    endif
    if sync_phase != 2
        return
    endif
    sslAnimationSlots slots = None
    if walk_source == 0
        slots = sexlab.AnimSlots
    else
        slots = sexlab.CreatureSlots as sslAnimationSlots
    endif
    if !slots
        FinishSourceOrDone()
        return
    endif
    int slotted = slots.Slotted
    int batch_count = 0
    String json = "["
    Bool first = True

    while walk_index < slotted && batch_count < BATCH_SIZE
        sslBaseAnimation anim = slots.GetBySlot(walk_index)
        walk_index += 1
        if !anim
            walk_skip_null += 1
        elseif !anim.Registered
            walk_skip_unreg += 1
            LogWalkSkip("unregistered", anim)
        else
            String piece = BuildAnimJson(anim, walk_source)
            if piece != ""
                if !first
                    json += ","
                endif
                json += piece
                first = False
                batch_count += 1
                walk_total += 1
            else
                walk_skip_empty += 1
                LogWalkSkip("empty registry", anim)
            endif
        endif
    endwhile
    json += "]"

    if batch_count > 0
        AnimDb_PushAnimBatch(json)
    endif

    float now = Utility.GetCurrentRealTime()
    if now - progress_last_time >= 5.0
        progress_last_time = now
        int done = walk_index
        if walk_source == 1
            done += walk_slots_human
        endif
        int pct = 0
        if walk_slots_total > 0
            pct = done * 100 / walk_slots_total
        endif
        if pct > 99
            pct = 99
        endif
        Trace("OnUpdate", "SkyrimNet_SexLab is "+pct+"% finished", True)
    endif

    if walk_index >= slotted
        FinishSourceOrDone()
    else
        RegisterForSingleUpdate(0.01)
    endif
EndEvent

Function LogWalkSkip(String reason, sslBaseAnimation anim)
    if walk_skip_logged >= 10
        return
    endif
    walk_skip_logged += 1
    Trace("OnUpdate", "skipped ("+reason+") source="+walk_source+" name="+anim.Name+" registry="+anim.Registry)
EndFunction

Function FinishSourceOrDone()
    if walk_source == 0
        walk_source = 1
        walk_index = 0
        RegisterForSingleUpdate(0.01)
        return
    endif
    AnimDb_EndSync()
    walk_active = False
    sync_phase = 0
    int db_count = AnimDb_TotalCount()
    last_sync_slots_total = walk_slots_total
    last_sync_db_count = db_count
    Trace("FinishSourceOrDone", "total_pushed="+walk_total+" slots="+walk_slots_total+" db_rows="+db_count+" skip_null="+walk_skip_null+" skip_unregistered="+walk_skip_unreg+" skip_empty_registry="+walk_skip_empty+" duplicates="+(walk_total - db_count))
    Trace("FinishSourceOrDone", "total_pushed="+walk_total)
    Trace("FinishSourceOrDone", "SkyrimNet_SexLab is ready", True)
    IsAligned() ; push fresh counts to the Settings panel
    if walk_force
        last_rebuild_timestamp = "game day " + Utility.GetCurrentGameTime()
        SkyrimNet_SexLab_WebUI.WebUI_SetLastRebuildTimestamp(last_rebuild_timestamp)
        Bool again = walk_force
        walk_force = False
    endif
EndFunction

String Function BuildAnimJson(sslBaseAnimation anim, int source)
    if !anim
        return ""
    endif
    String registry = anim.Registry
    if registry == ""
        return ""
    endif
    String name = anim.Name
    int enabled = 0
    if anim.Enabled
        enabled = 1
    endif
    int pos_count = anim.PositionCount
    int stage_count = anim.StageCount
    int[] genders = anim.Genders
    int males = 0
    int females = 0
    int male_creatures = 0
    int female_creatures = 0
    if genders
        if genders.length > 0
            males = genders[0]
        endif
        if genders.length > 1
            females = genders[1]
        endif
        if genders.length > 2
            male_creatures = genders[2]
        endif
        if genders.length > 3
            female_creatures = genders[3]
        endif
    endif
    int has_creature = 0
    if anim.IsCreature
        has_creature = 1
    endif
    String race_type = anim.RaceType
    if !race_type
        race_type = ""
    endif

    String pos_genders = "["
    String pos_race = "["
    int i = 0
    while i < pos_count
        if i > 0
            pos_genders += ","
            pos_race += ","
        endif
        pos_genders += anim.GetGender(i)
        String rk = ""
        String[] rts = anim.GetRaceTypes()
        if rts && i < rts.length && rts[i]
            rk = rts[i]
        endif
        pos_race += "\""+EscapeJson(rk)+"\""
        i += 1
    endwhile
    pos_genders += "]"
    pos_race += "]"

    String[] tags = anim.GetRawTags()
    String tags_json = "["
    i = 0
    int ntags = 0
    if tags
        ntags = tags.length
    endif
    while i < ntags
        if i > 0
            tags_json += ","
        endif
        tags_json += "\""+EscapeJson(tags[i])+"\""
        i += 1
    endwhile
    tags_json += "]"

    return "{\"_registry\":\""+EscapeJson(registry)+"\""\
        +",\"_name\":\""+EscapeJson(name)+"\""\
        +",\"_enabled\":"+enabled\
        +",\"_source\":"+source\
        +",\"_position_count\":"+pos_count\
        +",\"_stage_count\":"+stage_count\
        +",\"_males\":"+males\
        +",\"_females\":"+females\
        +",\"_male_creatures\":"+male_creatures\
        +",\"_female_creatures\":"+female_creatures\
        +",\"_has_creature\":"+has_creature\
        +",\"_race_type\":\""+EscapeJson(race_type)+"\""\
        +",\"_pos_genders\":"+pos_genders\
        +",\"_pos_race_keys\":"+pos_race\
        +",\"_tags\":"+tags_json+"}"
EndFunction

String Function EscapeJson(String s) global
    if !s
        return ""
    endif
    ; Minimal JSON string escape without StringUtil.Replace dependency.
    String out = ""
    int i = 0
    int n = StringUtil.GetLength(s)
    while i < n
        String ch = StringUtil.GetNthChar(s, i)
        if ch == "\\"
            out += "\\\\"
        elseif ch == "\""
            out += "\\" + "\"" ; split: papyrus.exe mis-lexes "\\\"" and breaks later strings
        else
            out += ch
        endif
        i += 1
    endwhile
    return out
EndFunction

; ---- Query wrappers used by Scene / UI ----

String Function QueryTopNAnims(String filter_json, int n)
    return AnimDb_QueryTopNAnims(filter_json, n)
EndFunction

String Function QueryTopNTags(String filter_json, int n)
    return AnimDb_QueryTopNTags(filter_json, n)
EndFunction

int Function TotalEnabled()
    return AnimDb_TotalEnabled()
EndFunction

String Function GetByRegistry(String registry)
    return AnimDb_GetByRegistry(registry)
EndFunction

String Function GetStageDescription(String registry, int stage)
    return AnimDb_GetStageDescription(registry, stage)
EndFunction

String Function GetTransition(String registry, int from_stage, int to_stage)
    return AnimDb_GetTransition(registry, from_stage, to_stage)
EndFunction

String Function SubstituteActors(String desc, String actors_json)
    return AnimDb_SubstituteActors(desc, actors_json)
EndFunction

Bool Function SaveAnimLocal(String registry, String json)
    return AnimDb_SaveAnimLocal(registry, json)
EndFunction

String Function ResolveTags(String tags_csv, int actor_count, String synonyms = "broad")
    return AnimDb_ResolveTags(tags_csv, actor_count, synonyms)
EndFunction

Bool Function CsvHasTag(String tags_csv, String tag)
    return AnimDb_CsvHasTag(tags_csv, tag)
EndFunction

; ---- Replacements for former Stages APIs ----

Bool Property hide_help = false Auto
String Property last_rebuild_timestamp = "never" Auto
; Set after the first hotkey press has checked DB vs SexLab counts
Bool Property hotkey_db_checked = false Auto
; Slot/DB counts recorded after a completed sync; an unchanged pair means the gap is explained (skips/duplicates)
int Property last_sync_slots_total = 0 Auto
int Property last_sync_db_count = 0 Auto
int walk_skip_null = 0
int walk_skip_unreg = 0
int walk_skip_empty = 0
int walk_skip_logged = 0

String Function GetThreadStageDescription(sslThreadController thread, int stage_override = -1)
    if !thread || !thread.animation
        return ""
    endif
    int stage = stage_override
    if stage < 1
        stage = thread.stage
    endif
    String reg = thread.animation.Registry
    String desc = AnimDb_GetStageDescription(reg, stage)
    if desc == "" && stage > 1
        ; fall back to earlier stages like old editor
        int s = stage - 1
        while s >= 1 && desc == ""
            desc = AnimDb_GetStageDescription(reg, s)
            s -= 1
        endwhile
    endif
    if desc == ""
        return ""
    endif
    Actor[] actors = thread.Positions
    String actors_json = "["
    int i = 0
    while actors && i < actors.length
        if i > 0
            actors_json += ","
        endif
        actors_json += "\""+EscapeJson(actors[i].GetDisplayName())+"\""
        i += 1
    endwhile
    actors_json += "]"
    return AnimDb_SubstituteActors(desc, actors_json)
EndFunction

; All stages of the thread's animation as a JSON array [{_stage,_template,_preview,_current}].
; One native call replaces the per-stage GetStageDescription + GetThreadStageDescription loop.
String Function GetThreadStagesJson(sslThreadController thread, int stage_count)
    if !thread || !thread.animation || stage_count < 1
        return "[]"
    endif
    Actor[] actors = thread.Positions
    String actors_json = "["
    int i = 0
    while actors && i < actors.length
        if i > 0
            actors_json += ","
        endif
        actors_json += "\""+EscapeJson(actors[i].GetDisplayName())+"\""
        i += 1
    endwhile
    actors_json += "]"
    return AnimDb_GetStagesJson(thread.animation.Registry, stage_count, actors_json, thread.stage)
EndFunction

String Function GetThreadTransition(sslThreadController thread, int from_stage, int to_stage)
    if !thread || !thread.animation || from_stage < 1 || to_stage < 1
        return ""
    endif
    String reg = thread.animation.Registry
    String text = AnimDb_GetTransition(reg, from_stage, to_stage)
    if text == ""
        return ""
    endif
    Actor[] actors = thread.Positions
    String actors_json = "["
    int i = 0
    while actors && i < actors.length
        if i > 0
            actors_json += ","
        endif
        actors_json += "\""+EscapeJson(actors[i].GetDisplayName())+"\""
        i += 1
    endwhile
    actors_json += "]"
    return AnimDb_SubstituteActors(text, actors_json)
EndFunction

int[] Function GetOrgasmExpected(sslThreadController thread)
    Actor[] actors = thread.Positions
    int n = 0
    if actors
        n = actors.length
    endif
    int[] out = Utility.CreateIntArray(n, 1)
    if !thread || !thread.animation || n < 1
        return out
    endif
    String row = AnimDb_GetByRegistry(thread.animation.Registry)
    if row == ""
        return out
    endif
    int obj = JValue.objectFromPrototype(row)
    if obj == 0
        return out
    endif
    int no_arr = JMap.getObj(obj, "_pos_no_orgasm")
    if no_arr == 0
        JValue.release(obj)
        return out
    endif
    int count = JArray.count(no_arr)
    int i = 0
    while i < n
        int no_org = 0
        if i < count
            no_org = JArray.getInt(no_arr, i)
        endif
        out[i] = 1 - no_org
        i += 1
    endwhile
    JValue.release(obj)
    return out
EndFunction

; Canonical default speaking_modifiers from orgasm_expected (missing JSON / SceneCreator).
String Function SpeakingDefaultFromOrgasmExpected(int orgasm_expected) global
    if orgasm_expected == 1
        return "_pleasure_"
    endif
    return ""
EndFunction

; Per-position speaking from AnimDB row (prefer resolved stage map); empty slots filled via SpeakingDefaultFromOrgasmExpected.
String[] Function GetSpeakingModifiers(sslThreadController thread)
    Actor[] actors = thread.Positions
    int n = 0
    if actors
        n = actors.length
    endif
    String[] out = Utility.CreateStringArray(n)
    int[] orgasm = GetOrgasmExpected(thread)
    int i = 0
    while i < n
        int expected = 1
        if orgasm && i < orgasm.length
            expected = orgasm[i]
        endif
        out[i] = SpeakingDefaultFromOrgasmExpected(expected)
        i += 1
    endwhile
    if !thread || !thread.animation
        return out
    endif
    String row = AnimDb_GetByRegistry(thread.animation.Registry)
    if row == ""
        return out
    endif
    int obj = JValue.objectFromPrototype(row)
    if obj == 0
        return out
    endif
    int speak_arr = 0
    int stage_map = JMap.getObj(obj, "_stage_speaking")
    if stage_map != 0
        int stage = thread.stage
        if stage < 1
            stage = 1
        endif
        speak_arr = JMap.getObj(stage_map, stage as string)
        if speak_arr == 0
            speak_arr = JMap.getObj(stage_map, ""+stage)
        endif
    endif
    if speak_arr == 0
        speak_arr = JMap.getObj(obj, "_pos_speaking_modifiers")
    endif
    if speak_arr == 0
        speak_arr = JMap.getObj(obj, "speaking_modifiers")
    endif
    if speak_arr != 0
        i = 0
        while i < n && i < JArray.count(speak_arr)
            out[i] = JArray.getStr(speak_arr, i, out[i])
            i += 1
        endwhile
    endif
    JValue.release(obj)
    return out
EndFunction

; Per-position clothed (1=dressed) from AnimDB JSON; default 0 when missing.
int[] Function GetClothed(sslThreadController thread)
    Actor[] actors = thread.Positions
    int n = 0
    if actors
        n = actors.length
    endif
    int[] out = Utility.CreateIntArray(n, 0)
    if !thread || !thread.animation
        return out
    endif
    String row = AnimDb_GetByRegistry(thread.animation.Registry)
    if row == ""
        return out
    endif
    int obj = JValue.objectFromPrototype(row)
    if obj == 0
        return out
    endif
    int clothed_arr = JMap.getObj(obj, "_clothed")
    if clothed_arr == 0
        clothed_arr = JMap.getObj(obj, "clothed")
    endif
    if clothed_arr != 0
        int i = 0
        while i < n && i < JArray.count(clothed_arr)
            out[i] = JArray.getInt(clothed_arr, i, 0)
            i += 1
        endwhile
    endif
    JValue.release(obj)
    return out
EndFunction

bool[] Function GetHasDescriptionOrgasmExpected(sslThreadController thread)
    Actor[] actors = thread.Positions
    int n = 0
    if actors
        n = actors.length
    endif
    bool[] out = Utility.CreateBoolArray(n, false)
    if !thread || !thread.animation
        return out
    endif
    String row = AnimDb_GetByRegistry(thread.animation.Registry)
    if row == ""
        return out
    endif
    int obj = JValue.objectFromPrototype(row)
    if obj == 0
        return out
    endif
    int has_arr = JMap.getObj(obj, "_stage_has_description")
    int stage = thread.stage
    bool has_desc = false
    if has_arr != 0 && stage >= 1 && stage <= JArray.count(has_arr)
        has_desc = JArray.getInt(has_arr, stage - 1) == 1
    endif
    int[] orgasm = GetOrgasmExpected(thread)
    int i = 0
    while i < n
        out[i] = has_desc && orgasm[i] == 1
        i += 1
    endwhile
    JValue.release(obj)
    return out
EndFunction
