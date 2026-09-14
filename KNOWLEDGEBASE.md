# Knowledgebase

## MO2: installed release vs dev folder (2026-09-13)

Profiles can enable the packaged mod (`SkyrimNet SexLab`, space) while the git workspace (`SkyrimNet_SexLab`, underscore) is disabled. Compiling this repo then does **not** affect the running game.

**Symptom:** Dom melt DN works, but Combined last-stage still emits a second `" is orgasming."` for the slave (pre-`orgasm_narrated` / pre-window build). Or melt waits until the next StageStart (~tens of seconds) instead of flushing after `sexlab.orgasm.delay`.

**Tell from the log:** after a melt, expect `Combined stash`, `ArmOrgasmWindow`, then `OnUpdate` / `FlushOrgasmWindow`. Absence of those traces means the installed release `.pex` is loaded, not this repo.

**Fix:** enable the MO2 entry that maps to `C:\Skyrim\dev\mods\SkyrimNet_SexLab` (this workspace) and disable the installed-release folder for that profile.

## JValue.toJsonString is JC 4.2.13.1+ only (2026-09-13)

`JValue.toJsonString` landed in JContainers SE 4.2.13.1. Older `JValue.pex` (Wabbajack lists, Nefaram) logs `Static function toJsonString not found` and returns None; `ObjectToLowerCaseKeyJson` then fed `""` to `JsonLowerCaseKeys` and every decorator dumped `{}`. Papyrus cannot guard a missing native — the compiled `.pex` must not call it. Walk JMap/JArray/JFormMap/JIntMap in `JValueToJsonString`, then `JsonLowerCaseKeys`. Do not `writeToFile` a shared temp path (decorator spam + races).

## DOM masturbation is a synthetic thread, not SexLab (2026-09-13)

DOM solo masturbation is behaviour `masturbate` (idles / `DOMActionMasturbating`), not a SexLab `ThreadSlots` scene. `0050_sexlab_activity.prompt` presents it via `handler_dom.GetThreads()` merged in `GetThreadsJson`. DOM bio `0055` skips `masturbating.` on purpose so 0050 owns description + `_pleasure_` speaking rules.

SkyrimNet **blocks Papyrus decorators when any menu pauses the game** (`ExecuteDecorator: Blocking VM call … because game is paused`). That is not `isTimePaused`. `0050` then falls back to `threads.json`. `DOMOnBehaviourChange` is a queued ModEvent sent after `EnterWait()`, so the next paused prompt can still see the start dump. Skip a thread in `0050` / `0550` unless an actor is in `SexLabAnimatingFaction`, `OStimActorCountFaction`, or `DOMActionMasturbating`. Sibling start/stop actions dump `threads.json` synchronously; `Handler_DOM` still refreshes on behaviour change for wheel-menu / NPC stops.

Sibling `SkyrimNet_DOM_API.GetThreads` walks `DOM02.actorAliases` / `GetMaxActorCount` (same as capture scan). `GetActorCount` / `actorArray` lag until `UpdateActorArray`. Skip when `IsBusy` so a live SexLab scene is not double-listed.

## YAML `>` is not a comparison operator (2026-09-13)

Unquoted `comparisonOperator: >` is a YAML folded block scalar, so SkyrimNet stores a blank operator. `SEXLAB_STOP` then logs `blank comparisonOperator; the rule always evaluates false` and EligibilityChecker `Unknown comparison operator ''` on every pass — Stop never becomes eligible while animating. Quote it: `comparisonOperator: ">"`. `<` and `==` can stay unquoted; quoting `>` (and `<` for consistency) is required.

## Dom player-orgasm tease is not slave climax (2026-09-13)

`DOM_Mind` sends `{name} squirms under your grasp as your orgasm submerges you` when the **player** climaxes. That is not a Dom slave orgasm. `Handler_DOM.DOMSlave_Orgasmed` must refuse it (no `OrgasmCustom` / DN). Sibling Dom Events skips it in `OnNotifcationSkip` and only routes melt phrasing to the handler. Oral `orgasm_expected [0, 1]` plus Combined skip of `dom_slave` already omit the giver; do not let the tease override that.

