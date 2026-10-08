# Prompts

Edit SkyrimNet prompt files shipped with this mod.

Contracts: [../reference/json-keys.md](../reference/json-keys.md), [../reference/protocol-tokens.md](../reference/protocol-tokens.md), [../reference/orgasm-narration.md](../reference/orgasm-narration.md).

## Paths

```
SKSE/Plugins/SkyrimNet/external/goodprovider.sexlab/prompts/
  helpers/
    sexlab/
  submodules/
    character_bio/
    system_head/
    user_final_instructions/
```

Canonical source is the plugin tree. After editing, run `tools/sync_legacy_skyrimnet_content.py` to copy into `SKSE/Plugins/SkyrimNet/prompts/` for pre-0.25 SkyrimNet.

| File | Role |
|------|------|
| `character_bio/0005_sexlab_variables.prompt` | Arousal / sex-active bio |
| `character_bio/0415_sexlab_appearance.prompt` | Appearance while SexLab-active |
| `character_bio/0416_sexlab_cum.prompt` | Warm / drying cum on mouth, pussy, ass after an orgasm |
| `system_head/0020_sexlab_setting.prompt` | System-head settings |
| `user_final_instructions/0050_sexlab_activity.prompt` | Scene + speaking rules |
| `user_final_instructions/0550_sexlab_narration.prompt` | Direct narration / orgasm gate |
| `helpers/sexlab/action_orgy.prompt` | Orgy action helper |
| `helpers/sexlab/none_stop.prompt` | Stop action helper |
| `helpers/sexlab/afterglow.prompt` | Scene afterglow (`RenderSlPrompt`) |
| `helpers/sexlab/cum.prompt` | Scene cum clause (`RenderSlPrompt`) |

No `0520_sexlab_dressing_instructions.prompt`.

`0416_sexlab_cum.prompt` has no plugin gate (it renders with `SkyrimNetUDNG.esp` too). `Scene.AddCum` stamps StorageUtil floats (game-time days) `skyrimnet_sexlab_cum_mouth` / `_pussy` / `_ass` plus the gate key `skyrimnet_sexlab_cum_time`. The prompt only calls the `sexlab_cum(actorUUID)` decorator when the gate key is set. It returns `{warm, drying, warm_mouth, drying_mouth}`: warm for the first game hour, drying until `sexlab.cum.duration_hours` (default 4, 0 = off), then cleared; swimming clears it too. A clothed actor seen from outside shows only the mouth.

Scene afterglow and cum are Papyrus-rendered sentences (v0.34.0+), not LLM system prompts. Bind `{{sl.*}}` only. A single actor name is a string (`{{sl.name}}`), not a one-element array. Papyrus builds lowercase JSON via `ObjectToLowerCaseKeyJson`, then `RenderTemplate` + `ParseString`. Empty, error-looking, or leftover-`{{` renders fall back to the previous Papyrus sentence. The `" is orgasming."` gate is Papyrus (`GetIsOrgasming`) — see [../reference/orgasm-narration.md](../reference/orgasm-narration.md).

## Keys vs values

| Kind | Form |
|------|------|
| JSON keys (Skyrim → prompts) | bare lowercase |
| Protocol values | `_wrapped_` |

Keep literals character-for-character or matching breaks.

## Activity flow (`0050`)

1. `sexlab_get_threads(npc.UUID)` or `threads.json` fallback.
2. v0.34.1+: skip a thread unless an actor is in `SexLabAnimatingFaction`, `OStimActorCountFaction`, or `DOMActionMasturbating` (stale DOM masturbate rows after stop).
3. Match speaker by `uuid`; read `speaking_modifiers`, `victim`, etc.
4. Emit context + Speaking Rules when modifiers present.

`contains(speaker.speaking_modifiers, "_pain_")` is case-sensitive.

v0.31.5+ length rules in `0050_sexlab_activity.prompt` when `_pain_` / `_pleasure_` (not `_gagged_`): one to two vocalizations (not every N words); 9-word dialogue cap (vocalizations do not count); if narration is enabled and the speaker is active, one narration sentence ≤ 20 words that should move the action forward. Edit that file; do not copy the full prompt here.

## Strategy decision (`decisions/sexlab/minigame_strategy`)

A SkyrimNet **decision template**, not a chat prompt: `[ state … ]` blocks plus one `[ question strategy choice ]` with `[ criteria ]`. The DLL sends it through `PublicSendCustomDecisionToLLM` for one NPC at a time (scene start, and after that NPC speaks). Flow and context keys: [../developers/orgasm-engine.md](../developers/orgasm-engine.md#strategy-decisions).

- Keep `{{ o.key }}` exactly as given: the DLL maps the answer back by key (`passive`, `tease_p2`, …).
- One criterion per line; profiles and other multi-line decorators go in a `[ state ]` block.
- The pushed context keys are bare lowercase (`focus_uuid`, `last_line_text`, `partners[].relationship`, …), per [../reference/json-keys.md](../reference/json-keys.md).

## Orgasm gate (`0550`)

See [../reference/orgasm-narration.md](../reference/orgasm-narration.md). Gate:

```inja
contains(_direct_narration, " is orgasming.")
```

## Coupling

| Source | Consumer |
|--------|----------|
| Scene `speaking_modifiers` | `0050_sexlab_activity.prompt` |
| `threads` / `actors` JSON | activity + narration |
| DirectNarration + `" is orgasming."` | `0550_sexlab_narration.prompt` |
| Scene `RenderSlPrompt` (`afterglow.prompt`, `cum.prompt`) | DirectNarration / RegisterEvent |
| `StrategyDecision.cpp` context JSON + `options[].key` | `decisions/sexlab/minigame_strategy.prompt` |

## Checklist

- [ ] Keys bare lowercase; values `_wrapped_` where protocol
- [ ] Orgasm gate still `" is orgasming."` (or Papyrus updated with it)
- [ ] Denied orgasm text never includes that substring
- [ ] Narration-enabled smoke test for changed paths
- [ ] `tools/sync_legacy_skyrimnet_content.py` if prompts changed
