Scriptname SkyrimNet_SexLab_MCM extends SKI_ConfigBase

SkyrimNet_SexLab_Main Property main Auto
SkyrimNet_SexLab_AnimDb Property animdb Auto
SkyrimNet_SexLab_Scene_Manager Property manager Auto
SkyrimNet_SexLab_Actions Property actions Auto
SkyrimNet_SexLab_Menu Property menu Auto

; Kept for Menu.psc framework labels / global wrapper (C++ syncs control store → global).
GlobalVariable Property skyrimnet_sexlab_ostim_player Auto
int Property sexlab_ostim_player
    int Function Get()
        return skyrimnet_sexlab_ostim_player.GetValueInt()
    EndFunction
    Function Set(int value)
        skyrimnet_sexlab_ostim_player.SetValue(value)
    EndFunction
EndProperty

GlobalVariable Property sexlab_public_sex_accepted Auto
GlobalVariable Property skyrimnet_sexlab_hide_hermaphrodites Auto

String page_options = "options"
String[] Property sexlab_ostim_options Auto
bool Property udng_found = false Auto
bool Property leashed_found = false Auto

; DX scancode hotkey (SkyUI KeyMap). Live override via WebUI_SetHotkey.
bool hot_key_toggle = False
int sex_edit_key = 43 ; backslash \
bool rape_actions_unregistered = False

string newline = ""

String PLUGIN_CONFIG = "Plugin_SkyrimNet_SexLab"

Function Trace(String func, String msg, Bool notification=False) global
    String logged = SkyrimNet_SexLab_WebUI.TraceLog("SkyrimNet_SexLab_MCM", func, msg)
    if notification
        Debug.Notification(logged)
    endif
EndFunction

Function Setup()
    Bool links_ok = Setup_CheckLinks()
    if !links_ok
        return
    endif

    if !sexlab_ostim_options
       sexlab_ostim_options = new String[2]
       sexlab_ostim_options[0] = "SexLab"
       sexlab_ostim_options[1] = "Ostim"
    endif

    if Game.GetModByName("Devious Devices - Assets.esm") != 255
        udng_found = True
    else
        udng_found = False
    endif

    leashed_found = Game.GetFormFromFile(0x800, "SkyrimNet_Leashed.esp") != None
    Trace("Setup", "leashed_found: "+leashed_found)

    UnRegisterForModEvent("SkyrimNet_OnPluginConfigSaved")
    RegisterForModEvent("SkyrimNet_OnPluginConfigSaved", "OnPluginConfigSaved")

    ApplyPluginConfig()
    Trace("Setup", "complete hotkey enabled="+hot_key_toggle+" dx="+sex_edit_key)
EndFunction

Bool Function Setup_CheckLinks()
    Bool links_ok = true

    if main == None
        main = (self as Quest) as SkyrimNet_SexLab_Main
        if main == None
            links_ok = false
        endif
    endif

    if animdb == None
        animdb = (self as Quest) as SkyrimNet_SexLab_AnimDb
        if animdb == None
            links_ok = false
        endif
    endif

    if manager == None
        manager = (self as Quest) as SkyrimNet_SexLab_Scene_Manager
        if manager == None
            links_ok = false
        endif
    endif

    if actions == None
        actions = (self as Quest) as SkyrimNet_SexLab_Actions
        if actions == None
            links_ok = false
        endif
    endif

    if menu == None
        menu = (self as Quest) as SkyrimNet_SexLab_Menu
        if menu == None
            links_ok = false
        endif
    endif

    return links_ok
EndFunction

