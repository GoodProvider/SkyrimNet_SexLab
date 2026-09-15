# Stages

SexLab stages are 1-based. SLAL stores them as parallel arrays on each actor. Gold labels store optional `"stage N"` objects. Templates must fill **every** SLAL stage; gold may be sparse.

## Two `stages` arrays

| Array | Where | What it is |
|-------|--------|------------|
| Pose stages | `actors[i].stages[j]` | Clips SexLab plays. Length = stage count. |
| Meta stages | animation-level `stages[]` | Optional per-stage `sound` / `timer`. Billyy Human: 9 anims, mostly stage-1 `sound: none` on oral setups. |

Never treat meta `stages` as extra poses. Index pose stages with `j + 1`.

## Stage count (Billyy Human)

| Count | Animations |
|-------|------------|
| 5 | 99 |
| 6 | 16 |
| 7 | 2 |

All 117 anims have matching stage lengths across actors.

Event id convention: `{registrar}_A{actorNum}_S{stageNum}` with actor and stage 1-based (`A1` = `actors[0]`).

## What can change between stages

SLAL **does not** encode pose. Per-stage wording may change only when one of these differs from the previous stage:

| Signal | Typical prose effect |
|--------|----------------------|
| `open_mouth` added | Mouth occupied / oral contact starts |
| `open_mouth` removed | Mouth no longer forced open |
| `silent` added | Quiet / gagged-adjacent (do not emit `_gagged_` unless oral tags also apply; see [emit.md](emit.md)) |
| `sos` change | Anatomy visibility; usually skip in prose |
| `strap_on` change | Strap-on used or removed |
| `object=` / FNIS objects | Prop appears, extra attachments, or dropped |
| Animation-level `sound` | Stage 1 silent setup vs later wet/oral sound |

If none of those change, the template keeps the same core sentence. A mild last-stage climax clause is allowed when climax tags/`add_cum` exist. Record `heuristic_arc` on the [feature dump](feature-record.md) only — not in anidata.

| Stage position | Dump `heuristic_arc` (only if tags support it) |
|----------------|----------------------------------|
| First | `setup` when `Foreplay` or first-stage `sound: none` |
| Middle | `main` |
| Last | `climax` when `Creampie`, `CumInMouth`, `AirCum`, `AnalCreampie`, `Facial`, or `add_cum` is set |

Do not invent over-the-knee vs kneeling swaps, hand placement, or bindings. Gold often does; that is why `B_B_SpankDog` is the HKX-gap example in [how-to-read-animation.md](how-to-read-animation.md).

## Gold labels vs SLAL stages

Gold is sparse. Consumer carry-forward (empty current stage → last earlier text) is a **runtime** behavior in AnimDB, not a license for the prototype to omit stages.

Human registrar-matched gold (54 files). Empty `description` does not count.

| Non-empty gold vs SLAL `1..N` | Files |
|-------------------------------|-------|
| Broken (no usable text, or `FMast4` tokens / `Stand` yoke) | [animations-broken.md](animations-broken.md) |
| Sparse (some stages unlabeled) | 45 — [animations-sparse.md](animations-sparse.md) |
| Complete + tokens | 5 — [animations-gold.md](animations-gold.md) |

Six files have keys for all five SLAL stages; `B_B_FMast4` is complete text but missing `{{sl.actors.N}}`.

Eval compares generated `stage N` to gold only when gold has that key **and** a non-empty description. Missing gold stages are not penalties and are not “broken.”

## Actor index

`actors[0]` → `{{sl.actors.0}}`. In Billyy Human MF pairs this is Female, then Male. Solo 1p is a single Female or Male. Do not assume victim/aggressor beyond position 0 = first registered actor.
