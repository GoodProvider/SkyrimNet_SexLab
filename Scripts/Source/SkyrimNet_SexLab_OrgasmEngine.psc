Scriptname SkyrimNet_SexLab_OrgasmEngine

; OrgasmEngine: C++ (SkyrimNet_SexLab.dll) owns enjoyment and orgasms for every SexLab scene.
; This script is only a shell: natives into the engine, and the Effect_* globals the engine
; dispatches back for SexLab side effects. See docs/developers/orgasm-engine.md.
;
; source = free-form owner id ("dom", "dd_vibrator", ...). Blocks and rate modifiers are keyed by it.
; ModEvents sent by the engine (sender = affected actor, strArg = "<source>|<acting actor FormID>"):
;   SkyrimNet_SexLab_Orgasm (numArg orgasm count), SkyrimNet_SexLab_OrgasmDenied,
;   SkyrimNet_SexLab_Edge (numArg seconds), SkyrimNet_SexLab_MentalBreak (numArg 1 broken / 0 recovered)

; ---- Public API ----
float Function GetEnjoyment(Actor akActor) global native
Function SetEnjoyment(Actor akActor, float value, String source) global native
Function AddEnjoyment(Actor akActor, float delta, String source) global native
bool Function Arouse(Actor who, Actor target, float mult = 1.0) global native
bool Function Calm(Actor who, Actor target, float mult = 1.0) global native
Function Edge(Actor akActor, float seconds, String source) global native
Function SetRateModifier(Actor akActor, String source, float mult) global native
Function ClearRateModifier(Actor akActor, String source) global native
Function SetOrgasmBlocked(Actor akActor, String source, bool blocked) global native
bool Function IsOrgasmAllowed(Actor akActor) global native
Function RequestOrgasm(Actor akActor, bool force, String source) global native
int Function GetOrgasmCount(Actor akActor) global native
float Function GetSecondsSinceOrgasm(Actor akActor) global native
bool Function IsManaged(Actor akActor) global native
bool Function IsMentallyBroken(Actor akActor) global native
bool Function IsMiniGameEnabled() global native
Function SetRates(float passive, float aggressor, float victim) global native
; Re-reads sexlab.enjoyment.* / sexlab.minigame.* / sexlab.hud.* (MCM on SkyrimNet_OnPluginConfigSaved).
Function ReloadConfig() global native

