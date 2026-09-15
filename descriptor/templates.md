# Template honesty examples

Templates stay **SLAL-honest**. Gold may be richer (LLM few-shot may imitate that). These rows are the honesty baseline for the rule writer, not copy-targets for ungrounded pose.

Worked SLAL: [how-to-read-animation.md](how-to-read-animation.md). Gold paths under `SKSE/Plugins/SkyrimNet_SexLab/animations/`.

## `B_B_SpankDog`

SLAL: tags `Spanking,Doggy,Kneeling,Foreplay,Discipline`; sound `none`; female `open_mouth` on stage 2, `silent` on stage 5; male `silent` + `sos: -9` all stages. No objects.

| Stage | Honest template (sketch) | Gold (do not require) |
|------:|--------------------------|------------------------|
| 1 | `{{sl.actors.1}} spanks {{sl.actors.0}} from behind while {{sl.actors.0}} kneels in a doggy stance.` | OTK, hand on back, biting a finger |
| 2 | Same core; `{{sl.actors.0}}`'s mouth is open. | Kneeling spank (no OTK) |
| 3–4 | Same core as 1 (no new flags). | OTK hard slaps / self-caress |
| 5 | Same core; do not narrate `silent` as gagged. | Kneeling spank again |

## `B_B_FMast1`

SLAL: solo female; tags `Masturbation,Standing,Kneeling,Vaginal,Anal`; sound `Squishing`; 5 stages. Gold skips stage 2.

| Stage | Honest template (sketch) | Gold (do not require) |
|------:|--------------------------|------------------------|
| 1 | `{{sl.actors.0}} masturbates, standing or kneeling (name: F Masturbation 1).` | Standing, arm across chest, fingering |
| 2 | Same core (no flag change). | (unlabeled) |
| 3–5 | Same core; last stage may add a climax clause (`add_cum` if set). | Kneeling / head to floor / prone — not in SLAL flags |

## `B_B_CGLay`

SLAL: pair; tags `Cowgirl,Laying,Creampie,Vaginal`. Gold has one non-empty stage (sparse — not a few-shot file).

| Stage | Honest template (sketch) | Gold |
|------:|--------------------------|------|
| 1–5 | `{{sl.actors.0}} rides {{sl.actors.1}} while {{sl.actors.1}} lies on their back.` Last stage may mention creampie from tags/`add_cum`. | Stage 1 only: laying cowgirl; close to SLAL |

`strap_on` is true on most Human males; do not mention it unless it toggles or tags imply pegging.
