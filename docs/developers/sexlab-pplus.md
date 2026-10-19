# SexLab P+

SexLab P+ ships the same script names as SexLab 1.6x (`SexLabFramework`, `sslThreadController`, `sslBaseAnimation`, …) and the same `SexLab.esm`. One install or the other is present, and `SkyrimNet_SexLab_Utilities.IsSexLabPPlus()` (`SexLabUtil` plugin version > 20000) picks the code path. Every 1.6x path is unchanged; P+ branches sit next to it as `if IsSexLabPPlus()`.

P+ scenes are directed graphs addressed by a case-sensitive NanoID. The legacy objects are proxies: `sslBaseAnimation.Name` / `Enabled` / tags stay empty (and an empty tag list makes `HasTag` true for every tag), `thread.Stage` is the length of the played history, `GoToStage(n)` moves one edge, and `UpdateTimer` sets `_ForceAdvance`.

## Bridge script and build

All P+ API calls live in one script, `SkyrimNet_SexLab_PPlus` (global functions taking `Quest` / `Actor` / `String`).

| File | Role |
|------|------|
| `Scripts/Source_PPlus/SkyrimNet_SexLab_PPlus.psc` | Real implementation, compiled against the P+ sources |
| `skyrimse-pplus.ppj` | Pyro project for the bridge only: imports `..\SexLab Framework PPLUS\Source\Scripts` before the 1.6x headers |
| `Headers_Source/SkyrimNet_SexLab_PPlus.psc` | Same signatures, empty bodies: what the main project (`skyrimse.ppj`, 1.6x headers) compiles against |
| `Headers_Source/SexLabPPlus/` | Header-only stubs P+'s own scripts need to compile (`MfgConsoleFuncExt`, `Lovense`, `VRIK`, SkyUI 5.2 `SKI_ConfigBase`); imported by `skyrimse-pplus.ppj` only |

`compile: pyro` (default task) builds the main scripts and then the bridge; `compile: pyro (P+ bridge)` builds only the bridge. Never ship main pex files from `compile: papyrus` (literal `\"` breaks the AnimDB sync JSON; run `make check-pex`). Keep the two `SkyrimNet_SexLab_PPlus.psc` signatures identical; the main build never writes the bridge's `.pex`.

## Two stage numberings

| Numbering | Value on P+ | Used by |
|-----------|-------------|---------|
| Legacy stage number | `GetAllStages(scene).Find(activeStage) + 1` of `GetNumStages(scene)` (P+ `GetLegacyStageNum`) | Narration, AnimDB "stage N" descriptions / speaking / transitions, stage keys, WebUI stage editor (`SkyrimNet_SexLab_AnimDb.ThreadStageNum` / `ThreadStageCount`) |
| Projected path | `GetStageHistory()` + `GetPathMax(scene, active)[1..]`; index = `thread.Stage`, count = path length (equal exactly at a sink) | Orgasm engine timing, gate and final stage (`Scene.Engine_StageCount`, `Engine_StageSeconds`) |

For SLSB-converted SLAL packs the legacy number matches the original stage, so the shipped anidata keeps working. Per-node seconds follow P+'s own rule (`GetFixedLength`, else climax stage = last timer, else `Timers[history length]` up to `Timers[len-2]`). A branch changes the path, which re-sends the stage timers: the engine restarts its Together curve from current enjoyment (nothing is lost).

## What changes on P+

