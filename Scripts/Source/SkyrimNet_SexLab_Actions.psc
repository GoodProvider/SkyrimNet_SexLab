Scriptname SkyrimNet_SexLab_Actions 

Function Trace(String func, String msg, Bool notification=False) global
    msg = "[SkyrimNet_SexLab_Actions."+func+"] "+msg
    Debug.Trace(msg) 
    if notification
        Debug.Notification(msg)
    endif 
EndFunction

;----------------------------------------------------------------------------------------------------
; Actions
;----------------------------------------------------------------------------------------------------
Function RegisterActions() global
    Trace("RegisterActions","started")
    SkyrimNet_SexLab_Main main = Game.GetFormFromFile(0x800, "SkyrimNet_SexLab.esp") as SkyrimNet_SexLab_Main

    String type = GetTypesStrings()

    ; ------------------------
    ; This also has a undress/dress action
    SkyrimNetApi.RegisterAction("SexLab_SexStart", \
            "Start having consensual {style} with {target}.", \
            "SkyrimNet_SexLab_Actions", "SexStart_IsEligible",  \
            "SkyrimNet_SexLab_Actions", "SexStart_Execute",  \
            "", "PAPYRUS", 1, \
            "{\"target\": \"Actor\", \"style\":\"fucking|sex|making love\", \"type\":\""+type+"\", \"rape\":false, \"target_victim\":false}",\
            "", "BodyAnimation")
    SkyrimNetApi.RegisterAction("SexLab_MasturbationStart", \
            "Start masturbating.",\
            "SkyrimNet_SexLab_Actions", "MastrubationStart_IsEligible",  \
            "SkyrimNet_SexLab_Actions", "MastrubationStart_Execute",  \
            "", "PAPYRUS", 1, \
            "{\"type\":\"masturbation\", \"rape\":{true|false}}",\
            "", "BodyAnimation")

    ; ------------------------
    SkyrimNetApi.RegisterAction("SexLab_Dress", \
            "Start to dress in clothing.",\
            "SkyrimNet_SexLab_Actions", "Dress_IsEligible",  \
            "SkyrimNet_SexLab_Actions", "Dress_Execute",  \
            "", "PAPYRUS", 1, \
            "")
    SkyrimNetApi.RegisterAction("SexLab_Undress", \
            "Start to undress clothing.",\
            "SkyrimNet_SexLab_Actions", "Undress_IsEligible",  \
            "SkyrimNet_SexLab_Actions", "Undress_Execute",  \
            "", "PAPYRUS", 5, \
            "")

    ; ------------------------
    RapeRegistration(main.rape_allowed)

    ; ------------------------
    SkyrimNetApi.RegisterTag("BodyAnimation", "SkyrimNet_SexLab_Actions","BodyAnimation_IsEligible")

EndFunction


Function RapeRegistration(bool rape_allowed) global
    if rape_allowed
        Trace("RapeRegistration","Resgistering SexLab_RapeStart and SexLab_RapedByStart actions")
        
        String type = GetTypesStrings()
        SkyrimNetApi.RegisterAction("SexLab_RapeStart", \
                "Start to sexually assualt {target}.",\
                "SkyrimNet_SexLab_Actions", "SexStart_IsEligible",  \
                "SkyrimNet_SexLab_Actions", "SexStart_Execute",  \
                "", "PAPYRUS", 1, \
                "{\"target\": \"Actor\", \"type\":\""+type+"\", \"rape\":true, \"target_victim\":true}","","BodyAnimation")
        SkyrimNetApi.RegisterAction("SexLab_RapedByStart", \
                "Start being sexually assulted by {target}.",\
                "SkyrimNet_SexLab_Actions", "SexStart_IsEligible",  \
                "SkyrimNet_SexLab_Actions", "SexStart_Execute",  \
                "", "PAPYRUS", 1, \
                "{\"target\": \"Actor\", \"type\":\""+type+"\", \"rape\":true, \"target_victim\":false}","","BodyAnimation")
    else 
        Trace("RapeRegistration","Unresgistering SexLab_RapeStart and SexLab_RapedByStart actions")
        SkyrimNetApi.UnregisterAction("SexLab_RapeStart")
        SkyrimNetApi.UnregisterAction("SexLab_RapedByStart")
    endif 
EndFunction

String Function GetTypesStrings() global 
    String[] types = GetTypes()
    int i = 0
    int count = types.Length 
    String type = ""
    while i < count 
        if type != "any"
            if type != "" 
                type += "|"
            endif 
            type += types[i]
        endif 
        i += 1
    endwhile 
    return type 
EndFunction

; -------------------------------------------------
; Tag 
; -------------------------------------------------