## Start Sex hotkey live-reload (2026-09-13)

Dashboard `sexlab.editor.hotkey_enabled` / `sexlab.editor.hotkey` used to apply only from `MCM.Setup` (load) and `OnConfigOpen`. Enabling the hotkey in the SkyrimNet dashboard did not `RegisterForKey`, so SkyMessage never opened until MCM or reload. `SkyrimNet_OnPluginConfigSaved` (SKSE `SendModEvent`: `eventName`, `strArg`, `numArg`, `sender`) now calls `ApplyPluginConfig`. Pre-VK saves stored DX `43` for backslash; `ApplyHotkey` treats `43` as VK `220`. Do not enable this hotkey on the same key as SkyrimNet_Leashed’s panel (both default `\\`).

## SkyrimNet Beta 25 content plugin (2026-09-12)

Beta 25 does not read `prompts/`, `config/triggers/`, or `config/actions/`. LLM content ships as `SKSE/Plugins/SkyrimNet/external/goodprovider.sexlab/` (`manifest.json` `id` must equal the folder name). Prompt paths inside the plugin are unchanged (`prompts/helpers/sexlab/…`, submodules). Action YAML filename (before `.yaml`) must equal the in-file `name` (case-insensitive); keep `name` casing. Settings schema stays at `config/plugins/SkyrimNet_SexLab/manifest.yaml` (`schema.fields` + `defaultValue`; `plugin.name` SkyrimNet_SexLab, `sexlab.*` keys) — that is not a content-plugin folder. Papyrus reads `Plugin_SkyrimNet_SexLab` via `GetConfig*` / `PatchConfig`. Ostim framework is `sexlab.ostim.player` (decorator `sexlab_ostim_player`); do not write `skyrimnet_sexlab_ostim_player`. Do not ship into `library/`. Upstream: SkyrimNet `docs/modding/MIGRATING_TO_BETA25.md`.

## SexLab P+ scene hop vs end (2026-09-10)

P+ `AdvanceFromTimer` does not end a player thread on the last stage when `ThreadWaitsForOrgasm()` is true (internal enjoyment + `HighEnjOrgasmWait` / `PlayerMustOrgasm` / `DomMustOrgasm`). It calls `FindSimilarSceneStage()` over `GetPlayingScenes()` (the `SetAnimations` list) and `ResetScene`s; if that list is empty it restarts the current scene. Vanilla still ends at `Stage > StageCount`.

**Do not** `SetAnimations` the full `GetAnimationsByTags` dump. Empty tags → skip lookup so SexLab picks internally (`SelectAnimations` and `SelectAnimationsDialog` both return `manager.empty`). On P+, cap a tagged match list to one random animation. `Scene.StageStart` also `EndAnimation()` after 120s real-time so enjoyment-wait cannot loop a single SLSB graph. Do not use `UpdateTimer` as an end mechanism on P+ — it sets `_ForceAdvance` and increases hopping.

MCM workaround: Climax type End/Legacy, or disable High Enj Orgasm Wait / Player Must Orgasm.

## Scene initiator vs victim (2026-08-30)

`Scene.initiator` is the speaker by default. If the thread has victims (`num_victims > 0`), a victim is never initiator: keep the current initiator only when they are not a victim; otherwise pick the first non-victim from positions 1…n then 0 (or None). Used for `"X initiates: …"` on first StageStart. Do not recompute on AlignActors / live SetVictim.

## SKSE native params must use engine types (2026-07-25)

CommonLib `RegisterFunction` derives the Papyrus signature from C++ types (`RE::TESForm*` → `Form`, `RE::Actor*` → `Actor`, etc.) and refuses to bind if the `.pex` differs. Declaring a specific script type on a native (e.g. `sslThreadController`) causes: `Native static function … does not match existing signature … Function will not be bound.`

