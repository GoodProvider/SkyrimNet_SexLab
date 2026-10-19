# Release guide

Align docs and version metadata with what will ship as `next_version`. Git tags, pushes and GitHub Releases are a separate maintainer step.

Agents: use the project `release` skill (`.cursor/skills/release/SKILL.md`). Session state: [release-checkpoint.xml](release-checkpoint.xml). Protocol contracts: [docs/reference/](docs/reference/) — do not restate them here.

## Who does what

| Actor | Owns | Does not do unless asked |
|-------|------|--------------------------|
| Agent | Changelogs, freshness-matrix docs, Makefile `VERSION`, checkpoint, release commits, `make check-pex`, `make release` | `compile: papyrus`, git tag, push, GitHub, feature work |
| Maintainer | Compile, tag, push, publish | Inventing changelog bullets the tree does not support |

**Agent done-when:** `CHANGELOG.md`, `CHANGELOG-developer.md` and `CHANGELOG-player.md` cover `next_version`; freshness-matrix files match the delta; checkpoint is current; release committed; `make check-pex` and `make release` passed; hand-off lists leftover version mismatches. Tag, push and GitHub Release are not part of done.

## Version sources

One release version. If these disagree, stop and ask — do not invent.

| Source | Field | Role |
|--------|-------|------|
| [Makefile](Makefile) | `VERSION` | Authoritative for `make release` package name |
| [SKSE/Plugins/SkyrimNet_SexLab/info.json](SKSE/Plugins/SkyrimNet_SexLab/info.json) | `version` | Written by `python_scripts/info.py` during `make release` |
| [FOMOD/info.xml](FOMOD/info.xml) | `Version` | From `FOMOD_source` via `fomod-update-name-version.py` |
| [FOMOD/ModuleConfig.xml](FOMOD/ModuleConfig.xml) | same | Same during `make release` |
| git tag matching `VERSION` | — | Created only when the maintainer ships |

Also reconcile checkpoint `base_tag` / `next_version` and the latest version tag.

Releases URL: `https://github.com/GoodProvider/SkyrimNet_SexLab/releases/tag/{VERSION}`

## Freshness matrix

Update only the rows the delta touches. Contracts stay single-sourced under `docs/reference/`.

| When the delta includes | Update |
|-------------------------|--------|
| Action YAML or scene JSON | `docs/authors/actions.md`; `docs/reference/scene-settings.md`; `CHANGELOG.md`; `CHANGELOG-developer.md`; `CHANGELOG-player.md` if player-visible; `README.md` index only if a new top-level feature category appears; `docs/examples/` stub only if no short in-tree file exists |
| Prompts, speaking modifiers, or orgasm DirectNarration text | exactly one of `docs/reference/protocol-tokens.md`, `orgasm-narration.md`, or `json-keys.md`; `docs/authors/prompts.md`; changelogs |
| Papyrus scene / manager / creator behavior | `docs/developers/papyrus.md`; changelogs; `docs/reference/*` only if a protocol contract changed |
| WebUI / SKSE / PrismaUI | `docs/developers/webui.md`; `docs/players/hotkeys.md` if user-visible; changelogs |
| Animation stage JSON or editor UX | `docs/authors/animations.md`; `docs/players/hotkeys.md` if needed; changelogs |
| Install / MCM / FAQ | `docs/players/overview.md` and/or `requirements.md`; keep `README.md` short |
| Doc layout or agent map | `llms.txt`; `AGENTS.md` pointers; `release-checkpoint.xml` `doc_files` |

## Doc inventory

| Role | Path |
|------|------|
| End-user front door | `README.md` |
| Agent router | `llms.txt` |
| Agent policy | `AGENTS.md` |
| Changelog (technical) | `CHANGELOG.md` |
| Changelog (developer summary) | `CHANGELOG-developer.md` |
| Changelog (player) | `CHANGELOG-player.md` |
| Players | `docs/players/overview.md`, `hotkeys.md`, `requirements.md` |
| Authors | `docs/authors/actions.md`, `prompts.md`, `animations.md` |
| Developers | `docs/developers/papyrus.md`, `webui.md` |
| Contracts | `docs/reference/papyrus-rules.md`, `protocol-tokens.md`, `json-keys.md`, `orgasm-narration.md`, `scene-settings.md` |
| Examples | `docs/examples/` |
| This guide | `release-guide.md` |
| Agent skill | `.cursor/skills/release/SKILL.md` |
| Session state | `release-checkpoint.xml` |

## Changelog rules

