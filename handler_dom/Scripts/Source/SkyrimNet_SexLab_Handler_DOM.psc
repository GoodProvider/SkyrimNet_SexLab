Scriptname SkyrimNet_SexLab_Handler_DOM extends Quest 

bool Property found = False Auto
Quest Property d_api = None Auto
Quest Property d_sexlab = None Auto

Function Trace(String func, String msg, Bool notification=False) global
    msg = "[SkyrimNet_SexLab_Handler_DOM."+func+"] "+msg
    Debug.Trace(msg) 
    if notification
        Debug.Notification(msg)
    endif 
EndFunction

Quest Function CheckRequirements() Global
    if  MiscUtil.FileExists("Data/SkyrimNet_SexLab_Handler_DOM.esp") &&MiscUtil.FileExists("Data/DiaryOfMine.esm") && MiscUtil.FileExists("Data/SkyrimNet_DOM.esp") 
        return Game.GetFormFromFile(0x800, "SkyrimNet_SexLab_Handler_DOM.esp") as SkyrimNet_SexLab_Handler_DOM
    endif 
    return None 
EndFunction

Function Setup()
    if MiscUtil.FileExists("Data/DiaryOfMine.esm") && MiscUtil.FileExists("Data/SkyrimNet_DOM.esp")
        Quest DOM01 = Game.GetFormFromFile(0x00000D61, "DiaryOfMine.esm") AS Quest 
        found = True
        d_api = DOM01
        d_sexlab = DOM01
    Else
        found = False
        d_api = None
        d_sexlab = None
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
    ;DOM_Actor slave = SkyrimNet_DOM_API.GetSlave("SkyrimNet_SexLab_Main", "Orgasm_Combined", akActor) as Dom_Actor
;
    ;if slave != None 
        ;if slave.mind.is_aroused_for > 0
            ;return akActor.GetDisplayName()+" was denied an orgasm. "
        ;endif 
    ;endif 
    ;return ""
EndFunction

Function DOMSlave_Orgasmed(Actor akActor, String msg)
EndFunction

Bool Function Orgasm_Desired(Actor akActor)
    return false
EndFunction