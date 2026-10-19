Scriptname SkyrimNet_SexLab_LoversLedger Hidden

; Lover's Ledger (TT_LoversLedger.esp) bridge: the ControlPanel Actor Info view's ledger section, first times.
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

; Each position's first sexual experience in this scene, split for the scene start:
; [0] the first-times sentences (start info event), [1] the virgin-blood sentences (start DN).
; Both "" when none or not installed. The blood text matches Lover's Ledger FirstTimes.cpp
; ("<name>'s vagina|asshole is a little sore and is bleeding."): keep the two in sync.
String[] Function FirstTimesParts(Actor[] positions, String tags) global
    String[] result = new String[2]
    result[0] = ""
    result[1] = ""
    if !IsInstalled() || positions.Length == 0
        return result
    endif
    String lines = TTLL_SexlabIntegration.GetFirstTimes(positions, tags)
    if lines == ""
        return result
    endif
    String[] parts = StringUtil.Split(lines, "\n")
    int i = 0
    while i < parts.Length
        ; Sentences end in ". " (Split takes single characters, so walk with Find).
        String rest = parts[i]
        while rest != ""
            String s = rest
            int cut = StringUtil.Find(rest, ". ")
            if cut >= 0
                s = StringUtil.Substring(rest, 0, cut + 1)
                rest = StringUtil.Substring(rest, cut + 2)
            else
                rest = ""
            endif
            if s != ""
                int k = 0
                if StringUtil.Find(s, " is a little sore and is bleeding") >= 0
                    k = 1
                endif
                if result[k] != ""
                    result[k] = result[k] + " "
                endif
                result[k] = result[k] + s
            endif
        endwhile
        i += 1
    endwhile
    Trace("FirstTimesParts", "first_times:"+result[0]+" | blood:"+result[1])
    return result
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

; Actor Info "ledger" object (ActorInfo.BuildPanelJson; JS renderActorInfo): {now, summary, did, got,
; lovers} or {empty}. Lovers by score, capped.
String Function LedgerJson(Actor target, Int maxLovers = 25, Int maxActions = 10) global
    if target == None
        return "{\"empty\":\"No target\"}"
    endif
    String name = target.GetDisplayName()
    if !IsInstalled()
        return "{\"empty\":\"Lover's Ledger is not installed\"}"
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
            return "{\"empty\":" + SkyrimNet_SexLab_Utilities.JsonQuote( \
                name + " is not unique; Lover's Ledger tracks unique NPCs only") + "}"
        endif
        return "{\"empty\":" + SkyrimNet_SexLab_Utilities.JsonQuote("No ledger entries for " + name) + "}"
    endif

    String json = "{\"now\":" + now
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
    Trace("LedgerJson", name + " lovers:" + lovers.Length + " unresolved:" + missing)
    return json
EndFunction
