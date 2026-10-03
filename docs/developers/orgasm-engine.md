# OrgasmEngine

The C++ OrgasmEngine owns enjoyment and orgasms for **every** SexLab scene, including NPC-only scenes. SexLab's own trigger is switched off (`thread.DisableAllOrgasms(true)`), and SLSO is not used.

## Who does what

| Layer | Role |
|-------|------|
| `SKSE_Source/src/OrgasmEngine.cpp` | Holds the state: enjoyment (0–100), passive gain, mini-game, gates, when an orgasm fires, co-save record `'ORGE'`. Runs a 250 ms tick on the game thread; the tick is skipped while the game is paused. |
| `SKSE_Source/src/Hud.cpp` + `PrismaUI/views/SkyrimNet_SexLab/hud.html` | Scene HUD: a second PrismaUI view that is shown but never focused, so the game keeps running. HUD key handling. |
| `Scripts/Source/SkyrimNet_SexLab_OrgasmEngine.psc` | **Shell only.** Native API declarations, plus the `Effect_*` globals the engine dispatches for SexLab side effects. |
| `SkyrimNet_SexLab_Scene.psc` | Adapter. Sends scene facts into the engine (`Engine_BeginScene`, `Engine_SetStage`, `Engine_SetSkills`, `SetOrgasmDisabled`, `EndScene`). Performs `Orgasm_ApplyGroup` (ForceOrgasm per actor + one narration), `SetDenyOrgasm` (deny / allow) and `Mirror_Apply` (AdjustEnjoyment). |

## Tick

For each managed scene:

1. **Passive gain:** `enjoyment += baseRate × roleMult × jitter × Π rate modifiers × anim speed × dt`.
   - **Base rate, from the stage timers.** `Engine_SetStage` sends `SetStageTimers(sid, stageSecs, leadIn)` with each stage's seconds, using `sslThreadController.GetTimer`'s rule: `Animation.GetTimer(s)` when `Animation.HasTimer(s)`, otherwise `thread.Timers`.
     - `targetSecs` = the sum of stages 1..N−1, plus 0.9 × the final stage.
     - `baseRate = 100 / targetSecs`. It is fixed per animation, and enjoyment carries over when the animation changes.
     - LeadIn: `targetSecs` = all stages × 1.5, so no one reaches 100.
     - No timers: a flat 0.5/s.
   - **The rate is fixed; it is not "remaining ÷ time left".** Extra time adds enjoyment: repeating a stage or a slow narration (a paused stage adds none). Real scenes usually run 2–3× their stage timers, which is why the default multipliers are well below 1.0.
   - **`roleMult`:** `sexlab.enjoyment.passive_mult` (0.4), `aggressor_mult` (0.45) or `victim_mult` (0.3).
   - **`jitter`:** rolled per actor at `BeginScene`, uniform in [`jitter_min`, `jitter_max`] (0.95–1.1).
   - **Anim speed:** `AnimSpeed::Get`, which is the style speed multiplied by the HUD's faster/slower scale.
   - **Not expected to orgasm:** positions with AnimDB `orgasm_expected` 0, or the scene's `no_orgasm` 1, get no passive gain. Not expected is **not** a block: orgasm checks run as normal. `Scene.ApplySexLabVoice` keeps SexLab silent below 50 enjoyment (`VOICE_GATE_ENJOYMENT`, re-checked in `Mirror_Apply`). The only scene block (`SetSceneBlocked`) is the player's `deny_orgasm` (HUD `sexlab.hud.key_deny` → `Menu.Hud_OnKey("deny", focus)` → `Scene.ToggleDenyOrgasm`; Description Editor `_deny_pos`). Positions with AnimDB `orgasm_expected` 0 get no passive gain (DOM slaves: no `domProgress`). `Engine_SetSkills` sends `SetOrgasmExpected(actor, expected)` at start and on each animation change; missing data counts as expected. Mini-game Arouse / Calm still move their enjoyment, and the no-timer safety net still needs 90 for them.
   - Expected results at normal speed with no mini-game:
     - A normal actor usually stays below 100; the gate before the final stage decides the orgasm (chance = enjoyment %).
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
3. **Gate (`sexlab.ending.gate`, timed scenes, never in LeadIn):** at 90% of the second-to-last stage's timer (animating, unpaused time), or on reaching the final stage first, each actor who has not orgasmed in this scene, is expected to orgasm and passes `CanOrgasmNow` rolls once: `uniform(0, 100) < enjoyment`. Passes fire as `source=gate` (individual). If anyone passed while still in the second-to-last stage, `Effect_AdvanceToFinal` → `Scene.Engine_AdvanceToFinal` jumps to the final stage and arms the dialogue hold (see [Scene ending](#scene-ending)). All fail: SexLab advances normally, no orgasm.

   **Safety net (gate off, or no timers):** at 90% of the final stage's timer, each non-DOM actor at 90 or more who has not orgasmed, is not blocked or edging and was not calmed in the final stage fires as *combined*. With no timers it fires on entering the final stage, everyone when the mini-game is off.
4. **Group (`JoinGroup`):** everyone fired in this scene in this tick (steps 2 and 3, forced included) is one group. Every other actor joins it when all of these hold:
   - not a DOM slave,
   - not blocked,
   - not edging,
   - not cooling down,
   - enjoyment ≥ `sexlab.enjoyment.group_join` (default 95).

   The group is sent as one `Effect_OrgasmGroup`, so it gets one narration. It is `individual` unless every trigger came from the safety net. Pending arouse/calm narrations about the group's actors are folded into it (`extras`).
