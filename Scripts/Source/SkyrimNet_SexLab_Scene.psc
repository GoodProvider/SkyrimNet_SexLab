Scriptname SkyrimNet_SexLab_Scene extends SkyrimNet_SexLab_Scene_Interface

Import SkyrimNet_SexLab_Utilities
import SkyrimNet_SexLab_Scene_Interface
Import JContainers

SexLabFramework Property sexlab Auto
sslThreadSlots Property threadSlots Auto
sslActorLibrary Property actorLib Auto

Faction Property SkyrimNet_SexLab_Faction_Victim Auto

; all arrays should be Handled by EnsureActorArraysLargeEnough
; Actor list is always thread.positions — do not cache a parallel Actor[].
int[] position_objs
int actors_objs
; JArray of Forms we granted SkyrimNet_SexLab_Faction_Victim. Tracked so an actor
; who leaves the scene mid-run (position swap / reshuffle) still gets the faction
; cleared. thread.positions stays authoritative for the participant list.
int victim_faction_forms
; Stores the Orgasm messages for Combined flush (StageStart, or Scene OnUpdate
; when a DOM slave is in the thread so last-stage melt can join the player).
String[] orgasm_messages
bool orgasm_messages_set = false
bool orgasm_window_open = false
; Real-time stamp when the Combined DOM window first armed; ArmOrgasmWindow
; will not extend past 2x orgasm_delay from this start.
float orgasm_window_started_at = 0.0

String storage_prefix = "skyrimnet_sexlab_scene"
String storage_obj_key = "skyrimnet_sexlab_scene_actor_position_obj"
String storage_total_orgasms_key = "skyrimnet_sexlab_scene_total_orgasms"
int thread_obj = 0 ; Thread_obj will be reused 
String[] played_registries
int played_registries_count = 0
; Per-registry user-edited animation defaults (Scene/AnimPanel). Wins over AnimDB on anim switch until Save.
int user_anim_defaults = 0

; -------------------------------------------
; Intent
; -------------------------------------------
int Property INTENT_STAGE_START = 0 AutoReadOnly
int Property INTENT_STAGE_ONGOING = 1 AutoReadOnly
int Property INTENT_STAGE_END = 2 AutoReadOnly

float Property orgasm_delay = 5.0 Auto
; Vanilla default stage timers sum to ~89s. P+ enjoyment-wait can hop/restart
; instead of ending; cap LLM scenes so they still finish.
float Property DURATION_CAP_SECONDS = 120.0 AutoReadOnly
float animating_started_at = 0.0

; -------------------------------------------
; Who send the messages to SkyrimNet 
; -------------------------------------------
Actor sender = None 
Actor receiver = None 

; Initiator is the actor who initiated the scene
Actor initiator = None

; --------------------------------------------
; Track Scene
; --------------------------------------------
bool Property tracking = False Auto

; True if Scene Creator was already shown for this SexLab thread (once-per-thread gate).
bool Property scene_creator_menu_called = False Auto

; --------------------------------------------
; Description of the scene
; --------------------------------------------
String description_last = ""
int stage_last = 0

; --------------------------------------------
; Thread
; --------------------------------------------
sslThreadController thread

; --------------------------------------------
; Fallback / generic scene flag
; Permanent once set via Initialize(..., _is_generic=true).
; Never clear on Release — this Scene is the pool fallback when no
; inactive sl_scenes remain, so every active thread can still get a description.
; --------------------------------------------
bool is_generic

Function Trace(String func, String msg="", Bool notification=False)
    String body = "sid:"+sid+" "+msg
    String logged = SkyrimNet_SexLab_WebUI.TraceLog("SkyrimNet_SexLab_Scene", func, body)
    if notification
        Debug.Notification(body)
    endif
EndFunction

bool debug_mode = false
Function DbgEnter(String func, String msg="")
    if debug_mode 
        if msg != ""
            Trace(func, "--- enter "+msg)
        else
            Trace(func, "--- enter")
        endif
    endif
EndFunction

Function DbgReturn(String func, String msg="")
    if debug_mode 
        if msg != ""
            Trace(func, "--- return "+msg)
        else
            Trace(func, "--- return")
        endif
    endif
EndFunction

Function DbgEnd(String func, String msg="")
    if debug_mode 
        if msg != ""
            Trace(func, "--- end "+msg)
        else
            Trace(func, "--- end")
        endif
    endif
EndFunction

Function DbgMsg(String func, String msg="")
    if debug_mode 
        if msg != ""
            Trace(func, "--- "+msg)
        else
            Trace(func, "---")
        endif
    endif
EndFunction


String Function GetString() 
    return " actors: ["+actor_names+"]"\
          +" victims: ["+victim_names+"]"\
          +" assailants: ["+assailant_names+"]"\
          +" style:"+style
EndFunction 

; _is_generic: pass true only for sl_scene_generic from Scene_Manager.
; This flag is permanent for the instance lifetime — do not clear on Release.
Function Initialize(int _sid, SkyrimNet_SexLab_Scene_Manager _manager, bool _is_generic = false) 
    debug_mode = False
    DbgEnter("Initialize", "sid:"+_sid+" is_generic:"+_is_generic)
    parent.Initialize(_sid,_manager, _is_generic) 
    EnsureActorArraysLargeEnough(2)
    sexlab = manager.sexlab
    threadSlots = manager.threadSlots
    actorLib = manager.actorLib
    SkyrimNet_SexLab_Faction_Victim = manager.SkyrimNet_SexLab_Faction_Victim
    is_generic = _is_generic
    ; Drop stale thread from prior save/session — status was reset by parent.Initialize.
    thread = None
    animating_started_at = 0.0
    StorageUtil.ClearAllPrefix(storage_prefix)

    if thread_obj < 1 || !SNSL_JValue.isExists(thread_obj)
        thread_obj = SNSL_JMap.object()
        SNSL_JValue.retain(thread_obj)
    endif

    ; Recreate rather than re-attach: actors_objs is retained, so setObj-ing it back into a
    ; thread_obj that lost it would store a deep copy (see ResetActorsObjs).
    if actors_objs < 1 || !SNSL_JValue.isExists(actors_objs) || SNSL_JMap.getObj(thread_obj, "actors") != actors_objs
        ResetActorsObjs(0)
    endif
    if victim_faction_forms < 1 || !SNSL_JValue.isExists(victim_faction_forms)
        victim_faction_forms = SNSL_JArray.object()
        SNSL_JValue.retain(victim_faction_forms)
    endif
    DbgEnd("Initialize")
EndFunction

; -----------------------------

Bool Function Setup(SkyrimNet_SexLab_Scene_Creator creator)
    if creator != None
        DbgEnter("Setup", "creator present")
    else
        DbgEnter("Setup")
    endif
    Bool links_ok = Setup_CheckLinks()
    if !links_ok
        DbgReturn("Setup", "False")
        return False
    endif
    if thread == None 
        Trace("Setup","thread is none, aborting")
        DbgReturn("Setup", "False")
        return False
    endif 

    Actor[] positions = thread.positions
    if !positions
        DbgReturn("Setup", "False")
        return False
    endif
    int num_actors = positions.length
    DbgMsg("Setup", "thread.positions count="+num_actors)
    EnsureActorArraysLargeEnough(num_actors) 
    orgasm_messages_set = false
    orgasm_window_open = false
    orgasm_window_started_at = 0.0
    UnregisterForUpdate()

    int i = 0 
    ; Assign interface property (not a local) before SetPosition/SetActor so assailant flags work.
    num_victims = 0 
    if num_actors != SNSL_JArray.count(actors_objs)
        ResetActorsObjs(num_actors)
    endif

    ReconcileVictimFactions()

    if creator != None 
        has_player = creator.has_player
        intent = creator.intent 
        style = creator.style
        ; initiator from Creator.GetSpeaker() (may be None); target only feeds receiver.
        initiator = creator.GetSpeaker()
        sender = initiator
        receiver = creator.GetTarget()
        if sender == None
            if num_actors == 1
                sender = positions[0]
            elseif num_actors >= 2
                sender = positions[1]
            endif
        endif
        if receiver == None && num_actors >= 2
            receiver = positions[0]
        endif
        position_override = creator.position_override
        i = 0
        while i < num_actors
            if i < creator.num_actors && position_override
                SetPosition(i, positions[i], creator.no_orgasm_mask[i], creator.speaking_modifiers[i])
                SNSL_JMap.setInt(position_objs[i], "dressed", creator.no_stripping_mask[i])
                ; Scene Creator's explicit choices hold for the starting animation, matching
                ; TM_ApplySpeaking's lock semantics -- otherwise StageStart's
                ; ApplyAnimDbSpeaking() clobbers speaking from the registry's per-stage default on
                ; the very next stage transition. Switching animation drops all three locks and
                ; reloads that animation's defaults (SyncAnimationDefaults).
                SNSL_JMap.setInt(position_objs[i], "speaking_locked", 1)
                SNSL_JMap.setInt(position_objs[i], "orgasm_locked", 1)
                SNSL_JMap.setInt(position_objs[i], "dressed_locked", 1)
            else
                SetPosition(i, positions[i], 0, creator.speaking_modifiers_default_current)
                SNSL_JMap.setInt(position_objs[i], "dressed", 0)
            endif 
            i += 1 
        endwhile 
    else 
        intent = INTENT_DEFAULT
        style = STYLE_DEFAULT
        initiator = None
        sender = None
        receiver = None
        i = 0 
        has_player = false
        Actor player = Game.GetPlayer()
        while i < num_actors
            SetPosition(i, positions[i], 0, speaking_modifiers_DEFAULT)
            if positions[i] == player
                has_player = true
            endif
            i += 1 
        endwhile 
        if num_actors == 1 
            sender = positions[0]
            receiver = None 
        else 
            sender = positions[1]
            receiver = positions[0]
        endif
    endif
    ApplySexLabVoices()
    if num_actors > 1 && num_victims > 0
        DbgMsg("Setup", "thread.GetVictim()")
        Actor victim = thread.GetVictim()
        DbgMsg("Setup", "thread.GetVictim() returned "+victim)
        if victim != None && sender == victim
            sender = receiver
            receiver = victim
        endif
    endif
    PickNonVictimInitiator()
    Trace("Setup", "initiator:"+GetDisplayName(initiator)+" sender:"+GetDisplayName(sender)+" receiver:"+GetDisplayName(receiver))

    if !is_generic
        status = STATUS_SETUP
    else 
        status = STATUS_ACTIVE 
    endif 
    if animating_started_at <= 0.0
        animating_started_at = Utility.GetCurrentRealTime()
    endif
    SetNames()
    PersistPositions()
    ; New scene: the starting animation is the baseline for SyncAnimationDefaults.
    seeded_registry = ""
    pending_animation_change = false
    animation_change_from = ""
    if !position_override
        ; No Scene Creator values: the first SyncAnimationDefaults (AnimationStart's
        ; GetThreadObj, or StageStart) seeds the starting animation's defaults. Not here: the
        ; thread is still preparing, and SexLab's own stripping would undo ApplyDressedToActor.
        seed_first_animation = true
    elseif thread.animation
        seeded_registry = thread.animation.Registry
    endif
    DbgEnd("Setup")
    return True
EndFunction 

Bool Function Setup_CheckLinks()
    Bool links_ok = true

    if manager == None
        links_ok = false
    endif

    if main == None
        links_ok = false
    endif

    if animdb == None
        links_ok = false
    endif

    if sexlab == None
        links_ok = false
    endif

    if threadSlots == None
        links_ok = false
    endif

    if actorLib == None
        links_ok = false
    endif

    return links_ok
EndFunction

; When the thread has victims, keep initiator only if they are not a victim.
; Otherwise pick the first non-victim from positions 1..n then 0, or None.
Function PickNonVictimInitiator()
    DbgEnter("PickNonVictimInitiator")
    if thread == None || num_victims < 1
        DbgReturn("PickNonVictimInitiator", "no victims")
        return
    endif
    if initiator != None
        DbgMsg("PickNonVictimInitiator", "thread.IsVictim "+initiator.GetDisplayName())
        if !thread.IsVictim(initiator)
            DbgReturn("PickNonVictimInitiator", "keep "+GetDisplayName(initiator))
            return
        endif
    endif
    initiator = None
    Actor[] positions = thread.positions
    if !positions
        DbgReturn("PickNonVictimInitiator", "no positions")
        return
    endif
    int n = positions.length
    int i = 1
    while i < n && initiator == None
        Actor a = positions[i]
        if a != None
            DbgMsg("PickNonVictimInitiator", "thread.IsVictim "+a.GetDisplayName())
            if !thread.IsVictim(a)
                initiator = a
            endif
        endif
        i += 1
    endwhile
    if initiator == None && n > 0
        Actor a = positions[0]
        if a != None
            DbgMsg("PickNonVictimInitiator", "thread.IsVictim "+a.GetDisplayName())
            if !thread.IsVictim(a)
                initiator = a
            endif
        endif
    endif
    DbgEnd("PickNonVictimInitiator", GetDisplayName(initiator))
EndFunction

; Reconcile SkyrimNet_SexLab_Faction_Victim membership with the current
; thread.positions. Adds the faction to current victims, removes it from current
; non-victims, and clears it from any previously-tracked actor who has left the
; scene. Keeps victim_faction_forms holding exactly the current victims and sets
; the num_victims interface property. Safe to call from Setup and AlignActors.
Function ReconcileVictimFactions()
    DbgEnter("ReconcileVictimFactions")
    if thread == None 
        DbgEnd("ReconcileVictimFactions")
        return 
    endif 
    if victim_faction_forms < 1 || !SNSL_JValue.isExists(victim_faction_forms)
        victim_faction_forms = SNSL_JArray.object()
        SNSL_JValue.retain(victim_faction_forms)
    endif

    Actor[] positions = thread.positions
    int num_actors = positions.length

    ; Drop tracked actors who are no longer a current victim (departed or role changed).
    int t = SNSL_JArray.count(victim_faction_forms) - 1
    while 0 <= t
        Actor tracked = SNSL_JArray.getForm(victim_faction_forms, t) as Actor
        bool still_victim = false 
        if tracked != None 
            int p = 0 
            while p < num_actors && !still_victim 
                if positions[p] == tracked && thread.IsVictim(tracked) 
                    still_victim = true 
                endif 
                p += 1 
            endwhile 
        endif 
        if !still_victim 
            if tracked != None && tracked.IsInFaction(SkyrimNet_SexLab_Faction_Victim) 
                tracked.RemoveFromFaction(SkyrimNet_SexLab_Faction_Victim) 
            endif 
            SNSL_JArray.eraseIndex(victim_faction_forms, t)
        endif
        t -= 1
    endwhile

    ; Apply faction to current actors and track new victims.
    num_victims = 0 
    int i = 0 
    while i < num_actors 
        Actor akActor = positions[i] 
        if akActor != None 
            DbgMsg("ReconcileVictimFactions", "thread.IsVictim "+akActor.GetDisplayName())
            if thread.IsVictim(akActor) 
                num_victims += 1 
                akActor.AddToFaction(SkyrimNet_SexLab_Faction_Victim) 
                if SNSL_JArray.findForm(victim_faction_forms, akActor) < 0
                    SNSL_JArray.addForm(victim_faction_forms, akActor)
                endif
            else 
                if akActor.IsInFaction(SkyrimNet_SexLab_Faction_Victim) 
                    akActor.RemoveFromFaction(SkyrimNet_SexLab_Faction_Victim) 
                endif 
            endif 
        endif 
        i += 1 
    endwhile 
    DbgEnd("ReconcileVictimFactions")
EndFunction 

