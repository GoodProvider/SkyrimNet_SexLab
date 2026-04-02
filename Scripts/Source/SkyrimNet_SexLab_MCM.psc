Scriptname SkyrimNet_SexLab_MCM extends SKI_ConfigBase

import SkyrimNet_SexLab_Actions
import SkyrimNet_SexLab_Utilities

int rape_toggle
GlobalVariable Property sexlab_public_sex_accepted Auto

SkyrimNet_SexLab_Main Property main Auto  
SkyrimNet_SexLab_Stages Property stages Auto 
SkyrimNet_SexLab_Actions Property actions Auto 

bool hot_key_toggle = False 
int sex_edit_key = 43 ; 26

bool dom_debug_toggle = False 
int dom_debug_key = 41

bool clear_JSON = False

; Devious Device Support 
Quest group_devices = None

; DOM Support 
Quest d_api = None 
Quest dom_main = None 

; OstimNet Support 
int ostimnet_player_menu = -1
int ostimnet_nonplayer_menu = -1
int ostimnet_affection_menu = -1

Quest Property ostimnet_actions Auto 

Function Trace(String func, String msg, Bool notification=False) global
    msg = "[SkyrimNet_SexLab_MCM."+func+"] "+msg
    Debug.Trace(msg) 
    if notification
        Debug.Notification(msg)
    endif 
EndFunction

String page_options = "options"
String page_actors = "actors debug (can be slow)"

; OstimNet found 
String[] sexlab_ostim_options 

int Property sexlab_ostim_player_menu Auto  ; menu id 
int Property sexlab_ostim_nonplayer_menu Auto  ; menu id 

Function Setup() 
    actions = (main as Quest) as SkyrimNet_SexLab_Actions
    if MiscUtil.FileExists("Data/TT_OStimNet.esp")
        ostimnet_actions = Game.GetFormFromFile(0x800, "TT_OStimNet.esp") as Quest
    endif 

    if sexlab_ostim_options.length == 0
       sexlab_ostim_options = new String[2]
       sexlab_ostim_options[0] = "SexLab"
       sexlab_ostim_options[1] = "Ostim" 
      ; sexlab_ostim_options[2] = "Choose each time"
    endif 

    ; -------------------------------
    ; Checks for Devious Support mod 
    if MiscUtil.FileExists("Data/SkyrimNetUDNG.esp")
        Trace("SetUp","found SkyrimNetUDNG.esp")
        group_devices = Game.GetFormFromFile(0x800, "SkyrimNetUDNG.esp") as Quest
    else 
        group_devices = None 
    endif

    ; -------------------------------
    ; Check if SkyrimNet_DOM is installed and the target is a slave
    if MiscUtil.FileExists("Data/DiaryOfMine.esm")
        Trace("SetUp","found DiaryOfMine.esm")
        d_api = Game.GetFormFromFile(0x00000D61, "DiaryOfMine.esm") as Quest
    else 
        d_api = None 
    endif 
    if MiscUtil.FileExists("Data/SkyrimNet_DOM.esp")
        Trace("SetUp","found SkyrimNet_DOM.esp")
        dom_main = Game.GetFormFromFile(0x800, "SkyrimNet_DOM.esp") as Quest
    else 
        dom_main = None 
    endif 

EndFunction 


Event OnConfigOpen()

    Pages = new String[1]
    pages[0] = page_options
    ;pages[1] = page_actors

EndEvent

;-----------------------------------------------------------------
; Create Pages 
;-----------------------------------------------------------------

Event OnPageReset(string page)
    if page == page_actors
        PageActors() 
    else 
        PageOptions() 
    endif 
EndEvent 

