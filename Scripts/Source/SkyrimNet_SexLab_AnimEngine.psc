Scriptname SkyrimNet_SexLab_AnimEngine Hidden

; AnimEngine (C++) drives actors through AnimDB playback data without SexLab's thread (sexlab.anim_engine.enabled).
; This script is its thin Papyrus shell for what the plugin has no C++ path for yet: restraint, player controls, the
; vehicle marker, the walk into place and the TranslateTo hold. C++ calls Lock / Approach / Sheathe / Begin / Place /
; Hold / Unlock (DispatchStaticCall); Hold is re-sent every second because a global script gets no OnTranslationComplete.
; See docs/developers/anim-engine.md §4.

; Debug start: player + NPC (or one actor), ordered by the registry's positions. Returns the scene id, -1 on failure.
int Function AnimEngine_DebugStart(Actor a, Actor b, String registry) global native
; sexlab.anim_engine.enabled.
Bool Function AnimEngine_Enabled() global native
; Scene creator start: plays the first registry with a matching position count. Victims play role 2, the others role 1.
; no_strip actors keep their clothes; the others strip at Begin and re-dress at Unlock.
; The creator's actor locks pass to AnimEngine on success, and stay with the creator on failure.
; Returns the scene id, -1 when no registry fits or the start fails.
int Function AnimEngine_StartFromCreator(Actor[] actors, String[] registries, Actor[] victims, Actor[] no_strip) global native
; scene_id -1 = the newest scene.
Bool Function AnimEngine_Advance(int scene_id = -1) global native
Bool Function AnimEngine_Back(int scene_id = -1) global native
Bool Function AnimEngine_GoToNode(int scene_id, String node) global native
Bool Function AnimEngine_SetPaused(int scene_id, Bool paused) global native
Bool Function AnimEngine_End(int scene_id = -1) global native
int Function AnimEngine_SceneOf(Actor akActor) global native
String Function AnimEngine_Describe(int scene_id = -1) global native

Function Trace(String func, String msg) global
    SkyrimNet_SexLab_WebUI.TraceLog("SkyrimNet_SexLab_AnimEngine", func, msg)
EndFunction

String Function MarkerKey() global
    return "SkyrimNet_SexLab_AE_Marker"
EndFunction

; SkyrimNet_SexLab_AE_DoNothing (Spriggit Packages/): a copy of SexLabDoNothing (Wait, StopMovement) without its
; SexLabAnimatingFaction condition. Applied as an override like sslActorAlias.psc:1317; PapyrusUtil saves overrides,
; so Unlock (also run for actors a save caught mid-scene) must remove it.
Package Function DoNothingPackage() global
    return Game.GetFormFromFile(0x81D, "SkyrimNet_SexLab.esp") as Package
EndFunction

; SkyrimNet_SexLab_AE_Marker (Spriggit Furniture/): a copy of SexLab's BaseMarker furniture (vanilla
; WallLeanMarker.nif). The vehicle anchor needs 3D: a bare XMarker has none, and an actor attached to it is pulled back
; to where the marker was first placed.
Form Function MarkerBase() global
    return Game.GetFormFromFile(0x81E, "SkyrimNet_SexLab.esp")
EndFunction

; The actor's marker, placed at the actor and 3D-loaded on first use (sslActorAlias.psc:1341-1352).
ObjectReference Function EnsureMarker(Actor akActor) global
    ObjectReference marker = StorageUtil.GetFormValue(akActor, MarkerKey()) as ObjectReference
    if marker
        return marker
    endif
    Form base = MarkerBase()
    if base == None
        Trace("EnsureMarker", "SkyrimNet_SexLab_AE_Marker missing from SkyrimNet_SexLab.esp; using XMarker")
        base = Game.GetFormFromFile(0x3B, "Skyrim.esm")
    endif
    marker = akActor.PlaceAtMe(base, 1, false, false)
    StorageUtil.SetFormValue(akActor, MarkerKey(), marker)
    int cycle = 0
    while !marker.Is3DLoaded() && cycle < 50
        Utility.Wait(0.1)
        cycle += 1
    endwhile
    if cycle > 0
        Trace("EnsureMarker", akActor.GetDisplayName() + " waited " + cycle + " cycles for 3D")
    endif
    return marker
EndFunction

Float Function DistanceTo(Actor akActor, float x, float y, float z) global
    float dx = akActor.GetPositionX() - x
    float dy = akActor.GetPositionY() - y
    float dz = akActor.GetPositionZ() - z
    return Math.sqrt(dx * dx + dy * dy + dz * dz)
EndFunction