; Teardown only — reset/release all state except sid and is_generic.
; AlignActors must not tear down; only Release owns resource cleanup.
Function Release()
    DbgEnter("Release")
    UnregisterForUpdate()
    seeded_registry = ""
    position_override = true
    seed_first_animation = false
    pending_animation_change = false
    animation_change_from = ""
    orgasm_window_open = false
    orgasm_window_started_at = 0.0
    int i = 0
    int num_actors = 0
    if thread != None
        num_actors = thread.positions.length
    endif
    while i < num_actors
        Actor akActor = thread.positions[i]
        if akActor != None
            if akActor.IsInFaction(SkyrimNet_SexLab_Faction_Victim)
                akActor.RemoveFromFaction(SkyrimNet_SexLab_Faction_Victim)
            endif 
            StorageUtil.UnsetIntValue(akActor, storage_obj_key)
            StorageUtil.UnsetIntValue(akActor, storage_total_orgasms_key)
            ClearPersistedPosition(akActor)
        endif
        if position_objs && i < position_objs.length && position_objs[i] > 0
            int speaking_obj = SNSL_JMap.getObj(position_objs[i], "speaking_modifiers")
            if speaking_obj > 0
                SNSL_JValue.release(speaking_obj)
            endif
            SNSL_JMap.clear(position_objs[i])
        endif
        i += 1
    endwhile
    ; Clear the victim faction from every tracked grant (covers actors who left the
    ; scene and so are no longer in thread.positions), then empty the tracker.
    if victim_faction_forms > 0 && SNSL_JValue.isExists(victim_faction_forms)
        int vf = SNSL_JArray.count(victim_faction_forms) - 1
        while 0 <= vf
            Actor va = SNSL_JArray.getForm(victim_faction_forms, vf) as Actor
            if va != None && va.IsInFaction(SkyrimNet_SexLab_Faction_Victim)
                va.RemoveFromFaction(SkyrimNet_SexLab_Faction_Victim)
            endif
            vf -= 1
        endwhile
        SNSL_JArray.clear(victim_faction_forms)
    endif
    ; Also clear leftover position_objs slots beyond current thread size
    if position_objs
        while i < position_objs.length
            if position_objs[i] > 0
                int speaking_obj = SNSL_JMap.getObj(position_objs[i], "speaking_modifiers")
                if speaking_obj > 0
                    SNSL_JValue.release(speaking_obj)
                endif
                SNSL_JMap.clear(position_objs[i])
            endif
            i += 1
        endwhile
    endif
    ; Clear pending orgasm messages so a reused pool scene never inherits stale
    ; entries (OrgasmCombined only writes a slot when orgasm_messages[i] == "").
    if orgasm_messages
        int m = 0
        while m < orgasm_messages.length
            orgasm_messages[m] = ""
            m += 1
        endwhile
    endif
    orgasm_messages_set = false
    orgasm_window_open = false
    orgasm_window_started_at = 0.0
    animating_started_at = 0.0

    sender = None 
    receiver = None 
    initiator = None
    tracking = False
    scene_creator_menu_called = False

    if thread_obj > 0 && SNSL_JValue.isExists(thread_obj)
        ; clear detaches the retained actors_objs; ResetActorsObjs frees it and attaches a fresh one.
        SNSL_JMap.clear(thread_obj)
        ResetActorsObjs(0)
    endif

    if thread != None
        ; Always clear thread_scene[tid], including generic — otherwise a reused
        ; generic leaves a stale tid→generic map until a later mismatch force-Release.
        manager.UnsetThread_scene(thread.tid)
        thread = None 
    else 
        Trace("Release","Thread is None, continuing cleanup") 
    endif 
    ; parent resets interface fields except sid; is_generic is intentionally preserved
    parent.Release()
    DbgEnd("Release")
EndFunction

Function EnsureActorArraysLargeEnough(int size)
    DbgEnter("EnsureActorArraysLargeEnough", "size:"+size)
    ; Resize only when too small (orgasm_messages must also be present -- save/load or older code
    ; can restore position_objs while orgasm_messages stays None, leaving Combined crashing). Do
    ; NOT early-return past the per-slot isExists loop below just because both arrays are already
    ; the right length: the JSON store invalidates every SNSL handle held in a Papyrus member
    ; variable on every save load (JsonStore.h OnNewSession), so a same-length position_objs loaded
    ; from a save is full of dead handles that must be recreated here, not skipped. See
    ; KNOWLEDGEBASE "JSON store handles die on every save load".
    if !position_objs || !orgasm_messages || size > position_objs.length || size > orgasm_messages.length
        position_objs = EnsureIntsLargeEnough(position_objs, size, 0 )
        orgasm_messages = EnsureStringsLargeEnough(orgasm_messages, size, "")
    endif
    int i = 0
    while i < size
        ; position_objs[i] is a retained root and the only live copy of the slot's metadata.
        ; It is never attached anywhere by reference: RelinkActorsObjs gives actors_objs a
        ; deep-copy snapshot of it, so all reads/writes must go through position_objs.
        if position_objs[i] < 1 || !SNSL_JValue.isExists(position_objs[i])
            if position_objs[i] > 0 && thread != None && status == STATUS_ACTIVE
                ; Diagnostic: a live scene's slot should only die across a save load.
                Trace("EnsureActorArraysLargeEnough", "recreating dead slot "+i+" old handle:"+position_objs[i])
            endif
            position_objs[i] = SNSL_JMap.object()
            SNSL_JValue.retain(position_objs[i])
            ; Prompts call contains(speaker.speaking_modifiers, ...), which errors on a missing key.
            ; RestorePosition bails for actors without a persisted tid, so seed an empty array first.
            SetSpeakingObj(i, "")
            ; After a load: restore before anything (SeedOverlayFromAnimDb, SetPosition) reads it.
            if thread != None && i < thread.positions.length
                RestorePosition(i, thread.positions[i])
                ApplySexLabVoice(i)
            endif
        endif
        i += 1
    endwhile
    DbgEnd("EnsureActorArraysLargeEnough")
EndFunction

; Frees actors_objs and attaches a fresh array of `size` under thread_obj.actors.
; Attach BEFORE retain (see SetSpeakingObj for why): a fresh, unretained array attaches by
; reference; retaining first would make setObj deep-copy it instead.
Function ResetActorsObjs(int size)
    if actors_objs > 0 && SNSL_JValue.isExists(actors_objs)
        SNSL_JValue.release(actors_objs)
    endif
    actors_objs = SNSL_JArray.objectWithSize(size)
    SNSL_JMap.setObj(thread_obj, "actors", actors_objs)
    SNSL_JValue.retain(actors_objs)
EndFunction

; Refreshes thread_obj.actors from position_objs. Each setObj stores a deep-copy snapshot
; (position_objs are retained roots) and frees the previous one, so call this after the
; last position_objs write and before thread_obj is dumped.
Function RelinkActorsObjs(int size)
    int i = 0
    while i < size && i < position_objs.length
        SNSL_JArray.setObj(actors_objs, i, position_objs[i])
        i += 1
    endwhile
EndFunction

; ----------------------------------------
; Animation change: locks (speaking/orgasm/dressed) only hold within one animation. Switching to
; a different animation drops them and reloads that animation's defaults.
; -----------------------------------------
String seeded_registry = ""   ; registry whose defaults position_objs currently reflect
; Scene Creator "override animation settings". Off: the WebUI's per-actor dressed/orgasm/speaking
; values are ignored and every animation, including the first, uses its own defaults.
bool position_override = true
; Set by Setup() when position_override is off, so SyncAnimationDefaults seeds the first
; registry instead of only recording it.
bool seed_first_animation = false

; Set when an animation change was detected and not yet narrated. StageStart consumes it and
; narrates "Scene changes from <old stage description> to <new stage description>".
bool pending_animation_change = false
String animation_change_from = ""

; Call from anywhere that may observe a changed thread.animation outside StageStart (poll, hooks,
; menus). Reloads the new animation's defaults now, and queues StageStart through a mod event
; (asynchronous: this can run inside GetThreadObj while a prompt decorator is building JSON, where
; narrating directly would be wrong). StageStart itself calls SyncAnimationDefaults directly.
Function CheckAnimationChange()
    String from_desc = description_last
    if SyncAnimationDefaults()
        QueueAnimationChangeStage(from_desc)
    endif
EndFunction

; Called every few seconds by Scene_Manager's poll (OnUpdate). SexLab's SetAnimation sends no
; event (SL Tools' animation list uses it), so polling is the only reliable detection. Returns
; True while this scene is animating, so the manager knows to keep polling.
bool Function PollAnimationChange()
    if thread == None || (thread as sslThreadModel).GetState() != "animating"
        return false
    endif
    CheckAnimationChange()
    return true
EndFunction

Function QueueAnimationChangeStage(String from_desc)
    pending_animation_change = true
    animation_change_from = from_desc
    int handle = ModEvent.Create("SkyrimNet_SexLab_AnimationChanged")
    if handle
        ModEvent.PushInt(handle, thread.tid)
        ModEvent.Send(handle)
    endif
EndFunction

; Reloads the new animation's defaults if thread.animation changed since the last call. Returns
; True on a change. The first registry of a scene is only recorded, so Setup's (Scene Creator)
; choices stand for the starting animation.
bool Function SyncAnimationDefaults()
    if thread == None || thread.animation == None
        return false
    endif
    String reg = thread.animation.Registry
    if reg == seeded_registry
        return false
    endif
    bool first = seeded_registry == ""
    seeded_registry = reg
    if first && !seed_first_animation
        return false
    endif
    seed_first_animation = false
    Trace("SyncAnimationDefaults", "animation "+reg+" first:"+first+", reloading its defaults")
    ReloadAnimationDefaults()
    ; The first animation is not a change: nothing to narrate.
    return !first
EndFunction

; Drops every position lock and reapplies the current animation's defaults to the actors.
Function ReloadAnimationDefaults()
    if thread == None || thread.animation == None
        return
    endif
    ClearPositionLocks()
    SeedOverlayFromAnimDb()
    ; SeedOverlayFromAnimDb only sets the dressed flag; make the actors match it.
    Actor[] positions = thread.positions
    int i = 0
    while positions && i < positions.length && i < position_objs.length
        if positions[i] && position_objs[i] > 0
            ApplyDressedToActor(positions[i], SNSL_JMap.getInt(position_objs[i], "dressed", 0) == 1)
        endif
        i += 1
    endwhile
EndFunction

; Strips or re-dresses akActor to match a dressed flag. Uses the thread's own tracked strip state
; (sslActorAlias.Strip/UnStrip), not main.Store/UnStoreStrippedItems -- that cache is only ever
; populated by the standalone Outfit_Dress/Outfit_Undress actions, never by the scene's own
; automatic per-thread stripping. See KNOWLEDGEBASE "Description Editor dressed toggle used wrong
; strip API (2026-09-22)".
Function ApplyDressedToActor(Actor akActor, Bool clothed)
    sslActorAlias slot = thread.ActorAlias(akActor)
    if slot
        if clothed
            slot.UnStrip()
        else
            slot.Strip()
        endif
    endif
EndFunction

; For callers that already applied the user's choices for the new animation (Description Editor
; commit): record it without reseeding, but still narrate the change like a stage start.
Function NoteSeededRegistry(String reg)
    bool changed = seeded_registry != "" && reg != seeded_registry
    seeded_registry = reg
    if changed
        QueueAnimationChangeStage(description_last)
    endif
EndFunction

Function ClearPositionLocks()
    int i = 0
    while position_objs && i < position_objs.length
        if position_objs[i] > 0 && SNSL_JValue.isExists(position_objs[i])
            SNSL_JMap.setInt(position_objs[i], "speaking_locked", 0)
            SNSL_JMap.setInt(position_objs[i], "orgasm_locked", 0)
            SNSL_JMap.setInt(position_objs[i], "dressed_locked", 0)
        endif
        i += 1
    endwhile
EndFunction

; ----------------------------------------
; Per-position settings that survive a save load
;
; position_objs live in the in-memory JSON store and are recreated empty after a load. The
; user-set fields below are mirrored per actor in StorageUtil (saved with the game) and
; restored when EnsureActorArraysLargeEnough recreates a dead slot. The prefix must NOT start with storage_prefix: Initialize's
; ClearAllPrefix(storage_prefix) runs on every load. Handler_DOM reads no_orgasm via
; Scene_Manager.IsNoOrgasmPersisted.
; -----------------------------------------
String persist_prefix = "skyrimnet_sexlab_pos_"

; Call at the end of any function that writes no_orgasm/dressed/deny_orgasm/speaking_modifiers
; or their *_locked flags. Only persists slots whose actor is bound to its position obj, so a
; not-yet-restored slot after a load can't overwrite the saved values with defaults.
Function PersistPositions()
    if thread == None || !position_objs
        return
    endif
    int n = thread.positions.length
    int i = 0
    while i < n && i < position_objs.length
        Actor a = thread.positions[i]
        int obj = position_objs[i]
        if a != None && SNSL_JValue.isExists(obj) && StorageUtil.GetIntValue(a, storage_obj_key, 0) == obj
            StorageUtil.SetIntValue(a, persist_prefix+"tid", thread.tid)
            StorageUtil.SetIntValue(a, persist_prefix+"no_orgasm", SNSL_JMap.getInt(obj, "no_orgasm"))
            StorageUtil.SetIntValue(a, persist_prefix+"deny_orgasm", SNSL_JMap.getInt(obj, "deny_orgasm"))
            StorageUtil.SetIntValue(a, persist_prefix+"dressed", SNSL_JMap.getInt(obj, "dressed"))
            StorageUtil.SetIntValue(a, persist_prefix+"orgasm_locked", SNSL_JMap.getInt(obj, "orgasm_locked"))
            StorageUtil.SetIntValue(a, persist_prefix+"speaking_locked", SNSL_JMap.getInt(obj, "speaking_locked"))
            StorageUtil.SetIntValue(a, persist_prefix+"dressed_locked", SNSL_JMap.getInt(obj, "dressed_locked"))
            StorageUtil.SetStringValue(a, persist_prefix+"speaking", SpeakingCsvFromIndex(i))
        endif
        i += 1
    endwhile
EndFunction

; Restores akActor's persisted settings into position_objs[i] if they belong to this thread.
Function RestorePosition(int i, Actor akActor)
    if thread == None || akActor == None || StorageUtil.GetIntValue(akActor, persist_prefix+"tid", -1) != thread.tid
        return
    endif
    int obj = position_objs[i]
    SNSL_JMap.setInt(obj, "no_orgasm", StorageUtil.GetIntValue(akActor, persist_prefix+"no_orgasm", 0))
    SNSL_JMap.setInt(obj, "deny_orgasm", StorageUtil.GetIntValue(akActor, persist_prefix+"deny_orgasm", 0))
    SNSL_JMap.setInt(obj, "dressed", StorageUtil.GetIntValue(akActor, persist_prefix+"dressed", 0))
    SNSL_JMap.setInt(obj, "orgasm_locked", StorageUtil.GetIntValue(akActor, persist_prefix+"orgasm_locked", 0))
    SNSL_JMap.setInt(obj, "speaking_locked", StorageUtil.GetIntValue(akActor, persist_prefix+"speaking_locked", 0))
    SNSL_JMap.setInt(obj, "dressed_locked", StorageUtil.GetIntValue(akActor, persist_prefix+"dressed_locked", 0))
    SetSpeakingObj(i, StorageUtil.GetStringValue(akActor, persist_prefix+"speaking", ""))
    Trace("RestorePosition", GetDisplayName(akActor)+" index:"+i+" no_orgasm:"+SNSL_JMap.getInt(obj, "no_orgasm")+" dressed:"+SNSL_JMap.getInt(obj, "dressed"))
EndFunction

Function ClearPersistedPosition(Actor akActor)
    StorageUtil.UnsetIntValue(akActor, persist_prefix+"tid")
    StorageUtil.UnsetIntValue(akActor, persist_prefix+"no_orgasm")
    StorageUtil.UnsetIntValue(akActor, persist_prefix+"deny_orgasm")
    StorageUtil.UnsetIntValue(akActor, persist_prefix+"dressed")
    StorageUtil.UnsetIntValue(akActor, persist_prefix+"orgasm_locked")
    StorageUtil.UnsetIntValue(akActor, persist_prefix+"speaking_locked")
    StorageUtil.UnsetIntValue(akActor, persist_prefix+"dressed_locked")
    StorageUtil.UnsetStringValue(akActor, persist_prefix+"speaking")
EndFunction

; ----------------------------------------
; actor_objs Functions 
;
; -----------------------------------------

Function SetPosition(int index, Actor akActor, int no_orgasm, String speaking_modifiers) 
    DbgEnter("SetPosition", "start index:"+index+" akActor:"+GetDisplayName(akActor)+" no_orgasm:"+no_orgasm+" speaking_modifiers:"+speaking_modifiers)
    EnsureActorArraysLargeEnough(index + 1)

    int obj = position_objs[index]
    SNSL_JMap.setInt(obj, "no_orgasm", no_orgasm)
    int speaking_obj = SetSpeakingObj(index, speaking_modifiers)
    SetActor(index, akActor)
    Trace("SetPosition", "end index:"+index+" name: "+akActor.GetDisplayName()+" no_orgasm: "+SNSL_JMap.getInt(obj, "no_orgasm")+" speaking_modifiers: "+JoinJArrayStrToJson(speaking_obj))
Endfunction

