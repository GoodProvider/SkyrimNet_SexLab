#!/usr/bin/env python3
"""Dump lockable DD inventory/rendered pairs into group-devices.json.

Reads Integration / Expansion / Assets ESMs plus zadLibs / zadx / zadLibsNG
property names. Used as BondagePanel fallback when DDNG GetAPI fails.
"""
from __future__ import annotations

import json
import re
import struct
import sys
import zlib
from collections import defaultdict
from pathlib import Path

GROUP_ORDER = [
    "Blindfold",
    "Gag",
    "Hood",
    "Collar",
    "Piercing Nipple",
    "Body",
    "Arms",
    "Belt",
    "Piercing Vaginal",
    "Plug Vaginal",
    "Plug Anal",
    "Legs",
    "Boots",
    "Suit",
]

KEYWORD_GROUPS = [
    ("zad_DeviousHood", "Hood"),
    ("zad_DeviousBlindfold", "Blindfold"),
    ("zad_DeviousGagPanel", "Gag"),
    ("zad_DeviousGagLarge", "Gag"),
    ("zad_DeviousGag", "Gag"),
    ("zad_DeviousCollar", "Collar"),
    ("zad_DeviousPiercingsNipple", "Piercing Nipple"),
    ("zad_DeviousBra", "Body"),
    ("zad_DeviousHarness", "Body"),
    ("zad_DeviousCorset", "Body"),
    ("zad_DeviousArmbinderElbow", "Arms"),
    ("zad_DeviousArmbinder", "Arms"),
    ("zad_DeviousElbowTie", "Arms"),
    ("zad_DeviousYokeBB", "Arms"),
    ("zad_DeviousYoke", "Arms"),
    ("zad_DeviousCuffsFront", "Arms"),
    ("zad_DeviousArmCuffs", "Arms"),
    ("zad_DeviousBondageMittens", "Arms"),
    ("zad_DeviousGloves", "Arms"),
    ("zad_DeviousBelt", "Belt"),
    ("zad_DeviousPiercingsVaginal", "Piercing Vaginal"),
    ("zad_DeviousPlugVaginal", "Plug Vaginal"),
    ("zad_DeviousPlugAnal", "Plug Anal"),
    ("zad_DeviousPlug", "Plug Anal"),
    ("zad_DeviousAnkleShackles", "Legs"),
    ("zad_DeviousLegCuffs", "Legs"),
    ("zad_DeviousBoots", "Boots"),
    ("zad_DeviousStraitJacket", "Suit"),
    ("zad_DeviousHobbleSkirt", "Suit"),
    ("zad_DeviousPetSuit", "Suit"),
    ("zad_DeviousSuit", "Suit"),
    ("zad_DeviousHeavyBondage", "Arms"),
]


def _u16(b, o):
    return struct.unpack_from("<H", b, o)[0]


def _u32(b, o):
    return struct.unpack_from("<I", b, o)[0]


def _zstr(b, o, end):
    z = b.find(b"\x00", o, end)
    if z < 0:
        return "", end
    return b[o:z].decode("utf-8", "replace"), z + 1


def _wstr(b, o, end):
    if o + 2 > end:
        return "", o
    n = _u16(b, o)
    o += 2
    raw = b[o : o + n]
    o += n
    if raw.endswith(b"\x00"):
        raw = raw[:-1]
    return raw.decode("utf-8", "replace"), o


