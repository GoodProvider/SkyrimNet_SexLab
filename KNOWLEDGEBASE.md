# Knowledgebase

## AniDescriber HKX fill on hold (2026-09-17)

Runtime missing-stage fill is **authored anidata → earlier authored stage (Papyrus) → `GetDescriptionFromTags`**. `AnimationDB::GetStageDescription` does not call AniDescriber. No `Debug.Notification("Missing descriptions, inferring")`. AniDescriber / `HkxAnim` compile into the DLL with `SKYRIMNET_ANIDESCRIBER_HKX=0` (does not restore `anim_events`). Source stays in tree for offline spline work.

**Historical quirks (when HKX is resumed):** empty `anim_events` after schema ALTER → `AnimDb_NeedsEventBackfill` forces rebuild. XPMSE dual skeleton: pick NPC set (`bones_m` ≫ 18), not Ragdoll (~18). Debug `std::clamp` abort on inverted knot bounds in `ReadSplineVector` — guarded to fail clean (`hkx_sample_fail`). Spline decoder still returns `hkx_sample_fail`; tag narration expected until fixed offline.

## Start Sex hotkey DX 0 / unbound VkToDxScanCode (2026-09-15)

Enabled hotkey did nothing after `main`→`skse` merge. Papyrus: `Unbound native function "VkToDxScanCode"`. SKSE: `WebUI_SetHotkey dx=0x0 enabled=true` then `WebUI menu hotkey disabled`. No `ProcessHotkey`.

**Cause:** Dashboard `type:hotkey` stores VK (`220` = backslash). MCM `ApplyHotkey` converts with native `VkToDxScanCode` then `WebUI_SetHotkey` (DX). The loaded DLL had not registered that native, so Papyrus stored `0`. `WebUI_SetMenuHotkey` treats DX `0` as disable — it will also **unregister** a C++ bind. C++ `ApplyMenuHotkey` still read retired keys `sexlab.controls.editStageHotkey*`; manifest is `sexlab.editor.hotkey_enabled` / `sexlab.editor.hotkey`. `Config.h` / `Config.cpp` were missing from the tree so SKSE could not rebuild.

**Fix:** Restore Config. `ApplyMenuHotkey` reads `sexlab.editor.hotkey*`, leftover saved `43` → VK `220`, `MapVirtualKeyA` → `WebUI_SetMenuHotkey`. MCM: if `VkToDxScanCode` returns `0`, fallback DX `43` (`0x2B`) and do not call `WebUI_SetHotkey(0, true)`. Rebuild Release DLL. Expect `WebUI menu hotkey registered dx=0x2b` and no unbound native.

## Leash TargetMenu panel (2026-09-02)

- TargetMenu **leash** is `panel: leash` (`SKSE/Plugins/SkyrimNet_SexLab/webui/TargetMenu/Actor/options/0700_sexlab_leash.json`). Catalog `requiresPlugin`: `SkyrimNet_Leash.esp`. Core SKSE tree (not FOMOD-split).
- Start-only ParameterPanel. Action pulldown is its own row (label column): not leashed → `tie to` / `give to`; leashed → `unleash` / `tie to` / `give to`. Control column: location if `tie to`, holder otherwise, empty if `unleash`.
- Status from C++ `onLeashStatus` → `LeashFramework.IsLeashed` / `GetLeashHolder` (faction 0xD6A fallback). Do not copy YAML leash decorators. Start dispatches `SkyrimNet_Leash_Actions` (no YAML / `actions_index`). No refuses.

## AddActor -11 ForbiddenFaction after Edit Tags (2026-09-14)

Threesome Setup/locks/Yes/Edit Tags succeeded (35 Oral 3-actor anims). After the UI, `NewThread` + `AddActor(Nina)` failed. Papyrus: `ValidateActor(Nina) -- FALSE -- They are flagged as forbidden from animating` then `FATAL ... not a valid target for animation`. Edit Tags is not the failure — AddActor runs after the menu.

**Cause:** SexLab `ForbiddenFaction` (ValidateActor **-11**). A prior `CanAnimate` miss **adds** that faction; later checks hit “flagged as forbidden” first. MCM/manual forbid uses the same faction.

**Fix:** `EnsureSexLabActorsValid` before `SelectAnimations` and again before `NewThread`: `IsForbidden` → `AllowActor`, then `ValidateActor`. Still `< 0` aborts with name+code (no Yes/Edit Tags on a doomed start). AddActor failure logs `ValidateActor` again. If race/`CanAnimate` is the real reason, SexLab re-forbids and the code is no longer a sticky -11.

## Overlapping Action_Start shares creator sid:0 (2026-09-14)

SkyrimNet can queue the same start action twice (two LLM selections). Both `ModEvent`s run `CreateCreator`; `IsActive()` was still false until `Setup` finished latent `Game.GetPlayer()` and set `STATUS_ACTIVE`. Both claimed sid:0. The loser `Release()`d the shared creator (`num_actors = 0`, names/tags cleared). The winner called `StartThread` with no actors.

**Symptom:** `SexLab_Start_Giving` (or any start) logs Setup with actors, then `StartScene` with empty actors/tags. Papyrus: `SEXLAB - FATAL - Thread[0] - No valid actors available for animation`.

**Log trap:** `LockActorLock` `"X is locked"` used to mean **already locked** (failure). Success had no info trace.

**Fix:** `TryClaim()` sets `STATUS_SETUP` with no natives before `Setup`; second start gets the next pool slot. `StartScene` aborts before `NewThread` if `num_actors < 1`. `LockActorLock` sets StorageUtil immediately; `"already locked"` vs `"locked"`.

## Action eligibility cannot use Papyrus decorators (2026-09-14)

Category parents (`ShowComfort`, `ExpressPhysicallyNonsexually`, `Sexlab_Punish`, `SexLab_Sexual_Activities_One`/`Two`/`Three`) gated on Papyrus `sexlab_ostim_player == 0`. Eligibility `CallDecoratorDirect` does **not** live-call 1-arg Papyrus decorators: missing `arguments` logs `expects exactly 1 argument (EntityUUID), got 0`; with `currentActor` it logs `cache miss … returning empty`. Empty ≠ `0`, so the AND group fails and the whole tree (comfort / sex / punish / affection) stays hidden. Prompt-cache calls that pass an actor still return `'0'`.

**Symptom:** embedded eligible actions are only top-level native ones (`change_outfit`, DD lock/unlock, WAITHERE, DOM slave pack). Not Nina-specific.

**Fix:** native `get_global_value` / `skyrimnet_sexlab_ostim_player` on those six parents. `MCM.ApplyPluginConfig` `SetValue`s that global from `sexlab.ostim.player`. Keep `Ostim_Player` for prompts; do not use it in action YAML. Refresh Actions in Game Data Explorer.

## Hotkey SkyMessage: GetThreadByActor arity (2026-09-14)

Start Sex hotkey fired (`OnKeyDown` DX 43) but SkyMessage did not open when the crosshair target was already in SexLab. Papyrus: `Expected 2, got 1` for `GetThreadByActor(Actor akActor, bool any_state)` from `Menu.ProcessHotkey`. The VM never entered the function, so the log showed `failed to find thread` even though the SexLab thread existed.

