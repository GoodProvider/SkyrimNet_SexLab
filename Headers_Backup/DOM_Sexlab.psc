Scriptname DOM_Sexlab extends Quest
Faction Property SexLabAnimatingFaction Auto
Faction Property DOMAnimatingFaction Auto
Function StartSex(Actor[] sexActors, sslBaseAnimation[] anims, Actor victim=None, bool allowBed=false, string hook="") Native
Function StartSexlabWithAnims(Actor[] akActors, DOM_Actor[] akDOMActors, string tied_pose, string tags, bool is_punishment, string reason_name, sslBaseAnimation[] anims, ObjectReference CenterOn = None, bool AllowBed = true, string Hook = "") Native
Function ClearAnimatingFaction(Actor akRef) Native
Function SetAnimatingFaction(Actor akRef) Native
Actor Function GetReadyForScene(Actor akRef, DOM_Actor akActor) Native
bool Property separateOrgasmToggle = false Auto Hidden
