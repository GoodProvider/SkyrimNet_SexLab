# SexLab Separate Orgasm (SLSO) — source summary

Summary of the Papyrus sources in `C:\Skyrim\dev\mods\SexLab Separate Orgasm\Scripts\Source`. It covers how the mini game works, how enjoyment is displayed and calculated, what decides whether an orgasm happens, and the hooks other mods can use.

All settings are read live from `/SLSO/Config.json` (JsonUtil), so MCM changes take effect mid-scene.

## Architecture

| Script | Role |
|---|---|
| `sslActorAlias.psc` | SLSO's **override** of SexLab's per-actor alias. Owns enjoyment math, orgasm trigger, orgasm conditions, multi-orgasm, `HoldOut`, `BonusEnjoyment`. |
| `sslThreadController.psc` | Override of SexLab's thread. Blocks the final stage until the aggressor is satisfied; min/max aggressor orgasm counts. |
| `sslBaseVoice.psc` | Override of SexLab's voice (moans driven by SLSO enjoyment). |
| `SLSO_PlayerAliasScript.psc` | Entry point. On `AnimationStart` it gives every actor three abilities (Game, Voice, AnimSync), fills widget aliases 1–5 (player scenes only), and sends `SLSO_Start_widget`. |
| `SLSO_SpellGameScript.psc` | The **mini game** (1 s tick per actor). |
| `SLSO_Widget{1-5}Update.psc` + `SLSO_WidgetCoreScript*.psc` | SkyUI meter widgets, one per actor slot. |
| `SLSO_SpellVoiceScript.psc` | Custom female voice packs, chosen by enjoyment. |
| `SLSO_SpellAnimSyncScript.psc` + `AnimSpeedHelper.psc` | Animation speed driven by stamina or enjoyment. |
| `SLSO_MCM.psc`, `SLSO_VoicePackInstallerScript.psc` | Config UI and voice pack install. |
| `SLSO_Game.psc` | Dead code. It was replaced by the spell version in v1.3.9. |

Startup flow: `AnimationStart` → the abilities are removed and re-added on each actor → `Utility.Wait(1)` → `SLSO_Start_widget(slot, threadId)` → the game, voice, animsync and widget scripts initialise, then loop every 1 s until the actor stops being in the `Animating` state or `AnimationEnd` arrives.

---

## 1. The mini game (`SLSO_SpellGameScript`)

The game runs if `game_enabled == 1` and either the scene includes the player or `game_npc_enabled == 1`. Otherwise the ability removes itself.

