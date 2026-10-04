Scriptname SkyrimNet_SexLab_Actions extends Quest

SkyrimNet_SexLab_Main Property main Auto 
SkyrimNet_SexLab_Scene_Manager Property manager Auto 
SexLabFramework Property sexlab Auto 

import SkyrimNet_SexLab_Utilities

Idle Property pa_HugA Auto  ; IDLE:000F4699

Faction OStimActorCountFaction = None 

Function Trace(String func, String msg, Bool notification=False) global
    String logged = SkyrimNet_SexLab_WebUI.TraceLog("SkyrimNet_SexLab_Actions", func, msg)
    if notification
        Debug.Notification(msg)
    endif 
EndFunction

; -------------------------------------------------
; Setup
; -------------------------------------------------
Function Setup()
    Bool links_ok = Setup_CheckLinks()
    if !links_ok
        return
    endif

    if Game.GetModByName("Ostim.esp") != 255
        OStimActorCountFaction = Game.GetFormFromFile(0xECA, "Ostim.esp") as Faction
        Trace("Setup","Found Ostim.esp, OStimActorCountFaction set to "+OStimActorCountFaction)
    else 
        OStimActorCountFaction = None 
    endif 
EndFunction 

Bool Function Setup_CheckLinks()
    Bool links_ok = true

    if main == None
        main = (self as Quest) as SkyrimNet_SexLab_Main
        if main == None
            links_ok = false
        endif
    endif

    if manager == None
        manager = (self as Quest) as SkyrimNet_SexLab_Scene_Manager
        if manager == None
            links_ok = false
        endif
    endif

    if sexlab == None
        links_ok = false
    endif

    return links_ok
EndFunction

;-------------------------------------------
; One
;-------------------------------------------

Bool Function StartScene_Consensual_One(String intent, Actor speaker, string style="", String method="", String setting_name="")
    Trace("StartScene_Consensual_One",intent+" "+speaker.GetDisplayName()+" style: "+style+" method: "+method)
    return StartScene_Event(intent, speaker, style=style, tags=method, setting_name=setting_name)
EndFunction

Bool Function StartScene_Nonconsensual_One(String intent, Actor speaker, string style="", String method="", String setting_name="")
    Trace("StartScene_Nonconsensual_One",intent+" "+speaker.GetDisplayName()+" style: "+style+" method: "+method)
    return StartScene_Event(intent, speaker, victim=speaker, style=style, tags=method, setting_name=setting_name)
EndFunction

;-------------------------------------------
; Two
;-------------------------------------------

Bool Function StartScene_Consensual_Two(String intent, Actor speaker, Actor target, string style="", string method="", String direction="", String setting_name="")
    Trace("StartScene_Consensual_Two","intent:"+intent+" speaker:"+speaker.GetDisplayName()+" + "+target.GetDisplayName()+" style: "+style+" direction: "+direction+" method:"+method+" setting_name:"+setting_name)
    return StartScene_Event(intent, speaker, target, None, style, method, direction, setting_name=setting_name)
EndFunction

Bool Function StartScene_Nonconsensual_Two(String intent, Actor speaker, Actor target=None, Actor victim,string style="", string method="", String direction="", String setting_name="")
    Trace("StartScene_Nonconsensual_Two",GetDisplayName(speaker)+" "+GetDisplayName(target)+" victim:"+GetDisplayName(victim)+" style: "+style+" method:"+method+" direction: "+direction+" setting_name:"+setting_name)
    return StartScene_Event(intent, speaker, target, victim, style, method, direction, setting_name=setting_name)
EndFunction

Bool Function StartScene_Nonconsensual_Two_SpeakerVictim(String intent, Actor speaker, Actor target, string style="", string method="", String direction="", String setting_name="")
    Trace("StartScene_Nonconsensual_Two_SpeakerVictim",GetDisplayName(speaker)+" "+GetDisplayName(target)+" style: "+style+" method:"+method+" direction: "+direction+" setting_name:"+setting_name)
    Actor victim = speaker
    return StartScene_Event(intent, speaker, target, victim, style, method, direction, setting_name=setting_name)