Function ApplyPluginConfig()
    if main == None
        return
    endif

    if sexlab_public_sex_accepted
        if SkyrimNetApi.GetConfigBool(PLUGIN_CONFIG, "sexlab.prompt.public_sex_accepted", false)
            sexlab_public_sex_accepted.SetValue(1.0)
        else
            sexlab_public_sex_accepted.SetValue(0.0)
        endif
    endif

    if skyrimnet_sexlab_hide_hermaphrodites
        if SkyrimNetApi.GetConfigBool(PLUGIN_CONFIG, "sexlab.prompt.hide_hermaphrodites", false)
            skyrimnet_sexlab_hide_hermaphrodites.SetValue(1.0)
        else
            skyrimnet_sexlab_hide_hermaphrodites.SetValue(0.0)
        endif
    endif

    if skyrimnet_sexlab_ostim_player
        if SkyrimNetApi.GetConfigInt(PLUGIN_CONFIG, "sexlab.ostim.player", 0) != 0
            skyrimnet_sexlab_ostim_player.SetValue(1.0)
        else
            skyrimnet_sexlab_ostim_player.SetValue(0.0)
        endif
    endif

    main.rape_allowed = SkyrimNetApi.GetConfigBool(PLUGIN_CONFIG, "sexlab.actions.rape_allowed", true)
    main.sex_edit_tags_player = SkyrimNetApi.GetConfigBool(PLUGIN_CONFIG, "sexlab.tags.player", true)
    main.sex_edit_tags_nonplayer = SkyrimNetApi.GetConfigBool(PLUGIN_CONFIG, "sexlab.tags.nonplayer", false)
    main.orgasm_delay = SkyrimNetApi.GetConfigFloat(PLUGIN_CONFIG, "sexlab.orgasm.delay", 5.0)
    main.narration_max_chars = SkyrimNetApi.GetConfigInt(PLUGIN_CONFIG, "sexlab.narration.max_chars", 350)
    main.voice_follows_speaking = SkyrimNetApi.GetConfigBool(PLUGIN_CONFIG, "sexlab.voice.follow_speaking", true)
    main.direct_narration_cool_off = SkyrimNetApi.GetConfigFloat(PLUGIN_CONFIG, "sexlab.narration.cooldown", 20.0)
    main.direct_narration_max_distance = SkyrimNetApi.GetConfigFloat(PLUGIN_CONFIG, "sexlab.narration.max_distance", 15.0)
    main.direct_narration_max_distance_default = 15.0
    if animdb
        animdb.hide_help = SkyrimNetApi.GetConfigBool(PLUGIN_CONFIG, "sexlab.editor.hide_help", false)
    endif

    ApplyRapeActions()
    ; Engine first: ApplyMiniGameActions reads the enjoyment mode from it.
    SkyrimNet_SexLab_OrgasmEngine.ReloadConfig()
    ApplyMiniGameActions()
    ApplyHotkey()
    Trace("ApplyPluginConfig", "rape_allowed:"+main.rape_allowed+" cool_off:"+main.direct_narration_cool_off+" hotkey:"+sex_edit_key+" enabled:"+hot_key_toggle)
EndFunction

Function ApplyRapeActions()
    if main.rape_allowed
        if rape_actions_unregistered
            Trace("ApplyRapeActions", "rape re-enabled; save and reload to restore LLM actions")
        endif
        return
    endif
    if rape_actions_unregistered
        return
    endif
    SkyrimNetApi.UnregisterAction("SexLab_Sexual_Assault_Target")
    SkyrimNetApi.UnregisterAction("SexLab_Sexual_Assault_Speaker")
    SkyrimNetApi.UnregisterAction("SexLab_Punish_Rape_Target")
    SkyrimNetApi.UnregisterAction("SexLab_Punish_Rape_Target_By_Target")
    SkyrimNetApi.UnregisterAction("SexLab_Masturbation_Forced")
    rape_actions_unregistered = True
    Trace("ApplyRapeActions", "unregistered rape LLM actions")
EndFunction

; Orgasm mini-game LLM actions (arouse / calm and the NPC strategies) exist only in the Multi-Orgasm
; Mini-game mode (sexlab.enjoyment.mode). Switching back to it needs a save + reload for the actions.
bool minigame_actions_unregistered = False

String[] Function MiniGameActionNames()
    String[] names = new String[16]
    names[0] = "SexLab_Arouse"
    names[1] = "SexLab_Calm"
    names[2] = "SexLab_Strategy_Mutual"
    names[3] = "SexLab_Strategy_Selfish"
    names[4] = "SexLab_Strategy_Selfless"
    names[5] = "SexLab_Strategy_Passive"
    names[6] = "SexLab_Strategy_Together"
    names[7] = "SexLab_Strategy_Tease"
    names[8] = "SexLab_Strategy_Reject"
    names[9] = "SexLab_Strategy_CumQuick"
    names[10] = "SexLab_Strategy_Greedy"
    names[11] = "SexLab_Strategy_ForcedOrgasm"
    names[12] = "SexLab_Strategy_AcceptForce"
    names[13] = "SexLab_Strategy_RejectForce_Selfish"
    names[14] = "SexLab_Strategy_RejectForce_Reject"
    names[15] = "SexLab_Strategy_NonSexual"
    return names
