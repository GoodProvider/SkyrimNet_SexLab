Scriptname SkyrimNet_SexLab_Menu extends Quest  ; Can extend Quest or Form depending on your architecture

SkyrimNet_SexLab_MCM Property mcm Auto
SkyrimNet_SexLab_Main Property main Auto  
SkyrimNet_SexLab_AnimDb Property animdb Auto
SkyrimNet_SexLab_Scene_Manager Property manager Auto 
SkyrimNet_SexLab_Actions Property actions Auto 

bool debug_mode = false 

Function Trace(String func, String msg, Bool notification=False) global
    String logged = SkyrimNet_SexLab_WebUI.TraceLog("SkyrimNet_SexLab_Menu", func, msg)
    if notification
        Debug.Notification(msg)
    endif 
EndFunction

Function OpenSkyrimNetDashboard()
    SkyrimNetApi.TriggerToggleDashboard()
EndFunction

Function Setup()
    debug_mode = False
    Bool links_ok = Setup_CheckLinks()
    if !links_ok
        return
    endif
EndFunction

Bool Function Setup_CheckLinks()
    Bool links_ok = true

    mcm = (self as Quest) as SkyrimNet_SexLab_MCM
    if mcm == None
        links_ok = false
    endif

    main = (self as Quest) as SkyrimNet_SexLab_Main
    if main == None
        links_ok = false
    endif

    animdb = (self as Quest) as SkyrimNet_SexLab_AnimDb
    if animdb == None
        links_ok = false
    endif

    manager = (self as Quest) as SkyrimNet_SexLab_Scene_Manager
    if manager == None
        links_ok = false
    endif

    actions = (self as Quest) as SkyrimNet_SexLab_Actions
    if actions == None
        links_ok = false
    endif

    return links_ok
EndFunction

Function ProcessHotkey(int key_code)
    ; Both players need to be in the crosshair to have SkyrimNet load them into the cache
    ; so the parseJsonActor works
    Actor target = Game.GetCurrentCrosshairRef() as Actor
    Actor player = Game.GetPlayer()
    bool preferExplicit = false

    if main.sexlab.IsActorActive(player)
        ; Player mid-scene (crosshair ignored): first non-player from position 0, else the player
        ; when solo. Others stay reachable via the pulldown.
        target = player
        preferExplicit = true
        sslThreadController thread = manager.GetThreadByActor(player)
        if thread && thread.Positions
            int i = 0
            while i < thread.Positions.length
                Actor a = thread.Positions[i]
                if a != None && a != player
                    target = a
                    i = thread.Positions.length
                else
                    i += 1
                endif
            endwhile
        endif
    elseif target != None
        preferExplicit = true
    else
        target = player
        preferExplicit = false
    endif

    bool target_not_none = target != None
    String target_name = "None"
    if target_not_none
        target_name = target.GetDisplayName()
    endif
    Trace("ProcessHotkey","target: "+target_name+" preferExplicit:"+preferExplicit)

    if target != None
        Open_WebUI_Target(target)
        SkyrimNet_SexLab_WebUI.WebUI_AfterTargetOpen(target, preferExplicit)
    endif
EndFunction

; Scene HUD keys (C++ Hud): SexLab thread operations on the player's scene. calm / arouse / focus /
; slower / faster never reach Papyrus (OrgasmEngine + AnimSpeed in C++).
; focus: the HUD's focus actor (deny key); None for the other keys.
Function Hud_OnKey(String control, Actor focus = None)
    Actor player = Game.GetPlayer()
    if !main.sexlab.IsActorActive(player)
        return
    endif
    Trace("Hud_OnKey", control)
    if control == "end"
        actions.SceneStop_Target(player, player, "normally")
    elseif control == "previous"
        actions.TM_StagePrev(player, player)
    elseif control == "next"
        actions.TM_StageNext(player, player)
    elseif control == "pause"
        SkyrimNet_SexLab_Scene sl_scene = manager.GetSceneByActor(player)
        if sl_scene != None
            sl_scene.TogglePause()
        endif
    elseif control == "deny"
        SkyrimNet_SexLab_Scene deny_scene = manager.GetSceneByActor(player)
        if deny_scene != None && focus != None
            deny_scene.ToggleDenyOrgasm(focus, true)
        endif
    elseif control == "pos_up" || control == "pos_down"
        SkyrimNet_SexLab_Scene pos_scene = manager.GetSceneByActor(player)
        if pos_scene != None
            pos_scene.HotkeyChangePositions(control == "pos_down")
        endif
    endif
