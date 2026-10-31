Scriptname SkyrimNet_SexLab_Registry Hidden

; Scenes::Registry (C++): the running scenes by sid and actor. Fed natively (Decorators Threads_Set / Threads_Remove,
; AnimEngine start / end); Manager.GetSceneByActor and IsBusy read it while sexlab.scene_registry.enabled is on.
; See docs/developers/scene-migration.md §8 step 1.

; Papyrus pool sid of the SexLab scene the actor is in, -1 when none.
int Function Registry_SidOf(Actor akActor) global native
; In any registered scene (SexLab or AnimEngine).
Bool Function Registry_IsBusy(Actor akActor) global native
; Debug: JSON array of {kind, id, actors}.
String Function Registry_Describe() global native
