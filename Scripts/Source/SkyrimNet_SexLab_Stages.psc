Scriptname SkyrimNet_SexLab_Stages extends Quest 

import SkyrimNet_SexLab_Main
import StorageUtil

Bool Property hide_help = false Auto

Actor player = None 

String Property animations_folder = "Data/SKSE/Plugins/SkyrimNet_SexLab/animations" Auto
String Property local_folder =      "" Auto

String VERSION_1_0 = "1.0"
String VERSION_2_0 = "2.0"

String desc_input = "" 

String tracking_db = ""

int tracking_thread_id = 0

String Button_Ok = "Ok"
String Button_Cancel = "Cancel"
String Button_Next = "Next"
String Button_Previo8us = "Previous"
String Button_Acttept = "Accept"
String Button_Rewrite = "Rewrite"
String Button_Retry = "Retry"
String Button_Never_Show_Again = "Never Show Again"
String Button_orgasm_expected = "Orgasm Expected"
String Button_Stop_Tracking = "Stop Tracking"
String Button_Start_Tracking = "Start Tracking"
String Button_Go_Back = "Go Back"
String Button_Done = "Done"

String storage_key = "skyrimnet_sexlab_stages_anim_info"

int anim_info_cache = 0

; Devious Devices
bool devices_found = false 
Keyword Property zad_DeviousBelt Auto

Function Trace(String func, String msg, Bool notification=False) global

    msg = "[SkyrimNet_SexLab_Stages."+func+"] "+msg
    Debug.Trace(msg)
    if notification
        Debug.Notification(msg)
    endif 
EndFunction

Function Setup()
    String temp = "sl" ; attempt to set the caplitiization of sl 

    ; Devious Devices
    if MiscUtil.FileExists("Data/Devious Devices - Integration.esm")
        devices_found = true
        zadLibs zlib =Game.GetFormFromFile(0x00F624, "Devious Devices - Integration.esm") as zadlibs
        zad_DeviousBelt = zlib.zad_DeviousBelt
    else 
        devices_found = false
    endif 

    desc_input = ""
    animations_folder = "Data/SKSE/Plugins/SkyrimNet_SexLab/animations"
    local_folder =      animations_folder+"/_local_"
    if player == None 
        player = Game.GetPlayer()
    endif 

    if tracking_thread_id <= 0 
        tracking_thread_id = JIntMap.object() 
        JValue.retain(tracking_thread_id)
    endif 

    if anim_info_cache <= 0 
        anim_info_cache = JMap.object() 
        JValue.retain(anim_info_cache) 
    else 
        JValue.clear(anim_info_cache) 
    endif 
EndFunction

String Function GetStageDescription(sslThreadController thread) global
    SkyrimNet_SexLab_Stages stages = Game.GetFormFromFile(0x800, "SkyrimNet_SexLab.esp") as SkyrimNet_SexLab_Stages
    if thread == None 
        Trace("GetStageDescription: thread is None", true)
        return ""
    endif 
    int stage = thread.stage
    int anim_info = stages.GetAnim_Info(thread)
    if anim_info != 0
        while 0 <= stage 
            String stage_id = "stage "+stage
            int desc_info = JMap.getObj(anim_info, stage_id)
            if desc_info != 0 
                Actor[] actors = thread.Positions
                String desc = JMap.getStr(desc_info, "description")
                String version = JMap.getStr(desc_info, "version")
                return stages.Description_Add_Actors(version, actors, desc)
            endif 
            stage -= 1
        endwhile 
    endif 
    return ""
EndFunction 

