# WebUI (SKSE + PrismaUI)

In-game overlay: C++ SKSE plugin, PrismaUI HTML, target/sex menu config.

Quirks: [../../KNOWLEDGEBASE.md](../../KNOWLEDGEBASE.md) (PrismaUI view path, action catalog).

## Paths

| Path | Role |
|------|------|
| `SKSE_Source/` | C++ → `SkyrimNet_SexLab.dll` |
| `SKSE/Plugins/SkyrimNet_SexLab.dll` | Built plugin |
| `PrismaUI/views/SkyrimNet_SexLab/index.html` | Overlay HTML under `Data/PrismaUI/views/` |
| `SKSE/Plugins/SkyrimNet_SexLab/webui/` | `actions_index.json`, `TargetMenu/Actor/`, `TargetMenu/Scene/`, `MainPanels/`, `ControlPanel/` (drop-in mode JSON only; third-party catalogs stay under their own `catalogRoot`) |
| `SKSE/Plugins/SkyrimNet_SexLab/webui/TargetMenu/Actor/options/0600_sexlab_bondage.json` | Bondage TargetMenu option (live catalog; `make release` moves it into FOMOD `handler_udng/`) |
| `SKSE/Plugins/SkyrimNet_SexLab/webui/TargetMenu/Actor/options/0700_sexlab_leash.json` | Leash TargetMenu option (`panel: leash`; catalog omitted unless `SkyrimNet_Leash.esp` is loaded) |
| `SKSE/Plugins/SkyrimNet_SexLab/bondage/group-devices.json` | BondagePanel file-first catalog (live; API `GetDatabase` overlays when ready; same release split) |
| `SKSE/Plugins/SkyrimNet/config/plugins/SkyrimNet_SexLab/manifest.yaml` | SkyrimNet plugin settings schema (control store) |
| `Scripts/Source/SkyrimNet_SexLab_WebUI.psc` | Target/Sex/YesNo/SceneCreator/Animation natives + `SceneConnections_Show` + `SceneInfos_Seed` |

## Layout

```
| ControlPanel (10% top/left) | Main panel (10% top/bottom/right) |
| TargetMenu (same width)     |                                     |
```

- **ControlPanel** (`#control-panel`): row 1 **mode** pulldown (`#control-mode-pulldown`, same widget as views/target; built-in `SkyrimNet SexLab` plus `webui/ControlPanel/*.json`); then **views** label (75% of `--text-base`) above an indented `main_panel` pulldown (from the **active mode** `MainPanels/`, with JS builtin fallback in SexLab mode); OStimNet-gated **framework** pulldown (`#framework-row`, `sexlab`/`ostim`, no label, hidden unless OStimNet or the mode sets `hideFramework`); then **target** label (same 75% size) above an indented **actor focus** pulldown (`#control-actor-pulldown`, nearby actors plus mode **sentinels**). Main-panel list includes **None** (clears the right main-panel host). Pulldowns stay **vertically aligned with the trigger**; only the left offset uses `--space-md` from the ControlPanel box (same gap as TargetPanel → Parameter Panel). Menus stack above TargetPanel and the main panel and use an opaque background.
- **Actor focus pulldown:** nearby actors (player pinned first), sorted sexlab → eligible → ineligible, then distance. Labels: name cropped to 10 chars; `(sexlab)` selectable; no suffix = eligible; `(reason)` greyed (`child`/`cmbt`/`ostim`/`dead`/`load`, ≤5 chars). Selection sets `Target_Current` and switches the selected **SceneInfo** to that actor’s thread if any, else the Scene Creator (`new`) SceneInfo. Default: crosshair if present, else nearest selectable non-player, else player.
- **Always paused while open:** `Focus(view, true)` on Show. There is no pause/unpause toggle (it would let SexLab threads drift from SceneInfo drafts). Log tailing is file I/O and still works. AnimDB rebuild that needs `RegisterForSingleUpdate` waits until the overlay closes.
- **TargetMenu:** stacked under ControlPanel in the left column (no actor name header — focus is the ControlPanel pulldown).
- **Main panel host:** one visible panel at a time, selected by the pulldown (builtin Scene Menu / Animation / Log / Settings). Scene Menu (`#scene-creator-panel`) fills the host; **Animations list is a fixed 50%** of the panel (scroll inside `#sc-anims-list`). Positions + Filter share the remaining height and scroll internally. Filter’s available-tags region (`#sc-available-tags`) is **2×** the selected tags+suppress rows; those chip lists scroll internally.
- Sex Menu / YesNo remain overlay panels outside the main_panel pulldown.

### SceneInfo (shared scene draft)

JS `SceneInfo` map: one instance per active SexLab scene (`scene:<sid>`) plus one `'new'` Scene Creator draft. Seeded from Papyrus `BuildAllSceneInfosJson` on overlay Show (`SceneInfos_Seed`). Actor focus selects the thread that contains that actor, or `'new'`. Switching actors does not wipe `'new'`.