; Writes the CSV tokens into position_objs[index].speaking_modifiers; returns the JArray.
int Function SetSpeakingObj(int index, String speaking_modifiers)
    int obj = position_objs[index]
    ; Split up speaking modifiers
    String[] strings = StringUtil.Split(speaking_modifiers,",")
    int count = strings.length
    int num_strings = 0
    int i = 0
    while i < count
        if strings[i] != ""
            num_strings += 1
        endif
        i += 1
    endwhile

    int speaking_obj = SNSL_JMap.getObj(obj, "speaking_modifiers")
    if speaking_obj < 1 || SNSL_JArray.count(speaking_obj) != num_strings
        if speaking_obj > 0
            SNSL_JValue.release(speaking_obj)
        endif
        speaking_obj = SNSL_JArray.objectWithSize(num_strings)
        ; Attach BEFORE retain: a freshly-created, unretained array is attached by reference
        ; (fast path). Retaining first would make MapSetObj see it as "unowned but explicitly
        ; retained" and deep-copy it on attach instead -- the string writes below would then land
        ; on the orphaned original, leaving the copy actually embedded in `obj` permanently empty.
        ; This is exactly what silently dropped Scene Creator's speaking modifiers before the
        ; Description Editor ever saw them. See KNOWLEDGEBASE "JSON store handles die on every
        ; save load" for the related class of store-migration bug.
        SNSL_JMap.setObj(obj, "speaking_modifiers",speaking_obj)
        SNSL_JValue.retain(speaking_obj)
    endif
    i = 0
    int w = 0
    while i < count
        if strings[i] != ""
            SNSL_JArray.setStr(speaking_obj, w, strings[i])
            w += 1
        endif
        i += 1
    endwhile
    return speaking_obj
EndFunction

; Push the animation's speaking (as shown in the Description Editor, stage-aware) into the
; live overlay. Positions with a live edit (speaking_locked) are left alone.
Function ApplyAnimDbSpeaking()
    if thread == None || thread.animation == None || !position_objs
        return
    endif
    String[] speaking = animdb.GetSpeakingModifiers(thread)
    int i = 0
    while i < speaking.length && i < position_objs.length
        if position_objs[i] > 0 && SNSL_JMap.getInt(position_objs[i], "speaking_locked", 0) != 1
            SetSpeakingObj(i, speaking[i])
        endif
        i += 1
    endwhile
EndFunction

String Function SpeakingCsvFromIndex(int i)
    String speaking = ""
    if !position_objs || i < 0 || i >= position_objs.length || position_objs[i] < 1
        return speaking
    endif
    int speaking_obj = SNSL_JMap.getObj(position_objs[i], "speaking_modifiers")
    if speaking_obj < 1
        return speaking
    endif
    int sc = SNSL_JArray.count(speaking_obj)
    int si = 0
    while si < sc
        String tok = SNSL_JArray.getStr(speaking_obj, si, "")
        if tok != ""
            if speaking != ""
                speaking += ","
            endif
            speaking += tok
        endif
        si += 1
    endwhile
    return speaking
EndFunction

; SexLab moans only for _pleasure_ / _pain_; every other speaking state (empty, _gagged_,
; _kissing_) is ForceSilent. Call after the speaking overlay is written.
Function ApplySexLabVoice(int i)
    if main == None || !main.voice_follows_speaking || thread == None
        return
    endif
    Actor[] positions = thread.positions
    if !positions || i < 0 || i >= positions.length || positions[i] == None
        return
    endif
    Actor a = positions[i]
    String csv = SpeakingCsvFromIndex(i)
    bool voiced = StringUtil.Find(csv, "_pleasure_") >= 0 || StringUtil.Find(csv, "_pain_") >= 0
    sslBaseVoice v = thread.GetVoice(a)
    ; Silenced before SexLab picked a voice leaves Voice none; pick one when un-silencing.
    if voiced && v == None && sexlab != None
        v = sexlab.PickVoice(a)
    endif
    thread.SetVoice(a, v, !voiced)
    Trace("ApplySexLabVoice", GetDisplayName(a)+" speaking:"+csv+" voiced:"+voiced)
EndFunction

Function ApplySexLabVoices()
    if thread == None
        return
    endif
    int n = thread.positions.length
    int i = 0
    while i < n
        ApplySexLabVoice(i)
        i += 1
    endwhile
EndFunction

bool Function SetActor(int i, Actor akActor)
    DbgEnter("SetActor", "i:"+i+" "+GetDisplayName(akActor))
    if i < 0
        DbgReturn("SetActor", "False")
        return False
    endif
    if akActor == None 
        DbgReturn("SetActor", "False")
        return False 
    endif
    int obj = position_objs[i]
    ; actors_objs is refreshed by RelinkActorsObjs (AlignActors / GetThreadObj), not here.

    StorageUtil.SetIntValue(akActor, storage_obj_key, obj)
    StorageUtil.SetIntValue(akActor, storage_total_orgasms_key, 0)
    SNSL_JMap.setStr(obj, "uuid", GetUUID(akActor))
    SNSL_JMap.setStr(obj, "formid", akActor.GetFormID())
    SNSL_JMap.setStr(obj, "name", akActor.GetDisplayName())

    int gender = akActor.GetLeveledActorBase().GetSex() ; actorLib.GetGender(akActor)
    DbgMsg("SetActor", "sexlab.GetGender "+akActor.GetDisplayName())
    int gender_sexlab = main.sexlab.GetGender(akActor) 
    DbgMsg("SetActor", "sexlab.GetGender returned "+gender_sexlab)
    int has_penis = 0
    if gender != 1 || (gender_sexlab != 1 && gender_sexlab != 3)
        has_penis = 1
    endif
    int has_pussy = 0
    if gender == 1 || gender_sexlab == 1 || gender_sexlab == 3
        has_pussy = 1
    endif

    int is_hermaphrodiate = 0
    if actorLib.GetTrans(akActor) == 0 
        is_hermaphrodiate = 1
    endif 


    SNSL_JMap.setInt(obj, "has_penis", has_penis)
    SNSL_JMap.setInt(obj, "has_pussy", has_pussy)
    SNSL_JMap.setInt(obj, "is_hermaphrodiate", is_hermaphrodiate)
    SNSL_JMap.setStr(obj, "creature_description", GetCreatureDescriptions(akActor))

    SNSL_JMap.setStr(obj,"notice_level","nothing")
    if status == STATUS_ACTIVE
        SNSL_JMap.setStr(obj,"notice_level","active")
    endif
    SNSL_JMap.setInt(obj,"total_orgasm",0)
    SNSL_JMap.setInt(obj,"orgasm_narrated",0)
    SNSL_JMap.setInt(obj,"arousal", -1)
    DbgMsg("SetActor", "thread.IsVictim "+akActor.GetDisplayName())
    if thread.IsVictim(akActor)
        SNSL_JMap.setInt(obj, "victim", 1)
        SNSL_JMap.setInt(obj, "assailant", 0)
    elseif num_victims > 0
        SNSL_JMap.setInt(obj, "victim", 0)
        SNSL_JMap.setInt(obj, "assailant", 1)
    else
        SNSL_JMap.setInt(obj, "victim", 0)
        SNSL_JMap.setInt(obj, "assailant", 0)
    endif

    DbgMsg("SetActor", "thread.ActorAlias "+akActor.GetDisplayName())
    int enjoyment = 0
    if status == STATUS_ACTIVE
        sslActorAlias actorAlias = thread.ActorAlias(akActor) 
        ;if Game.GetModByName("SLSO.esp") != 255
            ;enjoyment = actorAlias.Getfull_enjoyment() 
        ;else 
        ;    int enjoyment = actorAlias.GetEnjoyment() 
        ;endif 

        if actorAlias != None
            enjoyment = actorAlias.GetEnjoyment() 
        endif 
    endif 
    SNSL_JMap.setInt(obj, "enjoyment", enjoyment)

    if main.handler_dom.IsDOMSlave(akActor)
        SNSL_JMap.setInt(obj, "dom_slave", 1)
    else
        SNSL_JMap.setInt(obj, "dom_slave", 0)
    endif


    DbgReturn("SetActor", "True")
    return True
EndFunction

String Function GetUUID(Actor akActor)
    if akActor == None
        return ""
    endif
    return UuidToDecimalString(SkyrimNetApi.GetEntityUUID(akActor))
EndFunction

int Function GetObjFromActor(Actor akActor) 
    DbgEnter("GetObjFromActor", "akActor:"+GetDisplayName(akActor))
    int obj = StorageUtil.GetIntValue(akActor, storage_obj_key, 0)
    ; StorageUtil survives a save load but SNSL handles do not: a dead handle here would make
    ; callers read no_orgasm etc. as 0. Fall back to the actor's live position slot.
    if obj > 0 && !SNSL_JValue.isExists(obj)
        obj = 0
        if thread != None && position_objs
            int i = thread.positions.Find(akActor)
            if i >= 0 && i < position_objs.length && SNSL_JValue.isExists(position_objs[i])
                obj = position_objs[i]
            endif
        endif
    endif
    DbgReturn("GetObjFromActor", obj)
    return obj
EndFunction

bool Function UpdateActor(int i , Actor akActor) 
    DbgEnter("UpdateActor", "i:"+i+" akActor:"+GetDisplayName(akActor))
    bool changed = False 
    int obj = position_objs[i]
    ; Slot changed if this actor is not bound to this position's metadata obj
    ; Raw StorageUtil value, not GetObjFromActor: its dead-handle fallback would hide a stale
    ; binding that must still count as a mismatch so SetActor re-derives this slot.
    if StorageUtil.GetIntValue(akActor, storage_obj_key, 0) != position_objs[i]
        SetActor(i, akActor)
        changed = True
        int total_orgasms = StorageUtil.GetIntValue(akActor, storage_total_orgasms_key, 0) 
        SetTotalOrgasms(akActor, total_orgasms)
        obj = position_objs[i]
    elseif status == STATUS_ACTIVE && obj > 0
        SNSL_JMap.setStr(obj, "notice_level", "active")
    endif
    int wearing_strapon = 0
    if thread.IsUsingStrapon(akActor)
        wearing_strapon = 1
    endif
    if obj > 0
        SNSL_JMap.setInt(obj, "wearing_strapon", wearing_strapon)
    endif

    DbgReturn("UpdateActor", "changed")
    return changed 
EndFunction 

Function AlignActors() 
    DbgEnter("AlignActors")
    DbgMsg("AlignActors", "thread.positions.length")
    int size = thread.positions.length 
    EnsureActorArraysLargeEnough(size) 
    int i = 0 
    bool changed = False 
    if size != SNSL_JArray.count(actors_objs)
        ResetActorsObjs(size)
        changed = True
    endif
    while i < size
        if UpdateActor(i, thread.positions[i])
            changed = True
        endif
        i += 1
    endwhile
    RelinkActorsObjs(size)
    ; Do not tear down leftover slots here — only Release owns teardown.

    ; Positions may have changed; reconcile victim faction so departed actors are cleared.
    ReconcileVictimFactions()

    if changed 
        SetNames()
    endif 
    DbgEnd("AlignActors")
EndFunction 

; ------------------------------------
; Get Names 
; ------------------------------------

Function SetNames() 
    DbgEnter("SetNames")
    DbgMsg("SetNames", "thread.positions")
    actor_names = JoinActors(thread.positions)
    victim_names = GetNames("victim")
    assailant_names = GetNames("assailant")
    hermaphrodiate_names = GetNames("is_hermaphrodiate") 
    strapon_names = GetNames("wearing_strapon")
    DbgEnd("SetNames")
EndFunction 

String Function GetNames(String key_) 
    DbgEnter("GetNames", "key_:"+key_)
    String names = ""
    int matched = 0
    int i = 0 
    int num_actors = thread.positions.length
    while i < num_actors
        if SNSL_JMap.getInt(position_objs[i], key_, 0) == 1
            matched += 1
        endif
        i += 1
    endwhile

    i = 0
    int seen = 0
    while i < num_actors
        if SNSL_JMap.getInt(position_objs[i], key_, 0) == 1
            if seen > 0
                if seen + 1 == matched
                    names += " and "
                else
                    names += ", "
                endif
            endif
            names += SNSL_JMap.getStr(position_objs[i], "name")
            seen += 1
        endif 
        i += 1 
    endwhile 
    DbgReturn("GetNames", "names")
    return names 
EndFunction

String Function GetCreatureDescriptions(Actor akActor) 
    DbgEnter("GetCreatureDescriptions", "akActor:"+GetDisplayName(akActor))
    String desc = "" 
    Race r = akActor.GetRace() 
    if sslCreatureAnimationSlots.HasRaceType(r) 
        String name = akActor.GetDisplayName()
        String race_name = r.GetName() 
        desc += name+" is a "+race_name+". "
        int j = JArray.count(main.race_to_description) - 1 
        while 0 <= j 
            int creature = Jarray.getObj(main.race_to_description, j) 
            Race creature_race = JMap.getForm(creature,"form_") as Race 
            if creature_race == r 
                desc += JMap.getStr(creature, "description_")
                j = -1 
            else 
                j -= 1 
            endif 
        endwhile 
    endif 
    DbgReturn("GetCreatureDescriptions", "desc:"+desc)
    return desc 
EndFunction

; --------------------------------------------
; Get Functions 
; --------------------------------------------

int Function GetTotalOrgasms(Actor akActor)
    DbgEnter("GetTotalOrgasms", "akActor:"+GetDisplayName(akActor))
    DbgReturn("GetTotalOrgasms", "StorageUtil.GetIntValue(akActor, storage_total_orgasms_key, 0)")
    return StorageUtil.GetIntValue(akActor, storage_total_orgasms_key, 0) 
EndFunction 

Function SetTotalOrgasms(Actor akActor, int total_orgasms)
    DbgEnter("SetTotalOrgasms", "akActor:"+GetDisplayName(akActor)+" total_orgasms:"+total_orgasms)
    if akActor == None 
        Trace("SetTotalOrgasms","akActor is None")
        DbgReturn("SetTotalOrgasms", "void")
        return 
    endif 
    StorageUtil.SetIntValue(akActor, storage_total_orgasms_key, total_orgasms) 
    int obj = GetObjFromActor(akActor)
    if obj > 0
        SNSL_JMap.setInt(obj, "total_orgasm", total_orgasms)
    endif
    DbgEnd("SetTotalOrgasms")
EndFunction 

; Builds the prompt-gate clause and updates the actor's orgasm total.
; total_orgasms < 0: +1 from current. total_orgasms >= 0: set absolute (SLSO).
; Tentacles tag: append flavor on the orgasming actor only (do not force-orgasm all positions).
String Function GetIsOrgasming(Actor akActor, int total_orgasms = -1)
    DbgEnter("GetIsOrgasming", "akActor:"+GetDisplayName(akActor)+" total_orgasms:"+total_orgasms)
    if akActor == None
        Trace("GetIsOrgasming", "Is None")
        return ""
    endif
    if total_orgasms < 0
        SetTotalOrgasms(akActor, GetTotalOrgasms(akActor) + 1)
    else
        SetTotalOrgasms(akActor, total_orgasms)
    endif
    int recorded = GetTotalOrgasms(akActor)
    DbgMsg("GetIsOrgasming", GetDisplayName(akActor)+" total_orgasms:"+recorded) ; debug-total_orgasms
    String name = akActor.GetDisplayName()
    String msg = name+" is orgasming. "
    if recorded > 1
        msg = name+" is orgasming. again. "
    endif
    if thread != None && thread.Animation != None && thread.Animation.HasTag("tentacles")
        msg += "The tentacles is orgasming and flooding cum both inside and outside. "
    endif
    DbgReturn("GetIsOrgasming", msg)
    return msg
EndFunction

Function SetThread(sslThreadController _thread) 
    if _thread != None
        DbgEnter("SetThread", "tid:"+_thread.tid)
    else
        DbgEnter("SetThread")
    endif
    thread = _thread
    DbgEnd("SetThread")
EndFunction 
sslThreadController Function GetThread()
    DbgEnter("GetThread")
    if thread == None 
        Trace("GetThread","Thread is None | "+GetString())
    endif 
    DbgReturn("GetThread", "thread")
    return thread
EndFunction

; Prefer Initialize(..., _is_generic=true). This only sets true; never clear is_generic.
Function SetGeneric() 
    is_generic = True 
EndFunction 
bool Function IsGeneric() 
    DbgReturn("IsGeneric", "is_generic")
    return is_generic
EndFunction 

; --------------------------------------------
; Get a Status message for the sl_scene (start, are, finish) 
; --------------------------------------------
String Function GetIntentMessage(int intent_stage = -1) 
    DbgEnter("GetIntentMessage", "intent_stage:"+intent_stage)
    String verb = "are"
    if intent_stage == INTENT_STAGE_START 
        verb = "start"
    elseif intent_stage == INTENT_STAGE_END 
        verb = "finish"
    endif
    ; DOM / empty-intent creators must not emit "Nina and Bob finish ."
    String fallback = ""
    if num_victims > 0
        if intent != ""
            fallback = assailant_names+" "+verb+" "+intent+" "+victim_names+"."
        else
            fallback = assailant_names+" "+verb+" "+victim_names+"."
        endif
        DbgReturn("GetIntentMessage", "with victims")
    else
        if intent != ""
            fallback = actor_names+" "+verb+" "+intent+"."
        else
            fallback = actor_names+" "+verb+"."
        endif
        DbgReturn("GetIntentMessage", "actors only")
    endif
    return fallback
EndFunction 
    
