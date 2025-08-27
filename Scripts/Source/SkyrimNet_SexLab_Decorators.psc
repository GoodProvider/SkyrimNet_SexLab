Scriptname SkyrimNet_SexLab_Decorators

import SkyrimNet_SexLab_Main
import SkyrimNet_SexLab_Stages

Function Trace(String msg, Bool notification=False) global
    msg = "[SkyrimNet_SexLab_Decorators] "+msg
    Debug.Trace(msg)
    if notification
        Debug.Notification(msg)
    endif 
EndFunction


;----------------------------------------------------------------------------------------------------
; Decorators 
;----------------------------------------------------------------------------------------------------
Function RegisterDecorators() global
    SkyrimNetApi.RegisterDecorator("sexlab_get_threads", "SkyrimNet_SexLab_Decorators", "Get_Threads")
    SkyrimNetApi.RegisterDecorator("sexlab_nudity", "SkyrimNet_SexLab_Decorators", "Is_Nudity")
    Trace("SkyrimNet_SexLab_Decorators: RegisterDecorattors called")
EndFunction

; animal & ActorTypeCreature & ACtorTypeFamiliar 
; skyrim.13798 & skyrim.13795 & skyrim.10ED7  
; 
; Bethesda-Used Body Slots
; 30 - Head: This is the general head slot, often used for full helmets that cover the entire head and hair.
; 31 - Hair: Used for hair, but also for items that replace or cover the hair, like some hoods or flight caps.
; 32 - Body: The main body slot for chest armor, cuirasses, and full outfits.
; 33 - Hands: The slot for gloves and gauntlets.
; 34 - Forearms: Often used in conjunction with the hands slot for gloves or armor that extends up the forearm.
; 35 - Amulet: The slot for necklaces and amulets.
; 36 - Ring: The slot for rings.
; 37 - Feet: The slot for boots and shoes.
; 38 - Calves: Often used with the feet slot for boots or leg armor that extends up the calf.
; 39 - Shield: The slot for shields.
; 40 - Tail: For races with tails, such as Argonians or Khajiit.
; 41 - Long Hair: A slot for longer hairstyles.
; 42 - Circlet: The slot for circlets and headbands.
; 43 - Ears: The slot for ear jewelry or other ear-related accessories.
;
; Additional, Commonly Used Slots (often for custom mods)
; Mod authors frequently use these "unnamed" slots to create items that can be worn alongside vanilla armor without causing conflicts. This allows for things like capes, backpacks, or layered clothing. The specific numbers and their agreed-upon uses are a community standard, not a hard-coded Bethesda rule.
; 
; 44 - Face/Mouth: For masks, goggles, etc.
; 45 - Neck: For scarves, shawls, and capes.
; 46 - Chest Primary / Outergarment: For chest pieces that can be worn over another armor.
; 47 - Back: A very popular slot for backpacks, wings, or other items worn on the back.
; 48 - Misc/FX: A general-purpose slot for anything that doesn't fit elsewhere.
; 49 - Pelvis Primary / Outergarment: For skirts, kilts, or other items worn around the waist.
; 52 - Pelvis Secondary / Undergarment: Used for underwear or items meant to be worn beneath other clothing.
; 55 - Face Alternate / Jewelry: For jewelry or other face accessories that don't fit in the other slots.
;
; NoModestyTop
; slot: 26, 16, 18, 29 : NoModesy 
;   
;                    Clothingbody , ArmorCuirass
; slot: 2,19 : Modesty, skyrim.A8657 , Skyrim.6C0EC
;
; slot: 19 NoBody
; slot: 

; 
String Function Is_Nudity(Actor akActor) global
    ; 32 off top
    ; 52 and 49 off bottom 
    bool topless = false
    bool bottomless = false 
    if akActor != None 
        Form body = akActor.GetEquippedArmorInSlot(32)
        Form pelvis_primary = akActor.GetEquippedArmorInSlot(52)
        Form pelvis_seconday = akActor.GetEquippedArmorInSlot(49)

        if body == None 
            topless = true 
        endif 
        if pelvis_primary == None && pelvis_seconday == None
            bottomless = true 
        endif
    endif 
    return "{\"topless\":"+topless+",\"bottomless\":"+bottomless+"}"
EndFunction