Function PageOptions() 
    if stages == None 
       stages = Game.GetFormFromFile(0x800, "SkyrimNet_SexLab.esp") as SkyrimNet_SexLab_Stages
    endif

    SetCursorFillMode(LEFT_TO_RIGHT)
    SetCursorPosition(0)
    AddHeaderOption("Prompt Options")
    SetCursorPosition(2)

    AddToggleOptionST("HideDialogueHistoricInstructionsToggle","Hide dialogue historic instructions",main.hide_dialogue_historic_instructions)
    AddToggleOptionST("HideHermaphroditesToggle","Hide hermaphrodite from prompt",main.hide_hermaphrodites)
    AddToggleOptionST("PublicSexAcceptedToggle","Public sex accepted",sexlab_public_sex_accepted.GetValue() == 1.0)
    AddToggleOptionST("VirginBloodEnabled","Enable virgin blood message.",main.virgin_blood_enabled)
    
    SetCursorPosition(6)
    AddHeaderOption("Rape Options")
    SetCursorPosition(8)
    AddToggleOptionST("RapeAllowedToggle","Add rape actions (must toggle/save/reload)",main.rape_allowed)

    SetCursorPosition(10)
    AddHeaderOption("Tag Edit")
    SetCursorPosition(12)
    AddToggleOptionST("SexEditTagsPlayer","Show Tags_Editor for player sex",main.sex_edit_tags_player)
    AddToggleOptionST("SexEditTagsNonPlayer","Show Tags_Editor for nonplayer sex",main.sex_edit_tags_nonplayer)

    AddHeaderOption("Sex Description Editor")
    SetCursorPosition(16)
    AddToggleOptionST("HotKeyToggle","Enable the Start Sex / Edit Stage hot key",hot_key_toggle)
    AddKeyMapOptionST("SexEditKeySet", "Start Sex / Edit Stage Description", sex_edit_key)
;    AddToggleOptionST("SexEdithelpToggle","Hide Edit Stage Description Help",stages.hide_help)
;    AddTextOption("","")

    
    SetCursorPosition(18)
    AddHeaderOption("Direction Narration Blocking")
    AddHeaderOption("")
    AddSliderOptionST("NarrationCoolOff", "Narration cooldown", main.direct_narration_cool_off)
    AddSliderOptionST("NarrationMaxDistance", "Narration max distance", main.direct_narration_max_distance)

    ;if dom_main != None 
        ;AddHeaderOption("                              ")
        ;AddHeaderOption("Debug")
        ;AddHeaderOption("")
        ;AddToggleOptionST("DomDebugToggle","Enable DOM debugs",dom_debug_toggle)
    ;Endif 

    if hot_key_toggle 
        RegisterForKey(sex_edit_key)
    endif 

    if main.ostimnet_found
        Trace("PageOptions"," index: "+main.sexlab_ostim_player+" label: "+sexlab_ostim_options[main.sexlab_ostim_player])
        AddHeaderOption("OstimNet Integration")
        AddHeaderOption("")
        ostimnet_player_menu = AddMenuOption("sex framework:", sexlab_ostim_options[main.sexlab_ostim_player])
        ; ostimnet_affection_menu = AddMenuOption("hug framework:", sexlab_ostim_options[main.sexlab_ostim_affection])
        ; ostimnet_nonplayer_menu = AddMenuOption("sex without player:", sexlab_ostim_options[main.sexlab_ostim_player])
    endif 
EndFunction 

Function PageActors() 
    SetCursorFillMode(LEFT_TO_RIGHT)
    SetCursorPosition(0)

    AddHeaderOption("Actors")
    AddHeaderOption("")

    int actor_infos = JFormMap.object() 

    ; Get all the actors who have been stripped 
    int i = 0 
    int count = main.nude_refs.Length
    while i < count 
        Actor akActor = main.nude_refs[i].GetActorReference()
        if akActor != None 
            JFormMap.setStr(actor_infos, akActor, "undressed")
        endif 
        i += 1
    endwhile 

    ; Get all the actors who are been locked 
    Form[] forms = JFormMap.allKeysPArray(main.actorLock)
    i = forms.length - 1
    while 0 <= i 
        String info = JFormMap.getStr(actor_infos, forms[i], "") 
        if info != "" 
            info += ", "
        endif 
        Float minute_scaler = 24*60
        Float time = JFormMap.getFlt(main.actorLock, forms[i])
        info += "locked: "+(time*minute_scaler)+"/"+(main.actorLocktimeout*minute_scaler)
        i -= 1
    endwhile

    ; Print out the combined list 
    forms = JFormMap.allKeysPArray(actor_infos) 
    i = forms.length - 1
    while 0 <= i 
        Actor akActor = forms[i] as Actor 
        String info = JFormMap.getStr(actor_infos, forms[i], "") 
        AddTextOptionST("ActorInfo", akActor.GetDisplayName(),info)
        i -= 1
    endwhile 
    