; SheatheWeapon only starts the animation. C++ (Sheathe phase) waits for the weapon state to reach sheathed before
; Begin, and re-sends this every second for an actor still drawn.
Function Sheathe(Actor akActor) global
    if akActor == None
        return
    endif
    akActor.StopCombat()
    akActor.StopCombatAlarm()
    if akActor.IsWeaponDrawn()
        akActor.SheatheWeapon()
        Trace("Sheathe", akActor.GetDisplayName())
    endif
EndFunction

; Walks the actor toward its first-stage spot (C++ Approach phase); az in degrees. Latent: PathToReference returns
; when the actor arrives or the walk fails. C++ also watches the distance and runs Begin, whose Lock ends a walk still
; running. No package: the DoNothing override must not be on yet.
Function Approach(Actor akActor, Actor akFace, float x, float y, float z, float az) global
    if akActor == None || !akActor.Is3DLoaded()
        return
    endif
    Sheathe(akActor)
    ObjectReference marker = EnsureMarker(akActor)
    marker.SetPosition(x, y, z)
    marker.SetAngle(0.0, 0.0, az)
    if akActor == Game.GetPlayer()
        Game.ForceThirdPerson()
        Game.DisablePlayerControls(true, true, false, false, true, false, true, false, 0)
        Game.SetPlayerAIDriven(true)
    endif
    if akFace
        akActor.SetLookAt(akFace, false)
    endif
    bool ok = akActor.PathToReference(marker, 0.5)
    Trace("Approach", akActor.GetDisplayName() + " path " + ok + " d=" + DistanceTo(akActor, x, y, z))
EndFunction

; Lock, Strip, then Snap on one stack, so the vehicle marker exists before the first placement and the clothes are off
; before stage 1. C++ waits for every actor's Begin before it sends the first stage events.
Function Begin(Actor akActor, float x, float y, float z, float az, Bool strip, Bool victim) global
    Lock(akActor)
    if strip
        Strip(akActor, victim)
    endif
    Snap(akActor, x, y, z, az)
EndFunction

String Function StrippedKey() global
    return "SkyrimNet_SexLab_AE_Stripped"
EndFunction

; Scene.psc's in-scene strip flag, read by the WebUI dress / undress eligibility rules.
String Function UndressedKey() global
    return "skyrimnet_sexlab_scene_undressed"
EndFunction

; SexLab's MCM strip set (victim set when victim), no animation; Unlock re-dresses from the stored list.
Function Strip(Actor akActor, Bool victim) global
    if akActor == None
        return
    endif
    SexLabFramework sexlab = SexLabUtil.GetAPI()
    if sexlab == None
        Trace("Strip", "SexLab API missing; " + akActor.GetDisplayName() + " stays dressed")
        return
    endif
    Actor victim_ref = None
    if victim
        victim_ref = akActor
    endif
    Form[] forms = sexlab.StripActor(akActor, victim_ref, false, false)
    int count = 0
    if forms
        count = forms.Length
    endif
    int i = 0
    while i < count
        if forms[i]
            StorageUtil.FormListAdd(akActor, StrippedKey(), forms[i], false)
        endif
        i += 1
    endwhile
    StorageUtil.SetIntValue(akActor, UndressedKey(), 1)
    Trace("Strip", akActor.GetDisplayName() + " victim:" + victim + " items:" + count)
EndFunction

Function Redress(Actor akActor) global
    if StorageUtil.FormListCount(akActor, StrippedKey()) > 0
        Form[] forms = StorageUtil.FormListToArray(akActor, StrippedKey())
        StorageUtil.FormListClear(akActor, StrippedKey())
        SexLabFramework sexlab = SexLabUtil.GetAPI()
        if sexlab
            sexlab.UnstripActor(akActor, forms, false)
        endif
        Trace("Redress", akActor.GetDisplayName() + " items:" + forms.Length)
    endif
    StorageUtil.UnsetIntValue(akActor, UndressedKey())
EndFunction

; Settle phase (C++): stops the game Scene (e.g. a vanilla argument) the actor is in, once its voice line ended.
Function StopScene(Actor akActor) global
    if akActor == None
        return
    endif
    Scene sc = akActor.GetCurrentScene()
    if sc && sc.IsPlaying()
        sc.Stop()
        akActor.EvaluatePackage()
        Trace("StopScene", akActor.GetDisplayName() + " stopped " + sc)
    endif
EndFunction

; Approach, for an actor that does not walk: Lock, then a visible turn in place to az (toward the partner). One stack,
; so Lock's StopTranslation cannot cancel the turn.
Function LockFace(Actor akActor, float x, float y, float z, float az) global
    Sheathe(akActor)
    Lock(akActor)
    if akActor == None || !akActor.Is3DLoaded()
        return
    endif
    ObjectReference marker = EnsureMarker(akActor)
    marker.SetAngle(0.0, 0.0, az)
    akActor.TranslateTo(akActor.GetPositionX(), akActor.GetPositionY(), akActor.GetPositionZ(), 0.0, 0.0, az, 1.0, 180.0)
