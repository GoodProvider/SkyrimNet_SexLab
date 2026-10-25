Scriptname SkyrimNet_SexLab_Handler_DOM extends SkyrimNet_SexLab_Handler_DOM_Interface 

SkyrimNet_SexLab_Scene_Manager manager 

import SkyrimNet_SexLab_Utilities

String storage_actor_orgasm_total_key = "skyrimnet_sexlab_domactor_orgasm_total"
String storage_actor_orgasm_message_key = "skyrimnet_sexlab_domactor_orgasm_message"
String storage_behaviour_key = "skyrimnet_sexlab_dom_behaviour"



int actors_obj = 0


Function Trace(String func, String msg, Bool notification=False)
    String logged = SkyrimNet_SexLab_WebUI.TraceLog("SkyrimNet_SexLab_Handler_DOM", func, msg)
    if notification
        Debug.Notification(msg)
    endif 
EndFunction



bool Function Setup()
    Bool links_ok = Setup_CheckLinks()
    if !links_ok
        return False
    endif

    SkyrimNet_SexLab_Main main = Game.GetFormFromFile(0x000800, "SkyrimNet_SexLab.esp") as SkyrimNet_SexLab_Main
    main.handler_dom = self

    Trace("Setup", "Success")

    if actors_obj == 0 
        actors_obj = JArray.object()
        Jvalue.retain(actors_obj)
    endif

    UnRegisterForModEvent("DOMOnBehaviourChange")
    RegisterForModEvent("DOMOnBehaviourChange", "OnBehaviourChange")
    Trace("Setup", "--- registered DOMOnBehaviourChange")

    return True 
endFunction

Bool Function Setup_CheckLinks()
    Bool links_ok = true

    manager = Game.GetFormFromFile(0x000800, "SkyrimNet_SexLab.esp") as SkyrimNet_SexLab_Scene_Manager
    if manager == None 
        links_ok = false
    endif 

    ; Light Dom presence check (call sites use SkyrimNet_DOM_API, not a local Actions property)
    if Game.GetModByName("SkyrimNet_DOM.esp") == 255
        links_ok = false
    endif

    SkyrimNet_SexLab_Main main = Game.GetFormFromFile(0x000800, "SkyrimNet_SexLab.esp") as SkyrimNet_SexLab_Main
    if main == None
        links_ok = false
    endif

    return links_ok
EndFunction



; Checks if the actor is a dom slave 

Bool Function IsDOMSlave(Actor akActor)

    if akActor == None

        return false

    endif

    return SkyrimNet_DOM_API.IsDOMSlave(akActor)

EndFunction

Function SeedPunishReasons(Actor akActor)
    if akActor == None
        return
    endif
    SkyrimNet_DOM_API.PanelPunishReasons(akActor)
EndFunction



String Function HandleOrgasmDenied(Actor akActor)

    DOM_Actor slave = SkyrimNet_DOM_API.GetSlave("SkyrimNet_SexLab_Handler_DOM", "HandleOrgasmDenied", akActor) as Dom_Actor

    if slave != None && slave.mind != None 


        if slave.mind.arousal_factor > 120
            return akActor.GetDisplayName()+"'s body and mind scream for release, but was denied an orgasm. "
        elseif slave.mind.arousal_factor > 99
            return akActor.GetDisplayName()+"'s body hungers release, but was denied an orgasm. "
        elseif slave.mind.arousal_factor > 80
            return akActor.GetDisplayName()+"'s body yearns for release, but was denied an orgasm. "
        elseif slave.mind.arousal_factor > 50
            return akActor.GetDisplayName()+" is aroused, but did not orgasm. "
        else 
            return akActor.GetDisplayName()+" did not orgasm. "
        endif 

    endif 

    return ""

EndFunction


