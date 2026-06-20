Scriptname SkyrimNet_SexLab_Scene_Creator extends SkyrimNet_SexLab_Scene_Interface

Import SkyrimNet_SexLab_Utilities
Import SkyrimNet_SexLab_Scene_Interface

SexLabFramework Property sexlab Auto

; ----------------------------------
; Actors and Victims 
; ----------------------------------
int num_actors = 0 
Actor[] Property actors Auto

Actor[] Property victims Auto 

; --------------------------------------------
; Buttons 
; --------------------------------------------
int BUTTON_YES = 0
int BUTTON_YES_RANDOM = 1
int BUTTON_NO_SILENT = 2
int BUTTON_NO = 3

; --------------------------------------------
; speaker and target 
; --------------------------------------------
Actor speaker
Actor target

int[] victim_mask
int[] assailant_mask

; --------------------------------------------
; Direction
; --------------------------------------------
String direction = "" 

; --------------------------------------------
; event_hook
; --------------------------------------------
String event_hook = ""

; --------------------------------------------
; Tags 
; --------------------------------------------
int num_tags = 0 
String[] tags = None 

int num_tags_supress = 9 
String[] tags_supress = None 

; -------------------------------------
; Actor Locks 
; -------------------------------------
String storage_actor_lock_key = "skyrimnet_sexlab_scene_actor_lock"
int actorLock = 0 Auto 
float actorLockTimeout = 0.00069444444 Auto ;  1 day / (24 hours  * 60 minutes ) 

Function Trace(String func, String msg="", Bool notification=False)
    msg = "[SkyrimNet_SexLab_Scene_Creator."+func+"] sid:"+sid+" "+msg
    Debug.Trace(msg) 
    if notification
        Debug.Notification(msg)
    endif 
EndFunction

String Function GetString() 
    String tags_string = JoinStrings(tags,num_tags)
    String tags_supress_string = JoinStrings(tags_supress, num_tags_supress)
    return " actors: "+'"'+actor_names+'"'\
          +" victims: "+'"'+victim_names+'"'\
          +" assailants: "+'"'+assailant_names+'"'\
          +" tags:"+tags_string\
          +" supress_tags:"+tags_supress_string\
          +" style:"+style\
          +" event_hook:"+event_hook
EndFunction 

Function Initialize(int _sid, SkyrimNet_SexLab_Scene_Manager _manager) 
    parent.Initialize(_sid, _manager) 
    sexlab = manager.sexlab
    if !actors 
        actors = new Actor[2] 
        victims = new Actor[2] 
    endif 
    if !tags 
        tags = new String[10]
        tags_supress = new String[10]
    endif 
EndFunction 

; --------------------------------------------
; Release 
; --------------------------------------------
Function Release()
    UnlockAllActorLock() 
    num_tags = 0
    num_tags_supress = 0 
    event_hook = None 
    Release() 
EndFunction

Function CheckActorSize(int size) 
    actors = EnsureActorsLargeEnough(actors, size) 
    victim_mask = EnsureIntsLargeEnough(victim_mask, size) 
    assailant_mask = EnsureIntsLargeEnough(assailant_mask, size) 
EndFunction

Function Setup(Actor[] _actors, Actor _speaker, Actor _target)
    Trace("Setup","actors: ["+JoinActors(_actors)+"] speaker:"+GetDisplayName(_speaker)+" target:"+GetDisplayName(_target))
    CheckActorSize(_actors.length) 
    Trace("Setup","actors:"+JoinActors(actors))

    Actor player = Game.GetPlayer() 
    num_actors = 0 
    num_victims = 0 
    has_player = False 
    int i = 0
    int count = _actors.length
    while i < count 
        Actor akActor = _actors[i]
        if akActor != None 
            actors[num_actors] = akActor
            if player == akActor
                has_player = True 
            endif 
            num_actors += 1 
        endif 
        i += 1 
    endwhile 

    num_tags = 0
    num_tags_supress = 0 
    SetActivity(ACTIVITY_DEFAULT) 
    style = STYLE_NORMALLY
    event_hook = ""
    SetNames() 
    status = STATUS_ACTIVE 
