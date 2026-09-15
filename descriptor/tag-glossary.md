# Tag and id glossary (Billyy Human)

SexLab tags are a CSV string on the SLAL animation. Ids are compact; prefer `name` when decoding pose. This table is for this pack only.

## Skip in prose

`Billyy` (author), `Sex` (generic), `Straight`, `MF` (already implied by two human actors in this slice), `F` / `M` on solo (use `actors[].type`).

## Pose / body arrangement

| Tag or id token | Meaning |
|-----------------|--------|
| `Standing` / `Stand` | Standing |
| `Kneeling` / `Kneel` / `Kn` | Kneeling |
| `Laying` / `Lay` / `LY` | Lying down |
| `Sitting` / `Sit` | Sitting |
| `Squatting` / `Squat` / `Squatt` | Squatting |
| `Doggy` / `DoggyStyle` / `Dog` | All fours / from behind |
| `Cowgirl` / `CG` | Receiver on top, facing |
| `RCG` | Reverse cowgirl |
| `Missionary` / `Miss` | Receiver on back, partner between legs |
| `Mating` / `MatingP` | Mating press (missionary variant) |
| `Lotus` / `RevLotus` | Lotus / reverse lotus |
| `Spooning` / `Spoon` | Side-lying spoon |
| `Crab` | Crab / legs-up |
| `Prone` | Face down |
| `Behind` / `Beh` | Standing from behind |
| `Side` / `Sideways` | Sideways |
| `Nelson` / `Nel` | Full nelson |
| `Amazon` | Amazon cowgirl variant |
| `Hold` / `Holding` | Partner holding the other upright |
| `LegUp` | Leg raised |
| `Facesit` / `FaceSit` | Sitting on partner's face |
| `69` | 69 |

## Act

| Tag or id token | Meaning |
|-----------------|--------|
| `Vaginal` | Vaginal sex |
| `Anal` / trailing `A` on id (`MissA`, `StandA`) | Anal sex |
| `Blowjob` / `Oral` / `BJ` | Oral on penis |
| `Facefuck` / `FF` | Facefuck |
| `Handjob` / `HJ` / `FHJ` | Handjob (FHJ = finger + handjob) |
| `Footjob` / `FJ` / `Footfuck` | Footjob |
| `Boobjob` / `Titfuck` / `TitF` / `BoobJ` | Breast sex |
| `Cunnilingus` / `Cunn` | Oral on vulva |
| `Fingering` / `Finger` | Fingering |
| `Masturbation` / `FMast` / `Mast` | Solo or mutual masturbation |
| `Kissing` / `SKiss` | Kissing |
| `Spanking` / `Spank` | Spanking |
| `Thighjob` / `ThighF` / `ThighJ` | Thigh job |
| `Rimjob` / `RJ` | Rimjob |
| `Headpats` | Headpats (non-sex) |
| `Hugging` | Hugging |
| `Groping` | Groping |
| `Grinding` | Grinding (often no penetration yet) |

## Tone and climax

| Tag | Meaning |
|-----|--------|
| `Loving` | Gentle / affectionate |
| `Rough` / `Forced` | Rough |
| `Dirty` | Explicit / less romantic |
| `Femdom` | Female dominant |
| `Discipline` / `Fetish` | Spanking-adjacent |
| `Foreplay` | Setup; often non-penetrative |
| `Service` | Service-oriented |
| `Creampie` | Internal vaginal climax |
| `AnalCreampie` | Internal anal climax |
| `CumInMouth` | Oral climax |
| `AirCum` | External / no `add_cum` target |
| `Facial` | Facial |
| `FeetCum` / `ChestCum` / `BellyCum` / `ButtCum` / `BackCum` / `HandCum` / `BodyCum` / `WastedCum` | External target |

## Composition (Human pack)

| Tag | Meaning |
|-----|--------|
| `Solo` | One actor |
| `MF` | Male + female pair |
| `Object` | Uses an anim object (staff, mug) |

`3p` / `MMF` / `FFM` appear in other Billyy JSON files, not Human.

## Id decoding pitfalls

- Trailing `A` is anal (`MissA`) but `ArmG` / `Armgrab` is arm grab, not anal.
- `Dog` in `SpankDog` is doggy-adjacent spanking, not doggy penetration (`Doggy1` is).
- `S` prefix on `SKiss` / `SHeadpats` / `SThighF` is “standing” or “soft”, not stage.
- Source typos land in JSON `name` (`Masutrbation`). Do not copy typos into descriptions; use tags.
- Prefer `name` over id when they disagree (`B_Billyy_SpooningFacing` display name is `Billyy Laying Embrace OG`).
