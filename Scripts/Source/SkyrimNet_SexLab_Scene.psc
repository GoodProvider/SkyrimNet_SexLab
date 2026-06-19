Scriptname SkyrimNet_SexLab_Scene extends SkyrimNet_SexLab_Scene_Interface

Import SkyrimNet_SexLab_Utilities
import SkyrimNet_SexLab_Scene_Interface

SexLabFramework Property sexlab Auto
sslThreadSlots Property threadSlots Auto
sslActorLibrary Property actorLib Auto

Faction Property SkyrimNet_SexLab_Faction_Victim Auto

int[] victim_mask
int[] assailant_mask
int[] hermaphrodiate_mask
int[] strapon_mask


String creature_descriptions = "" 

; -------------------------------------------
; Who send the messages to SkyrimNet 
; -------------------------------------------
Actor sender = None 
Actor receiver = None 

int[] total_orgasms = None 

; --------------------------------------------
; Track Scene
; --------------------------------------------
bool tracking = False

; --------------------------------------------
; Thread
; --------------------------------------------
sslThreadController thread

; --------------------------------------------
; Set in the generic thread 
; --------------------------------------------
bool is_generic

Function Trace(String func, String msg="", Bool notification=False)
    msg = "[SkyrimNet_SexLab_Scene."+func+"] sid:"+sid+" "+msg
    Debug.Trace(msg) 
    if notification
        Debug.Notification(msg)
    endif 
EndFunction

String Function GetString() 
    return " actors: "+'"'+parent.actor_names+'"'\
          +" victims: "+'"'+parent.victim_names+'"'\
          +" assailants: "+'"'+parent.assailant_names+'"'\
          +" style:"+parent.style
EndFunction 

Function Initialize(int _sid, SkyrimNet_SexLab_Scene_Manager _manager) 
    parent.Initialize(_sid,_manager) 
    sexlab = manager.sexlab
    threadSlots = manager.threadSlots
    SkyrimNet_SexLab_Faction_Victim = manager.SkyrimNet_SexLab_Faction_Victim
    is_generic = false
    if !total_orgasms 
        total_orgasms = new Int[2] 
    endif 
EndFunction 

Function Setup(sslThreadController _thread, Actor speaker=None, Actor target=None) 
    thread = _thread

    num_victims = 0 
    Actor victim = thread.GetVictm() 
    if victim != None 
        num_victims = 1
    else 
        num_victims = 0
    endif 

    if thread.positions.length == 1 
        sender = thread.positions[0]
        receiver = None 
    elseif victim != None
        if victim == thread.positions[0] 
            sender = thread.positions[1]
            receiver = thread.positions[0]
        else 
            sender = thread.positions[0]
            receiver = thread.positions[1]
        endif 
    elseif speaker == None 
        sender = thread.positions[1]
        receiver = thread.positions[0]
    else
        sender = speaker
        if target != None  || target == sender
            if target == thread.positions[0]
                receiver = thread.positions[1]
            else 
                receiver = thread.positions[0]
            endif 
        else
            receiver = target 
        endif 
    endif 
            
    if !is_generic
        parent.status = parent.STATUS_SETUP
        manager.SetThread_Scene(thread.tid,self) 
    else 
        parent.status = parent.STATUS_ACTIVE 
    endif 
EndFunction 

Function Release()
    int i = 0
    Actor[] actors = thread.positions
    int num_actors = actors.length
    while i < num_actors
        if actors[i].IsInFaction(SkyrimNet_SexLab_Faction_Victim)
            actors[i].RemoveFromFaction(SkyrimNet_SexLab_Faction_Victim)
        endif 
        i += 1
    endwhile
    num_actors = 0 

    if thread != None && !is_generic
        manager.SetThread_scene(thread.tid, None)
    endif 
    parent.Release() 
    parent.status = parent.STATUS_INACTIVE 
EndFunction

Function CheckActorSize(int size) 
    victim_mask = EnsureIntsLargeEnough(victim_mask, size) 
    assailant_mask = EnsureIntsLargeEnough(assailant_mask, size) 
    hermaphrodiate_mask = EnsureIntsLargeEnough(hermaphrodiate_mask, size) 
    strapon_mask = EnsureIntsLargeEnough(strapon_mask, size) 
    total_orgasms = EnsureIntsLargeEnough(total_orgasms, size) 
EndFunction

Function SetMasks()
    If thread == None 
        Trace("SetMasks","thread is None")
        return 
    endif 
    int num_actors = thread.positions.length
    CheckActorSize(num_actors) 

    int i = 0 
    while i < num_actors 
        ; Victim and Assailant 
        if thread.IsVictim(thread.positions[i]) 
            victim_mask[i] = 1 
            assailant_mask[i] = 0 
        else 
            victim_mask[i] = 0 
            assailant_mask[i] = 1
        endif 

        ; Futa / Hermaphrodiate
        if actorLib.GetTrans(thread.positions[i]) == 0 
            hermaphrodiate_mask[i] = 1 
        else 
            hermaphrodiate_mask[i] = 0 
        endif 
        if thread != None && thread.IsUsingStrapon(thread.positions[i])
            strapon_mask[i] = 1
        else
            strapon_mask[i] = 0
        endif 
        i += 1 
    endwhile 
