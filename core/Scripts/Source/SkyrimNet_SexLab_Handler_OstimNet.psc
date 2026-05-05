ScriptName SkyrimNet_SexLab_Handler_OstimNet extends Quest 

Bool Property found = False Auto
Quest Property ostimnet_actions = None Auto
Faction Property OStimActorCountFaction Auto

Function Trace(String func, String msg, Bool notification=False) global
EndFunction


Quest Function CheckRequirements() Global
    return None 
EndFunction

bool Function Setup() 
    return false 
EndFunction

bool Function StartAffectionSceneExecute(Actor speaker, Actor target, String tag)
    return false
EndFunction 

bool Function StartSexActionExecute(Actor speaker, Actor target, Actor part0, Actor part1, Actor part2, String tag, String subtag)
    return false
EndFunction 