Panels copy the selected SceneInfo into a local draft on open. **Start / Done / Update / Stop / silent / explain** write the draft into SceneInfo. **Cancel** (and leaving a panel without confirming) does not. Overlay **Cancel / Escape** hide **without** committing — dirty SceneInfos are dropped. Non-Cancel hide (hotkey, Scene Menu Start, TargetMenu action Start) flushes dirty SceneInfos (`WebUI_OnSceneInfoCommit`) then Unfocus so `StartThread` can run.

### Scene Menu + Description Editor connection

- Focus actor owns the selected SceneInfo (or `"new"` creator state) for Scene Menu. Description Editor has its own **scene:** pulldown (None, Any, + active scenes). Filter and Animations panels show only for **Any**; **None** and a scene pick hide them. The editor stores `DE.currentAnimation` (last selected / scene-bound registry); on open the pulldown defaults to an active scene playing it (else Any). When the focused animation is playing in an active scene, its current stage row gets a lighter background (`de-stage-active`).
- Opening Scene Menu / Description Editor binds the panel to the selected SceneInfo (`mainPanelDidOpen`). Do not re-fetch Papyrus snapshots on actor change (that wiped drafts).
- **Scene Menu** (`scene_creator_panel`): multi-select anim pool. **Positions** always lists nearby SexLab-eligible actors (`selectable`, status `ok` or `sexlab`) as unselected grey rows even when they are not in the current scene; click name/`#` to add (SexLab cap 5) or remove. Ineligible nearby (`child`/`cmbt`/`ostim`/`dead`/`load`) stay off that table. They are not auto-joined. On `new`: Start (apply + `pendingCreate` + commit-hide) / Cancel (no SceneInfo write). On active scene: Stop (`pendingStop`), A/N column, Update (writes anim pool into SceneInfo; SexLab in-thread cap 128 applied on commit), stage prev/next stay in the draft until Update/Stop. Header **setting** pulldown is `none` plus C++-loaded `scenes/*.json`; every open resets to `none`. Picking a file applies `default` then that file onto SceneInfo without changing actors; `none` does not revert. **Save** uses overlay confirm / name+list / overwrite dialogs (not `window.confirm`); Papyrus writes the JSON even when there is no live creator.
- **Filter-by downgrade:** each Scene Creator / Scene Menu open arms `gender → none` (`scArmFilterDowngrade`; default `gender`). A query returning zero anims steps to the next looser mode and re-queries, so the pulldown shows the mode actually used. Re-armed once actor meta resolves. **Do not query gender/positions mode while any position `_gender` is unknown** (`null`, not `0` — `0` is male). Nearby/player JSON includes `gender` from C++ `GetSex` for first paint; Papyrus `GetGender` overwrites via `actorAnimMetaResult` (creatures 2/3). Picking a mode manually pins it for that open (`positions` remains a pulldown option). Callers wanting a different start set `SC.filterByOnce` before `configureSceneCreator` (SceneStartPanel **Custom** uses `none` for nonsexual/affection methods, which leaves no fallbacks; other Custom uses `gender`). Shared Filter row (Scene Menu + Description Editor): `filter by gender:` + mode pulldown (`gender` / `none` / `positions`), then `description:` + `any` / `described` / `undescribed`; changing either pulldown re-queries anims and tags (`_has_description` when not `any`). `described` / `undescribed` use `_stage_has_description` or non-empty `_stage_descriptions`; JS also applies the same filter client-side on query results (including `_also_registries` merges). Gender filter downgrade does not run while a description filter other than `any` is active.
- **Description Editor** (`description_editor_panel`): top **scene:** pulldown — **None** or one entry per active thread (`Nina, Bob: animation name`). Default: focus actor's scene if they are in one, else first active scene, else **None**. **Active scene** selected → current thread animation, Filter + Animations hidden; Description section header is **`Description: {anim name}`**; names row stays visible as bold **names:** `Nina, Bob` on the left and bold **tags:** plus read-only anim tag chips right-aligned (no separate Tags section). Names come from that scene's seeded `_positions` (`thread.Positions`, with `position_objs` name fallback). **None** → header **Description**; Filter + Animations visible (shared filter state with Scene Menu). Names in **None**: valid ControlPanel target → slot 0 Target, slot 1 Player, gaps Alice–Pat; **no target** → Alice–Pat only (player not used). Live thread refresh: `WebUI_ConfigureFocusScene` before DE hotkey restore; `WebUI_ConfigureIfOverlayVisible` on AnimationStart/StageStart when overlay open; `seedSceneInfos` merges `_positions` / `_in_thread_registries` / `_active_registry` into existing scene keys. On open in **None**, arms filter downgrade (`scArmFilterDowngrade`); creator/`new` seeds nearby positions. Anim queries may pass `_also_registries`. Animations section is **50%** when visible. Per-stage table: editable **text** (`{{sl.actors.N}}`) + read-only **description** preview (`AnimationDB::SubstituteActors`). **Save** → `onAnimRegistrySave` → `AnimDb_SaveAnimLocal`. **Cancel** discards unsaved stage edits.
- **Description Editor hotkey:** when ControlPanel focus is in SexLab (`WebUI_MaybeRestoreAnimationPanel` after hotkey / actor focus), C++ always selects Description Editor — not gated on last main-panel choice. Out-of-scene hotkey still opens TargetMenu only.
- **Hotkey toggle:** if the overlay is visible, the menu hotkey hides it immediately (any ControlPanel focus actor) and does **not** dispatch `ProcessHotkey`. Hidden → `Menu.ProcessHotkey` → `Target_Menu_Open` (rebuild if same actor, else full open). Close does not clear `Target_Current`. Show/Focus only after DomReady; missing overlay HTML does not pause the game. Escape uses JS `handleGlobalEscape` when ready; C++ Unfocus/Hide if DomReady never fired.
- **Input swallow while open:** C++ `KeyHandler` is prepended to `BSInputDeviceManager` on register and on every Show. While the overlay is visible, `ProcessEvent` runs this plugin’s Escape/menu callbacks, then **unlinks** keyboard `kButton` and `kChar` events from the SKSE input list so SexLab and other SKSE/Papyrus `RegisterForKey` handlers do not fire (description editor typing). It always returns `kContinue` so mouse-move and mouse clicks still propagate (PrismaUI cursor + field focus). PrismaUI text fields receive typed characters via Win32. Overlay hidden → no unlinking; `kContinue` so the menu hotkey can open the UI.
- **Escape z-order:** one layer per keypress, highest first: open `.pulldown` menus → Save SceneSetting overwrite / name / confirm dialogs → IntentPanel (Cancel, no SceneInfo write) → YesNo silent No → Sex menu hide → TargetMenu cascade / Parameter panel (pop one nested pulldown, or close the Parameter/papyrus panel) → selected main panel to ControlPanel **None** (does **not** run Scene Creator **Cancel** while TargetMenu is open). When only TargetMenu and/or ControlPanel remain, Escape hides the overlay without committing SceneInfo (`onCancel`). Scene Creator without TargetMenu (YesNo flow) still **Cancel**. Root **Custom** closes an open Parameter/cascade panel before toggling Scene Creator.

