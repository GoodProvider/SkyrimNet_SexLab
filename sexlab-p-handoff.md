# SexLab P+ handoff

Analysis only. Compared `../SexLab Framework PPLUS/Source/Scripts/` with the 1.6x scripts vendored in `extern/Source_SexLab/` and with the calls in `Scripts/Source/`. No runtime P+ session was run, and the P+ ESM alias counts were not opened.

SexLab P+ keeps the script names this mod already calls (`SexLabFramework`, `sslThreadController`, `sslBaseAnimation`, `sslActorAlias`, `sslAnimationSlots`). A build that only recompiles against P+ headers will load. It will not behave like 1.6x. P+ scenes are directed graphs addressed by NanoID, and the legacy objects are a proxy the P+ authors mark as redundant (`sslBaseAnimation.psc` header: use `SexlabRegistry.psc`). Supporting P+ means calling that registry and the thread’s graph functions anywhere this mod assumes a linear stage list.

Detection already exists: `SkyrimNet_SexLab_Utilities.IsSexLabPPlus()` is true when `SexLabUtil`’s version is above 20000. Both frameworks ship `SexLab.esm` and the `SexLabUtil` SKSE plugin, so this is one install or the other, switched inside the same scripts.

## What already lands on P+

These are containment, not support. They are in `SkyrimNet_SexLab_Utilities.psc`, `SkyrimNet_SexLab_Scene_Creator.psc`, and `SkyrimNet_SexLab_Scene.psc`, and written up in `KNOWLEDGEBASE.md` (“SexLab P+ scene hop vs end”).

- `PickOneAnimation` / `SelectAnimations`: a tagged match list longer than one animation is cut to a single random animation before `SetAnimations`.
- Empty tag filters skip `SetAnimations` so P+ picks internally.
- `Scene.StageStart` calls `EndAnimation()` after 120 seconds of real time (`DURATION_CAP_SECONDS`).
- Orgasm-window code avoids `UpdateTimer` on the DOM path, because on P+ `UpdateTimer` sets `_ForceAdvance`.

`StartThread`, `AddActor`, `SetVictim`, `SetNoStripping`, `DisableOrgasm`, `ForceOrgasm`, `EndAnimation`, `SetVoice` / `GetVoice`, `PickVoice`, `GetGender`, `ValidateActor`, `IsActorActive`, `StripActor` / `UnStripActor`, and the hook event names this mod registers (`HookAnimationStart`, `HookStageStart`, `HookAnimationEnd`, `HookAnimationChange`, `HookOrgasmStart`, `HookActorChangeEnd`, `HookLeadInEnd`, `SexLabOrgasm`) still exist with the same shapes.

## The model this mod assumes

`SkyrimNet_SexLab_Scene`, `SkyrimNet_SexLab_Actions`, and `SkyrimNet_SexLab_AnimDb` treat an animation as a fixed list of stages `1 .. StageCount`, with `thread.Stage` as the index, `GoToStage(n)` as a jump to that index, and `thread.Animation` as a stable SLAL registry string whose tags, name, enabled flag, and per-stage HKX events are readable off `sslBaseAnimation`.

P+ `sslThreadModel` in the `Animating` state:

| Call | P+ behavior |
|---|---|
| `Stage` | `_StageHistory.Length`. The setter calls `GoToStage`. |
| `GoToStage(n)` with `n <= 1` | `ResetScene` of the current scene. Restarts the graph. |
| `GoToStage(n)` with `n > Stage` | One step along one edge (`SelectNextStage` / `PlayNext`). If the player is in the scene and the node has more than one branch, it opens P+’s stage-select menu instead. It does not walk to stage `n`. |
| `GoToStage(n)` with `1 < n < Stage` | Rewinds history to that prefix. |
| `GoToStage(n)` with `n == Stage` | Restarts the stage timer. |
| `StageCount()` on the animation | Length of the longest path (`GetPathMax`), including branches the thread will never play. |
| `UpdateTimer(seconds)` | Adds time and sets `_ForceAdvance`, so the stage auto-advances even when `AutoAdvance` is false. |
| `PauseTimer(bool)` | Pauses the stage timer. This mod does not call it. |
| `SetAnimations(list)` | That list is `GetPlayingScenes()`. On the last stage, if `ThreadWaitsForOrgasm()` (P+’s own enjoyment plus `HighEnjOrgasmWait` / `PlayerMustOrgasm` / `DomMustOrgasm`), `AdvanceFromTimer` calls `FindSimilarSceneStage` over that list and `ResetScene`s. One entry means it restarts the same scene. |
| Active states | `Unlocked`, `Making`, `Making_M`, `Animating`, `Ending`. There is no `Advancing` state between stages. |
| `thread.Animation.Registry` | NanoID from `SexLabRegistry`, stable across saves, not the SLAL registry string in `SKSE/Plugins/SkyrimNet_SexLab/animations/`. |

