# 02 — no-narration: tested in game, committed

Repo `SkyrimNet_SexLab` · branch `main` · 2026-10-19. Supersedes [01-checkpoint.md](01-checkpoint.md).

## Status
- The maintainer tested the fix in game and it worked: the start DN is prompt, the silence nudges fire, and the receiver wording is right.
- "(untested)" is dropped from the Scene narration topic in all three changelogs. The KNOWLEDGEBASE entry now says tested in game.
- Committed as `0.36.3: start DN before bookkeeping, silence nudge, receiver wording`. That commit also carries the necro Papyrus side (see [../necro-animations/03-checkpoint.md](../necro-animations/03-checkpoint.md)).

## Still open
1. The cause of the slow Papyrus VM is unknown (01 §Risks): `GetThread` runs about every 1 s, plus the NECRO-DBG snapshots.
2. Reply to Delicious Nuts and ask them to retest with the 0.36.3 build.
