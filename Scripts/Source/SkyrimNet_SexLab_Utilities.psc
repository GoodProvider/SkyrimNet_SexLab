Scriptname SkyrimNet_SexLab_Utilities

; ------------------------------------------------------------
; Trace for Utilities
; ------------------------------------------------------------
Function Trace(String func, String msg, Bool notification=False) global
    msg = "[SkyrimNet_SexLab_Utilities."+func+"] "+msg
    Debug.Trace(msg)
    if notification
        Debug.Notification(msg)
    endif 
EndFunction

; ------------------------------------------------------------
; Combines Actors or Strings into natual lanuage list 
; will make a natrual sentence with comma and 'and' 
; filter is an int[] array 0 - false and 1 - true
; ------------------------------------------------------------
String Function JoinActors(ACtor[] actors, String noun = "") global 
    int[] filter = Utility.CreateIntArray(actors.length, 1)
    return JoinActorsFiltered(actors,filter,noun,True)
EndFunction 

String Function JoinActorsFiltered(Actor[] actors, int[] filter,  String Noun = "", Bool ignore_filter=False) global 
    String[] strings = Utility.CreateStringArray(actors.length) 
    int i = actors.length - 1 
    while 0 <= i 
        if actors[i] == None 
            strings[i] = "None"
        else
            strings[i] = actors[i].GetDisplayName() 
        endif 
        i -= 1 
    endwhile 
    ;Trace("JoinActorsFiltered",strings)
    if ignore_filter
        return JoinStrings(strings, noun)
    else
        return JoinStringsFiltered(strings, filter, noun)
    endif 
EndFunction 

String Function JoinStrings(String[] strings, bool add_is_are=False) global 
    int[] filter = Utility.CreateIntArray(strings.length, 1)

    int total = strings.length 
    int i = 0
    int count = strings.length
    string joined = "" 
    while i < count 
        if joined != "" 
            if total > 2
                joined += ", "
            endif
            if i == count - 1 
                joined += " and "
            endif
        endif
        joined += strings[i]
        i += 1  
    endwhile 
    joined = JoinIsAre(joined, total, add_is_are) 
    ;Trace("JoinStrings","strings: "+strings+" add_is_are: "+add_is_are+" joined: "+joined)
    return joined
EndFunction 

String Function JoinStringsFiltered(String[] strings, int[] filter, Bool add_is_are = false) global 
    int total = 0
    int i = 0
    int count = strings.length
    while i < count 
        if filter[i] == 1
            total += 1 
        endif 
        i += 1
    endwhile 

    i = 0
    int j = total 
    string joined = "" 
    while i < count
        if filter[i] == 1
            if joined != "" 
                if total > 2
                    joined += ", "
                endif
                if j == count - 1 
                    joined += " and "
                endif
            endif
            joined += strings[i]
            j += 1  
        endif 
        i += 1 
    endwhile 
    joined = JoinIsAre(joined, total, add_is_are) 
    ;Trace("JoinStringsfilter","strings: "+strings+" filter: "+filter+" add_is_are: "+add_is_are+" total: "+total+" joined: "+joined)
    return joined
EndFunction

String Function JoinIsAre(String joined, int total, bool add_is_are) global
    if add_is_are && total > 0 
        if total == 1 
            joined += " is "
        else 
            joined += " are "
        endif 
    endif 
    return joined 
EndFunction 

String Function JoinStringToArray(String[] strings, int[] filter) global 
    String array = "" 
    int i = strings.length - 1 
    while 0 <= i 
        if filter[i] == 1
            if array != "" 
                array += ", "
            endif 
            array += "\""+strings[i]+"\""
        endif 
        i -= 1
    endwhile
    array = "["+array+"]"
    ;Trace("JoinStringToArray","strings:"+strings+" filter: "+filter+" array: "+array)
    return array
EndFunction 

; ------------------------------------------------------------
; Narration Wrappers 
; ------------------------------------------------------------

Function ContinueScene(Actor source=None, Actor target=None, bool optional=False) global 
    String msg = ""
    If source != None 
        if target != None 
            msg = "continue scene that includes "+source.GetDisplayName()+" and "+target.GetDisplayName()
        else
            msg = "continue scene that includes "+source.GetDisplayName()
        endif 
    else 
            msg = "continue scene"
    endif
    DirectNarration_Optional("continue scene", msg, source, target, optional)
EndFunction 

Function DirectNarration_Optional(String event_type, String msg, Actor source=None, Actor target=None, bool optional=False) global
;    msg = CheckDuplicate("DirectNarration_Optional", source, msg)

    SkyrimNet_SexLab_Main main = Game.GetFormFromFile(0x800, "SkyrimNet_SexLab.esp") as SkyrimNet_SexLab_Main

    float unit_meter = 0.01465
    float distance = (unit_meter*main.direct_narration_max_distance) + 1 
    if source != None 
        Actor player = Game.GetPlayer()
        if player == source 
            distance = 0 
        else
            distance = unit_meter*player.GetDistance(source) 
        endif 
    endif 

    String type = "" 
    int last_audio = SkyrimNetAPI.GetTimeSinceLastAudioEnded()/1000 ; in seconds
    if last_audio >= main.direct_narration_cool_off && distance <= main.direct_narration_max_distance
        SkyrimNetApi.DirectNarration(msg, source, target)
        ;SkyrimNetApi.RegisterEvent(event_type, msg, source, target)
        type = "direct"
    else 
        if !optional && msg != ""
            SkyrimNetApi.RegisterEvent(event_type, msg, source, target)
            type = "event"
        else 
            type = "skipped"
        endif 
    endif 

    if source != None 
        msg += " source:"+source.GetDisplayName()
    endif 
    if target != None 
        msg += " target:"+target.GetDisplayName()
    endif
    Trace("DirectNarration_Optional","type:"+type+" last_audio_secs:"+last_audio+">?"+main.direct_narration_cool_off+" distance:"+distance+"<?"+main.direct_narration_max_distance+" msg:"+msg)
EndFunction

Function DirectNarration(String msg, Actor source=None, Actor target=None) global

    msg = CheckDuplicate("DirectNarration", source, msg)

    SkyrimNetApi.DirectNarration(msg, source, target)
    ;SkyrimNetApi.RegisterEvent("sexlab_event", msg, source, target)
    if source != None 
        msg += " source:"+source.GetDisplayName()
    endif 
    if target != None 
        msg += " target:"+target.GetDisplayName()
    endif
    Trace("DirectNarration", msg)
EndFunction


Function RegisterEvent(String event_name, String msg, Actor source=None, Actor target=None) global
    if msg != "" 
        msg = CheckDuplicate("RegisterEvent", source, msg)

        SkyrimNetApi.RegisterEvent(event_name, msg, source, target)

        ; Sets up the log message
        if source != None 
            msg += " source:"+source.GetDisplayName()
        endif 
        if target != None 
            msg += " target:"+target.GetDisplayName()
        endif
        Trace("RegisterEvent", "event_name:"+event_name+" msg:"+msg)
    endif 
EndFunction

String Function CheckDuplicate(String func, Actor source, String msg) global
    if msg == ""
        return msg
    endif 
    String storage_key = "sexlab_narration_last_msg"
    String old = StorageUtil.GetStringValue(source, storage_key, "")
    Bool old_equals_new = old == msg
    if old == msg
        Trace(func+".CheckDuplicate", "changing duplicate `"+msg+"' to ''")
        return "" 
    else 
        StorageUtil.SetStringValue(source, storage_key, msg)
        return msg
    endif
EndFunction