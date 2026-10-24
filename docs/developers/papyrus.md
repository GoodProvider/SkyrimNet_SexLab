# Papyrus / code

Developer guide: paths, compile, architecture, review, ESP.

Contracts: [../reference/papyrus-rules.md](../reference/papyrus-rules.md), [../reference/json-keys.md](../reference/json-keys.md), [../reference/orgasm-narration.md](../reference/orgasm-narration.md). WebUI: [webui.md](webui.md). Quirks: [../../KNOWLEDGEBASE.md](../../KNOWLEDGEBASE.md).

## Paths

| Path | Role |
|------|------|
| `Scripts/Source/` | Papyrus source |
| `Scripts/` | Compiled `.pex` |
| `Headers/` | Import headers |
| `skyrimse.ppj` | Pyro project (main, SexLab 1.6x headers) |
| `skyrimse-pplus.ppj`, `Scripts/Source_PPlus/` | Pyro project for the SexLab P+ bridge `SkyrimNet_SexLab_PPlus` ([sexlab-pplus.md](sexlab-pplus.md)) |
| `Spriggit/` | ESP ↔ JSON |
| `SKSE/Plugins/SkyrimNet/external/goodprovider.sexlab/` | Canonical action YAML + prompts (`manifest.json`; no settings schema). Pre-0.25 copies: `config/actions/`, `prompts/` |
| `SKSE/Plugins/SkyrimNet/config/plugins/SkyrimNet_SexLab/` | Settings schema (`Plugin_SkyrimNet_SexLab`, `sexlab.*`) |
| `SKSE/Plugins/SkyrimNet_SexLab/` | Scenes, animations, threads |
| `SKSE_Source/` | C++ WebUI plugin |

## Compile

VS Code / Cursor task **`compile: pyro`** (`.vscode/tasks.json`, default build task): `C:/Skyrim/tools/Pyro/pyro.exe` runs `skyrimse.ppj` (main scripts) and then `skyrimse-pplus.ppj` (P+ bridge, compiled against `..\SexLab Framework PPLUS\Source\Scripts`). Use `--no-incremental-build` when a pex is newer than its source. Afterwards, **`make check-pex`** must report 0 bad files. **Do not ship pex files from `compile: papyrus`** (papyrus.exe): it stores `"\""` as backslash+quote, which breaks every Papyrus-built JSON. That emptied the AnimDB in 0.36.0 (KNOWLEDGEBASE). Do not invent other one-off compile commands unless asked.

SKSE: [webui.md](webui.md).

## Architecture

```
Actions / Menu / DOM
        │
        ▼
Scene_Creator (pooled) ──StartScene──► Scene_Manager.CreateSceneByCreator
        │                                      │
        └── Release() after Setup ◄── Scene.Setup(creator)
                                               │
                                    SexLab events → Scene
                                               │
                         Decorators / threads.json → prompts
```