EndFunction
Bool Function StartScene_Nonconsensual_Two_TargetVictim(String intent, Actor speaker, Actor target, string style="", string method="", String direction="", String setting_name="")
    Trace("StartScene_Nonconsensual_Two_TargetVictim",GetDisplayName(speaker)+" "+GetDisplayName(target)+" style: "+style+" method:"+method+" direction: "+direction+" setting_name:"+setting_name)
    Actor victim = target
    return StartScene_Event(intent, speaker, target, victim, style, method, direction, setting_name=setting_name)
EndFunction

;-------------------------------------------
; Threesome
;-------------------------------------------

Bool Function StartScene_Consensual_Three(String intent, Actor speaker, Actor target, string style="", string method="", String direction="", String setting_name="", Actor participate)
    Int unique = 0
    if speaker != None
        unique += 1
    endif
    if target != None && target != speaker
        unique += 1
    endif
    if participate != None && participate != speaker && participate != target
        unique += 1
    endif

    if unique <= 1
        return StartScene_Consensual_One(intent, speaker, style, method, setting_name)
    elseif unique == 2
        Actor second = target
        if second == None || second == speaker
            second = participate
        endif
        return StartScene_Consensual_Two(intent, speaker, second, style, method, direction, setting_name)
    endif

    Trace("StartScene_Consensual_Three","intent:"+GetDisplayName(speaker)+" + "+GetDisplayName(target)+" style: "+style+" method: "+method+" direction: "+direction+" setting_name:"+setting_name+" participate:"+GetDisplayName(participate))
    return StartScene_Event(intent, speaker, target, None, style, method, direction, setting_name=setting_name, participate_3=participate)
EndFunction


Bool Function StartScene_Nonconsensual_Three(String intent, Actor speaker, Actor target, Actor victim, string style="", string method="", String direction="", String setting_name="", Actor participate)
    if victim == None || (victim != speaker && victim != target && victim != participate)
        return StartScene_Consensual_Three(intent, speaker, target, style, method, direction, setting_name, participate)
    endif

    Int unique = 0
    if speaker != None
        unique += 1
    endif
    if target != None && target != speaker
        unique += 1
    endif
    if participate != None && participate != speaker && participate != target
        unique += 1
    endif

    if unique <= 1
        return StartScene_Nonconsensual_One(intent, speaker, style, method, setting_name)
    elseif unique == 2
        Actor second = target
        if second == None || second == speaker
            second = participate
        endif
        return StartScene_Nonconsensual_Two(intent, speaker, second, victim, style, method, direction, setting_name)
    endif

    Trace("StartScene_Nonconsensual_Three","intent:"+GetDisplayName(speaker)+" + "+GetDisplayName(target)+" victim:"+GetDisplayName(victim)+" style: "+style+" method: "+method+" direction: "+direction+" setting_name:"+setting_name+" participate:"+GetDisplayName(participate))
    return StartScene_Event(intent, speaker, target, victim, style, method, direction, setting_name=setting_name, participate_3=participate)
EndFunction

;-------------------------------------------
; Scene Stop 
;-------------------------------------------

Function SceneStop(Actor speaker, String style)
    Trace("SceneStop",GetDisplayName(speaker)+" style: "+style)
    SceneStop_Event(speaker, speaker, style) 
EndFunction

Function SceneStop_Target(Actor speaker, Actor target, String style)
    Trace("SceneStop",GetDisplayName(speaker)+" + "+GetDisplayName(target)+" style: "+style)
    SceneStop_Event(speaker, target, style) 
EndFunction

;-------------------------------------------
; Scene Change Style (speed follows style)
;-------------------------------------------

Function SceneChangeStyle(Actor speaker, String style)
    Trace("SceneChangeStyle",GetDisplayName(speaker)+" style: "+style)
    int handle = ModEvent.Create("SkyrimNet_SexLab_Action_Style")
    ModEvent.PushForm(handle, speaker)
    ModEvent.PushString(handle, style)
    ModEvent.Send(handle)
EndFunction

;------------------------------------------------------------------------------
; Refused
;------------------------------------------------------------------------------

