Scriptname SkyrimNet_SexLab_Stages extends Quest 

import SkyrimNet_SexLab_Main
import StorageUtil

Bool Property hide_help = false Auto

Actor player = None 

String Property animations_folder = "Data/SkyrimNet_SexLab/animations" Auto
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
String Button_No_orgasm = "No Orgasm"
String Button_Stop_Tracking = "Stop Tracking"
String Button_Start_Tracking = "Start Tracking"
String Button_Go_Back = "Go Back"
String Button_Done = "Done"

String storage_key = "skyrimnet_sexlab_stages_anim_info"

int anim_info_cache = 0

;; DD Belt keyword
bool devices_found = false 
Keyword Property zad_DeviousBelt Auto

Function Trace(String func, String msg, Bool notification=False) global
    if notification
        Debug.Notification(msg)
    endif 
    msg = "[SkyrimNet_SexLab_Stages."+func+"] "+msg
    Debug.Trace(msg)
EndFunction

Function Setup()
    String temp = "sl" ; attempt to set the caplitiization of sl 

    if MiscUtil.FileExists("Data/Devious Devices - Integration.esm")
        devices_found = true
        zadLibs zlib =Game.GetFormFromFile(0x00F624, "Devious Devices - Integration.esm") as zadlibs
        zad_DeviousBelt = zlib.zad_DeviousBelt
    else 
        devices_found = false
    endif 


    desc_input = ""
    animations_folder = "Data/SkyrimNet_SexLab/animations"
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
        Trace("GetStageDescription","thread is None", true)
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
        if result == ""
            Trace("Description_Add_actors","cound't parse v"+version+" actors:"+actors.length+" desc:"+desc)
        endif 
    else 
        Trace("Description_Add_Actors","Unknown version "+version, true)
        return ""
    endif 
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
    Trace("EditDescriptions","thread: "+fname)

    String[] buttons = new String[7]
    int desc_prev = 0 
    int desc_edit = 1 
    int no_orgasm_expected_edit = 2
    int desc_next = 3 
    int tracking = 4 
    int style_edit = 5
    int done = 6
    buttons[desc_prev] = "previous"
    buttons[desc_edit] = "edit desc"
    buttons[no_orgasm_expected_edit] = "edit expect orgasm"
    buttons[desc_next] = "next"
    buttons[tracking] = "start tracking" 
    buttons[style_edit] = "style"
    buttons[done] = "done"

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

        String msg = fname+"\n"\
               +"tags:"+SkyrimNet_SexLab_Decorators.GetTagsString(anim)+"\n"
        if desc == "" 
            msg = "You may enter a description for stage "+thread.stage+".\n"
            msg += "ex: " + BuildExample(actors)
        else 
            if desc_stage != thread.stage
                buttons[desc_edit] = "add for stage "+thread.stage
                source = "from "+desc_stage+" stage"
            endif 
            String source_stage = source +" "+thread.stage+"/"+thread.animation.StageCount() 
            msg = "["+source_stage+"] "+desc
        endif 

        String no_orgasm_expected_desc = GetNoOrgasmExpectedDescription(thread)
        if no_orgasm_expected_desc != ""
            msg += "\n"+no_orgasm_expected_desc
        endif
        msg += "\nstyle:"+main.Thread_Narration(thread,"are") 
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
            EditorDescription(thread)
        elseif button == no_orgasm_expected_edit 
            SetNoOrgasmExpected(thread)
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
    Trace("GetPlayerInput","called")
    UIExtensions.OpenMenu("UITextEntryMenu")
    ; Don't do this if we're in VR
    if SkyrimNetApi.IsRunningVR()
        Trace("GetPlayerInput","Skipping input in VR")
        Debug.Notification("Text input is disabled in VR")
        return ""
    endif
    string messageText = UIExtensions.GetMenuResultString("UITextEntryMenu")
    Trace("GetPlayerInput","returned: " + messageText)
    return messageText
EndFunction