bool Function BodyAnimation_IsEligible(Actor akActor, string contextJson, string paramsJson) global
;    float time_last = Utility.GetCurrentRealTime()
    if akActor.IsDead() || akActor.IsInCombat() 
        Trace("BodyAnimation_IsEligible", akActor.GetDisplayName()+" is dead or in combat")
        return false 
    endif 

    ;float time = Utility.GetCurrentRealTime()
    ;float delta = time- time_last
    ;time_last = time
    ;Trace("BodyAnimation_tag","after isdead:"+delta)

    ; SexLab check
    SkyrimNet_SexLab_Main sexlab_main = Game.GetFormFromFile(0x800, "SkyrimNet_SexLab.esp") as SkyrimNet_SexLab_Main

    ;time = Utility.GetCurrentRealTime()
    ;delta = time- time_last
    ;time_last = time
    ;Trace("BodyAnimation_tag","after GetFrom :"+delta)

    if sexlab_main.IsActorLocked(akActor) || sexlab_main.sexLab.IsActorActive(akActor) 
        Trace("BodyAnimation_IsEligible", akActor.GetDisplayName()+" is locked or SexLab animation")
        return false 
    endif

    ;time = Utility.GetCurrentRealTime()
    ;delta = time- time_last
    ;time_last = time
    ;Trace("BodyAnimation_tag","locked :"+delta)

    ; Cuddle check 
    if MiscUtil.FileExists("Data/SkyrimNet_Cuddle.esp") 
        Faction cuddle_faction = Game.GetFormFromFile(0x802, "SkyrimNet_Cuddle.esp") as Faction
        if cuddle_faction == None 
            Trace("BodyAnimation_Tag","SkyrimNet_Cuddle_Main is None")
            return false
        endif
        int rank = akActor.GetFactionRank(cuddle_faction) 
        if rank > 0 
            Trace("BodyAnimation_IsEligible",akActor.GetDisplayName()+" has a cuddle rank of "+rank)
            return false
        endif
    endif 

    ;time = Utility.GetCurrentRealTime()
    ;delta = time- time_last
    ;time_last = time
    ;Trace("BodyAnimation_tag","cuddle :"+delta)

    ; Ostim check 
    if MiscUtil.FileExists("Data/OStim.esp") && OActor.IsInOStim(akActor)
        return false 
    endif 

    ;time = Utility.GetCurrentRealTime()
    ;delta = time- time_last
    ;time_last = time
    ;Trace("BodyAnimation_tag","ostim :"+delta)

    Trace("BodyAnimation_Tag", akActor.GetDisplayName()+" is eligible for sex")
    return True
EndFunction

; -------------------------------------------------
; ACtions 
; -------------------------------------------------

String[] Function GetTypes() global
    String[] types = new String[11]
    types[0] = "handjob"
    types[1] = "oral"
    types[2] = "boobjob"
    types[3] = "thighjob"
    types[4] = "vaginal"
    types[5] = "fisting"
    types[6] = "anal"
    types[7] = "dildo"
    types[9] = "fingering"
    types[10] = "footjob"
    return types
EndFunction

Bool Function SexStart_IsEligible(Actor akActor, string contextJson, string paramsJson) global
    return SexStart_Helper_IsEligible(akActor, contextJson, paramsJson, false)
EndFunction

Bool Function MastrubationStart_IsEligible(Actor akActor, string contextJson, string paramsJson) global
    return SexStart_Helper_IsEligible(akActor, contextJson, paramsJson, true)
EndFunction

Bool Function SexStart_Helper_IsEligible(Actor akActor, string contextJson, string paramsJson, bool masturbation) global
    SkyrimNet_SexLab_Main main = Game.GetFormFromFile(0x800, "SkyrimNet_SexLab.esp") as SkyrimNet_SexLab_Main
    if main.sexLab == None || main == None 
        return false
    endif 
    if main.sexlab_ostim_player_index == 1 && !masturbation
        Trace("SexStart_IsEligible", akActor.GetDisplayName()+" sexlab_sexstart is disabled")
        return false 
    endif 
    if !main.sexLab.IsValidActor(akActor)
        Trace("SexStart_IsEligible",akActor.GetDisplayName()+" can't have sex")
        return False
    endif

    Trace("SexStart_IsEligible", akActor.GetDisplayName()+" is eligible for sex")
    return True
EndFunction

Function MastrubationStart_Execute(Actor akActor, string contextJson, string paramsJson) global
    Trace("MastrubationStart_Execute",akActor.GetDisplayName()+" "+paramsJson)
    SkyrimNet_SexLab_Main main = Game.GetFormFromFile(0x800, "SkyrimNet_SexLab.esp") as SkyrimNet_SexLab_Main
    if main == None
        return
    endif
    Actor player = Game.GetPlayer()
    SexStart_Attempt(main, akActor, None, player, false, false, "mastrubation", main.STYLE_NORMALLY) 