Function StartScene_Refused_Two(String intent, Actor speaker, Actor target, string style="", string method="", string direction="")
    String speaker_name = GetDisplayName(speaker)
    String target_name = GetDisplayName(target)
    Trace("StartScene_Refused_Two","intent: "+intent+" "+speaker_name+" + "+target_name+" style: "+style+" direction: "+direction+" method: "+method)
    if style == "normal" || style == "normally"
        style = "" 
    endif 
    String msg = target_name+" "+style+" refused to allow "+intent+" by "
    if direction == "" || direction == "getting" 
        msg += direction+" "+method+" from "+speaker.GetDisplayName() 
    else 
        msg += direction+" "+method+" to "+speaker.GetDisplayName() 
    endif 
    DirectNarration(msg, target, speaker) 
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

; tags: CSV SexLab tags. Empty skips AnimDB. Non-empty resolve fail -> False (no event).
Bool Function StartScene_Event(String intent, Actor speaker, Actor target=None, Actor victim=None, \
     string style="", string tags="", String direction="", String event_hook="", String setting_name="",\
     Actor participate_3=None)

    if target == None && participate_3 != None 
        target = participate_3 
        participate_3 = None 
    endif 

    String speaker_name = GetDisplayName(speaker)
    String target_name = GetDisplayName(target) 
    String victim_name = GetDisplayName(victim) 
    String participate_3_name = GetDisplayName(participate_3)

    int actor_count = 1
    if target != None
        actor_count += 1
        if participate_3 != None
            actor_count += 1
        endif
    endif

    String resolved = tags
    if tags != ""
        resolved = SkyrimNet_SexLab_AnimDb.AnimDb_ResolveTags(tags, actor_count)
        if resolved == ""
            Trace("StartScene_Event", "AnimDB ResolveTags empty for tags='"+tags+"' actors="+actor_count)
            return False
        endif
    endif

    ; Lone hug -> idle
    if resolved == "hug" && target != None && pa_HugA != None
        ; Paired idle with a drawn weapon desyncs the player's graph (can't attack after).
        Bool sheathed = CalmForPairedIdle(speaker)
        sheathed = CalmForPairedIdle(target) || sheathed
        if sheathed
            int waits = 0
            while waits < 15 && (speaker.IsWeaponDrawn() || target.IsWeaponDrawn())
                Utility.Wait(0.1)
                waits += 1
            endwhile
        endif
        Trace("StartScene_Event", "lone hug pa_HugA target="+target_name+" speaker="+speaker_name+" sheathed="+sheathed)
        target.playIdleWithTarget(pa_HugA, speaker)
        Actor sender = speaker
        Actor receiver = target
        if direction == "get" || direction == "getting"
            sender = target
            receiver = speaker
        endif
        String msg = sender.GetDisplayName()+" hugs "+receiver.GetDisplayName()+"."
        DirectNarration(msg, speaker, target)
        return True
    endif

    int speaker_position = 0 
    if target != None 
        if victim != None && victim == speaker
            speaker_position = 0
        elseif victim != None && victim == target
            speaker_position = 1
        else
            if direction == "fucking" || direction == "fuck a" || direction == "fucking a"
                speaker_position = 1
            elseif direction == "fucked in"
                speaker_position = 0
            elseif IsHugGiverPose(intent, tags) || IsHugGiverPose(intent, resolved)
                ; Hug/cuddle/kiss: giver is SexLab pos1 (unlike oral, where giver is pos0).
                if direction == "getting" || direction == "get"
                    speaker_position = 0
                elseif direction == "giving" || direction == "give"
                    speaker_position = 1
                endif
            elseif direction == "getting" || direction == "get"
                speaker_position = 1
            elseif direction == "giving" || direction == "give"
                speaker_position = 0
            endif
        endif
    endif 

    String event_name = "SkyrimNet_SexLab_Action_Start"
    Trace("StartScene_Event","event_name:"+event_name+" intent:"+intent+" speaker:"+speaker_name+" target:"+target_name+" victim:"+victim_name\
        +" style:"+style+" speaker_position:"+speaker_position+" tags:"+resolved+" event_hook:"+event_hook+" setting_name:"+setting_name\
        +" participate_3_name:"+participate_3_name)

    int handle = ModEvent.Create(event_name)
    ModEvent.PushString(handle, intent)
    ModEvent.PushForm(handle, speaker)
    ModEvent.PushForm(handle, target)
    ModEvent.PushForm(handle, victim)
    ModEvent.PushString(handle, style)
    ModEvent.PushString(handle, resolved)
    ModEvent.PushInt(handle, speaker_position)
    ModEvent.PushString(handle, event_hook)
    ModEvent.PushString(handle, setting_name)
    ModEvent.PushForm(handle, participate_3)
    ModEvent.Send(handle)
    return True
