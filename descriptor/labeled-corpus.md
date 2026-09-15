# Labeled corpus (Billyy Human)

Gold stage text lives under [SKSE/Plugins/SkyrimNet_SexLab/animations/](../SKSE/Plugins/SkyrimNet_SexLab/animations/). Join and splits below are for **Billyy Human** (117 SLAL ids) only. Other packs: [slal-directories.md](slal-directories.md).

Style contract for generated text: [docs/developers/anidata-schema.md](../docs/developers/anidata-schema.md) §12 (`{{sl.actors.N}}`). Do not copy the rest of that schema here.

## Join

| Rule | Result |
|------|--------|
| Stem = SLAL `id` (case-insensitive) | **54** matched |
| Exact display `name` | **0** extra |
| Unmatched Human ids | **63** |

Providers among the 54: GoodProvider 47, YamahaFJR1300 5, Goncalo 1, Token 1. All 54 have `"version": "3.0"`.

If two gold files share a stem, prefer **GoodProvider**, then other providers alphabetically. Log the conflict. Do not merge stage texts.

Empty string descriptions do **not** count as labels.

### Matched gold shape

| Field | Among 54 |
|-------|----------|
| Non-empty `stage N.description` on at least one stage | 52 (`Cowgirl1` all-empty; `LayBJDog` version-only) |
| Complete SLAL `1..N` labeled | 6 (one of those, `FMast4`, has no actor tokens) |
| Few-shot eligible (complete + tokens, not broken) | **5** — [animations-gold.md](animations-gold.md) |
| Sparse | **45** — [animations-sparse.md](animations-sparse.md) |
| `{{sl.actors.N}}` in text | 51 among files with any non-empty text (`FMast4` is the Human complete miss) |
| `creator` / SNSL `tags` / `transitions` / `speaking_modifiers` / `clothed` | 0 |

Training signal is **description text**. Other 3.0 fields must be defaulted (see [emit.md](emit.md)).

### Display-name orphans (do not join for emit)

Emit filenames stay `<registrar>.json`. These gold stems are not Human ids:

| File | Closest Human id | Notes |
|------|------------------|-------|
| `GoodProvider/Billyy Footjob.json` | `B_B_FJ` | Version stub — [animations-broken.md](animations-broken.md) |
| `GoodProvider/Billyy Facesit Cunnilingus.json` | `B_B_FacesitCunn` | SLAL name is `Billyy Facesit Cunnilingus 1` |
| `GoodProvider/Billyy Kneeling Handjob 4 Cowgirl.json` | `B_B_HJ4Cow` | SLAL name is `Billyy Handjob 4 Cowgirl` |
| `YamahaFJR1300/Billyy Kneeling Handjob 5 Sitting Side.json` | `B_B_HJ5SitSide` | Same class of display-name file |

### Unmatched Human registrars (63)

See [animations-todo.md](animations-todo.md) (after sparse fill). Emit still runs; excluded from automatic eval.

## Gold style (LLM few-shot)

- Tokens, not names: `{{sl.actors.0}}`, `{{sl.actors.1}}`.
- Short present-tense sentences: pose, then act, then hands/props.
- Stage text describes the current picture, not “they continue”.
- Clothing stays out of the sentence (`clothed` field).

LLM few-shot **imitates gold style and pose detail** even when SLAL does not encode it. Templates do **not** ([templates.md](templates.md)).

Noise: SLAL `name` typos, mixed `he`/`she`, occasional actor-index mistakes (`Token/B_B_KneFF.json` stage 5). Do not copy pronouns into templates.

## Few-shot vs eval

| Set | Size | Use |
|-----|------|-----|
| Few-shot | 5 eligible files in [animations-gold.md](animations-gold.md) | LLM prompt examples |
| LLM eval | non-broken matched minus those 5 | LLM refine quality |
| Template eval | non-broken matched | Rule writer honesty + hard gates |
| Sparse | 45 | Eval on labeled keys only; not training |
| Broken | [animations-broken.md](animations-broken.md) | Handoff; exclude |
| Unmatched 63 | — | Smoke-scan only |

Score a gold `stage N` only when that key exists **and** description is non-empty. Do not penalize extra generated stages.

Do not overwrite gold files when comparing.
