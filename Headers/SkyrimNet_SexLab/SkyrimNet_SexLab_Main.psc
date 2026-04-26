Scriptname SkyrimNet_SexLab_Main extends Quest

import JContainers
import UIExtensions
import SkyrimNet_SexLab_Decorators
import SkyrimNet_SexLab_Actions
import SkyrimNet_SexLab_Stages
import SkyrimNet_SexLab_Utilities
import StorageUtil

Faction Property SkyrimNet_SexLab_Faction_Victim Auto

; ---------------------------------------------------
; Globals 
; ---------------------------------------------------

; SexLab Active Sex 
; 0 - no active sexlab animations 
; 1 - one or more active sexlab animations
GlobalVariable Property skyrimnet_sexlab_active_sex Auto
Bool Property active_sex 
    Bool Function Get()
    EndFunction 
    Function Set(Bool value)
    EndFunction 
EndProperty

; ----- Does all animations -----
; Sexlab or Ostim animation with player
; 0 - Sexlab
; 1 - Ostim
; 2 - Choose per animation
GlobalVariable Property skyrimnet_sexlab_ostim_player Auto
int Property sexlab_ostim_player
    int Function Get()
    EndFunction 
    Function Set(int value)
    EndFunction 
EndProperty

; Hides the dialogue historic instructions from the prompt
; 0 - false
; 1 - true
; 2 - Choose per animation
GlobalVariable Property skyrimnet_sexlab_hide_dialogue_historic_instructions Auto
bool Property hide_dialogue_historic_instructions
    bool Function Get()
    EndFunction 
    Function Set(bool value)
    EndFunction 
EndProperty

int Property sexlab_ostim_affection = 0 Auto 

; Hides the hermaphrodite from prompt 
; 0 - false
; 1 - true
; 2 - Choose per animation
GlobalVariable Property skyrimnet_sexlab_hide_hermaphrodites Auto
bool Property hide_hermaphrodites
    bool Function Get()
    EndFunction 
    Function Set(bool value)
    EndFunction 
EndProperty

; ----- Not currently supported ------
; Sexlab or Ostim animation without player
; 0 - Sexlab
; 1 - Ostim
; 2 - Choose per animation
GlobalVariable Property skyrimnet_sexlab_ostim_nonplayer Auto
int Property sexlab_ostim_nonplayer_index
    int Function Get()
    EndFunction 
    Function Set(int value)
    EndFunction 
EndProperty

; ---------------------------------------------------

ReferenceAlias[] Property nude_refs Auto


int Property BUTTON_YES = 0 Auto        ; 0
int Property BUTTON_YES_RANDOM = 1 Auto ; 1
int Property BUTTON_NO_SILENT = 2 Auto  ; 2
int Property BUTTON_NO = 3 Auto         ; 3

int Property STYLE_FORCEFULLY = 0 Auto 
int Property STYLE_NORMALLY = 1 Auto 
int Property STYLE_GENTLY = 2 Auto 
int Property STYLE_SILENTLY = 3 Auto 
String style_string_current = "" ; Used by Anims Dialogue, to return the Style
int[] thread_style
bool[] thread_started

bool[] thread_kissing_only 
bool Function GetKissingOnly(int id) 
EndFunction 
Function SetKissingOnly(int id, bool value ) 
EndFunction 


Function Trace(String func, String msg, Bool notification=False) global
EndFunction

bool Property rape_allowed = true Auto
bool Property sex_edit_tags_player = true Auto 
bool Property sex_edit_tags_nonplayer = False Auto

int Property actorLock = 0 Auto 
float Property actorLockTimeout = 0.00069444444 Auto ;  1 day / (24 hours  * 60 minutes ) 

int Property group_info = 0 Auto
int Property group_ordered = 0 Auto

int skynet_tag_sex_lock = 0 

String Property storage_items_key = "skyrimnet_sexlab_storage_items" Auto
String Property storage_arousal_key = "skyrimnet_sexlab_arousal_level" Auto
String Property storage_thread_ejaculated = "skyrimnet_sexlab_thread_ejaculated" Auto
String Property storage_should_naked = "skyrimnet_sexlab_should_be_naked" Auto

SkyrimNet_SexLab_Stages Property stages Auto
SkyrimNet_SexLab_Stats Property stats Auto 
SexLabFramework Property sexlab Auto 

; -----------------------------
; enable virgin blood
; -----------------------------
Bool Property virgin_blood_enabled = True Auto

