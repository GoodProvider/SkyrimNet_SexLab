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

    msg = "[SkyrimNet_SexLab_Stats."+func+"] "+msg
    Debug.Trace(msg)
    if notification
        Debug.Notification(msg)
    endif 
EndFunction

Function Setup() 

    main = (self as Quest) as SkyrimNet_SexLab_Main 

    types = Utility.CreateStringArray(stats_size)
    types[stats_any] = "sex"
    types[stats_vaginal_giving] = "fucking pussy"
    types[stats_vaginal_getting] = "fucked in pussy"
    types[stats_oral_giving] = "fucking mouth"
    types[stats_oral_getting] = "fucked in mouth"
    types[stats_anal_giving] = "fucking ass"
    types[stats_anal_getting] = "fucked in ass"
    types[stats_orgy] = "orgy"
    types[stats_male] = "sex with male"
    types[stats_female] = "sex with female"
    types[stats_creature] = "sex with creature"
    types[stats_raped] = "raped"
    types[stats_raping] = "raping"

    messages = Utility.CreateStringArray(stats_size)
    int i = 0 
    while i < stats_next_start 
        messages[i] = types[i] 
        i += 1 
    endwhile 
EndFunction

; This isn't working right now, not sure why :( 
String Function First_Sex(Actor[] actors, sslThreadController thread) 

    Keyword ActorTypeCreature = Game.GetFormFromFile(0x13795, "Skyrim.esm") as Keyword
    Actor player = Game.GetPlayer() 
    sslBaseAnimation anim = thread.Animation

    String[] groups = Utility.CreateStringArray(stats_size) 
    int i = 0 
    while i < stats_next_start 
        groups[i] = "experiences"
        i += 1 
    endwhile 

    ; Happing in this animation to this actor 
    bool[] matched = Utility.CreateBoolArray(stats_size)
    ; first time it has happend
    int[] first_filter = Utility.CreateIntArray(stats_size) 

    bool vaginal_matched = anim.HasTag("vaginal")
    bool oral_matched = anim.HasTag("oral") || anim.HasTag("cunnilingus") || anim.HasTag("blowjob") || anim.HasTag("69")
    bool oral_both_matched = anim.HasTag("69")
    bool anal_matched = anim.HasTag("anal")
    bool orgy_matched = actors.length > 2 

    String msg = ""
    i = actors.length - 1
    while 0 <= i 

        int type = types.length - 1 
        while 0 <= type 
            matched[type] = False 
            first_filter[type] = 0
            type -= 1 
        endwhile 

        int next = stats_next_start
        bool rape = False 

        if anim.HasTag("tentacle") || anim.HasTag("tentacles")
            matched[next] = True
            groups[next] = "Races"
            types[next] = "tentacles"
            messages[next] ="sex with tentacles"
            next += 1 
        endif 

        int k = actors.length - 1 
        while 0 <= k 
            if k != i
                int gender = actors[k].GetLeveledActorBase().GetSex() ; actorLib.GetGender(actors[i])
                if gender == 1 
                    matched[stats_female] = True 
                else 
                    matched[stats_male] = True 
                endif
                if actors[k].HasKeyword(ActorTypeCreature)
                    matched[stats_creature] = True 
                endif 

                String[] names = new String[2] 
                names[0] = actors[k].GetRace().GetName()
                names[1] = actors[k].GetDisplayName() 
                String[] gs = new String[2] 
                gs[0] = "races"
                gs[1] = "partners"
                int j = 0 
                while j < 2 
                    int count = IncreaseFirstTime(actors[i], gs[j], names[j])
                    if count == 1 && next < stats_size
                        groups[next] = gs[j]
                        types[next] = names[j]
                        if j == 0 
                            messages[next] = "sex with a "+names[j]
                        else
                            messages[next] = "sex with "+names[j]
                        endif 

                        matched[next] = True 
                        next += 1 
                        ; msg += name+"'s first time having sex with a "+race_name+". "
                    endif 
                    j += 1 
                endwhile 
            endif 

            if thread.IsVictim(actors[k])
                if k == i
                    matched[stats_raped] = True
                endif 
                rape = True 
            endif

            k -= 1
        endwhile 

        matched[stats_any] = True
        if actors.length == 1
            ; ignore masturbating
        else
            matched[stats_vaginal_giving] = vaginal_matched && i > 0
            matched[stats_vaginal_getting] = vaginal_matched && i == 0
            matched[stats_oral_giving] = oral_both_matched || (i == 1 && oral_matched)
            matched[stats_oral_getting] = oral_both_matched || (i == 0 && oral_matched)
            matched[stats_anal_giving] = i == 1 && anal_matched
            matched[stats_anal_getting] = i == 0 && anal_matched
            matched[stats_orgy] = orgy_matched
            if rape && !matched[stats_raped]
                matched[stats_raping] = True
            endif 
        endif 

        String name = actors[i].getDisplayName() 
        type = next - 1
        String bleeding = ""
        bool at_least_one = false
        while 0 <= type
            if matched[type] 
                int count = IncreaseFirstTime(actors[i],groups[type], types[type]) 
                if count == 1 
                    int gender = actors[i].GetLeveledActorBase().GetSex()
                    if main.virgin_blood_enabled
                        if type == stats_vaginal_getting && gender == 1 
                            bleeding += name+"'s pussy is bleeding."
                        endif 
                        if type == stats_anal_getting
                            bleeding += name+"'s ass is bleeding."
                        endif 
                    endif 
                    at_least_one = True 
                    first_filter[type] = 1
                else 
                    first_filter[type] = 0 
                endif 
            endif 
            type -= 1 
        endwhile 

        String first_string = ""
        if at_least_one
            String m = ""
            if first_filter[stats_any] == 1  && False 
                m = name+"'s first time having sex. "
            else
                m = name+"'s first time "+SkyrimNet_SexLab_Utilities.JoinStringsFiltered(messages,first_filter)+". "
            endif 
            first_string += m 
        endif 
        first_string += bleeding 
        Trace("First_Sex",name+": "+first_string)
        msg += first_string 
        i -= 1
    endwhile
    return msg 
EndFunction 

int Function IncreaseFirstTime(Actor akActor, String group, String name) 
    String storage_key = storage_first_time+"_"+group
    StorageUtil.StringListAdd(akActor, storage_key, name, false)

    storage_key = storage_first_time+"_"+group+"_"+name 
    int value = StorageUtil.GetIntValue(akActor, storage_key, 0) + 1
    StorageUtil.SetIntValue(akActor, storage_key, value)
    return value 
EndFunction

int Function GetFirstTime(Actor akActor, String group, String name) 
    String storage_key = storage_first_time+"_"+group+"_"+name 
    int value = StorageUtil.GetIntValue(akActor, storage_key, 0)
    return value 
EndFunction 

Function SetDefaults(Actor akActor) 
    String storage_key = storage_first_time+"_default_set"
    int value = StorageUtil.GetIntValue(akActor, storage_key, 0)
    if value == 1
        return 
    endif 

    SkyrimNetApi.SendCustomPromptToLLM("helpers/sexlab_default_sex_life", "meta", "", \
        self, "SkyrimNet_SexLab_Stats", "SetDefaults_CallBack")
    Trace("SetDefaults",akActor.GetDisplayName())
EndFunction 

Function SetDefaults_CallBack(String response, int success)
    if !success
        return 
    endif 
    Trace("SetDefaults_CallBack",response)
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