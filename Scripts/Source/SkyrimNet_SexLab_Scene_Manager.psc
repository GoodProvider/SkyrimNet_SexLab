Scriptname SkyrimNet_SexLab_Scene_Manager extends Quest 
; -------------------------------------
; SexLab 
; -------------------------------------
SexLabFramework Property sexlab Auto
SkyrimNet_SexLab_Main Property main Auto
SkyrimNet_SexLab_Stages Property stages Auto

Import SkyrimNet_SexLab_Utilities

; the scene_generic is returned when there re no more 
SkyrimNet_SexLab_Scene scene_generic = None 
SkyrimNet_SexLab_Scene[] Property scenes Auto
Form[] thread_scene

; -------------------------------------
Faction Property SkyrimNet_SexLab_Faction_Victim Auto

; Threads filename 
String threads_filename = "Data/SKSE/Plugins/SkyrimNet_SexLab/threads.json"

; -------------------------------------
; Storage 
; -------------------------------------
String storage_prefix = "skyrimnet_sexlab_scene"
int thread_counter = 0 

; -------------------------------------
; Storage 
; -------------------------------------
String[] tags_supress_sexual

; -------------------------------------
; Group Info Object 
; -------------------------------------
int Property group_info = 0 Auto

Function Trace(String func, String msg="", Bool notification=False) global

    msg = "[SkyrimNet_SexLab_Scene_Manager."+func+"] "+msg
    Debug.Trace(msg) 
    if notification
        Debug.Notification(msg)
    endif 
EndFunction

Function Setup() 
    if SexLab == None
        Trace("SetUp","SexLab is None")
        return  
    endif

    Trace("Setup")
    int i = scenes.length - 1
    while 0 <= i 
        scenes[i].sid = i 
        scenes[i].main = main 
        scenes[i].stages = stages 
        scenes[i].manager = self 
        scenes[i].sexlab = sexlab 
        scenes[i].ThreadSlots = (sexlab as Quest) as sslThreadSlots
        scenes[i].SkyrimNet_SexLab_Faction_Victim = SkyrimNet_SexLab_Faction_Victim
        i -= 1 
    endwhile  
    Trace("Setup","FInished with scenes")

    ; Unlocks actors 
    StorageUtil.ClearAllPrefix(storage_prefix)

    if !thread_scene
        Trace("Setup","creating thread_scene map")
        thread_scene = new form[32]
    endif 
    Trace("Setup","updated thread_scene")

    ; Reload the group_tags in case they where changed each time.
    if group_info == 0
        group_info = JValue.readFromFile("Data/SKSE/Plugins/SkyrimNet_Sexlab/group_tags.json")
        JValue.retain(group_info)
    else
        int group_info_new = JValue.readFromFile("Data/SKSE/Plugins/SkyrimNet_Sexlab/group_tags.json")
        JValue.releaseAndRetain(group_info, group_info_new)
        group_info = group_info_new
    endif


    if !tags_supress_sexual
        tags_supress_sexual = new String[10]
        tags_supress_sexual[0] = "oral"
        tags_supress_sexual[1] = "vaginal"
        tags_supress_sexual[2] = "anal"
        tags_supress_sexual[3] = "masturbation"
        tags_supress_sexual[4] = "handjob"
        tags_supress_sexual[5] = "boobjob"
        tags_supress_sexual[6] = "thighjob"
        tags_supress_sexual[7] = "fisting,dildo"
        tags_supress_sexual[8] = "fingering"
        tags_supress_sexual[9] = "footjob"
    endif 
    Trace("Setup","tags supress sexual finished")

    RegisterEventsActions()
    RegisterEventsSexLab()
EndFunction 

; --------------------------------------------------------------------
; Get Scene
; --------------------------------------------------------------------
SkyrimNet_SexLab_Scene Function CreateScene(String activity, Actor[] actors, Actor speaker, Actor target)
    SkyrimNet_SexLab_Scene scene = GetSceneNextInactive()
    Trace("CreateScene",scene.sid+" activity:'"+activity+"' actors:"+JoinActors(actors)+" speaker:"+GetDisplayName(speaker)+" target:"+GetDisplayName(target))
    if scene == None
        Trace("CreateScene", "Failed to get inactive scene, returning None")
        return None
    endif
    Trace("CreateScene"," a")
    scene.SetUp(actors, speaker, target) 
    Trace("CreateScene"," b")
    scene.SetActivityByString(activity)
    Trace("CreateScene"," c")
    return scene
EndFunction