class Plugin:
    def __init__(self, path: Path):
        self.path = path
        self.name = path.name
        self.data = path.read_bytes()
        self.masters: list[str] = []
        self.kywd: dict[int, str] = {}
        self.armo: dict[int, dict] = {}
        self.n_armo = 0
        self.n_kywd = 0
        self._parse()

    def resolve(self, fid: int) -> tuple[str, int] | None:
        idx = (fid >> 24) & 0xFF
        local = fid & 0xFFFFFF
        files = self.masters + [self.name]
        if idx >= len(files):
            return None
        return files[idx], local

    def _parse(self):
        data = self.data
        i = 0
        n = len(data)
        while i + 24 <= n:
            rtype = data[i : i + 4]
            if rtype == b"GRUP":
                i += 24
                continue
            size = _u32(data, i + 4)
            flags = _u32(data, i + 8)
            fid = _u32(data, i + 12)
            rec = data[i + 24 : i + 24 + size]
            if flags & 0x00040000 and len(rec) > 4:
                try:
                    rec = zlib.decompress(rec[4:])
                except Exception:
                    rec = b""
            if rtype == b"TES4":
                self._tes4(rec)
            elif rtype == b"KYWD":
                edid = self._sub_z(rec, b"EDID")
                if edid:
                    self.kywd[fid] = edid
                    self.n_kywd += 1
            elif rtype == b"ARMO":
                self.n_armo += 1
                self._armo(fid, rec)
            i += 24 + size

    def _tes4(self, rec: bytes):
        o = 0
        while o + 6 <= len(rec):
            st = rec[o : o + 4]
            ss = _u16(rec, o + 4)
            body = rec[o + 6 : o + 6 + ss]
            o += 6 + ss
            if st == b"MAST":
                name = body.split(b"\x00", 1)[0].decode("utf-8", "replace")
                if name:
                    self.masters.append(name)

    def _sub_z(self, rec: bytes, want: bytes) -> str:
        o = 0
        while o + 6 <= len(rec):
            st = rec[o : o + 4]
            ss = _u16(rec, o + 4)
            body = rec[o + 6 : o + 6 + ss]
            o += 6 + ss
            if st == want:
                return body.split(b"\x00", 1)[0].decode("utf-8", "replace")
        return ""

    def _armo(self, fid: int, rec: bytes):
        edid = ""
        full = ""
        desc = ""
        kwda: list[int] = []
        props: dict[str, int] = {}
        o = 0
        while o + 6 <= len(rec):
            st = rec[o : o + 4]
            ss = _u16(rec, o + 4)
            body = rec[o + 6 : o + 6 + ss]
            o += 6 + ss
            if st == b"EDID":
                edid = body.split(b"\x00", 1)[0].decode("utf-8", "replace")
            elif st == b"FULL":
                if len(body) > 4 and b"\x00" in body:
                    full = body.split(b"\x00", 1)[0].decode("utf-8", "replace")
                elif len(body) == 4:
                    full = ""
            elif st == b"DESC":
                desc = body.split(b"\x00", 1)[0].decode("utf-8", "replace")
            elif st == b"KWDA":
                for k in range(0, len(body) - 3, 4):
                    kwda.append(_u32(body, k))
            elif st == b"VMAD":
                props.update(self._vmad_objects(body))
        self.armo[fid] = {
            "edid": edid,
            "full": full,
            "desc": desc,
            "kwda": kwda,
            "props": props,
            "fid": fid,
        }

    def _vmad_objects(self, body: bytes) -> dict[str, int]:
        out: dict[str, int] = {}
        if len(body) < 6:
            return out
        try:
            ver = _u16(body, 0)
            objfmt = _u16(body, 2)
            nscripts = _u16(body, 4)
            o = 6
            end = len(body)
            if nscripts > 32:
                return out
            for _ in range(nscripts):
                name, o = _wstr(body, o, end)
                if o >= end:
                    break
                o += 1  # status
                if o + 2 > end:
                    break
                nprop = _u16(body, o)
                o += 2
                if nprop > 128:
                    return out
                for _p in range(nprop):
                    pname, o = _wstr(body, o, end)
                    if o + 2 > end:
                        return out
                    ptype = body[o]
                    o += 2  # type + status
                    if ptype == 1:
                        if objfmt == 1:
                            if o + 6 > end:
                                return out
                            o += 2
                            fid = _u32(body, o)
                            o += 4
                        else:
                            if o + 6 > end:
                                return out
                            fid = _u32(body, o)
                            o += 6
                        if pname:
                            out[pname.lower()] = fid
                    else:
                        skip = {
                            2: None,
                            3: 4,
                            4: 4,
                            5: 1,
                        }
                        if ptype == 2:
                            _, o = _wstr(body, o, end)
                        elif ptype in (3, 4):
                            o += 4
                        elif ptype == 5:
                            o += 1
                        elif ptype >= 11:
                            if o + 4 > end:
                                return out
                            count = _u32(body, o)
                            o += 4
                            inner = ptype - 10
                            if count > 256:
                                return out
                            for _i in range(count):
                                if inner == 1:
                                    if o + 6 > end:
                                        return out
                                    o += 6
                                elif inner == 2:
                                    _, o = _wstr(body, o, end)
                                elif inner in (3, 4):
                                    o += 4
                                elif inner == 5:
                                    o += 1
                                else:
                                    return out
                        else:
                            return out
        except Exception:
            return out
        return out


