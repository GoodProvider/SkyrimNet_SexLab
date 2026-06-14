Scriptname SkyrimNet_SexLab_Scene extends Quest


SkyrimNet_SexLab_Main Property main Auto
SkyrimNet_SexLab_Stages Property stages Auto
SkyrimNet_SexLab_Scene_Manager Property manager Auto 
SexLabFramework Property sexlab Auto
sslThreadSlots Property ThreadSlots Auto

Faction Property SkyrimNet_SexLab_Faction_Victim Auto

Import SkyrimNet_SexLab_Utilities

; --------------------------------------------
; Scene id == index in scenes
; --------------------------------------------
int Property sid = 0 Auto 

; --------------------------------------------
; Style
; --------------------------------------------
String Property STATUS_INACTIVE = "INACTIVE" Auto
String Property STATUS_SETUP = "SETUP" Auto
String Property STATUS_ACTIVE = "ACTIVE" Auto
string Property status = "INACTIVE" AUTO

; --------------------------------------------
; Style
; --------------------------------------------
String Property STYLE_FORCEFULLY = "forcefully" Auto
String Property STYLE_NORMALLY = "normally" Auto
String Property STYLE_GENTLY = "gently" Auto
String Property style Auto

; --------------------------------------------
; Buttons 
; --------------------------------------------
int BUTTON_YES = 0
int BUTTON_YES_RANDOM = 1
int BUTTON_NO_SILENT = 2
int BUTTON_NO = 3

; --------------------------------------------
; Actors 
; --------------------------------------------
Actor Property Speaker Auto
Actor Property Target Auto

int num_actors = 0 
Actor[] Property actors Auto
int num_victims = 0 
Actor[] Property victims Auto 
int[] victim_mask
int[] assailant_mask
int[] hermaphrodiate_mask
int[] strapon_mask

String actor_names = ""
String actor_names_json = ""

String victim_names = ""
String victim_names_json = ""

String assailant_names = "" 

String creature_descriptions = "" 
String hermaphrodiate_names = "" 
String strapon_names = "" 


Actor sender = None 
Actor receiver = None 

int[] total_orgasms = None 

; -------------------------------------
; Actor Locks 
; -------------------------------------
String storage_actor_lock_key = "skyrimnet_sexlab_scene_actor_lock"
int actorLock = 0 Auto 
float actorLockTimeout = 0.00069444444 Auto ;  1 day / (24 hours  * 60 minutes ) 

; --------------------------------------------
; Thread
; --------------------------------------------
sslThreadController thread

sslBaseAnimation[] animations = None 
; -------------------------------------------
; Activity
; -------------------------------------------
int Property ACTIVITY_STAGE_START = 0 Auto
int Property ACTIVITY_STAGE_ONGOING = 1 Auto
int Property ACTIVITY_STAGE_END = 2 Auto
String[] activity_stages = None 

bool sexual_assault = false 
bool player_is_victim = false 

; --------------------------------------------
; event_hook
; --------------------------------------------
String event_hook = ""

; --------------------------------------------
; Tags 
; --------------------------------------------
String[] tags = None 
String[] tags_supress = None 

int num_tags = 0 
int num_tags_supress = 9 

; --------------------------------------------
; Has Player 
; --------------------------------------------
bool has_player = False 

; --------------------------------------------
; Track Scene
; --------------------------------------------
bool tracking = False

; -------------------------------------------
; Descriptions 
; -------------------------------------------

Function Trace(String func, String msg="", Bool notification=False) global
    msg = "[SkyrimNet_SexLab_Scene."+func+"] "+msg
    Debug.Trace(msg) 
    if notification
        Debug.Notification(msg)
    endif 
EndFunction

Function Setup(Actor[] _actors, Actor _speaker, Actor _target)
    Trace("Setup","actors: ["+JoinActors(_actors)+"] speaker:"+GetDisplayName(_speaker)+" target:"+GetDisplayName(_target))
    if !actors || actors.length < _actors.length 
        int new_length = _actors.length+10
        actors = PapyrusUtil.ActorArray(new_length) 
        victim_mask = PapyrusUtil.IntArray(new_length,0) 
        assailant_mask = PapyrusUtil.IntArray(new_length,0) 
        total_orgasms = PapyrusUtil.IntArray(new_length,0) 
        hermaphrodiate_mask = PapyrusUtil.IntArray(new_length,0) 
        strapon_mask = PapyrusUtil.IntArray(new_length,0) 
    endif 

    if !victims 
        victims = PapyrusUtil.ActorArray(10) 
        num_victims = 0 
    endif 

    if SexLab == None 
        Trace("SkyrimNet_SexLab_Scene","SexLab is None")
        return 
    endif 
    sslActorLibrary actorLib = (SexLab as Quest) as sslActorLibrary
    if actorLib == None 
        Trace("SkyrimNet_SexLab_Scene","actorLib is None")
        return 
    endif 

    Actor player = Game.GetPlayer() 
    num_actors = 0 
    has_player = False 
    int i = 0
    int count = _actors.length
    while i < count 
        Actor akActor = _actors[i]
        if akActor != None 
            actors[num_actors] = akActor
            if player == akActor
                has_player = True 
            endif 

            victim_mask[num_actors] = 0
            assailant_mask[num_actors] = 0
            total_orgasms[num_actors] = 0

            if actorLib.GetTrans(akActor) == 0 
                hermaphrodiate_mask[num_actors] = 1 
            else 
                hermaphrodiate_mask[num_actors] = 0 
            endif 

            num_actors += 1 
        endif 
        i += 1 
    endwhile 

    SetCreatureDescriptions() 

    sexual_assault = false 

    sender = speaker
    receiver = None 
    if num_actors >= 2
         if sender == actors[0] 
            receiver = actors[1]
        else 
            receiver = actors[0]
        endif
    endif

    num_tags = 0
    num_tags_supress = 0 

    SetActivityByString("sex") 
    sexual_assault  = false 

    style = STYLE_NORMALLY
    event_hook = ""

    tracking = False
    status = STATUS_SETUP 
