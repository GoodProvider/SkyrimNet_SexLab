Scriptname SkyrimNet_SexLab_Decorators

import SkyrimNet_SexLab_Main
import SkyrimNet_SexLab_Stages

Function Trace(String func, String msg, Bool notification=False) global
    msg = "[SkyrimNet_SexLab_Decorators."+func+"] "+msg
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
    SkyrimNetApi.RegisterDecorator("sexlab_get_player_los_distance", "SkyrimNet_SexLab_Decorators", "Player_LOS_Distance")
    SkyrimNetApi.RegisterDecorator("sexlab_nudity", "SkyrimNet_SexLab_Decorators", "Is_Nudity")
    Trace("SkyrimNet_SexLab_Decorators","RegisterDecorattors called")
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

String Function Player_LOS_Distance(Actor akActor) global 
    Actor player = Game.GetPlayer() 
    float distance = player.GetDistance(akActor) 
    bool los = player.hasLOS(akActor) 
    return "{\"distance\":"+distance+",\"los\":"+los+"}"
EndFunction 

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

String Function BooleanString(bool b) global
    if b 
        return ":true"
    else 
        return ":false"
    endif
EndFunction 

String Function Save_Threads(SexLabFramework SexLab) global 

    Actor akActor = None 
    sslThreadSlots ThreadSlots = (SexLab as Quest) as sslThreadSlots
    sslThreadController[] threads = ThreadSlots.Threads
    int i = threads.length - 1
    while 0 <= i && akActor == None 
        String s = (threads[i] as sslThreadModel).GetState()
        if s == "animating" || s == "prepare"
            akActor = threads[i].Positions[0]
        endif 
        i -= 1
    endwhile

    if akActor == None 
        akActor = Game.GetPlayer()
    endif

    String threads_json = SkyrimNet_SexLab_Decorators.Get_Threads(akActor)
    Miscutil.WriteToFile("Data/SKSE/Plugins/SkyrimNet_SexLab/threads.json", threads_json, append=False)
    return threads_json
EndFunction

String Function Get_Threads(Actor speaker) global
    SkyrimNet_SexLab_Main main = Game.GetFormFromFile(0x800, "SkyrimNet_SexLab.esp") as SkyrimNet_SexLab_Main
    SkyrimNet_SexLab_Stages stages = (main as Quest) as SkyrimNet_SexLab_Stages

    Trace("Get_Threads", main.counter+" "+speaker.GetDisplayName())

    if main == None
        Trace("Get_Threads","main is None")
        return ""
    endif

    Quest q = Game.GetFormFromFile(0xD62, "SexLab.esm")  as Quest 
    sslActorLibrary actorLib = q as sslActorLibrary
    sslCreatureAnimationSlots creatureLib = q as sslCreatureAnimationSlots

    sslThreadSlots ThreadSlots = Game.GetFormFromFile(0xD62, "SexLab.esm") as sslThreadSlots
    if ThreadSlots == None
        Trace("Get_Threads","ThreadSlots is None",true)
        return "{\"threads\":[]}"
    endif

    sslThreadController[] threads = ThreadSlots.Threads

    if threads.length == 0 
        main.active_sex = False 
    endif 

    int i = 0
    String threads_str = ""
    bool speaker_having_sex = false 
    while i < threads.length
        String s = (threads[i] as sslThreadModel).GetState()
        if s == "animating" || s == "prepare"
            if threads_str != ""
                threads_str += ", "
            endif 
            String desc = Get_Thread_Description(threads[i], actorLib)

            Trace("Get_Threads","description: "+desc)
            threads_str += "{\"description\":\""+desc+"\""
            String enjoyments = GetEnjoyments(threads[i])
            threads_str += ", \"enjoyments\":"+enjoyments
            
            Actor[] actors = threads[i].Positions
            String[] names = Utility.CreateStringArray(actors.Length)
            Float distance = -1 
            bool los = False 
            bool[] denied = stages.HasDescriptionOrgasmDenied(threads[i])
            int j = actors.Length - 1
            String names_array = ""
            while 0 <= j 
                if names_array != ""
                    names_array += ", "
                endif
                String name = actors[j].GetDisplayName()
                names[j] = name
                names_array += "\""+name+"\""
                if actors[j] == speaker 
                    distance = 0
                    los = True 
                    if !denied[j]
                        speaker_having_sex = True
                    endif 
                endif 
                j -= 1
            endwhile 
            if distance == -1 
                distance = speaker.GetDistance(actors[0])
                los = speaker.HasLOS(actors[0]) 
            endif 

            String[] nouns = Utility.CreateStringArray(0)
            String names_string = SkyrimNetAPI.JoinStrings(names, nouns)
            threads_str += ",\"names\":["+names_array+"]"
            threads_str += ",\"names_string\":\""+names_string+"\""
            threads_str += ",\"speaker_distance\":"+distance
            threads_str += ",\"speaker_los\""+BooleanString(los)
            main.counter += 1

            threads_str += "}"
        endif 
        i += 1
    endwhile


    ; Speaker Information 
    ; ------------------------
    String json = "{\"speaker_having_sex\""+BooleanString(speaker_having_sex)
    json +=       ",\"speaker_name\":\""+speaker.GetDisplayName()+"\""
    json +=       ",\"threads\":["+threads_str+"]"
    json +=       ",\"counter\":"+main.counter
    json +=       "}"
    Trace("Get_Threads",json)
    return json
