# External JSON keys

Canonical rules for JSON that Skyrim emits and external consumers read (decorators, `threads.json`, prompts).

## Rule

Use **bare lowercase** keys only:

- `speaking_modifiers`, `actors`, `uuid`, `victim`, `notice_level`, `threads`, …

Do **not** invent Title Case or leading-`_` keys (`Actors`, `_actors`) for this pipeline.

Always serialize via `ObjectToLowerCaseKeyJson` / `JsonLowerCaseKeys` so export casing is stable under Skyrim’s string pool.

The strategy decision context (`StrategyDecision.cpp` → `decisions/sexlab/minigame_strategy.prompt`) is built with nlohmann in C++ and follows the same rule with `_` between words: `trigger`, `focus_uuid`, `focus_name`, `last_line_text`, `role`, `arousal`, `orgasms`, `expects_orgasm`, `timeline[]` (strings), `partners[]` (`uuid`, `name`, `is_player`, `role`, `arousal`, `orgasms`, `relationship`, `relationship_rank`), `options[]` (`key`, `text`). `trigger` is `scene_start`, `dialogue`, `asked`, `ordered` or `punished`. The player turn context (`decisions/sexlab/minigame_player_turn.prompt`) adds `last_speaker`, `has_strategy`, `ask_speak`, `hotkeys[]`, `aid_options[]`, `punish_options[]`, `punish_methods[]` (`key`, `text` each) and `parts[]`. The Ask / Order / Punish panel payload (`Hud.cpp` `OnPunish` → `openPunishPanel`): `actors[]` (`id`, `name`, `female`, `isPlayer`, `spells[]`, `requests[]` (`key`, `text`), `reasons[]`), `defaultPunisher`, `injuryengine`, `injuryengineSexual`, `injuryengineMaxStrikes` (the Aid panel payload, `OnAid` → `openAidPanel`, shares the `injuryengine*` keys); with Injury Engine's `External_PartPoints`, each actor of either panel also carries `injury` (`total`, `max`, `parts` keyed by pulldown term → `points`, `max`); its reply `onPunishResult`: `verb` (`ask` / `order` / `punish`), `subject`, `object`, then `request` or `text`, or `method`, `location`, `reason` (`""` for no reason), `amount` (hits, 1 without Injury Engine). Refusals and other punishment reasons are held per actor as `{order_actor, target_actor, reason_narration, strategyKey}` (`PunishRecord`: `by`, `target`, `reason`, `strategyKey`, plus `request` and `type`: `refused_strategy` | `external`).

Protocol **values** (speaking modifiers) are separate — still `_pain_`, etc. See [protocol-tokens.md](protocol-tokens.md).

## Implementation

[`Scripts/Source/SkyrimNet_SexLab_Utilities.psc`](../../Scripts/Source/SkyrimNet_SexLab_Utilities.psc) (excerpt):

```papyrus
; Serialize JValue -> JSON string with all object keys lowercased. Empty/invalid -> "{}".
; Walks JMap/JArray/JFormMap/JIntMap. Do not call JValue.toJsonString (JC 4.2.13.1+ only).
String Function ObjectToLowerCaseKeyJson(int obj) global
    String json = JValueToJsonString(obj)
    if json == "" || json == "null"
        return "{}"
    endif
    json = JsonLowerCaseKeys(json)
    if !json
        return "{}"
    endif
    return json
EndFunction
```

Call sites include DOM thread export in `SkyrimNet_SexLab_Scene_Manager.psc` (`PushDomThreads`), stages export in `SkyrimNet_SexLab_Stages.psc`, and `RenderSlPrompt` in `SkyrimNet_SexLab_Utilities.psc`.

## `sexlab_get_threads` / `threads.json`

Built in C++ (`SKSE_Source/src/Decorators.cpp`), live on every call. Papyrus only pushes data:

- `Scene.PushThread` (AnimationStart, StageStart, AnimationEnd, SetDenyOrgasm, the 2 s animation poll) runs `RefreshThreadObj` and hands its `thread_obj` handle to `Decorators.Threads_Set(sid, thread_obj, positions)`, or calls `Threads_Remove(sid)` once `GetThreadInScene()` is false. `Scene.Release` removes too.
- `Scene_Manager.PushDomThreads` (DOM behaviour change, setup) sends the DOM threads, already enriched by `EnrichActorObjForJson`, to `Threads_SetDom`.

Per call, C++ dumps each `thread_obj` (keys are already lowercase in the JSON store), overlays OrgasmEngine `enjoyment` / `strategy` / `stamina_regen` per actor, and adds `speaker_name` / `speaker_distance` (meters) / `speaker_los`. LOS comes from a main-thread cache (`HasLineOfSight`), primed for nearby actors on each push; an uncached pair reads `0` until its first check. `threads.json` (player view) is rewritten on every push whose threads changed. Shape: `{"counter", "threads": [{"active", "status", "description", "style", "speed", "location", "speaker_name", "speaker_distance", "speaker_los", "names", "victims", "actors": [...]}]}`.
