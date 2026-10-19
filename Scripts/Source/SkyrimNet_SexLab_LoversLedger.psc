Scriptname SkyrimNet_SexLab_LoversLedger Hidden

; Lover's Ledger (TT_LoversLedger.esp) bridge for the ControlPanel "Lover's Ledger" view.
; The only SexLab script that references TTLL_Store: call it only when TT_LoversLedger.esp is loaded.

Function Trace(String func, String msg, Bool notification=False) global
    String logged = SkyrimNet_SexLab_WebUI.TraceLog("SkyrimNet_SexLab_LoversLedger", func, msg)
    if notification
        Debug.Notification(msg)
    endif
EndFunction

Bool Function IsInstalled() global
    return Game.GetModByName("TT_LoversLedger.esp") != 255
EndFunction

; One sentence listing each position's first sexual experience in this scene; "" when none or not installed.
String Function FirstTimesSentence(Actor[] positions, String tags) global
    if !IsInstalled() || positions.Length == 0
        return ""
    endif
    String lines = TTLL_SexlabIntegration.GetFirstTimes(positions, tags)
    if lines == ""
        return ""
    endif
    String joined = ""
    String[] parts = StringUtil.Split(lines, "\n")
    int i = 0
    while i < parts.Length
        if parts[i] != ""
            if joined != ""
                joined += " "
            endif
            joined += parts[i]
        endif
        i += 1
    endwhile
    Trace("FirstTimesSentence", joined)
    return joined
EndFunction

; True when the ledger has no record of a receiving `act` ("Vaginal", "Anal") for a; false when not installed.
Bool Function NeverGot(Actor a, String act) global
    if !IsInstalled() || a == None
        return false
    endif
    return TTLL_Store.GetActionCount(a, false, act) == 0
EndFunction

; Game days since a ledger "lasttime"; -1 when never.
Float Function DaysAgo(Float lastTime, Float now) global
    if lastTime <= 0.0
        return -1.0
    endif
    return now - lastTime
EndFunction

; [{"name":..,"count":..}] for the top actions the target did (isDid) or got.
String Function ActionsJson(Actor target, Bool isDid, Int topK) global
    String[] names = TTLL_Store.GetAllActions(target, isDid, topK)
    String json = "["
    int i = 0
    while i < names.Length
        if i > 0
            json += ","
        endif
        json += "{\"name\":" + SkyrimNet_SexLab_Utilities.JsonQuote(names[i]) \
            + ",\"count\":" + TTLL_Store.GetActionCount(target, isDid, names[i]) + "}"
        i += 1
    endwhile
    return json + "]"
EndFunction

; Payload for JS renderLoversLedger (setMainPanelData). Lovers by score, capped.
String Function BuildPanelJson(Actor target, Int maxLovers = 25, Int maxActions = 10) global
    String head = "{\"panel\":\"lovers_ledger\",\"id\":\"lovers_ledger_panel\""
    if target == None
        return head + ",\"name\":\"\",\"empty\":\"No target\"}"
    endif
    String name = target.GetDisplayName()
    head += ",\"name\":" + SkyrimNet_SexLab_Utilities.JsonQuote(name)
    if !IsInstalled()
        return head + ",\"empty\":\"Lover's Ledger is not installed\"}"
    endif

    Float now = Utility.GetCurrentGameTime()
    int exclusive = TTLL_Store.GetNpcInt(target, "exclusivesex")
    int group = TTLL_Store.GetNpcInt(target, "groupsex")
    int solo = TTLL_Store.GetNpcInt(target, "solosex")
    int sameSex = TTLL_Store.GetNpcInt(target, "samesexencounter")
    int others = TTLL_Store.GetNpcInt(target, "otherscount")
    int icDid = TTLL_Store.GetNpcInt(target, "totalinternalclimax.did")
    int icGot = TTLL_Store.GetNpcInt(target, "totalinternalclimax.got")
    Float lastTime = TTLL_Store.GetNpcFlt(target, "lasttime")
    Form[] lovers = TTLL_Store.GetAllLovers(target, maxLovers)

    if exclusive + group + solo + others == 0 && lastTime <= 0.0 && lovers.Length == 0
        ActorBase base = target.GetActorBase()
        if base != None && !base.IsUnique()
            return head + ",\"empty\":" + SkyrimNet_SexLab_Utilities.JsonQuote( \
                name + " is not unique; Lover's Ledger tracks unique NPCs only") + "}"
        endif
        return head + ",\"empty\":" + SkyrimNet_SexLab_Utilities.JsonQuote("No ledger entries for " + name) + "}"
    endif

    String json = head + ",\"formId\":" + target.GetFormID() + ",\"now\":" + now
    json += ",\"summary\":{\"exclusive\":" + exclusive + ",\"group\":" + group + ",\"solo\":" + solo \
        + ",\"sameSex\":" + sameSex + ",\"others\":" + others + ",\"icDid\":" + icDid + ",\"icGot\":" + icGot \
        + ",\"lastDaysAgo\":" + DaysAgo(lastTime, now) + "}"
    json += ",\"did\":" + ActionsJson(target, true, maxActions)
    json += ",\"got\":" + ActionsJson(target, false, maxActions)

    ; Lover getters need a reference Actor; GetAllLovers returns NPC bases (ActorFromBase maps them).
    json += ",\"lovers\":["
    int missing = 0
    int i = 0
    while i < lovers.Length
        ActorBase loverBase = lovers[i] as ActorBase
        Actor lover = SkyrimNet_SexLab_Utilities.ActorFromBase(loverBase)
        if i > 0
            json += ","
        endif
        String loverName = "?"
        if lover != None
            loverName = lover.GetDisplayName()
        elseif loverBase != None
            loverName = loverBase.GetName()
        endif
        json += "{\"name\":" + SkyrimNet_SexLab_Utilities.JsonQuote(loverName)
        if lover != None
            json += ",\"formId\":" + lover.GetFormID() \
                + ",\"score\":" + TTLL_Store.GetLoverScore(target, lover) \
                + ",\"exclusive\":" + TTLL_Store.GetLoverInt(target, lover, "exclusivesex") \
                + ",\"group\":" + TTLL_Store.GetLoverInt(target, lover, "partofsamegroupsex") \
                + ",\"orgasms\":" + TTLL_Store.GetLoverFlt(target, lover, "orgasms") \
                + ",\"icDid\":" + TTLL_Store.GetLoverInt(target, lover, "internalclimax.did") \
                + ",\"icGot\":" + TTLL_Store.GetLoverInt(target, lover, "internalclimax.got") \
                + ",\"lastDaysAgo\":" + DaysAgo(TTLL_Store.GetLoverFlt(target, lover, "lasttime"), now)
        else
            missing += 1
            json += ",\"formId\":0,\"lastDaysAgo\":-1"
        endif
        json += "}"
        i += 1
    endwhile
    json += "]}"
    Trace("BuildPanelJson", name + " lovers:" + lovers.Length + " unresolved:" + missing)
    return json
EndFunction