EndFunction 

; ---------------------------------
; Set Up Names 
; ---------------------------------
Function ShiftActorsLeft() 
    if num_actors < 2
        return 
    endif 
    
    String before = actor_names 
    Actor actor_temp = actors[0]
    
    ; -----------------------------------------------------------------------
    ; SOLUTION: Leveraging PapyrusUtil's native array shifting
    ; This avoids the manual O(n) Papyrus while-loop shifting execution.
    ; -----------------------------------------------------------------------
    actors = PapyrusUtil.RemoveActor(actors, actor_temp)
    actors = PapyrusUtil.PushActor(actors, actor_temp)
    
    SetNames() 
    Trace("ShiftActorsLeft", before + " -> " + actor_names) 
EndFunction

Function SetMasks()
    int i = 0 
    while i < num_actors 

        ; Victim and Assailant 
        bool found = False 
        int j = 0
        while j < num_victims 
            if actors[i] == victims[j]
                found = true 
            endif 
            j += 1 
        endwhile 
        if found 
            victim_mask[i] = 1 
            assailant_mask[i] = 0 
        else 
            victim_mask[i] = 0 
            assailant_mask[i] = 1
        endif 
        i += 1 
    endwhile 
EndFunction 

Function SetNames() 
    SetMasks()
    actor_names = JoinActors(actors, num_actors)
    actor_names_json = JoinActorsToJson(actors, num_actors)

    victim_names = JoinActorsMasked(actors, victim_mask, num_actors)
    assailant_names = JoinActorsMasked(actors, assailant_mask, num_actors)

;    Trace("SexNames",sid+" actors:"+JoinActors(actors,num_actors)+" num_actors:"+num_actors+\
;        " actor_names:"+actor_names+" actor_names_json:"+actor_names_json+\
;        " hermaphrodiate_names:"+hermaphrodiate_names+" strapon_names:"+strapon_names+\
;        " victim_names:"+victim_names+" victim_names_json:"+victim_names_json+\
;        " assailant_names:"+assailant_names)
EndFunction 

; -------------------------------------------------
; Victim and Assailant setters 
; -------------------------------------------------

Function SetVictim(Actor victim) 
    if !victims 
        victims = PapyrusUtil.ActorArray(10)
    endif 
    num_victims = 0 
    if victim == None 
        Trace("SetVictim","victim is None")
        return
    endif 

    victims[0] = victim
    num_victims = 1 
    Trace("SetVictim",GetDisplayName(victim))
    SetNames() 
EndFunction 

Function SetVictims(Actor[] _victims) 
    num_victims = 0 
    Actor player = Game.GetPlayer() 
    player_is_victim = False
    int i = 0
    int count = _victims.length
    while i < count 
        if _victims[i] != None 
            if _victims[i] == player
                player_is_victim = True 
            endif 
            num_victims += 1 
        else 
            Trace("SetVictims", "victims["+i+"] is None")
        endif
        i += 1 
    endwhile 

    if num_victims == 0 
        Trace("SexVictims","No valid victims found")
    else 
        victims = EnsureActorsLargeEnough(victims, num_victims) 
        i = 0 
        int j = 0 
        while i < count 
            if _victims[i] != None 
                victims[j] = _victims[i]
                j += 1  
            endif
            i += 1 
        endwhile 
        Trace("SetVictim",JoinActorsToJson(victims))
    endif 
    SetNames() 
EndFunction 

; -------------------------
; Tag Functions 
; -------------------------
function SetTag(String tag) 
    num_tags = 0
    AddTag(tag)
EndFunction 

function SetTagSupress(String tag) 
    num_tags_supress = 0 
    AddTagSupress(tag)
