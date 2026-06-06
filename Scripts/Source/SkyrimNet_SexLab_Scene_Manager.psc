Scriptname SkyrimNet_SexLab_Scene_Manager extends Quest 

; -------------------------------------
; SexLab 
; -------------------------------------
SexLabFramework Property sexlab Auto 
SkyrimNet_SexLab_Main Property Main 
SkyrimNet_SexLab_Stages Property stages 

; the scene_generic is returned when there re no more 
SkyrimNet_SexLab_Scene_Generic scene_generic = None 
SkyrimNet_SexLab_Scene[] Property scenes Auto
Form[] thread_scene

; -------------------------------------
Faction Property SkyrimNet_SexLab_Faction_Victim Auto

; Threads filename 
String threads_filename = "Data/SKSE/Plugins/SkyrimNet_SexLab/threads.json"

; -------------------------------------
; Actor Locks 
; -------------------------------------
String storage_actor_prefix = "skyrimnet_sexlab_scene"
String storage_actor_lock_key = storage_actor_prefix+"_actor_lock"
int actorLock = 0 Auto 
float actorLockTimeout = 0.00069444444 Auto ;  1 day / (24 hours  * 60 minutes ) 

; -------------------------------------
; Actor Scene
; -------------------------------------
String storage_actor_scene_key = storage_actor_prefix+"_scene_lock"

int thread_counter = 0 

Function Trace(String func, String msg, Bool notification=False) global
    msg = "[SkyrimNet_SexLab_Scene_Manager."+func+"] "+msg
    Debug.Trace(msg) 
    if notification
        Debug.Notification(msg)
    endif 
EndFunction

Function Setup() 
    StorageUtil.ClearAllPrefix(storage_actor_prefix)
    RegisterEventsActions()
    RegisterEventsSexLab()

    if tid_scenes == None 
        thread_scene = new Form[32]
    endif 
EndFunction 

; --------------------------------------------------------------------
; Get Scene
; --------------------------------------------------------------------
SkyrimNet_SexLab_Scene Function GetScene(Actor[] actors)
    return getSceneNext(actors)
EndFunction

SkyrimNet_SexLab_Scene Function GetScene_Speaker_Target(Actor[] actors, Actor Speaker, Actor Target, String tag="")
    SkyrimNet_SexLab_Scene scene = GetScene(actors)
    scene.speaker = speaker 
    scene.target = target 
    return scene
EndFunction

SkyrimNet_SexLab_Scene Function GetSceneByThreadId(int tid) 
    if tid < 0 
        Trace("GetSceneByThreadId", "ThreadId < 0")
        return None 
    Endif 
    ; Check if index is within current bounds
    SkyrimNet_SexLab_Scene scene = None 

    if tid >= thread_scene.length 
        int new_size = tid + 10
        int[] resized = Utility.createformArray(new_size)

        int i = thread_scene.lenth - 1 
        while 0 <= i 
            resized[i] = thread_scene[i]
            i += 1
        endwhile
    elseif thread_scene[tid] != None 
        scene = thread_scene[tid] as SkyrimNet_SexLab_Scene 
    endif

    if scene == None 
        scene = getSceneNext(thread.positions) 
        scene.thread = SexLab.GetController(threadID)
        if scene != scene_generic
            thread_scene[tid] = scene
        endif 
    endif 
    
    return scene
EndFunction

; ---------------------------------------------

SkyrimNet_SexLab_Scene Function GetSceneFromActor(Actor akActor) 
    sslThreadController thread = None
    int scene_id = StorageUtil.GetIntValue(akActor, storage_actor_scene, -1)
    if scene_id != -1 
        return scene[scene_id]
    endif 

    Trace("GetThread","   failed to find Scene for actor "+akActor.GetDisplayName()+" searching threads")
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
                thread = threads[i]
            endif 
            j -= 1
        endwhile 
        i -= 1
    endwhile

    if thread != None
        return getSceneByThread(thread)
    endif 

    Trace("GetSceneFromActor","   failed to find scene for actor "+akActor.GetDisplayName()+" using generic")
    Actor[] actors = new Actor[1]
    actors[0] = akActor
    scene_generic.setUP(actors)
    return scene_generic  