EndFunction

; az - the actor's heading, in [-180, 180].
Float Function AngleOff(Actor akActor, float az) global
    float off = az - akActor.GetAngleZ()
    while off > 180.0
        off -= 360.0
    endwhile
    while off < -180.0
        off += 360.0
    endwhile
    return off
EndFunction

; First placement: a hard set of position and angle, as SexLab does at the start (sslActorAlias.psc:602-606).
Function Snap(Actor akActor, float x, float y, float z, float az) global
    if akActor == None || !akActor.Is3DLoaded()
        return
    endif
    ObjectReference marker = EnsureMarker(akActor)
    marker.SetPosition(x, y, z)
    marker.SetAngle(0.0, 0.0, az)
    akActor.SetVehicle(marker)
    akActor.SetPosition(x, y, z)
    akActor.SetAngle(0.0, 0.0, az)
    Hold(akActor, x, y, z, az)
EndFunction

Function Lock(Actor akActor) global
    if akActor == None
        return
    endif
    akActor.ClearLookAt()
    akActor.StopCombat()
    akActor.StopCombatAlarm()
    if akActor.IsWeaponDrawn()
        akActor.SheatheWeapon()
    endif
    if akActor == Game.GetPlayer()
        Game.ForceThirdPerson()
        Game.DisablePlayerControls(true, true, false, false, true, false, true, false, 0)
        Game.SetPlayerAIDriven(true)
    else
        akActor.SetRestrained(true)
        akActor.SetDontMove(true)
    endif
    Package pkg = DoNothingPackage()
    if pkg
        ActorUtil.AddPackageOverride(akActor, pkg, 100, 1)
        akActor.EvaluatePackage()
    else
        Trace("Lock", "DoNothing package missing from SkyrimNet_SexLab.esp")
    endif
    ; sslActorAlias LockActor: stop any translation, then attach the marker where the actor stands.
    akActor.StopTranslation()
    ObjectReference marker = EnsureMarker(akActor)
    marker.MoveTo(akActor)
    akActor.SetVehicle(marker)
    Trace("Lock", akActor.GetDisplayName())
EndFunction

; az in degrees. Moves the marker to (x, y, z, az), then the actor: a glide and turn when close (after Approach, and
; between stages), a set when far.
Function Place(Actor akActor, float x, float y, float z, float az) global
    if akActor == None || !akActor.Is3DLoaded()
        return
    endif
    ObjectReference marker = EnsureMarker(akActor)
    marker.SetPosition(x, y, z)
    marker.SetAngle(0.0, 0.0, az)
    akActor.SetVehicle(marker)
    float dist = DistanceTo(akActor, x, y, z)
    if dist > 100.0
        akActor.SetPosition(x, y, z)
        akActor.SetAngle(0.0, 0.0, az)
    elseif dist > 2.0 || Math.abs(AngleOff(akActor, az)) > 3.0
        akActor.TranslateTo(x, y, z, 0.0, 0.0, az, 200.0, 360.0)
        return
    endif
    Hold(akActor, x, y, z, az)
EndFunction

; SexLab's Snap (sslActorAlias.psc:893-914): far off → set, a little off → fast translate, in place → a very slow
; rotation that pins the actor. Unlike SexLab, it also checks the angle: the pin's 0.0001°/s rotation replaces a turn
; still in progress, which left the actor turned part way.
Function Hold(Actor akActor, float x, float y, float z, float az) global
    if akActor == None || !akActor.Is3DLoaded()
        return
    endif
    float dist = DistanceTo(akActor, x, y, z)
    if dist > 75.0
        akActor.SetPosition(x, y, z)
        akActor.SetAngle(0.0, 0.0, az)
    elseif dist > 2.0
        akActor.TranslateTo(x, y, z, 0.0, 0.0, az, 50000.0, 0.0)
        return
    else
        float off = AngleOff(akActor, az)
        if Math.abs(off) > 3.0
            Trace("Hold", akActor.GetDisplayName() + " angle off " + off)
            akActor.TranslateTo(x, y, z, 0.0, 0.0, az, 500.0, 720.0)
            return
        endif
    endif
    akActor.TranslateTo(x, y, z, 0.0, 0.0, az + 0.01, 500.0, 0.0001)
EndFunction