EndFunction 

; ---------------------------------
; Set Up Names 
; ---------------------------------
Function ShiftActorsLeft() 
    if num_actors < 2
        return 
    endif 
    Actor actor_temp = actors[0]
    int hermaphrodiate_temp = hermaphrodiate_mask[0]
    int victim_temp = victim_mask[0]
    int assailant_temp = assailant_mask[0]

    int i = 0 
    while i < num_actors - 1  
        int j = i + 1 
        actors[i] = actors[j] 
        hermaphrodiate_mask[i] = hermaphrodiate_mask[j]
        victim_mask[i] = victim_mask[j]
        assailant_mask[i] = assailant_mask[j]
        i += 1 
    endwhile 
    actors[i] = actor_temp 
    hermaphrodiate_mask[i] = hermaphrodiate_temp 
    victim_mask[i] = victim_temp 
    assailant_mask[i] = assailant_temp 
    SetNames() 
EndFunction

Function SetNames() 
    actor_names = JoinActors(actors, num_actors)
    actor_names_json = JoinActorsToJson(actors, num_actors)

    hermaphrodiate_names = JoinActorsMasked(actors, hermaphrodiate_mask, num_actors)

    victim_names = JoinActorsMasked(actors, victim_mask, num_actors)
    victim_names_json = JoinActorsToJsonMasked(actors, victim_mask, num_actors)

    assailant_names = JoinActorsMasked(actors, assailant_mask, num_actors)

    Trace("SexNames",sid+" actors:"+JoinActors(actors,num_actors)+" num_actors:"+num_actors+\
        " actor_names:"+actor_names+" actor_names_json:"+actor_names_json+\
        " hermaphrodiate_names:"+hermaphrodiate_names+" strapon_names:"+strapon_names+\
        " victim_names:"+victim_names+" victim_names_json:"+victim_names_json+\
        " assailant_names:"+assailant_names)
EndFunction 

Function SetCreatureDescriptions() 
    String desc = "" 
    int i = 0
    while i < num_actors
        Race r = actors[i].GetRace() 
        if sslCreatureAnimationSlots.HasRaceType(r) 
            String name = actors[i].GetDisplayName()
            String race_name = r.GetName() 
            desc += name+" is a "+race_name+". "
            int j = JArray.count(main.race_to_description) - 1 
            while 0 <= j 
                int creature = Jarray.getObj(main.race_to_description, j) 
                Race creature_race = JMap.getForm(creature,"form_") as Race 
                if creature_race == r 
                    desc += JMap.getStr(creature, "description_")
                    j = -1 
                else 
                    j -= 1 
                endif 
            endwhile 
        endif 
        i += 1
    endwhile
    creature_descriptions = desc
EndFunction

; -------------------------------------------------
; Victim and Assailant setters 
; -------------------------------------------------

Function SetVictim(Actor victim) 
    if !victims 
        victims = PapyrusUtil.ActorArray(10)
    endif 
    if victim == None 
        sexual_assault = False 
        num_victims = 0 
        Trace("SetVictim","victim is None")
        return
    endif 

    sexual_assault = True 
    victims[0] = victim
    num_victims = 1 
    SetVictimsMask() 
EndFunction 

Function SetVictims(Actor[] _victims) 
    num_victims = 0 
    Actor player = Game.GetPlayer() 
    player_is_victim = False
    int i = 0
    int count = _victims.length
    while i < count 
        if _victims[i] != None 
            if _victims[i] == player
                player_is_victim = True 
            endif 
            num_victims += 1 
        else 
            Trace("SetVictims", "victims["+i+"] is None")
        endif
        i += 1 
    endwhile 

    if num_victims == 0 
        sexual_assault = False
    else 
        victims = EnsureActorsLargeEnough(victims, num_victims) 
        i = 0 
        int j = 0 
        while i < count 
            if _victims[i] != None 
                victims[j] = _victims[i]
                j += 1  
            endif
            i += 1 
        endwhile 
        sexual_assault = True 
    endif 
    SetVictimsMask() 
EndFunction 

Function SetVictimsMask() 
    int i = 0 
    while i < num_actors 
        bool found = false 
        int j = 0
        while j < num_victims 
            if actors[i] == victims[j]
                found = true 
            endif 
            j += 1 
        endwhile 
        if found
            victim_mask[i] = 1 
        else 
            assailant_mask[i] = 1 
        endif 
        i += 1 
    endwhile 
EndFunction 


; -------------------------
; Tag Functions 
; -------------------------
function SetTag(String tag) 
    num_tags = 0
    AddTag(tag)
EndFunction 

function SetTagSupress(String tag) 
    num_tags_supress = 0 
    AddTagSupress(tag)
EndFunction 

function AddTag(String tag) 
    if tag == None || tag == "" 
        return 
    endif 
    tags = EnsureStringsLargeEnough(tags, num_tags + 1) 
    tags[num_tags] = tag
    num_tags += 1 
EndFunction 
function AddTagSupress(String tag) 
    if tag == None || tag == "" 
        return 
    endif 
    tags_supress = EnsureStringsLargeEnough(tags_supress, num_tags_supress + 1) 
    tags_supress[num_tags_supress] = tag
    num_tags_supress += 1 
