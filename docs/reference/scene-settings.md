# Scene settings JSON

Files under `SKSE/Plugins/SkyrimNet_SexLab/scenes/(setting_name).json`, loaded when an action passes `setting_name`.

## Keys

| key | meaning |
|-----|---------|
| `array_defaults` | Defaults for per-position arrays (`no_orgasm`, `no_stripping`, `speaking_modifiers`) |
| `no_orgasm` | Per-position: `0` orgasm expected, `1` not expected. Not expected means the animation does not arouse them: there is no passive enjoyment gain, and SexLab's voice stays silent below 50 enjoyment. The mini-game can still raise enjoyment, and an orgasm is still possible. |
| `no_stripping` | Per-position: `0` undress, `1` keep clothes |
| `speaking_modifiers` | Per-position underscore tokens — see [protocol-tokens.md](protocol-tokens.md) |
| `tags` | Animation must include these SexLab tags |
| `tags_suppress` | Animation must not include these tags |
| `method` | Optional description when tags are not enough |

`no_orgasm` / `no_stripping` / `speaking_modifiers` only apply when the Scene Creator's "override animation settings" is on. When it is off, each position starts clothed if a strict majority of the candidate animations default that position to clothed in AnimDB (`_clothed`); a tie starts undressed. The chosen animation's own defaults then take over at its first stage.

**Animation change mid-scene** (SexLab switching animations, SL Tools, or the Description Editor's animation filter): each actor's orgasm and speaking modifiers are reloaded from the new animation's defaults, but dressing only goes toward undressed. An actor the new animation wants undressed is stripped; an actor already undressed stays undressed even when the new animation defaults them to clothed (A dressed in animation 1, undressed in animation 2: 1 → 2 undresses A, 2 → 1 does not re-dress A). Turning "override animation settings" off on a live scene is the exception: it reapplies the animation's dressed flags both ways.

**Orgasm denied** (`deny_orgasm`, with the denier's name in `deny_by`) is not a scene-setting key. It is live scene state, set in either of two ways:
- by the player, with the HUD deny key (default Page Down, on the focus actor) or the Description Editor's 🔓/🔒 column;
- by an aggressor NPC, with the LLM actions `SexLab_DenyOrgasm` / `SexLab_AllowOrgasm`.

A denied actor gains enjoyment as normal but cannot orgasm. It survives animation changes.

Allowing again checks every actor at once. Anyone at 100 orgasms, and so does anyone at 95 or more, in one narration that starts "Bob allows Nina to orgasm." See [orgasm-narration.md](orgasm-narration.md).

## Built-in scenes

`default`, `pleasure_pain`, `no_penis`, `nonsexual`, `nonsexual_kissing`, `nonsexual_male_position_0`–`2`, `punish_spanking`, `punish_spanking_victim_nude`, `punish_whipping_oral`, `punish_pleasure_pain_rape`.

Use `punish_*` (not obsolete `punishing_*`).

## Examples

**Giving / no penis** — [`scenes/no_penis.json`](../../SKSE/Plugins/SkyrimNet_SexLab/scenes/no_penis.json):

```json
{
    "tags_suppress": "vaginal,anal"
}
```

**Punish / pain** — [`scenes/punish_spanking.json`](../../SKSE/Plugins/SkyrimNet_SexLab/scenes/punish_spanking.json):

```json
{
    "array_defaults": {
        "no_orgasm": 1,
        "no_stripping": 1
    },
    "speaking_modifiers": ["_pain_", ""],
    "tags_suppress": "oral,vaginal,anal,masturbation,handjob,boobjob,thighjob,fisting,dildo,fingering,footjob,cuddling,spooning"
}
```

Wire from actions via static `setting_name` — see [../authors/actions.md](../authors/actions.md).

You are encouraged to create and share your own scene settings. Example actions: [`SKSE/Plugins/SkyrimNet/external/goodprovider.sexlab/actions/`](../../SKSE/Plugins/SkyrimNet/external/goodprovider.sexlab/actions/). Full authoring rules: [../authors/actions.md](../authors/actions.md).

Synthetic stub (when no short shipped file fits): [../examples/minimal-scene-setting.json](../examples/minimal-scene-setting.json).
