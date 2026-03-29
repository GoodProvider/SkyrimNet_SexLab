Scriptname SkyrimNet_SexLab_AnimationHandler extends Quest

import JValue
import JMap
import JArray
import SkyrimNet_SexLab_Utilities

SkyrimNet_SexLab_Main Property main Auto
Package Property DoNothing Auto 

String animations_filename = "Data/SKSE/Plugins/SkyrimNet_SexLab/animations.json"

Function Trace(String func, String msg, Bool notification=False) global
    msg = "[SkyrimNet_SexLab_AnimationHandler."+func+"] "+msg
    Debug.Trace(msg)
    if notification
        Debug.Notification(msg)
    endif
EndFunction

bool Function PlayByName_SpeakerTarget(Actor speaker, Actor Target, String anim_name)
	int anim = FindAnimation_ByName(anim_name)
	if anim == 0
		return false
	endif
	int stage_end = JArray.count(solveObj(anim, ".animations[0]"))

	speaker.SetLookAt(target)
	target.SetLookAt(speaker)
	
	PathSpeakerToTarget(speaker, target)
	target.SetDontMove(false)

	Actor[] actors = new Actor[2]
	int gender = main.sexlab.GetGender(Speaker)
	bool has_penis = (gender != 1 && gender != 3)
	if has_penis
		actors[0] = Speaker
		actors[1] = target
	else
		actors[1] = Speaker
		actors[0] = target
	endif
	bool result = PlayAnim(actors, anim, 0, stage_end)
	return result
EndFunction

; Load animation by name and play all stages
bool Function PlayByName(Actor[] actors, String anim_name)
	int anim = FindAnimation_ByName(anim_name)
	if anim == 0
		return false
	endif
	int stage_end = JArray.count(solveObj(anim, ".animations[0]"))
	return PlayAnim(actors, anim, 0, stage_end)
EndFunction

; Load animation by name and play a specific stage range
bool Function PlayByNameStartEnd(Actor[] actors, String anim_name, int stage_start, int stage_end)
	int anim = FindAnimation_ByName(anim_name)
	if anim == 0
		return false
	endif
	return PlayAnim(actors, anim, stage_start, stage_end)
EndFunction

; Run actors through the animation stages from stage_start to stage_end (inclusive)
; animations.json format: animations[actor_index][stage_index], angles[actor_index][stage_index], timers[stage_index]
bool Function PlayAnim(Actor[] actors, int anim, int stage_start, int stage_end)

	String names = JoinActors(actors)
	Trace("PlayAnim","actors:"+names+" anim:"+anim+" stages:"+stage_start+","+stage_end)

	; animations is a JArray of per-actor animation arrays: animations[actor][stage]
	int animations = solveObj(anim, ".animations")
	if !animations
		return false
	endif

	int n_actors = JArray.count(animations)
	if actors.length != n_actors
		Trace("PlayAnim","actor count mismatch: expected "+n_actors+" got "+actors.length, true)
		return false
	endif

	; Stage count from actor 0's animation array
	int n_scenes = JArray.count(JArray.getObj(animations, 0))
	if stage_end >= n_scenes
		stage_end = n_scenes - 1
	endif
	if stage_start > stage_end
		return false
	endif

	; Move actors 50% closer to each other before first stage
	;if n_actors >= 2
		;MoveActorsCloser(actors, 1)
	;endif

	; Loop through stages
	int i = stage_start
	Float angle 
	while i <= stage_end
		Float timer = solveFlt(anim, ".timers[" + i + "]", 0.0)
		Trace("PlayAnim","i:"+i+" timer:"+timer)

		; Apply angles and play animation for each actor
		int j = 0
		while j < n_actors
			String anim_name = solveStr(anim, ".animations[" + j + "][" + i + "]", "")
			angle = solveFlt(anim, ".angles[" + j + "][" + i + "]", 0.0)

			; Orient actor j: actor 0 faces actor 1, all others face actor 0
			if n_actors >= 2
				if j == 0
					ApplyAngle(actors[0], actors[1], angle)
				else
					ApplyAngle(actors[j], actors[0], angle)
				endif
			endif

			if anim_name != ""
				Debug.SendAnimationEvent(actors[j], anim_name)
			endif
			j += 1
		endwhile

		if timer > 0.0
			Utility.Wait(timer)
		endif
		i += 1
	endwhile

	Trace("PlayAnim",names+" idleForcedDefaultState")
	i = 0 
	while i < actors.length
		actors[i].SetRestrained(true)
		actors[i].SetDontMove(true)
		actors[i].StopTranslation()
		int j = 1 
		if i == 1 
			j = 0 
		endif 
		FaceActor(actors[i], actors[j])
		Debug.SendAnimationEvent(actors[i], "idleforcedefaultstate")
		actors[i].SetRestrained(false)
		actors[i].SetDontMove(false)
		i += 1
	endwhile

	return true
