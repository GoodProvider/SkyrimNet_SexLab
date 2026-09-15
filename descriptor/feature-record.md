# Feature record (dump contract)

Normalized extract written by a later C++ `--dump`. Not anidata. Not a copy of SLAL JSON.

`feature_record_version`: `1`.

## Files (`--out` directory)

| File | Contents |
|------|----------|
| `<registrar>.features.json` | Feature record below |
| `<registrar>.template.json` | `{"stage 1": "…", …}` template strings only |

Do not write under `SKSE/Plugins/SkyrimNet_SexLab/animations/` in that milestone.

## Shape

```json
{
  "feature_record_version": 1,
  "registrar": "B_B_SpankDog",
  "name": "Billyy Spanking Doggy",
  "slal_json": "Billyy_Human.json",
  "tags": ["Straight", "MF", "Doggy", "Dirty", "Kneeling", "Spanking", "Foreplay", "Discipline", "Fetish"],
  "sound": "none",
  "actors": [
    {"index": 0, "type": "Female", "add_cum": null},
    {"index": 1, "type": "Male", "add_cum": null}
  ],
  "primary_pose": "Doggy",
  "primary_act": "Spanking",
  "stages": [
    {
      "index": 1,
      "heuristic_arc": "setup",
      "meta_sound": null,
      "objects": [],
      "actors": {
        "0": {"open_mouth": false, "silent": false, "sos": null, "strap_on": false},
        "1": {"open_mouth": false, "silent": true, "sos": -9, "strap_on": false}
      }
    }
  ]
}
```

`heuristic_arc` is `setup` | `main` | `climax` | `none`. It lives **only** on this dump. Do not put it in anidata 3.0.

Omit author tag `Billyy` from `tags`. `primary_*` follow [feature-signals.md](feature-signals.md).

## Required per-stage actor flags

`open_mouth`, `silent`, `sos` (nullable), `strap_on`, plus `objects` (FNIS preferred over source on conflict).