EndFunction 

; --------------------------------------------
; --------------------------------------------
function SetTags(String[] _tags) 
    SetTags_Helper(True,_tags) 
endfunction

function SetTagsSupress(String[] _tags_supress) 
    SetTags_Helper(False,_tags_supress) 
endfunction

Function SetTags_Helper(bool is_tags, String[] _tags)
    int number = 0 
    int i = 0
    int _num_tags = _tags.length
    while i < _num_tags 
        if _tags[i] != None && _tags[i] != "" 
            number += 1 
        endif 
        i += 1 
    endwhile 

    String[] ts = tags 
    if !is_tags
        ts = tags_supress
    endif 
    if number > 0
        ts = EnsureStringsLargeEnough(ts, number) 
        i = 0
        int j = 0 
        int count = _tags.length
        while i < count
            if _tags[i] != None && _tags[i] != "" 
                ts[j] = _tags[i]
                j += 1 
            endif 
            i += 1 
        endwhile 
    endif 

    if is_tags
        num_tags = number
        tags = ts
    else
        num_tags_supress = number
        tags_supress = ts
    endif 
EndFunction 

; --------------------------------------
; Ensure Functions 
; --------------------------------------

String[] Function EnsureStringsLargeEnough(String[] strings, int num_strings) global 
    if num_strings <= strings.length
        return strings 
    endif 

    String[] _strings = Utility.CreateStringArray(num_strings + 10) 
    int i = 0 
    int count = strings.length 
    while i < count 
        _strings[i] = strings[i]
        i += 1 
    endwhile 

    return _strings 
EndFunction 

Actor[] Function EnsureActorsLargeEnough(Actor[] actors_current, int total) global 
    if total <= actors_current.length
        return actors_current 
    endif 

    Actor[] _actors = PapyrusUtil.ActorArray(total + 10) 
    int i = 0 
    int count = actors_current.length 
    while i < count 
        _actors[i] = actors_current[i]
        i += 1 
    endwhile 

    return _actors 
EndFunction 

; ------------------------------------------------------
; Set Activity 
; ------------------------------------------------------

Function SetActivityByString(String activity="sex") 
    if !activity_stages 
        activity_stages = new String[3]
    endif 
    if activity == "affection"
        activity_stages[ACTIVITY_STAGE_START] = "showing affection"
        activity_stages[ACTIVITY_STAGE_ONGOING] = "showing affection"
        activity_stages[ACTIVITY_STAGE_END] = "showing affection"
    elseif activity == "rape" || activity == "sexual assault"
        activity_stages[ACTIVITY_STAGE_START] = "raping"
        activity_stages[ACTIVITY_STAGE_ONGOING] = "raping"
        activity_stages[ACTIVITY_STAGE_END] = "raping"
    else
        activity_stages[ACTIVITY_STAGE_START] = "having sexual activities"
        activity_stages[ACTIVITY_STAGE_ONGOING] = "having sexual activities"
        activity_stages[ACTIVITY_STAGE_END] = "having sexual activities"
    endif 
EndFunction

String Function GetActivity(int activity_stage)
    if activity_stage == ACTIVITY_STAGE_START 
        return "start "+activity_stages[activity_stage]
    elseif activity_stage == ACTIVITY_STAGE_END 
        return "finished "+activity_stages[activity_stage]
    endif 
    return "are "+activity_stages[ACTIVITY_STAGE_ONGOING]
EndFunction

; ------------------------------------------------------
; Set Style 
; ------------------------------------------------------
Function SetStyle(String _style) 
    if _style == "gentle" || _style == "gently"
        style = STYLE_GENTLY   
    elseif _style == "forceful" || _style == "forcefully"
        style = STYLE_FORCEFULLY
    else 
        style = STYLE_NORMALLY
    endif
EndFunction 
String Function GetStyle() 
    return style
EndFunction

Function SetEventHook(String _event_hook) 
    event_hook = _event_hook 
EndFunction

Function SetSpeaker(Actor _speaker) 
    Speaker = _Speaker 
EndFunction
Function SetTarget(Actor _Target) 
    Target = _Target 
EndFunction
; --------------------------------------------
; Release 
; --------------------------------------------
Function Release()
    UnlockAllActorLock() 

    int i = 0
    while i < num_actors
        if actors[i].IsInFaction(SkyrimNet_SexLab_Faction_Victim)
            actors[i].RemoveFromFaction(SkyrimNet_SexLab_Faction_Victim)
        endif 
        i += 1
    endwhile
    num_actors = 0 

    if thread != None
        manager.SetThread_scene(thread.tid, None)
    endif 

    num_tags = 0
    num_tags_supress = 0 
    thread = None 
    style = STYLE_NORMALLY
    event_hook = None 
    tracking = False
    status = STATUS_INACTIVE 
EndFunction

; --------------------------------------------
; Get a Status message for the scene (start, are, finished) 
; --------------------------------------------
String Function GetActivityStageMessage(int activity_stage = -1) 
    String activity = GetActivity(activity_stage) 
    if sexual_assault
        return assailant_names+" "+activity+" "+victim_names+". "
    endif 
    return actor_names+" "+activity+". "
EndFunction 

; -------------------------------------------------------------------------------------
; Actor LOck
; -------------------------------------------------------------------------------------