SkyrimNet_SexLab_Scene Function CreateSceneFromThread(sslThreadController thread)
    Actor[] actors = thread.Positions
    SkyrimNet_SexLab_Scene scene = GetSceneNextInactive()
    if scene == None
        Trace("CreateSceneFromThread", "Failed to get inactive scene for thread " + thread.tid)
        return None
    endif
    
    if scene != scene_generic
        ResizeThreadSceneAsNeeded(thread.tid)
        thread_scene[thread.tid] = scene
    endif 
    if actors.length > 1
        scene.Setup(actors, actors[0], actors[1]) 
    else 
        scene.Setup(actors, actors[0], None)
    endif 

    if actors.length > 1 
        int i = actors.length - 1
        int num_victims = 0 
        while 0 <= i
            if thread.IsVictim(actors[i])
                num_victims += 1
                endif
            i -= 1
        endwhile

        if num_victims > 0
            Actor[] victims = PapyrusUtil.ActorArray(num_victims)
            i = actors.length - 1
            int j = num_victims - 1
            while 0 <= i
                if thread.IsVictim(actors[i])
                    victims[j] = actors[i]
                    j -= 1
                endif
                i -= 1
            endwhile
            scene.SetVictims(victims) 
        endif
    endif 

    return scene 
EndFunction


SkyrimNet_SexLab_Scene Function GetSceneByThread(sslThreadModel thread)
    return GetSceneByThreadId(thread.tid) 
EndFunction 

SkyrimNet_SexLab_Scene Function GetSceneByThreadId(int tid)
    if tid < 0
        Trace("GetSceneByThreadId", "ThreadId < 0")
        return None
    endif

    SkyrimNet_SexLab_Scene scene = None

    ; Ensure thread_scene is large enough
    ResizeThreadSceneAsNeeded(tid)

    ; Validate SexLab property before unsafe cast
    if SexLab == None
        Trace("GetSceneByThreadId", "SexLab property is None, cannot retrieve thread")
        return None
    endif

    ; Try to locate the thread and create a scene from its positions
    sslThreadSlots ThreadSlots = (SexLab as Quest) as sslThreadSlots
    if ThreadSlots != None && tid < ThreadSlots.Threads.length
        sslThreadController thread = ThreadSlots.Threads[tid]
        if thread != None
            return CreateSceneFromThread(thread)
        endif
    endif

    return None
EndFunction

; ----------------------------------------

SkyrimNet_SexLab_Scene Function GetSceneByActor(Actor akActor) 
    sslThreadController thread = GetThreadByActor(akActor) 
    if thread != None
        return GetSceneByThread(thread)
    endif 
    return None 
EndFunction

sslThreadController Function GetThreadByActor(Actor akActor) 
    if SexLab == None 
        Trace("GetThreadByActor", "SexLab is None")
        return None 
    endif 
    Trace("GetThread","actor:"+akActor.GetDisplayName())
    sslThreadSlots ThreadSlots = (SexLab as Quest) as sslThreadSlots
    if ThreadSlots == None
        Trace("Get_Threads","ThreadSlots is None",true)
        return None
    endif

    sslThreadController thread = None 
    sslThreadController[] threads = ThreadSlots.Threads
    int i = threads.length - 1
    while 0 <= i && thread == None
        Actor[] actors = threads[i].Positions
        int j = actors.length - 1
        while 0 <= j && thread == None
            if actors[j] == akActor
                return threads[i]
            endif 
            j -= 1
        endwhile 
        i -= 1
    endwhile
    return None 
EndFunction 

; ----------------------------------------

SkyrimNet_SexLab_Scene Function GetSceneNextInactive()
    int sid = -1
    int i = scenes.length - 1
    while i >= 0
        if scenes[i].status == scenes[i].STATUS_INACTIVE
            return scenes[i]
        endif
        i -= 1
    endwhile

    Trace("CreateScene","No inactive scenes available, creating new one. Total scenes before creating: "+scenes.length)
    return scene_generic 
EndFunction

;----------------------------------------------------------------------------------------------------
; Scene Release 
;----------------------------------------------------------------------------------------------------

Function ReleaseScene(SkyrimNet_SexLab_Scene scene) 
    scene.Release() 
EndFunction 

;----------------------------------------------------------------------------------------------------
; Action Events
;----------------------------------------------------------------------------------------------------

sslThreadModel Function StartScene(SkyrimNet_SexLab_Scene scene) 
    return scene.Start()
EndFunction

