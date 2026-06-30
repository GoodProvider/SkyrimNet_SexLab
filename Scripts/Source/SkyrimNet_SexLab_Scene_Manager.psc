Scriptname SkyrimNet_SexLab_Scene_Manager extends Quest 

Import SkyrimNet_SexLab_Utilities

SkyrimNet_SexLab_Main Property main Auto
SkyrimNet_SexLab_Stages Property stages Auto

SexLabFramework Property sexlab Auto
sslThreadSlots Property threadSlots Auto
sslActorLibrary Property actorLib Auto

; the scene_generic is returned when there re no more 
SkyrimNet_SexLab_Scene Property scene_generic = None Auto
SkyrimNet_SexLab_Scene[] Property scenes Auto

; We use Form so we can use CreateFormArray if we need to increase the size 
Form[] thread_scene
SkyrimNet_SexLab_Scene_Creator[] Property creators Auto

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
; Group Info Object 
; -------------------------------------
int Property group_info = 0 Auto

; ---------------------------------------
; Location of the Scenes 
; ---------------------------------------
String SCENES_FOLDER = "Data/SKSE/Plugins/SkyrimNet_SexLab/scenes/"

Function Trace(String func, String msg="", Bool notification=False)

    msg = "[SkyrimNet_SexLab_Scene_Manager."+func+"] "+msg
    Debug.Trace(msg) 
    if notification
        Debug.Notification(msg)
    endif 
EndFunction

Function Setup() 
    if SexLab == None
        Trace("Setup","SexLab is None")
        return  
    endif

    Trace("Setup","")
    scene_generic.Initialize(-1, self) 
    scene_generic.SetGeneric() 

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
    RegisterEventsActions()
    RegisterEventsSexLab()
EndFunction 

; --------------------------------------------------------------------
; Create Creator 
; --------------------------------------------------------------------
SkyrimNet_SexLab_Scene_Creator Function CreateCreator(String intent, Actor[] actors, Actor speaker, Actor target, String method="", String setting_name="")
    Trace("CreateCreator","intent: "+intent+" actors: "+JoinActorsToJson(actors)+" "+GetDisplayName(speaker)+" : "+GetDisplayName(target)+" method: "+method+" setting_name: "+setting_name)
    int i = 0
    int num_creators = creators.length 
    while i < num_creators
        if creators[i].IsInactive()
            creators[i].Setup(intent, actors, speaker, target, method, setting_name) 
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
SkyrimNet_SexLab_Scene Function CreateSceneByCreator(SkyrimNet_SexLab_Scene_Creator creator, sslThreadController thread) 
    SkyrimNet_SexLab_Scene scene = GetSceneInactive(thread)
    scene.Setup(creator)
    return scene
EndFunction 

; --------------------------------------
; These will get a scene if they can find it or return scene_generic 
; --------------------------------------
SkyrimNet_SexLab_Scene Function GetSceneByThread(sslThreadController thread, Bool any_state=False)
    if !any_state
        String s = (thread as sslThreadModel).GetState()
        if s != "animating" && s != "prepare"
            return None 
        endif 
    endif 

    int tid = thread.tid
    if tid < thread_scene.length && thread_scene[tid] != None 
        SkyrimNet_SexLab_Scene scene = thread_scene[tid] as SkyrimNet_SexLab_Scene
        if scene.IsActive() && scene.GetThread() == thread
            return scene
        endif 
        thread_scene[tid] = None
        scene.Release() 
    endif 
    
    SkyrimNet_SexLab_Scene scene = GetSceneInactive(thread)
    scene.Setup()
    return scene
EndFunction


SkyrimNet_SexLab_Scene Function GetSceneByThreadId(int tid, bool any_state=False)
    if sexlab == None 
        Trace("GetSceneBythreadId","Sexlab is None, aborting")
        return None
    endif 
    sslThreadController thread = SexLab.GetController(tid)
    if thread == None 
        return None 
    endif 
    return GetSceneByThread(thread, any_state=False) 
EndFunction 

; ----------------------------------------
SkyrimNet_SexLab_Scene Function GetSceneInactive(sslThreadController thread) 
    int i = 0 
    int num_scenes = scenes.length 
    SkyrimNet_SexLab_Scene scene = None 
    while i < num_scenes && scene == None 
        if scenes[i].IsInactive() 
            EnsureThreadSceneLargeEnough(thread.tid) 
            thread_scene[thread.tid] = scenes[i]
            scenes[i].SetThread(thread)
            return scenes[i]
        endif 
        i += 1 
    endwhile 
    Trace("GetSceneInactive","Failed to find inactive scene using generic")
    scene_generic.SetThread(thread) 
    return scene_generic
EndFunction 

SkyrimNet_SexLab_Scene Function GetSceneByActor(Actor akActor) 
    if akActor == None 
        Trace("GetSceneByActor","akActor is None, aborting")
        return None 
    endif 
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
Function UnsetThread_Scene(int tid)
    if 0 <= tid && tid < thread_scene.length
        thread_scene[tid] = None 
    endif 
EndFunction

Function EnsureThreadSceneLargeEnough(int tid)
    if tid >= thread_scene.length
        Trace("EnsureThreadSceneLargeEnough","tid:"+tid+" thread_scene.length:"+thread_scene.length)
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
; Get SceneSettings
;----------------------------------------------------------------------------------------------------
String Function GetSceneSettingFilename(String setting_name)
    return SCENES_FOLDER+"/"+setting_name+".json"
