Scriptname SkyrimNet_SexLab_PlayerRef extends ReferenceAlias  

int Property actorLock = 0 Auto

SkyrimNet_SexLab_Main Property main Auto  

Function Trace(String func, String msg, Bool notification=False) global
EndFunction

Event OnInit() 
EndEvent 

Event OnPlayerLoadGame()
EndEvent