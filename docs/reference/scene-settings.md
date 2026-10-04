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
| `tags_any` | Animation must include **at least one** of these tags (ANDed with `tags` and the method tag). This is how a setting names its intent when the TargetMenu method is **random**. Never dropped by the fallback |
| `tags_prefer` | Soft OR group: when some candidates have one of these tags, only those are used; otherwise the whole pool is |
| `tags_suppress_unless_bound` | Suppressed only while nobody in the cast wears Devious Devices heavy bondage (and **Devious devices are added to tags** is on). Bound casts drop the list, and the worn-device tags then steer the pick |
| `assume_bound` | `true`: treat the cast as bound, so `tags_suppress_unless_bound` never applies (`punish_whipping_oral`: every whip animation is a DD one) |
| `exclude_settings` | Setting names. An animation is excluded if it passes that setting's own `tags` / `tags_any` / `tags_suppress` |
| `synonyms` | `broad` (default) · `strict` · `none`: which [tag-synonyms](tag-synonyms.md) clusters widen **every** tag key above, suppress lists included |
| `strict` | `true`: when nothing matches, the fallback may drop the method tag but never this setting's `tags_suppress`, `tags_any` or `exclude_settings`. The start aborts instead of loosening |
| `gender_match` | `false`: the TargetMenu random start never narrows by the cast's genders (default `true`) |
| `male_position` | Position index that should hold a male actor; swaps the first two actors when it does not |
| `style` | Scene style (`forcefully` · `normally` · `gently`) |
| `event_hook` | SexLab event hook name passed to the thread |
| `victim` | Per-position: `1` victim, `0` not |
| `method` | Optional description when tags are not enough |

Settings layer like Papyrus `LoadSetting`: `default.json` first, then the named file, which wins per key it sets. `tags_any`, `tags_prefer`, `tags_suppress_unless_bound` and `exclude_settings` are applied by C++ on every AnimDB query that carries the setting name (`_setting` in the filter JSON); Papyrus and JS only pass the name, the synonym mode, and `strict` / `gender_match`. The C++ copy is cached and reloads with the synonym files (game load, AnimDB sync).

`no_orgasm` / `no_stripping` / `speaking_modifiers` only apply when the Scene Creator's "override animation settings" is on. When it is off, each position starts clothed if a strict majority of the candidate animations default that position to clothed in AnimDB (`_clothed`); a tie starts undressed. The chosen animation's own defaults then take over at its first stage.

**Animation change mid-scene** (SexLab switching animations, SL Tools, or the Description Editor's animation filter): each actor's orgasm and speaking modifiers are reloaded from the new animation's defaults, but dressing only goes toward undressed. An actor the new animation wants undressed is stripped; an actor already undressed stays undressed even when the new animation defaults them to clothed (A dressed in animation 1, undressed in animation 2: 1 → 2 undresses A, 2 → 1 does not re-dress A). Turning "override animation settings" off on a live scene is the exception: it reapplies the animation's dressed flags both ways.

**Orgasm denied** (`deny_orgasm`, with the denier's name in `deny_by`) is not a scene-setting key. It is live scene state, set in either of two ways:
- by the player, with the HUD deny key (default Num 1, on the focus actor) or the Description Editor's 🔓/🔒 column;
- by an aggressor NPC, with the LLM actions `SexLab_DenyOrgasm` / `SexLab_AllowOrgasm`.

A denied actor gains enjoyment as normal but cannot orgasm. It survives animation changes.

Allowing again tests the allowed actor with the normal orgasm rule and checks every other actor at once. Whoever orgasms (anyone else at 100, plus the group join) goes into one normal orgasm narration that starts "Bob allowed Nina to orgasm." See [orgasm-narration.md](orgasm-narration.md).

## Built-in scenes

`default`, `consensual`, `pleasure_pain`, `no_penis`, `nonsexual`, `nonsexual_platonic`, `nonsexual_kissing`, `nonsexual_male_position_0`–`2`, `punish_spanking`, `punish_spanking_victim_nude`, `punish_whipping_oral`, `punish_pleasure_pain_rape`.

Use `punish_*` (not obsolete `punishing_*`).

`nonsexual_male_position_0`–`2` (LLM cuddle / comfort / affection actions, MCM affection) filter like `nonsexual` (strict, affection `tags_any`, same suppress list plus `forplay,whip`) and add `male_position`. The cuddle actions pass a posture (`sitting` / `laying`) as the method tag, so without `tags_any` + `strict` the posture alone matched sex animations.

TargetMenu scene-start options and their settings:

| Option | Setting | Filter |
|--------|---------|--------|
| sex | `consensual` | any sex act; no `aggressive`; not an affection/platonic animation |
| affection | `nonsexual` | strict; any of cuddling/hug/spooning/kissing/headpat/handholding/lappillow; no sex acts, spanking, aggressive |
| platonic | `nonsexual_platonic` | strict; any of cuddling/hug/spooning/headpat/handholding; also no kissing or submission |
| punish | `punish_spanking` | strict; `spanking` (broad: spank/punish/discipline); any gender. Option `methodSettings` sends **whip** to `punish_whipping_oral` (`assume_bound`, so whip always finds its DD animations) |
| masturbation | `default` | DD-only animations only when bound |
| rapes | `punish_pleasure_pain_rape` | everything except affection/platonic animations; prefers `aggressive` |

`default.json` sets `synonyms: broad` and `tags_suppress_unless_bound: armbinder,yoke,cuffs,bound` (every `deviousdevice` animation has one of these).

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
    "strict": true,
    "gender_match": false,
    "tags_any": "spanking",
    "tags_suppress": "oral,vaginal,anal,masturbation,handjob,boobjob,thighjob,fisting,dildo,fingering,footjob,blowjob,cunnilingus,69,tribadism,assjob,sex,penis,creampie,cuminmouth,handcum,cuddling,spooning"
}
```

**Everything but affection** — [`scenes/punish_pleasure_pain_rape.json`](../../SKSE/Plugins/SkyrimNet_SexLab/scenes/punish_pleasure_pain_rape.json):

```json
{
    "array_defaults": { "speaking_modifiers": "_pleasure_" },
    "speaking_modifiers": ["_pain_,_pleasure_"],
    "tags_prefer": "aggressive",
    "exclude_settings": "nonsexual,nonsexual_platonic"
}
```

Wire from actions via static `setting_name` — see [../authors/actions.md](../authors/actions.md).

You are encouraged to create and share your own scene settings. Example actions: [`SKSE/Plugins/SkyrimNet/external/goodprovider.sexlab/actions/`](../../SKSE/Plugins/SkyrimNet/external/goodprovider.sexlab/actions/). Full authoring rules: [../authors/actions.md](../authors/actions.md).

Synthetic stub (when no short shipped file fits): [../examples/minimal-scene-setting.json](../examples/minimal-scene-setting.json).