EndFunction

; WebUI hotkey / stay-open refresh: pass StorageUtil strip state for actionSwitch.
Function Open_WebUI_Target(Actor target)
    if target == None
        Trace("Open_WebUI_Target", "target is None")
        return
    endif
    bool hasStripped = main.HasStrippedItems(target)
    Trace("Open_WebUI_Target", target.GetDisplayName()+" hasStripped:"+hasStripped \
        +" editTagsPlayer:"+SkyrimNetApi.GetConfigBool("Plugin_SkyrimNet_SexLab", "sexlab.tags.player", true) \
        +" editTagsNonPlayer:"+SkyrimNetApi.GetConfigBool("Plugin_SkyrimNet_SexLab", "sexlab.tags.nonplayer", false))
    if !SkyrimNet_SexLab_WebUI.Target_Menu_Open(target, hasStripped, \
        SkyrimNetApi.GetConfigBool("Plugin_SkyrimNet_SexLab", "sexlab.tags.player", true), \
        SkyrimNetApi.GetConfigBool("Plugin_SkyrimNet_SexLab", "sexlab.tags.nonplayer", false))
        Trace("Open_WebUI_Target", \
            "PrismaUI overlay missing Data/PrismaUI/views/SkyrimNet_SexLab/index.html", True)
        return
    endif
    ; Mid-scene TargetMenu panels seed SceneInfo on overlay Show.
EndFunction

; ControlPanel actor pulldown changed focus.
Function WebUI_OnControlActorFocus(Actor target)
    if target == None
        Trace("WebUI_OnControlActorFocus", "target is None")
        return
    endif
    bool hasStripped = main.HasStrippedItems(target)
    Trace("WebUI_OnControlActorFocus", target.GetDisplayName()+" hasStripped:"+hasStripped)
    SkyrimNet_SexLab_WebUI.Target_Menu_Refresh(hasStripped)
    SkyrimNet_SexLab_WebUI.WebUI_MaybeRestoreScenePanel()
EndFunction

Function WebUI_ConfigureFocusScene()
    if !manager
        return
    endif
    Actor target = SkyrimNet_SexLab_WebUI.WebUI_GetFocusActor()
    if target == None
        return
    endif
    SkyrimNet_SexLab_Scene sl = manager.GetSceneByActor(target)
    if sl == None || !sl.GetThreadActive()
        return
    endif
    SkyrimNet_SexLab_WebUI.SceneCreator_Configure(sl.BuildWebUISceneMenuState())
    SkyrimNet_SexLab_WebUI.Animation_Menu_Configure(sl.BuildWebUIAnimationMenuState())
EndFunction

Function WebUI_SeedSceneInfos()
    if !manager
        return
    endif
    ; Overlay Show = "before the hotkey": the state WebUI Cancel restores.
    manager.WebUI_TakeCancelSnapshots()
    SkyrimNet_SexLab_WebUI.SceneInfos_Seed(manager.BuildAllSceneInfosJson())
EndFunction

