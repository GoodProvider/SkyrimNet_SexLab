Scriptname SkyrimNet_SexLab_Scene_Manager extends Quest 

SkyrimNet_SexLab_Scene[] Property scenes Auto
SkyrimNet_SexLab_Scene[] tid_scenes


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
    endif 
EndFunction 

int Property STYLE_FORCEFULLY = 0 Auto 
int Property STYLE_NORMALLY = 1 Auto 
int Property STYLE_GENTLY = 2 Auto 
String style_string_current = "" ; Used by Anims Dialogue, to return the Style
int[] thread_style
bool[] thread_started