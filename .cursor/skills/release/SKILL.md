---
name: release
description: >-
  Align SkyrimNet_SexLab release docs and version metadata for next_version.
  Use when preparing a release, writing CHANGELOG.md, CHANGELOG-developer.md or CHANGELOG-player.md,
  bumping Makefile VERSION, updating release-checkpoint.xml, documenting the
  delta since base_tag, or when the user asks to ship, tag-prep, or run a
  release-doc pass. Commits, runs make check-pex and make release; never
  creates git tags, pushes, or touches GitHub.
---

# Release documentation

Shared facts (freshness matrix, version sources, doc inventory, packaging): [release-guide.md](../../../release-guide.md). Session state: [release-checkpoint.xml](../../../release-checkpoint.xml). On conflict, the markdown wins for facts; this file wins for agent procedure. Do not read `release-guide.xml` (removed).

## Cold start

Read, in order:

1. `release-guide.md`
2. `release-checkpoint.xml`
3. `llms.txt`

Then:

1. Take `base_tag` and `next_version` from the checkpoint (fallback: `git describe` / latest version tag). If `next_version` already has a git tag, it has shipped: the new `next_version` is the patch bump, `base_tag` becomes that tag, and bullets added to its sections after tagging move to the new version (restore the tagged sections with `git show <tag>:<file>`).
2. Reconcile with Makefile `VERSION`, `SKSE/Plugins/SkyrimNet_SexLab/info.json`, `FOMOD/info.xml`, and the latest version tag. **If they disagree, stop and ask. Do not invent a version.**
3. Diff `base_tag...HEAD` plus uncommitted files that will ship.
4. For protocol contracts, open the single canonical file under `docs/reference/`. Changelogs get a one-line pointer, never a pasted contract.

Ignore the `llms.txt` denylist unless the maintainer says those paths ship (`SSEEdit Cache/`, `reviews/`, `Source/*.pex`, crash logs, `versions/`, `dist/`, `z-*`, `handler_*` unpack dirs, `SKSE_Source/build/`, vendored CommonLibSSE-NG).

## Hard stops

- Do not create the git tag, push, or touch GitHub (`gh`, GitHub Releases).
- Do not do feature work, refactors, or review fixes (`review-guide.xml` is a different job).
- Do not invent changelog bullets or README claims.
- Commit only the release pass (docs, Makefile, checkpoint, `make release` outputs); never the omit list.
- Do not promise VR-specific behavior unless verified. SE ≠ VR.
- Before any game/script/ESP fix that sneaks into this pass: state confidence ≥ 90% and assumptions.

## Workflow

Copy and track:

```
Release-doc progress:
- [ ] 1. Establish delta
- [ ] 2. Clarify before writing
- [ ] 3. Rewrite CHANGELOG.md
- [ ] 4. Rewrite CHANGELOG-developer.md
- [ ] 5. Write CHANGELOG-player.md
- [ ] 6. Align docs (freshness matrix)
- [ ] 7. Makefile VERSION if missing
- [ ] 8. Update checkpoint
- [ ] 9. Commit
- [ ] 10. make check-pex
- [ ] 11. make release
- [ ] 12. Hand-off
```

### 1. Establish delta

Collect user- and author-visible changes since `base_tag`: scripts, action YAMLs, prompts, scenes, animations, SKSE/WebUI, FOMOD, docs. Skip denylist noise.

Preflight (report only; do not compile or pack): whether `Scripts/*.pex`, SKSE DLL (if WebUI ships), and `Spriggit/` JSON look current.

### 2. Clarify before writing

Stop and ask if any of these are unclear:

- `next_version` / `base_tag` (including Makefile vs `info.json` vs FOMOD vs checkpoint vs tags)
- which working-tree changes ship
- CHANGELOG themes vs docs-only updates
- handler ESP special cases
- deliberate omissions
- the topic list for `next_version` (see Structure in `release-guide.md`) and which topics get `(untested)`

Do not draft `CHANGELOG*`, `README.md`, or `docs/` until answers avoid invention.

### 3. Rewrite CHANGELOG.md

First write the topic list for `next_version` once, from the delta: `### <Topic>` headings per **Structure** in `release-guide.md` (model: `CHANGELOG-player.md` 0.36.1 / 0.36.0). Steps 3–5 all use this list, in the same order.

Title:

```markdown
## [VERSION](https://github.com/GoodProvider/SkyrimNet_SexLab/releases/tag/VERSION) — since [BASE](https://github.com/GoodProvider/SkyrimNet_SexLab/releases/tag/BASE)
```

Then the topics. Internals-only topics (e.g. `Narration`, `Inja`, `Build`, `Docs`) go after the shared ones. Prefer concrete identifiers (YAML names, `setting_name`, StorageUtil keys, prompt files). Every bullet must be verifiable in git history or the shipping working tree.

### 4. Rewrite CHANGELOG-developer.md

First line:

```text
https://github.com/GoodProvider/SkyrimNet_SexLab/releases/tag/VERSION
```

Then the requirement line, then `## VERSION` with the same topics; 5–12 plain-English bullets per version in total. No claims missing from `CHANGELOG.md`.

### 5. Write CHANGELOG-player.md

Ships with the release. Same first line (releases URL) and requirement line as before, then `## VERSION` with the same topics (leave out internals-only ones). Only player-facing bullets from `CHANGELOG.md`; each bullet 100 characters or fewer (check with `awk 'length($0)>100'`). No claims missing from `CHANGELOG.md`.

### 6. Align docs

Apply the freshness matrix in `release-guide.md` — only touched rows. Prefer pointers over duplication. Keep `README.md` short. Preserve short technical voice under `docs/`.

### 7. Version prep

If `next_version` is missing from Makefile, update Makefile `VERSION` only. `make release` refreshes `info.json` and FOMOD — do not run it unless asked. ESP source of truth is `Spriggit/`, not hand-edited binaries.

### 8. Checkpoint

Update `release-checkpoint.xml`: `updated`, `base_tag`, `next_version`, `version_status`, status notes, `related_artifacts`, `doc_files`.

### 9. Commit

Commit the release-doc changes, Makefile and checkpoint. Summary in the first 72 chars (e.g. `0.36.2: release docs and version bump`). Leave the checkpoint omit list untracked.

### 10. make check-pex

Run `make check-pex`. If it fails, stop and report; rebuilding with `compile: papyrus` needs the maintainer's go-ahead.

### 11. make release

Run `make release`. Confirm `versions/SkyrimNet_SexLab <VERSION>.7z` exists with a fresh timestamp and that `info.json` / FOMOD now say `VERSION`. Commit the files it changed (`<VERSION>: make release version files`).

### 12. Hand-off

Report:

- files touched and commits made
- version mismatches left
- preflight notes
- remaining maintainer steps: git tag → push → GitHub Release

## Done-when

- Changelogs cover `next_version`
- The three changelogs use the same topic headings in the same order for `next_version`
- Freshness-matrix files match the shipping delta
- Checkpoint is current
- `make check-pex` and `make release` passed; `.7z` built; release commits made
- Hand-off lists leftover mismatches

Tag, push and GitHub Release are not part of done.
