"""Offline mirror of SKSE_Source/src/SlalLoader.cpp for checking AnimDB's SLAL registry without the game.

Resolves the MO2 virtual Data folder from a profile's modlist.txt (+ game Data + overwrite), then parses the same
sources the C++ loader reads: SLAnims/json/*.json, SKSE/Plugins/SkyrimNet_SexLab/slal/*.json, FNIS lists under
meshes/actors/**/animations/<pack>/FNIS_*_List.txt and SKSE/Plugins/ppa-animation-tagging/*.json.

  python -I tools/slal_offline.py stats
  python -I tools/slal_offline.py dump b_b_skiss1
  python -I tools/slal_offline.py parity <animationdb.sql copied before the SLAL registry>

SexLab P+ (SLSB scene packs, mirror of SlsbLoader.cpp): SKSE/SexLab/Registry/Source/*.slsb.json + the same FNIS lists.

  python -I tools/slal_offline.py --source slsb --profile "SkyrimNet SexLab P+" --enable "Automated SLSB Conversions 0.9d" stats
  python -I tools/slal_offline.py --source slsb dump <scene id>
  python -I tools/slal_offline.py --source slsb parity <animationdb.sql built by the P+ Papyrus walk>

Keep the derivation rules in step with SlalLoader.cpp / SlsbLoader.cpp (docs/developers/anim-engine.md).
"""

import argparse
import json
import os
import sqlite3
import sys

DEV = r"C:\Skyrim\dev"


def vfs_index(profile, mods_dir, game_data, overwrite, force_enable=()):
    """lower relative path -> real path, MO2 priority (overwrite > mods top of modlist > game Data).
    force_enable: mod folders treated as enabled at the highest mod priority (a profile set up for another framework)."""
    roots = [game_data]
    modlist = os.path.join(DEV, "profiles", profile, "modlist.txt")
    enabled = []
    with open(modlist, encoding="utf-8", errors="replace") as f:
        for line in f:
            line = line.rstrip("\r\n")
            if line.startswith("+"):
                enabled.append(line[1:])
    roots += [os.path.join(mods_dir, m) for m in reversed(enabled)]  # modlist.txt lists highest priority first
    roots += [os.path.join(mods_dir, m) for m in force_enable]
    roots.append(overwrite)
    index = {}
    wanted = (
        "slanims/json/",
        "skse/plugins/skyrimnet_sexlab/slal/",
        "skse/plugins/ppa-animation-tagging/",
        "meshes/actors/",
        "skse/sexlab/registry/",
    )
    for root in roots:
        if not os.path.isdir(root):
            continue
        for sub in ("SLAnims/json", "SKSE/Plugins/SkyrimNet_SexLab/slal", "SKSE/Plugins/ppa-animation-tagging", "meshes/actors",
                    "SKSE/SexLab/Registry"):
            base = os.path.join(root, sub)
            if not os.path.isdir(base):
                continue
            for dirpath, _dirs, files in os.walk(base):
                for fn in files:
                    full = os.path.join(dirpath, fn)
                    rel = os.path.relpath(full, root).replace("\\", "/")
                    lrel = rel.lower()
                    if lrel.startswith(wanted):
                        index[lrel] = (rel, full)
    return index


def lower(s):
    return s.lower()


def gender_of(t):
    return {"Female": 1, "Creature": 2, "CreatureMale": 2, "CreatureFemale": 3}.get(t, 0)


CUM = {"Vaginal": 1, "Oral": 2, "Anal": 3, "VaginalOral": 4, "VaginalAnal": 5, "OralAnal": 6, "VaginalOralAnal": 7}


def cum_of(actor):
    v = actor.get("add_cum")
    if isinstance(v, bool) or v is None:
        return -1
    if isinstance(v, int):
        return v
    if isinstance(v, str):
        return CUM.get(v, -1)
    return -1


