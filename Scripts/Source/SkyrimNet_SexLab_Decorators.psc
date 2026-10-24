Scriptname SkyrimNet_SexLab_Decorators

; Every SkyrimNet decorator is C++ (SKSE_Source/src/Decorators.cpp, registered at kDataLoaded):
;   sexlab_get_threads, sexlab_activities, sexlab_cum, sexlab_has_cum, sexlab_cum_count,
;   sexlab_has_stripped_items, sexlab_npc_stop_allowed, sexlab_verbose.
; This script is the Papyrus surface of the state behind them.

Function Trace(String func, String msg, Bool notification=False) global
    String logged = SkyrimNet_SexLab_WebUI.TraceLog("SkyrimNet_SexLab_Decorators", func, msg)
    if notification
        Debug.Notification(msg)
    endif 
EndFunction

;----------------------------------------------------------------------------------------------------
; Threads (sexlab_get_threads / sexlab_activities / threads.json)
;   Scene.PushThread sets its thread_obj after each refresh and removes it once the thread is no
;   longer listed; Scene_Manager.PushDomThreads replaces the DOM threads.
;----------------------------------------------------------------------------------------------------
Function Threads_Set(int sid, int thread_obj, Actor[] positions) global Native
Function Threads_Remove(int sid) global Native
Function Threads_SetDom(String threads_json) global Native
; Same JSON as sexlab_get_threads for this speaker (None = player).
String Function Threads_Get(Actor speaker) global Native

;----------------------------------------------------------------------------------------------------
; Cum left on an actor after an orgasm (C++ state, co-saved; game-time per place).
;----------------------------------------------------------------------------------------------------
Function RecordCum(Actor akActor, bool on_mouth, bool on_pussy, bool on_ass) global Native
; Places that still have cum ("pussy,mouth,ass" order, comma separated; "" when none).
;   TargetMenu clean_cum panel reads this via papyrusQuery.
String Function CumParts(Actor akActor) global Native
; Clears one place (mouth|pussy|ass) or "all"; returns the places left (CumParts format).
String Function CumClear(Actor akActor, String part) global Native

; Clean one place (mouth|pussy|ass) or "all". SexLab has no per-place overlay clear,
; so ClearCum then re-apply the places still recorded.
Function ClearCumPart(Actor akActor, String part) global
    if akActor == None
        return
    endif
    String left = CumClear(akActor, part)
    bool mouth = StringUtil.Find(left, "mouth") >= 0
    bool pussy = StringUtil.Find(left, "pussy") >= 0
    bool ass = StringUtil.Find(left, "ass") >= 0
    SexLabFramework sexlab = SexLabUtil.GetAPI()
    if sexlab != None
        sexlab.ClearCum(akActor)
        if mouth || pussy || ass
            sexlab.AddCum(akActor, pussy, mouth, ass)
        endif
    endif
    Trace("ClearCumPart", akActor.GetDisplayName()+" part:"+part+" left mouth:"+mouth+" pussy:"+pussy+" ass:"+ass)
EndFunction

;----------------------------------------------------------------------------------------------------
; Stripped clothing (sexlab_has_stripped_items: outfit_dress / outfit_undress eligibility).
;   C++ mirror of StorageUtil skyrimnet_sexlab_storage_items, kept by Main.psc; co-saved.
;----------------------------------------------------------------------------------------------------
Function SetStrippedItems(Actor akActor, bool has_items) global Native
