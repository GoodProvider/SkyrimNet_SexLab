Scriptname SkyrimNet_SexLab_Utilities

Function Trace(String func, String msg, Bool notification=False) global
    String logged = SkyrimNet_SexLab_WebUI.TraceLog("SkyrimNet_SexLab_Utilities", func, msg)
    if notification
        Debug.Notification(msg)
    endif 
EndFunction

; Vanilla SexLabUtil SKSE versions are ~16000–17000 (1.62–1.66).
; P+ registers the same plugin name with a packed 2.x.x.x version in the high bits.
bool Function IsSexLabPPlus() global
    int v = SKSE.GetPluginVersion("SexLabUtil")
    if v <= 0
        v = SexLabUtil.GetVersion()
    endif
    return v > 20000
EndFunction

; P+ FindSimilarSceneStage hops every animation in SetAnimations; pass one only.
sslBaseAnimation[] Function PickOneAnimation(sslBaseAnimation[] animations) global
    if !animations || animations.length <= 1
        return animations
    endif
    sslBaseAnimation[] one = new sslBaseAnimation[1]
    one[0] = animations[Utility.RandomInt(0, animations.length - 1)]
    return one
EndFunction

String Function GetDisplayName(Actor akActor) global
    if akActor == None 
        return "none"
    endif 
    return akActor.GetDisplayName()
EndFunction 

; SexLab owns creature vs non-creature. Race key only for SexLab creature genders (2/3).
String Function GetRaceKeyForActor(SexLabFramework sexlab, Actor akActor) global
    if akActor == None || sexlab == None
        return ""
    endif
    int gender = sexlab.GetGender(akActor)
    if gender < 2
        return ""
    endif
    ActorBase base = akActor.GetLeveledActorBase()
    if base == None
        return ""
    endif
    Race r = base.GetRace()
    if r == None
        return ""
    endif
    String rk = sslCreatureAnimationSlots.GetRaceKey(r)
    if !rk
        return ""
    endif
    return rk
EndFunction

String Function IntToHex(int value) global
    if value == 0
        return "0"
    endif
    String s = ""
    while value > 0
        int nibble = Math.LogicalAnd(value, 0xF)
        s = StringUtil.GetNthChar("0123456789abcdef", nibble) + s
        value = Math.RightShift(value, 4)
    endwhile
    return s
EndFunction

; Hex entity UUID -> decimal string (SKSE native). Decimal input returned unchanged.
String Function UuidToDecimalString(String entityUuid) global native


; ------------------------------------------------------------
; Timestamps
; A reasonable timestamp is acceptable. 
; ------------------------------------------------------------
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
; mask is an int[] array 0 - false and 1 - true
; ------------------------------------------------------------
String Function JoinActors(Actor[] actors, int num_actors=-1) global 
    if !actors 
        return "none"
    endif 
    if num_actors < 0 
        num_actors = actors.length
    endif 
    int i = 0
    string joined = "" 
    while i < num_actors 
        String name = "none"
        if actors[i] != None 
            name = actors[i].GetDisplayName() 
        endif 

        if joined != "" 
            if num_actors > 2
                joined += ", "
            endif
            if i == num_actors - 1 
                joined += " and "
            endif
        endif
        joined += name
        i += 1  
    endwhile 
    return joined
EndFunction 

String Function JoinActorsMasked(Actor[] actors, int[] mask, int num_actors = -1) global 
    if !actors 
        return "none"
    endif 

    if num_actors < 0 
        num_actors = actors.length
    endif 
    int i = 0
    string joined = "" 
    while i < num_actors 
        if mask[i] == 1 
            String name = "none"
            if actors[i] != None 
                name = actors[i].GetDisplayName() 
            endif 

            if joined != "" 
                if num_actors > 2
                    joined += ", "
                endif
                if i == num_actors - 1 
                    joined += " and "
                endif
            endif
            joined += name
        endif 
        i += 1  
    endwhile 
    return joined
EndFunction 

