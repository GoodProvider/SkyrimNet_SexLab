Scriptname SkyrimNet_SexLab_Scene extends Quest

SkyrimNet_SexLab_Main Property main Auto 
SexLabFramework Property sexlab Auto 
sslThreadSlots Property ThreadSlots Auto 

Import SkyrimNet_SexLab_Utilities

; --------------------------------------------
; Style
; --------------------------------------------
String Property STYLE_FORCEFULLY = "forcefully" Auto 
String Property STYLE_NORMALLY = "normally" Auto 
String Property STYLE_GENTLY = "gently" Auto 
String Property style  = STYLE_NORMALLY 

; --------------------------------------------
; Buttons 
; --------------------------------------------
int Property BUTTON_YES = 0 Auto        ; 0
int Property BUTTON_YES_RANDOM = 1 Auto ; 1
int Property BUTTON_NO_SILENT = 2 Auto  ; 2
int Property BUTTON_NO = 3 Auto         ; 3

; --------------------------------------------
; Actors 
; --------------------------------------------
Actor Property Speaker = None Auto 
Actor Property Target = None Auto 
Actor[] Property actors = None
Actor[] Property victims = None 
Actor[] Property aggressors = None

Actor sender = None 
Actor receiver = None 

String[] actors_names = None 
String[] victims_names = None 
String[] aggressors_names = None 
String actors_names_string = ""
String victims_names_string = ""
String aggressors_names_string = ""

; --------------------------------------------
; Thread
; --------------------------------------------
String status_message_temple = "" 

; --------------------------------------------
; SexLab
; --------------------------------------------
sslActorLibrary actorLib

sslBaseAnimation[] animations = None 

; -------------------------------------------
; number Orgasms
; -------------------------------------------
int[] number_orgasms
; -------------------------------------------
; type
; -------------------------------------------
String type
String TYPE_DEFAULT = "sexual activities"

; --------------------------------------------
; event_hook
; --------------------------------------------
String event_hook = ""

; --------------------------------------------
; Tags 
; --------------------------------------------
String[] tags = None 
String[] tags_supress = None 
String[] tag_filter_affection = ["oral","vaginal","anal","masturbation","handjob","boobjob","thighjob","fisting,dildo","fingering","footjob"]

; --------------------------------------------
; Has Player 
; --------------------------------------------
bool has_player = False 

Function Setup(Actor[] _actors)
    actors = PapyrusUtil.ActorArray(_actors.length) 
    actors_names = Utility.CreateStringArray(count)
    actors_names_string = SkyrimNetAPI.JoinStrings(actors_names)

    number_orgasm = PapyrusUtil.IntArray(_actors.length,0) 

    Actor player = Game.GetPlayer() 
    int i = _actors.length - 1 
    has_player = False 
    while (i >= 0) 
        actors[i] = _actors[i] 
        actors_names[i] = actors[i].GetDisplayName() 
        if player == actors[i] 
            has_player = True 
        endif 
        i = i - 1
    endwhile 

    victims = PapyrusUtil.ActorArray(0)
    victims_names = ""
    victims_names_string = ""

    aggressors = PapyrusUtil.ActorArray(0)
    aggressors_names = ""
    aggressors_names_string = ""

    tags = None 
    tags_supress = None 

    style = STYLE_NORMALLY
    type = TYPE_DEFAULT
    event_hook = ""

    status = STATUS_SETUP 
EndFunction 

Function SetUp_Victims(Actor[] _victims) 

; --------------------------------------------
; Tags 
; --------------------------------------------

Function SetTags(String[] _tags)
    int count = _tags.length
    tags = Utility.CreateStringArray(count)
    int i = _tags.length - 1  
    while 0 <= i 
        _tags[i] = tags[i] 
        i -= 1 
    endwhile 
EndFunction 

Function AddTag(String tag) 
    if tags == None 
        tags = Utility.CreateStringArray(1) 
        tags[0] = tag 
    else
        int count = tags.length
        String[] _tags = Utility.CreateStringArray(count+1)
        int i = tags.length - 1  
        while 0 <= i 
            if tags[i] == tag
                return 
            endif 
            _tags[i] = tags[i] 
            i -= 1 
        endwhile 
        _tags[count] = tag 
        tags = _tags 
    endif 
