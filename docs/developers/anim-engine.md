# AnimEngine and the SLAL registry

AnimEngine is the planned C++ replacement for SexLab's scene thread (`sslThreadModel` / `sslThreadController` / `sslActorAlias`). It drives actors through SLAL animations itself: actor lock, center, offsets, stage events, timers, teardown, plus bone IK for alignment. AnimDB is the animation registry. It loads SLAL packs from disk; SexLab's registry is not used.

**Status (checkpoint 02, 2026-10-25):**
- **Verified in game (AE):** the AnimDB SLAL registry (§1–§2).
- **Built, untested in game:** the SLSB (SexLab P+) registry, playback v2 stage graphs (§3) and the AnimEngine core with a debug start (§4). Both are off by default (`sexlab.anim_engine.slsb_registry`, `sexlab.anim_engine.enabled`).
- **Design only:** IK, contacts and the C++ Scene layer (§5–§9).
- Progress is tracked in `checkpoints/anim-engine/`.

No SexLab code goes into AnimDB or AnimEngine. SexLab P+ is supported in the C++ path: its scenes load from SLSB files and play through the same graph engine. The legacy Papyrus scene path keeps working until the C++ Scene layer replaces it.

## Files

| Part | Path |
|------|------|
| SLAL loader (packs, FNIS lists, PPA tags → rows + playback) | `SKSE_Source/src/SlalLoader.cpp`, `include/SlalLoader.h` |
| SLSB loader (P+ scene packs → rows + playback graph) | `SKSE_Source/src/SlsbLoader.cpp`, `include/SlsbLoader.h` |
| Shared source helpers (VFS Data dir, stamps, FNIS index) | `SKSE_Source/src/AnimSources.cpp`, `include/AnimSources.h` |
| Storage (`ReplaceRegistryRows`, `DropRowsExceptSource`, `GetPlayback`, `anim_playback`, `anim_enabled`) | `SKSE_Source/src/AnimationDB.cpp`, `include/AnimationDB.h` |
| Papyrus natives (`AnimDb_SyncFromSlal` / `…Slsb`, `AnimDb_GetPlaybackJson`, `AnimDb_SetEnabled`, …) | `SKSE_Source/src/Papyrus_AnimationDB.cpp`, `Scripts/Source/SkyrimNet_SexLab_AnimDb.psc` |
| AnimEngine (scenes, graph cursor, events, placement, co-save `ANME`) | `SKSE_Source/src/AnimEngine.cpp`, `include/AnimEngine.h`, `src/Papyrus_AnimEngine.cpp` |
| AnimEngine Papyrus shell (lock, hold, unlock) + natives | `Scripts/Source/SkyrimNet_SexLab_AnimEngine.psc` |
| OrgasmEngine bridge (enjoyment, gate, endings, victim hold for AnimEngine scenes) | `SKSE_Source/src/AnimEngineOrgasm.cpp`, `include/AnimEngineOrgasm.h` |
| Debug start (WebUI Settings → AnimEngine) | `SKSE_Source/src/WebUI.cpp` `AnimEngineDebug`, `PrismaUI/views/SkyrimNet_SexLab/index.html` `settingsAnimEngine` |
| SexLab built-ins as a SLAL pack (dev-time converter, output ships) | `tools/sexlab_defaults_to_slal.py` → `SKSE/Plugins/SkyrimNet_SexLab/slal/SexLab_Builtin.json` |
| Offline mirror of both loaders (stats / dump / parity against an old DB) | `tools/slal_offline.py` (`--source slsb`) |
| Planned: IK, contacts, Scene layer | `src/AnimIK.cpp`, `src/AnimContacts.cpp`, `src/SceneDirector.cpp` (+ split files) |

**`SexLab_Builtin.json` ships, AE only in effect.** The AE registry drops every non-SLAL row, so this pack is the only source of SexLab's 161 built-in animations (their hkx and FNIS list come with SexLab AE, a hard dependency). `make release` copies all of `SKSE/` into `core`, so no FOMOD option is needed; on P+ the SLAL loader never runs.

## 1. Who owns the AnimDB table