; -----------------------------
; Time since last dirrect narration
; needed, sine there appears to be a race condition on when things hit the audio queue
; -----------------------------


; -----------------------------
; DOM found 
; -----------------------------
bool dom_found_internal = false
bool Function dom_found()
EndFunction
;Quest d_api_internal = None 
;Quest Function dom_api()
    ;return d_api_internal
;EndFunction 
;Quest d_sexlab_internal = None 
;Quest Function dom_sexlab()
    ;return d_sexlab_internal
;EndFunction

Function CheckForDOM()
EndFunction

string actor_num_orgasms_key = "skyrimnet_sexlab_actor_num_orgasms"
string actor_thread_id = "skyrimnet_sexlab_actor_thread_id"

; Controls when Direction Narration occur 
float Property direct_narration_cool_off Auto 
float Property direct_narration_max_distance Auto 
float Property direct_narration_max_distance_default Auto 
float Property direct_narration_last_time Auto 

; OstimNet 
bool ostimnet_found_internal = false 
bool Property ostimnet_found 
    bool Function Get()
    EndFunction 
    Function Set(bool value)
    EndFunction 
EndProperty

; -----------------------------
; Cuddle found 
; -----------------------------
bool cuddle_found_internal = false 
bool Property cuddle_found 
    bool Function Get()
    EndFunction 
    Function Set(bool value)
    EndFunction 
EndProperty

; Race to speech 
int Property race_to_description Auto

int Property counter Auto 

Event OnInit()
EndEvent

Function Setup()
EndFunction


;----------------------------------------------------------------------------------------------------
; Stripped Items Storage
;----------------------------------------------------------------------------------------------------

Function StoreStrippedItems(Actor akActor, Form[] forms)
EndFunction 

Form[] Function UnStoreStrippedItems(Actor akActor)
    Trace("UnStoreStrippedItems",akActor.GetDisplayName()+" attempting to undress")
    int i = nude_refs.length - 1
    while 0 <= i 
        if nude_refs[i].GetActorReference() == akActor 
            nude_refs[i].Clear() 
            Utility.Wait(1.00)
            i = -1
        endif 
        i -= 1 
    endwhile 
    if !HasStrippedItems(akActor)
        return Utility.CreateFormArray(0)
    endif
    Form[] forms = StorageUtil.FormListToArray(akActor, storage_items_key)
    StorageUtil.FormListClear(akActor, storage_items_key)
    return forms
EndFunction

Bool Function HasStrippedItems(Actor akActor)
EndFunction

;----------------------------------------------------------------------------------------------------
; Actor Lock
;----------------------------------------------------------------------------------------------------

bool Function LockActors(Actor[] actors) 
EndFunction 

Function UnLockActors(Actor[] actors) 
EndFunction 

Bool Function IsActorLocked(Actor akActor) 
EndFunction

bool Function SetActorLock(Actor akActor) 
EndFunction

Function ReleaseActorLock(Actor akActor) 
EndFunction

;----------------------------------------------------------------------------------------------------
;Function SetThreadEjaculated(Actor akActor, int cum_added) 
    ;int value = 0 
    ;if ejaculated
        ;value = 1
    ;endif 
    ;StorageUtil.SetIntValue(thread, storage_thread_ejaculated, value)
;EndFunction 

;bool Function GetThreadEjaculated(sslThreadController thread) 
    ;1 == StorageUtil.GetIntValue(thread, storage_thread_ejaculated, 0)
;EndFunction 

;----------------------------------------------------------------------------------------------------
Function SetThreadStyle(int thread_id, int style) 
EndFunction

Int Function GetThreadStyle(int thread_id)
EndFunction

String Function GetThreadStyleString(int thread_id)
EndFunction

;----------------------------------------------------------------------------------------------------
bool Function Tag_SexAnimation(Actor akActor) 
EndFunction

;----------------------------------------------------------------------------------------------------
sslThreadController Function GetThread(Actor akActor) 
EndFunction

;----------------------------------------------------------------------------------------------------
; SexLab Events
;----------------------------------------------------------------------------------------------------
Function RegisterSexlabEvents() 
EndFunction 

event AnimationStart(int ThreadID, bool HasPlayer)
endEvent



Event StageStart(int ThreadID, bool HasPlayer)
EndEvent


event AnimationEnd(int ThreadID, bool HasPlayer)
EndEvent 

Function AnimationEndFunction(int ThreadID, bool HasPlayer, Actor actorEnder) 
EndFunction 

