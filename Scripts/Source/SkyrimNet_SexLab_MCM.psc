Scriptname SkyrimNet_SexLab_MCM extends SKI_ConfigBase

import SkyrimNet_SexLab_Actions

int rape_toggle
GlobalVariable Property sexlab_public_sex_accepted Auto

SkyrimNet_SexLab_Main Property main Auto  
SkyrimNet_SexLab_Stages Property stages Auto 

bool hot_key_toggle = False 
int sex_edit_key = 40 ; 26

bool dom_debug_toggle = False 
int dom_debug_key = 41

bool clear_JSON = False

; Devious Device Support 
skyrimnet_UDNG_Groups group_devices = None

; DOM Support 
Quest d_api = None 
SkyrimNet_DOM_Main dom_main = None 

; OstimNet Support 
int ostimnet_player_menu = -1
int ostimnet_nonplayer_menu = -1

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
bool ostimnet_found = False
String[] sexlab_ostim_options 

int Property sexlab_ostim_player_menu Auto  ; menu id 
int Property sexlab_ostim_nonplayer_menu Auto  ; menu id 

Function Setup() 
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
        group_devices = Game.GetFormFromFile(0x800, "SkyrimNetUDNG.esp") as skyrimnet_UDNG_Groups
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
        dom_main = Game.GetFormFromFile(0x800, "SkyrimNet_DOM.esp") as SkyrimNet_DOM_Main
    else 
        dom_main = None 
    endif 

    if MiscUtil.FileExists("Data/TT_OstimNet.esp")
        Trace("SetUp","found TT_OstimNet.esp")
        ostimnet_found = True
    else 
        ostimnet_found = False  
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
    if stages == None 
       stages = Game.GetFormFromFile(0x800, "SkyrimNet_SexLab.esp") as SkyrimNet_SexLab_Stages
    endif

    SetCursorFillMode(LEFT_TO_RIGHT)
    SetCursorPosition(0)
    
    AddHeaderOption("Options")
    AddHeaderOption("")
    AddToggleOptionST("RapeAllowedToggle","Add rape actions (must toggle/save/reload)",main.rape_allowed)
    AddToggleOptionST("PublicSexAcceptedToggle","Public sex accepted",sexlab_public_sex_accepted.GetValue() == 1.0)
    AddToggleOptionST("SexEditTagsPlayer","Show Tags_Editor for player sex",main.sex_edit_tags_player)
    AddToggleOptionST("SexEditTagsNonPlayer","Show Tags_Editor for nonplayer sex",main.sex_edit_tags_nonplayer)

    AddHeaderOption("Sex Description Editor")
    AddHeaderOption("")
    AddToggleOptionST("HotKeyToggle","Enable the Start Sex / Edit Stage hot key",hot_key_toggle)
    AddKeyMapOptionST("SexEditKeySet", "Start Sex / Edit Stage Description", sex_edit_key)
    AddToggleOptionST("SexEdithelpToggle","Hide Edit Stage Discription Help",stages.hide_help)
    AddTextOption("","")
    
    AddHeaderOption("Direction Narration Blocking")
    AddHeaderOption("")
    AddSliderOptionST("NarrationCoolOff", "Narration coolown", main.direct_narration_cool_off)
    AddSliderOptionST("NarrationMaxDistance", "Narration max distance", main.direct_narration_max_distance)

    if dom_main != None 
        AddHeaderOption("                              ")
        AddHeaderOption("Debug")
        AddHeaderOption("")
        AddToggleOptionST("DomDebugToggle","Enable DOM debugs",dom_debug_toggle)
    Endif 

    if hot_key_toggle 
        RegisterForKey(sex_edit_key)
    endif 

    if ostimnet_found
        Trace("PageOptions"," index: "+main.sexlab_ostim_player_index+" label: "+sexlab_ostim_options[main.sexlab_ostim_player_index])
        AddHeaderOption("OstimNet Integration")
        AddHeaderOption("")
        ostimnet_player_menu = AddMenuOption("sex framework:", sexlab_ostim_options[main.sexlab_ostim_player_index])
        ; ostimnet_nonplayer_menu = AddMenuOption("sex without player:", sexlab_ostim_options[main.sexlab_ostim_player_index])
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
        i += 1
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
; Set Toggles 
;-----------------------------------------------------------------

