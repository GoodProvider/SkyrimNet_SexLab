"""Fail when a compiled .pex keeps a literal backslash+quote in its string table.

papyrus.exe (compile: papyrus) stores the Papyrus literal "\"" as two characters, which breaks every
Papyrus-built JSON string (AnimDB sync, PatchConfig, scene JSON). pyro stores one quote character.
KNOWLEDGEBASE: "{{sl.actors.N}} reached SkyrimNet raw: non-pyro compiler kept \\\" literally".
"""

import argparse
import pathlib
import sys


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("dirs", nargs="*", default=["Scripts"], help="folders holding .pex files")
    args = parser.parse_args()

    bad = []
    total = 0
    for d in args.dirs:
        for pex in sorted(pathlib.Path(d).glob("*.pex")):
            total += 1
            hits = pex.read_bytes().count(b'\\"')
            if hits:
                bad.append((pex, hits))

    for pex, hits in bad:
        print(f"BAD  {pex}: {hits} literal \\\" (rebuild with compile: pyro)")
    print(f"check_pex_escapes: {total} pex checked, {len(bad)} bad")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
