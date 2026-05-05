Scriptname SkyrimNet_SexLab_Handler_UDNG extends Quest

bool Property found = False Auto
Quest Property group_devices = None Auto

Function Trace(String func, String msg, Bool notification=False) global
EndFunction


Quest Function CheckRequirements() Global
    return None 
EndFunction

bool Function Setup()
    return false 
EndFunction

Function UpdateDevices(Actor target)
EndFunction