EndFunction 

State ActorInfo
    Event OnHighlightST()
        SetInfoText("Actors who have state stored by SkyrimNet_SexLab." \
            +" undressed: SNSL keeping undressed. locked: locked by actorLock.")
    EndEvent
EndState

;-----------------------------------------------------------------
; Prompt Toggles 
;-----------------------------------------------------------------
State PublicSexAcceptedToggle
    Event OnSelectST()
        Bool public_bool = False
        if sexlab_public_sex_accepted.GetValue() == 1.0
            public_bool = False
            sexlab_public_sex_accepted.SetValue(0.0)
        else
            public_bool = True
            sexlab_public_sex_accepted.SetValue(1.0)
        endif 
        SetToggleOptionValueST(public_bool)
        Trace("PublicSexAcceptedToggle","sexlab_public: "+sexlab_public_sex_accepted.GetValue())
    EndEvent
    Event OnHighlightST()
        SetInfoText("Makes public sex a socially accepted activity..")
    EndEvent
EndState

State HideDialogueHistoricInstructionsToggle 
    Event OnSelectST()
        Bool public_bool = False
        if main.hide_dialogue_historic_instructions
            public_bool = False
            main.hide_dialogue_historic_instructions= false
        else
            public_bool = True
            main.hide_dialogue_historic_instructions= true
        endif 
        SetToggleOptionValueST(public_bool)
        Trace("HideDialogueHistoricInstructionsToggle","hide_dialogue_historic_instructions: "+main.hide_dialogue_historic_instructions)
    EndEvent
    Event OnHighlightST()
        SetInfoText("Hides the dialogue Skyrim/Fantasy instructions from the prompt.")
    EndEvent
EndState

State HideHermaphroditesToggle 
    Event OnSelectST()
        Bool public_bool = False
        if main.hide_hermaphrodites
            public_bool = False
            main.hide_hermaphrodites = false
        else
            public_bool = True
            main.hide_hermaphrodites = true
        endif 
        SetToggleOptionValueST(public_bool)
        Trace("HideHermaphroditesToggle","hide_hermaphrodites: "+main.hide_hermaphrodites)
    EndEvent
    Event OnHighlightST()
        SetInfoText("Hides the hermaphrodite labels the prompt.")
    EndEvent
EndState

;-----------------------------------------------------------------
; Set Toggles 
;-----------------------------------------------------------------
State RapeAllowedToggle
    Event OnSelectST()
        main.rape_allowed = !main.rape_allowed
        SetToggleOptionValueST(main.rape_allowed)
    EndEvent
    Event OnHighlightST()
        SetInfoText("Adds/Removes the NPC rape Actions. Request you save and reload.")
    EndEvent
EndState

State SexEditTagsPlayer
    Event OnSelectST()
        main.sex_edit_tags_player = !main.sex_edit_tags_player
        SetToggleOptionValueST(main.sex_edit_tags_player)
    EndEvent
    Event OnHighlightST()
        SetInfoText("Opens a tag editor for sex which includes the player.")
    EndEvent
EndState

State SexEditTagsNonPlayer
    Event OnSelectST()
        main.sex_edit_tags_nonplayer = !main.sex_edit_tags_nonplayer
        SetToggleOptionValueST(main.sex_edit_tags_nonplayer)
    EndEvent
    Event OnHighlightST()
        SetInfoText("Opens a tag editor for sex not including player.")
    EndEvent