EndFunction 

; Hug/cuddle/kiss giver @ SexLab pos1. Matches YAML long intents, SceneStartPanel short
; labels (show affection / comfort), and method tags even when intent is unrelated.
Bool Function IsHugGiverPose(String intent, String tags)
    if intent == "cuddling" || intent == "showing affection" || intent == "comforting"
        return True
    endif
    if intent == "show affection" || intent == "comfort"
        return True
    endif
    if SkyrimNet_SexLab_AnimDb.AnimDb_CsvHasTag(tags, "cuddling")
        return True
    endif
    if SkyrimNet_SexLab_AnimDb.AnimDb_CsvHasTag(tags, "kissing")
        return True
    endif
    if SkyrimNet_SexLab_AnimDb.AnimDb_CsvHasTag(tags, "hug")
        return True
    endif
    return False
EndFunction

; Mirrors DOM_Util.CalmActorFast. Returns True if a weapon sheathe was requested.
Bool Function CalmForPairedIdle(Actor akActor)
    if akActor == None
        return False
    endif
    akActor.StopCombatAlarm()
    if akActor.IsInCombat()
        akActor.StopCombat()
    endif
    if akActor.IsWeaponDrawn()
        akActor.SheatheWeapon()
        return True
    endif
    return False
EndFunction

;--------------------------------------
; Functions
;--------------------------------------



; -------------------------------------------------
; Dress and Undress
; Speaker = who performs (stripper); Target = whose outfit changes (stripped).
; Narration: direct, silent (RegisterEvent), none
; -------------------------------------------------
Function Outfit_Narrate(Actor Speaker, Actor Target, String style, String token, String narration)
    ; style silently|silent → no DirectNarration and no RegisterEvent.
    if style == "silently" || style == "silent"
        return
    endif
    Actor listener = Target
    if listener == Speaker
        listener = None
    endif
    String msg = Speaker.GetDisplayName()+" "+style+" "+token+"es "+Target.GetDisplayName()+"."
    if narration == "direct"
        DirectNarration(msg, Speaker, listener)
    elseif narration == "silent"
        RegisterEvent(token, msg, Speaker, listener)
    endif
EndFunction

; Refresh WebUI catalog if the target menu is open on this actor.
Function Outfit_RefreshWebUI(Actor Target)
    if Target == None
        return
    endif
    SkyrimNet_SexLab_WebUI.Target_Menu_Refresh(main.HasStrippedItems(Target))
EndFunction

Function Outfit_Dress(Actor Speaker, Actor Target, String style, String narration)
    Trace("Outfit_Dress", Speaker.GetDisplayName()+" speaker "+Target.GetDisplayName()+" style:"+style+" narration:"+narration)
    Form[] forms = main.UnStoreStrippedItems(Target)
    if forms.length > 0
        sexlab.UnStripActor(Target, forms, false)
        Outfit_Narrate(Speaker, Target, style, "dress", narration)
        Outfit_RefreshWebUI(Target)
    else
        Trace("Outfit_Dress", Target.GetDisplayName()+" has no stripped items")
    endif
EndFunction