**Fix**: Use engine types in the Papyrus stub that match C++ — e.g. `Sex_Menu_Open(Form thread, bool has_player)` with `RE::TESForm*`. Callers may still pass `sslThreadController` (it is a Quest/Form).

## ModEvent PushForm actors must be received as Form (2026-07-25)

SexLab/SLSO `SexLabOrgasm` uses `ModEvent.PushForm(eid, ActorRef)`. Handlers that declare the first parameter as `Actor` fail type-check for unique NPCs whose **attached script** is an Actor subclass — e.g. vanilla `WIDeadBodyCleanupScript` on Camilla (`CamillaValeriusREF`). Papyrus reports `received incompatible arguments! Received types (WIDeadBodyCleanupScript,int,int) instead!` and the event never runs (orgasm narration dropped for that NPC).

**Fix**: Receive `Form`, then `akForm as Actor` (same pattern as this mod’s `Action_Stop` / `MenuOpen`). `WIDeadBodyCleanupScript` is often on living uniques — it is cleanup-on-death, not “already dead.”

## PrismaUI view path (2026-07-24)

`CreateView("SkyrimNet_SexLab/index.html")` loads from **`Data/PrismaUI/views/`**, not from `SKSE/Plugins/`. This mod ships the overlay at `PrismaUI/views/SkyrimNet_SexLab/index.html` (restored from commit `a8c9440`). Missing that file → valid-looking C++ open path (hotkey / `Target_Menu_Open`) but **no visible UI**. C++ Invokes use panel ids `target_menu_panel` / `sex_menu_panel`; the HTML maps those via `showPanel` / `hidePanel` adapters onto `#target-panel` / `#sex-menu-panel`.

## WebUI target menu catalog (2026-07-24)

Target panel UI is driven by:
- `Data/SKSE/Plugins/SkyrimNet_SexLab/webui/target_options.json` — typed parameter dictionary + category options
- `Data/SKSE/Plugins/SkyrimNet_SexLab/webui/actions_index.json` — generated from SkyrimNet action YAMLs (`tools/generate_actions_index.py`)

Regenerate the index after editing action YAML `label`s. C++ `ActionCatalog` loads both at init / open; Start merges dictionary onto YAML `parameterMapping` and `DispatchMethodCall`s `scriptName`/`executionFunctionName`. Actor slots use dictionary `type: Actor` + `source: player|target` (menu focus). Do not change SkyrimNet mapping types for WebUI — only add `label` fields. Options with `requiresPlugin` are dropped when that ESP is unloaded. `type: handoff` (Target Menu **leash**) hides this overlay and sends `SkyrimNet_Leashed_OpenPanel` — there is no in-overlay leash ParameterPanel.

## SexLab position slots and speaker_position (2026-07-23)

In this mod's sex / punish animations, **position_0 is submissive** and **position_1 is dominant**:
- position_0 gives oral to position_1; position_1 receives oral from position_0.
- position_1 fucks into position_0; position_0 is fucked by position_1.
- Punish scene JSON puts `_pain_` (and whipping `_gagged_`) on index 0.

The **Speaker is always the subject** of LLM-facing sentences. `speaker_position` places the Speaker into that slot:
- `StartScene_Nonconsensual_Two_TargetVictim` → speaker at **pos1** (target is victim).
- `StartScene_Nonconsensual_Two_SpeakerVictim` → speaker at **pos0** (speaker is victim).
- Consensual direction tokens (Speaker as subject): `fucking` / `fuck a` / `fucking a` / service `getting` → pos1; `fucked in` / service `giving` → pos0.

## Intent start/finish mirror (2026-07-23)