Function DOMSlave_Orgasmed(Actor slave, String msg)
    if slave == None 
        Trace("DOMSlave_Orgasmed","slave is None, aborting")
        return
    endif
    ; Player-climax tease from DOM_Mind — not a slave orgasm. Do not OrgasmCustom / DN.
    if StringUtil.Find(msg, "squirms under your grasp") >= 0 || StringUtil.Find(msg, "your orgasm submerges you") >= 0
        Trace("DOMSlave_Orgasmed", "--- skip player-orgasm tease for "+GetDisplayName(slave)+": "+msg)
        return
    endif
    if manager == None 
        Trace("DOMSlave_Orgasmed","--- manager is None, aborting")
        return
    elseif !manager.sexlab.IsActorActive(slave) || manager.GetSceneByActor(slave) == None
        ; Scene unreachable (e.g. just after a load): the delayed fallback narrates directly and
        ; would bypass Scene.OrgasmCustom's no_orgasm gate, so check the persisted flag here.
        if manager.IsNoOrgasmPersisted(slave)
            Trace("DOMSlave_Orgasmed", "--- "+GetDisplayName(slave)+" has no_orgasm, dropping delayed melt")
            return
        endif
        DelayMeltNarration(slave, msg)
    else
        ; OrgasmEngine: count, cooldown, HUD flash, SkyrimNet_SexLab_Orgasm event. DOM's text still narrates.
        if SkyrimNet_SexLab_OrgasmEngine.IsManaged(slave)
            SkyrimNet_SexLab_OrgasmEngine.NoteExternalOrgasm(slave, "dom")
        endif
        Trace("DOMSlave_Orgasmed", "--- OrgasmCustom for "+GetDisplayName(slave)+": "+msg)
        manager.OrgasmCustom(slave, msg)
    endif
EndFunction

Function DelayMeltNarration(Actor slave, String msg)
    ; Store the raw melt text. OnUpdate retries OrgasmCustom (Manager adds the
    ; gate); only the unreachable-scene fallback appends " is orgasming." here.
    Trace("DOMSlave_Orgasmed", "--- delayed melt DN for "+GetDisplayName(slave))
    int total = StorageUtil.GetIntValue(slave, storage_actor_orgasm_total_key, 0)
    if total == 0 
        StorageUtil.SetIntValue(slave, storage_actor_orgasm_total_key, 1)
        StorageUtil.SetStringValue(slave, storage_actor_orgasm_message_key, msg)
        JArray.addForm(actors_obj, slave)
    else
        total += 1
        StorageUtil.SetIntValue(slave, storage_actor_orgasm_total_key, total)
    endif
    RegisterForSingleUpdate(1.0)
EndFunction

Event OnUpdate() 
    Form[] objs = JArray.asFormArray(actors_obj)
    int i = 0 
    int count = objs.Length
    String narration = ""
    Actor sender = None 
    Actor receiver = None 
    while i < count
        Actor slave = objs[i] as Actor
        int total = StorageUtil.GetIntValue(slave, storage_actor_orgasm_total_key, 0)
        String msg = StorageUtil.GetStringValue(slave, storage_actor_orgasm_message_key, "")
        StorageUtil.UnsetIntValue(slave, storage_actor_orgasm_total_key)
        StorageUtil.UnsetStringValue(slave, storage_actor_orgasm_message_key)

        ; Prefer rejoining the SexLab scene so totals / Combined window stay in sync.
        if slave != None && manager != None && manager.sexlab.IsActorActive(slave) && manager.GetSceneByActor(slave) != None
            Trace("OnUpdate", "--- retry OrgasmCustom for "+GetDisplayName(slave))
            manager.OrgasmCustom(slave, msg)
        else
            if sender == None 
                sender = slave
            elseif receiver == None 
                receiver = slave
            endif
            if total > 0 
                msg += " "+GetDisplayName(slave)+" is orgasming. "
                if total > 1 
                    msg += total+" times, over and over again." 
                endif 
            endif
            narration += msg+". "
        endif
        i += 1 
    endwhile 
    JArray.clear(actors_obj)
    if narration != "" 
        DirectNarration(narration, sender, receiver, purge_dialogue=true)
    endif
EndEvent


Bool Function Orgasm_Desired(Actor akActor)

    DOM_Actor slave = SkyrimNet_DOM_API.GetSlave("SkyrimNet_SexLab_Handler_DOM", "Orgasm_Desired", akActor) as Dom_Actor

    return slave != None && slave.mind != None && slave.mind.is_aroused_for > 0

EndFunction


; ------------------------------------------------------------
; OrgasmEngine DOM support. The engine raises DOM's arousal instead of enjoyment; the HUD
; meter is computed from the values DOM_Mind.IsOrgasmingAfterArousal uses; DOM rolls and decides.
; ------------------------------------------------------------