; ---- Shell: called by SkyrimNet_SexLab_Scene ----
; roles: 0 normal, 1 aggressor, 2 victim. seeds: SexLab GetEnjoyment at start.
Function BeginScene(int sid, Actor[] actors, int[] roles, float[] seeds, bool hasPlayer) global native
Function SetStage(int sid, int stage, int stageCount) global native
; Seconds per stage (SexLab's GetTimer rule): fixes the scene's base rate. LeadIn never reaches 100.
Function SetStageTimers(int sid, float[] stageSecs, bool leadIn) global native
; Pause hotkey: HUD label, stops the final-stage safety-net clock (gain keeps running).
Function SetScenePaused(int sid, bool paused) global native
; Gate pass narration was just sent: the next voice pushes the scene to its final stage.
Function GateNarrationSent(int sid) global native
; Scene ending lead and orgasm target (0 = off): the lead reaching it in the second-to-last stage makes
; everyone else roll early for the final stage, into the same DN.
Function SetEndingTarget(int sid, Actor lead, int target) global native
; Seconds left on the final stage's timer (unpaused, animating); -1 when not in a timed final stage.
float Function FinalStageRemaining(int sid) global native
Function SetSceneBlocked(Actor akActor, bool blocked) global native
; Position's orgasm_expected; false: no passive gain (mini-game Arouse / Calm only).
Function SetOrgasmExpected(Actor akActor, bool expected) global native
; DOM slave: passive progress goes to DOM's arousal in steps (Effect_DomSync); DOM decides the orgasm.
Function SetDomSlave(Actor akActor, bool dom) global native
; DOM slave: 0-100 meter computed from DOM's orgasm values (HUD bar + SexLab mirror).
Function SetDomMeter(Actor akActor, float meter) global native
Function SetActorSkills(Actor akActor, int skill, int lewd) global native
; SexLab's starting-enjoyment inputs: GetSkillLevels of the actor and of the partner SexLab bases skills on
; (empty arrays: unskilled), lowest / highest present relationship rank, act skill (0 foreplay 1 vaginal 2 anal
; 3 oral). The engine computes the actor's bonus with SexLab's formula.
Function SetBonusInputs(Actor akActor, float[] ownSkills, float[] partnerSkills, int lowestRank, int highestRank, int actSkill) global native

; ---- Mini-game NPC strategies (Multi-Orgasm Mini-game mode) ----
; ids: 0 passive 1 mutual 2 selfish 3 selfless 4 together 5 tease 6 reject 7 cumquick 8 greedy
;      9 forcedorgasm 10 acceptforce. target: Tease / Greedy (a victim) / ForcedOrgasm; None picks one.
; False when not allowed for the actor (mode, role, forced state). Narrated; notification in player scenes.
bool Function SetStrategy(Actor akActor, int strategy, Actor target) global native
int Function GetStrategy(Actor akActor) global native
; Third-person phrase ("focuses on self enjoyment"); "" when none, Together mode or the player.
String Function GetStrategyText(Actor akActor) global native
Actor Function GetForcedBy(Actor akActor) global native
; How the forcer forced akActor ("a slap to the face"); narrated with give in / resist. "" clears.
Function SetForceMethod(Actor akActor, String method) global native

; Strategy action key (static action parameter) -> id; -1 when unknown.
int Function StrategyId(String strategy_key) global
    String[] keys = new String[11]
    keys[0] = "passive"
    keys[1] = "mutual"
    keys[2] = "selfish"
    keys[3] = "selfless"
    keys[4] = "together"
    keys[5] = "tease"
    keys[6] = "reject"
    keys[7] = "cumquick"
    keys[8] = "greedy"
    keys[9] = "forcedorgasm"
    keys[10] = "acceptforce"
    return keys.Find(strategy_key)
EndFunction
Function EndScene(int sid) global native
Function ResetSpeedScale(Actor akActor) global native
; Speed level of the actor's effective animation speed: 0 gentle, 1 normal, 2 forceful.
int Function GetSpeedLevel(Actor akActor) global native
; SexLabOrgasm bookkeeping (Scene_Manager.OrgasmIndividual): our own vs another plugin's ForceOrgasm.
bool Function ConsumeOwnOrgasm(Actor akActor) global native
int Function NoteExternalOrgasm(Actor akActor, String source) global native
; deny_orgasm 1 -> 0: unblock and, in one step, fire everyone in the scene at 100 (+ group join at 95).
; True: Effect_OrgasmGroup narrates with "<allower> allowed <akActor> to orgasm. "; false: caller narrates.
bool Function AllowOrgasm(Actor akActor, Actor allower) global native

; ---- Shell: dispatched by the engine ----
SkyrimNet_SexLab_Scene_Manager Function GetManager() global
    return Game.GetFormFromFile(0x800, "SkyrimNet_SexLab.esp") as SkyrimNet_SexLab_Scene_Manager
EndFunction

; Kept for compatibility: one actor as a group.
Function Effect_Orgasm(Actor akActor, bool individual, String source) global
    if akActor == None
        return
    endif
    Actor[] actors = new Actor[1]
    actors[0] = akActor
    int[] forced = new int[1]
    Effect_OrgasmGroup(actors, forced, individual, source, None, None, "")
EndFunction

; Everyone who orgasmed together in one scene (natural, forced, safety net, allow, group join at 95).
; forced[i] 1: forced request. individual false: stash + window (safety net / joiners of an external orgasm).
; allower: deny 1 -> 0 prefix. extras: pending arouse / calm narrations folded into the one message.
Function Effect_OrgasmGroup(Actor[] actors, int[] forced, bool individual, String source, Actor allower, Actor allowed, String extras) global
    SkyrimNet_SexLab_Scene_Manager manager = GetManager()
    if manager == None || !actors || actors.length == 0 || actors[0] == None
        return
    endif
    SkyrimNet_SexLab_Scene sl_scene = manager.GetSceneByActor(actors[0])
    if sl_scene == None
        SkyrimNet_SexLab_WebUI.TraceLog("SkyrimNet_SexLab_OrgasmEngine", "Effect_OrgasmGroup", "no scene for "+actors[0].GetDisplayName())
        return
    endif
    sl_scene.Orgasm_ApplyGroup(actors, forced, individual, source, allower, allowed, extras)
EndFunction

; Gate passed: narrate the passers now (one DN) and, before the final stage, hold the stage until
; the voice starts (Effect_AdvanceToFinal). The orgasm itself follows as a "gate" group.
Function Effect_GatePassed(Actor[] actors, bool holdStage) global
    SkyrimNet_SexLab_Scene_Manager manager = GetManager()
    if manager == None || !actors || actors.length == 0 || actors[0] == None
        return
    endif
    SkyrimNet_SexLab_Scene sl_scene = manager.GetSceneByActor(actors[0])
    if sl_scene != None
        sl_scene.Engine_GatePassed(actors, holdStage)
    endif
EndFunction

; The gate narration's voice started: push the actor's scene to its final stage.
Function Effect_AdvanceToFinal(Actor akActor) global
    SkyrimNet_SexLab_Scene_Manager manager = GetManager()
    if manager == None || akActor == None
        return
    endif
    SkyrimNet_SexLab_Scene sl_scene = manager.GetSceneByActor(akActor)
    if sl_scene != None
        sl_scene.Engine_AdvanceToFinal()
    endif
EndFunction

Function Effect_Mirror(Actor akActor, int value) global
    SkyrimNet_SexLab_Scene_Manager manager = GetManager()
    if manager == None || akActor == None
        return
    endif
    SkyrimNet_SexLab_Scene sl_scene = manager.GetSceneByActor(akActor)
    if sl_scene != None
        sl_scene.Mirror_Apply(akActor, value)
    endif
EndFunction

; DOM slave: push the engine's arousal to DOM (prepay on the scene's first sync, spread steps,
; mini-game delta), then a light step roll when share > 0 (DOM decides; a melt comes back through
; Handler_DOM.DOMSlave_Orgasmed), then push the meter.
Function Effect_DomSync(Actor akActor, float miniDelta, float daring, float naivety, float share, bool prepay, bool hasPlayer) global
    SkyrimNet_SexLab_Scene_Manager manager = GetManager()
    if manager == None || akActor == None || manager.main == None || manager.main.handler_dom == None
        return
    endif
    SkyrimNet_SexLab_Handler_DOM_Interface dom = manager.main.handler_dom
    dom.DomSync(akActor, miniDelta, daring, naivety, prepay, hasPlayer)
    if share > 0.0
        dom.StepRoll(akActor, hasPlayer, share)
    endif
    SetDomMeter(akActor, dom.OrgasmMeter(akActor))
