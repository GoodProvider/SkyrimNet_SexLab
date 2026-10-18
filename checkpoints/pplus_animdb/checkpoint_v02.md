# P+ AnimDB — checkpoint v02 (2026-10-18)

## Status

User verified SexLab P+ in game (AnimDB build, scenes). `(untested)` removed from "SexLab P+" (0.36.0) and "AnimDB bug" (0.36.1) in all three changelogs; the "Not verified in game yet" section of `docs/developers/sexlab-pplus.md` is gone.

## Instrumentation removed

Every `DEBUG-DELETE(pplus-animdb)` block from v01 is gone (C++, AnimDb.psc, PPlus.psc, header stubs): `AnimDb_LastSyncFailures`, `SceneDebug`, `NoteBatchResult`, the `g_sync_batches` / `g_sync_rows_*` counters, the second `EndSync` line, the `DEBUG` traces. Both walk loops call bare `AnimDb_PushAnimBatch(json)` again; `AllSceneIds` returns `CreateProxyArray(0, creature)` directly.

## Kept (permanent)

- `AnimDb_PushAnimBatch` unescape retry; one `parse failed len= byte= … near=` warn on the first failure per sync (was the first 3 with `head=`).
- `NoteBatchParseError` / `NoteBatchDropped`; `EndSync` error "every batch failed to parse" now tests `g_sync_batches_dropped > 0 && g_rows.empty()` (was `g_sync_rows_received == 0`), plus the "needed unescaping" warn.
- `FinishSourceOrDone` `not_stored=` and the "AnimDB build failed" notification.
- `make check-pex`.

## Build

pyro main + P+ bridge: 0 failures; `make check-pex`: 29 pex, 0 bad; release DLL built and copied to `SKSE/Plugins/`. Not committed.
