Scriptname SkyrimNet_SexLab_AnimEngine Hidden

; AnimEngine (C++) drives actors through AnimDB playback data without SexLab's thread (sexlab.anim_engine.enabled).
; This script is its thin Papyrus shell for what the plugin has no C++ path for yet: restraint, player controls, the
; vehicle marker, the walk into place and the TranslateTo hold. C++ calls Lock / Approach / Sheathe / Begin / Place /
; Hold / Unlock (DispatchStaticCall); Hold is re-sent every second because a global script gets no OnTranslationComplete.
; See docs/developers/anim-engine.md §4.

; Debug start: player + NPC (or one actor), ordered by the registry's positions. Returns the scene id, -1 on failure.
int Function AnimEngine_DebugStart(Actor a, Actor b, String registry) global native
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

; Lock then Snap on one stack, so the vehicle marker exists before the first placement. C++ waits for every actor's
; Begin before it sends the first stage events.
Function Begin(Actor akActor, float x, float y, float z, float az) global
    Lock(akActor)
    Snap(akActor, x, y, z, az)
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
    akActor.EvaluatePackage()
    Trace("Unlock", akActor.GetDisplayName())
EndFunction
