Scriptname SkyrimNet_SexLab_MCM extends SKI_ConfigBase

SkyrimNet_SexLab_Main Property main Auto  
SkyrimNet_SexLab_Stages Property stages Auto 
SkyrimNet_SexLab_Scene_Manager Property manager Auto 
SkyrimNet_SexLab_Actions Property actions Auto 

int rape_toggle
GlobalVariable Property sexlab_public_sex_accepted Auto

; Whether to uses the sexlab or ostimnet options in the menu.
; sexlab = 0
; ostimnet = 1
GlobalVariable Property skyrimnet_sexlab_ostim_player Auto
int Property sexlab_ostim_player
    int Function Get()
        ;if !main.ostimnet_found
        ;    return 0
        ;endif 
        return skyrimnet_sexlab_ostim_player.GetValueInt()
    EndFunction 
    Function Set(int value)
        skyrimnet_sexlab_ostim_player.SetValue(value)
    EndFunction 
EndProperty

; Hides the hermaphrodite from prompt 
; 0 - false
; 1 - true
GlobalVariable Property skyrimnet_sexlab_hide_hermaphrodites Auto

; ------------------------
; Pages 
; ------------------------

String page_options = "options"
String page_actors = "undressed Actors"

bool hot_key_toggle = False 
int sex_edit_key = 43 ; 26

bool clear_JSON = False

; OstimNet Support 
int ostimnet_player_menu = -1
int ostimnet_nonplayer_menu = -1
int ostimnet_affection_menu = -1

String[] sexlab_ostim_options 
int Property sexlab_ostim_player_menu Auto  ; menu id 

; UDNG Support 
bool udng_found = false 
     
; Formating 
string newline = ""

Function Trace(String func, String msg, Bool notification=False) global
    msg = "[SkyrimNet_SexLab_MCM."+func+"] "+msg
    Debug.Trace(msg) 
    if notification
        Debug.Notification(msg)
    endif 
EndFunction

Function Setup() 
    if sexlab_ostim_options.length == 0
       sexlab_ostim_options = new String[2]
       sexlab_ostim_options[0] = "SexLab"
       sexlab_ostim_options[1] = "Ostim" 
    endif 

    if MiscUtil.FileExists("Data/SkyrimNetUDNG.esp") 
        udng_found = True
    else 
        udng_found = False 
    endif 

EndFunction 


Event OnConfigOpen()

    Pages = new String[2]
    pages[0] = page_options
    pages[1] = page_actors

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
    SetCursorFillMode(LEFT_TO_RIGHT)
    SetCursorPosition(0)
    AddHeaderOption("Prompt Options")
    SetCursorPosition(2)

    AddToggleOptionST("HideHermaphroditesToggle","Hide hermaphrodite from prompt",skyrimNet_sexlab_hide_hermaphrodites.GetValue() == 1.0)
    AddToggleOptionST("PublicSexAcceptedToggle","Public sex accepted",sexlab_public_sex_accepted.GetValue() == 1.0)
    AddToggleOptionST("VirginBloodEnabled","Enable virgin blood message.",main.virgin_blood_enabled)
    
    SetCursorPosition(6)
    AddHeaderOption("Rape Options")
    SetCursorPosition(8)
    AddToggleOptionST("RapeAllowedToggle","Add rape actions (must toggle/save/reload)",main.rape_allowed)

    SetCursorPosition(10)
    AddHeaderOption("Tag Edit")
    SetCursorPosition(12)
    AddToggleOptionST("SexEditTagsPlayer","Show Dialogs for player actions",main.sex_edit_tags_player)
    AddToggleOptionST("SexEditTagsNonPlayer","Show Dialogs for non-player actions",main.sex_edit_tags_nonplayer)

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

    if hot_key_toggle 
        RegisterForKey(sex_edit_key)
    endif 

    if main.ostimnet_found 
        int value = sexlab_ostim_player
        String label = sexlab_ostim_options[value]
        Trace("PageOptions"," index: "+value+" label: "+label) 
        AddHeaderOption("OstimNet Integration")
        AddHeaderOption("")
        ostimnet_player_menu = AddMenuOption("sex framework:", label)
    endif 