String Function Description_Add_Actors(String version, Actor[] actors, String desc)
    if desc == ""
        return ""
    endif 
    String result = "" 
    if version == VERSION_1_0
        if actors.length == 1 
            result = actors[0].GetDisplayName()+" "+desc+"."
            String last_char = StringUtil.GetNthChar(desc,StringUtil.GetLength(desc) - 1)
            if !StringUtil.IsPunctuation(last_char)
                result += "."
            endif
        else
            result = actors[1].GetDisplayName()+" "+desc+" "+actors[0].GetDisplayName()+"."
        endif 
    elseif version == VERSION_2_0
        String actors_json = SkyrimNet_SexLab_Main.ActorsToJson(actors)
        result = SkyrimNetApi.ParseString(desc, "sl", "{\"actors\":"+actors_json+"}")
    else 
        Trace("Description_Add_Actors","Unknown version "+version, true)
    endif 
    Trace("Description_Add_Actors","version "+version+" actors:"+actors.length+" desc:"+desc+" -> "+result)
    return result
EndFunction 
; ------------------------------------
; Tracking Function 
; ------------------------------------
Function StartThreadTracking(int thread_id)
    JIntMap.setInt(tracking_thread_id, thread_id, 1)
EndFunction

Function StopThreadTracking(int thread_id)
    JIntMap.removeKey(tracking_thread_id, thread_id)
EndFunction 

function ToggleThreadTracking(int thread_id)
    if IsThreadTracking(thread_id)
        StopThreadTracking(thread_id)
    else
        StartThreadTracking(thread_id)
    endif
EndFunction

bool Function IsThreadTracking(int thread_id)
    return JIntmap.hasKey(tracking_thread_id, thread_id)
EndFunction

; ------------------------------------
; Edit Description Function 
; Returns True if there was a thread to edit
; ------------------------------------

Function EditDescriptions(sslThreadController thread)
    if thread == None 
        return
    endif 
    Actor[] actors = thread.Positions

    sslBaseAnimation anim = thread.animation
    String fname = GetFilename(thread)
    Trace("EditDescriptions","fname: "+fname)

    String[] buttons = new String[7]
    int desc_prev = 0 
    int desc_edit = 1 
    int desc_next = 2 
    int orgasm_edit = 3 
    int tracking = 4 
    int style_edit = 5
    int done = 6
    buttons[desc_prev] = "Previous"
    buttons[desc_edit] = "Desc. Edit"
    buttons[desc_next] = "Next"
    buttons[orgasm_edit] = "Orgasm Expected"
    buttons[tracking] = "Start Tracking" 
    buttons[style_edit] = "Style"
    buttons[done] = "Done"

    int button = desc_prev

    SkyrimNet_SexLab_Main main = (self as Quest) as SkyrimNet_SexLab_Main
    while button != done 
        String source = "" 
        String desc = "" 
        int desc_stage = thread.stage 
        int anim_info = GetAnim_Info(thread, true)
        while 0 <= desc_stage && desc == "" 
            String stage_id = "stage "+desc_stage
            int desc_info = JMap.getObj(anim_info, stage_id)
            if desc_info == 0
                desc_stage -= 1 
            else 
                String desc_inja = JMap.getStr(desc_info, "description")
                source = JMap.getStr(desc_info, "source")
                String version = JMap.getStr(desc_info, "version")
                desc = Description_Add_Actors(version, actors, desc_inja)
            endif 
        endwhile 

        if IsThreadTracking(thread.tid)
            buttons[tracking] = Button_Stop_Tracking
        else
            buttons[tracking] = Button_Start_Tracking
        endif 

        String msg = "name:"+thread.animation.name+"\n"\
               +"tags:"+SkyrimNet_SexLab_Decorators.GetTagsString(anim)+"\n"
        if desc == "" 
            msg += "You may enter a description for stage "+thread.stage+".\n"
            msg += "ex: " + BuildExample(actors)
        else 
            if desc_stage != thread.stage
                buttons[desc_edit] = "add for stage "+thread.stage
                source = "from "+desc_stage+" stage"
            endif 
            String source_stage = source +" "+thread.stage+"/"+thread.animation.StageCount() 
            msg = "["+source_stage+"] "+desc
        endif 
        msg += "\nstyle:"+main.Thread_Narration(thread,"are") 
        int[] orgasm_filter = GetOrgasmExpected(thread)
        if orgasm_filter.length == actors.length 
            int i = orgasm_filter.length - 1
            while 0 <= i 
                if orgasm_filter[i] == 1
                    orgasm_filter[i] = 0
                else
                    orgasm_filter[i] = 1
                endif 
                i -= 1
            endwhile
            String names = SkyrimNet_SexLab_Utilities.JoinActorsFiltered(actors, orgasm_filter)
            if names != "" 
                msg += "\nOrgasm not expected for: "+names
            endif 
        endif 
        button = SkyMessage.ShowArray(msg, buttons, getIndex = true) as int  

        if button == desc_prev
            if thread.stage > 1 
                thread.GoToStage(thread.stage - 1)
            endif 
        elseif button == desc_next 
            if thread.stage + 1 <= thread.animation.StageCount()
                thread.GoToStage(thread.stage + 1)
            endif 
        elseif button == desc_edit  
            EditorDescription(main, thread)
        elseif button == orgasm_edit 
            SetOrgasmExpected(main, thread)
        elseif button == tracking 
            ToggleThreadTracking(thread.tid)
        elseif button == style_edit 
            main.SexStyleDialog(thread) 
        endif 
    endwhile 