String Function JoinNouns(String[] strings, int num_nouns = -1, bool add_is_are=false) global 
    if !strings 
        return "none"
    endif 
    int[] mask = Utility.CreateIntArray(strings.length, 1)

    int total = strings.length 
    int i = 0
    if num_nouns < 0 
        num_nouns = strings.length 
    endif 
    string joined = "" 
    while i < num_nouns 
        if joined != "" 
            if total > 2
                joined += ", "
            endif
            if i == num_nouns - 1 
                joined += " and "
            endif
        endif
        joined += strings[i]
        i += 1  
    endwhile 
    return JoinIsAre(joined, total, add_is_are) 
EndFunction 

String Function JoinNounsMasked(String[] strings, int[] mask, int num_strings = -1, bool add_is_are = false) global 
    if !strings 
        return "none"
    endif 
    int total = 0
    int i = 0
    int count = strings.length
    while i < count 
        if mask[i] == 1
            total += 1 
        endif 
        i += 1
    endwhile 

    i = 0
    int j = 0
    string joined = "" 
    while i < count
        if mask[i] == 1
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

String Function JoinStringsToJson(String[] strings, int num_strings=-1) global 
    if !strings 
        return "none"
    endif 
    if num_strings == -1 
        num_strings = strings.length 
    endif 
    int arr = JArray.object()
    int i = 0
    while i < num_strings 
        JArray.addStr(arr, strings[i])
        i += 1
    endwhile
    String json = ObjectToLowerCaseKeyJson(arr)
    JValue.release(arr)
    return json
EndFunction 

String Function JoinStringsToJsonMasked(String[] strings, int[] mask=None, int num_strings=-1) global 
    if !strings 
        return "none"
    endif 
    if num_strings == -1 
        num_strings = strings.length 
    endif 
    int arr = JArray.object()
    int i = 0
    while i < num_strings 
        if mask == None || mask[i] == 1
            JArray.addStr(arr, strings[i])
        endif 
        i += 1
    endwhile
    String json = ObjectToLowerCaseKeyJson(arr)
    JValue.release(arr)
    return json
EndFunction 

String Function JoinActorsToJson(Actor[] actors, int num_actors=-1) global
    if !actors 
        return "none"
    endif 
    if num_actors == -1 
        num_actors = actors.length 
    endif 
    int arr = JArray.object()
    int i = 0
    while i < num_actors 
        String name = "none" 
        if actors[i] != None 
            name = actors[i].GetDisplayName()
        endif
        JArray.addStr(arr, name)
        i += 1
    endwhile 
    String json = ObjectToLowerCaseKeyJson(arr)
    JValue.release(arr)
    return json
EndFunction 

String Function JoinActorsToJsonMasked(Actor[] actors, int[] mask, int num_actors=-1) global
    if !actors 
        return "none"
    endif 
    if num_actors == -1 
        num_actors = actors.length 
    endif 
    int arr = JArray.object()
    int i = 0
    while i < num_actors 
        if mask[i] == 1 
            String name = "none" 
            if actors[i] != None 
                name = actors[i].GetDisplayName()
            endif
            JArray.addStr(arr, name)
        endif 
        i += 1
    endwhile 
    String json = ObjectToLowerCaseKeyJson(arr)
    JValue.release(arr)
    return json
EndFunction 

String Function JoinStrings(String[] strings, int num_strings=-1) global
    if !strings 
        return "none"
    endif 
    int i = 0 
    if num_strings < 0
        num_strings = strings.length 
    endif 
    string joined = ""
    while i < num_strings 
        if joined != ""
            joined += "," 
        endif 
        joined += strings[i]
        i += 1 
    endwhile 
    return joined 
EndFunction 

String Function JoinIntsToJson(int[] ints, int num_ints=-1) global 
    if !ints 
        return "none"
    endif 
    if num_ints == -1 
        num_ints = ints.length 
    endif 
    int arr = JArray.object()
    int i = 0
    while i < num_ints 
        JArray.addInt(arr, ints[i])
        i += 1
    endwhile
    String json = ObjectToLowerCaseKeyJson(arr)
    JValue.release(arr)
    return json