DOM_Mind Function GetMind(Actor akActor, String func)
    if akActor == None
        return None
    endif
    DOM_Actor slave = SkyrimNet_DOM_API.GetSlave("SkyrimNet_SexLab_Handler_DOM", func, akActor) as DOM_Actor
    if slave == None
        return None
    endif
    return slave.mind
EndFunction

Function AddArousal(Actor akActor, float delta)
    DOM_Mind mind = GetMind(akActor, "AddArousal")
    if mind == None || delta == 0.0
        return
    endif
    if delta > 0.0
        ; An aroused slave first tops up is_aroused_for (1 point = 1 tick) to DOM's plateau max; the rest raises arousal_factor.
        int aroused = mind.is_aroused_for
        if aroused > 0
            int plateau_max = (mind.PRISM_Sensuality * 0.5 + mind.submission * 0.5) as int
            if aroused < plateau_max
                float room = (plateau_max - aroused) as float
                float used = delta
                if used > room
                    used = room
                endif
                mind.is_aroused_for = aroused + (used as int)
                Trace("AddArousal", GetDisplayName(akActor)+" aroused_for:"+aroused+"->"+mind.is_aroused_for+" max:"+plateau_max+" overflow:"+(delta - (used as int)))
                delta -= (used as int)
            endif
        endif
        if delta > 0.0
            mind.IncreaseArousal(delta, mind.MOD_SocialBoldness)
        endif
    else
        float af = mind.arousal_factor + delta
        if af < 0.0
            af = 0.0
        endif
        mind.arousal_factor = af
    endif
EndFunction

; DOM_Mind.IsOrgasmingAfterArousal's additive terms before the arousal multiplier, without its random
; ones, with handleSexOrgasm's act base.
float Function ScoreBase(DOM_Mind mind, Actor akActor)
    float base = mind.MOD_Vaginal
    if mind.MOD_Anal > base
        base = mind.MOD_Anal
    endif
    if mind.MOD_Oral > base
        base = mind.MOD_Oral
    endif
    float speed = 0.25
    if mind.DOM01 != None
        speed = mind.DOM01.train_speed_orgasm
        if mind.DOM01.DOMSexlab != None && mind.DOM01.DOMSexlab.separateOrgasmToggle
            base = 1000.0
        endif
    endif
    float chance = base * mind.MOD_Orgasm * speed
    if chance > 0.5
        chance = 0.5 + (chance - 0.5) / 20.0
    endif
    if IsMale(akActor)
        chance = chance * 2.0 + 0.1
    endif
    chance += mind.getArousalBonus()
    if mind.WasWarned(20) || mind.WasWarned(21)
        chance += 0.1
    endif
    if mind.whipping_active && (mind.whipping_reason == 20 || mind.whipping_reason == 21)
        chance += 0.1
    endif
    DOM_Actor slave_alias = mind.actor_alias
    if slave_alias != None
        ; DOM reads abuse_type == "sex" (a private variable); not sex_is_non_consensual stands in for it.
        if !slave_alias.canAnimate && !mind.sex_is_non_consensual && slave_alias.has_sex_with_player
            chance += 0.1
            if mind.number_of_sex == 0
                chance += 0.1
            endif
        endif
        if mind.number_of_sex == 0 && slave_alias.has_sex_with_player
            chance += 0.1
        endif
        if mind.number_of_sexformoney == 0 && slave_alias.has_sex_for_money
            chance += 0.1
        endif
    endif
    chance += mind.number_of_orgasm * 0.01
    return chance
EndFunction

; The roll's end terms, applied after the random additions.
float Function ApplyArousalTerms(DOM_Mind mind, float additive)
    float chance = additive * (1.0 + mind.arousal_factor / 1000.0)
    chance += mind.submission / 1000.0
    chance += mind.love_desire / 200.0
    return chance
EndFunction

float Function Clamp01(float value)
    if value > 1.0
        return 1.0
    elseif value < 0.0
        return 0.0
    endif
    return value
EndFunction

; Everything in DOM's roll that is not random, summed: the score the random roll is compared against.
float Function EstimateChance(DOM_Mind mind, Actor akActor)
    return ApplyArousalTerms(mind, ScoreBase(mind, akActor))
EndFunction

