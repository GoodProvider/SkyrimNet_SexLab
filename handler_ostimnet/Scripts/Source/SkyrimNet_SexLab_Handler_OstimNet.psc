ScriptName SkyrimNet_SexLab_Handler_OstimNet extends Quest 

Bool Property found = False Auto
Quest Property ostimnet_actions = None Auto
SkyrimNet_SexLab_Main Property main Auto

Function Trace(String func, String msg, Bool notification=False) global
    msg = "[SkyrimNet_SexLab_Handler_OstimNet."+func+"] "+msg
    Debug.Trace(msg) 
    if notification
        Debug.Notification(msg)
    endif 
EndFunction

Function Setup()
    bool main_none = main == None
    bool ostimnet_none = ostimnet_actions == None
    if !main_none && !ostimnet_none
        main.ostimnet_found = true
        Trace("Setup","main.ostimnet_found set to true")
    else 
        main.ostimnet_found = false
        Trace("Setup","main.ostimnet_found set to false |- main: " + main_none + " ostimnet_actions: " + ostimnet_none)
    endif 
EndFunction

bool Function IsInOStim(Actor akActor) Global 
    return OActor.IsInOstim(akActor)
EndFunction

bool Function StartAffectionSceneExecute(Actor speaker, Actor target, String tag) Global
    SkyrimNet_SexLab_Handler_OstimNet this = Game.GetFormFromFile(0x800, "SkyrimNet_SexLab_Handler_OstimNet.esp") as SkyrimNet_SexLab_Handler_OstimNet
    if this.ostimnet_actions != None
        Trace("StartAffectionSceneExecute","speaker: "+speaker.GetDisplayName()+" target: "+target.GetDisplayName()+" tag: "+tag)
        (this.ostimnet_actions as TTON_Actions).StartAffectionSceneExecute(speaker, target, tag)
        Trace("StartAffectionSceneExecute","ostimnet_actions: "+(this.ostimnet_actions != None))
        return true
    Else
        Trace("StartAffectionSceneExecute","ostimnet_actions quest is None, cannot start affection scene")
    endif
    return false
EndFunction 

bool Function StartSexActionExecute(Actor speaker, Actor target, Actor part0, Actor part1, Actor part2, String tag, String subtag) Global
    SkyrimNet_SexLab_Handler_OstimNet this = Game.GetFormFromFile(0x800, "SkyrimNet_SexLab_Handler_OstimNet.esp") as SkyrimNet_SexLab_Handler_OstimNet

    Trace("StartSexActionExecute","speaker: "+speaker.GetDisplayName()+" target: "+target.GetDisplayName()+" tag: "+tag+" subtag: "+subtag)
    if this.ostimnet_actions != None
        (this.ostimnet_actions as TTON_Actions).StartSexActionExecute(target, None, None, None, None, tag, subtag)
        return true
    else
        Trace("StartSexActionExecute","ostimnet_actions quest is None, cannot start sex action")
    endif
    return false
EndFunction 