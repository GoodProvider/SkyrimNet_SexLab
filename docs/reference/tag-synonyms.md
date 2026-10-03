# AnimDB tag synonyms

This is the canonical reference for the synonym clusters used when searching animations by tag in AnimDB.

## Files

These files live in `SKSE/Plugins/SkyrimNet_SexLab/`, next to `group_tags.json`:

| File | Mode | Contents |
|------|------|----------|
| `synonyms-strict.json` | `strict` | True equivalents only (`doggy` = `doggystyle`, `titfuck` = `boobjob`, `dp` = `doublepen`). |
| `synonyms-broad.json` | `broad` (default) | Every strict cluster plus wider families (`gallows*`, `creampie` + `vaginalcum`, `spanking` + `punishment`). |

```json
{
  "_comment": "…",
  "_mode": "broad",
  "clusters": [
    ["doggystyle", "doggy", "doggy style"],
    ["boobjob", "titfuck", "titjob", "paizuri"]
  ]
}
```

- **Matching is symmetric.** Searching for any member matches every animation tagged with any member of the same cluster.
- **Spelling:** members are lowercased and trimmed. Spaces are allowed. A member does not have to exist as a SexLab tag yet, so words the LLM uses (`fellatio`, `bondage`) are allowed.
- **No `SanitizeTag` aliasing.** Members are not rewritten the way `SanitizeTag` rewrites `pussy` → `vaginal`. SexLab row tags are stored as written, so `pussy` has to stay `pussy` to match.
- **Overlapping clusters merge.** If a member appears in two clusters, the clusters are merged and the SKSE log gets a warning.
- **Missing or malformed files** make that mode behave like `none` (literal tags). The SKSE log gets a warning.
- **Never cluster Devious Devices restraint tags together** (`yoke`, `armbinder`, `hogtied`). Worn-device tags (`AppendMatchingTags`) must match literally so the chosen animation suits the device.
- **Never cluster `hug` with `cuddling`.** `resolved == "hug"` triggers the hug idle in `SkyrimNet_SexLab_Actions.psc`.

## Reload

Both files are reloaded at three points:

- `kDataLoaded`, via `AnimationDB::Open`
- every game load or new game (`kPostLoadGame` / `kNewGame`)
- every AnimDB sync or rebuild (`AnimationDB::EndSync`)

To pick up an edit, reload a save. A restart is not needed.

## Mode parameter

| Where | Key / argument | Values |
|-------|----------------|--------|
| AnimDB filter JSON (`AnimDb_QueryTopNAnims`, `AnimDb_QueryTopNTags`, WebUI `onAnimDbQuery` `_filter`) | `_synonyms` | `broad` (default) · `strict` · `none` |
| `AnimDb_ResolveTags(tags_csv, actor_count, synonyms = "broad")` | 3rd argument | same |
| WebUI `onAnimDbResolveTags` | `_synonyms` | same |
| Scene Creator handoff (`scBuildResult`) → `Scene_Creator.ApplyWebUIState` | `_synonyms` | same; stored in `synonyms_mode` |
| Scene setting JSON ([scene-settings.md](scene-settings.md)) | `synonyms` | same; `default.json` sets `broad`. Widens the setting's `tags`, `tags_suppress`, `tags_any`, `tags_prefer` and `exclude_settings` filters. TargetMenu resolve/random and Papyrus `LoadSetting` adopt it; an explicit `_synonyms` (Scene Creator pulldown) wins |
| C++ `AnimationDB::FilterSpec::synonyms`, `ResolveTags(…, mode)`, `AppendMatchingTags(…, mode)` | `SynonymMode` | `Broad` (default) · `Strict` · `None` |

Matching rules:

- Must tags and suppress tags are both expanded to their clusters.
- `_require_all` still means AND (or OR) **across** the requested tags. Inside one cluster, any member counts.
- `ResolveTags` returns the **requested** words, not the synonyms they matched.

The **synonyms** pulldown in the Scene Creator and the Description Editor animation filter sets the mode. Both pulldowns share `SC.synonyms`, which resets to `broad` when the WebUI closes.

## Related filter key

`_shuffle` (bool, or int from JContainers): `QueryTopNAnims` returns matches in random order before truncating to `n`. `Scene_Creator.QuerySexLabAnimsFromAnimDb` sets it so scene starts pick a random 32 of the matches, not the alphabetically first 32.

## Animation selection

All tag-based selection in `SkyrimNet_SexLab_Scene_Creator.psc` goes through `SelectAnimationsFromAnimDb`, which runs the full AnimDB query and then the peel steps. `SexLab.GetAnimationsByTags` is not called anywhere, because it matches tags literally and ignores synonyms.
