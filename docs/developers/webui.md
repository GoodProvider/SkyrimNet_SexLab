# WebUI (SKSE + PrismaUI)

In-game overlay: C++ SKSE plugin, PrismaUI HTML, target/sex menu config.

Quirks: [../../KNOWLEDGEBASE.md](../../KNOWLEDGEBASE.md) (PrismaUI view path, action catalog).

## Paths

| Path | Role |
|------|------|
| `SKSE_Source/` | C++ → `SkyrimNet_SexLab.dll` |
| `SKSE/Plugins/SkyrimNet_SexLab.dll` | Built plugin |
| `PrismaUI/views/SkyrimNet_SexLab/index.html` | Overlay HTML under `Data/PrismaUI/views/` |
| `SKSE/Plugins/SkyrimNet_SexLab/webui/` | `actions_index.json`, `TargetMenu/Actor/`, `TargetMenu/Scene/`, `MainPanels/` (third-party JSON overlays into these folders; `requiresPlugin` omits missing ESPs) |
| `SKSE/Plugins/SkyrimNet_SexLab/webui/TargetMenu/Actor/options/0600_sexlab_bondage.json` | Bondage TargetMenu option (live catalog; `make release` moves it into FOMOD `handler_udng/`) |
| `SKSE/Plugins/SkyrimNet_SexLab/webui/TargetMenu/Actor/options/0700_sexlab_leash.json` | Old-ESP leash option (`panel: leash`; omitted unless `SkyrimNet_Leash.esp` is loaded). `SkyrimNet_Leashed.esp` rows overlay from that zip (`0700_leash.json` / `0701_unleash.json`); do not add a second `panel: leash` for Leashed. |
| `SKSE/Plugins/SkyrimNet_SexLab/bondage/group-devices.json` | BondagePanel file-first catalog (live; API `GetDatabase` overlays when ready; same release split) |
| `SKSE/Plugins/SkyrimNet/config/plugins/SkyrimNet_SexLab/manifest.yaml` | SkyrimNet plugin settings schema (control store) |
| `Scripts/Source/SkyrimNet_SexLab_WebUI.psc` | Target/Sex/YesNo/SceneCreator/Animation natives + `SceneConnections_Show` + `SceneInfos_Seed` |

## Layout

```
| ControlPanel (10% top/left) | Main panel (10% top/bottom/right) |
| TargetMenu (same width)     |                                     |
```

- **ControlPanel** (`#control-panel`): **views** label (75% of `--text-base`) above an indented `main_panel` pulldown (from `MainPanels/`, with JS builtin fallback); OStimNet-gated **framework** pulldown (`#framework-row`, `sexlab`/`ostim`, no label, hidden unless OStimNet); then **target** label (same 75% size) above an indented **actor focus** pulldown (`#control-actor-pulldown`, nearby actors plus **sentinels** declared on MainPanel JSON). Main-panel list includes **None** (clears the right main-panel host). Pulldowns stay **vertically aligned with the trigger**; only the left offset uses `--space-md` from the ControlPanel box (same gap as TargetPanel → Parameter Panel). Menus stack above TargetPanel and the main panel and use an opaque background.
- **Actor focus pulldown:** nearby actors (player pinned first), sorted sexlab → eligible → ineligible, then distance. Labels: name cropped to 10 chars; `(sexlab)` selectable; no suffix = eligible; `(reason)` greyed (`child`/`cmbt`/`ostim`/`dead`/`load`, ≤5 chars). Selection sets `Target_Current` and switches the selected **SceneInfo** to that actor’s thread if any, else the Scene Creator (`new`) SceneInfo. Default: crosshair if present, else nearest selectable non-player, else player.
- **Always paused while open:** `Focus(view, true)` on Show. There is no pause/unpause toggle (it would let SexLab threads drift from SceneInfo drafts). Log tailing is file I/O and still works. AnimDB rebuild that needs `RegisterForSingleUpdate` waits until the overlay closes.
- **TargetMenu:** stacked under ControlPanel in the left column (no actor name header — focus is the ControlPanel pulldown).
- **Main panel host:** one visible panel at a time, selected by the pulldown (builtin Scene Menu / Animation / Log / Settings). Scene Menu (`#scene-creator-panel`) fills the host; **Animations list is a fixed 50%** of the panel (scroll inside `#sc-anims-list`). Positions + Filter share the remaining height and scroll internally. Filter’s available-tags region (`#sc-available-tags`) is **2×** the selected tags+suppress rows; those chip lists scroll internally.
- Sex Menu / YesNo remain overlay panels outside the main_panel pulldown.

