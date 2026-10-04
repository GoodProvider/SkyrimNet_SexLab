Scriptname SkyrimNet_SexLab_Decorators


import SkyrimNet_SexLab_Main
import SkyrimNet_SexLab_Utilities
import PO3_SKSEFunctions

Function Trace(String func, String msg, Bool notification=False) global
    String logged = SkyrimNet_SexLab_WebUI.TraceLog("SkyrimNet_SexLab_Decorators", func, msg)
    if notification
        Debug.Notification(msg)
    endif 
EndFunction


;----------------------------------------------------------------------------------------------------
; Decorators 
;----------------------------------------------------------------------------------------------------
Function RegisterDecorators() global
    SkyrimNetApi.RegisterDecorator("sexlab_get_threads", "SkyrimNet_SexLab_Decorators", "Get_Threads")
    SkyrimNetApi.RegisterDecorator("sexlab_get_player_los_distance", "SkyrimNet_SexLab_Decorators", "Player_LOS_Distance")
    SkyrimNetApi.RegisterDecorator("sexlab_intent", "SkyrimNet_SexLab_Decorators", "Intent")
    SkyrimNetApi.RegisterDecorator("sexlab_activities", "SkyrimNet_SexLab_Decorators", "Activities")
    SkyrimNetApi.RegisterDecorator("sexlab_ostim_player", "SkyrimNet_SexLab_Decorators", "Ostim_Player")
    SkyrimNetApi.RegisterDecorator("sexlab_cum", "SkyrimNet_SexLab_Decorators", "Cum")
    ;SkyrimNetApi.RegisterDecorator("sexlab_nudity", "SkyrimNet_SexLab_Decorators", "Is_Nudity")
    ;SkyrimNetApi.RegisterDecorator("sexlab_speaker_info", "SkyrimNet_SexLab_Decorators", "Speaker_Info")
EndFunction

String Function Get_Threads(Actor speaker) global
    SkyrimNet_SexLab_Scene_Manager manager = Game.GetFormFromFile(0x800, "SkyrimNet_SexLab.esp") as SkyrimNet_SexLab_Scene_Manager
    if manager == None 
        Trace("Get_Threads","manger is None, aborting")
        return "{}" 
    endif 
    String json = manager.GetThreadsJson(speaker) 
    Trace("Get_Threads", "json:"+json)
    return json
EndFunction 

String Function Outfit_HasStrippedItems(Actor speaker) global 
    int obj = JMap.object() 
    bool has_stripped_items = False
    SkyrimNet_SexLab_Main main = Game.GetFormFromFile(0x800, "SkyrimNet_SexLab.esp") as SkyrimNet_SexLab_Main
    if main == None
        Trace("Outfit_HasStrippedItems", "ERROR: Failed to get SkyrimNet_SexLab_Main form", True)
    else
        ; Check if the actor has undressed items, they could put on 
        if main.HasStrippedItems(speaker) 
            has_stripped_items = True
        else
            has_stripped_items = False
        endif 
        Trace("Outfit_HasStrippedItems",speaker.GetDisplayName()+" has stripped items:"+has_stripped_items)
    endif
    JMap.setInt(obj, "has_stripped_items", has_stripped_items as Int) 
    String json = SkyrimNet_SexLab_Utilities.ObjectToLowerCaseKeyJson(obj) 
    JValue.release(obj) 
    return json 
EndFunction

String Function Intent(Actor speaker) global 
    SkyrimNet_SexLab_Scene_Manager manager = Game.GetFormFromFile(0x800, "SkyrimNet_SexLab.esp") as SkyrimNet_SexLab_Scene_Manager
    if manager == None 
        Trace("Intent","manager is None, aborting")
        return "{}" 
    endif 

    SkyrimNet_SexLab_Scene sl_scene = manager.GetSceneByActor(speaker) 
    if sl_scene != None 
        int obj = JMap.object()
        JMap.setStr(obj, "intent", sl_scene.intent)
        String json = SkyrimNet_SexLab_Utilities.ObjectToLowerCaseKeyJson(obj)
        JValue.release(obj)
        return json
    endif 
    return "{}"
EndFunction 

String Function Activities(Actor akActor) global
    SkyrimNet_SexLab_Scene_Manager manager = Game.GetFormFromFile(0x800, "SkyrimNet_SexLab.esp") as SkyrimNet_SexLab_Scene_Manager
    int obj = JMap.object()
    String activity = ""
    if manager != None 
        SkyrimNet_SexLab_Scene sl_scene = manager.GetSceneByActor(akActor)
        if sl_scene != None && sl_scene.GetThread() != None
            activity = sl_scene.GetDescription()
        endif 
    endif 
    JMap.setStr(obj, "activity", activity)
    String json = SkyrimNet_SexLab_Utilities.ObjectToLowerCaseKeyJson(obj)
    JValue.release(obj)
    return json
EndFunction


String Function Ostim_Player(Actor akActor) global
    int value = SkyrimNetApi.GetConfigInt("Plugin_SkyrimNet_SexLab", "sexlab.ostim.player", 0)
    return ""+value
EndFunction