**Cause:** `GetThreadByActor` gained `any_state`; Papyrus defaults are compile-time at the call site. `Menu.pex` still made a 1-arg call. Same trap: `Stages.EditDescriptions` / `SetOrgasmExpected` calling `GetSceneByThread(thread)` after that function gained two extra args.

**Fix:** cross-script callers pass every arg (`GetThreadByActor(target, true)` while `IsActorActive`; `GetSceneByThread(thread, false, true)`). Recompile callers after any signature change.

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

Beta 25 does not read `prompts/`, `config/triggers/`, or `config/actions/`. Canonical LLM content is `SKSE/Plugins/SkyrimNet/external/goodprovider.sexlab/` (`manifest.json` `id` must equal the folder name). The same actions and prompts are also copied to `config/actions/` and `prompts/` so pre-0.25 SkyrimNet still loads them (`tools/sync_legacy_skyrimnet_content.py`; do not edit those copies by hand). Prompt paths inside the plugin are unchanged (`prompts/helpers/sexlab/…`, submodules). Action YAML filename (before `.yaml`) must equal the in-file `name` (case-insensitive); keep `name` casing. Settings schema stays at `config/plugins/SkyrimNet_SexLab/manifest.yaml` (`schema.fields` + `defaultValue`; `plugin.name` SkyrimNet_SexLab, `sexlab.*` keys) — that is not a content-plugin folder. Papyrus reads `Plugin_SkyrimNet_SexLab` via `GetConfig*` / `PatchConfig`. Ostim framework is `sexlab.ostim.player` (decorator `sexlab_ostim_player`); do not write `skyrimnet_sexlab_ostim_player`. Do not ship into `library/`. Upstream: SkyrimNet `docs/modding/MIGRATING_TO_BETA25.md`.

## SexLab P+ scene hop vs end (2026-09-10)

P+ `AdvanceFromTimer` does not end a player thread on the last stage when `ThreadWaitsForOrgasm()` is true (internal enjoyment + `HighEnjOrgasmWait` / `PlayerMustOrgasm` / `DomMustOrgasm`). It calls `FindSimilarSceneStage()` over `GetPlayingScenes()` (the `SetAnimations` list) and `ResetScene`s; if that list is empty it restarts the current scene. Vanilla still ends at `Stage > StageCount`.

**Do not** `SetAnimations` the full `GetAnimationsByTags` dump. Empty tags → skip lookup so SexLab picks internally (`SelectAnimations` and `SelectAnimationsDialog` both return `manager.empty`). On P+, cap a tagged match list to one random animation. `Scene.StageStart` also `EndAnimation()` after 120s real-time so enjoyment-wait cannot loop a single SLSB graph. Do not use `UpdateTimer` as an end mechanism on P+ — it sets `_ForceAdvance` and increases hopping.

MCM workaround: Climax type End/Legacy, or disable High Enj Orgasm Wait / Player Must Orgasm.

## Scene initiator vs victim (2026-08-30)

`Scene.initiator` is the speaker by default. If the thread has victims (`num_victims > 0`), a victim is never initiator: keep the current initiator only when they are not a victim; otherwise pick the first non-victim from positions 1…n then 0 (or None). Used for `"X initiates: …"` on first StageStart. Do not recompute on AlignActors / live SetVictim.

## BondagePanel / Devious Devices NG (2026-09-15)

- **Core SkyrimNet_SexLab does not require DD.** SexLab scenes, outfit, leash, and other TargetMenu panels load with no `DeviousDevices.dll`. BondagePanel / Handler_UDNG **does** require Devious Devices NG (`DeviousDevices.dll`) plus Assets.esm and Integration.esm. Legacy DD without NG is not supported for this panel.
- TargetMenu **bondage** is `panel: bondage` (`SKSE/Plugins/SkyrimNet_SexLab/webui/TargetMenu/Actor/options/0600_sexlab_bondage.json`). Catalog `requiresPlugin`: `Devious Devices - Assets.esm`; `requiresDll`: `DeviousDevices.dll` (row omitted if the DLL is not loaded). FOMOD optional “Devious Devices bondage”; Recommended when Assets **and** Integration are active. `make release` moves this JSON and `bondage/group-devices.json` into `handler_udng/` — see **Optional SKSE files / FOMOD split**.
- Handler `Setup_CheckLinks` fails (no BondagePanel) without Assets/Integration/`DeviousDevices` SKSE plugin / `zadLibs`. That does **not** fail the main quest.
- SKSE `SkyrimNet_SexLab.dll` never imports `DeviousDevices.dll`. `LoadAPI` / `GetProcAddress("GetAPI")` runs only on the BondagePanel path (first `bondageConfigure`). Vendor header: `SKSE_Source/lib/DeviousDevicesNG/API.h` (`DD_APIVERSION 2`). Do not include `DeviceReader.h` / `Export.h`.
- **Live catalog:** C++ `g_API->GetDatabase()` lockable inventory+rendered pairs (skip `zad_QuestItem` / unlocked), grouped by `unit.kwd`. Papyrus `PushBondageState` sends only `{target}` (number or string FormID). **ESL FormIDs are signed Papyrus ints** (`-33195884` = `0xFE057894`); C++ must `static_cast<uint32_t>` and match `Target` case-insensitively or `LookupByID` is 0, `GetWornDevices` never runs, and pulldowns stay `none`. JS payload is slim `{id,name}` + `equippedId`. **Do not** one-shot `Invoke` the full catalog (408KB object-literal never ran). **File first:** `Bondage_Configure` sends a small object-literal header (`bondageConfigure({...})`, same as `configureTargetMenu`) plus per-group `bondageConfigureDevices({...})` chunks from `group-devices.json`, then overlays `GetDatabase` when ready (`source: api`). Do **not** `PrismaUI->InteropCall`. Do **not** `TM_BondageRefresh` on ControlPanel actor focus unless BondagePanel is open (that flooded PrismaUI with ~27 Invokes + `onNotify` acks and TargetMenu never painted). JS paints `BONDAGE_GROUP_ORDER` body-area rows immediately (`none` until devices arrive); `bondageSortedGroups` ignores empty `ab.groups` (`[]` is truthy). Ack: one deferred `bondageGot source=… groups=N` per header (no per-chunk HUD/listener spam). Apply still uses the JC file + `plugin:0xhex`. Keep `ActorBondage.current` / `original` across catalog replace; empty `''` original is not a snapshot (re-seed from `equippedId`). Device `id` = `plugin:0xlocal` hex. **Start** sends `{current, original}` from JS `ActorBondage`; Finish skips unchanged groups.
- BondagePanel top aligns with ControlPanel (`.target-bondage-panel`). Each group is a stacked 75% `--text-base` **body-area** label (`bondageGroupName`) above nested pulldowns (`none` + material → color → leftover name, **≤20** items per menu; menus top-aligned with `#control-panel`, left edge = parent panel right + `--space-md`). Head-to-foot: Blindfold, Gag, Hood, Collar, Piercing Nipple, Body, Arms, Belt, Piercing Vaginal, Plug Vaginal, Plug Anal, Legs, Boots, Suit (`BONDAGE_GROUP_ORDER`).
- **ActorBondage** (JS class + Handler JFormMap original snapshot): seed original+current from worn the first time an actor is ControlPanel-current this overlay session. Later `TM_BondageRefresh` must not clobber `current`. Pulldowns write `ActorBondage.current` only (no Papyrus). `bondageConfigure` always rebuilds the device list from `current` (not worn) when the panel is open. **Start** (not Done) sends `currentJson` → `TM_BondageFinish` applies `SetGroupToId` per group from the JC file, narrates original vs wanted unless `silently`/`silent`, `ReleaseAll`, `WebUI_CloseOverlay`. **Cancel** closes BondagePanel only (Map kept so reopen shows pending `current`). Hide/Escape: `bondageReleaseAll()` + `TM_BondageOnWebUIClosed` **ReleaseAll only** — do not restore devices (the actor was never mutated until Start).
- `zadLibs` / device Forms live **only** on `SkyrimNet_SexLab_Handler_UDNG` (optional ESP). Do **not** put `zadLibs` on the main quest — the VM will not bind the type when DD is absent. Runtime: `GetFormFromFile(0x00F624, "Devious Devices - Integration.esm")`. Apply still uses `zadLibs.LockDevice` / `SwapDevices` / `UnLockDevice`.
- Compile import: `@ModsFolder\Devious Devices for SE-AE-VR\Scripts\Source` plus `PapyrusSourcesDD\SRC_SLA` (`slautilscr` on `zadLibs`). That tree’s `zadLibs.psc` is Headliner-stubbed; shipped DD `.pex` is used at runtime. Do not clone `PapyrusSourcesDD` into this repo / `Makefile` `dd:`.
- LLM lock/unlock stays in SkyrimNet_UDNG. `TM_BondageApply` can remain for other callers; BondagePanel must not use it.

