# How to read animation files

Three file kinds describe one Billyy Human animation. The game registers from SLAL JSON. Source `.txt` and FNIS lists keep objects and flags that JSON generation drops.

Worked registrar throughout: `B_B_SpankDog` (display name `Billyy Spanking Doggy`).

## Join key

| Layer | Field | Example |
|-------|-------|---------|
| Source `.txt` | `id=` plus `anim_id_prefix("B_")` | `id="B_SpankDog"` → JSON `B_B_SpankDog` |
| SLAL JSON | `id` | `B_B_SpankDog` |
| SexLab | registry / `sslBaseAnimation.Registry` | `B_B_SpankDog` |
| FNIS comment | `' {registrar}` | `' B_B_SpankDog` |
| Gold anidata | filename stem | `B_B_SpankDog.json` |
| Per-actor stage event | `{id}_A{actor}_S{stage}` | `B_B_SpankDog_A1_S2` |

Display `name` is not unique and is not the join key. See [sources.md](sources.md).

## 1. SLAL JSON (`SLAnims/json/Billyy_Human.json`)

Category file:

```json
{ "name": "Billyy_Human", "animations": [ /* 117 objects */ ] }
```

Each animation object (keys observed in this pack):

| Key | Type | Role |
|-----|------|------|
| `id` | string | Registrar |
| `name` | string | MCM / SexLab display name |
| `tags` | string | CSV SexLab tags; trailing comma common |
| `sound` | string | Default: `Squishing`, `Sucking`, `none` |
| `actors` | array | SexLab position order = `{{sl.actors.N}}` |
| `stages` | array | Optional **animation-level** sound/timer overrides, not pose stages |

Actor object:

| Key | Type | Role |
|-----|------|------|
| `type` | string | `Female` or `Male` in Human pack |
| `stages` | array | Pose stages; length is stage count |
| `add_cum` | int | Cum target on this actor (see [feature-signals.md](feature-signals.md)) |

Per-actor stage object:

| Key | Type | Role |
|-----|------|------|
| `id` | string | Animation event id |
| `open_mouth` | bool | Oral / mouth-open cue |
| `silent` | bool | Suppress vocalizations |
| `sos` | int | Schlongs of Skyrim scale |
| `strap_on` | bool | Strap-on mesh this stage |

Loader also supports `forward` / `side` / `up` / `rotate`; unused in Billyy Human JSON.

Animation-level stage object (`animation.stages[]`):

| Key | Type | Role |
|-----|------|------|
| `number` | int | 1-based stage |
| `sound` | string | Override default sound |
| `timer` | float | Auto-advance; not used in this pack |

Stage count = `len(actors[0].stages)`. SLAL expects every actor to have the same length.

`B_B_SpankDog` in JSON (abbreviated):

```json
{
  "id": "B_B_SpankDog",
  "name": "Billyy Spanking Doggy",
  "sound": "none",
  "tags": "Billyy,Straight,MF,Doggy,Dirty,Kneeling,Spanking,Foreplay,Discipline,Fetish,",
  "actors": [
    {
      "type": "Female",
      "stages": [
        { "id": "B_B_SpankDog_A1_S1" },
        { "id": "B_B_SpankDog_A1_S2", "open_mouth": true },
        { "id": "B_B_SpankDog_A1_S3" },
        { "id": "B_B_SpankDog_A1_S4" },
        { "id": "B_B_SpankDog_A1_S5", "silent": true }
      ]
    },
    {
      "type": "Male",
      "stages": [
        { "id": "B_B_SpankDog_A2_S1", "silent": true, "sos": -9, "strap_on": false },
        { "id": "B_B_SpankDog_A2_S2", "silent": true, "sos": -9, "strap_on": false },
        { "id": "B_B_SpankDog_A2_S3", "silent": true, "sos": -9, "strap_on": false },
        { "id": "B_B_SpankDog_A2_S4", "silent": true, "sos": -9, "strap_on": false },
        { "id": "B_B_SpankDog_A2_S5", "silent": true, "sos": -9, "strap_on": false }
      ]
    }
  ]
}
```

What JSON does **not** say: over-the-knee vs kneeling, biting a finger, hand placement. Gold [GoodProvider/B_B_SpankDog.json](../SKSE/Plugins/SkyrimNet_SexLab/animations/GoodProvider/B_B_SpankDog.json) describes those pose changes anyway. Templates cannot recover them from SLAL.

## 2. Source DSL (`SLAnims/source/Billyy_Human.txt`)

Python-like input to SLAnimGenerate. Not loaded at runtime. The prototype **must not eval** this as Python. Scan for `id=`, `name=`, `tags=`, `Stage(n, object="…")`, actor `object=`. Unknown syntax: log and skip. FNIS remains the object cross-check.

File header:

```text
mcm_name = "Billyy_Human"
anim_dir("Billyy_Human")
anim_id_prefix("B_")
anim_name_prefix("Billyy ")
common_tags("Billyy")
```

Prefix rules:

- JSON `id` = `anim_id_prefix` + source `id` → `B_` + `B_SpankDog` = `B_B_SpankDog`
- JSON `name` = `anim_name_prefix` + source `name` → `Billyy Spanking Doggy`
- JSON `tags` prepend `common_tags`

Section headers in this pack: `##Solo 1p##` (11 anims) then `##Pair 2p##` (106).

Per-animation extras **dropped from JSON**:

| Source field | Example | Use |
|--------------|---------|-----|
| `Stage(n, object="…")` | `object="AO_BStaff2"` | Prop / furniture in descriptions |
| `animvars=` | `AVbHumanoidFootIKDisable` | Technical; skip in prose |
| Actor `object=` | furniture packs | Later slices |

`add_cum` is a named enum in source (`Vaginal`, `Oral`, `Anal`) and an int in JSON (1, 2, 3 in this pack).

## 3. FNIS list (`FNIS_Billyy_Human_List.txt`)

```text
' B_B_FMastStaff
s -o,AVbHumanoidFootIKDisable B_B_FMastStaff_A1_S1 B_FMastStaff_A1_S1.hkx AO_BStaff2
+ -o B_B_FMastStaff_A1_S3 B_FMastStaff_A1_S3.hkx AO_BStaff2 AOMBallMNodeR AO_BMCsA
```

| Token | Meaning |
|-------|---------|
| `' {id}` | Comment = registrar |
| `s` | Start of an actor block |
| `+` | Next stage, same actor |
| `-o` | Objects follow the `.hkx` |
| `-AVb…` | Animation variable (from `animvars`) |
| event id | Matches SLAL stage `id` |
| `*.hkx` | Havok clip (out of scope) |
| trailing names | Anim objects |

Human-pack objects are only staff and mug. See [anim-objects.md](anim-objects.md).

## Merge order for the prototype

1. Parse JSON → canonical animation + per-stage flag matrix.
2. Overlay source `object=` onto `(actor, stage)` if present.
3. Overlay FNIS trailing objects; log conflicts.
4. Join gold by registrar stem for eval only.

Do not parse `.hkx` in v1. Do not eval the source file as Python.