### Resources
The game spends two actor values:
- **Stamina** is spent to raise enjoyment (your own or your partner's).
- **Magicka** is spent to **edge** (hold back an orgasm). Magicka is also drained by the partner's pleasure, which leads to **mental break**.

### Skill modifiers (`GetMod`, clamped −6..6)
- **Stamina mod** is SexLab skill level for the act (by animation tag): Vaginal, Anal, Oral, or Foreplay/Masturbation. Range 0–6.
- **Magicka mod** is `Lewd(0.3) − Pure(0.3)`. −6 means pure, +6 means lewd.

`FullEnjoymentMOD = clamp(FullEnjoyment / 30, 1, 3)` makes actions cheaper as enjoyment rises.

### Player hotkeys (player only; many need the *utility* key held)
| Hotkey | Effect |
|---|---|
| `hotkey_bonusenjoyment` | `Game("Stamina")` raises enjoyment. It targets the **partner**, or **self** if solo or the utility key is held. Needs stamina above 10% and the actor not mentally broken. |
| `hotkey_edge` | `Game("Magicka")`. **Self**: costs magicka `base/(10−magMod)*0.5` and calls `HoldOut()` on self. **Partner**: costs stamina `base/(10+staMod)*0.5` and calls `HoldOut()` on the partner. |
| utility + `hotkey_select_actor_1..5` | `Change_Partner(n)` changes the focus partner. It sends `SLSO_Change_Partner` and the widget label turns yellow. |
| utility + `hotkey_pausegame` | Pauses or unpauses the automatic tick. |
| utility + `hotkey_widget` | Toggles widgets globally (`SLSO_PlayerAliasScript`). |

The orgasm hotkeys are commented out in the source.

### `ModEnjoyment(target, mod, FEM)`
- The actor pays stamina: `base / (10 + mod + FEM)`.
- If the skill is below 3 and `game_enjoyment_reduction_chance == 1`, there is a `(3 − mod) × 10 %` chance to give **−1** instead of +arousal-based bonus (clumsy lover).

### Automatic play (NPCs, player with `game_player_autoplay`, or mentally broken player)
Each tick, if stamina is above 10%:
- **Aggressor**
  - With relationship rank below 0 (hate sex), it pleasures self with `mod = |rank|`.
  - Otherwise it pleasures self. It pleasures the partner only when mentally broken in a 2-actor scene.
- **Not aggressor, not broken** (or more than 2 actors). The rolls run in order:
  1. If `game_pleasure_priority == 1`: self with chance `Lewd × 15 %`.
  2. Partner with chance `25 + highestRelationRank × 20 %` (2-actor scenes only).
  3. If `game_pleasure_priority == 0`: self with chance `Lewd × 15 %`.
- **Broken**: always pleasures the partner.
- **Auto edging** (`game_edging == 1`): in 2-actor scenes, with the relationship-based chance, if magicka is above 10% and own enjoyment is **above 95**, the actor pays magicka `base/(10−magMod)` and calls `HoldOut(3)`.

### Mental break
- An actor becomes `MentallyBroken` when magicka is at or below 10% (or the player is a victim with `game_victim_autoplay`). The state clears when magicka rises above 25%.
- Broken actors cannot use hotkeys (auto-play takes over), and they serve their partner.
- Whoever was pleasured takes magicka damage each tick:
  ```
  base/100 × (10 − ownStaMod + partnerMagMod/100) × partnerFullEnjoyment/100 × (1 + partnerOrgasms) × 0.5
  ```
  So good lovers, high enjoyment and repeat orgasms break the other actor faster.

### Extra per-tick effects
- **Devious Devices vibration** (`DeviceVibrateEffectStart/Stop`): each tick adds `+Vibrate` bonus enjoyment, costs stamina, and applies mental-break damage.
- **Forced** animations (tags Estrus/Machine/Slime/Ooze): each tick adds +1 bonus enjoyment, costs stamina, and applies mental-break damage.
- **Stage auto-advance**, only for solo scenes or a non-position-0 actor in a duo:
  - It advances if `game_no_sta_endanim` is on and the actor is out of stamina and not the aggressor.
  - It also advances if `game_male_orgasm_endanim` is on and a male has already orgasmed.
- **Passive decay** (`game_passive_enjoyment_reduction`): the widget loop applies −1 bonus enjoyment per second.

---

## 2. How enjoyment is displayed

### Widgets (`SLSO_Widget{N}Update`)
- There is one SkyUI meter per scene actor (slots 1–5). Widgets appear only in scenes that include the player; `widget_player_only` limits them to the player's own meter.
- The meter updates every 1 s from `GetFullEnjoyment()`:
  - The fill is `FullEnjoyment / 100`, clamped to 100%.
  - The colour is the gender base colour (`widgetcolors[4]` for male, `[5]` for female) blended toward `widgetcolors[3/2/1]` at **≥25 / ≥50 / ≥75 %**.
  - The meter **flashes** at 90% or more (throttled by real time).
- The label is the actor's name. The currently selected partner's label uses `widget_selectedactorcolor` (yellow by default).
- The optional value text `E:xx%` shows `GetFullEnjoymentMod()`, the combined multiplier (`widget_show_enjoymentmodifier`).
- Position, fill direction, alpha, scale and text size come from json (`widgetN` string list, `widget_*` keys).

### Voice (`SLSO_SpellVoiceScript`, females only, when a voice pack is selected)
- Each second a sound is chosen:
  - The enjoyment bucket is `clamp(FullEnjoyment/10, 0, 10) + 1`.
  - Above 9, it plays the **orgasm** sound.
  - For a victim below `sl_voice_painswitch`, it plays the **pain** sound.
  - Otherwise it plays the **normal** sound. With `sl_voice_enjoymentbased` and a pack of 10 sounds, the sound is indexed by the bucket.
- Voice selection:
  - For the player: `sl_voice_player`.
  - For NPCs: `sl_voice_npc`. `-2` means random, `-1` means random but not the player's voice, and `>0` is a fixed pack.
- Males and female actors with no pack fall back to SexLab voices, which also play at `ActorFullEnjoyment` strength.

### Animation speed (`SLSO_SpellAnimSyncScript`)
- `game_animation_speed_control` selects the driver. `1` is stamina-based: `clamp(sta%×100/90, min, max) + base`. `2` is enjoyment-based: `clamp(FullEnjoyment/90, min, max) + base`.
- It can sync every actor to the player or to position 0 (`..._actorsync`).

---

## 3. How enjoyment and orgasm are calculated (`sslActorAlias`)

### Base enjoyment at scene start (`PrepareActor`)
SexLab's `BaseEnjoyment` gets a random bonus based on the actor's role. `rel` is `BestRelation`, and each term is multiplied by `RandomInt(1,10)`:
- **Victim**: `(rel − 3) + clamp(ownLewd − ownPure, −6, 6)`.
- **Aggressor**: `−((rel − 4) + clamp((partnerLewd−partnerPure) − (ownLewd−ownPure), −6, 6))`.
- **Consensual**: `rel + clamp(avgLewd − avgPure, 0, 6)`.

Unskilled actors use the same terms without the lewd/pure part.

### Raw enjoyment (`SLSO_GetEnjoyment`)
- SexLab's time and stage gains are applied only if `sl_passive_enjoyment` / `sl_stage_enjoyment` is on, **or** the mini game is off for this scene.
- Skilled actors use native `CalcEnjoyment(...)` plus `BaseEnjoyment`. Unskilled actors use `clamp((t+1)/5, 0, 40) + stage/stageCount × 60`.
- The result is `FullEnjoyment − QuitEnjoyment`, floored at 0. `QuitEnjoyment` is set to `FullEnjoyment` at each orgasm, so the build-up restarts.

With the game on and passive gains off, **enjoyment comes almost entirely from `BonusEnjoyment`**, which the mini game produces.

### Full enjoyment (`CalculateFullEnjoyment`, run every actor loop)
```
S = SLSO_GetEnjoyment() + slaArousal(if sl_sla_arousal==2) + BonusEnjoyment

ActorFullEnjoyment =
  estrus anim && sl_estrusforcedenjoyment>0 ?  S × sl_estrusforcedenjoyment
  :  S × MasturbationMod / ExhibitionistMod / GenderMod × sl_enjoymentrate_{male|female} × slaArousalMod
```

| Modifier | Rule |
|---|---|
| `MasturbationMod` | Solo scenes with `sl_masturbation` only. Normal: `1 − Lewd/10`. Estrus: `1 + Lewd/10`. Clamped 0.1–2. |
| `ExhibitionistMod` | `sl_exhibitionist` 1 = counted at start, 2 = counted live. It counts NPCs within 1000 units with line of sight. An exhibitionist (SLA faction or Lewd > 5) gets `1.6 − 0.2×n`, which is a *bonus* once n > 3. Others, with n > 1 and not aggressor, get `1 + 0.2×n` (a penalty). |
| `GenderMod` | Male with `condition_male_orgasm_penalty`: `1 + 2×orgasms`, except position 0 in anal/fisting. This makes repeat male orgasms hard. |
| `sl_enjoymentrate_*` | Flat multiplier per sex. |
| `slaArousalMod` | `sl_sla_arousal == 3`: `arousal × 2 / 100`. |
| Aggressor floor | With `condition_aggressor_orgasm`, the aggressor's arousal and exhibition modifiers are floored at 1, so scenes that require an aggressor orgasm cannot stall. |

### BonusEnjoyment increments (`BonusEnjoyment(ref, fixed)`)
- If `fixed ≠ 0`, it adds `fixed` (used for −1 penalties, vibration, and `HoldOut`).
- If `fixed == 0`, it adds `clamp(slaArousal/20, 1, 5)`. The arousal term applies only when `sl_sla_arousal == 1`; otherwise the step is +1. Females with `condition_female_orgasm_bonus` get `+ orgasmCount` on top, so each orgasm makes the next come faster.
- If `ref` is another actor, the call is forwarded to that actor's alias.

### Orgasm trigger — deterministic, not a probability roll
In the actor's animating loop:
```
CalculateFullEnjoyment() >= 100
 && !NoOrgasm && SeparateOrgasms
 && (now − LastOrgasm) > (IsMale + IsCreature + 1) × 10 s     ; 10 s female, 20 s male, 30 s male creature
```
Then `DoOrgasm()` runs the checks in section 4. The **probabilistic** parts of SLSO are:
- the mini game's per-tick rolls (who gets pleasured, clumsy −1, auto-edging);
- the victim lewdness check (section 4);
- the multi-orgasm roll (section 5);
- the chance to raise the aggressor's orgasm requirement (section 6).

The widget's "orgasm probability" is therefore effectively *distance to 100*, divided by the tick rate (about +1–5 per pleasure tick, with modifiers).

### Edging (`HoldOut(x)`)
`HoldOut` pushes `LastOrgasm` to about `now − 8 + skill + x`, which re-arms the cooldown. It also subtracts bonus enjoyment:
- position 0, vaginal/anal act: `−(1 + skill)`;
- otherwise: −1.

### Forcing an orgasm (`Orgasm(experience)`)
- `-2` forces an orgasm, skipping every SLSO check.
- Otherwise it fires only if full enjoyment is at least 90 and the cooldown has passed. `-1` resets the cooldown first.

---

## 4. Orgasm conditions (`SLSO_DoOrgasm_Conditions`)

These checks apply to non-forced orgasms. A negative result blocks the orgasm and is logged. Most checks are skipped for **Estrus**-tagged animations.

| Code | Blocked when |
|---|---|
| −1 | Lead-in / foreplay stage and `condition_leadin_orgasm == 0` |
| −2 | Player and `condition_player_orgasm == 0` |
| −3 | Wearing a DD belt and `condition_ddbelt_orgasm == 0` |
| −4 | Victim and `condition_victim_orgasm == 0` |
| −5 | Victim, `condition_victim_orgasm == 2`, and the lewd check fails (pass chance ≈ `Lewd × 10 %`) |
| −6 | Female at position 0 with `condition_female_orgasm`, and the animation has none of Vaginal/Anal/Cunnilingus/Fisting/Lesbian |
| −7 / −8 | Male with `condition_male_orgasm`. At position 0 the animation needs Anal/Fisting. At other positions it needs Vaginal/Anal/Boobjob/Blowjob/Handjob/Footjob |
| −11 / −12 | Futa (or gender swap) with `condition_futa_orgasm`, using the same rules as female and male respectively |
| −9 / −10 | `StorageUtil` int `slso_forbid_orgasm == 1` on the actor. Code −10 also sends **`SexLabOrgasmSeparateDenied(actor, tid)`** |

The gender/position rules are skipped for aggressors, and for 69/Masturbation animations with more than 2 positions.

---

## 5. After an orgasm (`DoOrgasm` → `SLSO_DoOrgasm_Multiorgasm`)
- The orgasm count goes up by 1, and `QuitEnjoyment = FullEnjoyment` so the build-up restarts.
- For a male with the penalty setting, `GenderMod` is recalculated as `1 + 2×orgasms`.
- **Multi-orgasm** (females only):
  ```
  if RandomInt(0,100) > sl_multiorgasmchance + Lewd × sl_multiorgasmchance_curve − 10 × orgasms  (or not female)
      normal orgasm: BaseEnjoyment re-rolled (role formula, ×RandomInt(5,10)), BonusEnjoyment = 0
  else
      multi-orgasm: bonus kept, cooldown nearly reset (LastOrgasm = now − 9)
  ```
- Events sent:
  - `SexLabOrgasm(actor, FullEnjoyment, Orgasms)`, SexLab's standard event;
  - **`SexLabOrgasmSeparate(actor, tid)`**.
- Moans and the orgasm sound effect play.
- The player's orgasm count carries into the next scene if it starts within **1 game hour** (`SLSO_PlayerAliasScript`).
- The scene-end forced orgasm is skipped when separate orgasms are on, unless `sl_default_always_orgasm` is set, or `sl_npcscene_always_orgasm` is set for NPC-only scenes.

---

## 6. Aggressor satisfaction (`sslThreadController.SLSO_Animating_GoToStage`)
In scenes with the player, when the thread tries to go past the second-to-last stage:
- Consider each aggressor that has `condition_aggressor_orgasm` (NPC) or `condition_player_aggressor_orgasm` (player). Creatures count only if the game is enabled.
- If that aggressor has fewer orgasms than the **minimum** (`condition_minimum_aggressor_orgasm`, or 1 if the game is off) and is allowed to orgasm, the thread **jumps back to a random middle stage**. With `condition_aggressor_change_animation`, it changes animation instead (NPC aggressors only).
- A DD-belted aggressor with belt orgasms disabled lets the scene end.
- After each aggressor orgasm that reaches the minimum, there is a `condition_chance_minimum_aggressor_orgasm_increase` % chance to raise the minimum by 1, up to `condition_maximum_aggressor_orgasm`. This also applies to consensual actors if `condition_consensual_orgasm`.

---

## 7. Integration surface

| Kind | Name | Payload / use |
|---|---|---|
| ModEvent (sent) | `SexLabOrgasmSeparate` | `(Form actor, int tid)` on each separate orgasm |
| ModEvent (sent) | `SexLabOrgasmSeparateDenied` | `(Form actor, int tid)` when blocked by `slso_forbid_orgasm` |
| ModEvent (sent) | `SexLabOrgasm` | `(actor, FullEnjoyment, Orgasms)` |
| ModEvent (internal) | `SLSO_Start_widget`, `SLSO_Stop_widget`, `SLSO_Change_Partner` | Widget / game setup |
| ModEvent (received) | `DeviceVibrateEffectStart/Stop` | DD vibration → bonus enjoyment |
| StorageUtil | `slso_forbid_orgasm` (int on actor) | 1 = deny orgasm |
| Alias API | `GetFullEnjoyment()` | Cached modified enjoyment (cheap) |
| Alias API | `CalculateFullEnjoyment()` | Recomputes (expensive) |
| Alias API | `GetFullEnjoymentMod()` | Combined multiplier ×100 |
| Alias API | `BonusEnjoyment(ref, n)` | Add enjoyment to self or another actor |
| Alias API | `HoldOut(x)` | Edge |
| Alias API | `Orgasm(-2)` | Force an orgasm |
| Alias API | `GetOrgasmCount()` / `SetOrgasmCount()` | Orgasm count |
| Alias API | `IsOrgasmAllowed()`, `NeedsOrgasm()` (≥100) | Orgasm state checks |
| Thread API | `Get/Set_minimum_aggressor_orgasm_Count`, `Get/Set_maximum_...` | Aggressor orgasm requirement |

### Key JSON settings (`/SLSO/Config.json`)
| Group | Keys |
|---|---|
| Game | `game_enabled`, `game_npc_enabled`, `game_player_autoplay`, `game_victim_autoplay`, `game_pleasure_priority`, `game_edging`, `game_enjoyment_reduction_chance`, `game_passive_enjoyment_reduction`, `game_no_sta_endanim`, `game_male_orgasm_endanim`, `game_animation_speed_control*` |
| Enjoyment | `sl_passive_enjoyment`, `sl_stage_enjoyment`, `sl_enjoymentrate_male/female`, `sl_sla_arousal` (0–3), `sl_exhibitionist` (0–2), `sl_masturbation`, `sl_estrusforcedenjoyment`, `sl_multiorgasmchance`, `sl_multiorgasmchance_curve` |
| Conditions | `condition_leadin_orgasm`, `condition_player_orgasm`, `condition_victim_orgasm` (0/1/2), `condition_ddbelt_orgasm`, `condition_female_orgasm`, `condition_male_orgasm`, `condition_futa_orgasm`, `condition_female_orgasm_bonus`, `condition_male_orgasm_penalty`, `condition_aggressor_orgasm`, `condition_player_aggressor_orgasm`, `condition_consensual_orgasm`, `condition_minimum/maximum_aggressor_orgasm`, `condition_chance_minimum_aggressor_orgasm_increase`, `condition_aggressor_change_animation` |
| End | `sl_default_always_orgasm`, `sl_npcscene_always_orgasm` |
| Widget / voice | `widget_*`, `widgetcolors`, `widgetN`, `sl_voice_player`, `sl_voice_npc`, `sl_voice_painswitch`, `sl_voice_enjoymentbased`, `sl_voice_playandwait` |
| Hotkeys | `hotkey_utility`, `hotkey_bonusenjoyment`, `hotkey_edge`, `hotkey_select_actor_1..5`, `hotkey_pausegame`, `hotkey_widget` |
