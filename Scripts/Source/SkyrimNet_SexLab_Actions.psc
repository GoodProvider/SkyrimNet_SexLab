Scriptname SkyrimNet_SexLab_Actions extends Quest
SkyrimNet_SexLab_Main Property main Auto 
SkyrimNet_SexLab_AnimationHandler Property anim_handler Auto 

import SkyrimNet_SexLab_Utilities

Idle Property pa_HugA Auto  ; IDLE:000F4699

Quest Property ostimnet_actions Auto 

Function Trace(String func, String msg, Bool notification=False) global
    msg = "[SkyrimNet_SexLab_Actions."+func+"] "+msg
    Debug.Trace(msg) 
    if notification
        Debug.Notification(msg)
    endif 
EndFunction

Function Setup()
    main = (self as Quest) as SkyrimNet_SexLab_Main
    anim_handler = (Self as Quest) as SkyrimNet_SexLab_AnimationHandler
    if MiscUtil.FileExists("Data/TT_OStimNet.esp")
        ostimnet_actions = Game.GetFormFromFile(0x800, "TT_OStimNet.esp") as TTON_Actions
    endif 
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
    if sexlab_main == None
        return false
    endif

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

;--------------------------------------------------
; Sex Start Functions 
;--------------------------------------------------

sslThreadModel Function Sex_Start(Actor Speaker, Actor Target, string style, string direction, string tag)
    Trace("Sex_Start",Speaker.GetDisplayName()+" + "+Target.GetDisplayName()+" style: "+style+" direction: "+direction+" type: "+tag)
    Actor[] actors = new Actor[2]
    actors[0] = Speaker
    actors[1] = Target
    Actor[] victims = PapyrusUtil.ActorArray(0) 
    Trace("Sex_Start",SkyrimNet_Sexlab_Utilities.JoinActors(actors)+" style: "+style+" direction:"+direction+" type: "+tag)
    return Sex_Start_helper(Speaker, actors, victims, style, direction, tag) 
EndFunction

sslThreadModel Function Rape_Start(Actor Speaker, Actor Target, string style, String direction, string tag, Actor victim)
    Trace("Rape_Start",Speaker.GetDisplayName()+" + "+Target.GetDisplayName()+" style: "+style+" type: "+tag+" victim: "+victim.GetDisplayName())
    Actor[] actors = new Actor[2]
    actors[0] = Target
    actors[1] = Speaker

    Actor[] victims = PapyrusUtil.ActorArray(1) 
    victims[0] = actors[0]

    Trace("Rape_Start",SkyrimNet_Sexlab_Utilities.JoinActors(actors)+" victim:"+victim.GetDisplayName()+" style: "+style+" direction:"+direction+" type: "+tag)
    return Sex_Start_helper(Speaker, actors, victims, style, direction, tag) 
EndFunction

sslThreadModel Function Orgy_Start(Actor Speaker, Actor Target, Actor participate, string style, String direction, string tag)
    Actor[] possible = new Actor[3]
    possible[0] = speaker
    possible[1] = target
    possible[2] = participate 

    int num_actors = 1
    int i = possible.length - 1
    while 0 <= i
        if possible[i] != None
            num_actors += 1
        endif
        i -= 1
    endwhile
    Actor[] actors = PapyrusUtil.ActorArray(num_actors+1)
    actors[0] = Speaker
    int k = 1
    i = possible.length - 1
    while 0 <= i
        if possible[i] != None
            actors[k] = possible[i]
            k += 1
        endif
        i -= 1
    endwhile

    Trace("Orgy_Start",SkyrimNet_Sexlab_Utilities.JoinActors(actors)+" style: "+style+" direction:"+direction+" type: "+tag)
    Actor[] victims = PapyrusUtil.ActorArray(0) 
    return Sex_Start_helper(Speaker, actors, victims, style, direction, tag) 
EndFunction


sslThreadModel Function Masturbation_Start(Actor Speaker, string style, String tag)
    Trace("Masturbation_Start",Speaker.GetDisplayName()+" style: "+style+" tag: "+tag)
    int gender = main.sexlab.GetGender(Speaker)
    bool has_penis = (gender != 1 && gender != 3)

    Actor[] actors = new Actor[1] 
    actors[0] = speaker

    Actor[] victims = PapyrusUtil.ActorArray(0) 
    return Sex_Start_helper(Speaker, actors, victims, style, "", tag) 
EndFunction