Function Outfit_Undress(Actor Speaker, Actor Target, String style, String narration)
    Trace("Outfit_Undress", Speaker.GetDisplayName()+" speaker "+Target.GetDisplayName()+" style:"+style+" narration:"+narration)
    ;/* StripActor — SexLab MCM strip settings; VictimRef selects victim vs aggressor strip.
     * DoAnimate default true; LeadIn false here.
     */;
    Actor victim = None
    Bool do_animate = True
    if Speaker != Target
        victim = Target
        do_animate = False
    endif
    Form[] forms = sexlab.StripActor(Target, victim, do_animate, false)
    if forms && forms.length > 0
        main.StoreStrippedItems(Target, forms)
        Outfit_Narrate(Speaker, Target, style, "undress", narration)
        Outfit_RefreshWebUI(Target)
    else
        Trace("Outfit_Undress", Target.GetDisplayName()+" strip returned no items")
    endif
EndFunction

; -------------------------------------------------
; IsEligible
; -------------------------------------------------

bool Function BodyAnimation_IsEligible(Actor akActor, string contextJson, string paramsJson)
    if akActor == None 
        Trace("BodyAnimation_IsEligible","akActor is None")
        return false
    endif

    String name = akActor.GetDisplayName()
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

; -------------------------------------------------
; TargetMenu Papyrus APIs (type: papyrus — no SkyrimNet YAML)
; -------------------------------------------------

Function TM_Outfit(Actor speaker, Actor target, String style)
    Trace("TM_Outfit", GetDisplayName(speaker)+" -> "+GetDisplayName(target)+" style:"+style)
    if speaker == None || target == None
        return
    endif
    String narration = "silent"
    if style == "silently" || style == "silent"
        narration = "none"
    endif
    if main.HasStrippedItems(target)
        Outfit_Dress(speaker, target, style, narration)
    else
        Outfit_Undress(speaker, target, style, narration)
    endif
EndFunction

; TargetMenu/Scene dress|undress: target is in a SexLab thread, so strip/unstrip through the
; thread's sslActorAlias (scene end re-dresses them), not main.Store/UnStoreStrippedItems.
Function TM_SceneOutfit(Actor speaker, Actor target, String style, String how)
    Trace("TM_SceneOutfit", GetDisplayName(speaker)+" -> "+GetDisplayName(target)+" style:"+style+" how:"+how)
    if speaker == None || target == None
        return
    endif
    String narration = "silent"
    if style == "silently" || style == "silent"
        narration = "none"
    endif
    Bool clothed = how == "dress"
    SkyrimNet_SexLab_Scene sl = manager.GetSceneByActor(target)
    if sl == None
        if clothed
            Outfit_Dress(speaker, target, style, narration)
        else
            Outfit_Undress(speaker, target, style, narration)
        endif
        return
    endif
    ; Strip state only -- no TM_ApplyClothed, so position JSON / AnimDB defaults are untouched.
    sl.ApplyDressedToActor(target, clothed)
    Outfit_Narrate(speaker, target, style, how, narration)
EndFunction

Function TM_StopSilent(Actor speaker, Actor target)
    Trace("TM_StopSilent", GetDisplayName(speaker)+" -> "+GetDisplayName(target))
    SceneStop_Target(speaker, target, "silent")
EndFunction

Function TM_Stop(Actor speaker, Actor target)
    Trace("TM_Stop", GetDisplayName(speaker)+" -> "+GetDisplayName(target))
    SceneStop_Target(speaker, target, "stop")
EndFunction

Function TM_StopExplain(Actor speaker, Actor target, String narration)
    Trace("TM_StopExplain", GetDisplayName(speaker)+" -> "+GetDisplayName(target)+" msg:"+narration)
    SceneStop_Target(speaker, target, "explain:"+narration)
EndFunction

Function TM_StagePrev(Actor speaker, Actor target)
    Trace("TM_StagePrev", GetDisplayName(target))
    SkyrimNet_SexLab_Scene sl = manager.GetSceneByActor(target)
    if sl == None
        return
    endif
    sslThreadController th = sl.GetThread()
    if th == None
        return
    endif
    int stage = th.stage
    if stage > 1
        th.GoToStage(stage - 1)
    endif
EndFunction

