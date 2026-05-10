Scriptname SkyrimNet_SexLab_Handler_DOM extends Quest 

bool Property found = False Auto
Quest Property d_api = None Auto
Quest Property d_sexlab = None Auto

Function Trace(String func, String msg, Bool notification=False) global
EndFunction

Function Setup()
EndFunction

ReferenceAlias Function GetActor(Actor akActor) global
    return None 
EndFunction

; Increases the 
Bool Function IsDOMSlave(Actor akActor) global
    return false 
EndFunction

Bool Function Target_Menu_Selection(Actor target, Actor player) global
    return false
EndFunction

ReferenceAlias Function GetDOMSlave(String file, String func, Actor akActor) global
    return None 
EndFunction

String Function HandleOrgasmDenied(Actor akActor) global
    return ""
EndFunction

Function DOMSlave_Orgasmed(Actor akActor, String msg) global
EndFunction

Bool Function Orgasm_Desired(Actor akActor) global
    return false
EndFunction