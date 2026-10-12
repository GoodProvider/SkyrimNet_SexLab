# Actions (SkyrimNet YAML)

Create or edit LLM actions for SkyrimNet_SexLab.

Upstream schema: [WORKFLOW_ACTIONS.md](https://github.com/MinLL/SkyrimNet-GamePlugin/blob/main/docs/modding/WORKFLOW_ACTIONS.md).

See also: [prompts.md](prompts.md), [../reference/scene-settings.md](../reference/scene-settings.md), [../developers/papyrus.md](../developers/papyrus.md).

## Hard limit: 8 parameters

SkyrimNet allows **at most 8** `parameterMapping` entries. Threesome actions already use all 8. To add more inputs: fold into an existing dynamic string, use scene `setting_name`, or a Papyrus wrapper with hard-coded roles (`_TargetVictim` / `_SpeakerVictim`).

## Paths

SkyrimNet Beta 25+ reads this mod's LLM content from the **external plugin** folder. Folder name must equal `manifest.json` `id`. Edit that tree, then run `tools/sync_legacy_skyrimnet_content.py` so pre-0.25 copies stay identical.

| Path | Purpose |
|------|---------|
| `SKSE/Plugins/SkyrimNet/external/goodprovider.sexlab/` | Canonical plugin root (`manifest.json`) |
| `…/actions/` | Action YAML |
| `SKSE/Plugins/SkyrimNet/config/actions/` | Pre-0.25 copy of action YAML |
| `SKSE/Plugins/SkyrimNet/prompts/` | Pre-0.25 copy of prompts |
| `SKSE/Plugins/SkyrimNet_SexLab/scenes/` | Scene JSON via `setting_name` |
| `…/prompts/helpers/sexlab/` | Optional helpers |
| `Scripts/Source/SkyrimNet_SexLab_Actions.psc` | `executionFunctionName` targets |

The YAML filename (before `.yaml`) must equal the in-file `name`, compared case-insensitively. Keep the `name` casing; that is what the LLM sees. Do not rename an action `name` unless you intend to reset per-action enabled/cooldown settings.

Categories (`customCategory`): `sexlab_sex1` / `sexlab_sex2` / `sexlab_sex3`, `sexlab_nonsexual` / `sexlab_comfort`, `sexlab_punish`, `sexlab_none`.

Category parents have no `executionFunctionName` (e.g. `ShowComfort.yaml`, `SexLab_Sexual_Activities_Two.yaml`) — no Papyrus call.

## Category vs executable

**Parent only:** `name`, `description`, `customCategory`, `enabled`, optional `eligibilityRules`. No `questEditorId` / `scriptName` / `parameterMapping`.

**Executable:** unique `name`; `questEditorId: SkyrimNet_SexLab`; `scriptName: SkyrimNet_SexLab_Actions`; `executionFunctionName`; `parameterMapping` (≤ 8, positional vs Papyrus).

| mapping `type` | Required | Notes |
|----------------|----------|-------|
| `static` | `value` | Fixed every call |
| `dynamic` | `description` | LLM fills; no `value` |
| `speaker` | — | Triggering actor |

Prefer Papyrus slot names: `method`, `how` (outfit), `victim` when needed.

### Entry points

| Function | When |
|----------|------|
| `StartScene_Consensual_One` / `_Two` / `_Three` | Willing |
| `StartScene_Nonconsensual_Two` | LLM picks `victim` |
| `StartScene_Nonconsensual_Two_TargetVictim` | Target is victim |
| `StartScene_Nonconsensual_Two_SpeakerVictim` | Speaker is victim |
| `StartScene_Refused_Two` | Refusal |
| `Outfit_Dress` / `Outfit_Undress` | Speaker dresses/undresses Target; narration `silent` → RegisterEvent |
| `CleanCum` | `sexlab_clean_cum`: speaker cleans `part` (`mouth\|pussy\|ass\|all`; unknown → first live part) on target via `Decorators.ClearCumPart`; RegisterEvent narration. Gate: `papyrus_util FormListCount player skyrimnet_sexlab_cum_actors != 0` (list kept by `RecordCum` / expiry) |
| `SceneChangeStyle` | `SexLab_Change_Style`: speaker's live scene → `forcefully\|normally\|gently`; animation speed follows style |

No `speaking_victim`. No `sexlab_none_rape`. Outfit eligibility uses `OStimActorCountFaction`.

## setting_name

```yaml
  - type: static
    name: setting_name
    value: no_penis
```

Loads `scenes/(setting_name).json`. See [../reference/scene-settings.md](../reference/scene-settings.md).

- Fucking: empty `setting_name`, penis methods.
- Giving: `setting_name: no_penis`.
- Kissing method → Creator may force `nonsexual_kissing`.

## Example (shipped)

[`SexLab_Start_Giving.yaml`](../../SKSE/Plugins/SkyrimNet/external/goodprovider.sexlab/actions/SexLab_Start_Giving.yaml):

```yaml
customCategory: sexlab_sex2
name: SexLab_Start_Giving
executionFunctionName: StartScene_Consensual_Two
parameterMapping:
  - type: static
    name: setting_name
    value: "no_penis"
  # ... speaker, target, style, method, direction (≤ 8 total)
```

Copy patterns: `SexLab_Start_Fucking.yaml`, `SexLab_Punish_Spanking_Target.yaml`, `outfit_dress.yaml` / `outfit_undress.yaml`, `SEXLAB_STOP.yaml`. Stop `description` template: `helpers/sexlab/none_stop`. Outfit actions use inline descriptions (no shared `how` helper).

## Eligibility

Groups need `logicalOperator` (`AND`/`OR`) and `required: true`. Actor lock key: `skyrimnet_sexlab_scene_actor_lock` (not old `skyrimnet_sexlab_actor_lock`); C++ `ActorLocker` mirrors this StorageUtil int while a creator lock is held. Quote `comparisonOperator: ">"` — unquoted `>` is a YAML folded block and loads as blank (Stop never eligible). Do not use Papyrus decorators in action eligibility — `CallDecoratorDirect` returns empty on cache miss; use native `get_global_value` / factions (OStim gate: `skyrimnet_sexlab_ostim_player`).

Rape actions: SkyrimNet dashboard **Add rape actions** (`sexlab.actions.rape_allowed`). Off unregisters LLM actions immediately; on needs save and reload, then Game Data Explorer Refresh.

NPC Stop: **Allow NPCs to stop a scene** (`sexlab.actions.npc_stop_allowed`, default on). `SEXLAB_STOP` eligibility uses the C++ decorator `sexlab_npc_stop_allowed` (`"1"`/`"0"`, read live from config, registered at kDataLoaded via `PublicRegisterDecorator`). Off = Stop never eligible; no reload needed.

## After changes

1. `SkyrimNet_SexLab.esp` last in load order.
2. SkyrimNet webUI → Game Data Explorer → `_sexlab` → Refresh Actions (function count > 0).
3. If WebUI `label`s changed: `tools/generate_actions_index.py` — [../developers/webui.md](../developers/webui.md).
4. After editing plugin YAML or prompts: `tools/sync_legacy_skyrimnet_content.py`.

## Checklist

- [ ] Unique `name`; filename equals `name`; ≤ 8 mappings; order matches Papyrus
- [ ] `static`/`dynamic` fields correct; no `speaking_victim`
- [ ] `setting_name` file exists; modifiers use `_token_` form
- [ ] Eligibility: `logicalOperator` + `required: true`
- [ ] Game Data Explorer Refresh
- [ ] `tools/sync_legacy_skyrimnet_content.py` if YAML/prompts changed

## Mini-game actions

`SexLab_Arouse` / `SexLab_Calm` (`speaker` + dynamic `target`, eligible while the speaker is in `SexLabAnimatingFaction`) call `SkyrimNet_SexLab_Actions.MiniGame_Arouse` / `MiniGame_Calm`. Those call the same OrgasmEngine code as the HUD keys, with `mult = sexlab.minigame.llm_multiplier`. They work in NPC-only scenes, and `SkyrimNet_SexLab_MCM.ApplyMiniGameActions` unregisters them while the mini-game is off. See [../developers/orgasm-engine.md](../developers/orgasm-engine.md).

**NPC strategies** are not actions. SkyrimNet's decision model picks them (`StrategyDecision.cpp`, template `prompts/decisions/sexlab/minigame_strategy.prompt`): every NPC at scene start, and the speaker after each line an NPC in the scene speaks. See [../developers/orgasm-engine.md](../developers/orgasm-engine.md#strategy-decisions). Ask / Order (HUD panel, Papyrus `OrgasmEngine.AskOrder`) and Punish (HUD panel or `SexLab_Scene_Punish`) narrate first, then ask the target NPC's decision (triggers `asked` / `ordered` / `punished`, the narration is its `last_line`), then narrate its answer ("Nina agrees to|refuses Bob's request to …"). `SexLab_Arouse` / `SexLab_Calm` are unregistered in Together mode.

### Aid and Punish (mirror the HUD Aid / Punish keys)

| Action | Papyrus | Parameters | Eligible when (StorageUtil int on the speaker) |
|--------|---------|------------|------------------------------------------------|
| `SexLab_Aid` | `Actions.LLM_Aid` | `speaker`, `target` (can be the speaker), `kind` (`heal` / `stamina`) | `skyrimnet_sexlab_can_aid`: an affordable healing / stamina spell or such a potion |
| `SexLab_Scene_Punish` | `Actions.LLM_Punish` | `speaker`, `target` (anyone else in the scene, the player included), `method`, `part`, `reason` | `skyrimnet_sexlab_can_punish`: in a managed scene with someone else in it |

- `OrgasmEngine.ActionKeys_Refresh` sets both keys per position from `Scene.Engine_BeginScene` (natives `HasAidOptions` / `CanPunish`). `LLM_Aid` refreshes them after a use, because potions run out. `ActionKeys_Clear` runs at scene end.
- **Aid:** native `OrgasmEngine.Aid` picks the speaker's strongest affordable spell for `kind`, otherwise its strongest potion (`Aid.cpp`). A spell costs its magicka; a potion is consumed.
- **Punish:** native `OrgasmEngine.Punish`, the same engine path as the HUD Punish key: "Bob punishes Nina by pinching Nina's nipples, because Nina refused Bob's order to …" `method` is `slap` / `pinch` / `punch` / `pull`, a Novice / Apprentice Damage Health spell the speaker knows (a non-lethal hit of the spell's smallest magnitude, no real cast; "by hitting Nina's ass with Sparks"), or a free phrase ("biting"). `part` names where ("body": none); an empty `reason` drops ", because …". No strategy or forced state is set. The narration's source is the speaker and its target the punished actor, so SkyrimNet picks the target to answer, and that line runs the normal strategy decision.
- The name is `SexLab_Scene_Punish` because `Sexlab_Punish` is already the out-of-scene spanking / whipping category action.
- Papyrus still checks that speaker and target share the scene and differ.
- Both narrate through `DirectNarration_Optional` (`sexlab_aid` / `sexlab_punish` events when the cooldown blocks), so the NPC's own line is not doubled.
- **SkyrimNet_Whipped** (soft dependency, `Whipped.cpp`): when `Whipped::Installed()` (plugin loaded and `SkyrimNet_Whipped_Main.External_Damage` exists), Punish calls `External_TortureText(punisher, target, type, part, 1)` (silent hit, returns the feeling text, "" when no hit landed; `Whipped::PunishText`) and SexLab narrates the line plus that text (an older Whipped without it falls back to `External_Damage(punisher, target, line, part, type, 1, true)`) and heal-type Aid calls `External_Heal(caster, target, line, health, part)`. For heal-type Aid, Whipped applies the heal and sends the DirectNarration, so SexLab does not narrate (HUD: the `whipped` out-param of `Aid::Apply`; Papyrus: Aid checks `OrgasmEngine.WhippedInstalled()`). A weak spell then does no health damage of its own, and the Aid health restore is left to Whipped. Pulldown terms map to Whipped parts in `Whipped::PartName` (cock -> penis, ass -> ass hole; body / custom -> random).
- `SexLab_Aid` is in `MCM.MiniGameActionNames` (unregistered while the mini-game is off). `SexLab_Scene_Punish` is not: it needs no mini-game.

## Orgasm denial actions

`SexLab_DenyOrgasm` and `SexLab_AllowOrgasm` take `speaker` + dynamic `target`, and are eligible while the speaker is in `SexLabAnimatingFaction`. They call `SkyrimNet_SexLab_Actions.LLM_DenyOrgasm` / `LLM_AllowOrgasm`, and from there `Scene.SetDenyOrgasm(target, deny, speaker, from_llm=true)`.

- **Aggressor only.** YAML can only check the faction, so Papyrus enforces the rest. Nothing happens unless all of these hold:
  - speaker and target are in the same scene,
  - the speaker is not a victim,
  - the target is a victim,
  - the target is not the player.
- **Deny:** `deny_orgasm` 1 and `deny_by` = the speaker. The narration is the event `"<speaker> forbids <target> from orgasming without permission."`, because the NPC's own line already says it.
- **Allow:** every actor is checked at once (`OrgasmEngine.AllowOrgasm`).
  - If anyone orgasms, the one orgasm DN starts `"<speaker> allowed <target> to orgasm. "`.
  - Otherwise the event `"<speaker> permits <target> to orgasm."` is sent.
- See [../reference/orgasm-narration.md](../reference/orgasm-narration.md).