EndFunction

Function ApplyMiniGameActions()
    bool enabled = SkyrimNet_SexLab_OrgasmEngine.IsMiniGameEnabled()
    if enabled
        if minigame_actions_unregistered
            Trace("ApplyMiniGameActions", "mini-game re-enabled; save and reload to restore LLM actions")
        endif
        return
    endif
    if minigame_actions_unregistered
        return
    endif
    String[] names = MiniGameActionNames()
    int i = 0
    while i < names.length
        if names[i] != ""
            SkyrimNetApi.UnregisterAction(names[i])
        endif
        i += 1
    endwhile
    minigame_actions_unregistered = True
    Trace("ApplyMiniGameActions", "unregistered mini-game LLM actions")
EndFunction

Function ApplyHotkey()
    hot_key_toggle = SkyrimNetApi.GetConfigBool(PLUGIN_CONFIG, "sexlab.editor.hotkey_enabled", false)
    int vk = SkyrimNetApi.GetConfigInt(PLUGIN_CONFIG, "sexlab.editor.hotkey", 220)
    ; Pre-VK default was DX 43 (backslash). Dashboard type:hotkey now stores VK 220.
    if vk == 43
        Trace("ApplyHotkey", "--- leftover DX 43 mapped to VK 220")
        vk = 220
    endif
    sex_edit_key = SkyrimNet_SexLab_Utilities.VkToDxScanCode(vk)
    ; Unbound native returns None → 0. WebUI_SetHotkey(0, true) disables the C++ KeyHandler.
    if sex_edit_key == 0
        Trace("ApplyHotkey", "--- VkToDxScanCode returned 0; fallback DX 43")
        sex_edit_key = 43
    endif
    ; C++ KeyHandler, not Papyrus RegisterForKey.
    SkyrimNet_SexLab_WebUI.WebUI_SetHotkey(sex_edit_key, hot_key_toggle)
    Trace("ApplyHotkey", "--- webui enabled:"+hot_key_toggle+" vk:"+vk+" dx:"+sex_edit_key)
EndFunction

Event OnPluginConfigSaved(string eventName, string strArg, float numArg, Form sender)
    Trace("OnPluginConfigSaved", "--- reloading plugin config")
    ApplyPluginConfig()
EndEvent

Event OnConfigOpen()
    Pages = new String[1]
    pages[0] = page_options
    ApplyPluginConfig()
EndEvent

Event OnPageReset(string page)
    PageOptions()
EndEvent

Function PageOptions()
    SetCursorFillMode(TOP_TO_BOTTOM)
    SetCursorPosition(0)

    AddHeaderOption("Settings location")
    AddTextOption("Use SkyrimNet_SexLab WebUI", "Settings panel")
    AddTextOption("  (main panel pulldown → Settings)", "")
    AddTextOption("Or SkyrimNet plugin interface", "SkyrimNet_SexLab")
    AddTextOption("  (SkyrimNet mod menu)", "")

    AddHeaderOption("Enjoyment")
    AddMenuOptionST("EnjoymentMode", "Orgasm mode", EnjoymentModeLabel())

    AddHeaderOption("Start Sex / Edit Stage hotkey")
    AddToggleOptionST("HotKeyToggle", "Enable hotkey", hot_key_toggle)
    AddKeyMapOptionST("SexEditKeySet", "Hotkey", sex_edit_key)

    AddHeaderOption("Animation database")
    String ts = "never"
    if animdb
        ts = animdb.last_rebuild_timestamp
        if ts == ""
            ts = "never"
        endif
    endif
    AddTextOption("Last rebuild", ts)
    AddTextOptionST("RebuildAnimDb", "Rebuild Animation Database", "CLICK")
EndFunction

State HotKeyToggle
    Event OnSelectST()
        hot_key_toggle = !hot_key_toggle
        SetToggleOptionValueST(hot_key_toggle)
        SkyrimNet_SexLab_WebUI.WebUI_SetHotkey(sex_edit_key, hot_key_toggle)
        ForcePageReset()
    EndEvent
    Event OnHighlightST()
        SetInfoText("Enables the PrismaUI Start Sex / Edit Stage hotkey.")
    EndEvent
