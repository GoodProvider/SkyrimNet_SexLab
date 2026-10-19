# Checkpoint 03: "Dead actors can join scenes" tested in game, committed

Repo `SkyrimNet_SexLab` · branch `main` · 2026-10-19. Supersedes [02-checkpoint.md](02-checkpoint.md).

## Status
- The maintainer tested the toggle in game and it worked: the necro scene was no longer cancelled.
- "(untested)" is dropped from the "Dead actors can join scenes" topic in all three changelogs.
- Committed as `0.36.3: Dead actors can join scenes toggle (tested)`, which holds the C++, the DLL, the manifest toggle and the docs.
- The Papyrus side shares .psc/.pex files with the no-narration fix, so it went into the next commit: `0.36.3: start DN before bookkeeping, silence nudge, receiver wording`. It covers `IsDeadAllowed`, `CorpseHealth_*`, `EnsureSexLabActorsValid` and `MultiTarget_Menu_Selection`.

## Still open
1. NECRO-DBG instrumentation is still in the code (`grep -rn NECRO-DBG Scripts/Source`). Remove it, rebuild with pyro, and run `make check-pex`.
2. 02 §5 items 2–4 are not verified: the effect of the lifted corpse on revive mods, the floor order vs. other `HookAnimationStarting` handlers, and the position mix-up / "None and None Finish" afterglow.
3. P+: whether `AddActor` accepts a corpse from our TargetMenu.
