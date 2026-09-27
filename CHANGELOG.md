# Changelog

## Unreleased

### Animation speed
- Scene style now sets animation playback speed: gently 0.75×, normally 1.0×, forcefully 1.4× (dashboard **Animation speed**: `sexlab.speed.enabled`, `sexlab.speed.gently|normally|forcefully`). Speed only: stage length, orgasm timing and voices are unchanged. Native `UpdateAnimation` hook in `SkyrimNet_SexLab.dll` (`AnimSpeed.cpp`); Papyrus `SkyrimNet_SexLab_Utilities.SetAnimSpeed` / `ClearAnimSpeed` / `GetAnimSpeed`
- New LLM action `SexLab_Change_Style` (speaker + `forcefully|normally|gently`) changes the style of the speaker's live scene, with one DirectNarration
- New **Style hotkey** (`sexlab.style.hotkey_enabled`, `sexlab.style.hotkey`, default `]`) cycles gently → normally → forcefully on the player's scene (else the crosshair actor's). The WebUI style control also changes speed live

### Narration
- DirectNarrations made while the game is paused (WebUI overlay or a pausing menu) are queued in the DLL and sent as one joined DirectNarration once the game unpauses. Fixes NPC responses failing ("failed to generate a response") after WebUI actions such as the Description Editor style pulldown, because SkyrimNet cannot run Papyrus decorators while paused