## Scene Menu Start Control Panel new → Handoff (2026-08-16)

- Control Panel → Scene Menu → connection **new** seeds a provisional session (`_creator_sid:0`, `_from_target_menu:0`) with **no pooled** `Scene_Creator`. C++ Start then dispatches `WebUI_OnSceneCreatorResult(0, json)` because only `_from_target_menu` selects `WebUI_OnSceneCreatorHandoff`.
- `GetCreatorBySid(0)` misses → used to return with no Trace; SexLab never started. Result now Traces and falls through to Handoff (`CreateCreator` + `FinishStartScene`).
- Do **not** set `_from_target_menu` on Control Panel new — JS disables Load/Save presets when that flag is true. TargetMenu Custom keeps the flag; sid 0 is also a valid YesNo pool slot so C++ cannot infer provisional from sid alone.
- Same provisional seed in `Menu.WebUI_SeedSceneInfos` / `BuildAllSceneInfosJson` when there is no active `Scene_Creator` (`'new'` SceneInfo).

## Anidata schema 3.0 (2026-08-12)

- Contract: `docs/developers/anidata-schema.md` (+ accept/emit schemas under `docs/developers/schemas/`).
- Lookup: `<registry>.json` first, then display-name fallback (warn). Pack `_local_` last. No silent same-registrar merge.
- Port: `tools/port_anidata_v3.py --data-root <mods>` renames unambiguous display-name files; unmatched stay on display-name fallback.
- Stage change narration: `transitions["from-to"]` replaces `"Scene changes to "+desc` in `Scene.StageStart` when present.
- Rebuild AnimDB after upgrading so new SQLite columns / JSON packs are ingested.

## Nonsexual gender fallback / keep suppress (2026-08-10)

- **Policy / AnimDB none peel** (query-time; creator chips unchanged): after SexLab `GetAnimationsByTags` misses, (1) gender/position off with full must+suppress → (2) peel must-tags other than first (tail→front, keep `tags[0]`) → (3) peel suppress end→front with `tags[0]` → (4) drop front must-tag keeping full suppress (skip unconstrained 0+0). Never SexLab-random when original tags/suppress were set (`FinishStartScene` aborts).
- **`manager.empty` trap:** Scene Manager allocates `empty` as `sslBaseAnimation[2]` for identity compares. Never treat `anims.length > 0` alone as a hit — use `anims != manager.empty` (and `!= cancel`). Peel used to return after step1 miss because the sentinel looked non-empty.
- F/F + `nonsexual` often yields **0** from SexLab; AnimDB `_creature: exclude` + no gender/position finds F/M nonsexual while holding suppress as long as the peel allows.
- Callers: `SelectAnimations`, `ResolveAnimationsFromTags`, `SelectAnimationsDialog` final start.
- **SceneStart Custom:** C++ loads `scenes/*.json` into the TargetMenu catalog (`sceneSettings`). Overlay `ssLoadSetting` uses that cache (PrismaUI cannot fetch `../../../SKSE/...`). Custom applies **`default` then** `settingName` onto SceneInfo (speaking `""` clears `_pleasure_`; do not coerce empty through `filter(Boolean)` / `JArray.asStringArray`). Scene Menu setting pulldown stays **`none`** after Custom. Rapes / raped-by TargetMenu rows use `punish_pleasure_pain_rape`. Fallback hardcode still matches `nonsexual.json`. `filterByOnce='none'` for nonsexual/affection methods, otherwise Scene Creator default `gender`.
- **`SelectAnimationsDialog`:** probe/final miss never clears creator tags/suppress; peel is query-only then return to editor if still empty.

## Scene Menu filter-by downgrade (2026-08-10)

- Filter strictness in `MatchesFilter`: `positions` (per-slot `_pos_genders` + `_pos_race_keys`) ⊂ `gender` (aggregate counts, any arrangement) ⊂ `none` (`_actor_count` + tags + creature). Relaxing along that order can only gain animations.
- Each Scene Menu open arms the chain; `animDbQueryResult` steps one mode looser whenever the anim query returns zero and fallbacks remain. Tags query re-issues with the relaxed filter so available tags match the list.
- **Ordering trap:** in creator mode `scEnrichActorMeta()` resolves genders/race keys **after** the first query, so the opening `gender` pass runs on placeholder `_gender: 0`. Without re-arming on the `'e'` meta result the chain burns down to `none` before real genders exist. Re-arm from `SC.filterStart`, not the default mode, or the cuddle `none` seed flips back to `gender`.
- `animDbQueryResult` drops anim payloads whose `_request_id` != `'a' + SC.animQueryId`; C++ echoes the id verbatim and only `scRefreshAnims` issues `a`-prefixed queries, so a stale empty reply can no longer consume a chain step.
- Chain relaxes the **mode only** — actor count, tag chips, creature require/exclude, and **has description** still apply at `none`, so an empty list remains possible.

## StartScene tags CSV + SceneStartPanel (2026-08-13)