; Function AllowedDeniedOnlyIncrease(Actor[] actors, sslThreadController thread, String status)
    ; if !MiscUtil.FileExists("Data/SexLabAroused.esm") 
        ; return
    ; endif
    ; Store orgasm denied actor's arousal level before sex, It is not allowed to lower 
    ;q = Game.GetFormFromFile(0x800, "SkyrimNet_SexLab.esp") as Quest
    ;SkyrimNet_SexLab_main main = q as SkyrimNet_SexLab_Main
    ;SkyrimNet_SexLab_Stages stages_lib = q as SkyrimNet_SexLab_Stages

    ; int[] orgasm_denied = new int [1] ; stages.GetOrgasmDenied(thread)
    ; int satisifcation_idx = slaInternalModules.RegisterStaticEffect("Orgasm")
; 
    ; int i = orgasm_denied.length - 1
    ; while 0 <= i    
        ; float sat_value = slaInternalModules.GetStaticEffectValue(actors[i], satisifcation_idx)
        ; if orgasm_denied[i] == 1
            ; if status == "start"
                ; StorageUtil.SetFloatValue(actors[i], storage_arousal_key, sat_value)
            ; else
                ; float stored_value = StorageUtil.GetFloatValue(actors[i], storage_arousal_key)
                ; if stored_value < sat_value
                    ; StorageUtil.SetFloatValue(actors[i], storage_arousal_key, sat_value)
                ; elseif stored_value > sat_value
                    ; slaInternalModules.SetStaticArousalValue(actors[i], satisifcation_idx, stored_value)
                    ; Trace("AllowedDeniedOnlyIncrease",actors[i].GetDisplayName()+" orgasm denied, so erasing orgasm satisifaction "+sat_value+" -> "+stored_value)
                ; endif 
            ; endif 
        ; endif 
        ; sat_value = slaInternalModules.GetStaticEffectValue(actors[i], satisifcation_idx)
        ; i -= 1
    ; endwhile
; EndFunction

; ----------------------------------------------------------------------------------------------------
; Orgasm Event Functions 
; This function is not called when flag SLSO, as it has its own orgasm handling
; ----------------------------------------------------------------------------------------------------
Event Orgasm_Combined(int ThreadID, bool HasPlayer)
EndEvent 

; Used for SLSO.esp orgasm handling
Event Orgasm_Individual(form akActorForm, int FullEnjoyment, int num_orgasms)
EndEvent

Function Orgasm_Individual_Helper(Actor akActor, int FullEnjoyment, int num_orgasms, String msg, bool require_narration = false)
EndFunction

;----------------------------------------------------
; Add Cum
;----------------------------------------------------
String Function AddCum(sslThreadController thread, int position, Actor akActor, String name)
EndFunction  

; Increases the 
Bool Function IsDOMSlave(Actor akActor)
EndFunction

DOM_Actor Function GetDOMSlave(String func, Actor akActor, String file = "SkyrimNet_SexLab_Main")
EndFunction

Function DOMSlave_Orgasmed(Actor akActor, String msg)
EndFunction

;----------------------------------------------------
; Parses the tags
;----------------------------------------------------
String Function Thread_Narration(sslThreadController thread, String status)
EndFunction 
String Function ActorsToString(Actor[] actors) global
endFunction

String Function ActorsToJson(Actor[] actors) global
EndFunction 

;----------------------------------------------------
; Yes No dialogue choice for the player 
;----------------------------------------------------

; Allows the user to choose to accept the sex act chosen by the LLM 
; The value will between 
; 1 Yes with the editor 
; 2 Yes, but no tag editor 
; 3 No (silent), refused, but don't tell the LLM 
; 4 NO, tell the LLM 
int function YesNoSexDialog(Actor[] actors, Actor[] victims, Actor player, String tag)
EndFunction

; Selects the style of sex 
; 0 forcefully 
; 1 normally 
; 2 gently 
int Function SexStyleDialog(int thread_id, bool rape)
EndFunction

