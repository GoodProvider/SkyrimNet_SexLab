ScriptName SkyrimNet_SexLab_Handler_OstimNet extends Quest 

TTON_Actions Property ostimnet_actions = None Auto

Function Trace(String func, String msg, Bool notification=False) global
    msg = "[SkyrimNet_SexLab_Handler_OstimNet."+func+"] "+msg
    Debug.Trace(msg) 
    if notification
        Debug.Notification(msg)
    endif 
EndFunction

Function Setup()
    bool ostimnet_none = ostimnet_actions == None

    UnRegisterForModEvent("SkyrimNet_SexLab_OstimNet_AffectionStart")
    UnRegisterForModEvent("SkyrimNet_SexLab_OstimNet_SexStart")
    if ostimnet_actions != None
        RegisterForModEvent("SkyrimNet_SexLab_OstimNet_AffectionStart", "AffectionStart")
        RegisterForModEvent("SkyrimNet_SexLab_OstimNet_SexStart", "SexStart")
        Trace("Setup","main.ostimnet_found set to true")
    else 
        Trace("Setup","main.ostimnet_found set to false |- ostimnet_actions: " + ostimnet_none)
    endif 
EndFunction

Event AffectionStart(Form speaker_form, Form target_form, String tag)
    Actor speaker = speaker_form as Actor 
    Actor target = target_form as Actor 
    if ostimnet_actions != None
        ostimnet_actions.StartAffectionSceneExecute(speaker, target, tag)
        Trace("AffectionStart","speaker: "+speaker.GetDisplayName()+" target: "+target.GetDisplayName()+" tag: "+tag)
    Else
        Trace("AffectionStart","ostimnet_actions quest is None, cannot start affection scene")
    endif
EndEvent 

Event SexStart(Form speaker_form, Form target_form, String tag) 
    Actor speaker = speaker_form as Actor 
    Actor target = target_form as Actor 
    if ostimnet_actions != None
        ostimnet_actions.StartSexActionExecute(speaker, target, None, None, None, tag, "")
        Trace("StartSexActionExecute","speaker: "+speaker.GetDisplayName()+" target: "+target.GetDisplayName()+" tag: "+tag)
    else
        Trace("StartSexActionExecute","ostimnet_actions quest is None, cannot start sex action")
    endif
EndEvent 