`GetIntentMessage(START)` → `"A and B start <intent>."`; `GetIntentMessage(END)` → `"A and B finish <intent>."` (same actors + same static intent phrase). Intent is not always sexual — examples: `sexual activities`, `showing physical affection`, `physically comforting each other`, `physically punishing`, `sexual assault`, `cuddling`. YAML `intent` values must be static phrases that fit both templates.

## Orgasm totals via GetIsOrgasming (2026-07-24)

`Scene.GetIsOrgasming(Actor, total_orgasms=-1)` is the single place that both bumps per-actor totals (`StorageUtil` + `total_orgasm`) and returns the `" is orgasming."` prompt-gate clause. Call sites: `OrgasmCombined` (stash), `OrgasmIndividual` (SLSO absolute `num_orgasms`), `OrgasmCustom` (always increment; append only if substring missing). When `thread.Animation` has tag `tentacles`, `GetIsOrgasming` appends tentacles flavor on that orgasming actor only — do **not** force-orgasm all positions from `AnimationEnd`. `OrgasmMessagesToNarration` must not increment again on flush. "again" uses the post-update `GetTotalOrgasms` count (not the pre-increment `-1` local).

## Scene pool generic fallback (2026-07-26)

`GetSceneInactive` may bind `sl_scene_generic` only when `!GetThreadActive()`. Concurrent 11th+ scenes refuse allocate (`None`) rather than overwrite a live generic — avoids CK pool expansion. `Scene.Release` always `UnsetThread_scene(tid)` including generic.

## Creator.Setup returns Bool (2026-07-26)

`Scene_Creator.Setup` returns `False` on link/empty-actor failure (no `STATUS_ACTIVE`). `CreateCreator` returns `None` when Setup fails or pool exhausted; all callers must gate on `None` (Action_Start, Menu multitarget, CreateSceneWithoutCreator, GetSceneByThread).


## Pyro / UIExtensions import (2026-07-24)

`skyrimse.ppj` imports `@ModsFolder\UIExtensions\scripts\Source`. If that folder is empty, Caprica fails with `unable to locate script UIExtensions`. Restore real UIExtensions sources there (stubs only for compile smoke tests).

## Orgasm stash / AnimationEnd pipeline (2026-09-13)

1. `OrgasmCombined` / Combined `OrgasmCustom` stash into `orgasm_messages`.
2. **No Dom slave in thread:** `thread.UpdateTimer(4.0)`; next `StageStart` flushes via `OrgasmMessagesToNarration()` into one DirectNarration.
3. **Dom slave in thread:** do **not** `UpdateTimer` (P+ `_ForceAdvance` hops) and do **not** consume the stash on StageStart. `ArmOrgasmWindow` → `RegisterForSingleUpdate(sexlab.orgasm.delay)` (default 5s), restarted on every Combined/Custom event but capped at **2× delay** from `orgasm_window_started_at`. Scene `OnUpdate` waits out `IsInMenuMode`, then `FlushOrgasmWindow` (`AlignActors` then one DirectNarration of every `" is orgasming."` clause). Immediate `OrgasmHelper` on melt would be overwritten by a later player climax DN.
4. `SetStyleDialog` skips its DirectNarration while `orgasm_messages_set` (style is already in scene JSON).
5. `AnimationEnd`: leftover stash is prepended to the finish DirectNarration (must include `" is orgasming."`). Do not RegisterEvent-only leftover — 0550 gates on DirectNarration. Then `Release` (UnregisterForUpdate). SeparateOrgasms afterglow unchanged. Do not narrate ongoing activity at end.
6. `AnimationStart` (STATUS_SETUP): flush a pending stash before clearing — do not drop a melt that raced AnimationEnd→next start.
7. Handler delayed melt: after 1s, retry `manager.OrgasmCustom` if the scene is back; only DirectNarrate when still unreachable (keeps scene totals / Combined window in sync).