def looks_unlocked(edid: str) -> bool:
    s = edid.lower()
    if "locking" in s:
        return False
    return "unlock" in s


def strip_rendered(edid: str) -> str:
    s = edid
    for suf in ("Rendered", "_Rendered", "rendered", "_rendered"):
        if s.endswith(suf):
            return s[: -len(suf)]
    return s


def strip_inventory(edid: str) -> str:
    s = edid
    for suf in ("Inventory", "_Inventory", "inventory", "_inventory"):
        if s.endswith(suf):
            return s[: -len(suf)]
    return s


def formdata(plugin: str, local: int) -> str:
    return f"__formData|{plugin}|0x{local:x}"


def device_id(plugin: str, local: int) -> str:
    return f"{plugin}:0x{local:x}"


def group_for_keywords(edids: list[str]) -> str | None:
    have = {e.lower() for e in edids}
    for key, group in KEYWORD_GROUPS:
        if key.lower() in have:
            return group
    return None


def parse_psc_pairs(paths: list[Path]) -> set[tuple[str, str]]:
    """Return (inventory_prop, rendered_prop) lowercased names from Armor Property lines."""
    props: list[str] = []
    pat = re.compile(r"armor\s+property\s+(\w+)", re.I)
    for p in paths:
        if not p.is_file():
            continue
        text = p.read_text(encoding="utf-8", errors="replace")
        props.extend(pat.findall(text))
    lower = {n.lower(): n for n in props}
    pairs = set()
    for n in props:
        ln = n.lower()
        if looks_unlocked(n):
            continue
        for suf in ("rendered", "_rendered"):
            if ln.endswith(suf):
                base = ln[: -len(suf)]
                if base in lower:
                    pairs.add((base, ln))
                elif (base + "inventory") in lower:
                    pairs.add((base + "inventory", ln))
    return pairs