; Fills probs / adds (3 slots each) with DOM's should_be_noorgasm additions: probability of each outcome and its addition.
Function ControlOutcomes(DOM_Mind mind, float[] probs, float[] adds)
    probs[0] = 1.0
    adds[0] = 0.0
    if !mind.should_be_noorgasm
        return
    endif
    float sub = mind.submission
    float pSub = Clamp01(sub / 100.0)
    float pLove = Clamp01(mind.love_desire / 100.0)
    float p = pSub
    float hit
    float miss
    if mind.IsDevoted()
        if mind.was_allowed_toorgasm
            if sub >= 100.0
                p = pLove
                hit = 0.35
                miss = 0.25
            else
                hit = 0.2
                miss = 0.15
            endif
        elseif sub >= 100.0
            p = pLove
            hit = -0.35
            miss = -0.25
        else
            hit = -0.2
            miss = -0.15
        endif
    elseif mind.was_allowed_toorgasm
        hit = 0.15
        miss = 0.1
    else
        hit = -0.15
        miss = 0.2
    endif
    probs[0] = p
    adds[0] = hit
    probs[1] = 1.0 - p
    adds[1] = miss
EndFunction

; Probability (0-1) that IsOrgasmingAfterArousal's next roll succeeds: its random additions (orgasm control,
; whipping submissive, rapture oath) averaged over their outcomes; 0 when it cannot roll.
float Function RollProbability(DOM_Mind mind, Actor akActor)
    if mind.is_aroused_for <= 0 || IsRefractory(mind, akActor)
        return 0.0
    endif
    float base = ScoreBase(mind, akActor)

    float[] cP = Utility.CreateFloatArray(3, 0.0)
    float[] cA = Utility.CreateFloatArray(3, 0.0)
    ControlOutcomes(mind, cP, cA)

    float[] wP = Utility.CreateFloatArray(2, 0.0)
    float[] wA = Utility.CreateFloatArray(2, 0.0)
    wP[0] = 1.0
    if mind.whipping_active
        wP[0] = 1.0 - Clamp01(mind.PRISM_Submissivity)
        wP[1] = Clamp01(mind.PRISM_Submissivity)
        wA[1] = 0.1
    endif

    float[] rP = Utility.CreateFloatArray(3, 0.0)
    float[] rA = Utility.CreateFloatArray(3, 0.0)
    rP[0] = 1.0
    if mind.promiseOath == "rapture"
        float pSub = Clamp01(mind.submission / 100.0)
        float pSens = Clamp01(mind.PRISM_Sensuality / 100.0)
        rP[0] = 1.0 - pSub - (1.0 - pSub) * pSens
        rP[1] = pSub
        rA[1] = 0.1
        rP[2] = (1.0 - pSub) * pSens
        rA[2] = 0.2
    endif

    float total = 0.0
    int i = 0
    while i < 3
        int j = 0
        while j < 2
            int k = 0
            while k < 3
                float p = cP[i] * wP[j] * rP[k]
                if p > 0.0
                    total += p * Clamp01(ApplyArousalTerms(mind, base + cA[i] + wA[j] + rA[k]))
                endif
                k += 1
            endwhile
            j += 1
        endwhile
        i += 1
    endwhile
    return Clamp01(total)
EndFunction

float Function OrgasmProbability(Actor akActor)
    DOM_Mind mind = GetMind(akActor, "OrgasmProbability")
    if mind == None
        return 0.0
    endif
    return RollProbability(mind, akActor)
EndFunction

bool Function IsMale(Actor akActor)
    ActorBase base = akActor.GetLeveledActorBase()
    return base != None && base.GetSex() == 0
EndFunction

; DOM refuses a second orgasm this soon (male: while enraptured; female: first 4 ticks of it).
bool Function IsRefractory(DOM_Mind mind, Actor akActor)
    int enraptured = mind.is_enraptured_for
    if enraptured <= 0
        return false
    endif
    if IsMale(akActor)
        return true
    endif
    int enraptured_max = (mind.MOD_Orgasm * 10.0 + mind.submission * 0.5) as int
    if enraptured_max < 4
        enraptured_max = 4
    endif
    return enraptured > enraptured_max - 4
EndFunction

float Function OrgasmMeter(Actor akActor)
    DOM_Mind mind = GetMind(akActor, "OrgasmMeter")
    if mind == None
        return 0.0
    endif
    return 100.0 * Clamp01(EstimateChance(mind, akActor))
EndFunction