def parse_fnis(index):
    fnis = {}
    kinds = {"b", "s", "+", "o", "so", "fu", "fuo", "ofa", "pa", "km", "ch", "sa", "se", "^"}
    lists = sorted(
        k for k in index
        if k.startswith("meshes/actors/")
        and k.rsplit("/", 1)[-1].startswith("fnis_")
        and k.endswith("_list.txt")
        and k.split("/")[-3] == "animations"
    )
    for k in lists:
        rel, full = index[k]
        rel_dir = rel.rsplit("/", 1)[0]
        with open(full, encoding="utf-8", errors="replace") as f:
            for line in f:
                t = line.strip()
                if not t or t[0] == "'":
                    continue
                tok = t.split()
                if len(tok) < 3 or tok[0].lower() not in kinds:
                    continue
                i = 1
                animvars, acyclic = [], False
                if tok[1].startswith("-"):
                    for opt in tok[1][1:].split(","):
                        if len(opt) > 2 and opt[:2].lower() == "av":
                            animvars.append(opt[2:])
                        elif opt == "a":
                            acyclic = True
                    i = 2
                if i + 1 >= len(tok) or not tok[i + 1].lower().endswith(".hkx"):
                    continue
                hkx = rel_dir + "/" + tok[i + 1].replace("\\", "/")
                ev = tok[i].lower()
                if ev not in fnis:
                    fnis[ev] = {"kind": tok[0], "hkx": hkx, "objects": tok[i + 2:], "animvars": animvars,
                                "acyclic": acyclic, "loose": hkx.lower() in index}
    return fnis, len(lists)


def load_ppa(index):
    files = sorted((k for k in index if k.startswith("skse/plugins/ppa-animation-tagging/") and k.endswith(".json")),
                   key=lambda k: k.rsplit("/", 1)[-1])
    out = {}
    for k in reversed(files):
        try:
            with open(index[k][1], encoding="utf-8", errors="replace") as f:
                j = json.load(f)
        except Exception:
            continue
        for name, val in j.items():
            a = out.setdefault(name.strip().lower(), {"manual": False, "stages": {}})
            stg = None
            if isinstance(val, list):
                stg = val
            elif isinstance(val, dict):
                if isinstance(val.get("manual"), bool):
                    a["manual"] = val["manual"]
                stg = val.get("stg") if isinstance(val.get("stg"), list) else None
            for st in stg or []:
                if not isinstance(st, dict) or not isinstance(st.get("s"), int):
                    continue
                for pk, v in st.items():
                    if pk == "s":
                        continue
                    try:
                        pos = int(pk) - 1
                    except ValueError:
                        continue
                    if not 0 <= pos <= 4:
                        continue
                    site = lambda c: c if c in ("V", "A", "M", "H", "LH", "RH") else "none"
                    if isinstance(v, str):
                        a["stages"].setdefault(st["s"], {})[pos] = (site(v), -1)
                    elif isinstance(v, dict):
                        tgt = v.get("target")
                        a["stages"].setdefault(st["s"], {})[pos] = (site(v.get("action", "")), tgt - 1 if isinstance(tgt, int) else -1)
    return out


def build(index):
    fnis, nlists = parse_fnis(index)
    ppa = load_ppa(index)
    packs = sorted((k for k in index if k.startswith("slanims/json/") and k.endswith(".json") and k.count("/") == 2),
                   key=lambda k: k.rsplit("/", 1)[-1])
    packs += sorted((k for k in index if k.startswith("skse/plugins/skyrimnet_sexlab/slal/") and k.endswith(".json")),
                    key=lambda k: k.rsplit("/", 1)[-1])
    rows, playback = {}, {}
    stats = {"packs": 0, "anims": 0, "stages": 0, "missing_fnis": 0, "missing_hkx": 0, "duplicates": 0,
             "fnis_lists": nlists, "fnis_events": len(fnis), "ppa_tagged": 0}
    for k in packs:
        try:
            with open(index[k][1], encoding="utf-8", errors="replace") as f:
                j = json.load(f)
        except Exception:
            continue
        if not isinstance(j, dict) or not isinstance(j.get("animations"), list):
            continue
        stats["packs"] += 1
        pack = os.path.splitext(index[k][0].rsplit("/", 1)[-1])[0]
        for a in j["animations"]:
            if not isinstance(a, dict) or not a.get("id"):
                continue
            row, pb = build_anim(a, pack, fnis, ppa, stats)
            reg = row["_registry"]
            if reg in rows:
                stats["duplicates"] += 1
            rows[reg] = row
            playback[reg] = pb
    stats["anims"] = len(rows)
    return rows, playback, stats