Function EditorDescription(sslThreadController thread)
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
            String full = "tags:"+SkyrimNet_SexLab_Decorators.GetTagsString(thread.animation)+"\n\n"
            full += thread.stage+"/"+thread.animation.StageCount() + \
                   " On {the floor/a bed}, "+desc 

            int button = SkyMessage.ShowArray(full, buttons, getIndex = true) as int  

            if button == accept 
                StartThreadTracking(thread.tid)
                UpdateAnimInfo(thread, "stage", version, new int[1] )
            elseif button == rewrite
                EditorDescription(thread)
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
                EditorDescription(thread)
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
; No Orgasm Functions
; ------------------------------------
int[] Function GetNoOrgasmExpected(sslThreadController thread) 
    String fname = GetFilename(thread)
    Actor[] actors = thread.Positions

    int anim_info = GetAnim_Info(thread)
    if anim_info != 0
        if JMap.hasKey(anim_info, "no_orgasm_expected")
            int id = JMap.getObj(anim_info, "no_orgasm_expected")
            if id != 0 
                int count = Jarray.count(id)
                if count == actors.length
                    Trace("GetNoOrgasmExpected","found no_orgasm_expected in "+fname+":"+JArray.asIntArray(id))
                    return JArray.asIntArray(id)
                endif 
            endif 
        endif 
    endif 

    SkyrimNet_SexLab_Main main = (self as Quest) as SkyrimNet_SexLab_Main
    sslActorLibrary actorLib = (main.SexLab as Quest) as sslActorLibrary
    int[] no_orgasm_expected = Utility.CreateIntArray(actors.length, 0)
    int i = actors.length - 1
    sslBaseAnimation Animation = thread.animation
    Trace("GetNoOrgasmExpected","tags:"+animation.GetRawTags())

    while 0 <= i 
        ; -1 - no gender 
        ;  0 - Male (also the default values if the actor is not existing)
        ;  1 - Female
        int gender = actors[i].GetLeveledActorBase().GetSex() ; actorLib.GetGender(actors[i])
        bool has_penis = gender != 1 || actorLib.TreatAsMale(actors[i]) 
        bool has_pussy = gender == 1 || actorLib.TreatAsFemale(actors[i]) 

        String name = actors[i].GetDisplayName()
        Trace("GetNoOrgasmExpected",name+" gender:"+gender+" treatMale:"+actorLib.TreatAsMale(actors[i])+" treatFemale:"+actorLib.TreatAsFemale(actors[i]))

        String reason = ""
        if devices_found && actors[i].WornHasKeyword(zad_DeviousBelt)
            no_orgasm_expected[i] = 1
            reason = "has DD belt"
        elseif Animation.HasTag("Estrus")
            no_orgasm_expected[i] = 0
            reason = "animation has tag estrus"
        elseif Animation.HasTag("69") || Animation.HasTag("Masturbation")
            no_orgasm_expected[i] = 0
            reason = "animation has tag 69 or masturbation"
        else
            if i == 0 
                if has_pussy && (Animation.HasTag("Vaginal") || Animation.HasTag("Cunnilingus") || Animation.HasTag("Lesbian") || Animation.HasTag("Fingering") || Animation.HasTag("Dildo"))
                    no_orgasm_expected[i] = 0 
                    reason = "position 0 with pussy and tag: vaginal, cunnilingus, lesbian, fingering, or dildo"
                elseif Animation.hasTag("Anal") || Animation.HasTag("Fisting")
                    no_orgasm_expected[i] = 0 
                    reason = "position 0 with tags: anal or fisting)"
                else
                    no_orgasm_expected[i] = 1
                    reason = "position 0 with out: pussy+tag(vagianl, cunnilingus, lesbian, fingering, dildo) or (anal, fisting)"
                endif 
            else 
                if has_penis && (Animation.HasTag("Vaginal") || Animation.HasTag("Boobjob") || Animation.HasTag("Blowjob") || Animation.HasTag("Handjob") || Animation.HasTag("Footjob") || Animation.HasTag("Oral") || Animation.HasTag("Anal"))
                    no_orgasm_expected[i] = 0
                    reason = "position 1+ with penius and tags: vagianl, boobjob, blowjob, handjob, footjob, oral, or anal"

                else
                    no_orgasm_expected[i] = 1
                    reason = "position 1+ without penius+tag(vagianl, boobjob, blowjob, handjob, footjob, oral, anal)"
                endif 
            endif 
        endIf

        bool orgasm_expected = no_orgasm_expected[i] != 1 
        Trace("GetNoOrgasmExpected",i+" "+name+" pussy:"+has_pussy+" penis:"+has_penis+" orgasm_expected:"+orgasm_expected+" reasoning:"+reason)
        i -= 1
    endwhile
    Trace("GetNoOrgasmExpected","no_orgasm_expected: "+no_orgasm_expected)
    return no_orgasm_expected