EndFunction 

; ------------------------------------
; Editor Functions 
; ------------------------------------
string Function GetPlayerInput() global
    Trace("GetPlayerInput","GetPlayerInput called")
    UIExtensions.OpenMenu("UITextEntryMenu")
    ; Don't do this if we're in VR
    if SkyrimNetApi.IsRunningVR()
        Trace("SkyrimNetInternal","GetPlayerInput: Skipping input in VR")
        Debug.Notification("Text input is disabled in VR")
        return ""
    endif
    string messageText = UIExtensions.GetMenuResultString("UITextEntryMenu")
    Trace("GetPlayerInput","GetPlayerInput returned: " + messageText)
    return messageText
EndFunction

Function EditorDescription(SkyrimNet_SexLab_Main main, sslThreadController thread)
    int thread_id = thread.tid
    Actor[] actors = thread.Positions
    String stage_id = "stage "+thread.stage
  ;  uiextensions.InitMenu("UITextEntryMenu")
    ;uiextensions.OpenMenu("UITextEntryMenu")
    ;    desc_input = UIExtensions.GetMenuResultString("UITextEntryMenu")
    desc_input = GetPlayerInput()
    String version = VERSION_2_0
    if desc_input != ""
        String desc = Description_Add_Actors(version, actors, desc_input)
        if desc != ""
            int accept = 0
            int rewrite = 1 
            int cancel = 2
            String[] buttons = new String[3]
            buttons[accept] = "Accept"
            buttons[rewrite] = "Rewrite" 
            buttons[cancel] = "Cancel"
            String full = thread.animation.name+"\n" \
                +"tags:"+SkyrimNet_SexLab_Decorators.GetTagsString(thread.animation)+"\n\n" \
                + thread.stage+"/"+thread.animation.StageCount() + \
                   " On {the floor/a bed}, "+desc 

            int button = SkyMessage.ShowArray(full, buttons, getIndex = true) as int  

            if button == accept 
                StartThreadTracking(thread.tid)
                UpdateAnimInfo(main, thread, "stage", version, new int[1] )
            elseif button == rewrite
                EditorDescription(main, thread)
            endif 
        else
            String msg = "Your description wasn't parsed correctly.\n"
            int i = 0 
            int count = actors.length
            while i < count
                msg += "{{sl.actors."+i+"}}: "+actors[i].GetDisplayName()+"\n"
                i += 1
            endwhile 
            msg += BuildExample(actors)

            int retry = 0 
            int cancel = 1
            String[] buttons = new String[2]    
            buttons[retry] = "Retry"
            buttons[cancel] = "Cancel"

            int button = SkyMessage.ShowArray(msg, buttons, getIndex = true) as int  

            if button == retry
                EditorDescription(main, thread)
            endif 
        endif 
    endif 
    desc_input = ""
EndFunction