def build_anim(a, pack, fnis, ppa, stats):
    aid, name = a["id"], a.get("name", "")
    creature_race = a.get("creature_race", "")
    is_creature = "creature_race" in a
    actors = a.get("actors") if isinstance(a.get("actors"), list) else []
    genders, races, counts, race_type = [], [], [0, 0, 0, 0], ""
    for ac in actors:
        g = gender_of(ac.get("type", ""))
        genders.append(g)
        counts[g] += 1
        rk = ac.get("race", "") if g >= 2 else ""
        if g >= 2 and not rk:
            rk = creature_race
        if rk:
            race_type = rk
        races.append(rk)
    stage_count = len(actors[0].get("stages", [])) if actors else 0
    tags, seen = [], set()

    def add(t):
        t = t.strip().lower()
        if t and t not in seen:
            seen.add(t)
            tags.append(t)

    for t in str(a.get("tags", "")).split(","):
        add(t)
    gs = {0: "M", 1: "F"}
    gt0 = "".join(gs.get(g, "C") for g in genders)
    add(gt0)
    add(gt0[::-1])
    m, fe, c = counts[0], counts[1], counts[2] + counts[3]
    if len(genders) > 2:
        add("F" * fe + "M" * m + "C" * c)
        add("C" * c + "M" * m + "F" * fe)
    if is_creature:
        for p in range(1, len(genders)):
            if races[p - 1] and races[p] and races[p - 1].lower() != races[p].lower():
                add("interspecies")
                break
    row = {"_registry": aid.lower(), "_name": name, "_position_count": len(genders), "_stage_count": stage_count,
           "_pos_genders": genders, "_pos_race_keys": races, "_tags": tags, "_has_creature": int(is_creature or c > 0)}
    pa = ppa.get(name.strip().lower())
    if pa:
        stats["ppa_tagged"] += 1
    positions = []
    for p, ac in enumerate(actors):
        stages = []
        for sn, s in enumerate(ac.get("stages", []), 1):
            ev = s.get("id", "")
            fe_ = fnis.get(ev.lower())
            if fe_ is None:
                stats["missing_fnis"] += 1
            elif not fe_["loose"]:
                stats["missing_hkx"] += 1
            inter = {"site": "auto", "target": -1, "src": ""}
            if pa:
                t = pa["stages"].get(sn, {}).get(p)
                if t:
                    inter = {"site": t[0], "target": t[1], "src": "ppa"}
                elif pa["manual"]:
                    inter = {"site": "none", "target": -1, "src": "ppa"}
            stages.append({"event": ev, "hkx": fe_["hkx"] if fe_ else "", "kind": fe_["kind"] if fe_ else "",
                           "objects": fe_["objects"] if fe_ else [], "animvars": fe_["animvars"] if fe_ else [],
                           "fwd": s.get("forward", 0), "side": s.get("side", 0), "up": s.get("up", 0),
                           "rot": s.get("rotate", 0), "silent": bool(s.get("silent")),
                           "open_mouth": bool(s.get("open_mouth")), "strap_on": bool(s.get("strap_on")),
                           "sos": s.get("sos", 0), "fnis": fe_ is not None, "interact": inter})
            stats["stages"] += 1
        positions.append({"type": ac.get("type", ""), "gender": genders[p], "race": races[p],
                          "add_cum": cum_of(ac) if genders[p] in (1, 3) else -1, "stages": stages})
    return row, {"slal_id": aid, "pack": pack, "name": name, "positions": positions}


# ---- SexLab P+ (SLSB) ---------------------------------------------------------------------------------------------

SLSB_SRC = "skse/sexlab/registry/source/"