Function TM_StageNext(Actor speaker, Actor target)
    Trace("TM_StageNext", GetDisplayName(target))
    SkyrimNet_SexLab_Scene sl = manager.GetSceneByActor(target)
    if sl == None
        return
    endif
    sslThreadController th = sl.GetThread()
    if th == None || th.animation == None
        return
    endif
    int stage = th.stage
    int maxStage = th.animation.StageCount()
    if stage < maxStage
        th.GoToStage(stage + 1)
    endif
EndFunction

Function TM_GoToStage(Actor speaker, Actor target, String stageStr)
    Trace("TM_GoToStage", GetDisplayName(target)+" stage:"+stageStr)
    SkyrimNet_SexLab_Scene sl = manager.GetSceneByActor(target)
    if sl == None
        return
    endif
    sslThreadController th = sl.GetThread()
    if th == None || th.animation == None
        return
    endif
    int stage = stageStr as int
    int maxStage = th.animation.StageCount()
    if stage < 1 || stage > maxStage
        Trace("TM_GoToStage", "bad stage "+stageStr)
        return
    endif
    th.GoToStage(stage)
    SkyrimNet_SexLab_WebUI.SceneCreator_Configure(sl.BuildWebUISceneMenuState())
    SkyrimNet_SexLab_WebUI.Animation_Menu_Configure(sl.BuildWebUIAnimationMenuState())
EndFunction

Function TM_SetStageDescription(Actor speaker, Actor target, String stageStr, String description)
    Trace("TM_SetStageDescription", GetDisplayName(target)+" stage:"+stageStr)
    SkyrimNet_SexLab_Scene sl = manager.GetSceneByActor(target)
    if sl == None
        return
    endif
    sl.TM_SetStageDescription(stageStr, description)
EndFunction

Function TM_RotatePositions(Actor speaker, Actor target)
    Trace("TM_RotatePositions", GetDisplayName(target))
    SkyrimNet_SexLab_Scene sl = manager.GetSceneByActor(target)
    if sl == None
        return
    endif
    sslThreadController th = sl.GetThread()
    if th == None
        return
    endif
    th.ChangePositions(false)
EndFunction

Function TM_ChangeActors(Actor speaker, Actor target, String formIdsCsv)
    Trace("TM_ChangeActors", GetDisplayName(target)+" formIds:"+formIdsCsv)
    SkyrimNet_SexLab_Scene sl = manager.GetSceneByActor(target)
    if sl == None
        return
    endif
    sslThreadController th = sl.GetThread()
    if th == None
        return
    endif
    String[] parts = StringUtil.Split(formIdsCsv, ",")
    int n = parts.length
    if n < 1 || n > 5
        Trace("TM_ChangeActors", "invalid count "+n)
        return
    endif
    Actor[] next = PapyrusUtil.ActorArray(n)
    int i = 0
    int valid = 0
    while i < n
        int fid = parts[i] as int
        Actor a = None
        if fid != 0
            a = Game.GetFormEx(fid) as Actor
        endif
        if a != None
            next[valid] = a
            valid += 1
        endif
        i += 1
    endwhile
    if valid < 1
        return
    endif
    if valid != n
        Actor[] trimmed = PapyrusUtil.ActorArray(valid)
        i = 0
        while i < valid
            trimmed[i] = next[i]
            i += 1
        endwhile
        next = trimmed
    endif
    th.ChangeActors(next)
    SkyrimNet_SexLab_WebUI.SceneCreator_Configure(sl.BuildWebUISceneMenuState())
    SkyrimNet_SexLab_WebUI.Animation_Menu_Configure(sl.BuildWebUIAnimationMenuState())
EndFunction

Function TM_SetAnimationIndex(Actor speaker, Actor target, String indexStr)
    Trace("TM_SetAnimationIndex", GetDisplayName(target)+" idx:"+indexStr)
    SkyrimNet_SexLab_Scene sl = manager.GetSceneByActor(target)
    if sl == None
        return
    endif
    sslThreadController th = sl.GetThread()
    if th == None
        return
    endif
    int idx = indexStr as int
    sslBaseAnimation[] anims = th.Animations
    if anims == None || idx < 0 || idx >= anims.length
        Trace("TM_SetAnimationIndex", "bad index")
        return
    endif
    th.SetAnimation(idx)
    sl.CheckAnimationChange()
    SkyrimNet_SexLab_WebUI.SceneCreator_Configure(sl.BuildWebUISceneMenuState())
    SkyrimNet_SexLab_WebUI.Animation_Menu_Configure(sl.BuildWebUIAnimationMenuState())
