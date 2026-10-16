# OrgasmEngine

The C++ OrgasmEngine owns enjoyment and orgasms for **every** SexLab scene, including NPC-only scenes. SexLab's own trigger is switched off (`thread.DisableAllOrgasms(true)`), and SLSO is not used. Unless the engine is disabled: see [Engine disabled](#engine-disabled).

## Engine disabled

`sexlab.enjoyment.engine_disabled` (manifest "Disable OrgasmEngine, switch back to SexLab", default off) hands enjoyment and orgasms back to SexLab (or SLSO). The engine still tracks the scene (HUD, counts, narration), but it no longer decides anything.

- **Config:** `SexLabNet::IsOrgasmEngineDisabled` → `Settings::engineOff`. `ReloadConfig` also forces `miniGame` false, so strategies, NPC steps, decisions, Ask / Order, `IsGateScene` and the MCM Arouse / Calm actions are off through their existing guards. Log `config engine_off=true mode=sexlab`. Papyrus `IsEngineDisabled()`.
- **Scene:** `Engine_BeginScene` calls `thread.DisableAllOrgasms(false)`, so SexLab's trigger runs (vanilla: at the final stage; SLSO: at its 100). `Engine_SetStage` sends no `OrgasmStart` / `OrgasmEnd` because SexLab sends its own (same branch as P+). The flag is read at scene start, so a mid-scene toggle applies from the next scene.
- **Tick:** no rush, passive gain, Together curve, DOM progress, strategy step or orgasm test; the gate and safety net are off (`together`, `useGate` false). Only a forced request (`RequestOrgasm(…, true, …)`, the WebUI button) fires, alone (no `JoinGroup`).
- **Enjoyment:** `Effect_Mirror` goes out every `kMirrorInterval` (1 s) and becomes a pull: `Scene.Mirror_Apply` reads SexLab's `GetEnjoyment` and calls `SetEnjoyment(actor, v, "sexlab")` (logged on change only), so the HUD bars show SexLab's value. Nothing is written into SexLab.
- **Orgasms:** SexLab's `SexLabOrgasm` reaches `Scene_Manager.OrgasmIndividual` → `NoteExternalOrgasm(actor, "sexlab")` (count, cooldown, HUD flash, event; no group join) → `Scene.OrgasmIndividual(…, from_engine=true)`, narrated once.
- **Off as well:** `Arouse` / `Calm` return false; `AllowOrgasm` only clears the block (returns false, the caller narrates); the HUD hides the mini-game keys and Aid (`g_miniGame` false). Deny still works: `SetOrgasmDisabled` keeps SexLab's per-actor `DisableOrgasm` in step.

## Who does what

| Layer | Role |
|-------|------|
| `SKSE_Source/src/OrgasmEngine.cpp` | Holds the state: enjoyment (0–100), passive gain, mini-game, gates, when an orgasm fires, co-save record `'ORGE'`. Runs a 250 ms tick on the game thread; the tick is skipped while the game or WebUI is paused. All engine timers (gain, cooldown, edging, narration windows) use `Now()`, an unpaused clock advanced only by the tick `dt` (clamped to 0.5 s); `GameNow()` is the wall clock that feeds `dt`. |
| `SKSE_Source/src/Hud.cpp` + `PrismaUI/views/SkyrimNet_SexLab/hud.html` | Scene HUD: a second PrismaUI view that is shown but never focused, so the game keeps running. HUD key handling. |
| `Scripts/Source/SkyrimNet_SexLab_OrgasmEngine.psc` | **Shell only.** Native API declarations, plus the `Effect_*` globals the engine dispatches for SexLab side effects. |
| `SkyrimNet_SexLab_Scene.psc` | Adapter. Sends scene facts into the engine (`Engine_BeginScene`, `Engine_SetStage`, `Engine_SetSkills`, `SetOrgasmDisabled`, `EndScene`). Performs `Orgasm_ApplyGroup` (ForceOrgasm per actor + one narration), `SetDenyOrgasm` (deny / allow) and `Mirror_Apply` (AdjustEnjoyment). |

## Modes and the SexLab bonus

`sexlab.enjoyment.mode` (select; also the MCM **Orgasm mode** pulldown, which writes the same key with `PatchConfig`; unset falls back to the old `sexlab.minigame.enabled` bool, see `SexLabNet::IsMiniGameMode`):

| Mode | Gain | Ending |
|------|------|--------|
| **Always Orgasm Together at the end** | Bonus-shaped curve reaching 100 at the end of the second-to-last stage | Gate passes every expected, unblocked actor without a roll (repeat orgasms included); safety net as fallback |
| **Multi-Orgasm Mini-game** (default) | Passive rate x `(1 + minigame_bonus_mult x bonus)` | Reaching 100 (and the group join) fires, so several orgasms or none. No safety net. Gate only when the engine plays everyone (`SceneAiDriven`: NPCs, player on auto play): then the gate is the scene's last orgasm (see step 3) |

**Bonus** (`ActorState.bonus`, `ComputeBonus`): `Scene.Engine_SetBonusInputs` (from `Engine_SetSkills`, start and animation change) sends `SetBonusInputs(actor, ownSkills[], partnerSkills[], lowestRank, highestRank, actSkill)`: `Stats.GetSkillLevels` of the actor and of the partner SexLab bases skills on (the player when present, else the next position; creatures send empty arrays = unskilled), the present relationship ranks, and the act skill (0 foreplay, 1 vaginal, 2 anal, 3 oral). The engine applies SexLab's `StartAnimating` formula (victim: `lowest − 3 + clamp(ownLewd − ownPure, ±6)`; aggressor: `−((highest − 4) + clamp(partnerLP − ownLP, ±6))`; normal: `highest + clamp(avgLewd − avgPure, 0, 6)`; unskilled: rank terms only) with `RandomInt(1,10)` replaced by 5.5, 50 points = 1.0, plus `(partner act skill − 2) / 6`, times `bonus_scale` (0.5), clamped to ±`bonus_clamp` (0.75).

**Together curve** (`ApplyTogetherCurve`): progress `p` = (completed stages + `min(1, stage elapsed / stage timer)`) / (N − 1), on the scene's animating, unpaused stage clock (`stageElapsed`; untimed: stage index). `E(p) = 1 − (1 − p)^k`, `k = clamp(1 + together_k_range × bonus, 0.5, 2.5)`. Each tick closes the matching share of the gap to 100 (`(E(p) − E(p0)) / (1 − E(p0))`), so carried-over or external enjoyment still lands on 100 at `p = 1`. Capped at `kRushHover` (98) before the final stage; in the final stage an actor held at 98 goes to 100. A new animation (`SetStageTimers` change) or stepping back rebases the curve. No stage spike in this mode (the curve holds it); DOM slaves keep the passive rate.

## NPC strategies (Multi-Orgasm Mini-game)