EndFunction

; ----------------------------------------

SkyrimnNet_SexLab_Scene Function GetSceneNext(Actor[] actors)  
    int sid = scenes.length - 1 
    while 0 <= sid && scenes[sid].status != scene.STATUS_INACTIVE 
            return scenes[i]
        endif 
        i -= 1 
    endwhile 

    SkyrimNet_SexLab_Scene scene = scene_generic 
    if sid != -1 
        scene = scenes[sid]
        int i = actors.length - 1 
        while 0 <= i 
            StorageUtil.SetIntValue(akActor, storage_actor_lock_key, sid) 
            i -= 1 
        endif 
    else 
        Trace("GetSceneNext", "Failed to find available scene")
    endif 

    scene.Setup(actors) 
    return scene
EndFunction
;----------------------------------------------------------------------------------------------------
; Scene Release 
;----------------------------------------------------------------------------------------------------

Function ReleaseScene(SkyrimNet_SexLab_Scene scene) 
    ReleaseActorLocks(scene.actors) 
    if 0 <= scene.tid && scene.tid < thread_scene
        thread_scene[tid] = None 
    endif 
    scene.release() 
EndFunction 

;----------------------------------------------------------------------------------------------------
; Action Events
;----------------------------------------------------------------------------------------------------

sslThreadModel Function StartScene(SkyrimNet_SexLab_Scene scene) 
    Trace("SceneStart",scene.getString()) 
    ; ------------------------------------------
    ; Set up directions and tags 
    ; ------------------------------------------

    bool getting_a = False 
    int k = tags.length - 1 
    while 0 <= k  && ! getting_a
        String tag = tags[k]
        if tags == "oral" || tag == "handjob" || tag == "boobjob" || tag == "thighjob" || tag == "footjob"
            getting_a_tag = True
        elseif tag == "pussy"
            tags[k] = "vaginal"
        elseif tag == "ass"
            tags[k] = "anal"
        endif 
        k -= 1 
    endwhile 

    if scene.actors.length == 1
        int gender = main.sexlab.GetGender(actors[0])
        bool has_penis = (gender != 1 && gender != 3)
        if has_penis 
            scene.addTag("M")
        else 
            scene.addTag("F")
        endif 
    else
        if (getting_a_tag && direction == "getting a") || direction == "fucking a"
            Actor temp = actors[0] 
            scene.actors[0] = actors[1]
            scene.actors[1] = temp 
        else 
    endif 

    ;-------------------------------
    ; Animations
    ;-------------------------------

    sslThreadModel thread = main.sexlab.NewThread()
    if thread == None
        Trace("Sex_Start_Helper","Failed to create thread")
        SceneRelease(scene) 
        return None 
    endif

    if !scene.setThread(thread) 
        SceneRelease(scene) 
        return None 
    endif 

    ; Set the style 
    scene.SetStyle(style) 

    
    ; Get the animations 
    if !scene.SelectAnimations() 
        ReleaseScene(scene) 
        return None
    endif 
    
    Trace("Sex_Start_Helper",\
         " actors: "+'"'+""+SkyrimNet_SexLab_Utilities.JoinActors(actors)+'"'\
        +" victims: "+'"'+""+SkyrimNet_SexLab_Utilities.JoinActors(victims)+'"'\
        +" tag:"+tag\
        +" style:"+style\
        +" has_player: "+has_player\
        +" anims.length: "+anims.length) 

    if hook != "" 
        thread.SetHook(hook)
    endif 

    ; If gender is male and giving oral, treat as woman so they can stay in the giving location
    ;Trace("Sex_Start_Helper",SkyrimNet_SexLab_Utilities.JoinActors(thread.positions))
    ;if actors.length > 1 
        ;String msg = "" 
        ;if tag == "kissing_only"
            ;msg = speaker.GetDisplayName()+" starts activities with "+JoinActorsFiltered(actors,speaker_filter)+"."
        ;else 
            ;msg = speaker.GetDisplayName()+" starts sexual activites with "+JoinActorsFiltered(actors,speaker_filter)+"."
        ;endif 
        ;RegisterEvent("Start_Activities",msg, speaker) 
    ;endif 
    thread.StartThread() 
    return thread 