5. **Mirror:** at most once a second per actor, `Effect_Mirror` → `AdjustEnjoyment(ours − SexLab's)`, so SexLab voices and expressions follow our value.

**Firing an orgasm:**
- The engine sets `enjoyment = 0` and counts the orgasm for each group member, then dispatches `Effect_OrgasmGroup(actors, forced, individual, source, allower, allowed, extras)` → `Scene.Orgasm_ApplyGroup`. `forced[i]` is 1 for a WebUI forced request. `Effect_Orgasm` remains as a one-actor wrapper.
- `Orgasm_ApplyGroup` calls `thread.ForceOrgasm` (SexLab's cum, sound and `SexLabOrgasm`) for each actor, then narrates once, following [../reference/orgasm-narration.md](../reference/orgasm-narration.md).
- **Allow:** `AllowOrgasm(actor, allower)` (deny 1 → 0) does the following under one lock, so the tick can't fire first without the prefix:
  - clears the scene block,
  - fires every actor in the scene who can orgasm and is at 100,
  - runs the group join,
  - tags the group with `allower` / `allowed`, which gives the `"<allower> allows <actor> to orgasm. "` prefix.

  It returns whether anyone fired.
- **External orgasms** (`NoteExternalOrgasm`) run the group join too. The joiners go out as a non-individual group (stash + window), while the caller narrates the external actor, so both share one DN.
- `Scene_Manager.OrgasmIndividual` ignores `SexLabOrgasm` for managed actors, so an orgasm is never narrated twice.

**Thread hooks** are sent at SexLab's timing, not per orgasm:
- `Scene.Engine_SetStage` sends `OrgasmStart` once, on entering the final stage of a non-LeadIn animation.
- It sends `OrgasmEnd` on leaving that stage, or at `AnimationEnd` if the hook is still open.
- An early orgasm therefore does not use up DOM's once-per-scene hook roll.

## Pause

- The HUD key `sexlab.hud.key_pause` (default Home) goes through `Menu.Hud_OnKey("pause")` to `Scene.TogglePause`.
- `StageTimer` and `TimedStage` are private to `sslThreadController`, so the Scene uses its public functions instead:
  - **Pause:** `thread.UpdateTimer(100000)` pushes the stage's timer far out.
  - **Resume:** `thread.UpdateTimer(held − 100000)` puts back the remaining time, then `thread.ResolveTimers()` restores `TimedStage = Animation.HasTimer(Stage)`.
- `StageStart` re-applies the hold while paused, because `GoToStage` resets the timer. It is applied once per (animation, stage). Manual previous/next still work.
- `SetScenePaused` tells the engine. That drives the HUD's "Paused" tag and its **pause**/**resume** label, stops the safety-net clock and stops passive gain.

## Mini-game

`Arouse(who, target, mult)` / `Calm(who, target, mult)` are shared by the HUD keys (`mult` 1), the LLM actions `SexLab_Arouse` / `SexLab_Calm` (`mult` = `sexlab.minigame.llm_multiplier`) and the plugin API.

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
```

The shell-only natives (`BeginScene`, `SetStage`, `SetStageTimers`, `SetScenePaused`, `SetSceneBlocked`, `SetDomSlave`, `SetDomMeter`, `SetActorSkills`, `EndScene`, `ResetSpeedScale`, `ReloadConfig`, `AllowOrgasm`) are for this mod's own Scene and MCM scripts. `AllowOrgasm` is not in the C++ API.

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

`IOrgasmEngineV1` mirrors the Papyrus API and adds event callbacks. Calls are thread-safe. The export is `RequestOrgasmEngineAPI(InterfaceVersion)`.

## Persistence

- The co-save record `'ORGE'` (version 3) holds:
  - per scene: stage, stage timers, LeadIn, pause and the final-stage clock;
  - per actor: enjoyment, orgasm count, role, skill, jitter, blocks, rate modifiers and DOM step state.
- Versions 1 and 2 still load; their scenes use the fallback rate until the next stage.
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

## Scene ending

`Scene.psc` `Ending_*` (settings `sexlab.ending.*`):

- **Target:** `Ending_RollTarget` (from `Engine_BeginScene`, once per scene) picks the lead: `initiator` (`PickNonVictimInitiator` makes it the aggressor when there is a victim), else position 0. Target = `RandomInt(target_male_min, target_male_max)` for SexLab gender 0, else the female range. 0 = never jumps.
- **Jump:** `Ending_Check` (end of `Orgasm_ApplyGroup`) compares `OrgasmEngine.GetOrgasmCount(lead)` with the target; reaching it calls `Ending_ToFinal` → `thread.GoToStage(final)`. The gate's `Engine_AdvanceToFinal` does the same. Once per scene (`ending_done`), never in LeadIn.
- **Dialogue hold:** on the final stage's `StageStart` (`Ending_StageStart` → `Ending_Hold`) the stage is held with `thread.UpdateTimer(PAUSE_HOLD_SECONDS)`, as the pause key does. `Ending_Poll` (shares `OnUpdate` with the orgasm window, 1 s) releases when the orgasm window is closed, `SkyrimNetApi.GetSpeechQueueSize() == 0`, and `GetTimeSinceLastAudioEnded()` shows audio ended at least 1 s after the narration (min 3 s), or at `dialogue_hold_max` (45 s; 0 = no hold). Release pulls the timer back by the held time, so the final stage then plays its remaining time. While the pause key holds the stage the timer is left to the pause.

