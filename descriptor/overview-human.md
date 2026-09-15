# Billyy Human overview

Slice: `Billyy_Human` from Billyy's SLAL Animations 10.5. Full row list: [inventory-human.md](inventory-human.md).

## Counts

| Metric | Value |
|--------|-------|
| Animations | 117 |
| Solo 1p (`##Solo 1p##`) | 11 |
| Pair 2p (`##Pair 2p##`) | 106 |
| Female actor slots | 111 |
| Male actor slots | 112 |
| Typical stage count | 5 (99); also 6 (16) and 7 (2) |

## Sound

| `sound` | Count | Typical act |
|---------|-------|-------------|
| `Squishing` | 88 | Vaginal/anal/masturbation/handjob |
| `Sucking` | 20 | Blowjob / facefuck / 69 / rimjob |
| `none` | 9 | Kissing, headpats, spanking, male solo |

Nine anims add animation-level `stages[].sound` overrides:

| Registrar | Default `sound` | Meta `stages[].sound` |
|-----------|-----------------|------------------------|
| `B_Billyy_SpooningFacing` | Squishing | 1 `none` |
| `B_Billyy_LayingBlowjob` | Sucking | 1 `none` |
| `B_B_LayingBJ2` | Sucking | 1–3 `none` |
| `B_B_KneelBJ2` | Sucking | 1 `none` |
| `B_B_MaleSitBJ` | Sucking | 1 `none` |
| `B_B_SquatBJ` | Sucking | 1 `none` |
| `B_B_KneFF` | Sucking | 1 `none` |
| `B_B_Lay693MT` | Sucking | 1 `Squishing` |
| `B_B_RJDog` | Sucking | 1 `none` |

## Flags (animations that use the flag on any stage)

| Flag | Anims |
|------|-------|
| `strap_on` true somewhere | 100 |
| `sos` present | 93 |
| `add_cum` on an actor | 76 |
| `open_mouth` | 30 |
| `silent` | 24 |

Objects in this pack: staff (`B_B_FMastStaff`) and mug (`B_B_MaleMMug`) only. [anim-objects.md](anim-objects.md).

## Tag frequencies (selected)

Every anim has `Billyy` (117). Almost all pair anims have `Straight` + `MF` (106). `Sex` is 112.

| Tag | Count | Tag | Count |
|-----|-------|-----|-------|
| Laying | 60 | Vaginal | 49 |
| Creampie | 45 | Standing | 33 |
| Kneeling | 28 | AirCum | 27 |
| Handjob | 26 | Loving | 23 |
| Oral / Blowjob | 19 / 19 | CumInMouth | 19 |
| Kissing | 18 | Cowgirl | 17 |
| Foreplay | 16 | Masturbation | 15 |
| Sitting | 13 | Solo | 11 |
| Rough / Femdom | 11 / 11 | Anal | 10 |
| Doggy | 10 | Cunnilingus | 9 |

Id abbreviations (`Miss`, `BJ`, `RCG`, …): [tag-glossary.md](tag-glossary.md).

## Gold coverage

54 / 117 join by registrar. 5 complete+tokened files are few-shot ([animations-gold.md](animations-gold.md)). 45 are sparse. 63 unmatched. [labeled-corpus.md](labeled-corpus.md).

## What this slice is good for

- Dense 2p MF tag vocabulary and 5-stage Billyy pacing
- Clear `name` strings that already describe pose + act
- Limited furniture (only two object anims) so Human is a clean first parser target

What it is not: 3p+, furniture/DD, lesbian-only, or creature. Those live in the other 10.5 JSON files listed in [sources.md](sources.md).
