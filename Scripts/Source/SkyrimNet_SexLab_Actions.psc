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
Function RegisterActions(Bool rape_only=False) global
    SkyrimNet_SexLab_Main main = Game.GetFormFromFile(0x800, "SkyrimNet_SexLab.esp") as SkyrimNet_SexLab_Main
    String actions_fname = "Data/SKSE/Plugins/SkyrimNet_SexLab/actions.json"
    Trace("RegisterActions","loading "+actions_fname)

    String type = GetTypesStrings()
    int actions = JValue.readFromFile(actions_fname) 
    int count = JArray.count(actions) 
    int i = 0 
    while i < count 
        int a = JArray.getObj(actions, i) 
        Trace("RigsterActions", "i: "+i+" a: "+a)
         if a > 0
            String name = JMap.getStr(a, "name")
            if rape_only && name == "SexLab_Rape_Start" && !main.rape_allowed
                SkyrimNetApi.UnregisterAction(name)
            elseif (!rape_only && name != "SexLab_Rape_Start") || main.rape_allowed
                Trace("RegisterActions",\
                    i+" name: "+JMap.getStr(a, "name")\
                    +" description: "+JMap.getStr(a, "description")\
                    +" scriptFileName: "+JMap.getStr(a, "scriptFileName")\ 
                    +" execute: "+JMap.getStr(a, "execute")\
                    +" isEligible: "+JMap.getStr(a, "isEligible")\
                    +" priority: "+JMap.getInt(a, "priority")\
                    +" parameters: "+JMap.getStr(a, "parameters")\
                    +" tags: "+JMap.getStr(a, "tags"))
                SkyrimNetApi.RegisterAction(\ 
                    JMap.getStr(a, "name"),\
                    JMap.getStr(a, "description"),\
                    JMap.getStr(a, "scriptFileName"), JMap.getStr(a, "isEligible"),\
                    JMap.getStr(a, "scriptFileName"), JMap.getStr(a, "execute"),\
                    "", "PAPYRUS", JMap.getInt(a, "priority"),\
                    JMap.getStr(a, "parameters"),\
                    "", JMap.getStr(a, "tags"))
            endif
        else 
            Trace("RegisterActions","Failed to get object from i: "+i)
        endif 
        i += 1 
    endwhile 

    ; ------------------------
    SkyrimNetApi.RegisterTag("BodyAnimation", "SkyrimNet_SexLab_Actions","BodyAnimation_IsEligible")
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
    float start = Utility.GetCurrentRealTime()
    if akActor == None 
        Trace("BodyAnimation_IsEligible","akActor is None")
        return false
    endif

    String name = akActor.GetDisplayName()
    float current = Utility.GetCurrentRealTime() - start 
    Trace("BodyAnimation_IsEligible",current+" "+name+" contextJson: "+contextJson+" paramsJson: "+paramsJson)
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

    if sexlab_main.IsActorLocked(akActor)
        Trace("BodyAnimation_IsEligible", akActor.GetDisplayName()+" is locked")
        return false 
    endif

    if sexlab_main.sexLab.IsActorActive(akActor) 
        Trace("BodyAnimation_IsEligible", akActor.GetDisplayName()+" SexLab animation")
    endif 

    ;time = Utility.GetCurrentRealTime()
    ;delta = time- time_last
    ;time_last = time
    ;Trace("BodyAnimation_tag","locked :"+delta)

    ; Cuddle check 
    if sexlab_main.cuddle_found
        Faction cuddle_faction = Game.GetFormFromFile(0x801, "SkyrimNet_Cuddle.esp") as Faction
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
    if sexlab_main.ostimnet_found && OActor.IsInOStim(akActor)
        return false 
    endif 

    ;time = Utility.GetCurrentRealTime()
    ;delta = time- time_last
    ;time_last = time
    ;Trace("BodyAnimation_tag","ostim :"+delta)

    Trace("BodyAnimation_Tag", name+" is eligible for sex")
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

Bool Function Sex_Start_IsEligible(Actor akActor, string contextJson, string paramsJson) global
    return Sex_Start_Helper_IsEligible(akActor, contextJson, paramsJson, false)
EndFunction

Bool Function MastrubationStart_IsEligible(Actor akActor, string contextJson, string paramsJson) global
    return Sex_Start_Helper_IsEligible(akActor, contextJson, paramsJson, true)
EndFunction