EndFunction 

; --------------------------------------------
; Start
; --------------------------------------------
Bool Function StartThread(sslControlThread _thread) 
    thread = _thread
    Trace("AddActorsToThread", actors_names_string)

    int i = actors.length - 1 
    while 0 <= i 
        if thread.addActor(actors) < 0
            return False 
        endif 
        i -= 1 
    endwhile 

    ; ------------------------------
    ; Set up Victims and Aggressors
    ; ------------------------------
    int count = actors.length
    int num_victims = 0 
    int num_aggressors = 0
    int i = actors.length - 1 
    while (i >= 0) 
;;        if tag == "kissing_only"
;            thread.SetNoStripping(actors[i])
;            thread.DisableOrgasm(actors[i], true) 

;        elseif main.handler_dom.IsDOMSlave(actors[i]) 
;            thread.DisableOrgasm(actors[i], true) 
;            Debug.Notification(actors[i].getDisplayName()+" no orgasm!")
;        endif 
        bool is_victim = False 
        int j = victims.length - 1 
        while 0 <= j && !is_victim 
            if victims[j] == actors[i]
                is_victim = True
            endif 
            j -= 1 
        endwhile 

        if is_victim
            thread.SetVictim(actors[i])
            actors[i].AddtoFaction(SkyrimNet_SexLab_Faction_Victim)
            num_victims = num_victims + 1
        else 
            if actors[i].isInFaction(SkyrimNet_SexLab_Faction_Victim) 
                actors[i].RemoveFromFaction(SkyrimNet_SexLab_Faction_Victim)
            endif 
            num_aggressors = num_aggressors + 1
        endif 
        i = i - 1
    endwhile 
    status_message_default = " {{sl.state}} sexual activities"
    status_message_template = status_message_default 

    if num_victims == 0 
        type = "sexual activities"
        victims = PapyrusUtil.ActorArray(0) 
        aggressors = PapyrusUtil.ActorArray(0) 
    else 
        type = "rape"
        victims = PapyrusUtil.ActorArray(num_victims) 
        aggressors = PapyrusUtil.ActorArray(num_aggressors) 
        i = actors.length - 1 
        int v_i = 0 
        int a_i = 0
        while (i >= 0) 
            if thread.IsVictim(actors[i])
                victims[v_i] = actors[i] 
                v_i = v_i + 1
            else 
                aggressors[a_i] = actors[i] 
                a_i = a_i + 1
            endif 
        endwhile 
        victims_names_string = SkyrimNetAPI.Joinpositions(victims)
        aggressors_names_string = SkyrimNet_SexLab_.Joinpositions(aggressors)
        status_message_template = aggressors_names_string+" {{sl.state}} raping "+victims_names_string+"."
    endif 

    if aggressors.length > 0 
        sender = aggressors[0]
        receiver = victim[0]
    else 
        if actors.length > 1
            sender = actors[1]
            receiver = actors[0]
        else 
            sender = actors[0]
            receiver = None 
        endif 
    endif 
EndFunction 

; --------------------------------------------
; Animation Event Handlers 
; --------------------------------------------
Function AnimationStart()
    String msg = GetStatusMessage("start")
    RegisterEvent(type+" start", msg, sender, receiver) 
    manager.saveThreadsJson() 
EndFunction

Function StageStart() 
    if SexLab == None
        return  
    endif
    sslActorLibrary actorLib = (SexLab as Quest) as sslActorLibrary

    ; Send a DN if its a start and includes a player
    ; if not player send DN if allowed by cool off 
    String desc = GetStageDescription(thread)
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
            String desc_last = GetStageDescription(thread, thread.stage - 1)
            if desc != desc_last
                desc = actors[0].GetDisplayName()+"'s scene changes to "+desc
                use_continue = False 
            endif 
        endif 
        if use_continue 
            ContinueActivity(sender, receiver, True)
        else
            DirectNarration_optional("ChangePosition", sender, receiver, True) 
        endif 
    endif 

    ; If this thread is being tracked print the thread's status 
    if stages.IsThreadTracking(ThreadID)
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
    manager.saveThreadsJson() 
EndFunction

