# Sources

Paths and identity rules for the Billyy Human slice. Relative paths are from the SkyrimNet_SexLab repo root unless noted.

## Input paths

Pack root (sibling of this repo, **not in git**): `../Billyy's SLAL Animations 10.5/`

The folder name contains an apostrophe and spaces. Quote the whole path on the CLI (`--slal "…/Billyy's SLAL Animations 10.5/SLAnims/json/Billyy_Human.json"`). Other sibling packs: [slal-directories.md](slal-directories.md).

| Kind | Path |
|------|------|
| SLAL JSON | `../Billyy's SLAL Animations 10.5/SLAnims/json/Billyy_Human.json` |
| Source DSL | `../Billyy's SLAL Animations 10.5/SLAnims/source/Billyy_Human.txt` |
| FNIS list | `../Billyy's SLAL Animations 10.5/meshes/actors/character/animations/Billyy_Human/FNIS_Billyy_Human_List.txt` |
| Gold labels | `SKSE/Plugins/SkyrimNet_SexLab/animations/<provider>/<registrar>.json` |

## Later Billyy 10.5 JSON (not inventoried here)

| JSON | Anim count (from pack scan) |
|------|-----------------------------|
| `Billyy_HumanDD.json` | 60 |
| `Billyy_HumanFurniture.json` | 19 |
| `Billyy_HumanFurnitureDD.json` | 11 |
| `Billyy_HumanFurnitureInvis.json` | 43 |
| `Billyy_HumanLesbian.json` | 31 |
| `Billyy_HumanLesbianDD.json` | 14 |
| `Billyy_HumanGangbang.json` | 32 |
| `Billyy_HumanOrgy.json` | 20 |

Human 117 + these 230 = 347 in the 10.5 pack.

## Prefixes (Human source header)

```text
anim_id_prefix("B_")
anim_name_prefix("Billyy ")
common_tags("Billyy")
```

| Source | JSON |
|--------|------|
| `id="B_FMast1"` | `id`: `B_B_FMast1` |
| `name="F Masturbation 1"` | `name`: `Billyy F Masturbation 1` |
| `tags="Sex,Solo,…"` | `tags`: `Billyy,Sex,Solo,…` |

A few Human ids already contain `Billyy` (`B_Billyy_LegUp`, `B_Billyy_SpooningFacing`, `B_Billyy_LayingBlowjob`). Those are still the registrar; do not strip the extra `Billyy`.

## Join to gold

Normative lookup: [docs/developers/anidata-schema.md](../docs/developers/anidata-schema.md) §2.

1. Prefer filename stem = SLAL `id` (case-insensitive).
2. Display-name `.json` is a consumer fallback only; this prototype does **not** join on display name unless a later pass builds an explicit name map.
3. Provider folder (`GoodProvider`, `Token`, `Goncalo`, `YamahaFJR1300`) is grouping. If two files share a stem, log a conflict; do not merge. Eval prefers `GoodProvider`, then other providers alphabetically.
4. `_local_` is player override at runtime. Out of scope for training/eval (no `_local_` pack in repo).

Human result: **54 / 117** join by registrar; **0** extra hits by exact display name. Near-miss display-name files (`Billyy Footjob.json` vs `B_B_FJ` / name `Billyy Footjob Laying`) stay unmatched. Details: [labeled-corpus.md](labeled-corpus.md).

## Out of scope paths

| Path | Why |
|------|-----|
| `animations/_local_/` | Player edits; last-wins at runtime |
| `*.hkx` under `meshes/…/Billyy_Human/` | Pose analysis later |
| Other mods' `SLAnims/json` | Not Human inventory; paths/join counts only in [slal-directories.md](slal-directories.md) |
