Scriptname SkyrimNet_SexLab_DOM_Handler extends Quest 

bool Property found = False Auto
Quest Property d_api_internal  = None Auto
Quest Property d_sexlab_internal = None Auto
Quest property skyrimnet_dom_api = None Auto

Function Trace(String func, String msg, Bool notification=False) global
    msg = "[SkyrimNet_SexLab_DOM_Handler."+func+"] "+msg
    Debug.Trace(msg) 
    if notification
        Debug.Notification(msg)
    endif 
EndFunction

Function Setup()
    Quest DOM01 = Game.GetFormFromFile(0x00000D61, "DiaryOfMine.esm") AS Quest 
    Quest dom_utilities = Game.GetFormFromFile(0x800, "SkyrimNet_DOM.esp") AS Quest 
    if DOM01 != None && skyrimnet_dom_api != None
        found = True
        d_api_internal = DOM01
        d_sexlab_internal = DOM01
    else
        found = False 
        d_api_internal = None
        d_sexlab_internal = None
        skyrimnet_dom_api = None
    endif 
    Trace("CheckForDOM","DiaryOfMine (DOM) && SkyrimNet_DOM found: "+found)
EndFunction


ReferenceAlias Function GetActor(Actor akActor)
EndFunction

; Increases the 
Bool Function IsDOMSlave(Actor akActor)
    return false 
EndFunction

Bool Function Target_Menu_Selection(Actor target, Actor player)
    return false
EndFunction

ReferenceAlias Function GetDOMSlave(String file, String func, Actor akActor)
    return NOne 
EndFunction

String Function HandleOrgasmDenied(Actor akActor)
    ;DOM_Actor slave = SkyrimNet_SexLab_DOM.GetDOMSlave("SkyrimNet_SexLab_Main", "Orgasm_Combined", actors[i]) as Dom_Actor
    ;if slave != None 
    ;    if slave.mind.is_aroused_for > 0
    ;        return name+" was denied an orgasm. "
    ;    endif 
    ;endif 
    return ""
EndFunction

Function DOMSlave_Orgasmed(Actor akActor, String msg)
EndFunction

Bool Function Orgasm_Desired(Actor akActor)
    return false
EndFunction