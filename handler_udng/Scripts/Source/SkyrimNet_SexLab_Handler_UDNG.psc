Scriptname SkyrimNet_SexLab_Handler_UDNG extends Quest

bool Property found = False Auto
Quest Property group_devices = None Auto
SkyrimNet_SexLab_Main Property main Auto

Function Trace(String func, String msg, Bool notification=False) global
    msg = "[SkyrimNet_SexLab_Handler_UDNG."+func+"] "+msg
    Debug.Trace(msg) 
    if notification
        Debug.Notification(msg)
    endif
EndFunction

Function Setup()
    bool main_none = main == None
    bool udng_none = group_devices == None
    if !main_none && !udng_none
        ;main.udng_found = true
        Trace("Setup","main.udng_found set to true")
    else 
        ;main.udng_found = false
        Trace("Setup","main.udng_found set to false | main: " + main_none + " udng: " + udng_none)
    endif 
EndFunction

Function UpdateDevices(Actor target) global 
    SkyrimNet_SexLab_Handler_UDNG this = Game.GetFormFromFile(0x800, "SkyrimNet_SexLab_Handler_UDNG.esp") as SkyrimNet_SexLab_Handler_UDNG

    if this.group_devices != None
        Trace("UpdateDevices","Updating devices for target: "+target.GetDisplayName())
        (this.group_devices as SkyrimNet_UDNG_Groups).UpdateDevices(target) 
    endif
EndFunction