### SceneInfo (shared scene draft)

JS `SceneInfo` map: one instance per active SexLab scene (`scene:<sid>`) plus one `'new'` Scene Creator draft. Seeded from Papyrus `BuildAllSceneInfosJson` on overlay Show (`SceneInfos_Seed`). Actor focus selects the thread that contains that actor, or `'new'`. Switching actors does not wipe `'new'`.

Panels copy the selected SceneInfo into a local draft on open. **Start / Done / Update / Stop / silent / explain** write the draft into SceneInfo. **Cancel** (and leaving a panel without confirming) does not. Overlay **Cancel / Escape** hide **without** committing — dirty SceneInfos are dropped. Non-Cancel hide (hotkey, Scene Menu Start, TargetMenu action Start) flushes dirty SceneInfos (`WebUI_OnSceneInfoCommit`) then Unfocus so `StartThread` can run.

### Scene Menu + AnimationPanel connection

- Focus actor owns the selected SceneInfo (or `"new"` creator state). Duplicate scene pulldowns on Scene Menu / AnimationPanel were removed.
- Opening Scene Menu / Animation binds the panel to the selected SceneInfo (`mainPanelDidOpen`). Do not re-fetch Papyrus snapshots on actor change (that wiped drafts).
- **Scene Menu** (`scene_creator_panel`): multi-select anim pool. On `new`: Start (apply + `pendingCreate` + commit-hide) / Cancel (no SceneInfo write). On active scene: Stop (`pendingStop`), A/N column, Update (writes anim pool into SceneInfo; SexLab in-thread cap 128 applied on commit), stage prev/next stay in the draft until Update/Stop. Header **setting** pulldown is `none` plus C++-loaded `scenes/*.json`; every open resets to `none`. Picking a file applies `default` then that file onto SceneInfo without changing actors; `none` does not revert. **Save** uses overlay confirm / name+list / overwrite dialogs (not `window.confirm`); Papyrus writes the JSON even when there is no live creator.
- **Filter-by downgrade:** each Scene Creator / Scene Menu open arms `gender → none` (`scArmFilterDowngrade`; default `gender`). A query returning zero anims steps to the next looser mode and re-queries, so the pulldown shows the mode actually used. Re-armed once actor meta resolves. **Do not query gender/positions mode while any position `_gender` is unknown** (`null`, not `0` — `0` is male). Nearby/player JSON includes `gender` from C++ `GetSex` for first paint; Papyrus `GetGender` overwrites via `actorAnimMetaResult` (creatures 2/3). Picking a mode manually pins it for that open (`positions` remains a pulldown option). Callers wanting a different start set `SC.filterByOnce` before `configureSceneCreator` (SceneStartPanel **Custom** uses `none` for nonsexual/affection methods, which leaves no fallbacks; other Custom uses `gender`).
- **AnimationPanel**: in-thread name picker (no 10-cap). Filter input matches substring on name/registry; list scrolls inside `#main-panel-host`. Click a name selects it in the panel draft; **Done** writes `activeRegistry` into SceneInfo. Stage/position/stop editing lives on TargetMenu Scene panels (Done applies to SceneInfo).
- **Animation open preference:** C++ remembers whether Animation was the selected main panel across hide. Hotkey restores Animation only when the focus actor is in SexLab **and** that preference is true.
- **Hotkey toggle:** if the overlay is visible, the menu hotkey hides it immediately (any ControlPanel focus actor) and does **not** dispatch `ProcessHotkey`. Hidden → `Menu.ProcessHotkey` → `Target_Menu_Open` (rebuild if same actor, else full open). Close does not clear `Target_Current`. Show/Focus only after DomReady; missing overlay HTML does not pause the game. Escape uses JS `handleGlobalEscape` when ready; C++ Unfocus/Hide if DomReady never fired.
- **Escape z-order:** one layer per keypress, highest first: open `.pulldown` menus → Save SceneSetting overwrite / name / confirm dialogs → IntentPanel (Cancel, no SceneInfo write) → YesNo silent No → Sex menu hide → TargetMenu cascade / Parameter panel (pop one nested pulldown, or close the Parameter/papyrus panel) → selected main panel to ControlPanel **None** (does **not** run Scene Creator **Cancel** while TargetMenu is open). When only TargetMenu and/or ControlPanel remain, Escape hides the overlay without committing SceneInfo (`onCancel`). Scene Creator without TargetMenu (YesNo flow) still **Cancel**. Root **Custom** closes an open Parameter/cascade panel before toggling Scene Creator.