bool Function LockAllActorLock() 
    if !actors
        return False
    endif 
    int i = 0 
    while i < num_actors && LockActorLock(actors[i]) 
        i += 1 
    endwhile 

    if i < num_actors 
        int j = 0
        while j < i
            UnlockActorLock(actors[j]) 
            j += 1 
        endwhile 
        return False 
    endif 
    return True 
EndFunction 

Function UnLockAllActorLock() 
    if !actors 
        return 
    endif 
    int i = 0
    while i < num_actors
        UnlockActorLock(actors[i]) 
        i += 1 
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

Function UnlockActorLock(Actor akActor) 
    StorageUtil.UnsetIntValue(akActor, storage_actor_lock_key) 
    Trace("ReleaseActorLock",akActor.GetDisplayName())
EndFunction

; --------------------------------------------
; Start with Thread
; --------------------------------------------
sslThreadModel Function Start() 
    Trace("StartScene",GetString()) 
    UnlockAllActorLock() 

    sslThreadModel thread = sexlab.NewThread()
    if thread == None
        Trace("Start","Failed to create thread")
        Release()
        return None 
    endif
    manager.SetThread_scene(thread.tid, self)

    ; -----------------------------------------
    ; Add Actors and Victims 
    ; -----------------------------------------
    int i = 0 
    bool failed = False 
    while i < num_actors && !failed 
        if thread.AddActor(actors[i]) < 0 
            failed = True 
        else
            if victim_mask[i] == 1 
                actors[i].AddToFaction(SkyrimNet_SexLab_Faction_Victim)
                thread.SetVictim(actors[i])
            else 
                if actors[i].IsInFaction(SkyrimNet_SexLab_Faction_Victim)
                    actors[i].RemoveFromFaction(SkyrimNet_SexLab_Faction_Victim)
                endif 
            endif 
        endif 
        i += 1 
    endwhile 

    if failed 
        Release() 
        return 
    endif 

    ; ------------------------------------------
    ; Add Tags
    ; ------------------------------------------

    i = 0
    while i < num_tags
        String tag = tags[i]
        if tag == "mouth" || tag == "tongue"
            tags[i] = "oral"
        elseif tag == "pussy"
            tags[i] = "vaginal"
        elseif tag == "ass"
            tags[i] = "anal"
        endif 
        i += 1 
    endwhile 

    if num_actors == 1
        int gender = sexlab.GetGender(actors[0])
        bool has_penis = (gender != 1 && gender != 3)
        if has_penis 
            addTag("M")
        else 
            addTag("F")
        endif 
    endif 

    SetNames() 

    if !SelectAnimations() 
        Release() 
        return None
    endif 
    
    if event_hook != None && event_hook != "" 
        thread.SetHook(event_hook)
    endif 

    ; -----------------------------------
    ; Registers who started the activites 
    ; -----------------------------------
    if num_actors > 1 
        String msg = sender.GetDisplayName()+" initiates, "+ GetActivityStageMessage(ACTIVITY_STAGE_START)
        RegisterEvent("Start_Activities",msg, sender, receiver) 
    endif 

    String tags_string = JoinStrings(tags, num_tags)
    String tags_supress_string = JoinStrings(tags_supress, num_tags_supress)
    Trace("Start",
         " actors: "+'"'+actor_names+'"'\
        +" victims: "+'"'+victim_names+'"'\
        +" assailants: "+'"'+assailant_names+'"'\
        +" tag:"+tags_string\
        +" tag:"+tags_supress_string\
        +" style:"+style\
        +" event_hook:"+event_hook)

    thread.StartThread() 
    return thread 
EndFunction


; --------------------------------------------
; Animation Event Handlers 
; --------------------------------------------
Function AnimationStart()
    String msg = GetActivityStageMessage(ACTIVITY_STAGE_START)
    RegisterEvent("sexlab update", msg, sender, receiver) 
    manager.SaveThreadsJson() 
EndFunction

Function StageStart() 
    if SexLab == None || thread == None 
        Trace("StageStart","SexLab or thread is None for scene with actors "+actor_names)
        return 
    endif
    sslActorLibrary actorLib = (SexLab as Quest) as sslActorLibrary

    ; Send a DN if its a start and includes a player
    ; if not player send DN if allowed by cool off 
    String desc = stages.GetStageDescription(thread)
    if status != STATUS_ACTIVE
        status = STATUS_ACTIVE 
        if desc == "" 
            ContinueActivity(sender, receiver)
        else 
            DirectNarration(desc, sender, receiver) 
        endif 
    elseif thread.stage != thread.animation.StageCount()
        bool use_continue = True 
        if desc != "" && thread.stage > 1
            String desc_last = stages.GetStageDescription(thread, thread.stage - 1)
            if desc != desc_last
                desc = actors[0].GetDisplayName()+"'s scene changes to "+desc
                use_continue = False 
            endif 
        endif 
        if use_continue 
            ContinueActivity(sender, receiver, True)
        else
            DirectNarration_optional("ChangePosition", sender, receiver) 
        endif 
    endif 

    ; If this thread is being tracked print the thread's status 
    if tracking
        bool[] desc_orgasm = stages.GetHasDescriptionOrgasmExpected(thread)
        String msg = "" 
        if desc_orgasm[0]
            msg = "has description"
        endif
        if desc_orgasm[1]
            if msg != ""
                msg += " and "
            endif 
            msg += "orgasm expected"        
        endif
        Debug.Notification("stage "+thread.stage+" of "+ thread.animation.StageCount()+" "+msg)
    endif  
    manager.SaveThreadsJson() 
EndFunction

