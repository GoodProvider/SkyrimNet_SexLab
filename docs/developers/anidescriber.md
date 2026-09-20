# AniDescriber

SKSE module that **would** fill missing SexLab stage descriptions from Havok clips. **AnimationDB** remains the source of truth for registry rows and authored anidata.

**Status (2026-09-17): on hold.** HKX sampling is not wired into the live fill path. Missing stages use Papyrus `GetDescriptionFromTags` after authored anidata (and earlier-stage carry-forward in `GetThreadStageDescription`). Source stays in tree for later offline work.

Session handoff / historical bugs: [AniDescriber-checkpoint.md](AniDescriber-checkpoint.md).

File format: [anidata-schema.md](anidata-schema.md). Do not fork it here.

## Fill order (live)

For `(registry, stage)`:

1. Authored non-empty `stage N.description` in anidata (`animations/<provider>/`, `_local_` last). Never overwritten.
2. Papyrus `GetThreadStageDescription`: if current stage is empty, carry forward the nearest earlier authored stage.
3. Papyrus `GetDescriptionFromTags` if still empty.

Missing stages are **not** filled by copying an earlier authored sentence inside AnimationDB. `stage_has_description` is authored-only.

AniDescriber (when re-enabled) would sit between (1) and (3): sample whole animation on first miss, cache in `anidescriber.sql`, then serve generated stage text.

## Cache (dormant)

Sqlite table `anidescriber` beside `animationdb.sql`. Key: lowercase `registry` + hash of per-position-stage anim events. First call on an unseen registry would sample **every** stage, write descriptions + `orgasm_expected`, then serve later stages from cache. Only successful samples (`sampled: true`) are stored; failed payloads are not reused. Invalidate on force AnimDB rebuild or anim-event change. Empty `anim_events` (e.g. post-ALTER) triggers an automatic AnimDB force rebuild via `AnimDb_NeedsEventBackfill`.

Does not write pack or `_local_` JSON.

## Clips (dormant)

SexLab `FetchPositionStage` events (synced as `_anim_events`) join to `{event}.hkx` under `meshes/actors/.../animations/` (loose + BSA via `BSResourceNiBinaryStream`). Fallback filenames: `{event}.hkx`, and `B_B_Foo_A1_S1` → `B_Foo_A1_S1.hkx`. Human XPMSE skeletons: `meshes/actors/character/character assets/skeleton.hkx` and `skeleton_female.hkx`. Creatures: no sample, empty string.

## Landmarks and contacts

Sample mid-clip (and start/end; keep contacts seen in at least two samples). World-space bones (name match, optional `[short]` suffix stripped):

| Landmark | Bones / fallback |
|----------|------------------|
| pelvis, spine, head | `NPC Pelvis`, `NPC Spine2`, `NPC Head` |
| mouth | jaw if present, else head + forward offset |
| L/R hand | `NPC L Hand`, `NPC R Hand` |
| L/R breast | `NPC L/R Breast`, else chest offset from spine |
| L/R butt | `NPC L/R Butt`, else behind pelvis |
| penis | SOS `NPC Genitals06` / schlong chain, else male pelvis forward |
| pussy | XPMSE pussy nodes, else female pelvis forward/down |
| anus | behind pelvis |

Distances in Skyrim units (cm): **in** ≤ 12, **on** ≤ 25. Self-touch counts.

Posture: standing / kneeling / all-fours / sitting / supine / prone. Relative: behind / in front / astride / beside / over-the-knee.

## Sentences

Present tense. Only `{{sl.actors.N}}`. Possessives allowed. No names, clothing, or invented furniture. Up to about six clauses: genital contact, then hands/mouth on body, then kiss, then arrangement.

## `orgasm_expected`

Authored JSON array wins when length matches actor count. When AniDescriber is re-enabled, it would infer animation-wide:

- **Genital touch:** that actor’s penis, pussy, or anus is in/on a hand, mouth, or another actor’s genitals on any stage.
- **Cum:** deposit site (face, mouth, chest, pussy, anus) from late-stage genital→site proximity and/or SexLab tags `Facial`, `CumInMouth`, `AirCum`, `ChestCum`, `Creampie`, `AnalCreampie`. Donor is the actor whose genitals are near that site. Example: cum on actor.0’s face and actor.1’s genitals near that face → actor.1 orgasmed. Receiving cum is not an orgasm bit.

While on hold, `InferOrgasmExpected` tag rules apply as before.

## Code

`SKSE_Source/include/AniDescriber.h`, `SKSE_Source/src/AniDescriber.cpp`, `HkxAnim.cpp`. Compiled into the DLL with `SKYRIMNET_ANIDESCRIBER_HKX=0` (no clip sample; stripped `anim_events` / `speaking_authored` / `ApplyGeneratedFill` are not compiled). Not called from `AnimationDB::GetStageDescription` while on hold. Planning notes under `descriptor/` are not shipping code or data.
