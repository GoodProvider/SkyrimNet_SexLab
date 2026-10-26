"""Dev-time converter: SexLab AE built-in animations (sslAnimationDefaults.psc, sslCreatureAnimationDefaults.psc)
→ SLAL-format JSON that AnimDB's SlalLoader reads (SKSE/Plugins/SkyrimNet_SexLab/slal/SexLab_Builtin.json).

The game never runs SexLab code for this: the Papyrus source is parsed here and the result ships with the mod.
Registry id = the factory function name (RegisterAnimation("SexLabMissionary") → "SexLabMissionary"), as in
SexLab. AddPositionStage's own default is strapon=True (SLAL JSON leaves missing strap_on false), so every stage
writes strap_on explicitly. Bed offsets / cum sources are not carried over (SLAL does not have them either).

  python -I tools/sexlab_defaults_to_slal.py [--src <SexLab Scripts/Source>] [--out <json>]
"""

import argparse
import json
import os
import re
import sys

DEFAULT_SRC = r"C:\Skyrim\dev\mods\SexLabFrameworkAE\Scripts\Source"
DEFAULT_OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                           "SKSE", "Plugins", "SkyrimNet_SexLab", "slal", "SexLab_Builtin.json")

GENDER = {"male": "Male", "female": "Female", "creature": "Creature", "creaturemale": "CreatureMale",
          "creaturefemale": "CreatureFemale"}
CUM = {"vaginal": 1, "oral": 2, "anal": 3, "vaginaloral": 4, "vaginalanal": 5, "oralanal": 6,
       "vaginaloralanal": 7}
SOUND = {"squishing": "Squishing", "sucking": "Sucking", "sexmix": "SexMix", "squirting": "Squirting"}
STAGE_ARGS = ["forward", "side", "up", "rotate", "silent", "openmouth", "strapon", "sos"]


def split_args(s):
    out, cur, q, depth = [], "", False, 0
    for ch in s:
        if ch == '"':
            q = not q
        if not q and ch == "(":
            depth += 1
        if not q and ch == ")":
            depth -= 1
        if ch == "," and not q and depth == 0:
            out.append(cur.strip())
            cur = ""
        else:
            cur += ch
    if cur.strip():
        out.append(cur.strip())
    return out


def value(tok):
    tok = tok.strip()
    if tok.startswith('"') and tok.endswith('"'):
        return tok[1:-1]
    low = tok.lower()
    if low in ("true", "false"):
        return low == "true"
    try:
        return float(tok) if "." in tok else int(tok)
    except ValueError:
        return tok


def strip_comment(line):
    out, q = "", False
    for ch in line:
        if ch == '"':
            q = not q
        if ch == ";" and not q:
            break
        out += ch
    return out