sslThreadModel Function Affection_Start(Actor Speaker, Actor Target, String style, String tag, bool narration = False) 
    Trace("Affection_start"," speaker:"+speaker.getDisplayName() +" target:"+target.GetDisplayName()+" style:"+style+" tag:"+tag)
    ;if main.sexlab_ostim_affection 
        ;Trace("Affection_Start","ostimnet_actions")
        ;main.sexlab_ostim_player = 1
        ;(ostimnet_actions as TTON_Actions).StartAffectionSceneExecute(speaker, target, tag)
        ;main.sexlab_ostim_player = 0
        ;return None 
    ;endif 

    if tag == "hugging" 
        target.playIdleWithTarget(pa_HugA, speaker) 
        DirectNarration(speaker.GetDisplayName()+" hugs "+target.GetDisplayName()+".", speaker, target)
        return None 
    ; Couldn't make these look nice 
    ;elseif tag == "kiss"
    ;
    ;   anim_handler.PlayByName_SpeakerTarget(Speaker,Target, "kiss")
    ;    return None 
    endif 

    Actor[] actors = new Actor[2] 
    actors[0] = Speaker 
    actors[1] = Target 
    Actor[] victims = PapyrusUtil.ActorArray(0) 
    return Sex_Start_Helper(Speaker, actors, victims, style, "giving", "kissing_only") 
EndFunction

sslThreadModel Function Sex_Start_Helper(Actor Speaker, Actor[] actors, Actor[] victims, String style, String direction, String tag, String hook="")
    Trace("Sex_Start_Helper",SkyrimNet_SexLab_Utilities.JoinActors(actors)+" style:"+style+" direction:"+direction+" tag:"+tag)
    if !main.LockActors(actors) 
        return None
    endif 

    ; ------------------------------------------
    ; Set up directions and tags 
    ; ------------------------------------------
    if actors.length == 1
        if tag != ""
            tag += ","
        endif
        int gender = main.sexlab.GetGender(actors[0])

        bool has_penis = (gender != 1 && gender != 3)
        if has_penis 
            tag = "M"
        else 
            tag = "F"
        endif 
    else
        if  (tag == "oral" || tag == "handjob" || tag == "boobjob" || tag == "thighjob" || tag == "footjob") && direction == "getting"
            Actor temp = actors[0] 
            actors[0] = actors[1]
            actors[1] = temp 
        else 
            if direction == "fucking a"
                Actor temp = actors[0] 
                actors[0] = actors[1]
                actors[1] = temp 
            endif 
            if tag == "pussy" 
                tag = "vaginal" 
            elseif tag == "ass" 
                tag = "anal"
            endif 
        endif 
    endif 

    ; ------------------------------------------
    ; Find player 
    ; ------------------------------------------
    Actor player = Game.GetPlayer() 
    Bool has_player = False
    String names = ""
    int i = actors.length - 1
    while i >= 0 
        if actors[i] == player
            has_player = True
        endif 
        i -= 1
    endwhile 
    
    if names != ""
        Trace("Sex_Start_Helper","Ineligible actors: "+names)
        return NOne 
    endif

    ;-------------------------------
    ; Animations
    ;-------------------------------

    sslThreadModel thread = main.sexlab.NewThread()

    if thread == None
        Trace("Sex_Start_Helper","Failed to create thread")
        main.UnlockActors(actors)
        return None 
    endif

    ; Set the style 
    int style_int = main.STYLE_NORMALLY
    if style == "gentle" || style == "gently"
        style_int = main.STYLE_GENTLY   
    elseif style == "forceful" || style == "forcefully"
        style_int = main.STYLE_FORCEFULLY
    endif
    main.SetThreadStyle(thread.tid, style_int) 
    
    ; Get the animations 
    sslBaseAnimation[] anims =  GetAnims(main, thread, actors, victims, player, tag, has_player) 
    if anims.length > 0 && anims[0] == None
        main.UnlockActors(actors) 
        return None
    endif 

    if anims.length > 0 
        thread.SetAnimations(anims) 
    elseif tag == "kissing_only"
        Debug.Notification("No animations found for kissing")
        main.UnlockActors(actors)
        return None 
    endif 


    ;-------------------------------
    Trace("Sex_Start_Helper","adding actors")

    int[] speaker_filter = Utility.CreateIntArray(actors.length,1)
    i = 0 
    int count = actors.length 
    while i < count 
        if actors[i] == speaker
            speaker_filter[i] = 0
        endif 

        if thread.addActor(actors[i]) < 0   
            Trace("Sex_Start_Helper","Starting sex couldn't add " + actors[i].GetDisplayName())
            main.UnLockActors(actors) 
            return None
        endif  
        if tag == "kissing_only"
            thread.SetNoStripping(actors[i])
            thread.DisableOrgasm(actors[i], true) 
        endif 
        i += 1 
    endwhile 

    if tag == "kissing_only"
        main.SetKissingOnly(thread.tid, True ) 
    else
        main.SetKissingOnly(thread.tid, False ) 
    endif 

    ; Add Victims 
    i = victims.length - 1
    while 0 <= i 
        thread.SetVictim(victims[i])
        i -= 1 
    endwhile  

    Trace("Sex_Start_Helper",\
         " actors: \""+SkyrimNet_SexLab_Utilities.JoinActors(actors)+"\""\
        +" victims: \""+SkyrimNet_SexLab_Utilities.JoinActors(victims)+"\""\
        +" tag:"+tag\
        +" style:"+style\
        +" has_player: "+has_player\
        +" anims.length: "+anims.length) 

    if hook != "" 
        thread.SetHook(hook)
    endif 

    ; If gender is male and giving oral, treat as woman so they can stay in the giving location
    Trace("Sex_Start_Helper",SkyrimNet_SexLab_Utilities.JoinActors(thread.positions))
    if actors.length > 1 
        String msg = "" 
        if tag == "kissing_only"
            msg = speaker.GetDisplayName()+" starts activities with "+JoinActorsFiltered(actors,speaker_filter)+"."
        else 
            msg = speaker.GetDisplayName()+" starts sexual activites with "+JoinActorsFiltered(actors,speaker_filter)+"."
        endif 
        RegisterEvent("Start_Activities",msg, speaker) 
    endif 
    thread.StartThread() 
    return thread 