String Function BuildExample(Actor[] actors) 
    String example = "{{sl.actors.1}} is having sex with {{sl.actors.0}}."
    if actors.length == 1
        example = "{{sl.actors.0}} is masturbating."
    elseif actors.length > 3
        example = "{{sl.actors.2}}, {{sl.actors.1}}, and {{sl.actors.0}} are having an orgy."
    endif 
    String desc = Description_Add_Actors(VERSION_2_0, actors, example)
    return "\""+example+"\"\n"+ "\""+desc+"\""
EndFunction



; ------------------------------------
; Orgasm Expected Functions
; ------------------------------------
int[] Function GetOrgasmExpected(sslThreadController thread) 
    Trace("GetOrgasmExpected","thread: "+thread.tid+" "+thread.animation.name)
    String fname = GetFilename(thread)
    Actor[] actors = thread.Positions
    int anim_info = GetAnim_Info(thread)
    if anim_info == 0
        return Utility.CreateIntArray(actors.length, 0)
    endif 
    int id = 0 
    if JMap.hasKey(anim_info, "orgasm_expected")
        id = JMap.getObj(anim_info, "orgasm_expected")
    endif 

    int count = 0 
    if id != 0 
        count = Jarray.count(id)
    endif 
    if count == actors.length
        int[] orgasm_expected = JArray.asIntArray(id)
        Trace("GetOrgasmExpected","values found in file orgasm_expected: "+orgasm_expected)
        return JArray.asIntArray(id)
    endif 

    if actors.length > 2
        Trace("GetOrgasmExpected","more than 2 actors, all orgasm expected")
        return Utility.CreateIntArray(actors.length, 1)
    endif

    SkyrimNet_SexLab_Main main = (self as Quest) as SkyrimNet_SexLab_Main
    sslActorLibrary actorLib = (main.SexLab as Quest) as sslActorLibrary
    int[] orgasm_expected = Utility.CreateIntArray(actors.length, 1)
    sslBaseAnimation Animation = thread.animation
    Trace("GetOrgasmExpected","tags:"+animation.GetRawTags())

    int i = actors.length - 1
    while 0 <= i 
        ; -1 - no gender 
        ;  0 - Male (also the default values if the actor is not existing)
        ;  1 - Female
        int gender = actors[i].GetLeveledActorBase().GetSex() ; actorLib.GetGender(actors[i])
        int gender_sexlab = main.sexlab.GetGender(actors[i]) 
        bool has_penis = gender != 1 || (gender_sexlab != 1 && gender_sexlab != 3)
        bool has_pussy = gender == 1 || gender_sexlab == 1 || gender_sexlab == 3


        String reason = ""
        if devices_found && actors[i].WornHasKeyword(zad_DeviousBelt)
            orgasm_expected[i] = 0
            reason = "has DD belt"
        elseif Animation.HasTag("Estrus")
            orgasm_expected[i] = 1
            reason = "animation has tag estrus"
        elseif Animation.HasTag("69") || Animation.HasTag("Masturbation")
            orgasm_expected[i] = 1
            reason = "animation has tag 69 or masturbation"
        else
            if i == 0 
                if has_pussy && (Animation.HasTag("Vaginal") || Animation.HasTag("Cunnilingus") || Animation.HasTag("Lesbian") || Animation.HasTag("Fingering") || Animation.HasTag("Dildo"))
                    orgasm_expected[i] = 1 
                    reason = "position 0 with pussy and tag: vaginal, cunnilingus, lesbian, fingering, or dildo"
                elseif Animation.hasTag("Anal") || Animation.HasTag("Fisting")
                    orgasm_expected[i] = 1 
                    reason = "position 0 with tags: anal or fisting)"
                else
                    orgasm_expected[i] = 0
                    reason = "position 0 with out: pussy+tag(vagianl, cunnilingus, lesbian, fingering, dildo) or (anal, fisting)"
                endif 
            else 
                if has_penis && (Animation.HasTag("Vaginal") || Animation.HasTag("Boobjob") || Animation.HasTag("Blowjob") || Animation.HasTag("Handjob") || Animation.HasTag("Footjob") || Animation.HasTag("Oral") || Animation.HasTag("Anal"))
                    orgasm_expected[i] = 1
                    reason = "position 1+ with penis and tags: vagianl, boobjob, blowjob, handjob, footjob, oral, or anal"

                else
                    orgasm_expected[i] = 0
                    reason = "position 1+ without penis+tag(vagianl, boobjob, blowjob, handjob, footjob, oral, anal)"
                endif 
            endif 
        endIf

        String name = actors[i].GetDisplayName()
        bool expected = orgasm_expected[i] == 1 
        Trace("GetOrgasmExpected","    "+i+" "+name+" pussy:"+has_pussy+" penis:"+has_penis+" orgasm_expected:"+expected+" reasoning:"+reason)
        i -= 1
    endwhile
    Trace("GetOrgasmExpected","    orgasm_expected: "+orgasm_expected)
    return orgasm_expected
