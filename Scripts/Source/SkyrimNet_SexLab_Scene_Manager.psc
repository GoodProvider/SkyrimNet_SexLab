Scriptname SkyrimNet_SexLab_Scene_Manager extends Quest 

SkyrimNet_SexLab_Scene[] Property scenes Auto
SkyrimNet_SexLab_Scene[] tid_scenes

int Property STYLE_FORCEFULLY = 0 Auto 
int Property STYLE_NORMALLY = 1 Auto 
int Property STYLE_GENTLY = 2 Auto 
String[] style_strings 

Function Trace(String func, String msg, Bool notification=False) global
    msg = "[SkyrimNet_SexLab_Scene_Manager."+func+"] "+msg
    Debug.Trace(msg) 
    if notification
        Debug.Notification(msg)
    endif 
EndFunction

Function Setup() 
    if tid_scenes == None 
        tid_scenes = new SkyrimNet_SexLab_Scene[32]

        style_strings = new String[3]
        style_strings[STYLE_FORCEFULLY] = "forcefully"
        style_strings[STYLE_NORMALLY] = "normally"
        style_strings[STYLE_GENTLY] = "gently"

    endif 
EndFunction 