; This function returns the list of animations matching the requested animations
; If no animations were selected, it will return an array with a single None value `[None]`
; 
;   anims = AnmisDialog(sexlab. actors, tag) 
;   if anims.length > 0 && anims[0] != None 
;        thread.SetAnimations(anims)
;   endif 
;
sslBaseAnimation[] Function GetAnimsDialog(sslThreadModel thread, Actor[] actors, String type, String tag)
    String names = SkyrimNet_SexLab_Utilities.JoinActors(actors)
    Trace("GetAnimsDialog","names: "+names+" tag:"+tag)

    Actor player = Game.GetPlayer() 
    int i = actors.Length - 1 
    bool includes_player = False 
    while 0 <= i && !includes_player
        if actors[i] == player 
            includes_player = True 
        endif 
        i -= 1 
    endwhile

    ; Check if enabled by MCM 
    sslBaseAnimation[] empty = new sslBaseAnimation[1]
    empty[0] = None 

    if (includes_player && !sex_edit_tags_player) || (!includes_player && !sex_edit_tags_nonplayer)
        return empty 
    endif 

    ; Style to strings 
    String[] style_strings = new String[3]
    style_strings[STYLE_FORCEFULLY] = "style:forcefully>"
    style_strings[STYLE_NORMALLY] = "style:normally>"  
    style_strings[STYLE_GENTLY] = "style:gently>"

    ; Current set of tags
    String[] tags = new String[10]
    int count_max = 10
    int next = 0
    if tag != ""
        sslBaseAnimation[] anims =  SexLab.GetAnimationsByTags(actors.length, tag, "", true)
        if anims.length > 0
            tags[0] = tag
            next += 1
        else 
            Trace("AnimsDialog", "No animations found, dropping initial tag: "+tag)
        endif 
    endif 

    ; the order of the groups 
    int group_tags = JMap.getObj(group_info,"group_tags",0)
    if group_tags == 0 
        Trace("AnimsDialog", "group_tags not found in group_tags.json")
        return None
    endif 

    int groups = JMap.getObj(group_tags,"groups",0)
    if groups == 0
        groups = JMap.allKeys(group_tags)
    endif 
    int count = JArray.count(groups)

    JValue.retain(groups)
    uilistMenu listMenu = uiextensions.GetMenu("UIlistMenu") AS uilistMenu
    String start_label = "<start "+type+">"
    bool rape = type == "rape"
    while True
        String order_str ="change order>"
        bool finished = false
        String tags_str= ""
        String style_str = style_strings[thread_style[thread.tid]]
        while next < count_max && !finished
            listMenu.ResetMenu()

            ; build the current tags
            tags_str = "" 
            i = 0
            while i < next
                if i > 0 
                    tags_str += ","
                endif 
                tags_str += tags[i]
                i += 1
            endwhile 
            ; Use the current set of tags 
            String tags_label = "tags:"+tags_str
            listMenu.AddEntryItem(names)
            if actors.length > 1 
                listMenu.AddEntryItem(order_str)
            endif 
            listMenu.AddEntryItem(style_str)
            listMenu.AddEntryItem(tags_label)
            listMenu.AddEntryItem(start_label)

            ; Remove one tag 
            if 0 < next 
                listMenu.AddEntryItem("<remove")
            endif 

            ; Add groups
            i =  0
            while i < count
                String group = JArray.getStr(groups,i)
                listMenu.AddEntryItem(group)
                i += 1
            endwhile

            ; add the actions 
            ;ListAddTags(listMenu, group_tags, "actions>") 

            ; just give up
            listMenu.AddEntryItem("<cancel>")

            listMenu.OpenMenu()
            String button =  listMenu.GetResultString()
            if JMap.hasKey(group_tags, button)
                button = GroupDialog(group_tags, button)
            endif 

            if button == start_label 
                finished = true
            elseif button == style_str
                int style = SexStyleDialog(thread.tid, rape)
                style_str = style_strings[style]
            elseif button == order_str 
                if actors.length > 1 
                    Actor temp = actors[0]
                    i = 0 
                    while i < actors.length - 1 
                        actors[i] = actors[i+1] 
                        i += 1 
                    endwhile 
                    actors[i] = temp 
                    names = SkyrimNet_SexLab_Utilities.JoinActors(actors)
                endif 
            elseif button == "<cancel>"
                JValue.release(groups)
                return empty
            elseif button == "<remove"
                next -= 1
            elseif button != "-continue-" && button != names && button != tags_label
                tags[next] = button 
                next += 1
            endif 
        endwhile 
        sslBaseAnimation[] anims =  SexLab.GetAnimationsByTags(actors.length, tags_str, "", true)
        if anims.length > 0
            JValue.release(groups)
            return anims 
        else
            Trace("AnimsDialog","No animations found for: "+tags_str)
            Debug.Notification("No animations found for: "+tags_str)
        endif 
    endwhile 
    JValue.release(groups)
    return empty
EndFunction

Function ListAddTags(uilistMenu listMenu, int group_tags, String group) global
EndFunction

String Function GroupDialog(int group_tags, String group)  global
EndFunction