# Changelog

## [0.33.0](https://github.com/GoodProvider/SkyrimNet_SexLab/releases/tag/0.33.0) — since [0.31.5](https://github.com/GoodProvider/SkyrimNet_SexLab/releases/tag/0.31.5)

### Actions / scenes
- Ship LLM actions and prompts as SkyrimNet Beta 25 external plugin `goodprovider.sexlab` (`SKSE/Plugins/SkyrimNet/external/goodprovider.sexlab/`). Action YAML filenames now equal in-file `name` (e.g. `SexLab_Start_Giving.yaml`); `name` values unchanged
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
- Requires SkyrimNet **0.25.0+**. Plugin should appear under Installed Plugins with an **External** badge. Settings schema stays at [`config/plugins/SkyrimNet_SexLab/manifest.yaml`](SKSE/Plugins/SkyrimNet/config/plugins/SkyrimNet_SexLab/manifest.yaml) (`schema.fields` + `defaultValue`, `plugin.version` 0.33.0, 12 `sexlab.*` keys). Dashboard hid SexLab when the old list/`default` shape loaded as 0 fields. Start Sex hotkey is `type: hotkey` default **backslash** (`\`, VK 220). Change options in the SkyrimNet dashboard, not the MCM.
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