Function AnimationEnd(Actor actorEnder=None) 
    Trace("AnimationEnd","scene id:"+scene.sid+" status:"+scene.status" thread id:"+thread.tid+" status:"+thread.GetState())
    ; Handle Separate Orgasms
    sslSystemConfig config = (SexLab as Quest) as sslSystemConfig
    int i = actors.length - 1
    while 0 <= i 
        if actors[i].IsInFaction(SkyrimNet_SexLab_Faction_Victim)
            actors[i].RemoveFromFaction(SkyrimNet_SexLab_Faction_Victim)
        endif 
        i -= 1
    endwhile

    String narration = ""
    bool has_tentacles = False 

    if actorEnder != None 
        if actors.length < 2
            narration = actorEnder.GetDisplayName()+" stops the "+type+". "
        endif 
    endif 
    if  thread.Animation.HasTag("tentacles")
        has_tentacles = True 
        narration = "The tentacles orgasm flooding cum both inside and outside. "
    endif

    narration += GetStatusMessage("stop")+". "

    bool orgasm_denied = false
    Actor target = None
    if config.SeparateOrgasms
        String after = "" 
        if actors.length >= 2 && actors[0] != actors[1]
            target = actors[1]
        endif 
        int[] orgasm_expected = stages.GetOrgasmExpected(thread)
        int j = actors.length - 1 
        while 0 <= j 
            if num_orgasms[j] < 1
                if orgasm_expected.length > j && orgasm_expected[j] == 1
                    after += names[j]+" failed to orgasm. "
                    target = actors[j]
                    orgasm_denied = true
                endif
            elseif num_orgasms[j] < 2
                after += names[j]+"'s body glows in post orgasm. "
            else 
                after += names[j]+"'s body is recovering from "+num_orgasms+" orgasms. "
            endif 
            j -= 1 
        endwhile ;
        if target != None
            narration += " "+after
        endif 
    endif 

    if target == None && actors.length >= 2 && actors[0] != actors[1]
        target = actors[1]
    endif 

    if actorEnder != None || has_tentacles
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

    i = threads.length - 1 
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

    style = STYE_NORMALLY
    String msg = GetStatusMessage("start")
    RegisterEvent(type+" stop", msg) 
EndFunction 

String Function GetStatusMessage(String status="are") 
    String json = '{"status":"'+status+'","style":"'+style+'"}'
    msg = SkyrimNetAPI.ParseString("{{sl.style}} "+status_message_template, "sl", json) 
    if msg == "" 
        status_message_template = status_message_default 
        msg = SkyrimNetAPI.ParseString("{{sl.style}} "+status_message_template, "sl", json) 
    endif 

    if victims.length > 0
        return aggressors_names+" "+msg+" "+victims_names+"."
    endif 

    return actors_names_string+" "+msg+"."
EndFunction 