EndFunction

Function TM_SyncSceneState(Actor speaker, Actor target)
    Trace("TM_SyncSceneState", GetDisplayName(target))
    SkyrimNet_SexLab_Scene sl = manager.GetSceneByActor(target)
    if sl == None
        return
    endif
    SkyrimNet_SexLab_WebUI.SceneCreator_Configure(sl.BuildWebUISceneMenuState())
EndFunction

Function TM_SetVictim(Actor speaker, Actor target, String formIdStr, String isVictimStr)
    Trace("TM_SetVictim", GetDisplayName(target)+" form:"+formIdStr+" victim:"+isVictimStr)
    SkyrimNet_SexLab_Scene sl = manager.GetSceneByActor(target)
    if sl == None
        return
    endif
    Actor a = Game.GetFormEx(formIdStr as int) as Actor
    if a == None
        return
    endif
    Bool isVictim = (isVictimStr == "1" || isVictimStr == "true")
    ; Through the Scene so victim factions, victim/assailant flags and names follow the toggle.
    sl.TM_ApplyVictim(a, isVictim)
EndFunction

Function TM_SetOrgasmMode(Actor speaker, Actor target, String formIdStr, String mode)
    Trace("TM_SetOrgasmMode", GetDisplayName(target)+" form:"+formIdStr+" mode:"+mode)
    SkyrimNet_SexLab_Scene sl = manager.GetSceneByActor(target)
    if sl == None
        return
    endif
    Actor a = Game.GetFormEx(formIdStr as int) as Actor
    if a == None
        return
    endif
    sl.TM_ApplyOrgasmMode(a, mode)
EndFunction

Function TM_ForceOrgasm(Actor speaker, Actor target, String formIdStr)
    Trace("TM_ForceOrgasm", GetDisplayName(target)+" form:"+formIdStr)
    SkyrimNet_SexLab_Scene sl = manager.GetSceneByActor(target)
    if sl == None
        return
    endif
    sslThreadController th = sl.GetThread()
    if th == None
        return
    endif
    Actor a = Game.GetFormEx(formIdStr as int) as Actor
    if a == None
        return
    endif
    ; WebUI is all-powerful: forced engine request (skips every gate, narrates once).
    if SkyrimNet_SexLab_OrgasmEngine.IsManaged(a)
        SkyrimNet_SexLab_OrgasmEngine.RequestOrgasm(a, true, "webui")
        return
    endif
    th.ForceOrgasm(a)
EndFunction

;-------------------------------------------
; Orgasm mini-game (LLM actions): same engine code as the HUD keys, stronger (llm_multiplier)
;-------------------------------------------

Function MiniGame_Arouse(Actor speaker, Actor target)
    MiniGame_Act(speaker, target, true)
EndFunction

Function MiniGame_Calm(Actor speaker, Actor target)
    MiniGame_Act(speaker, target, false)
EndFunction

Function MiniGame_Act(Actor speaker, Actor target, bool arouse)
    if target == None
        target = speaker
    endif
    if speaker == None
        return
    endif
    SkyrimNet_SexLab_Scene sl = manager.GetSceneByActor(speaker)
    if sl == None || sl.GetThread() == None || sl.GetThread().Positions.Find(target) < 0
        Trace("MiniGame_Act", GetDisplayName(target)+" is not in "+GetDisplayName(speaker)+"'s scene")
        return
    endif
    float mult = SkyrimNetApi.GetConfigFloat("Plugin_SkyrimNet_SexLab", "sexlab.minigame.llm_multiplier", 3.0)
    bool ok
    if arouse
        ok = SkyrimNet_SexLab_OrgasmEngine.Arouse(speaker, target, mult)
    else
        ok = SkyrimNet_SexLab_OrgasmEngine.Calm(speaker, target, mult)
    endif
    Trace("MiniGame_Act", GetDisplayName(speaker)+" "+arouse+" "+GetDisplayName(target)+" mult:"+mult+" ok:"+ok)