;----------------------------------------------------------------------------------------------------
; Cum left on an actor after an orgasm (StorageUtil, game-time days per place)
;   skyrimnet_sexlab_cum_time is the prompt's cheap gate; unset once every place has expired.
;----------------------------------------------------------------------------------------------------
Function RecordCum(Actor akActor, bool on_mouth, bool on_pussy, bool on_ass) global
    if akActor == None || !(on_mouth || on_pussy || on_ass)
        return
    endif
    float now = Utility.GetCurrentGameTime()
    if on_mouth
        StorageUtil.SetFloatValue(akActor, "skyrimnet_sexlab_cum_mouth", now)
    endif
    if on_pussy
        StorageUtil.SetFloatValue(akActor, "skyrimnet_sexlab_cum_pussy", now)
    endif
    if on_ass
        StorageUtil.SetFloatValue(akActor, "skyrimnet_sexlab_cum_ass", now)
    endif
    StorageUtil.SetFloatValue(akActor, "skyrimnet_sexlab_cum_time", now)
EndFunction

; 0 = cleared/none, 1 = warm (< 1 game hour), 2 = drying (until duration)
int Function CumAge(Actor akActor, String storage_key, float now, float duration, bool wash) global
    float t = StorageUtil.GetFloatValue(akActor, storage_key, 0.0)
    if t <= 0.0
        return 0
    endif
    float hours = (now - t) * 24.0
    if wash || hours >= duration || hours < 0.0
        StorageUtil.UnsetFloatValue(akActor, storage_key)
        return 0
    elseif hours < 1.0
        return 1
    endif
    return 2
EndFunction

String Function CumPlaces(bool mouth, bool pussy, bool ass) global
    String[] p = Utility.CreateStringArray(3)
    int n = 0
    if pussy
        p[n] = "pussy"
        n += 1
    endif
    if mouth
        p[n] = "mouth"
        n += 1
    endif
    if ass
        p[n] = "ass"
        n += 1
    endif
    if n == 1
        return p[0]
    elseif n == 2
        return p[0]+" and "+p[1]
    elseif n == 3
        return p[0]+", "+p[1]+", and "+p[2]
    endif
    return ""
EndFunction

String Function Cum(Actor akActor) global
    if akActor == None
        return "{}"
    endif
    float duration = SkyrimNetApi.GetConfigFloat("Plugin_SkyrimNet_SexLab", "sexlab.cum.duration_hours", 4.0)
    bool wash = duration <= 0.0 || akActor.IsSwimming()
    float now = Utility.GetCurrentGameTime()
    int mouth = CumAge(akActor, "skyrimnet_sexlab_cum_mouth", now, duration, wash)
    int pussy = CumAge(akActor, "skyrimnet_sexlab_cum_pussy", now, duration, wash)
    int ass = CumAge(akActor, "skyrimnet_sexlab_cum_ass", now, duration, wash)
    if mouth == 0 && pussy == 0 && ass == 0
        StorageUtil.UnsetFloatValue(akActor, "skyrimnet_sexlab_cum_time")
    endif

    int obj = JMap.object()
    ; warm/drying: every place; *_mouth: the only place still visible on a clothed actor
    JMap.setStr(obj, "warm", CumPlaces(mouth == 1, pussy == 1, ass == 1))
    JMap.setStr(obj, "drying", CumPlaces(mouth == 2, pussy == 2, ass == 2))
    JMap.setInt(obj, "warm_mouth", (mouth == 1) as int)
    JMap.setInt(obj, "drying_mouth", (mouth == 2) as int)
    String json = SkyrimNet_SexLab_Utilities.ObjectToLowerCaseKeyJson(obj)
    JValue.release(obj)
    return json
EndFunction

String Function Player_LOS_Distance(Actor akActor) global
    Actor player = Game.GetPlayer() 
    float distance = player.GetDistance(akActor) 
    int los 
    if player.hasLOS(akActor) 
        los = 1
    else 
        los = 0
    endif 

  
    int obj = JMap.object() 
    JMap.setFlt(obj,"distance",distance)
    JMap.setInt(obj,"los",los) 
    String json = SkyrimNet_SexLab_Utilities.ObjectToLowerCaseKeyJson(obj) 
    JValue.release(obj)
    return json 
EndFunction 

String Function Is_Nudity(Actor akActor) global
    ; 32 off top
    ; 52 and 49 off bottom 
    bool topless = false
    bool bottomless = false 
    if akActor != None 
        Form body = akActor.GetEquippedArmorInSlot(32)
        Form pelvis_primary = akActor.GetEquippedArmorInSlot(52)
        Form pelvis_secondary = akActor.GetEquippedArmorInSlot(49)

        if body == None 
            topless = true  
        endif 
        if pelvis_primary == None && pelvis_secondary == None && body == None 
            bottomless = true 
        endif
    endif 
    
    int obj = JMap.object()
    JMap.setInt(obj, "topless", topless as Int)
    JMap.setInt(obj, "bottomless", bottomless as Int)
    String json = SkyrimNet_SexLab_Utilities.ObjectToLowerCaseKeyJson(obj)
    JValue.release(obj)
    return json
EndFunction