EndFunction

; --------------------------------------------------------
; Utility functions
; --------------------------------------------------------

; Lerp each actor's XY position fraction toward the group midpoint
; fraction=0.5 halves the pairwise distance between all actors
Function MoveActorsCloser(Actor[] actors, Float fraction)
	Float mid_x = 0.0
	Float mid_y = 0.0
	int j = 0
	while j < actors.length
		mid_x += actors[j].GetPositionX()
		mid_y += actors[j].GetPositionY()
		j += 1
	endwhile
	mid_x /= actors.length
	mid_y /= actors.length
	j = 0
	while j < actors.length
		Float new_x = actors[j].GetPositionX() + (mid_x - actors[j].GetPositionX()) * fraction
		Float new_y = actors[j].GetPositionY() + (mid_y - actors[j].GetPositionY()) * fraction
		actors[j].SetPosition(new_x, new_y, actors[j].GetPositionZ())
		j += 1
	endwhile
EndFunction

; Move speaker to a position in front of target
; Modeled after sslActorAlias.psc Snap: teleport if too far, TranslateTo if nearby
Function PathSpeakerToTarget(Actor speaker, Actor target)
	Float az      = target.GetAngleZ()
	Float dest_x  = target.GetPositionX() + 20.0 * Math.Sin(az)
	Float dest_y  = target.GetPositionY() + 20.0 * Math.Cos(az)
	Float dest_z  = target.GetPositionZ()
	Float dest_rz = az + 180.0

	Float distance = speaker.GetDistance(target)
	Trace("PathSpeakerToTarget", speaker.GetDisplayName() + " -> " + target.GetDisplayName() + " dist=" + distance)

	if distance > 500.0
		; Too far to walk - teleport instantly (sslActorAlias SetPosition fallback)
		speaker.SetPosition(dest_x, dest_y, dest_z)
		speaker.SetAngle(0.0, 0.0, dest_rz)
	else
		; Stop any playing idle so the actor is free to move, then walk via AI pathfinding
		Debug.SendAnimationEvent(speaker, "IdleForceDefaultState")
		speaker.SetDontMove(false)
		speaker.TranslateTo(dest_x, dest_y, dest_z, 0.0, 0.0, dest_rz, 150.0, 0.0)
		;Utility.Wait(0.05)
		;;speaker.MoveTo(target, dest_x, dest_y)
		;speaker.PathTo(target.GetPosition())
		Float waited = 0.0
		Float dist = speaker.GetDistance(target)
		while dist > 30.0 && waited < 3.0
			Utility.Wait(0.1)
			waited += 0.1
			dist = speaker.GetDistance(target)
		endwhile
		if dist > 30.0
			; Fallback: AI couldn't path, force translate
			speaker.TranslateTo(dest_x, dest_y, dest_z, 0.0, 0.0, dest_rz, 150.0, 0.0)
		endif
	endif
EndFunction

; returns 0 if the animation is not found
int Function FindAnimation_ByName(String anim_name)
	int data = JValue.readFromFile(animations_filename)
	if !data
		return 0
	endif
	int anim = JMap.getObj(data, anim_name)
	if !anim
		return 0
	endif
	return anim
EndFunction

; Rotate akRef to face toward akOther (modeled after DOM_Util.psc FaceActor)
Function FaceActor(Actor akRef, Actor akOther) global
	Float pz = akRef.GetHeadingAngle(akOther)
	if pz > 180.0 
		pz -= 360.0
	endif 
	akRef.SetAngle(akRef.GetAngleX(), akRef.GetAngleY(), akRef.GetAngleZ() + pz)
EndFunction

; Rotate akRef to face away from akOther (modeled after DOM_Util.psc BackActor)
Function BackActor(Actor akRef, Actor akOther) global
	Float pz = akRef.GetHeadingAngle(akOther) + 180.0
	akRef.SetAngle(akRef.GetAngleX(), akRef.GetAngleY(), akRef.GetAngleZ() + pz)
EndFunction

; Apply angle from animations.json: 0.0 = face toward, 180.0 = face away
Function ApplyAngle(Actor akRef, Actor akOther, Float angle) global
	if angle == 0.0
		FaceActor(akRef, akOther)
	elseif angle == 180.0
		BackActor(akRef, akOther)
	endif
EndFunction
