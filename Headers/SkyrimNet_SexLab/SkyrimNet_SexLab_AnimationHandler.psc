Scriptname SkyrimNet_SexLab_AnimationHandler extends Quest

import JValue
import JMap
import JArray
import SkyrimNet_SexLab_Utilities

SkyrimNet_SexLab_Main Property main Auto
Package Property DoNothing Auto 

String animations_filename = "Data/SKSE/Plugins/SkyrimNet_SexLab/animations.json"

Function Trace(String func, String msg, Bool notification=False) global
EndFunction

bool Function PlayByName_SpeakerTarget(Actor speaker, Actor Target, String anim_name)
EndFunction

; Load animation by name and play all stages
bool Function PlayByName(Actor[] actors, String anim_name)
EndFunction

; Load animation by name and play a specific stage range
bool Function PlayByNameStartEnd(Actor[] actors, String anim_name, int stage_start, int stage_end)
EndFunction

; Run actors through the animation stages from stage_start to stage_end (inclusive)
; animations.json format: animations[actor_index][stage_index], angles[actor_index][stage_index], timers[stage_index]
bool Function PlayAnim(Actor[] actors, int anim, int stage_start, int stage_end)
EndFunction

; --------------------------------------------------------
; Utility functions
; --------------------------------------------------------

; Lerp each actor's XY position fraction toward the group midpoint
; fraction=0.5 halves the pairwise distance between all actors
Function MoveActorsCloser(Actor[] actors, Float fraction)
EndFunction

; Move speaker to a position in front of target
; Modeled after sslActorAlias.psc Snap: teleport if too far, TranslateTo if nearby
Function PathSpeakerToTarget(Actor speaker, Actor target)
EndFunction

; returns 0 if the animation is not found
int Function FindAnimation_ByName(String anim_name)
EndFunction

; Rotate akRef to face toward akOther (modeled after DOM_Util.psc FaceActor)
Function FaceActor(Actor akRef, Actor akOther) global
EndFunction

; Rotate akRef to face away from akOther (modeled after DOM_Util.psc BackActor)
Function BackActor(Actor akRef, Actor akOther) global
EndFunction

; Apply angle from animations.json: 0.0 = face toward, 180.0 = face away
Function ApplyAngle(Actor akRef, Actor akOther, Float angle) global
EndFunction