bool Function GetThreadActive() 
    DbgEnter("GetThreadActive")
    if thread == None 
        DbgReturn("GetThreadActive", "false")
        return false 
    endif 
    DbgMsg("GetThreadActive", "thread.GetState()")
    String s = (thread as sslThreadModel).GetState() 
    DbgMsg("GetThreadActive", "thread.GetState() returned "+s)
    if s != "animating" && s != "prepare"
        Trace("GetThreadActive", "thread is not animating or prepare `"+s+"'")
        DbgReturn("GetThreadActive", "false")
        return false 
    endif 
    ; Ghost / stuck slot: state still animating but no actors left
    if !thread.Positions || thread.Positions.length == 0
        Trace("GetThreadActive", "thread has no positions")
        DbgReturn("GetThreadActive", "false")
        return false
    endif
    DbgReturn("GetThreadActive", "true")
    return true 
EndFunction

; --------------------------------------------
; Animation Event Handlers 
; --------------------------------------------
Function AnimationStart()
    description_last = ""
    stage_last = 0
    pending_animation_change = false
    animation_change_from = ""
    ; Re-entrant mid-scene AnimationStart must not force STATUS_SETUP (would re-run
    ; first-start/initiator path) or clear orgasm_messages_set while leaving non-empty
    ; slots (flush skips; Combined will not refill). Only reset orgasm stash on first start.
    ; A melt that landed between AnimationEnd and this start must still DN — flush first.
    if status != STATUS_ACTIVE
        status = STATUS_SETUP
        if animating_started_at <= 0.0
            animating_started_at = Utility.GetCurrentRealTime()
        endif
        if orgasm_messages_set
            Trace("AnimationStart", "--- flushing pending orgasm stash before reset")
            FlushOrgasmWindow()
        else
            if orgasm_messages
                int m = 0
                while m < orgasm_messages.length
                    orgasm_messages[m] = ""
                    m += 1
                endwhile
            endif
            orgasm_messages_set = false
            orgasm_window_open = false
            orgasm_window_started_at = 0.0
            UnregisterForUpdate()
        endif
    endif
    DbgEnter("AnimationStart")
    if thread == None
        Trace("AnimationStart","thread is None | actors:"+actor_names)
        DbgReturn("AnimationStart", "void")
        return
    endif
    AlignActors() 
    manager.SaveThreadsJson() 
    String msg = GetIntentMessage(INTENT_STAGE_START) + GetDescription()
    RegisterEvent("sexlab update", msg, sender, receiver) 
    WebUI_ConfigureIfOverlayVisible()
    DbgEnd("AnimationStart", "msg:"+msg+" sender:"+GetDisplayName(sender)+" receiver:"+GetDisplayName(receiver))
EndFunction

Function StageStart()
    DbgEnter("StageStart")
    AlignActors()
    ; Catches animation changes not yet seen elsewhere; narrated below like a stage change.
    String from_desc = description_last
    if SyncAnimationDefaults()
        pending_animation_change = true
        animation_change_from = from_desc
    endif
    ApplyAnimDbSpeaking()
    ApplySexLabVoices()
    manager.SaveThreadsJson()
    if SexLab == None
        Trace("StageStart","sexlab is None | actors:"+actor_names)
        DbgReturn("StageStart", "void")
        return 
    endif
    if thread == None 
        Trace("StageStart","thread is None | actors:"+actor_names)
        DbgReturn("StageStart", "void")
        return
    endif
    ; thread.stage is the truth (also covers the game advancing on its own): tell the editor before the slow narration work.
    WebUI_PushStage(true)
    if IsSexLabPPlus() && animating_started_at > 0.0
        float elapsed = Utility.GetCurrentRealTime() - animating_started_at
        if elapsed >= DURATION_CAP_SECONDS
            Trace("StageStart", "P+/duration cap ending thread elapsed:"+elapsed)
            thread.EndAnimation()
            DbgReturn("StageStart", "duration cap")
            return
        endif
    endif

    String orgasm_narration = ""
    if orgasm_window_open && orgasm_messages_set
        Trace("StageStart", "--- holding orgasm stash for DOM window")
    else
        orgasm_narration = OrgasmMessagesToNarration()
    endif
    String desc = GetDescription()
    int cur_stage = thread.stage

    ; Send a DN if its a start and includes a player
    ; if not player send DN if allowed by cool off 
    ; GetDescription: stage JSON, else tag fallback (raw GetStageDescription alone leaves initiates: empty)
    if status != STATUS_ACTIVE
        status = STATUS_ACTIVE
        if orgasm_window_open && orgasm_messages_set
            RegisterEvent("sexlab update", desc, sender, receiver)
        else
            String narration = desc + orgasm_narration
            if initiator != None
                narration = initiator.GetDisplayName()+" initiates: "+desc
                narration += orgasm_narration
            endif
            if orgasm_narration != ""
                ; Do not RegisterEvent the orgasm sentence — CheckDuplicate would blank the DN below.
                if desc != ""
                    RegisterEvent("sexlab update", desc, sender, receiver)
                endif
            else 
                if has_player
                    DirectNarration(narration, sender, receiver) 
                else
                    DirectNarration_Optional("start", narration, sender, receiver) 
                endif
            endif
        endif
    ; Late Dom custom msgs may arrive after Combined; flush any leftovers before send/Release
    else
        String narration = ""
        bool change_scene = false
        if pending_animation_change && desc != ""
            ; Animation switched (any route): narrate old animation's stage -> new animation's stage.
            ; No anidata transition lookup: those are per-animation stage pairs.
            if animation_change_from != "" && animation_change_from != desc
                narration = "Scene changes from "+animation_change_from+" to "+desc
            else
                narration = "Scene changes to "+desc
            endif
            change_scene = true
        elseif desc != "" && description_last != ""
            if desc != description_last
                ; Prefer anidata transitions["from-to"]; else constructed "Scene changes to".
                String transition = ""
                if stage_last > 0 && cur_stage > 0
                    int delta = cur_stage - stage_last
                    if delta == 1 || delta == -1
                        transition = animdb.GetThreadTransition(thread, stage_last, cur_stage)
                    endif
                endif
                if transition != ""
                    narration = transition
                else
                    narration = "Scene changes to "+desc
                endif
                change_scene = true
            else 
                desc = ""
            endif 
        endif 
        if orgasm_window_open && orgasm_messages_set
            if change_scene
                RegisterEventForce("change", narration, sender, receiver)
            endif
        elseif orgasm_narration != ""
            if change_scene
                RegisterEventForce("change", narration, sender, receiver)
            endif
        else
            if !change_scene
                ContinueActivity(sender, receiver, True)
            else
                ; A scene change must always yield a DN or an event (dedupe may drop the DN)
                if !DirectNarration_optional("ChangePosition", narration, sender, receiver)
                    RegisterEventForce("change", narration, sender, receiver)
                endif
            endif
        endif 
    endif 

    if orgasm_narration != ""
        float delay = 5.0
        if main
            delay = main.orgasm_delay
        endif
        thread.UpdateTimer(delay)
        if has_player
            DirectNarration(orgasm_narration, sender, receiver, purge_dialogue=True)
        else
            DirectNarration_optional("orgasm", orgasm_narration, sender, receiver)
        endif 
    endif 
    ; Only advance description_last when desc is a real new description; unchanged
    ; path sets desc="" and must not wipe the prior value (would skip later Scene changes to).
    if desc != ""
        description_last = desc
    endif
    if cur_stage > 0
        stage_last = cur_stage
    endif
    pending_animation_change = false
    animation_change_from = ""

    ; If this thread is being tracked print the thread's status
    if tracking
        bool[] desc_orgasm = animdb.GetHasDescriptionOrgasmExpected(thread)
        String msg = "" 
        if desc_orgasm[0]
            msg = "has description"
        endif
        if desc_orgasm[1]
            if msg != ""
                msg += " and "
            endif 
            msg += "orgasm expected"        
        endif
        Debug.Notification("stage "+thread.stage+" of "+ thread.animation.StageCount()+" "+msg)
    endif  
    WebUI_ConfigureIfOverlayVisible()
    DbgEnd("StageStart")
EndFunction

