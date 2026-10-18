Scriptname TTLL_Store Hidden

; ========================================================================================
; Generic Getter Functions (Dot-Separated Property Paths)
; ========================================================================================

; Get an integer property from an NPC using dot-separated path
; Examples:
;   GetNpcInt(npc, "exclusiveSex") - get NPC's exclusive sex count
;   GetNpcInt(npc, "totalInternalClimax.did") - get total internal climax given
;   GetNpcInt(npc, "did.Vaginal") - get count of "Vaginal" action performed
Int Function GetNpcInt(Actor npc, String propName) Global Native

; Get a float property from an NPC using dot-separated path
; Examples:
;   GetNpcFlt(npc, "lastTime") - get NPC's last encounter time
Float Function GetNpcFlt(Actor npc, String propName) Global Native

; Get an integer property from a lover relationship using dot-separated path
; Examples:
;   GetLoverInt(npc, lover, "exclusiveSex") - get exclusive sex count with lover
;   GetLoverInt(npc, lover, "partOfSameGroupSex") - get group sex count with lover
;   GetLoverInt(npc, lover, "internalClimax.did") - get internal climax given to lover
;   GetLoverInt(npc, lover, "internalClimax.got") - get internal climax received from lover
Int Function GetLoverInt(Actor npc, Actor lover, String propName) Global Native

; Get a float property from a lover relationship using dot-separated path
; Examples:
;   GetLoverFlt(npc, lover, "lastTime") - get last encounter time with lover
;   GetLoverFlt(npc, lover, "orgasms") - get total orgasms with lover
Float Function GetLoverFlt(Actor npc, Actor lover, String propName) Global Native


; ========================================================================================
; Generic Setter Functions (Dot-Separated Property Paths)
; ========================================================================================

; Set an integer property for an NPC using dot-separated path
; Examples:
;   SetNpcInt(npc, "exclusiveSex", 10) - set NPC's exclusive sex count
;   SetNpcInt(npc, "totalInternalClimax.did", 5) - set total internal climax given
;   SetNpcInt(npc, "actions_did.Vaginal", 3) - set count of "Vaginal" action performed
Function SetNpcInt(Actor npc, String propName, Int value) Global Native

; Set a float property for an NPC using dot-separated path
; Examples:
;   SetNpcFlt(npc, "lastTime", 123.45) - set NPC's last encounter time
Function SetNpcFlt(Actor npc, String propName, Float value) Global Native

; Set an integer property for a lover relationship using dot-separated path
; Examples:
;   SetLoverInt(npc, lover, "exclusiveSex", 10) - set exclusive sex count with lover
;   SetLoverInt(npc, lover, "partOfSameGroupSex", 5) - set group sex count with lover
;   SetLoverInt(npc, lover, "internalClimax.did", 3) - set internal climax given to lover
;   SetLoverInt(npc, lover, "internalClimax.got", 2) - set internal climax received from lover
Function SetLoverInt(Actor npc, Actor lover, String propName, Int value) Global Native

; Set a float property for a lover relationship using dot-separated path
; Examples:
;   SetLoverFlt(npc, lover, "lastTime", 123.45) - set last encounter time with lover
;   SetLoverFlt(npc, lover, "orgasms", 10.5) - set total orgasms with lover
Function SetLoverFlt(Actor npc, Actor lover, String propName, Float value) Global Native


; ========================================================================================
; Actions Functions
; ========================================================================================

; Record an action for an NPC
; isDid: True if NPC performed the action, False if NPC received the action
Function RecordAction(Actor npc, String actionName, Bool isDid) Global Native

; Get sorted actions by count (descending)
; isDid: True for actions performed (did), False for actions received (got)
; topK: -1 returns all, >0 returns only top K actions
; Example: GetAllActions(npc, true, 5) returns the 5 most frequently performed actions
String[] Function GetAllActions(Actor npc, Bool isDid, Int topK = -1) Global Native

; Get count for a specific action
; isDid: True for actions performed (did), False for actions received (got)
; actionName: The name of the action to query
; Returns: The count for the action, or 0 if not found
; Example: GetActionCount(npc, true, "Vaginal") returns how many times NPC performed "Vaginal" action
Int Function GetActionCount(Actor npc, Bool isDid, String actionName) Global Native

; ========================================================================================
; Counter Functions
; ========================================================================================

; Increment a named counter for an NPC
; Valid counter names: "sameSexEncounter", "soloSex", "exclusiveSex", "groupSex"
Function IncrementInt(Actor npc, String intName) Global Native

; ========================================================================================
; Utility Functions
; ========================================================================================

; Get all registered NPCs in the ledger
; Returns TESNPC base forms (ActorBase) — valid even when cells are unloaded
; Use (form as ActorBase) to get name/gender; (form as Actor) returns None if unloaded
Form[] Function GetAllNPCs() Global Native

; Get all lovers for a specific NPC, sorted by lover score (highest to lowest)
; topK: -1 returns all lovers, >0 returns only top K lovers by score
; Returns TESNPC base forms (ActorBase) — valid even when cells are unloaded
; Use (form as ActorBase) to get name/gender; (form as Actor) returns None if unloaded
; Example: GetAllLovers(npc, 5) returns the 5 highest-scoring lovers
Form[] Function GetAllLovers(Actor npc, Int topK = -1) Global Native

; Calculate lover score based on encounters, orgasms, and time decay
; Returns a score that represents the strength/recency of the relationship
; Higher scores indicate more active/recent relationships
; Example: GetLoverScore(npc, lover) returns the calculated score for that lover
Float Function GetLoverScore(Actor npc, Actor lover) Global Native

