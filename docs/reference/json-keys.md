# External JSON keys

Canonical rules for JSON that Skyrim emits and external consumers read (decorators, `threads.json`, prompts).

## Rule

Use **bare lowercase** keys only:

- `speaking_modifiers`, `actors`, `uuid`, `victim`, `notice_level`, `threads`, …

Do **not** invent Title Case or leading-`_` keys (`Actors`, `_actors`) for this pipeline.

Always serialize via `ObjectToLowerCaseKeyJson` / `JsonLowerCaseKeys` so export casing is stable under Skyrim’s string pool.

The strategy decision context (`StrategyDecision.cpp` → `decisions/sexlab/minigame_strategy.prompt`) is built with nlohmann in C++ and follows the same rule with `_` between words: `trigger`, `focus_uuid`, `focus_name`, `last_line_text`, `progress`, `role`, `arousal`, `orgasms`, `expects_orgasm`, `broken`, `current_key`, `approach`, `forced_by`, `force_method`, `partners[]` (`uuid`, `name`, `is_player`, `role`, `arousal`, `orgasms`, `approach`, `relationship`, `relationship_rank`), `options[]` (`key`, `text`). The player turn context (`decisions/sexlab/minigame_player_turn.prompt`) adds `last_speaker`, `has_strategy`, `ask_speak`, `hotkeys[]`, `aid_options[]`, `force_options[]`, `force_methods[]` (`key`, `text` each) and `parts[]`.

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

Call sites include scene/thread export in `SkyrimNet_SexLab_Scene.psc` / `SkyrimNet_SexLab_Scene_Manager.psc`, stages export in `SkyrimNet_SexLab_Stages.psc`, and `RenderSlPrompt` in `SkyrimNet_SexLab_Utilities.psc`.