EndFunction

string Function GetNoOrgasmExpectedDescription(sslThreadController thread)
    int[] no_orgasm_expected = GetNoOrgasmExpected(thread)
    Actor[] actors = thread.Positions
    String msg = ""
    int i = 0 
    while i < actors.length
        if no_orgasm_expected[i] == 1
            if msg != ""
                msg += " "
            endif 
            msg += actors[i].GetDisplayName()+" doesn't expect an orgasm."
        endif 
        i += 1
    endwhile
    return msg
EndFunction

Function SetNoOrgasmExpected(sslThreadController thread)
    Actor[] actors = thread.Positions
    int num_actors = actors.length
    int anim_info = GetAnim_Info(thread)
    int no_orgasm_expected_id = JMap.getObj(anim_info, "no_orgasm_expected")
    int count = Jarray.count(no_orgasm_expected_id)

    int[] no_orgasm_expected = Utility.CreateIntArray(num_actors, 0)
    int i = num_actors - 1
    while 0 <= i 
        if i < count
            no_orgasm_expected[i] = JArray.getInt(no_orgasm_expected_id, i)
        else
            no_orgasm_expected[i] = 0
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
        String msg = "Change if an actor expects an orgasm\n"
        while i < actors.length
            String name = actors[i].GetDisplayName()
            if no_orgasm_expected[i] == 1
                msg += "\n"+name+" doesn't expect an orgasm."
                buttons[i+1] = "Set "+ name+" expects to orgasm."
            else
                buttons[i+1] = "Set "+ name+" doesn't expect to orgasm."
            endif 
            i += 1
        endwhile

        button = SkyMessage.ShowArray(msg, buttons, getIndex = true) as int
        if go_back < button && button < done
            changed = true
            i = button - 1
            if no_orgasm_expected[i] == 1
                no_orgasm_expected[i] = 0
            else
                no_orgasm_expected[i] = 1    
            endif
        endif
    endwhile

    if changed 
        UpdateAnimInfo(thread, "no_orgasm_expected", VERSION_2_0, no_orgasm_expected)
    endif 

    if button == done
        return
    elseif button == go_back
        EditorDescription(thread) 
        return 
    endif 
EndFunction

; ------------------------------------
; Helper functions
; ------------------------------------

String Function GetSummary(sslThreadController thread)
    int anim_info = GetAnim_Info(thread)
    String summary = ""
    if anim_info != 0

        String stage_id = "stage "+thread.stage
        int desc_info = JMap.getObj(anim_info, stage_id)
        if desc_info != 0 
            summary += "animation has a description"
        endif 
        Actor[] actors = thread.Positions
        if JMap.hasKey(anim_info, "no_orgasm_expected")
            int no_orgasm_expected = JMap.getObj(anim_info, "no_orgasm_expected")
            int i = JArray.count(no_orgasm_expected) - 1
            String names = ""
            while 0 <= i
                if JArray.getInt(no_orgasm_expected, i) == 1
                    if names != ""
                        names += ", "
                    endif 
                    names += actors[i].GetDisplayName()
                endif 
                i -= 1
            endwhile
            if names != ""
                if summary != ""
                    summary += "\n"
                endif
                summary += "no orgasm for "+names
            endif 
        endif 
        summary = thread.stage+"/"+thread.animation.StageCount()+" "+summary
    endif 
    return summary