| Profile | Owner | How |
|---------|-------|-----|
| SexLab AE | `SlalLoader` | `AnimDb.psc` `UsesSlalRegistry()` is true. `StartSync` and `CheckAlignmentOnLoad` call `AnimDb_SyncFromSlal(force, drop_legacy=True)`. Rows get `source = 2` (`AnimationDB::kSourceSlal`). Afterwards `DropNonSlalRows` removes rows that the old SexLab registry walk pushed. |
| SexLab P+, `sexlab.anim_engine.slsb_registry` on | `SlsbLoader` | `UsesSlsbRegistry()`; `AnimDb_SyncFromSlsb(force, drop_legacy=True)`. Rows get `source = 3` (`kSourceSlsb`) and keep the scene id's case (`_case`). |
| SexLab P+, setting off (default) | Papyrus walk (`WalkPPlusBatch`) | `BeginSync` / `EndSync` wipe and prune **every** row (and the playback table), loader rows included. MO2's `overwrite` (where `animationdb.sql` lives) is shared between profiles. |

- The SexLab AE registry walk (`BuildAnimJson`) was removed.
- The load runs on a worker thread. `ReplaceSlalRows` takes the DB lock in chunks of 64 rows, so Papyrus and WebUI readers wait for at most one chunk.
- If no source file changed (mtime:size stamps in `playback_sources`, keyed `<source>|<path>`), the load logs `unchanged (…), skipped reparse` and stops. The stamps include `@playback_format` = `kPlaybackFormat`, so a playback format change reparses once.
- The P+ switch to `SlsbLoader` waits for in-game parity with the walk (checkpoint 02 Next). `AnimDb.psc` `UsesCppRegistry()` covers both loaders.

## 2. Sources and derivation (`SlalLoader.cpp`)

Data root = `<exe dir>/Data` (the MO2 VFS view).

| Source | Read |
|--------|------|
| `SLAnims/json/*.json` | SLAL packs, the same files `slalData.reloadData` reads. Keys follow `slalLoader.psc:126-211`. |
| `SKSE/Plugins/SkyrimNet_SexLab/slal/*.json` | Our packs, same format. They load after `SLAnims`, so a later duplicate id wins. |
| `meshes/actors/**/animations/<pack>/FNIS_*_List.txt` | Stage event → hkx path, line kind, AnimObjects (`-o … AO_x AO_y`), animvars (`-AVbHumanoidFootIKDisable`), acyclic (`-a`). Comment lines start with `'`. If the same event appears in several lists (Billyy ships `_canine_` / `_dog_` / `_wolf_` copies), the first one wins. |
| `SKSE/Plugins/ppa-animation-tagging/*.json` | Optional: Penetration Physics stage targets, joined by animation **name**. |

**Row (as Papyrus used to push it):**
- `registry` = lowercase SLAL `id`.
- `name`.
- `position_count` = number of actors.
- `stage_count` = position 0's stage count.
- `pos_genders` from the actor `type`: Male / Female / Creature / CreatureMale / CreatureFemale → 0/1/2/2/3. Unknown types count as Male, as SLAL treats them.
- `pos_race_keys` from `race` (creature positions only; falls back to `creature_race`).
- `race_type` = the last creature key.
- `has_creature` when `creature_race` is present.
- **Tags** = the SLAL `tags` plus what `sslBaseAnimation.Save()` adds:
  - The position-order gender string and its reverse (e.g. `FM` / `MF`).
  - For 3+ actors, `F…M…C` and `C…M…F` by count.
  - `interspecies` when two adjacent creature keys differ. This approximates SexLab's race-id set comparison.
  - Empty tags are dropped. SexLab's raw tag arrays keep `""`.
- **`enabled`:** from the `anim_enabled` table (`AnimDb_SetEnabled`), default 1. SLAL's own enable state lives in JContainers' JDB inside the save, so C++ cannot read it.

Offline parity (`tools/slal_offline.py parity`) against the SexLab-built DB of the `SkyrimNet SexLab` profile:
- 719 rows match.
- 3 tag differences, where the SLAL json is newer than the registration stored in the save.
- 43 rows missing: stale Billyy furniture registrations kept by SexLab whose json is no longer on disk.
- 527 extra rows: packs SexLab had not registered, or creatures.

### SLSB sources (`SlsbLoader.cpp`, SexLab P+)