; --------------------------------------------
; Description
; --------------------------------------------
String Function GetDescription() global

    ; gently are etc 
    String msg = GetStatusMessage()

    ; ----------------------------------------------------------------
    ; Return description if it already has one. 
    ; ----------------------------------------------------------------
    String desc = SkyrimNet_SexLab_Stages.GetStageDescription(thread)
    if desc == "" 
        ; ----------------------------------------------------------------
        ; Positions 
        ; ----------------------------------------------------------------
        sslBaseAnimation anim = thread.Animation

        if anim.HasTag("standing")
            msg += " While standing, "
        elseif anim.HasTag("kneeling")
            msg += " While kneeling, "
        elseif anim.HasTag("sitting")
            msg += " While sitting, "
        elseif anim.HasTag("cowgirl")
            msg += " While in the cowgirl position, "
        elseif anim.HasTag("69")
            msg += " While in the 69 position, "
        elseif anim.HasTag("missionary")
            msg += " While in the missionary position, "
        elseif anim.HasTag("doggy")
            msg += " While in the doggy position, "
        endif 

        ; ----------------------------------------------------------------
        ; Check if rape or orgy
        ; ----------------------------------------------------------------
        if positions.length == 1 
            msg += names[0]+" is "+style_ly_str+"masturbating"
            if anim.HasTag("dildo")
                msg += " with a dildo"
            endif 
        else 
            if num_victims == 0 && actors.length > 2
                msg = SkyrimNetAPI.JoinStrings(names, nouns_empty)+" having an orgy. "
            endif 
            
            ; ----------------------------------------------------------------
            ; Add action 
            ; ----------------------------------------------------------------

            if anim.HasTag("Anal") || anim.HasTag("assjob")
                msg += names[1]+" is "+style_ly_str+"fucking "+names[0]+"'s ass"
            elseif anim.HasTag("Boobjob")
                msg += names[1]+" is getting a "+style_full_str+"boobjob from "+names[0]  
            elseif anim.HasTag("Thighjob")
                msg += names[1]+" is getting a "+style_full_str+"thighjob from "+names[0]
            elseif anim.HasTag("Fisting")
                msg += names[1]+" is "+style_ly_str+"fisting "+names[0]
            elseif anim.HasTag("Oral") || anim.HasTag("blowjob") || anim.HasTag("cunnilingus")
                msg += names[1]+" is getting "+style_full_str+"oral sex from "+names[0]   
            elseif anim.HasTag("Fingering")
                msg += names[1]+" is "+style_ly_str+"fingering "+names[0]
            elseif anim.HasTag("Footjob")
                msg += names[1]+" is getting a "+style_full_str+"footjob from "+names[0]
            elseif anim.HasTag("Handjob")
                msg += names[1]+" is getting a "+style_full_str+"handjob from "+names[0]
            elseif anim.HasTag("Dildo")
                msg += names[1]+" is "+style_ly_str+"fucking "+names[0]+" with with a dildo"
            elseif anim.HasTag("Vaginal")
                msg += names[1]+" is "+style_ly_str+"fucking "+names[0]+"'s pussy"
            elseif anim.HasTag("Kissing")
                msg += names[1]+" is "+style_ly_str+"kissing "+names[0]
            elseif anim.HasTag("Headpat")
                msg += names[1]+" is "+style_ly_str+"patting "+names[0]+"'s head"
            elseif anim.HasTag("Hugging")
                msg += names[1]+" is "+style_ly_str+"hugging "+names[0]
            elseif anim.HasTag("Spanking")
          elseif anim.HasTag("cuffs") || anim.HasTag("cuffed")
            msg += name+"'s arms are cuffed."
        elseif anim.HasTag("yoke")
            msg += name+"'s arms are bound in a yoke."
        elseif anim.HasTag("hogtied")
            msg += name+" is hogtied."
        elseif anim.HasTag("chastiy") || anim.HasTag("chastitybelt")
            msg += name+" is wearing a chastity belt."
        endif 
    endif 

    msg += desc
    msg += " "+getNames() ; Strapon Names 

    ; Label hermpahrodites or not depending on user preference.
    GlobalVariable skyrimnet_sexlab_hide_hermaphrodites = Game.GetFormFromFile(0x806, "SkyrimNet_SexLab.esp") as GlobalVariable
    if skyrimnet_sexlab_hide_hermaphrodites.GetValueInt() != 1.0
        msg += " "+getNames(True) ; Futa Names 
    endif 
    msg += " "+getCreatures() ; Creature Names

    return msg
EndFunction