## Lifecycle

- `kDataLoaded`: PrismaUI API, `CreateView("SkyrimNet_SexLab/index.html")`, JS listeners.
- `kPostLoadGame` / `kNewGame`: `WebUI_SetGameReady()` (enables input; reloads ActionCatalog from `webui/`; `configureControlPanel`).
- DomReady / game-ready: `configureControlPanel(BuildMainPanelsCatalog())` (includes `sceneSettings` from `scenes/*.json` so Scene Menu’s setting pulldown is populated without opening TargetMenu).
- Pulldown → JS `onMainPanelChange` → C++ `SwitchMainPanel` (close previous, open next). On key change to Scene Menu / Animation, C++ invokes `mainPanelDidOpen()` → bind the selected SceneInfo into that panel’s local draft (no Papyrus `WebUI_OnSceneConnectionChange`). Scene Menu **Update** writes into SceneInfo; SexLab anim-list apply happens on overlay commit. Full `SceneCreator_Open` / `Animation_Menu_Show` remain for YesNo / Custom / hotkey.
- Papyrus → C++ open; C++ → JS `showPanel` for `target_menu_panel` / `sex_menu_panel` / `scene_creator_panel` / `animation_menu_panel` (SC/AM auto-select the matching main_panel entry; idempotent if already selected).
- Catalog: `TargetMenu/Actor` or `TargetMenu/Scene` (from ControlPanel SexLabAnimatingFaction) + `actions_index.json` + `MainPanels/`; **Start** merges params and dispatches; action-panel **Custom** writes the panel draft plus scene setting into creator SceneInfo `new` and shows Scene Creator.

### TargetMenu UX

- Root `#target-panel` holds globals + root options + Cancel only (no `#target-name`). Each opened `pulldown` is its own sibling panel (nav stack); Parameters is a separate confirm panel with **Start** / **Custom**. The cascade row sits in the left column under ControlPanel; Scene Creator opens in the right main-panel host.
- Mid-scene **Scene** catalog (focus in SexLabAnimatingFaction): **stop** (speaker pulldown + silent/stop/explain → SceneInfo `pendingStop`), **stage** (index + editable description; **Done** writes SceneInfo), **position** (Scene Creator-style whole-cast table; **Done** writes SceneInfo), **animation** (opens AnimationPanel picker in the main host), **save to json**.
- Nested Parameters / papyrus cascade panels put confirm buttons as the first row (Cuddle: Custom/Start then pulldowns) and show label+pulldown on one aligned row. Root TargetMenu Cancel stays at the bottom of `#target-panel`.
- Click a scene-start action while Scene Creator is closed → select it and open the Parameters panel (does not start). Nested under a `pulldown`, the parent cascade stays open and the Parameter Panel sits to its right. While Scene Creator is open, the same click reapplies that row's `panelDefaults` (plus scene setting JSON) onto creator SceneInfo `new` and reconfigures Scene Creator — it does not open the Parameters panel. SceneStartPanel **Custom** is omitted when `scene_creator_panel` is not in `MainPanels/`.
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

**Order = lexicographic filename** (numeric prefixes). Keys are lowercase. Actor root example: `0100_custom` → `0110_sex` → `0150_cuddle` → …. Every option node has `type`:

| type | Fields | Role |
|------|--------|------|
| `parameter` | `name`, `default`, `values` | Global param pulldown |
| `action` | `name`, `label`, optional `parameters`, optional `disabled`, optional dispatch fields | Selects action + Parameters panel; confirm with Start/Custom; `disabled` = greyed non-clickable |
| `scene_creator` | `label` | Actor-root toggle: open/close Scene Creator on creator SceneInfo `new` (no Papyrus). Highlighted while Scene Creator is the selected main panel. |
| `papyrus` | `label` (no `name`), `plugin`, `questFormId`, `scriptName`, `executionFunctionName`, `parameterMapping`, optional `eligibilityRules`, optional `closeWebUI` / `confirmSave` / `explainPrompt` / `panel`, optional `panelDefaults` / `panelFields` | TargetMenu-only Papyrus call via `onAction({action:"papyrus",...})` — no YAML / `actions_index`. Actor **`panel: scene_start`** is the shared sentence UI. Actor **`panel: fields`**: Start + labeled pulldowns from `panelFields` (`name`/`label`/`options:[{value,label}]`); Start copies values into `parameters` for dynamic mapping (used by DOM follow/punish/furniture). `applyOnChange: true` on a field fires the same Papyrus call on pulldown pick and skips the Start bar when every field has it (DOM walking). A field option may set `opensText: true` (DOM punish **custom**): picking it opens a text panel (Cancel / Ok, same chrome as IntentPanel); Ok stores the typed string as the field value (pulldown shows that text); empty Ok cancels; Start never sends the bare sentinel. `WebUI_PushCascadeChoices` payload `"panel": "fields"` replaces `papyrusSelectedOpt.panelFields` instead of stacking a button list. Actor **`panel: outfit`**: sentence `position_1` / style (`forcefully|normally|gently|silently`) / undresses|dresses / `position_0`; **Start** only (no Custom); `TM_Outfit`; style `silently` skips SkyrimNet narration. Actor **`panel: bondage`**: speaker / style / `changes devices on` / target; per-group 75% body-area label above a 1em-indented pulldown (menus open **below** the widget); pulldowns edit JS `ActorBondage.current` only (no live apply); **Cancel** / hide discard the session; **Start** applies `currentJson` (`TM_BondageFinish`) then narrates unless `silently` and `WebUI_CloseOverlay`; no Custom. **BondagePanel requires Devious Devices NG**; core SkyrimNet_SexLab does not. Catalog: `requiresPlugin: Devious Devices - Assets.esm` + `requiresDll: DeviousDevices.dll`. Actor **`panel: leash`**: Subject / Leashed / style / action pulldown (`tie to`\|`give to`, plus `unleash` when already leashed); action-row control is location or holder; **Start** only; `requiresPlugin: SkyrimNet_Leash.esp`; dispatches `SkyrimNet_Leash_Actions` (no YAML). Scene panels: **`stop`** (speaker pulldown + silent/stop/explain → SceneInfo `pendingStop`), **`stage`** / **`position`** (edit draft; **Done** writes SceneInfo), **`animation`** (opens AnimationPanel; **Done** writes `activeRegistry`). Apply to SexLab on overlay commit. `panelDefaults` seeds SceneStartPanel (Subject, `andThird` none/and, Object `with`/`to victim`/`none`, intent, direction, method, style, setting). Intent **custom** opens IntentPanel (text, Cancel, Ok). Hug/cuddle/kiss giver is SexLab pos1 when intent is `show affection` / `comfort` (or the long Papyrus labels) or method is `cuddling|kissing|hug`. When Scene Creator is already open, clicking a `scene_start` / `cuddle` row applies `panelDefaults` to SceneInfo `new` instead of opening this panel. |

| `pulldown` | `label`, `options[]`, optional `parameters`, optional `eligibilityRules`, optional `layout` | Group; children are `action`, `papyrus`, and/or nested `pulldown`. Nested pulldowns open as sibling cascade panels to the right (`‹` header pops). `layout: "buttons"` renders papyrus children as full-width `.action-btn` and nested pulldowns as buttons with `❯` (default is option rows). Optional `eligibilityRules` evaluated at catalog build against `currentActor`; fail **or** zero remaining children → option omitted. A nested `papyrus` row with `panel` (e.g. `scene_start`, `fields`) keeps the parent pulldown open so the Parameter Panel sits to its right. |
| `actionSwitch` | `label`, `options[]` of `action` + `eligibilityRules` | C++ picks first eligible child (or disabled fallback label) |

Optional on any option node: `requiresPlugin` (ESP/ESL name) — omitted from the catalog when that mod is not loaded. Optional `requiresDll` (e.g. `DeviousDevices.dll`) — omitted when `GetModuleHandle` does not find that SKSE plugin. Optional `source` (string). Missing or `"sexlab"` is native (no badge). Any other value is painted **upper-left at 50% font above** the option label (display uppercased, e.g. `"dom"` → `DOM`). Nested children inherit the parent `source` when they omit it.

