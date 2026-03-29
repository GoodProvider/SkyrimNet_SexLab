Scriptname SkyrimNet_SexLab_Utilities

; ------------------------------------------------------------
; Trace for Utilities
; ------------------------------------------------------------

Function Trace(String func, String msg, Bool notification=False) global

    ;msg = GetTimeStamp()+" [SkyrimNet_SexLab_Utilities."+func+"] "+msg
    msg = "[SkyrimNet_SexLab_Utilities."+func+"] "+msg
    Debug.Trace(msg)
    if notification
        Debug.Notification(msg)
    endif 
EndFunction
String Function GetTimestamp() global
    int ts = Utility.GetCurrentRealTime() as int

    int s    = ts % 60
    int m    = (ts / 60) % 60
    int h    = (ts / 3600) % 24
    int days = ts / 86400

    ; Walk years from epoch (1970-01-01)
    int year = 1970
    bool yearDone = false
    while !yearDone
        int diy = 365
        if (year % 4 == 0) && ((year % 100 != 0) || (year % 400 == 0))
            diy = 366
        endif
        if days >= diy
            days -= diy
            year += 1
        else
            yearDone = true
        endif
    endwhile

    ; Walk months
    int month = 1
    bool monDone = false
    while !monDone
        int dim = 31
        if month == 4 || month == 6 || month == 9 || month == 11
            dim = 30
        elseif month == 2
            if (year % 4 == 0) && ((year % 100 != 0) || (year % 400 == 0))
                dim = 29
            else
                dim = 28
            endif
        endif
        if days >= dim
            days -= dim
            month += 1
        else
            monDone = true
        endif
    endwhile
    int day = days + 1

    ; Zero-pad each component
    String yy = year as String
    String mo = month as String
    if month < 10
        mo = "0" + mo
    endif
    String dd = day as String
    if day < 10
        dd = "0" + dd
    endif
    String hh = h as String
    if h < 10
        hh = "0" + hh
    endif
    String mn = m as String
    if m < 10
        mn = "0" + mn
    endif
    String ss = s as String
    if s < 10
        ss = "0" + ss
    endif

    return yy + ":" + mo + ":" + dd + " " + hh + ":" + mn + ":" + ss
EndFunction

; ------------------------------------------------------------
; Combines Actors or Strings into natural language list 
; will make a natural sentence with comma and 'and' 
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
    int j = 0
    string joined = "" 
    while i < count
        if filter[i] == 1
            if j > 0
                if total > 2
                    joined += ", "
                    if j == total - 1 
                        joined += "and "
                    endif
                else
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

Function ContinueActivity(Actor source=None, Actor target=None, bool optional=False) global 
    String msg = ""
    If source != None 
        if target != None 
            msg = "continue activity that includes "+source.GetDisplayName()+" and "+target.GetDisplayName()
        else
            msg = "continue activity that includes "+source.GetDisplayName()
        endif 
    else 
            msg = "continue activity"
    endif
    DirectNarration_Optional("continue activity", msg, source, target, optional)
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
    int queue_size = SkyrimNetAPI.GetSpeechQueueSize()
    int last_audio = SkyrimNetAPI.GetTimeSinceLastAudioEnded()/1000 ; in seconds
    float time_current = Utility.GetCurrentRealTime() 
    float time_delta = time_current - main.direct_narration_last_time 
    if time_delta > main.direct_narration_cool_off && queue_size == 0 && (last_audio >= main.direct_narration_cool_off && distance <= main.direct_narration_max_distance)
        SkyrimNetApi.DirectNarration(msg, source, target)
        main.direct_narration_last_time = time_current
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
    Trace("DirectNarration_Optional","type:"+type+" narration_delta:"+time_delta+" queue_size:"+queue_size+" last_audio_secs:"+last_audio+">?"+main.direct_narration_cool_off+" distance:"+distance+"<?"+main.direct_narration_max_distance+" msg:"+msg)
EndFunction

Function DirectNarration(String msg, Actor source=None, Actor target=None) global
    SkyrimNet_SexLab_Main main = Game.GetFormFromFile(0x800, "SkyrimNet_SexLab.esp") as SkyrimNet_SexLab_Main
    ; msg = CheckDuplicate("DirectNarration", source, msg)

    SkyrimNetApi.DirectNarration(msg, source, target)
    main.direct_narration_last_time = Utility.GetCurrentRealTime() 
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
