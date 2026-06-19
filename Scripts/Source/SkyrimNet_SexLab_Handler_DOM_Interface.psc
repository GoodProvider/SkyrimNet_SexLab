Scriptname SkyrimNet_SexLab_Handler_DOM_Interface extends Quest 


; Checks if the actor is a dom slave 
Bool Function IsDOMSlave(Actor akActor) global
    return false 
EndFunction

; Hands off the slave to SkyrimNet_DOM Target_Menu_Selection
Bool Function Target_Menu_Selection(Actor target, Actor player) global
    return false
EndFunction

String Function HandleOrgasmDenied(Actor akActor) global
    return "" 
EndFunction

Function DOMSlave_Orgasmed(Actor slave, String msg) global
EndFunction

Bool Function Orgasm_Desired(Actor akActor) global
    return false 
EndFunction