State RapeAllowedToggle
    Event OnSelectST()
        main.rape_allowed = !main.rape_allowed
        Skyrimnet_sexlab_Actions.RapeRegistration(main.rape_allowed)
        SetToggleOptionValueST(main.rape_allowed)
    EndEvent
    Event OnHighlightST()
        SetInfoText("Adds/Removes the NPC rape Actions. Request you save and reload.")
    EndEvent
EndState
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

State SexEditTagsPlayer
    Event OnSelectST()
        main.sex_edit_tags_player = !main.sex_edit_tags_player
        SetToggleOptionValueST(main.sex_edit_tags_player)
    EndEvent
    Event OnHighlightST()
        SetInfoText("Selects which framework to use.")
    EndEvent
EndState

State SexEditTagsNonPlayer
    Event OnSelectST()
        main.sex_edit_tags_nonplayer = !main.sex_edit_tags_nonplayer
        SetToggleOptionValueST(main.sex_edit_tags_nonplayer)
    EndEvent
    Event OnHighlightST()
        SetInfoText("Opens a tag editor when sex includes the player.")
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
        SetInfoText("Mininum number of seconds since laster audio ended before next optional Direct Narration.\n")
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
    Trace("OnOptionMenuOpen","options: "+sexlab_ostim_options)
    SetMenuDialogOptions(sexlab_ostim_options)
    if menu_id == ostimnet_player_menu
        SetMenuDialogStartIndex(main.sexlab_ostim_player_index)
    elseif menu_id == ostimnet_nonplayer_menu
        SetMenuDialogStartIndex(main.sexlab_ostim_nonplayer_index)
    endif
    SetMenuDialogDefaultIndex(0)
endEvent


event OnOptionMenuAccept(int menu_id, int index)
    if menu_id == ostimnet_player_menu
        main.sexlab_ostim_player_index = index
    else 
        main.sexlab_ostim_nonplayer_index = index
    endif 
    Trace("OnOptionMenuAccept"," index: "+main.sexlab_ostim_player_index+" label: "+sexlab_ostim_options[main.sexlab_ostim_player_index])
    SetMenuOptionValue(menu_id, sexlab_ostim_options[index])
endEvent

; --------------------------------------------
; Handles OnKeyDown 
; --------------------------------------------

