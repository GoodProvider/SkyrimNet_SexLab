Scriptname SkyrimNet_SexLab_Handler_DOM extends Quest 

bool Property found = False Auto
Quest Property d_api = None Auto
Quest Property d_sexlab = None Auto

Function Trace(String func, String msg, Bool notification=False) global
EndFunction

Quest Function CheckRequirements() Global
    return None 
EndFunction

Function Setup()
EndFunction


ReferenceAlias Function GetActor(Actor akActor)
    return None 
EndFunction

; Increases the 
Bool Function IsDOMSlave(Actor akActor)
    return false 
EndFunction

Bool Function Target_Menu_Selection(Actor target, Actor player)
    return false
EndFunction

ReferenceAlias Function GetDOMSlave(String file, String func, Actor akActor)
    return None 
EndFunction

String Function HandleOrgasmDenied(Actor akActor)
    return ""
EndFunction

Function DOMSlave_Orgasmed(Actor akActor, String msg)
EndFunction

Bool Function Orgasm_Desired(Actor akActor)
    return false
EndFunction