# Feature signals

Map from parsed fields to description cues. Animation-wide fields set the core sentence; per-stage fields are the only **observed** reason to change wording. Heuristic stage arcs are `heuristic_arc` on the [feature dump](feature-record.md) only, not in anidata. See [stages.md](stages.md).

## Animation-wide

| Field | Where | Cue |
|-------|--------|-----|
| `name` | SLAL | Human-readable pose/act summary after stripping `Billyy `. Highest-precision short label. |
| `tags` | SLAL CSV | Activity, position, composition, tone, climax. Ignore author tag `Billyy`. See [tag-glossary.md](tag-glossary.md). |
| `actors.length` | SLAL | Solo vs pair. Human pack is 1 or 2 only. |
| `actors[i].type` | SLAL | `Female` / `Male` at position `i` → `{{sl.actors.i}}` role. |
| `sound` | SLAL | `Squishing` wet/penetrative or masturbation; `Sucking` oral; `none` quiet / non-sex or spanking. |
| `add_cum` | actor | Climax target on that actor (JSON int; source enum). |

### `add_cum` (Human pack)

Source named enum; JSON int. Observed values only 1–3:

| JSON | Source enum | Count | Typical tags |
|------|-------------|-------|--------------|
| `1` | `Vaginal` | 44 | `Vaginal`, `Creampie` |
| `2` | `Oral` | 23 | `Blowjob`, `CumInMouth` |
| `3` | `Anal` | 9 | `Anal`, `AnalCreampie` |

SLAL also allows combined enums (`VaginalOral`, …) and `"none"`; unused here.

Use for last-stage climax wording and for `orgasm_expected` defaults in [emit.md](emit.md). Do not describe cum on actors without `add_cum` unless tags are `AirCum` / `Facial` / `FeetCum` / similar (often the male climax is in the air, not `add_cum` on the female).

## Per-stage (observed)

| Field | Cue | Do not |
|-------|-----|--------|
| `open_mouth` | Mouth open; oral contact likely if tags include Oral/Blowjob/Kissing | Assume blowjob from this flag alone (SpankDog stage 2 is biting) |
| `silent` | Log only | Map to `_gagged_` or emit `[]` as “silent” ([emit.md](emit.md)) |
| `strap_on` | Mention only if it **toggles** or tags imply pegging / Femdom strap-on | Narrate on the ~100/117 Human anims where it is a static male mesh flag |
| `sos` | Schlong scale; `sos: -9` with `strap_on: false` often means hidden/soft (spanking, kissing) | Narrate numeric scale |
| `object` / FNIS names | Named prop in that stage | Invent props not in the list |
| Meta `sound` | Stage-local sound vs animation default (e.g. oral stage 1 `none` then `Sucking`) | Treat as a new pose |

## Tags → sentence slots

Pick one primary **act** and one primary **pose**. Prefer `name` when it already names both.

When tags stack (`B_B_Doggy1`: Doggy+Thighjob+Vaginal; `B_Billyy_LegUp`: Vaginal+Handjob+Kissing):

1. Pose: first hit in `name`, else first pose tag in the pose row below.
2. Act: first hit in `name`, else first of this order: `Facefuck`, `Blowjob`/`Oral`, `Cunnilingus`, `Rimjob`, `69`, `Handjob`, `Footjob`, `Boobjob`/`Titfuck`, `Thighjob`, `Fingering`, `Spanking`, `Kissing`, `Masturbation`, `Anal`, `Vaginal`.
3. Extra tagged acts: one trailing clause, not a second primary.

Sanitize SLAL `name` typos (`Masutrbation`) — use tags, do not copy the typo.

| Slot | Example tags |
|------|----------------|
| Pose | `Standing`, `Kneeling`, `Laying`, `Sitting`, `Squatting`, `Doggy`/`DoggyStyle`, `Cowgirl`, `Missionary`, `Lotus`, `Spooning`, `Crab`, `Prone`, `Behind` |
| Act | `Vaginal`, `Anal`, `Blowjob`, `Handjob`, `Footjob`, `Boobjob`/`Titfuck`, `Cunnilingus`, `Fingering`, `Masturbation`, `Kissing`, `Spanking`, `Thighjob`, `Rimjob`, `69`, `Facefuck` |
| Tone | `Loving`, `Rough`, `Dirty`, `Forced`, `Femdom`, `Discipline`, `Foreplay` |
| Climax | `Creampie`, `AnalCreampie`, `CumInMouth`, `AirCum`, `Facial`, `FeetCum`, `ChestCum`, `HandCum` |
| Composition | `Solo`, `MF`, `Straight` (Human pack has no 3p) |

`Sex` is nearly universal (112/117); skip it in prose. `Object` + `Staff` / `Mug` → name the prop from [anim-objects.md](anim-objects.md).

## Signals that are weak or unused

| Signal | Note |
|--------|------|
| Stage event `id` string | Redundant with registrar + index; abbreviations inside ids are less reliable than `name` |
| `animvars` / FNIS `-AVb…` | Foot IK disable; not prose |
| `.hkx` filename | Out of scope |
| Gold description | Eval / few-shot only; not an input feature at emit time |

## SpankDog (gap check)

Observed: tags `Spanking,Doggy,Kneeling,Foreplay`; female `open_mouth` on stage 2 and `silent` on stage 5; male `silent` + `sos: -9` all stages; sound `none`.

Gold: over-the-knee caress → kneel spank → over-the-knee hard slaps → self-caress → kneel spank. **Not recoverable from SLAL.** Template stays spanking + kneeling/doggy + mouth-open on stage 2 ([templates.md](templates.md)). LLM few-shot may still copy the gold choreography.