EndFunction 

Function PageActors() 
    AddHeaderOption("Undressed Actors")
    AddHeaderOption("")

    int count = StorageUtil.FormListCount(None, main.storage_items_key)
    int i = 0
    while i < count
        Actor akActor = StorageUtil.FormListGet(None, main.storage_items_key, i) as Actor
        if akActor != None
            int num_items = StorageUtil.FormListCount(akActor, main.storage_items_key)
            if num_items > 0
                AddTextOption(akActor.GetDisplayName(), num_items+" items")
            endif
        endif
        i += 1
    Endwhile
EndFunction

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
        SetInfoText("Makes public sex a socially accepted intent..")
    EndEvent
EndState

State HideHermaphroditesToggle 
    Event OnSelectST()
        Bool public_bool = False
        if skyrimnet_sexlab_hide_hermaphrodites.GetValue() == 1.0
            public_bool = False
            skyrimnet_sexlab_hide_hermaphrodites.SetValue(0.0)
        else
            public_bool = True
            skyrimnet_sexlab_hide_hermaphrodites.SetValue(1.0)
        endif 
        SetToggleOptionValueST(public_bool)
        bool hide = skyrimnet_sexlab_hide_hermaphrodites.GetValue() == 1.0
        Trace("HideHermaphroditesToggle","hide_hermaphrodites: "+hide)
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
        SetInfoText("Opens dialogs for events that include the player.")
    EndEvent
EndState

State SexEditTagsNonPlayer
    Event OnSelectST()
        main.sex_edit_tags_nonplayer = !main.sex_edit_tags_nonplayer
        SetToggleOptionValueST(main.sex_edit_tags_nonplayer)
    EndEvent
    Event OnHighlightST()
        SetInfoText("Opens dialogs for events that do not include the player.")
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
        SetInfoText("Enables the Sex Edit Hotkey."+newline)
    EndEvent
EndState

State SexEditKeySet
    Event OnKeyMapChangeST(int keyCode, string conflictControl, string conflictName)
        Trace("SexEditKeySet","keyCode: "+keyCode+" conflictControl: "+conflictControl+" conflictName: "+conflictName)
        bool continue = True
        if conflictControl != "" 
            String msg = None 
            if (conflictName != "")
                msg = "This key is already mapped to:"+"'"+ conflictControl+"'"+ newline\
                    +"(" + conflictName + ")"+newline+newline\
                    +"Are you sure you want to continue?"
            else
                msg = "This key is already mapped to:'" + conflictControl + "'"+newline+"Are you sure you want to continue?"
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
            "For an actor in the crosshair and not in a sex animation, it will allow you to start a sex animation."+newline \
          + "For an actor in the crosshair and in a sex animation, it will open a stage description editor for that animation."+newline \
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
        SetInfoText("Hides the help dialogue that appears if no stage description is found."+newline)
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
        SetInfoText("Minimum number of seconds since last audio ended before next optional Direct Narration."+newline)
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
        SetInfoText("Maximum distance in meters that could generate a new direct narration."+newline)
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
        SetMenuDialogStartIndex(sexlab_ostim_player)
    endif
    SetMenuDialogDefaultIndex(0)
endEvent

event OnOptionMenuAccept(int menu_id, int index)
    if menu_id == ostimnet_player_menu
        sexlab_ostim_player = index 
        String label = sexlab_ostim_options[index]
        Trace("OnOptionMenuAccept"," menu_id: "+menu_id+" sexlab_ostim_player: "+index+" label: "+label)
        SetMenuOptionValue(menu_id, label)
    endif 
endEvent

; --------------------------------------------
; Handles OnKeyDown 
; --------------------------------------------

