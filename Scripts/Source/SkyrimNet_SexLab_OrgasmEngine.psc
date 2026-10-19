Scriptname SkyrimNet_SexLab_OrgasmEngine

; OrgasmEngine: C++ (SkyrimNet_SexLab.dll) owns enjoyment and orgasms for every SexLab scene.
; This script is only a shell: natives into the engine, and the Effect_* globals the engine
; dispatches back for SexLab side effects. See docs/developers/orgasm-engine.md.
;
; source = free-form owner id ("dom", "dd_vibrator", ...). Blocks and rate modifiers are keyed by it.
; ModEvents sent by the engine (sender = affected actor, strArg = "<source>|<acting actor FormID>"):
;   SkyrimNet_SexLab_Orgasm (numArg orgasm count), SkyrimNet_SexLab_OrgasmDenied,
;   SkyrimNet_SexLab_Edge (numArg seconds)

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
bool Function IsMiniGameEnabled() global native
; sexlab.enjoyment.engine_disabled: SexLab owns enjoyment and decides orgasms; the engine records them.
bool Function IsEngineDisabled() global native
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
; Gate pass narration was just sent: the next voice after mark (NarrationMark() taken before the DN;
; -1 = now) pushes the scene to its final stage.
Function GateNarrationSent(int sid, int mark) global native
; Scene ending lead and orgasm target (0 = off): the lead reaching it in the second-to-last stage makes
; everyone else roll early for the final stage, into the same DN.
Function SetEndingTarget(int sid, Actor lead, int target) global native
; The engine plays this scene's ending gate (mini-game, everyone AI driven, timed): its last orgasm lands
; at the end of the second-to-last stage.
bool Function IsGateScene(int sid) global native
; Final-stage hold: take a mark just before sending the orgasm narration. Only the scene's own actors count:
; ResponseStartedSince(sid, mark) once one of them speaks, ResponseDoneSince(sid, mark) once that reply has
; finished playing (SkyrimNet_SpeechComplete).
int Function NarrationMark() global native
bool Function ResponseStartedSince(int sid, int mark) global native
bool Function ResponseDoneSince(int sid, int mark) global native
; Seconds left on the final stage's timer (unpaused, animating); -1 when not in a timed final stage.
float Function FinalStageRemaining(int sid) global native
Function SetSceneBlocked(Actor akActor, bool blocked) global native
; Position's orgasm_expected; false: no passive gain (mini-game Arouse / Calm only).
Function SetOrgasmExpected(Actor akActor, bool expected) global native
; Current animation's acts (Aid potion narration): Vaginal, Anal, Oral / Blowjob tags. Start and animation change.
Function SetSceneActs(Actor akAnchor, bool vaginal, bool anal, bool oral) global native
; This scene is the actor's first vaginal / anal (Lover's Ledger): the Punish / Aid panels show pussy / ass as
; damaged. Sticky for the scene (false never clears).
Function SetFirstTimes(Actor akActor, bool vaginal, bool anal) global native
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
; ids (strategies.json order): 0 passive 1 mutual 2 selfish 3 selfless 4 deny_self 5 deny_all 6 deny
;      7 tease 8 focused 9 nonsexual. target: deny / tease / focused; None picks one.
; False when not allowed for the actor (mode, scene). Narrated; shown on the HUD.
bool Function SetStrategy(Actor akActor, int strategy, Actor target) global native
int Function GetStrategy(Actor akActor) global native
; Third-person phrase ("focuses on self enjoyment"); "" when none, Together mode or the player.
String Function GetStrategyText(Actor akActor) global native
; Sex is hard work: stamina regen, percent of the actor's default (100 when unmanaged or the setting is off).
float Function GetStaminaRegen(Actor akActor) global native

