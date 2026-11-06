# Animations

Per-stage SexLab animation descriptions for SkyrimNet_SexLab.

Orgasm narration when a stage climaxes: [../reference/orgasm-narration.md](../reference/orgasm-narration.md).

## Paths

| Path | Purpose |
|------|---------|
| `SKSE/Plugins/SkyrimNet_SexLab/animations/_local_/` | Local edits (loaded last, wins) |
| `SKSE/Plugins/SkyrimNet_SexLab/animations/(author)/` | Shared packs |
| `animations/GoodProvider/` | Example pack |

## SexLab P+ playing set

Empty tags: skip `GetAnimationsByTags` so SexLab picks. Tagged matches: `PickOneAnimation` keeps one random anim (P+ `GetPlayingScenes` hops otherwise). `Scene.StageStart` ends the thread after 120s real-time. Papyrus: [../developers/papyrus.md](../developers/papyrus.md).

## In-game editor

Enable the Start Sex / Edit Stage hotkey in the SkyrimNet dashboard (default backslash `\`) while in a SexLab animation: add/replace stage description, set `orgasm_expected`, change sex style (if Tag Editor dialogs on).

ESC cancels cleanly. Save aborts if existing JSON fails to parse (avoids wiping with `{}`).

## Fallback

Authored anidata for the current stage, then the nearest earlier authored stage if empty. If still empty → tag-based (`GetDescriptionFromTags`). AniDescriber HKX fill is on hold; see [../developers/anidescriber.md](../developers/anidescriber.md).

## JSON format

Keys are **case-sensitive** (JContainers). Use lowercase `"stage N"` and `"version"`.

```json
{
    "stage 1": {
        "description": "{{sl.actors.1}} fingers {{sl.actors.0}}.",
        "version": "2.0"
    },
    "orgasm_expected": [1, 0]
}
```

Inja `2.0`: actors array; victim usually first; `{{sl.actors.0}}`, `{{sl.actors.1}}`, …

### orgasm_expected

Int array by thread position: `0` no orgasm expected, `1` expects orgasm.

If the file doesn't set it, it is inferred from tags. Animations with 3 or more positions expect everyone. In a 2-position animation, `69` and `masturbation` expect both, and a female position expects an orgasm with `doubledildo`, `tribbing` or `scissoring`. Otherwise position 0 expects one from a matching act, and position 1 only with a penis. So a female at position 1 of a one-sided lesbian animation (such as fingering or cunnilingus) is not expected unless the file says so. A value in the file always wins.

### Sex style (Tag Editor)

Forcefully fucking / having sex / gently making love.

## Sharing

Zip `_local_` or an author folder; install under `animations/(author_name)/`. Keep personal overrides in `_local_`.
