Scriptname SkyrimNet_SexLab_Decorators

import SkyrimNet_SexLab_Main
import SkyrimNet_SexLab_Stages

;----------------------------------------------------------------------------------------------------
; Decorators 
;----------------------------------------------------------------------------------------------------
Function RegisterDecorators() global
    Debug.Trace("SkyrimNet_SexLab_Decorators: RegisterDecorattors called")
    SkyrimNetApi.RegisterDecorator("sexlab_get_public_sex_accepted", "SkyrimNet_SexLab_Decorators", "Get_Public_Sex_Accepted")
    SkyrimNetApi.RegisterDecorator("sexlab_get_threads", "SkyrimNet_SexLab_Decorators", "Get_Threads")
EndFunction

String Function Get_Public_Sex_Accepted(Actor akActor) global
    SkyrimNet_SexLab_Main main = Game.GetFormFromFile(0x800, "SkyrimNet_SexLab.esp") as SkyrimNet_SexLab_Main
    if main.public_sex_accepted
        return "{\"public_sex_accepted\":true}"
    else
        return "{\"public_sex_accepted\":false}"
    endif
EndFunction

String Function Get_Threads(Actor speaker) global
    Debug.Trace("[SkyrimNet_SexLab] Get_Threads called for "+speaker.GetDisplayName())
    SkyrimNet_SexLab_Main main = Game.GetFormFromFile(0x800, "SkyrimNet_SexLab.esp") as SkyrimNet_SexLab_Main
    SkyrimNet_SexLab_Stages stages = (main as Quest) as SkyrimNet_SexLab_Stages

    if main == None
        Debug.Notification("[SkyrimNet_SexLab] Get_Threads: main is None")
        return ""
    endif

    sslThreadSlots ThreadSlots = Game.GetFormFromFile(0xD62, "SexLab.esm") as sslThreadSlots
    if ThreadSlots == None
        Debug.Notification("[SkyrimNet_SexLab] Get_Threads: ThreadSlots is None")
        return ""
    endif

    sslThreadController[] threads = ThreadSlots.Threads

    int i = 0
    String threads_str = ""
    bool speaker_having_sex = false 
    String[] states = new String[15]
    while i < threads.length
        String s = (threads[i] as sslThreadModel).GetState()
        if i < states.Length
            states[i] = s
        endif

        if s == "animating" || s == "prepare"
            if threads_str != ""
                threads_str += ", "
            endif 
            String stage_desc = GetStageDescription(threads[i])
            if stage_desc != ""
                String loc = GetLocation(threads[i].Animation, threads[i].BedTypeId) 
                threads_str += "{\"stage_description_has\":true,\"stage_description\":\""+stage_desc+"\",\"location\":\""+loc+"\"}"
            else
                threads_str += Thread_Json(threads[i])
            endif 

            Actor[] actors = threads[i].Positions
            int j = actors.Length - 1
            while 0 <= j 
                if actors[j] == speaker
                    speaker_having_sex = true
                endif 
                j -= 1
            endwhile 
        endif 
        i += 1
    endwhile
    String json = ""
    if main.public_sex_accepted
        json = "{\"public_sex_accepted\":true"
    else
        json = "{\"public_sex_accepted\":false"
    endif
    json += ",\"speaker_having_sex\":"+speaker_having_sex
    json += ",\"speaker_name\":\""+speaker.GetDisplayName()+"\""
    json += ",\"threads\":["+threads_str+"]}"
    return json
EndFunction 


