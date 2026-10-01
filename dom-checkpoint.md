# DOM / OrgasmEngine checkpoint: SexLab-like outcome without the mini-game

Status: **implemented, compiled (Pyro + DLL), not yet tested in game.** Branch `skse-scene`, 2026-09-29.

Deviations from the design below:
- **Pause:** `StageTimer` / `TimedStage` are private in `sslThreadController`. Pause uses `thread.UpdateTimer(100000)`; resume uses `UpdateTimer(held − 100000)` + `ResolveTimers()`. `AutoAdvance` is not touched.
- **Config keys renamed:** `sexlab.enjoyment.passive_mult` / `aggressor_mult` / `victim_mult`, so saved `*_rate` values (0.5/0.7/0.2) aren't misread as multipliers.
- **DOM debt** is kept in Papyrus (StorageUtil `skyrimnet_sexlab_dom_debt` on the actor), not in the engine.
- **`Effect_DomSync`** also carries the mini-game delta: `(actor, miniDelta, daring, naivety, share, prepay, hasPlayer)`.
- **No stage timers:** the safety net fires on entering the final stage. With the mini-game off it fires everyone (the old rule); with it on, only actors at 90 or more.
- **DOM headers:** the missing members were added to `SkyrimNet_DOM/Headers_Source/DOM/`, and a `DOM_Diary.psc` stub was created.

## Goal
If nobody uses a mini-game action (Arouse / Calm, from the HUD or the LLM), a scene should end much like a plain SexLab scene:
- **Non-DOM actors:** an expected actor normally orgasms once, near the end of the scene. Some orgasm a little earlier. A victim usually does not.
- **DOM slaves:** arousal grows by the same total as in a vanilla DOM scene, but spread over the animation. DOM decides the orgasm, as usual. A new slave will not orgasm at first. `arousal_factor` carries across scenes, so the slave becomes more orgasmic over time. That is expected, and the engine does not correct for it.

Players and actors can change the outcome on purpose:
- **Speed:** faster or slower changes the rate of gain.
- **Time:** repeating a stage, or pausing on the current stage, adds gain.
- **Mini-game:** Arouse / Calm deny or add orgasms.