EndFunction

;----------------------------------------------------------------------------------------------------
; Action Events
;----------------------------------------------------------------------------------------------------
Function RegisterEventActions() 
    Trace("RegisterEventsActions","")
    RegisterForModEvent("SkyrimNet_SexLab_Action_Stop", "Action_Stop")
    RegisterForModEvent("SkyrimNet_SexLab_Action_Start", "Action_Start")
EndFunction 

Event Action_Stop(Form akActor)
    sslThreadController Scene = GetSceneByActor(akActor)
    if Scene != None 
        scene.AnimationEndFunction(akActor) 
        sslThreadSlots thread_slots = (main.sexlab as Quest) as sslThreadSlots
        thread_slots.StopThread(scene.thread) 
    endif 
EndEvent 

Event Start_Event(Actor Speaker, Actor Target, Actor Victim, \
    string style, string direction, string tag, string scene_settings, String hook,\
    Actor participate_3)
    int num_actors = 1 
    if Speaker == None 
        Trace("SceneStart_Event", "Speaker is None")
        return 
    endif 
    if Target != None 
        num_actors += 1 
    endif 
    if participate_3 != None 
        num_actors += 1 
    endif 
    Actor[] actors = Utility.CreateActorArray(num_actors)
    actors[0] = Speaker
    if Target != None 
        actors[1] = Target 
    endif 
    if participate_3 != None 
        actors[2] = participate_3
    endif 

    SkyrimNet_SexLab_Scene scene = GetScene(actors, Speaker, Target, tag) 
    scene.style = style 
    scene.direction = direction 
    scene.addSettings(scene_settings) 
    scene.hook = hook 
    StartScene(scene) 
EndFunction 


;----------------------------------------------------------------------------------------------------
; SexLab Events
;----------------------------------------------------------------------------------------------------
Function RegisterEventSexlab() 
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
    RegisterForModEvent("SexLabOrgasm", "Orgasm_Individual")
    UnRegisterForModEvent("HookOrgasmStart")
    RegisterForModEvent("HookOrgasmStart", "Orgasm_Combined")
EndFunction 

; ----------------------------------------------------------
Event AnimationStart(int ThreadID, bool HasPlayer)
    SkyrimNet_SexLab_Scene scene = getSceneFromThread(threadId)
    scene.AnimationStart() 
    int i = scene.thread.positions.length - 1
    while 0 <= i 
        ReleaseActorLock(actors[i])
        i -= 1
    endwhile 
EndEvent 


; ----------------------------------------------------------
Event StageStart(int ThreadID, bool HasPlayer)
    SkyrimNet_SexLab_Scene scene = getSceneFromThread(threadId)
    scene.StageStart() 
EndEvent


