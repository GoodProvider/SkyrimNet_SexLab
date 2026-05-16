Scriptname SkyrimNet_SexLab_Handler_DOM extends Quest 

Function Trace(String func, String msg, Bool notification=False) global
    msg = "[SkyrimNet_SexLab_Handler_DOM."+func+"] "+msg
    Debug.Trace(msg) 
    if notification
        Debug.Notification(msg)
    endif 
EndFunction

Function Setup()
    SkyrimNet_SexLab_Main main = Game.GetFormFromFile(0x800, "SkyrimNet_SexLab_Main.esp") as SkyrimNet_SexLab_Main
    bool main_none = main == None
    bool dom_found = false 
    if MiscUtil.FileExists("Data/SkyrimNet_DOM.esp")
        dom_found = true 
    endif 
    if !main_none && !dom_found
        main.dom_found = true
        Trace("Setup","main.dom_found set to true")
    else 
        main.dom_found = false
        Trace("Setup","main.dom_found set to false |- main: " + main_none + " dom_found: " + dom_found)
    endif 
EndFunction


; Checks if the actor is a dom slave 
Bool Function IsDOMSlave(Actor akActor) global
    return SkyrimNet_DOM_API.IsDOMSlave(akActor)
EndFunction

; Hands off the slave to SkyrimNet_DOM Target_Menu_Selection
Bool Function Target_Menu_Selection(Actor target, Actor player) global
    return SkyrimNet_DOM_Menu.Target_Menu_Selection(target, player)
EndFunction

String Function HandleOrgasmDenied(Actor akActor) global
    DOM_Actor slave = SkyrimNet_DOM_API.GetSlave("SkyrimNet_SexLab_Main", "HandleOrgasmDenied", akActor) as Dom_Actor

    if slave != None 
        if slave.mind.is_aroused_for > 0
            return akActor.GetDisplayName()+" was denied an orgasm. "
        endif 
    endif 
    return ""
EndFunction

Function DOMSlave_Orgasmed(Actor slave, String msg) global
    SkyrimNet_SexLab_Main main_local = Game.GetFormFromFile(0x800, "SkyrimNet_SexLab_Main.esp") as SkyrimNet_SexLab_Main
    if main_local != None 
        main_local.HandleDomSlaveOrgasmed(slave, msg)
    endif
EndFunction

Bool Function Orgasm_Desired(Actor akActor) global
    DOM_Actor slave = SkyrimNet_DOM_API.GetSlave("SkyrimNet_SexLab_Main", "Orgasm_Combined", akActor) as Dom_Actor
    return slave != None && slave.mind.is_aroused_for > 0
EndFunction