String Function GetThreadJson()

    sslActorLibrary actorLib = (SexLab as Quest) as sslActorLibrary 

    String thread_str = "{"+'"'+"stage_description_has"+'"'+":false"

    String names = "" 
    int i = 0
    int num_victims = 0
    while i < actors.Length
        if names != "" 
            names += ","
        endif 
        names += '"'+actors[i].GetDisplayName()+'"'
        if thread.IsVictim(actors[i])
            num_victims += 1
        endif
        i += 1
    endwhile 
    if actors.length > 2 
        thread_str += ", "+'"'+"orgy"+'"'+":true"
    else 
        thread_str += ", "+'"'+"orgy"+'"'+":false"
    endif
    thread_str += ", "+'"'+"names"+'"'+":["+names+"]"
    thread_str += ", "+'"'+"names_str"+'"'+":"+'"'+""+GetStatusMessage()+'"'

    String style = ""

    if num_victims > 0
        String victims = "" 
        String aggressors = ""
        i = 0
        while i < actors.Length 
            if thread.IsVictim(actors[i])
                if victims != ""
                    victims += ", "
                endif 
                victims += '"'+actors[i].GetDisplayName()+'"'
            else
                if aggressors != ""
                    aggressors += ", "
                endif 
                aggressors += '"'+actors[i].GetDisplayName()+'"'
            endif
            i += 1
        endwhile
        thread_str += ',"victims":['+victims+"]"
        thread_str += ',"aggressors":['+aggressors+"]"
        thread_str += ',"rape": true'
    else
        thread_str += ',"rape": false'
    endif 

    sslBaseAnimation anim = thread.Animation
    i = 0
    String tags_str = GetTagsString(anim)
    thread_str += ',"tags": ['+tags_str+"]"

    String[] positions = new String[7]
    positions[0] = "69"
    positions[1] = "cowgirl"
    positions[2] = "missionary"
    positions[3] = "kneeling"
    positions[4] = "doggy"
    positions[5] = "sitting"
    positions[6] = "standing"

    i = 0
    bool found = false
    String position = ""
    while i < positions.Length && position == ""
        if anim.HasTag(positions[i])
            position = positions[i]
            found = true
        endif
        i += 1
    endwhile
    thread_str += ',"position":"'+position+'"'
    
    String emotion = ""
    if anim.HasTag("rough")
        emotion += " roughly"
    elseif anim.HasTag("loving")
        emotion += " lovingly"
    endif
    thread_str += ',"emotion":"'+emotion+'"'
    return thread_str
EndFunction

;----------------------------------------------------
; Orgasm 
;----------------------------------------------------

Function addOrgasm(ACtor akActor, String msg) 
    int i = actors.length
    while 0 < i && actors[i] != akActor
        i -= 1 
    endif 
    if 0 <= i 
        num_orgasms[i] += 1 
        DirectNarration(msg, akActor, None)
    endif 
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

String Function GetCreatures() 
    Actor[] positions = thread.Positions
    String names = "" 
    int i = 0
    int count = positions.length 
    while i < count
        Race r = positions[i].GetRace() 
        if sslCreatureAnimationSlots.HasRaceType(r) 
            String name = positions[i].GetDisplayName()
            String race_name = r.GetName() 
            names += name+" is a "+race_name+". "
            int j = JArray.count(main.race_to_description) - 1 
            while 0 <= j 
                int creature = Jarray.getObj(main.race_to_description, j) 
                Race creature_race = JMap.getForm(creature,"form_") as Race 
                if creature_race == r 
                    names += JMap.getStr(creature, "description_")
                    j = -1 
                else 
                    j -= 1 
                endif 
            endwhile 
        endif 
        i += 1
    endwhile
    return names
EndFunction

String Function GetNamesArray() global
    String names = "" 
    int i = 0
    while i < positions.Length
        if names != "" 
            names += ","
        endif 
        names += '"'+positions[i].GetDisplayName()+'"'
        i += 1
    endwhile 
    return "["+names+"]"
EndFunction

String Function GetNames(Bool trans_names=False) global
    Actor[] positions = thread.Positions
    int num_positions = 0
    int count = positions.length
    int i = 0
    while i < count
        if actorLib != None 
            if actorLib.GetTrans(positions[i]) == 0 
                num_positions += 1
            endif 
        else 
            if thread.IsUsingStrapon(positions[i])
                num_positions += 1
            endif 
        endif 
        i += 1
    endwhile

    String names = "" 
    i = 0
    int j = 0
    while i < count
        bool match =  false 
        if actorLib != None 
            if actorLib.GetTrans(positions[i]) == 0 
                match = true
            endif 
        else 
            if thread.IsUsingStrapon(positions[i])
                match = true
            endif 
        endif 

        if match
            if j > 0
                if num_positions > 2
                    names += ", "
                else 
                endif
                if j == count - 1 
                    names += " and "
                endif
            endif
            names += positions[i].GetDisplayName()
            j += 1  
        endif 
        i += 1
    endwhile 
    if names != "" 
        if actorLib != None 
            if num_positions == 1
                names += " has a cock and pussy."
            else 
                names += " have a cock and pussy."
            endif
        else 
            if num_positions == 1
                names += " is using a strapon."
            else 
                names += " are using strapons."
            endif
        endif 
    endif 
    return names 
EndFunction