String Function Thread_Json(sslThreadController thread) global

    SkyrimNet_SexLab_Main main = Game.GetFormFromFile(0x800, "SkyrimNet_SexLab.esp") as SkyrimNet_SexLab_Main

    String thread_str = "{\"stage_description_has\":false, "

    Actor[] actors = thread.Positions
    String names = "" 
    int i = 0
    int num_victims = 0
    while i < actors.Length
        if names != "" 
            names += ","
        endif 
        names += "\""+actors[i].GetDisplayName()+"\""
        if thread.IsVictim(actors[i])
            num_victims += 1
        endif
        i += 1
    endwhile 
    if actors.length > 2 
        thread_str += "\"orgy\":true, "
    else 
        thread_str += "\"orgy\":false, "
    endif
    thread_str += "\"names\":["+names+"], "
    thread_str += "\"names_str\":\""+Thread_Narration(thread,"are")+"\", "

    if num_victims > 0
        String victims = "" 
        String aggressors = ""
        i = 0
        while i < actors.Length 
            if thread.IsVictim(actors[i])
                if victims != ""
                    victims += ", "
                endif 
                victims += "\""+actors[i].GetDisplayName()+"\""
            else
                if aggressors != ""
                    aggressors += ", "
                endif 
                aggressors += "\""+actors[i].GetDisplayName()+"\""
            endif
            i += 1
        endwhile
        thread_str += "\"victims\":["+victims+"], "
        thread_str += "\"aggressors\":["+aggressors+"], "
        thread_str += "\"rape\": true, "
    else
        thread_str += "\"rape\": false, "
    endif 

    sslBaseAnimation anim = thread.Animation
    i = 0
    String[] tags = anim.GetRawTags()
    String tags_str = "" 
    while i < tags.Length
        if tags_str != ""
            tags_str += ", "
        endif 
        tags_str += "\""+tags[i]+"\""
        i += 1
    endwhile
    thread_str += "\"tags\": ["+tags_str+"], "

    String[] positions = new String[7]
    positions[0] = "69"
    positions[1] = "cowgirl"
    positions[2] = "missionary"
    positions[3] = "kneeling"
    positions[4] = "doggy"
    positions[5] = "sitting"
    positions[6] = "standing"

    i = 0
    bool found = false
    String position = ""
    while i < positions.Length && position == ""
        if anim.HasTag(positions[i])
            position = positions[i]
            found = true
        endif
        i += 1
    endwhile
    thread_str += "\"position\":\""+position+"\","
    
    String loc = GetLocation(anim, thread.BedTypeId) 

    thread_str += "\"location\":\""+loc+"\","

    String emotion = ""
    if anim.HasTag("rough")
        emotion += " roughly"
    elseif anim.HasTag("loving")
        emotion += " lovingly"
    endif
    thread_str += "\"emotion\":\""+emotion+"\""

    thread_str += "}"
    return thread_str
EndFunction

String Function GetLocation(sslBaseAnimation anim, int bed) global
    String loc = "the floor"
    if  bed == 1
        loc = "a bedroll "
    elseif bed == 2
        loc = "a single bed "
    elseif bed == 3
        loc = "a double bed "
    endif 

    String[] on_furniture = new String[21]
    on_furniture[0] = "Table"
    on_furniture[1] = "LowTable"
    on_furniture[2] = "JavTable"
    on_furniture[3] = "Pole"
    on_furniture[4] = "wall"
    on_furniture[5] = "horse"
    on_furniture[6] = "Pillory"
    on_furniture[7] = "PilloryLow"
    on_furniture[8] = "Cage"
    on_furniture[9] = "Haybale"
    on_furniture[10] = "Xcross"
    on_furniture[11] = "WoodenPony"
    on_furniture[12] = "EnchantingWB"
    on_furniture[13] = "AlchemyWB"
    on_furniture[14] = "FuckMachine"
    on_furniture[15] = "chair"
    on_furniture[16] = "wheel"
    on_furniture[17] = "DwemerChair"
    on_furniture[18] = "NecroChair"
    on_furniture[19] = "Throne"
    on_furniture[20] = "Stockade"
    ; Add more if needed

    int i = 0
    bool found = false
    while i < on_furniture.Length && !found
        if anim.HasTag(on_furniture[i])
            loc = on_furniture[i]
            found = true
        endif
        i += 1
    endwhile

    if anim.HasTag("Cage")
        loc += " in a cage"
    elseif anim.HasTag("Gallows")
        loc += " in a gallows"
    elseif anim.HasTag("coffin")
        loc += " in a coffin"
    elseif anim.HasTag("floating")
        loc += " floating in air"
    elseif anim.HasTag("tentacles")
        loc += " with tentacles"
    elseif anim.HasTag("gloryhole") || anim.HasTag("gloryholem")
        loc += " through a gloryhole"
    endif

    return loc+" "
EndFunction 

bool Function SexLab_Thread_LOS(Actor akActor, sslThreadController thread) global
    Actor[] actors = thread.Positions
    int i = 0
    while i < actors.length 
        if akActor == actors[i] || akActor.HasLOS(actors[i])
            return true
        endif 
        i += 1
    endwhile 
    return false
endFunction 