**Symptom (2026-09-13):** Dom HUD `Nina's brain melts…`, `total_orgasm` 0→1, no `" is orgasming."` DN; 0550 never gated. SexLab hotkey SkyMessage was open; Combined stash waited on StageStart/`UpdateTimer`; style DN (`Bob changes from 'forcefully' to 'gently'`) took the slot.

**Symptom (2026-09-13 later):** Melt DN correct (`Nina is orgasming`, total 0→1). Last-stage Combined then flushed `Nina is orgasming. Bob is orgasming.` even though DOM skipped the player-tease HUD and Nina’s total stayed 1.

**Cause:** `OrgasmMessagesToNarration` Combined slave fallback treated lifetime `total_orgasm > 0` as “orgasming now”. Also: MO2 profile was loading the installed release without `ArmOrgasmWindow` / `orgasm_narrated`.

**Fix:** Position JMap `orgasm_narrated` records how many orgasms were already spoken. Flush marks it when emitting a stash clause. Fallback only if `GetTotalOrgasms > orgasm_narrated`. Already-spoken slave gets `" is not orgasming right now."` (not denied). Enable the git workspace mod in MO2 when testing.

**Symptom (2026-09-13 StageEnd melt):** DOM HUD `Nina melt orgasm` between `HookStageEnd` and `HookStageStart`. `Get_Threads` stayed `total_orgasm: 0`. StageStart sent `continue activity`. No `"brain melts"` DN.

**Cause:** `GetThreadByActor` / `GetSceneByThread` require SexLab state `animating` or `prepare`. During StageEnd the controller is often neither, so `OrgasmCustom` aborts. Separately, first-stage melt flushed via `RegisterEvent` then `DirectNarration` of the same sentence; `CheckDuplicate` emptied the DN (0550 gates on DN only).

**Fix:** `GetSceneByActor` scans `thread_scene` (and `sl_scenes`) when the state filter misses. `OrgasmCustom` uses `GetThreadByActor(any_state)` + `GetSceneByThread(any_state, create_if_missing=false)`. Handler delays the melt 1s if scene is still None, then retries `OrgasmCustom` before falling back to DirectNarration. StageStart RegisterEvents the stage desc only, then DirectNarrates the orgasm sentence.

## Actor lock key (2026-07-23)

Creator locks with `skyrimnet_sexlab_scene_actor_lock`. Action YAML eligibility and `Main.storage_actor_lock_key` must use the same string (not `skyrimnet_sexlab_actor_lock`).

## Punish-rape setting_name must match scene file (2026-07-22)

`sexlab_punish_rape_target.yaml` / `sexlab_punish_rape_target_by_target.yaml` must use `setting_name: punish_pleasure_pain_rape` (file `scenes/punish_pleasure_pain_rape.json`). A swapped token order (`punish_pain_pleasure_rape`) fails to load the scene. Hotkey Menu.psc uses the correct name. See review-checkpoint `Y-RapeSettingName`.

## SkyrimNet action YAML practice (2026-07-18)

Full authoring guide: [docs/authors/actions.md](docs/authors/actions.md).

Actions live in `SKSE/Plugins/SkyrimNet/external/goodprovider.sexlab/actions/`. The YAML filename must equal the in-file `name`. Executable YAMLs dispatch to `SkyrimNet_SexLab_Actions` via positional `parameterMapping` — order and types must match the Papyrus signature; mapping `name` is LLM-facing only.

- **Hard limit: max 8 `parameterMapping` entries** per action YAML (SkyrimNet). Threesome actions already use all 8; do not add a 9th — fold into an existing dynamic, use `setting_name`, or a fixed-role Papyrus wrapper.
- `static` requires `value`; `dynamic` requires `description` (not `value`).
- Prefer Papyrus slot names in mappings (`method`, not `type`; `how` for outfit).
- Action `name` must be unique across all YAMLs.
- Fixed-role nonconsensual two-actor scenes use `StartScene_Nonconsensual_Two_TargetVictim` / `_SpeakerVictim`. Dynamic victim uses `StartScene_Nonconsensual_Two` with an explicit `victim` mapping. Do not pass obsolete `speaking_victim`.
- Eligibility rule groups that exist should set `logicalOperator` and `required: true` (`required: false` is ignored by SkyrimNet).
- Category parents: only `name` / `description` / `customCategory` / `enabled` / eligibility — no `description_` field; keep PARAMS JSON valid.