EndFunction

Function SexStart_Execute(Actor akActor, string contextJson, string paramsJson) global
    Trace("SexStart_Execute",akActor.GetDisplayName()+" "+paramsJson)
    SkyrimNet_SexLab_Main main = Game.GetFormFromFile(0x800, "SkyrimNet_SexLab.esp") as SkyrimNet_SexLab_Main
    if main == None
        return
    endif

    Actor player = Game.GetPlayer()
    String type = SkyrimNetApi.GetJsonString(paramsJson, "type","")
    Actor akTarget = None
    if type != "masturbation" && type != "masturbate"
        akTarget = SkyrimNetApi.GetJsonActor(paramsJson, "target", None)
        if akTarget == None 
            if SkyrimNetApi.GetJsonBool(paramsJson, "target_is_player", false)
                akTarget = player
            endif 
            Bool name = SkyrimNetApi.GetJsonString(paramsJson, "target", "")
            Bool target_is_player = SkyrimNetApi.GetJsonBool(paramsJson, "target_is_player", false)
            Trace("SexStart_IsEligible", "name: "+name+" "+target_is_player+" "+akTarget+" "+paramsJson)
        endif 
        if akTarget == None 
            Trace("SexStart_IsExligible","type != masturbation, but target is None (likely in complete Actor name)", true )
            return 
        elseif !BodyAnimation_IsEligible(akTarget, "", "") 
            Trace("SexStart_IsExligible","akTarget already in an animation") 
            return 
        elseif !main.sexlab.IsValidActor(akTarget) 
            Trace("SexStart_IsExligible","akTarget is not a valid actor") 
            return 
        endif 
    endif 
    if akActor == akTarget
        type = "masturbation"
        akTarget = None
    endif 

    Bool target_is_victim = SkyrimNetApi.GetJsonBool(paramsJson, "target_is_victim", true)
    bool rape = SkyrimNetApi.GetJsonBool(paramsJson, "rape", false)

    String style_str = SkyrimNetApi.GetJsonString(paramsJson, "style","sex")

    int style = main.STYLE_NORMALLY
    if style_str == "making love" 
        style = main.STYLE_GENTLY 
    elseif style_str == "fucking"
        style = main.STYLE_FORCEFULLY
    endif  

    SexStart_Attempt(main, akActor, akTarget, player, rape, target_is_victim, type, style) 
EndFunction 

Function SexStart_Attempt(SkyrimNet_SexLab_Main main, Actor akActor, Actor akTarget, Actor player, bool rape, bool target_is_victim, String type, Int style) global
    if !main.SetActorLock(akActor) 
        main.ReleaseActorLock(akActor) 
        return 
    endif 
    if akTarget != None && !main.SetActorLock(akTarget)
        main.ReleaseActorLock(akActor)
        main.ReleaseActorLock(akTarget) 
        return 
    endif 

    Actor domActor = akTarget
    Actor subActor = akActor 
    ;Trace("SexStart_Attempt",domActor.GetDisplayName()+" > "+subActor.GetDisplayName())
    if rape && target_is_victim 
        domActor = akActor
        subActor = akTarget
    endif
    ;Trace("SexStart_Attempt",domActor.GetDisplayName()+" > "+subActor.GetDisplayName())

    int button = main.BUTTON_YES_RANDOM
    if subActor == player || (domActor != None && domActor == player)
        button = main.YesNoSexDialog(type, rape, domActor, subActor, player)
        if button == main.BUTTON_NO || button == main.BUTTON_NO_SILENT
            Trace("SexStart_Execute","User declined")
            main.ReleaseActorLock(akActor)
            main.ReleaseActorLock(akTarget)
            return 
        endif 
    elseif main.sex_edit_tags_nonplayer
        button = main.BUTTON_YES
    endif  

    int num_actors = 1
    if domActor != None
        num_actors = 2
    endif 

    bool failure = False
    sslThreadModel thread = main.sexlab.NewThread()
    if thread == None
        Trace("SexStart_Execute","Failed to create thread")
        failure = true 
    endif
    if button != main.BUTTON_YES_RANDOM
        if type == "kissing"
            String tagSupress = "oral,vaginal,anal,spanking,masturbate,handjob,footjob,masturbation,breastfeeding,fingering"
            sslBaseAnimation[] anims =  main.sexLab.GetAnimationsByTags(num_actors, type, tagSupress, true)
            if anims.length > 0
                thread.SetAnimations(anims)
                thread.addTag(type)
            else
                Trace("SexStart_Exectue","No kissing animation found")
                return 
            endif 
        else
            Actor[] actors = PapyrusUtil.ActorArray(num_actors)
            if num_actors == 1
                actors[0] = subActor
            else
                actors[0] = subActor
                actors[1] = domActor
            endif

            sslBaseAnimation[] anims = main.AnimsDialog(main.sexlab, actors, "")
            if anims.length > 0 && anims[0] != None  
                thread.SetAnimations(anims)
            endif 
        endif 
    endif 
    
    if !failure && thread.addActor(subActor) < 0   
        Trace("SexStart_Execute","Starting sex couldn't add " + subActor.GetDisplayName())
        failure = true 
    endif  
    if !failure && domActor != None 
        if thread.addActor(domActor) < 0   
            Trace("SexStart_Execute","Starting sex couldn't add DOM actor " + domActor.GetDisplayName())
            failure = true 
        endif  
    endif 
    
    if failure
        main.ReleaseActorLock(akActor)
        main.ReleaseActorLock(akTarget)
        return
    endif

    if rape
        thread.SetVictim(subActor)
    endif 

    main.SetThreadStyle(thread.tid, style) 
    thread.StartThread() 
