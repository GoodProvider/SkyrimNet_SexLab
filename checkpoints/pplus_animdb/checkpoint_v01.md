# P+ AnimDB empty on 0.36.0 — checkpoint v01 (2026-10-17)

## Report

- **userA:** 0.35.2 worked with SexLab P+ 2.18.1. On 0.36.0 the AnimDB tries to build on every reload and ends up with 0 animations. A new game does the same: the build "completes", but the DB is empty and the rebuild prompt comes back.
- **userB:** on P+, the AnimDB has not rebuilt once since 0.36.
- **Log:** `bug-logs/SkyrimNet_SexLab_p+_adnimdb_failed.log`. This was analysed on a different machine, using only this log.

## Evidence in the log

- `IsAligned db_count=0 registered=2758` → mismatch prompt → `BeginSync force=true`.
- `WalkPPlusBatch P+ source=0 scenes=1567`, then `source=1 scenes=1191`, so the P+ registry walk itself works.
- **Every** batch logged `AnimDb_PushAnimBatch: parse failed`, about 58 per sync and none succeeded.
- `EndSync rows=0 duplicate_registries=0 upsert_failures=0`. Then `FinishSourceOrDone total_pushed=2758 ... db_rows=0 duplicates=2758` and "is ready". The `duplicates` number was really `pushed - db_rows`.

## Root cause (confirmed in repo)

The 0.36.0 `Scripts/*.pex` were built with **`compile: papyrus`** (papyrus.exe; default task since 7349eea). papyrus.exe stores the Papyrus literal `"\""` as **backslash + quote**. The AnimDb.pex string table held `{\"_registry\":\"`, `,\"_name\":\"`, and `\"`, so every row built by `BuildAnimJson_PPlus` / `BuildAnimJson` was invalid JSON.

- Affected pex: AnimDb, MCM (PatchConfig), Menu (PatchConfig, GetFormEx), Scene (`_stage_started`, `_mode`), Utilities.
- **Not P+-specific**: 1.6x builds the same JSON. P+ users simply hit it first.
- This is the same bug as KNOWLEDGEBASE "`{{sl.actors.N}}` reached SkyrimNet raw" (2026-10-08). That entry already listed the 10-16 papyrus.exe build as **Open**.
- Why the build drifted: the pyro tasks pointed at `joelday.papyrus-lang-vscode-2024.578.1412/pyro/pyro.exe`. The installed extension (2026.1014.13) no longer bundles pyro, so only `compile: papyrus` worked.

## Done (uncommitted)

### Root fix
- `.vscode/tasks.json`: `compile: pyro` is the default build task again (not `compile: papyrus`). Both pyro tasks now use `C:/Skyrim/tools/Pyro/pyro.exe`.
- All 28 pex rebuilt with pyro (`skyrimse.ppj` + `skyrimse-pplus.ppj`, `--no-incremental-build`). Both compiled with 0 failures.
- New `python_scripts/check_pex_escapes.py` and `make check-pex`. `release` depends on it. Before the rebuild it reported 5 bad files; after, 0.
- `AnimDb_PushAnimBatch` (Papyrus_AnimationDB.cpp) retries once with `\"` → `"` when the first parse fails, and warns once per sync "pex not built with pyro". This is **permanent** tolerance, not debug.
- New native counters `NoteBatchParseError` / `NoteBatchDropped` (AnimationDB.cpp/.h). `EndSync` logs an **error** when every batch failed, or a warn when some batches needed unescaping. Permanent.
- `FinishSourceOrDone`: `duplicates=` renamed to `not_stored=`. It notifies "AnimDB build failed: 0 of N animations stored" instead of "ready" when `db_count == 0 && walk_total > 0`. Permanent.
- Release DLL built (`cmake --build --preset build-release`) and copied to `SKSE/Plugins/`.
- Docs: CHANGELOG / -player / -developer (0.36.1), KNOWLEDGEBASE ("Reverted 2026-10-17" bullet), `docs/developers/papyrus.md`, `docs/developers/sexlab-pplus.md`, AGENTS.md, CLAUDE.md, .cursorrules, release-guide.md, and the release SKILL.md now say `compile: pyro` + `make check-pex`.

### Instrumentation — tagged `DEBUG-DELETE(pplus-animdb)` for later removal

Find it all with `grep -rn "DEBUG-DELETE(pplus-animdb)" SKSE_Source Scripts/Source Scripts/Source_PPlus Headers Headers_Backup Headers_Source`.

