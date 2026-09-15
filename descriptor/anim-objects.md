# Anim objects (Billyy Human)

SLAL JSON does **not** list anim objects. Read them from source `object=` or FNIS trailing names. This pack has two object animations.

## Objects observed

| FNIS / source name | Animation | Stages | Prose |
|--------------------|-----------|--------|-------|
| `AO_BStaff2` | `B_B_FMastStaff` | 1–6 | Staff |
| `AOMBallMNodeR` | `B_B_FMastStaff` | 3–4 | Extra staff/magic node; mention only if describing extra attachments |
| `AO_BMCsA` | `B_B_FMastStaff` | 3–6 | Extra attachment on later stages |
| `AOMugB` | `B_B_MaleMMug` | 1–5 | Mug |

## FNIS lines

Staff (`-o` plus names after `.hkx`):

```text
s -o,AVbHumanoidFootIKDisable B_B_FMastStaff_A1_S1 B_FMastStaff_A1_S1.hkx AO_BStaff2
+ -o B_B_FMastStaff_A1_S3 B_FMastStaff_A1_S3.hkx AO_BStaff2 AOMBallMNodeR AO_BMCsA
```

Mug:

```text
s -o,AVbHumanoidFootIKDisable B_B_MaleMMug_A1_S1 B_MaleMMug_A1_S1.hkx AOMugB
```

## Template notes

- If `Object` is in tags but FNIS/source has no names, say “using a prop” and log.
- Do not pull furniture ids (`AOPillory`, yoke, stockade, furo tub) from other Billyy JSON packs into Human descriptions.
- `animvars` / `-AVbHumanoidFootIKDisable` is not an object.