Function AnimationEnd(Actor speaker=None, String style="silently") 
    String msg = GetActivityStageMessage(ACTIVITY_STAGE_END)
    status = STATUS_INACTIVE
    manager.SaveThreadsJson()
    if SexLab == None || thread == None 
        Trace("StageStart","SexLab or thread is None for scene with actors "+actor_names)
        RegisterEvent("sexlab update", msg, sender, receiver) 
        return 
    endif 
    Trace("AnimationEnd","scene id:"+sid+" status:"+status+" thread id:"+thread.tid+" status:"+thread.GetState())
    ; Handle Separate Orgasms
    sslSystemConfig config = (SexLab as Quest) as sslSystemConfig

    String narration = ""
    if style != "silently" && speaker != None
        narration = speaker.GetDisplayName()+" "+style+" stops, "+GetActivityStageMessage(ACTIVITY_STAGE_ONGOING)+". "
    endif
    bool has_tentacles = False 

    if speaker != None && num_actors == 1
        narration = speaker.GetDisplayName()+" stops, "+msg
    endif 
    if  thread.Animation.HasTag("tentacles")
        has_tentacles = True 
        narration = "The tentacles orgasm flooding cum both inside and outside. "
    endif

    narration += GetActivityStageMessage(ACTIVITY_STAGE_END)+". "

    bool orgasm_denied = false
    Actor target = None
    if config.SeparateOrgasms
        String after = "" 
        if num_actors >= 2 && actors[0] != actors[1]
            target = actors[1]
        endif 
        int[] orgasm_expected = stages.GetOrgasmExpected(thread)
        int j = num_actors - 1 
        while 0 <= j 
            String name = actors[j].GetDisplayName()
            if total_orgasms[j] < 1
                if orgasm_expected.length > j && orgasm_expected[j] == 1
                    after += name+" failed to orgasm. "
                    target = actors[j]
                    orgasm_denied = true
                endif
            elseif total_orgasms[j] < 2
                after += name+"'s body glows in post orgasm. "
            else 
                after += name+"'s body is recovering from "+total_orgasms[j]+" orgasms. "
            endif 
            j -= 1 
        endwhile ;
        if target != None
            narration += " "+after
        endif 
    endif 

    if target == None && num_actors >= 2 && actors[0] != actors[1]
        target = actors[1]
    endif 

    if speaker != None || has_tentacles
        DirectNarration(narration, sender, receiver)
    elseif orgasm_denied
        DirectNarration_Optional(narration, sender, receiver)
    else
        RegisterEvent("sex_end", narration, sender, receiver)
    endif 

    if ThreadSlots == None
        Trace("[SkyrimNet_SexLab] Get_Threads: ThreadSlots is None", true)
        return
    endif
    sslThreadController[] threads = ThreadSlots.Threads

    int i = threads.length - 1 
    bool found = false
    while 0 <= i && !found
        String s = (threads[i] as sslThreadModel).GetState()
        if s == "animating" || s == "prepare"
            found = true
        endif 
        i -= 1
    endwhile
    if found
        main.active_sex = true
    else 
        main.active_sex = false
    endif

    style = STYLE_NORMALLY
    Release() 
EndFunction 

; --------------------------------------------
; Orgasm Handlers
; --------------------------------------------
Function OrgasmCombined()
    int[] orgasm_expected = stages.GetOrgasmExpected(thread)
    bool someone_ejaculated = False 
    int i = 0
    String narration = "" 
    Trace("Orgasm_Combined","ThreadID:"+thread.tid+" has_player:"+has_player+" orgasm_expected:"+orgasm_expected)
    while i < num_actors
        String name = actors[i].GetDisplayName()
        int gender = actors[i].GetLeveledActorBase().GetSex() ; actorLib.GetGender(actors[i])
        int gender_sexlab = sexlab.GetGender(actors[i]) 
        bool has_penis = gender != 1 || (gender_sexlab != 1 && gender_sexlab != 3)
        if main.handler_dom.IsDomSlave(actors[i])
            if orgasm_expected[i] == 1
                if total_orgasms[i] > 0
                    if has_penis
                        someone_ejaculated = True 
                    endif 
                else 
                    narration += main.handler_dom.HandleOrgasmDenied(actors[i])
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
        i += 1
    endwhile

    ; Generate cum message 
    i = 0
    while i < num_actors 
        if someone_ejaculated
            narration += AddCum(i, actors[i], actors[i].GetDisplayName())
        endif 
        Trace("Orgasm_Combined",i+" "+actors[i].GetDisplayName()+"| adding cum | narration: "+narration)
        i += 1 
    endwhile 

    SkyrimNetApi.PurgeDialogue(True)
    DirectNarration(narration, sender, receiver)
EndFunction

; Used for SLSO.esp orgasm handling
Event OrgasmIndividual(Actor akActor, int full_enjoyment, int num_orgasms)
    String msg = ""
    if num_orgasms == 1
        msg += akActor.GetDisplayName()+" orgasmed."
    else
        msg += akActor.GetDisplayName()+" orgasmed again."
    endif 

    ; Setup number of orgasms
    int i = 0
    while i < num_actors && actors[i] != akActor
        i += 1 
    endwhile 

    if i < num_actors 
        total_orgasms[i] = num_orgasms
    endif 
    OrgasmHelper(akActor, msg)
EndEvent

Function OrgasmCustom(Actor akActor, String msg)
    int number_orgasms = 0 
    int i = 0
    while i < num_actors && actors[i] != akActor
        i += 1 
    endwhile 


    if i < num_actors
        total_orgasms[i] += 1
    endif 
    OrgasmHelper(akActor, msg)
EndFunction