**Filesystem dispatch actions** (optional handlers / third parties): an `action` option may carry `plugin`, `questFormId` (local, e.g. `"0x800"`), `scriptName`, `executionFunctionName`, and `parameterMapping`. C++ synthesizes an `ActionDef` so `ExecuteAction` works without an `actions_index` row. Prefer `plugin` + local FormID over EditorID for optional ESPs.

Actor sources: `playerActor` / `currentActor` (aliases `player` / `target` / `focus` still work).

Outfit: Actor catalog `panel: outfit` (undress/dress via FormListCount eligibility) → `TM_Outfit(speaker, target, style)`. Sentence UI; **Start** closes WebUI (no Custom). Style `silently` skips DirectNarration and RegisterEvent. `Outfit_Dress` / `Outfit_Undress` still call `Target_Menu_Refresh` after storage updates (no-ops when menu is closed). LLM YAML `outfit_dress` / `outfit_undress` is unchanged.

Bondage: Actor catalog `SKSE/Plugins/SkyrimNet_SexLab/webui/TargetMenu/Actor/options/0600_sexlab_bondage.json` (`panel: bondage`, `requiresPlugin: Devious Devices - Assets.esm`, `requiresDll: DeviousDevices.dll`). **BondagePanel requires Devious Devices NG; core SkyrimNet_SexLab does not.** Click opens BondagePanel (speaker / style / target), top-aligned with ControlPanel. Each group is a 75% `--text-base` body-area label above a 1em-indented pulldown (`none` + devices; menus open below the widget). Head-to-foot: Blindfold, Gag, Hood, Collar, Piercing Nipple, Body, Arms, Belt, Piercing Vaginal, Plug Vaginal, Plug Anal, Legs, Boots, Suit — JS draws these `BONDAGE_GROUP_ORDER` rows immediately (`none` until catalog devices arrive). C++ seeds slim `{id,name}` from `group-devices.json` first (`bondageConfigure({...})` object-literal header plus per-group `bondageConfigureDevices({...})`; a 400KB one-shot `Invoke` never ran), then overlays `GetDatabase()` when `LoadAPI` succeeds (`source: api`). Do not `PrismaUI->InteropCall`. JS ignores parse fail and empty headers; ignores empty `ab.groups`; keeps `ActorBondage.current` / `original`. Ack `bondageGot` in the SKSE log. Papyrus `PushBondageState` sends `{target}` only (number or string). Apply still uses the JC file (`plugin:0xhex`). Per-actor **ActorBondage** seeds original+current from worn on first current-actor select; later Refresh must not clobber `current`. Pulldown change writes `current` only (no Papyrus). `bondageConfigure` always rebuilds the device list from `current`. **Cancel** closes the panel only (Map kept until overlay hide). **Start** → `TM_BondageFinish(speaker, target, style, currentJson)` applies `SetGroupToId` per group, narrates unless `silently`, `ReleaseAll`, `WebUI_CloseOverlay` (`closeWebUI: false` so C++ does not Hide first). Hotkey/Escape hide: `bondageReleaseAll()` + `TM_BondageOnWebUIClosed` ReleaseAll only (no device restore). LLM lock/unlock actions stay in SkyrimNet_UDNG. `zadLibs` is Handler-only so the main ESP loads without DD. Repo/MO2 sees the SKSE tree; `make release` moves this JSON and `bondage/group-devices.json` into FOMOD `handler_udng/` with the handler ESP (see KNOWLEDGEBASE **Optional SKSE files / FOMOD split**).

Leash (current): SkyrimNet_Leashed overlays `0700_leash.json` / `0701_unleash.json` into `Data/SKSE/Plugins/SkyrimNet_SexLab/webui/TargetMenu/Actor/options/` (`source: leashed`, `requiresPlugin: SkyrimNet_Leashed.esp`). Those are `type: papyrus` with `closeWebUI` and **no** `panel` — click hides this overlay and opens Leashed’s PrismaUI. Eligibility is `is_in_faction` / `LeashedFaction` (FormID `Leash.esm` `0xD6A` if EditorID lookup misses). Do not host a second leash ParameterPanel here.