;----------------------------------------------------------------------------------------------------
; Action Events
;----------------------------------------------------------------------------------------------------
Function SetThread_Scene(int tid, SkyrimNet_SexLab_Scene scene) 
    if tid < 0
        Trace("SetThread_Scene", "ThreadId < 0")
        return
    endif

    ResizeThreadSceneAsNeeded(tid)
    thread_scene[tid] = scene
EndFunction

Function ResizeThreadSceneAsNeeded(int tid)
    if tid >= thread_scene.length
        int new_size = tid + 10
        Form[] resized = Utility.CreateFormArray(new_size)
        int i = thread_scene.length - 1
        while i >= 0
            resized[i] = thread_scene[i]
            i -= 1
        endwhile
        thread_scene = resized
    endif
EndFunction
   
;----------------------------------------------------------------------------------------------------
; Action Events
;----------------------------------------------------------------------------------------------------
Function RegisterEventsActions() 
    Trace("RegisterEventsActions","")
    RegisterForModEvent("SkyrimNet_SexLab_Action_Stop", "Action_Stop")
    RegisterForModEvent("SkyrimNet_SexLab_Action_Start", "Action_Start")
EndFunction 

Event Action_Stop(Actor f_speaker, Actor f_target, String style)
    Actor speaker = f_speaker as Actor 
    Actor target = f_target as Actor 
    Trace("Action_Stop", "speaker: "+speaker.GetDisplayName()+" target: "+target.GetDisplayName()+" style: "+style)
    SkyrimNet_SexLab_Scene scene = GetSceneByActor(target)
    if scene == None 
        Trace("Action_Stop", "No scene found for target: "+target.GetDisplayName())
        return 
    endif 
    if main == None 
        Trace("Action_Stop", "main is None")
        return  
    endif 

    sslThreadSlots thread_slots = (main.sexlab as Quest) as sslThreadSlots
    if thread_slots == None 
        Trace("Action_Stop", "thread_slots is None")
        return 
    endif 

    Actor Player = Game.GetPlayer() 
    if speaker != player && scene.has_player && main.sex_edit_tags_player
        int yes = 0
        int no = 1
        int no_forcefully = 2
        int no_gently = 3
        int no_silently = 4
        String[] buttons = new String[5]
        buttons[yes] = "Yes"
        buttons[no] = "No"
        buttons[no_forcefully] = "No (forcefully)"
        buttons[no_gently] = "No (gently)"
        buttons[no_silently] = "No (silently)"
        String activity
        String question = speaker.GetDisplayName()+" is trying to stop "+scene.GetActivityStageMessage(scene.ACTIVITY_STAGE_ONGOING)+", will you allow it?"
        int button = SkyMessage.showArray(question, buttons, getIndex = True) as int 
        if button != yes
            if button == no_silently
                return 
            endif 
            String style = "" 
            if button == no_forcefully
                style = "forcefully"
            elseif button == no_gently
                style = "gently"
            endif 
            String message = player.GetDisplayName()+" "+style+" refuses "+speaker.GetDisplayName()+"'s attempt to stop "\
                +scene.GetActivityStageMessage(scene.ACTIVITY_STAGE_ONGOING)+"."
            DirectNarration(message, speaker)
            return
        endif 
    endif 

    scene.AnimationEnd(speaker,style)
    thread_slots.StopThread(scene.GetThread())
EndEvent 

Event Action_Start(String activity, Form f_speaker, Form f_target, Form f_victim, \
    string style, string tag, bool target_position_0, string scene_settings, String event_hook,\
    Form f_participate_3)
    Actor speaker = f_speaker as Actor 
    Actor target = f_target as Actor 
    Actor victim = f_victim as Actor 
    Actor participate_3 = f_participate_3 as Actor 

    Trace("Action_Start","activity:"+activity\
        +" speaker:"+GetDisplayName(Speaker)+" target:"+GetDisplayName(Target)+" victim:"+GetDisplayName(Victim)\
        +" style:"+style+" tag:"+tag+" scene_settings:"+scene_settings+" event_hook:"+event_hook\
        +" participate_3:"+GetDisplayName(participate_3))

    if Speaker == None 
        Trace("StartScene_Event", "Speaker is None")
        return 
    endif 

    ; ----------------------------
    ; Build the actors array
    ; ----------------------------
    int num_actors = 1 
    if Target != None 
        num_actors += 1 
    elseif participate_3 != None 
        Target = participate_3
        participate_3 = None 
        num_actors += 1 
    endif 
    if participate_3 != None 
        num_actors += 1 
    endif 
    Actor[] actors = PapyrusUtil.ActorArray(num_actors)
    actors[0] = Speaker
    int i = 1 
    if Target != None 
        if target_position_0
            actors[0] = target
            actors[1] = speaker
        else 
            actors[1] = Target 
        endif 
        i += 1 
    endif 
    if participate_3 != None 
        actors[i] = participate_3
        i += 1 
    endif 

    SkyrimNet_SexLab_Scene scene = CreateScene(activity, actors, speaker, target)
    scene.SetUp(actors, speaker, target) 
    if scene.LockAllActorLock()
        scene.SetVictim(victim)
        scene.SetTag(tag) 
        scene.SetStyle(style) 
        scene.SetEventHook(event_hook) 
        ;scene.addSettings(scene_settings) 
        StartScene(scene) 
    endif 