Bool Function CouldOrgasm(Actor akActor)
    DOM_Mind mind = GetMind(akActor, "CouldOrgasm")
    if mind == None || IsRefractory(mind, akActor)
        return false
    endif
    if mind.is_aroused_for <= 0 && mind.arousal_factor < 100.0
        return false
    endif
    return EstimateChance(mind, akActor) > 0.0
EndFunction

; ---- Spread DOM arousal (docs/developers/orgasm-engine.md#dom-slaves) ----
; Arousal DOM added itself that the prepay could not take off yet (arousal_factor was near 0).
; Paid off by later step pushes; carries across scenes.
String storage_dom_debt_key = "skyrimnet_sexlab_dom_debt"

; DOM_Mind.IncreaseArousal's value during sex (sex_active): the arousal_factor change for amount/reason.
float Function DomArousalValue(DOM_Mind mind, Actor akActor, float amount, float reason)
    float m = mind.FACET_Sensuality / 200.0 + 0.5 + reason / 10.0
    float speed = 0.5
    float trainer_mod = 1.0
    if mind.DOM01 != None
        speed = mind.DOM01.train_speed_arousal
        Actor trainer = None
        if mind.actor_alias != None
            trainer = mind.actor_alias.GetCurrentSexTrainer()
        endif
        if mind.sex_is_non_consensual
            trainer_mod = mind.DOM01.GetPredatorModifier(trainer)
        else
            trainer_mod = mind.DOM01.GetDeceiverModifier(trainer)
        endif
    endif
    float value = amount * m * speed * trainer_mod
    if IsMale(akActor) && mind.is_enraptured_for > 0
        value = value / 10.0
    endif
    return value
EndFunction

; A step push: IncreaseArousal, minus any debt still owed.
Function PushStep(DOM_Mind mind, Actor akActor, float amount, float reason)
    float debt = StorageUtil.GetFloatValue(akActor, storage_dom_debt_key, 0.0)
    if debt <= 0.0
        mind.IncreaseArousal(amount, reason)
        return
    endif
    float value = DomArousalValue(mind, akActor, amount, reason)
    float pay = value
    if pay > debt
        pay = debt
    endif
    mind.arousal_factor = mind.arousal_factor + value - pay
    StorageUtil.SetFloatValue(akActor, storage_dom_debt_key, debt - pay)
EndFunction

Function DomSync(Actor akActor, float miniDelta, float daring, float naivety, bool prepay, bool hasPlayer)
    DOM_Mind mind = GetMind(akActor, "DomSync")
    if mind == None
        return
    endif
    if prepay
        ; DOM adds IncreaseArousal(20, MOD_Daring) at its scene start and, with the player,
        ; IncreaseArousal(20, MOD_Naivety) at its roll. The steps replace those: take them off now.
        float owed = DomArousalValue(mind, akActor, 20.0, mind.MOD_Daring)
        if hasPlayer
            owed += DomArousalValue(mind, akActor, 20.0, mind.MOD_Naivety)
        endif
        float debt = StorageUtil.GetFloatValue(akActor, storage_dom_debt_key, 0.0) + owed
        float af = mind.arousal_factor
        float take = debt
        if take > af
            take = af
        endif
        if take < 0.0
            take = 0.0
        endif
        mind.arousal_factor = af - take
        StorageUtil.SetFloatValue(akActor, storage_dom_debt_key, debt - take)
        Trace("DomSync", GetDisplayName(akActor)+" prepay owed:"+owed+" taken:"+take+" debt:"+(debt - take)+" arousal:"+af+"->"+mind.arousal_factor)
    endif
    if miniDelta != 0.0
        AddArousal(akActor, miniDelta)
    endif
    if daring > 0.0
        PushStep(mind, akActor, daring, mind.MOD_Daring)
    endif
    if naivety > 0.0
        PushStep(mind, akActor, naivety, mind.MOD_Naivety)
    endif
EndFunction

; Light roll after a rise; about 1/share of these add up to one handleSexOrgasm roll (DOM's
; chance is linear below 0.5). The success branch is handleSexOrgasm's.
Function StepRoll(Actor akActor, bool hasPlayer, float share)
    DOM_Mind mind = GetMind(akActor, "StepRoll")
    if mind == None || share <= 0.0
        return
    endif
    mind.IsArousedAfterSex(mind.MOD_Daring)
    if !CouldOrgasm(akActor)
        return
    endif
    float base = 0.0
    if mind.hadVaginalSex
        base = mind.MOD_Vaginal
    endif
    if mind.hadAnalSex && mind.MOD_Anal > base
        base = mind.MOD_Anal
    endif
    if mind.hadOralSex && mind.MOD_Oral > base
        base = mind.MOD_Oral
    endif
    if mind.DOM01 != None && mind.DOM01.DOMSexlab != None && mind.DOM01.DOMSexlab.separateOrgasmToggle
        base = 1000.0
    endif
    if base <= 0.0
        return
    endif
    Trace("StepRoll", GetDisplayName(akActor)+" base:"+base+" share:"+share+" arousal:"+mind.arousal_factor+" aroused_for:"+mind.is_aroused_for+" player:"+hasPlayer)
    if !mind.IsOrgasmingAfterArousal(base * share)
        return
    endif
    String type = "sex"
    if mind.sex_is_non_consensual
        type = "rape"
    elseif mind.actor_alias != None && mind.actor_alias.has_sex_alone
        type = "masturbate"
    endif
    if mind.actor_alias != None
        mind.actor_alias.SendExternalEventSS("Orgasm", type)
        if mind.DOM01 != None && mind.DOM01.DOM04 != None
            mind.DOM01.DOM04.NotifyOrgasm(mind.actor_alias, type, mind.should_be_noorgasm, mind.was_allowed_toorgasm, mind.sex_is_non_consensual)
        endif
    endif
    Trace("StepRoll", GetDisplayName(akActor)+" orgasm ("+type+")")
EndFunction

int Function GetThreads()
    return SkyrimNet_DOM_API.GetThreads()
EndFunction

; DOM solo masturbation is not a SexLab thread: push it to sexlab_get_threads / threads.json on
; start/stop (Scene_Manager.PushDomThreads).
Event OnBehaviourChange(Form akRef, String type)
    Actor slave = akRef as Actor
    if slave == None
        Trace("OnBehaviourChange", "akRef is not an Actor, skipping")
        return
    endif
    String current = StorageUtil.GetStringValue(akRef, storage_behaviour_key, "")
    Trace("OnBehaviourChange", GetDisplayName(slave)+" "+current+"->"+type)
    bool refresh = (type == "masturbate") || (current == "masturbate")
    StorageUtil.SetStringValue(akRef, storage_behaviour_key, type)
    if !refresh
        return
    endif
    if manager == None
        Trace("OnBehaviourChange", "manager is None, aborting")
        return
    endif
    manager.PushDomThreads()
    Trace("OnBehaviourChange", "--- pushed DOM threads for "+GetDisplayName(slave)+" type:"+type)
EndEvent



; ------------------------------------------------------------

Function Start_Masturbate(String intent, Actor speaker, Actor superior, String position="")
    SkyrimNet_DOM_API.Start_Masturbate(intent, speaker, superior, position)
EndFunction



Function StartScene_Consensual_Two(String intent, Actor speaker, Actor superior, Actor target, string style="", string method="", String direction="", String setting_name="")
    SkyrimNet_DOM_API.StartScene_Consensual_Two(intent, speaker, superior, target, style, method, direction, setting_name)
EndFunction



; style omitted (ExecuteQuestFunction max 8 args / DOM_API); SexLab always gets style=""
Function StartScene_Nonconsensual_Two(String intent, Actor speaker, Actor superior, Actor target, Actor victim, string method="", String direction="", String setting_name="")
    SkyrimNet_DOM_API.StartScene_Nonconsensual_Two(intent, speaker, superior, target, victim, method=method, direction=direction, setting_name=setting_name)
EndFunction

Function StartScene_Nonconsensual_Two_SpeakerVictim(String intent, Actor speaker, Actor superior, Actor target, string method="", String direction="", String setting_name="")
    SkyrimNet_DOM_API.StartScene_Nonconsensual_Two_SpeakerVictim(intent, speaker, superior, target, method=method, direction=direction, setting_name=setting_name)
EndFunction

Function StartScene_Nonconsensual_Two_TargetVictim(String intent, Actor speaker, Actor superior, Actor target, string method="", String direction="", String setting_name="")
    SkyrimNet_DOM_API.StartScene_Nonconsensual_Two_TargetVictim(intent, speaker, superior, target, method=method, direction=direction, setting_name=setting_name)
EndFunction