# Release 0.37.4 — checkpoint 01

Repo: `c:\Skyrim\dev\mods\SkyrimNet_SexLab` · branch `main` · baseline 0.37.3 (3c2df04e, tagged on origin)

## Goal

Release pass for 0.37.4 (release skill): changelogs, docs, version bump, `make check-pex`, `make release`. No tag / push / GitHub.

## Decisions

- Ship set (maintainer): the three commits since 0.37.3 plus the working-tree Scene style work and the Scene_Manager foreign-restart diagnostics.
- Tested (maintainer): Scene style, Last stage, WebUI actor_form panels. Untested: Scenes restarting, SkyrimNet 1.0.0 bug.
- Topics (all three changelogs, same order): Scene style, Last stage, Scenes restarting (untested), SkyrimNet 1.0.0 bug (untested), WebUI (CHANGELOG.md / developer only).
- Omit: `extern/` (untracked).

## Results

- `fa00e9e4` Style sets passive enjoyment rate; foreign-restart diagnostics (feature work, DLL, pex, manifest, docs, KB)
- `0668389c` 0.37.4: release docs and version bump (CHANGELOG*, papyrus.md foreign-restart line, Makefile, release-checkpoint.xml)
- `0.37.4: make release version files` (info.json, FOMOD info.xml / ModuleConfig.xml, this checkpoint)
- `make check-pex`: 32 + 2 pex, 0 bad; corpse-patch hashes match.
- `make release`: `versions/SkyrimNet_SexLab 0.37.4.7z` (3,200,718 bytes, 2026-11-14 10:27); no `sex-graph.json` in the archive.

## Findings

- `make` must run from PowerShell / cmd. Under Git Bash the cmd-style `if not exist` recipe in the `esp` target fails with an sh syntax error.
- The 0.37.3 tag exists only on origin; `git fetch --tags` locally if needed.

## Not yet tested

- Foreign-restart notification (waiting on the user from `checkpoints/2026-11-14-never-started`).
- 0050/0550 fix on SkyrimNet 1.0.0.

## Next

1. Maintainer: `git tag 0.37.4` → push → GitHub Release with `versions/SkyrimNet_SexLab 0.37.4.7z` and the 0.37.4 section of `CHANGELOG-player.md`.
2. Optionally `git fetch --tags` so 0.37.3 exists locally for the next release diff.