EndState

State VirginBloodEnabled
    Event OnSelectST()
        main.virgin_blood_enabled = !main.virgin_blood_enabled
        SetToggleOptionValueST(main.virgin_blood_enabled)
    EndEvent
    Event OnHighlightST()
        SetInfoText("Add virgin blood to the first time pussy or anal sex.")
    EndEvent
EndState

; --------------------------------------------
; Hot Keys 
; --------------------------------------------

State HotKeyToggle
    Event OnSelectST()
        hot_key_toggle = !hot_key_toggle
        SetToggleOptionValueST(hot_key_toggle)
        if !hot_key_toggle
            UnregisterForKey(sex_edit_key)
        else
            RegisterForKey(sex_edit_key)
        endif
        ForcePageReset()
    EndEvent
    Event OnHighlightST()
        SetInfoText("Enables the Sex Edit Hotkey.\n")
    EndEvent
EndState

State SexEditKeySet
    Event OnKeyMapChangeST(int keyCode, string conflictControl, string conflictName)
        Trace("SexEditKeySet","keyCode: "+keyCode+" conflictControl: "+conflictControl+" conflictName: "+conflictName)
        bool continue = True
        if conflictControl != "" 
            String msg = None 
            if (conflictName != "")
                msg = "This key is already mapped to:\n'" + conflictControl + "'\n(" + conflictName + ")\n\nAre you sure you want to continue?"
            else
                msg = "This key is already mapped to:\n'" + conflictControl + "'\n\nAre you sure you want to continue?"
            endIf

            continue = ShowMessage(msg, true, "$Yes", "$No")
        endif 
        if continue 
            UnregisterForKey(sex_edit_key)
            sex_edit_key = keyCode
            RegisterForKey(sex_edit_key)
            SetKeymapOptionValueST(sex_edit_key)
        endif 
    EndEvent
    Event OnHighlightST()
        SetInfoText( \
            "For an actor in the crosshair and not in a sex animation, it will allow you to start a sex animation.\n" \
          + "For an actor in the crosshair and in a sex animation, it will open a stage description editor for that animation.\n" \
          + "Without any actor in the crosshair, it will allow you to start sex between a near by set of eligible actors.")
    EndEvent
EndState

State SexEditHelpToggle
    Event OnSelectST()
        stages.hide_help = !stages.hide_help
        SetToggleOptionValueST(stages.hide_help)
        ForcePageReset()
    EndEvent
    Event OnHighlightST()
        SetInfoText("Hides the help dialogue that appears if no stage description is found.\n")
    EndEvent
EndState

;-----------------------------------------------------------------
; Direct Narration 
;-----------------------------------------------------------------

State NarrationCoolOff
    Event OnSliderOpenST()
        SetSliderDialogStartValue(main.direct_narration_cool_off)
        SetSliderDialogDefaultValue(50)
        SetSliderDialogRange(1, 120)
        SetSliderDialogInterval(1)
    EndEvent
    Event OnSliderAcceptST(float value) 
        main.direct_narration_cool_off = value 
        SetSliderDialogStartValue(main.direct_narration_cool_off)
        ForcePageReset()
    EndEvent
    Event OnHighlightST()
        SetInfoText("Minimum number of seconds since last audio ended before next optional Direct Narration.\n")
    EndEvent
EndState
State NarrationMaxDistance
    Event OnSliderOpenST()
        SetSliderDialogStartValue(main.direct_narration_max_distance)
        SetSliderDialogDefaultValue(main.direct_narration_max_distance_default)
        SetSliderDialogRange(5, 100)
        SetSliderDialogInterval(1)
    EndEvent
    Event OnSliderAcceptST(float value) 
        main.direct_narration_max_distance = value 
        SetSliderDialogStartValue(main.direct_narration_max_distance)
        ForcePageReset()
    EndEvent
    Event OnHighlightST()
        SetInfoText("Maximum distance in meters that could generate a new direct narration.\n")
    EndEvent