String Function GetEnjoyments()
    String str = ""
    int i = positions.length - 1 
    while 0 <= i 
        if str != "" 
            str += ", "
        endif 
        int enjoyment = 0
        sslActorAlias actorAlias = controller.ActorAlias(positions[i]) 
        if MiscUtil.FileExists("Data/SLSO.esp")
            enjoyment = actorAlias.GetFullEnjoyment() 
        else 
            enjoyment = actorAlias.GetEnjoyment() 
        endif 
        str += '"'+positions[i].GetDisplayName()+""+'"'+": "+enjoyment
        bool found = MiscUtil.FileExists("Data/SLSO.esp")
        i -= 1 
    endwhile 
    return "{"+str+"}"
EndFunction 

bool Function SexLab_Thread_LOS(Actor akActor)
    Actor[] positions = thread.Positions
    int i = 0
    while i < positions.length 
        if akActor == positions[i] || akActor.HasLOS(actors[i])
            return true
        endif 
        i += 1
    endwhile 
    return false
endFunction 

String Function GetTagsString() global 
    sslBaseAnimation anim = thread.Animation
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

; Allows the user to choose to accept the sex act chosen by the LLM 
; The value will between 
; 1 Yes with the editor 
; 2 Yes, but no tag editor 
; 3 No (silent), refused, but don't tell the LLM 
; 4 NO, tell the LLM 
int function YesNoDialog()
    Trace("YesNoDialog","positions.length: "+actors.length+" victims.length: "+victims.length+" player:"+player.GetDisplayName()+" type:"+type)

    Actor player = Game.GetPlayer() 
    String player_name = player.GetDisplayName()

    int yes = 0 
    int no_silent = 1
    int no = 2 

    String[] buttons = new String[4]
    if type == "kissing_only"
        buttons = new String[3] 
        buttons[yes] = "Yes"
        buttons[no_silent] = "No (Silent)"
        buttons[no] = "No"
    else 
        buttons[BUTTON_YES] = "Yes "
        buttons[BUTTON_YES_RANDOM] = "Yes (Random)"
        buttons[BUTTON_NO_SILENT] = "No (Silent)"
        buttons[BUTTON_NO] = "No "
    endif 


    String question = ""
    String rejection = ""

    if victims.length == 0
        int[] positions_filter = Utility.CreateIntArray(actors.length, 1)
        int i = positions.length - 1 
        while 0 <= i
            if positions[i] == player
                positions_filter[i] = 0
            endif 
            i -= 1
        endwhile
        String names = SkyrimNet_SexLab_Utilities.JoinpositionsFiltered(actors, actors_filter)
        Trace("YesNoDialog","type:names: "+names)
        question = "Would you like to have "+type+" with "+names+"?"
        rejection = player_name+" refuses to have "+type+" with "+names+"."
    endif 
else
    int[] victim_filter = Utility.CreateIntArray(positions.length, 1)
    int i = victims.length - 1 
    Bool player_is_victim = False
    while 0 <= i
        if victims[i] == player
            victim_filter[i] = 0
            player_is_victim = True 
        endif 
        i -= 1
    endwhile 

    int[] assailant_filter = Utility.CreateIntArray(positions.length, 1)
    i = positions.length - 1 
    while 0 <= i
        if positions[i] == player
            assailant_filter[i] = 0
        else    
            int j = victims.length - 1 
                while 0 <= j && assailant_filter[i] == 1
                    if positions[i] == victims[j]
                        assailant_filter[i] = 0
                    endif 
                    j -= 1
                endwhile
            endif 
            i -= 1 
        endwhile 

        Trace("YesNoDialog","type:rape names: "+SkyrimNet_SexLab_Utilities.Joinpositions(actors)+" victim_filter: "+victim_filter+" assailant_filter: "+assailant_filter)
        String assailant_names = SkyrimNet_SexLab_Utilities.JoinpositionsFiltered(actors, assailant_filter)
        if player_is_victim
            question = "Would you like to be "+type+" by "+assailant_names+"?"
            rejection = player_name+" refuses to be "+type+" "+assailant_names+"."
        else 
            String victim_names = SkyrimNet_SexLab_Utilities.JoinpositionsFiltered(victims, victim_filter)
            question = "Would you like to "+type+" "+victim_names
            if assailant_names != "" 
                question += " with "+assailant_names
            endif 
            question += "?"
            rejection = player_name+" refuses to "+type+" "+victim_names+"."
        endif 
    endif 
    
    int button = SkyMessage.ShowArray(question, buttons, getIndex = true) as int  
    if type == "kissing_only" 
        if button == yes 
            button = BUTTON_YES
        elseif button == no_silent 
            button = BUTTON_NO_SILENT
        else
            button = BUTTON_NO 
        endif 
    endif 
    Trace("YesNoDialog","question: "+question+" button:"+button)
    if button == BUTTON_NO || button == BUTTON_NO_SILENT
        if button == BUTTON_NO 
            DirectNarration_Optional(type+" refuses", rejection, player, positions[0])
        endif 
    endif 
    return button 