Upstream schema: [WORKFLOW_ACTIONS.md](https://github.com/MinLL/SkyrimNet-GamePlugin/blob/main/docs/modding/WORKFLOW_ACTIONS.md).

## StageStart scene-change must not wipe orgasm narration (2026-07-17)

**Symptom**: `OrgasmCombined` stashes `"bob is orgasming. "` and sets `orgasm_messages_set`, but final DirectNarration is only `"Scene changes to …"` + cum — no `" is orgasming."`, so `0550_sexlab_narration.prompt` never gates.

**Cause**: In `Scene.StageStart`, after building `narration` from `orgasm_messages`, `desc != description_last` did `narration = "Scene changes to "+desc`, which replaced the orgasm/denied block. `orgasm_happened` stayed true (cum still appended); only the orgasm text was lost.

**Fix**: When the stage description changes, lead with `"Scene changes to "+desc` and **append** any existing orgasm narration instead of assigning over it. Non-orgasm ChangePosition path (empty narration) is unchanged.

## EnsureActorArraysLargeEnough must check both arrays (2026-07-16)

**Symptom**: `OrgasmCombined` — `Cannot access an element of a None array` on `orgasm_messages[i]`.

**Cause**: `EnsureActorArraysLargeEnough` early-returned when only `position_objs` was large enough. After save/load (or when `orgasm_messages` was added later), `position_objs` can be restored while `orgasm_messages` stays None.

**Fix**: Early-return only when **both** `position_objs` and `orgasm_messages` exist and meet `size`. `OrgasmCombined` also calls `EnsureActorArraysLargeEnough(num_actors)` before indexing (same pattern as `OrgasmCustom`).

## Papyrus string literals do not treat `\n` as newline (2026-07-15)

`"\n"` / `"\r\n"` in Papyrus source are backslash + letter(s), not control characters. Use `StringUtil.AsChar(10)` (LF) and `StringUtil.AsChar(13)` (CR). This project already does that in `Stages.psc` / `MCM.psc` via a `newline` field.

## SexLab orgasm narration trigger (2026-07-14)

**Prompt**: `SKSE/Plugins/SkyrimNet/external/goodprovider.sexlab/prompts/submodules/user_final_instructions/0550_sexlab_narration.prompt` uses `contains(_direct_narration, " is orgasming.")`.

**Contract**:
- Orgasming actors’ clauses in Combined/custom narration must include `" is orgasming."`.
- Non-orgasming / denied clauses must not (e.g. Combined and Separate `name+" is not orgasming right now. "`, `HandleOrgasmDenied`, “did not orgasm”, afterglow “failed to orgasm”). Combined flush and `OrgasmIndividual` name every non-orgasming actor; do not use a generic “only listed actors” sentence.
- Dom custom path: `Handler_DOM.DOMSlave_Orgasmed` → `Scene_Manager.OrgasmCustom` appends `". "+name+" is orgasming."` before Scene stashes/sends. Required for the prompt gate.
- Dom Combined fallback: when `_dom_slave`, `orgasm_expected==1`, totals > 0, and custom message empty, Scene still appends `name+" is orgasming. "` so the prompt gate fires if Dom feed raced past Combined.
- Dom feed: sibling `SkyrimNet_DOM_Events.OnNotificationSent` (Ext3 on) routes **melt** phrasing (`brain melts` / `mind melts` / `overwhelmed by orgasm` / `submerged by orgasm`, not `your orgasm`) to `DOMSlave_Orgasmed`. Do not match bare `"orgasm"`. The player-climax tease (`squirms under your grasp as your orgasm submerges you`) is skipped in Dom `OnNotifcationSkip` and again in `Handler_DOM.DOMSlave_Orgasmed` (no OrgasmCustom / DN). Prefer notifications over `DOMOnOrgasm` (faster; leave Orgasm unregistered). Dom `SexLab_AnimationStart` may `DisableOrgasm` on Dom actors so SexLab hooks alone will not narrate them. If Ext3 is off: Dom melt HUD can fire while DN denies the slave or narrates other actors only — see SkyrimNet_DOM KNOWLEDGEBASE “Dom melt without DirectNarration”.

**SeparateOrgasms**: Manager skips Dom on `SexLabOrgasm`; `Scene.OrgasmCustom` must use `config.SeparateOrgasms` and call `OrgasmHelper` immediately when Separate is on; Combined stashes into `orgasm_messages` and, with a Dom slave, arms the Scene `OnUpdate` window instead of StageStart/`UpdateTimer`.

## Scene pool / GetSceneInactive None (2026-07-12)

**Symptom**: `Cannot call SetThread() on a None object` in `GetSceneInactive` after `Failed to find inactive sl_scene using generic`, even with **no active SexLab animations** (pool should be free).

**Causes**:
1. Property rename `scenes`/`scene_generic` → `sl_scenes`/`sl_scene_generic`: Auto property fills are **baked into saves**. Old saves keep empty new-name properties; `creators` (unchanged name) still works. Runtime pool looks empty → fallback to None generic → crash.
2. `sl_scene_generic` Auto property unresolved → fallback `SetThread` crashed (no None guard).
3. `STATUS_*` were `Auto` (not `AutoReadOnly`). Saves can corrupt constants so `IsActive()` stays true forever.
4. `Initialize` did not reset `status` / clear stale `thread`.

**Fixes**: `RebuildScenePool()` via `GetFormFromFile` every Setup; None-guard + generic recovery; `STATUS_*` → `AutoReadOnly`; reset `status`/`thread` on Initialize; reclaim by `GetThreadActive()` (not status alone).

## DOM / external thread scene bind race (2026-07-27)

**Symptom**: Native DOM SexLab threads log `[SkyrimNet_SexLab_Stages.GetStageDescription] thread is None` shortly after `SetPosition` during scene auto-create. SkyrimNet prompts may lack activity/description for that thread.

**Cause**: `GetSceneInactive` published `thread_scene[tid]` before `SetThread(thread)`. A reentrant `GetSceneByThread` (from `SaveThreadsJson` / decorators during first-frame Setup) saw `GetThread() == None`, failed reference equality, and `Release()`'d the scene mid-Setup. `SetPosition` could still finish; later `GetDescription` ran with `thread == None`.

**Fixes**: `SetThread` before `thread_scene[tid]` in `GetSceneInactive`; `GetSceneByThread` treats `thread_scene[tid]` as authoritative (rebind when `bound == None` or `bound.tid` matches — do **not** require `IsActive()`, because Setup only sets `STATUS_SETUP` at the end); `EnsureSceneForThread` on `HookAnimationStart` / `HookStageStart`; thread guards in `Scene.AnimationStart` / `GetDescription` / `GetThreadObj`. Release only on tid mismatch.

## Scene narration prompts (2026-09-09)

Only afterglow and cum go through `RenderSlPrompt` (`helpers/sexlab/afterglow.prompt`, `helpers/sexlab/cum.prompt`). That helper is `SkyrimNetApi.RenderTemplate` then `ParseString` with namespace `sl` JSON (same as Stages `ParseString`). Empty, error-looking, or leftover-`{{` renders fall back to the previous Papyrus sentence. A single name is string `sl.name` (`{{sl.name}}`), not a one-element array. All other scene DirectNarration strings are inline Papyrus. The `" is orgasming."` 0550 gate is still emitted by `GetIsOrgasming`; that function still bumps totals before wording.