`SexLabThread.psc` is the API P+ documents for new callers: `GetActiveScene`, `GetActiveStage`, `SkipTo`, `BranchTo`, `GetPlayingScenes`, `PauseTimer`. `sslThreadController` still extends `sslThreadModel`, so the old names resolve, with the semantics above.

## Legacy properties that stay empty

`sslBaseAnimation` overrides `_GetName`, `_GetEnabled`, and `_GetTags` to read `SexLabRegistry`. Those helpers are not what external callers hit. The properties live on `sslBaseObject`, and that script’s getters call `sslBaseObject`’s own `_GetName` / `_GetEnabled` / `_GetTags`, which return the raw fields. Papyrus does not dispatch those parent calls to the child overrides. `GetSetAnimation` assigns `Registry` and nothing else.

So after a slot walk:

- `anim.Registry` is the NanoID. Usable as a key.
- `anim.Name` stays `""`.
- `anim.Enabled` stays false, so an enabled-only AnimDB query drops the row.
- `anim.GetRawTags()` / `anim.HasTag()` stay empty. `HasTag` on `sslBaseObject` is also true for every tag when the array length is 0 (`Tag && !Tags.Length || Find`), so a direct `HasTag` check on an unfilled proxy is not a usable filter.
- `anim.StageCount`, `anim.PositionCount`, `anim.Genders`, `anim.GetGender`, `anim.GetRaceTypes`, `anim.IsCreature` are declared on `sslBaseAnimation` and do read the registry. Those survive.

`sslAnimationSlots.GetBySlot` / `Slotted` are a proxy array filled by native `CreateProxyArray`, capped by the number of aliases on that quest, and only after `SyncBackEnd()`. `OnInit` and `Setup` are empty, and `Slotted` is `_proxyid.Length`. `SkyrimNet_SexLab_AnimDb` reads `slots.Slotted` once, then walks. If nothing has called `SyncBackEnd` yet, that length is 0 and the walk imports nothing. `GetBySlot` itself calls `SyncBackEnd`, which does not help a loop whose bound was already read as 0.

`GetStageBounded` is the helper behind `HasTimer` and `GetTimer`:

```
if maxpath.Length >= aiDepth
    return maxpath[maxpath.Length - 1]   ; the sink
return maxpath[aiDepth]
```

For every in-range stage index the condition is true, so the timer read is the sink’s fixed length. `Scene.Engine_StageSeconds` uses `HasTimer` / `GetTimer` and would stamp that one duration onto every stage. `FetchStage` and `GetAnimEvents` pass the int index into `SexLabRegistry.GetAnimationEventA`, which takes a stage-id string. Do not use them. Events are `SexLabRegistry.GetAnimationEvent(sceneId, stageId, position)` with ids from `GetAllStages` or `GetPathMax`. `FetchPosition` only follows branch 0, so it disagrees with `StageCount()` on any scene that branches.

`thread.HasTag` / `IsVaginal` / `IsAnal` / `IsOral` are fine after startup: `Making_M.BeginAliasPreparation` sets `_ThreadTags` from `SexLabRegistry.GetCommonTags` of the playing set. `thread.Animation.HasTag` is the empty proxy. `Scene` skill selection uses `thread.Animation.HasTag("Vaginal"|"Anal"|"Oral"|"Blowjob"|"Cunnilingus")`.

## Call sites that change meaning

### Starting a scene (`Scene_Creator.FinishStartScene`)

`NewThread`, `AddActor`, `SetVictim`, `SetNoStripping`, `DisableOrgasm`, `SetAnimations`, `StartThread` still work. `SetAnimations` of a multi-animation tag dump is the enjoyment-wait hop; the one-animation cap is why that is currently cut. The in-thread animation list (`thread.Animations` / `GetPlayingScenes`) is that same list, so the cap also leaves the animation menu with one entry. Alternatives have to stay out of the playing set and be applied later with `ResetScene(sceneId)` (valid inside `Animating`).

`IsAggressive` is `HasContext("Aggressive")`. `SetVictim` sets the submissive flag and does not add that context. Nothing in this mod adds it, and the property setter is inverted (`set(true)` calls `SetConsent(true)`, which removes the context). Strip choice and the aggressor ending path (`Ending_Check`) read `thread.IsAggressive` and will see a consenting thread.

`GetGender` is still 0 male / 1 female / 2+ creature, and a futa overwrite is faction rank 2 (`TreatAsSex(..., 2)`), so `GetGender` returns 2. `GetRaceKeyForActor` treats any gender at or above 2 as a creature. P+’s real sex is `SexLabRegistry.GetSex`: 0 male, 1 female, 2 futa, 3 creature male, 4 creature female.