Function OrgasmHelper(Actor akActor, String msg)
    Trace("OrgasmHelper","akActor:"+akActor.GetDisplayName()+" msg:"+msg)
    Actor cum_catcher = None
    String cum_catcher_name = "(None)"

    int gender = sexlab.GetGender(akActor) 
    bool male = gender == 0 || gender == 2
    if male 
        ; Generate the orgasm message
        int last = num_actors - 1 
        int i = 0
        while i <= last
            if actors[i] != akActor && cum_catcher == None
                cum_catcher = actors[i]
                cum_catcher_name = cum_catcher.GetDisplayName()
                msg += AddCum(i, cum_catcher, cum_catcher_name)
            endif 
            i += 1 
        endwhile 
    endif 

    Trace("OrgasmHelper"," male:"+male+" cum_catcher:"+cum_catcher_name+" msg:"+msg)
    SkyrimNetApi.PurgeDialogue(True)
    DirectNarration(msg, akActor, cum_catcher)
EndFunction

;----------------------------------------------------
; Add Cum
;----------------------------------------------------
String Function AddCum(int position, Actor akActor, String name)
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

; --------------------------------------------
; --------------------------------------------
String Function GetDescription()
    if thread == None 
        return ""
    endif 
    return GetActivityStageMessage()+" "+stages.GetStageDescription(thread)
EndFunction

String Function GetJson(Actor Speaker)

    if speaker == None 
        Trace("GetJson","Speaker is None")
        return "{}"
    endif 

    if SexLab == None 
        Trace("GetJson","SexLab is None")
        return "{}"
    endif 

    sslActorLibrary actorLib = (SexLab as Quest) as sslActorLibrary 

    String description = GetDescription()

    String json = "{"+'"'+"description"+'"'+":"+'"'+description+'"'
    String enjoyments = GetEnjoyments()
    json += ", "+'"'+"enjoyments"+'"'+":"+enjoyments
    
    bool los = False 
    int[] orgasm_expected = stages.GetOrgasmExpected(thread)
    String orgasm_expected_json = JoinActorsToJsonMasked(actors, orgasm_expected, num_actors)
    int i = 0
    while i < num_actors 
        if actors[i] == speaker 
            los = True 
        endif 
        if thread.IsUsingStrapon(actors[i])
            strapon_mask[i] = 1
        else
            strapon_mask[i] = 0
        endif 
        i += 1 
    endwhile 
    strapon_names = JoinActorsMasked(actors, strapon_mask, num_actors)

    Float distance = 0
    if !los
        distance = speaker.GetDistance(actors[0]) ;
        los = speaker.HasLOS(actors[0]) 
    endif 

    json += ',"actors":'+actor_names_json
    json += ',"victims":'+victim_names_json
    json += ',"orgasm_expected":'+orgasm_expected_json
    json += ',"actor_names":"'+actor_names+'"'
    json += ',"hermaphrodiate_names":"'+hermaphrodiate_names+'"'
    json += ',"strapon_names":"'+strapon_names+'"'
    json += ',"speaker_distance":'+distance
    json += ',"speaker_los":'+los
    json += ',"location":"'+GetLocation()+'"'
    json += ',"style":"'+style+'"'
    json += "}"
    return json
EndFunction

String Function GetLocation()

    int bed = thread.BedTypeId

    String loc = "the floor"
    if  bed == 1
        loc = "a bedroll "
    elseif bed == 2
        loc = "a single bed "
    elseif bed == 3
        loc = "a double bed "
    endif 

    String[] on_furniture = new String[21]
    on_furniture[0] = "Table"
    on_furniture[1] = "LowTable"
    on_furniture[2] = "JavTable"
    on_furniture[3] = "Pole"
    on_furniture[4] = "wall"
    on_furniture[5] = "horse"
    on_furniture[6] = "Pillory"
    on_furniture[7] = "PilloryLow"
    on_furniture[8] = "Cage"
    on_furniture[9] = "Haybale"
    on_furniture[10] = "Xcross"
    on_furniture[11] = "WoodenPony"
    on_furniture[12] = "EnchantingWB"
    on_furniture[13] = "AlchemyWB"
    on_furniture[14] = "FuckMachine"
    on_furniture[15] = "chair"
    on_furniture[16] = "wheel"
    on_furniture[17] = "DwemerChair"
    on_furniture[18] = "NecroChair"
    on_furniture[19] = "Throne"
    on_furniture[20] = "Stockade"
    ; Add more if needed

    sslBaseAnimation anim = thread.Animation
    int i = 0
    bool found = false
    while i < on_furniture.Length && !found
        if anim.HasTag(on_furniture[i])
            loc = on_furniture[i]
            found = true
        endif
        i += 1
    endwhile

    if loc == "" 
        if anim.HasTag("Cage")
            loc = " in a cage"
        elseif anim.HasTag("Gallows")
            loc = " in a gallows"
        elseif anim.HasTag("coffin")
            loc = " in a coffin"
        elseif anim.HasTag("floating")
            loc = " floating in air"
        elseif anim.HasTag("tentacles")
            loc = " with tentacles"
        elseif anim.HasTag("gloryhole") || anim.HasTag("gloryholem")
            loc = " through a gloryhole"
        endif
    endif 

    return loc+" "
EndFunction 

String Function GetEnjoyments()
    String str = ""
    int i = 0
    while i < num_actors 
        if str != "" 
            str += ", "
        endif 
        int enjoyment = 0
        sslActorAlias actorAlias = thread.ActorAlias(actors[i]) 
        ;if MiscUtil.FileExists("Data/SLSO.esp")
            ;enjoyment = actorAlias.Getfull_enjoyment() 
        ;else 
            enjoyment = actorAlias.GetEnjoyment() 
        ;endif 
        str += '"'+actors[i].GetDisplayName()+'"'+": "+enjoyment
        i += 1  
    endwhile 
    return "{"+str+"}"
