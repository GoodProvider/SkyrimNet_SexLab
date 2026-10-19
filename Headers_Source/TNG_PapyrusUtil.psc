Scriptname TNG_PapyrusUtil Hidden

; HEADER ONLY (The New Gentleman, TheNewGentleman.esp). Only what SkyrimNet_SexLab calls; guard every call
; with Game.GetModByName("TheNewGentleman.esp") != 255.

Armor Function GetActorAddon(Actor akActor) Global Native ;Returns None if there is no addon or another error happens