SkyrimNet's decision model (e.g. Jev) picks a strategy per NPC; see [Strategy decisions](#strategy-decisions). Every `sexlab.minigame.npc_interval` s (2) the tick plays one step per NPC (`StrategyStep`), through the same cost / edge code as a key press (`ArouseLocked` / `CalmLocked`), not narrated. A step without stamina / magicka is skipped. No step runs before the scene's first non-empty `SetStageTimers` (SexLab's `thread.Timers` is empty at the first `Engine_SetStage`), or `kUntimedGrace` (10 s) after `BeginScene` for a scene that never sends timers. Only AI-driven actors step (`AiDriven`: NPCs the player does not control, the player only in auto play); see [Take control and auto play](#take-control-and-auto-play).

- **Step size, timed scenes:** `mgStepRate × npc_interval × random(npc_step_min, npc_step_max) / mean(min, max)` (4–8: 0.67–1.33×), divided by the scene's mean NPC skill factor `mean(1 + 0.1 × skill)`. Arouse then applies the actor's own skill factor, so skill matters between actors while Mutual stays on budget. See [Mini-game calibration](#mini-game-calibration).
- **Step size, scenes without timers:** `random(npc_step_min, npc_step_max)` (arouse × skill factor).

| Strategy (`strategies.json` key) | Who | Step |
|----------|-----|------|
| `passive` | anyone | none |
| `mutual` / `selfless` | 2+ actors | arouse the lowest-enjoyment actor (self included / others only) |
| `selfish` | anyone | arouse self |
| `deny_self` | anyone | calm self |
| `deny_all` | 2+ actors | calm every actor of the scene, self included |
| `deny` (target) | 2+ actors | calm the target |
| `tease` (target) | 2+ actors | arouse the target below 90, calm (edge) it at 90+ |
| `focused` (target) | 2+ actors | arouse the target |
| `nonsexual` | no actor expects orgasm | nothing (the default while no actor expects orgasm; NPCs on a default switch both ways when that changes, announced) |

`strategies.json` (`Data/SKSE/Plugins/SkyrimNet_SexLab/strategies.json`) is the source of truth for the keys and their wording: `label` (HUD tag), `text` (third person), `option` (decision criterion), `observed` (how a decision-made change looks) and `order` (the phrase after "to" in "Bob orders Nina to <order>", it names the strategy so a request reads like the key). `{target}` / `{name}` / `{self}` / `{his}` are filled in. `Strategy` ids are the file order (0 passive … 9 nonsexual). The earlier forced state (Greedy / ForcedOrgasm / AcceptForce, `forcedBy`) and the mental break (`broken`, `sexlab.minigame.mental_break`, the `SkyrimNet_SexLab_MentalBreak` event, `IsMentallyBroken`) no longer exist; the old co-save fields are written as zeros and ignored on load (SexLab stops scenes on load, so no saved strategy is restored).

- **Ask / Order** (`OrgasmEngine::AskOrderNarrated(by, target, order, requestKey, customText)`, HUD panel and Papyrus `AskOrder`): the player (or an NPC through Papyrus) asks or orders another actor of the scene to take a strategy. `requestKey` is `<key>` or `<key>_p<slot>` (the actor a deny / tease / focused request is about; `GetRequestOptions(target)` lists them: what `StrategyAllowed` permits for the target now, its current one left out) or `""` with a free phrase. Narration (one DirectNarration when the scene has the player or the player drives an actor of it, else `DirectNarration_Optional`; `PlayerScene` / `NarrateRequest`): "Bob orders|asks Nina to <order>." The target's strategy decision then runs with that line as `last_line_text` (trigger `ordered` / `asked`, `StrategyDecision::RequestAnswer`), and its answer is narrated on its own (`FinishRequest`): "Nina agrees to Bob's request to <order>." when the new strategy key (`CurrentRequestKey`) equals the requested one (a free phrase: when the decision changed the strategy), else "Nina refuses Bob's request to <order>." No line when no decision was made (`kDropped`). A refusal is kept on the target (`ActorState::reasons`, a `PunishRecord`: `by` = order_actor, `target` = target_actor, `reason` = "Nina refused Bob's order|request to <order>", `strategyKey`, `request`, `type` `refused_strategy`; the last 8, one per `by` + key); an agreement removes it. Other mods add reasons with `AddPunishReason` (type `external`, SkyrimNet_DOM). Records are not saved.
- **Punish** (`OrgasmEngine::PunishNarrated(punisher, target, method, location, reason)`): the HUD key, auto play's `punish` key and the `SexLab_Scene_Punish` action (`CanPunish`) share one path. Anyone in a managed scene (any role, mini-game not required) can punish anyone else in it, the player included (`GetPunishInfo`). The HUD panel offers the verb only when `GetPunishReasons(target)` is not empty. The line: "<punisher> punishes <target> by <slapping / pinching / punching / pulling> <target>['s <part>], because <reason>." (`kPunishMethods`); a free phrase is the method as typed ("biting"); a method naming one of `Aid::PunishSpells` (weak attack spells, or with Injury Engine its torture spells) reads "by hitting <target>'s <part> with <spell>" (`Aid::PunishSpellDisplayName` drops Injury Engine's " (torture)" suffix) and queues a health hit of the spell's smallest magnitude when Injury Engine is not handling damage, never below 1 health (`Aid::QueueWeakSpellHit`; no cast, so no combat or bounty), then plays the spell's visuals (`PlaySpellVisuals`). "body" names no part; a reason that already starts with "because " loses it. **Hit, narrate, decide:** with Injury Engine's `External_TortureText` (`InjuryEngine::PunishText`) the hit lands silently and its feeling text comes back as a String ("Nina's nipples throb in tight, bruised points. …"); the line plus that text is narrated (`ContinuePunish`, same DirectNarration rule as Ask / Order) and is the `last_line_text` of the target's decision (trigger `punished`). A punishment for a reason that is a refused request then gets the answer line, "Nina agrees to|refuses Bob's request to <order>." Without `External_TortureText` (older Injury Engine) the hit goes through `External_Damage` with the line and Injury Engine narrates it; without Injury Engine the line is narrated alone. Callers narrate nothing; the Papyrus `Punish` always returns "".
- **Aid** (`Aid.cpp`, HUD Aid key and `SexLab_Aid`): healing / stamina spells (beneficial Value Modifier effects on Health / Stamina; base list plus `addedSpells`) and such potions. The restore is applied directly as magnitude × duration (a concentration spell as 3 s of casting) and the spell's magicka cost is spent; a potion is removed from the caster. Then `PlaySpellVisuals` plays each effect's casting art on the caster (spells), effect shader and hit art on the target, and release / hit sounds (3 s for concentration, else 2 s); nothing is engine-cast. The HUD greys the cell out via `Aid::HasOptions`, checked at most once a second.
- **Defaults** at `BeginScene` by role: `sexlab.minigame.default_strategy_normal` / `_aggressor` / `_victim` (Mutual / Selfish / Passive). Not announced. They are the fallback until the scene-start decision lands, and always without a decisions provider.
- **Announce** (every change): `Effect_StrategyChanged(actor, target, msg, observed, narrate)` shows no notification. `narrate` (API / Papyrus `SetStrategy`, NonSexual switches): `DirectNarration_Optional("sexlab_strategy", msg, …)`. Decision-made changes (`StrategySource::kDecision`): no narration, `SkyrimNetApi.RegisterEvent("sexlab_strategy", observed, …)`, a short-term event with how it looks to others ("Lydia appears to be focused on her own enjoyment.", `observed` in `strategies.json`). Both, and `Effect_NarrateDirect` / `Effect_NarrateOptional` (requests, Force, Aid), are capped by `sexlab.narration.minigame_level` (see [orgasm-narration.md](../reference/orgasm-narration.md)).
- **Prompt / HUD**: `Scene` writes `GetStrategyText` to the position obj `strategy` (0050 prompt: "<name> focuses on …"; the speaker's own line ends "Speak and act in line with that approach."); the HUD shows the label as a tag.
- `MCM.ApplyMiniGameActions` unregisters Arouse / Calm in Together mode (switching back needs save + reload). There are no strategy actions.

### Strategy decisions

`SKSE_Source/src/StrategyDecision.cpp` asks SkyrimNet's decision model through `PublicSendCustomDecisionToLLM` (public API v12+). One request decides one NPC (the *focus*), with the template `prompts/decisions/sexlab/minigame_strategy.prompt` (one `[ question strategy choice ]`). Off with `sexlab.minigame.decision_strategy` or in Together mode.

- **Triggers:**
  - *Scene start*: the tick marks a scene ready on the same rule as `StrategyStep` (first non-empty `SetStageTimers`, or `kUntimedGrace` after `BeginScene`) and dispatches `OnSceneReady(sid)` → one request per NPC (`SceneNpcs`). Once per scene (`decisionsStarted`); scenes restored from the co-save skip it.
  - *Asked / ordered / punished*: `RequestAnswer(target, trigger, line, done)` from `AskOrderNarrated` / `PunishNarrated`; `last_line_text` is the ask / order / punishment narration (trigger `asked` | `ordered` | `punished`). Its `done` callback runs exactly once (answer or `kDropped`).
  - *Dialogue*: `PublicRegisterEventCallback` for `dialogue`, `dialogue_npc` and `dialogue_background`. The originator, if a managed non-player actor, gets a request with the line (`data.text` / `dialogue` / `line`). In auto play, any line in the player's scene also sends a [player turn](#take-control-and-auto-play).
- **Threading:** SkyrimNet calls both callbacks on its ThreadPool. They only copy strings, then `AddTask`; context building, relationship lookups and `ApplyStrategyDecision` run on the game thread.
- **Push (`contextJson`)**, built from `OrgasmEngine::GetStrategyDecisionInput` under the engine lock: `trigger`, `focus_uuid`, `focus_name`, `last_line_text`, `role` (partner / aggressor / victim), `arousal` (0050 bands), `orgasms`, `expects_orgasm`, `timeline[]`, `partners[]` (`uuid`, `name`, `is_player`, `role`, `arousal`, `orgasms`, `relationship`, `relationship_rank`), `options[]` (`key`, `text`). The current strategy, earlier strategies, punishments and the scene progress are **not** sent (`current_key` stays in C++ for the kept / changed comparison).
  - **Timeline** (`BuildTimeline`): the focus actor's recent SkyrimNet events (`PublicGetRecentEvents`, oldest first, newest 15 lines) as one list of lines: speech "Bob said: …", the actor's own thoughts "Nina thought: …" (`npc_thoughts`; other actors' telepathic thoughts are skipped), DirectNarrations and other events as their text; spell / hit / combat / gamemaster events are skipped. Narration inside speech is pulled out onto its own line: `kiss me *bob leans in*` -> "Bob said: kiss me", "Bob leans in." Ask / order / refuse / punish narrations are DirectNarrations, so they appear here as events. The question ranks `last_line`, then the actor's thoughts, then recent over older events.
  - **Options** are only what `StrategyAllowed` permits now, so the model cannot pick an illegal one. Deny / Tease / Focused expand to one option per valid target, key `<key>_p<slot>` (1-based SexLab position); the text comes from `option` in `strategies.json` with names and pronouns filled in.
  - **Relationship**: Skyrim's rank between the focus and each partner, `BGSRelationship::GetRelationship` on the actor bases (template bases as a fallback): `4 − level`, labels lovers / allies / confidants / friends / acquaintances / rivals / foes / enemies / archnemeses; no relationship form is `strangers` (0).
- **Pull (template):** `decnpc` and `render_character_profile("short_inline", …)` for the focus and its partners; `sexlab_get_threads(focus_uuid)` for the act and location; `last_line_text`; `timeline` (above).
- **Answer:** `answers.strategy.choice` and `answers.strategy.confidence` → `ApplyStrategyDecision`, which returns a `DecisionResult`: `kDropped` when the scene ended or its `generation` changed (bumped when the roster changes; a reused sid gets a new one); the `_p<slot>` suffix resolves through the snapshot's `slots`; same key and target = `kKept` (quiet); a change with a reported confidence under `sexlab.minigame.decision_min_confidence` (default 0.6; no confidence reported = no floor) = `kLowConfidence`, current strategy stays; else `SetStrategyLocked` with narrate off (`kChanged`).
- **Coalescing:** one request in flight per NPC; a line arriving meanwhile is kept and sent once the answer lands. An ask / order / punishment arriving meanwhile becomes that follow-up (later dialogue does not replace it); several waiting ones share its answer.
- **Failure:** `no_decisions_route` warns once and stops asking until the next load (role defaults stay); other errors are logged. Log lines: `StrategyDecision: send …`, `answer <key> p=… (changed | kept | low confidence, kept current | unknown key | dropped: scene ended or roster changed)`.

### Take control and auto play

The HUD take-control key (`sexlab.hud.key_take_control`, default Num \*, controls group) is in the HUD keys and, while the HUD is down, an unconsumed `KeyHandler::Register` callback (ignored while a blocking menu or the WebUI is open). `Hud::OnTakeControl`:

- **Player in a managed scene:** toggles `OrgasmEngine::SetAutoPlay` (player `ActorState::autoPlay`); turning it on assigns the role default (the Passive `BeginScene` gave is a placeholder) and calls `StrategyDecision::OnAutoPlay`.
- **Sticky:** `SetAutoPlay` also sets `g_autoPlaySticky` (co-save v8). While it is set, `BeginScene` turns `autoPlay` on for the player as a newcomer, before the role default is picked (log `auto play on (scene N, sticky)`), so the scene keeps the gate and gets its `scene_start` player turn. Only the key turns it off.
- **Else, already controlling an NPC:** releases it (`SetPlayerDriven(npc, false)`).
- **Else, crosshair actor (`CrosshairPickData::GetActiveTarget`) in a managed scene:** `SetPlayerDriven(npc, true)` (`ActorState::playerDriven`) and `Hud` keeps it as the anchor `g_anchor`.

`AiDriven(st)` (player: `autoPlay`; NPC: `!playerDriven`) gates `StrategyAllowed`, `StrategyStep`, the default migration, `GetStrategyDecisionInput`, `SceneNpcs`, `GetStrategyText` and the HUD strategy label. Both per-actor flags end with the actor's `ActorState` (scene end, or moving to another scene); the player's comes back from the sticky flag at the next scene and on load.

**Anchor (Hud.cpp):** `ActingLocked()` is the anchor NPC, else the player. `Tick` builds the HUD from `GetActorScene(acting)` and uses the acting actor for pause, stage, speed, Punish info and the blocked flags; it releases the anchor when its scene is gone or the player's own scene starts. Arouse / calm are paid by the acting actor; speed steps its scene; Punish opens with every actor of the acting actor's scene (`GetPunishInfo(acting)`, each with `Aid::PunishSpells`) and the acting actor as the default subject (the panel is Ask / Order / Punish: see [WebUI](webui.md)); `onPunishResult` → `AskOrderNarrated` or `PunishNarrated` on the game thread; Aid is hidden and ignored while controlling. `DispatchMenuKey` passes the anchor as the third argument of `Menu.Hud_OnKey(control, focus, anchor)` (None: the player), which works on `GetSceneByActor(anchor)`; deny goes through `Scene.ToggleDenyOrgasm(actor, denier)`. `ResolveFocus` picks the first actor other than the acting one. HUD push: `takeControlLabel` (`auto` = hand to AI, `control` = take back from auto play, `release` = stop driving an NPC) and `acting` (the anchor's name, "" in the player's own scene).

**Player turn (auto play, `StrategyDecision.cpp`):** template `prompts/decisions/sexlab/minigame_player_turn.prompt` (same timeline rules as the NPC template; it says Passive only fits someone reluctant, exhausted or uninterested). Sent when auto play turns on (`auto_play`, asks to speak), at scene start (`scene_start`, from `OnSceneReady` when the player is in `SceneNpcs`) and after every line anyone in the player's scene speaks (`dialogue`; asks to speak unless the player said it). Needs the same gates as NPC decisions (`IsStrategyDecisionEnabled`, decisions provider). One request in flight; a later line is kept for one follow-up.

- **Push:** the strategy context with the player as focus, plus `last_speaker` ("" = the player), `has_strategy` (2+ options), `ask_speak`, `hotkeys[]`, `aid_options[]`, `punish_options[]`, `punish_methods[]` (`key`, `text` each) and `parts` (body / pussy / ass / nipples).
- **Hotkeys** offered (what the HUD allows now): `none`, `previous` (stage > 1), `next` (stage < count), `pos_up` / `pos_down` (2+ actors), `slower` / `faster` (not at that end), `pause` (pause or resume), `deny_p<slot>` / `allow_p<slot>` per other actor, `end`, `aid` (affordable `Aid::ListOptions`, up to 20 `aid_<n>` "cast / use <option> on <actor>"), `punish` (`GetPunishInfo(player)`: everyone else as `punish_<n>`; methods slap / pinch / punch / pull and `spell_<n>` per `Aid::PunishSpells` entry: weak attack spells, or with Injury Engine the torture spells the player knows).
- **Answer** (game thread, dropped when auto play is off or the scene changed): `strategy` → `ApplyStrategyDecision`; `hotkey` (floor `decision_min_confidence`, 0.8 for `end`, at most one press per 5 s) → `Hud::PressKey` (deny with the slot's actor), `aid` → `Aid::Apply(player, target, form, aid_part)` + `NarrateDirect`, `punish` → `PunishNarrated(player, target, method, punish_part, "")` (no reason: a decision can't write free text); then `speak.noul` ≥ 0.5 (at most one line per 5 s) → `Hud::PressKey("speak")` → `Menu.Hud_OnKey` → `SkyrimNetApi.TransformDialogue("<player> replies")`. Log lines: `StrategyDecision: send player turn …`, `player strategy …`, `player pressed …`, `player speak p=…`.

## Tick

For each managed scene:

1. **Passive gain** (Mini-game mode and DOM slaves; Together uses the curve above): `enjoyment += baseRate × roleMult × jitter × Π rate modifiers × (1 + minigame_bonus_mult × bonus) × anim speed × dt`. In Mini-game mode (not DOM slaves, timed scenes), `baseRate × roleMult` is replaced by `mgPassiveRate × roleMult / passive_mult` (see [Mini-game calibration](#mini-game-calibration)).
   - **Base rate, from the stage timers.** `Engine_SetStage` sends `SetStageTimers(sid, stageSecs, leadIn)` with each stage's seconds, using `sslThreadController.GetTimer`'s rule: `Animation.GetTimer(s)` when `Animation.HasTimer(s)`, otherwise `thread.Timers`.
     - `targetSecs` = the sum of stages 1..N−1, plus 0.9 × the final stage.
     - `baseRate = 100 / targetSecs`. It is fixed per animation, and enjoyment carries over when the animation changes.
     - LeadIn: `targetSecs` = all stages × 1.5, so no one reaches 100.
     - No timers: a flat 0.5/s.
   - **The rate is fixed; it is not "remaining ÷ time left".** Extra time adds enjoyment: repeating a stage or a slow narration (a paused stage still gains at the normal rate). Real scenes usually run 2–3× their stage timers, which is why the default multipliers are well below 1.0.
   - **`roleMult`:** `sexlab.enjoyment.passive_mult` (0.4), `aggressor_mult` (0.45) or `victim_mult` (0.3).
   - **`jitter`:** rolled per actor at `BeginScene`, uniform in [`jitter_min`, `jitter_max`] (0.95–1.1).
   - **Anim speed:** `AnimSpeed::Get`, which is the style speed multiplied by the HUD's faster/slower scale.
   - **Not expected to orgasm:** positions with AnimDB `orgasm_expected` 0, or the scene's `no_orgasm` 1, get no passive gain. Not expected is **not** a block: orgasm checks run as normal. `Scene.ApplySexLabVoice` keeps SexLab silent below 50 enjoyment (`VOICE_GATE_ENJOYMENT`, re-checked in `Mirror_Apply`). The only scene block (`SetSceneBlocked`) is the player's `deny_orgasm` (HUD `sexlab.hud.key_deny` → `Menu.Hud_OnKey("deny", focus)` → `Scene.ToggleDenyOrgasm`; Description Editor `_deny_pos`). Positions with AnimDB `orgasm_expected` 0 get no passive gain (DOM slaves: no `domProgress`). `Engine_SetSkills` sends `SetOrgasmExpected(actor, expected)` at start and on each animation change; missing data counts as expected. Mini-game Arouse / Calm still move their enjoyment, and the no-timer safety net still needs 90 for them.
   - Expected results at normal speed with no mini-game:
     - A normal actor usually stays below 100; the gate before the final stage decides the orgasm (`enjoyment + random(0, random_bonus) + stage_spike ≥ 100`).
     - Each stage advance adds `sexlab.enjoyment.stage_spike` (5) to every expected actor (`SetStage`; DOM: `domProgress`).
2. **Orgasm test:**
   - The test value is `enjoyment`. With the mini-game on, once a second it becomes `enjoyment + random(0, random_bonus)`.
   - An orgasm fires at 100 or more when:
     - no scene block is set (`no_orgasm` / deny),
     - the actor is not a DOM slave (see [DOM slaves](#dom-slaves)),
     - no plugin block is set,
     - the actor is not edging, and
     - the cooldown has passed (SexLab's rule: 10 s female, 20 s male, +10 s creature).
   - A blocked actor at 100 sends `OrgasmDenied` once per climb.
   - A **forced** request (the WebUI orgasm button, `RequestOrgasm(…, true, …)`) skips every gate.
3. **Gate (Together mode, or an AI-driven mini-game scene; `sexlab.ending.gate`, timed scenes, never in LeadIn; Together skips the roll, everyone expected passes):** each actor who has not orgasmed in this scene, is expected to orgasm and passes `CanOrgasmNow` rolls once: `enjoyment + random(0, random_bonus) + stage_spike ≥ 100` (`RollOrgasm`).
   - **AI-driven mini-game (`aiGate`):** `SceneAiDriven(sc)` — every non-DOM actor is `AiDriven` (NPCs; the player only on auto play), re-checked each tick. Earlier orgasms do not skip the gate. The ending lead (`SetEndingTarget`, target > 0) passes without a roll; in the second-to-last stage its cooldown is ignored (block, DOM, edging and a failed final roll still stop it). **Every aggressor expected to orgasm passes the same way**, whatever its enjoyment or earlier orgasms, so it always finishes in the gate group. A victim follows its aggressor's strategy: an aggressor on Focused targeting it passes it outright, one on Tease or Deny targeting it keeps it out of the gate and the gate join (`teased=true` on `gate skips`), anything else rolls. An actor with a pending (non-forced) request passes; the rest roll. From the second-to-last stage on, non-rushing, non-DOM actors are capped at 98 and skip the orgasm test (a forced request still fires), so the gate's orgasm is the scene's last and the final stage is held for its response (`Ending_Hold`). Taking control of anyone drops back to the free mini-game. Log `ai_gate=` / `ending_lead=` / `aggressor=` / `forced_victim=` on the `gate` lines. The cap is applied after the strategy step, so an `arouse … -> 98.7` (or 100) line shows the value before the hold.
   - **When:** `lead` + 2 s (`kGateDispatchMargin`: tick → Papyrus → `UpdateTimer`, so `Gate_Hold` lands before SexLab's timer) before the second-to-last stage's timer ends (animating, unpaused time; on entering it when `lead` is longer), or on reaching the final stage first. `lead` = `NarrationTiming::EstimateSeconds`: the median of the last 20 clean DN→first-speech samples this session, `sexlab.ending.gate_lead_default` (5 s) until 3 exist, clamped 1–30 s.
   - **A pass does not fire yet.** The actor is *rushing*: enjoyment climbs at `(98 − enjoyment) / lead` per second (no passive gain, pause and speed ignored, capped at 98 before the final stage, no other orgasm test). `Effect_GatePassed(actors, holdStage)` → `Scene.Engine_GatePassed` stashes the passers and sends one DirectNarration at once, then calls `GateNarrationSent(sid, mark)` with the `NarrationMark()` (`NarrationTiming::SpeakerMark()`) it took just before the DN, so a voice that starts before the call still counts (-1: mark now).
   - **Before the final stage** the Scene holds the stage (`Gate_Hold`, `UpdateTimer` like the pause key). The first `SkyrimNet_SpeechStarted` by one of **this scene's** non-player actors after the mark (`NarrationTiming::StartedSince(mark, actors)`; another scene's reply does not count) makes the tick dispatch `Effect_AdvanceToFinal` → `Scene.Engine_AdvanceToFinal`: release the hold, `Ending_ToFinal` (final stage + dialogue hold). No voice by `sexlab.ending.gate_wait_max` (20 s): `Gate_Poll` advances anyway. SexLab reaching the final stage first also ends the wait.
   - **In the final stage** the rush finishes within 1 s and fires at 97 as a `gate` group: `Fire` only, no group join, no extras fold. `Orgasm_ApplyGroup` runs `ForceOrgasm` and skips the stash and narration.
   - **Gate join:** when anyone passes, every other actor who is expected to orgasm, passes `CanOrgasmNow`, isn't rushing and is at ≥ `group_join_final` rushes with them and goes into the same gate DN. Repeat orgasms join too (only rolling skips them). Log `gate join`.
   - A block (deny) cancels the rush. A forced request fires through the normal path. Stepping back before the last two stages drops the rush and re-arms the gate. Rushes are not saved.
   - All fail: SexLab advances normally, no orgasm.

   **Safety net (Together mode; gate off, or no timers):** at 90% of the final stage's timer, each non-DOM actor at 90 or more who has not orgasmed, is not blocked or edging and was not calmed in the final stage fires as *combined*. With no timers it fires on entering the final stage, everyone when the mini-game is off.
4. **Group (`JoinGroup`):** everyone fired in this scene in this tick (steps 2 and 3, forced included) is one group. Every other actor who passes `CanOrgasmNow` (not a DOM slave, blocked, edging, cooling down or out after a final roll) and isn't rushing joins outright at ≥ `sexlab.enjoyment.group_join` (default 85, log `group join`). Below that it rolls once: `enjoyment + random(0, random_bonus) ≥ 100` (`RollOrgasm`, `sexlab.minigame.random_bonus`, default 10). Passers join the group. Repeat orgasms join or roll too. Log `group roll`.
   - **Early final roll:** in the second-to-last stage of a timed, non-LeadIn scene, when the Scene's ending lead (`SetEndingTarget`) is in the group and has reached the target (the Scene is about to jump), everyone still out rolls again with `enjoyment + random(0, random_bonus) + stage_spike ≥ 100`. A pass joins this group, so it goes into the same DN. A fail sets `finalRollFailed`: no more orgasms (no denied event either) until the scene steps back before the last two stages, except a forced request. Not saved. Log `final roll`.
   - The same `JoinGroup` runs for `NoteExternalOrgasm` and `AllowOrgasm`.

   The group is sent as one `Effect_OrgasmGroup`, so it gets one narration. It is `individual` unless every trigger came from the safety net. Pending arouse/calm narrations about the group's actors are flushed as short-lived events at the same time (`extras` stays empty).
   `FinalStageRemaining(sid)` (native) returns the final stage's timer minus its animating, unpaused seconds, or -1 outside a timed final stage. `Scene.OrgasmWindow_HoldForFinish` uses it.
5. **Mirror:** at most once a second per actor, `Effect_Mirror` → `AdjustEnjoyment(ours − SexLab's)`, so SexLab voices and expressions follow our value.

**Firing an orgasm:**
- The engine sets `enjoyment = 0` and counts the orgasm for each group member, then dispatches `Effect_OrgasmGroup(actors, forced, individual, source, allower, allowed, extras)` → `Scene.Orgasm_ApplyGroup`. `forced[i]` is 1 for a WebUI forced request. `Effect_Orgasm` remains as a one-actor wrapper.
- `Orgasm_ApplyGroup` calls `SexLabForceOrgasm` (SexLab's cum, sound and `SexLabOrgasm`; with SLSO, `sslActorAlias.Orgasm(-2)` through native `SLSOForceOrgasm` so SLSO's 5 s guard can't drop it, else `thread.ForceOrgasm`) for each actor, then narrates once, following [../reference/orgasm-narration.md](../reference/orgasm-narration.md).
- **Allow:** `AllowOrgasm(actor, allower)` (deny 1 → 0) does the following under one lock, so the tick can't fire first without the prefix:
  - clears the scene block,
  - fires every actor in the scene who can orgasm and is at 100,
  - runs the group join,
  - tags the group with `allower` / `allowed`, which gives the `"<allower> allowed <actor> to orgasm. "` prefix.

  It returns whether anyone fired.
- **External orgasms** (`NoteExternalOrgasm`) run the group join too. The joiners go out as a non-individual group (stash + window), while the caller narrates the external actor, so both share one DN.
- `Scene_Manager.OrgasmIndividual` ignores `SexLabOrgasm` for managed actors, so an orgasm is never narrated twice.

**Thread hooks** are sent at SexLab's timing, not per orgasm:
- `Scene.Engine_SetStage` sends `OrgasmStart` once, on entering the final stage of a non-LeadIn animation.
- It sends `OrgasmEnd` on leaving that stage, or at `AnimationEnd` if the hook is still open.
- An early orgasm therefore does not use up DOM's once-per-scene hook roll.

## Mini-game calibration

`CalibrateMiniGame` (from `SetStageTimers`) sets each mini-game scene's rates **once**, from its first non-LeadIn animation's timers. Goal: with every NPC on Mutual, each actor reaches `sexlab.enjoyment.mutual_target` (87) at the end of the second-to-last stage. The final stage's spike (+5) then makes it 92, and the once-a-second random roll fires the orgasm early in the final stage.

- `T` = seconds of stages 1..N−1 (N = 1: stage 1). `spikes` = (N − 2) × `stage_spike` (the advances into stages 2..N−1).
- `budget` = clamp(target − spikes, 0.25 × target, target). `R` = budget / T, per actor per second.
- `mgPassiveRate` = `passive_share` (0.3) × R; `mgStepRate` = (1 − passive_share) × R.
- Roles: `roleMult / passive_mult`. With 0.4 / 0.45 / 0.3: normal 1.0, aggressor 1.125, victim 0.75. Jitter, rate modifiers, the bonus factor and anim speed apply as before.
- **Fixed:** later animations keep the rates, and so does a config change. Extra time adds enjoyment on purpose: pause, a stage back, long narration (multiple orgasms).
- **LeadIn first:** provisional rates (all LeadIn stages × 1.5, no spikes) until a main animation calibrates. **No timers:** the fallback rate and fixed steps.
- **Player scenes:** each NPC step is sized for one actor. With player + NPC on Mutual and an idle player, both reach about 60; the player has to play.
- Log: `mini-game calibration T=… spikes=… budget=… passive=…/s steps=…/s`.

## Pause

- The HUD key `sexlab.hud.key_pause` (default Num 5) goes through `Menu.Hud_OnKey("pause")` to `Scene.TogglePause`.
- `StageTimer` and `TimedStage` are private to `sslThreadController`, so the Scene uses its public functions instead:
  - **Pause:** `thread.UpdateTimer(100000)` pushes the stage's timer far out.
  - **Resume:** `thread.UpdateTimer(held − 100000)` puts back the remaining time, then `thread.ResolveTimers()` restores `TimedStage = Animation.HasTimer(Stage)`.
- `StageStart` re-applies the hold while paused, because `GoToStage` resets the timer. It is applied once per (animation, stage). Manual previous/next still work.
- `SetScenePaused` tells the engine. That drives the HUD's "Paused" tag and its **pause**/**resume** label, stops the safety-net clock. It does not affect passive gain, which continues as normal.
- **SexLab P+:** `UpdateTimer` sets `_ForceAdvance` there, so pause, resume and every other hold go through `PauseTimer` (`Scene.Timer_SyncHold`, re-asserted each StageStart and 1 s poll). See [sexlab-pplus.md](sexlab-pplus.md).

## Mini-game

`Arouse(who, target, mult)` / `Calm(who, target, mult)` are shared by the HUD keys (`mult` 1; also LMB calm / RMB arouse when `sexlab.minigame.mouse` is on), the LLM actions `SexLab_Arouse` / `SexLab_Calm` (`mult` = `sexlab.minigame.llm_multiplier`) and the plugin API. A HUD press targets the focus actor; with Shift held (`Hud::ShiftHeld`, the game's keyboard `curState`) it targets the next actor in the list instead, wrapping, and the focus stays. The HUD gets that row as `shiftTarget` and marks it `⇧`.

| | Effect |
|---|---|
| Arouse | Costs `who`'s stamina: `stamina_cost × 10/(10+skill)`. Adds `arouse_amount × mult × (1 + 0.1 × skill)`. |
| Calm | Costs `who`'s magicka: `magicka_cost × (1 + 0.05 × lewd)`. Removes `calm_amount × mult`, but never below 0. If the target was at 90 or more, it **edges**: no orgasm test for `edge_seconds`. |
| Skill / lewd | `skill` is SexLab's skill level for the act, picked by animation tag (Vaginal, Anal, Oral, else Foreplay). `lewd` is lewd level − pure level. Both are sent by the Scene script at start, on each stage and on an animation change. |

**Narration**
- Acting on someone else is narrated as `"<A> arouses <B>, pushing them closer to orgasm."` or `"<A> calms <B>, keeping them further from orgasm."`.
- Presses are coalesced per (who, target, action) inside `narrate_window`.
- It is sent through `Effect_Narrate`, as is the HUD faster/slower narration (`sexlab_speed`). All of these are optional, and this includes scenes with the player:
  - They go through `DirectNarration_Optional`, which sends a `DirectNarration` only when `NarrationCoolOffAllows` (the speech queue is empty and the cooldown, last-audio and distance checks pass).
  - Otherwise it falls back to `RegisterEvent`, so nothing is dropped.
  - Orgasm and finish narrations are the exception: in NPC-only scenes they use `DirectNarration_Nearby` (distance only). See [../reference/orgasm-narration.md](../reference/orgasm-narration.md).
- Source and target are always passed.
- Acting on yourself is silent.

## DOM slaves

DOM (Diary of Mine) decides a DOM slave's orgasm itself. The engine does not block these actors; it drives DOM instead (`SetDomSlave`, sent by the Scene).

Goal: with no mini-game, arousal grows by the same total as in a vanilla DOM scene, but spread over the animation. DOM still decides the orgasm. A new slave does not orgasm at first. `arousal_factor` carries across scenes, so a slave becomes more orgasmic over time; the engine does not correct for that.

- **Progress:** the slave's passive curve (see [Tick](#tick)) feeds `domProgress`, which runs 0→100 over a normal scene. It never changes the slave's enjoyment.
- **Steps:** every 10 progress points (about 10 pushes per scene), `Effect_DomSync` → `Handler_DOM.DomSync` calls:
  - `IncreaseArousal(10 × sexlab.dom.arousal_scale, MOD_Daring)`, with a default scale of 0.2;
  - in player scenes, also `IncreaseArousal(10 × sexlab.dom.arousal_scale_player, MOD_Naivety)`, also 0.2 by default.
- **Prepay:** DOM adds 20 (`MOD_Daring`) itself at scene start, and 20 (`MOD_Naivety`) at its roll in player scenes.
  - The first sync of the scene subtracts those amounts from `arousal_factor` using `Handler_DOM.DomArousalValue`, a copy of `IncreaseArousal`'s formula.
  - Whatever cannot come off without going below 0 becomes a debt (StorageUtil `skyrimnet_sexlab_dom_debt` on the actor). Later steps pay it first.
  - One-time adds are not cancelled: virginity, first act, same-sex, kink.
  - The engine logs `dom step` lines, and Handler_DOM traces the prepay.
- **Mini-game:** Arouse and Calm still push at once, as `IncreaseArousal(delta, MOD_SocialBoldness)` or a direct drop in `arousal_factor`.
- **Step roll after every rise** (`Handler_DOM.StepRoll(actor, hasPlayer, share)`):
  - It runs only when the actor is not blocked (`no_orgasm` / deny / plugin block), not edging and not cooling down.
  - It is a light roll, not `handleSexOrgasm`:
    1. `mind.IsArousedAfterSex(MOD_Daring)`.
    2. If `CouldOrgasm`: `mind.IsOrgasmingAfterArousal(actBase × share)`. `actBase` is the best `MOD_Vaginal` / `MOD_Anal` / `MOD_Oral` among the acts played (1000 with DOM's separate orgasm on).
    3. On success, it does what `handleSexOrgasm` does: `SendExternalEventSS("Orgasm", sex|rape|masturbate)` and `DOM04.NotifyOrgasm`.
  - `share` is 0.1 per passive step, plus `arouse amount / 100` for Arouse. Below 0.5, DOM's chance is linear in `base_chance`, so about 10 rolls at 1/10 add up to roughly one full roll.
  - Known bias: DOM's male `×2 + 0.1` and its additive bonuses apply to every step.
- **DOM's own roll is kept:** DOM makes one full `handleSexOrgasm` from the `OrgasmStart` hook at the final stage, or at `AnimationEnd` if the hook never fired.
- **Melt:** DOM's "brain melts" notification reaches `Handler_DOM.DOMSlave_Orgasmed`. It calls `NoteExternalOrgasm(slave, "dom")` (count, cooldown, HUD flash, `SkyrimNet_SexLab_Orgasm`), then narrates DOM's text through `OrgasmCustom`.
- **Bar:** `Handler_DOM.OrgasmMeter` is pushed with `SetDomMeter` after every sync, and the HUD tags the actor "DOM".
  - Below 50: not aroused yet. The value is `50 × min(arousal_factor, 100)/100`.
  - 50–100: aroused. The value is `50 + 50 × min(1, chance/0.5)`.
    - `chance` holds the fixed terms of `IsOrgasmingAfterArousal`, based on the best act modifier (1000 with DOM's separate orgasm on).
    - The random terms (orgasm control, whipping, promise) are left out.
  - Refractory: capped at 49.
- A blocked DOM slave sends `OrgasmDenied` once the bar reaches 50.
- The safety net skips DOM slaves. A forced WebUI request still fires them directly.
- The `dom` flag, progress, step remainder and prepaid flag are saved in the co-save.

## Papyrus API (`SkyrimNet_SexLab_OrgasmEngine`)

`source` is a free-form owner id. Blocks and rate modifiers are keyed by it, so two plugins never clear each other's state.

```papyrus
float GetEnjoyment(Actor)                     SetEnjoyment(Actor, float, String source)
AddEnjoyment(Actor, float delta, String src)  bool Arouse(Actor who, Actor target, float mult = 1.0)
bool Calm(Actor who, Actor target, float mult = 1.0)
Edge(Actor, float seconds, String source)
SetRateModifier(Actor, String source, float mult)   ClearRateModifier(Actor, String source)
SetOrgasmBlocked(Actor, String source, bool)        bool IsOrgasmAllowed(Actor)
RequestOrgasm(Actor, bool force, String source)
int GetOrgasmCount(Actor)   float GetSecondsSinceOrgasm(Actor)   bool IsManaged(Actor)
bool IsMiniGameEnabled()
SetRates(float passive, float aggressor, float victim)   ; role multipliers, runtime override until the next config save
bool SetStrategy(Actor, int strategy, Actor target)  int GetStrategy(Actor)   ; mini-game NPC strategies (ids in the shell); narrated
String GetStrategyText(Actor)   int StrategyId(String key)
bool AskOrder(Actor by, Actor target, bool order, String key, String text)   ; ask / order a strategy; narrates the request and the answer
Function AddPunishReason(Actor by, Actor target, String reason)   ; a reason target can be punished for (SkyrimNet_DOM)
```

The shell-only natives (`BeginScene`, `SetStage`, `SetStageTimers`, `SetScenePaused`, `GateNarrationSent`, `SetEndingTarget`, `SetSceneBlocked`, `SetDomSlave`, `SetDomMeter`, `SetActorSkills`, `EndScene`, `ResetSpeedScale`, `ReloadConfig`, `AllowOrgasm`) are for this mod's own Scene and MCM scripts. `AllowOrgasm` is not in the C++ API.

## ModEvents

`sender` is the affected actor, and `strArg` is `"<source>|<acting actor FormID>"`.

| Event | numArg |
|-------|--------|
| `SkyrimNet_SexLab_Orgasm` | orgasm count this scene |
| `SkyrimNet_SexLab_OrgasmDenied` | orgasm count |
| `SkyrimNet_SexLab_Edge` | edge seconds |

## C++ API

Copy [`SKSE_Source/include/OrgasmEngineAPI.h`](../../SKSE_Source/include/OrgasmEngineAPI.h) into your plugin. It is self-contained.

```cpp
#include "OrgasmEngineAPI.h"
// at or after SKSE kPostLoad
if (auto* engine = SKYRIMNET_SEXLAB_API::RequestOrgasmEngine()) {
    engine->SetRateModifier(actor, "my_vibrator", 2.0f);
    engine->RegisterEventCallback([](const SKYRIMNET_SEXLAB_API::EngineEvent& e) { /* main thread */ });
}
```

`IOrgasmEngineV1` mirrors the Papyrus API and adds event callbacks. `IOrgasmEngineV2` (`RequestOrgasmEngineV2()`, `InterfaceVersion::V2`) adds `SetStrategy` / `GetStrategy`; V1 requests get the same object. Calls are thread-safe. The export is `RequestOrgasmEngineAPI(InterfaceVersion)`.

## Persistence

- The co-save record `'ORGE'` (version 7) holds:
  - per scene: stage, stage timers, LeadIn, pause and the final-stage clock;
  - per actor: enjoyment, orgasm count, role, skill, jitter, blocks, rate modifiers and DOM step state;
  - v4: gate state; v5: the stage clock, and per actor the bonus, curve progress, strategy, target and forcer; v6: per actor stamina regen (before v6: 100); v7: per scene the mini-game rates (before v7: calibrated from the saved timers on load).
- Versions 1 and 2 still load; their scenes use the fallback rate until the next stage. Before v5: bonus 0, Passive, curve rebased to the current progress.
- A revert (load or new game) clears everything.
- The faster/slower scale is not saved; style speeds are not restored on load either.
- A scene with no actor in `SexLabAnimatingFaction` for 10 s is dropped. This is the safety net for a missed `AnimationEnd`.

## Other plugins that use SexLab directly

Older plugins call SexLab rather than the engine. The engine picks up both kinds of change.

- **Their orgasms** (`thread.ForceOrgasm`, `sslActorAlias.OrgasmEffect`):
  - Each orgasm the engine fires counts one "own orgasm in flight" for that actor.
  - When `Scene_Manager.OrgasmIndividual` gets `SexLabOrgasm` for a managed actor, it calls `ConsumeOwnOrgasm`. If that returns true, the event was ours and was already narrated.
  - Otherwise `NoteExternalOrgasm(actor, "sexlab")` records it like one of ours (enjoyment 0, count, cooldown, HUD flash, `SkyrimNet_SexLab_Orgasm` event with source `sexlab`). The Scene then narrates it once (`OrgasmIndividual(…, from_engine=true)`; DOM slaves are skipped as before).
- **Their enjoyment changes** (`AdjustEnjoyment`):
  - `Scene.Mirror_Apply` keeps the SexLab value it last left (position obj `sl_mirror_set`).
  - On the next mirror, if SexLab moved by 3 or more (`MIRROR_EXTERNAL_THRESHOLD`), that move is added to the engine (`AddEnjoyment(…, "sexlab")`) before mirroring, so it is kept rather than overwritten.
  - SexLab's own small time drift stays under the threshold.
  - The baseline is dropped where SexLab jumps by itself: after an orgasm (the `QuitEnjoyment` reset) and on every stage change (the stage term).
  - The baseline also stores the stage and animation it was taken at (`sl_mirror_stage`, `sl_mirror_anim`). A baseline from another stage or animation is never folded in. SexLab's stage term (about +10) often steps up one mirror before `Engine_SetStage` rebaselines; before this fix it leaked in as `SexLab added 10` on every stage change.

## Scene ending

`Scene.psc` `Ending_*` (settings `sexlab.ending.*`):

- **Target:** `Ending_RollTarget` (from `Engine_BeginScene`, once per scene) picks the lead: `initiator` (`PickNonVictimInitiator` makes it the aggressor when there is a victim), else position 0. Target = `RandomInt(target_male_min, target_male_max)` for SexLab gender 0, else the female range. 0 = never jumps.
- **Engine:** `Engine_SetEndingTarget` (every `Engine_BeginScene`) sends `SetEndingTarget(sid, lead, target)`. The target is 0 once `ending_done` is set or `sexlab.ending.enabled` is off. The engine uses it for the early final roll.
- **Jump:** `Ending_Check` (end of `Orgasm_ApplyGroup`, after the engine's group roll) compares `OrgasmEngine.GetOrgasmCount(lead)` with the target. Reaching it in the second-to-last or final stage calls `Ending_ToFinal` → `thread.GoToStage(final)`. Earlier stages: no jump (`ending_done` stays false). The gate's `Engine_AdvanceToFinal` (its narration's voice started) does the same after releasing the gate hold. Once per scene (`ending_done`), never in LeadIn.
- **Aggressor ends (no gate only):** in a scene the engine does not gate (`OrgasmEngine.IsGateScene(sid)` false: someone under the player's hand), an NPC lead in an aggressive scene (`thread.IsAggressive`, lead not a victim) reaching the target at any stage holds the current stage (`Ending_Hold`, `ending_end_after`). `Ending_Poll`'s release then calls `thread.EndAnimation()` instead of releasing the timer, even with `dialogue_hold_max` 0 (ends at the first poll). In a gate scene an early aggressor orgasm does not end the scene: the aggressor may orgasm again and always passes the gate.
- **Dialogue hold:** on the final stage's `StageStart` (`Ending_StageStart` → `Ending_Hold`) the stage is held with `thread.UpdateTimer(PAUSE_HOLD_SECONDS)`, as the pause key does. A stage change under the hold (the hold landed as SexLab turned the stage) applies it again to the new stage, once per (animation, stage).
  - **Response:** every orgasm DN (`NarrateOrgasmStash`, the `StageStart` fold) first takes `ending_response_mark = OrgasmEngine.NarrationMark()` (`NarrationTiming::SpeakerMark()`). `NarrationTiming` tracks each non-player speaker's response (first `SpeechStarted` to its `SkyrimNet_SpeechComplete`). `ResponseStartedSince(sid, mark)` / `ResponseDoneSince(sid, mark)` only count the scene's own actors (`OrgasmEngine::SceneActors`), so two scenes narrating together don't release each other's holds (2026-10-08).
  - **Release** (`Ending_Poll`, shares `OnUpdate` with the orgasm window, 1 s; held ≥ 2 s, window closed): `ResponseDoneSince(mark)` (log `(response played)`). While one of the scene's actors is speaking after the mark, wait. With no paired response yet (the DN went out as an event, TTS off): `GetSpeechQueueSize() == 0` and audio ended at least 1 s after the first poll, min 3 s (`(speech queue empty)`). Always at `dialogue_hold_max` (30 s, capped at `ENDING_HOLD_CAP` 30; 0 = no hold; `(max)`).
  - Release takes the hold back off (`UpdateTimer(-PAUSE_HOLD_SECONDS)`) without adding the held time: the final stage ends at the later of its own timer and the response. While the pause key holds the stage the timer is left to the pause.

## SexLab P+

The engine itself is unchanged; the Scene shell feeds it a linear view of P+'s scene graph ([sexlab-pplus.md](sexlab-pplus.md)):

- **Stage / count / seconds:** `Engine_StageCount` is the projected path (played history + longest path from the active stage to a sink); `thread.Stage` (history length) is the index, so the gate stage is the node before a sink and the final stage is the sink. `Engine_StageSeconds` uses P+'s per-node rule (`GetFixedLength`, climax stage = last timer, else the config timers). A branch changes the path; `SetStageTimers` then restarts the Together curve from current enjoyment.
- **Holds:** pause, gate and ending holds are one `PauseTimer` (`Timer_SyncHold`), never `UpdateTimer`.
- **Jump to final:** `Ending_ToFinal` calls `SkipToSink` (the path's sink) instead of `GoToStage(count)`, which is one edge on P+.
- **Finish:** after the dialogue hold the final stage stays paused and `Ending_Watch` calls `EndAnimation()` at the stage's remaining time, so P+'s enjoyment-wait (`ThreadWaitsForOrgasm` → restart) never runs. `Scene.PPlus_StageStart` ends a thread P+ restarted from an expired sink anyway, and `DURATION_CAP_SECONDS` counts from the first sink.
- **Hooks:** no synthesized `OrgasmStart` / `OrgasmEnd`; P+ sends its own at climax stages.
- **Skills:** act tags come from the registry (`Scene.AnimHasTag`), not the empty proxy.

## Sex is hard work (stamina regen)

**Disabled for now** (0.35.2): the `sexlab.stamina.*` settings are removed from the manifest and no longer read, and `staminaFatigue` defaults off, so `GetStaminaRegen` returns 100 and nothing below happens. The code is kept for later; the defaults below are the struct defaults.

`sexlab.stamina.fatigue`. Each actor has `regen`, 100 → -10 (`kRegenFloor`) percent of its default stamina regen, tracked per actor:

- The tick subtracts the scene's `regenRate` = `(100 − sexlab.stamina.regen_at_orgasm) / targetSecs` points per second (`ApplyStageTimers`; default 45 at the orgasm point, so an orgasm's cost leaves a Mutual NPC tired near 35). Scenes without stage timers use `sexlab.stamina.regen_decay` points per minute (40). This happens while the scene is animating and not paused. While no actor in the scene expects orgasm, an actor loses nothing until their enjoyment reaches 50. `regenRate` is not saved: the co-save load rebuilds it from the saved timers.
- Crossing a fatigue stage sends one DirectNarration: below 90 "<name> is breathing hard.", 40 or less "is tired.", 0 or less "is exhausted." (`SpendRegen`; regen only falls, so a reload does not repeat it).
- Each orgasm subtracts `sexlab.stamina.orgasm_cost` points (10).
- The tick takes back the decayed share as stamina damage: `MaxStamina × base StaminaRate × base StaminaRateMult × (1 − regen/100) × dt`. It uses base values, so potions and buffs add on top. At full stamina only the negative share (`−regen/100`, regen below 0) drains. No damage is applied in combat. No actor value modifier is left behind.
- A non-victim (player or NPC) reaching regen -10 ends the scene once: `Effect_Exhausted` → `Scene_Manager.EndExhausted` → `Scene.AnimationEnd`. That actor's end sentence is "is too tired to continue." Victims stay at -10.
- Native `GetStaminaRegen` (can be negative). The Scene writes position obj `stamina_regen`. The end DN and 0550 use the same tiers on the int: ≥ 90 nothing, < 90 "breathing hard", ≤ 40 "tired", ≤ 0 "exhausted".