Function Target_Menu_Selection(Actor target, Actor player)
    int cancel = 0 
    int sexlab_ostim = -1
    
    if main.ostimnet_found 
        sexlab_ostim = cancel
        cancel += 1
    endif 

    int masturbate = cancel
    int punish = cancel+1
    int affection = cancel+2
    int sex = cancel+3
    int raped_by_player = cancel+4
    int rapes_player = cancel+5
    
    cancel += 6 

    int bondage = -1
    if mcm.udng_found
        bondage = cancel
        cancel += 1 
    endif

    int leash = -1
    if mcm.leashed_found
        leash = cancel
        cancel += 1
    endif
    
    String[] buttons = Utility.CreateStringArray(cancel+1)

    int ostim_player = SkyrimNetApi.GetConfigInt("Plugin_SkyrimNet_SexLab", "sexlab.ostim.player", 0)
    if ostim_player < 0
        ostim_player = 0
    elseif ostim_player > 1
        ostim_player = 1
    endif
    if sexlab_ostim != -1
        buttons[sexlab_ostim] = mcm.sexlab_ostim_options[ostim_player]
    endif 
    buttons[masturbate] = "masturbate"
    buttons[punish] = "punish"
    buttons[affection] = "affection"
    buttons[sex] = "sex"
    buttons[raped_by_player] = "player rapes"
    buttons[rapes_player] = "rapes player"
    if bondage != -1 
        buttons[bondage] = "bondage"
    endif
    if leash != -1
        buttons[leash] = "leash"
    endif
    Trace("Target_Menu_Selection", "leashed_found: "+mcm.leashed_found+ "leash index: "+leash)
    buttons[cancel] = "cancel"

    String msg = "Should "+target.getDisplayName()+":"
    int button = SkyMessage.ShowArray(msg, buttons, getIndex = true) as int  

    if button < 0 || button == cancel
        Trace("Target_Menu_Selection","cancelled")
        return
    endif
    Trace("Target_Menu_Selection","button:" +buttons[button]) 
    
    if button == masturbate
        if ostim_player == 1 && main.ostimnet_found
            EventSend_OStimNet("SexStart", target, None, "")
        elseif main.handler_dom.IsDOMSlave(target) 
            main.handler_dom.Start_Masturbate("sexual training", target, player)
        else 
            actions.StartScene_Consensual_one("sexual activities", target, "normal", "")
        endif 
    elseif sexlab_ostim != -1 && button == sexlab_ostim 
        String choice = ""
        if ostim_player == 0
            ostim_player = 1
            choice = "Ostim"
        else
            ostim_player = 0
            choice = "SexLab"
        endif
        SkyrimNetApi.PatchConfig("Plugin_SkyrimNet_SexLab", "{ \"sexlab\": { \"ostim\": { \"player\": "+ostim_player+" } } }")
        Debug.Notification("Switched to "+choice)
    elseif button == punish 
        String[] bs = new String[4] 
        bs[0] = "spanking"
        bs[1] = "spanking nude"
        bs[2] = "whip"
        bs[3] = "rape"
        String method = SkyMessage.ShowArray("How would you like to punish?", bs, getIndex = false) as string  
        if method == ""
            Trace("Target_Menu_Selection","cancelled punish method selection")
            return
        endif
        string setting_name= "punish_spanking"
        String punish_intent = "physically punishing"
        if method == "spanking nude"
            method = "spanking"
            setting_name= "punish_spanking_victim_nude"
        elseif method == "whipping"  || method == "whip"
            method = "whip"
            setting_name= "punish_whipping_oral"
        elseif method == "rape"
            method = ""
            setting_name= "punish_pleasure_pain_rape"
            punish_intent = "sexual assault"
        endif 
        if debug_mode && main.handler_dom.IsDOMSlave(target) 
            main.handler_dom.StartScene_Nonconsensual_Two_SpeakerVictim(punish_intent, target, player, player, method=method, setting_name=setting_name)
        else
            actions.StartScene_Nonconsensual_Two_TargetVictim(punish_intent, player, target, method=method, setting_name=setting_name)
        endif 
    elseif button == affection
        if ostim_player == 0 || !main.ostimnet_found    
            String[] bs = new String[6] 
            bs[0] = "single hug"
            bs[1] = "hugging"
            bs[2] = "cuddle"
            bs[3] = "spooning"
            bs[4] = "kissing"
            bs[5] = "headpat"
            String method = SkyMessage.ShowArray("How would you like to show affection?", bs, getIndex = false) as string  
            if method == ""
                Trace("Target_Menu_Selection","cancelled affection method selection")
                return
            endif
            string setting_name = "nonsexual_male_position_1"
            if method == "kissing" 
                setting_name = "nonsexual_kissing"
            endif 
            actions.StartScene_Consensual_Two("showing physical affection",player, target=target, style="gently", method=method,setting_name=setting_name)
        else
            Debug.Notification("Affection is not available while OStim is the active framework.")
        endif 
    elseif button == sex
        if debug_mode && main.handler_dom.IsDOMSlave(target) 
            main.handler_dom.StartScene_Consensual_Two("sexual activities", target, player, player)
        else
            actions.StartScene_Consensual_Two("sexual activities", player, target)
        endif 
    elseif button == rapes_player
        if debug_mode && main.handler_dom.IsDOMSlave(target) 
            ; slave (speaker) assaults player (target); speaker is not the victim
            main.handler_dom.StartScene_Nonconsensual_Two_TargetVictim("sexual assault", target, player, player)
        else
            actions.StartScene_Nonconsensual_Two_SpeakerVictim("sexual assault", player, target)
        endif 
    elseif button == raped_by_player
        if debug_mode && main.handler_dom.IsDOMSlave(target) 
            main.handler_dom.StartScene_Nonconsensual_Two_SpeakerVictim("sexual assault", target, player, player)
        else
            actions.StartScene_Nonconsensual_Two_TargetVictim("sexual assault",player, target)
        endif 
    elseif button == bondage
        EventSend_UDNG("MenuOpen", target)
    elseif leash != -1 && button == leash
        EventSend_LeashedOpen()
    endif 