EndFunction 

String Function Get_Thread_Description(sslThreadController thread, sslActorLibrary actorLib) global

    ; ----------------------------------------------------------------
    ; Style 
    ; ----------------------------------------------------------------
    SkyrimNet_SexLab_Main main = Game.GetFormFromFile(0x800, "SkyrimNet_SexLab.esp") as SkyrimNet_SexLab_Main
    int style = main.GetThreadStyle(thread.tid)
    String style_ly_str = "" 
    if style == main.STYLE_GENTLY
        style_ly_str = "gently " 
    elseif style == main.STYLE_FORCEFULLY
        style_ly_str = "forcefully " 
    endif
    String style_full_str = "" 
    if style == main.STYLE_GENTLY
        style_full_str = "gentle " 
    elseif style == main.STYLE_FORCEFULLY
        style_full_str = "forceful "
    endif

    ; ----------------------------------------------------------------
    ; Check for rape 
    ; ----------------------------------------------------------------
    Actor[] actors = thread.Positions
    int i = 0
    int num_victims = 0
    int num_actors = actors.Length
    String[] names = Utility.CreateStringArray(actors.Length)
    while i < num_actors
        names[i] = actors[i].GetDisplayName()
        if thread.IsVictim(actors[i])
            num_victims += 1
        endif
        i += 1
    endwhile 
    String[] nouns_empty = Utility.CreateStringArray(0)

    String msg = "" 
    if num_victims > 0 
        int num_aggressors = actors.Length - num_victims
        String[] victums = Utility.CreateStringArray(num_victims)
        String[] aggs = Utility.CreateStringArray(num_aggressors)
        i = 0
        int v_i = 0 
        int a_i = 0 
        while i < num_actors
            if thread.IsVictim(actors[i])
                victums[v_i] = names[i]
                v_i += 1 
            else    
                aggs[a_i] = names[i]
                a_i += 1 
            endif
            i += 1
        endwhile 
        String[] nouns = new String[2] 
        nouns[0] = style_ly_str+" raping"
        nouns[1] = style_ly_str+" raping"
        msg = SkyrimNetAPI.JoinStrings(aggs, nouns)+" "+SkyrimNetAPI.JoinStrings(victums, nouns_empty)+"."
    endif 

    ; ----------------------------------------------------------------
    ; Return description if it already has one. 
    ; ----------------------------------------------------------------
    String desc = GetStageDescription(thread)
    if desc != "" 
        if msg == "" && style != main.STYLE_NORMALLY
            Trace("Thread_Description","description: names: "+names)
            String[] nouns = new String[2] 
            nouns[0] = style_ly_str+" having a sexual experience."
            nouns[1] = style_ly_str+" having a sexual experience."
            msg = SkyrimNetAPI.JoinStrings(names, nouns)
        endif 
        msg += desc
    else 
        ; ----------------------------------------------------------------
        ; Positions 
        ; ----------------------------------------------------------------
        sslBaseAnimation anim = thread.Animation

        if anim.HasTag("standing")
            msg += " While standing, "
        elseif anim.HasTag("kneeling")
            msg += " While kneeling, "
        elseif anim.HasTag("sitting")
            msg += " While sitting, "
        elseif anim.HasTag("cowgirl")
            msg += " While in the cowgirl position, "
        elseif anim.HasTag("69")
            msg += " While in the 69 position, "
        elseif anim.HasTag("missionary")
            msg += " While in the missionary position, "
        elseif anim.HasTag("doggy")
            msg += " While in the doggy position, "
        endif 

        ; ----------------------------------------------------------------
        ; Check if rape or orgy
        ; ----------------------------------------------------------------
        if actors.length == 1 
            msg += names[0]+" is "+style_ly_str+"masturbating"
            if anim.HasTag("dildo")
                msg += " with a dildo"
            endif 
        else 
            if num_victims == 0 && actors.length > 2
                msg = SkyrimNetAPI.JoinStrings(names, nouns_empty)+" having an orgy. "
            endif 
            
            ; ----------------------------------------------------------------
            ; Add action 
            ; ----------------------------------------------------------------

            if anim.HasTag("Anal") || anim.HasTag("assjob")
                msg += names[1]+" is "+style_ly_str+"fucking "+names[0]+"'s ass"
            elseif anim.HasTag("Boobjob")
                msg += names[1]+" is getting a "+style_full_str+"boobjob from "+names[0]  
            elseif anim.HasTag("Thighjob")
                msg += names[1]+" is getting a "+style_full_str+"thighjob from "+names[0]
            elseif anim.HasTag("Fisting")
                msg += names[1]+" is "+style_ly_str+"fisting "+names[0]
            elseif anim.HasTag("Oral") || anim.HasTag("blowjob") || anim.HasTag("cunnilingus")
                msg += names[1]+" is getting "+style_full_str+"oral sex from "+names[0]   
            elseif anim.HasTag("Fingering")
                msg += names[1]+" is "+style_ly_str+"fingering "+names[0]
            elseif anim.HasTag("Footjob")
                msg += names[1]+" is getting a "+style_full_str+"footjob from "+names[0]
            elseif anim.HasTag("Handjob")
                msg += names[1]+" is getting a "+style_full_str+"handjob from "+names[0]
            elseif anim.HasTag("Dildo")
                msg += names[1]+" is "+style_ly_str+"fucking "+names[0]+" with with a dildo"
            elseif anim.HasTag("Vaginal")
                msg += names[1]+" is "+style_ly_str+"fucking "+names[0]+"'s pussy"
            elseif anim.HasTag("Kissing")
                msg += names[1]+" is "+style_ly_str+"kissing "+names[0]
            elseif anim.HasTag("Headpat")
                msg += names[1]+" is "+style_ly_str+"patting "+names[0]+"'s head"
            elseif anim.HasTag("Hugging")
                msg += names[1]+" is "+style_ly_str+"hugging "+names[0]
            elseif anim.HasTag("Spanking")
                msg += names[1]+" is "+style_ly_str+"spanking "+names[0]
            endif 
        endif

        ; ----------------------------------------------------------------
        ; Location
        ; ----------------------------------------------------------------
        String loc = GetLocation(anim, thread.BedTypeId)
        if loc != "" 
            msg += " on "+loc
        endif
        msg += ". "

        ; ----------------------------------------------------------------
        ; Add Bondage 
        ; ----------------------------------------------------------------
        String name = thread.Positions[0].GetDisplayName()
        if anim.HasTag("armbinder")
            msg += name+"'s arms are bound in an armbinder."
        elseif anim.HasTag("cuffs") || anim.HasTag("cuffed")
            msg += name+"'s arms are cuffed."
        elseif anim.HasTag("yoke")
            msg += name+"'s arms are bound in a yoke."
        elseif anim.HasTag("hogtied")
            msg += name+" is hogtied."
        elseif anim.HasTag("chastiy") || anim.HasTag("chastiybelt")
            msg += name+" is wearing a chastity belt."
        endif 
    endif 

    msg += " "+GetNames(thread) ; Strapon Names 
    msg += " "+GetNames(thread, actorLib) ; Futa Names 
    msg += " "+GetCreatures(thread) ; Creature Names

    return msg