## Lifecycle

- `kDataLoaded`: PrismaUI API, `CreateView("SkyrimNet_SexLab/index.html")`, JS listeners.
- `kPostLoadGame` / `kNewGame`: `WebUI_SetGameReady()` (enables input; reloads ActionCatalog from `webui/`; `configureControlPanel`).
- DomReady / game-ready: `configureControlPanel(BuildMainPanelsCatalog())` (includes `sceneSettings` from `scenes/*.json` so Scene Menu’s setting pulldown is populated without opening TargetMenu).
- Pulldown → JS `onMainPanelChange` → C++ `SwitchMainPanel` (close previous, open next). On key change to Scene Menu / Description Editor, C++ invokes `mainPanelDidOpen()` → bind the selected SceneInfo into that panel’s local draft (no Papyrus `WebUI_OnSceneConnectionChange`). Scene Menu **Update** writes into SceneInfo; SexLab anim-list apply happens on overlay commit. Full `SceneCreator_Open` / `Animation_Menu_Show` remain for YesNo / Custom / hotkey.
- Papyrus → C++ open; C++ → JS `showPanel` for `target_menu_panel` / `sex_menu_panel` / `scene_creator_panel` / `description_editor_panel` (SC/DE auto-select the matching main_panel entry; idempotent if already selected).
- Catalog: `TargetMenu/Actor` or `TargetMenu/Scene` (from ControlPanel SexLabAnimatingFaction) + `actions_index.json` + `MainPanels/`; **Start** merges params and dispatches; action-panel **Custom** writes the panel draft plus scene setting into creator SceneInfo `new` and shows Scene Creator.

### TargetMenu UX