Bool Function Sex_Start_Helper_IsEligible(Actor akActor, string contextJson, string paramsJson, bool masturbation) global
    SkyrimNet_SexLab_Main main = Game.GetFormFromFile(0x800, "SkyrimNet_SexLab.esp") as SkyrimNet_SexLab_Main
    if main.sexLab == None || main == None 
        return false
    endif 
    if main.sexlab_ostim_player == 1 && !masturbation
        Trace("Sex_Start_IsEligible", akActor.GetDisplayName()+" sexlab_sexstart is disabled")
        return false 
    endif 
    if !main.sexLab.IsValidActor(akActor)
        Trace("Sex_Start_IsEligible",akActor.GetDisplayName()+" can't have sex")
        return False
    endif

    Trace("Sex_Start_IsEligible", akActor.GetDisplayName()+" is eligible for sex")
    return True
EndFunction

Bool Function Sex_Start(Actor akActor, string contextJson, string paramsJson) global
    Trace("Sex_Start",akActor.GetDisplayName()+" "+paramsJson)
    SkyrimNet_SexLab_Main main = Game.GetFormFromFile(0x800, "SkyrimNet_SexLab.esp") as SkyrimNet_SexLab_Main
    if main == None
        return False
    endif
    String tag = SkyrimNetApi.GetJsonString(paramsJson, "type","")
    if !BodyAnimation_IsEligible(akActor, "", "") 
        return  False
    endif 

    Actor akTarget = SkyrimNetApi.GetJsonActor(paramsJson, "target", None)

    Bool target_is_dominate = SkyrimNetApi.GetJsonBool(paramsJson, "target_is_dominate",false)
    if target_is_dominate && akTarget != None 
        Actor temp = akActor 
        akActor = akTarget 
        akTarget = temp
    endif
    ;-------------------------------

    Actor player = Game.GetPlayer() 
    int num_parts = 0 
    Actor[] parts = new Actor[5]
    parts[num_parts] = akActor 
    num_parts += 1 
    if akTarget != None && akTarget != akActor
        parts[num_parts] = akTarget 
        num_parts += 1
    endif

    String target_name = "None"
    if akTarget != None 
        target_name = akTarget.GetDisplayName() 
    endif
    Trace("Sex_Start","target: "+target_name+" parts:"+SkyrimNet_SexLab_Utilities.JoinActors(parts))
    
    int num_victs = 0 
    Actor[] victs = new Actor[5]
    String target_is_victim = SkyrimNetApi.GetJsonString(paramsJson, "target_is_victim","")
    if target_is_victim == "true"
        victs[0] = akTarget
        num_victs += 1
    elseif target_is_victim == "false"        
        victs[0] = akActor
        num_victs += 1
    endif 

    String[] parameters = new String[3] 
    parameters[0] = "participant"
    parameters[1] = "victim"
    parameters[2] = "assailant"     
    int i = 0
    while i < 5
        int k = 0
        while k < 3
            String param = parameters[k]+"_"+i
            Actor participant = SkyrimNetAPI.GetJsonActor(paramsJson, param, None) 
            if participant != None 
                int j = 0 
                Bool found = False
                while j < num_parts && !found
                    if parts[j] == participant 
                        found = True 
                    endif 
                    j += 1
                endwhile
                if !found
                    String name = participant.GetDisplayName() 
                    Trace("Sex_Start",param+" is actor "+name)
                    parts[num_parts] = participant
                    num_parts += 1
                    ;elseif i == 0 
                    ;    name = SkyrimNetAPI.GetJsonString(paramsJson, param, "") 
                    ;    if name == player.GetDisplayName() 
                    ;        parts[num_parts] = player
                    ;        num_parts += 1 
                    ;        Trace("Sex_Start",param+" is None. name: "+name+ " matched player")
                    ;    elseif name == akActor.GetDisplayName() 
                    ;        parts[num_parts] = akActor
                    ;        num_parts += 1 
                    ;        Trace("Sex_Start",param+" is None. name: "+name+ " matched akActor")
                    ;    endif 
                    ;endif 
                else 
                    Trace("Sex_Start",param+" is duplicate actor "+participant.GetDisplayName())
                endif 

                if parameters[k] == "victim"
                    j = 0 
                    found = False
                    while j < num_victs && !found
                        if victs[j] == participant 
                            found = True 
                        endif 
                        j += 1
                    endwhile
                    if !found
                        victs[num_victs] = participant 
                        num_victs += 1 
                    endif 
                endif 
            endif 
            k += 1
        endwhile
        i += 1 
    endwhile 
    int style = GetStyle(main, paramsJson)

    ;-------------------------------
    Bool has_player = False
    Actor[] actors = PapyrusUtil.ActorArray(num_parts) 
    i = 0
    while i < num_parts
        actors[i] = parts[i]
        if actors[i] == player
            has_player = True   
        endif
        i += 1 
    endwhile 
    if num_parts == 1
        int gender = main.sexlab.GetGender(actors[0]) 
        bool has_penis = (gender != 1 && gender != 3)
        tag = "F" 
        if has_penis 
            tag = "M"
        endif 
    endif 

    ;-------------------------------
    Actor[] victims = PapyrusUtil.ActorArray(num_victs) 
    i = 0
    while i < num_victs
        victims[i] = victs[i]
        i += 1 
    endwhile 

    if num_victs > 0 && num_parts && actors[0] != victims[0]
        int j = 1 
        while j < num_parts && actors[0] != victims[0] 
            if actors[j] == victims[0]
                Actor temp = actors[0]
                actors[0] = actors[j]
                actors[j] = temp
            endif 
            j += 1
        endwhile
    endif 

    ;-------------------------------
    ; Animations
    ;-------------------------------

    if !main.LockActors(actors) 
        return False
    endif 
    sslBaseAnimation[] anims =  GetAnims(main, actors, victims, player, tag, has_player) 
    if anims.length > 0 && anims[0] == None
        Trace("Sex_Start","Failed to get animations")
        main.UnlockActors(actors) 
        return False
    endif 
    sslThreadModel thread = main.sexlab.NewThread()
    if anims.length > 0 
        thread.SetAnimations(anims) 
    endif 

    ;-------------------------------

    if thread == None
        Trace("Sex_Start","Failed to create thread")
        main.UnlockActors(actors)
        return False 
    endif
    
    i = 0 
    int count = actors.length 
    while i < count 
        if thread.addActor(actors[i]) < 0   
            Trace("Sex_Start","Starting sex couldn't add " + actors[i].GetDisplayName())
            main.UnLockActors(actors) 
            return False
        endif  
        i += 1 
    endwhile 

    i = num_victs - 1 
    while 0 <= i 
        thread.SetVictim(victims[i])
        i -= 1 
    endwhile  

    main.SetThreadStyle(thread.tid, style) 
    Trace("Sex_Start",\
         " actors: \""+SkyrimNet_SexLab_Utilities.JoinActors(actors)+"\""\
        +" victims: \""+SkyrimNet_SexLab_Utilities.JoinActors(victims)+"\""\
        +" tag:"+tag\
        +" style:"+style\
        +" has_player: "+has_player\
        +" anims.length: "+anims.length) 
    thread.StartThread() 
    return True 
