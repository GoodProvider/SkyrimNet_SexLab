# Player overview

SkyrimNet_SexLab bridges SkyrimNet (LLM) and SexLab Framework.

Hotkeys: [hotkeys.md](hotkeys.md). Authoring: [../authors/actions.md](../authors/actions.md). Changelog: [../../CHANGELOG.md](../../CHANGELOG.md).

LLM actions and prompts ship in both layouts. SkyrimNet 0.25+ loads plugin `goodprovider.sexlab` (External on the Plugins page). Older SkyrimNet loads `prompts/` and `config/actions/`.

## FAQ

### Actions or prompts missing after updating SkyrimNet

On SkyrimNet 0.25+, check **Plugins > Installed Plugins** for `goodprovider.sexlab` with an **External** badge (the shipped `prompts/` and `config/actions/` copies are ignored there). Pre-0.25 uses those copies. **Plugins > Import Old Content** is for personal tweaks, not this mod — an imported copy hides later updates.

### NPCs avoid casual sex

- Public visibility matters; try whisper mode. SkyrimNet can see/hear through walls.
- Match social-world settings to the tone you want.
- SkyrimNet dashboard **Public sex accepted** (`sexlab.prompt.public_sex_accepted`) changes prompt treatment of public sex.

### Too much sex

- Tune [arousal prompts](https://github.com/GoodProvider/SkyrimNet_SexLab/blob/main/SKSE/Plugins/SkyrimNet/external/goodprovider.sexlab/prompts/submodules/character_bio/0005_sexlab_variables.prompt#L12).
- Check social-world settings.
- Review your other mods, they can also start sex animations

### Memory errors when actions fire

SkyrimNet is not seeing Actions functions.

1. Put `SkyrimNet_SexLab.esp` last.
2. SkyrimNet webUI → Tools → Game Data Explorer → search `_sexlab` → Quests → View Scripts → **Refresh** → Actions (function count > 0).

### Narration spammy or silent

- SkyrimNet dashboard **Narration cooldown** — min seconds since last audio before optional Direct Narration.
- SkyrimNet dashboard **Narration max distance** — player distance for optional narration.

## Shipped LLM actions

| Category | What |
|----------|------|
| sex1 / sex2 / sex3 | Masturbation, two-actor, threesome; forceful/normal/gentle; **fucking** vs **giving** (`no_penis`); rape if **Add rape actions** is on |
| nonsexual / comfort | Kiss, hug, cuddle, spoon, headpat; 3-actor nonsexual |
| punish | Spanking, nude spanking, whipping; punish-rape |
| none | Stop; dress/undress (`dresses`/`undresses`, silent OK) |
| mini-game | `SexLab_Arouse` / `SexLab_Calm` (only while **Enable orgasm mini-game** is on) |

Scene files via `setting_name`: [../reference/scene-settings.md](../reference/scene-settings.md).

## Settings (SkyrimNet dashboard)

Configure in SkyrimNet under plugin **SkyrimNet_SexLab** (`goodprovider.sexlab`). The MCM only reloads those values.

- Prompt: hide hermaphrodites; public sex accepted
- Rape: add rape actions (off unregisters LLM actions; on needs save/reload)
- Tag Edit dialogs; Start Sex / Edit Stage hotkey (default backslash `\`)
- Direct Narration: cooldown, max distance
- Scene HUD, enjoyment rates, orgasm mini-game: see [hotkeys.md](hotkeys.md#scene-hud-player-scenes). Orgasms are decided by the mod's OrgasmEngine (SexLab's own trigger is off)
- OstimNet: sex framework 0 SexLab / 1 Ostim (`sexlab.ostim.player`)
- Leash (`SkyrimNet_Leashed.esp`): SkyMessage / Target Menu opens the Leashed panel

## Requirements

Full list: [requirements.md](requirements.md).