EndFunction 

String Function JoinJArrayStrToJson(int array) global 
    if array < 1
        return "none"
    endif 
    return ObjectToLowerCaseKeyJson(array)
EndFunction 

; ------------------------------------------------------------
; Narration Wrappers 
; ------------------------------------------------------------

Function ContinueActivity(Actor source=None, Actor target=None, bool optional_is_dropped=False) global 
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
    DirectNarration_Optional("continue activity", msg, source, target, optional_is_dropped)
EndFunction 

Bool Function NarrationCoolOffAllows(Actor source, Actor target) global
    SkyrimNet_SexLab_Main main = Game.GetFormFromFile(0x800, "SkyrimNet_SexLab.esp") as SkyrimNet_SexLab_Main
    if main == None 
        return False 
    endif 

    float unit_meter = 0.0142875
    float distance = 0
    if source != None 
        Actor player = Game.GetPlayer()
        if player == source 
            distance = 0 
        else
            distance = unit_meter*player.GetDistance(source) 
        endif 
    endif 

    int queue_size = SkyrimNetAPI.GetSpeechQueueSize()
    int last_audio = SkyrimNetAPI.GetTimeSinceLastAudioEnded()/1000 
    float time_current = Utility.GetCurrentRealTime() 
    float time_delta = time_current - main.direct_narration_last_time 
    float cool_off = SkyrimNetApi.GetConfigFloat("Plugin_SkyrimNet_SexLab", "sexlab.narration.cooldown", 20.0)
    float max_distance = SkyrimNetApi.GetConfigFloat("Plugin_SkyrimNet_SexLab", "sexlab.narration.maxDistance", 15.0)
    return time_delta > cool_off && queue_size == 0 && (last_audio >= cool_off && distance <= max_distance)
EndFunction

bool Function DirectNarration_Optional(String event_type, String msg, Actor source=None, Actor target=None, bool optional_is_dropped=False) global
    msg = CheckDuplicate("DirectNarration_Optional", source, msg, False, target)
    if msg == ""
        return false 
    endif 

    SkyrimNet_SexLab_Main main = Game.GetFormFromFile(0x800, "SkyrimNet_SexLab.esp") as SkyrimNet_SexLab_Main
    if main == None
        Trace("DirectNarration_Optional","main is None, aborting")
        return false
    endif

    String type = "" 
    if NarrationCoolOffAllows(source, target)
        SkyrimNetApi.DirectNarration(msg, source, target)
        main.direct_narration_last_time = Utility.GetCurrentRealTime() 
        type = "direct"
    else 
        if optional_is_dropped || msg == ""
            type = "dropped"
        else
            SkyrimNetApi.RegisterEvent(event_type, msg, source, target)
            type = "event"
        endif 
    endif 

    if source != None 
        msg += " source:"+source.GetDisplayName()
    endif 
    if target != None 
        msg += " target:"+target.GetDisplayName()
    endif
    Trace("DirectNarration_Optional","type:"+type+" msg:"+msg)
    return type != "dropped"
EndFunction

Function DirectNarration(String msg, Actor source=None, Actor target=None, bool purge_dialogue=False) global
    SkyrimNet_SexLab_Main main = Game.GetFormFromFile(0x800, "SkyrimNet_SexLab.esp") as SkyrimNet_SexLab_Main
    if main == None
        Trace("DirectNarration","main is None, aborting")
        return
    endif 
    msg = CheckDuplicate("DirectNarration", source, msg, False, target)
    if msg == ""
        return 
    endif 

    if purge_dialogue
          SkyrimNetApi.PurgeDialogue(True)
    endif 
    SkyrimNetApi.DirectNarration(msg, source, target)
    main.direct_narration_last_time = Utility.GetCurrentRealTime() 
    if source != None 
        msg += " source:"+source.GetDisplayName()
    endif 
    if target != None 
        msg += " target:"+target.GetDisplayName()
    endif
    Trace("DirectNarration", msg)
EndFunction