EndFunction

sslBaseAnimation[] Function GetAnims(SkyrimNet_SexLab_Main main, Actor[] actors, Actor[] victims, Actor player, String tag, Bool has_player) global
    String names = SkyrimNet_SexLab_Utilities.JoinActors(actors) 
    String victim_names = SkyrimNet_SexLab_Utilities.JoinActors(victims) 
    Trace("GetAnims", "actors: "+names+" victims: "+victim_names+" tag:"+tag+" has_player: "+has_player)
    sslBaseAnimation[] anims = new sslBaseAnimation[1] 
    anims[0] = None 
    int button = main.BUTTON_YES
    if has_player
        button = main.YesNoSexDialog(actors, victims, player, tag)
        if button == main.BUTTON_NO || button == main.BUTTON_NO_SILENT
            Trace("GetAnims_CheckLock","User declined")
            return anims 
        endif 
    endif  

    if button != main.BUTTON_YES_RANDOM
        String type = "sex"
        if victims.length > 0 
            type = "rape"
        endif 

        if (main.sex_edit_tags_player && has_player) || (main.sex_edit_tags_nonplayer && !has_player)
            anims = main.GetAnimsDialog(main.sexlab, actors, type, tag)
        endif 
        Trace("GetAnims", "has_player: "+has_player+" player edit: "+main.sex_edit_tags_player\
            +" nonplayer edit: "+main.sex_edit_tags_nonplayer+" anims.length: "+anims.length)
    elseif tag != ""
        String tagSupress = ""
        anims =  main.sexLab.GetAnimationsByTags(actors.length, tag, tagSupress, true)
    endif 

    return anims 
EndFunction 

int Function GetStyle(SkyrimNet_SexLab_Main main , String paramsJson) global
    String style_str = SkyrimNetApi.GetJsonString(paramsJson, "style","normal")
    int style = main.STYLE_NORMALLY
    if style_str == "gentle" 
        style = main.STYLE_GENTLY 
    elseif style_str == "forceful"
        style = main.STYLE_FORCEFULLY
    endif  
    return style 
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