EndEvent 


;----------------------------------------------------------------------------------------------------
; SexLab Events
;----------------------------------------------------------------------------------------------------
Function RegisterEventsSexlab() 
    Trace("RegisterSexlabEvents","")
    ; SexLabFramework sexlab = Game.GetForm

    UnRegisterForModEvent("HookAnimationStart")
    RegisterForModEvent("HookAnimationStart", "AnimationStart")
    UnRegisterForModEvent("HookStageStart")
    RegisterForModEvent("HookStageStart", "StageStart")
    ;UnRegisterForModEvent("HookStageEnd")
    ;RegisterForModEvent("HookStageEnd", "SexLab_StageEnd")
    UnRegisterForModEvent("HookAnimationEnd")
    RegisterForModEvent("HookAnimationEnd", "AnimationEnd")

    UnRegisterForModEvent("HookOrgasmStart")
    UnRegisterForModEvent("SexLabOrgasm")
    RegisterForModEvent("SexLabOrgasm", "OrgasmIndividual")
    UnRegisterForModEvent("HookOrgasmStart")
    RegisterForModEvent("HookOrgasmStart", "OrgasmCombined")
EndFunction 

; ----------------------------------------------------------
Event AnimationStart(int ThreadID, bool HasPlayer)
    SkyrimNet_SexLab_Scene scene = GetSceneByThreadId(ThreadID)
    if scene == None 
        Trace("AnimationStart","Scene is None for ThreadID "+ThreadID)
        return
    endif
    scene.AnimationStart() 
EndEvent 


; ----------------------------------------------------------
Event StageStart(int ThreadID, bool HasPlayer)
    SkyrimNet_SexLab_Scene scene = GetSceneByThreadId(ThreadID)
    if scene == None 
        Trace("StageStart","Scene is None for ThreadID "+ThreadID)
        return
    endif
    scene.StageStart() 
EndEvent


; ----------------------------------------------------------
event AnimationEnd(int ThreadID, bool HasPlayer)
    SkyrimNet_SexLab_Scene scene = GetSceneByThreadId(ThreadID)
    if scene == None 
        Trace("AnimationEnd","Scene is None for ThreadID "+ThreadID)
        return
    endif
    scene.AnimationEnd() 
EndEvent 

; Function AllowedDeniedOnlyIncrease(Actor[] actors, sslThreadController thread, String status)
    ; if !MiscUtil.FileExists("Data/SexLabAroused.esm") 
        ; return
    ; endif
    ; Store orgasm denied actor's arousal level before sex, It is not allowed to lower 
    ;q = Game.GetFormFromFile(0x800, "SkyrimNet_SexLab.esp") as Quest
    ;SkyrimNet_SexLab_main main = q as SkyrimNet_SexLab_Main
    ;SkyrimNet_SexLab_Stages stages_lib = q as SkyrimNet_SexLab_Stages

    ; int[] orgasm_denied = new int [1] ; stages.GetOrgasmDenied(thread)
    ; int satisifcation_idx = slaInternalModules.RegisterStaticEffect("Orgasm")
; 
    ; int i = orgasm_denied.length - 1
    ; while 0 <= i    
        ; float sat_value = slaInternalModules.GetStaticEffectValue(actors[i], satisifcation_idx)
        ; if orgasm_denied[i] == 1
            ; if status == "start"
                ; StorageUtil.SetFloatValue(actors[i], storage_arousal_key, sat_value)
            ; else
                ; float stored_value = StorageUtil.GetFloatValue(actors[i], storage_arousal_key)
                ; if stored_value < sat_value
                    ; StorageUtil.SetFloatValue(actors[i], storage_arousal_key, sat_value)
                ; elseif stored_value > sat_value
                    ; slaInternalModules.SetStaticArousalValue(actors[i], satisifcation_idx, stored_value)
                    ; Trace("AllowedDeniedOnlyIncrease",actors[i].GetDisplayName()+" orgasm denied, so erasing orgasm satisifaction "+sat_value+" -> "+stored_value)
                ; endif 
            ; endif 
        ; endif 
        ; sat_value = slaInternalModules.GetStaticEffectValue(actors[i], satisifcation_idx)
        ; i -= 1
    ; endwhile