EndFunction

String Function Thread_Json(sslThreadController thread,sslActorLibrary actorLib) global

    SkyrimNet_SexLab_Main main = Game.GetFormFromFile(0x800, "SkyrimNet_SexLab.esp") as SkyrimNet_SexLab_Main

    String thread_str = "{\"stage_description_has\":false"

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
        thread_str += ", \"orgy\":true"
    else 
        thread_str += ", \"orgy\":false"
    endif
    thread_str += ", \"names\":["+names+"]"
    thread_str += ", \"names_str\":\""+main.Thread_Narration(thread,"are")+"\""

    String style = ""

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
        thread_str += ", \"victims\":["+victims+"]"
        thread_str += ", \"aggressors\":["+aggressors+"]"
        thread_str += ", \"rape\": true"
    else
        thread_str += ", \"rape\": false"
    endif 

    sslBaseAnimation anim = thread.Animation
    i = 0
    String tags_str = GetTagsString(anim)
    thread_str += ", \"tags\": ["+tags_str+"]"

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
    thread_str += ", \"position\":\""+position+"\""
    
    String emotion = ""
    if anim.HasTag("rough")
        emotion += " roughly"
    elseif anim.HasTag("loving")
        emotion += " lovingly"
    endif
    thread_str += ",\"emotion\":\""+emotion+"\""
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
    SkyrimNet_SexLab_Main main = Game.GetFormFromFile(0x800, "SkyrimNet_SexLab.esp") as SkyrimNet_SexLab_Main
    Actor[] actors = thread.Positions
    String names = "" 
    int i = 0
    int count = actors.length 
    while i < count
        Race r = actors[i].GetRace() 
        if sslCreatureAnimationSlots.HasRaceType(r) 
            String name = actors[i].GetDisplayName()
            String race_name = r.GetName() 
            names += name+" is a "+race_name+". "
            int j = JArray.count(main.race_to_description) - 1 
            while 0 <= j 
                int creature = Jarray.getObj(main.race_to_description, j) 
                Race creature_race = JMap.getForm(creature,"form_") as Race 
                if creature_race == r 
                    names += JMap.getStr(creature, "description_")
                    j = -1 
                else 
                    j -= 1 
                endif 
            endwhile 
        endif 
        i += 1
    endwhile
    return names
