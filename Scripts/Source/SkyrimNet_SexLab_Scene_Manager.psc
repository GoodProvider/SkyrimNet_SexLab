Scriptname SkyrimNet_SexLab_Scene_Manager extends Quest 

Import SkyrimNet_SexLab_Utilities

SkyrimNet_SexLab_Main Property main Auto
SkyrimNet_SexLab_Stages Property stages Auto
SkyrimNet_SexLab_Scene_Manager Property manager Auto 

SexLabFramework Property sexlab Auto
sslThreadSlots Property threadSlots Auto
sslActorLibrary Property actorLib Auto

; the scene_generic is returned when there re no more 
SkyrimNet_SexLab_Scene scene_generic = None 
SkyrimNet_SexLab_Scene[] Property scenes Auto

; We use Form so we can use CreateFormArray if we need to increase the size 
Form[] thread_scene
SkyrimNet_SexLab_Scene_Creator[] creators

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

Function Trace(String func, String msg="", Bool notification=False)

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

    scene_generic.Initialize(-1, self) 
    scene_generic.SetGeneric() 

    Trace("Setup")
    int i = scenes.length - 1
    while 0 <= i 
        scenes[i].Initialize(i, self)
        i -= 1 
    endwhile  

    i = creators.length - 1 
    while 0 <= i 
        creators[i].Initialize(i, self) 
        i -= 1 
    endwhile 

    ; Unlocks actors 
    StorageUtil.ClearAllPrefix(storage_prefix)

    if !thread_scene
        Trace("Setup","creating thread_scene map")
        thread_scene = new form[32]
    endif 

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
    RegisterEventsActions()
    RegisterEventsSexLab()
EndFunction 

; --------------------------------------------------------------------
; Create Creator 
; --------------------------------------------------------------------
SkyrimNet_SexLab_Scene_Creator  Function CreateCreator(Actor[] actors, Actor speaker, Actor target)

    int i = 0
    int num_creators = creators.length 
    while i < num_creators
        if creators[i].IsInactive()
            creators[i].SetUp(actors, speaker, target) 
            return creators[i]
        endif
        i += 1 
    endwhile

    Trace("CreateScene", "Failed to get inactive creator, returning None")
    return None
EndFunction

; --------------------------------------------------------------------
; Get Scene 
; --------------------------------------------------------------------
SkyrimNet_SexLab_Scene Function CreateSceneByThread(sslThreadController thread) 
    int i = 0 
    int num_scenes = scenes.length 
    while i < 0 
        if scenes[i].IsInactive() 
            scenes[i].Setup(thread)
            return scenes[i]
        endif 
        i += 1 
    endwhile 
    scene_generic.SetUp(thread)
    return scene_generic
EndFunction 

SkyrimNet_SexLab_Scene Function GetSceneByThread(sslThreadController thread)
    int tid = thread.tid
    if tid < thread_scene.length && thread_scene[tid] != None 
        SkyrimNet_SexLab_Scene scene = thread_scene[tid] as SkyrimNet_SexLab_Scene
        if scene.thread == thread
            return scene
        endif 
        scene.Release() 
    endif 
    int sid = 0
    int num_scenes = scenes.length 
    while sid < num_scenes
        if scenes[sid].IsInactive() 
            scenes[sid].SetUp(thread) 
            return scenes[sid]
        endif 
        sid += 1 
    endwhile 

    Trace("CreateSceneFromThread", "Failed to get inactive scene for thread " + thread.tid+" using generic")
    scene_generic.SetUp(Thread)
    return scene_generic
EndFunction


SkyrimNet_SexLab_Scene Function GetSceneByThreadId(int tid)
    sslThreadController thread = SexLab.GetController(tid)
    if thread == None 
        return None 
    endif 
    return GetSceneByThread(thread) 
EndFunction 

; ----------------------------------------

SkyrimNet_SexLab_Scene Function GetSceneByActor(Actor akActor) 
    sslThreadController thread = GetThreadByActor(akActor) 
    if thread == None
        return None 
    endif 
    return GetSceneByThread(thread)
EndFunction

sslThreadController Function GetThreadByActor(Actor akActor) 
    Trace("GetThread","actor:"+akActor.GetDisplayName())
    sslThreadController[] threads = ThreadSlots.Threads
    int i = threads.length - 1
    while 0 <= i
        String status = (threads[i] as sslThreadModel).GetState()
        if status == "animating" || status == "prepare"
            Actor[] actors = threads[i].Positions
            int j = actors.length - 1
            while 0 <= j 
                if actors[j] == akActor
                    return threads[i]
                endif 
                j -= 1
            endwhile 
        endif 
        i -= 1
    endwhile
    return None 
EndFunction 

;----------------------------------------------------------------------------------------------------
; Thread_Scene Functions 
;----------------------------------------------------------------------------------------------------
Function SetThread_Scene(int tid, SkyrimNet_SexLab_Scene scene) 
    if scene == scene_generic
        Trace("SetThread_Scene", "can not set scene_generic to thread_scene")
        return 
    endif 
    ResizeThreadSceneAsNeeded(tid)
    thread_scene[tid] = scene
EndFunction

Function ResizeThreadSceneAsNeeded(int tid)

    if tid >= thread_scene.length
        Trace("ResizeThreadSceneAsNeeded","tid:"+tid+" thread_scene.length:"+thread_scene.length)
        int new_size = tid + 10
        Form[] resized = Utility.CreateFormArray(new_size)
        int i = 0
        int length = thread_scene.length
        while i < length 
            resized[i] = thread_scene[i]
            i += 1
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
        String question = speaker.GetDisplayName()+" is trying to stop "+scene.GetActivityMessage(scene.ACTIVITY_STAGE_ONGOING)+", will you allow it?"
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
                +scene.GetActivityMessage(scene.ACTIVITY_STAGE_ONGOING)+"."
            DirectNarration(message, speaker)
            return
        endif 
    endif 

    scene.AnimationEnd(speaker,style)
    threadSlots.StopThread(scene.GetThread())
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

    SkyrimNet_SexLab_Scene_Creator creator = CreateCreator(actors, speaker, target)
    creator.SetUp(actors, speaker, target) 
    if creator.LockAllActorLock()
        creator.SetActivity(activity) 
        if victim != None 
            creator.SetVictim(victim)
        endif 
        Trace("Action_Start","--- a")
        creator.SetTag(tag) 
        Trace("Action_Start","--- b")
        creator.SetStyle(style) 
        Trace("Action_Start","--- c")
        creator.SetEventHook(event_hook) 
        Trace("Action_Start","--- c")
        creator.SetEventHook(event_hook) 
        Trace("Action_Start","--- d")
        creator.Start() 
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
        Trace("GetthreadsJson","main is None")
        return ""
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
    String json = '{"speaker_having_sex"'+JsonBool(speaker_having_sex)
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