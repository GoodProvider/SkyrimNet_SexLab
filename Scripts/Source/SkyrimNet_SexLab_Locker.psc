Scriptname SkyrimNet_SexLab_Locker Hidden

; Pre-start scene lock (C++ ActorLocker). All locks are released on game load
; (SexLab cancels every scene on load).
; A locked actor cannot be claimed by another Scene_Creator. The Scene Creator actor table lists it last
; with a lock (not addable); the lock calls Scene_Manager.WebUI_ForceUnlock. Control Panel shows "Name (locked)".

; Locks akActor. False when None, dead, in combat, already locked, or in a SexLab/OStim scene.
Bool Function Lock(Actor akActor) global native
Function Unlock(Actor akActor) global native
Bool Function IsLocked(Actor akActor) global native

; Removes akActor from OStim's ActorCount faction (a stale "in OStim" flag). True when they were in it.
; Does not end a live OStim thread.
Bool Function ClearOstim(Actor akActor) global native

; All-or-nothing. False (and nothing left locked by this call) if any actor fails.
Bool Function LockAll(Actor[] actors) global native
Function UnlockAll(Actor[] actors) global native