EndFunction 

Function SetNames() 
    SetMasks()
    parent.actor_names = JoinActors(thread.positions)
    parent.actor_names_json = JoinActorsToJson(thread.positions)

    parent.hermaphrodiate_names = JoinActorsMasked(thread.positions, hermaphrodiate_mask)
    parent.strapon_names = JoinActorsMasked(thread.positions, strapon_mask)

    parent.victim_names = JoinActorsMasked(thread.positions, victim_mask)
    parent.victim_names_json = JoinActorsToJsonMasked(thread.positions, victim_mask)

    parent.assailant_names = JoinActorsMasked(thread.positions, assailant_mask)

;    Trace("SexNames",sid+" actors:"+JoinActors(actors,num_actors)+" num_actors:"+num_actors+\
;        " actor_names:"+actor_names+" actor_names_json:"+actor_names_json+\
;        " hermaphrodiate_names:"+hermaphrodiate_names+" strapon_names:"+strapon_names+\
;        " victim_names:"+victim_names+" victim_names_json:"+victim_names_json+\
;        " assailant_names:"+assailant_names)
EndFunction 

Function SetCreatureDescriptions() 
    String desc = "" 
    int i = 0
    Actor[] actors = thread.positions
    int num_actors = actors.length
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

; --------------------------------------------
; Get Functions 
; --------------------------------------------

int Function GetNumberOfOrgasms(Actor akActor)
    int i = 0
    int num_actors = thread.positions.length
    while i < num_actors && thread.positions[i] != akActor
        i += 1 
    endwhile 
    if i < num_actors
        return total_orgasms[i] 
    endif 
    return 0
EndFunction


sslThreadController Function GetThread()
    if thread == None 
        Trace("GetThread","Thread is None | "+GetString())
    endif 
    return thread
EndFunction

Function SetGeneric() 
    is_generic = True 
EndFunction 
bool Function IsGeneric() 
    return is_generic
EndFunction 

; --------------------------------------------
; Animation Event Handlers 
; --------------------------------------------
Function AnimationStart()
    SetNames() 
    String msg = GetActivityMessage(ACTIVITY_STAGE_START)
    RegisterEvent("sexlab update", msg, sender, receiver) 
    manager.SaveThreadsJson() 
EndFunction

Function StageStart() 
    SetNames() 
    Actor[] actors = thread.positions
    int num_actors = actors.length
    if SexLab == None 
        Trace("StageStart","sexlab is None | actors:"+JoinActors(actors,num_actors))
        return 
    endif
    if thread == None 
        Trace("StageStart","thread is None | actors:"+JoinActors(actors,num_actors))
        return 
    endif

    ; Send a DN if its a start and includes a player
    ; if not player send DN if allowed by cool off 
    String desc = stages.GetStageDescription(thread)
    if parent.status != parent.STATUS_ACTIVE
        parent.status = parent.STATUS_ACTIVE

        ; -----------------------------------
        ; Registers who started the activites 
        ; -----------------------------------
        if num_actors > 1 
            desc = sender.GetDisplayName()+" initiates, "+ GetActivityMessage(ACTIVITY_STAGE_START)+desc
        endif 

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
    SetNames() 
    int num_actors = thread.positions.length 

    String msg = GetActivityMessage(ACTIVITY_STAGE_END)
    manager.SaveThreadsJson()
    if SexLab == None || thread == None 
        Trace("StageStart","SexLab or thread is None for scene with actors "+parent.actor_names)
        RegisterEvent("sexlab update", msg, sender, receiver) 
        return 
    endif 
    Trace("AnimationEnd","thread id:"+thread.tid+" status:"+thread.GetState())
    ; Handle Separate Orgasms
    sslSystemConfig config = (SexLab as Quest) as sslSystemConfig

    String narration = ""
    if style != "silently" && speaker != None
        narration = speaker.GetDisplayName()+" "+style+" stops, "+GetActivityMessage(ACTIVITY_STAGE_ONGOING)+". "
    endif
    bool has_tentacles = False 

    if speaker != None && num_actors == 1
        narration = speaker.GetDisplayName()+" stops, "+msg
    endif 
    if  thread.Animation.HasTag("tentacles")
        has_tentacles = True 
        narration = "The tentacles orgasm flooding cum both inside and outside. "
    endif

    narration += GetActivityMessage(ACTIVITY_STAGE_END)+". "

    bool orgasm_denied = false
    Actor target = None
    if config.SeparateOrgasms
        String after = "" 
        if num_actors >= 2 && thread.positions[0] != thread.positions[1]
            target = thread.positions[1]
        endif 
        int[] orgasm_expected = stages.GetOrgasmExpected(thread)
        int j = num_actors - 1 
        while 0 <= j 
            String name = thread.positions[j].GetDisplayName()
            if total_orgasms[j] < 1
                if orgasm_expected.length > j && orgasm_expected[j] == 1
                    after += name+" failed to orgasm. "
                    target = thread.positions[j]
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

    if target == None && num_actors >= 2 && thread.positions[0] != thread.positions[1]
        target = thread.positions[1]
    endif 

    if speaker != None || has_tentacles
        DirectNarration(narration, sender, receiver)
    elseif orgasm_denied
        DirectNarration_Optional(narration, sender, receiver)
    else
        RegisterEvent("sex_end", narration, sender, receiver)
    endif 

    if ThreadSlots == None
        Trace("AnimationEnd","ThreadSlots is None", true)
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

    style = parent.STYLE_NORMALLY
    Release() 
