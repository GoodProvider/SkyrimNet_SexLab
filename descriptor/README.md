# Stage descriptor prototype

Offline work toward generating per-stage SexLab descriptions from SLAL animation files. First slice: **Billyy Human** (117 animations).

**Status:** Markdown contracts and gold/SLAL lists are in this tree. C++ is specified, not built. No writes under `SKSE/Plugins/SkyrimNet_SexLab/animations/`.

**Runtime status (SkyrimNet_SexLab):** missing stage descriptions use Papyrus tags (`GetDescriptionFromTags`) after authored anidata. HKX AniDescriber fill is **on hold** (source in `SKSE_Source/` but not wired into `GetStageDescription`). Offline SLAL→anidata prototype docs below are unchanged.

Hybrid writer (locked): templates stay SLAL-honest; optional LLM refine may imitate gold style and pose detail; template draft is fallback. See [plan.md](plan.md) and [pipeline.md](pipeline.md).

## Read order

1. [plan.md](plan.md) — goal, hybrid pipeline, later C++, eval, non-goals
2. [sources.md](sources.md) — paths and join key
3. [slal-directories.md](slal-directories.md) — sibling `*SLAL*` packs and gold join counts
4. [how-to-read-animation.md](how-to-read-animation.md) — SLAL JSON, source `.txt`, FNIS list
5. [stages.md](stages.md) — stage model and what text can honestly change
6. [feature-signals.md](feature-signals.md) — field → description cue
7. [feature-record.md](feature-record.md) — dump JSON for later C++
8. [overview-human.md](overview-human.md) + [inventory-human.md](inventory-human.md) — this slice
9. [labeled-corpus.md](labeled-corpus.md) — gold labels, join, few-shot vs eval
10. [animations-gold.md](animations-gold.md) — few-shot pool (pointers only)
11. [animations-sparse.md](animations-sparse.md) — missing stages (skip training)
12. [animations-broken.md](animations-broken.md) — handoff to remove invalid gold
13. [animations-todo.md](animations-todo.md) — Human label priority
14. [emit.md](emit.md) — anidata 3.0 output (pointer, not a second contract)
15. [pipeline.md](pipeline.md) — extract → templates → LLM → fallback
16. [templates.md](templates.md) — honest template vs gold (honesty baseline)

Supporting vocab: [tag-glossary.md](tag-glossary.md), [anim-objects.md](anim-objects.md).

## Done / next / later

| Done | Next (not this pass) | Later |
|------|----------------------|-------|
| Human inventory, parse notes, gold join, emit pointer | C++23 CLI: parse Human + feature dump + template texts | LLM refine; schema-validate emit; other Billyy JSON |
| Gold quality lists (broken / sparse / eligible / todo) | Review dump before LLM | Ship generated JSON under `animations/` for AnimDB to **consume** |

Do not parse SLAL inside `AnimationDB::LoadAnimJson`. That function already loads anidata.

## Known limits

- SLAL has no pose deltas. `B_B_SpankDog` is the HKX-gap example. Templates stay honest; the LLM may still copy gold choreography.
- Anidata has no silent token. `[]` means speaks normally. v1 maps spanking/whipping to `_pain_` and mouth obstruction to `_gagged_`; SLAL `silent` is logged only.
- Human gold is sparse: 5 files have every SLAL stage labeled **and** actor tokens. Empty stubs and invented-prop files are [animations-broken.md](animations-broken.md).
- Billyy pack path contains an apostrophe (`Billyy's SLAL Animations 10.5`). Quote it on the CLI. The pack is a sibling directory, not in git.

Normative runtime contract stays in [docs/developers/anidata-schema.md](../docs/developers/anidata-schema.md). Do not duplicate it here.