EndFunction 

function AddTag(String tag) 
    if tag == None || tag == "" 
        return 
    endif 
    tags = EnsureStringsLargeEnough(tags, num_tags + 1) 
    tags[num_tags] = tag
    num_tags += 1 
EndFunction 
function AddTagSupress(String tag) 
    if tag == None || tag == "" 
        return 
    endif 
    tags_supress = EnsureStringsLargeEnough(tags_supress, num_tags_supress + 1) 
    tags_supress[num_tags_supress] = tag
    num_tags_supress += 1 
EndFunction 

; --------------------------------------------
; --------------------------------------------
function SetTags(String[] _tags) 
    SetTags_Helper(True,_tags) 
endfunction

function SetTagsSupress(String[] _tags_supress) 
    SetTags_Helper(False,_tags_supress) 
endfunction

Function SetTags_Helper(bool is_tags, String[] _tags)
    int number = 0 
    int i = 0
    int _num_tags = _tags.length
    while i < _num_tags 
        if _tags[i] != None && _tags[i] != "" 
            number += 1 
        endif 
        i += 1 
    endwhile 

    String[] ts = tags 
    if !is_tags
        ts = tags_supress
    endif 
    if number > 0
        ts = EnsureStringsLargeEnough(ts, number) 
        i = 0
        int j = 0 
        int count = _tags.length
        while i < count
            if _tags[i] != None && _tags[i] != "" 
                ts[j] = _tags[i]
                j += 1 
            endif 
            i += 1 
        endwhile 
    endif 

    if is_tags
        num_tags = number
        tags = ts
    else
        num_tags_supress = number
        tags_supress = ts
    endif 
EndFunction 

; ------------------------------------------------------
; Set Style 
; ------------------------------------------------------
Function SetStyle(String _style) 
    style = _style
EndFunction 
String Function GetStyle() 
    return style
EndFunction

Function SetDirection(String _direction)
    direction = _direction
    if actors.length > 1
        if direction == "giving"
            Actor temp = actors[0]
            actors[0] = actors[1]
            actors[1] = temp 
        endif 
    endif 
EndFunction 

Function SetEventHook(String _event_hook) 
    event_hook = _event_hook 
EndFunction

; -------------------------------------------------------------------------------------
; Actor LOck
; -------------------------------------------------------------------------------------

bool Function LockAllActorLock() 
    if !actors
        return False
    endif 
    int i = 0 
    while i < num_actors && LockActorLock(actors[i]) 
        i += 1 
    endwhile 

    if i < num_actors 
        int j = 0
        while j < i
            UnlockActorLock(actors[j]) 
            j += 1 
        endwhile 
        return False 
    endif 
    return True 
EndFunction 

Function UnLockAllActorLock() 
    if !actors 
        return 
    endif 
    int i = 0
    while i < num_actors
        UnlockActorLock(actors[i]) 
        i += 1 
    endwhile 
EndFunction 

Bool Function IsActorLocked(Actor akActor) 
    return StorageUtil.HasIntValue(akActor, storage_actor_lock_key) 
EndFunction 

bool Function LockActorLock(Actor akActor) 
    if StorageUtil.HasIntValue(akActor, storage_actor_lock_key) 
        return False 
    endif 
    Trace("LockActorLock",akActor.GetDisplayName())
    StorageUtil.SetIntValue(akActor, storage_actor_lock_key, 1) 
    return True 
EndFunction 

Function UnlockActorLock(Actor akActor) 
    StorageUtil.UnsetIntValue(akActor, storage_actor_lock_key) 
    Trace("ReleaseActorLock",akActor.GetDisplayName())
EndFunction

