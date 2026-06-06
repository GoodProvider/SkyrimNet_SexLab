Scriptname SkyrimNet_SexLab_Main extends Quest

import JContainers
import UIExtensions
import SkyrimNet_SexLab_Decorators
import SkyrimNet_SexLab_Stages
import SkyrimNet_SexLab_Utilities
import StorageUtil

SkyrimNet_SexLab_Stages Property stages Auto
SkyrimNet_SexLab_Handler_DOM_Interface Property handler_dom Auto 

; ---------------------------
; Optional Mods Found 
; ---------------------------
Bool Property ostimnet_found = False Auto

SexLabFramework Property sexlab Auto 

Faction Property SkyrimNet_SexLab_Faction_Victim Auto

; ---------------------------------------------------
; Globals 
; ---------------------------------------------------

; SexLab Active Sex 
; 0 - no active sexlab animations 
; 1 - one or more active sexlab animations
GlobalVariable Property skyrimnet_sexlab_active_sex Auto
bool Property active_sex
    bool Function Get()
        if skyrimnet_sexlab_active_sex.GetValue() == 1
            return true
        endif
        return false 
    EndFunction 
    Function Set(bool value)
        if value
            skyrimnet_sexlab_active_sex.SetValue(1)
        else
            skyrimnet_sexlab_active_sex.SetValue(0)
        endif
    EndFunction 
EndProperty

; ---------------------------------------------------


Function Trace(String func, String msg, Bool notification=False) global
    msg = "[SkyrimNet_SexLab_Main."+func+"] "+msg
    Debug.Trace(msg) 
    if notification
        Debug.Notification(msg)
    endif 
EndFunction

bool Property rape_allowed = true Auto
bool Property sex_edit_tags_player = true Auto 
bool Property sex_edit_tags_nonplayer = False Auto

int Property actorLock = 0 Auto 
float Property actorLockTimeout = 0.00069444444 Auto ;  1 day / (24 hours  * 60 minutes ) 

int Property group_info = 0 Auto
int Property group_ordered = 0 Auto

String Property storage_actor_lock_key = "skyrimnet_sexlab_actor_lock" Auto 
String Property storage_items_key = "skyrimnet_sexlab_storage_items" Auto
String Property storage_arousal_key = "skyrimnet_sexlab_arousal_level" Auto
String Property storage_thread_ejaculated = "skyrimnet_sexlab_thread_ejaculated" Auto


; -----------------------------
; enable virgin blood
; -----------------------------
Bool Property virgin_blood_enabled = True Auto

; -----------------------------
; Time since last dirrect narration
; needed, sine there appears to be a race condition on when things hit the audio queue
; -----------------------------

; ---------------------------
; Storage Keys 
; ---------------------------
string actor_num_orgasms_key = "skyrimnet_sexlab_actor_num_orgasms"
string actor_thread_id = "skyrimnet_sexlab_actor_thread_id"

; Controls when Direction Narration occur 
float Property direct_narration_cool_off Auto 
float Property direct_narration_max_distance Auto 
float Property direct_narration_max_distance_default Auto 
float Property direct_narration_last_time Auto 

; Race to speech 
int Property race_to_description Auto

int Property counter Auto 