- Root `#target-panel` holds globals + root options + Cancel only (no `#target-name`). Each opened `pulldown` is its own sibling panel (nav stack); Parameters is a separate confirm panel with **Start** / **Custom**. The cascade row sits in the left column under ControlPanel; Scene Creator opens in the right main-panel host.
- Mid-scene **Scene** catalog (focus in SexLabAnimatingFaction): **stop** (speaker pulldown + silent/stop/explain → SceneInfo `pendingStop`), **stage** (index + editable description; **Done** writes SceneInfo), **position** (Scene Creator-style whole-cast table; **Done** writes SceneInfo), **animation** (opens Description Editor in the main host), **save to json**.
- Nested Parameters / papyrus cascade panels put confirm buttons as the first row (Cuddle: Custom/Start then pulldowns) and show label+pulldown on one aligned row. Root TargetMenu Cancel stays at the bottom of `#target-panel`.
- Click a scene-start action while Scene Creator is closed → select it and open the Parameters panel (does not start). While Scene Creator is open, the same click reapplies that row's `panelDefaults` (plus scene setting JSON) onto creator SceneInfo `new` and reconfigures Scene Creator — it does not open the Parameters panel.
- Root **Custom** (`type: scene_creator`) toggles Scene Creator bound to creator SceneInfo `new` (hide = ControlPanel **None**; does not discard the draft). If a Parameter/cascade panel is open, Custom closes it first, then toggles. Action-panel **Custom** snapshots the current panel, applies **`default` then** `catalog.sceneSettings[setting]` (C++-loaded `scenes/{setting}.json`; PrismaUI cannot fetch `../../../SKSE/...`), writes `speaking_modifiers` per position as `_speaking` CSV (array default then per-index overlay; empty string clears), writes into SceneInfo `new`, closes the cascade, and shows Scene Creator with the setting pulldown on **`none`**. Rapes / raped-by rows use `settingName: punish_pleasure_pain_rape`.
- **Start** snapshot params, then **close all pulldown + Parameters panels**, then fire `onAction`.
- **Start** → `onAction({action:"start",…})` → `ExecuteAction`, then **closes WebUI** (clear TargetMenu session + hide overlay, same as Cancel) so SexLab `StartThread` runs unpaused. For scene-start actions, C++ sets `SkipSceneCreatorOnce`; Papyrus `Action_Start` consumes it via `ConsumeSkipSceneCreator()` and sets `scene_creator_menu_called` so that scene skips Scene Creator **and** YesNo (treated as Yes/Random). SceneStartPanel **Start** (`action:"papyrus"` + `closeWebUI` + `StartScene_*`) sets the same flag; Custom / live papyrus rows do not. Scene Creator **Start** (including after TargetMenu Custom) also clears the TargetMenu session and hides the overlay; Cancel from Scene Creator still keeps TargetMenu open.
- Action-panel **Custom** (scene-start) loads **`default` then** the panel `settingName` JSON onto creator SceneInfo `new` (`_from_target_menu`), then shows Scene Creator with the setting pulldown on **`none`**. TargetMenu root stays open. Clicking another scene-start row while Scene Creator is visible reapplies that row's `panelDefaults` (including the setting overlay) instead of opening its panel.
- Cancel clears the TargetMenu session. `WebUI_HideAllPanels` spares TargetMenu while that session is active.

### `TargetMenu/`

C++ loads **both** trees at `Load()` and `BuildUICatalog` picks one from ControlPanel focus `SexLabAnimatingFaction`:

| Path | Role |
|------|------|
| `TargetMenu/Actor/defaults.json` | `{ "defaultsParameters": { ... } }` (legacy root key `defaults` still accepted) |
| `TargetMenu/Actor/options/*.json` | Start-scene + outfit (not animating) |
| `TargetMenu/Scene/options/*.json` | Live-scene group editors (animating) |

**Order = lexicographic filename** (numeric prefixes). Keys are lowercase. Every option node has `type`:

| type | Fields | Role |
|------|--------|------|
| `parameter` | `name`, `default`, `values` | Global param pulldown |
| `action` | `name`, `label`, optional `parameters`, optional `disabled`, optional dispatch fields | Selects action + Parameters panel; confirm with Start/Custom; `disabled` = greyed non-clickable |
| `scene_creator` | `label` | Actor-root toggle: open/close Scene Creator on creator SceneInfo `new` (no Papyrus). Highlighted while Scene Creator is the selected main panel. |
| `papyrus` | `label` (no `name`), `plugin`, `questFormId`, `scriptName`, `executionFunctionName`, `parameterMapping`, optional `eligibilityRules`, optional `closeWebUI` / `confirmSave` / `explainPrompt` / `panel`, optional `panelDefaults` | TargetMenu-only Papyrus call via `onAction({action:"papyrus",...})` — no YAML / `actions_index`. Actor **`panel: scene_start`** is the shared sentence UI. Actor **`panel: outfit`**: sentence `position_1` / style (`forcefully|normally|gently|silently`) / undresses|dresses / `position_0`; **Start** only (no Custom); `TM_Outfit`; style `silently` skips SkyrimNet narration. Actor **`panel: bondage`**: speaker / style / `changes devices on` / target; per-group 75% body-area label above a 1em-indented pulldown (menus open **below** the widget); pulldowns edit JS `ActorBondage.current` only (no live apply); **Cancel** / hide discard the session; **Start** applies `currentJson` (`TM_BondageFinish`) then narrates unless `silently` and `WebUI_CloseOverlay`; no Custom. **BondagePanel requires Devious Devices NG**; core SkyrimNet_SexLab does not. Catalog: `requiresPlugin: Devious Devices - Assets.esm` + `requiresDll: DeviousDevices.dll`. Actor **`panel: leash`**: Subject / Leashed / style / action pulldown (`tie to`\|`give to`, plus `unleash` when already leashed); action-row control is location or holder; **Start** only; `requiresPlugin: SkyrimNet_Leash.esp`; dispatches `SkyrimNet_Leash_Actions` (no YAML). Scene panels: **`stop`** (speaker pulldown + silent/stop/explain → SceneInfo `pendingStop`), **`stage`** / **`position`** (edit draft; **Done** writes SceneInfo), **`animation`** (opens Description Editor). Apply to SexLab on overlay commit. `panelDefaults` seeds SceneStartPanel (Subject, `andThird` none/and, Object `with`/`to victim`/`none`, intent, direction, method, style, setting). Intent **custom** opens IntentPanel (text, Cancel, Ok). Hug/cuddle/kiss giver is SexLab pos1 when intent is `show affection` / `comfort` (or the long Papyrus labels) or method is `cuddling|kissing|hug`. When Scene Creator is already open, clicking a `scene_start` / `cuddle` row applies `panelDefaults` to SceneInfo `new` instead of opening this panel. |