Leash (old ESP): Actor catalog `SKSE/Plugins/SkyrimNet_SexLab/webui/TargetMenu/Actor/options/0700_sexlab_leash.json` (`panel: leash`, `requiresPlugin: SkyrimNet_Leash.esp`). **Start** only (no Custom). Subject / Leashed / style, then an action pulldown in the label column: `tie to` / `give to`, plus `unleash` when `LeashFramework.IsLeashed` on the Leashed actor. `tie to` shows location (`floor|left|back|front|right|wall`); `give to` shows holder; `unleash` has no extra control. Start calls `SkyrimNet_Leash_Actions` (`LeashedToHolder` / `LeashedToTiePoint` / `GiveLeash` / `TakeLeash` / `Unleash*`) — not YAML. Status via JS `onLeashStatus` → C++ `DispatchStaticCall` (no `LeashFramework.dll` link). Lives in the core SKSE tree (not a FOMOD handler split).

Menu labels for the target panel come from `TargetMenu/Actor` or `TargetMenu/Scene`. Nested pulldowns open as separate panels in a row (`‹` header pops).

Start merge order: YAML statics → `defaultsParameters` → matching action-node `parameters` → UI dictionary (UI wins).

`actions_index.json` is `{ "actions": [...] }` only — no `by_category`.

### `webui/MainPanels/`

One JSON object per file; **order = lexicographic filename**. Optional `requiresPlugin` skips the entry when the mod is missing. Optional `source` (same as TargetMenu): non-`sexlab` values appear as a **leading superscript** on the views pulldown label. Optional `sentinels` (array of `{id, label, mainPanel}`) inject target-pulldown entries. Optional `rowClickMainPanel` on a `data_table` is the MainPanel `id` to open after a row click.

| type | Fields | Role |
|------|--------|------|
| `builtin` | `label`, `panel` | Panel already in PrismaUI (`log_panel`, `settings_panel`, `scene_creator_panel` labeled Scene Menu, `animation_menu_panel`) |
| `papyrus` | `label`, `id`, `plugin`, `questFormId`, `scriptName`, `openFunction`, `closeFunction` | Zero-arg Papyrus open/close on that quest script |
| `data_table` | same quest fields as `papyrus`, plus `columns` (`id`/`label`) | Generic table host (`#data-table-panel`). Open still calls `openFunction`; rows arrive via `WebUI_PushMainPanelData`. |
| `actor_detail` | same quest fields as `papyrus` | Generic key/value + control host (`#actor-detail-panel`). Payload `fields` + `controls`. |

Starters in core: `0900_log_panel.json` (Log), `1000_settings.json` (Settings), `0100_scene_creator_panel.json`, `0200_animation_panel.json`. Third parties overlay extra files into this folder (e.g. DOM `0300_dom_status.json` / `0400_dom_slaves.json`).

**AnimationDB / AniDescriber:** authored anidata first; missing stage text is filled from Havok clips ([anidescriber.md](anidescriber.md)), then Papyrus tags. Rebuild does not precompute every clip.

**Settings panel:** rebuild AnimationDB (then switches main panel to Log with follow-tail), version from `Data/SKSE/Plugins/SkyrimNet_SexLab/info.json` (fallback `Config::kPluginVersion`), docs URL shown as text (`https://github.com/GoodProvider/SkyrimNet_SexLab` — no `ShellExecute`), **Open SkyrimNet dashboard** hides this WebUI then `SkyrimNetApi.TriggerToggleDashboard()` (navigate Plugins → SkyrimNet_SexLab; no deep-link API). Plugin config schema: `SKSE/Plugins/SkyrimNet/config/plugins/SkyrimNet_SexLab/manifest.yaml`. C++ reads via `PublicGetPluginConfigValue("SkyrimNet_SexLab", …)`; Papyrus via `SkyrimNetApi.GetConfig*("Plugin_SkyrimNet_SexLab", …)`.

**Log panel:** reads `SKSE::log::log_directory()` / `SkyrimNet_SexLab.log` (same sink as `webui_log` / Papyrus `TraceLog`). Regex filter in JS; follow-tail unless the user scrolls away. C++ tails by file offset; JS polls `onLogPoll` while visible.

### Optional integrations (FOMOD / third parties)

Drink your own champagne: official optional packages use the same filesystem JSON contract as third parties. Ship JSON under `Data/SKSE/Plugins/SkyrimNet_SexLab/webui/…` next to the handler ESP. Load order can overwrite files.