EndFunction

String Function GetNamesArray(sslThreadController thread) global
    Actor[] actors = thread.Positions
    String names = "" 
    int i = 0
    while i < actors.Length
        if names != "" 
            names += ","
        endif 
        names += "\""+actors[i].GetDisplayName()+"\""
        i += 1
    endwhile 
    return "["+names+"]"
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

String Function GetEnjoyments(sslThreadController controller) global
    Actor[] actors = controller.positions 
    String str = ""
    int i = actors.length - 1 
    while 0 <= i 
        if str != "" 
            str += ", "
        endif 
        int enjoyment 
        sslActorAlias actorAlias = controller.ActorAlias(actors[i]) 
        if MiscUtil.FileExists("Data/SLSO.esp")
            enjoyment = actorAlias.GetFullEnjoyment() 
        else 
            enjoyment = actorAlias.GetEnjoyment() 
        endif 
        str += "\""+actors[i].GetDisplayName()+"\": "+enjoyment
        bool found = MiscUtil.FileExists("Data/SLSO.esp")
        i -= 1 
    endwhile 
    return "{"+str+"}"
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

String Function GetTagsString(sslBaseAnimation anim) global 
    String tags_str = ""
    String[] tags = anim.GetRawTags()
    int i = 0 
    while i < tags.Length
        if tags[i] != "" 
            if tags_str != ""
                tags_str += ", "
            endif 
            tags_str += "\""+tags[i]+"\""
        endif
        i += 1
    endwhile
    return tags_str 
EndFunction 