| `pulldown` | `label`, `options[]`, optional `parameters`, optional `eligibilityRules` | Group; children are `action` and/or nested `pulldown`. Optional `eligibilityRules` evaluated at catalog build against `currentActor`; fail **or** zero remaining children → option omitted |
| `actionSwitch` | `label`, `options[]` of `action` + `eligibilityRules` | C++ picks first eligible child (or disabled fallback label) |

Optional on any option node: `requiresPlugin` (ESP/ESL name) — omitted from the catalog when that mod is not loaded. Optional `requiresDll` (e.g. `DeviousDevices.dll`) — omitted when `GetModuleHandle` does not find that SKSE plugin.

Optional `source` (string) on TargetMenu option roots and MainPanel entries: omit or `"sexlab"` is native (no decoration). Any other value (e.g. `"dom"`) paints a 50% badge in the upper left above TargetMenu option labels, and a leading superscript on the ControlPanel views pulldown. Nested cascade children inherit the parent pulldown’s `source` when they have none.

**Filesystem dispatch actions** (optional handlers / third parties): an `action` option may carry `plugin`, `questFormId` (local, e.g. `"0x800"`), `scriptName`, `executionFunctionName`, and `parameterMapping`. C++ synthesizes an `ActionDef` so `ExecuteAction` works without an `actions_index` row. Prefer `plugin` + local FormID over EditorID for optional ESPs.

Actor sources: `playerActor` / `currentActor` (aliases `player` / `target` / `focus` still work).

Outfit: Actor catalog `panel: outfit` (undress/dress via FormListCount eligibility) → `TM_Outfit(speaker, target, style)`. Sentence UI; **Start** closes WebUI (no Custom). Style `silently` skips DirectNarration and RegisterEvent. `Outfit_Dress` / `Outfit_Undress` still call `Target_Menu_Refresh` after storage updates (no-ops when menu is closed). LLM YAML `outfit_dress` / `outfit_undress` is unchanged.

Bondage: Actor catalog `SKSE/Plugins/SkyrimNet_SexLab/webui/TargetMenu/Actor/options/0600_sexlab_bondage.json` (`panel: bondage`, `requiresPlugin: Devious Devices - Assets.esm`, `requiresDll: DeviousDevices.dll`). **BondagePanel requires Devious Devices NG; core SkyrimNet_SexLab does not.** Click opens BondagePanel (speaker / style / target), top-aligned with ControlPanel. Each group is a 75% `--text-base` body-area label above a 1em-indented pulldown (`none` + devices; menus open below the widget). Head-to-foot: Blindfold, Gag, Hood, Collar, Piercing Nipple, Body, Arms, Belt, Piercing Vaginal, Plug Vaginal, Plug Anal, Legs, Boots, Suit — JS draws these `BONDAGE_GROUP_ORDER` rows immediately (`none` until catalog devices arrive). C++ seeds slim `{id,name}` from `group-devices.json` first (`bondageConfigure({...})` object-literal header plus per-group `bondageConfigureDevices({...})`; a 400KB one-shot `Invoke` never ran), then overlays `GetDatabase()` when `LoadAPI` succeeds (`source: api`). Do not `PrismaUI->InteropCall`. JS ignores parse fail and empty headers; ignores empty `ab.groups`; keeps `ActorBondage.current` / `original`. Ack `bondageGot` in the SKSE log. Papyrus `PushBondageState` sends `{target}` only (number or string). Apply still uses the JC file (`plugin:0xhex`). Per-actor **ActorBondage** seeds original+current from worn on first current-actor select; later Refresh must not clobber `current`. Pulldown change writes `current` only (no Papyrus). `bondageConfigure` always rebuilds the device list from `current`. **Cancel** closes the panel only (Map kept until overlay hide). **Start** → `TM_BondageFinish(speaker, target, style, currentJson)` applies `SetGroupToId` per group, narrates unless `silently`, `ReleaseAll`, `WebUI_CloseOverlay` (`closeWebUI: false` so C++ does not Hide first). Hotkey/Escape hide: `bondageReleaseAll()` + `TM_BondageOnWebUIClosed` ReleaseAll only (no device restore). LLM lock/unlock actions stay in SkyrimNet_UDNG. `zadLibs` is Handler-only so the main ESP loads without DD. Repo/MO2 sees the SKSE tree; `make release` moves this JSON and `bondage/group-devices.json` into FOMOD `handler_udng/` with the handler ESP (see KNOWLEDGEBASE **Optional SKSE files / FOMOD split**).

