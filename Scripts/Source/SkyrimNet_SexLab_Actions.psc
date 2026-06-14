Scriptname SkyrimNet_SexLab_Actions extends Quest
SkyrimNet_SexLab_Main Property main Auto 
SexLabFramework Property sexlab Auto 

import SkyrimNet_SexLab_Utilities

Idle Property pa_HugA Auto  ; IDLE:000F4699

Faction OStimActorCountFaction = None 

Function Trace(String func, String msg, Bool notification=False) global
    msg = "[SkyrimNet_SexLab_Actions."+func+"] "+msg
    Debug.Trace(msg) 
    if notification
        Debug.Notification(msg)
    endif 
EndFunction

; -------------------------------------------------
; SetUp
; -------------------------------------------------
Function Setup()
    if MiscUtil.FileExists("Data/Ostim.esp") 
        OStimActorCountFaction = Game.GetFormFromFile(0xECA, "Ostim.esp") as Faction
        Trace("Setup","Found Ostim.esp, OStimActorCountFaction set to "+OStimActorCountFaction)
    else 
        OStimActorCountFaction = None 
    endif 
EndFunction 

;--------------------------------------------------------------------------------------
; Scene Start and Stop
;--------------------------------------------------------------------------------------

;-------------------------------------------
; One
;-------------------------------------------

Function StartScene_Consensual_One(Actor speaker, string style="", String tag="")
    Trace("StartScene_Consensual_One",speaker.GetDisplayName()+" style: "+style+" tag: "+tag)
    StartScene_Event("sexual activities", Speaker, style=style, tag=tag) 
EndFunction

;-------------------------------------------
; Two
;-------------------------------------------

Function StartScene_Affection_Two(Actor speaker, Actor target, string style="", string tag="", bool target_position_0=false)
    Trace("StartScene_Affection_Two",speaker.GetDisplayName()+" + "+target.GetDisplayName()+" style: "+style+" target_position_0: "+target_position_0+" activity: "+tag)
    StartScene_Event("affection", speaker, target, None, style, tag, target_position_0) 
EndFunction

Function StartScene_Consensual_Two(Actor speaker, Actor target, string style="", string tag="", bool target_position_0=false)
    Trace("StartScene_Consensual_Two",speaker.GetDisplayName()+" + "+target.GetDisplayName()+" style: "+style+" target_position_0: "+target_position_0+" activity: "+tag)
    StartScene_Event("sex", speaker, target, None, style, tag, target_position_0) 
EndFunction

Function StartScene_Rape_Two(Actor speaker, Actor target=None, string style="", string tag="", bool target_position_0=false, bool speaker_victim=false)
    Trace("StartScene_RapeTarget_Two",speaker.GetDisplayName()+" + "+target.GetDisplayName()+" style: "+style+" tag:"+tag+" target_position_0: "+target_position_0)
    Actor victim = target
    if speaker_victim 
        victim = speaker
    endif 
    StartScene_Event("rape", speaker, target, victim, style, tag, target_position_0) 
EndFunction

;-------------------------------------------
; Threesome
;-------------------------------------------

Function StartScene_Affection_Three(Actor speaker, Actor target, string style, String target_position_0, string tag, Actor participate)
    Trace("StartScene_Consensual_Three",speaker.GetDisplayName()+" + "+target.GetDisplayName()+" style: "+style+" target_position_0: "+target_position_0+" activity: "+tag+" participate:"+participate.GetDisplayName())
    StartScene_Event("showing affection", Speaker, target, None, style, target_position_0, tag, participate_3=participate) 
EndFunction

Function StartScene_Consensual_Three(Actor speaker, Actor target, string style, string tag, bool target_position_0, Actor participate)
    Trace("StartScene_Consensual_three",GetDisplayName(speaker)+" + "+GetDisplayName(target)+" style: "+style+" target_position_0: "+target_position_0+" activity: "+tag+" participate:"+GetDisplayName(participate))
    StartScene_Event("sexual activities", speaker, target, None, style, tag, target_position_0, participate) 
EndFunction

Function StartScene_Rape_Three(Actor speaker, Actor target, string style, string tag, bool target_position_0, bool speaker_victim, Actor participate)
    Trace("StartScene_Rape_three",GetDisplayName(speaker)+" + "+GetDisplayName(target)+" style: "+style+" target_position_0: "+target_position_0+" activity: "+tag+" speaker_victim:"+speaker_victim+" participate:"+GetDisplayName(participate))
    Actor victim = target
    if speaker_victim 
        victim = speaker
    endif 
    StartScene_Event("raping", speaker, target, victim, style, tag, target_position_0, participate) 