EndFunction 

bool Function SexLab_Thread_LOS(Actor akActor)
    int i = 0
    while i < num_actors 
        if akActor == actors[i] || akActor.HasLOS(actors[i])
            return true
        endif 
        i += 1
    endwhile 
    return false
endFunction 

String Function GetTagsString(sslBaseAnimation anim) global
    String tags_str = ""
    String[] _tags = anim.GetRawTags()
    int i = 0 
    while i < _tags.Length
        if _tags[i] != "" 
            if tags_str != ""
                tags_str += ", "
            endif 
            tags_str += '"'+_tags[i]+'"'
        endif
        i += 1
    endwhile
    return tags_str 
EndFunction 

;---------------------------------------------------------------------------------------------------------------------
;---------------------------------------------------------------------------------------------------------------------
int Function GetNumberOfOrgasms(Actor akActor)
    int i = 0
    while i < num_actors && actors[i] != akActor
        i += 1 
    endwhile 
    if i < num_actors
        return total_orgasms[i] 
    endif 
    return 0
EndFunction

;---------------------------------------------------------------------------------------------------------------------
;---------------------------------------------------------------------------------------------------------------------

; Allows the user to choose to accept the sex act chosen by the LLM 
; The value will between 
; 1 Yes with the editor 
; 2 Yes, but no tag editor 
; 3 No (silent), refused, but don't tell the LLM 
; 4 NO, tell the LLM 
int function YesNoDialog()
    Actor player = Game.GetPlayer() 
    String player_name = player.GetDisplayName()

    int yes = 0 
    int no_silent = 1
    int no = 2 

    String[] buttons = new String[4]
    buttons[BUTTON_YES] = "Yes"
    buttons[BUTTON_YES_RANDOM] = "Yes (Random)"
    buttons[BUTTON_NO_SILENT] = "No (Silent)"
    buttons[BUTTON_NO] = "No"

    String question = ""
    String rejection = ""

    String activity = activity_stages[ACTIVITY_STAGE_ONGOING]
    if !sexual_assault
        int[] player_mask = Utility.CreateIntArray(num_actors, 1)
        int i = 0
        while i < num_actors
            if actors[i] == player
                player_mask[i] = 0
            endif 
            i += 1
        endwhile
        String names = JoinActorsMasked(actors, player_mask, num_actors)
        question = "Would you like to "+activity+" with "+names+"?"
        rejection = player_name+" refuses to "+activity+" with "+names+"."
    else
        if player_is_victim
            question = "Will you allow, "+assailant_names+" start "+activity+" you?"
            rejection = player_name+" prevents, "+assailant_names+" from "+activity+" them?"
        else 
            question = "Would you like to "+activity+" "+victim_names+"?"
            rejection = player_name+" refuses to "+activity+" "+victim_names+"."
        endif 
    endif 
    
    int button = SkyMessage.ShowArray(question, buttons, getIndex = true) as int  
    Trace("YesNoDialog","question: "+question+" button:"+button)
    if button == BUTTON_NO || button == BUTTON_NO_SILENT
        if button == BUTTON_NO 
            DirectNarration(rejection, sender, receiver)
        endif 
    endif 
    return button 
EndFunction

; Selects the style of sex 
; 0 forcefully 
; 1 normally 
; 2 gently 
int Function SetStyleDialog()
    String[] buttons = new String[3] 
    String activity = activity_stages[ACTIVITY_STAGE_ONGOING]
    if sexual_assault
        buttons[0] = "Violently "+activity
        buttons[1] = activity
        buttons[2] = "Gently "+activity
    else
        buttons[0] = "Forcefully "+activity
        buttons[1] = activity
        buttons[2] = "Gently "+activity
    endif 
    int button = SkyMessage.ShowArray("Change style to:", buttons, getIndex = true) as int 
    if button == 0 
        style = STYLE_FORCEFULLY
    elseif button == 2
        style = STYLE_GENTLY
    else 
        style = STYLE_NORMALLY
    endif 
EndFunction

Bool Function SelectAnimations()
    Trace("SelectAnimations", sid+" "+actor_names+" victims: "+victim_names)
    sslBaseAnimation[] animations = new sslBaseAnimation[1] 
    animations[0] = None 
    int button = BUTTON_YES
    if has_player
        button = YesNoDialog()
        if button == BUTTON_NO || button == BUTTON_NO_SILENT
            return False 
        endif 
    endif  

    if button != BUTTON_YES_RANDOM
        if (main.sex_edit_tags_player && has_player) || (main.sex_edit_tags_nonplayer && !has_player)
            Trace("GetAnims", "Opening anim edit dialog")
            animations = SelectAnimationsDialog()
        else 
            String tags_string = JoinStrings(tags, num_tags)
            String tags_supress_string = JoinStrings(tags_supress, num_tags_supress)
            animations = sexLab.GetAnimationsByTags(num_actors, tags_string, tags_supress_string, true)
        endif 
    else
        String tags_string = JoinStrings(tags, num_tags)
        String tags_supress_string = JoinStrings(tags_supress, num_tags_supress)
        animations =  sexLab.GetAnimationsByTags(num_actors, tags_string, tags_supress_string, true)
    endif 
    if animations[0] != None 
        thread.SetAnimations(animations) 
        return True 
    Endif 
    return False 