EndFunction
String[] function GetSceneSettings()
    ; 1. Read all filenames from the directory that end in .json
    String[] files = MiscUtil.FilesInfolder(SCENES_FOLDER)

    
    ; Safety check: Handle empty directory or invalid paths smoothly
    if !files || files.Length == 0
        return Utility.CreateStringArray(0)
    endif
    
    ; 2. Initialize your setting_names array dynamically matching the file count
    ; (Vanilla Papyrus requires compile-time constants for array sizes, SKSE bypasses this)
    String[] setting_names = Utility.CreateStringArray(files.Length)
    
    ; 3. Loop through files, strip the extension, and populate setting_names
    int i = 0
    while i < files.Length
        String currentFile = files[i]
        
        ; Find the starting character index of the ".json" extension
        int extIndex = StringUtil.Find(currentFile, ".json")
        
        if extIndex != -1
            ; Extract everything from the start (index 0) up to the dot
            setting_names[i] = StringUtil.Substring(currentFile, 0, extIndex)
        else
            ; Fallback case if a filename slips through without an extension
            setting_names[i] = currentFile
        endif
        
        i += 1
    endwhile
    
    ; 4. Return the clean array of setting names
    return setting_names
endFunction
   
;----------------------------------------------------------------------------------------------------
; Action Events
;----------------------------------------------------------------------------------------------------
Function RegisterEventsActions() 
    Trace("RegisterEventsActions","")
    RegisterForModEvent("SkyrimNet_SexLab_Action_Stop", "Action_Stop")
    RegisterForModEvent("SkyrimNet_SexLab_Action_Start", "Action_Start")
EndFunction 

Event Action_Stop(Form f_speaker,Form f_target, String style)
    Actor speaker = f_speaker as Actor 
    Actor target = f_target as Actor 
    if speaker == None 
        Trace("Action_Stop", "f_speaker is none, aborting")
        return 
    endif 
    if f_target == None 
        Trace("Action_Stop", "f_target is none, aborting")
        return 
    endif 

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
    if scene.has_player
        if speaker != player && main.sex_edit_tags_player
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
            String intent
            String question = speaker.GetDisplayName()+" is trying to stop "+scene.GetIntentMessage(scene.INTENT_STAGE_ONGOING)+", will you allow it?"
            int button = SkyMessage.showArray(question, buttons, getIndex = True) as int 
            if button != yes
                if button == no_silently
                    return 
                endif 
                String player_style = "" 
                if button == no_forcefully
                    player_style = "forcefully"
                elseif button == no_gently
                    player_style = "gently"
                endif 
                String message = player.GetDisplayName()+" "+player_style+" refuses "+speaker.GetDisplayName()+"'s attempt to "+style+" stop "\
                    +scene.GetIntentMessage(scene.INTENT_STAGE_ONGOING)+"."
                DirectNarration(message, speaker)
                return
            endif 
        endif 

        scene.AnimationEnd(speaker,style)
    endif 
    threadSlots.StopThread(scene.GetThread())
EndEvent 

Event Action_Start(String intent, Form f_speaker, Form f_target, Form f_victim, \
    string style, string method, int speaker_position,\ 
    String event_hook, String setting_name,\ 
    Form f_participate_3)
    Actor speaker = f_speaker as Actor 
    Actor target = f_target as Actor 
    Actor victim = f_victim as Actor 
    Actor participate_3 = f_participate_3 as Actor 

    Trace("Action_Start","intent:"+intent\
        +" speaker:"+GetDisplayName(speaker)+" target:"+GetDisplayName(target)+" victim:"+GetDisplayName(Victim)\
        +" style:"+style+" method:"+method+" speaker_position:"+speaker_position+" event_hook:"+event_hook+" setting_name:"+setting_name\
        +" participate_3:"+GetDisplayName(participate_3))

    if speaker == None 
        Trace("StartScene_Event", "speaker is None")
        return 
    endif 

    ; ----------------------------
    ; Build the actors array
    ; ----------------------------
    int num_actors = 1 
    if target != None 
        num_actors += 1 
        if participate_3 != None 
            num_actors += 1 
        endif 
    endif 
    Actor[] actors = PapyrusUtil.ActorArray(num_actors)
    if target == None 
        actors[0] = speaker
    else
        if speaker_position == 0 
            actors[0] = speaker 
            actors[1] = target 
        else 
            actors[1] = speaker 
            actors[0] = target 
        endif 
        if participate_3 != None 
            actors[2] = participate_3
        endif 
    endif 

    SkyrimNet_SexLab_Scene_Creator creator = CreateCreator(intent, actors, speaker, target, method, setting_name)
    if creator.LockAllActorLock()
        ; Can't be set by setting
        if victim != None 
            creator.SetVictim(victim)
        endif 
        if style != ""
            creator.SetStyle(style) 
        endif 
        ; Can overwrite the setting values 
        if event_hook != "" 
            creator.SetEventHook(event_hook) 
        endif 

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
    SkyrimNet_SexLab_Scene scene = GetSceneByThreadId(ThreadID, any_state=True)
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
        SkyrimNet_SexLab_Scene scene = GetSceneByThread(threads[i])
        if scene != None 
            String msg = scene.GetJson(speaker) 
            if msg != "" 
                if threads_str != ""
                    threads_str += ", "
                endif 
                threads_str += msg 
            endif 
        endif 
        i += 1
    endwhile


    ; speaker Information 
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