EndState

; --------------------------------------------
; Dom Debug Hotkey
; --------------------------------------------
State DomDebugToggle
    Event OnSelectST()
        dom_debug_toggle = !dom_debug_toggle
        SetToggleOptionValueST(dom_debug_toggle)
        ForcePageReset()
    EndEvent
    Event OnHighlightST()
        SetInfoText("Adds the DOM debug option to the hotkey.\n")
    EndEvent
EndState

;-----------------------------------------------------------------
; OstimNet Integration
; https://github.com/schlangster/skyui/wiki/MCM-Option-Types
; https://www.nexusmods.com/skyrimspecialedition/articles/925
;-----------------------------------------------------------------
Event OnOptionMenuOpen(int menu_id)
    Trace("OnOptionMenuOpen","menu_id: "+menu_id+" options: "+sexlab_ostim_options)
    SetMenuDialogOptions(sexlab_ostim_options)
    if menu_id == ostimnet_player_menu
        SetMenuDialogStartIndex(main.sexlab_ostim_player)
    elseif menu_id == ostimnet_affection_menu
        SetMenuDialogStartIndex(main.sexlab_ostim_affection)
    endif
    SetMenuDialogDefaultIndex(0)
endEvent

event OnOptionMenuAccept(int menu_id, int index)
    if menu_id == ostimnet_player_menu
        main.sexlab_ostim_player = index
    elseif menu_id == ostimnet_affection_menu 
        main.sexlab_ostim_affection = index
    endif 
    Trace("OnOptionMenuAccept"," menu_id: "+menu_id+" sexlab_ostim_player: "+main.sexlab_ostim_player+" label: "+sexlab_ostim_options[main.sexlab_ostim_player]\
        +" sexlab_ostim_affection: "+main.sexlab_ostim_affection+" label: "+sexlab_ostim_options[main.sexlab_ostim_affection])
    SetMenuOptionValue(menu_id, sexlab_ostim_options[index])
endEvent

; --------------------------------------------
; Handles OnKeyDown 
; --------------------------------------------

Event OnKeyDown(int key_code)
    return 
    if UI.IsTextInputEnabled()
        return 
    endif 
    if sex_edit_key == key_code
        ; Both players need to be in the crosshair to have SkyrimNet load them into the cache
        ; so the parseJsonActor works
        Actor target = Game.GetCurrentCrosshairRef() as Actor 
        Actor player = Game.GetPlayer() 
        if target == None && main.sexlab.IsActorActive(player)
            target = player
        endif 
        bool target_not_none = target != None
        Trace("OnKeyDown","target_not_none: "+target_not_none)
        if target != None 
            if main.sexlab.IsActorActive(target)
                Trace("OnKeyDown","target: "+target.getDisplayName()+" in active sex")
                sslThreadController thread = main.GetThread(target)
                if thread != None
                    Trace("OnKeyDown", "thread found "+thread.tid+" for target:"+target.GetDisplayName())
                    stages.EditDescriptions(thread)
                else
                    Trace("OnKeyDown","failed to find thread for target:"+target.GetDisplayName())
                endif
            elseif SkyrimNet_SexLab_Actions.BodyAnimation_IsEligible(target, "", "") && main.sexlab.IsValidActor(target)
            endif 
        else 
            MutliTarget_Menu_Selection(player)
        endif 
    endif 
EndEvent 

