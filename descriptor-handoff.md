# Descriptor handoff

Offline prototype under [`descriptor/`](descriptor/): generate per-stage SexLab **anidata 3.0** descriptions from SLAL animation packs. First slice: **Billyy Human** (117 anims). Markdown contracts are done; **C++ is specified, not built**. No writes under `SKSE/Plugins/SkyrimNet_SexLab/animations/` yet.

Canonical entry: [`descriptor/README.md`](descriptor/README.md). Runtime schema stays in [`docs/developers/anidata-schema.md`](docs/developers/anidata-schema.md) — do not fork it here.

## Goal

Standalone C++23 CLI (`stage_descriptor`) that:

1. Parses Billyy SLAL JSON + source `.txt` + FNIS list
2. Extracts a feature dump per animation
3. Writes **SLAL-honest** template descriptions for every stage
4. Optionally **LLM-refines** (gold style / pose detail); templates are fallback
5. Emits accept-profile anidata 3.0 to `--out` (not into `animations/` until eval is OK)

Fold-in later = ship generated JSON for `AnimationDB::LoadAnimJson` to **consume**. Do **not** parse SLAL inside `LoadAnimJson`.

## Locked decisions

| Topic | Choice |
|-------|--------|
| Pack | Billyy Human (`Billyy_Human.json`, 117) |
| Writer | Hybrid: templates always; LLM optional refine |
| Join key | SLAL `id` = gold filename stem (case-insensitive) |
| Few-shot | 5 complete+tokened Human files only |
| HKX / pose analysis | Out of scope |
| Silent | No anidata silent token; log SLAL `silent` only |
| Billyy path | Sibling dir `Billyy's SLAL Animations 10.5` (apostrophe — quote CLI); not in git |

## Corpus (Human)

| Metric | Value |
|--------|-------|
| SLAL anims | 117 (11 solo / 106 pair) |
| Gold join by registrar | 54 / 117 |
| Few-shot eligible | 5 |
| Sparse (partial labels) | 45 |
| Unmatched | 63 |
| Broken gold | Listed for maintainer cleanup — do not delete in prototype |

Providers among joins: GoodProvider preferred on stem conflict, then alpha. Display-name gold orphans are not join keys for emit.

Other Billyy 10.5 JSON (~230) and sibling `*SLAL*` packs are recorded, not inventoried. Creatures / other authors later.

## Pipeline (specified)

```text
parse (SLAL + source + FNIS) → merge on registrar/stage
  → feature record dump → deterministic templates
  → optional LLM refine → emit 3.0 JSON
```

- Source `.txt` is a Python-like DSL: **scan, do not eval**.
- Objects: prefer FNIS over source on mismatch; log.
- Templates change wording only when flags/objects/sound change (mild last-stage climax OK when tags/`add_cum` support it).
- Hard gates: actor tokens in range, no clothing in prose, no empty strings, no invented props.
- Honest limit: SLAL has no pose deltas (`B_B_SpankDog` is the canonical gap).

## Emit (v1)

- `version` `"3.0"`, `creator` `stage-descriptor-prototype` or `…+llm`
- Every SLAL stage: `"stage N"` + non-empty `description` with `{{sl.actors.N}}`
- Defaults: `orgasm_expected`, `speaking_modifiers` (`_pain_` / `_gagged_` / `_kissing_` / `_pleasure_`), `clothed` all `0`
- Omit `transitions` and SNSL `tags` in v1
- Filename: `<registrar>.json`

## What is done vs next

| Done (markdown) | Next | Later |
|-----------------|------|-------|
| Human inventory, parse notes, feature/signals/templates/pipeline/emit contracts | C++23 CMake under `descriptor/`: parse Human, feature dump, template texts | LLM refine; schema-validate emit |
| Gold lists: gold / sparse / broken / todo | Review dump before LLM | Other Billyy JSON; ship into `animations/` after eval |
| Sibling SLAL pack index | | Creature / other authors |

Suggested first executable milestone: parse + merge + feature dump + templates. No CommonLibSSE / SKSE / Papyrus in the tool.

## Doc map (read order)

1. [`descriptor/plan.md`](descriptor/plan.md) — goal, hybrid, eval, non-goals  
2. [`descriptor/sources.md`](descriptor/sources.md) — paths, join key  
3. [`descriptor/how-to-read-animation.md`](descriptor/how-to-read-animation.md) — SLAL / source / FNIS  
4. [`descriptor/pipeline.md`](descriptor/pipeline.md) + [`templates.md`](descriptor/templates.md)  
5. [`descriptor/feature-record.md`](descriptor/feature-record.md) + [`feature-signals.md`](descriptor/feature-signals.md)  
6. [`descriptor/labeled-corpus.md`](descriptor/labeled-corpus.md) + gold/sparse/broken/todo lists  
7. [`descriptor/emit.md`](descriptor/emit.md) — v1 emit pointer only  

## Non-goals (prototype)

- Parsing `.hkx`
- Overwriting gold or writing `animations/` before an explicit pass
- Deleting broken gold in-tree (handoff only)
- In-game editor / Papyrus / WebUI
- Full emit-profile fields in v1