def main() -> int:
    repo = Path(__file__).resolve().parents[1]
    ng = repo.parent / "Devious Devices NG"
    dd = repo.parent / "Devious Devices for SE-AE-VR"
    esms = [
        ng / "Devious Devices - Assets.esm",
        ng / "Devious Devices - Integration.esm",
        ng / "Devious Devices - Expansion.esm",
    ]
    plugins = []
    for p in esms:
        if not p.is_file():
            print(f"missing ESM: {p}", file=sys.stderr)
            return 1
        print(f"parse {p.name} ...")
        pl = Plugin(p)
        print(f"  masters={pl.masters} kywd={pl.n_kywd} armo={pl.n_armo}")
        plugins.append(pl)

    kywd_edid: dict[tuple[str, int], str] = {}
    armo_by_edid: dict[str, tuple[Plugin, dict]] = {}
    for pl in plugins:
        for fid, edid in pl.kywd.items():
            resolved = pl.resolve(fid)
            if resolved:
                kywd_edid[resolved] = edid
        for rec in pl.armo.values():
            if rec["edid"]:
                armo_by_edid[rec["edid"].lower()] = (pl, rec)

    psc_paths = [
        repo / "Headers_Source" / "Devious Devices" / "zadLibs.psc",
        dd / "scripts" / "Source" / "zadxLibs.psc",
        dd / "scripts" / "Source" / "zadxlibs2.psc",
        ng / "Source" / "Scripts" / "zadLibsNG.psc",
    ]
    parse_psc_pairs(psc_paths)

    inv_kw = "zad_InventoryDevice"
    lock_kw = "zad_Lockable"
    quest_kw = "zad_QuestItem"

    def rec_kw_edids(pl: Plugin, rec: dict) -> list[str]:
        out = []
        for kw in rec["kwda"]:
            resolved = pl.resolve(kw)
            if not resolved:
                continue
            ed = kywd_edid.get(resolved)
            if ed:
                out.append(ed)
        return out

    groups: dict[str, list[dict]] = defaultdict(list)
    seen: set[str] = set()

    for pl in plugins:
        for rec in pl.armo.values():
            edid = rec["edid"]
            if not edid or looks_unlocked(edid):
                continue
            kws = rec_kw_edids(pl, rec)
            if inv_kw not in kws:
                continue
            if quest_kw in kws:
                continue
            resolved_inv = pl.resolve(rec["fid"])
            if not resolved_inv:
                continue
            inv_plugin, inv_local = resolved_inv

            rendered = None
            rend_pl = None
            for key in ("devicerendered", "deviceRendered", "zad_RenderedDevice"):
                fid = rec["props"].get(key.lower())
                if not fid:
                    continue
                r = pl.resolve(fid)
                if not r:
                    continue
                rplugin, rlocal = r
                for cand in plugins:
                    if cand.name != rplugin:
                        continue
                    for other in cand.armo.values():
                        rr = cand.resolve(other["fid"])
                        if rr == (rplugin, rlocal):
                            rendered = other
                            rend_pl = cand
                            break
                    if rendered:
                        break
                if rendered:
                    break
            if rendered is None:
                base = strip_inventory(edid)
                for suffix in (base + "Rendered", base + "_Rendered", base + "rendered"):
                    hit = armo_by_edid.get(suffix.lower())
                    if hit:
                        rend_pl, rendered = hit
                        break
            if rendered is None:
                continue
            rend_kws = rec_kw_edids(rend_pl, rendered)
            all_kws = kws + rend_kws
            if lock_kw not in all_kws:
                continue
            group = group_for_keywords(all_kws)
            if not group:
                continue
            rend_res = rend_pl.resolve(rendered["fid"])
            if not rend_res:
                continue
            name = rec["full"] or edid
            desc = rec["desc"] or rendered.get("desc") or name
            did = device_id(inv_plugin, inv_local)
            if did in seen:
                continue
            seen.add(did)
            kwd_ed = None
            kwd_form = None
            for key, _g in KEYWORD_GROUPS:
                if key in all_kws:
                    kwd_ed = key
                    break
            if kwd_ed:
                for (p, loc), ed in kywd_edid.items():
                    if ed == kwd_ed:
                        kwd_form = formdata(p, loc)
                        break
            item = {
                "id": did,
                "Name": name,
                "name": name,
                "description": desc,
                "formInventory": formdata(inv_plugin, inv_local),
                "formRendered": formdata(*rend_res),
            }
            if kwd_form:
                item["Keyword"] = kwd_form
            groups[group].append(item)

    out = []
    total = 0
    for gname in GROUP_ORDER:
        devices = groups.get(gname) or []
        devices.sort(key=lambda d: d["Name"].lower())
        if not devices:
            continue
        out.append({"name": gname, "devices": devices})
        total += len(devices)

    dest = repo / "SKSE" / "Plugins" / "SkyrimNet_SexLab" / "bondage" / "group-devices.json"
    dest.write_text(json.dumps(out, indent=4) + "\n", encoding="utf-8")
    print(f"wrote {dest} groups={len(out)} devices={total}")
    for g in out:
        print(f"  {g['name']}={len(g['devices'])}")
    return 0 if total else 2


if __name__ == "__main__":
    raise SystemExit(main())