- Papyrus `StartScene_*` take **`tags`** (comma-separated), return **`Bool`**. Empty tags → skip AnimDB, still start. Non-empty → `AnimDb_ResolveTags` (sanitize + largest front-preferring subset, always lowercase); fail → False, no ModEvent.
- `AnimDb_CsvHasTag(csv, tag)` for membership checks (kissing → setting, etc.).
- YAML AI params stay named **`method`** (single value); ActionDispatch maps `method`↔`tags` positionally.
- TargetMenu inactive start rows share **`panel: scene_start`** (cuddle, punish, sex, masturbation, raped by, rapes). `panelDefaults` seed Subject / Object / `andThird` / intent / direction / method / style / setting. Root **Custom** (`type: scene_creator`, `0100_custom.json`) toggles Scene Creator on the creator SceneInfo (`new`) without applying a preset. **Start** probes `AnimDb_ResolveTags` — hit → close WebUI + existing `StartScene_One/Two/Three` (JS picks; Object `to victim` → TargetVictim / Nonconsensual_Three); miss → `onNotify`, stay open. Action-panel **Custom** closes SceneStartPanel, applies **`default` then** C++-shipped `scenes/{setting}.json` from the TargetMenu catalog (`sceneSettings`; PrismaUI cannot fetch `../../../SKSE/...`) (`tags_suppress`, `tags`, `array_defaults` / per-position `no_stripping`/`no_orgasm`/`speaking_modifiers`) onto creator SceneInfo `new`, shows Scene Creator with the setting pulldown on **`none`** (`SC.filterByOnce = 'none'` only for nonsexual/affection methods, otherwise `gender`). When Scene Creator is already visible, clicking cuddle/sex/etc. reapplies that row's `panelDefaults` (including default-then-setting overlay) to SceneInfo `new` instead of opening the Parameters panel. Nearby refresh still fills Include with all in-range actors except `child`/`dead`.
- Layout: Subject; `none|and` + optional third actor; direction (giving/getting vs fucking/fucked in filters method); Object relation `with|to victim|none` + Object actor; intent (custom opens IntentPanel); style; Scene Setting. UI intents `show affection` / `comfort` map to Papyrus `showing affection` / `comforting`. Hug-giver @ SexLab pos1 when intent is those labels **or** method is `cuddling|kissing|hug` (`StartScene_Event` + Custom JS). Selectable pool gates: only player → Object disabled; player+one → `and`/third disabled. **Custom** stays enabled whenever Subject is set (missing Object / third / duplicates still open Scene Creator); **Start** keeps the stricter cast gates.
- Third is `participate` only (never a second victim). Solo + assault/punish uses `StartScene_Nonconsensual_One`.

## Parameters Position formId on Start (2026-08-08)

- Position 0/1 pulldowns write `{ type: "Actor", formId }` into `paramDict` (target/speaker). Custom/scene-seed already used `ResolveActorDictEntry`.
- **Bug:** `ExecuteAction` / `ExecutePapyrusOption` ignored `formId` and always `ResolveSource` (player/focus) — picking Toy had no effect on Start.
- **Fix:** Both paths resolve Actor dict via `ResolveActorDictEntry` first, then fall back to `source`.
- **Also:** `ExecutePapyrusOption` must apply UI params **after** `defaultsParameters` (same as `ExecuteAction`). Defaults-last wiped Cuddle `speaker`/`target` formIds back to `playerActor`/`currentActor`.

## TargetMenu cascade label+pulldown rows (2026-08-23)

- Parameters, scene start (Cuddle), outfit, bondage, and stop put confirm buttons as the **first row** of the cascade panel (`Custom`/`Start`, `Cancel`/`Start` on BondagePanel, silent/stop/explain). The left TargetMenu option already names the panel (no title+buttons header).
- `.labeled-fields` is a 2-col grid (`max-content` + pulldown). Child `.dyn-field` uses `display: contents` so pulldown left edges align down the column. Bondage groups are stacked (75% label + 1em-indented pulldown), not this grid. `#right-dynamics` still scrolls; menus stay `position: fixed` so they are not clipped.

## TargetMenu Parameters pulldown clip (2026-08-08)

- `#right-dynamics { overflow-y: auto }` makes `overflow-x: visible` ineffective (CSS forces both axes). Right-opening `.pulldown-menu` children were clipped while Start/Custom (outside the scroller) still worked.
- Fix: `createPulldown` opens menus with `position: fixed` + `getBoundingClientRect` (`positionOpenPulldownMenu`); clear on close. Affects all action→Parameters paths (comfort/affection/punish/sex/masturbation/outfit), not cascade/papyrus option rows.

## Scratch files `z-*.*` (standing rule)

Always **ignore** files matching `z-*.*` (e.g. `z-plan.md`). Local scratch / notes only — not product docs or agent source of truth.

## Optional SKSE files / FOMOD split (standing rule)

- **One source of truth:** optional-handler files that the game reads at runtime live under `SKSE/Plugins/SkyrimNet_SexLab/` in the repo (Actor `options/`, `bondage/group-devices.json`, etc.). Do not keep a second copy under `optional/handler_udng/`.
- **Split at release:** `make release` copies `SKSE` into `core`, then **moves** those files into `handler_udng/` (same Data-relative paths) so Nexus FOMOD can install them only with the handler ESP. Dev/MO2 overlay uses the repo tree as-is.

## ControlPanel actor focus + active TargetMenu (2026-08-07)

- ControlPanel bottom `#control-actor-pulldown` owns focus for TargetMenu / Scene Menu / AnimationPanel. `#target-name` and Scene/Animation **scene** pulldowns removed. OStimNet framework pulldown (`#framework-row`) sits on ControlPanel above the actor row.
- Nearby list (C++ `PopulateNearbyActors`): player first; then status `sexlab` → `ok` → ineligible (`child`/`cmbt`/`ostim`/`dead`/`load`); then distance. Labels crop name to 10 + status suffix. Scene Menu Positions unselected rows = `selectable` and status `ok|sexlab` (ineligible stay off that table). Soft Sex Menu pool = `selectable && status==ok`.
- Hotkey **always toggles** overlay visibility: visible → C++ `WebUI_Visibility_Hide` (no Papyrus); hidden → `Open_WebUI_Target` (+ `WebUI_AfterTargetOpen` default pick). Close does not require the same focus actor. MultiTarget retired for this path. Animation main-panel preference persists across hide; restore via `WebUI_MaybeRestoreAnimationPanel` only when focus is SexLab-animating **and** preference true.
- Active panels: `stop` (speaker + silent/stop/explain → SceneInfo), `stage` / `position` (**Done** → SceneInfo), `animation` (AnimationPanel name picker; **Done** → SceneInfo).

## Active TargetMenu `type: papyrus` (2026-08-06, Actor/Scene split 2026-08-16)

- Mid-scene TargetMenu options under `webui/TargetMenu/Scene/options/*.json` use **`type: papyrus`** (no `name`, no YAML / `actions_index`). JS `onAction({action:"papyrus",...})` → C++ `ExecutePapyrusOption` → `SkyrimNet_SexLab_Actions.TM_*`. Actor (not animating) options live in `webui/TargetMenu/Actor/options/`. Catalog pick is ControlPanel focus `SexLabAnimatingFaction` — no per-option faction eligibility on Scene JSON. Actor **`panel: outfit`**: sentence `position_1` / style (`forcefully|normally|gently|silently`) / undresses|dresses / `position_0`; Start → `TM_Outfit`; no Custom; silently skips SkyrimNet narration.
- Storage: Animation JSON durable; AnimDB cache; Scene overlay this-thread only. Save (`TM_SaveAnimationSettings` / AnimationPanel Save) → SQL + JSON (`orgasm_expected`, `speaking_modifiers`, `clothed`). Victim/deny never durable; deny saves as expected=`1`. Full speaking token CSV is persisted (not token `[0]` only).
- Anim switch: `SeedOverlayFromAnimDb` — per-registry `user_anim_defaults` win, else AnimDB, else orgasm→speaking helper (`1`→`_pleasure_`, `0`→`""`).
- Live Scene panels (`panel` on option JSON): `stop` / `stage` / `position` edit a panel draft; confirm (silent/stop/explain or **Done**) writes the selected SceneInfo. `animation` opens AnimationPanel; **Done** writes `activeRegistry`. SexLab `TM_*` / `ApplyWebUICommit` run on overlay commit, not live.

