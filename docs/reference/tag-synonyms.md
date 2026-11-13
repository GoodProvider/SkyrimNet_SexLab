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

`_shuffle` (bool, or int from JContainers): `QueryTopNAnims` returns matches in random order before truncating to `n`.

`_rank` (bool, or int from JContainers; wins over `_shuffle`): `QueryTopNAnims` orders matches before truncating to `n`: described first, then cast-gender tier, then play count ascending (least played first), then random. `_rank_pos_genders` (int array, SexLab genders 0 m / 1 f / 2 m creature / 3 f creature, in cast order) sets the tier: 0 = the row's positions match the cast in cast order or females-first (SexLab's seating), 1 = same gender counts in any position, 2 = the rest. When any match is tier 0 or 1, the tier-2 matches are dropped before truncating (P+ pickers take one of the top `n` at random, so a misfit left in would get played). When none fit, all are kept. `Scene_Creator.QuerySexLabAnimsFromAnimDb` and `Scene.LastStage_PickRegistry` set both, so scene starts (TargetMenu / action YAMLs) and Papyrus mid-scene picks get the top 32 by that order. The animation table's `default` sort uses the same order with its gender key in place of the tier.

`_creatures` (array, one object per creature in the cast): `{"_gender": 2 | 3 | "mc" | "fc", "_race_keys": ["wolves", "canines"] or "Wolves,Canines", "_pos": i}`. A row passes only when its creature positions (`pos_genders` 2 / 3) number the same as the entries and each entry seats one of them whose `pos_race_keys` value is in its `_race_keys` (case-insensitive; an empty key on either side matches any species). `_pos` (optional) pins the entry to that row position. The gender is checked only with `_gender_match` or `_position_match`; then it replaces the `_male_creatures` / `_female_creatures` count check and the single-key `_pos_race_keys` compare. Species is checked in every mode, so a wolf cast never gets a horse animation. `_race_keys` holds every SexLab race key of the actor's race (`sslCreatureAnimationSlots.GetAllRaceKeys`, Papyrus `GetRaceKeysForActor`), because SexLab files one race under several keys. Senders: the Scene Creator (`scApplyCreatures`, every filter mode), the random pick (`ssRandomFilter`, never loosened), `Scene_Creator.QuerySexLabAnimsFromAnimDb` and `Scene.LastStage_PickRegistry` (`CreatureWantsJArray`; these also switch `_creature` to `require` for a creature cast).

`_pos_genders` and `_rank_pos_genders` entries take the strings `m` / `f` / `mc` / `fc` as well as 0 to 3. The animation table and the cast label show creature genders as `MC` / `FC`.

## Animation selection

All tag-based selection in `SkyrimNet_SexLab_Scene_Creator.psc` goes through `SelectAnimationsFromAnimDb`, which runs the full AnimDB query and then the peel steps. `SexLab.GetAnimationsByTags` is not called anywhere, because it matches tags literally and ignores synonyms.

## Derived `sexual` tag (`sex_tags.json`)

`SKSE/Plugins/SkyrimNet_SexLab/sex_tags.json` is a flat array of tags (`["oral","vaginal","anal",…]`). AnimDB adds the tag `sexual` to every animation whose tags include any of them. It is stored in the row's tags, so filters, tag chips and `ResolveTags` treat it like any other tag. Loaded with the synonym files (game load, AnimDB sync).

- Use `sexual` to require any sex act and suppress `sexual` to exclude them. `kissing` is **not** a sex tag.
- The tag is only ever added. If you remove a tag from the file, rows that already have `sexual` keep it until AnimDB is force-rebuilt.

## Derived `rape` tag (`rape_tags.json`)

`SKSE/Plugins/SkyrimNet_SexLab/rape_tags.json` works like `sex_tags.json`: AnimDB adds the tag `rape` to every animation with any listed tag (`rape`, `aggressive`, `forced`, `fbrape`, `assault`, `defeated`, `conquering`, `aggressivedefault`). The **rape** word in the animation row filters on it: red (suppressed) by default, white while the cast has a victim (`scApplyRapeDefault`), until the player clicks it. A bound scene counts as rape: while bound is enabled (`scBoundEnabled`) the word is never red; a red word goes grey, not white. `restrained` does not derive `rape` (other packs may add non-rape bound animations).

## Derived `necro` tag (`necro_tags.json`)

`SKSE/Plugins/SkyrimNet_SexLab/necro_tags.json` works the same way: AnimDB adds the tag `necro` to every animation with any listed tag (`necro`, `necrophilia`, `corpse`, `dead`). The **necro** word in the animation row filters on it: red (suppressed) unless someone in the cast is dead (`_dead` on the position, `scApplyNecroDefault`), white then, until the player clicks it.

- Papyrus queries (`AnimDb_QueryTopNAnims` with `_form_ids`) suppress `necro` themselves when nobody in the cast is dead and the query doesn't ask for `necro` in its must / any tags (`AnimationDB::SuppressUnlessDead`). This covers the Scene Creator's own query, the end-list picks and the mid-scene switch.

## Name words (`necro`, `restrained`)

For `necro` and `restrained` only, a listed word also counts when it is a whole word of the animation's name or registry: split at non-letters and at a lower-to-upper case change (`FB_NecroFemDomCow` → `fb necro fem dom cow`, `FB_BoundFemCowGirl` → `… bound …`). Many SLAL packs name the act without tagging it. `sexual` and `rape` stay tag-only.

## Derived `restrained` tag (`restraint_tags.json`)

`SKSE/Plugins/SkyrimNet_SexLab/restraint_tags.json` works the same way: AnimDB adds the tag `restrained` to every animation with any listed tag (`bound`, `bondage`, `yoke`, `armbinder`, `cuffs`, `cuffed`, `rope`, `chains`, `hogtied`). The **bound** word in the animation row filters on it.

- The page shows this tag as `bound` on its chip and in an animation's tag list, and leaves it out of the available tags list. Filters still use `restrained`.

- It is a separate tag because worn-device tags, which include `bound` (`BondageCatalog::WornAnimationTags`), must match literally. Do not derive `bound` from these tags or cluster them.
- It is stored on the row, so the synonyms pulldown does not change what it matches.
- Unbound casts leave it out: every AnimDB query that knows its cast (`_form_ids`, scanned with `WearsHeavyBondage` whatever the DD tag setting), `_bound` or `_setting` suppresses `restrained` unless the cast wears heavy bondage (`SuppressUnlessBound`).
- Asking for a restraint or worn-device tag (`restrained`, `bound`, `bondage`, `armbinder`, `yoke`, `cuffs`, `cuffed`, `rope`, `chains`, `hogtied`, `deviousdevice`) in `_must_tags` / `_any_tags`, or in the tags being resolved, counts as bound (`AsksBound`). Then neither that suppress nor `tags_suppress_unless_bound` empties the result.