### Stage keys and the ending (`Actions`, `Scene`)

`TM_StageNext` / `TM_StagePrev` / `TM_GoToStage` call `GoToStage(stage ± 1)` or `GoToStage(absolute)`. Forward moves one edge, or opens P+’s branch menu. Previous from stage 2 calls `GoToStage(1)`, which resets the scene. An absolute jump such as `Ending_ToFinal`’s `GoToStage(StageCount)` does not skip to the sink. The sink is `SexLabRegistry.GetEndingStages(sceneId)` plus `SkipTo`. `EnjBasedSkipToLastStage` already does that skip for 1- and 2-actor scenes.

`StageKeyReady` requires state `Animating`. That still matches P+’s playing state. There is no `Advancing` gap, so keys are not dropped mid-transition the way 1.6x drops them. `GoToStage` during `_animationSyncPending` can still be ignored (`ResetScene` bails while a reset is settling).

Pause, the ending hold, and the gate hold call `UpdateTimer(PAUSE_HOLD_SECONDS)` and release with a negative `UpdateTimer`. On P+ each of those sets `_ForceAdvance` and the stage hops when the timer drains. The call that holds a stage is `PauseTimer(true)` / `PauseTimer(false)`.

`Engine_SetStage` treats `Stage >= StageCount()` as the orgasm stage and sends `OrgasmStart` / `OrgasmEnd` itself. On a graph, history length meeting the longest-path length is not “the climax node.” P+ sends `HookOrgasmStart` from `PlayNextImpl` when the next node is a sink (`GetNodeType == 2`, legacy climax mode) or when `GetClimaxingActors` is non-empty. Both can fire for one scene. `ForceOrgasm` still reaches `sslActorAlias.DoOrgasm(true)` and sends `SexLabOrgasm`; `DisableOrgasm` still blocks the unforced path. P+’s own enjoyment wait is independent of this mod’s orgasm engine. With one playing scene the wait restarts that scene until the 120s cap calls `EndAnimation`.

`Engine_StageSeconds` is the orgasm engine’s pace. It is wrong on P+ while it trusts `HasTimer` / `GetTimer`. Per-node duration is `SexLabRegistry.GetFixedLength(sceneId, stageId)`, and nodes without a fixed length use `thread.Timers` (config stage timers, same array as 1.6x).

### Animation database (`AnimDb.BuildAnimJson` and the slot walk)

The walk can produce rows only after `SyncBackEnd`, and only up to the proxy alias cap. Rows that do get built have a NanoID, an empty name, enabled 0, and no tags. Shipped anidata under `SKSE/Plugins/SkyrimNet_SexLab/animations/` is keyed by SLAL registry strings, so `LoadAnimJson` will not attach stage descriptions, orgasm masks, or speaking modifiers. AniDescriber samples HKX by the event names stored on the row; the walk does not copy `GetAnimationEvent` into the row, and P+ event names will not match the 1.6x event lists those JSON files were authored against.

`GetThreadStageDescription` / `GetThreadStagesJson` index descriptions by `thread.Stage` as a 1-based linear index. On P+ that number is history length. Descriptions have to be keyed by `(sceneId, stageId)` or by an index into the path the thread actually took (`GetStageHistory` / `GetActiveStage`).

Creature slots extend `sslAnimationSlots`, so the cast in the walk is valid. Human race keys come back as `"humans"` and `GetRaceTypes` rewrites those to `""`, which matches this mod’s “empty race key means human” convention. `RaceType` on a human scene calls `GetRaceIDs()[0]` on an empty array.

### Stripping (`Scene.ApplyDressedToActor`)

`sslActorAlias.Strip`, `UnStrip`, and `OverrideStrip` still exist, and `OverrideStrip` still requires a 33-long bool array. `Config.GetStrip` still has the 1.6x signature. It is implemented as `BitsToBool`, which returns 33 entries only when the weapon bit is set and 32 otherwise. A 32-long array is logged and ignored. Mid-scene dress/undress via `OverrideStrip` + `Strip` fails in that case. `SetNoStripping` still writes 33 falses and clears `DoUndress`.

`ChangeActors` on the playing thread calls `EndAnimation` (sends `AnimationEnd`, state `Ending`) and then `Ending.ResetAnimation`, which builds a new instance and `StartThread`s again. `Scene_Manager`’s `AnimationEnd` handler will tear the SkyrimNet scene down across that gap unless it treats this end as a rebuild.

### Voices, cum, stats

`PickVoice`, `thread.SetVoice`, and `thread.GetVoice` still go through `sslActorAlias`. `sexlab.Stats.GetSkillLevel` / `GetSkillLevels` / `GetLewdLevel` / `GetPureLevel` are still how `Engine_SetSkills` reads starting enjoyment. `SexLabOrgasm`’s argument order (actor, enjoyment, orgasm count) is unchanged in `DoOrgasm`. Cum clear uses `RemoveCumFx` on the framework; that function is still declared.

