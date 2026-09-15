# Broken gold (handoff)

Invalid or empty labeled JSON under [SKSE/Plugins/SkyrimNet_SexLab/animations/](../SKSE/Plugins/SkyrimNet_SexLab/animations/). **Do not delete in this pass.** Maintainer removes or rewrites later.

Missing stages are **not** broken — see [animations-sparse.md](animations-sparse.md).

Empty `description` is absent at consume time. A stage key with `""` does not count as a label.

Scan: whole gold tree (346 files). Invented-prop check vs SLAL is Billyy Human–joined only unless the filename/tags already name the furniture (yoke anims in other Billyy JSON are not Human-pack errors).

## Empty or stub

| File | Problem |
|------|---------|
| `GoodProvider/AP Skull Fuck.json` | `"version": "3.0"` only, no stages |
| `GoodProvider/Billyy Footjob.json` | version only (display-name orphan for Human `B_B_FJ`) |
| `GoodProvider/B_B_Cowgirl1.json` | `stage 1.description` is `""` |
| `GoodProvider/B_B_LayBJDog.json` | version only (Human registrar match, no text) |
| `GoodProvider/Mitos Female Facedom.json` | version only |
| `YamahaFJR1300/B_B_SpoonA.json` | version only (duplicate stem; GoodProvider file is sparse, not this stub) |

## Missing actor tokens

Non-empty text but no `{{sl.actors.N}}` in any stage. Unusable as few-shot style.

| File | Non-empty stages |
|------|------------------|
| `GoodProvider/B_B_FMast4.json` | 1–5 (Human complete labels otherwise) |
| `GoodProvider/B_Billyy_ChairDildo.json` | 1–5 |
| `GoodProvider/B_B_BSoloF1.json` | 1–6 |
| `GoodProvider/B_B_CLayBA.json` | 1–2 |
| `GoodProvider/B_B_LCFingMiss.json` | 1–5 |
| `GoodProvider/B_B_LYFingSit.json` | 1–5 |
| `GoodProvider/FB_MolagWildDoggy.json` | 1, 4 |

## Invented prop vs Billyy Human SLAL

| File | Problem |
|------|---------|
| `GoodProvider/B_B_Stand.json` | Gold says “yoke”. Human SLAL tags/objects for `B_B_Stand` are standing vaginal only (no furniture). |

Yoke in `B_Billyy_Yoke*.json` / `B_B_Y*.json` is expected for furniture/DD packs, not listed here.

## Parse

0 unreadable JSON files in this scan.