Function Target_Menu_Selection(Actor target, Actor player)
    
    if d_api != None && (d_api as DOM_API).IsDOMSlave(target) 
        SkyrimNet_DOM_Menu.Target_Menu_Selection(target,player)
        return 
    endif 

    ;if slave != None && dom_main != None 
        ;dom_main.SelectPlayerAction(target, slave) 
        ;return 
    ;endif 

    bool target_is_undressed = false 
    target_is_undressed = main.HasStrippedItems(target)
    String clothing_string = "undress"
    if target_is_undressed 
        clothing_string = "dress"
    endif 
    int sexlab_ostim = 0
    int masturbate = 1
    int affection = 2
    int sex = 3
    int raped_by_player = 4
    int rapes_player = 5
    int clothing = 6
    int cancel = 7

    int cuddle = -2 
    int bondage = -2
    int dom_debug = -2 
    if main.cuddle_found 
        cuddle = cancel
        cancel += 1
    endif 
    if group_devices != None 
        bondage = cancel
        cancel += 1 
    endif  
    if dom_main != None && dom_debug_toggle
        dom_debug = cancel
        cancel += 1 
    endif  
    String[] buttons = Utility.CreateStringArray(cancel+1)

    buttons[sexlab_ostim] = sexlab_ostim_options[main.sexlab_ostim_player]
    buttons[masturbate] = "masturbate"
    buttons[affection] = "affection"
    buttons[sex] = "sex"
    buttons[raped_by_player] = "player rapes"
    buttons[rapes_player] = "rapes player"
    buttons[clothing] = clothing_string
    if cuddle != -2 
        buttons[cuddle] = "cuddle"
    endif
    if bondage != -2 
        buttons[bondage] = "bondage"
    endif 
    if dom_debug != -2 
        buttons[dom_debug] = "dom Debug"
    endif 
    buttons[cancel] = "cancel"

    String msg = "Should "+target.getDisplayName()+":"
    int button = SkyMessage.ShowArray(msg, buttons, getIndex = true) as int  

    if button >= 0 && button <= cancel
        Trace("OnKeyDown","button:" +buttons[button])
    endif 
    if button == masturbate
        if main.sexlab_ostim_player == 0
            actions.Masturbation_Start(target, "normal", "")
        else 
            (ostimnet_actions as TTON_Actions).StartSexActionExecute(target, None, None, None, None, "", "")
        endif 
    elseif button == sexlab_ostim 
        if main.sexlab_ostim_player == 0
            main.sexlab_ostim_player = 1 
        else
            main.sexlab_ostim_player = 0 
        endif 
        Target_Menu_Selection(Target, Player) 
    elseif button == affection
        Trace("OnKeyDown","affection!")
        if main.sexlab_ostim_player == 0
            String[] bs = new String[2] 
            bs[0] = "hugging"
            bs[1] = "kissing"
            String tag = SkyMessage.ShowArray("select", bs, getIndex = false) as string  
            actions.Affection_Start(player, target, "normal", tag, "")
        else 
            String[] bs = new String[3] 
            bs[0] = "hugging"
            bs[1] = "kissing"
            bs[2] = "cuddling"
            String tag = SkyMessage.ShowArray("select", bs, getIndex = false) as string  
            (ostimnet_actions as TTON_Actions).StartAffectionSceneExecute(target, player, tag)
        endif 
    elseif button == sex
        if main.sexlab_ostim_player == 0
            actions.Sex_Start(player, target, "normal", "", "")
        else 
            String[] bs = new String[3] 
            bs[0] = "vaginalsex"
            bs[1] = "blowjob"
            bs[2] = "analsex"
            String tag = SkyMessage.ShowArray("select", bs, getIndex = false) as string  
            (ostimnet_actions as TTON_Actions).StartSexActionExecute(target, player, None, None, None, tag, "")
        endif 

    elseif button == rapes_player
        actions.Rape_Start(target, player, "normal", "", "", player)
    elseif button == raped_by_player
        actions.Rape_Start(player, target, "normal", "", "", target)
    elseif button == clothing

        ;--------------------------------------------------
        ; How would they like it appear? 
        buttons = new String[4] 
        buttons[main.STYLE_FORCEFULLY] = "Forcefully by player "
        buttons[main.STYLE_NORMALLY] = "By player"
        buttons[main.STYLE_GENTLY] = "Gently by player"
        buttons[main.STYLE_SILENTLY] = "( Silently )"

        button = SkyMessage.ShowArray(msg, buttons, getIndex = true) as int 
        String style = "normally"
        String narration = "direct"
        if button == main.STYLE_SILENTLY
            narration = "none"
        elseif button == main.STYLE_GENTLY 
            style = "gently"
        elseif button == main.STYLE_FORCEFULLY 
            style = "forcefully"
        endif 

        ;--------------------------------------------------
        ; Now do the action 
        Trace("Target_Menu_Selection","style:"+style+" clothing_string:"+clothing_string)
        actions.Change_Outfit(target, player, style, clothing_string+"es", narration)

    elseif button == cuddle 
        SkyrimNet_Cuddle_API.OpenMenu(player, target) 
    elseif button == bondage 
        (group_devices as skyrimnet_UDNG_Groups).UpdateDevices(target) 
    endif 
