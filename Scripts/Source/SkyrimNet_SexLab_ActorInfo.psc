Scriptname SkyrimNet_SexLab_ActorInfo Hidden

; ControlPanel "Actor Info" view (MainPanels 0800_actor_info.json): header row of source title, name and
; gender pulldown, then the facts: Lover's Ledger when TT_LoversLedger.esp is loaded, else SexLab's own
; stats ("SexLab P+ Facts" on P+). JS: renderActorInfo.

Function Trace(String func, String msg, Bool notification=False) global
    String logged = SkyrimNet_SexLab_WebUI.TraceLog("SkyrimNet_SexLab_ActorInfo", func, msg)
    if notification
        Debug.Notification(msg)
    endif
EndFunction

String Function GenderName(int choice) global
    if choice == 0
        return "male"
    elseif choice == 1
        return "female"
    elseif choice == 2
        return "intersex"
    endif
    return "creature"
EndFunction

; "male" / "female" / "intersex" -> 0 / 1 / 2; -1 otherwise.
int Function GenderFromName(String name) global
    if name == "male"
        return 0
    elseif name == "female"
        return 1
    elseif name == "intersex"
        return 2
    endif
    return -1
EndFunction

; Actor Info "sexlab" object from sslActorStats (P+ keeps this API).
String Function SexLabJson(SexLabFramework sexlab, Actor target) global
    if sexlab == None || target == None
        return "{\"empty\":\"SexLab is not available\"}"
    endif
    sslActorStats stats = sexlab.Stats
    String json = "{\"sexCount\":" + stats.SexCount(target) + ",\"playerSexCount\":" + stats.PlayerSexCount(target)
    String partner = ""
    Actor last = stats.LastSexPartner(target)
    if last != None
        partner = last.GetDisplayName()
    endif
    json += ",\"lastPartner\":" + SkyrimNet_SexLab_Utilities.JsonQuote(partner)
    Float daysAgo = -1.0
    if stats.HadSex(target)
        daysAgo = stats.DaysSinceLastSex(target)
    endif
    json += ",\"lastDaysAgo\":" + daysAgo
    if target.HasKeywordString("ActorTypeNPC")
        json += ",\"sexuality\":" + SkyrimNet_SexLab_Utilities.JsonQuote(stats.GetSexualityTitle(target)) \
            + ",\"sexualityPct\":" + stats.GetSexuality(target) \
            + ",\"purity\":" + SkyrimNet_SexLab_Utilities.JsonQuote(stats.GetPurityTitle(target))
        String[] skills = new String[4]
        skills[0] = "Foreplay"
        skills[1] = "Vaginal"
        skills[2] = "Anal"
        skills[3] = "Oral"
        json += ",\"skills\":["
        int i = 0
        while i < skills.Length
            if i > 0
                json += ","
            endif
            json += "{\"name\":" + SkyrimNet_SexLab_Utilities.JsonQuote(skills[i]) \
                + ",\"title\":" + SkyrimNet_SexLab_Utilities.JsonQuote(stats.GetSkillTitle(target, skills[i])) + "}"
            i += 1
        endwhile
        json += "]"
    endif
    return json + "}"
EndFunction

; Payload for JS renderActorInfo (setMainPanelData). The dispatch keys let the gender pulldown call
; Menu.WebUI_ActorInfoApply through fireStatusApply.
String Function BuildPanelJson(Actor target) global
    String json = "{\"panel\":\"actor_info\",\"id\":\"actor_info_panel\"" \
        + ",\"plugin\":\"SkyrimNet_SexLab.esp\",\"questFormId\":\"0x800\"" \
        + ",\"scriptName\":\"SkyrimNet_SexLab_Menu\",\"applyFunction\":\"WebUI_ActorInfoApply\""
    if target == None
        return json + ",\"name\":\"\",\"empty\":\"No target\"}"
    endif
    SexLabFramework sexlab = SexLabUtil.GetAPI()
    String name = target.GetDisplayName()
    int choice = SkyrimNet_SexLab_Utilities.GenderChoice(sexlab, target)
    json += ",\"name\":" + SkyrimNet_SexLab_Utilities.JsonQuote(name) + ",\"formId\":" + target.GetFormID() \
        + ",\"gender\":\"" + GenderName(choice) + "\",\"genderEditable\":" + (choice >= 0) as int \
        + ",\"genderNote\":\"OStim uses the body's sex\""
    if SkyrimNet_SexLab_LoversLedger.IsInstalled()
        json += ",\"source\":\"ledger\",\"sourceTitle\":\"Lover's Ledger\",\"ledger\":" + SkyrimNet_SexLab_LoversLedger.LedgerJson(target)
    else
        String sourceTitle = "SexLab Facts"
        if SkyrimNet_SexLab_Utilities.IsSexLabPPlus()
            sourceTitle = "SexLab P+ Facts"
        endif
        json += ",\"source\":\"sexlab\",\"sourceTitle\":\"" + sourceTitle + "\",\"sexlab\":" + SexLabJson(sexlab, target)
    endif
    Trace("BuildPanelJson", name + " gender:" + GenderName(choice))
    return json + "}"
EndFunction
