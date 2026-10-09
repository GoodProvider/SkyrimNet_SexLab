Scriptname SkyrimNet_SexLab_Locker Hidden

; Pre-start scene lock (C++ ActorLocker, persisted in the SKSE co-save).
; A locked actor cannot be claimed by another Scene_Creator and is left out of the
; Scene Creator actor table (Control Panel shows it as "Name (locked)").

; Locks akActor. False when None, dead, in combat, already locked, or in a SexLab/OStim scene.
Bool Function Lock(Actor akActor) global native
Function Unlock(Actor akActor) global native
Bool Function IsLocked(Actor akActor) global native

; All-or-nothing. False (and nothing left locked by this call) if any actor fails.
Bool Function LockAll(Actor[] actors) global native
Function UnlockAll(Actor[] actors) global native