**Reference: bondage / DDNG** — BondagePanel requires Devious Devices NG (`DeviousDevices.dll` + Assets.esm + Integration.esm). Core SkyrimNet_SexLab does not. Live files are `webui/TargetMenu/Actor/options/0600_sexlab_bondage.json` (TargetMenu `bondage` → BondagePanel stacked body-area label + pulldown below widget → **Start** → `Handler_UDNG.TM_BondageFinish`) and `bondage/group-devices.json` (file-first catalog; `GetDatabase` overlays when ready; head-to-foot including Hood / Boots / Suit). FOMOD Recommended when Assets **and** Integration are active. `make release` moves both into FOMOD `handler_udng/` with the handler ESP (KNOWLEDGEBASE **Optional SKSE files / FOMOD split**). Handler `Setup` fails without DDNG (no BondagePanel) and does not call `RegisterTargetMenuOption` or depend on `SkyrimNetUDNG.esp`. Do not send the catalog through Papyrus `ObjectToLowerCaseKeyJson`.

`RegisterTargetMenuOption` remains in the API for legacy callers but is not used by the bondage handler.

### Third-party overlay JSON

Third parties drop TargetMenu/MainPanel JSON into `Data/SKSE/Plugins/SkyrimNet_SexLab/webui/…` (MO2 overlay, FOMOD copy, or a Data-path file in their own repo). SexLab does not scan other plugin folders and does **not** load `webui/ControlPanel/*.json` modes. `requiresPlugin` omits files when the ESP is missing. Same JSON loader as core TargetMenu/MainPanels — no YAML parser.

There is no ControlPanel **mode** pulldown and no `catalogRoot` catalog swap.

### Target sentinels

A MainPanel JSON may inject actor-pulldown entries that are not nearby FormIDs (`sentinels`: `id` + `label`; optional `mainPanel`). C++ unions sentinels from every loaded MainPanel that passes `requiresPlugin`.

Selecting a sentinel:

- JS `onControlActorChange({ sentinel, formId: 0 })`
- C++ sets `Target_Current` to null and `FocusKind` to the sentinel id, then rebuilds the TargetMenu catalog
- `webui_focus_kind` eligibility decorator compares against `FocusKind` (`==` / `!=`)
- `ExecutePapyrusOption` allows a missing `target` Actor when the mapping source is `target` (Papyrus receives `None`)
- If the sentinel has `mainPanel`, C++ `SwitchMainPanel`s to that id; otherwise the current panel stays

`WebUI_GetFocusActor` / `WebUI_GetFocusKind` expose the pair to Papyrus. `Target_Menu_Refresh` is allowed when `Target_Current` is null if `FocusKind` is set. Clearing the TargetMenu session clears `FocusKind`.

Far-actor pin: a `data_table` row click still calls `ApplyControlActorFocus` with that FormID even if the actor is not nearby; SexLab already keeps the current focus actor in the nearby list. If that table’s JSON sets `rowClickMainPanel`, the overlay then opens that panel.

### Foreign main panels

`type: papyrus` MainPanels still only run zero-arg open/close and do not paint HTML. Use:

| type | Host | Payload (`WebUI_PushMainPanelData`) |
|------|------|-------------------------------------|
| `data_table` | `#data-table-panel` | `{ "panel": "data_table", "id", "columns", "rows", "truncated" }` |
| `actor_detail` | `#actor-detail-panel` | `{ "panel": "actor_detail", "id", "fields", "controls" }` |

Do not mix table and detail in one object. Row: `{ "formId": 123, "cells": ["Name", ...] }` (unsigned FormID; ESL signed Papyrus ints are `>>> 0` in JS). Field: `{ "id", "label", "value" }`. Control: `{ "id", "label", "widget": "toggle"|"select"|"button", "value", "options" }`.

`openFunction` should build and push the payload. Include `plugin`, `questFormId`, `scriptName`, and `applyFunction` in the JSON so toggles can dispatch Papyrus; the overlay has no hardcoded plugin/script fallbacks. Toggle/select/button → `onAction` papyrus `(speaker, target, control, value)` with `closeWebUI: false`. Row click → `onMainPanelRow` → focus that FormID, then `rowClickMainPanel` if the table JSON set it.

Native: `SkyrimNet_SexLab_WebUI.WebUI_PushMainPanelData(String json)`. Cap roster/table size so PrismaUI is not stalled by a huge Invoke.

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