; --------------------------------------------
; Start with Thread
; --------------------------------------------
SkyrimNet_SexLab_Scene Function Start() 
    SetNames() 

    Trace("CreateThread",GetString()) 

    sslThreadModel model = sexlab.NewThread()
    if model == None
        Trace("CreateThread","Failed to create model")
        Release()
        return None 
    endif

    sslBaseAnimation[] animations = SelectAnimations() 
    if animations == empty
        Trace("CreateThread","SelectAnimations returned empty")
        Release() 
        return None
    endif 
    model.SetAnimations(animations) 
    
    ; -----------------------------------------
    ; Add Actors and Victims 
    ; -----------------------------------------
    int i = 0 
    bool failed = False 
    while i < num_actors && !failed 
        if model.AddActor(actors[i]) < 0 
            Trace("Start","AddActor failed on actor:"+actors[i].GetDisplayName())
            failed = True 
        endif 
        i += 1 
    endwhile 

    i = 0 
    while i < num_victims && !failed
        model.SetVictim(victims[i])
        i += 1 
    endwhile 

    if failed 
        Release() 
        return 
    endif 

    ; Reset the masks, in case the names moves things around 
    i = 0
    num_actors = model.positions.length
    while i < num_actors 
        actors[i] = model.positions[i]
        i += 1 
    endwhile 
    SetNames() 

    Trace("CreateThread","--- a")

    ; ------------------------------------------
    ; Add Tags
    ; ------------------------------------------

    i = 0
    while i < num_tags
        String tag = tags[i]
        if tag == "mouth" || tag == "tongue"
            tags[i] = "oral"
        elseif tag == "pussy"
            tags[i] = "vaginal"
        elseif tag == "ass"
            tags[i] = "anal"
        endif 
        i += 1 
    endwhile 

    Trace("CreateThread","--- b")
    if num_actors == 1
        int gender = sexlab.GetGender(actors[0])
        bool has_penis = (gender != 1 && gender != 3)
        if has_penis 
            addTag("M")
        else 
            addTag("F")
        endif 
    endif 

    Trace("CreateThread","--- c")
    if event_hook != None && event_hook != "" 
        model.SetHook(event_hook)
    endif 


    String tags_string = JoinStrings(tags, num_tags)
    String tags_supress_string = JoinStrings(tags_supress, num_tags_supress)
    Trace("CreateThread",sid\
        +" activity:"+activity\
        +" actors: "+'"'+actor_names+'"'\
        +" victims: "+'"'+victim_names+'"'\
        +" assailants: "+'"'+assailant_names+'"'\
        +" tag:"+tags_string\
        +" tag:"+tags_supress_string\
        +" style:"+style\
        +" event_hook:"+event_hook)

    Trace("CreateThread","--- d")
    sslThreadController thread = model.StartThread() 
    Trace("Start","--- f")
    if thread == None 
        Trace("Start","StartThread returned None, releasing scene.sid")
        Release() 
        return None 
    endif 
    Release() 

    return manager.CreateSceneByThread(thread) 
EndFunction

;---------------------------------------------------------------------------------------------------------------------
;---------------------------------------------------------------------------------------------------------------------