EndFunction

Function SetOrgasmExpected(SkyrimNet_SexLab_Main main, sslThreadController thread)
    Actor[] actors = thread.Positions
    int num_actors = actors.length
    int anim_info = GetAnim_Info(thread)
    int orgasm_expected_id = JMap.getObj(anim_info, "orgasm_expected")
    int count = Jarray.count(orgasm_expected_id)

    int[] orgasm_expected = Utility.CreateIntArray(num_actors, 0)
    int i = num_actors - 1
    while 0 <= i 
        if i < count
            orgasm_expected[i] = JArray.getInt(orgasm_expected_id, i)
        else
            orgasm_expected[i] = 0
        endif 
        i -= 1
    endwhile

    String[] buttons = Utility.CreateStringArray(num_actors + 2)
    int go_back = 0
    int done = num_actors + 1

    buttons[go_back] = Button_Go_Back
    buttons[done] = Button_Done
    int button = 1
    bool changed  = false
    while button != go_back && button != done 
        i = 0 
        String msg = "Change if an actor orgasm expected.\n"
        while i < actors.length
            String name = actors[i].GetDisplayName()
            if orgasm_expected[i] == 1
                msg += "\n"+name+"'s expects an orgasm."
                buttons[i+1] = "Set "+ name+" to not expect orgasm."
            else
                msg += "\n"+name+"'s doesn't expects an orgasm."
                buttons[i+1] = "Set "+ name+" to expect orgasm."
            endif 
            i += 1
        endwhile

        button = SkyMessage.ShowArray(msg, buttons, getIndex = true) as int
        if go_back < button && button < done
            changed = true
            i = button - 1
            if orgasm_expected[i] == 1
                orgasm_expected[i] = 0
            else
                orgasm_expected[i] = 1    
            endif
        endif
    endwhile

    if changed 
        UpdateAnimInfo(main, thread, "orgasm_expected", VERSION_2_0, orgasm_expected)
    endif 

    if button == done
        return
    elseif button == go_back
        EditorDescription(main, thread) 
        return 
    endif 
EndFunction

; ------------------------------------
; Helper functions
; ------------------------------------

bool[] Function GetHasDescriptionOrgasmExpected(sslThreadController thread)
    int anim_info = GetAnim_Info(thread)
    bool[] desc_orgasmExpected = Utility.CreateBoolArray(2, false)
    if anim_info == 0 
        return desc_orgasmExpected
    endif 
    String stage_id = "stage "+thread.stage
    desc_orgasmExpected[0] = JMap.hasKey(anim_info, stage_id)
    int orgasm_expected = JMap.getObj(anim_info, "orgasm_expected")
    if orgasm_expected != 0
        desc_orgasmExpected[1] = true
    endif 
    return desc_orgasmExpected
EndFunction

