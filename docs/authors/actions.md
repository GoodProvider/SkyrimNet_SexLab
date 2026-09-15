# Actions (SkyrimNet YAML)

Create or edit LLM actions for SkyrimNet_SexLab.

Upstream schema: [WORKFLOW_ACTIONS.md](https://github.com/MinLL/SkyrimNet-GamePlugin/blob/main/docs/modding/WORKFLOW_ACTIONS.md).

See also: [prompts.md](prompts.md), [../reference/scene-settings.md](../reference/scene-settings.md), [../developers/papyrus.md](../developers/papyrus.md).

## Hard limit: 8 parameters

SkyrimNet allows **at most 8** `parameterMapping` entries. Threesome actions already use all 8. To add more inputs: fold into an existing dynamic string, use scene `setting_name`, or a Papyrus wrapper with hard-coded roles (`_TargetVictim` / `_SpeakerVictim`).

## Paths

SkyrimNet Beta 25+ reads this mod's LLM content from the **external plugin** folder. Folder name must equal `manifest.json` `id`.

| Path | Purpose |
|------|---------|
| `SKSE/Plugins/SkyrimNet/external/goodprovider.sexlab/` | Plugin root (`manifest.json`) |
| `…/actions/` | Action YAML |
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

Groups need `logicalOperator` (`AND`/`OR`) and `required: true`. Actor lock key: `skyrimnet_sexlab_scene_actor_lock` (not old `skyrimnet_sexlab_actor_lock`). Quote `comparisonOperator: ">"` — unquoted `>` is a YAML folded block and loads as blank (Stop never eligible). Do not use Papyrus decorators in action eligibility — `CallDecoratorDirect` returns empty on cache miss; use native `get_global_value` / factions (OStim gate: `skyrimnet_sexlab_ostim_player`).

Rape actions: SkyrimNet dashboard **Add rape actions** (`sexlab.actions.rape_allowed`). Off unregisters LLM actions immediately; on needs save and reload, then Game Data Explorer Refresh.

## After changes

1. `SkyrimNet_SexLab.esp` last in load order.
2. SkyrimNet webUI → Game Data Explorer → `_sexlab` → Refresh Actions (function count > 0).
3. If WebUI `label`s changed: `tools/generate_actions_index.py` — [../developers/webui.md](../developers/webui.md).

## Checklist

- [ ] Unique `name`; filename equals `name`; ≤ 8 mappings; order matches Papyrus
- [ ] `static`/`dynamic` fields correct; no `speaking_victim`
- [ ] `setting_name` file exists; modifiers use `_token_` form
- [ ] Eligibility: `logicalOperator` + `required: true`
- [ ] Game Data Explorer Refresh