Function AnimationEnd(Actor speaker=None, String style="silently") 
    DbgEnter("AnimationEnd", "speaker:"+GetDisplayName(speaker)+" style:"+style)
    AlignActors() 
    manager.SaveThreadsJson()

    if SexLab != None && thread != None 
        Trace("AnimationEnd","thread id:"+thread.tid+" status:"+thread.GetState())
        DbgMsg("AnimationEnd", "thread.GetState()="+thread.GetState())
        DbgMsg("AnimationEnd", "SexLab as sslSystemConfig")
        sslSystemConfig config = (SexLab as Quest) as sslSystemConfig

        UnregisterForUpdate()
        orgasm_window_open = false
        orgasm_window_started_at = 0.0

        ; Leftover Combined orgasm stash folded into the end DN so 0550 still gates
        ; (RegisterEvent-only leftover is invisible to contains(_direct_narration, ...)).
        String orgasm_narration = OrgasmMessagesToNarration()

        ; Post-activity afterglow (SeparateOrgasms); not ongoing sexual activity
        String afterglow = ""
        if config.SeparateOrgasms
            int[] orgasm_expected = animdb.GetOrgasmExpected(thread)
            int j = thread.positions.length - 1 
            while 0 <= j 
                String name = SNSL_JMap.getStr(position_objs[j], "name")
                int total_orgasms = SNSL_JMap.getInt(position_objs[j], "total_orgasm")
                int expected = 0
                if orgasm_expected.length > j && orgasm_expected[j] == 1
                    expected = 1
                endif
                String glow_fallback = ""
                if total_orgasms < 1
                    if expected == 1
                        glow_fallback = name+" failed to orgasm. "
                    endif
                elseif total_orgasms >= 1
                    glow_fallback = name+"'s body is recovering from "+total_orgasms+" orgasms. "
                endif
                if glow_fallback != "" || total_orgasms >= 1
                    int glow_obj = JMap.object()
                    JMap.setStr(glow_obj, "name", name)
                    JMap.setInt(glow_obj, "total_orgasms", total_orgasms)
                    JMap.setInt(glow_obj, "expected", expected)
                    afterglow += RenderSlPrompt("helpers/sexlab/afterglow", glow_obj, glow_fallback)
                endif
                j -= 1 
            endwhile
        endif 

        ; Mirror AnimationStart: "A and B finish <intent>."
        ; style: silently|silent → no DirectNarration; explain:<text> → custom end text; else default end_message.
        String end_message = GetIntentMessage(INTENT_STAGE_END)
        if orgasm_narration != ""
            end_message = orgasm_narration + " " + end_message
        endif
        if afterglow != ""
            end_message += " "+afterglow
        endif
        Bool skip_narration = (style == "silently" || style == "silent")
        if StringUtil.GetLength(style) > 8 && StringUtil.Substring(style, 0, 8) == "explain:"
            end_message = StringUtil.Substring(style, 8, StringUtil.GetLength(style) - 8)
            skip_narration = False
        endif
        int d = 0
        while d < thread.positions.length
            String dbg_name = SNSL_JMap.getStr(position_objs[d], "name")
            int dbg_total = SNSL_JMap.getInt(position_objs[d], "total_orgasm")
            DbgMsg("AnimationEnd", dbg_name+" total_orgasms:"+dbg_total) ; debug-total_orgasms
            d += 1
        endwhile
        DbgMsg("AnimationEnd", "end_message:"+end_message+" skip_narration:"+skip_narration) ; debug-total_orgasms
        if !skip_narration
            if has_player
                DirectNarration(end_message, sender, receiver, purge_dialogue=True)
            else
                DirectNarration_optional("end", end_message, sender, receiver)
            endif
        endif 
    endif

    ; Keep the scene visible to the Description Editor after the thread is gone (snapshot before Release clears position_objs).
    ; ended_obj is an SNSL_JValue handle (BuildWebUISceneMenuObject's own store).
    if thread != None && manager != None
        int ended_obj = BuildWebUISceneMenuObject()
        if ended_obj > 0
            SNSL_JMap.setStr(ended_obj, "_mode", "ended")
            manager.SetLastEndedScene(ended_obj)
        endif
    endif

    Release()
    DbgEnd("AnimationEnd")
EndFunction 

; --------------------------------------------
; Orgasm Handlers
; --------------------------------------------

; --------------------------------------------
; Captures the orgasm message sent just before the last stage 
; We have a race condition where other HookOrgasmStart listeners 
; may send their messages before we get ours.
; We will there for store all the orgasm messages 
; and send them at the start of the next stage. 
; When a DOM slave is in the thread, do not flush on StageStart and do not
; use thread.UpdateTimer as the clock (P+ _ForceAdvance hops). Arm a Scene
; OnUpdate window so a last-stage melt can join the player in one DN.
; --------------------------------------------
Function OrgasmCombined()
    DbgEnter("OrgasmCombined")
    AlignActors() 
    int[] orgasm_expected = animdb.GetOrgasmExpected(thread)
    int i = 0
    int num_actors = thread.positions.length
    EnsureActorArraysLargeEnough(num_actors)
    bool has_dom_slave = ThreadHasDomSlave()
    while i < num_actors
        int obj = position_objs[i]
        bool no_orgasm = SNSL_JMap.getInt(obj, "no_orgasm") == 1
        bool is_dom_slave = SNSL_JMap.getInt(obj,"dom_slave") == 1

        if orgasm_expected[i] == 1 && !no_orgasm && !is_dom_slave && orgasm_messages[i] == ""
            orgasm_messages_set = true
            orgasm_messages[i] = GetIsOrgasming(thread.positions[i])
        endif 
        i += 1
    endwhile
    if orgasm_messages_set
        if has_dom_slave
            Trace("OrgasmCombined", "--- DOM window, skip UpdateTimer")
            ArmOrgasmWindow()
        elseif thread != None
            thread.UpdateTimer(4.0)
        endif
    endif

    DbgEnd("OrgasmCombined")
EndFunction

; Used for SLSO.esp orgasm handling (invoked from Manager as a Function call)
Function OrgasmIndividual(Actor akActor, int full_enjoyment, int num_orgasms)
    DbgEnter("OrgasmIndividual", "akActor:"+GetDisplayName(akActor)+" full_enjoyment:"+full_enjoyment+" num_orgasms:"+num_orgasms)
    if akActor == None 
        Trace("OrgasmIndividual","akActor is None") 
        DbgReturn("OrgasmIndividual", "void")
        return 
    endif 

    String name = GetDisplayName(akActor) 
    int obj = GetObjFromActor(akActor)
    if obj > 0
        if SNSL_JMap.getInt(obj, "no_orgasm") == 1
            Trace("OrgasmIndividual",name+" shouldn't orgasm")
            DbgReturn("OrgasmIndividual", "void")
            return
        endif
        SNSL_JMap.setInt(obj, "enjoyment", full_enjoyment)
    endif

    ; Prompt gate + total via GetIsOrgasming (SLSO absolute count).
    String msg = GetIsOrgasming(akActor, num_orgasms)

    int num_actors = thread.positions.length
    int i = 0
    while i < num_actors
        if thread.positions[i] != akActor
            msg += " "+thread.positions[i].GetDisplayName()+" is not orgasming right now. "
        endif 
        i += 1 
    endwhile 
    OrgasmHelper(akActor, msg)
    DbgEnd("OrgasmIndividual")
EndFunction

Function OrgasmCustom(Actor akActor, String msg)
    DbgEnter("OrgasmCustom", "akActor:"+GetDisplayName(akActor)+" msg:"+msg)
    sslSystemConfig config = (SexLab as Quest) as sslSystemConfig

    ; DOM rolls its own orgasm and ignores SexLab DisableOrgasm; honor orgasm_expected (no_orgasm = 1 - expected).
    int obj = GetObjFromActor(akActor)
    if obj > 0 && SNSL_JMap.getInt(obj, "no_orgasm") == 1
        Trace("OrgasmCustom", "--- "+GetDisplayName(akActor)+" shouldn't orgasm, dropping")
        DbgEnd("OrgasmCustom")
        return
    endif

    if StringUtil.Find(msg, " is orgasming.") < 0
        msg += GetIsOrgasming(akActor)
    else
        ; Manager/DOM already appended the substring; still count this orgasm.
        GetIsOrgasming(akActor)
    endif

    if config.SeparateOrgasms
        Trace("OrgasmCustom", "--- SeparateOrgasms OrgasmHelper "+GetDisplayName(akActor))
        OrgasmHelper(akActor, msg)
    else 
        if thread == None
            Trace("OrgasmCustom", "--- thread is None, aborting")
            DbgEnd("OrgasmCustom")
            return
        endif
        EnsureActorArraysLargeEnough(thread.positions.length)
        int i = 0 
        while i < thread.positions.length && thread.positions[i] != akActor
            i += 1
        endwhile
        if i < thread.positions.length
            orgasm_messages_set = true
            orgasm_messages[i] = msg
            Trace("OrgasmCustom", "--- Combined stash "+GetDisplayName(akActor)+" slot:"+i)
            ArmOrgasmWindow()
        else
            Trace("OrgasmCustom", "--- actor not in thread.positions, stash skipped "+GetDisplayName(akActor))
        endif
    endif
    DbgEnd("OrgasmCustom")
EndFunction

Function OrgasmHelper(Actor akActor, String msg)
    DbgEnter("OrgasmHelper", "akActor:"+GetDisplayName(akActor)+" msg:"+msg)
    AlignActors()
    Actor cum_catcher = None
    String cum_catcher_name = "(None)"

    int gender = sexlab.GetGender(akActor) 
    DbgMsg("OrgasmHelper", "sexlab.GetGender returned "+gender)
    bool has_penis = gender == 0 || gender == 2
    if has_penis 
        ; Generate the orgasm message
        int i = 0
        int num_actors = thread.positions.length
        while i < num_actors
            if thread.positions[i] != akActor && cum_catcher == None
                cum_catcher = thread.positions[i]
                cum_catcher_name = cum_catcher.GetDisplayName()
                msg += AddCum(i, cum_catcher, cum_catcher_name)
            endif 
            i += 1 
        endwhile 
    endif 

    Trace("OrgasmHelper"," has_penis:"+has_penis+" cum_catcher:"+cum_catcher_name+" msg:"+msg)
    if has_player 
        DirectNarration(msg, akActor, cum_catcher, purge_dialogue=true)
    else 
        DirectNarration_Optional("orgasm", msg, akActor, cum_catcher) 
    endif 
    DbgEnd("OrgasmHelper")
EndFunction

String Function OrgasmMessagesToNarration()
    String narration = ""
    bool orgasm_happened = false
    bool ejaculation_happened = false
    int num_actors = thread.positions.length
    if orgasm_messages_set
        orgasm_messages_set = false
        int k = 0
        int[] orgasm_expected = animdb.GetOrgasmExpected(thread)
        while k < num_actors && k < orgasm_messages.length
            ; position_objs, not actors_objs: actors_objs holds snapshots, so MarkOrgasmNarrated's
            ; orgasm_narrated write would be lost on the next relink.
            int obj = 0
            if k < position_objs.length
                obj = position_objs[k]
            endif
            String name = SNSL_JMap.getStr(obj, "name")
            if orgasm_messages[k] != ""
                orgasm_happened = true
                ; Totals already bumped when GetIsOrgasming built the stashed clause.
                if SNSL_JMap.getInt(obj, "has_penis") == 1
                    ejaculation_happened = true
                endif 
                narration += orgasm_messages[k]
                orgasm_messages[k] = ""
                MarkOrgasmNarrated(obj, thread.positions[k])
            elseif orgasm_expected.length > k && orgasm_expected[k] == 1 && SNSL_JMap.getInt(obj, "dom_slave") == 1
                ; Dom Combined fallback: custom raced empty this window (unspoken total bump).
                int total = GetTotalOrgasms(thread.positions[k])
                if total < 1
                    total = SNSL_JMap.getInt(obj, "total_orgasm")
                endif
                int narrated = SNSL_JMap.getInt(obj, "orgasm_narrated")
                if total > narrated
                    orgasm_happened = true
                    if SNSL_JMap.getInt(obj, "has_penis") == 1
                        ejaculation_happened = true
                    endif
                    narration += name+" is orgasming. "
                    MarkOrgasmNarrated(obj, thread.positions[k])
                elseif total < 1
                    narration += main.handler_dom.HandleOrgasmDenied(thread.positions[k])
                else
                    narration += name+" is not orgasming right now. "
                endif
            else
                narration += name+" is not orgasming right now. "
            endif 
            k += 1
        endwhile
    endif 

    if ejaculation_happened
        int i = 0
        while i < num_actors 
            String cum_msg = AddCum(i, thread.positions[i], thread.positions[i].GetDisplayName())
            if cum_msg != ""
                if narration != "" && StringUtil.GetNthChar(narration, StringUtil.GetLength(narration) - 1) != " "
                    narration += " "
                endif
                narration += cum_msg
            endif
            i += 1 
        endwhile 
    endif 

    if orgasm_happened
        return narration
    else 
        return ""
    endif
EndFunction

Function MarkOrgasmNarrated(int obj, Actor akActor)
    if obj == 0
        return
    endif
    int spoken = 0
    if akActor != None
        spoken = GetTotalOrgasms(akActor)
    endif
    if spoken < 1
        spoken = SNSL_JMap.getInt(obj, "total_orgasm")
    endif
    SNSL_JMap.setInt(obj, "orgasm_narrated", spoken)
EndFunction

bool Function ThreadHasDomSlave()
    if !position_objs || thread == None
        return false
    endif
    int i = 0
    int n = thread.positions.length
    while i < n && i < position_objs.length
        if SNSL_JMap.getInt(position_objs[i], "dom_slave") == 1
            return true
        endif
        i += 1
    endwhile
    return false
EndFunction

float Function GetOrgasmDelay()
    float delay = 5.0
    if main
        delay = main.orgasm_delay
    endif
    if delay < 0.5
        delay = 0.5
    endif
    return delay
EndFunction

Function ArmOrgasmWindow()
    float delay = GetOrgasmDelay()
    float now = Utility.GetCurrentRealTime()
    float cap = delay * 2.0
    if !orgasm_window_open || orgasm_window_started_at <= 0.0
        orgasm_window_started_at = now
        orgasm_window_open = true
        RegisterForSingleUpdate(delay)
        Trace("ArmOrgasmWindow", "--- delay:"+delay)
        return
    endif
    float elapsed = now - orgasm_window_started_at
    float remaining = cap - elapsed
    if remaining <= 0.0
        Trace("ArmOrgasmWindow", "--- cap reached elapsed:"+elapsed+" cap:"+cap+", flush now")
        FlushOrgasmWindow()
        return
    endif
    if remaining > delay
        remaining = delay
    endif
    orgasm_window_open = true
    RegisterForSingleUpdate(remaining)
    Trace("ArmOrgasmWindow", "--- delay:"+remaining+" elapsed:"+elapsed+" cap:"+cap)
EndFunction

Function FlushOrgasmWindow()
    UnregisterForUpdate()
    orgasm_window_open = false
    orgasm_window_started_at = 0.0
    if thread == None
        Trace("FlushOrgasmWindow", "--- thread is None, clearing stash")
        if orgasm_messages
            int m = 0
            while m < orgasm_messages.length
                orgasm_messages[m] = ""
                m += 1
            endwhile
        endif
        orgasm_messages_set = false
        return
    endif
    ; Match StageStart / AnimationEnd: keep actors_objs aligned with positions
    ; before OrgasmMessagesToNarration reads names / orgasm_narrated.
    AlignActors()
    String orgasm_narration = OrgasmMessagesToNarration()
    if orgasm_narration == ""
        Trace("FlushOrgasmWindow", "--- empty stash")
        return
    endif
    Trace("FlushOrgasmWindow", "--- "+orgasm_narration)
    if has_player
        DirectNarration(orgasm_narration, sender, receiver, purge_dialogue=True)
    else
        DirectNarration_Optional("orgasm", orgasm_narration, sender, receiver)
    endif
EndFunction

Event OnUpdate()
    if Utility.IsInMenuMode()
        RegisterForSingleUpdate(0.5)
        Trace("OnUpdate", "--- orgasm window waiting on menu")
        return
    endif
    if !orgasm_messages_set
        orgasm_window_open = false
        orgasm_window_started_at = 0.0
        Trace("OnUpdate", "--- orgasm window empty, skip")
        return
    endif
    Trace("OnUpdate", "--- flushing orgasm window")
    FlushOrgasmWindow()
EndEvent

;----------------------------------------------------
; Add Cum
;----------------------------------------------------
String Function AddCum(int position, Actor akActor, String name)
    ; Add cum overlay 
    DbgEnter("AddCum", "position:"+position+" akActor:"+GetDisplayName(akActor)+" name:"+name)
    DbgMsg("AddCum", "thread.Animation")
    sslBaseAnimation anim = thread.Animation
    DbgMsg("AddCum", "anim.GetCumId position="+position+" stage="+thread.stage)
    int CumId = anim.GetCumId(position, thread.stage)

    ; -1 - no gender 
    ;  0 - Male (also the default values if the actor is not existing)
    ;  1 - Female
    int gender = akActor.GetLeveledActorBase().GetSex()
    ; 0 - male
    ; 1 - female 
    ; 2 - male creature 
    ; 3 - female creature 
    DbgMsg("AddCum", "sexlab.GetGender "+akActor.GetDisplayName())
    int gender_sexlab = sexlab.GetGender(akActor)
    DbgMsg("AddCum", "sexlab.GetGender returned "+gender_sexlab)
    bool has_pussy = gender == 1 || gender_sexlab == 1 || gender_sexlab == 3
    String genital = "" 
    if has_pussy
        genital = "pussy"
    else 
        genital = "penis"
    endif 

    String places = "" 
    if cumId > 0
        if cumId == sslObjectFactory.vaginal()
            places = genital
        elseif cumId == sslObjectFactory.oral()
            places = "mouth"
        elseif cumId == sslObjectFactory.anal()
            places = "ass"
        elseif cumId == sslObjectFactory.VaginalOral()
            if has_pussy
                places = genital+" and mouth"
            else
                places = "mouth"
            endif 
        elseif cumId == sslObjectFactory.VaginalAnal()
            if has_pussy
                places = genital+" and ass"
            else
                places = "ass"
            endif 
        elseif cumId == sslObjectFactory.OralAnal()
            places = "mouth and ass"
        elseif cumId == sslObjectFactory.VaginalOralAnal()
            if has_pussy
                places = genital+", mouth, and ass"
            else
                places = "mouth and ass"
            endif 
        endif
    endif 

    if places != ""
        DbgReturn("AddCum", "cum message")
        String cum_fallback = name+"'s "+places+" is dripping with warm sticky cum. "
        int cum_obj = JMap.object()
        JMap.setStr(cum_obj, "name", name)
        JMap.setStr(cum_obj, "places", places)
        return RenderSlPrompt("helpers/sexlab/cum", cum_obj, cum_fallback)
    endif 
    DbgReturn("AddCum", "empty")
    return "" 
EndFunction  

; --------------------------------------------
; --------------------------------------------
String Function GetDescription()
    DbgEnter("GetDescription")
    if thread == None
        DbgReturn("GetDescription", "")
        return ""
    endif
    String desc = animdb.GetThreadStageDescription(thread)
    if desc == "" 
        desc = GetDescriptionFromTags()
    endif 
    return desc 
EndFunction 

String Function GetThreadJson(Actor speaker) 
    DbgEnter("GetThreadJson", "speaker:"+GetDisplayName(speaker))
    GetThreadObj(speaker)
    String json = SNSL_JValue.dump(thread_obj)
    DbgReturn("GetThreadJson", "json")
    return json 
EndFunction 

int Function GetThreadObj(Actor speaker)
    DbgEnter("GetThreadObj", "speaker:"+GetDisplayName(speaker))
    if thread == None
        DbgReturn("GetThreadObj", "thread_obj (no thread)")
        return thread_obj
    endif
    alignactors()
    ; Poll: some plugins switch animation via a bare SetAnimation that sends no SexLab event.
    CheckAnimationChange()

    float distance = 0.0
    bool los = true 
    String speaker_name = ""
    if speaker == None
        ; No viewing speaker: treat as present/close so prompts do not gate on LOS.
        distance = 1.0
        los = true
        speaker_name = "none"
    else
        los = false 
    endif 

    int i = 0
    int num_actors = thread.positions.length
    bool actor_changed = false 
    while i < num_actors 
        if speaker != None && thread.positions[i] == speaker 
            los = true 
        endif 
        if updateactor(i, thread.positions[i])
            actor_changed = true
        endif
        i += 1
    endwhile
    ; updateactor wrote position_objs after alignactors' relink; refresh the snapshots.
    RelinkActorsObjs(num_actors)
    if actor_changed
        setnames() 
    endif 

    if speaker != None
        speaker_name = speaker.GetDisplayName()
        if !los
            distance = 0.0142875*speaker.getdistance(thread.positions[0])
            los = speaker.haslos(thread.positions[0]) 
        endif 
    endif 


    SNSL_JMap.setint(thread_obj, "active", getthreadactive() as int )
    SNSL_JMap.SetStr(thread_obj, "status",status)
    SNSL_JMap.SetStr(thread_obj, "description", getdescription())
    SNSL_JMap.SetStr(thread_obj, "style", style)
    SNSL_JMap.setStr(thread_obj, "speaker_name", speaker_name)
    SNSL_JMap.SetFlt(thread_obj, "speaker_distance", distance)
    SNSL_JMap.setint(thread_obj, "speaker_los", los as int)

    int names_arr = SNSL_JArray.object()
    int victims_arr = SNSL_JArray.object()
    i = 0
    while i < num_actors
        Actor akActor = thread.positions[i]
        SNSL_JArray.addstr(names_arr, akActor.getdisplayname())
        dbgmsg("GetThreadObj", "thread.isvictim "+akActor.getdisplayname())
        if thread.isvictim(akActor)
            SNSL_JArray.addstr(victims_arr, akActor.getdisplayname())
        endif
        i += 1
    endwhile
    SNSL_JMap.setobj(thread_obj, "names", names_arr)
    SNSL_JMap.setobj(thread_obj, "victims", victims_arr)
    SNSL_JMap.SetStr(thread_obj, "location", getlocation())

    dbgreturn("getThreadobj", "thread_obj")
    return thread_obj
EndFunction

String Function GetLocation()

    DbgEnter("GetLocation")
    DbgMsg("GetLocation", "thread.BedTypeId")
    int bed = thread.BedTypeId

    String loc = "the floor"
    if  bed == 1
        loc = "a bedroll "
    elseif bed == 2
        loc = "a single bed "
    elseif bed == 3
        loc = "a double bed "
    endif 

    String[] on_furniture = new String[21]
    on_furniture[0] = "Table"
    on_furniture[1] = "LowTable"
    on_furniture[2] = "JavTable"
    on_furniture[3] = "Pole"
    on_furniture[4] = "wall"
    on_furniture[5] = "horse"
    on_furniture[6] = "Pillory"
    on_furniture[7] = "PilloryLow"
    on_furniture[8] = "Cage"
    on_furniture[9] = "Haybale"
    on_furniture[10] = "Xcross"
    on_furniture[11] = "WoodenPony"
    on_furniture[12] = "EnchantingWB"
    on_furniture[13] = "AlchemyWB"
    on_furniture[14] = "FuckMachine"
    on_furniture[15] = "chair"
    on_furniture[16] = "wheel"
    on_furniture[17] = "DwemerChair"
    on_furniture[18] = "NecroChair"
    on_furniture[19] = "Throne"
    on_furniture[20] = "Stockade"
    ; Add more if needed

    ; Natural phrasing (with preposition/article) parallel to on_furniture, so the
    ; location reads as e.g. "on a table" instead of the bare tag "Table".
    String[] on_furniture_phrase = new String[21]
    on_furniture_phrase[0] = "on a table"
    on_furniture_phrase[1] = "on a low table"
    on_furniture_phrase[2] = "on a table"
    on_furniture_phrase[3] = "on a pole"
    on_furniture_phrase[4] = "against a wall"
    on_furniture_phrase[5] = "on a horse"
    on_furniture_phrase[6] = "in a pillory"
    on_furniture_phrase[7] = "in a pillory"
    on_furniture_phrase[8] = "in a cage"
    on_furniture_phrase[9] = "on a haybale"
    on_furniture_phrase[10] = "on an X-cross"
    on_furniture_phrase[11] = "on a wooden pony"
    on_furniture_phrase[12] = "at an enchanting table"
    on_furniture_phrase[13] = "at an alchemy table"
    on_furniture_phrase[14] = "on a fuck machine"
    on_furniture_phrase[15] = "on a chair"
    on_furniture_phrase[16] = "on a wheel"
    on_furniture_phrase[17] = "on a Dwemer chair"
    on_furniture_phrase[18] = "on a necromancer chair"
    on_furniture_phrase[19] = "on a throne"
    on_furniture_phrase[20] = "in a stockade"

    DbgMsg("GetLocation", "thread.Animation")
    sslBaseAnimation anim = thread.Animation
    int i = 0
    bool found = false
    while i < on_furniture.Length && !found
        if anim.HasTag(on_furniture[i])
            loc = on_furniture_phrase[i]
            found = true
        endif
        i += 1
    endwhile

    if !found 
        if anim.HasTag("Cage")
            loc = " in a cage"
        elseif anim.HasTag("Gallows")
            loc = " in a gallows"
        elseif anim.HasTag("coffin")
            loc = " in a coffin"
        elseif anim.HasTag("floating")
            loc = " floating in air"
        elseif anim.HasTag("tentacles")
            loc = " with tentacles"
        elseif anim.HasTag("gloryhole") || anim.HasTag("gloryholem")
            loc = " through a gloryhole"
        endif
    endif 

    DbgReturn("GetLocation", "loc")
    return loc+" "
EndFunction 


bool Function SexLab_Thread_LOS(Actor akActor)
    DbgEnter("SexLab_Thread_LOS", "akActor:"+GetDisplayName(akActor))
    if thread == None 
        DbgReturn("SexLab_Thread_LOS", "True")
        return True 
    endif 
    int i = 0
    int num_actors = thread.positions.length
    while i < num_actors 
        if akActor == thread.positions[i] || akActor.HasLOS(thread.positions[i])
            DbgReturn("SexLab_Thread_LOS", "true")
            return true
        endif 
        i += 1
    endwhile 
    DbgReturn("SexLab_Thread_LOS", "false")
    return false
endFunction 

String Function GetTagsString(sslBaseAnimation anim) global
    String[] _tags = anim.GetRawTags()
    int num_tags = _tags.length
    int i = 0
    String tags_string = ""
    while i < num_tags
        tags_string += _tags[i]
        if i < num_tags - 1
            tags_string += ", "
        endif
        i += 1
    endwhile
    return tags_string
EndFunction

; Fills in_thread (registry strings) and in_thread_anims (registry/name/tags objects) from
; thread.Animations. Entries whose Registry reads back empty are skipped rather than emitted
; half-built -- see KNOWLEDGEBASE "Papyrus VM returns None under overlay pause (2026-09-22)".
; in_thread/in_thread_anims are SNSL_JArray handles (C++ JSON store, not JContainers) -- this
; loop can run ~500 VM calls for a live scene, and JContainers garbage-collects unowned temporary
; objects on a ~10s timer, which used to corrupt this exact payload mid-build.
Function BuildInThreadAnims(sslThreadController _thread, int in_thread, int in_thread_anims)
    if !_thread
        return
    endif
    sslBaseAnimation[] anims = _thread.Animations
    int ai = 0
    int skipped = 0
    int first_skipped = -1
    while anims && ai < anims.length
        if anims[ai]
            String registry = anims[ai].Registry
            if registry != ""
                SNSL_JArray.addStr(in_thread, registry)
                int ao = SNSL_JMap.object()
                SNSL_JMap.setStr(ao, "_registry", registry)
                SNSL_JMap.setStr(ao, "_name", anims[ai].name)
                SNSL_JMap.setStr(ao, "_tags", GetTagsString(anims[ai]))
                SNSL_JArray.addObj(in_thread_anims, ao)
            else
                skipped += 1
                if first_skipped < 0
                    first_skipped = ai
                endif
            endif
        endif
        ai += 1
    endwhile
    if skipped > 0
        Trace("BuildInThreadAnims", "skipped "+skipped+"/"+anims.length+" anims, first at index "+first_skipped)
    endif
EndFunction


String Function GetDescriptionFromTags()
    ; Get the thread that triggered this event via the thread id
    sslBaseAnimation anim = thread.Animation
    ; Get our list of actors that were in this animation thread.
    Actor[] positions = thread.positions
    int num_actors = positions.length
    String sub_name = ""
    String dom_name = ""
    if num_actors > 0 && positions[0] != None
        sub_name = positions[0].GetDisplayName()
    endif
    if num_actors > 1 && positions[1] != None
        dom_name = positions[1].GetDisplayName()
    endif

    String buffer

    If anim.HasTag("aggressive") && dom_name != ""
        buffer = dom_name + " is sexually assaulting " + sub_name + ". "
    Else
        buffer = ""
    EndIf
    buffer += sub_name + " is"

    If anim.HasTag("rough")
        buffer += " roughly"
    ElseIf anim.HasTag("loving")
        buffer += " lovingly"
    EndIf

    If anim.HasTag("cowgirl")
        buffer += ", cowgirl position,"
    ElseIf anim.HasTag("missionary")
        buffer += ", missionary position,"
    ElseIf anim.HasTag("kneeling")
        buffer += ", kneeling position,"
    ElseIf anim.HasTag("standing")
        buffer += ", standing position,"
    EndIf

    If anim.HasTag("anal")
        buffer += " having anal sex with"
    ElseIf anim.HasTag("assjob")
        buffer += " having an assjob by"
    ElseIf anim.HasTag("boobjob")
        buffer += " giving a boobjob to"
    ElseIf anim.HasTag("thighjob")
        buffer += " giving a thighjob to"
    ElseIf anim.HasTag("vaginal")
        buffer += " having vaginal sex with"
    ElseIf anim.HasTag("fisting")
        buffer += " having her pussy fisted by"
    ElseIf anim.HasTag("oral") || anim.HasTag("blowjob") || anim.HasTag("cunnilingus")
        buffer += " giving a blowjob to"
    ElseIf anim.HasTag("spanking")
        buffer += " being spanked by"
    ElseIf anim.HasTag("masturbation")
        buffer += " masturbating furiously"
    ElseIf anim.HasTag("fingering")
        buffer += " being fingered by"
    ElseIf anim.HasTag("footjob")
        buffer += " giving a footjob to"
    ElseIf anim.HasTag("handjob")
        buffer += " giving a handjob to"
    ElseIf anim.HasTag("kissing")
        buffer += " kissing with"
    ElseIf anim.HasTag("headpat")
        buffer += " having head patted by"
    ElseIf anim.HasTag("hugging")
        buffer += " hugging"
    Else
        buffer += " having sex with"
        Trace("GetDescriptionFromTags", "no matching animation tag")
    EndIf

    If num_actors > 1 && dom_name != ""
        buffer += " " + dom_name
    EndIf
    buffer += ".\n\n"
    return buffer
endFunction

Function SetStyleDialog()
    DbgEnter("SetStyleDialog")
    String style_old = style
    parent.SetStyleDialog()

    if style_old != style
        if orgasm_messages_set
            Trace("SetStyleDialog", "--- skipping style DN, orgasm window open")
        else
            String name = GetDisplayName(sender)
            if has_player
                name = GetDisplayName(game.GetPlayer())
            endif
            DirectNarration(name+" changes from '"+style_old+"' to '"+style+"'", sender, receiver)
        endif
    endif 
    DbgReturn("SetStyleDialog")
endFunction

Function WebUI_ExportAnimationMenuState(sslThreadController _thread)
    if _thread != None
        thread = _thread
    endif
    SkyrimNet_SexLab_WebUI.Animation_Menu_Show(BuildWebUIAnimationMenuState())
EndFunction

String Function BuildWebUIAnimationMenuState()
    if thread == None
        return "{}"
    endif
    CheckAnimationChange()
    sslBaseAnimation anim = thread.animation
    int obj = JMap.object()
    JMap.setStr(obj, "_mode", "active")
    JMap.setInt(obj, "_scene_sid", sid)
    JMap.setStr(obj, "_connection", "scene:"+sid)
    JMap.setInt(obj, "_stage", thread.stage)
    if anim != None
        String registry = anim.Registry
        JMap.setStr(obj, "_registry", registry)
        JMap.setStr(obj, "_active_registry", registry)
        NotePlayedRegistry(registry)
        ; Prefer meaningful registry as title; keep display name as subtitle.
        if registry != "" && StringUtil.GetLength(registry) > 2
            JMap.setStr(obj, "_title", registry)
            JMap.setStr(obj, "_subtitle", anim.name)
        else
            JMap.setStr(obj, "_title", anim.name)
            JMap.setStr(obj, "_subtitle", registry)
        endif
        JMap.setStr(obj, "_anim_name", anim.name)
        JMap.setInt(obj, "_stage_count", anim.StageCount())
        JMap.setStr(obj, "_tags", GetTagsString(anim))
    endif
    ; obj (this function) is still a JContainers map -- BuildInThreadAnims now builds its two
    ; arrays in the C++ store, so bridge them across with a JSON round-trip (one native dump,
    ; one native parse; not the slow Papyrus walker this whole change exists to avoid).
    int in_thread = SNSL_JArray.object()
    int in_thread_anims = SNSL_JArray.object()
    BuildInThreadAnims(thread, in_thread, in_thread_anims)
    JMap.setObj(obj, "_in_thread_registries", JValue.objectFromPrototype(SNSL_JValue.dump(in_thread)))
    JMap.setObj(obj, "_in_thread_anims", JValue.objectFromPrototype(SNSL_JValue.dump(in_thread_anims)))
    SNSL_JValue.release(in_thread)
    SNSL_JValue.release(in_thread_anims)
    JMap.setStr(obj, "_intent", intent)
    JMap.setStr(obj, "_style", style)
    JMap.setStr(obj, "_activity", intent)
    Actor[] positions = thread.Positions
    int n = 0
    if positions
        n = positions.length
    endif
    int[] orgasm = animdb.GetOrgasmExpected(thread)
    int pos_arr = JArray.object()
    int i = 0
    while i < n
        int po = JMap.object()
        Actor ak = positions[i]
        JMap.setStr(po, "_name", ak.GetDisplayName())
        JMap.setStr(po, "_uuid", GetUUID(ak))
        JMap.setInt(po, "_form_id", ak.GetFormID())
        int no_org = 0
        int dressed = 0
        String speaking = ""
        if i < position_objs.length && position_objs[i] > 0
            no_org = SNSL_JMap.getInt(position_objs[i], "no_orgasm", 0)
            dressed = SNSL_JMap.getInt(position_objs[i], "dressed", 0)
            int speaking_obj = SNSL_JMap.getObj(position_objs[i], "speaking_modifiers")
            if speaking_obj > 0
                int sc = SNSL_JArray.count(speaking_obj)
                int si = 0
                while si < sc
                    String tok = SNSL_JArray.getStr(speaking_obj, si, "")
                    if tok != ""
                        if speaking != ""
                            speaking += ","
                        endif
                        speaking += tok
                    endif
                    si += 1
                endwhile
            endif
        endif
        JMap.setInt(po, "_no_orgasm", no_org)
        JMap.setInt(po, "_dressed", dressed)
        JMap.setInt(po, "_victim", thread.IsVictim(ak) as int)
        JMap.setStr(po, "_speaking", speaking)
        if i < orgasm.length
            JMap.setInt(po, "_orgasm_expected", orgasm[i])
        endif
        JArray.addObj(pos_arr, po)
        i += 1
    endwhile
    JMap.setObj(obj, "_positions", pos_arr)
    if anim != None
        int stage_count = anim.StageCount()
        int stages_arr = JValue.objectFromPrototype(animdb.GetThreadStagesJson(thread, stage_count))
        if stages_arr
            JMap.setObj(obj, "_stages", stages_arr)
        endif
    endif
    String json = ObjectToLowerCaseKeyJson(obj)
    JValue.release(obj)
    return json
EndFunction

Function WebUI_OnMenuClose(String json)
    int obj = JValue.objectFromPrototype(json)
    if obj == 0
        return
    endif
    bool dirty = JMap.getInt(obj, "_dirty", 0) == 1
    if JMap.hasKey(obj, "_style")
        String style_old = style
        SetStyle(JMap.getStr(obj, "_style", style))
        if style_old != style && has_player
            DirectNarration(GetDisplayName(Game.GetPlayer())+" changes from '"+style_old+"' to '"+style+"'", sender, receiver)
        endif
    endif
    ; Apply final position state; AnimDb write only when description/orgasm dirty.
    WebUI_ApplyLivePositions(obj)
    if dirty
        WebUI_SaveMenuState(obj)
    endif
    JValue.release(obj)
EndFunction

Function WebUI_OnMenuLiveUpdate(String json)
    int obj = JValue.objectFromPrototype(json)
    if obj == 0
        return
    endif
    if JMap.hasKey(obj, "_style")
        SetStyle(JMap.getStr(obj, "_style", style))
    endif
    if JMap.hasKey(obj, "_intent")
        intent = JMap.getStr(obj, "_intent", intent)
    endif
    WebUI_ApplyLivePositions(obj)
    JValue.release(obj)
EndFunction

; apply_values False (Scene Creator override off): only victim changes are applied; the per-actor
; dressed/orgasm/speaking values stay whatever the animation defaults set.
Function WebUI_ApplyLivePositions(int obj, bool apply_values = true)
    if thread == None || !JMap.hasKey(obj, "_positions")
        return
    endif
    Actor[] positions = thread.Positions
    if !positions
        return
    endif
    int pos_arr = JMap.getObj(obj, "_positions")
    int count = JArray.count(pos_arr)
    int n = positions.length
    if count < n
        n = count
    endif
    EnsureActorArraysLargeEnough(n)
    ; -1 = unchanged this call; 0/1 = new victim value, for the post-loop narration pass below.
    int[] victim_changed_new = Utility.CreateIntArray(n, -1)
    int i = 0
    while i < n
        int po = JArray.getObj(pos_arr, i)
        if po > 0 && apply_values
            int no_org = JMap.getInt(po, "_no_orgasm", 0)
            int dressed = JMap.getInt(po, "_dressed", 0)
            String speaking = JMap.getStr(po, "_speaking", "")
            SetPosition(i, positions[i], no_org, speaking)
            SNSL_JMap.setInt(position_objs[i], "dressed", dressed)
            ; A live WebUI commit is an explicit user choice, same as Setup()'s Scene-Creator
            ; hand-off and TM_ApplySpeaking -- lock it so StageStart's ApplyAnimDbSpeaking() never
            ; silently reverts it to the registry default on the next stage transition.
            SNSL_JMap.setInt(position_objs[i], "speaking_locked", 1)
            SNSL_JMap.setInt(position_objs[i], "orgasm_locked", 1)
            SNSL_JMap.setInt(position_objs[i], "dressed_locked", 1)
            thread.DisableOrgasm(positions[i], no_org == 1)
            Bool clothed = dressed == 1
            ApplyDressedToActor(positions[i], clothed)
            TM_ApplyClothed(positions[i], clothed)
        endif
        if po > 0 && JMap.hasKey(po, "_victim")
            Bool newVictim = JMap.getInt(po, "_victim", 0) == 1
            Bool wasVictim = thread.IsVictim(positions[i])
            thread.SetVictim(positions[i], newVictim)
            if newVictim != wasVictim
                victim_changed_new[i] = newVictim as int
            endif
        endif
        i += 1
    endwhile
    ; Narrate victim changes only after every SetVictim above has landed, so the aggressor lookup
    ; (the first other non-victim position) sees the fully-applied state, not a partial one.
    i = 0
    while i < n
        if victim_changed_new[i] >= 0
            NarrateVictimToggle(positions[i], victim_changed_new[i] == 1)
        endif
        i += 1
    endwhile
    if apply_values
        MarkUserDefaultsDirty()
    endif
EndFunction

; Fired by WebUI_ApplyLivePositions when a live victim toggle (Description Editor's V column)
; actually flips a position's victim status. Aggressor is the first other position that is not
; itself a victim (thread.IsVictim), read fresh -- does not touch the separate `initiator` field,
; which has its own lifecycle and is explicitly not recomputed on a live SetVictim (see
; PickNonVictimInitiator's own doc comment).
Function NarrateVictimToggle(Actor victim, Bool becameVictim)
    if thread == None || victim == None
        return
    endif
    Actor aggressor = None
    Actor[] positions = thread.Positions
    if positions
        int i = 0
        while i < positions.length && aggressor == None
            Actor a = positions[i]
            if a != None && a != victim && !thread.IsVictim(a)
                aggressor = a
            endif
            i += 1
        endwhile
    endif
    if aggressor == None
        Trace("NarrateVictimToggle", "no non-victim aggressor found, skipping narration for "+GetDisplayName(victim))
        return
    endif
    String msg = ""
    if becameVictim
        msg = aggressor.GetDisplayName()+" starts sexually assaulting "+victim.GetDisplayName()+"."
    else
        msg = aggressor.GetDisplayName()+" switches from sexual assault to sex with "+victim.GetDisplayName()+"."
    endif
    DirectNarration(msg, aggressor, victim)
EndFunction

Function WebUI_SaveMenuState(int obj)
    String registry = ""
    if JMap.hasKey(obj, "_registry")
        registry = JMap.getStr(obj, "_registry", "")
    endif
    if registry == "" && thread && thread.animation
        registry = thread.animation.Registry
    endif
    if registry == ""
        return
    endif
    int payload = JMap.object()
    if JMap.hasKey(obj, "_stages")
        int stages_arr = JMap.getObj(obj, "_stages")
        int count = JArray.count(stages_arr)
        int i = 0
        while i < count
            int st = JArray.getObj(stages_arr, i)
            if st > 0
                int stage_no = JMap.getInt(st, "_stage", i + 1)
                String template = JMap.getStr(st, "_template", "")
                if template != ""
                    int stage_obj = JMap.object()
                    JMap.setStr(stage_obj, "description", template)
                    JMap.setObj(payload, "stage "+stage_no, stage_obj)
                endif
            endif
            i += 1
        endwhile
    endif
    ; Persist O / speaking / clothed with the animation.
    if JMap.hasKey(obj, "_positions")
        int pos_arr = JMap.getObj(obj, "_positions")
        int count = JArray.count(pos_arr)
        int orgasm_arr = JArray.objectWithSize(count)
        int speak_arr = JArray.objectWithSize(count)
        int clothed_arr = JArray.objectWithSize(count)
        int i = 0
        while i < count
            int po = JArray.getObj(pos_arr, i)
            int no_org = 0
            int dressed = 0
            String speaking = ""
            if po > 0
                no_org = JMap.getInt(po, "_no_orgasm", 0)
                dressed = JMap.getInt(po, "_dressed", 0)
                speaking = JMap.getStr(po, "_speaking", "")
            endif
            JArray.setInt(orgasm_arr, i, 1 - no_org)
            JArray.setStr(speak_arr, i, speaking)
            JArray.setInt(clothed_arr, i, dressed)
            i += 1
        endwhile
        JMap.setObj(payload, "orgasm_expected", orgasm_arr)
        JMap.setObj(payload, "speaking_modifiers", speak_arr)
        JMap.setObj(payload, "clothed", clothed_arr)
    endif
    String save_json = ObjectToLowerCaseKeyJson(payload)
    JValue.release(payload)
    animdb.SaveAnimLocal(registry, save_json)
    if registry != ""
        ClearUserAnimDefaults(registry)
    endif
EndFunction

Function WebUI_OnMenuPrevNext(int direction)
    if thread == None || thread.animation == None
        return
    endif
    int stage = thread.stage
    if direction < 0 && stage > 1
        thread.GoToStage(stage - 1)
    elseif direction > 0 && stage < thread.animation.StageCount()
        thread.GoToStage(stage + 1)
    endif
    SkyrimNet_SexLab_WebUI.Animation_Menu_Show(BuildWebUIAnimationMenuState())
EndFunction

Function WebUI_OnMenuStop()
    if thread == None || !thread.Positions || thread.Positions.length < 1
        return
    endif
    Actor player = Game.GetPlayer()
    SkyrimNet_SexLab_Actions actions = (manager as Quest) as SkyrimNet_SexLab_Actions
    if actions
        actions.SceneStop_Target(player, thread.Positions[0], "stop")
    endif
EndFunction
Function NotePlayedRegistry(String registry)
    if registry == ""
        return
    endif
    int i = 0
    while i < played_registries_count
        if played_registries[i] == registry
            return
        endif
        i += 1
    endwhile
    if !played_registries || played_registries.length < played_registries_count + 1
        String[] grown = Utility.CreateStringArray(played_registries_count + 8)
        i = 0
        while i < played_registries_count
            grown[i] = played_registries[i]
            i += 1
        endwhile
        played_registries = grown
    endif
    played_registries[played_registries_count] = registry
    played_registries_count += 1
EndFunction

Bool Function WasRegistryPlayed(String registry)
    int i = 0
    while i < played_registries_count
        if played_registries[i] == registry
            return true
        endif
        i += 1
    endwhile
    return false
EndFunction

; Builds the scene state as an SNSL_JValue handle (C++ JSON store, not JContainers -- see
; KNOWLEDGEBASE "Papyrus VM silently returns None under overlay pause"). Caller serializes via
; SNSL_JValue.dump() or embeds it, and owns release if standalone.
int Function BuildWebUISceneMenuObject()
    int obj = SNSL_JMap.object()
    SNSL_JMap.setStr(obj, "_mode", "active")
    SNSL_JMap.setInt(obj, "_scene_sid", sid)
    SNSL_JMap.setStr(obj, "_connection", "scene:"+sid)
    SNSL_JMap.setStr(obj, "_connection_label", GetIntentMessage(INTENT_STAGE_ONGOING))
    SNSL_JMap.setStr(obj, "_intent", intent)
    SNSL_JMap.setStr(obj, "_style", style)
    int pos_arr = SNSL_JArray.object()
    int n = 0
    if thread && thread.Positions
        n = thread.Positions.length
    endif
    if n == 0 && position_objs
        n = position_objs.length
    endif
    String pos_names_dbg = ""
    int i = 0
    while i < n
        int po = SNSL_JMap.object()
        Actor ak = None
        if thread && thread.Positions && i < thread.Positions.length
            ak = thread.Positions[i]
        endif
        String name = ""
        String uuid = ""
        int form_id = 0
        int victim = 0
        int gender = -1
        if ak
            name = ak.GetDisplayName()
            uuid = GetUUID(ak)
            form_id = ak.GetFormID()
            victim = thread.IsVictim(ak) as int
            gender = sexlab.GetGender(ak)
        elseif position_objs && i < position_objs.length && position_objs[i] > 0
            name = SNSL_JMap.getStr(position_objs[i], "name")
            uuid = SNSL_JMap.getStr(position_objs[i], "uuid")
            form_id = SNSL_JMap.getInt(position_objs[i], "formid", 0)
            if form_id == 0
                String form_str = SNSL_JMap.getStr(position_objs[i], "formid")
                if form_str != ""
                    form_id = form_str as int
                endif
            endif
        endif
        if name != ""
            if pos_names_dbg != ""
                pos_names_dbg += ", "
            endif
            pos_names_dbg += name
        endif
        SNSL_JMap.setStr(po, "_name", name)
        SNSL_JMap.setStr(po, "_uuid", uuid)
        SNSL_JMap.setInt(po, "_form_id", form_id)
        int no_org = 0
        int dressed = 0
        String speaking = ""
        if position_objs && i < position_objs.length && position_objs[i] > 0
            no_org = SNSL_JMap.getInt(position_objs[i], "no_orgasm", 0)
            dressed = SNSL_JMap.getInt(position_objs[i], "dressed", 0)
            speaking = SpeakingCsvFromIndex(i)
        endif
        SNSL_JMap.setInt(po, "_dressed", dressed)
        SNSL_JMap.setInt(po, "_no_orgasm", no_org)
        int deny = 0
        if position_objs && i < position_objs.length && position_objs[i] > 0
            deny = SNSL_JMap.getInt(position_objs[i], "deny_orgasm", 0)
        endif
        SNSL_JMap.setInt(po, "_deny_orgasm", deny)
        SNSL_JMap.setInt(po, "_victim", victim)
        SNSL_JMap.setStr(po, "_speaking", speaking)
        if gender >= 0
            SNSL_JMap.setInt(po, "_gender", gender)
        endif
        SNSL_JArray.addObj(pos_arr, po)
        i += 1
    endwhile
    SNSL_JMap.setObj(obj, "_positions", pos_arr)
    SNSL_JMap.setInt(obj, "_position_override", position_override as int)
    int in_thread = SNSL_JArray.object()
    String active_reg = ""
    if thread && thread.animation
        active_reg = thread.animation.Registry
        NotePlayedRegistry(active_reg)
    endif
    SNSL_JMap.setStr(obj, "_active_registry", active_reg)
    int in_thread_anims = SNSL_JArray.object()
    if thread
        BuildInThreadAnims(thread, in_thread, in_thread_anims)
        SNSL_JMap.setInt(obj, "_stage", thread.stage)
        if thread.animation
            SNSL_JMap.setInt(obj, "_stage_count", thread.animation.StageCount())
            int stage_count = thread.animation.StageCount()
            ; One native call builds every stage row (was 2+ natives per stage). Already a plain
            ; JSON string, so no bridge needed -- straight into the SNSL store.
            int stages_arr = SNSL_JValue.objectFromPrototype(animdb.GetThreadStagesJson(thread, stage_count))
            if stages_arr
                SNSL_JMap.setObj(obj, "_stages", stages_arr)
            endif
        endif
    endif
    SNSL_JMap.setObj(obj, "_in_thread_registries", in_thread)
    SNSL_JMap.setObj(obj, "_in_thread_anims", in_thread_anims)
    int played = SNSL_JArray.object()
    i = 0
    while i < played_registries_count
        SNSL_JArray.addStr(played, played_registries[i])
        i += 1
    endwhile
    SNSL_JMap.setObj(obj, "_played_registries", played)
    if manager && manager.group_info > 0
        ; manager.group_info is still a JContainers map (Scene_Manager.psc not migrated this
        ; stage) -- bridge these two small subtrees across with a JSON round-trip.
        int group_tags = JMap.getObj(manager.group_info, "group_tags", 0)
        if group_tags > 0
            int group_tags_snsl = SNSL_JValue.objectFromPrototype(ObjectToLowerCaseKeyJson(group_tags))
            if group_tags_snsl
                SNSL_JMap.setObj(obj, "_group_tags", group_tags_snsl)
            endif
        endif
        int groups = JMap.getObj(manager.group_info, "groups", 0)
        if groups > 0
            int groups_snsl = SNSL_JValue.objectFromPrototype(ObjectToLowerCaseKeyJson(groups))
            if groups_snsl
                SNSL_JMap.setObj(obj, "_group_order", groups_snsl)
            endif
        endif
    endif
    Trace("BuildWebUISceneMenuState", "--- sid:"+sid+" positions:"+n+" names:["+pos_names_dbg+"] active:"+active_reg+" stage:"+SNSL_JMap.getInt(obj, "_stage", 0)+"/"+SNSL_JMap.getInt(obj, "_stage_count", 0))
    return obj
EndFunction

String Function BuildWebUISceneMenuState()
    CheckAnimationChange()
    int obj = BuildWebUISceneMenuObject()
    String json = SNSL_JValue.dump(obj)
    SNSL_JValue.release(obj)
    return json
EndFunction

; Description Editor "continue scene": narrate the (already rendered) active-stage description.
Function WebUI_OnNarrate(String json)
    int obj = JValue.objectFromPrototype(json)
    if obj == 0
        return
    endif
    String text = JMap.getStr(obj, "_text", "")
    JValue.release(obj)
    if text == ""
        return
    endif
    DirectNarration("The scene changes to "+text, sender, receiver)
EndFunction

Function WebUI_OnAnimUpdate(String json)
    if thread == None
        return
    endif
    int obj = JValue.objectFromPrototype(json)
    if obj == 0
        return
    endif
    String next_reg = JMap.getStr(obj, "_next_registry", "")
    JValue.release(obj)
    if next_reg == ""
        return
    endif
    sslBaseAnimation next_anim = sexlab.GetAnimationByRegistry(next_reg)
    if next_anim == None
        Trace("WebUI_OnAnimUpdate", "unknown registry:"+next_reg, true)
        return
    endif
    sslBaseAnimation[] cur = thread.Animations
    int idx = -1
    int i = 0
    while cur && i < cur.length
        if cur[i] && cur[i].Registry == next_reg
            idx = i
        endif
        i += 1
    endwhile
    if idx >= 0
        thread.SetAnimation(idx)
        NotePlayedRegistry(next_reg)
        CheckAnimationChange()
        SkyrimNet_SexLab_WebUI.SceneCreator_Configure(BuildWebUISceneMenuState())
        SkyrimNet_SexLab_WebUI.Animation_Menu_Configure(BuildWebUIAnimationMenuState())
        return
    endif
    int len = 0
    if cur
        len = cur.length
    endif
    bool use_forced = false
    sslBaseAnimation[] forced = thread.GetForcedAnimations()
    if forced && forced.length > 0
        use_forced = true
    endif
    if len >= 128
        String active_now = ""
        if thread.animation
            active_now = thread.animation.Registry
        endif
        int evict = -1
        i = 0
        while i < len
            if cur[i] && cur[i].Registry != active_now
                if !WasRegistryPlayed(cur[i].Registry)
                    evict = i
                    i = len
                elseif evict < 0
                    evict = i
                endif
            endif
            i += 1
        endwhile
        if evict < 0
            Trace("WebUI_OnAnimUpdate", "cannot evict at cap", true)
            return
        endif
        sslBaseAnimation[] rebuilt = sslUtility.AnimationArray(len)
        int w = 0
        i = 0
        while i < len
            if i != evict
                rebuilt[w] = cur[i]
                w += 1
            endif
            i += 1
        endwhile
        rebuilt[w] = next_anim
        if use_forced
            thread.SetForcedAnimations(rebuilt)
        else
            thread.SetAnimations(rebuilt)
        endif
        thread.SetAnimation(w)
    else
        thread.AddAnimation(next_anim)
        cur = thread.Animations
        idx = -1
        i = 0
        while cur && i < cur.length
            if cur[i] && cur[i].Registry == next_reg
                idx = i
            endif
            i += 1
        endwhile
        if idx >= 0
            thread.SetAnimation(idx)
        endif
    endif
    NotePlayedRegistry(next_reg)
    CheckAnimationChange()
    SkyrimNet_SexLab_WebUI.SceneCreator_Configure(BuildWebUISceneMenuState())
    SkyrimNet_SexLab_WebUI.Animation_Menu_Configure(BuildWebUIAnimationMenuState())
EndFunction

Function ApplyWebUICommit(int obj)
    if obj == 0
        return
    endif
    if JMap.getInt(obj, "_pending_stop", 0) == 1
        Actor speaker = Game.GetPlayer()
        int spid = JMap.getInt(obj, "_stop_speaker_form_id", 0)
        if spid != 0
            Actor sp = Game.GetFormEx(spid) as Actor
            if sp
                speaker = sp
            endif
        endif
        Actor target = None
        if thread && thread.Positions && thread.Positions.length > 0
            target = thread.Positions[0]
        endif
        if target
            String stop_style = JMap.getStr(obj, "_stop_style", "stop")
            String narration = JMap.getStr(obj, "_stop_narration", "")
            if narration != "" && StringUtil.Find(stop_style, "explain") != 0
                stop_style = "explain:"+narration
            endif
            SkyrimNet_SexLab_Actions actions = (manager as Quest) as SkyrimNet_SexLab_Actions
            if actions
                actions.SceneStop_Target(speaker, target, stop_style)
            endif
        endif
        return
    endif
    if thread == None
        return
    endif
    int i = 0
    int pos_arr = JMap.getObj(obj, "_positions")
    int count = JArray.count(pos_arr)
    if count >= 1 && count <= 5
        Actor[] next = PapyrusUtil.ActorArray(count)
        i = 0
        int valid = 0
        while i < count
            int po = JArray.getObj(pos_arr, i)
            Actor a = None
            if po > 0
                int fid = JMap.getInt(po, "_form_id", 0)
                if fid != 0
                    a = Game.GetFormEx(fid) as Actor
                endif
            endif
            if a
                next[valid] = a
                valid += 1
            endif
            i += 1
        endwhile
        if valid >= 1
            if valid != count
                Actor[] trimmed = PapyrusUtil.ActorArray(valid)
                i = 0
                while i < valid
                    trimmed[i] = next[i]
                    i += 1
                endwhile
                next = trimmed
            endif
            bool same = true
            Actor[] cur = thread.Positions
            int cn = 0
            if cur
                cn = cur.length
            endif
            if cn != next.length
                same = false
            else
                i = 0
                while i < cn && same
                    if cur[i] != next[i]
                        same = false
                    endif
                    i += 1
                endwhile
            endif
            if !same
                thread.ChangeActors(next)
            endif
        endif
    endif
    if JMap.hasKey(obj, "_style")
        SetStyle(JMap.getStr(obj, "_style", style))
    endif
    if JMap.hasKey(obj, "_intent")
        intent = JMap.getStr(obj, "_intent", intent)
    endif
    ; Commits without the key (Description Editor, older UI) keep the scene's current mode.
    bool override_on = JMap.getInt(obj, "_position_override", position_override as int) != 0
    WebUI_ApplyLivePositions(obj, override_on)
    if !override_on && position_override
        ; Just switched off: drop the user's values and locks, fall back to the animation.
        ReloadAnimationDefaults()
        PersistPositions()
    endif
    position_override = override_on
    i = 0
    while i < count
        int po = JArray.getObj(pos_arr, i)
        if po > 0 && override_on
            int fid = JMap.getInt(po, "_form_id", 0)
            Actor a = None
            if fid != 0
                a = Game.GetFormEx(fid) as Actor
            endif
            if a
                Bool isVictim = JMap.getInt(po, "_victim", 0) == 1
                thread.SetVictim(a, isVictim)
                int deny = JMap.getInt(po, "_deny_orgasm", 0)
                String mode = "expect"
                if deny == 1
                    mode = "deny"
                elseif JMap.getInt(po, "_no_orgasm", 0) == 1
                    mode = "not_expected"
                endif
                TM_ApplyOrgasmMode(a, mode)
            endif
        endif
        i += 1
    endwhile
    int want_stage = JMap.getInt(obj, "_stage", 0)
    int stage_step = JMap.getInt(obj, "_stage_step", 0)
    if stage_step != 0 && thread.animation
        ; Relative step resolved on the thread, so a stale editor stage can't misdirect it.
        want_stage = thread.stage + stage_step
        if want_stage < 1
            want_stage = 1
        endif
    endif
    if want_stage >= 1 && thread.animation
        int maxStage = thread.animation.StageCount()
        if want_stage > maxStage && stage_step != 0
            want_stage = maxStage
        endif
        Trace("ApplyWebUICommit", "stage thread:"+thread.stage+" want:"+want_stage+" step:"+stage_step+" max:"+maxStage)
        if want_stage <= maxStage && want_stage != thread.stage
            thread.GoToStage(want_stage)
            Trace("ApplyWebUICommit", "stage now:"+thread.stage)
        endif
        ; GoToStage sets thread.stage synchronously: show it in the editor now, not at StageStart.
        WebUI_PushStage()
    endif
    String active_reg = JMap.getStr(obj, "_active_registry", "")
    if active_reg == ""
        active_reg = JMap.getStr(obj, "_next_registry", "")
    endif
    if active_reg != "" && sexlab
        sslBaseAnimation next_anim = sexlab.GetAnimationByRegistry(active_reg)
        if next_anim
            sslBaseAnimation[] cur = thread.Animations
            int idx = -1
            i = 0
            while cur && i < cur.length
                if cur[i] && cur[i].Registry == active_reg
                    idx = i
                endif
                i += 1
            endwhile
            if idx >= 0
                thread.SetAnimation(idx)
                NotePlayedRegistry(active_reg)
                NoteSeededRegistry(active_reg)
            else
                thread.AddAnimation(next_anim)
                cur = thread.Animations
                idx = -1
                i = 0
                while cur && i < cur.length
                    if cur[i] && cur[i].Registry == active_reg
                        idx = i
                    endif
                    i += 1
                endwhile
                if idx >= 0
                    thread.SetAnimation(idx)
                    NotePlayedRegistry(active_reg)
                    NoteSeededRegistry(active_reg)
                endif
            endif
        endif
    endif
EndFunction

; -------------------------------------------------
; TargetMenu helpers
; -------------------------------------------------

Function EnsureUserAnimDefaultsMap()
    if user_anim_defaults < 1 || !SNSL_JValue.isExists(user_anim_defaults)
        user_anim_defaults = SNSL_JMap.object()
        SNSL_JValue.retain(user_anim_defaults)
    endif
EndFunction

Function ClearUserAnimDefaults(String registry)
    EnsureUserAnimDefaultsMap()
    if registry != ""
        SNSL_JMap.removeKey(user_anim_defaults, registry)
    endif
EndFunction

; Snapshot current overlay as user defaults for registry (wins on later anim switch).
Function CacheUserDefaultsForRegistry(String registry)
    if registry == "" || thread == None
        return
    endif
    Actor[] positions = thread.positions
    int n = 0
    if positions
        n = positions.length
    endif
    if n < 1
        return
    endif
    EnsureUserAnimDefaultsMap()
    int payload = SNSL_JMap.object()
    int orgasm_arr = SNSL_JArray.objectWithSize(n)
    int speak_arr = SNSL_JArray.objectWithSize(n)
    int clothed_arr = SNSL_JArray.objectWithSize(n)
    int i = 0
    while i < n
        int no_org = 0
        int dressed = 0
        String speaking = ""
        if position_objs && i < position_objs.length && position_objs[i] > 0
            no_org = SNSL_JMap.getInt(position_objs[i], "no_orgasm", 0)
            dressed = SNSL_JMap.getInt(position_objs[i], "dressed", 0)
            int speaking_obj = SNSL_JMap.getObj(position_objs[i], "speaking_modifiers")
            if speaking_obj > 0 && SNSL_JArray.count(speaking_obj) > 0
                speaking = SNSL_JArray.getStr(speaking_obj, 0)
            endif
            if SNSL_JMap.getInt(position_objs[i], "deny_orgasm", 0) == 1
                no_org = 0
            endif
        endif
        SNSL_JArray.setInt(orgasm_arr, i, 1 - no_org)
        SNSL_JArray.setStr(speak_arr, i, speaking)
        SNSL_JArray.setInt(clothed_arr, i, dressed)
        i += 1
    endwhile
    SNSL_JMap.setObj(payload, "orgasm_expected", orgasm_arr)
    SNSL_JMap.setObj(payload, "speaking_modifiers", speak_arr)
    SNSL_JMap.setObj(payload, "clothed", clothed_arr)
    SNSL_JMap.setObj(user_anim_defaults, registry, payload)
EndFunction

; Called after every live per-position edit (WebUI / Target Menu).
Function MarkUserDefaultsDirty()
    if thread && thread.animation
        CacheUserDefaultsForRegistry(thread.animation.Registry)
    endif
    PersistPositions()
EndFunction

Function SeedOverlayFromAnimDb()
    if thread == None || thread.animation == None
        return
    endif
    String registry = thread.animation.Registry
    Actor[] positions = thread.positions
    int n = 0
    if positions
        n = positions.length
    endif
    EnsureActorArraysLargeEnough(n)

    EnsureUserAnimDefaultsMap()
    int cached = 0
    if SNSL_JMap.hasKey(user_anim_defaults, registry)
        cached = SNSL_JMap.getObj(user_anim_defaults, registry)
    endif

    int[] orgasm = animdb.GetOrgasmExpected(thread)
    String[] speaking_arr = animdb.GetSpeakingModifiers(thread)
    int[] clothed_arr = animdb.GetClothed(thread)

    if cached > 0
        int c_org = SNSL_JMap.getObj(cached, "orgasm_expected")
        int c_spk = SNSL_JMap.getObj(cached, "speaking_modifiers")
        int c_cl = SNSL_JMap.getObj(cached, "clothed")
        int i = 0
        while i < n
            int expected = 1
            if c_org > 0 && i < SNSL_JArray.count(c_org)
                expected = SNSL_JArray.getInt(c_org, i, 1)
            elseif orgasm && i < orgasm.length
                expected = orgasm[i]
            endif
            int no_org = 1 - expected
            String speaking = SkyrimNet_SexLab_AnimDb.SpeakingDefaultFromOrgasmExpected(expected)
            if c_spk > 0 && i < SNSL_JArray.count(c_spk)
                speaking = SNSL_JArray.getStr(c_spk, i, speaking)
            elseif speaking_arr && i < speaking_arr.length
                speaking = speaking_arr[i]
            endif
            int dressed = 0
            if c_cl > 0 && i < SNSL_JArray.count(c_cl)
                dressed = SNSL_JArray.getInt(c_cl, i, 0)
            elseif clothed_arr && i < clothed_arr.length
                dressed = clothed_arr[i]
            endif
            if positions[i]
                ; An explicit speaking choice (Setup()/WebUI) must survive an animation change --
                ; only re-derive from AnimDB when nothing has locked this position yet.
                bool locked = position_objs && i < position_objs.length && position_objs[i] > 0 \
                    && SNSL_JMap.getInt(position_objs[i], "speaking_locked", 0) == 1
                bool dressed_locked = position_objs && i < position_objs.length && position_objs[i] > 0 \
                    && SNSL_JMap.getInt(position_objs[i], "dressed_locked", 0) == 1
                bool orgasm_locked = position_objs && i < position_objs.length && position_objs[i] > 0 \
                    && SNSL_JMap.getInt(position_objs[i], "orgasm_locked", 0) == 1
                String applied_speaking = speaking
                if locked
                    applied_speaking = SpeakingCsvFromIndex(i)
                endif
                int applied_no_org = no_org
                if orgasm_locked && position_objs[i] > 0
                    applied_no_org = SNSL_JMap.getInt(position_objs[i], "no_orgasm", no_org)
                endif
                SetPosition(i, positions[i], applied_no_org, applied_speaking)
                thread.DisableOrgasm(positions[i], applied_no_org == 1)
                if position_objs && i < position_objs.length && position_objs[i] > 0
                    SNSL_JMap.setInt(position_objs[i], "orgasm_mode", expected)
                    if !dressed_locked
                        SNSL_JMap.setInt(position_objs[i], "dressed", dressed)
                    endif
                    if !orgasm_locked
                        SNSL_JMap.setInt(position_objs[i], "deny_orgasm", 0)
                    endif
                    if !locked
                        SNSL_JMap.setInt(position_objs[i], "speaking_locked", 0)
                    endif
                endif
            endif
            i += 1
        endwhile
        PersistPositions()
        return
    endif

    int i = 0
    while i < n
        int expected = 1
        if orgasm && i < orgasm.length
            expected = orgasm[i]
        endif
        int no_org = 1 - expected
        String speaking = SkyrimNet_SexLab_AnimDb.SpeakingDefaultFromOrgasmExpected(expected)
        if speaking_arr && i < speaking_arr.length
            speaking = speaking_arr[i]
        endif
        int dressed = 0
        if clothed_arr && i < clothed_arr.length
            dressed = clothed_arr[i]
        endif
        if positions[i]
            bool locked = position_objs && i < position_objs.length && position_objs[i] > 0 \
                && SNSL_JMap.getInt(position_objs[i], "speaking_locked", 0) == 1
            bool dressed_locked = position_objs && i < position_objs.length && position_objs[i] > 0 \
                && SNSL_JMap.getInt(position_objs[i], "dressed_locked", 0) == 1
            bool orgasm_locked = position_objs && i < position_objs.length && position_objs[i] > 0 \
                && SNSL_JMap.getInt(position_objs[i], "orgasm_locked", 0) == 1
            String applied_speaking = speaking
            if locked
                applied_speaking = SpeakingCsvFromIndex(i)
            endif
            int applied_no_org = no_org
            if orgasm_locked && position_objs[i] > 0
                applied_no_org = SNSL_JMap.getInt(position_objs[i], "no_orgasm", no_org)
            endif
            SetPosition(i, positions[i], applied_no_org, applied_speaking)
            thread.DisableOrgasm(positions[i], applied_no_org == 1)
            if position_objs && i < position_objs.length && position_objs[i] > 0
                SNSL_JMap.setInt(position_objs[i], "orgasm_mode", expected)
                if !dressed_locked
                    SNSL_JMap.setInt(position_objs[i], "dressed", dressed)
                endif
                if !orgasm_locked
                    SNSL_JMap.setInt(position_objs[i], "deny_orgasm", 0)
                endif
                if !locked
                    SNSL_JMap.setInt(position_objs[i], "speaking_locked", 0)
                endif
            endif
        endif
        i += 1
    endwhile
    PersistPositions()
EndFunction

Function TM_ApplyOrgasmMode(Actor akActor, String mode)
    if thread == None || akActor == None
        return
    endif
    Actor[] positions = thread.positions
    int n = 0
    if positions
        n = positions.length
    endif
    int i = 0
    while i < n
        if positions[i] == akActor
            int no_org = 0
            int deny = 0
            if mode == "not_expected"
                no_org = 1
            elseif mode == "deny"
                no_org = 1
                deny = 1
            endif
            String speaking = ""
            int speaking_obj = SNSL_JMap.getObj(position_objs[i], "speaking_modifiers")
            if speaking_obj > 0 && SNSL_JArray.count(speaking_obj) > 0
                speaking = SNSL_JArray.getStr(speaking_obj, 0)
            endif
            if speaking == "" && mode != "not_expected"
                speaking = SkyrimNet_SexLab_AnimDb.SpeakingDefaultFromOrgasmExpected(1)
            elseif mode == "not_expected"
                speaking = SkyrimNet_SexLab_AnimDb.SpeakingDefaultFromOrgasmExpected(0)
            endif
            SetPosition(i, positions[i], no_org, speaking)
            SNSL_JMap.setInt(position_objs[i], "deny_orgasm", deny)
            SNSL_JMap.setInt(position_objs[i], "orgasm_locked", 1)
            thread.DisableOrgasm(akActor, no_org == 1 || deny == 1)
            MarkUserDefaultsDirty()
            return
        endif
        i += 1
    endwhile
EndFunction

Function TM_ApplySpeaking(Actor akActor, String speaking)
    if thread == None || akActor == None
        return
    endif
    Actor[] positions = thread.positions
    int n = 0
    if positions
        n = positions.length
    endif
    int i = 0
    while i < n
        if positions[i] == akActor
            int no_org = SNSL_JMap.getInt(position_objs[i], "no_orgasm", 0)
            SetPosition(i, positions[i], no_org, speaking)
            SNSL_JMap.setInt(position_objs[i], "speaking_locked", 1)
            ApplySexLabVoice(i)
            MarkUserDefaultsDirty()
            return
        endif
        i += 1
    endwhile
EndFunction

Function TM_ApplyClothed(Actor akActor, Bool clothed)
    if thread == None || akActor == None
        return
    endif
    Actor[] positions = thread.positions
    int n = 0
    if positions
        n = positions.length
    endif
    int i = 0
    while i < n
        if positions[i] == akActor
            SNSL_JMap.setInt(position_objs[i], "dressed", clothed as int)
            SNSL_JMap.setInt(position_objs[i], "dressed_locked", 1)
            MarkUserDefaultsDirty()
            return
        endif
        i += 1
    endwhile
EndFunction

Function TM_SaveAnimationSettings()
    if thread == None || thread.animation == None
        return
    endif
    String registry = thread.animation.Registry
    Actor[] positions = thread.positions
    int n = 0
    if positions
        n = positions.length
    endif
    int payload = JMap.object()
    int orgasm_arr = JArray.objectWithSize(n)
    int speak_arr = JArray.objectWithSize(n)
    int clothed_arr = JArray.objectWithSize(n)
    int i = 0
    while i < n
        int no_org = 0
        int dressed = 0
        String speaking = ""
        if position_objs && i < position_objs.length && position_objs[i] > 0
            no_org = SNSL_JMap.getInt(position_objs[i], "no_orgasm", 0)
            dressed = SNSL_JMap.getInt(position_objs[i], "dressed", 0)
            speaking = SpeakingCsvFromIndex(i)
            if SNSL_JMap.getInt(position_objs[i], "deny_orgasm", 0) == 1
                no_org = 0
            endif
        endif
        JArray.setInt(orgasm_arr, i, 1 - no_org)
        JArray.setStr(speak_arr, i, speaking)
        JArray.setInt(clothed_arr, i, dressed)
        i += 1
    endwhile
    JMap.setObj(payload, "orgasm_expected", orgasm_arr)
    JMap.setObj(payload, "speaking_modifiers", speak_arr)
    JMap.setObj(payload, "clothed", clothed_arr)
    String save_json = ObjectToLowerCaseKeyJson(payload)
    JValue.release(payload)
    animdb.SaveAnimLocal(registry, save_json)
    ClearUserAnimDefaults(registry)
    i = 0
    while position_objs && i < n && i < position_objs.length
        if position_objs[i] > 0
            SNSL_JMap.setInt(position_objs[i], "speaking_locked", 0)
            SNSL_JMap.setInt(position_objs[i], "orgasm_locked", 0)
            SNSL_JMap.setInt(position_objs[i], "dressed_locked", 0)
        endif
        i += 1
    endwhile
    PersistPositions()
EndFunction

Function WebUI_ConfigureIfOverlayVisible()
    if !SkyrimNet_SexLab_WebUI.WebUI_IsOverlayVisible()
        return
    endif
    SkyrimNet_SexLab_WebUI.SceneCreator_Configure(BuildWebUISceneMenuState())
    ; The Animation state only feeds the Description Editor; the Scene state above already refreshes SceneInfo.
    if SkyrimNet_SexLab_WebUI.WebUI_IsMainPanelOpen("description_editor_panel")
        SkyrimNet_SexLab_WebUI.Animation_Menu_Configure(BuildWebUIAnimationMenuState())
    endif
EndFunction

; Stage-only push straight from thread.stage; the Description Editor moves its row/nav without reloading stage text.
; started=true only from StageStart (thread reached Animating); GoToStage alone leaves the thread in Advancing.
Function WebUI_PushStage(Bool started = false)
    if thread == None || !SkyrimNet_SexLab_WebUI.WebUI_IsOverlayVisible()
        return
    endif
    if !SkyrimNet_SexLab_WebUI.WebUI_IsMainPanelOpen("description_editor_panel")
        return
    endif
    String tail = "}"
    if started
        tail = ",\"_stage_started\":1}"
    endif
    SkyrimNet_SexLab_WebUI.Animation_Menu_Configure("{\"_mode\":\"active\",\"_scene_sid\":"+sid+",\"_stage\":"+thread.stage+",\"_stage_only\":1"+tail)
EndFunction

Function TM_SetStageDescription(String stageStr, String description)
    if thread == None || thread.animation == None
        return
    endif
    int stage = stageStr as int
    if stage < 1
        return
    endif
    int payload = JMap.object()
    int sd = JMap.object()
    JMap.setStr(sd, stageStr, description)
    JMap.setObj(payload, "stage_descriptions", sd)
    String save_json = ObjectToLowerCaseKeyJson(payload)
    JValue.release(payload)
    animdb.SaveAnimLocal(thread.animation.Registry, save_json)
    SkyrimNet_SexLab_WebUI.SceneCreator_Configure(BuildWebUISceneMenuState())
    SkyrimNet_SexLab_WebUI.Animation_Menu_Configure(BuildWebUIAnimationMenuState())
EndFunction
