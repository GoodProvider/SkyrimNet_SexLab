Scriptname TTLL_SexlabIntegration Hidden

; Header stub for Lover's Ledger (TT_LoversLedger.esp). Keep the signature identical to theirs.
; Call only through SkyrimNet_SexLab_LoversLedger, which checks the plugin first.

; First-time lines for a SexLab animation, newline-separated; "" when nothing is new.
String Function GetFirstTimes(Actor[] positions, string tags) global
    return ""
EndFunction

; True on SexLab P+ (SexLabUtil plugin version > 20000).
bool Function IsPPlus() global
    return false
EndFunction