EndFunction 

; --------------------------------------------
; Orgasm Handlers
; --------------------------------------------
Function OrgasmCombined()
    int[] orgasm_expected = stages.GetOrgasmExpected(thread)
    bool someone_ejaculated = False 
    String narration = "" 
    Trace("Orgasm_Combined","ThreadID:"+thread.tid+" has_player:"+parent.has_player+" orgasm_expected:"+orgasm_expected)
    int i = 0
    int num_actors = thread.positions.length 
    while i < num_actors
        String name = thread.positions[i].GetDisplayName()
        int gender = thread.positions[i].GetLeveledActorBase().GetSex() ; actorLib.GetGender(thread.positions[i])
        int gender_sexlab = sexlab.GetGender(thread.positions[i]) 
        bool has_penis = gender != 1 || (gender_sexlab != 1 && gender_sexlab != 3)
        if main.handler_dom.IsDomSlave(thread.positions[i])
            if orgasm_expected[i] == 1
                if total_orgasms[i] > 0
                    if has_penis
                        someone_ejaculated = True 
                    endif 
                else 
                    narration += main.handler_dom.HandleOrgasmDenied(thread.positions[i])
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
            narration += AddCum(i, thread.positions[i], thread.positions[i].GetDisplayName())
        endif 
        Trace("Orgasm_Combined",i+" "+thread.positions[i].GetDisplayName()+"| adding cum | narration: "+narration)
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
    int num_actors = thread.positions.length
    while i < num_actors && thread.positions[i] != akActor
        i += 1 
    endwhile 

    if i < thread.positions.length 
        total_orgasms[i] = num_orgasms
    endif 
    OrgasmHelper(akActor, msg)
EndEvent

Function OrgasmCustom(Actor akActor, String msg)
    int number_orgasms = 0 
    int i = 0
    int num_actors = thread.positions.length
    while i < num_actors && thread.positions[i] != akActor
        i += 1 
    endwhile 


    if i < thread.positions.length
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
        int num_actors = thread.positions.length
        int i = 0
        while i <= num_actors
            if thread.positions[i] != akActor && cum_catcher == None
                cum_catcher = thread.positions[i]
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
    return GetActivityMessage()+" "+stages.GetStageDescription(thread)
EndFunction

String Function GetJson(Actor Speaker)
    SetNames()
    int num_actors = thread.positions.length

    if speaker == None 
        Trace("GetJson","Speaker is None")
        return "{}"
    endif 

    if SexLab == None 
        Trace("GetJson","SexLab is None")
        return "{}"
    endif 

    String description = GetDescription()

    String json = "{"+'"'+"description"+'"'+":"+'"'+description+'"'
    String enjoyments = GetEnjoyments()
    json += ", "+'"'+"enjoyments"+'"'+":"+enjoyments
    
    bool los = False 
    int[] orgasm_expected = stages.GetOrgasmExpected(thread)
    String orgasm_expected_json = JoinActorsToJsonMasked(thread.positions, orgasm_expected, thread.positions.length)
    int i = 0
    while i < num_actors 
        if thread.positions[i] == speaker 
            los = True 
        endif 
        i += 1 
    endwhile 

    Float distance = 0
    if !los
        distance = speaker.GetDistance(thread.positions[0]) ;
        los = speaker.HasLOS(thread.positions[0]) 
    endif 

    json += ',"actors":'+parent.actor_names_json
    json += ',"victims":'+parent.victim_names_json
    json += ',"orgasm_expected":'+orgasm_expected_json
    json += ',"actor_names":"'+parent.actor_names+'"'
    json += ',"hermaphrodiate_names":"'+parent.hermaphrodiate_names+'"'
    json += ',"strapon_names":"'+parent.strapon_names+'"'
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
    int num_actors = thread.positions.length
    while i < num_actors 
        if str != "" 
            str += ", "
        endif 
        int enjoyment = 0
        sslActorAlias actorAlias = thread.ActorAlias(thread.positions[i]) 
        ;if MiscUtil.FileExists("Data/SLSO.esp")
            ;enjoyment = actorAlias.Getfull_enjoyment() 
        ;else 
            enjoyment = actorAlias.GetEnjoyment() 
        ;endif 
        str += '"'+thread.positions[i].GetDisplayName()+'"'+": "+enjoyment
        i += 1  
    endwhile 
    return "{"+str+"}"
EndFunction 

bool Function SexLab_Thread_LOS(Actor akActor)
    int i = 0
    int num_actors = thread.positions.length
    while i < num_actors 
        if akActor == thread.positions[i] || akActor.HasLOS(thread.positions[i])
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