EndFunction

;--------------------------------------
; Stop Function 
;--------------------------------------

Function Sex_Stop(Actor akActor) 
    sslThreadController thread = main.GetThread(akActor) 
    main.AnimationEndFunction(thread.tid,true, akActor) 
    sslThreadSlots thread_slots = (main.sexlab as Quest) as sslThreadSlots
    thread_slots.StopThread(thread) 
EndFunction 

;--------------------------------------
; Kissing Function 
;--------------------------------------

;--------------------------------------
; Functions 
;--------------------------------------

sslBaseAnimation[] Function GetAnims(SkyrimNet_SexLab_Main main, sslThreadModel thread, Actor[] actors, Actor[] victims, Actor player, String tag, Bool has_player) global
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
        if tag == "kissing_only"
            String tag_filter =" oral,vaginal,anal,masturbation,handjob,boobjob,thighjob,fisting,dildo,fingering,footjob"
            anims = main.sexLab.GetAnimationsByTags(actors.length, "kissing", tag_filter, true)
        else 
            String type = "sex"
            if victims.length > 0 
                type = "rape"
            endif 

            if (main.sex_edit_tags_player && has_player) || (main.sex_edit_tags_nonplayer && !has_player)
                Trace("GetAnims", "Opening anim edit dialog")
                anims = main.GetAnimsDialog(thread, actors, type, tag)
            else 
                anims = main.sexLab.GetAnimationsByTags(actors.length, tag, "", true)
            endif 
            Trace("GetAnims", "has_player: "+has_player+" player edit: "+main.sex_edit_tags_player\
                +" nonplayer edit: "+main.sex_edit_tags_nonplayer+" anims.length: "+anims.length)
        endif 
    else
        String tagSupress = ""
        anims =  main.sexLab.GetAnimationsByTags(actors.length, tag, tagSupress, true)
    endif 

    return anims 
EndFunction 

; -------------------------------------------------
; Dress and Undress
; -------------------------------------------------
Function Change_Outfit(Actor Stripper, Actor Stripped, String Style, String how, String Narration)
    Trace("Change_Outfit",Stripper.GetDisplayName()+" stripper "+Stripped.GetDisplayName()+" style:"+style+" how: "+how+" narration:"+narration)
    SkyrimNet_SexLab_Main main_local = Game.GetFormFromFile(0x800, "SkyrimNet_SexLab.esp") as SkyrimNet_SexLab_Main

    bool success = False
    if how == "dresses"
        Form[] forms = main_local.UnStoreStrippedItems(Stripped)
        if forms.length > 0
            main_local.sexlab.UnStripActor(Stripped, forms, false)
            success = True
        else
            Trace("Change_Outfit",Stripped.GetDisplayName()+" has no stripped items")
        endif
    else
        ;/* StripActor
        * * Strips an actor using SexLab's strip settings as chosen by the user from the SexLab MCM
        * * 
        * * @param: Actor ActorRef - The actor whose equipment shall be unequipped.
        * * @param: Actor VictimRef [OPTIONAL] - If ActorRef matches VictimRef victim strip settings are used. If VictimRef is set but doesn't match, aggressor settings are used.
        * * @param: bool DoAnimate [OPTIONAL true by default] - Whether or not to play the actor stripping animations during the strip
        * * @param: bool LeadIn [OPTIONAL false by default] - If TRUE and VictimRef == none, Foreplay strip settings will be used.
        * * @return: Form[] - An array of all equipment stripped from ActorRef
        */;
        Actor victim = None 
        Bool do_animate = True
        if stripper != stripped
            victim = stripped 
            do_animate = False
        endif 
        Form[] forms = main_local.sexlab.StripActor(stripped, victim, do_animate, false) 
        main_local.StoreStrippedItems(Stripped, forms)
    endif

    if success
        Actor listener = Stripped 
        if listener == Stripper 
            listener = None 
        endif 

        String msg = Stripper.GetDisplayName()+" "+style+" "+how+"es "+Stripped.GetDisplayName()+"."
        if narration == "direct"
            DirectNarration(msg, stripper, listener) 
        elseif narration == "silent"
            RegisterEvent(how,msg, stripper, listener) 
        endif 
    endif 
EndFunction