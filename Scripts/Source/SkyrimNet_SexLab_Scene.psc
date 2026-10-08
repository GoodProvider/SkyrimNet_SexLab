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
; Per slot, what orgasm_messages[i] holds (ORGASM_KIND_*). DOM melt: the text with the name as {n}.
int[] orgasm_kinds
; Pending parts of the one orgasm message: "<allower> allowed <allowed> to orgasm. " and folded
; arouse / calm narrations. orgasm_overflow: parts that did not fit the budget (sent as an event).
String orgasm_prefix = ""
String orgasm_extras = ""
String orgasm_overflow = ""
; Sex is hard work: non-victims whose exhaustion ends the scene (Scene_Manager.EndExhausted).
Actor[] exhausted_actors
bool orgasm_messages_set = false
bool orgasm_window_open = false
; NarrateOrgasmStash is building / sending: a second caller arms the window instead (slot arrays are shared).
bool orgasm_narrating = false
; Orgasm_ApplyGroup is stashing its group (window not armed yet): StageStart must not take a partial stash.
bool orgasm_group_pending = false
; Thread hook OrgasmStart sent on entering the final (non-LeadIn) stage; OrgasmEnd not yet sent.
bool orgasm_hook_open = false
; Pause hotkey: the stage is held with thread.UpdateTimer(PAUSE_HOLD_SECONDS) (StageTimer and
; TimedStage are private to sslThreadController). paused_stage/paused_anim: the stage last held.
bool scene_paused = false
float pause_started_at = 0.0
int paused_stage = 0
sslBaseAnimation paused_anim = None
float Property PAUSE_HOLD_SECONDS = 100000.0 AutoReadOnly
; Scene ending (sexlab.ending.*): the lead (initiator; the aggressor with a victim) has a target orgasm
; count; reaching it jumps to the final stage, which is held until the orgasm dialogue has played.
Actor ending_actor = None
int ending_target = 0
bool ending_done = false
bool ending_holding = false
bool ending_hold_pending = false
float ending_hold_started = 0.0
float ending_orgasm_at = 0.0
float ending_narrated_at = 0.0
; An aggressive NPC lead reached the target: Ending_Poll ends the animation instead of releasing the hold.
bool ending_end_after = false
; Engine gate passed in the second-to-last stage: that stage is held until the gate narration's voice
; starts (Engine_AdvanceToFinal) or sexlab.ending.gate_wait_max. gate_hold_timer: UpdateTimer applied.
bool gate_holding = false
bool gate_hold_timer = false
float gate_hold_started = 0.0
; Real-time stamp when the Combined DOM window first armed; ArmOrgasmWindow
; will not extend past 2x orgasm_delay from this start.
float orgasm_window_started_at = 0.0
; A gate narration arrived while NarrateOrgasmStash was busy: the deferred flush must still go out
; as a DirectNarration (never Optional) and tell the engine once it actually sends.
bool gate_pending_force = false
bool gate_pending_notify = false

String storage_prefix = "skyrimnet_sexlab_scene"
String storage_obj_key = "skyrimnet_sexlab_scene_actor_position_obj"
String storage_total_orgasms_key = "skyrimnet_sexlab_scene_total_orgasms"
String storage_orgasm_narrated_key = "skyrimnet_sexlab_scene_orgasm_narrated"
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
    orgasm_narrating = false
    orgasm_group_pending = false
    orgasm_hook_open = false
    scene_paused = false
    Ending_Reset()
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
                SetUndressedFlag(positions[i], creator.no_stripping_mask[i] == 0)
            else
                SetPosition(i, positions[i], 0, creator.speaking_modifiers_default_current)
                SNSL_JMap.setInt(position_objs[i], "dressed", 0)
                SetUndressedFlag(positions[i], true)
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
    ; WebUI initiator pulldown can make the speaker the creator's target: never narrate "Bob and Bob".
    if num_actors >= 2 && (receiver == None || receiver == sender)
        receiver = FirstOtherPosition(sender)
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
    ClearStyleSpeed()
    seeded_registry = ""
    position_override = true
    seed_first_animation = false
    pending_animation_change = false
    animation_change_from = ""
    orgasm_window_open = false
    orgasm_hook_open = false
    scene_paused = false
    Ending_Reset()
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
            StorageUtil.UnsetIntValue(akActor, storage_orgasm_narrated_key)
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
    ClearOrgasmStash()
    orgasm_window_open = false
    orgasm_hook_open = false
    scene_paused = false
    Ending_Reset()
    orgasm_window_started_at = 0.0
    animating_started_at = 0.0

    ; A reused pool scene must not apply the previous cast's per-registry edits or played list.
    if user_anim_defaults > 0 && SNSL_JValue.isExists(user_anim_defaults)
        SNSL_JMap.clear(user_anim_defaults)
    endif
    played_registries_count = 0

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
    if !orgasm_kinds || size > orgasm_kinds.length
        orgasm_kinds = EnsureIntsLargeEnough(orgasm_kinds, size, 0)
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
; sends optional DirectNarration "Scene changes to '<new stage description>'".
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
        Engine_SetSkills()
        Engine_SetStage()
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
; undress_only (animation changes): dressing only goes toward undressed -- an actor the new animation
; wants dressed but who is already undressed stays undressed (flag rewritten to match).
Function ReloadAnimationDefaults(bool undress_only = true)
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
            bool want_dressed = SNSL_JMap.getInt(position_objs[i], "dressed", 0) == 1
            if want_dressed && undress_only && StorageUtil.HasIntValue(positions[i], storage_undressed_key)
                SNSL_JMap.setInt(position_objs[i], "dressed", 0)
            else
                ApplyDressedToActor(positions[i], want_dressed)
            endif
        endif
        i += 1
    endwhile
    PersistPositions()
EndFunction