int Function GetAnim_Info(sslThreadController thread, Bool force_load=False)

    ; Load the local version if it exists and we aren't forcing a reload 
    sslBaseAnimation anim = thread.animation
    ;if False 
        ;Bool anim_info_cached = JMap.HasKey(anim_info_cache, anim.name)
        ;if !force_load && anim_info_cached
            ;int anim_info = JMap.getObj(anim_info_cache, anim.name) 
            ;if anim_info != 0 
                ;String name = JMap.getStr(anim_info, "name")
                ;JValue.writeToFile(anim_info, animations_folder+"/anim_info_loaded.json")
                ;return anim_info
            ;endif 
        ;endif 
            ;
        ;; This will hold a map between the Stage nad the descriptions 
        ;if anim_info_cached
            ;int anim_info = JMap.getObj(anim_info_cache, anim.name) 
            ;if anim_info != 0 
                ;JValue.release(anim_info)
            ;endif 
            ;JMap.removeKey(anim_info_cache, anim.name)
        ;endif 
    ;endif 

    ; This will hold a map between the Stage nad the descriptions 
    int anim_info = JMap.object() 
    JMap.setStr(anim_info, "name", anim.name)

    String[] folders = MiscUtil.FoldersInfolder(animations_folder)

    String fname = GetFilename(thread)
    ; Make sure the local folder is processed last
    int i = folders.length - 1
    while 0 <= i && folders[i] != "_local_"
        i -= 1
    endwhile 
    if 0 < i 
        folders[i] = folders[0]
        folders[0] = "_local_"
    endif

    i = folders.Length - 1
    while 0 <= i
        String fn = animations_folder+"/"+folders[i]+"/"+fname
        if MiscUtil.FileExists(fn)
            Trace("GetAnim_Info","loading: "+fn)
            int info = JValue.readFromFile(fn)
            if info != 0
                String[] keys = JMap.allKeysPArray(info)
                int k = keys.length - 1
                while 0 <= k
                    if keys[k] == "orgasm_expected"
                        int orgasm_expected = JMap.getObj(info, "orgasm_expected")
                        JMap.setObj(anim_info, "orgasm_expected", orgasm_expected)
                    else
                        int desc_info = JMap.getObj(info, keys[k])
                        JMap.setStr(desc_info, "source", folders[i])
                        String stage_id = keys[k]
                        String desc = JMap.getStr(desc_info, "description")
                        JMap.setObj(anim_info, stage_id, desc_info)
                    endif 
                    k -= 1
                endwhile 
            else 
                Trace("Parse error for '"+fn+"'",true)
            endif 
        endif
        i -= 1
    endwhile 
    ; setAnimCache(thread, anim_info) 
    JValue.writeToFile(anim_info, animations_folder+"/anim_info.json")
    return anim_info
EndFunction 

Function UpdateAnimInfo(SkyrimNet_SexLab_Main main, sslThreadController thread, String field, String version, int[] orgasm_expected)
    String fname = GetFilename(thread)
    String path = local_folder+"/"+fname
    int anim_info = 0
    if MiscUtil.FileExists(path)
        anim_info = JValue.readFromFile(path)
    else 
        anim_info = JMap.object()
    endif 
    if field == "stage"
        String stage_id = "stage "+thread.stage
        int stage_info = JMap.object() 
        JMap.setStr(stage_info,"version",version)
        JMap.setStr(stage_info,"description",desc_input)
        JMap.setObj(anim_info, stage_id, stage_info)
    else 
        int orgasm_expected_id = JArray.objectWithSize(orgasm_expected.length)
        int i = orgasm_expected.length - 1
        while 0 <= i 
            JArray.setInt(orgasm_expected_id, i, orgasm_expected[i])
            i -= 1
        endwhile
        JMap.setObj(anim_info, "orgasm_expected", orgasm_expected_id)
    endif 

    Trace("saving "+fname,true)
    JValue.writeToFile(anim_info, path)
    JValue.writeToFile(anim_info, animations_folder+"/last.json")
    SkyrimNet_SexLab_Decorators.Save_Threads(main.SexLab)
EndFunction 

Function SetAnimCache(sslThreadController thread, int anim_info)
    JMap.setObj(anim_info_cache, thread.animation.name, anim_info) 
    JValue.retain(anim_info)
EndFunction 

String Function GetFilename(sslThreadController thread) global
    sslBaseAnimation anim = thread.animation
    return anim.name+".json"
EndFunction 