Event OnKeyDown(int key_code)
    if UI.IsTextInputEnabled()
        return 
    endif 

    if sex_edit_key == key_code
        ; Both players need to be in the crosshair to have SkyrimNet load them into the cache
        ; so the parseJsonActor works
        Actor target = Game.GetCurrentCrosshairRef() as Actor 
        Actor player = Game.GetPlayer() 
        bool player_having_sex = main.sexlab.IsActorActive(player)
        if player_having_sex || target != None 
            ;---------------------------------
            ; The original 
            if player_having_sex || main.sexlab.IsActorActive(target)
                if player_having_sex 
                    target = player 
                endif 
                sslThreadController thread = main.GetThread(target)
                
                if thread != None 
                    stages.EditDescriptions(thread) 
                endif 
            elseif SkyrimNet_SexLab_Actions.BodyAnimation_IsEligible(target, "", "") && main.sexlab.IsValidActor(target)

                DOM_Actor slave = None 
                if d_api != None && (d_api as DOM_API).IsDOMSlave(target) 
                    slave = (d_api as DOM_API).GetDOMActor(target) 
                endif 

                ;if slave != None && dom_main != None 
                    ;dom_main.SelectPlayerAction(target, slave) 
                    ;return 
                ;endif 

                bool target_is_undressed = false 
                if slave != None 
                    Trace("OnKeyDown","slave.is_naked:"+slave.is_naked+" should_be_naked:"+slave.mind.should_be_naked)
                    target_is_undressed = slave.is_naked
			        ;DOM_Mind sl_mind = slave.mind
			        ;if sl_mind != None
				        ;if sl_mind.should_be_naked ; && sl_alias.is_naked
                            ;target_is_undressed = True 
                        ;endif 
                    ;endif 
                else 
                    target_is_undressed = main.HasStrippedItems(target)
                endif 
                String clothing_string = "undress"
                if target_is_undressed 
                    clothing_string = "dress"
                endif 
                int masturbate = 0
                int sex = 1
                int raped_by = 2
                int rapes = 3
                int clothing = 4
                int cancel = 5

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

                buttons[masturbate] = "masturbate"
                buttons[sex] = "have sex with player"
                buttons[raped_by] = "raped by player"
                buttons[rapes] = "rapes the player"
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

                Trace("OnKeyDown","buttons:" +buttons)

                String msg = "Should "+target.getDisplayName()+":"
                if slave != None 
                    msg += "\nDOM slave's mind can not refuse these actions."
                endif 
                int button = SkyMessage.ShowArray(msg, buttons, getIndex = true) as int  

                if button == masturbate
                    SkyrimNet_SexLab_Actions.SexStart_Execute(target, "", "{\"type\":\"masturbation\"}")
                elseif button == sex
                    SkyrimNet_SexLab_Actions.SexStart_Execute(target, "", "{\"rape\":false, \"target\":\""+player.GetDisplayName()+"\", \"target_is_player\":true}")
                elseif button == rapes
                    SkyrimNet_SexLab_Actions.SexStart_Execute(target, "", "{\"rape\":true, \"target\":\""+player.GetDisplayName()+"\", \"target_is_victim\":true, \"target_is_player\":true}")
                elseif button == raped_by
                    SkyrimNet_SexLab_Actions.SexStart_Execute(target, "", "{\"rape\":true, \"Target\":\""+player.GetDisplayName()+"\", \"target_is_victim\":false, \"target_is_player\":true}")
                elseif button == clothing

                    ;--------------------------------------------------
                    ; How would they like it appear? 
                    buttons = new String[4] 
                    buttons[main.STYLE_FORCEFULLY] = "Forcefully by player "
                    buttons[main.STYLE_NORMALLY] = "By player"
                    buttons[main.STYLE_GENTLY] = "Gently by player"
                    buttons[main.STYLE_SILENTLY] = "( Silently )"

                    msg = "How is "+target.getDisplayName()+" to be "+clothing_string+"ed?"
                    button = SkyMessage.ShowArray(msg, buttons, getIndex = true) as int 
                    if button != main.STYLE_SILENTLY
                        String style = " "
                        if button == main.STYLE_GENTLY 
                            style = " gently "
                        elseif button == main.STYLE_FORCEFULLY 
                            style = " forcefully "
                        endif 
                        msg = player.GetDisplayName()+style+clothing_string+"es "+target.GetDisplayName()+"."
                        main.DirectNarration(msg, player, target) 
                    endif 

                    ;--------------------------------------------------
                    ; Now do the action 
                    if slave != None 
                        if target_is_undressed 
                            Trace("OnKeyDown","DOM slave"+target.GetDisplayName()+" dressing", true)
                            slave.UnsetShouldBeNaked(player)
                            slave.Anim_DressUp(true)
                        else 
                            Trace("OnKeyDown","DOM slave"+target.GetDisplayName()+" undressing", true)
                            slave.Interact_UndressNoChoice(player, false) 
                        endif 
                    else 
                        if target_is_undressed
                            SkyrimNet_SexLab_Actions.Dress_Execute(target, "", "")
                        else
                            SkyrimNet_SexLab_Actions.Undress_Execute(target, "", "")
                        endif
                    endif 

                elseif button == cuddle 
                    SkyrimNet_Cuddle_API.OpenMenu(player, target) 
                elseif button == bondage 
                    group_devices.UpdateDevices(target) 
                elseif button == dom_debug
                    dom_main.DebugMenuOpen(target) 
                endif 
                return 
            endif 
            return 
        endif 

        ; If not, then we allow them to start a sex animation with nearby actors
        Debug.Notification("No target in crosshair, looking for sexable nearby actors")
        Trace("OnKeyDown","No target in crosshair, looking for nearby actors")
        ;float time_last = Utility.GetCurrentRealTime()
        Actor[] actors_all = MiscUtil.ScanCellActors(player, 1000)

        bool[] valid = PapyrusUtil.BoolArray(actors_all.length)

        if actors_all.length < 2
            actors_all = MiscUtil.ScanCellActors(player, 2000)
            if actors_all.length == 0
                Trace("OnKeyDown","No eligible actors found in the area.")
                return
            endif 
        endif 

        int i = actors_all.length - 1 
        int num_actors = 0 

        while 0 <= i 
            if SkyrimNet_SexLab_Actions.BodyAnimation_IsEligible(actors_all[i], "", "") && main.sexlab.IsValidActor(actors_all[i])
                valid[i] = True
                num_actors += 1
            else 
                valid[i] = False
            endif 
            i -= 1
        endwhile 


        if num_actors < 2
            Trace("OnKeyDown","Not enough eligible actors found in the area.")
            return
        endif
        Trace("OnKeyDown","Found "+actors.length+" actors in the area.")

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
        int index = 1
        uilistmenu listMenu = uiextensions.GetMenu("UIListMenu") AS uilistmenu
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
            listmenu.AddEntryItem(type)

            i = 0
            while i < num_actors
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
                type = SexRapeSelection()
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
                    Trace("OnKeyDown","after next:"+next+" selected[index]:"+selected[next - 1])
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

        if type == "cuddle>"
            ;SkyrimNet_Cuddle.StageStart(
        else 
            StartSex(group, type == "rape>")
        endif 
    endif 
EndEvent 

Function StartSex(Actor[] actors, bool is_rape) 
    Trace("StartSex","num_actors:"+actors.length+" is_rape:"+is_rape)
    SexLabFramework SexLab = Game.GetFormFromFile(0xD62, "SexLab.esm") as SexLabFramework
    if SexLab == None
        Trace("StartSex","SexLab is None")
        return
    endif

    ; Lock the actors 
    int num_actors = actors.length 
    int i = 0
    bool cancel = false
    while !cancel && i < num_actors 
        if !main.SetActorLock(actors[i])
            cancel = true
        endif 
        main.SetActorLock(actors[i])
        i += 1
    endwhile

    sslThreadModel thread = None 
    if !cancel
        thread = sexlab.NewThread()
        if thread == None
            Trace("StartSex","Failed to create thread")
            cancel = true
        endif
    endif 

    i = 0
    while !cancel && i < num_actors 
        if thread.addActor(actors[i]) < 0   
            Trace("StartSex","Starting sex couldn't add "+i+" "+actors[i].GetDisplayName())
            cancel = true 
        endif  
        i += 1
    endwhile


    if cancel
        i = 0 
        while i <= num_actors 
            main.ReleaseActorLock(actors[i])
            i += 1 
        endwhile 
        return
    endif

    if is_rape
        thread.SetVictim(actors[0])
    endif 

    sslBaseAnimation[] anims = main.AnimsDialog(sexlab, actors, "")
    if anims.length > 0 && anims[0] != None  
        thread.SetAnimations(anims)
    endif 

    thread.StartThread() 
EndFunction 

String Function SexRapeSelection()
    uilistmenu listMenu = uiextensions.GetMenu("UIListMenu") AS uilistmenu
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