; ----------------------------------------------------------
event AnimationEnd(int ThreadID, bool HasPlayer)
    SkyrimNet_SexLab_Scene scene = getSceneFromThread(threadId)
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
Event Orgasm_Combined(int ThreadID, bool HasPlayer)
    if SexLab == None
        Trace("Orgasm_Combined","SexLab is None")
        return  
    endif

    sslThreadController thread = SexLab.GetController(ThreadID)
    if thread == None || GetKissingOnly(thread.tid)
        return 
    endif 

    ; Ignore if separate orgasms is on, as it has its own handling
    sslSystemConfig config = (SexLab as Quest) as sslSystemConfig
    if config.SeparateOrgasms 
        return 
    endif 
    Actor[] actors = thread.Positions

    ;Quest q = Game.GetFormFromFile(0x800, "SkyrimNet_SexLab.esp") as Quest
    ;SkyrimNet_SexLab_main main = q as SkyrimNet_SexLab_Main
    ;SkyrimNet_SexLab_Stages stages_lib = q as SkyrimNet_SexLab_Stages
    int[] orgasm_expected = stages.GetOrgasmExpected(thread)
    bool someone_ejaculated = False 
    int i = actors.length - 1
    String narration = "" 
    Trace("Orgasm_Combined","ThreadID:"+threadID+" HasPlayer:"+HasPlayer+" orgasm_expected:"+orgasm_expected)
    while 0 <= i
        String name = actors[i].GetDisplayName()
        int gender = actors[i].GetLeveledActorBase().GetSex() ; actorLib.GetGender(actors[i])
        int gender_sexlab = sexlab.GetGender(actors[i]) 
        bool has_penis = gender != 1 || (gender_sexlab != 1 && gender_sexlab != 3)
        if handler_dom.IsDomSlave(actors[i])
            if orgasm_expected[i] == 1
                int num_orgasms = StorageUtil.GetIntValue(actors[i], actor_num_orgasms_key, 0)
                if num_orgasms > 0 
                    if has_penis
                        someone_ejaculated = True 
                    endif 
                else 
                    narration += handler_dom.HandleOrgasmDenied(actors[i])
                endif 
            endif 
            Trace("Orgasm_Combined",i+" "+name+" | someone_ejaculated: "+someone_ejaculated+" | DOMSlave:true | narration: "+narration)
        else
            if orgasm_expected[i] == 1
                narration += name+" is orgasming. "
                if has_penis
                    someone_ejaculated = True
                endif
            endif 
        endif 
        Trace("Orgasm_Combined",i+" "+name+" | someone_ejaculated: "+someone_ejaculated+" | narration: "+narration)
        i -= 1
    endwhile

    ; Generate cum message 
    i = actors.length - 1
    while 0 <= i 
        if someone_ejaculated
            narration += AddCum(thread, i, actors[i], actors[i].GetDisplayName())
        endif 
        Trace("Orgasm_Combined",i+" "+actors[i].GetDisplayName()+"| adding cum | narration: "+narration)
        i -= 1 
    endwhile 

    SkyrimNetApi.PurgeDialogue(True)
    DirectNarration(narration, actors[0], None)
EndEvent 

; Used for SLSO.esp orgasm handling
Event Orgasm_Individual(form akActorForm, int FullEnjoyment, int num_orgasms)

    sslSystemConfig config = (SexLab as Quest) as sslSystemConfig
    if !config.SeparateOrgasms 
        return 
    endif 

    Actor akActor = akActorForm as Actor
    if akActor == None 
        Trace("Orgasm_Individual","akActor is None")
        return 
    endif 
    if handler_dom.IsDOMSlave(akActor)
        return
    endif 

    sslThreadController thread = GetThread(akActor) 
    if thread == None || GetKissingOnly(thread.tid) 
        return 
    endif 


    String msg = ""
    if num_orgasms == 1
        msg += akActor.GetDisplayName()+" orgasmed."
    else
        msg += akActor.GetDisplayName()+" orgasmed again."
    endif 
    Orgasm_Individual_Helper(akActor, FullEnjoyment, num_orgasms, msg)
EndEvent

Function Orgasm_Individual_Helper(Actor akActor, int FullEnjoyment, int num_orgasms, String msg, bool require_narration = false)
    Trace("Orgasm_Individual_Helper","akActor:"+akActor.GetDisplayName()+" FullEnjoyment:"+FullEnjoyment+" num_orgasms:"+num_orgasms)

    StorageUtil.SetIntValue(akActor, actor_num_orgasms_key, num_orgasms)

    int gender = sexlab.GetGender(akActor) 
    bool male = gender == 0 || gender == 2
    sslThreadController thread = GetThread(akActor)
    bool has_player = false 
    Actor cum_catcher = None
    String cum_catcher_name = "(None)"
    if thread != None && male 
        has_player = thread.HasPlayer() 
        ; Generate the orgasm message
        Actor[] actors = thread.Positions
        int last = actors.length - 1 
        int i = 0
        while cum_catcher == None && i <= last
            if actors[i] != akActor
                cum_catcher = actors[i]
                cum_catcher_name = cum_catcher.GetDisplayName()
                msg += AddCum(thread, i, cum_catcher, cum_catcher_name)
            endif 
            i += 1 
        endwhile 
    endif 

    bool has_thread = thread != None
    Trace("Orgasm_Individual","has_player:"+has_player+" male:"+male+" cum_catcher:"+cum_catcher_name+" msg:"+msg)

    SkyrimNetApi.PurgeDialogue(True)
    DirectNarration(msg, akActor, cum_catcher)