; ---- LLM actions SexLab_Aid / SexLab_Scene_Punish (mirror the HUD Aid / Punish keys) ----
; caster heals or restores target with its best healing (kind "heal") or stamina ("stamina") spell (costs magicka)
; or potion (consumed). Returns the narration line, "" when it has none / refused.
String Function Aid(Actor caster, Actor target, String kind) global native
; by asks (order false) or orders (true) target to take a strategy: key a request key ("passive", "focused_p1": the
; strategy plus "_p<position>" of the actor it is about; see the Ask / Order panel), or "" with text (a free phrase
; after "to"). The engine narrates "Bob orders Nina to ...", runs Nina's strategy decision, then narrates "Nina agrees
; to|refuses Bob's request to ..." itself; a refusal becomes a punishment reason. False when refused.
bool Function AskOrder(Actor by, Actor target, bool order, String key, String text) global native
; Another mod (SkyrimNet_DOM) supplies a reason target can be punished for in its scene ("Nina spoke without
; permission"); it appears in the Punish panel's reason pulldown.
Function AddPunishReason(Actor by, Actor target, String reason) global native
; punisher hurts target (anyone else in its scene, the player included) by method (slap / pinch / punch / pull, a
; weak attack spell the punisher knows, or a free phrase like "biting") on part (body, face, nipples, ...) because
; reason ("" for none): "Bob punishes Nina by pinching Nina's nipples, because Nina refused Bob's order to ...". With
; Injury Engine the hit's feeling text follows the line. The engine narrates it, then runs Nina's strategy decision.
; Always returns "" (kept as a String for old callers); the caller narrates nothing.
String Function Punish(Actor punisher, Actor target, String method, String part, String reason) global native
; Injury Engine (with External_Damage) is installed: Punish hits and "heal" Aid go through it, and Injury Engine sends
; their narration line (the caller must not narrate it again; Punish never needs it).
bool Function InjuryEngineInstalled() global native
; Any affordable healing / stamina spell or any such potion (skyrimnet_sexlab_can_aid).
bool Function HasAidOptions(Actor akActor) global native
; In a managed scene with someone else in it (skyrimnet_sexlab_can_punish).
bool Function CanPunish(Actor akActor) global native

; Eligibility keys (StorageUtil ints) for the SexLab_Aid / SexLab_Scene_Punish papyrus_util rules. Set per position at
; scene begin, refreshed after an aid (potions run out), cleared at scene end.
Function ActionKeys_Refresh(Actor akActor) global
    if akActor == None
        return
    endif
    if HasAidOptions(akActor)
        StorageUtil.SetIntValue(akActor, "skyrimnet_sexlab_can_aid", 1)
    else
        StorageUtil.UnsetIntValue(akActor, "skyrimnet_sexlab_can_aid")
    endif
    if CanPunish(akActor)
        StorageUtil.SetIntValue(akActor, "skyrimnet_sexlab_can_punish", 1)
    else
        StorageUtil.UnsetIntValue(akActor, "skyrimnet_sexlab_can_punish")
    endif
    StorageUtil.UnsetIntValue(akActor, "skyrimnet_sexlab_can_force") ; removed Force action
EndFunction

Function ActionKeys_Clear(Actor akActor) global
    if akActor == None
        return
    endif
    StorageUtil.UnsetIntValue(akActor, "skyrimnet_sexlab_can_aid")
    StorageUtil.UnsetIntValue(akActor, "skyrimnet_sexlab_can_punish")
    StorageUtil.UnsetIntValue(akActor, "skyrimnet_sexlab_can_force") ; removed Force action
EndFunction

; Strategy action key (static action parameter) -> id; -1 when unknown.
int Function StrategyId(String strategy_key) global
    String[] keys = new String[10]
    keys[0] = "passive"
    keys[1] = "mutual"
    keys[2] = "selfish"
    keys[3] = "selfless"
    keys[4] = "deny_self"
    keys[5] = "deny_all"
    keys[6] = "deny"
    keys[7] = "tease"
    keys[8] = "focused"
    keys[9] = "nonsexual"
    return keys.Find(strategy_key)
EndFunction
Function EndScene(int sid) global native
Function ResetSpeedScale(Actor akActor) global native
; Speed level of the actor's effective animation speed: 0 gentle, 1 normal, 2 forceful.
int Function GetSpeedLevel(Actor akActor) global native
; SexLabOrgasm bookkeeping (Scene_Manager.OrgasmIndividual): our own vs another plugin's ForceOrgasm.
bool Function ConsumeOwnOrgasm(Actor akActor) global native
int Function NoteExternalOrgasm(Actor akActor, String source) global native
; SLSO only: queues akAlias.Orgasm(-2) (resets SLSO's 5 s guard, then DoOrgasm(true)). False: not dispatched.
bool Function SLSOForceOrgasm(ReferenceAlias akAlias) global native
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
; allower: deny 1 -> 0 prefix. extras: always "" (arouse / calm go out as short-lived events via Effect_Narrate).
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

; Strategy change (no notification). narrate: optional narration of msg (LLM / API / forced
; changes). Else (the decision model changed it) a short-term event with observed, how the change looks
; to others ("Lydia appears to be focused on her own enjoyment.").
Function Effect_StrategyChanged(Actor akActor, Actor target, String msg, String observed, bool narrate) global
    if msg == ""
        return
    endif
    int level = MiniGameNarrationLevel()
    if narrate
        if level >= 3
            SkyrimNet_SexLab_Utilities.DirectNarration_Optional("sexlab_strategy", msg, akActor, target, False)
        else
            SkyrimNet_SexLab_Utilities.NarrateBelowDirect(level, "sexlab_strategy", msg, akActor, target, True)
        endif
    elseif observed != ""
        SkyrimNet_SexLab_Utilities.NarrateBelowDirect(level, "sexlab_strategy", observed, akActor, target, True)
    endif
EndFunction

; sexlab.narration.minigame_level: cap for strategy / request / Force / Aid narrations (3 Direct .. 0 Silent).
int Function MiniGameNarrationLevel() global
    return SkyrimNet_SexLab_Utilities.NarrationLevel("sexlab.narration.minigame_level")
EndFunction

; Sex is hard work: these non-victims are at 0 stamina regen and 0 stamina; the scene ends.
Function Effect_Exhausted(Actor[] actors) global
    SkyrimNet_SexLab_Scene_Manager manager = GetManager()
    if manager != None
        manager.EndExhausted(actors)
    endif
EndFunction

; Player Force (HUD): always narrated.
Function Effect_NarrateDirect(String msg, Actor source, Actor target) global
    if msg == ""
        return
    endif
    int level = MiniGameNarrationLevel()
    if level >= 3
        SkyrimNet_SexLab_Utilities.DirectNarration(msg, source, target)
    else
        SkyrimNet_SexLab_Utilities.NarrateBelowDirect(level, "sexlab_request", msg, source, target)
    endif
EndFunction

; Ask / order / agree / refuse narration in a scene without the player: dropped-never (falls back to an event when the
; speech queue is busy), like a strategy change.
Function Effect_NarrateOptional(String msg, Actor source, Actor target) global
    if msg == ""
        return
    endif
    int level = MiniGameNarrationLevel()
    if level >= 3
        SkyrimNet_SexLab_Utilities.DirectNarration_Optional("sexlab_request", msg, source, target, False)
    else
        SkyrimNet_SexLab_Utilities.NarrateBelowDirect(level, "sexlab_request", msg, source, target)
    endif
EndFunction

; Arouse / calm narrations: short-lived events only (no DN, no history). Stable eventId per
; (type, source, target) so a repeat replaces the previous one instead of stacking.
Function Effect_Narrate(String event_type, String msg, Actor source, Actor target) global
    if msg == "" || source == None || target == None
        return
    endif
    int ttlMs = 30000
    String eventId = event_type + "_" + source.GetFormID() + "_" + target.GetFormID()
    SkyrimNetApi.RegisterShortLivedEvent(eventId, event_type, msg, "", ttlMs, source, target)
    SkyrimNet_SexLab_WebUI.TraceLog("SkyrimNet_SexLab_OrgasmEngine", "Effect_Narrate", "short-lived "+eventId+" msg:"+msg)
EndFunction
