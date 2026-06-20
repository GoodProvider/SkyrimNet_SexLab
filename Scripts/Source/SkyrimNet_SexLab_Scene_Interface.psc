Scriptname SkyrimNet_SexLab_Scene_Interface extends Quest

Import SkyrimNet_SexLab_Utilities

SkyrimNet_SexLab_Main Property main Auto
SkyrimNet_SexLab_Stages Property stages Auto
SkyrimNet_SexLab_Scene_Manager Property manager Auto 

; --------------------------------------------
; Scene id == index in scenes
; --------------------------------------------
int Property sid = 0 Auto 

; --------------------------------------------
; Style
; --------------------------------------------
String Property STYLE_FORCEFULLY = "forcefully" Auto
String Property STYLE_NORMALLY = "normally" Auto
String Property STYLE_GENTLY = "gently" Auto
String Property style Auto

; --------------------------------------------
; Number Victims
; --------------------------------------------
int Property num_victims = 0 Auto 

; --------------------------------------------
; Names
; --------------------------------------------
String Property actor_names = "" Auto
String Property actor_names_json = ""Auto

String Property victim_names = ""Auto
String Property victim_names_json = ""Auto

String Property assailant_names = "" Auto

String Property creature_descriptions = "" Auto
String Property hermaphrodiate_names = "" Auto
String Property strapon_names = "" Auto

; --------------------------------------------
; Since returning a None array cause an error
; we set the empty
; --------------------------------------------
sslBaseAnimation[] Property empty = None Auto

; -------------------------------------------
; Activity
; -------------------------------------------
int Property ACTIVITY_STAGE_START = 0 Auto
int Property ACTIVITY_STAGE_ONGOING = 1 Auto
int Property ACTIVITY_STAGE_END = 2 Auto
String Property activity = "having sexual activities" Auto
String Property ACTIVITY_DEFAULT = "having sexual activities" Auto

; --------------------------------------------
; Status 
; --------------------------------------------
String Property STATUS_INACTIVE = "INACTIVE" Auto
String Property STATUS_SETUP = "SETUP" Auto
String Property STATUS_ACTIVE = "ACTIVE" Auto
String Property status = "INACTIVE" Auto

; --------------------------------------------
; Has Player 
; --------------------------------------------
bool property has_player = False Auto
bool property player_is_victim = False Auto

Function Trace(String func, String msg="", Bool notification=False)
    msg = "[SkyrimNet_SexLab_Scene_Interface."+func+"] sid:"+sid+" "+msg
    Debug.Trace(msg) 
    if notification
        Debug.Notification(msg)
    endif 
EndFunction

String Function GetString() 
    return " actors: "+'"'+actor_names+'"'\
          +" victims: "+'"'+victim_names+'"'\
          +" assailants: "+'"'+assailant_names+'"'\
          +" style:"+style
EndFunction 


Function Initialize(int _sid, SkyrimNet_SexLab_Scene_Manager _manager) 
    sid = _sid
    manager = _manager 
    main = manager.main
    stages = manager.stages 
    if !empty 
        empty = new sslBaseAnimation[1]
        empty[0] = None 
    endif 
EndFunction 

Function Release()
    style = STYLE_NORMALLY
    status = STATUS_INACTIVE 
EndFunction



; --------------------------------------
; Ensure Functions 
; --------------------------------------
int[] Function EnsureIntsLargeEnough(int[] ints, int total) global 
    if !ints 
        return Utility.CreateIntArray(total) 
    endif 
    if total <= ints.length
        return ints 
    endif 

    int[] _ints = Utility.CreateIntArray(total + 10) 
    int i = 0 
    int count = ints.length 
    while i < count 
        _ints[i] = ints[i]
        i += 1 
    endwhile 

    return _ints 
EndFunction 

String[] Function EnsureStringsLargeEnough(String[] strings, int num_strings) global 
    if !strings 
        return Utility.CreateStringArray(num_strings) 
    endif 
    if num_strings <= strings.length
        return strings 
    endif 

    String[] _strings = Utility.CreateStringArray(num_strings + 10) 
    int i = 0 
    int count = strings.length 
    while i < count 
        _strings[i] = strings[i]
        i += 1 
    endwhile 

    return _strings 
EndFunction 

Actor[] Function EnsureActorsLargeEnough(Actor[] actors_current, int total) global 
    if !actors_current
        return PapyrusUtil.ActorArray(total) 
    endif 
    if total <= actors_current.length
        return actors_current 
    endif 

    Actor[] _actors = PapyrusUtil.ActorArray(total + 10) 
    int i = 0 
    int count = actors_current.length 
    while i < count 
        _actors[i] = actors_current[i]
        i += 1 
    endwhile 

    return _actors 
EndFunction 

; ------------------------------------------------------
; Set Activity 
; ------------------------------------------------------

Function SetActivity(String _activity) 
    if activity == "sex" 
        activity = "having sexual activities"
    elseif activity == "affection"
        activity = "showing affection"
    else 
        activity = _activity
    endif 
    Trace("SetActivity","activity:"+activity)
EndFunction

String Function GetActivity()
    return activity 
EndFunction

; ------------------------------------------------------
; Set Style 
; ------------------------------------------------------
Function SetStyle(String _style) 
    if _style == "gentle" || _style == "gently"
        style = STYLE_GENTLY   
    elseif _style == "forceful" || _style == "forcefully"
        style = STYLE_FORCEFULLY
    else 
        style = STYLE_NORMALLY
    endif
EndFunction 
String Function GetStyle() 
    return style
EndFunction

String Function IsInactive() 
    return status == STATUS_INACTIVE 
EndFunction

; --------------------------------------------
; Get a Status message for the scene (start, are, finished) 
; --------------------------------------------
String Function GetActivityMessage(int activity_stage = -1) 
    String message = "are "+activity 
    if activity_stage == ACTIVITY_STAGE_START 
        message = "start "+activity
    elseif activity_stage == ACTIVITY_STAGE_END 
        message = "finished "+activity
    endif 
    if num_victims > 0
        return assailant_names+" "+message+" "+victim_names+"."
    endif 
    return actor_names+" "+message+"."
EndFunction 


; Selects the style of sex 
; 0 forcefully 
; 1 normally 
; 2 gently 
int Function SetStyleDialog()
    String[] buttons = new String[3] 
    if num_victims > 0 
        buttons[0] = "Violent "+activity
        buttons[1] = activity
        buttons[2] = "Gentle "+activity
    else
        buttons[0] = "Forceful "+activity
        buttons[1] = activity
        buttons[2] = "Gentle "+activity
    endif 
    int button = SkyMessage.ShowArray("Change style to:", buttons, getIndex = true) as int 
    if button == 0 
        style = STYLE_FORCEFULLY
    elseif button == 2
        style = STYLE_GENTLY
    else 
        style = STYLE_NORMALLY
    endif 
EndFunction