EndFunction 

; -----------------------------------
; Style 
; -----------------------------------

sslThreadController Function GetThread()
    return thread
EndFunction

bool Function GetHasPlayer() 
    return has_player
EndFunction

String Function GetString() 
    String tags_string = JoinStrings(tags,num_tags)
    String tags_supress_string = JoinStrings(tags_supress, num_tags_supress)
    return sid+" actors: ["+actor_names+"] victims:["+victim_names+"] assailants:["+assailant_names+"]"+\
        " tags:["+tags_string+"] supress:["+tags_supress_string+"] style:"+style+" event_hook:"+event_hook
EndFunction 

; This function returns the list of animations matching the requested animations
; If no animations were selected, it will return an array with a single None value `[None]`
; 
;   anims = AnmisDialog(sexlab. positions, tag) 
;   if anims.length > 0 && anims[0] != None 
;        thread.SetAnimations(anims)
;   endif 
;
sslBaseAnimation[] Function SelectAnimationsDialog() 
    Trace("GetAnimsDialog","sid: "+sid+" "+actor_names)

    ; Check if enabled by MCM 
    sslBaseAnimation[] empty = new sslBaseAnimation[1]
    empty[0] = None 

    if (has_player && !main.sex_edit_tags_player) || (!has_player && !main.sex_edit_tags_nonplayer)
        return empty 
    endif 

    if num_tags > 0 || num_tags_supress > 0
        String tags_string = JoinStrings(tags, num_tags)
        String tags_supress_string = JoinStrings(tags_supress, num_tags_supress)
        sslBaseAnimation[] anims =  SexLab.GetAnimationsByTags(num_actors, tags_string, tags_supress_string, true)
        if anims.length == 0
            Trace("AnimsDialog", "No animations found, dropping initial tag: "+tags_string+" tags_supress:"+tags_supress_string)
            num_tags = 0 
            num_tags_supress = 0
        endif 
    endif 

    ; the order of the groups 
    int group_tags = JMap.getObj(manager.group_info,"group_tags",0)
    if group_tags == 0 
        Trace("AnimsDialog", "group_tags not found in group_tags.json")
        return None
    endif 

    int groups = JMap.getObj(group_tags,"groups",0)
    if groups == 0
        groups = JMap.allKeys(group_tags)
        JValue.retain(groups)
    endif 

    int num_tags_max = tags.length 
    int group_count = JArray.count(groups)
    uilistMenu listMenu = uiextensions.GetMenu("UIlistMenu") AS uilistMenu

    String start_label = "<start "+GetActivityStageMessage(ACTIVITY_STAGE_START)+">"
    while True
        String order_str ="change order>"
        bool finished = false
        String tags_string = ""
        while num_tags < num_tags_max && !finished
            String style_button = style+">"
            listMenu.ResetMenu()

            ; build the current tags
            tags_string = JoinStrings(tags,num_tags)
            ; Use the current set of tags 
            String tags_label = "tags:"+tags_string
            listMenu.AddEntryItem(actor_names)
            if num_actors > 1 
                listMenu.AddEntryItem(order_str)
            endif 
            listMenu.AddEntryItem(style_button)
            listMenu.AddEntryItem(tags_label)
            listMenu.AddEntryItem(start_label)

            ; there is at least one tag that can be removed 
            if 0 < num_tags 
                listMenu.AddEntryItem("<remove")
            endif 

            ; Add groups
            int i =  0
            while i < group_count
                String group = JArray.getStr(groups,i)
                listMenu.AddEntryItem(group)
                i += 1
            endwhile

            ; just give up
            listMenu.AddEntryItem("<cancel>")

            listMenu.OpenMenu()
            String button =  listMenu.GetResultString()
            if JMap.hasKey(group_tags, button)
                button = GroupDialog(group_tags, button)
            endif 

            if button == start_label 
                finished = true
            elseif button == style_button
                SetStyleDialog()
                style_button = style+">"
            elseif button == order_str 
                ShiftActorsLeft() 
            elseif button == "<cancel>"
                JValue.release(groups)
                return empty
            elseif button == "<remove"
                num_tags -= 1
            elseif button != "-continue-" && button != actor_names && button != tags_label
                tags[num_tags] = button 
                num_tags += 1
            endif 
        endwhile 
        sslBaseAnimation[] anims =  SexLab.GetAnimationsByTags(num_actors, tags_string, "", true)
        if anims.length > 0
            JValue.release(groups)
            return anims 
        else
            Trace("AnimsDialog","No animations found for: "+tags_string, True )
            if num_tags > 0
               num_tags -= 1 
            endif 
        endif 
    endwhile 
    JValue.release(groups)
    return empty
EndFunction

Function AddGroupTags(uilistMenu listMenu, int group_tags, String group) global
    int tags = JMap.getObj(group_tags, group, 0)
    if tags != 0 
        int i = 0
        int count = JArray.count(tags)
        while i < count
            String tag = JArray.getStr(tags, i, "")
            if tag != ""
                listMenu.AddEntryItem(tag)
            endif
            i += 1
        endwhile 
    endif 
EndFunction

String Function GroupDialog(int group_tags, String group)  global
    uilistMenu listMenu = uiextensions.GetMenu("UIlistMenu") AS uilistMenu
    listMenu.ResetMenu()
    listMenu.AddEntryItem("<back")
    AddGroupTags(listMenu, group_tags, group) 
    listMenu.OpenMenu()
    String button =  listMenu.GetResultString()
    if button == "<back"
        button = "-continue-"
    endif 
    return button
EndFunction 