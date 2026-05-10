Scriptname SkyrimNet_SexLab_Handler_OstimNet_PR extends ReferenceAlias  

SkyrimNet_SexLab_Handler_OstimNet Property handler Auto  

Function Trace(String func, String msg, Bool notification=False) global
    msg = "[SkyrimNet_SexLab_Handler_OstimNet_PlayerRef."+func+"] "+msg
    Debug.Trace(msg) 
    if notification
        Debug.Notification(msg)
    endif 
EndFunction

Event OnInit() 
    Trace("OnInit", "Initializing OstimNet handler for player reference")
    OnPlayerLoadGame() ; ensure setup runs on initial load as well as subsequent loads, in case player starts a new game without reloading a save. Also ensures setup runs before any other scripts that rely on it, since this is an alias of the player and will initialize before any quests or other objects.
EndEvent 

Event OnPlayerLoadGame()
    Trace("OnPlayerLoadGame", "Initializing OstimNet handler for player reference")
    handler.Setup()
EndEvent