def slsb_gender(pos):
    """1.6x coding as SkyrimNet_SexLab_PPlus.PositionGenders: human male/futa 0, female 1; creature 2, female-only 3."""
    sex = pos.get("sex") or {}
    if (pos.get("race") or "Human") == "Human":
        return 0 if sex.get("male") or sex.get("futa") else 1
    return 3 if sex.get("female") and not sex.get("male") else 2


def slr_pack_name(path):
    """.slr header: u8 version, 7 bytes, then u8 length + pack_name (same as the .slsb.json pack_name)."""
    try:
        with open(path, "rb") as f:
            head = f.read(8 + 1 + 255)
        return head[9:9 + head[8]].decode("utf-8", "replace") if len(head) > 9 else ""
    except OSError:
        return ""


def build_slsb(index):
    fnis, nlists = parse_fnis(index)
    packs = sorted((k for k in index if k.startswith(SLSB_SRC) and k.endswith(".slsb.json")),
                   key=lambda k: k.rsplit("/", 1)[-1])
    slr = {slr_pack_name(index[k][1]): index[k][0] for k in index
           if k.startswith("skse/sexlab/registry/") and k.count("/") == 3 and k.endswith(".slr")}
    have_json = set()
    rows, playback = {}, {}
    stats = {"packs": 0, "scenes": 0, "stages": 0, "branching": 0, "missing_fnis": 0, "missing_hkx": 0,
             "duplicates": 0, "fnis_lists": nlists, "fnis_events": len(fnis),
             "slr_without_json": []}
    for k in packs:
        try:
            with open(index[k][1], encoding="utf-8", errors="replace") as f:
                j = json.load(f)
        except Exception:
            continue
        if not isinstance(j, dict) or not isinstance(j.get("scenes"), dict):
            continue
        stats["packs"] += 1
        pack = j.get("pack_name") or index[k][0].rsplit("/", 1)[-1][:-len(".slsb.json")]
        have_json.add(pack)
        prefix = j.get("prefix_hash") or ""
        for sid, sc in j["scenes"].items():
            if not isinstance(sc, dict) or not isinstance(sc.get("stages"), list) or not sc["stages"]:
                continue
            row, pb = build_slsb_scene(sc.get("id") or sid, sc, pack, prefix, fnis, stats)
            if row["_registry"] in rows:
                stats["duplicates"] += 1
            rows[row["_registry"]] = row
            playback[row["_registry"]] = pb
    stats["scenes"] = len(rows)
    stats["slr_without_json"] = sorted(v for k, v in slr.items() if k not in have_json)
    return rows, playback, stats


def build_slsb_scene(sid, sc, pack, prefix, fnis, stats):
    stages = sc["stages"]
    graph = sc.get("graph") or {}
    root = sc.get("root") or stages[0].get("id", "")
    first = next((s for s in stages if s.get("id") == root), stages[0])
    poss = first.get("positions") or []
    genders = [slsb_gender(p) for p in poss]
    races = ["" if (p.get("race") or "Human") == "Human" else p.get("race") for p in poss]
    counts = [genders.count(g) for g in range(4)]
    tags, seen = [], set()
    for s in stages:  # union in stage order: SLSB copies the SLAL animation tags onto every stage plus per-stage acts
        for t in s.get("tags") or []:
            t = str(t).strip().lower()
            if t and t not in seen:
                seen.add(t)
                tags.append(t)
    row = {"_registry": sid, "_case": 1, "_name": sc.get("name", ""), "_position_count": len(poss),
           "_stage_count": len(stages), "_pos_genders": genders, "_pos_race_keys": races, "_tags": tags,
           "_has_creature": int(counts[2] + counts[3] > 0)}
    if any(len((graph.get(s.get("id")) or {}).get("dest") or []) > 1 for s in stages):
        stats["branching"] += 1
    nodes, positions = [], [{"gender": g, "race": r, "stages": []} for g, r in zip(genders, races)]
    for n, s in enumerate(stages, 1):
        nid = s.get("id", "")
        ex = s.get("extra") or {}
        nodes.append({"id": nid, "n": n, "dest": (graph.get(nid) or {}).get("dest") or [], "tags": s.get("tags") or [],
                      "fixed_len": ex.get("fixed_len", 0)})
        for p, pos in enumerate(s.get("positions") or []):
            if p >= len(positions):
                break
            ev = prefix + (pos.get("event") or [""])[0]  # SLSB FNIS lists name events <prefix_hash><event>
            fe_ = fnis.get(ev.lower())
            if fe_ is None:
                stats["missing_fnis"] += 1
            elif not fe_["loose"]:
                stats["missing_hkx"] += 1
            off = pos.get("offset") or {}
            pex = pos.get("extra") or {}
            positions[p]["stages"].append({"event": ev, "hkx": fe_["hkx"] if fe_ else "", "fnis": fe_ is not None,
                                           "fwd": off.get("x", 0), "side": off.get("y", 0), "up": off.get("z", 0),
                                           "rot": off.get("r", 0), "anim_obj": pos.get("anim_obj", ""),
                                           "climax": bool(pex.get("climax")), "schlong": pos.get("schlong", 0),
                                           "scale": pos.get("scale", 1.0)})
            stats["stages"] += 1
    return row, {"scene_id": sid, "pack": pack, "name": sc.get("name", ""), "root": root, "nodes": nodes,
                 "positions": positions}