EndFunction

; Selects the style of sex 
; 0 forcefully 
; 1 normally 
; 2 gently 
int Function SexStyleDialog()
    String[] buttons = new String[3] 

;    Actor[] positions = thread.Positions
;    int k = positions.length - 1
;    bool rape = False
;    while 0 <= k && !rape
;        if thread.IsVictim(positions[k])
;            rape = True 
;        endif 
;        k -= 1
;    endwhile

    if !rape
        buttons[STYLE_FORCEFULLY] = "Forcefully "+type
        buttons[STYLE_NORMALLY] = "Have "+type
        buttons[STYLE_GENTLY] = "Gently make love"
    else
        buttons[STYLE_FORCEFULLY] = "Violently Raping"
        buttons[STYLE_NORMALLY] = "Raping"
        buttons[STYLE_GENTLY] = "Gently Raping"
    endif 
    int style = SkyMessage.ShowArray("Change style to:", buttons, getIndex = true) as int 
    if style < STYLE_FORCEFULLY || style > STYLE_GENTLY
        style = STYLE_NORMALLY
    endif 
    thread_style[thread_id] = style 
    return style
EndFunction

Bool Function SelectAnimations()
    Trace("SelectAnimations", sid+" "+positions_names_string+" victims: "+victims_names_string)
    sslBaseAnimation[] animations = new sslBaseAnimation[1] 
    animations[0] = None 
    int button = main.BUTTON_YES
    if has_player
        button = YesNoDialog()
        if button == main.BUTTON_NO || button == main.BUTTON_NO_SILENT
            return False 
        endif 
    endif  

    if button != main.BUTTON_YES_RANDOM
        if (main.sex_edit_tags_player && has_player) || (main.sex_edit_tags_nonplayer && !has_player)
            Trace("GetAnims", "Opening anim edit dialog")
            animations = SelectAnimations_Dialog()
        else 
            String tags_string = SkyrimNetApi.JoinStrings(tags)
            String tags_supress_string = SkyrimNetApi.JoinStrings(tags_supress)
            animations = sexLab.GetAnimationsByTags(positions.length, tags_string, tags_supress_string, true)
        endif 
    else
        String tags_string = SkyrimNetApi.JoinStrings(tags)
        String tags_supress_string = SkyrimNetApi.JoinStrings(tags_supress)
        animations =  main.sexLab.GetAnimationsByTags(positions.length, tags_string, tags_supress_string, true)
    endif 
    if animation[0] != None 
        thread.SetAnimations(animations) 
        return True 
    Endif 
    return False 
EndFunction 