String Function Get_Threads(Actor speaker) global
    Debug.Trace("[SkyrimNet_SexLab] Get_Threads called for "+speaker.GetDisplayName())
    SkyrimNet_SexLab_Main main = Game.GetFormFromFile(0x800, "SkyrimNet_SexLab.esp") as SkyrimNet_SexLab_Main
    SkyrimNet_SexLab_Stages stages = (main as Quest) as SkyrimNet_SexLab_Stages

    if main == None
        Trace("[SkyrimNet_SexLab] Get_Threads: main is None",true)
        return ""
    endif

    Quest q = Game.GetFormFromFile(0xD62, "SexLab.esm")  as Quest 
    sslActorLibrary actorLib = q as sslActorLibrary
    sslCreatureAnimationSlots creatureLib = q as sslCreatureAnimationSlots


    sslThreadSlots ThreadSlots = Game.GetFormFromFile(0xD62, "SexLab.esm") as sslThreadSlots
    if ThreadSlots == None
        Trace("[SkyrimNet_SexLab] Get_Threads: ThreadSlots is None",true)
        return ""
    endif

    sslThreadController[] threads = ThreadSlots.Threads

    if threads.length == 0 
        main.active_sex = False 
    endif 

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
                threads_str += "{\"stage_description_has\":true,\"stage_description\":\""+stage_desc+"\","

                String strapon_names = GetNames(threads[i])
                threads_str += " \"strapon_names\":\""+strapon_names+"\","

                String futa_names = GetNames(threads[i], actorLib)
                threads_str += " \"futa_names\":\""+futa_names+"\","

                String creature_names = GetCreatures(threads[i])
                threads_str += " \"creature_names\":\""+creature_names+"\","

                threads_str += " \"location\":\""+loc+"\"}"
            else
                threads_str += Thread_Json(threads[i], actorLib)
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
    String json = "{\"speaker_having_sex\":"+speaker_having_sex
    json +=       ",\"speaker_name\":\""+speaker.GetDisplayName()+"\""
    json +=       ",\"threads\":["+threads_str+"]}"
    return json
EndFunction 


String Function Thread_Json(sslThreadController thread,sslActorLibrary actorLib) global

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

    String strapon_names = GetNames(thread)
    thread_str += " \"strapon_names\":\""+strapon_names+"\","

    String futa_names = GetNames(thread, actorLib)
    thread_str += " \"futa_names\":\""+futa_names+"\","

    String creature_names = GetCreatures(thread)
    thread_str += " \"creature_names\":\""+creature_names+"\","

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

String Function GetCreatures(sslThreadController thread) global
    Actor[] actors = thread.Positions
    String names = "" 
    int i = 0
    int count = actors.length 
    while i < count
        Race r = actors[i].GetRace() 
        if sslCreatureAnimationSlots.HasRaceType(r) 
            names += actors[i].GetDisplayName()+" is a "+r.GetName()+". "
        endif 
        i += 1
    endwhile
    return names
EndFunction

String Function GetNames(sslThreadController thread, sslActorLibrary actorLib = None) global
    Actor[] actors = thread.Positions
    int num_actors = 0
    int count = actors.length
    int i = 0
    while i < count
        if actorLib != None 
            if actorLib.GetTrans(actors[i]) == 0 
                num_actors += 1
            endif 
        else 
            if thread.IsUsingStrapon(actors[i])
                num_actors += 1
            endif 
        endif 
        i += 1
    endwhile

    String names = "" 
    i = 0
    int j = 0
    while i < count
        bool match =  false 
        if actorLib != None 
            if actorLib.GetTrans(actors[i]) == 0 
                match = true
            endif 
        else 
            if thread.IsUsingStrapon(actors[i])
                match = true
            endif 
        endif 

        if match
            if j > 0
                if num_actors > 2
                    names += ", "
                else 
                endif
                if j == count - 1 
                    names += " and "
                endif
            endif
            names += actors[i].GetDisplayName()
            j += 1  
        endif 
        i += 1
    endwhile 
    if names != "" 
        if actorLib != None 
            if num_actors == 1
                names += " is a hermaphrodite."
            else 
                names += " are hermaphrodites."
            endif
        else 
            if num_actors == 1
                names += " is using a strapon."
            else 
                names += " are using strapons."
            endif
        endif 
    endif 
    return names 
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