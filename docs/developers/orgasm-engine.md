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
| `SKSE_Source/src/Hud.cpp` + `PrismaUI/views/SkyrimNet_SexLab/hud.html` | Scene HUD: a second UI-engine view (shared views folder — both Magelight and PrismaUI read it) that is shown but never focused, so the game keeps running. HUD key handling. |
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

SkyrimNet's decision model (e.g. Jev) picks a strategy per NPC; see [Strategy decisions](#strategy-decisions). Every `kPressTick` (1 s) each NPC starts a burst (`StrategyStep`): `random(kPressMin = 5, kPressMax = 10)` presses queued `kPressGap` (0.1 s) apart, fired by the 250 ms tick as they come due (2–3 per tick), through the same cost / edge code as a key press (`ArouseLocked` / `CalmLocked`), not narrated. The first press the NPC can't pay (stamina to arouse, magicka to calm) drops the rest of the burst, and the NPC rests `kRestSecs` (2 s; log `out of stamina|magicka … rests 2s`). That is how an NPC runs its stamina down: about 7.5 × the arouse cost per second, far more than NPC regen. A strategy change, take-control toggle or auto-play toggle clears the queued presses. DenyAll pays for every calm; Tease pays stamina or magicka by the target's enjoyment. Passive and Non-sexual make no presses. No step runs before the scene's first non-empty `SetStageTimers` (SexLab's `thread.Timers` is empty at the first `Engine_SetStage`), or `kUntimedGrace` (10 s) after `BeginScene` for a scene that never sends timers. Only AI-driven actors step (`AiDriven`: NPCs the player does not control, the player only in auto play); see [Take control and auto play](#take-control-and-auto-play).

**Enjoyment budget** (`sexlab.minigame.enjoyment_budget`, default on; `OverBudget`, strategy presses only): the share of max stamina or magicka an AI-driven actor may spend equals its **own** enjoyment, whoever the press targets. A press must leave at least `max × (1 − enjoyment / 100)`, read live on every press. A held press takes the same path as one it can't pay: it drops the burst and rests `kRestSecs`, but logs `holds stamina|magicka (current/max) at enjoyment …` once per hold instead of the `out of` line. At enjoyment 0 an actor can't press at all, including right after an orgasm. A DOM slave's share is `max(min(domArousal, 100), level)`: its DOM arousal, or its level when higher, because an aroused slave can be low on points after an orgasm. HUD keys, `MiniGame_Arouse` / `MiniGame_Calm` and the plugin API aren't limited: the check is in `StrategyStep`, not in `ArouseLocked` / `CalmLocked`.

- **Press size, timed scenes:** `mgStepRate × random(npc_step_min, npc_step_max) / mean(min, max)` (4–8: 0.67–1.33×, rolled once per burst), divided by the scene's mean NPC skill factor `mean(1 + 0.1 × skill)`, × `kPressTick / mean(kPressMin, kPressMax)`, rolled once per burst, so the mean presses per second keep the rate while the NPC isn't resting (rests make it slower). Arouse then applies the actor's own skill factor, so skill matters between actors while Mutual stays on budget. See [Mini-game calibration](#mini-game-calibration).
- **Press size, scenes without timers:** `random(npc_step_min, npc_step_max) / 2` per second, split the same way (arouse × skill factor).

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

`strategies.json` (`Data/SKSE/Plugins/SkyrimNet_SexLab/strategies.json`) is the source of truth for the keys and their wording: `label` (HUD tag), `text` (third person), `option` (decision criterion), `observed` (how a decision-made change looks) and `order` (the phrase after "to" in "Bob orders Nina to <order>", it names the strategy so a request reads like the key) and `choice` (third person infinitive after "to" in "Nina chooses to <choice>"; no longer narrated). `{target}` / `{name}` / `{self}` / `{his}` are filled in. `Strategy` ids are the file order (0 passive … 9 nonsexual). The earlier forced state (Greedy / ForcedOrgasm / AcceptForce, `forcedBy`) and the mental break (`broken`, `sexlab.minigame.mental_break`, the `SkyrimNet_SexLab_MentalBreak` event, `IsMentallyBroken`) no longer exist; the old co-save fields are written as zeros and ignored on load (SexLab stops scenes on load, so no saved strategy is restored).

- **Ask / Order** (`OrgasmEngine::AskOrderNarrated(by, target, order, requestKey, customText)`, HUD panel and Papyrus `AskOrder`): the player (or an NPC through Papyrus) asks or orders another actor of the scene to take a strategy. `requestKey` is `<key>` or `<key>_p<slot>` (the actor a deny / tease / focused request is about; `GetRequestOptions(target)` lists them: what `StrategyAllowed` permits for the target now, its current one left out) or `""` with a free phrase. Narration (one DirectNarration when the scene has the player or the player drives an actor of it, else `DirectNarration_Optional`; `PlayerScene` / `NarrateRequest`): "Bob orders|asks Nina to <order>." The target's strategy decision then runs **after the target's LLM reply** to that line, with the line as `last_line_text` (trigger `ordered` / `asked`, `StrategyDecision::RequestAnswer`, see [Strategy decisions](#strategy-decisions)), and its answer is narrated on its own (`FinishRequest`): "Nina agrees to Bob's request to <order>." when the new strategy key (`CurrentRequestKey`) equals the requested one (a free phrase: when the decision changed the strategy), else "Nina refuses Bob's request to <order>." No line when no decision was made (`kDropped`). A refusal is kept on the target (`ActorState::reasons`, a `PunishRecord`: `by` = order_actor, `target` = target_actor, `reason` = "Nina refused Bob's order|request to <order>", `strategyKey`, `request`, `type` `refused_strategy`; the last 8, one per `by` + key); an agreement removes it. Other mods add reasons with `AddPunishReason` (type `external`, SkyrimNet_DOM). Records are not saved. `GetPunishReasons(target)` also lists, last, an `AiDriven` target's current strategy as others see it ("Nina appears to be focused on her own enjoyment", `ObservedPhrase`) while the mini-game is on; it is not a record.
- **Punish** (`OrgasmEngine::PunishNarrated(punisher, target, method, location, reason)`): the HUD key, auto play's `punish` key and the `SexLab_Scene_Punish` action (`CanPunish`) share one path. Anyone in a managed scene (any role, mini-game not required) can punish anyone else in it, the player included (`GetPunishInfo`). The HUD panel always offers the verb ("no reason" is a reason). The line: "<punisher> punishes <target> by <slapping / pinching / punching / pulling> <target>['s <part>], because <reason>." (`kPunishMethods`); a free phrase is the method as typed ("biting"); a method naming one of `Aid::PunishSpells` (weak attack spells, or with Injury Engine its torture spells) reads "by hitting <target>'s <part> with <spell>" (`Aid::PunishSpellDisplayName` drops Injury Engine's " (torture)" suffix) and queues a health hit of the spell's smallest magnitude when Injury Engine is not handling damage, never below 1 health (`Aid::QueueWeakSpellHit`; no cast, so no combat or bounty), then plays the spell's visuals (`PlaySpellVisuals`). "body" names no part; a reason that already starts with "because " loses it. **Hit, narrate, decide:** with Injury Engine's `External_TortureText` (`InjuryEngine::PunishText`) the hit lands silently and its feeling text comes back as a String ("Nina's nipples throb in tight, bruised points. …"); the line plus that text is narrated at once (`ContinuePunish`, same DirectNarration rule as Ask / Order) and is the `last_line_text` of the target's decision (trigger `punished`), which is sent after the target's LLM reply to the narration. No "<target> chooses to ..." sentence is added: the reply says what the target does, and the decision follows it. A punishment for a reason that is a refused request then gets the answer line, "Nina agrees to|refuses Bob's request to <order>." **Order with the punishment** (panel only, `orderKey`): when the reason is the target's current strategy (`GetCurrentStrategyReason`), the panel adds a strategy pulldown and the line ends ", and orders them to <order>." The decision gets the key as `ordered_key`; it still decides, but an answer picking that key skips `decision_min_confidence`. The rest follows the refused-request path (`plan.requestKey`): the answer line, a refusal kept as a reason, and Submit above 80% torture taking the ordered strategy. Without `External_TortureText` (older Injury Engine) the hit goes through `External_Damage` with the line and Injury Engine narrates it; without Injury Engine the line is narrated alone. Callers narrate nothing; the Papyrus `Punish` always returns "".
- **Aid** (`Aid.cpp`, HUD Aid key and `SexLab_Aid`): healing / stamina spells (beneficial Value Modifier effects on Health / Stamina; base list plus `addedSpells`) and such potions. The restore is applied directly as magnitude × duration (a concentration spell as 3 s of casting) and the spell's magicka cost is spent; a potion is removed from the caster. Then `PlaySpellVisuals` plays each effect's casting art on the caster (spells), effect shader and hit art on the target, and release / hit sounds (3 s for concentration, else 2 s); nothing is engine-cast. The HUD greys the cell out via `Aid::HasOptions`, checked at most once a second. **Potion parts** (Aid panel): `drink`, and `lips` / `ass` / `pussy` / `cock` get their own lines (`PotionLine`); when the scene's act (`GetSceneActs`, sent by `Scene.Engine_SetSkills`) carries the potion between two actors ("… puts the stamina potion on Bob's dick and it is thrust into Amy's pussy.") the effect is split half to caster, half to target. Drink / lips on someone else needs consent (`Aid::NeedsConsent`): an NPC asks `prompts/decisions/sexlab/aid_accept.prompt` (`StrategyDecision::RequestAidAccept`, accepted without a provider), the player gets a Yes / No dialogue for a drink; a refusal is narrated and becomes a punish reason.
- **Defaults** at `BeginScene` by role: `sexlab.minigame.default_strategy_normal` / `_aggressor` / `_victim` (Mutual / Selfish / Passive). Not announced. They are the fallback until the scene-start decision lands, and always without a decisions provider.
- **Announce** (every change): `Effect_StrategyChanged(actor, target, msg, observed, narrate)` shows no notification. `narrate` (API / Papyrus `SetStrategy`, NonSexual switches): `DirectNarration_Optional("sexlab_strategy", msg, …)`. Decision-made changes (`StrategySource::kDecision`): no narration, `SkyrimNetApi.RegisterEvent("sexlab_strategy", observed, …)`, a short-term event with how it looks to others ("Lydia appears to be focused on her own enjoyment.", `observed` in `strategies.json`). Both, and `Effect_NarrateDirect` / `Effect_NarrateOptional` (requests, Force, Aid), are capped by `sexlab.narration.minigame_level` (see [orgasm-narration.md](../reference/orgasm-narration.md)). The player's HUD panels are not: `WebUI.cpp` passes `fromPlayer = true` to `AskOrderNarrated` / `PunishNarrated` and `callerNarrates = true` to `Aid::Apply` / `Aid::StartChannel`, and narrates with `NarratePlayer` (`Effect_NarratePlayer`: purge the speech queue, always DirectNarration; Injury Engine silent).
- **Prompt / HUD**: `Scene` writes `GetStrategyText` to the position obj `strategy` (0050 prompt: "<name> focuses on …"; the speaker's own line ends "Speak and act in line with that approach."); the HUD shows the label as a tag.
- `MCM.ApplyMiniGameActions` unregisters Arouse / Calm in Together mode (switching back needs save + reload). There are no strategy actions.

### Strategy decisions

`SKSE_Source/src/StrategyDecision.cpp` asks SkyrimNet's decision model through `PublicSendCustomDecisionToLLM` (public API v12+). One request decides one NPC (the *focus*), with the template `prompts/decisions/sexlab/minigame_strategy.prompt` (one `[ question strategy choice ]`). Off with `sexlab.minigame.decision_strategy` or in Together mode.

- **Triggers:**
  - *Scene start*: the tick marks a scene ready on the same rule as `StrategyStep` (first non-empty `SetStageTimers`, or `kUntimedGrace` after `BeginScene`) and dispatches `OnSceneReady(sid)` → one request per NPC (`SceneNpcs`). Once per scene (`decisionsStarted`). The co-save restores no scene, so every scene after a load gets its decisions.
  - *Asked / ordered / punished*: `RequestAnswer(target, trigger, line, done)` from `PunishNarrated` for a plain punishment (ask / order and keyed punishments use *Comply*, below; same wait); `last_line_text` is the ask / order / punishment narration (trigger `asked` | `ordered` | `punished`). **After the reply:** the narration goes out first; the request waits (`g_awaiting`, log `await ... trigger=`) for the target's LLM reply to it and replaces the `dialogue` decision that reply would send. Released by `StrategyDecision::Tick` (every OrgasmEngine tick): `kReplySettle` (1 s) after the target's next `npc_thoughts` event (inline thoughts register when the reply is generated; the dialogue event only fires when its speech completes, 40 s+ later in practice), or after `kReplyTimeout` (20 s); log `released after reply (thought|dialogue|timeout)`. Without the `npc_thoughts` callback, the target's next dialogue event releases it. While waiting or in flight, the target's dialogue sends no decision of its own (`dialogue decision skipped`). A second ask / order / punishment while waiting merges into it (one answer for both `done`s); a punishment keeps its `punished` query over an ask / order. Its `done` callback runs exactly once (answer or `kDropped`). An NPC the player controls (`playerDriven`) answers like any NPC and plays the answer at once (`AiDriven` ignores `playerDriven`). Above 80% Injury Engine torture (`PartPoints` `total > 0.8 × max`), a punishment sends no request. Instead `Submit` narrates "<target> can't take it any more and submits!" and sets a strategy: the punished request's key first, then the newest refused order, then the newest refused request. With none of those it is `selfless` (2+ actors) or `selfish` (solo).
  - *Serial punishment rejects* (`sexlab.minigame.max_serial_punishment_rejects`, int 0–10, default 3, 0 = never): `ActorState::punishRejects` counts the target's punishments refused in a row (not saved; a new scene starts at 0). `NotePunishAnswer` runs on each LLM answer to a punishment, before the DOM roll, so the roll never counts. `kDropped` / `kUnknown`: no change. With a `requestKey`: refused unless `CurrentRequestKey` is now that key. Plain: refused on `kKept` / `kLowConfidence`. Refused adds 1, anything else resets to 0. Log: `punish rejects 0x… = n/N`. At the start of `ContinuePunish`, `ForcedGiveIn` checks `punishRejects >= N - 1` for an `AiDriven` target (DOM slaves included) with the mini-game on; `NotePunishAnswer` counts only under the same check (`PunishCapApplies`). When it fires, the target gives in at once (`GiveInLocked`, the same pick as `Submit`; `Submit` resets the count too), and the narration becomes "<punishment line>. <target> switches to <choice>." (`choice` from strategies.json, `FillStrategyText`). No decision is sent and there is no torture check. If the punishment had a `requestKey`, `FinishRequest(kChanged)` narrates "agrees to …" and clears the reason. With an older Injury Engine that narrates the hit itself (`External_Damage`), only "<target> switches to <choice>." is narrated. Log: `gives in after n refused punishments -> <key>`.
  - *Comply* (`RequestComply(target, trigger, line, by, requestKey, requestText, done)`): `AskOrderNarrated` always uses it, and so does a punishment whose plan has a `requestKey` (an order with the punishment, or a punishment for a refused request). It waits for the reply exactly like `RequestAnswer` (`Awaiting::comply`, log `await … comply`). On release, `SendComply` sends `prompts/decisions/sexlab/minigame_comply.prompt` (one `[ question comply choice ]`, `comply` / `refuse`) instead of the strategy template. `comply` + key → `ApplyStrategyDecision(key, confidence -1)` (no floor; `kChanged`, or `kKept` when already on it; a change sets the 30 s hold). `comply` with no key (free-text request) → `kChanged`. `refuse` → `kKept`. A failure → `kDropped`, so orders still get the DOM obedience roll. `FinishRequest` then narrates agree / refuse as before. While it is in flight (`g_complyInFlight`), the target's dialogue sends no decision. Merging: a comply request takes over a waiting entry. A plain punishment arriving on a comply entry keeps the comply query. Either way the wait restarts. Log: `comply send … key='…' request='…'`, `comply … answer comply|refuse p=… (changed|kept|…)`.
  - *Dialogue*: `PublicRegisterEventCallback` for `dialogue`, `dialogue_npc` and `dialogue_background`. The originator, if a managed non-player actor, gets a request with the line (`data.text` / `dialogue` / `line`). In auto play, any line in the player's scene also sends a [player turn](#take-control-and-auto-play).
- **Threading:** SkyrimNet calls both callbacks on its ThreadPool. They only copy strings, then `AddTask`; context building, relationship lookups and `ApplyStrategyDecision` run on the game thread.
- **Push (`contextJson`)**, built from `OrgasmEngine::GetStrategyDecisionInput` under the engine lock: `trigger`, `focus_uuid`, `focus_name`, `last_line_text`, `role` (partner / aggressor / victim), `arousal` (0050 bands), `orgasms`, `expects_orgasm`, `timeline[]`, `partners[]` (`uuid`, `name`, `is_player`, `role`, `arousal`, `orgasms`, `relationship`, `relationship_rank`), `options[]` (`key`, `text`), `latest_thought` (the focus's newest thought: the one the `npc_thoughts` callback caught in the last 120 s, else the newest in the timeline; `""` for none; the template ranks it first). The current strategy, earlier strategies, punishments and the scene progress are **not** sent (`current_key` stays in C++ for the kept / changed comparison).
  - **Timeline** (`BuildTimeline`): the focus actor's recent SkyrimNet events (`PublicGetRecentEvents`, oldest first, newest 15 lines) as one list of lines: speech "Bob said: …", the actor's own thoughts "Nina thought: …" (`npc_thoughts`; other actors' telepathic thoughts are skipped), DirectNarrations and other events as their text; spell / hit / combat / gamemaster events are skipped. Narration inside speech is pulled out onto its own line: `kiss me *bob leans in*` -> "Bob said: kiss me", "Bob leans in." Ask / order / refuse / punish narrations are DirectNarrations, so they appear here as events. The question ranks `last_line`, then the actor's thoughts, then recent over older events.
  - **Options** are only what `StrategyAllowed` permits now, so the model cannot pick an illegal one. Deny / Tease / Focused expand to one option per valid target, key `<key>_p<slot>` (1-based SexLab position); the text comes from `option` in `strategies.json` with names and pronouns filled in.
  - **Relationship**: Skyrim's rank between the focus and each partner, `BGSRelationship::GetRelationship` on the actor bases (template bases as a fallback): `4 − level`, labels lovers / allies / confidants / friends / acquaintances / rivals / foes / enemies / archnemeses; no relationship form is `strangers` (0).
- **Pull (template):** `decnpc` and `render_character_profile("short_inline", …)` for the focus and its partners; `sexlab_get_threads(focus_uuid)` for the act and location; `last_line_text`; `timeline` (above).
- **Answer:** `answers.strategy.choice` and `answers.strategy.confidence` → `ApplyStrategyDecision`, which returns a `DecisionResult`: `kDropped` when the scene ended or its `generation` changed (bumped when the roster changes; a reused sid gets a new one); the `_p<slot>` suffix resolves through the snapshot's `slots`; same key and target = `kKept` (quiet); a change with a reported confidence under `sexlab.minigame.decision_min_confidence` (default 0.6; no confidence reported = no floor) = `kLowConfidence`, current strategy stays; else `SetStrategyLocked` with narrate off (`kChanged`).
- **Coalescing:** one request in flight per NPC; a line arriving meanwhile is kept and sent once the answer lands. An ask / order / punishment arriving meanwhile becomes that follow-up (later dialogue does not replace it); several waiting ones share its answer.
- **Hold:** a strategy changed by a `punished` / `ordered` / `asked` decision holds for 30 s (`kHoldSeconds`) against `dialogue` decisions, so the NPC's own reaction line can't undo it at once. Another punishment or order can still change it. Log: `answer <key> p=… (held after punished/ordered, Ns left)`.
- **Failure:** `no_decisions_route` warns once and stops asking until the next load (role defaults stay); other errors are logged. Log lines: `StrategyDecision: send …`, `answer <key> p=… (changed | kept | low confidence, kept current | unknown key | dropped: scene ended or roster changed)`.

### Take control and auto play

The HUD take-control key (`sexlab.hud.key_take_control`, default Num \*, controls group) is in the HUD keys and, while the HUD is down, an unconsumed `KeyHandler::Register` callback (ignored while a blocking menu or the WebUI is open). `Hud::OnTakeControl`:

- **Player in a managed scene:** toggles `OrgasmEngine::SetAutoPlay` (player `ActorState::autoPlay`); turning it on assigns the role default (the Passive `BeginScene` gave is a placeholder) and calls `StrategyDecision::OnAutoPlay`.
- **Sticky:** `SetAutoPlay` also sets `g_autoPlaySticky` (co-save v8). While it is set, `BeginScene` turns `autoPlay` on for the player as a newcomer, before the role default is picked (log `auto play on (scene N, sticky)`), so the scene keeps the gate and gets its `scene_start` player turn. Only the key turns it off.
- **Else, already controlling an NPC:** releases it (`SetPlayerDriven(npc, false)`).
- **Else, crosshair actor (`CrosshairPickData::GetActiveTarget`) in a managed scene:** `SetPlayerDriven(npc, true)` (`ActorState::playerDriven`) and `Hud` keeps it as the anchor `g_anchor`.

`AiDriven(st)` (player: `autoPlay`; NPC: always true) gates `StrategyAllowed`, `StrategyStep`, the default migration, `GetStrategyDecisionInput`, `SceneNpcs`, `GetStrategyText`, the strategy punish reason and the HUD strategy label. `playerDriven` does not mute the NPC's AI: the player joins its scene through the HUD, acting as themselves. It only marks the anchor for `PunisherScene` and `PlayerScene`. Both per-actor flags end with the actor's `ActorState` (scene end, or moving to another scene); the player's comes back from the sticky flag at the next scene and on load.

**Anchor (Hud.cpp):** `ActingLocked()` is the anchor NPC, else the player. `Tick` builds the HUD from `GetActorScene(acting)` and uses the acting actor for pause, stage and speed (the Punish cell's `enabled` uses `GetPunishInfo(player)`); it releases the anchor when its scene is gone or the player's own scene starts. The player is always the doer, also while controlling: arouse / calm come from and are paid by the player (`blocked` uses `CanArouse(player)` / `CanCalm(player)`; while controlling the push adds `payer {name, magicka, stamina}` from `GetResourcePct`, a row under the actors in `hud.html`); speed steps the acting actor's scene; Punish opens with the player first and default subject plus the other actors of the scene (`GetPunishInfo(player)`; `PunisherScene` falls back to the `playerDriven` actor's scene for the untracked player), each with `Aid::PunishSpells` (the panel is Ask / Order / Punish: see [WebUI](webui.md)); `onPunishResult` → `AskOrderNarrated` or `PunishNarrated` on the game thread; Aid opens with the player as caster and the actors of `GetActorScene(acting)`. So every line names the player ("Bob arouses Nina…"). `DispatchMenuKey` passes the anchor as the third argument of `Menu.Hud_OnKey(control, focus, anchor)` (None: the player), which works on `GetSceneByActor(anchor)`; deny goes through `Scene.ToggleDenyOrgasm(actor, Game.GetPlayer())`. `ResolveFocus` picks the first actor other than the acting one. HUD push: `takeControlLabel` (`auto` = hand to AI, `control` = take back from auto play, `release` = stop driving an NPC) and `acting` (the anchor's name, "" in the player's own scene).

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
   - **AI-driven mini-game (`aiGate`):** `SceneAiDriven(sc)` — every non-DOM actor is `AiDriven` (NPCs; the player only on auto play), re-checked each tick. Earlier orgasms do not skip the gate. The ending lead (`SetEndingTarget`, target > 0) passes without a roll; in the second-to-last stage its cooldown is ignored (block, DOM, edging and a failed final roll still stop it). **Every aggressor expected to orgasm passes the same way**, whatever its enjoyment or earlier orgasms, so it always finishes in the gate group. A victim follows its aggressor's strategy: an aggressor on Focused targeting it passes it outright, one on Tease or Deny targeting it keeps it out of the gate and the gate join (`teased=true` on `gate skips`), anything else rolls. An actor with a pending (non-forced) request passes; the rest roll. From the second-to-last stage on, non-rushing, non-DOM actors are capped at 98 and skip the orgasm test (a forced request still fires), so the gate's orgasm is the scene's last and the final stage is held for its response (`Ending_Hold`). Taking control of anyone drops back to the free mini-game. **Victim hold** (`VictimHoldScene`: mini-game, timed, no LeadIn, a victim and a non-DOM aggressor expected to orgasm): aggressors are not capped at 98 in the second-to-last stage, and the gate fires when an aggressor who `CanOrgasmNow` reaches 100 (log `victim hold: aggressor … at 100, gate`), or when the Scene's cap runs out (`VictimHoldExpired`, log `victim hold expired, gate`), not on the stage timer. The Scene holds that stage meanwhile; see [Scene ending](#scene-ending). Log `ai_gate=` / `ending_lead=` / `aggressor=` / `forced_victim=` on the `gate` lines. The cap is applied after the strategy step, so an `arouse … -> 98.7` (or 100) line shows the value before the hold.
   - **When** (not a victim hold scene): `lead` + 2 s (`kGateDispatchMargin`: tick → Papyrus → `UpdateTimer`, so `Gate_Hold` lands before SexLab's timer) before the second-to-last stage's timer ends (animating, unpaused time; on entering it when `lead` is longer), or on reaching the final stage first. `lead` = `NarrationTiming::EstimateSeconds`: the median of the last 20 clean DN→first-speech samples this session, `sexlab.ending.gate_lead_default` (5 s) until 3 exist, clamped 1–30 s.
   - **A pass does not fire yet.** The actor is *rushing*: enjoyment climbs at `(98 − enjoyment) / lead` per second (no passive gain, pause and speed ignored, capped at 98 before the final stage, no other orgasm test). `Effect_GatePassed(actors, holdStage)` → `Scene.Engine_GatePassed` stashes the passers and sends one DirectNarration at once, then calls `GateNarrationSent(sid, mark)` with the `NarrationMark()` (`NarrationTiming::SpeakerMark()`) it took just before the DN, so a voice that starts before the call still counts (-1: mark now).
   - **The Scene goes to the final stage at once**, never waiting for the voice: `Engine_GatePassed` drops any victim hold (`Victim_Drop`, because `GoToStage` resets the timer) and calls `Engine_AdvanceToFinal` → `Ending_ToFinal` (final stage + dialogue hold). `gate_holding` / `Gate_Poll` remain only to release a save made mid-hold on an older version.
   - **Flash:** the passers' HUD bars flash from the pass (`flashUntil`, 5 s, `kGateFlashInitial`), so the player sees the orgasm was triggered. `GateNarrationSent` means a voice is expected: the flash extends to `sexlab.ending.gate_wait_max` (20 s), and the first `SkyrimNet_SpeechStarted` by one of **this scene's** non-player actors after the mark (`NarrationTiming::StartedSince(mark, actors)`; another scene's reply does not count) ends it 2 s later (`kFlashAfterVoice`; log `gate voice started, flash ends in 2s`). `Fire` never shortens a longer flash.
   - **No voice expected** (`orgasm_level` below Direct, or Global AI off): the Scene does not call `GateNarrationSent` (log `no voice expected`), so the flash ends at the 5 s, shortly after the orgasm. Global AI is read in Papyrus with `Utilities.GlobalAIEnabled()` (`GetConfigBool("Game", "general.globalAIEnabled", true)`; C++ can't read it). With it off, `Ending_HoldMax` is 0 and `StageStart` doesn't extend the stage for its orgasm DN. The DN is still sent.
   - **In the final stage** the rush finishes within 1 s and fires at 97 as a `gate` group: `Fire` only, no group join, no extras fold. `Orgasm_ApplyGroup` runs `ForceOrgasm` and skips the stash and narration.
   - **Gate join:** when anyone passes, every other actor who is expected to orgasm, passes `CanOrgasmNow`, isn't rushing and is at ≥ `group_join_final` rushes with them and goes into the same gate DN. Repeat orgasms join too (only rolling skips them). Log `gate join`.
   - A block (deny) cancels the rush. A forced request fires through the normal path. Stepping back before the last two stages drops the rush and re-arms the gate. Rushes are not saved.
   - All fail: SexLab advances normally, no orgasm.

   **Safety net (Together mode; gate off, or no timers):** at 90% of the final stage's timer, each non-DOM actor at 90 or more who has not orgasmed, is not blocked or edging and was not calmed in the final stage fires as *combined*. With no timers it fires on entering the final stage, everyone when the mini-game is off.
4. **Group (`JoinGroup`):** everyone fired in this scene in this tick (steps 2 and 3, forced included) is one group. Every other actor who passes `CanOrgasmNow` (not a DOM slave, blocked, edging, cooling down or out after a final roll) and isn't rushing joins outright at ≥ `sexlab.enjoyment.group_join` (default 85, log `group join`). Below that it rolls once: `enjoyment + random(0, random_bonus) ≥ 100` (`RollOrgasm`, `sexlab.minigame.random_bonus`, default 10). Passers join the group. Repeat orgasms join or roll too. Log `group roll`.
   - **Early final roll:** in the second-to-last stage of a timed, non-LeadIn scene, when the Scene's ending lead (`SetEndingTarget`) is in the group and has reached the target, or (victim hold scene) any aggressor is in the group whatever the target (the Scene is about to jump), everyone still out rolls again with `enjoyment + random(0, random_bonus) + stage_spike ≥ 100`. A pass joins this group, so it goes into the same DN. A fail sets `finalRollFailed`: no more orgasms (no denied event either) until the scene steps back before the last two stages, except a forced request. Not saved. Log `final roll … victim_hold=`.
   - The same `JoinGroup` runs for `NoteExternalOrgasm` and `AllowOrgasm`.

   The group is sent as one `Effect_OrgasmGroup`, so it gets one narration. It is `individual` unless every trigger came from the safety net (`extras` stays empty).
   `FinalStageRemaining(sid)` (native) returns the final stage's timer minus its animating, unpaused seconds, or -1 outside a timed final stage. In the last stage it returns the seconds until the afterglow bars drain to 0 instead. `Scene.OrgasmWindow_HoldForFinish` uses it.
5. **Mirror:** at most once a second per actor, `Effect_Mirror` → `AdjustEnjoyment(ours − SexLab's)`, so SexLab voices and expressions follow our value. One `Scene.Mirror_Apply` per position at a time (`mirror_busy_at`, 5 s stale guard): ticks queued while a menu paused the VM used to run together and apply the same correction twice.

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

`Arouse(who, target, mult)` / `Calm(who, target, mult)` are shared by the HUD keys (`mult` 1; also LMB calm / RMB arouse when `sexlab.minigame.mouse` is on), Papyrus `MiniGame_Arouse` / `MiniGame_Calm` (`mult` 3; no longer LLM actions) and the plugin API. A HUD press targets the focus actor; with Shift held (`Hud::ShiftHeld`, the game's keyboard `curState`) it targets the next actor in the list instead, wrapping, and the focus stays. The HUD gets that row as `shiftTarget` and marks it `⇧`.

| | Effect |
|---|---|
| Arouse | Costs `who`'s stamina: `stamina_cost × 10/(10+skill)`. Adds `arouse_amount × mult × (1 + 0.1 × skill)`. |
| Calm | Costs `who`'s magicka: `magicka_cost × (1 + 0.05 × lewd)`. Removes `calm_amount × mult`, but never below 0. If the target was at 90 or more, it **edges**: no orgasm test for `edge_seconds`. |
| Skill / lewd | `skill` is SexLab's skill level for the act, picked by animation tag (Vaginal, Anal, Oral, else Foreplay). `lewd` is lewd level − pure level. Both are sent by the Scene script at start, on each stage and on an animation change. |

**Mini-game plays in the silence nudge**
- Presses are not narrated one by one. `ArouseLocked` / `CalmLocked` call `NotePlay`, which records on the presser (player keys and NPC strategy presses alike) when they last aroused or calmed themselves or another actor, and whom.
- The Scene's silence nudge (`Utilities.SilenceNudge`) asks `GetMiniGameSummary(speaker)`: one sentence per actor of the scene who played since the scene's last summary (at most 30 s back), from their latest play. Then it marks those plays as summarized.

  | Latest play | Sentence |
  |---|---|
  | Aroused self and another in the window, or an NPC on Mutual | "A focused on mutual pleasure." |
  | Aroused another | "A focused on B's pleasure." |
  | Aroused self | "A focused on her own pleasure." |
  | Calmed self | "A resisted her orgasm." |
  | Calmed another | "A held back B's orgasm." |

  The pronoun comes from `stageGender`. The nudge sends the joined sentences as its DirectNarration, or `"continue scene"` when nobody played.

**Other engine narrations**
- The HUD faster/slower narration (`sexlab_speed`) goes through `Effect_Narrate` (a short-lived event). Engine narrations are optional, and this includes scenes with the player:
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
  - `IncreaseArousal(10 × sexlab.dom.arousal_scale, MOD_SocialBoldness)`, with a default scale of 0.2;
  - in player scenes, also `IncreaseArousal(10 × sexlab.dom.arousal_scale_player, MOD_Naivety)`, also 0.2 by default.
- **Prepay:** DOM adds 20 (`MOD_SocialBoldness`) itself at scene start, and 20 (`MOD_Naivety`) at its roll in player scenes.
  - The first sync of the scene subtracts those amounts from `arousal_factor` using `Handler_DOM.DomArousalValue`, a copy of `IncreaseArousal`'s formula.
  - Whatever cannot come off without going below 0 becomes a debt (StorageUtil `skyrimnet_sexlab_dom_debt` on the actor). Later steps pay it first.
  - One-time adds are not cancelled: virginity, first act, same-sex, kink.
  - The engine logs `dom step` lines, and Handler_DOM traces the prepay.
- **Mini-game:** Arouse and Calm still push at once. Arouse on an aroused slave (`is_aroused_for > 0`) first raises `is_aroused_for` toward its max (`PRISM_Sensuality × 0.5 + submission × 0.5`, 1 point per tick); the rest goes to `IncreaseArousal(delta, MOD_SocialBoldness)`. Calm is a direct drop in `arousal_factor`.
- **Step roll after every rise** (`Handler_DOM.StepRoll(actor, hasPlayer, share)`):
  - It runs only when the actor is not blocked (`no_orgasm` / deny / plugin block), not edging and not cooling down.
  - It is a light roll, not `handleSexOrgasm`:
    1. `mind.IsArousedAfterSex(MOD_SocialBoldness)`.
    2. If `CouldOrgasm`: `mind.IsOrgasmingAfterArousal(actBase × share)`. `actBase` is the best `MOD_Vaginal` / `MOD_Anal` / `MOD_Oral` among the acts played (1000 with DOM's separate orgasm on).
    3. On success, it does what `handleSexOrgasm` does: `SendExternalEventSS("Orgasm", sex|rape|masturbate)` and `DOM04.NotifyOrgasm`.
  - `share` is 0.1 per passive step, plus `arouse amount / 100` for Arouse. Below 0.5, DOM's chance is linear in `base_chance`, so about 10 rolls at 1/10 add up to roughly one full roll.
  - Known bias: DOM's male `×2 + 0.1` and its additive bonuses apply to every step.
- **DOM's own roll is kept:** DOM makes one full `handleSexOrgasm` from the `OrgasmStart` hook at the final stage, or at `AnimationEnd` if the hook never fired.
- **Melt:** DOM's "brain melts" notification reaches `Handler_DOM.DOMSlave_Orgasmed`. It calls `NoteExternalOrgasm(slave, "dom")` (count, cooldown, HUD flash, `SkyrimNet_SexLab_Orgasm`), then narrates DOM's text through `OrgasmCustom`.
- **Bar:** `Effect_DomSync` pushes `SetDomMeter(actor, DomLevel, OrgasmProbability)` and `SetDomStep(actor, DomArousal, DomStepLabel, StepProbability)` after every sync, and the HUD tags the actor "DOM".
  - **Total and steps:** the bar total is DOM's `arousal_factor`, uncapped. Each hundred is one step, and the fill is the position inside the step (`Hud.cpp`). It carries across scenes and falls with DOM's decay and orgasm reset.
  - **Label:** `Handler_DOM.StepLabel`, from DOM's real state and not from the hundreds: `just orgasmed` (refractory), then, when aroused, the chance bands (under 25% `orgasm possible, low`, under 50% `orgasm possible, moderate`, under 75% `orgasm likely`, else `orgasm very likely`), otherwise `orgasm impossible` below 100 and `impossible, can become aroused` from 100. Reaching 100 only allows DOM's own roll for becoming aroused.
  - **Arouse / Calm:** each press changes `arousal_factor` by the same amount in every step. `AddArousal` tops up `is_aroused_for` for an aroused slave and still adds the full amount. Arouse goes through DOM's `IncreaseArousal`, so one press varies by slave (about +0.6 at 2.4); Calm is a direct -3.2, stopping at 0.
  - **Pulse:** fill 94 or more and `OrgasmProbability` above 0 (`Hud.cpp`). The full flash stays on a real melt.
  - **`enjoyment` is the level:** `SetDomMeter` stores `Handler_DOM.DomLevel` for the engine, the SexLab mirror and the prompts (`enjoyment`, and `arousal` from `sexlab_get_threads`). It comes from DOM's real state, checked in `StepLabel`'s order: refractory 15; aroused `50 + 49 x min(full chance / 0.5, 1)`; not aroused at 100 or more `25 + 24 x min((arousal - 100) / 100, 1)`; otherwise `arousal x 0.24`. So under 25 means not aroused, 25-49 can become aroused, 50 and up aroused. The 0.5 top comes from one play session in which every orgasm landed in the low or moderate bands; the `dom meter` log line carries the level and full chance for revisiting it.
  - **Text over the bar end:** `Handler_DOM.StepProbability`, the chance the next step roll succeeds: `RollProbability` with the act base scaled by the last non-zero share (StorageUtil `skyrimnet_sexlab_dom_last_share`), as `StepRoll` passes it to DOM. It averages the random terms (orgasm control, whipping submissive, rapture oath) over their outcomes. It is 0 when the slave is not aroused (`is_aroused_for <= 0`) or refractory. The label, the level and the pulse use the full end-of-act chance (`OrgasmProbability`).
  - `block_orgasm` is a private variable in DOM_Mind, so it is not read.
- **Enjoyment list** (`sexlab.hud.dom_enjoyment`, default off): when on, `Effect_DomSync` also calls `Handler_DOM.PushEnjoymentBreakdown(actor)`, which pushes rows to `OrgasmEngine.SetDomBreakdown`.
  - It only reads DOM, and traces a line if its fixed contributions stop matching `EstimateChance`.
  - Order: the rows that add up to `bar total` (arousal at scene start, DOM's scene adds prepaid, scene steps, Arouse, Calm, DOM and decay), `bar total`, `needed for next step`, the step and its label, the chance rows, then the inputs. Only `bar total`, `needed for next step` and the label show at 0.
  - `DomSync` keeps the bar rows in StorageUtil (`skyrimnet_sexlab_dom_ledger_*`, reset on the scene's prepay). They are in arousal points. `DOM and decay` is the remainder, so the rows always add up.
  - Fixed contributions plus random terms add up to the threshold range. Random terms are scaled by the `arousal_factor` multiplier, as DOM applies it after them.
  - `full roll chance` is `OrgasmProbability`. `next step roll (HUD chance)` is `RollProbability` at the last non-zero share, the value shown over the bar.
  - It cannot show `block_orgasm`, or the virginity doublings and `× 0.3` not-aroused penalty inside `handleSexOrgasm`.
- **Orders with no decision:** when an order or a punishment that orders a strategy comes back `kDropped` (decisions off, no provider, a failed request), `RollDomOrder` sends `Effect_DomOrderRoll`. It rolls `SkyrimNet_DOM_Obedience.RollOrder` (kind `masturbate_harder`) and answers through `DomOrderAnswer`. Obeying applies the ordered option; the outcome then follows the usual path as `kChanged` or `kKept`, so a refusal is narrated and becomes a punish reason.
- **Decisions:** `minigame_strategy`, `last_stage` and `aid_accept` add a `dom_instructions` state for a DOM slave, rendering SkyrimNet_DOM's `0551_dom_instructions`.
- **Stages:** with nobody else expected to orgasm, the slave is the stage primary and the stages follow its level (see [Stage by enjoyment](#stage-by-enjoyment)). Under 25 (not aroused) is stage 1 of 5. `stage_hold_max` still moves a stuck stage on, so the final stage can be reached while orgasm is impossible. DOM's melt ends the stage moves and jumps to the final stage, like any primary's orgasm. A slave primary never starts a stuck-stage punishment, and it doesn't count for the NPC-only stall end.
- A blocked DOM slave sends `OrgasmDenied` once its chance is above 0.
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

The shell-only natives (`BeginScene`, `SetStage`, `SetStageTimers`, `SetScenePaused`, `GateNarrationSent`, `SetEndingTarget`, `IsVictimHoldScene`, `VictimHoldExpired`, `SetSceneBlocked`, `SetDomSlave`, `SetDomMeter`, `SetActorSkills`, `SetFirstTimes` (Lover's Ledger first vaginal / anal: Punish / Aid show pussy / ass as damaged; sticky for the scene), `EndScene`, `ResetSpeedScale`, `ReloadConfig`, `AllowOrgasm`) are for this mod's own Scene and MCM scripts. `AllowOrgasm` is not in the C++ API.

## ModEvents

`sender` is the affected actor, and `strArg` is `"<source>|<acting actor FormID>"`.

| Event | numArg |
|-------|--------|
| `SkyrimNet_SexLab_Orgasm` | orgasm count this scene |
| `SkyrimNet_SexLab_OrgasmDenied` | orgasm count |
| `SkyrimNet_SexLab_Edge` | edge seconds |
| `SkyrimNet_SexLab_AidStart` | health restored |

`SkyrimNet_SexLab_AidStart` fires once per health Aid (spell or potion, any entry point) on another actor. Its `strArg` is `"<spell|potion>|<caster FormID>"`, and the FormID is a signed decimal, so Papyrus `as Int` parses ESL ids. Aid casts nothing, so Injury Engine sends no `Injury_Engine_HealStart` for it. SkyrimNet_DOM uses this event to praise healed slaves.

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

- The co-save record `'ORGE'` (version 9) is written with every scene, but **`Load` restores none of them**. SexLab cancels every scene on load (the same reason `ActorLocker` drops its co-saved locks), so a restored scene was always dead, and a new scene that reused the thread id within the 10 s stale window "resumed" it with old enjoyment, gate and orgasm counts, no opening strategy decision, and `primaryFinished` back to false. `Load` reads every field to keep the layout, logs `co-save read N scene(s), M actor(s), not restored`, and keeps only the sticky auto play flag (v8). Record contents, for the layout:
  - per scene: stage, stage timers, LeadIn, pause and the final-stage clock;
  - per actor: enjoyment, orgasm count, role, skill, jitter, blocks, rate modifiers and DOM step state;
  - v4: gate state; v5: the stage clock, and per actor the bonus, curve progress, strategy, target and forcer; v6: per actor stamina regen; v7: per scene the mini-game rates; v8: sticky auto play; v9: strategy ids renumbered.
- A revert (load or new game) clears everything.
- The faster/slower scale is not saved; style speeds are not restored on load either.
- A scene with no actor in `SexLabAnimatingFaction` for 10 s is dropped. This is the safety net for a missed `AnimationEnd`. AnimEngine scenes (sid > 100000) are never saved and use the bridge's `IsLive` instead ([AnimEngine scenes](#animengine-scenes)).

## Other plugins that use SexLab directly

Older plugins call SexLab rather than the engine. The engine picks up both kinds of change.

- **Their orgasms** (`thread.ForceOrgasm`, `sslActorAlias.OrgasmEffect`):
  - Each orgasm the engine fires counts one "own orgasm in flight" for that actor.
  - When `Scene_Manager.OrgasmIndividual` gets `SexLabOrgasm` for a managed actor, it calls `ConsumeOwnOrgasm`. If that returns true, the event was ours and was already narrated.
  - Otherwise `NoteExternalOrgasm(actor, "sexlab")` records it like one of ours (enjoyment 0, count, cooldown, HUD flash, `SkyrimNet_SexLab_Orgasm` event with source `sexlab`). The Scene then narrates it once (`OrgasmIndividual(…, from_engine=true)`; DOM slaves are skipped as before).
- **Their enjoyment changes** (`AdjustEnjoyment`):
  - `Scene.Mirror_Apply` keeps the value it wrote (position obj `sl_mirror_set`) and SexLab's value just before the write (`sl_mirror_pre`).
  - On the next mirror, if SexLab is 3 to 25 away from what we wrote (`MIRROR_EXTERNAL_THRESHOLD`, `MIRROR_EXTERNAL_MAX`), that move is added to the engine (`AddEnjoyment(…, "sexlab")`) before mirroring, so it is kept rather than overwritten.
  - SexLab still reading `sl_mirror_pre` means our write has not landed (P+ builds that apply `AdjustEnjoyment` on their next recalc): nothing is folded or re-written, for up to `MIRROR_WAIT_TICKS` mirrors.
  - A bigger move, or SexLab outside -100..100 (P+ 2.17 does not clamp), is SexLab's own drift: not folded, and the write pulls SexLab back to ours. Before this, re-importing our own late writes grew into `SexLab added -4110` and pinned actors at 0 (scene never ended) or 100 (false orgasm).
  - SexLab's own small time drift stays under the threshold.
  - The baseline is dropped where SexLab jumps by itself: after an orgasm (the `QuitEnjoyment` reset) and on every stage change (the stage term).
  - The baseline also stores the stage and animation it was taken at (`sl_mirror_stage`, `sl_mirror_anim`). A baseline from another stage or animation is never folded in. SexLab's stage term (about +10) often steps up one mirror before `Engine_SetStage` rebaselines; before this fix it leaked in as `SexLab added 10` on every stage change.

## Scene ending

`Scene.psc` `Ending_*` (settings `sexlab.ending.*`):

- **Target:** `Ending_RollTarget` (from `Engine_BeginScene`, once per scene) picks the lead: `initiator` (`PickNonVictimInitiator` makes it the aggressor when there is a victim), else position 0. Target = `RandomInt(target_male_min, target_male_max)` for SexLab gender 0, else the female range. 0 = never jumps.
- **Engine:** `Engine_SetEndingTarget` (every `Engine_BeginScene`) sends `SetEndingTarget(sid, lead, target)`. The target is 0 once `ending_done` is set or `sexlab.ending.enabled` is off. The engine uses it for the early final roll.
- **Jump:** `Ending_Check` (end of `Orgasm_ApplyGroup`, after the engine's group roll) compares `OrgasmEngine.GetOrgasmCount(lead)` with the target. Reaching it in the second-to-last or final stage calls `Ending_ToFinal` → `thread.GoToStage(final)`. Earlier stages: no jump (`ending_done` stays false). The gate's `Engine_AdvanceToFinal` (its narration's voice started) does the same after releasing the gate hold. Once per scene (`ending_done`), never in LeadIn.
- **Victim hold:** in a victim scene (`OrgasmEngine.IsVictimHoldScene(sid)`: Multi-Orgasm Mini-game, timed, no LeadIn, a victim and a non-DOM aggressor expected to orgasm; aggressor = not a victim) the second-to-last stage's `StageStart` (`Ending_StageStart` → `Victim_StageStart`, once per (animation, stage), not after `ending_done`, needs `sexlab.ending.enabled`) holds the stage (`Victim_Hold`, `UpdateTimer` or P+ `PauseTimer`). Earlier aggressor orgasms are free; the scene no longer ends on them.
  - *Free mini-game:* the first orgasm group in that stage with an aggressor in it (the engine's early final roll already ran for everyone, so one DN) makes `Ending_Check` call `Victim_Release` + `Ending_ToFinal`, whatever the target (`Victim_AggressorFinished`; `Ending_WillJump` folds the stash into the final-stage DN).
  - *Gate scene:* the engine fires the gate once an aggressor reaches 100; `Engine_GatePassed` hands the victim hold to the gate hold as is, and the gate voice wait goes on as usual.
  - *Cap:* `Victim_Poll` (1 s, frozen while paused): after `sexlab.ending.victim_hold_max` (120 s, 0 = none) a gate scene calls `VictimHoldExpired(sid)` (the gate runs as the timer would have; nobody passing releases 3 s later), otherwise `Victim_Release` hands the stage back to its own timer without the held time. A manual stage move or animation change drops the hold (`Victim_Drop`); stepping back before the stage re-arms it.
  - Together mode and the disabled engine are unchanged (the Together gate already passes every expected actor).
- **Dialogue hold:** on the final stage's `StageStart` (`Ending_StageStart` → `Ending_Hold`) the stage is held with `thread.UpdateTimer(PAUSE_HOLD_SECONDS)`, as the pause key does. A stage change under the hold (the hold landed as SexLab turned the stage) applies it again to the new stage, once per (animation, stage).
  - **Response:** every orgasm DN (`NarrateOrgasmStash`, the `StageStart` fold) first takes `ending_response_mark = OrgasmEngine.NarrationMark()` (`NarrationTiming::SpeakerMark()`). `NarrationTiming` tracks each non-player speaker's response (first `SpeechStarted` to its `SkyrimNet_SpeechComplete`). `ResponseStartedSince(sid, mark)` / `ResponseDoneSince(sid, mark)` only count the scene's own actors (`OrgasmEngine::SceneActors`), so two scenes narrating together don't release each other's holds (2026-10-08).
  - **Release** (`Ending_Poll`, shares `OnUpdate` with the orgasm window, 1 s, 0.5 s once drained): 2 s after `FinalStageRemaining(sid)` first read ≤ 0 (`ending_drained_at`; the afterglow drain in the last stage, else the final stage's timer; unknown counts as drained), once `GetSpeechQueueSize() == 0`, the orgasm window is closed and `NarrationIdle()` (`NarrationTiming::Idle() && NarrationQueue::Empty()`: no DN sent in the last 10 s without speech, no line playing up to 20 s past its last speech event, no speech event within 1 s). Log `(drained)`. Always at `dialogue_hold_max` (30 s, capped at `ENDING_HOLD_CAP` 30; halved when `!thread.HasPlayer`; 0 = no hold; `(max)`). The response mark no longer releases: it never fired on 2026-11-07 and ignored the drain.
  - A `(drained)` release sets `ending_released_drained`: `LastStage_TimedLeft` returns 0 (no `LIST_MIN_SECONDS` floor), so a timed end list commits its highlighted line on the next poll, and `Ending_MidPoll` switches at once.
  - Release takes the hold back off (`UpdateTimer(-PAUSE_HOLD_SECONDS)`) without adding the held time: the final stage ends at the later of its own timer and the response. While the pause key holds the stage the timer is left to the pause.

## Stage by enjoyment

With the engine on, stages follow one actor's enjoyment instead of SexLab's stage timers, so the animation's progress matches how close that actor is to orgasm (`StageAdvancePrimaryEnjoyment`). It works in both modes and on all three backends (SexLab 1.6x, P+, AnimEngine).

**Active when all of these hold**, otherwise timers run as usual: engine enabled, `sexlab.enjoyment.stage_advance_primary_enjoyment` on (default), no LeadIn, 2+ stages, an eligible primary, the Scene's inputs received (`SetStageInputs`), and not turned off by the player (`stageEnjoymentOff`).

**Turning it off and on** (`Scene.StageMode_Cycle`, HUD control `stage_mode`; AnimEngine: `Hud.cpp` `OnAnimKey`): the player's pause key cycles enjoyment → paused → timers → enjoyment, and `pauseLabel` names what a press does next (*pause*, *play*, *enjoy*). A manual stage move also switches to timers (`StageManual_TakeOver`). Where `CanStageAdvancePrimaryEnjoyment` is false (final stage, `primaryFinished`, no primary), the key is plain pause / play. Auto play's `pause` key stays `TogglePause`, so its resume returns to the earlier mode.

- **To paused:** `TogglePause`, then `StageMode_Timers`. Pause goes first so the timer stays pushed out: `StageMode_Timers` calls `Victim_Release`, not `Victim_Drop`, because no stage move reset the timer, and a pull-back on its own could expose an expired timer.
- **To timers:** `TogglePause` resumes, and the mode is already off.
- **To enjoyment:** `EnableStageAdvancePrimaryEnjoyment` clears `stageFloor` and sets `stageSnap`, so `StageFollowPrimary` goes to the primary's band in either direction without the `kStageBackMinSecs` wait. `StageMode_Enjoy` runs `Victim_StageStart` to hold the stage it lands on.
- **Back off the final stage** (`StageStep` / `StageGoTo` → `Ending_LeaveFinal`, AnimEngine `OnStageBackFromFinal`, with the setting on): closes the list and re-arms the ending (`Ending_Rearm`) before the stage moves, so the pull-back doesn't land on the fresh timer. `SetStage` clears `primaryFinished` and the gate state, so the key cycles normally again.
- **New animation** (registry change, also seen by `Engine_SetStageInputs`): clears `stage_manual`, `stageEnjoymentOff`, `primaryFinished` and a pause. The pause is cleared without `TogglePause`, because the new animation resets SexLab's stage timer and the pull-back could end the stage early.

**Primary** (`PrimaryOf`, computed each tick; log `stage primary`):

1. Must expect an orgasm.
2. Male first, then female; a `femdom` animation (`stageFemdom`) puts females first. Creatures count by sex (`gender % 2`).
3. Within each, positions 1, 2, 3, ..., then 0.
4. A DOM slave comes after every other actor expected to orgasm. Its enjoyment is its DOM level.
5. Nobody qualifies: the stages keep their timers.

The victim role doesn't change the order: the primary is there to line the animation up with an actor's enjoyment. In a femdom animation with no female expected to orgasm, the male is the primary.

| Expected | Positions | Primary |
|---|---|---|
| [1,1] | [F,M] | 1 |
| [1,0] | [F,M] | 0 |
| [1,1,1] | [F,M,F] | 1 |
| [1,1,0] | [F,F,M] | 1 |
| [1,1] | [M,M] | 1 |
| [1,1], position 1 is the victim | [F,F] | 1 |
| [0,0] | any | none (timers) |

**Stage from enjoyment** (`StageFollowPrimary`; log `stage follows`): N stages give N−1 equal bands, and the last stage is the orgasm's. Stage `k` (2..N−1) needs `enjoyment > 100 × (k−1) / (N−1)`. With 5 stages: above 25 → 2, above 50 → 3, above 75 → 4, and stage 4 holds until the primary orgasms.

- **Both directions.** A move back needs `kStageBackMinSecs` (3 s) on the stage, so enjoyment hovering at a threshold can't flip it every tick. `stage_spike` applies only on a stage's first entry (`spikedThrough`).
- **No moves** while paused, in the final stage, once the primary has orgasmed in this animation (`primaryFinished`, set in `Fire` and `NoteExternalOrgasm`, cleared by a step back off the final stage), or while a gate is passing. `NotePrimaryFinished` also sets `gateDone`, so the gate on reaching the final stage doesn't fire the primary a second time. `SetStage` re-arms it on a new animation or a step back. Without this guard, the orgasm's reset to 0 would send the stage back to 1 just before the jump.
- **Delivery.** `Effect_MoveStage` → `Scene.Engine_MoveStage`, which ignores the move unless the thread is Animating. The engine re-sends after `kStageMoveResend` (3 s) if `SetStage` hasn't confirmed it. 1.6x jumps straight to the stage. P+ and AnimEngine take one step per call, and the engine sends the next as soon as `SetStage` confirms. P+ forward uses `SkipTo(pplus_path[stage])`, so a fork opens no branch menu.
- **Floor.** A forward stage change the engine didn't ask for (the cap, SexLab's own key) sets `stageFloor`, so the back rule doesn't undo it, until the key returns to enjoyment. A new animation (new registry in `SetStageInputs`) resets the floor, `spikedThrough`, `stageEnjoymentOff`, `primaryFinished` and the Together clock, and the next tick jumps to the stage for the carried-over enjoyment.

**Holds.** The victim hold is generalized rather than duplicated: `Victim_StageStart` holds every stage below the final on each entry (`victim_hold_enjoyment`), without needing `sexlab.ending.enabled`. SexLab sets `StageTimer` in `FireAction`, before it sends `StageStart`, so a hold applied there survives, including on stage 1. While the mode is active, `VictimHoldScene` returns false.

**Stuck stage** (per-stage clock, animating and unpaused):

- `sexlab.enjoyment.stage_punish_after` (15 s, 0 = never), once per stage entry: the primary punishes (`StagePunish` → `PunishNarrated`, so the hit, narration and target decision run as usual). The target is an actor on Deny all, or on Deny / Tease against the primary, otherwise the next position. A random method from `kPunishMethods`. Skipped if the primary is alone, or is the player without auto play.
  - `VictimScene`: an aggressor punishes instead of the primary: the ending lead if the engine plays it as an expected aggressor, else the first such aggressor. The target is a victim on Deny / Deny all / Tease against it, else a Passive victim, else the first victim. A victim never punishes.
  - No decision for the punished actor (AI off, no provider, failure): `NoDecisionFallback` sets an engine-played target to the ordered option, or Focused on the punisher (log `punished, no decision`).
  - The victim hold's Papyrus clock (`Victim_HeldTick`) caps each step between polls at 2 s, so menu time doesn't count toward `StageHoldCap`.
- `StageHoldCap` = the later of `sexlab.enjoyment.stage_hold_max` (60 s, 0 = no limit) and the stage's own timer: the stage advances outright (`Stage_Forward`), because a released timer would wait for the key on an untimed stage with `AutoAdvance` off. In a gate scene the second-to-last stage asks for the gate first (`VictimHoldExpired`), and advances 3 s later if nobody passed.
- `sexlab.enjoyment.stall_end_after` (30 s, 0 = never), NPC-only scenes, per-scene clock (`StallCheck`): if no non-DOM actor's enjoyment reaches a new high, the scene ends where it is (`Effect_EndStalled` → `Engine_EndStalled` → `LastStage_Stop`; AnimEngine `OnStallEnd`), with no gate and no final stage. It compares against a per-actor high-water mark, because an edge cycle (100 → 99.93 → 100) would otherwise count as rising forever. An orgasm resets the marks. The clock is frozen while paused, in the final stage, once the primary has finished, while anyone is rushing, and during a gate's voice wait. With no primary (timers, or nobody expected) it doesn't run. At 30 s it comes before the 60 s `StageHoldCap`, so it can end a scene before the cap's gate would have passed an aggressor outright. The engine resends every 5 s until the scene ends, because `Engine_EndStalled` ignores a thread that isn't `animating`.

**Ending.** The primary's orgasm goes to the final stage from any stage (`Stage_PrimaryFinished` in `Ending_Check` / `Ending_WillJump`).

**Victim scene ending** (`VictimScene`: a victim and a non-DOM aggressor expected to orgasm). The stages still follow `PrimaryOf`, because the animation says who is aroused (a victim can be the primary). The primary's orgasm doesn't finish the scene: `NotePrimaryFinished`, `JoinGroup`'s `primaryFired`, the penultimate gate's primary-at-top trigger and `Stage_PrimaryFinished` all skip it. Instead the penultimate gate fires when an aggressor expected to orgasm reaches 100 (`victim scene: aggressor X at 100, gate`), and the 98 `gateHeld` cap doesn't apply to those aggressors. `Ending_PickLead` prefers an expected non-victim, so the lead is an aggressor. When the lead reaches `ending_target` (`Ending_EndReached`), `Ending_EndState` does the following:
- It sets `ending_done` and `ending_end_state` and calls `SetEndHold(sid, true)`.
- It releases the victim hold, jumps to the final stage (`Ending_ToFinal`: 1.6x `GoToStage`, P+ `SkipToSink`; the final stage's `StageStart` holds its fresh timer through `ending_hold_pending`) and opens the last-stage list (`LastStage_Begin`).
- **The lead below its target** (`NoteLeadMidFinish` in `Fire`): the engine sets `primaryFinished` / `gateDone`, so the reset bar does not send the stage back and the lead's bar drains (afterglow). Log `victim scene: lead X orgasm n/target at stage s/N, last stage`. The Scene (`Ending_MidReached`, native `IsPrimaryFinished`) sets `ending_mid` and calls `Ending_ToFinal`. `LastStage_Begin` takes no list and no NPC decision. `Ending_MidPoll` waits until the engine is in its last stage (`IsLastStage`; right after the jump the Papyrus stage is final first, so it keeps waiting while only `IsPrimaryFinished` is true) and `FinalStageRemaining` is 0, never before `LIST_MIN_SECONDS`, then switches through `LastStage_TrySwitch`: line 5 (the Scene Creator's tags and suppressed tags, `SetStartTags`), else lines 2–4 in a random order. After 3 failed tries it falls back to `LastStage_Step(-1)` (Num 4). The new animation clears `primaryFinished`, and `Ending_Rearm` keeps the target.
- **Any other orgasm** below the final stage (a victim primary, an aggressor that isn't the lead, or any non-primary partner, in any scene): `StartOrgasmHold` in `Fire` / `NoteExternalOrgasm` keeps the bar as an `afterglowFree` drain, so `StageFollowPrimary` waits on the orgasm's stage while it drains at the afterglow rate. It sets `stagePunished` (the hold is not a stall). At 0, `OrgasmHoldSpeaking` keeps waiting until a line that started after the orgasm finishes (`SpeakerMark` → `StartedSince` / `DoneSinceMostRecentStarted`). When none started, it waits for the speech estimate + 4 s, never longer than `hold_max`. Then the afterglow ends and the stages follow again. Without stage by enjoyment only the drain applies (no `stagePunished`). `AfterglowRemaining` counts these bars too, so one that runs into the last stage holds the end. `ArouseLocked` refuses any `afterglow` target (no partner gain while draining). Logs: `orgasm hold at stage s/N (scene n, primary 0x…)`, `orgasm hold ended after Ns`.
- `endHold` stops stage moves, the gate and the stall end. The engine sets it itself in `Fire` (`NoteEndReached`), the moment the lead's orgasm reaches `endingTarget`. A Papyrus round-trip would be too late: `StageFollowPrimary` sends the stage back on the reset enjoyment within the same second. The Scene's `SetEndHold(true)` is then a no-op. `Ending_Check` releases an engine hold the Scene doesn't turn into an end state (ending off, P+ < 2.17).
- While `endHold` is set, `FinalStageRemaining` returns the time until the lead's afterglow drains to 0, so the list has a deadline (at least 4 s, `LIST_MIN_SECONDS`). The player picks with Num 6 / Enter / Space. When the time runs out, the highlighted line is committed. An NPC-only scene commits the NPC's line.
- **The lead follows expectations.** If the lead fell to a victim because no aggressor was expected to orgasm (the first animation's position defaults), and a later animation makes an aggressor expected, `Ending_RollTarget` (every `StageStart`, through `Engine_BeginScene`) moves the lead to that aggressor with a target one above their count. Log `lead X (victim) -> Y (aggressor now expected)`. Otherwise the stages follow the aggressor while the end waits on the victim's target, and every stage waits for the victim hold's cap.

### Last stage (afterglow)

`InLastStage` is `endHold`, or `primaryFinished` on the final stage. Native `IsLastStage(sid)` (tasklet-callable) exposes it.
- **Afterglow:** an orgasm that starts the last stage (the primary's, or the lead reaching the target), or any orgasm during it, keeps its bar (`afterglow`, `afterglowFrom`).
  - While the jump to the final stage is still in flight, the bar holds.
  - Then it drains at one fixed rate: `sexlab.ending.afterglow_seconds` (default 10) per 100 points, in every scene. Num 5's pause doesn't stop it (only a game, menu or narration-queue pause does, through `dt`).
  - An afterglow actor gets no gain, steps or orgasm test (`CanOrgasmNow` is false); a forced request still fires.
- **Length:** `AfterglowRemaining` = the highest afterglow bar / the rate. `FinalStageRemaining` returns it in the last stage. `lastStageElapsed` is kept for the log only.
- **List deadline:** `LastStage_TimedLeft` = `max(LIST_MIN_SECONDS (4), FinalStageRemaining)`. It is read at the snapshot and again whenever the countdown (re)starts after a freeze (Num 5 pause, a menu, an NPC deciding), because the bar kept draining meanwhile.
- **Chain first:** the scene's animation chain (`Scene.chain_registries`, set by the Scene Creator start via `SetChain` or a Description Editor commit via `WebUI_ApplyChain`) decides the next animation. `LastStage_ChainNext` is the chain entry after the playing animation that SexLab resolves; after the last entry it wraps to the first only when `last_stage_mode` is loop (2). A playing animation outside the chain has no next. When there is a next, or the chain ends under end (1, `LastStage_ChainEnds`), `LastStage_Begin` skips `LastStage_Request` (no decision call): it preselects the next animation's line (`LINE_NEXT`, 6) or Stop, and the deadline or player commits. NPC choice (0) after the chain's end asks the NPC as before. The WebUI calls `last_stage_mode` the **last animation** pulldown. `LastStage_PickRegistry` returns the chain's next for line 6 (and line 5 from `Ending_MidPoll`); the act lines 1–4 always get their tag pick. `LastStage_Commit` skips `LastStage_OpenEditor` only for line 6. `LastStage_OnDecision` replaces the NPC's choice with line 6 when a chain next appeared while it decided, and `WebUI_ApplyChain` re-shows an open list (line 6 selected again, or Stop when the next is gone). A one-animation loop replays it (P+: `LastStage_Step(-1)`, since ResetScene to the playing scene does nothing). Scenes not started by the Scene Creator have no chain until the Description Editor sends one. **Top line:** `LastStage_ShowList` passes the chain next's name to `LastStage_Show(index, advance_key, next_name)`; the HUD adds "Next: <name>" as row 0 and moves the act lines down one (`Hud` `g_listNextName`, `RowOfChoice` / `ChoiceOfRow`). `LastStage_Index`, `LastStage_OnMove` and `LastStage_OnSelect` carry choice codes (0–4, 6), never rows. `LastStage_ChainActLine` maps the chain's next to an act by tag (Vaginal 2, Anal 4, Oral / Blowjob / Cunnilingus 3, else Cuddle 1) for `LastStage_NoteIntent` only.
- **Leaving:** `ClearAfterglow` sets those actors to 0 on any way out except Num 4: `SetEndHold(false)`, a new animation (`ClearAfterglow(sc, true)` also ends a Num 4 drain), a step back off the final stage, or the tick seeing the last stage end.
- **Keys** (Scene `LastStage_Active` → `LastStage_Step`): none of them switches stages to timers. `LastStage_Active` is true whenever the engine is in the last stage (`IsLastStage`), not only once the list is up. A Num 4 pressed before the list appeared used to take the old path and switch to timers.
  - **Num 4:** `LeaveLastStage` first, then `LastStage_Close` and `Ending_Rearm`, so `SetEndHold(false)` can't zero the drain. The Scene moves to stage 1 (the return value), and `StageFollowPrimary` skips the scene while any actor has `afterglowFree`, so the stage waits at 1 until the drain reaches 0.
    - `LeaveLastStage` marks the afterglow actors `afterglowFree`, clears `endHold`, `primaryFinished`, `stageEnjoymentOff`, `gateDone` and the floor, and returns the stage for the primary's bar now (the `StageFollowPrimary` band, 1..N−1). The Scene moves there (P+: `SkipToLegacy`), because the engine doesn't move off the final stage itself.
    - The bar keeps draining and `StageFollowPrimary` steps the stages down with it (3 s per step back). At 0 the afterglow ends (`afterglow ended at 0`) and gain resumes.
    - A pause drops too.
  - **Num 6:** commits the list line. Before the list is up, it does nothing.
  - **Num 5:** pause / play for SexLab's timer and the list countdown only (`StageMode_Cycle` checks `LastStage_Active` first).
- `LastStage_Close` clears the end state and `endHold`, as do a new animation (`SetStageInputs`) and a stage key (`Ending_CanLeaveFinal`). If that jump is sent during an animation change, SexLab drops it. The new animation's first `StageStart` then sees `ending_done` on a stage below its last, and `Ending_StageStart` re-arms the ending (stale final-stage holds are dropped without a timer pull-back). Without that, `Victim_StageStart` holds nothing and SexLab's timers carry the new animation to its final stage. `sexlab.ending.target_*` no longer applies, and other actors can orgasm several times before that. The early final roll in `JoinGroup` runs when the primary is in the group.

- **Gate scene:** due when the primary reaches 100 and `CanOrgasmNow`, not on the stage timer. The primary passes outright and is exempt from the 98 cap (`gateHeld`). Aggressors still pass outright, but an aggressor's orgasm no longer jumps the stage.
- **Together:** `SceneProgress` uses an animation-wide clock over stages 1..N−1, because a stage-by-stage clock would deadlock: stages would wait for enjoyment and enjoyment for stages. The gate is due at `kRushHover`. With the gate off, the primary at `kRushHover` goes to the final stage directly (`fx.advances`) and the safety net finishes it.

**HUD stage modes** (`StageModeOf` → the HUD's `stageMode`; Scene `StageMode_Cycle`, AnimEngine `Hud::OnAnimKey`):

| Mode | Num 4 / 5 / 6 | Num 5 label | Num 5 press |
|---|---|---|---|
| `enjoy` (stages follow enjoyment) | greyed | timer | to timers, running (`StageMode_Timers`: the victim hold's pull-back leaves out the held time, so the stage gets the rest of its own timer) |
| `timer`, running | normal | pause | pauses the timer |
| `timer`, paused | normal | enjoy (play if enjoyment isn't possible) | unpauses and returns to enjoyment (`StageMode_Enjoy`) |
| `last` (last stage, or the end list up) | normal | pause / play | pauses / resumes the timer and the list; the afterglow keeps draining |

**Manual takeover.** While the mode drives the scene, the HUD's `prev`, `pause` and `next` are greyed (`stageMode` `enjoy`) but still work. `StageStep`, `StageGoTo` and the editor's direct `GoToStage` call `StageManual_TakeOver` after a move that happened: `DisableStageAdvancePrimaryEnjoyment` and `Victim_Drop` (GoToStage already reset the timer, and `Victim_Release` would subtract the hold from the new stage's timer). Timers run for the rest of the scene. On AnimEngine, `Hud::OnAnimKey` does the same. Auto play isn't offered `previous` / `next` while the mode is active (`BuildTurn`), so the AI can't turn it off by accident. The AnimEngine debug panel's next / back don't take over.

**Not saved.** Nothing new goes in the co-save. After a load the mode stays off until `SetStageInputs` arrives (`stageInputsKnown`): `Victim_Poll` re-sends it within 1 s, and `Engine_SetStageInputs` re-sends the Scene's `stage_manual`. A hold whose real-time clock reset on load starts its clock over instead of expiring.

Natives: `SetStageInputs`, `StageInputsKnown`, `IsStageAdvancePrimaryEnjoyment`, `GetStagePrimary`, `StageHoldCap`, `DisableStageAdvancePrimaryEnjoyment`. AnimEngine: `OnMoveStage`, with `StageStartLocked` / `EndingCheckLocked` / `Tick` as the ports; genders come from base sex, `femdom` from the AnimDB row.

## Contact mode (planned)

With AnimEngine (see [anim-engine.md](anim-engine.md) §7), passive gain is driven by detected contact instead of animation tags:

- `SetStimulation(actor, level 0..1, sites)` comes from `AnimContacts` each tick. A partner's hand, penis or strap-on, vagina or mouth (or the actor's own hand) at the actor's penis, vagina or anus counts. Passive gain = the passive rate × `level`. In contact mode, an actor with no contact gains nothing passively; the mini-game and strategies are unchanged.
- First contact calls `SetOrgasmExpected(actor, true)`, sticky for the rest of the scene.
- The detected sites feed `SetSceneActs`.
- Config: `sexlab.enjoyment.contact_mode`. Not implemented yet.

## SexLab P+

The engine itself is unchanged; the Scene shell feeds it a linear view of P+'s scene graph ([sexlab-pplus.md](sexlab-pplus.md)):

- **Stage / count / seconds:** `Engine_StageCount` is the projected path (played history + longest path from the active stage to a sink); `thread.Stage` (history length) is the index, so the gate stage is the node before a sink and the final stage is the sink. `Engine_StageSeconds` uses P+'s per-node rule (`GetFixedLength`, climax stage = last timer, else the config timers). A branch changes the path; `SetStageTimers` then restarts the Together curve from current enjoyment.
- **Holds:** pause, gate and ending holds are one `PauseTimer` (`Timer_SyncHold`), never `UpdateTimer`.
- **Jump to final:** `Ending_ToFinal` calls `SkipToSink` (the path's sink) instead of `GoToStage(count)`, which is one edge on P+.
- **Finish:** after the dialogue hold the final stage stays paused and `Ending_Watch` calls `EndAnimation()` at the stage's remaining time, so P+'s enjoyment-wait (`ThreadWaitsForOrgasm` → restart) never runs. `Scene.PPlus_StageStart` ends a thread P+ restarted from an expired sink anyway, and `DURATION_CAP_SECONDS` counts from the first sink.
- **Hooks:** no synthesized `OrgasmStart` / `OrgasmEnd`; P+ sends its own at climax stages.
- **Skills:** act tags come from the registry (`Scene.AnimHasTag`), not the empty proxy.

## AnimEngine scenes

Built in checkpoint 12, untested in game. This is strangler step 2 in [scene-migration.md](scene-migration.md) §8. AnimEngine scenes ([anim-engine.md](anim-engine.md) §4) have no SexLab thread and no Papyrus Scene. `AnimEngineOrgasm` (`SKSE_Source/src/AnimEngineOrgasm.cpp`) is the native port of the Scene script's part: `Engine_*`, `Ending_*`, `Gate_*`, `Victim_*` and `Orgasm_ApplyGroup`. The engine itself is unchanged.

**Setting:** `sex-graph.json` `anim_engine.orgasm_engine` (Sex Graph panel, default on), read at the scene's first stage. With `sexlab.enjoyment.engine_disabled` on, the scene is not wired and a warning is logged, because SexLab is not there to own enjoyment.

**sid:** `100000 + AnimEngine scene id` (`AnimEngineOrgasm::SidOf`). SexLab pool sids stay below it.

**Notes from AnimEngine:**
- AnimEngine posts every note as a task, never under its lock.
- First stage, the `Engine_BeginScene` port:
  - Roles come from `StartScene` (the debug panel's **Victim**: that position 2, the others 1); seeds are 0.
  - Blocked and DOM are off. Skill and lewd are 0, and the bonus is unskilled with relationship ranks only.
  - Acts come from the AnimDB row tags. `SetOrgasmExpected` comes from `pos_no_orgasm`.
  - Lead: the first expected position. The target is rolled from `sexlab.ending.target_*`.
- Each stage, the `Engine_SetStage` port:
  - `SetEndingTarget`, then `SetStageTimers(secs, leadIn=false)`, then `SetStage(stage, count)`.
  - Then the `Victim_StageStart` / `Ending_StageStart` ports.
- Stage numbering is AnimEngine's `StageView`:
  - A linear graph (all SLAL): node order.
  - A branch: history + current + the first-edge chain to a sink (the P+ model above, but with the path auto-advance actually plays).
  - Seconds are AnimEngine's own `StageSeconds`.
- Pause: `SetScenePaused`. End (sink, request, actor gone, exhausted): `EndScene`. A load or revert clears the bridge, and an epoch drops queued notes.

**Effects:** `RunEffects` routes an actor of a wired scene to the bridge instead of the Papyrus shell:

| Effect | Bridge |
|---|---|
| `OrgasmGroup` | No SexLab `ForceOrgasm` / mirror / SLA relief. Counts and the `SkyrimNet_SexLab_Orgasm` event already ran. Narration (checkpoint 15): one orgasm DN per group, built in C++ with the [orgasm-narration.md](../reference/orgasm-narration.md) sentences and budget, sent through the shell's `NarrateOrgasm` (`orgasm_level`; DirectNarration with the player, else Nearby). There is no orgasm window, stage fold or ending-hold mark yet. Then the shell's `OrgasmEffect` per actor (gate groups too), then `Ending_Check` (victim hold: an aggressor orgasm in the second-to-last stage jumps; lead at target from the second-to-last stage jumps) |
| `GatePassed` | Narration seam. No voice (the step 2 stub, so every gate pass today): no hold, jump to the final stage, 5 s flash. The `kSent` branch still has the old voice hold and is unreachable; change it to match `Scene.Engine_GatePassed` when the stub is replaced. The dialogue hold can't read Global AI, so with AI off it runs to its cap |
| `AdvanceToFinal` | Release the gate hold, then `AnimEngine::GoToFinal` (final-stage dialogue hold when narration exists) |
| `Mirror` | dropped (SexLab enjoyment) |
| `Exhausted` | `AnimEngine::EndScene` |
| DomSync, StrategyChanged, narrations | unchanged (global Papyrus; DOM is off here) |

**Holds:** these are `AnimEngine::SetHold` bits.
- A held stage does not auto-advance, but its clock keeps running. A release therefore advances at the later of the timer and the hold, with no timer push-out.
- Entering a stage clears the holds. The bridge re-applies them where the Scene would.
- `AnimEngineOrgasm::Tick` runs at the end of each engine tick, on unpaused game time, and polls the `gate_wait_max`, `victim_hold_max` (then `VictimHoldExpired`, release 3 s later) and dialogue-hold timers.

**HUD:** a player in an AnimEngine scene sees the HUD. The end / previous / next / pause keys drive AnimEngine, and deny toggles `SetSceneBlocked` / `AllowOrgasm` through the bridge.

**Not saved:** `ORGE` skips AnimEngine sids. The stale drop asks `AnimEngineOrgasm::IsLive` instead of `SexLabAnimatingFaction`.

**Gaps:**
- Orgasm / gate / deny narration (step 5).
- SLA relief and SexLab cum / sound.
- DOM slaves, Lover's Ledger first times, SexLab skills.
- `OrgasmStart` / `OrgasmEnd` thread hooks.
- LLM actions on AnimEngine actors (the Actions.psc deny / orgasm paths still look for a SexLab scene).

## Sex is hard work (stamina regen)

**Disabled for now** (0.35.2): the `sexlab.stamina.*` settings are removed from the manifest and no longer read, and `staminaFatigue` defaults off, so `GetStaminaRegen` returns 100 and nothing below happens. The code is kept for later; the defaults below are the struct defaults.

`sexlab.stamina.fatigue`. Each actor has `regen`, 100 → -10 (`kRegenFloor`) percent of its default stamina regen, tracked per actor:

- The tick subtracts the scene's `regenRate` = `(100 − sexlab.stamina.regen_at_orgasm) / targetSecs` points per second (`ApplyStageTimers`; default 45 at the orgasm point, so an orgasm's cost leaves a Mutual NPC tired near 35). Scenes without stage timers use `sexlab.stamina.regen_decay` points per minute (40). This happens while the scene is animating and not paused. While no actor in the scene expects orgasm, an actor loses nothing until their enjoyment reaches 50. `regenRate` is not saved; a scene after a load computes it from its own timers.
- Crossing a fatigue stage sends one DirectNarration: below 90 "<name> is breathing hard.", 40 or less "is tired.", 0 or less "is exhausted." (`SpendRegen`; regen only falls, so a reload does not repeat it).
- Each orgasm subtracts `sexlab.stamina.orgasm_cost` points (10).
- The tick takes back the decayed share as stamina damage: `MaxStamina × base StaminaRate × base StaminaRateMult × (1 − regen/100) × dt`. It uses base values, so potions and buffs add on top. At full stamina only the negative share (`−regen/100`, regen below 0) drains. No damage is applied in combat. No actor value modifier is left behind.
- A non-victim (player or NPC) reaching regen -10 ends the scene once: `Effect_Exhausted` → `Scene_Manager.EndExhausted` → `Scene.AnimationEnd`. That actor's end sentence is "is too tired to continue." Victims stay at -10.
- Native `GetStaminaRegen` (can be negative). The Scene writes position obj `stamina_regen`. The end DN and 0550 use the same tiers on the int: ≥ 90 nothing, < 90 "breathing hard", ≤ 40 "tired", ≤ 0 "exhausted".