## Facts established (verified in source)
- **DOM always rolls once per scene.**
  - It hooks `HookOrgasmStart_DOM<id>ORGASM` and `HookAnimationEnd_DOM<id>END` in `handleSexEvent` ([DOM_Mind.psc:10000-10011](extern/Source_DOM/DOM_Mind.psc#L10000-L10011)).
  - If the orgasm hook never fired, `handleSexEndEvent` calls `handleSexOrgasm` at AnimationEnd ([DOM_Mind.psc:10436-10438](extern/Source_DOM/DOM_Mind.psc#L10436-L10438)).
  - `SexLabOrgasmSeparate` only comes from SLSO, which is not used.
- **SexLab's hook timing:** SexLab sends `OrgasmStart` once, on entering the final stage of a non-LeadIn animation ([sslThreadController.psc:162-165](extern/Source_SexLab/sslThreadController.psc#L162-L165)), and `OrgasmEnd` when leaving it (line 197). Individual (separate) orgasms never send it.
- **Our current hook timing differs:** `Scene.Orgasm_Apply` sends `OrgasmStart` for every engine orgasm ([Scene.psc:1495-1498](Scripts/Source/SkyrimNet_SexLab_Scene.psc#L1495-L1498)). A partner's early orgasm therefore uses up DOM's hook roll early.
- **Current DOM handling is too generous:**
  - Passive gain goes to DOM as `IncreaseArousal`.
  - Any positive delta rolls a full `mind.handleSexOrgasm`, about once a second ([OrgasmEngine.cpp:542-575](SKSE_Source/src/OrgasmEngine.cpp#L542-L575), [OrgasmEngine.psc:80-94](Scripts/Source/SkyrimNet_SexLab_OrgasmEngine.psc#L80-L94)).
  - Each call repeats `HasFlingWith`, praise reasons and the player-scene +20 arousal.
- **Current final-stage auto-fire** only runs with the mini-game off ([OrgasmEngine.cpp:624](SKSE_Source/src/OrgasmEngine.cpp#L624)), and it skips DOM slaves.
- **Stage advance:** SexLab advances when `(AutoAdvance || TimedStage) && StageTimer < now` ([sslThreadController.psc:182](extern/Source_SexLab/sslThreadController.psc#L182)). `GetTimer()` rule: [sslThreadController.psc:802-815](extern/Source_SexLab/sslThreadController.psc#L802-L815).

### DOM arousal per SexLab scene (vanilla)
`IncreaseArousal(amount, reason)` applies ([DOM_Mind.psc:9611-9631](extern/Source_DOM/DOM_Mind.psc#L9611-L9631)):

```
value = amount × (FACET_Sensuality/200 + 0.5 + reason/10) × DOM01.train_speed_arousal (default 0.5) × trainer_mod
trainer_mod = sex_is_non_consensual ? DOM01.GetPredatorModifier(trainer) : DOM01.GetDeceiverModifier(trainer)
male && enraptured → value / 10
```

| When | Call | Amount |
|---|---|---|
| Scene start (`handleSexStart`, line 10100) | `IncreaseArousal(20, MOD_Daring)` | 20, every scene |
| Same-sex tagged, real same-sex (line 10184/10188) | `MOD_Daring` | 20 the first time, then 10 |
| First oral / vaginal / anal / gang (lines 10141-10176) | act MOD | 20 or 10, once per lifetime |
| Orgasm roll with the player (`handleSexOrgasm`, line 10264) | `IncreaseArousal(20, MOD_Naivety)` | 20, player scenes only |
| Virginity taken by the player (lines 10292-10345) | act MOD | 10, once per lifetime |
| Scene end: known kink matched (`DiscoverHiddenKink`, line 18835) | `MOD_Ingenuity × w` | 10 × `arousal_speed_kink`, situational |
| Ongoing (`HandleArousalOnUpdate`, line 9580) | decay | −0.002 × (100 − Sens) per second |

**Recurring total per scene:** 20 (`MOD_Daring`) for NPC scenes, plus 20 (`MOD_Naivety`) for player scenes. One-time and situational items stay with DOM.

**Scalar:** amount per engine progress point (engine progress runs 0→100 over a normal scene):
- `MOD_Daring` part: **0.2** / point (20 total);
- `MOD_Naivety` part (player scenes): **+0.2** / point (20 total).

---

## Design

### 1. Passive rate from the scene's stage timers (non-DOM and DOM progress)
- **Scene script:** at `Engine_BeginScene` and on animation change, build `float[] stageSecs` with SexLab's `GetTimer()` rule:
  - use `Animation.GetTimer(s)` when `Animation.HasTimer(s)`;
  - otherwise use `thread.Timers[s-1]` for early stages, `Timers[last]` for the final stage, and `Timers[last-1]` in between.
  - Send it with a new native, `SetStageTimers(sid, stageSecs, leadIn)`.
- **Engine target:** `targetSecs` = the sum of stages 1..N-1, plus 0.9 × the final stage. `baseRate = 100 / targetSecs` is fixed per animation. Enjoyment carries over on an animation change.
- **Actor rate:** `baseRate × roleMult × jitter × Π rateMods × AnimSpeed`.
  - `roleMult` defaults: normal 1.0, aggressor 1.15, **victim 0.8**. The existing keys `passive_rate` / `aggressor_rate` / `victim_rate` become multipliers.
  - `jitter` is rolled per actor at BeginScene, uniform in [0.95, 1.2] (`sexlab.enjoyment.jitter_min/max`).
- **Fixed rate:** the rate is not "remaining ÷ time left". Extra time from pausing or repeating a stage adds enjoyment, so the actor orgasms earlier or more than once. Speed scales it through `AnimSpeed`.
- **Fallback:** if there are no timers, use the old absolute rate of 0.5/s.
- **LeadIn:** `targetSecs` = all stages × 1.5, so actors never reach 100. There is no safety net and no `OrgasmStart`.

### 2. End-of-scene safety net (non-DOM)
Replaces step 4 at [OrgasmEngine.cpp:623-633](SKSE_Source/src/OrgasmEngine.cpp#L623-L633).
- Runs with the mini-game on or off, and not for LeadIn.
- At 90% of the final stage's timer, counting only animating, unpaused time, fire each non-DOM actor that has:
  - `orgasmCount == 0`,
  - **enjoyment ≥ 90**,
  - no `AnyBlock`,
  - no edging, and
  - no Calm during the final stage (`lastCalmAt < finalStageAt`).
- Below 90, the actor does not orgasm. This is the natural miss for a victim.

**Expected results at normal speed:**
- A normal actor reaches 95–120, so all orgasm: 1.0 × jitter ≥ 0.95. Those with jitter above 1.0 orgasm before the safety point.
- A victim reaches 76–96 (0.8 × jitter). About 30% reach 90 and orgasm (jitter ≥ 1.125); the rest don't.

### 3. Pause / resume hotkey
- **HUD key:** `{ "pause", "sexlab.hud.key_pause", VK_PAUSE, false }` in `kBindings` ([Hud.cpp:34](SKSE_Source/src/Hud.cpp#L34)). It uses `DispatchMenuKey`. `Menu.Hud_OnKey` maps `"pause"` → `Scene.TogglePause()` ([Menu.psc:137](Scripts/Source/SkyrimNet_SexLab_Menu.psc#L137)).
- **Pause:**
  - save `thread.AutoAdvance`;
  - save `remaining = thread.StageTimer - SexLabUtil.GetCurrentGameRealTime()`;
  - set `thread.AutoAdvance = false` and `thread.TimedStage = false`.
- **Resume:**
  - restore `AutoAdvance`;
  - set `TimedStage = Animation.HasTimer(Stage)`;
  - set `StageTimer = now + remaining`.
- **Keep it applied:** re-apply the pause on each StageStart while paused, because `GoToStage` / `ResolveTimers` reset `TimedStage`. Clear it on AnimationEnd. Manual previous/next still work.
- **Engine:** native `SetScenePaused(sid, bool)`, used for the HUD label and the safety-net clock. Passive gain keeps running while paused.
- **HUD:** the JSON gains `paused`. `hud.html` shows the key label as **Pause** or **Resume**, and a "Paused" tag.

### 4. DOM slaves: vanilla total, spread over the animation (the "Replace" option)
- **Progress:** the slave's passive curve (section 1) feeds `domProgress` 0→100. The existing DOM meter stays on the HUD.
- **Steps:** push to DOM in steps of `kDomStep` = 10 progress points, about 10 pushes per scene.
  - Each step calls `IncreaseArousal(10 × 0.2, MOD_Daring)`.
  - In player scenes it also calls `IncreaseArousal(10 × 0.2, MOD_Naivety)`.
  - Scalars: `sexlab.dom.arousal_scale` 0.2 and `sexlab.dom.arousal_scale_player` 0.2.
- **Mini-game:** Arouse / Calm still push immediately. Calm lowers `arousal_factor`, as today.
- **Cancel DOM's own recurring adds (prepay):**
  - On the first DOM sync of the scene, subtract `DomArousalValue(mind, 20, MOD_Daring)` from `arousal_factor`, plus `DomArousalValue(mind, 20, MOD_Naivety)` in player scenes.
  - DOM adds these itself at start and at its roll. The net per scene is then the spread-out total only.
  - If the subtraction would drop `arousal_factor` below 0, keep the remainder as `domDebt` and take it off later step pushes.
  - `DomArousalValue` in `Handler_DOM` copies the formula above. The fields it reads are properties: `FACET_Sensuality`, `MOD_Daring`, `MOD_Naivety`, `DOM01.train_speed_arousal`, `DOM01.GetPredatorModifier` / `GetDeceiverModifier(actor_alias.GetCurrentSexTrainer())`, `sex_is_non_consensual`, `is_enraptured_for`.
  - One-time virginity, same-sex and kink adds are not cancelled.
- **Roll each time arousal increases:** after every positive push, call `Handler_DOM.StepRoll(actor, hasPlayer, share)`. It is a light roll, not `handleSexOrgasm`:
  1. `mind.IsArousedAfterSex(mind.MOD_Daring)`.
  2. If `CouldOrgasm`, call `mind.IsOrgasmingAfterArousal(actBase × share)`.
     - `actBase` is the best `MOD_Vaginal` / `MOD_Anal` / `MOD_Oral` for the acts played.
     - `share` = 0.1 for a passive step, or `arouse_amount × mult / 100` for Arouse.
     - Below 0.5 the DOM chance is linear in `base_chance`, so about 10 rolls at 1/10 add up to roughly one normal roll.
  3. On success, do what `handleSexOrgasm` does: `actor_alias.SendExternalEventSS("Orgasm", "sex"|"rape"|"masturbate")` and `DOM01.DOM04.NotifyOrgasm(...)`. The melt comes back through `DOMSlave_Orgasmed` → `NoteExternalOrgasm`, unchanged.
  - Gates are unchanged: blocks, edging and cooldown suppress the step roll. `OrgasmCustom` still drops the melt narration when the slave is not expected.
  - Known bias: DOM's male `×2 + 0.1` and its additive bonuses apply to each step.
- **DOM's own roll is kept:** DOM still makes its one full `handleSexOrgasm` from the hook (section 5), or at AnimationEnd.

### 5. Thread hooks at SexLab's timing
- **`Scene.Engine_SetStage`**, before `OrgasmEngine.SetStage`:
  - on entering a final, non-LeadIn stage: `SendThreadEvent("OrgasmStart")`, then set `orgasm_hook_open`;
  - on leaving the final stage: send `OrgasmEnd`.
- **`AnimationEnd`:** send `OrgasmEnd` if the hook is open.
- **`Orgasm_Apply`:** remove the `send_hooks` block.
- **Reset** `orgasm_hook_open` with `orgasm_window_open` at scene init.

## Files
- **`SKSE_Source/src/OrgasmEngine.cpp`, `include/OrgasmEngine.h`:**
  - scene: `stageSecs`, `targetSecs`, `baseRate`, `finalStageAt`, `paused`, `leadIn`;
  - actor: `jitter`, `lastCalmAt`, `domProgress`, step accumulator, `domDebt`, `domPrepaid`;
  - safety net;
  - co-save version 3.
- **`SKSE_Source/src/Papyrus_OrgasmEngine.cpp`, `Scripts/Source/SkyrimNet_SexLab_OrgasmEngine.psc`:**
  - `SetStageTimers` and `SetScenePaused`;
  - `Effect_DomSync(actor, daringAmt, naivetyAmt, share, prepay, hasPlayer)`.
- **`Scripts/Source/SkyrimNet_SexLab_Handler_DOM.psc`, `_Interface.psc`:** `DomArousalValue`, `StepRoll`, prepay.
- **`Scripts/Source/SkyrimNet_SexLab_Scene.psc`:** timers, `TogglePause`, hook timing, `Orgasm_Apply`.
- **`Scripts/Source/SkyrimNet_SexLab_Menu.psc`:** `"pause"`.
- **`SKSE_Source/src/Hud.cpp`, `PrismaUI/views/SkyrimNet_SexLab/hud.html`:** pause key and label.
- **Config** (`Config.cpp`, `manifest.yaml`):
  - `sexlab.enjoyment.jitter_min/max`;
  - `sexlab.dom.arousal_scale`, `sexlab.dom.arousal_scale_player`;
  - `sexlab.hud.key_pause`;
  - the role multipliers.
- **Docs:**
  - `docs/developers/orgasm-engine.md`;
  - `docs/players/hotkeys.md`;
  - `docs/reference/orgasm-narration.md`;
  - `KNOWLEDGEBASE.md`: the "Thread hooks kept" entry, plus new entries on "DOM always rolls at AnimationEnd" and the timed rate.

## Verification
- `compile: pyro` on the changed scripts, and build the DLL.
- In game, mini-game on but unused, watching the WebUI log (`OrgasmEngine:`, including `baseRate` / `targetSecs`) and the Papyrus trace:
  1. Two non-DOM actors: both orgasm near the end, and there is one `OrgasmStart` at the final stage.
  2. Victim: over about 10 scenes, roughly 30% orgasm.
  3. Faster ×2: an earlier orgasm, and a second one is possible. Slower: below 90 at the safety point, so no orgasm.
  4. Pause: the stage holds, the HUD shows **Resume**, and enjoyment keeps rising. Resume continues the remaining stage time.
  5. Player + DOM slave:
     - about 10 `dom step` lines;
     - one prepay at the start;
     - `arousal_factor` at scene end minus at start ≈ the vanilla figure (the formula value of 20 + 20);
     - a single DOM `handleSexOrgasm` at the final stage.
  6. A new DOM slave does not orgasm, and repeated scenes build `arousal_factor`.
  7. LeadIn: no orgasm and no `OrgasmStart`. Save/load mid-scene keeps the rate and jitter.