EndFunction

Function MutliTarget_Menu_Selection(Actor player)
    ; If not, then we allow them to start a sex animation with nearby actors
    String msg = "No target in crosshair, looking for nearby sexable actors"
    Debug.Notification(msg)
    Trace("MultiTarget_Menu_Selection",msg)
    ;float time_last = Utility.GetCurrentRealTime()
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
        if SkyrimNet_SexLab_Actions.BodyAnimation_IsEligible(actors_all[i], "", "") && main.sexlab.IsValidActor(actors_all[i])
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
    String type = "sex>"

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
        listMenu.AddEntryItem(type)

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
            if type == "sex>"
                type = "rape>"
            Else
                type = "sex>"
            endif 
        elseif index < num_actors + 2
            index -= 2
            if indexes[index] == -1 
                selected[next] = index
                next += 1
            else
                j = indexes[index]
                while j < next - 1 
                    selected[j] = selected[j+1]
                    j += 1
                endwhile
                next -= 1
            endif
            if next > 0
                Trace("MultiTarget_Menu_Selection","after next:"+next+" selected[index]:"+selected[next - 1])
            endif 
        else 
            return 
        endif 
    endwhile

    Actor[] group = PapyrusUtil.ActorArray(next)
    i = 0 
    while i < next 
        group[i] = actors[selected[i]]
        i += 1 
    endwhile 
    Trace("MultiTarget_Menu_Selection","type:"+type+" next:"+next+" group:"+SkyrimNet_SexLab_Utilities.JoinActors(group))

    if type == "cuddle>"
        if next < 2
            Trace("MultiTarget_Menu_Selection","Not enough actors selected for cuddling.")
            Debug.Notification("Select at least 2 actors to cuddle.")
            return
        endif
        SkyrimNet_Cuddle_API.StartCuddling(group[0], group[1])
    else 
        if next == 1
            actions.Masturbation_Start(group[0], "normal", "")
        else 
            String json = "{\"target\":\""+group[1].GetDisplayName()+"\""
            i = 2 
            while i < next 
                j = i - 2
                json += ", \"participate_"+j+"\":\""+group[i].GetDisplayName()+"\""
                i += 1
            endwhile
            json += "}"

            String rape_victim = "None" 
            if type == "rape>"
                Actor[] victims = new Actor[1]
                victims[0] = group[0]
                actions.Sex_Start_Helper(group[1], group, victims, "normal", "", "", "")
            else 
                Actor[] victims = PapyrusUtil.ActorArray(0) 
                actions.Sex_Start_Helper(group[1], group, victims, "normal", "", "", "")
            endif   
        endif 
    endif 
EndFunction

String Function SexRapeSelection()
    uilistMenu listMenu = uiextensions.GetMenu("UIlistMenu") AS uilistMenu
    listMenu.ResetMenu()
    listMenu.AddEntryItem("sex")
    listMenu.AddEntryItem("rape")
    if main.cuddle_found 
        listMenu.AddEntryItem("cuddle")
    endif 
    listMenu.OpenMenu()
    int index = listMenu.GetResultInt() 
    if index == 0
        return "sex>"
    elseif index == 1
        return "rape>"
    else 
        return "cuddle>"
    endif
EndFunction