; This function returns the list of animations matching the requested animations
; If no animations were selected, it will return an array with a single None value `[None]`
; 
;   anims = AnmisDialog(sexlab. positions, tag) 
;   if anims.length > 0 && anims[0] != None 
;        thread.SetAnimations(anims)
;   endif 
;
sslBaseAnimation[] Function GetAnimsDialog(sslThreadModel thread, Actor[] positions, String type, String tag)
    String names = SkyrimNet_SexLab_Utilities.Joinpositions(actors)
    Trace("GetAnimsDialog","names: "+names+" tag:"+tag)

    Actor player = Game.GetPlayer() 
    int i = positions.Length - 1 
    bool includes_player = False 
    while 0 <= i && !includes_player
        if positions[i] == player 
            includes_player = True 
        endif 
        i -= 1 
    endwhile

    ; Check if enabled by MCM 
    sslBaseAnimation[] empty = new sslBaseAnimation[1]
    empty[0] = None 

    if (includes_player && !sex_edit_tags_player) || (!includes_player && !sex_edit_tags_nonplayer)
        return empty 
    endif 

    ; Style to strings 
    String[] style_strings = new String[3]
    style_strings[STYLE_FORCEFULLY] = "style:forcefully>"
    style_strings[STYLE_NORMALLY] = "style:normally>"  
    style_strings[STYLE_GENTLY] = "style:gently>"

    ; Current set of tags
    String[] tags = new String[10]
    int count_max = 10
    int next = 0
    if tag != ""
        sslBaseAnimation[] anims =  SexLab.GetAnimationsByTags(positions.length, tag, "", true)
        if anims.length > 0
            tags[0] = tag
            next += 1
        else 
            Trace("AnimsDialog", "No animations found, dropping initial tag: "+tag)
        endif 
    endif 

    ; the order of the groups 
    int group_tags = JMap.getObj(group_info,"group_tags",0)
    if group_tags == 0 
        Trace("AnimsDialog", "group_tags not found in group_tags.json")
        return None
    endif 

    int groups = JMap.getObj(group_tags,"groups",0)
    if groups == 0
        groups = JMap.allKeys(group_tags)
    endif 
    int count = JArray.count(groups)

    JValue.retain(groups)
    uilistMenu listMenu = uiextensions.GetMenu("UIlistMenu") AS uilistMenu
    String start_label = "<start "+type+">"
    bool rape = type == "rape"
    while True
        String order_str ="change order>"
        bool finished = false
        String tags_str= ""
        String style_str = style_strings[thread_style[thread.tid]]
        while next < count_max && !finished
            listMenu.ResetMenu()

            ; build the current tags
            tags_str = "" 
            i = 0
            while i < next
                if i > 0 
                    tags_str += ","
                endif 
                tags_str += tags[i]
                i += 1
            endwhile 
            ; Use the current set of tags 
            String tags_label = "tags:"+tags_str
            listMenu.AddEntryItem(names)
            if positions.length > 1 
                listMenu.AddEntryItem(order_str)
            endif 
            listMenu.AddEntryItem(style_str)
            listMenu.AddEntryItem(tags_label)
            listMenu.AddEntryItem(start_label)

            ; Remove one tag 
            if 0 < next 
                listMenu.AddEntryItem("<remove")
            endif 

            ; Add groups
            i =  0
            while i < count
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
            elseif button == style_str
                int style = SexStyleDialog(thread.tid, rape)
                style_str = style_strings[style]
            elseif button == order_str 
                if positions.length > 1 
                    Actor temp = positions[0]
                    i = 0 
                    while i < positions.length - 1 
                        positions[i] = actors[i+1] 
                        i += 1 
                    endwhile 
                    positions[i] = temp 
                    names = SkyrimNet_SexLab_Utilities.Joinpositions(actors)
                endif 
            elseif button == "<cancel>"
                JValue.release(groups)
                return empty
            elseif button == "<remove"
                next -= 1
            elseif button != "-continue-" && button != names && button != tags_label
                tags[next] = button 
                next += 1
            endif 
        endwhile 
        sslBaseAnimation[] anims =  SexLab.GetAnimationsByTags(positions.length, tags_str, "", true)
        if anims.length > 0
            JValue.release(groups)
            return anims 
        else
            Trace("AnimsDialog","No animations found for: "+tags_str)
            Debug.Notification("No animations found for: "+tags_str)
        endif 
    endwhile 
    JValue.release(groups)
    return empty
EndFunction

Function ListAddTags(uilistMenu listMenu, int group_tags, String group) global
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
    ListAddTags(listMenu, group_tags, group) 
    listMenu.OpenMenu()
    String button =  listMenu.GetResultString()
    if button == "<back"
        button = "-continue-"
    endif 
    return button
EndFunction

; -----------------------------------
; Style 
; -----------------------------------
Function SetStyle(String _style) 
    style = STYLE_NORMALLY
    if style == "gentle" || style == "gently"
        scene.style = STYLE_GENTLY   
    elseif style == "forceful" || style == "forcefully"
        scene.style = STYLE_FORCEFULLY
    endif
EndFunction 