EndFunction


; -------------------------------------------------
; Dress and Undress
; -------------------------------------------------

Bool Function Undress_IsEligible(Actor akActor, string contextJson, string paramsJson) global
    Trace("Undress_IsEligible",akActor.GetDisplayName())
    SkyrimNet_SexLab_Main main = Game.GetFormFromFile(0x800, "SkyrimNet_SexLab.esp") as SkyrimNet_SexLab_Main
    if main == None 
        return false
    endif 

    if main.dom_main_found
        if SkyrimNet_DOM_Utils.GetSlave("SkryimNet_SexLab_Actions", "SexTaget_IsEligible", akActor,false,false) != None
            Trace("Undress_IsEligible",akActor.GetDisplayName()+"'s is controlled by SkyrimNet_DOM so ineligible")
            return False
        endif 
    endif 

    if !main.sexLab.IsValidActor(akActor)
        Trace("Undress_IsEligible",akActor.GetDisplayName()+" can't undress")
        return False
    endif

    Trace("Undress_IsEligible", akActor.GetDisplayName()+" can undress")
    return True
EndFunction

Function Undress_Execute(Actor akActor, string contextJson, string paramsJson) global
    Trace("Undress_Execute",akActor.GetDisplayName())
    SkyrimNet_SexLab_Main main = Game.GetFormFromFile(0x800, "SkyrimNet_SexLab.esp") as SkyrimNet_SexLab_Main
    if main == None 
       return 
    endif 

    Trace("Undress_Execute", akActor.GetDisplayName())
    Form[] forms = main.sexlab.StripActor(akActor, akActor, false, false) 
    main.StoreStrippedItems(akActor, forms)
EndFunction

Bool Function Dress_IsEligible(Actor akActor, string contextJson, string paramsJson) global
    SkyrimNet_SexLab_Main main = Game.GetFormFromFile(0x800, "SkyrimNet_SexLab.esp") as SkyrimNet_SexLab_Main
    if main == None 
        return false
    endif 

    if main.dom_main_found
        if SkyrimNet_DOM_Utils.GetSlave("SkryimNet_SexLab_Actions", "SexTaget_IsEligible", akActor,false,false) != None
            Trace("Dress_IsEligible",akActor.GetDisplayName()+"'s is controlled by SkyrimNet_DOM so ineligible")
            return False
        endif 
    endif 


    if !main.sexLab.IsValidActor(akActor)
        Trace("Dress_IsEligible",akActor.GetDisplayName()+" can't dress")
        return False
    endif

    if !main.HasStrippedItems(akActor)
        Trace("Dress_IsEligible",akActor.GetDisplayName()+" has no stripped items")
        return False
    endif
    Trace("Dress_IsEligible", akActor.GetDisplayName()+" can dress")
    return True
EndFunction

Function Dress_Execute(Actor akActor, string contextJson, string paramsJson) global
    Trace("Dress_Execute",akActor.GetDisplayName())
    SkyrimNet_SexLab_Main main = Game.GetFormFromFile(0x800, "SkyrimNet_SexLab.esp") as SkyrimNet_SexLab_Main
    if main == None 
        return
    endif 

    Trace("Dress_Execute","Unstoring stripped items")
    Form[] forms = main.UnStoreStrippedItems(akActor)
    if forms.length > 0
        Trace("Dress_Execute",akActor.GetDisplayName()+" unstripping "+forms)
        main.sexlab.UnStripActor(akActor, forms, false) 
    else 
        Trace("Dress_Execute",akActor.GetDisplayName()+" has no stripped items")
    endif 
EndFunction

; -------------------------------------------------
; Tools
; -------------------------------------------------