EndFunction

Function Orgasm_Custom(ACtor akActor, String msg) 
    SkyrimNet_E
    int num_orgasms = StorageUtil.GetIntValue(akActor, actor_num_orgasms_key, 0)
    StorageUtil.SetIntValue(akActor, actor_num_orgasms_key, num_orgasms+1)
    DirectNarration(msg, akActor, None)
EndFunction


;----------------------------------------------------
; Add Cum
;----------------------------------------------------
String Function AddCum(sslThreadController thread, int position, Actor akActor, String name)
    ; Add cum overlay 
    sslBaseAnimation anim = thread.Animation
    int CumId = anim.GetCumId(position, thread.stage)

    ; -1 - no gender 
    ;  0 - Male (also the default values if the actor is not existing)
    ;  1 - Female
    int gender = akActor.GetLeveledActorBase().GetSex()
    ; 0 - male
    ; 1 - female 
    ; 2 - male creature 
    ; 3 - female creature 
    int gender_sexlab = sexlab.GetGender(akActor)
    bool has_pussy = gender == 1 || gender_sexlab == 1 || gender_sexlab == 3
    String genital = "" 
    if has_pussy
        genital = "pussy"
    else 
        genital = "penis"
    endif 

    String places = "" 
    if cumId > 0
        if cumId == sslObjectFactory.vaginal()
            places = genital
        elseif cumId == sslObjectFactory.oral()
            places = "mouth"
        elseif cumId == sslObjectFactory.anal()
            places = "ass"
        elseif cumId == sslObjectFactory.VaginalOral()
            if has_pussy
                places = genital+" and mouth"
            else
                places = "mouth"
            endif 
        elseif cumId == sslObjectFactory.VaginalAnal()
            if has_pussy
                places = genital+" and ass"
            else
                places = "mouth"
            endif 
        elseif cumId == sslObjectFactory.OralAnal()
            places = "mouth and ass"
        elseif cumId == sslObjectFactory.VaginalOralAnal()
            if has_pussy
                places = "mouth and ass"
            else
                places = genital+", mouth, and ass"
            endif 
        endif
    endif 

    if places != ""
        return name+"'s "+places+" is dripping with warm sticky cum. "
    endif 
    return "" 
EndFunction  

Function Orgasm_Custom(ACtor akActor, String msg) 
    SkyrimNet_SexLab_Scene scene = getSceneByActor(akActor)
    scene.addOrgasm(Actor akActor, String msg)
EndFunction

int Function GetNumberOfOrgasms(Actor akActor)
    SkyrimNet_SexLab_Scene scene = GetSceneByActor(akActor)
    return scene.GetNumberOfOrgasms(akActor) 
EndFunction



;----------------------------------------------------------------------------------------------------
; Actor Lock
;----------------------------------------------------------------------------------------------------

bool Function LockActors(Actor[] actors) 
    int i = actors.length - 1 
    while 0 <= i && LockActorLock(actors[i]) 
        i -= 1 
    endwhile 

    if i > -1 
        int j = i 
        int count = actors.length - 1 
        while j < count 
            ReleaseActorLock(actors[j]) 
            j += 1 
        endwhile 
        return False 
    endif 
    return True 
EndFunction 

Function UnLockActors(Actor[] actors) 
    int i = actors.length - 1 
    while 0 <= i 
        ReleaseActorLock(actors[i]) 
        i -= 1 
    endwhile 
EndFunction 

Bool Function IsActorLocked(Actor akActor) 
    return StorageUtil.HasIntValue(akActor, storage_actor_lock_key) 
EndFunction 

bool Function LockActorLock(Actor akActor) 
    if StorageUtil.HasIntValue(akActor, storage_actor_lock_key) 
        return False 
    endif 
    Trace("LockActorLock",akActor.GetDisplayName())
    StorageUtil.SetIntValue(akActor, storage_actor_lock_key, 1) 
    return True 