EndFunction

;-------------------------------------------
; Orgasm denial (LLM actions): only the aggressor denies / allows the victim
;-------------------------------------------

Function LLM_DenyOrgasm(Actor speaker, Actor target)
    LLM_SetDenyOrgasm(speaker, target, true)
EndFunction

Function LLM_AllowOrgasm(Actor speaker, Actor target)
    LLM_SetDenyOrgasm(speaker, target, false)
EndFunction

; Same scene, speaker not a victim, target a victim, target not the player (the player's own deny
; stays with the player). Allow checks every actor and narrates the orgasm with the allow prefix.
Function LLM_SetDenyOrgasm(Actor speaker, Actor target, bool deny)
    if speaker == None || target == None || speaker == target
        Trace("LLM_SetDenyOrgasm", "needs a speaker and a different target")
        return
    endif
    if target == Game.GetPlayer()
        Trace("LLM_SetDenyOrgasm", GetDisplayName(speaker)+" cannot deny / allow the player")
        return
    endif
    SkyrimNet_SexLab_Scene sl = manager.GetSceneByActor(speaker)
    sslThreadController thread = None
    if sl != None
        thread = sl.GetThread()
    endif
    if thread == None || thread.Positions.Find(target) < 0
        Trace("LLM_SetDenyOrgasm", GetDisplayName(target)+" is not in "+GetDisplayName(speaker)+"'s scene")
        return
    endif
    if thread.IsVictim(speaker) || !thread.IsVictim(target)
        Trace("LLM_SetDenyOrgasm", GetDisplayName(speaker)+" is not the aggressor of "+GetDisplayName(target))
        return
    endif
    bool changed = sl.SetDenyOrgasm(target, deny, speaker, true)
    Trace("LLM_SetDenyOrgasm", GetDisplayName(speaker)+" deny:"+deny+" "+GetDisplayName(target)+" changed:"+changed)
EndFunction

Function TM_SetSpeaking(Actor speaker, Actor target, String formIdStr, String speaking)
    Trace("TM_SetSpeaking", GetDisplayName(target)+" form:"+formIdStr+" speaking:"+speaking)
    SkyrimNet_SexLab_Scene sl = manager.GetSceneByActor(target)
    if sl == None
        return
    endif
    Actor a = Game.GetFormEx(formIdStr as int) as Actor
    if a == None
        return
    endif
    sl.TM_ApplySpeaking(a, speaking)
EndFunction

Function TM_SetClothed(Actor speaker, Actor target, String formIdStr, String clothedStr)
    Trace("TM_SetClothed", GetDisplayName(target)+" form:"+formIdStr+" clothed:"+clothedStr)
    Actor a = Game.GetFormEx(formIdStr as int) as Actor
    if a == None
        return
    endif
    Bool clothed = (clothedStr == "1" || clothedStr == "true")
    ; Live scene actor: SexLab's own strip state (sslActorAlias.Strip/UnStrip), so the scene end
    ; re-dresses them. Outfit_Dress/Undress is the out-of-scene API (KNOWLEDGEBASE "Description
    ; Editor dressed toggle used wrong strip API").
    SkyrimNet_SexLab_Scene sl = manager.GetSceneByActor(a)
    if sl != None
        sl.ApplyDressedToActor(a, clothed)
        sl.TM_ApplyClothed(a, clothed)
    elseif clothed
        Outfit_Dress(speaker, a, "silently", "silent")
    else
        Outfit_Undress(speaker, a, "silently", "silent")
    endif
EndFunction

Function TM_SaveAnimationSettings(Actor speaker, Actor target)
    Trace("TM_SaveAnimationSettings", GetDisplayName(target))
    SkyrimNet_SexLab_Scene sl = manager.GetSceneByActor(target)
    if sl == None
        return
    endif
    sl.TM_SaveAnimationSettings()
EndFunction