Ground truth is the git delta since `base_tag` plus working-tree files that will ship. No invented features. Every bullet must be verifiable. Net delta only: anything added and then removed or reverted before the release (temporary debug instrumentation, a feature dropped mid-cycle) gets no bullet, not even a "removed" one. Changelogs get a one-line pointer to `docs/reference/…`, never a pasted protocol.

### Structure (all three changelogs)

Model: `CHANGELOG-player.md` 0.36.1 and 0.36.0.

- One `## VERSION` section per release, newest first.
- Under it, `### <Topic>` groups named after the feature or bug as a player knows it: `Injury Engine`, `SexLab P+`, `Force/Punish/Ask/Order`, `Aid`, `NPC strategy`, `Bug Fixes`, `WebUI`. A single-issue fix gets its own `### <Thing> bug` topic (e.g. `AnimDB bug`, `Dead Actor bug`).
- Add ` (untested)` to a topic heading when the change has not been verified in game.
- Topic order: headline features first, then smaller features, then `Bug Fixes`, then `WebUI` / install.
- For a version, all three files use the same topic headings in the same order. A file leaves out a topic only when it has no bullet for it. `CHANGELOG.md` and `CHANGELOG-developer.md` may add internals-only topics (e.g. `Narration`, `Inja`, `Build`, `Docs`) after the shared ones.
- A fix bullet starts with `Fixed:`. Add a short player action when one is needed ("Rebuild it once after updating").
- Versions up to 0.35.2 keep their old format. Do not rewrite them.

Example:

```markdown
## 0.36.1

### AnimDB bug (untested)
- Fixed: the animation database stayed empty on 0.36.0 (every rebuild "finished" with 0 animations). Rebuild it once after updating
- A failed animation database build now says so instead of "ready"

### Dead Actor bug (untested)
- Fixed: necro animations with a corpse (e.g. FunnyBizness) ended right after starting on SexLab 1.6x
```

### `CHANGELOG.md`

Version title (unreleased: `## VERSION (unreleased)`):

```markdown
## [VERSION](https://github.com/GoodProvider/SkyrimNet_SexLab/releases/tag/VERSION) — since [BASE](https://github.com/GoodProvider/SkyrimNet_SexLab/releases/tag/BASE)
```

Topics per [Structure](#structure-all-three-changelogs). Prefer concrete identifiers (YAML names, `setting_name`, StorageUtil keys, prompt files).

### `CHANGELOG-developer.md`

First line = GitHub releases URL for `next_version`, then the SkyrimNet requirement line. Then `## VERSION` with topics per Structure; 5–12 plain-English bullets per version in total. No claims missing from `CHANGELOG.md`.

### `CHANGELOG-player.md`

Ships with the release. First line = GitHub releases URL for `next_version`, then the SkyrimNet requirement line, then `## VERSION` with topics per Structure. Only player-facing bullets taken from `CHANGELOG.md` (no Papyrus / SKSE internals); each bullet is 100 characters or fewer. No claims missing from `CHANGELOG.md`.

### Writing bar

- Short technical bullets; one H1 per markdown file; sequential H2/H3; pure Markdown (no HTML).
- Examples: minimal snippet + link to the full in-tree file; if none is short enough, add a stub under `docs/examples/`.
- Version-pin behavior that is release-specific (applies to vX.Y+).
- Do not promise VR-specific behavior unless verified; SE ≠ VR.
- Ask before drafting when version, ship set, handler ESP special cases, or omissions are unclear.

## Noise (do not changelog)

Ignore the [llms.txt](llms.txt) denylist unless the maintainer says those paths ship: `SSEEdit Cache/`, `reviews/`, `Source/*.pex`, crash logs, `versions/`, `dist/`, `z-*`, `handler_*` unpack dirs, `SKSE_Source/build/`, vendored CommonLibSSE-NG.

## Packaging

Prereqs: `Scripts/*.pex` current (`compile: papyrus`; `make check-pex` passes, and `make release` runs it); SKSE DLL if WebUI ships; `Spriggit/` JSON is ESP source of truth (not hand-edited binaries); animations merged if required.

`make release` writes `info.json` and FOMOD from `VERSION`/`NAME`, deserializes `SkyrimNet_SexLab.esp` from `Spriggit/`, stages core + handlers, packs `versions/SkyrimNet_SexLab ${VERSION}.7z`.

Ship order: commit → `compile: papyrus` if needed → `make check-pex` → `make release` → commit version files (agent stops here) → git tag → push → GitHub Release (maintainer).