; EndFunction

; ----------------------------------------------------------------------------------------------------
; Orgasm Event Functions 
; This function is not called when flag SLSO, as it has its own orgasm handling
; ----------------------------------------------------------------------------------------------------
Event OrgasmCombined(int ThreadID, bool HasPlayer)
    ; Ignore if separate orgasms is on, as it has its own handling
    sslSystemConfig config = (SexLab as Quest) as sslSystemConfig
    if config.SeparateOrgasms 
        return 
    endif 
    SkyrimNet_SexLab_Scene scene = GetSceneByThreadId(ThreadID)
    if scene == None 
        Trace("OrgasmCombined","Scene is None for ThreadID "+ThreadID)
        return
    endif
    scene.OrgasmCombined() 
EndEvent 

; Used for SLSO.esp orgasm handling
Event OrgasmIndividual(Actor akActor, int full_enjoyment, int num_orgasms)
    sslSystemConfig config = (SexLab as Quest) as sslSystemConfig
    if !config.SeparateOrgasms 
        return 
    endif 

    ; DOM handles it's own orgasms
    if main.handler_dom.IsDOMSlave(akActor)
        return
    endif 

    SkyrimNet_SexLab_Scene scene = GetSceneByActor(akActor)
    if scene == None
        Trace("OrgasmCombined","Scene is none for actor: "+akActor.GetDisplayName())
        return
    endif
    scene.OrgasmIndividual(akActor, full_enjoyment, num_orgasms) 
EndEvent

int Function GetNumberOfOrgasms(Actor akActor)
    SkyrimNet_SexLab_Scene scene = GetSceneByActor(akActor)
    if scene == None 
        return 0 
    endif 
    return scene.GetNumberOfOrgasms(akActor)
EndFunction

Function OrgasmCustom(Actor akActor, String msg) 
    SkyrimNet_SexLab_Scene scene = GetSceneByActor(akActor)
    if scene == None 
        return 
    endif 
    scene.OrgasmCustom(akActor, msg)
EndFunction



; ------------------------------------------------------
; JSON 
; ------------------------------------------------------
Function SaveThreadsJson()
    GetThreadsJson()
EndFunction

String Function GetThreadsJson(Actor speaker = None)
    if speaker == None 
        speaker = Game.GetPlayer()
    endif 

    if main == None
        Trace("SexLab_Get_Threads","main is None")
        return ""
    endif

    Quest q = Game.GetFormFromFile(0xD61, "SexLab.esm")  as Quest 
    sslActorLibrary actorLib = q as sslActorLibrary
    sslCreatureAnimationSlots creatureLib = q as sslCreatureAnimationSlots

    sslThreadSlots ThreadSlots = Game.GetFormFromFile(0xD61, "SexLab.esm") as sslThreadSlots
    if ThreadSlots == None
        Trace("SexLab_Get_Threads","ThreadSlots is None",true)
        return "{"+'"'+"threads"+'"'+":[]}"
    endif

    sslThreadController[] threads = ThreadSlots.Threads

    if threads.length == -1 
        main.active_sex = false 
    endif 

    int i = 0
    String threads_str = ""
    bool speaker_having_sex = false 
    while i < threads.length
        String s = (threads[i] as sslThreadModel).GetState()
        if s == "animating" || s == "prepare"
            if threads_str != ""
                threads_str += ", "
            endif 
            SkyrimNet_SexLab_Scene scene = GetSceneByThread(threads[i])
            threads_str += scene.GetJson(speaker) 
        endif 
        i += 1
    endwhile


    ; Speaker Information 
    ; ------------------------
    String json = '{"speaker_having_sex:"'+speaker_having_sex
    json +=       ',"speaker_name":"'+speaker.GetDisplayName()+'"'
    json +=       ',"threads":['+threads_str+']'
    json +=       ',"counter":'+thread_counter
    json +=       '}'
    thread_counter += 1 
    
    Trace("getThreadsJson",json)
    Miscutil.WriteToFile(threads_filename, json, append=False)
    return json
EndFunction 

String Function GetStyleDialog(String msg) global
    String[] buttons = new String[4]
    buttons[0] = "forcefully"
    buttons[1] = "normally"
    buttons[2] = "gently"
    buttons[3] = "silently"
    return SkyMessage.ShowArray(msg, buttons, getIndex=False) as String
EndFunction