| Where | What |
|-------|------|
| `SKSE_Source/src/Papyrus_AnimationDB.cpp` | First 3 parse failures per sync: `e.what()`, byte, len, `near=` (120 chars around the error), `head=` (first 400 chars). Native `AnimDb_LastSyncFailures` and its registration |
| `SKSE_Source/src/AnimationDB.cpp` | Counters `g_sync_batches`, `rows_received`, `rows_accepted`, `rows_rejected`. First 5 rejected rows (reason + JSON). `batch N accepted x/y`. Second `EndSync` line with all counters. `LastSyncFailures()` |
| `SKSE_Source/include/AnimationDB.h` | `LastSyncFailures` decl |
| `Scripts/Source/SkyrimNet_SexLab_AnimDb.psc` | `AnimDb_LastSyncFailures` decl. `walk_batches`, `walk_batches_rejected`, `walk_rows_accepted`, `walk_skip_empty_id` vars and resets. `NoteBatchResult` (first batch JSON head, rejected batches). P+ per-source `ids vs slots` trace plus `SceneDebug` of the first scene. First 10 skipped ids. `DEBUG batches=…` line in `FinishSourceOrDone` |
| `Scripts/Source_PPlus/SkyrimNet_SexLab_PPlus.psc` | `AllSceneIds` count / first id trace (it now returns via a local). New `SceneDebug(id)` |
| `Headers_Source/SkyrimNet_SexLab_PPlus.psc` | `SceneDebug` stub |
| `Headers/`, `Headers_Backup/SkyrimNet_SexLab_AnimDb.psc` | `AnimDb_LastSyncFailures` decl |

**Removal notes:**
- In AnimDb.psc both walk loops call `NoteBatchResult(AnimDb_PushAnimBatch(json), batch_count, json) ; DEBUG-DELETE…`. Restore the bare `AnimDb_PushAnimBatch(json)` there; don't delete the line.
- In C++, `PushAnimBatch` keeps its `std::lock_guard`. Removing the tagged lines leaves the original loop.
- `NoteBatchDropped` has a tagged `++g_sync_batches` line. Keep the function itself, because the retry uses it.
- Recompile with pyro and rebuild the DLL after removal. `AnimDb_LastSyncFailures` must be removed from both the C++ and the psc together.

## Log review 2026-10-17 (this machine, snapshot `review-logs/2026-10-17_082702/`)

User reported "no bug appears". The snapshot shows a game load only:

- `SkyrimNet_SexLab.log`: `AnimationDB: opened … animationdb.sql (762 rows)`, then WebUI / Hud ready. No
  `IsAligned`, `BeginSync`, `parse failed`, `EndSync` or `FinishSourceOrDone` lines, so no sync ran. That
  means the pyro pex and the parse retry were not exercised. There's also no "pex not built with pyro" warning.
- `SkyrimNet.log`: 0 errors. `Papyrus.0.log`: no SkyrimNet_SexLab errors except the old
  `Unknown property type 97/101 … Handler_UDNG_PR` (present since 10-08). No new crash log.

Result: the build with the new DLL and the pyro pex loads cleanly, and the existing DB opens. Rebuilding the DB is **still unverified**.

## Not yet verified

- **In game:** no AnimDB rebuild yet on P+ or 1.6x (the 2026-10-17 session only loaded the game).
- **Negative test** (one papyrus.exe build of AnimDb.psc, expecting `unescaped` warnings and the DB still filling) has not been run.

## What to ask the users for (after 0.36.1)

Rebuild the AnimDB, then send `SkyrimNet_SexLab.log`. Expected lines:
- `NoteBatchResult DEBUG first batch accepted=48/48 json={"_registry":"…` (no `\"`)
- `AnimationDB: EndSync gen=N rows=2758 …` and the second `EndSync … batch_parse_errors=0 batches_dropped=0 rows_accepted=2758 rows_rejected=0`
- `FinishSourceOrDone DEBUG batches=… rejected_batches=0 accepted=2758 … native_failures=0`
- `WalkPPlusBatch DEBUG P+ source=0 ids=1567 …` / `DEBUG first scene id='…' … sex_flags=[…]`

If `rows` < `registered` but there are no failures, look at `duplicate_registries` and `skip_empty_id`.

## Next steps

1. In-game rebuild on P+ (or 1.6x) with this build: MCM / ControlPanel Rebuild DB. Check the lines above.
2. ~~Commit~~ Done 2026-10-17, in one commit with the necro corpse fix. Version strings are already 0.36.1 (Makefile, info.json, FOMOD, manifest.json). Ship as 0.36.1 after step 1.
3. Once users confirm, remove the `DEBUG-DELETE(pplus-animdb)` blocks (checkpoint v02).