EndFunction


int Function GetAnim_Info(sslThreadController thread, Bool force_load=False)

    ; Load the local version if it exists and we aren't forcing a reload 
    sslBaseAnimation anim = thread.animation
    if False 
        Bool anim_info_cached = JMap.HasKey(anim_info_cache, anim.name)
        if !force_load && anim_info_cached
            int anim_info = JMap.getObj(anim_info_cache, anim.name) 
            if anim_info != 0 
                String name = JMap.getStr(anim_info, "name")
                JValue.writeToFile(anim_info, animations_folder+"/anim_info_loaded.json")
                return anim_info
            endif 
        endif 
            
        ; This will hold a map between the Stage and the descriptions 
        if anim_info_cached
            int anim_info = JMap.getObj(anim_info_cache, anim.name) 
            if anim_info != 0 
                JValue.release(anim_info)
            endif 
            JMap.removeKey(anim_info_cache, anim.name)
        endif 
    endif 

    ; This will hold a map between the Stage and the descriptions 
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
            int info = JValue.readFromFile(fn)
            if info != 0
                String[] keys = JMap.allKeysPArray(info)
                int k = keys.length - 1
                while 0 <= k
                    if keys[k] == "no_orgasm_expected"
                        int no_orgasm_expected = JMap.getObj(info, "no_orgasm_expected")
                        JMap.setObj(anim_info, "no_orgasm_expected", no_orgasm_expected)
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
                Trace("GetAnimInfo","Parse error for '"+fn+"'",true)
            endif 
        endif
        i -= 1
    endwhile 
    if JMap.hasKey(anim_info, "no_orgasm_expected")
        int no_orgasm_expected = JMap.getObj(anim_info, "no_orgasm_expected")
        int count = thread.Positions.length
        int count_old = Jarray.count(no_orgasm_expected)
        if count_old != count
            int new_no_orgasm_expected = JArray.objectWithSize(count)
            int j = count - 1 
            while 0 <= j
                if j < count_old
                    JArray.setInt(new_no_orgasm_expected, j, JArray.getInt(no_orgasm_expected, j))
                else
                    JArray.setInt(new_no_orgasm_expected, j, 0)
                endif
                j += 1
            endwhile 
            JMap.setObj(anim_info, "no_orgasm_expected", new_no_orgasm_expected)
        endif
    endif

    ; setAnimCache(thread, anim_info) 
    ; JValue.writeToFile(anim_info, animations_folder+"/anim_info.json")
    return anim_info
EndFunction 

Function UpdateAnimInfo(sslThreadController thread, String field, String version, int[] no_orgasm_expected)
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
        int no_orgasm_expected_id = JArray.objectWithSize(no_orgasm_expected.length)
        int i = no_orgasm_expected.length - 1
        while 0 <= i 
            JArray.setInt(no_orgasm_expected_id, i, no_orgasm_expected[i])
            i -= 1
        endwhile
        JMap.setObj(anim_info, "no_orgasm_expected", no_orgasm_expected_id)
    endif 

    Trace("UpdateAnimInfo","saving "+fname,true)
    JValue.writeToFile(anim_info, path)
    JValue.writeToFile(anim_info, animations_folder+"/last.json")
EndFunction 

Function SetAnimCache(sslThreadController thread, int anim_info)
    JMap.setObj(anim_info_cache, thread.animation.name, anim_info) 
    JValue.retain(anim_info)
EndFunction 

String Function GetFilename(sslThreadController thread) global
    sslBaseAnimation anim = thread.animation
    return anim.name+".json"
EndFunction 
