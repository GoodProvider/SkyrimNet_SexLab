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

; Scene start: adds the slave's open DOM punishment reasons to the Punish panel (OrgasmEngine.AddPunishReason)
Function SeedPunishReasons(Actor akActor)
EndFunction

; The slave refused to change its mini-game strategy: DOM punishment reason "refusing to have sex"
Function AddRefusedSexReason(Actor superior, Actor slaveActor)
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

; 0-100 level for the engine, the SexLab mirror and the prompts, from DOM's real state
float Function DomLevel(Actor akActor)
    return 0.0
EndFunction

; An order with no decision: DOM's obedience roll. True when the slave obeys.
Bool Function RollOrder(Actor superior, Actor slave)
    return true
EndFunction

; 0-1 probability that DOM's full end-of-act roll succeeds (random terms averaged; 0 when it cannot)
float Function OrgasmProbability(Actor akActor)
    return 0.0
EndFunction

; 0-1 probability that the next step roll succeeds. share > 0 replaces the remembered step size.
float Function StepProbability(Actor akActor, float share)
    return 0.0
EndFunction

; The HUD bar's total: DOM's arousal_factor. Each hundred is one step.
float Function DomArousal(Actor akActor)
    return 0.0
EndFunction

; The HUD bar's label, from DOM's real state ("orgasm impossible", "orgasm likely", ...)
String Function DomStepLabel(Actor akActor)
    return ""
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

; Upper-right DOM enjoyment list (sexlab.hud.dom_enjoyment): pushes every value behind DOM's orgasm decision.
Function PushEnjoymentBreakdown(Actor akActor)
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