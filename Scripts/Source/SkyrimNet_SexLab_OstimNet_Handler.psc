ScriptName SkyrimNet_SexLab_OstimNet_Handler extends Quest 

Bool Property found = False Auto
Quest Property ostimnet_actions = None Auto
Faction Property OStimActorCountFaction Auto

Function Trace(String func, String msg, Bool notification=False) global
    msg = "[SkyrimNet_SexLab_OstimNet_Handler."+func+"] "+msg
    Debug.Trace(msg) 
    if notification
        Debug.Notification(msg)
    endif 
EndFunction


Quest Function CheckRequirements() Global
    if MiscUtil.FileExists("Data/OStim.esp") && MiscUtil.FileExists("Data/TT_OStimNet.esp")
        return  Game.GetFormFromFile(0x8A0, "SkyrimNet_SexLab.esp") as SkyrimNet_SexLab_OstimNet_Handler
    endif 
    return None 
EndFunction

bool Function Setup() 
    if MiscUtil.FileExists("Data/OStim.esp") && MiscUtil.FileExists("Data/TT_OStimNet.esp")
        found = True 
        ostimnet_actions = Game.GetFormFromFile(0x800, "TT_OStimNet.esp") as Quest
        OStimActorCountFaction = Game.GetFormFromFile(0x801, "TT_OStimNet.esp") as Faction
    else 
        found = False 
        ostimnet_actions = None
        OStimActorCountFaction = None 
    endif 
    return found
EndFunction

bool Function StartAffectionSceneExecute(Actor speaker, Actor target, String tag)
    if ostimnet_actions != None
        (ostimnet_actions as TTON_Actions).StartAffectionSceneExecute(speaker, target, tag)
        return true
    endif
    return false
EndFunction 

bool Function StartSexActionExecute(Actor speaker, Actor target, Actor part0, Actor part1, Actor part2, String tag, String subtag)
    if ostimnet_actions != None
        (ostimnet_actions as TTON_Actions).StartSexActionExecute(target, None, None, None, None, tag, subtag)
        return true
    endif
    return false
EndFunction 