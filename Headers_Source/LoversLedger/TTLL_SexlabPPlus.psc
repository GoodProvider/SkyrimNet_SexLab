Scriptname TTLL_SexlabPPlus Hidden

; Header stub for Lover's Ledger (TT_LoversLedger.esp). Keep the signature identical to theirs.
; Call only through SkyrimNet_SexLab_LoversLedger, which checks the plugin first. P+ only.

; A SexLabStatistics counter (10 vaginal, 11 anal, 15 total).
int Function GetCount(Actor akActor, int id) global
    return 0
EndFunction
