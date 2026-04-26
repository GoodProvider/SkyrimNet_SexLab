Scriptname SkyrimNet_SexLab_Actions extends Quest
SkyrimNet_SexLab_Main Property main Auto 
SkyrimNet_SexLab_AnimationHandler Property anim_handler Auto 

import SkyrimNet_SexLab_Utilities

Idle Property pa_HugA Auto  ; IDLE:000F4699

Quest Property ostimnet_actions Auto 

Function Trace(String func, String msg, Bool notification=False) global
EndFunction

Function Setup()
EndFunction 

; -------------------------------------------------
; Tag 
; -------------------------------------------------

bool Function BodyAnimation_IsEligible(Actor akActor, string contextJson, string paramsJson) global
EndFunction

;--------------------------------------------------
; Sex Start Functions 
;--------------------------------------------------

sslThreadModel Function Sex_Start(Actor Speaker, Actor Target, string style, string direction, string tag) 
EndFunction

sslThreadModel Function Rape_Start(Actor Speaker, Actor Target, string style, String direction, string tag, Actor victim)
EndFunction

sslThreadModel Function Orgy_Start(Actor Speaker, Actor Target, Actor participate, string style, String direction, string tag)
EndFunction


sslThreadModel Function Masturbation_Start(Actor Speaker, string style, String tag)
EndFunction

sslThreadModel Function Affection_Start(Actor Speaker, Actor Target, String style, String tag, bool narration = False)
EndFunction

sslThreadModel Function Sex_Start_Helper(Actor Speaker, Actor[] actors, Actor[] victims, String style, String direction, String tag_include, String tag_exclude, String hook="")
EndFunction

;--------------------------------------
; Stop Function 
;--------------------------------------

Function Sex_Stop(Actor akActor) 
EndFunction 

;--------------------------------------
; Kissing Function 
;--------------------------------------

;--------------------------------------
; Functions 
;--------------------------------------

sslBaseAnimation[] Function GetAnims(SkyrimNet_SexLab_Main main, sslThreadModel thread, Actor[] actors, Actor[] victims, Actor player, String tag, Bool has_player) global
    String names = SkyrimNet_SexLab_Utilities.JoinActors(actors) 
    String victim_names = SkyrimNet_SexLab_Utilities.JoinActors(victims) 
    Trace("GetAnims", "actors: "+names+" victims: "+victim_names+" tag:"+tag+" has_player: "+has_player)
    sslBaseAnimation[] anims = new sslBaseAnimation[1] 
    anims[0] = None 
    int button = main.BUTTON_YES
    if has_player
        button = main.YesNoSexDialog(actors, victims, player, tag)
        if button == main.BUTTON_NO || button == main.BUTTON_NO_SILENT
            Trace("GetAnims_CheckLock","User declined")
            return anims 
        endif 
    endif  

    if button != main.BUTTON_YES_RANDOM
        if tag == "kissing_only"
            String tag_filter =" oral,vaginal,anal,masturbation,handjob,boobjob,thighjob,fisting,dildo,fingering,footjob"
            anims = main.sexLab.GetAnimationsByTags(actors.length, "kissing", tag_filter, true)
        else 
            String type = "sex"
            if victims.length > 0 
                type = "rape"
            endif 

            if (main.sex_edit_tags_player && has_player) || (main.sex_edit_tags_nonplayer && !has_player)
                Trace("GetAnims", "Opening anim edit dialog")
                anims = main.GetAnimsDialog(thread, actors, type, tag)
            else 
                anims = main.sexLab.GetAnimationsByTags(actors.length, tag, "", true)
            endif 
            Trace("GetAnims", "has_player: "+has_player+" player edit: "+main.sex_edit_tags_player\
                +" nonplayer edit: "+main.sex_edit_tags_nonplayer+" anims.length: "+anims.length)
        endif 
    else
        String tagSupress = ""
        anims =  main.sexLab.GetAnimationsByTags(actors.length, tag, tagSupress, true)
    endif 

    return anims 
EndFunction 

; -------------------------------------------------
; Dress and Undress
; -------------------------------------------------
Function Change_Outfit(Actor Stripper, Actor Stripped, String Style, String how, String Narration)
EndFunction