EndFunction

; Strategy action eligibility: StorageUtil int keys on the actor, read by the actions' papyrus_util
; HasIntValue rules. allow: set; deny: unset.
Function Effect_StrategyEligibility(Actor akActor, String[] allow, String[] deny) global
    if akActor == None
        return
    endif
    int i = 0
    while i < allow.length
        StorageUtil.SetIntValue(akActor, allow[i], 1)
        i += 1
    endwhile
    i = 0
    while i < deny.length
        StorageUtil.UnsetIntValue(akActor, deny[i])
        i += 1
    endwhile
EndFunction

; Strategy change: optional narration; in player scenes also a notification.
Function Effect_StrategyChanged(Actor akActor, Actor target, String msg, bool notify) global
    if msg == ""
        return
    endif
    if notify
        Debug.Notification(msg)
    endif
    SkyrimNet_SexLab_Utilities.DirectNarration_Optional("sexlab_strategy", msg, akActor, target, False)
EndFunction

; Player Force (HUD): always narrated.
Function Effect_NarrateDirect(String msg, Actor source, Actor target) global
    if msg == ""
        return
    endif
    SkyrimNet_SexLab_Utilities.DirectNarration(msg, source, target)
EndFunction

; Speed / mini-game narrations are optional for everyone (player included): standard optional path,
; DirectNarration when NarrationCoolOffAllows, else downgraded to RegisterEvent (never dropped).
Function Effect_Narrate(String event_type, String msg, Actor source, Actor target) global
    if msg == ""
        return
    endif
    SkyrimNet_SexLab_Utilities.DirectNarration_Optional(event_type, msg, source, target, False)
EndFunction
