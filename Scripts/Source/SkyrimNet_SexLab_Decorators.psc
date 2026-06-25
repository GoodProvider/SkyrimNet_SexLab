Scriptname SkyrimNet_SexLab_Decorators


import SkyrimNet_SexLab_Main
import SkyrimNet_SexLab_Stages
import SkyrimNet_SexLab_Utilities
import PO3_SKSEFunctions

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
    SkyrimNetApi.RegisterDecorator("sexlab_get_threads", "SkyrimNet_SexLab_Decorators", "SexLab_Get_Threads")
    SkyrimNetApi.RegisterDecorator("sexlab_get_player_los_distance", "SkyrimNet_SexLab_Decorators", "Player_LOS_Distance")
    SkyrimNetApi.RegisterDecorator("sexlab_outfit_options", "SkyrimNet_SexLab_Decorators", "Outfit_Options")
    SkyrimNetApi.RegisterDecorator("sexlab_intent", "SkyrimNet_SexLab_Decorators", "Intent")
    ;SkyrimNetApi.RegisterDecorator("sexlab_nudity", "SkyrimNet_SexLab_Decorators", "Is_Nudity")
    ;SkyrimNetApi.RegisterDecorator("sexlab_speaker_info", "SkyrimNet_SexLab_Decorators", "Speaker_Info")
EndFunction

String Function Outfit_Options(Actor speaker) global 
    SkyrimNet_SexLab_Main main = Game.GetFormFromFile(0x800, "SkyrimNet_SexLab.esp") as SkyrimNet_SexLab_Main
       if main == None
        Trace("Outfit_Options", "ERROR: Failed to get SkyrimNet_SexLab_Main form", True)
        return '{"option":"undresses"}'
    endif
    String options = "undresses"
    ; Check if the actor has undressed items, they could put on 
    if main.HasStrippedItems(speaker) 
        options = "dresses"
    endif 
    Trace("Outfit_Options",speaker.GetDisplayName()+" has options:"+options)
    return "{"+'"'+"option"+'"'+":"+'"'+options+'"'+"}"
EndFunction

String Function Intent(Actor speaker) global 
    SkyrimNet_SexLab_Scene_Manager manager = Game.GetFormFromFile(0x800, "SkyrimNet_SexLab.esp") as SkyrimNet_SexLab_Scene_Manager
    SkyrimNet_SexLab_Scene scene = manager.GetSceneByActor(speaker) 
    if scene != None 
        return '{"intent":"'+scene.intent+'"}'
    endif 
    return "{}"
EndFunction 


String Function Player_LOS_Distance(Actor akActor) global 
    Actor player = Game.GetPlayer() 
    float distance = player.GetDistance(akActor) 
    bool los = player.hasLOS(akActor) 
    return "{"+'"'+"distance"+'"'+":"+distance+","+'"'+"los"+'"'+":"+los+"}"
EndFunction 

String Function Is_Nudity(Actor akActor) global
    ; 32 off top
    ; 52 and 49 off bottom 
    bool topless = false
    bool bottomless = false 
    if akActor != None 
        Form body = akActor.GetEquippedArmorInSlot(32)
        Form pelvis_primary = akActor.GetEquippedArmorInSlot(52)
        Form pelvis_secondary = akActor.GetEquippedArmorInSlot(49)


        if body == None 
            topless = true 
        endif 
        if pelvis_primary == None && pelvis_secondary == None
            bottomless = true 
        endif
    endif 
    return "{"+'"'+"topless"+'"'+":"+topless+","+'"'+"bottomless"+'"'+":"+bottomless+"}"
EndFunction

String Function SexLab_Get_Threads(Actor speaker) global
    SkyrimNet_SexLab_Scene_Manager manager = Game.GetFormFromFile(0x800, "SkyrimNet_SexLab.esp") as SkyrimNet_SexLab_Scene_Manager
    if manager == None 
        return '{"threads":[]}' 
    endif 
    return manager.GetThreadsJson(speaker) 
EndFunction 

; animal & ActorTypeCreature & ActorTypeFamiliar 
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
;bool Function IsActorNude(Actor akActor) global
    ;if akActor.GetEquippedArmorInSlot(32) != None
        ;return false ; Wearing main armor body layer
    ;endif
    ;; Check if clothing items exist unequipped within the local container list
    ;if akActor.GetItemCount(Game.GetFormFromFile(0x00012E49, "Skyrim.esm")) > 0 ; Clothing Body Keyword match check
        ;return true ; Is currently nude, but has clothes available
    ;endif
    ;return true
;EndFunction
