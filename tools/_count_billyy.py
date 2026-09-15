import json
from pathlib import Path

json_dir = Path(r"c:/Skyrim/dev/mods/Billyy's SLAL Animations 10.5/SLAnims/json")
files = {
    "Human": "Billyy_Human.json",
    "HumanDD": "Billyy_HumanDD.json",
    "Furniture": "Billyy_HumanFurniture.json",
    "FurnitureDD": "Billyy_HumanFurnitureDD.json",
    "FurnitureInvis": "Billyy_HumanFurnitureInvis.json",
    "Lesbian": "Billyy_HumanLesbian.json",
    "LesbianDD": "Billyy_HumanLesbianDD.json",
    "Gangbang": "Billyy_HumanGangbang.json",
    "Orgy": "Billyy_HumanOrgy.json",
}
counts = {}
human_ids = set()
for k, fn in files.items():
    p = json_dir / fn
    with open(p, encoding="utf-8") as f:
        data = json.load(f)
    anims = data.get("animations", data if isinstance(data, list) else [])
    counts[k] = len(anims)
    if k == "Human":
        for a in anims:
            if isinstance(a, dict):
                human_ids.add(str(a.get("id", a.get("name", ""))).lower())

extra = sum(v for k, v in counts.items() if k != "Human")
print("JSON counts:", counts)
print("Human total:", counts.get("Human"))
print("Extra total (non-Human):", extra)
print("Grand total:", sum(counts.values()))

anim_dir = Path(r"c:/Skyrim/dev/mods/SkyrimNet_SexLab/SKSE/Plugins/SkyrimNet_SexLab/animations")
stems = {f.stem.lower(): f.name for f in anim_dir.rglob("*.json")}
matched = [sid for sid in sorted(human_ids) if sid in stems]
unmatched = [sid for sid in sorted(human_ids) if sid not in stems]
print("Human ids count:", len(human_ids))
print("Matched stems:", len(matched))
print("Unmatched ids:", len(unmatched))

# Check specific samples
for sample in ["b_b_fj", "b_b_fmaststaff"]:
    print(f"  {sample}: in stems={sample in stems}, in human_ids={sample in human_ids}")

orphan_files = sorted(n for s, n in stems.items() if s not in human_ids)
billyy_orphans = [n for n in orphan_files if "billyy" in n.lower() or "goodprovider" in n.lower()]
print("Total json files under animations:", len(stems))
print("Orphan stems (not in human ids):", len(orphan_files))
print("Billyy/GoodProvider orphan samples:", billyy_orphans[:20])
