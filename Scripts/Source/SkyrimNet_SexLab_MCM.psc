Scriptname SkyrimNet_SexLab_MCM extends SKI_ConfigBase

SkyrimNet_SexLab_Main Property main Auto
SkyrimNet_SexLab_Stages Property stages Auto
SkyrimNet_SexLab_Scene_Manager Property manager Auto
SkyrimNet_SexLab_Actions Property actions Auto
SkyrimNet_SexLab_Menu Property menu Auto

GlobalVariable Property sexlab_public_sex_accepted Auto
GlobalVariable Property skyrimnet_sexlab_hide_hermaphrodites Auto

String page_options = "options"

bool hot_key_toggle = False
int sex_edit_key = 43
bool rape_actions_unregistered = False

String[] Property sexlab_ostim_options Auto

bool Property udng_found = false Auto
bool Property leashed_found = false Auto

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

    if Game.GetModByName("SkyrimNetUDNG.esp") != 255
        udng_found = True
    else
        udng_found = False
    endif

    leashed_found = Game.GetFormFromFile(0x800, "SkyrimNet_Leashed.esp") != None
    Trace("Setup", "leashed_found: "+leashed_found)

    UnRegisterForModEvent("SkyrimNet_OnPluginConfigSaved")
    RegisterForModEvent("SkyrimNet_OnPluginConfigSaved", "OnPluginConfigSaved")

    ApplyPluginConfig()
    Trace("Setup", "complete")
EndFunction

Bool Function Setup_CheckLinks()
    Bool links_ok = true

    if main == None
        main = (self as Quest) as SkyrimNet_SexLab_Main
        if main == None
            links_ok = false
        endif
    endif

    if stages == None
        stages = (self as Quest) as SkyrimNet_SexLab_Stages
        if stages == None
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
    if main == None || stages == None
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

    main.rape_allowed = SkyrimNetApi.GetConfigBool(PLUGIN_CONFIG, "sexlab.actions.rape_allowed", true)
    main.sex_edit_tags_player = SkyrimNetApi.GetConfigBool(PLUGIN_CONFIG, "sexlab.tags.player", true)
    main.sex_edit_tags_nonplayer = SkyrimNetApi.GetConfigBool(PLUGIN_CONFIG, "sexlab.tags.nonplayer", false)
    main.orgasm_delay = SkyrimNetApi.GetConfigFloat(PLUGIN_CONFIG, "sexlab.orgasm.delay", 5.0)
    main.direct_narration_cool_off = SkyrimNetApi.GetConfigFloat(PLUGIN_CONFIG, "sexlab.narration.cooldown", 20.0)
    main.direct_narration_max_distance = SkyrimNetApi.GetConfigFloat(PLUGIN_CONFIG, "sexlab.narration.max_distance", 15.0)
    main.direct_narration_max_distance_default = 15.0
    stages.hide_help = SkyrimNetApi.GetConfigBool(PLUGIN_CONFIG, "sexlab.editor.hide_help", false)

    ApplyRapeActions()
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

Function ApplyHotkey()
    UnregisterForKey(sex_edit_key)
    hot_key_toggle = SkyrimNetApi.GetConfigBool(PLUGIN_CONFIG, "sexlab.editor.hotkey_enabled", false)
    int vk = SkyrimNetApi.GetConfigInt(PLUGIN_CONFIG, "sexlab.editor.hotkey", 220)
    ; Pre-VK default was DX 43 (backslash). Dashboard type:hotkey now stores VK 220.
    if vk == 43
        Trace("ApplyHotkey", "--- leftover DX 43 mapped to VK 220")
        vk = 220
    endif
    sex_edit_key = SkyrimNet_SexLab_Utilities.VkToDxScanCode(vk)
    if hot_key_toggle && sex_edit_key > 0
        RegisterForKey(sex_edit_key)
        Trace("ApplyHotkey", "--- registered enabled:"+hot_key_toggle+" vk:"+vk+" dx:"+sex_edit_key)
    else
        Trace("ApplyHotkey", "--- skipped enabled:"+hot_key_toggle+" vk:"+vk+" dx:"+sex_edit_key)
    endif
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
    SetCursorFillMode(LEFT_TO_RIGHT)
    SetCursorPosition(0)
    AddHeaderOption("SkyrimNet plugin settings")
    AddHeaderOption("")
    AddTextOptionST("DashboardHint", "Configure in SkyrimNet dashboard", "Plugins")
EndFunction

State DashboardHint
    Event OnHighlightST()
        SetInfoText("Change SexLab options in the SkyrimNet dashboard under plugin SkyrimNet_SexLab (goodprovider.sexlab). Saving there rebinds the Start Sex hotkey immediately. The default is backslash (\\).")
    EndEvent
EndState

Event OnKeyDown(int key_code)
    Trace("OnKeyDown", "key_code: "+key_code)
    if UI.IsTextInputEnabled()
        return
    endif
    if sex_edit_key == key_code
        if !menu
            Trace("OnKeyDown", "menu is None; hotkey ignored", true)
            return
        endif
        menu.ProcessHotkey(key_code)
    endif
EndEvent