Leash: Actor catalog `SKSE/Plugins/SkyrimNet_SexLab/webui/TargetMenu/Actor/options/0700_sexlab_leash.json` (`panel: leash`, `requiresPlugin: SkyrimNet_Leash.esp`). **Start** only (no Custom). Subject / Leashed / style, then an action pulldown in the label column: `tie to` / `give to`, plus `unleash` when `LeashFramework.IsLeashed` on the Leashed actor. `tie to` shows location (`floor|left|back|front|right|wall`); `give to` shows holder; `unleash` has no extra control. Start calls `SkyrimNet_Leash_Actions` (`LeashedToHolder` / `LeashedToTiePoint` / `GiveLeash` / `TakeLeash` / `Unleash*`) — not YAML. Status via JS `onLeashStatus` → C++ `DispatchStaticCall` (no `LeashFramework.dll` link). Lives in the core SKSE tree (not a FOMOD handler split).

Menu labels for the target panel come from `TargetMenu/Actor` or `TargetMenu/Scene`. Nested pulldowns open as separate panels in a row (`‹` header pops).

Start merge order: YAML statics → `defaultsParameters` → matching action-node `parameters` → UI dictionary (UI wins).

`actions_index.json` is `{ "actions": [...] }` only — no `by_category`.

### `webui/MainPanels/`

One JSON object per file; **order = lexicographic filename**. Optional `requiresPlugin` skips the entry when the mod is missing.

| type | Fields | Role |
|------|--------|------|
| `builtin` | `label`, `panel` | Panel already in PrismaUI (`log_panel`, `settings_panel`, `scene_creator_panel` labeled Scene Menu, `description_editor_panel`) |
| `papyrus` | `label`, `id`, `plugin`, `questFormId`, `scriptName`, `openFunction`, `closeFunction` | Zero-arg Papyrus open/close on that quest script |
| `data_table` | same quest fields as `papyrus`, plus `columns` (`id`/`label`) | Generic table host (`#data-table-panel`). Open still calls `openFunction`; rows arrive via `WebUI_PushMainPanelData`. |
| `actor_detail` | same quest fields as `papyrus` | Generic key/value + control host (`#actor-detail-panel`). Payload `fields` + `controls`. |

Starters in core: `0900_log_panel.json` (Log), `1000_settings.json` (Settings), `0100_scene_creator_panel.json`, `0200_description_editor_panel.json`. Third-party modes ship their own `MainPanels/` under `catalogRoot` (see **ControlPanel modes**).

**Settings panel:** rebuild AnimationDB (then switches main panel to Log with follow-tail), version from `Data/SKSE/Plugins/SkyrimNet_SexLab/info.json` (fallback `Config::kPluginVersion`), docs URL shown as text (`https://github.com/GoodProvider/SkyrimNet_SexLab` — no `ShellExecute`), **Open SkyrimNet dashboard** hides this WebUI then `SkyrimNetApi.TriggerToggleDashboard()` (navigate Plugins → SkyrimNet_SexLab; no deep-link API). Plugin config schema: `SKSE/Plugins/SkyrimNet/config/plugins/SkyrimNet_SexLab/manifest.yaml`. C++ reads via `PublicGetPluginConfigValue("SkyrimNet_SexLab", …)`; Papyrus via `SkyrimNetApi.GetConfig*("Plugin_SkyrimNet_SexLab", …)`.

**AnimationDB / stage descriptions:** rebuild syncs SexLab registry rows and loads authored anidata. Missing stage text is **not** HKX-inferred at runtime (AniDescriber on hold); Papyrus uses earlier authored stages, then SexLab tag fallback. See [anidescriber.md](anidescriber.md).

**Log panel:** reads `SKSE::log::log_directory()` / `SkyrimNet_SexLab.log` (same sink as `webui_log` / Papyrus `TraceLog`). Regex filter in JS; follow-tail unless the user scrolls away. C++ tails by file offset; JS polls `onLogPoll` while visible.

### Optional integrations (FOMOD / third parties)