## Debug SKSE DLL + PublicGetPluginConfigValue CTD (2026-08-05, harden 2026-08-16)

- **Symptom:** CTD on load / `kDataLoaded` — Crash Logger `EXCEPTION_ACCESS_VIOLATION` in `SkyrimNet_SexLab.dll` during `std::string` teardown (`std::exchange`).
- **Stack:** `plugin.cpp` → `Config::ApplyFromConfig` → `ApplyMenuHotkey` → `EditStageHotkeyEnabled` → `GetValue` → SkyrimNet `PublicGetPluginConfigValue` (returns `std::string` by value across DLL). Same AV later from `PublicGetActorNameByUUID` in WebUI.
- **Cause:** Debug-built `SkyrimNet_SexLab.dll` (~7.96 MB, `/MTd`) against Release SkyrimNet (`/MD`) — `std::string` layout mismatch. Stack shows `0xCCCCCCCC` fill and path `sexlab.controls.editStageHotkeyEnabled`. AV is on return/destructor; memcpy / `.c_str()` after the call cannot help.
- **Also:** `CMake: Build SKSE (Debug)` copies over `SKSE/Plugins/` (e.g. 2026-08-16 2:39 PM overwrote a 2:17 PM Release). In-game config needs Release.
- **Fix:** `_DEBUG` skips all SkyrimNet exports that return `std::string` (`CrossDllStdStringSafe` in `Config.h`) and uses hardcoded fallbacks. Ship / test config with `CMake: Build SKSE (Release)` (~2.66 MB).
- **Crash logs (this machine):** `C:\Users\bhuff\OneDrive\Documents\my games\Skyrim Special Edition\SKSE\crash-*.log` (OneDrive Documents).

## Plugin config / control store (2026-08-04)

- **Source of truth:** `SKSE/Plugins/SkyrimNet/config/plugins/SkyrimNet_SexLab/manifest.yaml` (`schema.fields`). New settings always go in the manifest; MCM may mirror utilities only.
- **IDs:** C++ `PublicGetPluginConfigValue("SkyrimNet_SexLab", path, def)`; Papyrus `SkyrimNetApi.GetConfig*("Plugin_SkyrimNet_SexLab", path, def)`.
- **Practical split:** C++ owns plugin-config hotkey (`sexlab.editor.hotkey_enabled` / `sexlab.editor.hotkey` VK→DX via `MapVirtualKeyA`), WebUI Settings panel, and syncing `skyrimnet_sexlab_public_sex_accepted` / `hide_hermaphrodites` / `ostim_player` globals on load. MCM can also enable/remap the same KeyHandler via DX `WebUI_SetHotkey`. Papyrus only `GetConfig*` at Menu / Utilities / Scene / Creator / Manager call sites. No plugin `PatchConfig`.
- **ControlPanel framework toggle** still writes the ostim_player **global** for live eligibility; next load re-syncs from control store.
- **Settings main panel:** `webui/MainPanels/1000_settings.json` → `settings_panel` (rebuild → switches to Log, version from `info.json`, docs URL text, Open SkyrimNet dashboard). MCM shows redirect text + rebuild + last-rebuild timestamp.
- **Log main panel:** `webui/MainPanels/0900_log_panel.json` → `log_panel`. Source: `SKSE::log::log_directory()` + `SkyrimNet_SexLab.log`. JS regex filter; follow-tail until user scrolls away. Settings Rebuild AnimDB switches here so progress lines are visible.
- **No Prisma deep-link** to Plugins → SkyrimNet_SexLab; `TriggerToggleDashboard()` only toggles the SkyrimNet dashboard. **ShellExecute** for GitHub docs is unreliable in-game — show the URL as text instead.

## AnimationDB creature / race-key filter (2026-08-02)

- Scene Creator sets `_creature: require|exclude` from SexLab classification only (`GetGender` 2/3 + `sslCreatureAnimationSlots.GetRaceKey`). Do **not** treat non-creature as “human.”
- **Filter by pulldown** (`gender` / `none` / `positions`, default `gender`): `none` and `gender` apply `_creature` require/exclude without forcing `_position_match`. `gender` sends `_gender_match` + aggregate `_males`/`_females`/`_male_creatures`/`_female_creatures`. `positions` uses `_position_match` + `_pos_genders`; when any creature is present also `_pos_race_keys` (exact lowercase match vs AnimationDB `pos_race_keys`). Dog → only `"Dogs"` (primary GetRaceKey), not `creatures.json` display names.
- **`_gender: 0` is male, not unknown.** Scene Menu must not default unresolved positions to `0` (that queried male,male for a female+male cast). Use `null` until C++ nearby `gender` (`GetSex`) or Papyrus `GetGender` meta arrives; skip `_gender_match` / `_position_match` until every position is resolved. Persist enriched genders onto SceneInfo so `copySceneInfoToSC` does not wipe them. Match meta by `formIdU32`. Anim count shows cast letters (`F M`).
- Anim list sort: selected/active → has-description → gender-position string (`FFM` from `_pos_genders`, 0/2→M 1/3→F).
- Positions carry `_race_key` from Papyrus `BuildWebUIState` / `GetRaceKeyForActor`. TargetMenu C++ open and nearby-add enrich via `onResolveActorMeta` → `WebUI_OnResolveActorMeta` → `actorAnimMetaResult`.
- WebUI `ParseFilterJson` must accept `_creature`, `_pos_race_keys`, `_gender_match`, `_males`, `_females`, `_male_creatures`, `_female_creatures` (parity with Papyrus AnimationDB parse).

## AnimDB no auto-rebuild on load (2026-08-21)

- Load opens SQLite only (`AnimDb_Open`). Do **not** call `StartSync(False)` from `Main.Setup`.
- After SexLab is enabled, compare `AnimDb_TotalCount` vs human+creature `Slotted`. Match → no prompt. Mismatch → `Trace` + notification `SkyrimNet SexLab # animations doesn't match`, then SkyMessage **above everything** (`ShowArray_NonBlocking`, poll `OnUpdate` — do not latent-block `OnPlayerLoadGame`).
- Empty DB: body `AnimDB is empty`, buttons **Build AnimDB** / **Close**. Non-empty mismatch: `AnimDB has N, SexLab has M`, buttons **Rebuild AnimDB** / **Close**. Close / ESC does nothing. Build/Rebuild → `StartSync(True)` (MCM / Settings still use `RebuildDatabase`).

## AnimationDB + PrismaUI scene panels (2026-08-01)