def parse_file(path):
    text = open(path, encoding="utf-8", errors="replace").read()
    code = "\n".join(strip_comment(l) for l in text.splitlines())  # Papyrus: ';' comments, case-insensitive
    registered = re.findall(r'RegisterAnimation\(\s*"([^"]+)"', code, re.I)
    funcs = {}
    cur = None
    for raw in text.splitlines():
        line = strip_comment(raw).strip()
        m = re.match(r"function\s+(\w+)\s*\(\s*int\s+id\s*\)", line, re.I)
        if m:
            cur = {"id": m.group(1), "name": "", "sound": "none", "tags": "", "actors": [], "vars": {},
                   "timers": {}, "stage_sounds": {}}
            funcs[m.group(1)] = cur
            continue
        if cur is None:
            continue
        if re.match(r"endfunction", line, re.I):
            cur = None
            continue
        m = re.match(r'Base\.Name\s*=\s*"([^"]*)"', line, re.I)
        if m:
            cur["name"] = m.group(1)
            continue
        m = re.match(r"Base\.SoundFX\s*=\s*(\w+)", line, re.I)
        if m:
            cur["sound"] = SOUND.get(m.group(1).lower(), "none")
            continue
        m = re.match(r'Base\.SetTags\(\s*"([^"]*)"\s*\)', line, re.I)
        if m:
            cur["tags"] = (cur["tags"] + "," if cur["tags"] else "") + m.group(1)
            continue
        m = re.match(r"int\s+(\w+)\s*=\s*Base\.(AddPosition|AddCreaturePosition)\((.*)\)\s*$", line, re.I)
        if m:
            args = [value(a) for a in split_args(m.group(3))]
            actor = {"stages": []}
            if m.group(2).lower() == "addposition":
                g = str(args[0]).lower() if args else "male"
                actor["type"] = GENDER.get(g, "Male")
                cum = args[1] if len(args) > 1 else -1
            else:
                actor["race"] = args[0] if args else ""
                g = str(args[1]).lower() if len(args) > 1 else "creature"
                actor["type"] = GENDER.get(g, "Creature")
                if actor["type"] in ("Male", "Female"):
                    actor["type"] = "Creature" if actor["type"] == "Male" else "CreatureFemale"
                cum = args[2] if len(args) > 2 else -1
            if isinstance(cum, str):
                cum = CUM.get(cum.lower().split("=")[-1].strip(), -1)
            if actor["type"] in ("Female", "CreatureFemale") and isinstance(cum, int) and cum > 0:
                actor["add_cum"] = cum
            cur["vars"][m.group(1)] = len(cur["actors"])
            cur["actors"].append(actor)
            continue
        m = re.match(r"Base\.AddPositionStage\((.*)\)\s*$", line, re.I)
        if m:
            args = split_args(m.group(1))
            pos = cur["vars"].get(args[0].strip())
            if pos is None:
                print(f"WARN {cur['id']}: unknown position var {args[0]}", file=sys.stderr)
                continue
            st = {"id": value(args[1]), "forward": 0, "side": 0, "up": 0, "rotate": 0, "silent": False,
                  "openmouth": False, "strapon": True, "sos": 0}
            k = 0
            for a in args[2:]:
                if "=" in a:
                    key, v = a.split("=", 1)
                    st[key.strip().lower()] = value(v)
                else:
                    st[STAGE_ARGS[k]] = value(a)
                k += 1
            cur["actors"][pos]["stages"].append({
                "id": st["id"], "forward": st["forward"], "side": st["side"], "up": st["up"], "rotate": st["rotate"],
                "silent": bool(st["silent"]), "open_mouth": bool(st["openmouth"]), "strap_on": bool(st["strapon"]),
                "sos": st["sos"]})
            continue
        m = re.match(r"Base\.SetStageTimer\((.*)\)", line, re.I)
        if m:
            a = [value(x) for x in split_args(m.group(1))]
            if len(a) == 2:
                cur["timers"][int(a[0])] = float(a[1])
            continue
        m = re.match(r"Base\.SetStageSoundFX\((.*)\)", line, re.I)
        if m:
            a = split_args(m.group(1))
            if len(a) == 2:
                cur["stage_sounds"][int(value(a[0]))] = SOUND.get(a[1].strip().lower(), "none")
    return registered, funcs


def to_slal(fn, creature):
    anim = {"id": fn["id"], "name": fn["name"], "sound": fn["sound"], "tags": fn["tags"], "actors": []}
    for a in fn["actors"]:
        actor = {"type": a["type"], "stages": a["stages"]}
        if "race" in a:
            actor["race"] = a["race"]
        if "add_cum" in a:
            actor["add_cum"] = a["add_cum"]
        anim["actors"].append(actor)
    if creature:
        races = [a.get("race") for a in fn["actors"] if a.get("race")]
        anim["creature_race"] = races[0] if races else ""
    stages = sorted(set(fn["timers"]) | set(fn["stage_sounds"]))
    if stages:
        anim["stages"] = []
        for s in stages:
            e = {"number": s}
            if s in fn["timers"]:
                e["timer"] = fn["timers"][s]
            if s in fn["stage_sounds"]:
                e["sound"] = fn["stage_sounds"][s]
            anim["stages"].append(e)
    return anim


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--src", default=DEFAULT_SRC)
    ap.add_argument("--out", default=DEFAULT_OUT)
    a = ap.parse_args()
    anims = []
    for fname, creature in (("sslAnimationDefaults.psc", False), ("sslCreatureAnimationDefaults.psc", True)):
        path = os.path.join(a.src, fname)
        if not os.path.exists(path):
            print(f"skip missing {path}", file=sys.stderr)
            continue
        registered, funcs = parse_file(path)
        for reg in registered:
            fn = funcs.get(reg)
            if not fn or not fn["actors"]:
                print(f"WARN {fname}: RegisterAnimation({reg}) has no factory body", file=sys.stderr)
                continue
            anims.append(to_slal(fn, creature))
    os.makedirs(os.path.dirname(a.out), exist_ok=True)
    with open(a.out, "w", encoding="utf-8", newline="\n") as f:
        json.dump({"name": "SexLab_Builtin", "animations": anims}, f, indent=1)
        f.write("\n")
    print(f"wrote {len(anims)} animations to {a.out}")


if __name__ == "__main__":
    main()