Event OnKeyDown(int key_code)
;    int before = sexlab_ostim_player
;    if sexlab_ostim_player == 0
;        sexlab_ostim_player = 1
;    else
;        sexlab_ostim_player = 0
;    endif
;    Debug.Notification("OnKeyDown: sexlab_ostim_player: "+sexlab_ostim_player+" was: "+before)
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
                sslThreadController thread = manager.GetThreadbyActor(target)
                if thread != None
                    Trace("OnKeyDown", "thread found "+thread.tid+" for target:"+target.GetDisplayName())
                    stages.EditDescriptions(thread)
                else
                    Trace("OnKeyDown","failed to find thread for target:"+target.GetDisplayName())
                endif
            elseif actions.BodyAnimation_IsEligible(target, "", "") && main.sexlab.IsValidActor(target)
                Target_Menu_Selection(target, player)
            endif 
        else 
            MutliTarget_Menu_Selection(player)
        endif 
    endif 

EndEvent 

Function Target_Menu_Selection(Actor target, Actor player)
    if main.handler_dom.IsDOMSlave(target)
        main.handler_dom.Target_Menu_Selection(target,player)
        return 
    endif 

    bool target_is_undressed = false 
    target_is_undressed = main.HasStrippedItems(target)
    String clothing_string = "undress"
    if target_is_undressed 
        clothing_string = "dress"
    endif 
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
    int clothing = cancel+6
    cancel += 7 

    int bondage = -1
    if udng_found
        bondage = cancel
        cancel += 1 
    endif  
    String[] buttons = Utility.CreateStringArray(cancel+1)

    if sexlab_ostim != -1
        buttons[sexlab_ostim] = sexlab_ostim_options[sexlab_ostim_player]
    endif 
    buttons[masturbate] = "masturbate"
    buttons[punish] = "punish"
    buttons[affection] = "affection"
    buttons[sex] = "sex"
    buttons[raped_by_player] = "player rapes"
    buttons[rapes_player] = "rapes player"
    buttons[clothing] = clothing_string
    if bondage != -1 
        buttons[bondage] = "bondage"
    endif 
    buttons[cancel] = "cancel"

    String msg = "Should "+target.getDisplayName()+":"
    int button = SkyMessage.ShowArray(msg, buttons, getIndex = true) as int  

    if button >= 0 && button <= cancel
        Trace("OnKeyDown","button:" +buttons[button])
    endif 
    if button == masturbate
        if sexlab_ostim_player == 0 || !main.ostimnet_found
            actions.StartScene_Consensual_one("sexual activites", target, "normal", "")
        else 
            EventSend_OStimNet("SexStart", target, None, "")
        endif 
    elseif button == sexlab_ostim 
        String choice = ""
        if sexlab_ostim_player == 0
            sexlab_ostim_player = 1
            choice = "Ostim"
        else
            sexlab_ostim_player = 0
            choice = "SexLab"
        endif 
        Debug.Notification("Switched to "+choice)
    elseif button == punish 
            String[] bs = new String[3] 
            bs[0] = "spanking"
            bs[1] = "spanking nude"
            bs[2] = "whip"
            String method = SkyMessage.ShowArray("How would you like to show affection?", bs, getIndex = false) as string  
            string setting_name= "punishing_spanking"
            if method == "spanking nude"
                method = "spanking"
                string setting_name= "punishing_spanking_victim_nude"
            elseif method == "whipping"  || method == "whip"
                method = "whip"
                string setting_name= "punishing_whipping_oral"
            endif 
            actions.StartScene_Nonconsensual_Two("punishing", player, target=target, method=method, direction="giving", setting_name=setting_name) 
    elseif button == affection
;        if sexlab_ostim_player == 0 || !main.ostimnet_found    
            String[] bs = new String[6] 
            bs[0] = "single hug"
            bs[1] = "hugging"
            bs[2] = "cuddle"
            bs[3] = "spooning"
            bs[4] = "kissing"
            bs[5] = "headpat"
            String method = SkyMessage.ShowArray("How would you like to show affection?", bs, getIndex = false) as string  
            string setting_name = "nonsexual_male_position_1"
            if method == "kissing" 
                setting_name = "nonsexual_kissing"
            endif 
            actions.StartScene_Consensual_Two("showing affection",player, target=target, style="gently", method=method,setting_name=setting_name)