- **Holds** (pause key, gate, ending, final-stage watch): one `PauseTimer` (`Scene.Timer_SyncHold`), re-asserted every StageStart / 1 s poll because P+'s scene HUD focus clears it. No `UpdateTimer`; the orgasm-narration timer extensions run only when `AutoAdvance`.
- **Ending:** `Ending_ToFinal` skips to the path's sink (`SkipToSink`). After the dialogue hold the final stage stays paused and `Ending_Watch` calls `EndAnimation()` at the stage's remaining time, so P+'s enjoyment-wait (`ThreadWaitsForOrgasm` → `ResetScene`) never runs. Backstops (`Scene.PPlus_StageStart`): a lower stage right after a sink whose timer ran out ends the animation; `DURATION_CAP_SECONDS` counts from the first sink.
- **Orgasm hooks:** no synthesized `OrgasmStart` / `OrgasmEnd`; P+ sends its own at climax stages.
- **Stage moves** (`Scene.StageStep` / `StageGoTo`): next follows one edge (P+ opens its branch menu for the player; nothing at a sink), previous rewinds history, an absolute stage is `SkipTo` the legacy stage.
- **Animation switch:** `Scene.PPlus_SwitchScene` → `ResetScene(id)`. The playing set stays the one start scene (its entries are what P+'s enjoyment-wait hops between). `thread.Animation` is a getter on the active scene, so registry comparisons follow a switch.
- **ChangeActors** ends the thread (AnimationEnd) and starts it again (AnimationStart). `Scene_Manager.AnimationEnd` keeps the scene (`ActorChange_KeepScene`); a WebUI commit's remaining edits replay at the restart (`ActorChange_Started`). No restart within 15 s: normal teardown. `HookActorChangeStart` covers other mods' calls.
- **Consent:** `SetVictim` does not add P+'s `Aggressive` context; `Scene.Consent_Sync` / Scene_Creator call `SetConsent(false)` when anyone is a victim, so `thread.IsAggressive` works.
- **Sex:** `Utilities.SexLabGender` maps `SexlabRegistry.GetSex` to the 1.6x coding (futa → 0, creatures → 2 / 3); `Utilities.IsFuta` adds the penis on top of the base sex.
- **TNG futa:** P+ detects futa from SOS schlong factions, not The New Gentleman. A female with a TNG genital addon (`Utilities.HasTNGPenis`, `TNG_PapyrusUtil.GetActorAddon`) comes back 1 from `GetSex`; `SexLabGender` returns 0 and `IsFuta` true for her anyway. `Scene_Creator.EnsureSexLabActorsValid` calls `Utilities.EnsureFutaSex` → `TreatAsSex(actor, 2)` (GenderFaction) before animation selection, so P+'s position sort puts her in a male/futa slot. The overwrite is marked (StorageUtil `SkyrimNet_SexLab_ForcedFuta`) and `Scene.AnimationEnd` clears only marked ones (`ClearFutaSex`). On P+ `is_hermaphrodiate` is `IsFuta` (P+ `GetTrans` is `configSex-1`, not the 1.6x 0 = treated-as-male).
- **Animation lookup:** never `SexLabFramework.GetAnimationByRegistry` on P+. `sslAnimationSlots.GetbyRegistrar` runs `SyncBackEnd` (rebuild the proxy array, loop every alias) twice per call and only finds ids already in the alias cap: about 1 s of Papyrus per row and mostly None, so a 32-row AnimDB step took ~55 s and backed up the VM. `Utilities.ResolveAnimation` → bridge `ResolveAnimation` → `GetSetAnimation(id)` (creature slots when a position is a creature) binds the id to a proxy alias. `QuerySexLabAnimsFromAnimDb` resolves one random row on P+ (the playing set is capped to one).
- **Tags / names:** `Scene.AnimTag` / `AnimHasTag` / `AnimRawTags` / `AnimName` read the registry for the proxy's scene id.
- **Cum:** P+ `GetCumID` is always 0; the bridge derives it from the active stage's Vaginal / Oral / Anal tags for receiving positions.
- **Strip:** P+ `GetStrip` can return 32 entries; `ApplyDressedToActor` pads to the 33 `OverrideStrip` requires.

## AnimDB

The walk does not use slots (a proxy array, empty until `SyncBackEnd`, capped by the quest's aliases). It enumerates `sslAnimationSlots.CreateProxyArray(0, creature)` and builds rows from `SexlabRegistry` (`AnimDb.BuildAnimJson_PPlus`). Rows carry `"_case":1`: the C++ AnimationDB keeps that registry's case as the key and returns it as `_registry` (1.6x registrars stay lowercased). Lookups try the exact key, then lowercase. Anidata matches `<nanoid>.json`, else `<scene name>.json`. AniDescriber is compiled out (`SKYRIMNET_ANIDESCRIBER_HKX=0`) and was not re-checked against P+ event names.
