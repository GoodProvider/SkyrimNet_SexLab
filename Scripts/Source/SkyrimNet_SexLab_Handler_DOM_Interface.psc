Scriptname SkyrimNet_SexLab_Handler_DOM_Interface extends Quest 

Bool Function Setup() 
    return Setup_CheckLinks()
EndFunction 

Bool Function Setup_CheckLinks()
    return true
EndFunction

; Checks if the actor is a dom slave 
Bool Function IsDOMSlave(Actor akActor)
    return false 
EndFunction

String Function HandleOrgasmDenied(Actor akActor) 
    return "" 
EndFunction

Function DOMSlave_Orgasmed(Actor slave, String msg)
EndFunction

Bool Function Orgasm_Desired(Actor akActor)
    return false
EndFunction

; OrgasmEngine DOM support: engine arousal change -> DOM arousal_factor
Function AddArousal(Actor akActor, float delta)
EndFunction

; 0-100 meter of how close DOM is to an orgasm (>= 50: DOM's values could produce one)
float Function OrgasmMeter(Actor akActor)
    return 0.0
EndFunction

; True when DOM's current values could produce an orgasm (aroused / arousable, not refractory)
Bool Function CouldOrgasm(Actor akActor)
    return false
EndFunction

; Engine push: prepay (cancel DOM's own recurring adds once per scene), mini-game delta, spread steps
Function DomSync(Actor akActor, float miniDelta, float daring, float naivety, bool prepay, bool hasPlayer)
EndFunction

; Light roll after a rise: IsOrgasmingAfterArousal(act base x share). DOM decides.
Function StepRoll(Actor akActor, bool hasPlayer, float share)
EndFunction

int Function GetThreads()
    return 0
EndFunction 

; ------------------------------------------------------------

Function Start_Masturbate(String intent, Actor speaker, Actor superior, String position="")
EndFunction

Function StartScene_Consensual_Two(String intent, Actor speaker, Actor Superior, Actor target, string style="", string method="", String direction="", String setting_name="")
EndFunction

; style omitted (ExecuteQuestFunction max 8 args / DOM_API); SexLab always gets style=""
Function StartScene_Nonconsensual_Two(String intent, Actor speaker, Actor superior, Actor target, Actor victim, string method="", String direction="", String setting_name="")
EndFunction

Function StartScene_Nonconsensual_Two_SpeakerVictim(String intent, Actor speaker, Actor superior, Actor target, string method="", String direction="", String setting_name="")
EndFunction

Function StartScene_Nonconsensual_Two_TargetVictim(String intent, Actor speaker, Actor superior, Actor target, string method="", String direction="", String setting_name="")
EndFunction