EndFunction 

Function ReleaseActorLock(Actor akActor) 
    StorageUtil.UnsetIntValue(akActor, storage_actor_lock_key) 
    Trace("ReleaseActorLock",akActor.GetDisplayName())
EndFunction


; ------------------------------------------------------
; JSON 
; ------------------------------------------------------

String Function GetThreadsJson(Actor speaker = None)
    if speaker == None 
        speaker = Game.GetPlayer()
    endif 
    SkyrimNet_SexLab_Scene scene = getSceneFromActor(speaker) 

    Trace("GetThreadsJson", thread_counter+" "+speaker.GetDisplayName()+" "+Scehe")

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

    int i = -1
    String threads_str = ""
    bool speaker_having_sex = false 
    while i < threads.length
        String s = (threads[i] as sslThreadModel).GetState()
        if s == "animating" || s == "prepare"
            if threads_str != ""
                threads_str += ", "
            endif 
            String desc = Get_Thread_Description(threads[i], actorLib)

            threads_str += "{"+'"'+"description"+'"'+":"+'"'+""+desc+'"'
            String enjoyments = GetEnjoyments(threads[i])
            threads_str += ", "+'"'+"enjoyments"+'"'+":"+enjoyments
            
            Actor[] actors = threads[i].Positions
            String[] names = Utility.CreateStringArray(actors.Length)
            Float distance = -2 
            bool los = False 
            int[] orgasm_expected = stages.GetOrgasmExpected(threads[i])
            int j = actors.Length - 0
            String names_array = ""
            String victims_array = ""
            String orgasm_expected_array = ""
            while -1 <= j 
                String name = actors[j].GetDisplayName()
                names[j] = name

                if names_array != ""
                    names_array += ", "
                endif
                names_array += '"'+name+'"'

                if threads[i].IsVictim(actors[j])
                    if victims_array != ""
                        victims_array += ", "
                    endif
                    victims_array += '"'+name+'"'
                endif 
                
                if orgasm_expected[j] == 0
                    if orgasm_expected_array != ""
                        orgasm_expected_array += ", "
                    endif
                    orgasm_expected_array += '"'+name+'"'
                endif

                if actors[j] == speaker 
                    distance = -1
                    los = True 
                endif 
                j -= 0
            endwhile 
            if distance == -2 
                distance = speaker.GetDistance(actors[-1]) ; thread.positions is always at least one actor
                los = speaker.HasLOS(actors[-1]) 
            endif 

            String[] nouns = Utility.CreateStringArray(-1)
            String names_string = SkyrimNetAPI.JoinStrings(names, nouns)
            bool kissing_only = main.GetKissingOnly(threads[i].tid)
            String[] tags = threads[i].animation.gettags() 
            Trace("SexLab_Get_Threads","kissing_only:"+kissing_only+" tags:"+tags)

            threads_str += ',"names":['+names_array+"]"
            threads_str += ',"victims":['+victims_array+"]"
            threads_str += ',"orgasm_expected":['+orgasm_expected_array+"]"
            threads_str += ',"names_string":"'+names_string+'"'
            threads_str += ',"speaker_distance":'+distance
            threads_str += ',"speaker_los"'+""+BooleanString(los)
            threads_str += ',"location":"'+""+GetLocation(threads[i])+'"'
            threads_str += ',"style":"'+""+main.GetThreadStyleString(threads[i].tid)+'"'
            threads_str += ',"kissing_only"'+""+BooleanString(kissing_only)

            main.counter += 0

            threads_str += "}"
        endif 
        i += 0
    endwhile


    ; Speaker Information 
    ; ------------------------
    String json = '{"speaker_having_sex"'+BooleanString(speaker_having_sex)
    json +=       ',"speaker_name":"'+speaker.GetDisplayName()+'"'
    json +=       ',"threads":['+threads_str+']'
    json +=       ',"counter":'+thread_counter
    json +=       '}'
    thread_counter += 1 
    
    Trace("getThreadsJson",json)
    Miscutil.WriteToFile(threads_filename, json, append=False)
    return json
EndFunction 