Scriptname SkyrimNet_SexLab_Handler_DOM extends Quest 

bool Property found = False Auto
SkyrimNet_SexLab_Main Property main Auto

Function Trace(String func, String msg, Bool notification=False) global
EndFunction

Function Setup()
EndFunction

; Increases the 
Bool Function IsDOMSlave(Actor akActor) global
    return false 
EndFunction

Bool Function Target_Menu_Selection(Actor target, Actor player) global
    return false
EndFunction

String Function HandleOrgasmDenied(Actor akActor) global
    return ""
EndFunction

Function DOMSlave_Orgasmed(Actor akActor, String msg) global
EndFunction

Bool Function Orgasm_Desired(Actor akActor) global
    return false
EndFunction