Function RegisterEvent(String event_name, String msg, Actor source=None, Actor target=None) global
    if msg == ""
        return 
    endif 
    msg = CheckDuplicate("RegisterEvent", source, msg, False, target)
    if msg == ""
        return 
    endif 
    SkyrimNetApi.RegisterEvent(event_name, msg, source, target)

    if source != None 
        msg += " source:"+source.GetDisplayName()
    endif 
    if target != None 
        msg += " target:"+target.GetDisplayName()
    endif
    Trace("RegisterEvent", "event_name:"+event_name+" msg:"+msg)
EndFunction

; Like RegisterEvent but skips CheckDuplicate — for scene changes that must never be dropped.
Function RegisterEventForce(String event_name, String msg, Actor source=None, Actor target=None) global
    if msg == ""
        return
    endif
    SkyrimNetApi.RegisterEvent(event_name, msg, source, target)

    if source != None
        msg += " source:"+source.GetDisplayName()
    endif
    if target != None
        msg += " target:"+target.GetDisplayName()
    endif
    Trace("RegisterEventForce", "event_name:"+event_name+" msg:"+msg)
EndFunction

String Function CheckDuplicate(String func, Actor source, String msg, Bool allow_continue_fallback=True, Actor target=None) global
    if msg == ""
        return msg
    endif 
    if source == None && target == None 
        return "" 
    endif 

    Actor storage_actor = source 
    if storage_actor == None 
        storage_actor = Game.GetPlayer() 
    endif 

    String storage_key = "sexlab_narration_last_msg"
    String old = StorageUtil.GetStringValue(storage_actor, storage_key, "")
    if old == msg
        Trace(func+".CheckDuplicate", "changing duplicate \""+msg+"\" to \"\"")
        if allow_continue_fallback && NarrationCoolOffAllows(source, target)
            ContinueActivity(source, target, True)
        endif 
        return "" 
    else 
        StorageUtil.SetStringValue(storage_actor, storage_key, msg)
        return msg
    endif
EndFunction

String Function JsonBool(bool value) global
    if value 
        return ":true"
    endif 
    return ":false"
EndFunction

; Recursively lowercase all JSON object keys (SKSE native). Invalid/empty -> "".
String Function JsonLowerCaseKeys(String json) global native

; SkyrimNet dashboard hotkey fields store VK; Papyrus RegisterForKey wants DX.
; Invalid/unmapped VK -> DX backslash (0x2B).
int Function VkToDxScanCode(int vk) global native

; JSON string literal (SKSE native): quoted and escaped; control bytes become unicode escapes.
String Function JsonQuote(String s) global native

; JC writeToFile form token, or null.
String Function JsonForm(Form akForm) global
    if akForm == None
        return "null"
    endif
    return JsonQuote(JString.encodeFormToString(akForm))
EndFunction

; Walk JMap/JArray/JFormMap/JIntMap. Do not call JValue.toJsonString (JC 4.2.13.1+ only).
String Function JValueToJsonString(int obj) global
    if obj == 0 || !JValue.isExists(obj)
        return "null"
    endif
    if JValue.isMap(obj)
        return JMapToJson(obj)
    elseif JValue.isArray(obj)
        return JArrayToJson(obj)
    elseif JValue.isFormMap(obj)
        return JFormMapToJson(obj)
    elseif JValue.isIntegerMap(obj)
        return JIntMapToJson(obj)
    endif
    return "null"
EndFunction

String Function JMapToJson(int obj) global
    String json = "{"
    bool first = true
    String map_key = JMap.nextKey(obj, "", "")
    while map_key != ""
        if !first
            json += ","
        endif
        first = false
        json += JsonQuote(map_key) + ":" + JMapValueToJson(obj, map_key)
        map_key = JMap.nextKey(obj, map_key, "")
    endwhile
    return json + "}"
EndFunction

String Function JMapValueToJson(int obj, String map_key) global
    int t = JMap.valueType(obj, map_key)
    if t == 2
        return JMap.getInt(obj, map_key)
    elseif t == 3
        return JMap.getFlt(obj, map_key)
    elseif t == 4
        return JsonForm(JMap.getForm(obj, map_key))
    elseif t == 5
        return JValueToJsonString(JMap.getObj(obj, map_key))
    elseif t == 6
        return JsonQuote(JMap.getStr(obj, map_key))
    endif
    return "null"