def parity(rows, db):
    c = sqlite3.connect(db)
    old = {}
    for reg, name, pc, sc, pg, tags in c.execute(
            "select registry,name,position_count,stage_count,pos_genders,tags from animations"):
        old[reg] = (name, pc, sc, json.loads(pg or "[]"), {t for t in (tags or "").split(",") if t})
    missing = sorted(set(old) - set(rows))
    extra = sorted(set(rows) - set(old))
    diffs = []
    for reg in sorted(set(old) & set(rows)):
        n, pc, sc, pg, ot = old[reg]
        r = rows[reg]
        nt = set(r["_tags"]) | ({"sexual"} if "sexual" in ot else set())
        d = []
        if n != r["_name"]:
            d.append(f"name {n!r} != {r['_name']!r}")
        if pc != r["_position_count"]:
            d.append(f"positions {pc} != {r['_position_count']}")
        if sc != r["_stage_count"]:
            d.append(f"stages {sc} != {r['_stage_count']}")
        if pg != r["_pos_genders"]:
            d.append(f"genders {pg} != {r['_pos_genders']}")
        if ot != nt:
            d.append(f"tags -{sorted(ot - nt)} +{sorted(nt - ot)}")
        if d:
            diffs.append((reg, d))
    print(f"old rows={len(old)} slal rows={len(rows)} common={len(set(old) & set(rows))} "
          f"missing_in_slal={len(missing)} extra_in_slal={len(extra)} differing={len(diffs)}")
    for reg in missing[:40]:
        print("  MISSING", reg, old[reg][0])
    for reg, d in diffs[:40]:
        print("  DIFF", reg, "; ".join(d))
    return 0 if not diffs else 1


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("cmd", choices=["stats", "dump", "parity"])
    ap.add_argument("arg", nargs="?")
    ap.add_argument("--profile", default="SkyrimNet SexLab")
    ap.add_argument("--mods", default=os.path.join(DEV, "mods"))
    ap.add_argument("--game-data", default=os.path.join(DEV, "skyrim", "Data"))
    ap.add_argument("--overwrite", default=os.path.join(DEV, "overwrite"))
    ap.add_argument("--source", choices=["slal", "slsb"], default="slal")
    ap.add_argument("--enable", action="append", default=[], help="mod folder to treat as enabled (repeatable)")
    a = ap.parse_args()
    index = vfs_index(a.profile, a.mods, a.game_data, a.overwrite, a.enable)
    rows, playback, stats = (build_slsb if a.source == "slsb" else build)(index)
    if a.cmd == "stats":
        print(json.dumps(stats))
    elif a.cmd == "dump":
        reg = (a.arg or "") if a.source == "slsb" else (a.arg or "").lower()
        print(json.dumps({"row": rows.get(reg), "playback": playback.get(reg)}, indent=1))
    else:
        sys.exit(parity(rows, a.arg))


if __name__ == "__main__":
    main()
