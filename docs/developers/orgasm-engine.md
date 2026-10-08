# OrgasmEngine

The C++ OrgasmEngine owns enjoyment and orgasms for **every** SexLab scene, including NPC-only scenes. SexLab's own trigger is switched off (`thread.DisableAllOrgasms(true)`), and SLSO is not used.

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
| **Multi-Orgasm Mini-game** (default) | Passive rate x `(1 + minigame_bonus_mult x bonus)` | No gate, no safety net: only reaching 100 (and the group join) fires, so several orgasms or none |

**Bonus** (`ActorState.bonus`, `ComputeBonus`): `Scene.Engine_SetBonusInputs` (from `Engine_SetSkills`, start and animation change) sends `SetBonusInputs(actor, ownSkills[], partnerSkills[], lowestRank, highestRank, actSkill)`: `Stats.GetSkillLevels` of the actor and of the partner SexLab bases skills on (the player when present, else the next position; creatures send empty arrays = unskilled), the present relationship ranks, and the act skill (0 foreplay, 1 vaginal, 2 anal, 3 oral). The engine applies SexLab's `StartAnimating` formula (victim: `lowest − 3 + clamp(ownLewd − ownPure, ±6)`; aggressor: `−((highest − 4) + clamp(partnerLP − ownLP, ±6))`; normal: `highest + clamp(avgLewd − avgPure, 0, 6)`; unskilled: rank terms only) with `RandomInt(1,10)` replaced by 5.5, 50 points = 1.0, plus `(partner act skill − 2) / 6`, times `bonus_scale` (0.5), clamped to ±`bonus_clamp` (0.75).

**Together curve** (`ApplyTogetherCurve`): progress `p` = (completed stages + `min(1, stage elapsed / stage timer)`) / (N − 1), on the scene's animating, unpaused stage clock (`stageElapsed`; untimed: stage index). `E(p) = 1 − (1 − p)^k`, `k = clamp(1 + together_k_range × bonus, 0.5, 2.5)`. Each tick closes the matching share of the gap to 100 (`(E(p) − E(p0)) / (1 − E(p0))`), so carried-over or external enjoyment still lands on 100 at `p = 1`. Capped at `kRushHover` (98) before the final stage; in the final stage an actor held at 98 goes to 100. A new animation (`SetStageTimers` change) or stepping back rebases the curve. No stage spike in this mode (the curve holds it); DOM slaves keep the passive rate.

## NPC strategies (Multi-Orgasm Mini-game)

