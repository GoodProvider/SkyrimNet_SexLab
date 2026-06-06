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

    if main.IsActorLocked(akActor)
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

;--------------------------------------------------------------------------------------
; Scene Start
;--------------------------------------------------------------------------------------

;-------------------------------------------
; One
;-------------------------------------------

Function SceneStart_Consensual_One(Actor Speaker, string style, String tag)
    Trace("SceneStart_Consensual_One",Speaker.GetDisplayName()+" style: "+style+" tag: "+tag)
    SceneStart_Event_Tag(speaker, None, None, None, None, style, "", tag) 
EndFunction

;-------------------------------------------
; Two
;-------------------------------------------

Function SceneStart_Consensual_Two(Actor Speaker, Actor Target, string style, string direction, string tag)
    Trace("SceneStart_Consensual",Speaker.GetDisplayName()+" + "+Target.GetDisplayName()+" style: "+style+" direction: "+direction+" type: "+tag)
    SceneStart_Event_Tag(speaker, target, None, None, style, direction, tag) 
EndFunction

Function SceneStart_RapeTarget_Two(Actor Speaker, Actor Target, string style, String direction, string tag)
    Trace("SceneStart_RapeTarget",Speaker.GetDisplayName()+" + "+Target.GetDisplayName()+" style: "+style+" direction: "+direction+" type: "+tag)
    SceneStart_Event_Tag("tag", speaker, target, None, target, style, direction, tag) 
EndFunction

Function SceneStart_RapebyTarget_Two(Actor Speaker, Actor Target, string style, String direction, string tag)
    Trace("SceneStart_RapebyTarget",Speaker.GetDisplayName()+" + "+Target.GetDisplayName()+" style: "+style+" direction: "+direction+" type: "+tag)
    SceneStart_Event_Tag(speaker, target, None, speaker, style, direction, tag) 
EndFunction

;-------------------------------------------
; Threesome
;-------------------------------------------

Function SceneStart_Consensual_Three(Actor Speaker, Actor Target, string style, String direction, string tag, Actor participate)
    Trace("SceneStart_Consensual_Three",Speaker.GetDisplayName()+" + "+Target.GetDisplayName()+" style: "+style+" direction: "+direction+" type: "+tag+" participate:"+participate.GetDisplayName())
    SceneStart_Event_Tag(speaker, target, None, style, direction, tag, participate_3=participate) 
EndFunction

Function SceneStart_RapeTarget_Three(Actor Speaker, Actor Target, string style, String direction, string tag, Actor participate)
    Trace("SceneStart_RapeTarget_Three",Speaker.GetDisplayName()+" + "+Target.GetDisplayName()+" style: "+style+" direction: "+direction+" type: "+tag+" participate:"+participate.GetDisplayName())
    SceneStart_Event_Tag(speaker, target, target, style, direction, tag, participate_3=participate) 
EndFunction

Function SceneStart_RapeByTarget_Three(Actor Speaker, Actor Target, string style, String direction, string tag, Actor participate)
    Trace("SceneStart_RapeByTarget_Three",Speaker.GetDisplayName()+" + "+Target.GetDisplayName()+" style: "+style+" direction: "+direction+" type: "+tag+" participate:"+participate.GetDisplayName())
    SceneStart_Event_Tag(speaker, target, participate, speaker, style, direction, tag, participate_3=participate) 
EndFunction

;------------------------------------------------------------------------------
; Events 
;------------------------------------------------------------------------------

Function SceneStop_Event(Actor akActor) 
    int handle = ModEvent.Create("SkyrimNet_SexLab_Action_Stop")
    ModEvent.PushForm(handle, akActor)
    ModEvent.Send(handle)
EndFunction 

;--------------------------------------
; Two actors 
;--------------------------------------
Function Function SceneStart_Event(Actor Speaker, Actor Target, Actor Victim,\
     string style="", string direction="", string tag="", string scene_settings="", String Hook="",\
     Actor participate_3=None)
    int handle = ModEvent.Create("SkyrimNet_SexLab_Action_Start")
    ModEvent.PushForm(handle, speaker)
    ModEvent.PushForm(handle, target)
    ModEvent.PushForm(handle, victim)
    ModEvent.PushString(handle, style)
    ModEvent.PushString(handle, direction)
    ModEvent.PushString(handle, tag)
    ModEvent.PushString(handle, scene_settings)
    ModEvent.PushString(handle, hook)
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
Function Change_Outfit(Actor Stripper, Actor Stripped, String Style, String how, String Narration)
    Trace("Change_Outfit",Stripper.GetDisplayName()+" stripper "+Stripped.GetDisplayName()+" style:"+style+" how: "+how+" narration:"+narration)

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
        main.StoreStrippedItems(Stripped, forms)
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