; Allows the user to choose to accept the sex act chosen by the LLM 
; The value will between 
; 1 Yes with the editor 
; 2 Yes, but no tag editor 
; 3 No (silent), refused, but don't tell the LLM 
; 4 NO, tell the LLM 
int function YesNoDialog()
    
    Actor player = Game.GetPlayer() 
    String player_name = player.GetDisplayName()

    int yes = 0 
    int no_silent = 1
    int no = 2 

    String[] buttons = new String[4]
    buttons[BUTTON_YES] = "Yes"
    buttons[BUTTON_YES_RANDOM] = "Yes (Random)"
    buttons[BUTTON_NO_SILENT] = "No (Silent)"
    buttons[BUTTON_NO] = "No"

    String question = ""
    String rejection = ""

    Trace("YesNoDialog","activity:"+activity+" num_victims:"+num_victims)
    if num_victims == 0
        int[] player_mask = Utility.CreateIntArray(num_actors, 1)
        int i = 0
        while i < num_actors
            if actors[i] == player
                player_mask[i] = 0
            endif 
            i += 1
        endwhile
        String names = JoinActorsMasked(actors, player_mask, num_actors)
        question = "Would you like to start "+activity+" with "+names+"?"
        rejection = player_name+" refuses to start "+activity+" with "+names+"."
    else
        if player_is_victim
            question = "Will you allow, "+assailant_names+" to start "+activity+" you?"
            rejection = player_name+" prevents, "+assailant_names+" from to start "+activity+" them?"
        else 
            question = "Would you like to start "+activity+" "+victim_names+"?"
            rejection = player_name+" refuses to start "+activity+" "+victim_names+"."
        endif 
    endif 
    
    int button = SkyMessage.ShowArray(question, buttons, getIndex = true) as int  
    if button == BUTTON_NO || button == BUTTON_NO_SILENT
        if button == BUTTON_NO 
            DirectNarration(rejection, player, actors[0])
        endif 
    endif 
    return button
EndFunction
; -----------------------------------
; Style 
; -----------------------------------

sslBaseAnimation[] Function SelectAnimations()
    if num_victims > 0
        Trace("SelectAnimations"," assailants:"+assailant_names+" victims:"+victim_names)
    else 
        Trace("SelectAnimations"," actors:"+actor_names)
    endif 
    sslBaseAnimation[] animations = empty
    int button = BUTTON_YES
    if has_player
        button = YesNoDialog()
        if button == BUTTON_NO || button == BUTTON_NO_SILENT
            return empty 
        endif 
    endif  

    if button != BUTTON_YES_RANDOM
        if (main.sex_edit_tags_player && has_player) || (main.sex_edit_tags_nonplayer && !has_player)
            animations = SelectAnimationsDialog()
        else 
            String tags_string = JoinStrings(tags, num_tags)
            String tags_supress_string = JoinStrings(tags_supress, num_tags_supress)
            animations = sexLab.GetAnimationsByTags(num_actors, tags_string, tags_supress_string, true)
        endif 
    else
        String tags_string = JoinStrings(tags, num_tags)
        String tags_supress_string = JoinStrings(tags_supress, num_tags_supress)
        animations =  sexLab.GetAnimationsByTags(num_actors, tags_string, tags_supress_string, true)
    endif 
    return animations  
EndFunction 


