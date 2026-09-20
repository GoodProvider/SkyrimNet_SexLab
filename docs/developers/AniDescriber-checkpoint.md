# AniDescriber checkpoint (2026-09-17)

Handoff from debug session: missing HKX narration → tags; CTD after spline patch (no CrashLogger for last two). Canonical product docs: [anidescriber.md](anidescriber.md). Quirks: [KNOWLEDGEBASE.md](../../KNOWLEDGEBASE.md).

## Status: on hold

HKX fill is **not active in-game**. `AnimationDB::GetStageDescription` returns authored stage text only; Papyrus falls through to `GetDescriptionFromTags`. AniDescriber / `HkxAnim` source remains for offline decoder work. No `Debug.Notification("Missing descriptions, inferring")`.

## Goal (when resumed)

Fill missing stage descriptions from human SexLab `.hkx` + XPMSE skeleton so narration is HKX-inferred, not Papyrus tag fallback (`GetDescriptionFromTags`).

## State at hold (after rollback)

| Layer | Status |
|-------|--------|
| Live fill path | **On hold.** Authored → earlier-stage carry-forward → tags. AniDescriber not called. |
| AnimDB `anim_events` | **Fixed.** Column ALTER left rows `[]`; counts matched SexLab so sync skipped. `AnimDb_NeedsEventBackfill` + PromptAlignment/BeginWalk force rebuild. |
| Skeleton pick | **Fixed.** XPMSE has NPC (~126) + Ragdoll (~18). `ParseSkeleton` prefers NPC (`bones_m=126` in log). |
| Clip paths | **OK.** BSResource `meshes/...`; index ~13k files; SexLabAP/SexLab fallbacks. Events like `AP_Cowgirl_A1_S1` resolve. |
| Spline sample | **Broken (pre-crash code restored).** `SampleAnimation` → `hkx_sample_fail`; tags used. Knot `std::clamp` when `lo > hi` no longer Debug-aborts (fail clean). |
| Fail cache | Failed Analyze not written to SQLite; in-memory session negative-cache. |

**Not fixed:** successful HKX sample → non-empty stage description. Tag narration is expected until spline decoder works and AniDescriber is re-wired.

## Call path (live)

```
StageStart → GetDescription → GetThreadStageDescription
  → AnimDb_GetStageDescription (authored only)
  → if empty, earlier authored stages
  → empty → GetDescriptionFromTags
```

## Call path (when resumed)

```
StageStart → GetDescription → GetThreadStageDescription
  → AnimDb_GetStageDescription
    → authored? return
    → else AniDescriber::Describe → EnsurePayload → Analyze
  → empty → GetDescriptionFromTags
```

Code: `Scripts/Source/SkyrimNet_SexLab_Scene.psc`, `AnimDb.psc`, `SKSE_Source/src/AnimationDB.cpp`, `AniDescriber.cpp`, `HkxAnim.cpp`.

## Log fingerprints (historical / when resumed)

| Symptom | Meaning |
|---------|---------|
| `adding column animations.anim_events` then no rebuild | Empty events until NeedsEventBackfill |
| `bones_m=18` | Ragdoll skeleton (old bug) |
| `bones_m=126` + `indexed N` + `hkx_sample_fail` | Skeleton+load OK; decoder fail |
| `inferring from HKX` then silence / exit | Died inside first Analyze/SampleSplineAll |
| Debug assert `std::clamp` / `invalid bound arguments` in `algorithm` | Knot `lo > hi` in `ReadSplineVector` (malformed/misaligned track). Guarded: now returns false → `hkx_sample_fail` (no CRT abort). Does **not** fix successful HKX narration. |
| Narration “having … sex / giving a blowjob” | Tag fallback |

Logs: `…/SKSE/SkyrimNet_SexLab.log`. Last two CTDs produced **no** `crash-*.log`.

## What crashed

Spline-decoder attempt (rolled back):

1. Parse `maskAndQuantizationSize` (+0x44); use **4-byte** mask stride (`ntracks*4`).
2. Map component subtype **3 → Static**.
3. `LastSampleFail()` detail strings.

Hypothesis that motivated the patch: SE uses 4-byte masks; old code used `ntracks*2`, then subtype 3 rejected → `hkx_sample_fail`. That change CTD’d (often mid-first sample after index). **Do not re-land blindly**; fix offline or with tighter fail/guards.

## Still in tree (keep for resume)

- `NeedsEventBackfill` + auto force rebuild (`AnimationDB.*`, `AnimDb.psc`)
- NPC `ParseSkeleton` scoring (`HkxAnim.cpp`)
- SexLabAP/SexLab `LoadClipBytes` fallbacks
- No SQLite store of `sampled:false`; session `g_fail_cache`
- SampleFail buckets: `load_fail` / `hkx_sample_fail` / `landmark_miss`
- Log `AniDescriber: {reg} inferring from HKX` (no HUD notify)

## Next work (suggested)

1. Offline harness: load `AP_KneelBlowjob_A1_S1.hkx` + skeleton → `SampleAnimation` without game; assert mid-pose pelvis/head.
2. Re-introduce 4-byte mask **only** with bounds checks; validate subtype-3 byte consumption vs Havok/`hkaSplineCompressedAnimation.h` in CommonLib.
3. If still CTD: isolate rotation/scale walk vs translation; log per-track before mutate.
4. Re-wire `GetStageDescription` → `AniDescriber::Describe` only after offline harness passes.
5. In-game smoke: either `sampled: true` narration or clean `hkx_sample_fail` (no hang, no notify).

## Build

Release: `cmake --build --preset build-release` from `SKSE_Source`, copy DLL → `SKSE/Plugins/`. HKX fill is compile-gated (`SKYRIMNET_ANIDESCRIBER_HKX=0`). Debug: `cmake --build --preset build-debug`. Papyrus: `compile: pyro` if AnimDb natives changed.

## References

- Docs: [anidescriber.md](anidescriber.md), [anidata-schema.md](anidata-schema.md)
- CommonLib: `hkaSplineCompressedAnimation.h` (`maskAndQuantizationSize` @ +0x44; type 5 = spline)
- Layout note: type 3 in AnimationType enum is **wavelet**, not spline
