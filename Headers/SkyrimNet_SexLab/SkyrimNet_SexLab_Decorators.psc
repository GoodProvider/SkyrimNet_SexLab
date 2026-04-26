Scriptname SkyrimNet_SexLab_Decorators

import SkyrimNet_SexLab_Main
import SkyrimNet_SexLab_Stages
import SkyrimNet_SexLab_Utilities
import PO3_SKSEFunctions

Function Trace(String func, String msg, Bool notification=False) global
EndFunction


;----------------------------------------------------------------------------------------------------
; Decorators 
;----------------------------------------------------------------------------------------------------
Function RegisterDecorators() global
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
String Function Outfit_Options(Actor speaker) global 
EndFunction

String Function Speaker_Info(Actor speaker) global 
EndFunction


String Function Player_LOS_Distance(Actor akActor) global 
EndFunction 

String Function Is_Nudity(Actor akActor) global
EndFunction

String Function BooleanString(bool b) global
EndFunction 

String Function Save_Threads(SexLabFramework SexLab) global 
EndFunction

String Function Get_Threads(Actor speaker) global
EndFunction 

String Function Get_Thread_Description(sslThreadController thread, sslActorLibrary actorLib) global
EndFunction

String Function Thread_Json(sslThreadController thread,sslActorLibrary actorLib) global
EndFunction

String Function GetLocation(sslThreadController thread) global
EndFunction 

String Function GetCreatures(sslThreadController thread) global
EndFunction

String Function GetNamesArray(sslThreadController thread) global
EndFunction

String Function GetNames(sslThreadController thread, sslActorLibrary actorLib = None) global
EndFunction

String Function GetEnjoyments(sslThreadController controller) global
EndFunction 

bool Function SexLab_Thread_LOS(Actor akActor, sslThreadController thread) global
endFunction 

String Function GetTagsString(sslBaseAnimation anim) global 
EndFunction 