EndFunction

String Function JArrayToJson(int obj) global
    String json = "["
    int n = JArray.count(obj)
    int i = 0
    while i < n
        if i > 0
            json += ","
        endif
        json += JArrayValueToJson(obj, i)
        i += 1
    endwhile
    return json + "]"
EndFunction

String Function JArrayValueToJson(int obj, int index) global
    int t = JArray.valueType(obj, index)
    if t == 2
        return JArray.getInt(obj, index)
    elseif t == 3
        return JArray.getFlt(obj, index)
    elseif t == 4
        return JsonForm(JArray.getForm(obj, index))
    elseif t == 5
        return JValueToJsonString(JArray.getObj(obj, index))
    elseif t == 6
        return JsonQuote(JArray.getStr(obj, index))
    endif
    return "null"
EndFunction

String Function JFormMapToJson(int obj) global
    String json = "{"
    bool first = true
    Form map_key = JFormMap.nextKey(obj, None, None)
    while map_key != None
        if !first
            json += ","
        endif
        first = false
        json += JsonForm(map_key) + ":" + JFormMapValueToJson(obj, map_key)
        map_key = JFormMap.nextKey(obj, map_key, None)
    endwhile
    return json + "}"
EndFunction

String Function JFormMapValueToJson(int obj, Form map_key) global
    int t = JFormMap.valueType(obj, map_key)
    if t == 2
        return JFormMap.getInt(obj, map_key)
    elseif t == 3
        return JFormMap.getFlt(obj, map_key)
    elseif t == 4
        return JsonForm(JFormMap.getForm(obj, map_key))
    elseif t == 5
        return JValueToJsonString(JFormMap.getObj(obj, map_key))
    elseif t == 6
        return JsonQuote(JFormMap.getStr(obj, map_key))
    endif
    return "null"
EndFunction

String Function JIntMapToJson(int obj) global
    String json = "{"
    int[] keys = JIntMap.allKeysPArray(obj)
    if keys
        int i = 0
        int n = keys.length
        while i < n
            if i > 0
                json += ","
            endif
            int map_key = keys[i]
            json += JsonQuote(map_key) + ":" + JIntMapValueToJson(obj, map_key)
            i += 1
        endwhile
    endif
    return json + "}"
EndFunction

String Function JIntMapValueToJson(int obj, int map_key) global
    int t = JIntMap.valueType(obj, map_key)
    if t == 2
        return JIntMap.getInt(obj, map_key)
    elseif t == 3
        return JIntMap.getFlt(obj, map_key)
    elseif t == 4
        return JsonForm(JIntMap.getForm(obj, map_key))
    elseif t == 5
        return JValueToJsonString(JIntMap.getObj(obj, map_key))
    elseif t == 6
        return JsonQuote(JIntMap.getStr(obj, map_key))
    endif
    return "null"
EndFunction

; Serialize JValue -> JSON string with all object keys lowercased. Empty/invalid -> "{}".
; Walks JC containers; do not call JValue.toJsonString (missing on JC before 4.2.13.1).
String Function ObjectToLowerCaseKeyJson(int obj) global
    String json = JValueToJsonString(obj)
    if json == "" || json == "null"
        return "{}"
    endif
    json = JsonLowerCaseKeys(json)
    if !json
        return "{}"
    endif
    return json
EndFunction