Drink your own champagne: official optional packages use the same filesystem JSON contract as third parties. Ship JSON under `Data/SKSE/Plugins/SkyrimNet_SexLab/webui/…` next to the handler ESP. Load order can overwrite files.

**Reference: bondage / DDNG** — BondagePanel requires Devious Devices NG (`DeviousDevices.dll` + Assets.esm + Integration.esm). Core SkyrimNet_SexLab does not. Live files are `webui/TargetMenu/Actor/options/0600_sexlab_bondage.json` (TargetMenu `bondage` → BondagePanel stacked body-area label + pulldown below widget → **Start** → `Handler_UDNG.TM_BondageFinish`) and `bondage/group-devices.json` (file-first catalog; `GetDatabase` overlays when ready; head-to-foot including Hood / Boots / Suit). FOMOD Recommended when Assets **and** Integration are active. `make release` moves both into FOMOD `handler_udng/` with the handler ESP (KNOWLEDGEBASE **Optional SKSE files / FOMOD split**). Handler `Setup` fails without DDNG (no BondagePanel) and does not call `RegisterTargetMenuOption` or depend on `SkyrimNetUDNG.esp`. Do not send the catalog through Papyrus `ObjectToLowerCaseKeyJson`.

`RegisterTargetMenuOption` remains in the API for legacy callers but is not used by the bondage handler.

### ControlPanel modes

`Data/SKSE/Plugins/SkyrimNet_SexLab/webui/ControlPanel/*.json` (lexicographic) is the **only** mode registry. SexLab does not scan other plugin folders. Third parties work by deploying a JSON file **into this directory** (MO2 overlay, FOMOD copy, or a Data-path file in their own repo). TargetMenu and MainPanels stay under that plugin’s own `catalogRoot` — do not drop those trees into SexLab’s `webui/` (they would mix with SexLab’s built-in options). Same JSON loader as TargetMenu/MainPanels — no YAML parser.

Built-in SexLab (no file required):

- `id`: `sexlab`
- `label`: `SkyrimNet SexLab`
- catalog = this plugin’s `webui/TargetMenu` + `webui/MainPanels`

Example drop-in (fields are generic; any plugin can use them):

```json
{
  "id": "example_mode",
  "label": "Example Mode",
  "requiresPlugin": "Example.esp",
  "catalogRoot": "SKSE/Plugins/Example/webui",
  "plugin": "Example.esp",
  "questFormId": "0x800",
  "scriptName": "Example_Menu",
  "openFunction": "TM_ModeOpened",
  "closeFunction": "TM_ModeClosed",
  "hideFramework": true,
  "rowClickMainPanel": "detail",
  "sentinels": [{ "id": "all_units", "label": "All Units", "mainPanel": "roster" }]
}
```

| Field | Role |
|-------|------|
| `id` / `label` | Mode pulldown (replaces the old hardcoded `SkyrimNet SexLab` title) |
| `requiresPlugin` | Omit the mode if that ESP is not loaded |
| `catalogRoot` | Data-relative folder with that plugin’s `TargetMenu/Actor/` + `MainPanels/` |
| `plugin` / `questFormId` / `scriptName` | Quest script for `openFunction` / `closeFunction` (zero-arg) |
| `hideFramework` | Hide the OStim framework row while this mode is active |
| `rowClickMainPanel` | MainPanel `id` to open after a `data_table` row click; omit to leave the current panel |
| `sentinels` | Extra actor-pulldown entries (see **Target sentinels**) |

JS `onControlModeChange` → C++ `SwitchControlMode`: close current main panel, call previous `closeFunction`, select the mode, `configureControlPanel` + `configureTargetMenu` from that catalog, call `openFunction`. Last mode is remembered for the overlay session (hide/show does not reset to SexLab). Actor focus is kept unless the new mode’s open path changes it.

Foreign-mode views are whatever that `catalogRoot/MainPanels/` ships. SexLab Scene Menu / Animation / Log / Settings disappear when the active mode’s catalog does not include them. SexLab sex/scene TargetMenu rows are not on screen (different `catalogRoot`).

### Target sentinels

A mode may inject actor-pulldown entries that are not nearby FormIDs (`id` + `label`; optional `mainPanel`).

Selecting a sentinel:

- JS `onControlActorChange({ sentinel, formId: 0 })`
- C++ sets `Target_Current` to null and `FocusKind` to the sentinel id, then rebuilds the TargetMenu catalog
- `webui_focus_kind` eligibility decorator compares against `FocusKind` (`==` / `!=`)
- `ExecutePapyrusOption` allows a missing `target` Actor when the mapping source is `target` (Papyrus receives `None`)
- If the sentinel has `mainPanel`, C++ `SwitchMainPanel`s to that id; otherwise the current panel stays