### Voice
- SexLab moans now follow speaking modifiers: an actor moans only while its modifiers include `_pleasure_` or `_pain_`; no modifiers, `_gagged_`, or `_kissing_` force the actor silent (`thread.SetVoice(..., ForceSilent)`). Re-applied at scene setup, every `StageStart`, live speaking edits, and after a load. Dashboard toggle **SexLab moans follow speaking modifiers** (`sexlab.voice.follow_speaking`, default on). See [docs/reference/protocol-tokens.md](docs/reference/protocol-tokens.md#sexlab-voice)

### AnimDB
- Live scenes now apply the animation's speaking modifiers (as shown in the Description Editor, per stage) at every `StageStart`, so a position with orgasm not expected / empty speaking no longer keeps the creator's `_pleasure_`. Live speaking edits stay until Save or an animation switch
- Scenes started without "override animation settings" now begin each actor in the clothed state most candidate animations share (new `AnimDb_ClothedMajority` native; tie → undressed), so an all-dressed animation set (hug, kiss) no longer strips then re-dresses at the first stage
- Stop auto-rebuilding AnimDB on load. If counts differ from SexLab after SexLab is ready, notify `SkyrimNet SexLab # animations doesn't match` and show a SkyMessage (empty → Build/Close; mismatch → Rebuild/Close)

### SKSE / WebUI
- TargetMenu scene-start panel: every field is now a **pulldown_cascade** — shows the current value and opens cascade columns (hover drill, like the TargetMenu) to change it. The **method** row is a direction → method tree that reads `random`: picking a method starts the scene and closes the WebUI; `random` (or Start) has AnimDB pick 3 related animations (one random plus the two sharing the most tags) for the cast and scene setting
- SKSE build: SkyrimNet `PublicAPI.h` include path is now `mods/SkyrimNet devkit/CppAPI`
- Description Editor: new **style** pulldown left of Save (live scenes only). Changing it sets the scene's style (and animation speed) and sends one "changes from 'x' to 'y'" DirectNarration
- Scene Creator layout: title is now "Scene Creator" with the style pulldown beside Start / Cancel; the range pulldown moved under the actor table; the activity field and the scene-setting preset pulldown / Save dialogs are removed. New **Save** next to "override animation settings" writes the actor table's dressed / O / modifiers to the selected animation (`onAnimRegistrySave`, stage descriptions untouched); disabled unless override is on and exactly one animation with a matching position count is selected
- Scene Creator: the animation list starts with one animation selected; click selects just that row (click again to deselect), Ctrl+click adds rows. Each added animation reorders actors to match its position genders when possible and sets the dressed / O / modifiers columns from its defaults
- Description Editor lists the scene that just ended (`… (ended)`) in the scene pulldown and selects it by default when no scene is active, so its animation is the current animation and editable after the scene stops
- Menu hotkey mid-scene with the crosshair on a non-participant (e.g. a DOM mistress) now focuses the player, so the Description Editor opens instead of staying on TargetMenu
- Menu hotkey always toggles ControlPanel: hide immediately when the overlay is visible (any focus actor); open TargetMenu only when hidden
- Ship `PrismaUI/views/SkyrimNet_SexLab/index.html` in the FOMOD zip (`make release` copies `PrismaUI/` into `core`)
- Do not Show/Focus the overlay until DomReady; Escape Unfocus/Hide if the view never loaded (missing HTML no longer pauses the game with a blank overlay)

- Description Editor: with an active scene picked, ◀ previous / next ▶ move the live scene stage and `copy previous` copies the prior stage text; names are buttons that insert `{{sl.actors.N}}` into the active stage; tags on their own right-aligned row; Save now closes the WebUI
- Description Editor: the **scene:** pulldown now defaults to an active scene (last-edited animation's scene, then the target's, then the first); with no active scene it defaults to **Any** with the last-edited animation focused, else **None** (was **Any**)
- Description Editor: stays on "loading..." until the scene seed lands (10 s safety fallback), then shows the final pick directly (no **None** → **Any** → scene flicker); if the seed already landed it binds immediately
- Description Editor: stage nav and tags sit in a bottom-aligned panel left of the actor table (tags above the nav buttons); the names row is gone and actor-table names are buttons that insert `{{sl.actors.N}}`; hint line below both panels; new play/pause button between previous and next toggles the game pause (`onGamePauseSet` → PrismaUI `Unfocus` + `Focus(view, pauseGame)`; resets to paused on Show/Hide), hint moved under the actor table; every action button autosaves dirty descriptions to disk without closing; new **continue scene** button sends DirectNarration "The scene changes to …" with the active stage's description (`onSceneNarrate`)
- Description Editor: the SexLab thread is the source of truth for the stage. ◀/▶ send a relative `_stage_step` (resolved on `thread.stage`); right after `GoToStage` (which sets `thread.stage` synchronously) Papyrus pushes `thread.stage` to the editor, and `StageStart` (also when the game advances on its own) first pushes `thread.stage` as a light `_stage_only` update that moves the active row/nav without reloading stage text; commits dropped while the thread is Advancing, or that change nothing, resync the editor; `BuildWebUISceneMenuState` traces `stage:N/M`
- Description Editor: fixed ◀/▶ while the game is paused stranding the SexLab thread in `Advancing` (later clicks then showed a "dropped (thread not active)" notification). A step now auto-unpauses and re-pauses at `StageStart`; the nav stays greyed until the thread reaches `StageStart` (`_stage_started`); dropped commits are logged only, no on-screen notification
- Description Editor: opening on an active scene no longer rebuilds the scene state up to three times. Stage rows come from one `AnimDb_GetStagesJson` native call instead of 2+ natives per stage (with an O(stages²) backward walk), `AnimationDB::GetStageDescription` / `GetTransition` no longer copy the whole `AnimRow`, and the hotkey open no longer dispatches `WebUI_ConfigureFocusScene` (the overlay-Show seed already carries the scene)
- Description Editor: new per-actor table under **scene:** (`#`, name, `O`, speaking modifiers) edits the animation's `orgasm_expected` / `speaking_modifiers`; Save writes them only when edited (`WebUI_OnAnimRegistrySave` now persists `speaking_modifiers`), scene picks load the row via new `onAnimDbQuery` `_type:"anim"`; the **names:** row now sits directly above the stage table
### Orgasm / narration
- `Scene.OrgasmCustom` drops a DOM melt when the actor's `no_orgasm` is 1 (`orgasm_expected` 0): no stash, no `total_orgasm` bump, no `" is orgasming."`. DOM rolls its own orgasm and ignores SexLab `DisableOrgasm`
### Actions
- LLM outfit actions remain `outfit_dress` / `outfit_undress` (`Outfit_Dress` / `Outfit_Undress`) as Beta 25 files `outfit_dress.yaml` / `outfit_undress.yaml` in `external/goodprovider.sexlab/actions/`; not combined `change_outfit`
- Dual-ship LLM actions and prompts: canonical `external/goodprovider.sexlab/` plus pre-0.25 copies at `config/actions/` and `prompts/` (`tools/sync_legacy_skyrimnet_content.py`)

## [0.34.1](https://github.com/GoodProvider/SkyrimNet_SexLab/releases/tag/0.34.1) — since [0.34.0](https://github.com/GoodProvider/SkyrimNet_SexLab/releases/tag/0.34.0)

### Orgasm / narration
- Combined + Dom last-stage: stash into `orgasm_messages` and `ArmOrgasmWindow` (`sexlab.orgasm.delay`, default 5s, cap **2×** from `orgasm_window_started_at`) so player and slave climaxes share one DirectNarration. StageStart does not consume the stash while the window is open. Contract: [docs/reference/orgasm-narration.md](docs/reference/orgasm-narration.md)
- Position JMap `orgasm_narrated`: Combined fallback only if `GetTotalOrgasms > orgasm_narrated`; already-spoken totals get `" is not orgasming right now."`
- `DOMSlave_Orgasmed` skips player-orgasm teases (`squirms under your grasp` / `your orgasm submerges you`)
- Melt with no scene: Handler delays 1s then retries `OrgasmCustom`; DirectNarrates only if still unreachable. `FlushOrgasmWindow` calls `AlignActors()` first; `AnimationStart` flushes a pending stash before clear
- `0050_sexlab_activity.prompt` / `0550_sexlab_narration.prompt`: skip a thread unless an actor is in `SexLabAnimatingFaction`, `OStimActorCountFaction`, or `DOMActionMasturbating`

### Papyrus
- `EnsureSexLabActorsValid` before Yes/Edit Tags and before `NewThread`: `IsForbidden` → `AllowActor`, then `ValidateActor`; abort with name+code if still `< 0`. `AddActor` failure logs `ValidateActor` again (sticky `ForbiddenFaction` -11 after tag UI)
- `CreateCreator` `TryClaim()` marks the pool slot `SETUP` before latent `Setup` / `Game.GetPlayer()` so two overlapping `Action_Start` events cannot share sid:0; `StartScene` aborts before `NewThread` when `num_actors < 1`. `LockActorLock` sets StorageUtil immediately (`"already locked"` vs `"locked"`)
- DOM solo `masturbate` is a synthetic thread via `handler_dom.GetThreads()` in `GetThreadsJson`; `OnBehaviourChange` (`DOMOnBehaviourChange`) dumps `threads.json` on masturbate start/stop
- `OrgasmCustom` / `GetSceneByActor`: `GetThreadByActor(any_state)` + `thread_scene` fallback when animating/prepare miss
- `GetIntentMessage`: empty `intent` no longer emits `"Nina and Bob finish ."`
- `ObjectToLowerCaseKeyJson` walks JMap/JArray/JFormMap/JIntMap (`JValueToJsonString`); do not call `JValue.toJsonString` (JC 4.2.13.1+)
- `MCM.ApplyPluginConfig` `SetValue`s `skyrimnet_sexlab_ostim_player` from `sexlab.ostim.player` so eligibility can read the global
- `Menu.ProcessHotkey` calls `GetThreadByActor(target, true)`; `Stages.EditDescriptions` / `SetOrgasmExpected` call `GetSceneByThread(thread, false, true)` after those callees gained extra args

### Actions / scenes
- `SEXLAB_STOP.yaml`: `comparisonOperator` values quoted (`">"` / `"<"`)
- Category parents `ShowComfort`, `ExpressPhysicallyNonsexually`, `Sexlab_Punish`, `SexLab_Sexual_Activities_One`/`Two`/`Three`: eligibility uses native `get_global_value` / `skyrimnet_sexlab_ostim_player` (Papyrus `sexlab_ostim_player` cache-misses and hid the tree)

### Install / MCM
- Plugin `manifest.json` / settings `plugin.version` **0.34.1**. Dashboard **Orgasm delay** (`sexlab.orgasm.delay`) waits after the last orgasm (player or Dom slave) before one combined Direct Narration

### Docs
- Orgasm window / `orgasm_narrated` / tease skip / delayed melt: [docs/reference/orgasm-narration.md](docs/reference/orgasm-narration.md)
- Live-thread faction skip: [docs/authors/prompts.md](docs/authors/prompts.md)
- Eligibility / caller arity: [docs/authors/actions.md](docs/authors/actions.md), [docs/reference/papyrus-rules.md](docs/reference/papyrus-rules.md)
- KNOWLEDGEBASE: Combined window, DOM masturbation synthetic thread, MO2 installed-release vs workspace, overlapping `Action_Start` empty `StartThread`, `AddActor` ForbiddenFaction -11 after Edit Tags, Papyrus eligibility cache-miss, `GetThreadByActor` arity

## [0.34.0](https://github.com/GoodProvider/SkyrimNet_SexLab/releases/tag/0.34.0) — since [0.31.5](https://github.com/GoodProvider/SkyrimNet_SexLab/releases/tag/0.31.5)

### Actions / scenes
- Ship LLM actions and prompts as SkyrimNet Beta 25 external plugin `goodprovider.sexlab` (`SKSE/Plugins/SkyrimNet/external/goodprovider.sexlab/`). Plugin `manifest.json`: `id` goodprovider.sexlab, `type` bundle, `version` 0.34.0, `min_skyrimnet_version` 0.25.0; `mods` requires `SkyrimNet_SexLab.esp`. Action YAML filenames now equal in-file `name` (e.g. `SexLab_Start_Giving.yaml`); `name` values unchanged
- `change_outfit.yaml` / `SEXLAB_STOP.yaml`: `render_template` paths `helpers/sexlab/none_change_outfit` and `helpers/sexlab/none_stop` (helpers moved off `helpers/sexlab_*`)
- Removed unused helpers `action_rape_target_start`, `action_raped_by_target_start`, `default_sex_life`

### Orgasm / narration
- Afterglow / cum clauses via `RenderSlPrompt` (`helpers/sexlab/afterglow.prompt`, `cum.prompt`); empty, `Error*`, inja exception, or leftover `{{` falls back to the previous Papyrus sentence. Bind `{{sl.*}}` only (`{{sl.name}}` is a string)
- Combined flush (`OrgasmMessagesToNarration`) and `OrgasmIndividual` name every non-orgasming actor with `" is not orgasming right now."` — must not match the `" is orgasming."` gate. Contract: [docs/reference/orgasm-narration.md](docs/reference/orgasm-narration.md)
- `afterglow.prompt`: totals under 1 and `expected == 1` → “failed to orgasm”; else “finished having orgasmed N times”

### Papyrus
- `SelectAnimations` / `SelectAnimationsDialog`: `num_tags == 0 && num_tags_suppress == 0` skips `GetAnimationsByTags` and returns `manager.empty` (SexLab picks internally)
- `PickOneAnimation`: on P+, a tagged match list longer than one is capped to one random animation
- `Scene.StageStart`: P+ `DURATION_CAP_SECONDS` 120s real-time → `thread.EndAnimation()` (enjoyment-wait cannot loop a single SLSB graph). Do not use `UpdateTimer` as an end mechanism on P+
- `MCM`: options moved to SkyrimNet plugin settings; MCM is a pointer page. `ApplyPluginConfig` reads `Plugin_SkyrimNet_SexLab`. Listens for `SkyrimNet_OnPluginConfigSaved` so a dashboard save re-registers the Start Sex hotkey without MCM open or reload. `ApplyHotkey` logs enabled/vk/dx; leftover saved `43` (old DX backslash) maps to VK `220`. `leashed_found` from `GetFormFromFile(0x800, "SkyrimNet_Leashed.esp")`; `EventSend_LeashedOpen` hides WebUI then `SkyrimNet_Leashed_OpenPanel`
- `Decorators.Ostim_Player`: reads `sexlab.ostim.player` (YAML/WebUI eligibility `decoratorName: sexlab_ostim_player`)
- `Menu.Target_Menu_Selection`: cancel/negative button returns immediately; `bondage` / `leash` run only when their index is not `-1`. SexLab/Ostim toggle uses `GetConfigInt` / `PatchConfig` `sexlab.ostim.player` (no `sexlab_ostim_player` global)

### SKSE / WebUI
- `target_options.json`: `type: handoff` option `leash` (`requiresPlugin: SkyrimNet_Leashed.esp`, `modEvent: SkyrimNet_Leashed_OpenPanel`)
- `WebUI.cpp` / `Papyrus_WebUI.cpp`: handoff hides this overlay and `DispatchMethodCall` `EventSend_LeashedOpen`; DLL rebuilt

### Animations
- P+ playing set: empty tags skip lookup; tagged hits capped to one via `PickOneAnimation` (avoids `FindSimilarSceneStage` hopping). Details: [docs/developers/papyrus.md](docs/developers/papyrus.md)

### Install / MCM
- Requires SkyrimNet **0.25.0+**. Plugin should appear under Installed Plugins with an **External** badge. Settings schema stays at [`config/plugins/SkyrimNet_SexLab/manifest.yaml`](SKSE/Plugins/SkyrimNet/config/plugins/SkyrimNet_SexLab/manifest.yaml) (`schema.fields` + `defaultValue`, `plugin.version` 0.34.0, 12 `sexlab.*` keys). Dashboard hid SexLab when the old list/`default` shape loaded as 0 fields. Start Sex hotkey is `type: hotkey` default **backslash** (`\`, VK 220). Change options in the SkyrimNet dashboard, not the MCM.
- SkyMessage target menu **leash** button when `SkyrimNet_Leashed.esp` is loaded (does not require Leashed’s own hotkey)

### Docs
- KNOWLEDGEBASE: P+ scene hop vs end (`AdvanceFromTimer` / `GetPlayingScenes`); Beta 25 `goodprovider.sexlab` layout; settings schema at `config/plugins/SkyrimNet_SexLab/` only
- `helpers/sexlab/` prompt paths; orgasm denied clause; leash on [docs/players/hotkeys.md](docs/players/hotkeys.md)
- Author/player/dev paths point at `external/goodprovider.sexlab/`

## [0.31.5](https://github.com/GoodProvider/SkyrimNet_SexLab/releases/tag/0.31.5) — since [0.31.4](https://github.com/GoodProvider/SkyrimNet_SexLab/releases/tag/0.31.4)

### Papyrus / scenes
- `PickNonVictimInitiator()` in `Scene.Setup`: if `num_victims > 0`, initiator is never a victim (keep current if non-victim; else positions 1…n then 0). First-stage `"X initiates: …"` only
- `GetSceneInactive`: `SetThread` before publishing `thread_scene[tid]`
- `GetSceneByThread`: `thread_scene[tid]` is authoritative during Setup (no `IsActive()` requirement); rebind when `GetThread()` is None or tid matches; Release only on tid mismatch
- `EnsureSceneForThread` from `AnimationStart` / `StageStart` (DOM / external SexLab threads)
- `thread == None` guards in `AnimationStart`, `GetDescription`, `GetThreadObj`

### Prompts
- `0050_sexlab_activity.prompt` (v0.31.5+): `_pain_` / `_pleasure_` vocalizations are “one to two” (dropped every-N-words); distracted cap 9 words (was 8); narration-enabled cap 20 words (was 12) and “Narration should move the action forward”; dropped consecutive-vocalization ban

### SKSE / WebUI
- `Papyrus_WebUI.cpp`: SkyrimNet PublicAPI via `extern` function pointers instead of `#include "PublicAPI.h"`; DLL rebuilt

## [0.31.4](https://github.com/GoodProvider/SkyrimNet_SexLab/releases/tag/0.31.4) — since [0.31.3](https://github.com/GoodProvider/SkyrimNet_SexLab/releases/tag/0.31.3)

### Actions / scenes
- Ship `scenes/no_penis.json` (`tags_suppress`: vaginal, anal) for giving actions that already pass `setting_name: no_penis`

### SKSE / SkyrimNet
- Add plugin manifest `SKSE/Plugins/SkyrimNet/config/plugins/SkyrimNet_SexLab/manifest.yaml` with `sexlab.orgasm.delay` (orgasm delay seconds)

### Docs
- Migrate author/developer docs to `docs/` (players, authors, developers, reference); add `llms.txt` agent router; rewrite `release-guide.xml` / `documentation-guide.xml`; shorten `README.md`
- Root `guides/` removed in favor of `docs/`