Function Unlock(Actor akActor) global
    if akActor == None
        return
    endif
    akActor.ClearLookAt()
    akActor.StopTranslation()
    akActor.SetVehicle(None)
    ObjectReference marker = StorageUtil.GetFormValue(akActor, MarkerKey()) as ObjectReference
    StorageUtil.UnsetFormValue(akActor, MarkerKey())
    if marker
        marker.Disable()
        marker.Delete()
    endif
    Package pkg = DoNothingPackage()
    if pkg
        ActorUtil.RemovePackageOverride(akActor, pkg)
    endif
    if akActor == Game.GetPlayer()
        Game.SetPlayerAIDriven(false)
        Game.EnablePlayerControls()
    else
        akActor.SetRestrained(false)
        akActor.SetDontMove(false)
    endif
    ; sslActorAlias.psc:1429: remove the SOS erection.
    Debug.SendAnimationEvent(akActor, "SOSFlaccid")
    SetMouth(akActor, false)
    Redress(akActor)
    akActor.EvaluatePackage()
    Trace("Unlock", akActor.GetDisplayName())
EndFunction

String Function MouthKey() global
    return "SkyrimNet_SexLab_AE_MouthOpen"
EndFunction

; Stage open_mouth flag (SexLab RefreshExpression, sslActorAlias.psc:1825). C++ calls it when the flag changes;
; Unlock closes a mouth this opened.
Function SetMouth(Actor akActor, Bool open) global
    if akActor == None
        return
    endif
    if open
        sslBaseExpression.OpenMouth(akActor)
        StorageUtil.SetIntValue(akActor, MouthKey(), 1)
    elseif StorageUtil.GetIntValue(akActor, MouthKey(), 0) == 1
        sslBaseExpression.CloseMouth(akActor)
        StorageUtil.UnsetIntValue(akActor, MouthKey())
    endif
EndFunction

; SexLab's orgasm effect without a thread (sslActorAlias.DoOrgasm, sslActorAlias.psc:987-1007): camera shake for the
; player, the voice's orgasm sound, OrgasmFX, and cum on cum_to (C++ picks the targets and cum ids). No SexLabOrgasm
; ModEvent: Scene_Manager.OrgasmIndividual listens to it and would narrate the orgasm a second time.
Function OrgasmEffect(Actor akActor, Actor[] cum_to, int[] cum_ids, Bool silent) global
    if akActor == None
        return
    endif
    SexLabFramework sexlab = SexLabUtil.GetAPI()
    if sexlab == None
        Trace("OrgasmEffect", "SexLab API missing; " + akActor.GetDisplayName())
        return
    endif
    sslSystemConfig config = sexlab.Config
    if config && config.OrgasmEffects
        if akActor == Game.GetPlayer() && config.ShakeStrength > 0.0 && Game.GetCameraState() >= 8
            Game.ShakeCamera(None, config.ShakeStrength, config.ShakeStrength + 1.0)
        endif
        if !silent
            sslBaseVoice voice = sexlab.GetVoice(akActor)
            if voice == None
                voice = sexlab.PickVoice(akActor)
            endif
            if voice
                PlaySound(voice.GetSound(100, false), akActor, config.VoiceVolume)
            endif
        endif
        PlaySound(config.OrgasmFX, akActor, config.SFXVolume)
    endif
    int cum = 0
    if (config == None || config.UseCum) && cum_to
        int i = 0
        while i < cum_to.Length
            if cum_to[i] && cum_ids && i < cum_ids.Length && cum_ids[i] > 0
                sexlab.ApplyCum(cum_to[i], cum_ids[i])
                cum += 1
            endif
            i += 1
        endwhile
    endif
    Trace("OrgasmEffect", akActor.GetDisplayName() + " silent:" + silent + " cum:" + cum)
EndFunction

Function PlaySound(Sound sfx, Actor akActor, float volume) global
    if sfx == None
        return
    endif
    int id = sfx.Play(akActor)
    if id != 0 && volume > 0.0
        Sound.SetInstanceVolume(id, volume)
    endif
EndFunction

; AnimEngineOrgasm::Narration::OrgasmGroup's DN, routed like Scene.NarrateOrgasmStash (orgasm-narration.md): the
; orgasm_level cap, DirectNarration with the player in the scene, else Nearby; overflow goes out as an update event.
Function NarrateOrgasm(String msg, String overflow, Actor source, Actor target, Bool has_player) global
    int level = SkyrimNet_SexLab_Utilities.NarrationLevel("sexlab.narration.orgasm_level")
    if msg != ""
        if level < 3
            SkyrimNet_SexLab_Utilities.NarrateBelowDirect(level, "orgasm", msg, source, target)
        elseif has_player
            SkyrimNet_SexLab_Utilities.DirectNarration(msg, source, target, purge_dialogue=true)
        else
            SkyrimNet_SexLab_Utilities.DirectNarration_Nearby("orgasm", msg, source, target)
        endif
    endif
    if overflow != ""
        SkyrimNet_SexLab_Utilities.NarrateBelowDirect(level, "sexlab update", overflow, source, target)
    endif
    Trace("NarrateOrgasm", "level:" + level + " " + msg + " | overflow: " + overflow)
EndFunction