`WebUI_GetFocusActor` / `WebUI_GetFocusKind` expose the pair to Papyrus. `Target_Menu_Refresh` is allowed when `Target_Current` is null if `FocusKind` is set. Clearing the TargetMenu session clears `FocusKind`.

Far-actor pin: a `data_table` row click still calls `ApplyControlActorFocus` with that FormID even if the actor is not nearby; SexLab already keeps the current focus actor in the nearby list. If the mode sets `rowClickMainPanel`, the overlay then opens that panel.

### Foreign main panels

`type: papyrus` MainPanels still only run zero-arg open/close and do not paint HTML. Use:

| type | Host | Payload (`WebUI_PushMainPanelData`) |
|------|------|-------------------------------------|
| `data_table` | `#data-table-panel` | `{ "panel": "data_table", "id", "columns", "rows", "truncated" }` |
| `actor_detail` | `#actor-detail-panel` | `{ "panel": "actor_detail", "id", "fields", "controls" }` |

Do not mix table and detail in one object. Row: `{ "formId": 123, "cells": ["Name", ...] }` (unsigned FormID; ESL signed Papyrus ints are `>>> 0` in JS). Field: `{ "id", "label", "value" }`. Control: `{ "id", "label", "widget": "toggle"|"select"|"button", "value", "options" }`.

`openFunction` should build and push the payload. Include `plugin`, `questFormId`, `scriptName`, and `applyFunction` in the JSON so toggles can dispatch Papyrus; the overlay has no hardcoded plugin/script fallbacks. Toggle/select/button → `onAction` papyrus `(speaker, target, control, value)` with `closeWebUI: false`. Row click → `onMainPanelRow` → focus that FormID, then `rowClickMainPanel` if the mode set it.

Native: `SkyrimNet_SexLab_WebUI.WebUI_PushMainPanelData(String json)`. Cap roster/table size so PrismaUI is not stalled by a huge Invoke.

### TargetMenu `panel: fields` + live cascades

Actor **`panel: fields`**: Start (unless every field has `applyOnChange`) then labeled selects from `panelFields` / `panelDefaults`. Field schema: `fieldId` / `caption` / `choices` / choice `val`+`caption` (avoid `name`/`label`/`options`/`value` — Skyrim string pool remaps those). Dynamic params are `fieldId`s. `applyOnChange: true` fires Papyrus on pick (Order walking). Option `opensText: true` (e.g. punish **custom**): picking it shows an inline text field; Ok inserts the string into that select’s choices and selects it (session-only; never Start with bare `"custom"`).

Live lists: `SkyrimNet_SexLab_WebUI.WebUI_PushCascadeChoices(String json)` → JS `setCascadeChoices`. Push payloads should use `ObjectToLowerCaseKeyJson`. Button cascades use `{ title, options:[{type:papyrus,…}] }`. Fields cascades use `{ panel:"fields", panelFields, panelDefaults, plugin, questFormId, scriptName, executionFunctionName, parameterMapping, closeWebUI }`. Catalog rows without static `panelFields` fire the opener Papyrus (closeWebUI false) so Push can fill the panel.

DOM punish: method field `type === "rape"` expands the full `scene_start` controls under the reason/method row **without** Custom. Start records via DOM `TM_PunishRapeRecord` then fires SexLab `StartScene_Nonconsensual_*` (AnimDb tag probe first).

## Build

CMake tasks in `.vscode/tasks.json` with `cwd` = `SKSE_Source`. Needs VS 2022, `VCPKG_ROOT`, `x64-windows-static`.

Papyrus C++ bindings declare SkyrimNet PublicAPI symbols as `extern` function pointers (`PublicFormIDToUUID`, …). Do not `#include "PublicAPI.h"` from this plugin.

| Task | Effect |
|------|--------|
| `CMake: Configure (Debug\|Release)` | submodule init + cmake preset |
| `CMake: Build SKSE (Debug\|Release)` | build + copy DLL → `SKSE/Plugins/` |

## PrismaUI

Hard dependency ([Nexus](https://www.nexusmods.com/skyrimspecialedition/mods/148718)); the PrismaUI **plugin** is not shipped here.

**View path:** `CreateView("SkyrimNet_SexLab/index.html")` resolves under **`Data/PrismaUI/views/`**, not `SKSE/Plugins/`. This mod’s overlay HTML **is** shipped: `make release` copies `PrismaUI/` into FOMOD `core`. Missing file → open path looks fine; do not `Focus` until DomReady or the game pauses with a blank overlay (Escape is JS-only unless C++ Hide runs).

**Display scale:** Overlay matches SkyrimNet’s system — px design tokens (~15px base), `body.style.zoom` × Dashboard `ui_scale` × up-only 1080p baseline, scrollable left-column / panel shells. See [KNOWLEDGEBASE.md](../../KNOWLEDGEBASE.md).

After changing action `label`s: regenerate `actions_index.json` with `tools/generate_actions_index.py`.