Function Setup()
    Trace("SetUp","")
    ; --------------------------------
    ; Decorators
    ; --------------------------------
    SkyrimNet_SexLab_Decorators.RegisterDecorators() 
    ((self as Quest) as SkyrimNet_SexLab_Actions).Setup()
    ((self as Quest) as SkyrimNet_SexLab_MCM).Setup()
    ((self as Quest) as SkyrimNet_SexLab_Stages).Setup()
    ((self as Quest) as SkyrimNet_SexLab_Scene_Manager).Setup()

    bool skyrimnet_dom_found = MiscUtil.FileExists("Data/SkyrimNet_DOM.esp")
    bool skyrimnet_sexlab_handler_dom_found = MiscUtil.FileExists("Data/SkyrimNet_SexLab_Handler_DOM.esp")
    if skyrimnet_dom_found && skyrimnet_sexlab_handler_dom_found
        handler_dom = Game.GetFormFromFile(0x800, "SkyrimNet_SexLab_Handler_DOM.esp") as SkyrimNet_SexLab_Handler_DOM_Interface
        Trace("Setup","SkyrimNet_DOM found setting main.dom_handler to SkyrimNet_SexLab_Handler_DOM")
    else 
        handler_dom = (self as Quest) as SkyrimNet_SexLab_Handler_DOM_Interface
        Trace("Setup","SkyrimNet_SexLab_Handler_DOM found:"+skyrimnet_sexlab_handler_dom_found+", SkyrimNet_DOM found :"+skyrimnet_dom_found)
    endif 

    if !MiscUtil.FileExists("Data/SexLab.esm")
        Trace("SetUp","Data/SexLab.esm does not exist") 
        Debug.MessageBox("Can't find Data/SexLab.esm"+StringUtil.AsChar(10)\
            +"SkyrimNet_SexLab will not work.")
        return 
    endif 

    ; Direct Narration 
    if direct_narration_cool_off == 0 
        direct_narration_cool_off = 20 
        direct_narration_max_distance = 15
        direct_narration_max_distance_default = 15
    endif 
    direct_narration_last_time = 0 

    ReleaseAllActorLock()

    if group_info == 0
        group_info = JValue.readFromFile("Data/SKSE/Plugins/SkyrimNet_Sexlab/group_tags.json")
        JValue.retain(group_info)
    else
        int group_info_new = JValue.readFromFile("Data/SKSE/Plugins/SkyrimNet_Sexlab/group_tags.json")
        JValue.releaseAndRetain(group_info, group_info_new)
        group_info = group_info_new
    endif

    if race_to_description <= 0 
        race_to_description = JValue.readFromFile("Data/SKSE/Plugins/SkyrimNet_Sexlab/creatures.json")
        JValue.retain(race_to_description)
    endif 

    ; --------------------------------
    ; Register SexLab Events
    ; --------------------------------
    RegisterSexlabEvents()

    ; --------------------------------
    ; Decorators
    ; --------------------------------
    if MiscUtil.FileExists("Data/TT_OStimNet.esp") 
        ostimnet_found = True 
        Trace("SetUp","Found TT_OstimNet.esp found")
    endif 

EndFunction


;----------------------------------------------------------------------------------------------------
; Stripped Items Storage
;----------------------------------------------------------------------------------------------------

Function StoreStrippedItems(Actor akActor, Form[] forms)
    if akActor == None || forms.Length == 0
        return 
    endif 
    Trace("AddStrippedItems",akActor.GetDisplayName()+" num_items:"+forms.Length)
    StorageUtil.FormListClear(akActor, storage_items_key)
    int i = 0
    while i < forms.Length
        StorageUtil.FormListAdd(akActor, storage_items_key, forms[i])
        i += 1
    endwhile
EndFunction 

Form[] Function UnStoreStrippedItems(Actor akActor)
    if !HasStrippedItems(akActor)
        Trace("UnStoreStrippedItems",akActor.GetDisplayName()+" attempting to get stripped items: found none")
        return Utility.CreateFormArray(0)
    endif
    Form[] forms = StorageUtil.FormListToArray(akActor, storage_items_key)
    StorageUtil.FormListClear(akActor, storage_items_key)
    Trace("UnStoreStrippedItems",akActor.GetDisplayName()+" removed stored items: "+forms.Length)
    return forms
EndFunction

Bool Function HasStrippedItems(Actor akActor)
    if akActor == None || StorageUtil.FormListCount(akActor, storage_items_key) == 0
        return False
    endif 
    return true 
EndFunction

;----------------------------------------------------
; Yes No dialogue choice for the player 
;----------------------------------------------------