EndFunction

;-------------------------------------------
; Threesome
;-------------------------------------------

Function SceneStop(Actor speaker, Actor Target, String style)
    Trace("SceneStop",speaker.GetDisplayName()+" + "+Target.GetDisplayName()+" style: "+style)
    SceneStop_Event(speaker, target, style) 
EndFunction

;------------------------------------------------------------------------------
; Events 
;------------------------------------------------------------------------------

Function SceneStop_Event(Actor speaker, Actor target, String style) 
    int handle = ModEvent.Create("SkyrimNet_SexLab_Action_Stop")
    ModEvent.PushForm(handle, speaker)
    ModEvent.PushForm(handle, target)
    ModEvent.PushString(handle, style)
    ModEvent.Send(handle)
EndFunction 

;--------------------------------------
; Two actors 
;--------------------------------------
Function StartScene_Event(String activity, Actor speaker, Actor target=None, Actor victim=None,\
     string style="", string tag="", bool target_position_0=False, string scene_settings="", String event_hook="",\
     Actor participate_3=None)

    String speaker_name = GetDisplayName(speaker)
    String target_name = GetDisplayName(target) 
    String victim_name = GetDisplayName(victim) 
    Trace("StartScene_Event","activity:"+activity+" speaker:"+speaker_name+" target:"+target_name+" victim:"+victim_name\
        +" style:"+style+" target_position_0:"+target_position_0+" tag:"+tag+" scene_settings:"+scene_settings+" event_hook:"+event_hook)

    int handle = ModEvent.Create("SkyrimNet_SexLab_Action_Start")
    ModEvent.PushString(handle, activity)
    ModEvent.PushForm(handle, speaker)
    ModEvent.PushForm(handle, target)
    ModEvent.PushForm(handle, victim)
    ModEvent.PushString(handle, style)
    ModEvent.PushString(handle, tag)
    ModEvent.PushBool(handle, target_position_0)
    ModEvent.PushString(handle, scene_settings)
    ModEvent.PushString(handle, event_hook)
    ModEvent.PushForm(handle, participate_3)
    ModEvent.Send(handle)
EndFunction 


;--------------------------------------
; Functions 
;--------------------------------------



; -------------------------------------------------
; Dress and Undress
; Narration: direct, silent, none (notification or event)
; -------------------------------------------------
Function Change_Outfit(Actor stripper, Actor stripped, String style, String how, String narration)
    Trace("Change_Outfit",stripper.GetDisplayName()+" stripper "+stripped.GetDisplayName()+" style:"+style+" how: "+how+" narration:"+narration)

    bool success = False
    if how == "put on"
        Form[] forms = main.UnStoreStrippedItems(Stripped)
        if forms.length > 0
            sexlab.UnStripActor(Stripped, forms, false)
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
        Form[] forms = sexlab.StripActor(stripped, victim, do_animate, false) 
        main.StoreStrippedItems(stripped, forms)
    endif

    if success
        Actor listener = Stripped 
        if listener == Stripper 
            listener = None 
        endif 

        String msg = stripper.GetDisplayName()+" "+style+" "+how+"es "+stripped.GetDisplayName()+"."
        if narration == "direct"
            DirectNarration(msg, stripper, listener) 
        elseif narration == "silent"
            RegisterEvent(how,msg, stripper, listener) 
        endif 
    endif 
EndFunction
; -------------------------------------------------
; Tag 
; -------------------------------------------------

bool Function BodyAnimation_IsEligible(Actor akActor, string contextJson, string paramsJson)
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

    if StorageUtil.HasIntValue(akActor, "skyrimnet_sexlab_scene_actor_lock")
        Trace("BodyAnimation_IsEligible", akActor.GetDisplayName()+" is locked")
        return false 
    endif

    if main.sexLab.IsActorActive(akActor) 
        Trace("BodyAnimation_IsEligible", akActor.GetDisplayName()+" SexLab animation")
        return false 
    endif 

    if OstimActorCountFaction != None && akActor.IsInFaction(OStimActorCountFaction)
        Trace("BodyAnimation_IsEligible", akActor.GetDisplayName()+" OStim animation")
        return false 
    endif
    Trace("BodyAnimation_Tag", name+" is eligible for sex")
    return True
EndFunction
