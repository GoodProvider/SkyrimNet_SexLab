import json
from pathlib import Path
mods=Path(r"c:/Skyrim/dev/mods")
for stem in ["B_Can_B_Dog","B_Seek_B_TBehind","B_Drau_B_RCG"]:
    hits=[]
    for p in mods.rglob("*.json"):
        if p.stat().st_size>5_000_000: continue
        try:
            t=p.read_text(encoding="utf-8",errors="ignore")
        except: continue
        if stem in t:
            hits.append(str(p))
    print(stem, len(hits))
    for h in hits[:3]: print(" ",h)