| Source | Read |
|--------|------|
| `SKSE/SexLab/Registry/Source/*.slsb.json` | SLSB project files: `pack_name`, `prefix_hash`, `scenes{id → {name, root, graph{stage → {dest[]}}, furniture{furni_types, allow_bed, offset xyzr}, stages[{id, tags[], extra.fixed_len, positions[{sex{male,female,futa}, race, event[], scale, extra{climax,…}, offset xyzr, anim_obj, schlong}]}]}}`. |
| `SKSE/SexLab/Registry/*.slr` | Only stamped and matched to a json by the header `pack_name` (u8 length at byte 8). A `.slr` with no json is logged (`slr_without_json`); its scenes are not in AnimDB. |
| FNIS lists | Same index as SLAL. SLSB events are `<prefix_hash><event[0]>` (`xujsCan_B_BoobJ_A1_S1`). |

**Row (as `BuildAnimJson_PPlus` pushed it):**
- `registry` = scene id, case kept (`_case: 1`).
- `pos_genders` from the root stage's positions: human male or futa 0, female 1; creature 2, female-only creature 3 (`SkyrimNet_SexLab_PPlus.PositionGenders`).
- `pos_race_keys` = the SLSB `race` display name for creatures, `""` for `Human`. P+ `GetRaceKeyPositionA` returns its race keys (`Dogs`, `Draugrs`, …); the mapping waits for in-game parity.
- `stage_count` = number of stages (P+ `GetNumStages`).
- **Tags** = the union of the stage tags in stage order (SLSB copies the SLAL animation tags onto each stage and adds per-stage acts).
- `enabled` from `anim_enabled`, default 1 (P+'s enable state lives in P+).

Offline (`tools/slal_offline.py --source slsb`, `Automated SLSB Conversions 0.9d`): 40 packs, 1212 scenes, 13 659 stage positions, 0 branching scenes, 0 missing FNIS events, every `.slr` matched to a json.

## 3. Playback JSON (`anim_playback.playback`, contract)

Version 2 (`kPlaybackFormat`). Every animation is a stage graph; SLAL animations are the linear graph `"1"` → `"2"` → … → sink.

```json
{"v":2,"format":"slal","slal_id":"B_B_SKiss1","pack":"Billyy_Human","name":"Billyy Kissing","sound":"none",
 "creature_race":"","stage_count":5,"root":"1",
 "nodes":[{"id":"1","n":1,"dest":["2"],"tags":[],"fixed_len":0},
          {"id":"3","n":3,"dest":["4"],"tags":[],"fixed_len":0,"timer":12.0,"sound":"Sucking"}],
 "positions":[{"type":"Female","gender":1,"race":"","add_cum":-1,
   "stages":[{"event":"B_B_SKiss1_A1_S1",
     "hkx":"meshes/actors/character/animations/Billyy_Human/B_SKiss1_A1_S1.hkx",
     "kind":"s","objects":[],"animvars":["bHumanoidFootIKDisable"],"acyclic":false,
     "fwd":0,"side":0,"up":0,"rot":0,"silent":true,"open_mouth":false,"strap_on":false,"sos":0,
     "fnis":true,"interact":{"site":"auto","target":-1,"src":""}}]}],
 "missing_fnis":0,"missing_hkx":0}
```

SLSB blobs have `"format":"slsb"`, `scene_id` instead of `slal_id`, a top-level `furniture{types, allow_bed, offset[fwd,side,up,rot]}`, positions with `futa` (`type` is `""`), and per-stage `anim_obj`, `climax`, `schlong`, `scale`.

| Key | Meaning |
|-----|---------|
| `root` / `nodes` | The stage graph. `nodes` is in file order; `n` (index + 1) is the legacy stage number (P+ `GetLegacyStageNum`). `dest` = next node ids, empty at a sink. SLSB nodes carry their `tags` and `fixed_len`; SLAL nodes carry `timer` / `sound` from SLAL `stages[{number,timer,sound}]`. |
| `positions[p].stages[i]` | Parallel to `nodes[i]`. |
| v1 (checkpoint 01) | Had a top-level `stages{"n":{timer,sound}}` map and no `nodes`. `GetPlayback` still reads it as a linear graph. |
| `add_cum` | Read only for female / creature-female positions (as SLAL does). 1 V, 2 O, 3 A, 4 VO, 5 VA, 6 OA, 7 VOA, -1 none. |
| `strap_on` | Missing = false (SLAL's `JMap.getInt`). `SexLab_Builtin.json` writes every value explicitly, because SexLab's own `AddPositionStage` default is true. |
| `fnis` / `missing_fnis` | The stage event was found in an FNIS list. A missing event can never play through `NotifyAnimationGraph`. |
| `missing_hkx` | The hkx is not a loose file (it may still be in a BSA). Informational only. |
| `interact` | Penetration target for the IK and contact passes: `site` is one of V A M H LH RH none auto; `target` is a 0-based position or -1; `src` is ppa, anidata (planned) or "". |

**`interact` resolution order:**
1. Anidata `stages[N].actors[i].interact` (planned; [anidata-schema.md](anidata-schema.md)).
2. PPA tags. PPA positions 1–5 map to 0–4. `!` and unknown strings are none. With `manual: true`, positions left out are none.
3. `auto`.

C++ reads it with `AnimationDB::GetPlayback(registry)` (cached, returns a `PlaybackData` struct). Papyrus/debug reads it with `AnimDb_GetPlaybackJson(registry)`.

## 4. AnimEngine runtime (built in checkpoint 02, untested in game)

**Wiring:**
- Co-save record `'ANME'`: the actors of running scenes. Scenes do not survive a load; `Load` releases those actors (`IdleForceDefaultState` + shell `Unlock`). `Revert` drops every scene.
- A tick thread posts `Tick` with `AddTask` every 100 ms while a scene runs (the `OrgasmEngine` pattern). All scene state is behind one mutex; game calls run on the main thread.
- Gated by dashboard `sexlab.anim_engine.enabled` (Debug category, default off).

**Scene:**
- `{id, registry, PlaybackData, actors[pos], center{x,y,z,rz}, node, history[], stage_started, duration, paused, pending events, placed[pos]}`.
- API (`AnimEngine.h`): `StartScene(actors by position, registry, center)`, `Advance` (first edge; at a sink the scene ends), `GoToNode`, `Back` (history), `SetPaused`, `EndScene`, `SceneOf`, `LatestScene`, `DescribeJson`, `OrderForRegistry` (debug: actors to positions by gender).
- `StartScene` takes an `ActorLocker` lock per actor. An actor that is already locked, in a SexLab / OStim scene, or in an AnimEngine scene is refused.
- ModEvents: `SNSL_AE_SceneStart` (str registry, num scene id), `SNSL_AE_StageStart` (str node id, num legacy stage), `SNSL_AE_SceneEnd`.
- OrgasmEngine (checkpoint 12, untested in game): every stage entry, pause change and end posts a note to `AnimEngineOrgasm`, which wires the scene into the OrgasmEngine natively (see [orgasm-engine.md](orgasm-engine.md#animengine-scenes); setting `sexlab.anim_engine.orgasm_engine`, default on).
  - `StartScene(…, roles)`: OrgasmEngine roles per position (the debug panel's **Victim** select).
  - `SetHold(id, gate | victim | ending, on, node)`: a held stage does not auto-advance, and its clock keeps running. Entering a stage clears all holds.
  - `GoToFinal(id)`: jump to the projected final node.
  - `StageView`: the engine's stage / count / seconds. A linear graph uses node order; a branching graph uses history + current + the first-edge chain to a sink.
  - Pause keeps the stage's elapsed time; resume continues it. Before checkpoint 12, resume restarted the stage.
  - HUD: the SexLab HUD shows for a player in an AnimEngine scene. Its end / previous / next / pause keys act on the acting actor's AnimEngine scene. With the HUD controls hidden, the AnimEngine hotkeys stay on.
- Papyrus: `SkyrimNet_SexLab_AnimEngine.AnimEngine_DebugStart(a, b, registry)` and `_Advance` / `_Back` / `_GoToNode` / `_SetPaused` / `_End` / `_SceneOf` / `_Describe` (scene id -1 = newest).
- Debug start: WebUI Settings → AnimEngine (shown while the setting is on) starts the typed registry on the player and the nearest living NPC within 400 units.

**Center:** the explicit ref, else the first actor. Without an explicit ref and with 2+ actors, the heading is the direction from pos 0 toward the others' average position (more than 10 units away), not pos 0's own facing. So the actors face each other and turn less. SexLab keeps the center's own facing. The SLSB scene furniture offset moves the center with the same math. Planned for the Scene layer: the victim, else the player (`sslThreadModel.psc:512-545`).

**Offsets:** the SexLab AE math (correct form at `PPLUS sslActorAlias.psc:1525-1548`):

```text
x = cx + sin(rz)*fwd + cos(rz)*side
y = cy + cos(rz)*fwd - sin(rz)*side
z = cz + up
az = wrap360(rz + rot)
```

P+ `OffsetCoords` uses the same math (`[0]` forward, `[1]` side at rz + 90°), so SLSB offsets `x, y, z, r` are `fwd, side, up, rot`.

CenterAdjust = −0.5 × the forward offset with the largest absolute value across positions of the stage, only with 2+ actors (`sslBaseAnimation.psc:928-941`). SLAL only.

**Start phases (checkpoint 04):** `Approach` → `Sheathe` → `Begin` → `Play`. Stage commands (Advance, Back, GoToNode, Pause) wait for `Play`. End works in any phase. `DescribeJson` has `phase`.
- **Approach** (dashboard `sexlab.anim_engine.approach`, default on): placements are computed for the root node.
  - An actor farther than 50 units from its spot gets the shell call `Approach(actor, partner, x, y, z, az)`. It runs `SetLookAt(partner)` and `PathToReference(marker, 0.5)`, which needs no package. For the player it first calls `DisablePlayerControls` and `SetPlayerAIDriven`.
  - Actors already close get `LockFace(actor, x, y, z, az)` and wait: `Lock`, then a visible turn in place to az (toward the partner), on one stack.
  - The tick checks once per second. A walker is done when `PathToReference` returns (counted with an `IStackCallbackFunctor`), when it is within 50 units, or after 4 checks with less than 1 unit of progress (stuck). After 30 s every walker is treated as done.
  - SexLab only walks to within 100 units of the center (`PathToCenter`, `sslActorAlias.psc:537-582`, a faction-rank travel package). We walk to the pose spot itself, which is usually inside the partner's collision, so the walk stops short.
  - `Approach` and `LockFace` first call the shell's `Sheathe` (`StopCombat`, `StopCombatAlarm`, `SheatheWeapon`), so weapons go away during the walk or turn.
- **Sheathe:** once the approach is done, the tick (100 ms) waits until every actor's weapon state (`ActorState::GetWeaponState`) is `kSheathed`. Drawing and sheathing count as not done. Once per second it re-sends `Sheathe` to actors still `kDrawn`, for example when AI drew again. After 5 s it warns `weapons still drawn after 5 s for pos [..]` and runs Begin anyway. `SheatheWeapon` only starts the animation; without this wait, Begin's `Snap` and the root stage events cut the sheathe off. SexLab P+ waits for the player the same way (`BeginPlayerSheatheWait`, `sslThreadModel.psc:938`). The no-walk path benefits too: `LockFace` and `Begin` were dispatched in the same tick and raced (Lock ran twice per actor).
- **Begin:** the shell `Begin(actor, x, y, z, az)` runs `Lock` then `Snap` on one stack. `Snap` is a hard `SetPosition` / `SetAngle`, as SexLab does at the start (`sslActorAlias.psc:602-606`), then `Hold`. The root stage events wait until every Begin has returned (5 s failsafe). Before this, `Lock` and `Place` were separate dispatches that could interleave, and the events fired before `Lock` ran.

**Lock (the Papyrus shell `SkyrimNet_SexLab_AnimEngine.psc`, called with `DispatchStaticCall`):**
- `Lock`: `ClearLookAt`, StopCombat, sheathe. NPCs get `SetRestrained` + `SetDontMove`; the player gets `ForceThirdPerson`, `DisablePlayerControls`, `SetPlayerAIDriven`. Both get the package override `SkyrimNet_SexLab_AE_DoNothing` (`00081D`, priority 100) + `EvaluatePackage`, as SexLab does (`sslActorAlias.psc:1317`). Then `StopTranslation`, the marker `MoveTo` the actor, and `SetVehicle(marker)` (SexLab `LockActor`). Locking should also end a walk that is still running; this is not verified in game yet.
- **Marker:** `SkyrimNet_SexLab_AE_Marker` (`00081E`, Furniture), a copy of SexLab's `SexLabBaseMarker` (`045A93:SexLab.esm`; vanilla `Furniture\WallLeanMarker.nif`, no SexLab asset). `EnsureMarker` places it once per actor, waits up to 5 s for `Is3DLoaded` and keeps it in StorageUtil. **Do not use a bare XMarker** (`Skyrim.esm` 0x3B): it has no 3D, and an actor attached to it as a vehicle is pulled back to where it was placed (the checkpoint 04 loop bug).
- `Place` (every stage): move the marker, `SetVehicle(marker)`, then move the actor. More than 100 units away: `SetPosition` / `SetAngle`. From 2 to 100 units, or more than 3° off: `TranslateTo` at 200 units/s and 360°/s, a visible glide and turn. Otherwise `Hold`.
- `Hold`: SexLab's `Snap` (`sslActorAlias.psc:893-914`), plus an angle check. Within 2 units but more than 3° off, it does a fast turn (`TranslateTo` at 720°/s) and logs `Hold: <name> angle off <deg>`, in place of the 0.0001°/s pin (see KNOWLEDGEBASE "TranslateTo pin cancels a turn"). The tick re-sends it every 1 s, since a global script gets no `OnTranslationComplete`.
- `Unlock`: `ClearLookAt`, `StopTranslation`, `SetVehicle(None)`, delete the marker, remove the package override, restore restraint / controls, `EvaluatePackage`.
- The package (`Spriggit/SkyrimNet_Sexlab/Packages/`) is a copy of `SexLabDoNothing` (`00E50E:SexLab.esm`: one `Wait` procedure, `StopMovement`) without its `SexLabAnimatingFaction` condition. PapyrusUtil saves package overrides, so the co-save release on load also goes through `Unlock`.
- Later: a per-frame pin in the `AnimSpeed` UpdateAnimation hook.

**Events** (`NotifyAnimationGraph` on the main thread; delays are scheduled by the tick, never slept):

| Case | Sequence |
|------|----------|
| Stage 1 | `AnimObjectUnequip` → `IdleForceDefaultState` (creature defaults: `sslActorAlias.psc:1234-1293`) → 0.2 s → S1 |
| Next stage, same animation | Sn |
| Animation change | default → S1 → 0.2 s → Sn. FNIS `s`/`+` sequences must be entered at S1. |
| Realign | `SexLabSequenceExit1` → default → S1 → Sn |

Built:
- Stage 1 takes the default → event path.
- Jumps (Back, GoToNode, a non-sequential edge) use `QueueJump`:
  - The target is a `+` stage, and the actor is in its sequence: Sn is sent directly, backward too, as `sslActorAlias.psc:739-763` SendAnimation does. This blends the way Next does.
  - The target is the `s` stage (S1), sent from inside its sequence: the full re-entry (log `jump reenter`). The graph accepts S1 only from the default state, so this cannot blend. SexLab snaps here too (`sslActorAlias.psc:742-745`; KNOWLEDGEBASE "Re-entering an FNIS sequence").
  - Any other case: a `b` or unknown stage is sent directly. For a `+` stage outside its sequence, the full re-entry is used.
  - While the game is paused (any pausing menu, including the WebUI debug panel), Tick freezes the pending events and the stage timer, so stage time counts only while the game is running.
- Full re-entry (`QueueReentry`, RefreshActor timing `sslActorAlias.psc:855-862`): `SexLabSequenceExit1` + `AnimObjectUnequip` + default → 0.2 s → S1 → 0.2 s → Sn. The Sn step is used only for a `+` target.
- When a stage event is refused, that position takes the full re-entry, up to 2 times. Only then is the stage marked unplayable. Creature default states (`sslActorAlias.psc:1234-1293`) and AnimObject equipping are not done yet (logged).

If an event returns false, the stage is logged once as unplayable (`DescribeJson` lists it). That is the hook for the later injection fallback (OAR's FakeClipGenerator technique, reimplemented, not copied: GPL).

**Hotkeys:** while an AnimEngine scene runs and the SexLab HUD is not up, the dashboard HUD keys for `end` / `previous` / `pause` / `next` (default Num 2 / 4 / 5 / 6) end the scene, step back, toggle pause and advance. The keys act on the player's scene, else the newest one (as the debug panel does), and are consumed like the HUD keys. They are off while the WebUI is open or a pausing menu, the console or dialogue is up (`Hud::Tick` → `KeyHandler::SetAnimActive`). Log: `Hud: AnimEngine key <ctl> scene <id> -> <ok>`.

**Scene registry:** start and end register the scene in `Scenes::Registry` as `(animengine, id)` (scene-migration.md §8 step 1).

**Timers:** the node `timer`, else its `fixed_len`, else 30/20/15/15 by stage index and 9 at a sink (the climax). A paused scene holds until it is stepped; resuming restarts the stage time.

**Teardown:** `AnimObjectUnequip`, `IdleForceDefaultState`, shell `Unlock`, `ActorLocker::Unlock`. A scene also ends when an actor dies or unloads.

**Cosmetics:** SOS `SOSFastErect` / `SOSBend<n>` / `SOSFlaccid` come first. Strap-on, open mouth, sound, cum and strip come later, all with our own forms.

## 5. Bone IK (planned, checkpoint 04)

Penetration Physics (`AccuratePenetration.dll`, closed source) finds scenes by scraping SexLab threads. Its API V1 is listener-only, so it never sees AnimEngine scenes. AnimEngine does its own IK; only PPA's public data files are read.

**Config** `SKSE/Plugins/SkyrimNet_SexLab/anim-ik.json`:
- The penis chain. Default: `NPC GenitalsBase [GenBase]`, `NPC Genitals01..06`, forward axis +Y. Per-race creature chains are keyed `"Plugin.esm|FormID"`.
- Orifice entry points (anchor bone + offset + cylinder) and waypoint splines. Seed values from PPA's defaults:
  - vagina: `NPC Pelvis [Pelv]` (0.07, -1.37, -3.34)
  - anus: Pelvis (0, -4.95, -1.17)
  - mouth: `NPC Head [Head]` (0, 1, -1.15)
  - canal waypoints via Spine1 / Neck / Spine2
- Hands (hand bone + grip offset), solver limits, smoothing.

**Hook:** after the pose and after CBPC/SMP, before skinning. First try a post-call in the existing `UpdateAnimation` vfunc hook (`AnimSpeed.cpp`); if CBPC overwrites, use a late-frame hook. Only actors in an AnimEngine scene are processed (atomic fast path).

**Target:** the stage `interact` (forced, none, or auto). Auto scores the partners' entry cylinders against the tip ray, with hysteresis.

**Solve:**
- Path = base → entry → canal spline (Catmull-Rom, corner smoothing).
- Depth = the animated tip projected past the entry plane.
- Joints sit at the bone arc lengths. Each bone aims its forward axis at the next joint, converted to parent-local and clamped to the bend cone.
- Write `local.rotate` and update the chain. Smoothing scales with `AnimSpeed::Get`.

**Fallback:** when the bend limits can't reach, a small, clamped, smoothed fwd/side/up nudge on the penetrator. Learned per-(registry, stage, pos) deltas go in an `anim_align` table.

## 6. Body-size adaptation (planned, checkpoint 04d–e)

Contacts are stored relative to the partner's **bones**, not world space, so height, scale and skeleton differences resolve against the real skeleton.

1. **Offline contacts** (`anim_contacts` table, cached by hkx mtime):
   - Place each position's clip using the SLAL offsets on the reference skeleton.
   - Sample 16 times with `HkxAnim::SampleAnimation`.
   - Wherever an effector (hands, head; later feet) comes within ~6 units of a partner bone (head, neck, spine, pelvis, thighs, breasts, butt), record `{pos, effector, target_pos, target_bone, local_offset, weight[16]}`.
   - Risk: the sampler is unexercised since the AniDescriber hkx path was compiled out (`SKYRIMNET_ANIDESCRIBER_HKX=0`).
2. **Root fit:** a clamped up/fwd correction per non-anchor actor, minimizing the weighted contact error (genital > hand > other) against the live bones. It replaces SexLab's `ScaleActors` normalization, which stays as a config fallback.
3. **Arm/head IK:**
   - Two-bone analytic IK for the hand; the pole comes from the animated elbow.
   - Blend = the `weight` curve at the clip's local time (active `hkbClipGenerator`) × a reach limit.
   - Head/neck IK for oral, together with the penis solver.
4. **Body width:** morphs move the mesh, not the bones. First a surface push along the bone→hand direction; later snapping to skinned-mesh vertices.

**Solve order per frame:** root fit → penis chain → arm/head contacts.

## 7. Contact-driven enjoyment (planned, checkpoint 04f)

The same geometry feeds OrgasmEngine ([orgasm-engine.md](orgasm-engine.md), "Contact mode (planned)").

**Receiver sites:** penis (the chain), a strap-on (virtual chain while equipped), vagina and anus entries.

**Stimulators:** a partner's hand, penis or strap-on, vagina (tribbing) or mouth; the actor's own hand for masturbation.

**Per tick:**
- `stim = max(closeness × relative motion)`, plus IK depth, with hysteresis and a short hold.
- Sent with `SetStimulation(actor, level, sites)`: passive gain = rate × level. In contact mode, an actor with no contact gains nothing passively.
- First contact → `SetOrgasmExpected(actor, true)`, sticky for the scene.
- The sites drive `SetSceneActs`.

The offline contacts also give AnimDB a geometry-based `orgasm_expected` default, better than tag inference. Anidata still wins.

## 8. Scene layer in C++ (planned, checkpoints 02–05)

`SkyrimNet_SexLab_Scene.psc` (216 functions), `Scene_Manager.psc` (77) and `Scene_Creator.psc` (60) move to a C++ `Scenes` namespace, in a strangler pattern.

| Papyrus area | C++ owner |
|--------------|-----------|
| Creator: cast, lock, tag resolve, `SelectAnimations`, `TryStartScene` | `Scenes::Creator` (ActorLocker, ResolveTags, QueryTopNAnims are already C++) |
| Manager: registry, create/find, save/restore, `Web*` | `Scenes::Registry` + direct WebUI calls, co-save |
| Scene: `Stage*`, `Anim*`, `Engine_*`, `Orgasm*`, `Ending_*`, `Gate_*`, `Victim_*`, `Web*`, state | `Scenes::Scene` over AnimEngine + OrgasmEngine |
| Scene: `Narrate*`, `Silence*`, `Note*`, `Mark*` | NarrationQueue / NarrationTiming / SkyrimNet C++ API |
| Scene: `SLA_*`, DOM / UDNG handlers | Thin Papyrus shell (Papyrus-only mods), via ModEvents |
| Scene: `PPlus_*` (graph moves, timers, sink handling) | `Scenes::Scene` over the AnimEngine graph cursor (P+ scenes come from `SlsbLoader`) |
| Scene: `Mirror_*`, `TM_*` (SexLab thread bridge) | Dropped with the SexLab path |

- `SkyrimNet_SexLab_Scene_Interface.psc` stays as a native-backed facade for other mods.
- The per-function inventory (owner / shell / dropped, outside callers, strangler order) is in [scene-migration.md](scene-migration.md).

## 9. Roadmap

| Checkpoint | Scope |
|------------|-------|
| 02 | SLSB (P+) registry loader + offline parity; playback v2 stage graphs; AnimEngine core; debug start (one animation, 2 actors) |
| 03 | Scene-migration inventory (done: [scene-migration.md](scene-migration.md)); `Scenes::Creator` + `Scenes::Registry`; OrgasmEngine stage wiring; P+ switch-over once parity holds |
| 04a–f | IK: chain read and target pick; solver and hook point; offset nudge and `anim_align`; offline contacts and root fit; arm/head IK; contact-driven stimulation |
| 05+ | The rest of `Scenes::Scene`; then remove the legacy Papyrus scene path, the SexLab thread dependency and the P+ thread bridge (P+ scenes keep playing through AnimEngine) |
| Later | Cosmetics, orifice gape, mouth open; injection fallback for stages without FNIS events; a binary `.slr` reader if a pack ships without its `.slsb.json` |
