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

; Each position's first sexual experience in this scene (the scene start info event), one line;
; "" when none or not installed.
String Function FirstTimes(Actor[] positions, String tags) global
    if !IsInstalled() || positions.Length == 0
        return ""
    endif
    String lines = TTLL_SexlabIntegration.GetFirstTimes(positions, tags)
    if lines == ""
        return ""
    endif
    String result = PapyrusUtil.StringJoin(StringUtil.Split(lines, "\n"), " ")
    Trace("FirstTimes", result)
    return result
EndFunction

; SexLab's own count of `act` ("Vaginal", "Anal") for a: P+ statistics 10 / 11, AE skills VaginalCount / AnalCount.
; The same counts Lover's Ledger seeds itself from (TTLL_SexlabIntegration.CheckHistory).
Int Function SexLabCount(Actor a, String act) global
    if TTLL_SexlabIntegration.IsPPlus()
        int id = 10
        if act == "Anal"
            id = 11
        endif
        return TTLL_SexlabPPlus.GetCount(a, id)
    endif
    SexLabFramework slf = Game.GetFormFromFile(0xD62, "SexLab.esm") as SexLabFramework
    if slf == None
        return 0
    endif
    return slf.Stats.GetSkill(a, act + "Count")
EndFunction

; True when this is a's first receiving `act` ("Vaginal", "Anal"); false when not installed.
; The ledger decides, once it holds SexLab's history: SexLab knowing more than the ledger (not seeded yet,
; or a past lover still queued) is not a first. Same test as Lover's Ledger FirstTimes.cpp.
Bool Function FirstGot(Actor a, String act) global
    if !IsInstalled() || a == None
        return false
    endif
    int got = TTLL_Store.GetActionCount(a, false, act)
    if got != 0
        return false
    endif
    return SexLabCount(a, act) <= TTLL_Store.GetActionCount(a, true, act)
EndFunction

; Virgin-blood sentences for the scene start DN (sexlab.narration.virgin_blood, default off). Receivers as in
; Scene.Engine_SetSkills: vaginal for a female position, anal for position 0. "" when none.
String Function VirginBloodSentences(Actor[] positions, Bool vaginal, Bool anal) global
    if !(vaginal || anal) || !IsInstalled() \
            || !SkyrimNetApi.GetConfigBool("Plugin_SkyrimNet_SexLab", "sexlab.narration.virgin_blood", false)
        return ""
    endif
    String result = ""
    int i = 0
    while i < positions.Length
        Actor a = positions[i]
        if a != None
            String name = a.GetDisplayName()
            if vaginal && a.GetLeveledActorBase().GetSex() == 1 && FirstGot(a, "Vaginal")
                result += " This is " + name + "'s first time having vaginal sex; there is some bleeding and their pussy is a little sore."
            endif
            if anal && i == 0 && FirstGot(a, "Anal")
                result += " This is " + name + "'s first time having anal sex; there is some bleeding and their ass is a little sore."
            endif
        endif
        i += 1
    endwhile
    if result != ""
        result = StringUtil.Substring(result, 1)
        Trace("VirginBloodSentences", result)
    endif
    return result
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