EndState

State SexEditKeySet
    Event OnKeyMapChangeST(int keyCode, string conflictControl, string conflictName)
        Trace("SexEditKeySet", "keyCode: "+keyCode+" conflictControl: "+conflictControl+" conflictName: "+conflictName)
        bool continue = True
        if conflictControl != ""
            String msg
            if conflictName != ""
                msg = "This key is already mapped to:'"+ conflictControl+"'"+ newline\
                    +"(" + conflictName + ")"+newline+newline\
                    +"Are you sure you want to continue?"
            else
                msg = "This key is already mapped to:'" + conflictControl + "'"+newline+"Are you sure you want to continue?"
            endIf
            continue = ShowMessage(msg, true, "$Yes", "$No")
        endif
        if continue
            sex_edit_key = keyCode
            SkyrimNet_SexLab_WebUI.WebUI_SetHotkey(sex_edit_key, hot_key_toggle)
            SetKeymapOptionValueST(sex_edit_key)
        endif
    EndEvent
    Event OnHighlightST()
        SetInfoText( \
            "Crosshair on actor not in sex: start sex."+newline \
          + "Crosshair on actor in sex: stage description editor."+newline \
          + "No crosshair: start sex among nearby eligible actors.")
    EndEvent
EndState

; Same setting as the dashboard pulldown (sexlab.enjoyment.mode): changing either changes the other.
String MODE_TOGETHER = "Always Orgasm Together at the end"
String MODE_MINIGAME = "Multi-Orgasm Mini-game"

String Function EnjoymentModeLabel()
    if SkyrimNet_SexLab_OrgasmEngine.IsMiniGameEnabled()
        return MODE_MINIGAME
    endif
    return MODE_TOGETHER
EndFunction

String[] Function EnjoymentModeOptions()
    String[] options = new String[2]
    options[0] = MODE_TOGETHER
    options[1] = MODE_MINIGAME
    return options
EndFunction

State EnjoymentMode
    Event OnMenuOpenST()
        SetMenuDialogOptions(EnjoymentModeOptions())
        int start = 0
        if SkyrimNet_SexLab_OrgasmEngine.IsMiniGameEnabled()
            start = 1
        endif
        SetMenuDialogStartIndex(start)
        SetMenuDialogDefaultIndex(0)
    EndEvent
    Event OnMenuAcceptST(int index)
        if index < 0 || index > 1
            return
        endif
        String mode = EnjoymentModeOptions()[index]
        bool ok = SkyrimNetApi.PatchConfig(PLUGIN_CONFIG, "{ \"sexlab\": { \"enjoyment\": { \"mode\": \"" + mode + "\" } } }")
        Trace("EnjoymentMode", "mode:" + mode + " patched:" + ok)
        ApplyPluginConfig()
        SetMenuOptionValueST(EnjoymentModeLabel())
        if index == 1 && minigame_actions_unregistered
            ShowMessage("Mini-game LLM actions come back after a save and reload.", false)
        endif
    EndEvent
    Event OnDefaultST()
        OnMenuAcceptST(0)
    EndEvent
    Event OnHighlightST()
        SetInfoText(             "Always Orgasm Together: SexLab skill, Lewd/Pure, victim/aggressor and relationship shape how fast enjoyment rises; everyone reaches 100 at the end and orgasms together."+newline           + "Multi-Orgasm Mini-game: the bonus is constant; several orgasms or none. NPCs pick strategies (LLM). Also in the SkyrimNet_SexLab settings.")
    EndEvent
EndState

State RebuildAnimDb
    Event OnSelectST()
        SkyrimNet_SexLab_AnimDb adb = (main as Quest) as SkyrimNet_SexLab_AnimDb
        if adb
            adb.RebuildDatabase()
            ShowMessage("Animation database rebuild started in the background.", false)
        else
            ShowMessage("AnimDb script not found on quest.", false)
        endif
        SetTextOptionValueST("STARTED")
        ForcePageReset()
    EndEvent
    Event OnHighlightST()
        SetInfoText("Force a full rebuild of the AnimationDB from SexLab registered animations.")
    EndEvent
EndState