; Strips or re-dresses akActor to match a dressed flag. Uses the thread's own tracked strip state
; (sslActorAlias.Strip/UnStrip), not main.Store/UnStoreStrippedItems -- that cache is only ever
; populated by the standalone Outfit_Dress/Outfit_Undress actions, never by the scene's own
; automatic per-thread stripping. See KNOWLEDGEBASE "Description Editor dressed toggle used wrong
; strip API (2026-09-22)".
Function ApplyDressedToActor(Actor akActor, Bool clothed)
    if thread == None || akActor == None
        return
    endif
    sslActorAlias slot = thread.ActorAlias(akActor)
    if slot
        Trace("ApplyDressedToActor", akActor.GetDisplayName()+" clothed:"+clothed)
        if clothed
            slot.UnStrip()
        else
            ; SetNoStripping left an all-false StripOverride; replace it with SexLab's normal strip
            ; set (OverrideStrip can't clear it -- length must be 33).
            Bool is_female = akActor.GetLeveledActorBase().GetSex() == 1
            slot.OverrideStrip(thread.Config.GetStrip(is_female, thread.UseLimitedStrip(), thread.IsAggressive, thread.IsVictim(akActor)))
            slot.Strip()
        endif
        SetUndressedFlag(akActor, !clothed)
    endif
EndFunction

; In-scene strip state for the WebUI TargetMenu/Scene dress|undress eligibilityRules
; (HasIntValue). Separate from position_objs "dressed", which TargetMenu dress/undress must not
; touch. Set by Setup (SexLab's own start strip) and ApplyDressedToActor; cleared at scene end.
String storage_undressed_key = "skyrimnet_sexlab_scene_undressed"

Function SetUndressedFlag(Actor akActor, Bool undressed)
    if akActor == None
        return
    endif
    if undressed
        StorageUtil.SetIntValue(akActor, storage_undressed_key, 1)
    else
        StorageUtil.UnsetIntValue(akActor, storage_undressed_key)
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
            StorageUtil.SetStringValue(a, persist_prefix+"deny_by", SNSL_JMap.getStr(obj, "deny_by"))
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
    SNSL_JMap.setStr(obj, "deny_by", StorageUtil.GetStringValue(akActor, persist_prefix+"deny_by", ""))
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
    StorageUtil.UnsetStringValue(akActor, persist_prefix+"deny_by")
    StorageUtil.UnsetIntValue(akActor, persist_prefix+"dressed")
    StorageUtil.UnsetIntValue(akActor, persist_prefix+"orgasm_locked")
    StorageUtil.UnsetIntValue(akActor, persist_prefix+"speaking_locked")
    StorageUtil.UnsetIntValue(akActor, persist_prefix+"dressed_locked")
    StorageUtil.UnsetStringValue(akActor, persist_prefix+"speaking")
    SetUndressedFlag(akActor, false)
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
    Trace("SetPosition", "end index:"+index+" name: "+akActor.GetDisplayName()+" no_orgasm: "+SNSL_JMap.getInt(obj, "no_orgasm")+" speaking_modifiers: "+SNSL_JValue.dump(speaking_obj))
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
    ; Not expected to orgasm: the animation does not arouse them, silent until enjoyment reaches 50.
    int obj = GetObjFromActor(a)
    if voiced && obj > 0 && SNSL_JMap.getInt(obj, "orgasm_expected", 1) == 0 && Voice_BelowGate(a)
        voiced = false
    endif
    sslBaseVoice v = thread.GetVoice(a)
    ; Silenced before SexLab picked a voice leaves Voice none; pick one when un-silencing.
    if voiced && v == None && sexlab != None
        v = sexlab.PickVoice(a)
    endif
    thread.SetVoice(a, v, !voiced)
    Trace("ApplySexLabVoice", GetDisplayName(a)+" speaking:"+csv+" voiced:"+voiced)
EndFunction

bool Function Voice_BelowGate(Actor a)
    return SkyrimNet_SexLab_OrgasmEngine.IsManaged(a) && SkyrimNet_SexLab_OrgasmEngine.GetEnjoyment(a) < VOICE_GATE_ENJOYMENT
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

    ; SetPosition re-runs SetActor on anim change / WebUI / TargetMenu edits. Keep the orgasm counts
    ; when the actor is already bound to this scene (same or moved slot). Read them per actor from
    ; StorageUtil, not the old obj: in a slot swap the other actor may already have overwritten it.
    int total_orgasms = 0
    int orgasm_narrated = 0
    int prev_obj = StorageUtil.GetIntValue(akActor, storage_obj_key, 0)
    if prev_obj > 0 && position_objs.Find(prev_obj) >= 0
        total_orgasms = StorageUtil.GetIntValue(akActor, storage_total_orgasms_key, 0)
        orgasm_narrated = StorageUtil.GetIntValue(akActor, storage_orgasm_narrated_key, 0)
    endif
    StorageUtil.SetIntValue(akActor, storage_obj_key, obj)
    StorageUtil.SetIntValue(akActor, storage_total_orgasms_key, total_orgasms)
    StorageUtil.SetIntValue(akActor, storage_orgasm_narrated_key, orgasm_narrated)
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
    SNSL_JMap.setInt(obj,"total_orgasm",total_orgasms)
    SNSL_JMap.setInt(obj,"orgasm_narrated",orgasm_narrated)
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
    ; OrgasmEngine's live enjoyment (0-100); SexLab's is mirrored from it.
    int enjoyment = 0
    if status == STATUS_ACTIVE
        if SkyrimNet_SexLab_OrgasmEngine.IsManaged(akActor)
            enjoyment = SkyrimNet_SexLab_OrgasmEngine.GetEnjoyment(akActor) as int
        else
            sslActorAlias actorAlias = thread.ActorAlias(akActor)
            if actorAlias != None
                enjoyment = actorAlias.GetEnjoyment()
            endif
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

String Function PossessivePronoun(Actor akActor)
    if akActor != None
        int sex = akActor.GetLeveledActorBase().GetSex()
        if sex == 1
            return "her"
        elseif sex == 0
            return "his"
        endif
    endif
    return "their"
EndFunction

; "A" / "A and B" / "A, B, and C".
String Function JoinNames(String[] names, int count)
    if count <= 0
        return ""
    elseif count == 1
        return names[0]
    elseif count == 2
        return names[0]+" and "+names[1]
    endif
    String s = ""
    int i = 0
    while i < count - 1
        s += names[i]+", "
        i += 1
    endwhile
    return s+"and "+names[count - 1]
EndFunction

; One sentence for a state: "<A> <single> " or "<A and B> <plural> ". Empty when count is 0.
String Function NamesClause(String[] names, int count, String single, String plural)
    if count <= 0
        return ""
    elseif count == 1
        return names[0]+" "+single+" "
    endif
    return JoinNames(names, count)+" "+plural+" "
EndFunction

; Sex is hard work: one sentence per tier of OrgasmEngine stamina regen. >= 90: nothing; 41-89 breathing
; hard; 1-40 tired; 0 to -10 exhausted. Actors in exhausted_actors are "too tired to continue".
String Function FatigueText()
    if thread == None
        return ""
    endif
    int n = thread.positions.length
    String[] gave_out = Utility.CreateStringArray(n)
    String[] breath = Utility.CreateStringArray(n)
    String[] tired = Utility.CreateStringArray(n)
    String[] spent = Utility.CreateStringArray(n)
    int c_gave_out = 0
    int c_breath = 0
    int c_tired = 0
    int c_spent = 0
    int i = 0
    while i < n
        Actor a = thread.positions[i]
        String name = GetDisplayName(a)
        int regen = SkyrimNet_SexLab_OrgasmEngine.GetStaminaRegen(a) as int
        if exhausted_actors && exhausted_actors.Find(a) >= 0
            gave_out[c_gave_out] = name
            c_gave_out += 1
        elseif regen <= 0
            spent[c_spent] = name
            c_spent += 1
        elseif regen <= 40
            tired[c_tired] = name
            c_tired += 1
        elseif regen < 90
            breath[c_breath] = name
            c_breath += 1
        endif
        i += 1
    endwhile
    String msg = NamesClause(gave_out, c_gave_out, "is too tired to continue.", "are too tired to continue.")
    msg += NamesClause(spent, c_spent, "is exhausted.", "are exhausted.")
    msg += NamesClause(tired, c_tired, "is tired.", "are tired.")
    msg += NamesClause(breath, c_breath, "is breathing hard.", "are breathing hard.")
    return msg
EndFunction

Function SetExhausted(Actor[] actors)
    exhausted_actors = actors
EndFunction

; OrgasmEngine's live enjoyment (0-100), or SexLab's for unmanaged actors.
int Function LiveEnjoyment(Actor a)
    if a == None
        return 0
    endif
    if SkyrimNet_SexLab_OrgasmEngine.IsManaged(a)
        return SkyrimNet_SexLab_OrgasmEngine.GetEnjoyment(a) as int
    endif
    if thread != None
        sslActorAlias actorAlias = thread.ActorAlias(a)
        if actorAlias != None
            return actorAlias.GetEnjoyment()
        endif
    endif
    return 0
EndFunction

; Enjoyment band for the not-orgasming / denied lead-ins: 0 (<=30), 1 (<=60), 2 (<90), 3 (90+).
int Function EnjoymentBand(int e)
    if e <= 30
        return 0
    elseif e <= 60
        return 1
    elseif e < 90
        return 2
    endif
    return 3
EndFunction

String Function BandLeadIn(int band)
    if band == 1
        return "Though aroused, "
    elseif band == 2
        return "Although close, "
    elseif band == 3
        return "Although on the edge, "
    endif
    return ""
EndFunction

String Function ReplaceAll(String s, String find, String rep)
    if s == "" || find == ""
        return s
    endif
    int flen = StringUtil.GetLength(find)
    String out = ""
    int p = StringUtil.Find(s, find)
    while p >= 0
        out += StringUtil.Substring(s, 0, p) + rep
        s = StringUtil.Substring(s, p + flen)
        p = StringUtil.Find(s, find)
    endwhile
    return out + s
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

; orgasm_kinds: what a stash slot holds. The builder (OrgasmMessagesToNarration) groups by kind.
int Property ORGASM_KIND_NONE = 0 AutoReadOnly    ; empty, or legacy verbatim text
int Property ORGASM_KIND_ORGASM = 1 AutoReadOnly  ; "<names> is/are orgasming."
int Property ORGASM_KIND_AGAIN = 2 AutoReadOnly   ; "<names> is orgasming. again." / "are orgasming again."
int Property ORGASM_KIND_FORCED = 3 AutoReadOnly  ; "<names> is/are forced to orgasm by <player>."
int Property ORGASM_KIND_MELT = 4 AutoReadOnly    ; DOM melt: orgasm_messages[i] = text with {n} for the name

; Stashes an orgasm for slot i and updates the actor's orgasm total.
; total_orgasms < 0: +1 from current. total_orgasms >= 0: set absolute (SLSO).
; A melt / forced slot is not downgraded to a plain orgasm by a later stash in the same window.
Function StashOrgasm(int i, Actor akActor, int kind, String text = "", int total_orgasms = -1)
    if akActor == None || i < 0
        return
    endif
    EnsureActorArraysLargeEnough(i + 1)
    if total_orgasms < 0
        SetTotalOrgasms(akActor, GetTotalOrgasms(akActor) + 1)
    else
        SetTotalOrgasms(akActor, total_orgasms)
    endif
    int recorded = GetTotalOrgasms(akActor)
    if kind == ORGASM_KIND_ORGASM && recorded > 1
        kind = ORGASM_KIND_AGAIN
    endif
    int old = orgasm_kinds[i]
    if (old == ORGASM_KIND_MELT || old == ORGASM_KIND_FORCED) && (kind == ORGASM_KIND_ORGASM || kind == ORGASM_KIND_AGAIN)
        kind = old
        text = orgasm_messages[i]
    endif
    if kind != ORGASM_KIND_MELT
        ; Non-empty marker so slot checks (orgasm_messages[i] == "") still see the stash.
        text = GetDisplayName(akActor)+" is orgasming. "
    endif
    orgasm_kinds[i] = kind
    orgasm_messages[i] = text
    orgasm_messages_set = true
    Trace("StashOrgasm", GetDisplayName(akActor)+" slot:"+i+" kind:"+kind+" total:"+recorded+" text:"+text)
EndFunction

Function ClearOrgasmStash()
    if orgasm_messages
        int m = 0
        while m < orgasm_messages.length
            orgasm_messages[m] = ""
            m += 1
        endwhile
    endif
    if orgasm_kinds
        int k = 0
        while k < orgasm_kinds.length
            orgasm_kinds[k] = 0
            k += 1
        endwhile
    endif
    orgasm_prefix = ""
    orgasm_extras = ""
    orgasm_messages_set = false
EndFunction

; DOM melt text -> stash key: drops the manager's ". <name> is orgasming." clause and replaces the
; slave's name with {n}, so slaves with the same melt text merge into one sentence.
String Function MeltKey(Actor akActor, String msg)
    String name = GetDisplayName(akActor)
    int p = StringUtil.Find(msg, name+" is orgasming.")
    if p >= 0
        msg = StringUtil.Substring(msg, 0, p)
    endif
    int len = StringUtil.GetLength(msg)
    while len > 0 && (StringUtil.GetNthChar(msg, len - 1) == " " || StringUtil.GetNthChar(msg, len - 1) == ".")
        len -= 1
    endwhile
    if len <= 0
        return ""
    endif
    return ReplaceAll(StringUtil.Substring(msg, 0, len), name, "{n}")
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
    ; Start / ongoing carry the pace: "Bob and Alice are forcefully ..." (normal: no adverb).
    if intent_stage != INTENT_STAGE_END
        String adverb = GetSpeedAdverb()
        if adverb != ""
            verb += " "+adverb
        endif
    endif
    ; DOM / empty-intent creators must not emit "Nina and Bob finish ."
    String fallback = ""
    ; Empty intent with victims: "Bob finish Camilla." read wrong, so fall through to "Camilla and Bob finish."
    if num_victims > 0 && intent != ""
        fallback = assailant_names+" "+verb+" "+intent+" "+victim_names+"."
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
; OrgasmEngine shell (C++ owns enjoyment + orgasms; see docs/developers/orgasm-engine.md)
; --------------------------------------------

; Per-actor orgasm on/off. SexLab's own trigger is off for the whole thread (DisableAllOrgasms);
; keep SexLab's per-actor flag in step and tell the engine. DOM slaves are DOM-driven: the engine
; raises DOM's arousal and DOM rolls its own orgasm (Handler_DOM, docs/developers/orgasm-engine.md).
Function SetOrgasmDisabled(Actor akActor, bool disabled)
    if akActor == None
        return
    endif
    if thread != None
        thread.DisableOrgasm(akActor, disabled)
    endif
    SkyrimNet_SexLab_OrgasmEngine.SetSceneBlocked(akActor, disabled)
    SkyrimNet_SexLab_OrgasmEngine.SetDomSlave(akActor, main.handler_dom.IsDOMSlave(akActor))
EndFunction

; Registers (or re-syncs) this scene with the engine. Re-entrant: the engine keeps existing actors' state.
Function Engine_BeginScene()
    if thread == None || !thread.Positions
        return
    endif
    thread.DisableAllOrgasms(true)
    Actor[] positions = thread.Positions
    int n = positions.length
    int[] roles = Utility.CreateIntArray(n)
    float[] seeds = Utility.CreateFloatArray(n)
    bool any_victim = false
    int i = 0
    while i < n
        if positions[i] != None && thread.IsVictim(positions[i])
            any_victim = true
        endif
        i += 1
    endwhile
    i = 0
    while i < n
        Actor a = positions[i]
        if a != None
            if thread.IsVictim(a)
                roles[i] = 2
            elseif any_victim
                roles[i] = 1
            endif
            sslActorAlias actorAlias = thread.ActorAlias(a)
            if actorAlias != None
                seeds[i] = actorAlias.GetEnjoyment() as float
            endif
        endif
        i += 1
    endwhile
    sla_checked = false
    SkyrimNet_SexLab_OrgasmEngine.BeginScene(sid, positions, roles, seeds, has_player)
    i = 0
    while i < n
        Actor a = positions[i]
        if a != None
            int obj = GetObjFromActor(a)
            ; Only the player's deny blocks; not expected (no_orgasm) just stops passive gain (Engine_SetSkills).
            bool blocked = obj > 0 && SNSL_JMap.getInt(obj, "deny_orgasm") == 1
            SkyrimNet_SexLab_OrgasmEngine.SetSceneBlocked(a, blocked)
            SkyrimNet_SexLab_OrgasmEngine.SetDomSlave(a, main.handler_dom.IsDOMSlave(a))
        endif
        i += 1
    endwhile
    Ending_RollTarget()
    Engine_SetEndingTarget()
    Engine_SetSkills()
    Engine_SetStage()
EndFunction

; Skill for the current act (by animation tag) and lewd - pure, per actor. Start and animation change only.
Function Engine_SetSkills()
    if thread == None || thread.Animation == None || sexlab == None
        return
    endif
    String skill_name = "Foreplay"
    int act_skill = 0
    if thread.Animation.HasTag("Vaginal")
        skill_name = "Vaginal"
        act_skill = 1
    elseif thread.Animation.HasTag("Anal")
        skill_name = "Anal"
        act_skill = 2
    elseif thread.Animation.HasTag("Oral") || thread.Animation.HasTag("Blowjob") || thread.Animation.HasTag("Cunnilingus")
        skill_name = "Oral"
        act_skill = 3
    endif
    Actor[] positions = thread.Positions
    Engine_SetBonusInputs(positions, act_skill)
    ; Not expected to orgasm (AnimDB orgasm_expected 0, or the scene's no_orgasm): no passive gain,
    ; mini-game only. Missing: expected.
    int[] orgasm = animdb.GetOrgasmExpected(thread)
    int i = 0
    while i < positions.length
        Actor a = positions[i]
        if a != None
            int lewd = sexlab.Stats.GetLewdLevel(a) - sexlab.Stats.GetPureLevel(a)
            SkyrimNet_SexLab_OrgasmEngine.SetActorSkills(a, sexlab.GetSkillLevel(a, skill_name), lewd)
            int obj = GetObjFromActor(a)
            bool expected = !orgasm || orgasm.length <= i || orgasm[i] == 1
            if obj > 0 && SNSL_JMap.getInt(obj, "no_orgasm") == 1
                expected = false
            endif
            SkyrimNet_SexLab_OrgasmEngine.SetOrgasmExpected(a, expected)
            if obj > 0
                SNSL_JMap.setInt(obj, "orgasm_expected", expected as int)
            endif
        endif
        i += 1
    endwhile
EndFunction

; SexLab's starting-enjoyment inputs per actor (sslActorAlias StartAnimating): skills of the actor and of
; the partner SexLab bases them on (the player when present, else the next position), and the present
; relationship ranks. Creatures are unskilled (empty arrays). The engine applies SexLab's formula.
Function Engine_SetBonusInputs(Actor[] positions, int act_skill)
    Actor player = Game.GetPlayer()
    float[] unskilled = Utility.CreateFloatArray(0)
    int n = positions.length
    int i = 0
    while i < n
        Actor a = positions[i]
        if a != None
            Actor partner = a
            if a != player && positions.Find(player) >= 0
                partner = player
            elseif n > 1
                partner = positions[(i + 1) % n]
            endif
            float[] own = unskilled
            float[] other = unskilled
            if partner != None && a.HasKeywordString("ActorTypeNPC") && partner.HasKeywordString("ActorTypeNPC")
                own = sexlab.Stats.GetSkillLevels(a)
                other = sexlab.Stats.GetSkillLevels(partner)
            endif
            int low = thread.GetLowestPresentRelationshipRank(a)
            int high = thread.GetHighestPresentRelationshipRank(a)
            SkyrimNet_SexLab_OrgasmEngine.SetBonusInputs(a, own, other, low, high, act_skill)
        endif
        i += 1
    endwhile
EndFunction

Function Engine_SetStage()
    if thread == None || thread.Animation == None
        return
    endif
    ; SexLab's stage term steps on a stage change: not another plugin's doing.
    Mirror_RebaselineAll()
    int count = thread.Animation.StageCount()
    SkyrimNet_SexLab_OrgasmEngine.SetStageTimers(sid, Engine_StageSeconds(), thread.LeadIn)
    ; Thread hooks at SexLab's timing (its own are off with DisableAllOrgasms): OrgasmStart once on
    ; entering the final non-LeadIn stage, OrgasmEnd on leaving it (or at AnimationEnd). DOM makes
    ; its one full roll from this OrgasmStart.
    bool final_stage = thread.Stage >= count && !thread.LeadIn
    if final_stage && !orgasm_hook_open
        orgasm_hook_open = true
        Trace("Engine_SetStage", "OrgasmStart hook stage:"+thread.Stage+"/"+count)
        thread.SendThreadEvent("OrgasmStart")
    elseif !final_stage && orgasm_hook_open
        orgasm_hook_open = false
        Trace("Engine_SetStage", "OrgasmEnd hook stage:"+thread.Stage+"/"+count)
        thread.SendThreadEvent("OrgasmEnd")
    endif
    SkyrimNet_SexLab_OrgasmEngine.SetStage(sid, thread.Stage, count)
EndFunction

; Seconds per stage of the current animation, by sslThreadController.GetTimer's rule (TimedStage is
; Animation.HasTimer(stage)). Empty when SexLab has no timers: the engine uses its fallback rate.
float[] Function Engine_StageSeconds()
    sslBaseAnimation anim = thread.Animation
    float[] timers = thread.Timers
    int count = anim.StageCount()
    if count < 1 || timers.length < 1
        return Utility.CreateFloatArray(0)
    endif
    float[] secs = Utility.CreateFloatArray(count)
    int last = timers.length - 1
    int s = 1
    while s <= count
        if anim.HasTimer(s)
            secs[s - 1] = anim.GetTimer(s)
        elseif s < last
            secs[s - 1] = timers[s - 1]
        elseif s >= count || last < 1
            secs[s - 1] = timers[last]
        else
            secs[s - 1] = timers[last - 1]
        endif
        s += 1
    endwhile
    return secs
EndFunction

; --------------------------------------------
; Scene ending (sexlab.ending.*). The lead's orgasm target is rolled once per scene; reaching it
; (Orgasm_ApplyGroup) jumps to the final stage. The engine's gate passes just before the final stage
; (Engine_GatePassed: DN now, stage held) and its voice starting jumps (Engine_AdvanceToFinal). The
; final stage is then held (UpdateTimer, like the pause key) until the orgasm dialogue has played.
; --------------------------------------------
Function Ending_Reset()
    if ending_holding && thread != None && !scene_paused
        thread.UpdateTimer(-PAUSE_HOLD_SECONDS)
        thread.ResolveTimers()
    endif
    if gate_holding && gate_hold_timer && thread != None
        thread.UpdateTimer(-PAUSE_HOLD_SECONDS)
        thread.ResolveTimers()
    endif
    gate_holding = false
    gate_hold_timer = false
    gate_hold_started = 0.0
    ending_actor = None
    ending_target = 0
    ending_done = false
    ending_holding = false
    ending_hold_pending = false
    ending_hold_started = 0.0
    ending_orgasm_at = 0.0
    ending_narrated_at = 0.0
    ending_end_after = false
EndFunction

Function Ending_RollTarget()
    if ending_actor != None || thread == None || !thread.Positions
        return
    endif
    ending_actor = initiator
    if ending_actor == None || thread.Positions.Find(ending_actor) < 0
        ending_actor = thread.Positions[0]
    endif
    if ending_actor == None
        return
    endif
    String which = "female"
    int def_hi = 2
    if sexlab != None && sexlab.GetGender(ending_actor) == 0
        which = "male"
        def_hi = 1
    endif
    int lo = SkyrimNetApi.GetConfigInt("Plugin_SkyrimNet_SexLab", "sexlab.ending.target_"+which+"_min", 1)
    int hi = SkyrimNetApi.GetConfigInt("Plugin_SkyrimNet_SexLab", "sexlab.ending.target_"+which+"_max", def_hi)
    if lo < 0
        lo = 0
    endif
    if hi < lo
        hi = lo
    endif
    ending_target = Utility.RandomInt(lo, hi)
    Trace("Ending_RollTarget", GetDisplayName(ending_actor)+" ("+which+") target:"+ending_target)
EndFunction

; The engine's early final roll needs the lead and target (0 once the ending is done or off).
Function Engine_SetEndingTarget()
    int target = ending_target
    if ending_done || ending_actor == None || !SkyrimNetApi.GetConfigBool("Plugin_SkyrimNet_SexLab", "sexlab.ending.enabled", true)
        target = 0
    endif
    SkyrimNet_SexLab_OrgasmEngine.SetEndingTarget(sid, ending_actor, target)
EndFunction

; After an orgasm group (the engine's group roll already ran, so a lead who joined counts): the lead
; reached the target. Aggressive NPC lead: hold the current stage and end the animation once the
; dialogue has played. Otherwise: final stage + dialogue hold, from the second-to-last stage only.
Function Ending_Check(Actor[] actors)
    if ending_done || ending_actor == None || ending_target <= 0 || thread == None || thread.Animation == None || thread.LeadIn
        return
    endif
    if !SkyrimNetApi.GetConfigBool("Plugin_SkyrimNet_SexLab", "sexlab.ending.enabled", true)
        return
    endif
    if actors.Find(ending_actor) < 0
        return
    endif
    int count = SkyrimNet_SexLab_OrgasmEngine.GetOrgasmCount(ending_actor)
    if count < ending_target
        Trace("Ending_Check", GetDisplayName(ending_actor)+" orgasms:"+count+"/"+ending_target)
        return
    endif
    int stages = thread.Animation.StageCount()
    if ending_actor != Game.GetPlayer() && thread.IsAggressive && !thread.IsVictim(ending_actor)
        Trace("Ending_Check", GetDisplayName(ending_actor)+" (aggressor) reached target "+count+"/"+ending_target+" at stage "+thread.Stage+"/"+stages+", ending after dialogue")
        ending_done = true
        ending_end_after = true
        ending_orgasm_at = Utility.GetCurrentRealTime()
        ending_narrated_at = 0.0
        Ending_Hold()
        return
    endif
    if thread.Stage < stages - 1
        Trace("Ending_Check", GetDisplayName(ending_actor)+" reached target "+count+"/"+ending_target+" at stage "+thread.Stage+"/"+stages+", not second-to-last: no jump")
        return
    endif
    Trace("Ending_Check", GetDisplayName(ending_actor)+" reached target "+count+"/"+ending_target+", final stage")
    Ending_ToFinal()
EndFunction

; Engine gate passed (in the second-to-last stage, early by the measured DN -> voice time; or on
; reaching the final stage first): narrate the passers now as one direct DN so the voice is ready when
; the stage turns. Their orgasms follow as a "gate" group (ForceOrgasm only) once their bars fill in
; the final stage. hold_stage: hold the second-to-last stage until the voice starts.
Function Engine_GatePassed(Actor[] actors, bool hold_stage)
    if thread == None || thread.Animation == None || !actors
        return
    endif
    EnsureActorArraysLargeEnough(thread.positions.length)
    Actor first = None
    int i = 0
    while i < actors.length
        Actor a = actors[i]
        int slot = -1
        if a != None
            slot = thread.positions.Find(a)
        endif
        if slot >= 0
            StashOrgasm(slot, a, ORGASM_KIND_ORGASM)
            if first == None
                first = a
            endif
        else
            Trace("Engine_GatePassed", GetDisplayName(a)+" not in thread.positions")
        endif
        i += 1
    endwhile
    if first == None
        return
    endif
    Trace("Engine_GatePassed", "count:"+actors.length+" hold:"+hold_stage+" stage:"+thread.Stage+"/"+thread.Animation.StageCount())
    ; Anything waiting in the orgasm window goes out in this same DN.
    if orgasm_window_open
        UnregisterForUpdate()
        orgasm_window_open = false
        orgasm_window_started_at = 0.0
        if ending_holding
            RegisterForSingleUpdate(1.0)
        endif
    endif
    bool sent = NarrateOrgasmStash(first, FirstOtherPosition(first), force_direct=True)
    if sent
        SkyrimNet_SexLab_OrgasmEngine.GateNarrationSent(sid)
    else
        ; NarrateOrgasmStash was busy: the window will flush this force_direct and notify the
        ; engine once it actually goes out (FlushOrgasmWindow).
        gate_pending_notify = true
    endif
    if hold_stage
        Gate_Hold()
    elseif !ending_done && !thread.LeadIn
        Ending_ToFinal()
    endif
EndFunction

Function Gate_Hold()
    if gate_holding
        return
    endif
    gate_holding = true
    gate_hold_started = Utility.GetCurrentRealTime()
    ; The pause key already holds the stage; its resume restores the timer.
    gate_hold_timer = !scene_paused
    if gate_hold_timer
        thread.UpdateTimer(PAUSE_HOLD_SECONDS)
    endif
    Trace("Gate_Hold", "holding stage:"+thread.Stage+" for the gate voice")
    RegisterForSingleUpdate(1.0)
EndFunction

Function Gate_Release()
    if !gate_holding
        return
    endif
    gate_holding = false
    if gate_hold_timer && thread != None
        ; A save/load mid-hold resets GetCurrentRealTime(): a negative gap would push the timer far
        ; out instead of releasing it; treat it as "no time held" instead.
        float held = Utility.GetCurrentRealTime() - gate_hold_started
        if held < 0.0
            held = 0.0
        endif
        thread.UpdateTimer(held - PAUSE_HOLD_SECONDS)
        thread.ResolveTimers()
    endif
    gate_hold_timer = false
EndFunction

; No voice by sexlab.ending.gate_wait_max (DN dropped, TTS off, load mid-wait): go on anyway.
Function Gate_Poll()
    if !gate_holding
        return
    endif
    if scene_paused
        ; Freeze the countdown while paused (the hotkey pause, not a save/load); re-check next tick.
        gate_hold_started += 1.0
        RegisterForSingleUpdate(1.0)
        return
    endif
    float held = Utility.GetCurrentRealTime() - gate_hold_started
    float wait_max = SkyrimNetApi.GetConfigFloat("Plugin_SkyrimNet_SexLab", "sexlab.ending.gate_wait_max", 20.0)
    ; held < 0: a save/load reset the real-time clock mid-wait; stop waiting instead of holding for
    ; up to the old gate_hold_started's worth of real seconds.
    if held >= 0.0 && held < wait_max
        RegisterForSingleUpdate(1.0)
        return
    endif
    Trace("Gate_Poll", "no gate voice after "+held+"s")
    Engine_AdvanceToFinal()
EndFunction

; The gate narration's voice started (engine) or Gate_Poll gave up: release the gate hold and go to
; the final stage (plus the dialogue hold); the engine's rush fires the orgasm there.
Function Engine_AdvanceToFinal()
    Gate_Release()
    if thread == None || thread.Animation == None || thread.LeadIn
        return
    endif
    int count = thread.Animation.StageCount()
    Trace("Engine_AdvanceToFinal", "gate voice stage:"+thread.Stage+"/"+count)
    if ending_done && thread.Stage >= count
        return
    endif
    Ending_ToFinal()
EndFunction

Function Ending_ToFinal()
    ending_done = true
    ending_orgasm_at = Utility.GetCurrentRealTime()
    ending_narrated_at = 0.0
    int count = thread.Animation.StageCount()
    if thread.Stage < count
        ending_hold_pending = true
        thread.GoToStage(count)
    else
        Ending_Hold()
    endif
EndFunction

Function Ending_StageStart()
    ; A new animation started while the gate hold was active: the engine already dropped gateAwait /
    ; rushing on this SetStage (stage < stageCount-1), so the old hold is stale. Drop it without
    ; touching this animation's fresh timer or forcing it to its final stage.
    if gate_holding && pending_animation_change
        Trace("Ending_StageStart", "--- animation changed mid gate-hold, dropping the stale hold")
        gate_holding = false
        gate_hold_timer = false
        gate_hold_started = 0.0
    endif
    ; SexLab (or a manual advance) reached the final stage before the gate voice: GoToStage already
    ; reset the held timer; hold the final stage for the dialogue instead.
    if gate_holding && thread != None && thread.Animation != None && thread.Stage >= thread.Animation.StageCount()
        gate_holding = false
        gate_hold_timer = false
        if !ending_done && !thread.LeadIn
            Ending_ToFinal()
            return
        endif
    endif
    if ending_hold_pending && thread != None && thread.Animation != None && thread.Stage >= thread.Animation.StageCount()
        Ending_Hold()
    endif
EndFunction

Function Ending_Hold()
    ending_hold_pending = false
    float hold_max = SkyrimNetApi.GetConfigFloat("Plugin_SkyrimNet_SexLab", "sexlab.ending.dialogue_hold_max", 45.0)
    ; Ending after the dialogue still needs the poll, even with no hold cap (ends at the first poll).
    if (hold_max <= 0.0 && !ending_end_after) || ending_holding
        return
    endif
    ending_holding = true
    ending_hold_started = Utility.GetCurrentRealTime()
    ; The pause key already holds the stage; its resume restores the timer.
    if !scene_paused
        thread.UpdateTimer(PAUSE_HOLD_SECONDS)
    endif
    Trace("Ending_Hold", "holding final stage:"+thread.Stage+" max:"+hold_max)
    if !orgasm_window_open
        RegisterForSingleUpdate(1.0)
    endif
EndFunction

; Release once the orgasm narration was sent (window closed), SkyrimNet's speech queue is empty and
; audio ended at least 1 s after that; or at sexlab.ending.dialogue_hold_max.
Function Ending_Poll()
    if !ending_holding || thread == None
        return
    endif
    float now = Utility.GetCurrentRealTime()
    float held = now - ending_hold_started
    float hold_max = SkyrimNetApi.GetConfigFloat("Plugin_SkyrimNet_SexLab", "sexlab.ending.dialogue_hold_max", 45.0)
    bool release = held >= hold_max
    if !release && !orgasm_window_open
        if ending_narrated_at <= 0.0
            ending_narrated_at = now
        endif
        int queue = SkyrimNetApi.GetSpeechQueueSize()
        float since_audio = (SkyrimNetApi.GetTimeSinceLastAudioEnded() as float) / 1000.0
        float since_narrated = now - ending_narrated_at
        release = held >= 3.0 && queue == 0 && since_audio > 0.0 && since_audio < since_narrated - 1.0
    endif
    if !release
        RegisterForSingleUpdate(1.0)
        return
    endif
    ending_holding = false
    if ending_end_after
        ending_end_after = false
        Trace("Ending_Poll", "aggressor finished, ending the animation after "+held+"s")
        thread.EndAnimation()
        return
    endif
    if !scene_paused
        thread.UpdateTimer(held - PAUSE_HOLD_SECONDS)
        thread.ResolveTimers()
    endif
    Trace("Ending_Poll", "released final stage after "+held+"s")
EndFunction

; --------------------------------------------
; Pause / resume (HUD pause key). StageTimer / TimedStage are private to sslThreadController, so the
; stage is held by pushing its timer far out (UpdateTimer) and released by pulling it back by the
; unpaused remainder; ResolveTimers restores TimedStage = Animation.HasTimer(Stage).
; --------------------------------------------
bool Function IsPaused()
    return scene_paused
EndFunction

Function TogglePause()
    if thread == None || thread.Animation == None
        return
    endif
    scene_paused = !scene_paused
    if scene_paused
        paused_stage = 0
        paused_anim = None
        Pause_Hold()
    else
        float held = SexLabUtil.GetCurrentGameRealTime() - pause_started_at
        thread.UpdateTimer(held - PAUSE_HOLD_SECONDS)
        thread.ResolveTimers()
        Trace("TogglePause", "resumed stage:"+thread.Stage+" held:"+held)
    endif
    SkyrimNet_SexLab_OrgasmEngine.SetScenePaused(sid, scene_paused)
EndFunction

; Holds the current stage. Once per (animation, stage): a new stage resets SexLab's timer, a
; repeated StageStart for the same stage (animation-change queue) must not stack another hold.
Function Pause_Hold()
    if !scene_paused || thread == None
        return
    endif
    if paused_anim == thread.Animation && paused_stage == thread.Stage
        return
    endif
    paused_anim = thread.Animation
    paused_stage = thread.Stage
    pause_started_at = SexLabUtil.GetCurrentGameRealTime()
    thread.UpdateTimer(PAUSE_HOLD_SECONDS)
    Trace("Pause_Hold", "holding stage:"+thread.Stage)
EndFunction

; Engine -> Effect_OrgasmGroup: everyone who orgasmed together (trigger + group join at 95).
; ForceOrgasm runs SexLab's cum/sound/SexLabOrgasm and resets its build-up for each.
; individual: narrate the group now as one DN; else (safety net / joiners of an external orgasm) or
; while a window is open: stash and let the window flush one DN.
; allower: deny 1 -> 0 -> "<allower> allowed <allowed> to orgasm. " leads the message.
Function Orgasm_ApplyGroup(Actor[] actors, int[] forced, bool individual, String source, Actor allower, Actor allowed, String extras)
    if thread == None || !actors
        Trace("Orgasm_ApplyGroup", "no thread or actors")
        return
    endif
    DbgEnter("Orgasm_ApplyGroup", "count:"+actors.length+" individual:"+individual+" source:"+source+" allower:"+GetDisplayName(allower))
    EnsureActorArraysLargeEnough(thread.positions.length)
    ; The loop yields (ForceOrgasm): a StageStart in between must not narrate half the group.
    if source != "gate"
        orgasm_group_pending = true
    endif
    Actor first = None
    int i = 0
    while i < actors.length
        Actor a = actors[i]
        int slot = -1
        if a != None
            slot = thread.positions.Find(a)
        endif
        if slot >= 0
            ; SexLab's trigger stays disabled (DisableAllOrgasms); we run SexLab's orgasm ourselves. The
            ; thread hooks OrgasmStart / OrgasmEnd follow SexLab's stage timing (Engine_SetStage).
            thread.ForceOrgasm(a)
            Mirror_Rebaseline(a)
            ; Gate rush: stashed and narrated at the pass (Engine_GatePassed).
            if source != "gate"
                int kind = ORGASM_KIND_ORGASM
                if forced && i < forced.length && forced[i] == 1
                    kind = ORGASM_KIND_FORCED
                endif
                StashOrgasm(slot, a, kind)
            endif
            if first == None
                first = a
            endif
        else
            Trace("Orgasm_ApplyGroup", GetDisplayName(a)+" not in thread.positions")
        endif
        i += 1
    endwhile
    if first == None
        orgasm_group_pending = false
        DbgEnd("Orgasm_ApplyGroup")
        return
    endif
    if source == "gate"
        Ending_Check(actors)
        DbgEnd("Orgasm_ApplyGroup")
        return
    endif
    if allower != None && allowed != None
        orgasm_prefix = GetDisplayName(allower)+" allowed "+GetDisplayName(allowed)+" to orgasm. "
    endif
    if extras != ""
        if orgasm_extras != ""
            orgasm_extras += " "
        endif
        orgasm_extras += extras
    endif
    ; Final stage: window too, so a near end folds it into the finish DN (OnUpdate). The dialogue hold
    ; (ending_holding) waits on this narration, so it goes out at once there.
    if !individual || orgasm_window_open || (IsFinalStage() && !ending_holding)
        ArmOrgasmWindow()
    else
        Actor target = allower
        if target == None || target == first
            target = FirstOtherPosition(first)
        endif
        NarrateOrgasmStash(first, target)
    endif
    ; Cleared only now: the window is open or the stash went out (NarrateOrgasmStash).
    orgasm_group_pending = false
    Ending_Check(actors)
    DbgEnd("Orgasm_ApplyGroup")
EndFunction

bool Function IsFinalStage()
    return thread != None && thread.Animation != None && !thread.LeadIn && thread.Stage >= thread.Animation.StageCount()
EndFunction

Actor Function FirstOtherPosition(Actor akActor)
    if thread == None
        return None
    endif
    int i = 0
    while i < thread.positions.length
        if thread.positions[i] != akActor
            return thread.positions[i]
        endif
        i += 1
    endwhile
    return None
EndFunction

; SexLab enjoyment the last mirror left behind (position obj "sl_mirror_set"; -1 = no baseline), with the
; stage and animation it was taken at ("sl_mirror_stage" / "sl_mirror_anim"). Within one stage SexLab only
; drifts a little on its own (time term), so a larger move means another plugin called AdjustEnjoyment:
; fold it into the engine instead of overwriting it. SexLab's stage term jumps (about +10) on a stage or
; animation change, often a mirror before Engine_SetStage rebaselines: a baseline from another stage or
; animation is stale and never folded.
int Property MIRROR_EXTERNAL_THRESHOLD = 3 AutoReadOnly
; Not expected to orgasm: SexLab voice stays silent below this enjoyment.
int Property VOICE_GATE_ENJOYMENT = 50 AutoReadOnly

; Forget the baseline where SexLab jumps legitimately (orgasm resets QuitEnjoyment, stage term steps).
Function Mirror_Rebaseline(Actor akActor)
    int obj = GetObjFromActor(akActor)
    if obj > 0
        SNSL_JMap.setInt(obj, "sl_mirror_set", -1)
    endif
EndFunction

Function Mirror_RebaselineAll()
    if thread == None
        return
    endif
    int i = 0
    while i < thread.positions.length
        Mirror_Rebaseline(thread.positions[i])
        i += 1
    endwhile
EndFunction

; Engine -> Effect_Mirror: SexLab's enjoyment follows ours (voices / expressions), after pulling in
; any change another plugin made to SexLab's enjoyment since the last mirror.
Function Mirror_Apply(Actor akActor, int value)
    if thread == None || akActor == None
        return
    endif
    sslActorAlias actorAlias = thread.ActorAlias(akActor)
    if actorAlias == None
        return
    endif
    int current = actorAlias.GetEnjoyment()
    int obj = GetObjFromActor(akActor)
    int baseline = -1
    String anim_key = ""
    if thread.Animation != None
        anim_key = thread.Animation.Registry
    endif
    if obj > 0
        baseline = SNSL_JMap.getInt(obj, "sl_mirror_set", -1)
        if SNSL_JMap.getInt(obj, "sl_mirror_stage", -1) != thread.Stage || SNSL_JMap.getStr(obj, "sl_mirror_anim", "") != anim_key
            baseline = -1
        endif
    endif
    if baseline >= 0
        int external = current - baseline
        if external >= MIRROR_EXTERNAL_THRESHOLD || external <= -MIRROR_EXTERNAL_THRESHOLD
            SkyrimNet_SexLab_OrgasmEngine.AddEnjoyment(akActor, external as float, "sexlab")
            value = SkyrimNet_SexLab_OrgasmEngine.GetEnjoyment(akActor) as int
            Trace("Mirror_Apply", GetDisplayName(akActor)+" external SexLab change "+external+" -> engine "+value)
        endif
    endif
    int delta = value - current
    if delta != 0
        actorAlias.AdjustEnjoyment(delta)
    endif
    if obj > 0
        SNSL_JMap.setInt(obj, "sl_mirror_set", actorAlias.GetEnjoyment())
        SNSL_JMap.setInt(obj, "sl_mirror_stage", thread.Stage)
        SNSL_JMap.setStr(obj, "sl_mirror_anim", anim_key)
        ; Not expected: re-voice when enjoyment crosses the gate either way.
        if SNSL_JMap.getInt(obj, "orgasm_expected", 1) == 0
            int above = (value >= VOICE_GATE_ENJOYMENT) as int
            if SNSL_JMap.getInt(obj, "voice_gate", -1) != above
                SNSL_JMap.setInt(obj, "voice_gate", above)
                ApplySexLabVoice(thread.Positions.Find(akActor))
            endif
        endif
    endif
    Arousal_Floor(akActor, value)
EndFunction

; ---- SLO Aroused NG / OSL Aroused (optional): arousal never below enjoyment ----
; Raise only: arousal above enjoyment is left alone; below it, exposure is raised by the gap.
slaFrameworkScr sla_fw = None
bool sla_checked = false

Function Arousal_Floor(Actor akActor, int enjoyment)
    if !sla_checked
        sla_checked = true
        if Game.GetModByName("SexLabAroused.esm") != 255 && SkyrimNetApi.GetConfigBool("Plugin_SkyrimNet_SexLab", "sexlab.arousal.floor_enjoyment", true)
            sla_fw = Game.GetFormFromFile(0x4290F, "SexLabAroused.esm") as slaFrameworkScr
        endif
    endif
    if sla_fw == None || akActor == None || sla_fw.IsActorArousalLocked(akActor)
        return
    endif
    int current = sla_fw.GetActorArousal(akActor)
    if enjoyment > current
        sla_fw.SetActorExposure(akActor, sla_fw.GetActorExposure(akActor) + (enjoyment - current))
        Trace("Arousal_Floor", GetDisplayName(akActor)+" arousal "+current+" -> "+enjoyment)
    endif
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
            ClearOrgasmStash()
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
    ApplyStyleSpeed()
    Engine_BeginScene()
    manager.SaveThreadsJson()
    String msg = GetIntentMessage(INTENT_STAGE_START) + GetDescription()
    RegisterEvent("sexlab update", msg, sender, receiver)
    ; Scene view showing Scene Creator for a target who just started animating -> Description Editor.
    WebUI_RerouteForFocus(true)
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
        Engine_SetSkills()
    endif
    ; Also covers actors joining / leaving (ChangeActors restarts at a stage).
    Engine_BeginScene()
    ; GoToStage reset SexLab's stage timer: keep a paused scene held.
    Pause_Hold()
    Ending_StageStart()
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
    ; Read once: the flags change across the yields below. A group mid-stash (orgasm_group_pending) or
    ; a NarrateOrgasmStash in progress sends its own DN; taking the stash here split one orgasm into two DNs.
    bool hold_stash = orgasm_messages_set && (orgasm_window_open || orgasm_group_pending || orgasm_narrating)
    if hold_stash
        Trace("StageStart", "--- holding orgasm stash window:"+orgasm_window_open+" group:"+orgasm_group_pending+" narrating:"+orgasm_narrating)
    elseif !orgasm_narrating && !orgasm_group_pending
        orgasm_narrating = true
        orgasm_narration = OrgasmMessagesToNarration()
        orgasm_narrating = false
    endif
    String desc = GetDescription()
    int cur_stage = thread.stage

    ; Send a DN if its a start and includes a player
    ; if not player send DN if allowed by cool off 
    ; GetDescription: stage JSON, else tag fallback (raw GetStageDescription alone leaves initiates: empty)
    if status != STATUS_ACTIVE
        status = STATUS_ACTIVE
        if hold_stash
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
            narration = "Scene changes to '"+desc+"'"
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
        if hold_stash
            if change_scene
                RegisterEventForce("change", narration, sender, receiver)
            endif
        elseif orgasm_narration != ""
            if change_scene
                RegisterEventForce("change", narration, sender, receiver)
            endif
        elseif IsFinalStage() && (gate_holding || ending_done || animdb.GetHasDescriptionOrgasmExpected(thread)[1])
            ; An orgasm / finish DN is coming (gate passed, ending reached, or someone expects one):
            ; no continue DN to race it, a scene change is an event.
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
        SendOrgasmOverflow(sender, receiver)
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

; "<speaker> [forcefully|gently] stops <intent>[, because <reason>]. " (no adverb for normally / stop).
; Parameters are stop_style, not style: `style` resolves to the Scene_Interface property (scene style).
String Function StopMessage(Actor speaker, String stop_style, String reason="")
    String how = ""
    if stop_style == "forcefully" || stop_style == "gently"
        how = stop_style+" "
    endif
    String what = intent
    if what == ""
        what = "the scene"
    endif
    String msg = GetDisplayName(speaker)+" "+how+"stops "+what
    if reason != ""
        msg += ", because "+reason
    endif
    return msg+". "
EndFunction

; stop_style (from Action_Stop): silently|silent → no DirectNarration; explain:<reason> → stop text with the
; reason; else stop text. "" (SexLab end event) → finish text only.
Function AnimationEnd(Actor speaker=None, String stop_style="")
    DbgEnter("AnimationEnd", "speaker:"+GetDisplayName(speaker)+" stop_style:"+stop_style)
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
        ClearStyleSpeed()

        ; Leftover Combined orgasm stash folded into the end DN so 0550 still gates
        ; (RegisterEvent-only leftover is invisible to contains(_direct_narration, ...)).
        String end_intent = GetIntentMessage(INTENT_STAGE_END)
        String orgasm_narration = OrgasmMessagesToNarration(StringUtil.GetLength(end_intent) + 1)

        ; Post-activity afterglow (individual orgasms: OrgasmEngine, or SexLab SeparateOrgasms); not ongoing sexual activity
        String afterglow = ""
        bool engine_managed = thread.positions.length > 0 && SkyrimNet_SexLab_OrgasmEngine.IsManaged(thread.positions[0])
        ; Read before EndScene drops the engine state.
        String fatigue = FatigueText()
        exhausted_actors = None
        if orgasm_hook_open
            orgasm_hook_open = false
            thread.SendThreadEvent("OrgasmEnd")
        endif
        scene_paused = false
        SkyrimNet_SexLab_OrgasmEngine.EndScene(sid)
        if config.SeparateOrgasms || engine_managed
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
        String end_message = end_intent
        if orgasm_narration != ""
            end_message = orgasm_narration + " " + end_message
        endif
        if fatigue != ""
            end_message += " " + fatigue
        endif
        if afterglow != ""
            ; Lowest priority of the end DN: over the budget it becomes an event.
            if StringUtil.GetLength(end_message) + 1 + StringUtil.GetLength(afterglow) <= NarrationMaxChars()
                end_message += " "+afterglow
            else
                orgasm_overflow += afterglow
            endif
        endif
        Bool skip_narration = (stop_style == "silently" || stop_style == "silent")
        if speaker != None && !skip_narration
            ; Stopped by someone (Action_Stop): "Bob gently stops <intent>[, because <reason>]. " + finish text.
            String reason = ""
            if StringUtil.GetLength(stop_style) > 8 && StringUtil.Substring(stop_style, 0, 8) == "explain:"
                reason = StringUtil.Substring(stop_style, 8, StringUtil.GetLength(stop_style) - 8)
            endif
            end_message = StopMessage(speaker, stop_style, reason) + end_message
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
            SendOrgasmOverflow(sender, receiver)
        endif
        orgasm_overflow = ""
    endif

    ; Scene view showing this scene's Description Editor -> Scene Creator (the target is no longer in a scene).
    WebUI_RerouteForFocus(false)

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
            StashOrgasm(i, thread.positions[i], ORGASM_KIND_ORGASM)
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

; Used for SLSO.esp / another plugin's SexLab orgasm (invoked from Manager as a Function call)
; from_engine: the OrgasmEngine already decided (a forced request may target a no_orgasm actor).
; Stashes and arms the window: the engine's group join for this orgasm (NoteExternalOrgasm) lands
; in the same window, so both are one DirectNarration.
Function OrgasmIndividual(Actor akActor, int full_enjoyment, int num_orgasms, bool from_engine = false)
    DbgEnter("OrgasmIndividual", "akActor:"+GetDisplayName(akActor)+" full_enjoyment:"+full_enjoyment+" num_orgasms:"+num_orgasms+" from_engine:"+from_engine)
    if akActor == None || thread == None
        Trace("OrgasmIndividual","akActor or thread is None")
        DbgReturn("OrgasmIndividual", "void")
        return
    endif

    String name = GetDisplayName(akActor)
    int obj = GetObjFromActor(akActor)
    if obj > 0 && !from_engine
        ; Only the deny blocks; not expected (no_orgasm) can still orgasm via the mini-game.
        if SNSL_JMap.getInt(obj, "deny_orgasm") == 1
            Trace("OrgasmIndividual",name+" orgasm denied")
            DbgReturn("OrgasmIndividual", "void")
            return
        endif
    endif

    EnsureActorArraysLargeEnough(thread.positions.length)
    int i = thread.positions.Find(akActor)
    if i < 0
        Trace("OrgasmIndividual", name+" not in thread.positions")
        DbgEnd("OrgasmIndividual")
        return
    endif
    ; SLSO sends an absolute count (num_orgasms >= 0).
    StashOrgasm(i, akActor, ORGASM_KIND_ORGASM, "", num_orgasms)
    ArmOrgasmWindow()
    DbgEnd("OrgasmIndividual")
EndFunction

; DOM melt (and the Description Editor button for unmanaged actors). The melt text is stashed as a
; key with {n} for the name, so slaves with the same text merge into one sentence, then the window
; joins it with the player / group joiners into one DirectNarration.
; ignore_no_orgasm: manual trigger (Description Editor orgasm button) narrates even when denied.
Function OrgasmCustom(Actor akActor, String msg, bool ignore_no_orgasm = false)
    DbgEnter("OrgasmCustom", "akActor:"+GetDisplayName(akActor)+" msg:"+msg+" ignore_no_orgasm:"+ignore_no_orgasm)

    ; DOM rolls its own orgasm and ignores SexLab DisableOrgasm; honor deny_orgasm.
    ; Not expected (no_orgasm) no longer blocks: it only stops passive gain.
    int obj = GetObjFromActor(akActor)
    if !ignore_no_orgasm && obj > 0 && SNSL_JMap.getInt(obj, "deny_orgasm") == 1
        Trace("OrgasmCustom", "--- "+GetDisplayName(akActor)+" orgasm denied, dropping")
        DbgEnd("OrgasmCustom")
        return
    endif
    if thread == None
        Trace("OrgasmCustom", "--- thread is None, aborting")
        DbgEnd("OrgasmCustom")
        return
    endif

    EnsureActorArraysLargeEnough(thread.positions.length)
    int i = thread.positions.Find(akActor)
    if i < 0
        Trace("OrgasmCustom", "--- actor not in thread.positions, stash skipped "+GetDisplayName(akActor))
        DbgEnd("OrgasmCustom")
        return
    endif
    String melt_key = MeltKey(akActor, msg)
    if melt_key != ""
        StashOrgasm(i, akActor, ORGASM_KIND_MELT, melt_key)
    else
        StashOrgasm(i, akActor, ORGASM_KIND_ORGASM)
    endif
    Trace("OrgasmCustom", "--- stash "+GetDisplayName(akActor)+" slot:"+i+" key:"+melt_key)
    ArmOrgasmWindow()
    DbgEnd("OrgasmCustom")
EndFunction

; Narration budget (sexlab.narration.max_chars): DirectNarration text past it moves its lowest-priority
; parts into one event (SendOrgasmOverflow).
int Function NarrationMaxChars()
    if main && main.narration_max_chars > 0
        return main.narration_max_chars
    endif
    return 350
EndFunction

; Appends part when it fits the budget, else queues it for the overflow event.
String Function FitOrOverflow(String text, String part, int budget)
    if part == ""
        return text
    endif
    String sep = ""
    if text != "" && StringUtil.GetNthChar(text, StringUtil.GetLength(text) - 1) != " "
        sep = " "
    endif
    if StringUtil.GetLength(text) + StringUtil.GetLength(sep) + StringUtil.GetLength(part) <= budget
        return text + sep + part
    endif
    if orgasm_overflow != ""
        orgasm_overflow += " "
    endif
    orgasm_overflow += part
    return text
EndFunction

; The one orgasm message for everything stashed (see docs/reference/orgasm-narration.md, message table).
; Each actor is in one state; names in a state are joined "A" / "A and B" / "A, B, and C".
; Always in the DN: allow prefix, forced, DOM melt, orgasming, denied. While the budget allows
; (reserve = room the caller needs): cum, recovering / not orgasming, folded arouse / calm.
; The rest is left in orgasm_overflow for SendOrgasmOverflow. "" when nobody orgasmed.
String Function OrgasmMessagesToNarration(int reserve = 0)
    orgasm_overflow = ""
    if thread == None || !orgasm_messages_set || !orgasm_messages
        orgasm_prefix = ""
        orgasm_extras = ""
        return ""
    endif
    orgasm_messages_set = false
    int n = thread.positions.length
    if n > orgasm_messages.length
        n = orgasm_messages.length
    endif
    if n < 1
        orgasm_prefix = ""
        orgasm_extras = ""
        return ""
    endif
    EnsureActorArraysLargeEnough(n)
    int[] orgasm_expected = animdb.GetOrgasmExpected(thread)
    String player_name = GetDisplayName(Game.GetPlayer())

    String[] forced_names = Utility.CreateStringArray(n)
    String[] orgasm_names = Utility.CreateStringArray(n)
    String[] again_names = Utility.CreateStringArray(n)
    String[] denied_names = Utility.CreateStringArray(n)
    String[] denied_by = Utility.CreateStringArray(n)
    int[] denied_band = Utility.CreateIntArray(n)
    String[] recovering_names = Utility.CreateStringArray(n)
    String[] idle_names = Utility.CreateStringArray(n)
    int[] idle_band = Utility.CreateIntArray(n)
    int forced_n = 0
    int orgasm_n = 0
    int again_n = 0
    int denied_n = 0
    int recovering_n = 0
    int idle_n = 0
    Actor recovering_one = None
    String legacy = ""
    String dom_not = ""
    bool orgasm_happened = false
    bool ejaculation_happened = false

    int k = 0
    while k < n
        ; position_objs, not actors_objs: actors_objs holds snapshots, so MarkOrgasmNarrated's
        ; orgasm_narrated write would be lost on the next relink.
        int obj = 0
        if k < position_objs.length
            obj = position_objs[k]
        endif
        Actor a = thread.positions[k]
        String name = SNSL_JMap.getStr(obj, "name")
        if name == ""
            name = GetDisplayName(a)
        endif
        int kind = orgasm_kinds[k]
        bool fired = orgasm_messages[k] != ""
        bool dom_unspoken = false
        if !fired && orgasm_expected.length > k && orgasm_expected[k] == 1 && SNSL_JMap.getInt(obj, "dom_slave") == 1
            ; Dom Combined fallback: custom raced empty this window (unspoken total bump).
            int total = GetTotalOrgasms(a)
            if total < 1
                total = SNSL_JMap.getInt(obj, "total_orgasm")
            endif
            if total > SNSL_JMap.getInt(obj, "orgasm_narrated")
                dom_unspoken = true
            endif
        endif

        if fired || dom_unspoken
            orgasm_happened = true
            ; Totals were bumped when the slot was stashed.
            if SNSL_JMap.getInt(obj, "has_penis") == 1
                ejaculation_happened = true
            endif
            if kind == ORGASM_KIND_FORCED
                forced_names[forced_n] = name
                forced_n += 1
            elseif kind == ORGASM_KIND_NONE && fired
                ; Legacy verbatim text (older stash).
                legacy += orgasm_messages[k]
            elseif kind == ORGASM_KIND_AGAIN || (kind != ORGASM_KIND_ORGASM && GetTotalOrgasms(a) > 1)
                again_names[again_n] = name
                again_n += 1
            else
                orgasm_names[orgasm_n] = name
                orgasm_n += 1
            endif
            ; Melt slots keep their key for the melt pass below.
            if kind != ORGASM_KIND_MELT
                orgasm_messages[k] = ""
                orgasm_kinds[k] = 0
            endif
            MarkOrgasmNarrated(obj, a)
        elseif SNSL_JMap.getInt(obj, "deny_orgasm") == 1
            String by = SNSL_JMap.getStr(obj, "deny_by")
            if by == ""
                by = player_name
            endif
            denied_names[denied_n] = name
            denied_by[denied_n] = by
            denied_band[denied_n] = EnjoymentBand(LiveEnjoyment(a))
            denied_n += 1
        elseif orgasm_expected.length > k && orgasm_expected[k] == 1 && SNSL_JMap.getInt(obj, "dom_slave") == 1 && GetTotalOrgasms(a) < 1 && SNSL_JMap.getInt(obj, "total_orgasm") < 1
            dom_not += main.handler_dom.HandleOrgasmDenied(a)
        elseif GetTotalOrgasms(a) > 0
            recovering_names[recovering_n] = name
            recovering_n += 1
            recovering_one = a
        else
            idle_names[idle_n] = name
            idle_band[idle_n] = EnjoymentBand(LiveEnjoyment(a))
            idle_n += 1
        endif
        k += 1
    endwhile

    ; DOM melts: one sentence per distinct melt text, {n} -> every slave who melted with it.
    String melts = ""
    int m = 0
    while m < n
        if orgasm_kinds[m] == ORGASM_KIND_MELT && orgasm_messages[m] != ""
            String melt_key = orgasm_messages[m]
            String[] melt_names = Utility.CreateStringArray(n)
            int melt_n = 0
            int j = m
            while j < n
                if orgasm_kinds[j] == ORGASM_KIND_MELT && orgasm_messages[j] == melt_key
                    String melt_name = SNSL_JMap.getStr(position_objs[j], "name")
                    if melt_name == ""
                        melt_name = GetDisplayName(thread.positions[j])
                    endif
                    melt_names[melt_n] = melt_name
                    melt_n += 1
                    orgasm_messages[j] = ""
                    orgasm_kinds[j] = 0
                endif
                j += 1
            endwhile
            melts += ReplaceAll(melt_key, "{n}", JoinNames(melt_names, melt_n)) + ". "
        endif
        m += 1
    endwhile

    ; Denied, grouped by who denied them and enjoyment band (BandLeadIn).
    String denied = ""
    int d = 0
    while d < denied_n
        if denied_by[d] != ""
            String denier = denied_by[d]
            int band = denied_band[d]
            String[] group = Utility.CreateStringArray(denied_n)
            int group_n = 0
            int e = d
            while e < denied_n
                if denied_by[e] == denier && denied_band[e] == band
                    group[group_n] = denied_names[e]
                    group_n += 1
                    denied_by[e] = ""
                endif
                e += 1
            endwhile
            denied += BandLeadIn(band) + NamesClause(group, group_n, "was denied an orgasm by "+denier+".", "were denied an orgasm by "+denier+".")
        endif
        d += 1
    endwhile

    String must = orgasm_prefix
    must += NamesClause(forced_names, forced_n, "is forced to orgasm by "+player_name+".", "are forced to orgasm by "+player_name+".")
    must += melts
    must += NamesClause(orgasm_names, orgasm_n, "is orgasming.", "are orgasming.")
    must += NamesClause(again_names, again_n, "is orgasming. again.", "are orgasming again.")
    must += legacy
    if orgasm_happened && thread.Animation != None && thread.Animation.HasTag("tentacles")
        must += "The tentacles is orgasming and flooding cum both inside and outside. "
    endif
    must += denied

    String others = ""
    if recovering_n == 1
        others += recovering_names[0]+" is recovering from "+PossessivePronoun(recovering_one)+" orgasm. "
    else
        others += NamesClause(recovering_names, recovering_n, "", "are recovering from their orgasms.")
    endif
    ; Not orgasming, one sentence per enjoyment band, lowest first (BandLeadIn).
    int band_i = 0
    while band_i < 4
        String[] band_names = Utility.CreateStringArray(n)
        int band_n = 0
        int b = 0
        while b < idle_n
            if idle_band[b] == band_i
                band_names[band_n] = idle_names[b]
                band_n += 1
            endif
            b += 1
        endwhile
        if band_n > 0
            others += BandLeadIn(band_i) + NamesClause(band_names, band_n, "is not orgasming right now.", "are not orgasming right now.")
        endif
        band_i += 1
    endwhile
    others += dom_not

    String cum = ""
    if ejaculation_happened
        int i = 0
        while i < n
            String cum_msg = AddCum(i, thread.positions[i], thread.positions[i].GetDisplayName())
            if cum_msg != ""
                if cum != "" && StringUtil.GetNthChar(cum, StringUtil.GetLength(cum) - 1) != " "
                    cum += " "
                endif
                cum += cum_msg
            endif
            i += 1
        endwhile
    endif

    String extras = orgasm_extras
    orgasm_prefix = ""
    orgasm_extras = ""
    if !orgasm_happened
        return ""
    endif
    int budget = NarrationMaxChars() - reserve
    String narration = must
    narration = FitOrOverflow(narration, cum, budget)
    narration = FitOrOverflow(narration, others, budget)
    narration = FitOrOverflow(narration, extras, budget)
    return narration
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
    if akActor != None
        StorageUtil.SetIntValue(akActor, storage_orgasm_narrated_key, spoken)
    endif
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
    if ending_holding || gate_holding
        RegisterForSingleUpdate(1.0)
    endif
    orgasm_window_open = false
    orgasm_window_started_at = 0.0
    if thread == None
        Trace("FlushOrgasmWindow", "--- thread is None, clearing stash")
        ClearOrgasmStash()
        gate_pending_force = false
        gate_pending_notify = false
        return
    endif
    bool force = gate_pending_force
    gate_pending_force = false
    bool sent = NarrateOrgasmStash(sender, receiver, force)
    if sent && gate_pending_notify
        gate_pending_notify = false
        SkyrimNet_SexLab_OrgasmEngine.GateNarrationSent(sid)
    endif
EndFunction

; One DirectNarration for everything stashed, then the parts that did not fit as one event.
; force_direct: always a DirectNarration, NPC-only scenes too (gate pass: the voice times the stage).
; Returns true once the narration actually went out (false: deferred to the window, or nothing stashed).
bool Function NarrateOrgasmStash(Actor source, Actor target, bool force_direct = false)
    ; Two groups narrating at once interleave on the slot arrays (external calls yield): the later
    ; one leaves its stash for the window. A deferred force_direct must survive to that flush.
    if orgasm_narrating
        Trace("NarrateOrgasmStash", "--- busy, stash goes to the window")
        gate_pending_force = gate_pending_force || force_direct
        ArmOrgasmWindow()
        return false
    endif
    orgasm_narrating = true
    ; Match StageStart / AnimationEnd: keep actors_objs aligned with positions
    ; before OrgasmMessagesToNarration reads names / orgasm_narrated.
    AlignActors()
    String orgasm_narration = OrgasmMessagesToNarration()
    if orgasm_narration == ""
        orgasm_narrating = false
        Trace("NarrateOrgasmStash", "--- empty stash")
        return false
    endif
    Trace("NarrateOrgasmStash", "--- "+orgasm_narration+" | overflow: "+orgasm_overflow)
    if has_player || force_direct
        DirectNarration(orgasm_narration, source, target, purge_dialogue=has_player)
    else
        DirectNarration_Optional("orgasm", orgasm_narration, source, target)
    endif
    SendOrgasmOverflow(source, target)
    orgasm_narrating = false
    return true
EndFunction

; Lower-priority orgasm parts (cum, not orgasming, arouse / calm) that did not fit the DN budget.
; Never holds an orgasm gate string, so CheckDuplicate cannot blank the DN it follows.
Function SendOrgasmOverflow(Actor source, Actor target)
    if orgasm_overflow == ""
        return
    endif
    String overflow = orgasm_overflow
    orgasm_overflow = ""
    RegisterEvent("sexlab update", overflow, source, target)
EndFunction

; Final stage ending within the window's cap (2x orgasm_delay from its start): keep the stash for
; AnimationEnd, which folds it into the finish DN. Past the cap the next OnUpdate flushes.
bool Function OrgasmWindow_HoldForFinish()
    if !orgasm_window_open || ending_holding || gate_holding || !IsFinalStage() || orgasm_window_started_at <= 0.0
        return false
    endif
    float remaining = SkyrimNet_SexLab_OrgasmEngine.FinalStageRemaining(sid)
    if remaining < 0.0
        return false
    endif
    float elapsed = Utility.GetCurrentRealTime() - orgasm_window_started_at
    if elapsed + remaining + 1.0 > GetOrgasmDelay() * 2.0
        return false
    endif
    Trace("OnUpdate", "--- holding orgasm window for finish remaining:"+remaining+" elapsed:"+elapsed)
    RegisterForSingleUpdate(remaining + 1.0)
    return true
EndFunction

Event OnUpdate()
    if Utility.IsInMenuMode()
        RegisterForSingleUpdate(0.5)
        Trace("OnUpdate", "--- orgasm window waiting on menu")
        return
    endif
    ; Shared with the scene-ending dialogue hold poll and the gate voice wait.
    if orgasm_window_open || (!ending_holding && !gate_holding)
        if !orgasm_messages_set
            orgasm_window_open = false
            orgasm_window_started_at = 0.0
            Trace("OnUpdate", "--- orgasm window empty, skip")
        elseif !OrgasmWindow_HoldForFinish()
            Trace("OnUpdate", "--- flushing orgasm window")
            FlushOrgasmWindow()
        endif
    endif
    if gate_holding
        Gate_Poll()
    endif
    if ending_holding
        Ending_Poll()
    endif
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
        ; Remember where for the character bio (0416_sexlab_cum.prompt).
        bool on_mouth = cumId == sslObjectFactory.oral() || cumId == sslObjectFactory.VaginalOral() || cumId == sslObjectFactory.OralAnal() || cumId == sslObjectFactory.VaginalOralAnal()
        bool on_pussy = has_pussy && (cumId == sslObjectFactory.vaginal() || cumId == sslObjectFactory.VaginalOral() || cumId == sslObjectFactory.VaginalAnal() || cumId == sslObjectFactory.VaginalOralAnal())
        bool on_ass = cumId == sslObjectFactory.anal() || cumId == sslObjectFactory.VaginalAnal() || cumId == sslObjectFactory.OralAnal() || cumId == sslObjectFactory.VaginalOralAnal()
        SkyrimNet_SexLab_Decorators.RecordCum(akActor, on_mouth, on_pussy, on_ass)
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
        ; Live OrgasmEngine enjoyment for sexlab_get_threads / 0050 prompt.
        if i < position_objs.length && position_objs[i] > 0 && SkyrimNet_SexLab_OrgasmEngine.IsManaged(thread.positions[i])
            SNSL_JMap.setInt(position_objs[i], "enjoyment", SkyrimNet_SexLab_OrgasmEngine.GetEnjoyment(thread.positions[i]) as int)
            ; Mini-game NPC strategy phrase ("focuses on self enjoyment"); "" in Together mode.
            SNSL_JMap.setStr(position_objs[i], "strategy", SkyrimNet_SexLab_OrgasmEngine.GetStrategyText(thread.positions[i]))
            ; Stamina regen, percent of default (0550 tiredness tiers).
            SNSL_JMap.setInt(position_objs[i], "stamina_regen", SkyrimNet_SexLab_OrgasmEngine.GetStaminaRegen(thread.positions[i]) as int)
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
    SNSL_JMap.SetStr(thread_obj, "speed", GetSpeedName())
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

; ------------------------------------------------------
; Style -> animation speed. Playback rate only: SexLab stage timers,
; orgasm window and voices keep real-time timing.
; ------------------------------------------------------
Function SetStyle(String _style)
    parent.SetStyle(_style)
    ApplyStyleSpeed()
EndFunction

float Function GetStyleSpeed()
    if !SkyrimNetApi.GetConfigBool("Plugin_SkyrimNet_SexLab", "sexlab.speed.enabled", true)
        return 1.0
    endif
    if style == STYLE_GENTLY
        return SkyrimNetApi.GetConfigFloat("Plugin_SkyrimNet_SexLab", "sexlab.speed.gently", 0.75)
    elseif style == STYLE_FORCEFULLY
        return SkyrimNetApi.GetConfigFloat("Plugin_SkyrimNet_SexLab", "sexlab.speed.forcefully", 1.25)
    endif
    return SkyrimNetApi.GetConfigFloat("Plugin_SkyrimNet_SexLab", "sexlab.speed.normally", 1.0)
EndFunction

; Speed level (OrgasmEngine) of the scene's effective animation speed: style speed x HUD slower/faster.
; 0 gentle, 1 normal, 2 forceful. No thread: from the style.
int Function GetSpeedLevel()
    if thread != None && thread.positions.length > 0 && thread.positions[0] != None
        return SkyrimNet_SexLab_OrgasmEngine.GetSpeedLevel(thread.positions[0])
    endif
    if style == STYLE_GENTLY
        return 0
    elseif style == STYLE_FORCEFULLY
        return 2
    endif
    return 1
EndFunction

String Function GetSpeedName()
    int level = GetSpeedLevel()
    if level == 0
        return "gentle"
    elseif level == 2
        return "forceful"
    endif
    return "normal"
EndFunction

String Function GetSpeedAdverb()
    int level = GetSpeedLevel()
    if level == 0
        return "gently"
    elseif level == 2
        return "forcefully"
    endif
    return ""
EndFunction

; Same multiplier for every position keeps paired animations in sync.
Function ApplyStyleSpeed()
    if thread == None
        return
    endif
    float speed = GetStyleSpeed()
    Actor[] positions = thread.positions
    int i = 0
    while i < positions.length
        if positions[i] != None
            SkyrimNet_SexLab_Utilities.SetAnimSpeed(positions[i], speed)
        endif
        i += 1
    endwhile
    Trace("ApplyStyleSpeed", "style:"+style+" speed:"+speed+" actors:"+positions.length)
EndFunction

Function ClearStyleSpeed()
    if thread == None
        return
    endif
    Actor[] positions = thread.positions
    int i = 0
    while i < positions.length
        if positions[i] != None
            SkyrimNet_SexLab_Utilities.ClearAnimSpeed(positions[i])
        endif
        i += 1
    endwhile
EndFunction

; LLM action / style hotkey: change style mid-scene with one DirectNarration.
Function ChangeStyle(Actor who, String _style)
    String style_old = style
    SetStyle(_style)
    if style_old == style
        return
    endif
    ; HUD faster/slower is relative to the style: back to 1.0 on a style change.
    if thread != None && thread.positions.length > 0
        SkyrimNet_SexLab_OrgasmEngine.ResetSpeedScale(thread.positions[0])
    endif
    if orgasm_messages_set
        Trace("ChangeStyle", "--- skipping style DN, orgasm window open")
        return
    endif
    DirectNarration(GetDisplayName(who)+" changes from '"+style_old+"' to '"+style+"'", sender, receiver)
EndFunction

Function SetStyleDialog()
    DbgEnter("SetStyleDialog")
    String style_old = style
    parent.SetStyleDialog()
    ApplyStyleSpeed()

    if style_old != style
        if thread != None && thread.positions.length > 0
            SkyrimNet_SexLab_OrgasmEngine.ResetSpeedScale(thread.positions[0])
        endif
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

; Same object as the Scene Menu push (BuildWebUISceneMenuObject carries the Description
; Editor fields), so one build serves both views.
String Function BuildWebUIAnimationMenuState()
    if thread == None
        return "{}"
    endif
    return BuildWebUISceneMenuState()
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
    Bool any_victim_change = false
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
            SetOrgasmDisabled(positions[i], SNSL_JMap.getInt(position_objs[i], "deny_orgasm") == 1)
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
                any_victim_change = true
            endif
        endif
        i += 1
    endwhile
    ; SetPosition above ran SetActor before this call's SetVictim, so victim/assailant are stale.
    if any_victim_change
        RefreshVictimRoles()
    endif
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
        ; no_orgasm may have changed: passive gain + voice gate follow.
        Engine_SetSkills()
        ApplySexLabVoices()
        MarkUserDefaultsDirty()
    endif
EndFunction

; After a live thread.SetVictim: victim faction + num_victims, per-position victim/assailant
; (same rule as SetActor), and the victim/assailant name strings. Does not touch `initiator`.
Function RefreshVictimRoles()
    if thread == None
        return
    endif
    ReconcileVictimFactions()
    Actor[] positions = thread.Positions
    int i = 0
    while positions && i < positions.length && i < position_objs.length
        int obj = position_objs[i]
        if positions[i] != None && obj > 0
            if thread.IsVictim(positions[i])
                SNSL_JMap.setInt(obj, "victim", 1)
                SNSL_JMap.setInt(obj, "assailant", 0)
            elseif num_victims > 0
                SNSL_JMap.setInt(obj, "victim", 0)
                SNSL_JMap.setInt(obj, "assailant", 1)
            else
                SNSL_JMap.setInt(obj, "victim", 0)
                SNSL_JMap.setInt(obj, "assailant", 0)
            endif
        endif
        i += 1
    endwhile
    SetNames()
EndFunction

; TargetMenu victim toggle on a live scene actor.
Function TM_ApplyVictim(Actor akActor, Bool isVictim)
    if thread == None || akActor == None || thread.Positions.Find(akActor) < 0
        return
    endif
    Bool wasVictim = thread.IsVictim(akActor)
    thread.SetVictim(akActor, isVictim)
    RefreshVictimRoles()
    if wasVictim != isVictim
        NarrateVictimToggle(akActor, isVictim)
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
        ; Description Editor fields (this object also feeds Animation_Menu_Configure).
        SNSL_JMap.setStr(obj, "_registry", active_reg)
        SNSL_JMap.setStr(obj, "_anim_name", thread.animation.name)
        SNSL_JMap.setStr(obj, "_tags", GetTagsString(thread.animation))
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
    ; Description Editor style pulldown: style + speed + one style-change DirectNarration.
    String new_style = JMap.getStr(obj, "_style", "")
    ; Description Editor orgasm button: thread position index.
    int orgasm_pos = JMap.getInt(obj, "_orgasm_pos", -1)
    ; Description Editor deny column: thread position index.
    int deny_pos = JMap.getInt(obj, "_deny_pos", -1)
    JValue.release(obj)
    if orgasm_pos >= 0
        WebUI_ForceOrgasm(orgasm_pos)
        return
    endif
    if deny_pos >= 0
        if thread != None && deny_pos < thread.Positions.length
            ToggleDenyOrgasm(thread.Positions[deny_pos])
        endif
        return
    endif
    if new_style != ""
        Actor who = sender
        if has_player
            who = Game.GetPlayer()
        endif
        ChangeStyle(who, new_style)
        cancel_dirty = true
        return
    endif
    if text == ""
        return
    endif
    DirectNarration("The scene changes to "+text, sender, receiver)
EndFunction

; HUD PosUp / PosDn (PgUp / PgDn): SexLab's swap positions. sexlab.hud.pos_narration narrates the
; current stage description with the actors in their new roles, worded like "continue scene".
Function HotkeyChangePositions(bool backwards)
    if thread == None
        return
    endif
    Actor[] before = PapyrusUtil.ActorArray(thread.Positions.length)
    int i = 0
    while i < before.length
        before[i] = thread.Positions[i]
        i += 1
    endwhile
    thread.ChangePositions(backwards)
    bool changed = false
    i = 0
    while i < before.length && !changed
        if i >= thread.Positions.length || before[i] != thread.Positions[i]
            changed = true
        endif
        i += 1
    endwhile
    if !changed
        Trace("HotkeyChangePositions", "no change (solo / creature) backwards:"+backwards)
        return
    endif
    AlignActors()
    if !SkyrimNetApi.GetConfigBool("Plugin_SkyrimNet_SexLab", "sexlab.hud.pos_narration", true)
        return
    endif
    String desc = GetDescription()
    if desc != ""
        DirectNarration("The scene changes to "+desc, sender, receiver)
    endif
EndFunction

; Player orgasm denial toggle (HUD deny key, Description Editor deny column).
Function ToggleDenyOrgasm(Actor akActor)
    int obj = GetObjFromActor(akActor)
    if obj <= 0
        Trace("ToggleDenyOrgasm", "no obj")
        return
    endif
    SetDenyOrgasm(akActor, SNSL_JMap.getInt(obj, "deny_orgasm") != 1, Game.GetPlayer())
EndFunction

; Orgasm denial: the player (HUD / Description Editor / TargetMenu) or an aggressor NPC (LLM actions
; SexLab_DenyOrgasm / SexLab_AllowOrgasm). Scene state, not animation metadata: survives animation
; changes. The denied actor gains enjoyment as normal but cannot orgasm.
; Allow (1 -> 0) tests akActor with the normal orgasm rule and checks every other actor at once
; (OrgasmEngine.AllowOrgasm): when anyone orgasms, the group's normal orgasm DN starts
; "<denier> allowed <actor> to orgasm. "; otherwise the plain allow is narrated.
; The plain deny / allow is always an event ("<denier> forbids <actor> from orgasming without
; permission." / "<denier> permits <actor> to orgasm."), never a DN. from_llm is informational (trace only).
; narrate false: no plain deny / allow event (an orgasm on allow still narrates).
; Returns false when the state already matched (nothing changed).
bool Function SetDenyOrgasm(Actor akActor, bool deny, Actor denier, bool from_llm = false, bool narrate = true)
    int obj = GetObjFromActor(akActor)
    if thread == None || akActor == None || obj <= 0
        Trace("SetDenyOrgasm", "no thread / actor / obj")
        return false
    endif
    if denier == None
        denier = Game.GetPlayer()
    endif
    if (SNSL_JMap.getInt(obj, "deny_orgasm") == 1) == deny
        Trace("SetDenyOrgasm", GetDisplayName(akActor)+" already deny:"+deny)
        return false
    endif
    SNSL_JMap.setInt(obj, "deny_orgasm", deny as int)
    String msg = ""
    bool fired = false
    if deny
        SNSL_JMap.setStr(obj, "deny_by", GetDisplayName(denier))
        SetOrgasmDisabled(akActor, true)
        msg = GetDisplayName(denier)+" forbids "+GetDisplayName(akActor)+" from orgasming without permission."
    else
        SNSL_JMap.setStr(obj, "deny_by", "")
        thread.DisableOrgasm(akActor, false)
        SkyrimNet_SexLab_OrgasmEngine.SetDomSlave(akActor, main.handler_dom.IsDOMSlave(akActor))
        ; Unblocks in the engine, tests akActor with the normal orgasm rule and fires anyone else at
        ; 100 (+ the group join) in one step.
        fired = SkyrimNet_SexLab_OrgasmEngine.AllowOrgasm(akActor, denier)
        msg = GetDisplayName(denier)+" permits "+GetDisplayName(akActor)+" to orgasm."
    endif
    PersistPositions()
    manager.SaveThreadsJson()
    Trace("SetDenyOrgasm", GetDisplayName(akActor)+" deny:"+deny+" by:"+GetDisplayName(denier)+" fired:"+fired+" llm:"+from_llm)
    if fired || !narrate
        ; The group orgasm DN carries the allow prefix.
        return true
    endif
    RegisterEvent("sexlab update", msg, denier, akActor)
    return true
EndFunction

; SexLab ForceOrgasm only sends SexLabOrgasm (never HookOrgasmStart), so the event path narrates only
; with SeparateOrgasms on, a non-DOM-slave actor and no_orgasm off. Otherwise narrate via OrgasmCustom.
Function WebUI_ForceOrgasm(int pos)
    if thread == None || pos < 0 || pos >= thread.Positions.length
        Trace("WebUI_ForceOrgasm", "no thread or bad pos:"+pos)
        return
    endif
    Actor a = thread.Positions[pos]
    if a == None
        Trace("WebUI_ForceOrgasm", "no actor at pos:"+pos)
        return
    endif
    ; The WebUI is all-powerful: a forced request skips every engine gate (no_orgasm, cooldown, edge).
    ; The engine fires on its next tick -> Effect_OrgasmGroup -> Orgasm_ApplyGroup (ForceOrgasm + group join + one narration).
    if SkyrimNet_SexLab_OrgasmEngine.IsManaged(a)
        Trace("WebUI_ForceOrgasm", GetDisplayName(a)+" pos:"+pos+" -> OrgasmEngine forced request")
        SkyrimNet_SexLab_OrgasmEngine.RequestOrgasm(a, true, "webui")
        return
    endif
    Trace("WebUI_ForceOrgasm", GetDisplayName(a)+" pos:"+pos+" not managed, OrgasmCustom")
    thread.ForceOrgasm(a)
    OrgasmCustom(a, "", true)
EndFunction

Function WebUI_OnAnimUpdate(String json)
    if thread == None
        return
    endif
    int obj = JValue.objectFromPrototype(json)
    if obj == 0
        return
    endif
    ; Description Editor actor table: live scene values only (Save writes them to disk).
    if JMap.hasKey(obj, "_positions")
        WebUI_ApplyLivePositions(obj, true)
        cancel_dirty = true
    endif
    ; Description Editor Load: back to the animation's AnimDB defaults, re-dressing included.
    if JMap.getInt(obj, "_reload_defaults", 0) == 1 && thread.animation
        ClearUserAnimDefaults(thread.animation.Registry)
        ReloadAnimationDefaults(false)
        Engine_SetSkills()
        ApplySexLabVoices()
        cancel_dirty = true
        WebUI_ConfigureIfOverlayVisible()
    endif
    String next_reg = JMap.getStr(obj, "_next_registry", "")
    JValue.release(obj)
    if next_reg == ""
        return
    endif
    WebUI_SwitchToRegistry(next_reg, true)
EndFunction

; DEBUG-DELETE: raw SexLab thread.Animations dump, "len:N forced:F [reg,None,...]".
String Function DbgAnimList()
    if thread == None
        return "no thread"
    endif
    sslBaseAnimation[] anims = thread.Animations
    int n = 0
    if anims
        n = anims.length
    endif
    sslBaseAnimation[] forced = thread.GetForcedAnimations()
    int nf = 0
    if forced
        nf = forced.length
    endif
    String s = "len:"+n+" forced:"+nf+" ["
    int i = 0
    while i < n
        if i > 0
            s += ","
        endif
        if anims[i]
            s += anims[i].Registry
        else
            s += "None"
        endif
        i += 1
    endwhile
    return s+"]"
EndFunction
; DEBUG-DELETE end

; Makes reg the playing animation: SetAnimation when the thread already has it, else appends it to a
; rebuilt list (at SexLab's 128 cap, evicts an unplayed non-active entry first). reseed: reload the new animation's
; orgasm/speaking defaults, dressing only toward undressed, and narrate the change (CheckAnimationChange).
; Otherwise only record it (NoteSeededRegistry), for callers that already applied their own choices.
bool Function WebUI_SwitchToRegistry(String reg, bool reseed)
    if thread == None || reg == "" || !sexlab
        return false
    endif
    sslBaseAnimation next_anim = sexlab.GetAnimationByRegistry(reg)
    if next_anim == None
        Trace("WebUI_SwitchToRegistry", "unknown registry:"+reg, true)
        return false
    endif
    Trace("WebUI_SwitchToRegistry", "DEBUG before "+reg+" "+DbgAnimList()) ; DEBUG-DELETE
    sslBaseAnimation[] cur = thread.Animations
    int idx = -1
    int i = 0
    while cur && i < cur.length
        if cur[i] && cur[i].Registry == reg
            idx = i
        endif
        i += 1
    endwhile
    if idx < 0
        ; Never thread.AddAnimation: SexLab's MergeAnimationLists overwrites index 0 and leaves a None
        ; tail (KNOWLEDGEBASE), and it only writes PrimaryAnimations, which a forced list hides. Rebuild
        ; the list instead: drop None slots, evict at the 128 cap, append the new animation last.
        int len = 0
        if cur
            len = cur.length
        endif
        int kept = 0
        i = 0
        while i < len
            if cur[i]
                kept += 1
            endif
            i += 1
        endwhile
        int evict = -1
        if kept >= 128
            String active_now = ""
            if thread.animation
                active_now = thread.animation.Registry
            endif
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
                Trace("WebUI_SwitchToRegistry", "cannot evict at cap", true)
                return false
            endif
            kept -= 1
        endif
        sslBaseAnimation[] rebuilt = sslUtility.AnimationArray(kept + 1)
        int w = 0
        i = 0
        while i < len
            if cur[i] && i != evict
                rebuilt[w] = cur[i]
                w += 1
            endif
            i += 1
        endwhile
        rebuilt[w] = next_anim
        sslBaseAnimation[] forced = thread.GetForcedAnimations()
        if forced && forced.length > 0
            thread.SetForcedAnimations(rebuilt)
        else
            thread.SetAnimations(rebuilt)
        endif
        cur = thread.Animations
        i = 0
        while cur && i < cur.length
            if cur[i] && cur[i].Registry == reg
                idx = i
            endif
            i += 1
        endwhile
    endif
    if idx < 0
        Trace("WebUI_SwitchToRegistry", "add failed:"+reg, true)
        return false
    endif
    int anim_count = 0
    if thread.Animations
        anim_count = thread.Animations.length
    endif
    Trace("WebUI_SwitchToRegistry", "DEBUG after rebuild idx:"+idx+" "+DbgAnimList()) ; DEBUG-DELETE
    thread.SetAnimation(idx)
    Trace("WebUI_SwitchToRegistry", "DEBUG after SetAnimation active:"+thread.animation.Registry+" "+DbgAnimList()) ; DEBUG-DELETE
    NotePlayedRegistry(reg)
    cancel_dirty = true
    if reseed
        CheckAnimationChange()
    else
        NoteSeededRegistry(reg)
    endif
    Trace("WebUI_SwitchToRegistry", reg+" idx:"+idx+" anims:"+anim_count+" reseed:"+reseed)
    WebUI_ConfigureIfOverlayVisible()
    return true
EndFunction

; -------------------------------------------------
; WebUI Cancel snapshot
;
; Taken when the overlay opens (Menu.WebUI_SeedSceneInfos). WebUI Cancel sends _restore_snapshot and
; the scene goes back to it: animation list, playing animation, stage, style, per-actor orgasm/
; speaking/dressed + locks, and anyone undressed since is re-dressed. Plain script arrays, no JSON
; store handles. cancel_dirty marks that a WebUI change landed since the snapshot (restore is a
; no-op otherwise).
; -------------------------------------------------
bool snap_valid = false
bool cancel_dirty = false
String[] snap_regs
bool snap_forced = false
String snap_active_reg = ""
int snap_stage = 0
String snap_style = ""
String snap_seeded = ""
Actor[] snap_actors
int[] snap_no_orgasm
int[] snap_deny
int[] snap_dressed
int[] snap_undressed
int[] snap_orgasm_locked
int[] snap_speaking_locked
int[] snap_dressed_locked
int[] snap_victim
String[] snap_speaking

Function WebUI_TakeCancelSnapshot()
    snap_valid = false
    cancel_dirty = false
    if thread == None || thread.animation == None
        return
    endif
    sslBaseAnimation[] forced = thread.GetForcedAnimations()
    snap_forced = forced && forced.length > 0
    sslBaseAnimation[] anims = thread.Animations
    int n = 0
    if anims
        n = anims.length
    endif
    snap_regs = PapyrusUtil.StringArray(n)
    int i = 0
    while i < n
        if anims[i]
            snap_regs[i] = anims[i].Registry
        endif
        i += 1
    endwhile
    snap_active_reg = thread.animation.Registry
    snap_stage = thread.stage
    snap_style = style
    snap_seeded = seeded_registry
    Actor[] positions = thread.positions
    int pn = 0
    if positions
        pn = positions.length
    endif
    snap_actors = PapyrusUtil.ActorArray(pn)
    snap_no_orgasm = PapyrusUtil.IntArray(pn)
    snap_deny = PapyrusUtil.IntArray(pn)
    snap_dressed = PapyrusUtil.IntArray(pn)
    snap_undressed = PapyrusUtil.IntArray(pn)
    snap_orgasm_locked = PapyrusUtil.IntArray(pn)
    snap_speaking_locked = PapyrusUtil.IntArray(pn)
    snap_dressed_locked = PapyrusUtil.IntArray(pn)
    snap_speaking = PapyrusUtil.StringArray(pn)
    snap_victim = PapyrusUtil.IntArray(pn)
    i = 0
    while i < pn
        Actor a = positions[i]
        snap_actors[i] = a
        if a && StorageUtil.HasIntValue(a, storage_undressed_key)
            snap_undressed[i] = 1
        endif
        if a && thread.IsVictim(a)
            snap_victim[i] = 1
        endif
        if position_objs && i < position_objs.length && position_objs[i] > 0
            int po = position_objs[i]
            snap_no_orgasm[i] = SNSL_JMap.getInt(po, "no_orgasm")
            snap_deny[i] = SNSL_JMap.getInt(po, "deny_orgasm")
            snap_dressed[i] = SNSL_JMap.getInt(po, "dressed")
            snap_orgasm_locked[i] = SNSL_JMap.getInt(po, "orgasm_locked")
            snap_speaking_locked[i] = SNSL_JMap.getInt(po, "speaking_locked")
            snap_dressed_locked[i] = SNSL_JMap.getInt(po, "dressed_locked")
            snap_speaking[i] = SpeakingCsvFromIndex(i)
        endif
        i += 1
    endwhile
    snap_valid = true
    Trace("WebUI_TakeCancelSnapshot", "anim:"+snap_active_reg+" stage:"+snap_stage+" anims:"+n+" actors:"+pn)
EndFunction

Function WebUI_RestoreCancelSnapshot()
    if !snap_valid || !cancel_dirty || thread == None
        Trace("WebUI_RestoreCancelSnapshot", "nothing to restore valid:"+snap_valid+" dirty:"+cancel_dirty)
        return
    endif
    ; Animation list + playing animation.
    int n = snap_regs.length
    sslBaseAnimation[] anims = sslUtility.AnimationArray(n)
    int w = 0
    int active_idx = -1
    int i = 0
    while i < n
        sslBaseAnimation a = None
        if snap_regs[i] != ""
            a = sexlab.GetAnimationByRegistry(snap_regs[i])
        endif
        if a
            anims[w] = a
            if snap_regs[i] == snap_active_reg
                active_idx = w
            endif
            w += 1
        endif
        i += 1
    endwhile
    if w > 0
        if w != n
            sslBaseAnimation[] trimmed = sslUtility.AnimationArray(w)
            i = 0
            while i < w
                trimmed[i] = anims[i]
                i += 1
            endwhile
            anims = trimmed
        endif
        if snap_forced
            thread.SetForcedAnimations(anims)
        else
            thread.SetAnimations(anims)
        endif
        if active_idx >= 0 && (thread.animation == None || thread.animation.Registry != snap_active_reg)
            thread.SetAnimation(active_idx)
        endif
    endif
    ; Record without reseeding or narrating: the values below are the ones to keep.
    seeded_registry = snap_seeded
    pending_animation_change = false
    if snap_style != "" && snap_style != style
        SetStyle(snap_style)
    endif
    ; Per-actor settings, matched by actor (not slot).
    Actor[] positions = thread.positions
    Bool victim_restored = false
    i = 0
    while i < snap_actors.length
        Actor a = snap_actors[i]
        int p = -1
        if a && positions
            p = positions.Find(a)
        endif
        if p >= 0 && position_objs && p < position_objs.length && position_objs[p] > 0
            int po = position_objs[p]
            SNSL_JMap.setInt(po, "no_orgasm", snap_no_orgasm[i])
            SNSL_JMap.setInt(po, "deny_orgasm", snap_deny[i])
            SNSL_JMap.setInt(po, "dressed", snap_dressed[i])
            SNSL_JMap.setInt(po, "orgasm_locked", snap_orgasm_locked[i])
            SNSL_JMap.setInt(po, "speaking_locked", snap_speaking_locked[i])
            SNSL_JMap.setInt(po, "dressed_locked", snap_dressed_locked[i])
            SetSpeakingObj(p, snap_speaking[i])
            SetOrgasmDisabled(a, snap_deny[i] == 1)
            if snap_undressed[i] == 0 && StorageUtil.HasIntValue(a, storage_undressed_key)
                ApplyDressedToActor(a, true)
            elseif snap_undressed[i] == 1 && !StorageUtil.HasIntValue(a, storage_undressed_key)
                ApplyDressedToActor(a, false)
            endif
            ; Description Editor V column: restore silently (no victim narration).
            if i < snap_victim.length && thread.IsVictim(a) != (snap_victim[i] == 1)
                thread.SetVictim(a, snap_victim[i] == 1)
                victim_restored = true
            endif
        endif
        i += 1
    endwhile
    if victim_restored
        RefreshVictimRoles()
    endif
    Engine_SetSkills()
    ApplySexLabVoices()
    PersistPositions()
    if snap_stage >= 1 && thread.animation && snap_stage != thread.stage && snap_stage <= thread.animation.StageCount()
        thread.GoToStage(snap_stage)
    endif
    cancel_dirty = false
    Trace("WebUI_RestoreCancelSnapshot", "anim:"+snap_active_reg+" stage:"+snap_stage+" style:"+snap_style)
EndFunction

Function ApplyWebUICommit(int obj)
    if obj == 0
        return
    endif
    ; WebUI Cancel: put the scene back the way it was when the overlay opened.
    if JMap.getInt(obj, "_restore_snapshot", 0) == 1
        WebUI_RestoreCancelSnapshot()
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
            if narration != "" && StringUtil.Find(stop_style, "explain:") != 0
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
        ReloadAnimationDefaults(false)
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
            cancel_dirty = true
            Trace("ApplyWebUICommit", "stage now:"+thread.stage)
        endif
        ; GoToStage sets thread.stage synchronously: show it in the editor now, not at StageStart.
        WebUI_PushStage()
    endif
    String active_reg = JMap.getStr(obj, "_active_registry", "")
    if active_reg == ""
        active_reg = JMap.getStr(obj, "_next_registry", "")
    endif
    if active_reg != "" && (thread.animation == None || thread.animation.Registry != active_reg)
        ; _reseed_defaults (Description Editor switch): the new animation's defaults replace the actors'
        ; orgasm/speaking, dressing only toward undressed. Without it (Scene Menu Update) the user's
        ; values above stand.
        WebUI_SwitchToRegistry(active_reg, JMap.getInt(obj, "_reseed_defaults", 0) == 1)
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
            speaking = SpeakingCsvFromIndex(i)
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
                if position_objs && i < position_objs.length && position_objs[i] > 0
                    SNSL_JMap.setInt(position_objs[i], "orgasm_mode", expected)
                    if !dressed_locked
                        SNSL_JMap.setInt(position_objs[i], "dressed", dressed)
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
            if position_objs && i < position_objs.length && position_objs[i] > 0
                SNSL_JMap.setInt(position_objs[i], "orgasm_mode", expected)
                if !dressed_locked
                    SNSL_JMap.setInt(position_objs[i], "dressed", dressed)
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
                ; Deny is its own flag: keeps the current expected state.
                no_org = SNSL_JMap.getInt(position_objs[i], "no_orgasm", 0)
                deny = 1
            endif
            String speaking = SpeakingCsvFromIndex(i)
            if speaking == "" && mode != "not_expected"
                speaking = SkyrimNet_SexLab_AnimDb.SpeakingDefaultFromOrgasmExpected(1)
            elseif mode == "not_expected"
                speaking = SkyrimNet_SexLab_AnimDb.SpeakingDefaultFromOrgasmExpected(0)
            endif
            int old_deny = SNSL_JMap.getInt(position_objs[i], "deny_orgasm", 0)
            SetPosition(i, positions[i], no_org, speaking)
            SNSL_JMap.setInt(position_objs[i], "orgasm_locked", 1)
            if deny == 1
                if old_deny != 1
                    SNSL_JMap.setStr(position_objs[i], "deny_by", GetDisplayName(Game.GetPlayer()))
                endif
                SNSL_JMap.setInt(position_objs[i], "deny_orgasm", 1)
                SetOrgasmDisabled(akActor, true)
            elseif old_deny == 1
                ; 1 -> 0: the allow path checks every actor; silent unless someone orgasms (then the
                ; group DN starts "<player> allowed <actor> to orgasm. ").
                SNSL_JMap.setInt(position_objs[i], "deny_orgasm", 1)
                SetDenyOrgasm(akActor, false, Game.GetPlayer(), false, false)
            else
                SNSL_JMap.setInt(position_objs[i], "deny_orgasm", 0)
                SetOrgasmDisabled(akActor, false)
            endif
            Engine_SetSkills()
            ApplySexLabVoice(i)
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

; Scene start (in_scene) / end with the overlay open: when the ControlPanel target is in this thread,
; flip a selected Scene view to the Description Editor or Scene Creator. Told explicitly because the
; SexLab animating faction may not have changed yet inside these hooks.
Function WebUI_RerouteForFocus(bool in_scene)
    if thread == None || !SkyrimNet_SexLab_WebUI.WebUI_IsOverlayVisible()
        return
    endif
    Actor focus = SkyrimNet_SexLab_WebUI.WebUI_GetFocusActor()
    if focus == None || !thread.positions || thread.positions.Find(focus) < 0
        return
    endif
    SkyrimNet_SexLab_WebUI.WebUI_RerouteScenePanel(in_scene)
EndFunction

Function WebUI_ConfigureIfOverlayVisible()
    if !SkyrimNet_SexLab_WebUI.WebUI_IsOverlayVisible()
        return
    endif
    ; One build feeds both views; the Animation push only matters to an open Description Editor.
    String scene_state_json = BuildWebUISceneMenuState()
    SkyrimNet_SexLab_WebUI.SceneCreator_Configure(scene_state_json)
    if SkyrimNet_SexLab_WebUI.WebUI_IsMainPanelOpen("description_editor_panel")
        SkyrimNet_SexLab_WebUI.Animation_Menu_Configure(scene_state_json)
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
    String scene_state_json = BuildWebUISceneMenuState()
    SkyrimNet_SexLab_WebUI.SceneCreator_Configure(scene_state_json)
    SkyrimNet_SexLab_WebUI.Animation_Menu_Configure(scene_state_json)
EndFunction
