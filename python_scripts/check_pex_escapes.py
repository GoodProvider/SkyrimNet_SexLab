"""Fail when a compiled .pex keeps a literal backslash+quote in its string table.

papyrus.exe (compile: papyrus) stores the Papyrus literal "\"" as two characters, which breaks every
Papyrus-built JSON string (AnimDB sync, PatchConfig, scene JSON). pyro stores one quote character.
KNOWLEDGEBASE: "{{sl.actors.N}} reached SkyrimNet raw: non-pyro compiler kept \\\" literally".
"""

import argparse
import pathlib
import struct
import sys


def string_table_hits(data: bytes) -> int:
    """Count string-table entries holding a backslash+quote. Bytecode after the table can hold those two bytes by chance."""
    pos = 4 + 1 + 1 + 2 + 8  # magic, major, minor, game id, compile time
    for _ in range(3):  # source file, user, machine
        pos += 2 + struct.unpack_from(">H", data, pos)[0]
    count = struct.unpack_from(">H", data, pos)[0]
    pos += 2
    hits = 0
    for _ in range(count):
        size = struct.unpack_from(">H", data, pos)[0]
        pos += 2
        if b'\\"' in data[pos : pos + size]:
            hits += 1
        pos += size
    return hits


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("dirs", nargs="*", default=["Scripts"], help="folders holding .pex files")
    args = parser.parse_args()

    bad = []
    total = 0
    for d in args.dirs:
        for pex in sorted(pathlib.Path(d).glob("*.pex")):
            total += 1
            hits = string_table_hits(pex.read_bytes())
            if hits:
                bad.append((pex, hits))

    for pex, hits in bad:
        print(f"BAD  {pex}: {hits} literal \\\" (rebuild with compile: pyro)")
    print(f"check_pex_escapes: {total} pex checked, {len(bad)} bad")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