;        else 
;            String[] bs = new String[3] 
;            bs[0] = "hugging"
;            bs[1] = "kissing"
;            bs[2] = "cuddling"
;            String tag = SkyMessage.ShowArray("select", bs, getIndex = false) as string  
;            EventSend_OstimNet("AffectionStart", player, target, tag)
;        endif 
    elseif button == sex
        actions.StartScene_Consensual_Two("sexual activities", player, target=target)
        ;if sexlab_ostim_player  == 0.0 || !main.ostimnet_found
            ;actions.StartScene_Consensual_Two("sexual activities", player, target=target)
        ;else 
            ;String[] bs = new String[3] 
        ;    bs[0] = "vaginalsex"
        ;    bs[1] = "blowjob"
        ;    bs[2] = "analsex"
        ;    String tag = SkyMessage.ShowArray("select", bs, getIndex = false) as string  
        ;    EventSend_OstimNet("SexStart", player, target, tag)
        ;endif 

    elseif button == rapes_player
        actions.StartScene_Nonconsensual_Two("raping", player,target, speaker_victim=True)
    elseif button == raped_by_player
        actions.StartScene_Nonconsensual_Two("raping",player, target)
    elseif button == clothing

        if clothing_string == "undress"
            clothing_string = "take off"
        Else
            clothing_string = "put on"
        endif 

        ;--------------------------------------------------
        ; How would they like it appear? 
        int forcefully = 0
        int normally = 1
        int gently = 2
        int silently = 3
        buttons = new String[4] 
        buttons[forcefully] = "Forcefully by player "
        buttons[normally] = "By player"
        buttons[gently] = "Gently by player"
        buttons[silently] = "( Silently )"

        button = SkyMessage.ShowArray(msg, buttons, getIndex = true) as int 
        String narration = "direct"
        String style = "" 
        if button == gently
            style = "gently"
        elseif button == forcefully
            style = "forcefully"
        elseif button == silently
            narration = "none"
        endif 
        ;--------------------------------------------------
        ; Now do the action 
        Trace("Target_Menu_Selection","style:"+style+" clothing_string:"+clothing_string)
        actions.Change_Outfit(player, target, style, clothing_string+"es", narration)

    elseif button == bondage 
        EventSend_UDNG("MenuOpen", target)
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
    String intent = "sex>"

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
        listMenu.AddEntryItem(intent)

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
            buttons[0] = "comfort>"
            buttons[1] = "affection>"
            buttons[2] = "sex>"
            buttons[3] = "rape>"

            String msg = "What is the intent?"
            intent = SkyMessage.ShowArray(msg, buttons, getIndex = false) as String
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

    Actor[] actors_selected = PapyrusUtil.ActorArray(next)
    i = 0 
    while i < next 
        actors_selected[i] = actors[selected[i]]
        i += 1 
    endwhile 
    Trace("MultiTarget_Menu_Selection","intent:"+intent+" next:"+next+" actors_selected:"+SkyrimNet_SexLab_Utilities.JoinActors(actors_selected))

    Actor speaker = actors_selected[0]
    Actor target = None 
    if next > 1 
        target = actors_selected[1]
    endif 
    if intent == "rape>"
        SkyrimNet_SexLab_Scene_Creator creator = manager.CreateCreator(intent, actors_selected, speaker, target, setting_name="")
        creator.SetVictim(actors_selected[0])
        creator.Start() 
    else 
        String setting_name = ""
        String method = ""
        if intent == "comfort>"
            intent = "comfort"
            setting_name = "nonsexual_male_position_1"
            method = "spooning"
        elseif intent == "affection>"
            intent = "showing affection"
            method = "spooning"
            setting_name = "nonsexual_male_position_1"
        else
            intent = "sexual activites"
        endif 
        ;if actors.length > 2 && setting_name == "nonsexual_male_position_1"
            ;method = "spooning"
            ;setting_name = "nonsexual_male_position_0"
        ;endif 
        SkyrimNet_SexLab_Scene_Creator creator = manager.CreateCreator(intent, actors_selected, speaker, target, method=method, setting_name=setting_name)
        creator.Start() 
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