; Load helpers/sexlab/*.prompt via RenderTemplate, then bind sl JSON with ParseString
; (same namespace as Stages AddActorDescriptionActors). Releases obj. Empty, error,
; leftover "{{", or inja text -> fallback so SkyrimNet errors are never DirectNarrated.
String Function RenderSlPrompt(String template_name, int obj, String fallback="") global
    String json = "{}"
    if obj > 0
        json = ObjectToLowerCaseKeyJson(obj)
        JValue.release(obj)
    endif
    String result = SkyrimNetApi.RenderTemplate(template_name, "sl", json)
    if result == ""
        Trace("RenderSlPrompt", "--- empty template:"+template_name+" json:"+json)
        return fallback
    endif
    String head = StringUtil.Substring(result, 0, 5)
    if head == "Error" || head == "error" || head == "ERROR"
        Trace("RenderSlPrompt", "--- render failed template:"+template_name+" json:"+json+" result:"+result)
        return fallback
    endif
    if StringUtil.Find(result, "inja.exception") >= 0
        Trace("RenderSlPrompt", "--- inja error template:"+template_name+" json:"+json+" result:"+result)
        return fallback
    endif
    String parsed = SkyrimNetApi.ParseString(result, "sl", json)
    if parsed != "" && StringUtil.Find(parsed, "inja.exception") < 0
        String parsed_head = StringUtil.Substring(parsed, 0, 5)
        if parsed_head != "Error" && parsed_head != "error" && parsed_head != "ERROR"
            result = parsed
        endif
    endif
    if StringUtil.Find(result, "{{") >= 0
        Trace("RenderSlPrompt", "--- leftover braces template:"+template_name+" json:"+json+" result:"+result)
        return fallback
    endif
    Trace("RenderSlPrompt", "--- template:"+template_name+" json:"+json+" result:"+result)
    return result
EndFunction

; ------------------------------------------------------------
; Ensure Functions 
; ------------------------------------------------------------
int[] Function EnsureIntsLargeEnough(int[] ints, int total, int default=0) global 
    if !ints 
        return Utility.CreateIntArray(total, default) 
    endif 
    if total <= ints.length
        return ints 
    endif 

    int[] _ints = Utility.CreateIntArray(total + 10,default) 
    int i = 0 
    int count = ints.length 
    while i < count 
        _ints[i] = ints[i]
        i += 1 
    endwhile 

    return _ints 
EndFunction 

String[] Function EnsureStringsLargeEnough(String[] strings, int num_strings, String default="") global 
    if !strings 
        return Utility.CreateStringArray(num_strings,default) 
    endif 
    if num_strings <= strings.length
        return strings 
    endif 

    String[] _strings = Utility.CreateStringArray(num_strings + 10,default) 
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

String Function ReplaceWord(String asSource, String asToFind, String asReplacement) global
    If asSource == "" || asToFind == ""
        Return asSource
    EndIf

    int iTargetLen = StringUtil.GetLength(asToFind)
    int iPos = StringUtil.Find(asSource, asToFind)
    
    While iPos >= 0
        bool bIsWordMatch = false
        int iSourceLen = StringUtil.GetLength(asSource)
        
        If iSourceLen == iTargetLen
            bIsWordMatch = true
            
        ElseIf iPos == 0
            If StringUtil.Substring(asSource, iTargetLen, 1) == " "
                bIsWordMatch = true
            EndIf
            
        ElseIf iPos == (iSourceLen - iTargetLen)
            If StringUtil.Substring(asSource, iPos - 1, 1) == " "
                bIsWordMatch = true
            EndIf
            
        Else
            If StringUtil.Substring(asSource, iPos - 1, 1) == " " && StringUtil.Substring(asSource, iPos + iTargetLen, 1) == " "
                bIsWordMatch = true
            EndIf
        EndIf
        
        If bIsWordMatch
            String sBefore = ""
            If iPos > 0
                sBefore = StringUtil.Substring(asSource, 0, iPos)
            EndIf
            
            String sAfter = ""
            If (iPos + iTargetLen) < iSourceLen
                sAfter = StringUtil.Substring(asSource, iPos + iTargetLen, 0)
            EndIf
            
            asSource = sBefore + asReplacement + sAfter
            
            iPos = StringUtil.Find(asSource, asToFind, iPos + StringUtil.GetLength(asReplacement))
        Else
            iPos = StringUtil.Find(asSource, asToFind, iPos + 1)
        EndIf
    EndWhile
    
    Return asSource
EndFunction