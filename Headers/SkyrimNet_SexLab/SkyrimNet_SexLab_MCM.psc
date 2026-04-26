Scriptname SkyrimNet_SexLab_MCM extends SKI_ConfigBase

import SkyrimNet_SexLab_Actions
import SkyrimNet_SexLab_Utilities

int rape_toggle
GlobalVariable Property sexlab_public_sex_accepted Auto

SkyrimNet_SexLab_Main Property main Auto  
SkyrimNet_SexLab_Stages Property stages Auto 
SkyrimNet_SexLab_Actions Property actions Auto 

bool hot_key_toggle = False 
int sex_edit_key = 43 ; 26

bool dom_debug_toggle = False 
int dom_debug_key = 41

bool clear_JSON = False

; Devious Device Support 
Quest group_devices = None

; DOM Support 
Quest d_api = None 
Quest dom_main = None 

; OstimNet Support 
int ostimnet_player_menu = -1
int ostimnet_nonplayer_menu = -1
int ostimnet_affection_menu = -1

Quest Property ostimnet_actions Auto 

Function Trace(String func, String msg, Bool notification=False) global
EndFunction

String page_options = "options"
String page_actors = "actors debug (can be slow)"

; OstimNet found 
String[] sexlab_ostim_options 

int Property sexlab_ostim_player_menu Auto  ; menu id 
int Property sexlab_ostim_nonplayer_menu Auto  ; menu id 

Function Setup() 
EndFunction 


Event OnConfigOpen()
EndEvent

;-----------------------------------------------------------------
; Create Pages 
;-----------------------------------------------------------------

Event OnPageReset(string page)
EndEvent 

Function PageOptions() 
EndFunction 

Function PageActors() 
EndFunction 

State ActorInfo
    Event OnHighlightST()
    EndEvent
EndState

;-----------------------------------------------------------------
; Prompt Toggles 
;-----------------------------------------------------------------
State PublicSexAcceptedToggle
    Event OnSelectST()
    EndEvent
    Event OnHighlightST()
    EndEvent
EndState

State HideDialogueHistoricInstructionsToggle 
    Event OnSelectST()
    EndEvent
    Event OnHighlightST()
    EndEvent
EndState

State HideHermaphroditesToggle 
    Event OnSelectST()
    EndEvent
    Event OnHighlightST()
    EndEvent
EndState

;-----------------------------------------------------------------
; Set Toggles 
;-----------------------------------------------------------------
State RapeAllowedToggle
    Event OnSelectST()
    EndEvent
    Event OnHighlightST()
    EndEvent
EndState

State SexEditTagsPlayer
    Event OnSelectST()
    EndEvent
    Event OnHighlightST()
    EndEvent
EndState

State SexEditTagsNonPlayer
    Event OnSelectST()
    EndEvent
    Event OnHighlightST()
    EndEvent
EndState

State VirginBloodEnabled
    Event OnSelectST()
    EndEvent
    Event OnHighlightST()
    EndEvent
EndState

; --------------------------------------------
; Hot Keys 
; --------------------------------------------

State HotKeyToggle
    Event OnSelectST()
    EndEvent
    Event OnHighlightST()
    EndEvent
EndState

State SexEditKeySet
    Event OnKeyMapChangeST(int keyCode, string conflictControl, string conflictName)
    EndEvent
    Event OnHighlightST()
    EndEvent
EndState

State SexEditHelpToggle
    Event OnSelectST()
    EndEvent
    Event OnHighlightST()
    EndEvent
EndState

;-----------------------------------------------------------------
; Direct Narration 
;-----------------------------------------------------------------

State NarrationCoolOff
    Event OnSliderOpenST()
    EndEvent
    Event OnSliderAcceptST(float value) 
    EndEvent
    Event OnHighlightST()
    EndEvent
EndState
State NarrationMaxDistance
    Event OnSliderOpenST()
    EndEvent
    Event OnSliderAcceptST(float value) 
    EndEvent
    Event OnHighlightST()
    EndEvent
EndState

; --------------------------------------------
; Dom Debug Hotkey
; --------------------------------------------
State DomDebugToggle
    Event OnSelectST()
    EndEvent
    Event OnHighlightST()
    EndEvent
EndState

;-----------------------------------------------------------------
; OstimNet Integration
; https://github.com/schlangster/skyui/wiki/MCM-Option-Types
; https://www.nexusmods.com/skyrimspecialedition/articles/925
;-----------------------------------------------------------------
Event OnOptionMenuOpen(int menu_id)
endEvent

event OnOptionMenuAccept(int menu_id, int index)
endEvent

; --------------------------------------------
; Handles OnKeyDown 
; --------------------------------------------

Event OnKeyDown(int key_code)
EndEvent 

Function Target_Menu_Selection(Actor target, Actor player)
EndFunction

Function MutliTarget_Menu_Selection(Actor player)
EndFunction

String Function SexRapeSelection()
EndFunction