- **DB file**: `Data/SKSE/Plugins/SkyrimNet_SexLab/animationdb.sql` (SQLite via vcpkg `unofficial-sqlite3`). Registry / tags / race keys stored lowercase for matching; PK = SexLab `registry`. Display `name` (and `animations/(name).json`) keep SexLab casing.
- **Ingest**: Papyrus `SkyrimNet_SexLab_AnimDb` walks `GetBySlot` in batches (not SexLab `GetByTags` — 125-cap lossy). C++ `InferOrgasmExpected` seeds `pos_no_orgasm` / speaking mods; stage descriptions from `animations/**/*.json` (`_local_` last wins). Rebuild is player-opt-in (load prompt / MCM / Settings), not automatic.
- **YesNo / SceneCreator are async**: PrismaUI cannot block like SkyMessage. `SelectAnimations` returns `manager.ui_pending`; C++ JS listeners dispatch `Scene_Manager.WebUI_OnYesNoResult` / `WebUI_OnSceneCreatorResult` → `ContinueAfterYesNo` / `ContinueAfterSceneCreator` → `FinishStartScene`.
- **Yes always opens SceneCreatorMenu**; **Yes (Random)** skips editor; NPC–NPC opens creator when config `sexlab.tagEdit.nonPlayerDialogs` is on. Escape on YesNo = No (Silent).
- **TargetMenu Custom / Start**: root panel only; each pulldown + Parameters are sibling panels in a row **above** Scene Creator. Action click opens Parameters (no immediate start). **Custom** / **Start** close the cascade then fire; Custom opens Scene Creator (`_from_target_menu`, `_creator_sid:0`); Start on SC → `WebUI_OnSceneCreatorHandoff`. **Start** always `ExecuteAction` then **closes WebUI** (clear session + hide; PrismaUI `Focus(..., pauseGame=true)` must not stay focused or SexLab `StartThread` fails). Scene Creator **Start** also closes WebUI even when TargetMenu session is still active (Custom path). For scene-start actions sets `SkipSceneCreatorOnce` → `ConsumeSkipSceneCreator` → `scene_creator_menu_called` so Papyrus skips Scene Creator **and** YesNo (Yes/Random). SceneStartPanel **Start** (`action:"papyrus"` + `closeWebUI` + `StartScene_*`, not `Refused`) sets the same flag; outfit/live papyrus rows do not. Tag Edit MCM no longer intercepts TargetMenu Start.
- **Cuddle tags**: LLM/general method `cuddle` → `cuddling` (`RemapTag` / `Actions` / C++ `RemapMethod`). Dedicated cuddle actions keep UI method `sitting|laying` for narration but `Setup` adds SexLab tag `cuddling` (not sitting/laying — those are position tags and miss Ace cuddle packs).
- **`scene_creator_menu_called`**: once per creator / SexLab thread; `TryOpenSceneCreatorMenu` gates Papyrus first-open; Load/Save refresh still calls `SceneCreator_Open` directly. TargetMenu Custom may re-`configureSceneCreator` while TargetMenu stays open (`TargetMenuSessionActive`; HideAllPanels spares TargetMenu until Cancel). **Do not** keep TargetMenu open across Start — paused overlay blocks SexLab.
- **Scene Creator anim list**: query cap is 125 (SexLab `GetList`). Do **not** embed `JSON.stringify(anim)` in each row `onclick` — with 125 rows that freezes CEF during `configureSceneCreator` and the panel never paints. Keep rows in `SC.lastAnims` and pass an index. Rendered as a 5-column table (genders / modifiers / name / num stages / description); WebUI `AnimRowToJson` includes `_stage_descriptions` so the description column can substitute `{{sl.actors.N}}` from Scene Creator positions. **Layout:** `#scene-creator-panel` fills `#main-panel-host`; `.sc-anims-section` is a fixed **50%** of the panel; only `#sc-anims-list` scrolls.
- **Scene settings pulldown:** Names and JSON bodies come from C++ `LoadSceneSettings` (`scenes/*.json`) on **both** TargetMenu and ControlPanel catalogs. A DLL whose ActionCatalog log line has no `N scene settings` count will leave the pulldown as only `none` and Custom/punish cannot overlay speaking. JS `ssAdoptSceneSettings` copies that object into `SCENE_SETTINGS` / `window.SCENE_SETTINGS` and refreshes the pulldown. Open still resets the pulldown to **`none`**. Picking a file applies `default.json` then that file without changing actors. **Save** dialogs write via Papyrus even when `creator_sid` is 0.
- **Victim mask:** After WebUI V toggles, call `RebuildVictimsFromMask` — never `SetNames`/`SetMasks` (those rebuild the mask from `victims[]` and wipe UI).
- **AnimationMenu:** hotkey opens TargetMenu + ControlPanel focus; Animation main panel restores only if preferred-open and focus is SexLab-animating. AnimationPanel is an in-thread **name picker** (filter + scrollable list, no 10-cap); **Done** writes SceneInfo. Stage/position/stop live on TargetMenu Scene. Escape cancels the overlay without committing SceneInfo.
- **Scene Menu dual-mode (2026-08-02 / 2026-08-07):** UI label Scene Menu; scene focus from ControlPanel actor (no duplicate scene pulldown). Active: A/N + Update (SexLab anim list cap **128** via `sslUtility.PushAnimation`). Tags stay UI filters — pool mutates only on Update.
- **Legacy**: `SkyrimNet_SexLab_Stages` is an empty stub for save compatibility; all callers use AnimDb.

## Caprica rejects formal param name `scriptName` (2026-07-29)

Caprica fails natives that declare a parameter named `scriptName` with `no viable alternative at input 'String'` (even a one-arg stub). Callers are unaffected (positional). Use a different formal name (e.g. `sName`) and document the slot in a comment — see `SkyrimNet_SexLab_API.RegisterTargetMenuOption`.

## TargetMenuRegistry external options (2026-07-29)

`SkyrimNet_SexLab_API.RegisterTargetMenuOption(Form quest, …)` appends runtime actions to the WebUI Target Menu (end of `options` + `actions` in `BuildUICatalog`). Stores the quest **FormID** (not EditorID) — EditorID lookup often fails for optional handler ESPs and `FindQuest` would fall back to the main quest. Cleared on `kPostLoadGame` / `kNewGame`; handlers must re-register in `Setup` with `self as Form`. Click dispatches via `ExecuteAction` with a single `target` Actor arg.

**Preferred (2026-08-02, dest 2026-08-16 / bondage 2026-08-21):** optional handlers ship filesystem `webui/TargetMenu/Actor/options/*.json` with `plugin` + `questFormId` + `scriptName` + `executionFunctionName` (+ optional `requiresPlugin`). Bondage is Actor `options/0600_sexlab_bondage.json` (`panel: bondage` → Handler_UDNG `TM_Bondage*`). Live under the repo SKSE tree; `make release` moves it into FOMOD `handler_udng/` (see **Optional SKSE files / FOMOD split**). `RegisterTargetMenuOption` is legacy (Actor catalog only).

## ControlPanel / MainPanels (2026-08-02, rename 2026-08-16)

