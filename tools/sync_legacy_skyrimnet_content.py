#!/usr/bin/env python3
"""Copy Beta 25 plugin actions/prompts into pre-0.25 SkyrimNet folders.

Canonical source: SKSE/Plugins/SkyrimNet/external/goodprovider.sexlab/
Destinations:     config/actions/ and prompts/

Does not copy manifest.json or triggers. Prunes dest files that are not in the plugin.
"""

from __future__ import annotations

import shutil
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PLUGIN = ROOT / "SKSE" / "Plugins" / "SkyrimNet" / "external" / "goodprovider.sexlab"
SKYRIMNET = ROOT / "SKSE" / "Plugins" / "SkyrimNet"
SRC_ACTIONS = PLUGIN / "actions"
SRC_PROMPTS = PLUGIN / "prompts"
DST_ACTIONS = SKYRIMNET / "config" / "actions"
DST_PROMPTS = SKYRIMNET / "prompts"


def sync_dir(src: Path, dst: Path, pattern: str) -> tuple[int, int]:
    if not src.is_dir():
        raise FileNotFoundError(f"missing source: {src}")

    wanted: set[Path] = set()
    copied = 0
    for path in sorted(src.glob(pattern)):
        if not path.is_file():
            continue
        rel = path.relative_to(src)
        dest = dst / rel
        dest.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(path, dest)
        wanted.add(rel)
        copied += 1
        print(f"copied: {rel}")

    pruned = 0
    if dst.is_dir():
        for path in sorted(dst.rglob("*")):
            if not path.is_file():
                continue
            rel = path.relative_to(dst)
            if rel not in wanted:
                path.unlink()
                pruned += 1
                print(f"pruned: {rel}")
        for directory in sorted(
            (p for p in dst.rglob("*") if p.is_dir()),
            key=lambda p: len(p.parts),
            reverse=True,
        ):
            if not any(directory.iterdir()):
                directory.rmdir()
                print(f"pruned dir: {directory.relative_to(dst)}")
    return copied, pruned


def main() -> int:
    if not PLUGIN.is_dir():
        print(f"error: plugin folder missing: {PLUGIN}", file=sys.stderr)
        return 1

    actions_copied, actions_pruned = sync_dir(SRC_ACTIONS, DST_ACTIONS, "*.yaml")
    prompts_copied, prompts_pruned = sync_dir(SRC_PROMPTS, DST_PROMPTS, "**/*")
    print(
        f"actions: copied {actions_copied}, pruned {actions_pruned} -> {DST_ACTIONS}"
    )
    print(
        f"prompts: copied {prompts_copied}, pruned {prompts_pruned} -> {DST_PROMPTS}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