; This function returns the list of animations matching the requested animations
; If no animations were selected, it will return an array with a single None value `[None]`
; 
;   anims = AnmisDialog(sexlab. positions, tag) 
;   if anims.length > 0 && anims[0] != None 
;        thread.SetAnimations(anims)
;   endif 
;
sslBaseAnimation[] Function SelectAnimationsDialog() 
    if num_victims > 0
        Trace("SelectAnimationsDialog"," assailants:"+assailant_names+" victims:"+victim_names)
    else 
        Trace("SelectAnimationsDialog"," actors:"+actor_names)
    endif 

    if (has_player && !main.sex_edit_tags_player) || (!has_player && !main.sex_edit_tags_nonplayer)
        Trace("SelectAnimationsDialog", "Returning empty | sex_edit_tags_player:"+main.sex_edit_tags_player+" sex_edit_tags_nonplayer:"+main.sex_edit_tags_nonplayer)
        return empty 
    endif 

    if num_tags > 0 || num_tags_supress > 0
        String tags_string = JoinStrings(tags, num_tags)
        String tags_supress_string = JoinStrings(tags_supress, num_tags_supress)
        sslBaseAnimation[] anims =  SexLab.GetAnimationsByTags(num_actors, tags_string, tags_supress_string, true)
        if anims.length == 0
            Trace("SelectAnimationsDialog", "No animations found, dropping initial tag: "+tags_string+" tags_supress:"+tags_supress_string)
            num_tags = 0 
            num_tags_supress = 0
        endif 
    endif 

    ; the order of the groups 
    int group_tags = JMap.getObj(manager.group_info,"group_tags",0)
    if group_tags == 0 
        Trace("SelectAnimationsDialog", "group_tags not found in group_tags.json")
        return empty
    endif 

    int groups = JMap.getObj(group_tags,"groups",0)
    if groups == 0
        groups = JMap.allKeys(group_tags)
        JValue.retain(groups)
    endif 

    int num_tags_max = tags.length 
    int group_count = JArray.count(groups)
    uilistMenu listMenu = uiextensions.GetMenu("UIlistMenu") AS uilistMenu

    while True
        String order_str ="change order>"
        bool finished = false
        String tags_string = ""
        Trace("SelectAnimationsDialog","num_tags:"+num_tags+" num_tags_max:"+num_tags_max)
        while num_tags < num_tags_max && !finished
            String start_label = "<start "+activity+">"
            Trace("SelectAnimationsDialog"," start_label:"+start_label)
            String style_button = "change style: "+style+">"
            listMenu.ResetMenu()

            ; build the current tags
            tags_string = JoinStrings(tags,num_tags)
            ; Use the current set of tags 
            String tags_label = "tags:"+tags_string
            listMenu.AddEntryItem(actor_names)
            if num_actors > 1 
                listMenu.AddEntryItem(order_str)
            endif 
            listMenu.AddEntryItem(style_button)
            listMenu.AddEntryItem(tags_label)
            listMenu.AddEntryItem(start_label)

            ; there is at least one tag that can be removed 
            if 0 < num_tags 
                listMenu.AddEntryItem("<remove")
            endif 

            ; Add groups
            int i =  0
            while i < group_count
                String group = JArray.getStr(groups,i)
                listMenu.AddEntryItem(group)
                i += 1
            endwhile

            ; just give up
            listMenu.AddEntryItem("<cancel>")

            listMenu.OpenMenu()
            String button =  listMenu.GetResultString()
            if JMap.hasKey(group_tags, button)
                button = GroupDialog(group_tags, button)
            endif 

            if button == start_label 
                finished = true
            elseif button == style_button
                SetStyleDialog()
                style_button = style+">"
            elseif button == order_str 
                ShiftActorsLeft() 
            elseif button == "<cancel>"
                JValue.release(groups)
                return empty
            elseif button == "<remove"
                num_tags -= 1
            elseif button != "-continue-" && button != actor_names && button != tags_label
                if button != "" 
                    tags[num_tags] = button 
                    num_tags += 1
                endif 
            endif 
        endwhile 
        sslBaseAnimation[] anims =  SexLab.GetAnimationsByTags(num_actors, tags_string, "", true)
        if anims.length > 0
            JValue.release(groups)
            return anims 
        else
            Trace("SelectAnimationsDialog","No animations found for: "+tags_string, True )
            if num_tags > 0
               num_tags -= 1 
            endif 
        endif 
    endwhile 
    JValue.release(groups)
    return empty
EndFunction

Function AddGroupTags(uilistMenu listMenu, int group_tags, String group) global
    int tags = JMap.getObj(group_tags, group, 0)
    if tags != 0 
        int i = 0
        int count = JArray.count(tags)
        while i < count
            String tag = JArray.getStr(tags, i, "")
            if tag != ""
                listMenu.AddEntryItem(tag)
            endif
            i += 1
        endwhile 
    endif 
EndFunction

String Function GroupDialog(int group_tags, String group)  global
    uilistMenu listMenu = uiextensions.GetMenu("UIlistMenu") AS uilistMenu
    listMenu.ResetMenu()
    listMenu.AddEntryItem("<back")
    AddGroupTags(listMenu, group_tags, group) 
    listMenu.OpenMenu()
    String button =  listMenu.GetResultString()
    if button == "<back"
        button = "-continue-"
    endif 
    Trace("GroupDialog","button:"+button)
    return button
EndFunction 