## Work, in the order it has to happen

1. **Registry read path.** Add a P+ branch that never reads `anim.Name`, `anim.Enabled`, or `anim.GetRawTags()`. Use `SexLabRegistry.GetSceneName`, `IsSceneEnabled`, `GetSceneTags`, `GetStageTags`, `GetPositionSexA`, `GetRaceKeyPosition`, `GetActorCount`, `GetAllStages` / `GetPathMax`, `GetAnimationEvent`, `GetFixedLength`, `GetClimaxingActors`, `GetNodeType`, `GetEndingStages`. Call `SyncBackEnd()` (via `GetBySlot(0)` or a direct call) before reading `Slotted`. Key AnimDB by NanoID. Rebuild descriptions from those event names; keep the existing JSON as a name fallback (`GetSceneName` against the current filenames) only where the names still match.

2. **Stage identity inside `Scene` and `Actions`.** Store `GetActiveScene()` + `GetActiveStage()` beside the history length. Next stage: `GoToStage(Stage + 1)` only when the node has one branch; otherwise surface the branch (P+ already opens its own menu when the player is present). Previous stage: `SkipTo` the previous history id, and never call `GoToStage(1)`. Jump to end: `SkipTo(GetEndingStages(scene)[0])`. Point the orgasm engine’s “final stage” at climax nodes (`GetClimaxingActors` / node type 2), and stop synthesizing `OrgasmStart` from `Stage >= StageCount()`.

3. **Timers.** Replace every hold (`Pause_Hold`, ending hold, gate hold) with `PauseTimer`. Leave `UpdateTimer` unused on P+. Feed `Engine_StageSeconds` from `GetFixedLength` per history node, then `thread.Timers`.

4. **End the scene when our engine is done.** `EndAnimation()` on our orgasm/ending completion, so `ThreadWaitsForOrgasm` cannot restart the graph. The 120s cap can stay as a backstop. Do not put extra scenes in `SetAnimations` to “give it somewhere to hop.”

5. **Animation menu.** Keep the playing set at one scene. Fill the menu from `SexLabRegistry.LookupScenesA(positions, tagString, submissives, furniture, center)` or from the AnimDB query, and apply a choice with `ResetScene(sceneId)`. Rebind the SkyrimNet scene across that reset: `ResetScene` fires `StageStart` and may change `thread.Animation.Registry` without a second `AnimationStart`.

6. **`ChangeActors`.** Expect `AnimationEnd` then a new `AnimationStart` on the same thread object. `Scene_Manager.AnimationEnd` has to keep the SkyrimNet scene when the end came from `ChangeActors` (`HookActorChangeStart` / `HookActorChangeEnd` bracket it).

7. **Consent and sex.** When the scene is non-consent, call `SetConsent(false)` (adds context `Aggressive`). Read sex with `SexLabRegistry.GetSex` anywhere gender `>= 2` currently means creature, including `GetRaceKeyForActor` and AnimDB position genders.

8. **Strip.** Build the 33-long override explicitly when `GetStrip` returns 32. Confirm `RemoveCumFx` still clears the overlay this mod’s Clean Cum action expects.

9. **Narration copy.** Stage descriptions, transitions, orgasm-expected, speaking modifiers, and clothed flags in `AnimDb.GetThread*` are all indexed by linear stage. Retarget them at the active stage id. Per-stage tags from `GetStageTags` should drive speaking inference instead of the scene-wide tag list repeated for every stage.

## What can stay shared

Hook registration in `Scene_Manager`, `ForceOrgasm` → `SexLabOrgasm`, voice apply, `NewThread` startup, actor validation, the faction/victim bookkeeping, and the orgasm engine’s enjoyment math. The engine should keep receiving a stage index and a timer array; those values have to be computed from the graph first. `IsSexLabPPlus()` is the right switch. 1.6x call sites should keep using `GoToStage` and `UpdateTimer` as they do now.

## Gaps

- Proxy alias count versus scene count is in the ESM, not these scripts. If P+ has more scenes than aliases, `CreateProxyArray(aliasCount, ...)` truncates the walk.
- `CreateInstance`, `GetPlayingScenes`, `GetActiveScene`, and `AdvanceScene` are native. The Papyrus around them is what this note describes.
- `GetStageBounded`, `FetchStage`, and the `IsAggressive` setter look like P+ defects. Working around them in this mod is enough; patching P+ is a separate choice.
- AniDescriber and the HKX index were not re-read against P+ event-name strings. Step 1 has to include one real P+ scene’s event names before treating narration as done.