SkyrimNet's decision model (e.g. Jev) picks a strategy per NPC; see [Strategy decisions](#strategy-decisions). Every `sexlab.minigame.npc_interval` s (2) the tick plays one step per NPC (`StrategyStep`), through the same cost / mental-break / edge code as a key press (`ArouseLocked` / `CalmLocked`), not narrated. A step without stamina / magicka is skipped. No step runs before the scene's first non-empty `SetStageTimers` (SexLab's `thread.Timers` is empty at the first `Engine_SetStage`), or `kUntimedGrace` (10 s) after `BeginScene` for a scene that never sends timers. The player is never automated.

- **Step size, timed scenes:** `mgStepRate × npc_interval × random(npc_step_min, npc_step_max) / mean(min, max)` (4–8: 0.67–1.33×), divided by the scene's mean NPC skill factor `mean(1 + 0.1 × skill)`. Arouse then applies the actor's own skill factor, so skill matters between actors while Mutual stays on budget. See [Mini-game calibration](#mini-game-calibration).
- **Step size, scenes without timers:** `random(npc_step_min, npc_step_max)` (arouse × skill factor).

| Strategy | Who | Step |
|----------|-----|------|
| Passive | anyone not forced | none |
| Mutual / Selfless | not forced, 2+ actors | arouse the lowest-enjoyment actor (self included / others only) |
| Selfish | not forced, or forced via RejectForce | arouse self |
| Together | not forced, 2+ actors | calm self when > 5 ahead of the least-aroused partner, arouse self when > 5 behind |
| Tease (target) | non-victims | arouse the target below 90, calm (edge) it at 90+ |
| Reject | victims, or forced via RejectForce | calm self |
| CumQuick | victims | arouse the most-aroused aggressor (none: most-aroused other) |
| Greedy (target = victim) | non-victims, a victim present | arouse self; the target is **forced** to arouse the speaker |
| ForcedOrgasm (target) | non-victims | arouse the target; the target is **forced** to arouse self |
| AcceptForce | forced | the forced action |
| NonSexual | no actor expects orgasm | nothing (the default while no actor expects orgasm; NPCs on a default switch both ways when that changes, announced) |

- **Forced** (`forcedBy`, `forcedAction`): only `acceptforce`, `selfish` and `reject` (resist) are offered; only `acceptforce` during the player Force fear cooldown. Ends when the forcer picks something else or leaves ("<name> is no longer forced by <forcer>."), or at scene end. The player is never forced.
- **Force** (`OrgasmEngine::Force(forcer, victim, strategy, method)`): the HUD Force key (`PlayerForce`, player aggressor only) and the `SexLab_Force` action (any non-victim forcer, `CanForce`) share one path: `forcedAction = kPlayStrategy`, the chosen strategy, the method noun and the fear cooldown. A method naming one of the forcer's Novice / Apprentice Damage Health spells (`Aid::WeakAttackSpells`) reads "hits <victim> with <spell>" and queues a health hit of the spell's smallest magnitude, never below 1 health (`Aid::QueueWeakSpellHit`; no cast, so no combat or bounty).
- **Aid** (`Aid.cpp`, HUD Aid key and `SexLab_Aid`): healing / stamina spells (beneficial Value Modifier effects on Health / Stamina; base list plus `addedSpells`) and such potions. The restore is applied directly as magnitude × duration (a concentration spell as 3 s of casting) and the spell's magicka cost is spent; a potion is removed from the caster. The HUD greys the cell out via `Aid::HasOptions`, checked at most once a second.
- **Broken** (mental break): the strategy is set aside and the NPC arouses itself until it recovers.
- **Defaults** at `BeginScene` by role: `sexlab.minigame.default_strategy_normal` / `_aggressor` / `_victim` (Mutual / Selfish / Passive). Not announced. They are the fallback until the scene-start decision lands, and always without a decisions provider.
- **Announce** (every change): `Effect_StrategyChanged(actor, target, msg, observed, narrate)` shows no notification. `narrate` (API / Papyrus `SetStrategy`, forced / released, NonSexual switches): `DirectNarration_Optional("sexlab_strategy", msg, …)`. Decision-made changes (`StrategySource::kDecision`): no narration, `SkyrimNetApi.RegisterEvent("sexlab_strategy", observed, …)`, a short-term event with how it looks to others ("Lydia appears to be focused on her own enjoyment.", `kStrategies[].observed`).
- **Prompt / HUD**: `Scene` writes `GetStrategyText` to the position obj `strategy` (0050 prompt: "<name> focuses on …"; the speaker's own line ends "Speak and act in line with that approach."); the HUD shows the label as a tag.
- `MCM.ApplyMiniGameActions` unregisters Arouse / Calm in Together mode (switching back needs save + reload). There are no strategy actions.

### Strategy decisions

`SKSE_Source/src/StrategyDecision.cpp` asks SkyrimNet's decision model through `PublicSendCustomDecisionToLLM` (public API v12+). One request decides one NPC (the *focus*), with the template `prompts/decisions/sexlab/minigame_strategy.prompt` (one `[ question strategy choice ]`). Off with `sexlab.minigame.decision_strategy` or in Together mode.

- **Triggers:**
  - *Scene start*: the tick marks a scene ready on the same rule as `StrategyStep` (first non-empty `SetStageTimers`, or `kUntimedGrace` after `BeginScene`) and dispatches `OnSceneReady(sid)` → one request per NPC (`SceneNpcs`). Once per scene (`decisionsStarted`); scenes restored from the co-save skip it.
  - *Dialogue*: `PublicRegisterEventCallback` for `dialogue`, `dialogue_npc` and `dialogue_background`. The originator, if a managed non-player actor, gets a request with the line (`data.text` / `dialogue` / `line`).
- **Threading:** SkyrimNet calls both callbacks on its ThreadPool. They only copy strings, then `AddTask`; context building, relationship lookups and `ApplyStrategyDecision` run on the game thread.
- **Push (`contextJson`)**, built from `OrgasmEngine::GetStrategyDecisionInput` under the engine lock: `trigger`, `focus_uuid`, `focus_name`, `last_line_text`, `progress` (start / middle / near the end / final stage), `role` (partner / aggressor / victim), `arousal` (0050 bands), `orgasms`, `expects_orgasm`, `broken`, `current_key`, `approach`, `forced_by`, `force_method`, `partners[]` (`uuid`, `name`, `is_player`, `role`, `arousal`, `orgasms`, `approach`, `relationship`, `relationship_rank`), `options[]` (`key`, `text`).
  - **Options** are only what `StrategyAllowed` permits now, so the model cannot pick an illegal one. Tease / Greedy / ForcedOrgasm expand to one option per valid target, key `<key>_p<slot>` (1-based SexLab position); the text comes from `kStrategies[].option` with names and pronouns filled in.
  - **Relationship**: Skyrim's rank between the focus and each partner, `BGSRelationship::GetRelationship` on the actor bases (template bases as a fallback): `4 − level`, labels lovers / allies / confidants / friends / acquaintances / rivals / foes / enemies / archnemeses; no relationship form is `strangers` (0).
- **Pull (template):** `decnpc` and `render_character_profile("short_inline", …)` for the focus and NPC partners; `sexlab_get_threads(focus_uuid)` for the act and location; `get_recent_events(15, focus_uuid)` + `format_event(…, "compact")`; `last_line_text`.
- **Answer:** `answers.strategy.choice` and `answers.strategy.confidence` → `ApplyStrategyDecision`, which returns a `DecisionResult`: `kDropped` when the scene ended or its `generation` changed (bumped when the roster changes; a reused sid gets a new one); the `_p<slot>` suffix resolves through the snapshot's `slots`; same key and target = `kKept` (quiet); a change with a reported confidence under `sexlab.minigame.decision_min_confidence` (default 0.6; no confidence reported = no floor) = `kLowConfidence`, current strategy stays; else `SetStrategyLocked` with narrate off (`kChanged`).
- **Coalescing:** one request in flight per NPC; a line arriving meanwhile is kept and sent once the answer lands.
- **Failure:** `no_decisions_route` warns once and stops asking until the next load (role defaults stay); other errors are logged. Log lines: `StrategyDecision: send …`, `answer <key> p=… (changed | kept | low confidence, kept current | unknown key | dropped: scene ended or roster changed)`.

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
3. **Gate (Together mode only; `sexlab.ending.gate`, timed scenes, never in LeadIn; Together skips the roll, everyone expected passes):** each actor who has not orgasmed in this scene, is expected to orgasm and passes `CanOrgasmNow` rolls once: `enjoyment + random(0, random_bonus) + stage_spike ≥ 100` (`RollOrgasm`).
   - **When:** `lead` seconds before the second-to-last stage's timer ends (animating, unpaused time; on entering it when `lead` is longer), or on reaching the final stage first. `lead` = `NarrationTiming::EstimateSeconds`: the median of the last 20 clean DN→first-speech samples this session, `sexlab.ending.gate_lead_default` (5 s) until 3 exist, clamped 1–30 s.
   - **A pass does not fire yet.** The actor is *rushing*: enjoyment climbs at `(98 − enjoyment) / lead` per second (no passive gain, pause and speed ignored, capped at 98 before the final stage, no other orgasm test). `Effect_GatePassed(actors, holdStage)` → `Scene.Engine_GatePassed` stashes the passers and sends one DirectNarration at once, then calls `GateNarrationSent(sid)`, which marks `NarrationTiming::SpeechStarts()`.
   - **Before the final stage** the Scene holds the stage (`Gate_Hold`, `UpdateTimer` like the pause key). The first non-player `SkyrimNet_SpeechStarted` after the mark makes the tick dispatch `Effect_AdvanceToFinal` → `Scene.Engine_AdvanceToFinal`: release the hold, `Ending_ToFinal` (final stage + dialogue hold). No voice by `sexlab.ending.gate_wait_max` (20 s): `Gate_Poll` advances anyway. SexLab reaching the final stage first also ends the wait.
   - **In the final stage** the rush finishes within 1 s and fires at 97 as a `gate` group: `Fire` only, no group join, no extras fold. `Orgasm_ApplyGroup` runs `ForceOrgasm` and skips the stash and narration.
   - **Gate join:** when anyone passes, every other actor who is expected to orgasm, passes `CanOrgasmNow`, isn't rushing and is at ≥ `group_join_final` rushes with them and goes into the same gate DN. Repeat orgasms join too (only rolling skips them). Log `gate join`.
   - A block (deny) cancels the rush. A forced request fires through the normal path. Stepping back before the last two stages drops the rush and re-arms the gate. Rushes are not saved.
   - All fail: SexLab advances normally, no orgasm.

   **Safety net (Together mode; gate off, or no timers):** at 90% of the final stage's timer, each non-DOM actor at 90 or more who has not orgasmed, is not blocked or edging and was not calmed in the final stage fires as *combined*. With no timers it fires on entering the final stage, everyone when the mini-game is off.
4. **Group (`JoinGroup`):** everyone fired in this scene in this tick (steps 2 and 3, forced included) is one group. Every other actor who passes `CanOrgasmNow` (not a DOM slave, blocked, edging, cooling down or out after a final roll) and isn't rushing joins outright at ≥ `sexlab.enjoyment.group_join` (default 85, log `group join`). Below that it rolls once: `enjoyment + random(0, random_bonus) ≥ 100` (`RollOrgasm`, `sexlab.minigame.random_bonus`, default 10). Passers join the group. Repeat orgasms join or roll too. Log `group roll`.
   - **Early final roll:** in the second-to-last stage of a timed, non-LeadIn scene, when the Scene's ending lead (`SetEndingTarget`) is in the group and has reached the target (the Scene is about to jump), everyone still out rolls again with `enjoyment + random(0, random_bonus) + stage_spike ≥ 100`. A pass joins this group, so it goes into the same DN. A fail sets `finalRollFailed`: no more orgasms (no denied event either) until the scene steps back before the last two stages, except a forced request. Not saved. Log `final roll`.
   - The same `JoinGroup` runs for `NoteExternalOrgasm` and `AllowOrgasm`.

   The group is sent as one `Effect_OrgasmGroup`, so it gets one narration. It is `individual` unless every trigger came from the safety net. Pending arouse/calm narrations about the group's actors are folded into it (`extras`).
   `FinalStageRemaining(sid)` (native) returns the final stage's timer minus its animating, unpaused seconds, or -1 outside a timed final stage. `Scene.OrgasmWindow_HoldForFinish` uses it.
5. **Mirror:** at most once a second per actor, `Effect_Mirror` → `AdjustEnjoyment(ours − SexLab's)`, so SexLab voices and expressions follow our value.

**Firing an orgasm:**
- The engine sets `enjoyment = 0` and counts the orgasm for each group member, then dispatches `Effect_OrgasmGroup(actors, forced, individual, source, allower, allowed, extras)` → `Scene.Orgasm_ApplyGroup`. `forced[i]` is 1 for a WebUI forced request. `Effect_Orgasm` remains as a one-actor wrapper.
- `Orgasm_ApplyGroup` calls `thread.ForceOrgasm` (SexLab's cum, sound and `SexLabOrgasm`) for each actor, then narrates once, following [../reference/orgasm-narration.md](../reference/orgasm-narration.md).
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

## Mini-game

`Arouse(who, target, mult)` / `Calm(who, target, mult)` are shared by the HUD keys (`mult` 1; also LMB calm / RMB arouse when `sexlab.minigame.mouse` is on), the LLM actions `SexLab_Arouse` / `SexLab_Calm` (`mult` = `sexlab.minigame.llm_multiplier`) and the plugin API. A HUD press targets the focus actor; with Shift held (`Hud::ShiftHeld`, the game's keyboard `curState`) it targets the next actor in the list instead, wrapping, and the focus stays. The HUD gets that row as `shiftTarget` and marks it `⇧`.

| | Effect |
|---|---|
| Arouse | Costs `who`'s stamina: `stamina_cost × 10/(10+skill)`. Adds `arouse_amount × mult × (1 + 0.1 × skill)`. |
| Calm | Costs `who`'s magicka: `magicka_cost × (1 + 0.05 × lewd)`. Removes `calm_amount × mult`, but never below 0. If the target was at 90 or more, it **edges**: no orgasm test for `edge_seconds`. |
| Mental break (`sexlab.minigame.mental_break`) | Arousing someone else drains the target's magicka by `break_drain × enjoyment/100 × (1 + 0.1 × skill) × (1 + orgasms)`. At 10% magicka or less the target is broken and cannot calm; it recovers above 25%. |
| Skill / lewd | `skill` is SexLab's skill level for the act, picked by animation tag (Vaginal, Anal, Oral, else Foreplay). `lewd` is lewd level − pure level. Both are sent by the Scene script at start, on each stage and on an animation change. |

**Narration**
- Acting on someone else is narrated as `"<A> arouses <B>, pushing them closer to orgasm."` or `"<A> calms <B>, keeping them further from orgasm."`.
- Presses are coalesced per (who, target, action) inside `narrate_window`.
- It is sent through `Effect_Narrate`, as is the HUD faster/slower narration (`sexlab_speed`). All of these are optional, and this includes scenes with the player:
  - They go through `DirectNarration_Optional`, which sends a `DirectNarration` only when `NarrationCoolOffAllows` (the speech queue is empty and the cooldown, last-audio and distance checks pass).
  - Otherwise it falls back to `RegisterEvent`, so nothing is dropped.
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
bool IsMentallyBroken(Actor)   bool IsMiniGameEnabled()
SetRates(float passive, float aggressor, float victim)   ; role multipliers, runtime override until the next config save
bool SetStrategy(Actor, int strategy, Actor target)  int GetStrategy(Actor)   ; mini-game NPC strategies (ids in the shell); narrated
String GetStrategyText(Actor)   Actor GetForcedBy(Actor)   int StrategyId(String key)
```

The shell-only natives (`BeginScene`, `SetStage`, `SetStageTimers`, `SetScenePaused`, `GateNarrationSent`, `SetEndingTarget`, `SetSceneBlocked`, `SetDomSlave`, `SetDomMeter`, `SetActorSkills`, `EndScene`, `ResetSpeedScale`, `ReloadConfig`, `AllowOrgasm`) are for this mod's own Scene and MCM scripts. `AllowOrgasm` is not in the C++ API.

## ModEvents

`sender` is the affected actor, and `strArg` is `"<source>|<acting actor FormID>"`.

| Event | numArg |
|-------|--------|
| `SkyrimNet_SexLab_Orgasm` | orgasm count this scene |
| `SkyrimNet_SexLab_OrgasmDenied` | orgasm count |
| `SkyrimNet_SexLab_Edge` | edge seconds |
| `SkyrimNet_SexLab_MentalBreak` | 1 broken / 0 recovered |

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
- **Aggressor ends:** an NPC lead in an aggressive scene (`thread.IsAggressive`, lead not a victim) reaching the target at any stage holds the current stage (`Ending_Hold`, `ending_end_after`). `Ending_Poll`'s release then calls `thread.EndAnimation()` instead of releasing the timer, even with `dialogue_hold_max` 0 (ends at the first poll).
- **Dialogue hold:** on the final stage's `StageStart` (`Ending_StageStart` → `Ending_Hold`) the stage is held with `thread.UpdateTimer(PAUSE_HOLD_SECONDS)`, as the pause key does. `Ending_Poll` (shares `OnUpdate` with the orgasm window, 1 s) releases when the orgasm window is closed, `SkyrimNetApi.GetSpeechQueueSize() == 0`, and `GetTimeSinceLastAudioEnded()` shows audio ended at least 1 s after the narration (min 3 s), or at `dialogue_hold_max` (45 s; 0 = no hold). Release pulls the timer back by the held time, so the final stage then plays its remaining time. While the pause key holds the stage the timer is left to the pause.

## Sex is hard work (stamina regen)

**Disabled for now** (0.35.2): the `sexlab.stamina.*` settings are removed from the manifest and no longer read, and `staminaFatigue` defaults off, so `GetStaminaRegen` returns 100 and nothing below happens. The code is kept for later; the defaults below are the struct defaults.

`sexlab.stamina.fatigue`. Each actor has `regen`, 100 → -10 (`kRegenFloor`) percent of its default stamina regen, tracked per actor:

- The tick subtracts the scene's `regenRate` = `(100 − sexlab.stamina.regen_at_orgasm) / targetSecs` points per second (`ApplyStageTimers`; default 45 at the orgasm point, so an orgasm's cost leaves a Mutual NPC tired near 35). Scenes without stage timers use `sexlab.stamina.regen_decay` points per minute (40). This happens while the scene is animating and not paused. While no actor in the scene expects orgasm, an actor loses nothing until their enjoyment reaches 50. `regenRate` is not saved: the co-save load rebuilds it from the saved timers.
- Crossing a fatigue stage sends one DirectNarration: below 90 "<name> is breathing hard.", 40 or less "is tired.", 0 or less "is exhausted." (`SpendRegen`; regen only falls, so a reload does not repeat it).
- Each orgasm subtracts `sexlab.stamina.orgasm_cost` points (10).
- The tick takes back the decayed share as stamina damage: `MaxStamina × base StaminaRate × base StaminaRateMult × (1 − regen/100) × dt`. It uses base values, so potions and buffs add on top. At full stamina only the negative share (`−regen/100`, regen below 0) drains. No damage is applied in combat. No actor value modifier is left behind.
- A non-victim (player or NPC) reaching regen -10 ends the scene once: `Effect_Exhausted` → `Scene_Manager.EndExhausted` → `Scene.AnimationEnd`. That actor's end sentence is "is too tired to continue." Victims stay at -10.
- Native `GetStaminaRegen` (can be negative). The Scene writes position obj `stamina_regen`. The end DN and 0550 use the same tiers on the int: ≥ 90 nothing, < 90 "breathing hard", ≤ 40 "tired", ≤ 0 "exhausted".