Left column: ControlPanel (`#control-panel`: **mode pulldown** + **views** label + indented main_panel pulldown + OStimNet framework pulldown + **target** label + indented **actor focus pulldown**) above TargetMenu (10% top/left). Right: one main panel (10% top/bottom/right) from the **active mode** `MainPanels/` (`builtin`, `papyrus`, `data_table`, `actor_detail`). Pulldown → `onMainPanelChange` → `SwitchMainPanel`. Catalog invoke: `configureControlPanel`. Actor focus → `onControlActorChange` → `ApplyControlActorFocus` / `WebUI_OnControlActorFocus` (catalog refresh only) + JS `selectSceneInfoForActor`. `WebUI_Visibility_Show` pushes `setFrameworkToggle` and `WebUI_SeedSceneInfos`.

### ControlPanel modes + foreign hosts (2026-09-15)

- **Mode registry:** only `Data/SKSE/Plugins/SkyrimNet_SexLab/webui/ControlPanel/*.json` plus built-in `sexlab`. SexLab git does not vendor third-party JSON. `requiresPlugin` omits missing ESPs. `catalogRoot` loads that plugin’s own `TargetMenu/Actor` + `MainPanels` (not SexLab’s `webui/`). `SwitchControlMode` closes the current main panel, runs previous `closeFunction`, swaps catalogs, runs `openFunction`. Session remembers the last mode across overlay hide.
- **Pause:** overlay still `Focus(view, true)`. TargetMenu execute must `closeWebUI: true` or SexLab `StartThread` / other-mod packages stall. Foreign panel `openFunction` and config toggles stay `closeWebUI: false`.
- **Sentinel target:** pulldown entries with `id` and no FormID. Optional sentinel `mainPanel` / mode `rowClickMainPanel` drive `SwitchMainPanel`; omit them to leave the current panel. `Target_Current` is null; `FocusKind` holds the id. `webui_focus_kind` eligibility; `ExecutePapyrusOption` allows None target. `Target_Menu_Refresh` is valid with a sentinel. Do not treat player focus as group.
- **Foreign panels:** `data_table` / `actor_detail` paint HTML from `WebUI_PushMainPanelData`. Payload must include `plugin` / `scriptName` / `applyFunction` — JS has no plugin-name fallbacks. Cap table rows — a huge Invoke stalls PrismaUI. ESL FormIDs from Papyrus are signed; JS `formIdU32` / C++ accept signed-or-string `formId` on row click. Do not mix table and detail in one payload.
- **TargetMenu `panel: fields` (2026-09-18):** Start + labeled selects from `panelFields`/`panelDefaults`. `applyOnChange` fires on pick. `opensText` options show inline text; Ok adds to the pulldown (session-only). Live Push: `WebUI_PushCascadeChoices` → `setCascadeChoices` (`panel:"fields"` or button `options[]`). Catalog openers without static `panelFields` fire Papyrus first. DOM punish method `rape` embeds `scene_start` without Custom; Start → mind record then SexLab Nonconsensual.

- **SceneInfo (2026-08-22):** JS class + `sceneInfoByKey` (`'new'` + `scene:<sid>`). Seed on Show. Panel drafts copy SceneInfo on open. Start/Done/Update/Stop write into SceneInfo; Cancel does not. Overlay Cancel/Escape → `WebUI_Visibility_HideWithoutCommit` (drop dirty). Hotkey / Scene Start / TargetMenu Start → `flushSceneInfos` → `WebUI_OnSceneInfoCommit` then Hide. Do not live-call `TM_*` from Scene panels during the session.

- **Escape peel (2026-08-23):** Escape closes the highest UI layer first (open pulldowns → IntentPanel Cancel → YesNo silent → Sex menu → TargetMenu cascade/Parameters → main panel to ControlPanel **None**). Leftover TargetMenu/ControlPanel hides the overlay without SceneInfo commit. Scene Creator without TargetMenu (YesNo) still Cancel. Root Custom closes an open Parameter panel before toggling Scene Creator.

- **No pause toggle (2026-08-22):** Overlay always `Focus(view, true)`. Removed ControlPanel pause/unpause so live threads cannot drift from SceneInfo. Log tail is file I/O. AnimDB rebuild that needs Papyrus updates waits until close.

- **ControlPanel missing after Start (2026-08-16):** Scene Creator / papyrus Start hide `#control-panel`. Same-actor `Target_Menu_Open` used to only `configureTargetMenu` + Show, skipping `showPanel`. Overlay came back with TargetMenu/ControlPanel still `display:none`. Fix: `WebUI_Visibility_Show` invokes `showControlPanel()`; same-actor open also `showPanel('target_menu_panel')`.

- **Scene Menu appear/disappear loop (2026-08-03):** Do **not** call `requestSceneConnectionChange` from `revealMainPanel`. Connection reload → `SceneCreator_Open` (`showPanel` → `onMainPanelChange` → `SwitchMainPanel` → reveal) loops. Soft path: bind selected SceneInfo (`mainPanelDidOpen` / `configureSceneCreator` merge, no HideAll/showPanel). `SwitchMainPanel` invokes `mainPanelDidOpen()` once on **key change** only. `showPanel` for SC/AM is idempotent when already selected.

## SKSE native params must use engine types (2026-07-25)

CommonLib `RegisterFunction` derives the Papyrus signature from C++ types (`RE::TESForm*` → `Form`, `RE::Actor*` → `Actor`, etc.) and refuses to bind if the `.pex` differs. Declaring a specific script type on a native (e.g. `sslThreadController`) causes: `Native static function … does not match existing signature … Function will not be bound.`

**Fix**: Use engine types in the Papyrus stub that match C++ — e.g. `Sex_Menu_Open(Form thread, bool has_player)` with `RE::TESForm*`. Callers may still pass `sslThreadController` (it is a Quest/Form).

## ModEvent PushForm actors must be received as Form (2026-07-25)

SexLab/SLSO `SexLabOrgasm` uses `ModEvent.PushForm(eid, ActorRef)`. Handlers that declare the first parameter as `Actor` fail type-check for unique NPCs whose **attached script** is an Actor subclass — e.g. vanilla `WIDeadBodyCleanupScript` on Camilla (`CamillaValeriusREF`). Papyrus reports `received incompatible arguments! Received types (WIDeadBodyCleanupScript,int,int) instead!` and the event never runs (orgasm narration dropped for that NPC).

**Fix**: Receive `Form`, then `akForm as Actor` (same pattern as this mod’s `Action_Stop` / `MenuOpen`). `WIDeadBodyCleanupScript` is often on living uniques — it is cleanup-on-death, not “already dead.”

## PrismaUI view path (2026-07-24)

`CreateView("SkyrimNet_SexLab/index.html")` loads from **`Data/PrismaUI/views/`**, not from `SKSE/Plugins/`. This mod ships the overlay at `PrismaUI/views/SkyrimNet_SexLab/index.html` (restored from commit `a8c9440`). **`make release` copies `PrismaUI/` into FOMOD `core`** so it installs under Data. Missing that file → valid-looking C++ open path (hotkey / `Target_Menu_Open`) but **no visible UI**. Do **not** `Show`/`Focus` until `g_domReady` — `Focus(view, true)` pauses the game; Escape is JS `handleGlobalEscape` which never runs if DomReady never fires (player stuck paused). C++ Escape and a refused open `Unfocus`/`Hide` instead. Papyrus `Open_WebUI_Target` notifies when `Target_Menu_Open` returns false. C++ Invokes use panel ids `target_menu_panel` / `sex_menu_panel`; the HTML maps those via `showPanel` / `hidePanel` adapters onto `#target-panel` / `#sex-menu-panel`.