- Creator: `CreateCreator()` `TryClaim()` → SETUP (before latent `Setup` / `GetPlayer`), then `Setup` → ACTIVE; always `Release()` after cancel or after Setup copies state. `StartScene` aborts before `NewThread` when `num_actors < 1`.
- `SelectAnimations()` / `SelectAnimationsDialog()`: empty tags (`num_tags == 0 && num_tags_suppress == 0`) skip `GetAnimationsByTags` and return `manager.empty` so SexLab picks. On P+, tagged hits go through `PickOneAnimation` (one random). `Scene.StageStart` `EndAnimation()` after `DURATION_CAP_SECONDS` (120s real-time). Do not `UpdateTimer` to end a P+ thread.
- Afterglow / cum: `RenderSlPrompt` with `helpers/sexlab/afterglow`, `afterglow_failed` or `cum` (no `{% %}` in these templates: RenderTemplate does not bind `sl`, so Papyrus picks the template) — empty / `Error*` / inja / leftover `{{` → fallback. See [prompts.md](../authors/prompts.md).
- `SelectAnimations()` before `sexlab.NewThread()`; abort → `model.Initialize()` then `Release()`.
- `Scene.Setup` returns `Bool`; failure → Release, no half-init slot.
- `Scene.initiator` is the speaker by default. If `num_victims > 0`, `PickNonVictimInitiator()` keeps initiator only when they are not a victim; otherwise first non-victim from positions 1…n then 0 (or None). First-stage `"X initiates: …"` only; do not recompute on AlignActors / live SetVictim.
- External / DOM threads: `EnsureSceneForThread` from `AnimationStart` / `StageStart`. `GetSceneInactive` calls `SetThread` before `thread_scene[tid]`. `GetSceneByThread` treats that slot as authoritative during Setup (status still INACTIVE); Release only on tid mismatch.
- Actor lock: `skyrimnet_sexlab_scene_actor_lock`.
- Trace → `WebUI.TraceLog` → `SKSE\SkyrimNet_SexLab.log` (prefix `"---"`).
- DOM optional: `handler_dom`; Dom orgasm → `OrgasmCustom` + `" is orgasming."`. Combined + Dom last-stage uses `ArmOrgasmWindow` / `orgasm_narrated` instead of immediate DN — [orgasm-narration.md](../reference/orgasm-narration.md). Solo `masturbate` is a synthetic thread (`DOMOnBehaviourChange` → `Scene_Manager.PushDomThreads` → C++ `Threads_SetDom`). Nonconsensual wrappers omit `style` (8-arg limit).
- `GetIntentMessage`: empty `intent` omits the activity clause (no `"finish ."`). `ObjectToLowerCaseKeyJson` walks JC containers; do not call `JValue.toJsonString`.
- Leash: `MCM.leashed_found` (`GetFormFromFile(0x800, "SkyrimNet_Leashed.esp")`); `Menu.EventSend_LeashedOpen` hides WebUI then `SkyrimNet_Leashed_OpenPanel`. Bondage/leash SkyMessage buttons skipped when their index is `-1`.
- Settings: MCM is a pointer; `ApplyPluginConfig` reads `Plugin_SkyrimNet_SexLab`. `Setup` registers `SkyrimNet_OnPluginConfigSaved` → `OnPluginConfigSaved` → `ApplyPluginConfig` so a dashboard save rebinds `RegisterForKey`. `ApplyHotkey` maps leftover saved `43` (old DX backslash) to VK `220`, then `VkToDxScanCode`. Ostim framework setting is `GetConfigInt` / `PatchConfig` `sexlab.ostim.player`. `ApplyPluginConfig` mirrors that into GlobalVariable `skyrimnet_sexlab_ostim_player` for action eligibility (`get_global_value`). Do not use the Papyrus decorator name as a dashboard key or in action YAML.
- Style → speed: `Scene.SetStyle` / `ChangeStyle` / `SetStyleDialog` call `ApplyStyleSpeed` (same multiplier on every `thread.positions`, from `sexlab.speed.*`); `AnimationEnd` / `Release` call `ClearStyleSpeed`. Natives `SkyrimNet_SexLab_Utilities.SetAnimSpeed` / `ClearAnimSpeed` / `GetAnimSpeed`. Speed only — never `UpdateTimer` for style.
- Camera (v0.35.1+): `Scene_Manager` `AnimationStarting` records `Game.GetCameraState()` for the player's first scene (before SexLab forces third person); `AnimationEnd`, once the player is no longer SexLab-active, calls `RestoreCameraAfterScene` (TFC off, first person if that was the start mode). Free camera turned off mid-scene → `Menu.Hud_OnKey("camera_lock")` (from `Hud.cpp`, see [webui.md](webui.md)).
- Inja: always `SkyrimNet_SexLab_Utilities.ParseInja` (native `InjaPrepare` turns literal backslash+`n` into LF, then `SkyrimNetApi.ParseString`); never call `SkyrimNetApi.ParseString` directly. `RenderSlPrompt` already does this.
- Start narration (v0.36.3+): `Scene.StageStart` claims `STATUS_ACTIVE` and calls `StageStart_NarrateStart` before its bookkeeping (`AlignActors`, `SyncAnimationDefaults`, …), so the start DN is not delayed. Intersex positions and Lover's Ledger first times go first as a forced `"sexlab start info"` event; see [orgasm-narration.md](../reference/orgasm-narration.md).
- Keep-talking nudge (v0.36.3+): `sexlab.narration.silence_seconds` (default 8, 0 = off). `PollAnimationChange` → `SilenceTick` → `SilenceNudge_IfQuiet` rotates over non-player positions; `Utilities.SilenceAllows` gates, `Utilities.SilenceNudge` sends `"continue scene"` (no CheckDuplicate).
- Virgin blood (v0.36.4+): `sexlab.narration.virgin_blood` (default false). `StageStart_NarrateStart` appends `LoversLedger.VirginBloodSentences(positions, vaginal, anal)` to the start text; first-times lines (`LoversLedger.FirstTimes`) go in the `"sexlab start info"` event. Lover's Ledger no longer writes blood text.
- Dead actors (v0.36.3+): `sexlab.actors.dead_allowed` (default off), native `SkyrimNet_SexLab_WebUI.IsDeadAllowed()`. False on SexLab 1.66 until `SkyrimNet_SexLab_WebUI.CorpsePatchMismatch(pplus)` (run by `MCM.CorpsePatch_Check`) finds the FOMOD SexLab 1.66 corpse patch; the patched `sslActorAlias` / `sslActorLibrary` call `IsDeadAllowed()`. Nothing changes a corpse's Health. LLM action eligibility unchanged.
- Quirks (initiator vs victim, P+ hop vs end, DOM bind race): [KNOWLEDGEBASE.md](../../KNOWLEDGEBASE.md).

## Review

| File | Role |
|------|------|
| `review-guide.xml` | Persona / rules |
| `review-checkpoint.xml` | Locked decisions, backlog |
| `review-execution-plan.xml` | Current fix pass |
| `reviews/*.review.md` | Per-pass notes |

Resume: guide + checkpoint → plan High→Medium→Low (1-based lines, include comments) → apply → `compile: pyro` → write review → update checkpoint.

## ESP / Spriggit

Do not hand-edit `.esp`. `Spriggit/` is source of truth for the main plugin.

| Command | Direction |
|---------|-----------|
| `make update` / `serialize.bat` | `.esp` → `Spriggit/` |
| `make esp` | `Spriggit/` → `.esp` |
| `make release` | version + esp + pack `.7z` |

Handler ESPs are not Spriggit-backed yet.

## Content authors

Actions / prompts / animations → [../authors/](../authors/). Keep protocol strings in sync with [../reference/](../reference/).
