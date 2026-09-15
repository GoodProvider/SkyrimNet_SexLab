# Emit (anidata 3.0, v1)

Generated files must be valid **accept** 3.0 documents. Canonical contract: [docs/developers/anidata-schema.md](../docs/developers/anidata-schema.md). Machine schemas: [snsl-anidata-3.0-accept.schema.json](../docs/developers/schemas/snsl-anidata-3.0-accept.schema.json) and [snsl-anidata-3.0-emit.schema.json](../docs/developers/schemas/snsl-anidata-3.0-emit.schema.json).

This page only records **what the prototype emits**. Do not treat it as a second schema.

## v1 required keys

| Key | Value |
|-----|--------|
| `version` | `"3.0"` |
| `creator` | `stage-descriptor-prototype` or `stage-descriptor-prototype+llm` |
| `stage N` | Object with `description` for **every** SLAL stage (1-based, no leading zeros) |

Filename: `<registrar>.json` (SLAL `id`). Output directory is CLI `--out`, not `animations/`, until an explicit later pass.

## v1 defaults (always write)

Gold Billyy files almost never include these. Emit defaults so the file is closer to the emit profile and consumers do not have to guess.

| Key | Default |
|-----|---------|
| `orgasm_expected` | Per actor: `1` if that actor has `add_cum` **or** animation tags include a climax tag (`Creampie`, `AnalCreampie`, `CumInMouth`, `AirCum`, `Facial`, or `*Cum` except author noise). Else `0`. Length = actor count. |
| `speaking_modifiers` | Per actor array of tokens. Stage-level override allowed. See below. |
| `clothed` | All `0` (Human pack has no clothing signal). |

`transitions` and SNSL `tags`: omit in v1.

## `speaking_modifiers`

Tokens and exclusivity stay in the schema (§7): `_pleasure_`, `_pain_`, `_gagged_`, `_kissing_`. There is **no** silent token. Schema `[]` means speaks normally — do **not** emit `[]` to mean SLAL `silent`. Log `silent`; do not map it.

Prototype mapping (Human MF: position 0 is usually the receiver):

| Condition | Actor token list |
|-----------|------------------|
| Tags include `Kissing` and not Oral/Blowjob/Facefuck | `["_kissing_"]` on actors whose mouths are occupied by the kiss |
| Mouth obstruction: tags Oral/Blowjob/Facefuck, or `open_mouth` with those tags, or a dildo/object in that actor's mouth | `["_gagged_"]` on the obstructed actor |
| Tags `Spanking` / `Discipline` / whipping | `["_pain_"]` on the receiving actor (Human MF: position 0) |
| Else if climax expected | `["_pleasure_"]` |
| Foreplay-only / `sound: none` with no sex and no spanking | omit extra modifiers (animation-level empty lists only if that is the file default) |

`_gagged_` wins over `_pain_` and `_pleasure_`. Do not emit `["_pleasure_", "_kissing_"]`.

Stage-level `speaking_modifiers` only when a stage’s `open_mouth` / oral obstruction differs from the animation default.

SpankDog: pain on actor 0 for spanking; do not treat stage-2 `open_mouth` as `_gagged_` (no oral tags — biting, not a penis/dildo). Male `silent` is logged only.

## Description rules

- `{{sl.actors.N}}` only; no spaces inside braces; no actor names.
- Do not assert clothing in the sentence.
- Keys lowercase: `"stage 1"`, not `"Stage 1"`.
- Empty description is absent at consume time; v1 must not emit empty strings.

Minimal shape:

```json
{
  "version": "3.0",
  "creator": "stage-descriptor-prototype",
  "orgasm_expected": [0, 1],
  "speaking_modifiers": [["_pain_"], []],
  "clothed": [0, 0],
  "stage 1": {
    "description": "{{sl.actors.1}} spanks {{sl.actors.0}}."
  }
}
```

## Not in v1

- Writing into `SKSE/Plugins/SkyrimNet_SexLab/animations/`
- `transitions`
- Copying SexLab registry tags into SNSL `tags` (schema forbids using this file as identity)
- Per-stage `version` (2.0 leftover)
- A `_silent_` token (schema gap; do not invent it here)