EndFunction

Function EventSend_OstimNet(String type, Actor speaker, Actor target, String tag)
    int handle = ModEvent.Create("SkyrimNet_SexLab_OStimNet_"+type)
    ModEvent.PushForm(handle, speaker)
    ModEvent.PushForm(handle, target)
    ModEvent.PushString(handle, tag)
    ModEvent.Send(handle)
EndFunction

Function EventSend_UDNG(String type, Actor target)
    int handle = ModEvent.Create("SkyrimNet_SexLab_UDNG_"+type)
    ModEvent.PushForm(handle, target)
    ModEvent.Send(handle)
EndFunction

Function EventSend_LeashedOpen()
    SkyrimNet_SexLab_WebUI.WebUI_CloseOverlay()
    int handle = ModEvent.Create("SkyrimNet_Leashed_OpenPanel")
    ModEvent.Send(handle)
EndFunction

Function MultiTarget_Menu_Selection(Actor player)
    String msg = "No target in crosshair, looking for nearby sexable actors"
    Debug.Notification(msg)
    Trace("MultiTarget_Menu_Selection",msg)
    
    int[] ranges = new int[5]
    ranges[0] = 100 
    ranges[1] = 200 
    ranges[2] = 400
    ranges[3] = 800
    ranges[4] = 1600

    uilistMenu listMenu = uiextensions.GetMenu("UIlistMenu") AS uilistMenu
    int i = 0
    while i < ranges.length
        listMenu.AddEntryItem(ranges[i]+" units")
        i += 1
    endwhile
    listMenu.AddEntryItem("<cancel>")
    listMenu.OpenMenu()
    int index = listMenu.GetResultInt() 
    
    if index < 0 || index > ranges.length - 1
        Trace("MultiTarget_Menu_Selection","cancelled range selection")
        return
    endif

    ; -----------------------------------------
    Trace("MultiTarget_Menu_Selection","selected index:"+index+" range:"+ranges[index])
    int scan_range = ranges[index]

    int range = 0 
    int scaler = 0
    Actor[] actors_all = new Actor[1]
    
    while actors_all.length < 2 && scaler <= 5
        range = scan_range + 100*scaler
        actors_all = MiscUtil.ScanCellActors(player, range)
        Trace("MultiTarget_Menu_Selection","scaler:"+scaler+" scan range:"+range+" found:"+actors_all.length)
        scaler += 1 
    endwhile 
   
    Trace("MultiTarget_Menu_Selection"," scan range:"+range+" found:"+actors_all.length)

    if actors_all.length < 2
        actors_all = MiscUtil.ScanCellActors(player, 2000)
        if actors_all.length == 0
            Trace("MultiTarget_Menu_Selection","No eligible actors found in the area.")
            return
        endif 
    endif 

    bool[] valid = PapyrusUtil.BoolArray(actors_all.length)
    int num_actors = 0 
    i = actors_all.length - 1

    while 0 <= i 
        if actions.BodyAnimation_IsEligible(actors_all[i], "", "") && main.sexlab.IsValidActor(actors_all[i])
            valid[i] = True
            num_actors += 1
        else 
            valid[i] = False
        endif 
        Trace("MultiTarget_Menu_Selection","i:"+i+" "+actors_all[i].GetDisplayName()+" valid:"+valid[i])
        i -= 1
    endwhile 

    if num_actors < 2
        Trace("MultiTarget_Menu_Selection","Not enough eligible actors found in the area.")
        return
    endif
    Trace("MultiTarget_Menu_Selection","Found "+num_actors+" valid actors.")

    Actor[] actors = PapyrusUtil.ActorArray(num_actors)
    String[] names = Utility.CreateStringArray(num_actors)
    int[] indexes = Utility.CreateIntArray(num_actors)
    
    i = actors_all.length - 1
    int j = 0 
    while 0 <= i
        if valid[i]
            actors[j] = actors_all[i]
            names[j] = actors[j].GetDisplayName()
            j += 1
        endif 
        i -= 1
    endwhile 

    int[] selected = new int[5]

    String cancel = "<cancel>"
    String intent = "sexual activities"
    String setting_name = ""

    int next = 0 
    bool building_list = true 
    index = 1
    listMenu = uiextensions.GetMenu("UIlistMenu") AS uilistMenu
    
    ; I couldn't compare directly to the strings button in some case
    ; so fell back on next and index :(
    bool finished = false
    while finished == false
        listMenu.ResetMenu()

        i = 0 
        String start = "start | "
        if next > 0
            while i < next 
                if i > 0 
                    start += "+"
                endif 
                start += names[selected[i]]
                i += 1
            endwhile 
        else 
            start = "select actors to: "
        endif 
        
        listMenu.AddEntryItem(start)
        listMenu.AddEntryItem("intent: '"+intent+"'>")
        listMenu.AddEntryItem("setting: '"+setting_name+"'>")

        i = 0
        while 0 <= i && i < num_actors
            bool found = false 
            j = 0 
            while j < next && !found 
                if selected[j] == i
                    found = True
                else 
                    j += 1
                endif 
            endwhile
            
            String front = "  "
            if found
                front = "- "
                indexes[i] = j
            elseif next < selected.length
                front = "+ "
                indexes[i] = -1
            endif
            listMenu.AddEntryItem(front+names[i])
            i += 1
        endwhile 

        listMenu.AddEntryItem(cancel)
        listMenu.OpenMenu()
        index = listMenu.GetResultInt()
        
        if index <= 0 
            if 0 < next 
                finished = True 
            endif 
        elseif index == 1 
            String[] buttons = new String[4] 
            buttons[0] = "showing physical affection"
            buttons[1] = "sexual activities"
            buttons[2] = "sexual assault"
            buttons[3] = "custom"

            String msg_intent = "What is the intent?"
            intent = SkyMessage.ShowArray(msg_intent, buttons, getIndex = false) as String
            
            if intent == "custom"
                UIExtensions.OpenMenu("UITextEntryMenu")
                intent = UIExtensions.GetMenuResultString("UITextEntryMenu")
                Trace("MultiTarget_Menu_Selection","custom intent: " + intent)
                if intent == ""
                    intent = "sexual activities"
                endif
            elseif intent == ""
                intent = "sexual activities"
            else 
                setting_name = ""
            endif 
        elseif index == 2
            String[] setting_names = manager.GetSceneSettings() 
            listMenu = uiextensions.GetMenu("UIlistMenu") AS uilistMenu
            listMenu.ResetMenu() 
            int idx = 0 
            while idx < setting_names.length 
                listMenu.AddEntryItem(setting_names[idx]) 
                idx += 1 
            endwhile 
            listMenu.OpenMenu()
            idx = listMenu.GetResultInt()
            if 0 <= idx && idx < setting_names.length 
                setting_name = setting_names[idx]
            else 
                setting_name = "" 
            endif 

        elseif index < num_actors + 3
            index -= 3
            ; Remove only a currently-selected actor; add only when there is free
            ; capacity. When the list is full (next == selected.length) the render loop
            ; stops refreshing indexes[] for unselected rows, leaving a stale -1; without
            ; this guard clicking such a row fell into the remove branch with j = -1 and
            ; wrote selected[-1] / wrongly decremented next.
            if indexes[index] != -1
                j = indexes[index]
                while j < next - 1 
                    selected[j] = selected[j+1]
                    j += 1
                endwhile
                next -= 1
            elseif next < selected.length
                selected[next] = index
                next += 1
            endif
            if next > 0
                Trace("MultiTarget_Menu_Selection","after next:"+next+" selected[index]:"+selected[next - 1])
            endif 
        else 
            return 
        endif 
    endwhile

    Actor[] actors_selected = PapyrusUtil.ActorArray(next)
    i = 0 
    while i < next 
        actors_selected[i] = actors[selected[i]]
        i += 1 
    endwhile 
    Trace("MultiTarget_Menu_Selection","intent:"+intent+" next:"+next+" actors_selected:"+SkyrimNet_SexLab_Utilities.JoinActors(actors_selected))

    if intent == ""
        intent = "sexual activities"
    endif

    Actor speaker = actors_selected[0]
    Actor target = None 
    if next > 1 
        target = actors_selected[1]
    endif 

    String method = ""
    if intent == "comfort"
        setting_name = "nonsexual_male_position_1"
        method = "spooning"
    elseif intent == "showing physical affection" || intent == "showing affection"
        method = "spooning"
        setting_name = "nonsexual_male_position_1"
    endif 

    if intent == "sexual assault"
        SkyrimNet_SexLab_Scene_Creator creator = manager.CreateCreator(intent, actors_selected, speaker, target, setting_name="")
        if creator == None 
            Trace("MultiTarget_Menu_Selection", "CreateCreator returned None, aborting")
            return 
        endif 
        if creator.LockAllActorLock()
            creator.SetVictim(actors_selected[0])
            Creator.StartScene() 
        else 
            creator.Release()
        endif 
    else 
        SkyrimNet_SexLab_Scene_Creator creator = manager.CreateCreator(intent, actors_selected, speaker, target, tags=method, setting_name=setting_name)
        if creator == None 
            Trace("MultiTarget_Menu_Selection", "CreateCreator returned None, aborting")
            return 
        endif 
        if creator.LockAllActorLock()
            Creator.StartScene() 
        else 
            creator.Release()
        endif 
    endif 
EndFunction

String Function SexRapeSelection(String current)
    uilistMenu listMenu = uiextensions.GetMenu("UIlistMenu") AS uilistMenu
    listMenu.ResetMenu()
    listMenu.AddEntryItem("sex")
    listMenu.AddEntryItem("rape")
    listMenu.OpenMenu()
    int index = listMenu.GetResultInt() 
    if index == 0
        return "sex>"
    elseif index == 1
        return "rape>"
    endif
    return current
EndFunction
; Soft C++ gate + StorageUtil scene lock + SexLab IsValidActor (pre-check 3D to avoid WaitMenuMode).
bool Function IsAvailableActor(Actor akActor)
    if akActor == None
        return false
    endif
    if !SkyrimNet_SexLab_WebUI.IsAvailableActor(akActor)
        return false
    endif
    if StorageUtil.HasIntValue(akActor, "skyrimnet_sexlab_scene_actor_lock")
        return false
    endif
    if !akActor.Is3DLoaded()
        return false
    endif
    if main == None || main.sexlab == None
        return false
    endif
    return main.sexlab.IsValidActor(akActor)
EndFunction

; C++ ProcessLists CSV of form IDs -> filter -> SetNearbyActorsJson (names resolved in C++).
Function WebUI_PushAvailableNearby(String formIdCsv)
    if formIdCsv == ""
        SkyrimNet_SexLab_WebUI.SetNearbyActorsJson("[]")
        return
    endif

    String[] parts = StringUtil.Split(formIdCsv, ",")
    if parts == None || parts.Length == 0
        SkyrimNet_SexLab_WebUI.SetNearbyActorsJson("[]")
        return
    endif

    String json = "["
    int n = 0
    int i = 0
    while i < parts.Length
        if parts[i] != ""
            int formId = parts[i] as int
            Actor ak = Game.GetFormEx(formId) as Actor
            if ak && IsAvailableActor(ak)
                if n > 0
                    json += ","
                endif
                json += "{\"formId\":" + formId + "}"
                n += 1
            endif
        endif
        i += 1
    endwhile
    json += "]"
    SkyrimNet_SexLab_WebUI.SetNearbyActorsJson(json)
EndFunction