**Display scale (2026-08-07):** Matches SkyrimNet dashboard scaling system. Design tokens are **px** (`--text-base: 15px`, `--space-*`, `--radius`, `--target-min: 44px`); global scale is `document.body.style.zoom = clamp(ui_scale,0.75–1.5) * resolutionBaseline()` where baseline is `1` at ≤~1080p height else `(innerHeight/1080)*0.85` (up-only; never shrinks from resolution). User `ui_scale` from `GET {__SN_BASE__||http://localhost:8080}/config?api=get&name=Dashboard`. Fit without crop: `#left-column` / target panels use `max-height` + `overflow-y: auto` (same pattern as SkyrimNet’s `.main` scroll). Re-applies on resize and Settings configure.

**Menu hotkey (2026-08-04, toggle 2026-08-16, DomReady guard 2026-08-21, keys 2026-09-15):** Plugin config `sexlab.editor.hotkey_enabled` + `sexlab.editor.hotkey` (VK→DX). MCM also has Enable + KeyMap (DX) → `WebUI_SetHotkey`. Escape stays always registered; if DomReady never fired, Escape is C++ `WebUI_Visibility_Hide` (Unfocus), not queued JS. Hotkey hides immediately when the overlay is visible (any actor); otherwise `Menu.ProcessHotkey` → `Open_WebUI_Target`. Same-actor reopen rebuilds catalog, `showPanel('target_menu_panel')`, and Show (ControlPanel included). Do not dispatch `AfterTargetOpen` on close. Do not Show/Focus until `g_domReady`. `WebUI_SetHotkey(0, true)` disables the KeyHandler — never pass DX 0 when enabled.

## WebUI target menu catalog (2026-07-28, outfit/actionSwitch 2026-07-31, split layout 2026-07-31)

Target panel UI is driven by:
- `Data/SKSE/Plugins/SkyrimNet_SexLab/webui/TargetMenu/Actor/defaults.json` — `{ "defaultsParameters": { ... } }` (legacy root key `defaults` still accepted).
- `Data/SKSE/Plugins/SkyrimNet_SexLab/webui/TargetMenu/Actor/options/*.json` — start-scene + outfit when focus is **not** in SexLabAnimatingFaction.
- `Data/SKSE/Plugins/SkyrimNet_SexLab/webui/TargetMenu/Scene/options/*.json` — live-scene group editors when focus **is** animating.
- `Data/SKSE/Plugins/SkyrimNet_SexLab/webui/actions_index.json` — generated from SkyrimNet action YAMLs (`tools/generate_actions_index.py`); `{ "actions": [...] }` only (no `by_category`).

**Order = lexicographic filename** (numeric prefixes). All JSON keys lowercase. Pulldowns / switches nest via `options[]`; each `action` needs `name` (SkyrimNet id) + `label` (WebUI display only). Optional `parameters` on `action`/`pulldown` overrides defaults. C++ loads both trees and `BuildUICatalog` picks Actor vs Scene.

**Actor sources** in `defaultsParameters`: prefer `playerActor` (player) and `currentActor` (menu focus). `ActionDispatch::ResolveSource` also accepts legacy `player` / `target` / `focus`.

**`actionSwitch`**: `options[]` of `action` children, each with SkyrimNet-shaped `eligibilityRules`. C++ evaluates in order, takes the **first** true branch, logs the winner. No match → emit disabled/greyed row using switch `label` or first child’s `label`. Menu focus is `currentActor` for `FormListCount` / strip storage.

**Outfit roles**: Papyrus `Outfit_Dress` / `Outfit_Undress(Speaker, Target, style, narration)` — Speaker performs, Target’s outfit changes; StorageUtil key `skyrimnet_sexlab_storage_items` is on **Target**. Narration `silent` → `RegisterEvent`. Style `silently`/`silent` skips both DirectNarration and RegisterEvent. TargetMenu dress/undress is papyrus `panel: outfit` → `TM_Outfit` (not YAML Start); FormListCount eligibility picks the undress vs dress left-row label; execute uses `HasStrippedItems` on selected position_0. Hotkey opens via `Menu.Open_WebUI_Target` (passes `HasStrippedItems`). LLM YAML files are `outfit_dress.yaml` / `outfit_undress.yaml` under `SKSE/Plugins/SkyrimNet/external/goodprovider.sexlab/actions/` (filename equals `name`).

Regenerate the index after editing action YAMLs (`tools/generate_actions_index.py` reads `external/goodprovider.sexlab/actions`). C++ `ActionCatalog` loads at WebUI init and **reloads on every `kPostLoadGame` / `kNewGame`** (`WebUI_SetGameReady`); Start merges dictionary onto YAML `parameterMapping` and `DispatchMethodCall`s `scriptName`/`executionFunctionName`. Do not change SkyrimNet YAML schema — only action content within existing fields.

Guideline: if a pulldown would have only one child, promote that child to a top-level `action`.

## TargetMenu hierarchical param store (2026-08-02)

Do **not** remember dynamic fields under flat `sns_tm_param:<name>` — shared names (`method`, `direction`) leaked across actions (e.g. comfort `hugging` onto fucking). JS builds a parent-linked tree from the catalog (synthetic root `id=0`; DFS creation ids; `path = parent.path + '.' + label`). Values live at `sns_tm_node:{id}.{path}.{key}` (empty path → `sns_tm_node:0.style`). Global `parameter` options (e.g. `style`) read/write the **root**. Action dynamics initialize fill-if-absent by walking parents for an **allowed** YAML pipe match (style synonyms `gently↔gentle`, `normally↔normal`, `forcefully↔forceful`), else first pipe / full non-pipe description; then store on that action node. `configureTargetMenu` clears legacy `sns_tm_param:*`.

## SexLab position slots and speaker_position (2026-07-23)

In this mod's sex / punish animations, **position_0 is submissive** and **position_1 is dominant**:
- position_0 gives oral to position_1; position_1 receives oral from position_0.
- position_1 fucks into position_0; position_0 is fucked by position_1.
- Punish scene JSON puts `_pain_` (and whipping `_gagged_`) on index 0.

The **Speaker is always the subject** of LLM-facing sentences. `speaker_position` places the Speaker into that slot:
- `StartScene_Nonconsensual_Two_TargetVictim` → speaker at **pos1** (target is victim).
- `StartScene_Nonconsensual_Two_SpeakerVictim` → speaker at **pos0** (speaker is victim).
- Consensual direction tokens (Speaker as subject): `fucking` / `fuck a` / `fucking a` / service `getting` → pos1; `fucked in` / service `giving` → pos0.
- **Cuddling intents** (`cuddling` / `showing affection` / `comforting`): opposite of oral — `giving` → pos1 (hug giver / male slot); `getting` → pos0.

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
