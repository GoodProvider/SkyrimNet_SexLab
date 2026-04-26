Scriptname SkyrimNet_SexLab_Stats extends Quest 

int stats_any = 0 
int stats_vaginal_giving = 1
int stats_vaginal_getting = 2
int stats_oral_giving = 3 
int stats_oral_getting = 4
int stats_anal_giving = 5
int stats_anal_getting = 6 
int stats_orgy = 7
int stats_male = 8
int stats_female = 9
int stats_creature = 10
int stats_raped = 11
int stats_raping = 12
int stats_next_start = 13
int stats_size = 22

String[] types
String[] messages

String storage_first_time = "sexlab_first_time"

SkyrimNet_SexLab_Main main = None 

Function Trace(String func, String msg, Bool notification=False) global
EndFunction

Function Setup() 
EndFunction

; This isn't working right now, not sure why :( 
String Function First_Sex(Actor[] actors, sslThreadController thread) 
EndFunction 

int Function IncreaseFirstTime(Actor akActor, String group, String name) 
EndFunction

int Function GetFirstTime(Actor akActor, String group, String name) 
EndFunction 

Function SetDefaults(Actor akActor) 
EndFunction 

Function SetDefaults_CallBack(String response, int success)
Endfunction 

String[] Function ListFirstTime(Actor akActor, String group) 
    ; will set the character's defaults 

    String[] keys = new String[1]
    if group == "experiences"
        int num_stats = 0 
        int type = 0
        int[] freqs = Utility.CreateIntArray(stats_size) 
        while type < stats_next_start 
            String storage_key = storage_first_time+"_"+group+"_"+types[type]
            freqs[type] = StorageUtil.GetIntValue(akActor, storage_key, 0) 
            if freqs[type] > 0 
                num_stats += 1 
            endif 
            type += 1 
        endwhile 

        keys = Utility.CreateStringArray(num_stats) 
        int i = 0 
        type = 0
        while type < stats_next_start 
            if freqs[type] > 0 
                keys[i] = types[type]
;                Trace("ListFirstTime",akActor.GetDisplayName()+" type:"+types[type]+" freq:"+freqs[type]+" key:"+keys[i])
                i += 1 
            endif 
            type += 1 
        endwhile 
    else
        String storage_key = storage_first_time+"_"+group
        StorageUtil.StringListSort(akActor, storage_key)
        keys = StorageUtil.StringListToArray(akActor, storage_key)
    endif 
    Trace("ListFirstTime",akActor.GetDisplayName()+" "+keys)
    return keys
EndFunction