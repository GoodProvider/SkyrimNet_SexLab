Repo: SkyrimNet_SexLab · branch main · baseline cc204a12 (uncommitted work in tree)

# checkpoint-01: 0050 / 0550 RenderTemplate exception

## Goal

A user reports "the same issue as always": `RenderTemplate : Exception during rendering of template 'submodules/user_final_instructions/0050_sexlab_activity'`. Find the cause and decide whether more files are needed.

## Logs

[logs/2026-11-14-09-55-34/](logs/2026-11-14-09-55-34/) (moved from the loose `logs/` files, see `MANIFEST.txt`):
- `SkyrimNet.log` 17.2 MB and `SkyrimNet_SexLab.log` 45 KB: the same run, game time 2026-11-09 20:05–20:48.
- `Papyrus.0.log`: a **different run** (opened 11/14 18:09), as the user said. Not needed for this issue.

## Findings

1. Full error ([SkyrimNet.log:10770](logs/2026-11-14-09-55-34/SkyrimNet.log#L10770)): `[json.exception.out_of_range.404] unresolved reference token 'source'`. `0550_sexlab_narration` fails the same way ([SkyrimNet.log:10895](logs/2026-11-14-09-55-34/SkyrimNet.log#L10895)). It happens on **every** `render_mode: full` render (about 15 pairs, 20:17–20:48).
2. `transform` renders succeed. They fall back to `read_json threads.json` ([SkyrimNet.log:10386](logs/2026-11-14-09-55-34/SkyrimNet.log#L10386)).
3. The failing line is `{% set sexlab.source = "sexlab_get_threads" %}`.
   - The error comes in the same millisecond as the render start, and no `read_json` is logged.
   - nlohmann 404 "unresolved reference token" means the parent is a scalar, so `sexlab_get_threads(npc.UUID)` reached the template as a string.
4. Our C++ always returns an object dump (`BuildThreadsJson`, [Decorators.cpp:247](../../SKSE_Source/src/Decorators.cpp#L247)). Registration succeeded ([SkyrimNet_SexLab.log:51](logs/2026-11-14-09-55-34/SkyrimNet_SexLab.log#L51)).
5. The user runs **SkyrimNet 1-0-0-0** ([SkyrimNet.log:1](logs/2026-11-14-09-55-34/SkyrimNet.log#L1)). Dev runs 1-1-1-0 / 1-2-0-0, both on PublicAPI v14. Dev `SkyrimNet.2026-11-13_15-42-21.log` (1-1-1-0) has 98 full renders of 0050 and 0 errors. The template has used `sexlab.source` since 0.34.
   - **Inference (untested):** SkyrimNet 1.0.0 doesn't parse PublicAPI decorator strings in full renders.
6. The user's DLL is SkyrimNet_SexLab **0.37.0** (current release 0.37.3). OStimNet is also installed. Neither is related to the 404.

## Results (uncommitted)

- [0050_sexlab_activity.prompt](../../SKSE/Plugins/SkyrimNet/external/goodprovider.sexlab/prompts/submodules/user_final_instructions/0050_sexlab_activity.prompt) and [0550_sexlab_narration.prompt](../../SKSE/Plugins/SkyrimNet/external/goodprovider.sexlab/prompts/submodules/user_final_instructions/0550_sexlab_narration.prompt):
  - `sexlab.source` is now `_sexlab_source`.
  - The fallback check is `not existsIn(sexlab,"threads") or not sexlab.threads`. `existsIn` is false on a string, so a string result reads `threads.json` (player view) instead of throwing.
  - `isObject` was not used: there's no evidence SkyrimNet's inja exposes it, and an unknown function would break the template.
- KNOWLEDGEBASE.md has a new top entry. CHANGELOG-player / CHANGELOG-developer have a "Prompts" line under Unreleased. docs/players/requirements.md now recommends SkyrimNet 1.1.1+.

## Not yet tested

- The edited templates have not run in game (dev SkyrimNet 1.2): the regular path, with `[SNSL DEBUG 0050] source:sexlab_get_threads`.
- Behaviour on SkyrimNet 1.0.0: the fallback to threads.json, and whether `existsIn` on the string really is false there.
- The root cause in SkyrimNet 1.0.0 is inferred from the version difference only.

## Next

1. Dev: in game, start a SexLab scene and talk to a participant with Verbose on. SkyrimNet.log should show 0050/0550 full renders with no `[error]`, plus `[SNSL DEBUG 0050] source:sexlab_get_threads threads:N`.
2. Reply to the user:
   - Cause: in full renders on SkyrimNet 1-0-0-0, `sexlab_get_threads` reaches the prompt as a string.
   - Ask them to update SkyrimNet to 1.1.1+ and SkyrimNet_SexLab to 0.37.3 (or the next release with this template fix).
   - If it persists: turn on Verbose logging and send SkyrimNet.log + SkyrimNet_SexLab.log **from the same session**. Papyrus.0.log isn't needed.
3. If the user stays on 1.0.0 and retests the new templates: check for `source:file` in the `[SNSL DEBUG 0050]` line and no 404.
4. Commit the template, docs and changelog changes (separately from the unrelated work already in the tree).
