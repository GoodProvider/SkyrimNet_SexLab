# Changelog

## [0.35.1](https://github.com/GoodProvider/SkyrimNet_SexLab/releases/tag/0.35.1) — since [0.35.0](https://github.com/GoodProvider/SkyrimNet_SexLab/releases/tag/0.35.0)

### AnimDB
- WebUI Settings panel shows the AnimDB animation count next to SexLab's slot count, with a 200% red warning to rebuild whenever they differ (strict compare)
- When the counts differ, the ControlPanel title (mode pulldown) is replaced by a red **Rebuild DB** button
- The ControlPanel title is plain text "SkyrimNet SexLab" when no extra control modes (`ControlPanel/*.json`) are installed; the mode pulldown only appears with two or more modes
- Every WebUI rebuild button (ControlPanel, Settings) closes the WebUI and starts the rebuild; Settings no longer switches to the Log panel
- The first time the menu hotkey is pressed on a save, a mismatch shows a "There is likely a problem" dialog offering to rebuild, instead of opening the overlay (`AnimDb.IsAligned`, `hotkey_db_checked`). The check waits while a rebuild or prompt is in progress or SexLab isn't enabled. The load-time prompt keeps its explained-gap exemption
- AnimDB loaded fewer animations than SexLab slotted (2588 of 2844) with no explanation. The sync now traces per-reason skip counts (null, unregistered, empty registry) with the first 10 names, and the SKSE side warns on duplicate registries and failed upserts. `EndSync` logs `duplicate_registries` / `upsert_failures`
- The "animations doesn't match" prompt no longer repeats when SexLab's slot count and the DB row count are unchanged since the last completed sync (an explained gap); any slot-count change re-prompts
- Tag cleanup on upsert uses a bound statement (a registry containing `'` broke it)
- New game with no AnimDB: the WebUI showed no warning and no **Rebuild DB** button, and the counts read `0 / ?`, because the SexLab count was only pushed once SexLab was enabled. An empty DB now always counts as a mismatch (Settings warning "Animation database is empty", ControlPanel **Build DB**), and the menu hotkey pushes the SexLab slot count on every open (`AnimDb.PushSexLabCount`)

### Actions / scenes
- Lone hug (`StartScene_Event` resolved `hug` → `pa_HugA` `playIdleWithTarget`) now stops combat and sheathes both actors first (new `Actions.CalmForPairedIdle`, mirrors DOM `CalmActorFast`) and waits up to 1.5 s for the sheathe. A paired idle played while the player held a drawn weapon (whip) left the player unable to attack afterward. The path now logs a `lone hug pa_HugA` trace
- Lone hug narration is always "<speaker> hugs <target>." The `direction: getting` swap was dropped: Nina calling a hug with `getting` narrated "Bob hugs Nina."

### Orgasm / narration
- Removed the HUD deny key's Transform (`sexlab.hud.deny_transform` setting, `TransformDialogue` call, `ToggleDenyOrgasm` `from_hotkey` and `SetDenyOrgasm` `transform` params). Deny / allow orgasm are plain events for every source: "<denier> forbids <actor> from orgasming without permission." / "<denier> permits <actor> to orgasm."

### SKSE / WebUI
- Aligned with SkyrimNet beta26 rc4 (PublicAPI v12). Every API symbol this plugin uses is unchanged. The rc4 `PublicAPI.h` includes `PublicAPIDiaryQuery.h`, which neither rc4 zip ships, so `SKSE_Source/include/PublicAPIDiaryQuery.h` is a local stand-in (delete it once upstream ships the real file)
- CommonLibSSE-NG submodule bumped from v4.10.0 to v11.0.0 (`alandtse/CommonLibSSE-NG`, branch `ng`) for Skyrim 1.7.x / 1.7.99 (Address Library format 5). `.gitmodules` URL now uses the repo's current name (was `CommonLibVR`). CommonLib is GPL-3.0-or-later with the Skyrim Modding Exception from v5 on
- TargetMenu Scene catalog: removed `0100_stop`, `0200_stage`, `0300_position`, `0400_animation` and their dead panel JS (`tmRenderStopPanel` / `tmRenderStagePanel` / `tmRenderPositionPanel`, cast-draft helpers, `tmCastDraft`). The Description Editor covers stop / stage / actor order / animation. Manual (non-MO2) upgrades should delete those four files
- Description Editor **continue scene** closes the WebUI (`requestWebUIHide(true)`) after sending its DirectNarration
- New HUD scene keys **PosUp** / **PosDn** (`sexlab.hud.key_pos_up` PgUp, `sexlab.hud.key_pos_down` PgDn) in a new column left of Num 7 / Num 4; the HUD controls grid is now 5 x 3. `Menu.Hud_OnKey pos_up|pos_down` → `Scene.HotkeyChangePositions` (SexLab `ChangePositions`, then `AlignActors`). New `sexlab.hud.pos_narration` (**Narrate position changes**, on) narrates "The scene changes to <stage description>" with the new roles
- Camera: `Hud.cpp` `Tick` edge-detects `IsInFreeCameraMode()` true to false mid-scene and calls `Menu.Hud_OnKey("camera_lock")` (ForceThirdPerson if first person, `EnablePlayerControls` look/camswitch only). `Scene_Manager` records `Game.GetCameraState()` on `HookAnimationStarting` (before SexLab forces third person) and on `HookAnimationEnd`, once the player has no active thread, turns TFC off and restores first/third person (`RestoreCameraAfterScene`).
- `sexlab.minigame.mouse` (**Allow right mouse to arouse and left mouse to calm**) now defaults to on (manifest `defaultValue` + `Hud.cpp` fallback). A value already saved in settings.yaml is kept

## [0.35.0](https://github.com/GoodProvider/SkyrimNet_SexLab/releases/tag/0.35.0) — since [0.34.1](https://github.com/GoodProvider/SkyrimNet_SexLab/releases/tag/0.34.1)

### Actions / scenes
- `nonsexual_male_position_0/1/2` now match `nonsexual`: `strict`, `tags_any` cuddling/hug/spooning/kissing/headpat/handholding/lappillow, and the full sex-act suppress list. LLM `SexLab_Nonsexual_Cuddle` / `SexLabComfortCuddle` send `sitting|laying` as the method tag; with no `tags_any` and a non-strict setting, the posture alone (or the step-3 fallback that peels suppress tags) picked sex animations
- New LLM action `SexLab_Change_Style` (speaker + `forcefully|normally|gently`) changes the style of the speaker's live scene, with one DirectNarration
- New LLM mini-game actions `SexLab_Arouse` / `SexLab_Calm` and `SexLab_AllowOrgasm` / `SexLab_DenyOrgasm` (`speaker` + dynamic `target`, eligible while the speaker is in `SexLabAnimatingFaction`; `MCM.ApplyMiniGameActions` unregisters them while the mini-game is off). See [docs/authors/actions.md](docs/authors/actions.md)
- New `SexLab_Nonsexual_Cuddle`; `SexLab_Nonsexual_Accepted` renamed `SexLab_Nonsexual_General`
- LLM outfit actions `change_outfit` / `change_outfit_target` replaced by `outfit_dress` / `outfit_undress` (`Outfit_Dress` / `Outfit_Undress`); helper `helpers/sexlab/none_change_outfit` removed
- Dual-ship LLM actions and prompts: canonical `external/goodprovider.sexlab/` plus pre-0.25 copies at `config/actions/` and `prompts/` (`tools/sync_legacy_skyrimnet_content.py`)
- Scene settings gain `tags_any` (at least one), `tags_prefer` (soft OR), `tags_suppress_unless_bound` (only while nobody wears DD heavy bondage), `exclude_settings` (drop animations another setting would pick), `synonyms` (default `broad`; widens every tag key, suppress included), `strict` (the fallback never drops suppress / `tags_any` / `exclude_settings`) and `gender_match`. C++ `AnimationDB::ApplySceneSetting` applies them on every query that carries `_setting` (Papyrus `QuerySexLabAnimsFromAnimDb`, TargetMenu random/resolve, `ExecuteAction`, Scene Creator draft filter); `ResolveTags` / `AppendMatchingTags` take the setting as a base so a method leaf never resolves to tags the setting then empties. See [docs/reference/scene-settings.md](docs/reference/scene-settings.md)
- TargetMenu review: on Start (method random) only the scene setting filtered, so sex and rapes drew from all 411 two-actor animations and cuddle/punish from pools full of sex animations. New `consensual` (sex), `nonsexual` rewritten as **affection** (was *cuddle*), new **platonic** option + `nonsexual_platonic` (no kissing), `punish_spanking*` strict + any gender, `punish_pleasure_pain_rape` = everything but affection/platonic, preferring aggressive. `default.json`: `synonyms: broad`, `tags_suppress_unless_bound: armbinder,yoke,cuffs,bound`. Punish option `methodSettings` sends **whip** to `punish_whipping_oral`, which sets new key `assume_bound` so its DD-only whip animations are never gated
- `AnimDb_CsvHasTag` matches through strict clusters (`kiss` = `kissing`). The kissing → `nonsexual_kissing` switch skips `nonsexual_platonic`
- Tag synonyms: `synonyms-strict.json` (true equivalents) and `synonyms-broad.json` (default; adds families) in `SKSE/Plugins/SkyrimNet_SexLab/` group tags into clusters. A must or suppress tag matches every animation tagged with any member of its cluster. The clusters were curated from all 274 tags in the 531-animation AnimDB. Mode parameter `_synonyms` (`broad|strict|none`) on AnimDB filters, `AnimDb_ResolveTags(…, synonyms = "broad")` and `onAnimDbResolveTags`. Reloaded at `kDataLoaded`, on every game load, and on AnimDB sync/rebuild. See [docs/reference/tag-synonyms.md](docs/reference/tag-synonyms.md)
- Scene starts no longer call `SexLab.GetAnimationsByTags` (literal tags only). All tag-based selection goes through AnimDB (`SelectAnimationsFromAnimDb`, formerly `SelectAnimationsAnimDbNoneFallback`) with a new `_shuffle` filter key, so starts pick a random 32 matches instead of the alphabetically first 32
- Live scenes now apply the animation's speaking modifiers (as shown in the Description Editor, per stage) at every `StageStart`, so a position with orgasm not expected / empty speaking no longer keeps the creator's `_pleasure_`. Live speaking edits stay until Save or an animation switch
- Scenes started without "override animation settings" now begin each actor in the clothed state most candidate animations share (new `AnimDb_ClothedMajority` native; tie → undressed), so an all-dressed animation set (hug, kiss) no longer strips then re-dresses at the first stage
- Stop auto-rebuilding AnimDB on load. If counts differ from SexLab after SexLab is ready, notify `SkyrimNet SexLab # animations doesn't match` and show a SkyMessage (empty → Build/Close; mismatch → Rebuild/Close)

### Orgasm / narration
- Slower default enjoyment: `sexlab.enjoyment.passive_mult` 1.0 → 0.4, `aggressor_mult` 1.15 → 0.45, `victim_mult` 0.8 → 0.3, `jitter_max` 1.2 → 1.1. Logs showed scenes running 2–3.5× their stage timers (narration / LLM pacing), so actors orgasmed every ~50 s. Saved configs keep their old values; reset the **Enjoyment** settings to pick up the new defaults
- Pausing the stage advance (pause key) no longer stops passive enjoyment gain; it continues as normal. The pause still holds the stage timer and the final-stage safety-net clocks
- New **Scene ending** settings (`sexlab.ending.*`). The lead (aggressor with a victim, else the initiator) gets a target orgasm count at scene start (male 1-1, female 1-2, ranges configurable); reaching it jumps the scene to the final stage (`Scene.Ending_Check` → `GoToStage`)
- The final stage is then held until the orgasm dialogue has played (SkyrimNet speech queue empty + audio ended), at most `sexlab.ending.dialogue_hold_max` (45 s)
- Orgasm gate replaces the final-stage safety net for timed scenes (`sexlab.ending.gate`): each actor who hasn't orgasmed rolls once, chance = enjoyment %, `lead` seconds before the second-to-last stage ends (or on reaching the final stage first). `lead` = `NarrationTiming::EstimateSeconds` (median of the last 20 clean DN->speech samples; `sexlab.ending.gate_lead_default` 5 s until 3 exist). A pass sends the combined orgasm DN at once (`Effect_GatePassed` -> `Scene.Engine_GatePassed`, DirectNarration even in NPC-only scenes), holds the stage, and rushes the bar to 98 by the expected voice. The first non-player `SkyrimNet_SpeechStarted` after the DN (`GateNarrationSent` mark, `NarrationTiming::SpeechStarts`) pushes the final stage (`Effect_AdvanceToFinal`); the rush finishes within 1 s there and fires at 97 as a `gate` group (ForceOrgasm only, no second DN). No voice by `sexlab.ending.gate_wait_max` (20 s): advances anyway. All fail: no orgasm. Logs showed the old net (needs 90) skipping everyone at 38-86
- Each stage advance adds `sexlab.enjoyment.stage_spike` (5) enjoyment
- New `sexlab.enjoyment.group_join_final` (80): the group-join threshold in the final stage and for the gate (anyone that close, repeat orgasms too, rushes with a gate passer into the same DN). New native `FinalStageRemaining(sid)`
- Final-stage narration: orgasms go through the orgasm window and fold into the `… finish` DN when the stage ends inside the window cap (`Scene.OrgasmWindow_HoldForFinish`); no `continue activity` DN at final-stage StageStart (a scene change is an event); `NarrateOrgasmStash` re-entrancy guard (concurrent groups crossed their sentences)
- Group join is now a roll: when anyone orgasms, every other actor rolls once (chance = enjoyment %). `sexlab.enjoyment.group_join` removed
- Early final roll: in the second-to-last stage, when the lead's orgasm (after the group roll) reaches their target, everyone still out rolls again with the passive enjoyment left until the scene ends (rest of that stage + the final stage), so they finish in the same DN. A fail means no more orgasms this scene (forced still works). New native `SetEndingTarget(sid, lead, target)`
- The lead's target jumps to the final stage only from the second-to-last stage; earlier, the scene runs on
- An aggressive NPC lead reaching their target, at any stage, holds the stage until the orgasm dialogue has played, then ends the animation
- `sexlab.enjoyment.group_join_final` default 80 → 90 (now only the gate-pass join)
- Orgasm narration: the not-orgasming and denied sentences scale with live enjoyment. 0–30 `Nina is not orgasming right now.`, 31–60 `Though aroused, …`, 61–89 `Although close, …`, 90+ `Although on the edge, …`. Denied now reads `<lead-in>Nina was denied an orgasm by Bob.` Actors are grouped per band (`Scene.EnjoymentBand` / `BandLeadIn`)
- `Scene.Setup`: receiver falls back to the first other position when it equals sender (WebUI initiator pulldown gave "Bob and Bob")
- A scene stopped by someone (Stop dialog, TargetMenu stop, LLM `SEXLAB_STOP`) now narrates who stopped it before the finish text: "Bob gently stops showing affection. Bob and Camilla Valerius finish showing affection." (`forcefully` / `gently` shown, `normally` omitted). A custom / explain stop adds the reason: "Bob stops the scene, because <reason>. Bob and Camilla Valerius finish." Natural scene ends are unchanged
- Fixed custom (explain) stop text being ignored and silent stops still narrating: `Scene.AnimationEnd`'s `style` parameter was shadowed by the scene's `style` property, so it always saw the scene style (e.g. `normally`)
- Scenes with a victim but no intent now narrate "Camilla Valerius and Bob start / finish." instead of "Bob finish Camilla Valerius."
- Fixed a scene started from the WebUI sometimes getting a second, intent-less scene on the same SexLab thread (a lookup during `StartThread` adopted the thread before the creator bound it), so a stop could narrate "Bob and Camilla Valerius finish." with no intent. `GetSceneByThread` no longer adopts a thread while its actors are creator-locked
- DirectNarrations made while the game is paused (WebUI overlay or a pausing menu) are queued in the DLL and sent as one joined DirectNarration once the game unpauses. Fixes NPC responses failing ("failed to generate a response") after WebUI actions such as the Description Editor style pulldown, because SkyrimNet cannot run Papyrus decorators while paused
- DirectNarration → first speech latency is logged (`NarrationTiming.cpp`). The DLL stamps each DirectNarration it hands to SkyrimNet and stops the clock on SkyrimNet's `SkyrimNet_SpeechStarted` mod event. Each sample is one `NarrationTiming: DN->speech` line in `SkyrimNet_SexLab.log` with the speaker, the message and running clean-sample mean / median / p90 / min / max. Samples sent while speech was already playing (`busy`) or with more narrations sent before the speech (`overlapped`) are counted but kept out of the stats; no speech within 60 s counts as `missed`
- SexLab moans now follow speaking modifiers: an actor moans only while its modifiers include `_pleasure_` or `_pain_`; no modifiers, `_gagged_`, or `_kissing_` force the actor silent (`thread.SetVoice(..., ForceSilent)`). Re-applied at scene setup, every `StageStart`, live speaking edits, and after a load. Dashboard toggle **SexLab moans follow speaking modifiers** (`sexlab.voice.follow_speaking`, default on). See [docs/reference/protocol-tokens.md](docs/reference/protocol-tokens.md#sexlab-voice)
- `Scene.OrgasmCustom` drops a DOM melt when the actor's `no_orgasm` is 1 (`orgasm_expected` 0): no stash, no `total_orgasm` bump, no `" is orgasming."`. DOM rolls its own orgasm and ignores SexLab `DisableOrgasm`
- New character-bio submodule `0416_sexlab_cum.prompt` (`sexlab_cum` decorator, recorded by `Scene.AddCum`): warm cum on mouth / pussy / ass for the first game hour, then drying until `sexlab.cum.duration_hours` (default 4); cleared by swimming. No plugin gate (renders with UDNG); a clothed actor seen from outside shows only the mouth

### Papyrus
- New C++ JSON store (`SKSE_Source/src/JsonStore.cpp`, Papyrus `SNSL_JMap` / `SNSL_JArray` / `SNSL_JValue` / `SNSL_JFormMap`, same signatures as JContainers) for the scene-menu build path and per-position / animation-default state in `Scene`, `Scene_Manager` and `Scene_Creator` (including `user_anim_defaults`). No garbage collector and one-call serialization, so the Description Editor no longer gets `NULL` text or dropped keys from JContainers collecting objects mid-walk. JContainers is still required by the rest of the scripts
- `SetActor` keeps `total_orgasm` / `orgasm_narrated` when the actor is already bound to the scene (animation change, O toggle and WebUI edits no longer reset them). `TM_SetClothed` uses SexLab Strip / UnStrip for scene actors; `Outfit_Dress` / `Outfit_Undress` only outside a scene. Live victim toggles refresh factions, victim / assailant flags and names (`RefreshVictimRoles`)
- `0050_sexlab_activity.prompt`: Inja literal `True` → `true` (creature scenes). Narration max distance reads `sexlab.narration.max_distance`. Stop → explain: typed narration reaches `AnimationEnd`

### SKSE / WebUI
- TargetMenu **bondage** is in the Scene catalog too (`TargetMenu/Scene/options/0600_sexlab_bondage.json`, copy of the Actor one; FOMOD installs both). `WebUI_MaybeRestoreScenePanel` now opens the Scene view whenever the focus is in SexLab (Description Editor), not only with `show_scene_panel`. Removed the Scene-root **Editor** row (`0050_editor.json`) and the JS `scene_editor` type
- LLM-started scene gating dialogue (`YesNo_Open`) is now a centered modal. WebUI open: shown on top (`showYesNoDialog`), answers leave the view as it was (`YesNo_OverlayWasOpen`). WebUI closed: dialogue only (one Invoke `openYesNoSolo(cfg)` before `WebUI_Visibility_Show(false)`; separate hide/show Invokes arrived out of order and sometimes hid the dialogue; hides the ControlPanel / main panels inline and makes `showControlPanel` a no-op until `clearYesNoSolo`; the dialogue lives in its own `#yesno-overlay` layer because a fixed panel inside `#overlay-panels` rendered invisible); Yes keeps it as an "Opening Scene Creator…" placeholder until `SceneCreator_Open`; Yes (Random) / No (Silent) / No close the WebUI. New **No, explain** (button 4): textarea + Accept / Cancel; Accept → `Manager.WebUI_OnYesNoExplain` → `Creator.RejectWithReason` DirectNarration "<player> rejects <requester>'s request for <intent>, because <reason>.", no scene. Buttons top-aligned
- New `sexlab.minigame.mouse` (**Allow right mouse to arouse and left mouse to calm**, off): with the mini-game on, RMB arouses and LMB calms the HUD focus actor alongside the numpad keys. Fixed HUD keys (DX 257 / 256), swallowed while the HUD is up; listed in `hotkey-map.json` as `arouse_mouse` / `calm_mouse`
- Scene style now sets animation playback speed: gently 0.75×, normally 1.0×, forcefully 1.4× (dashboard **Animation speed**: `sexlab.speed.enabled`, `sexlab.speed.gently|normally|forcefully`). Speed only: stage length, orgasm timing and voices are unchanged. Native `UpdateAnimation` hook in `SkyrimNet_SexLab.dll` (`AnimSpeed.cpp`); Papyrus `SkyrimNet_SexLab_Utilities.SetAnimSpeed` / `ClearAnimSpeed` / `GetAnimSpeed`
- The WebUI style control also changes speed live. The style hotkey (`sexlab.style.hotkey*`, `]`) was removed; the HUD slower / faster keys cover it
- Scene keys default to the numpad, laid out like the HUD grid: calm Num 8, arouse Num 9, deny Num 1, slower Num -; previous Num 4, pause Num 5, next Num 6, end Num 2, faster Num +. Num 3 stays SexLab's free camera (shown in the HUD, not bound); Num 7 is left to SkyrimNet. Manifest `defaultValue`s and `Hud.cpp` `kBindings` changed; `\` (menu) unchanged. Saved dashboard keys are not migrated
- HUD controls are a fixed 4 x 3 grid laid out like the numpad (`hud.html`): `(Num 7) calm arouse <slower>` / `prev pause next <faster>` / `deny end free📷`, each cell one equal-width box with the key above its label. Every cell carries all labels its column can show as hidden sizers, so column widths never change; the 📷 is drawn at 0.75em. Labels name what a press does: pause / play; slower / faster show the speed level they step to (`Hud.cpp` sends `slower` / `faster`, `""` → dimmed `—` at either end) in place of the old `Paused` tag and speed readout. `keys.free` is SexLab's free camera (Num 3) and `keys.skyrimnet` is Num 7 (dimmed, no label), display only. `freeCam` (`PlayerCamera::IsInFreeCameraMode`) switches the Num 3 label to *lock*
- Speed levels cut to three: gentle 0.75, normal 1.0, forceful 1.25 (`OrgasmEngine::kSpeedLevels`). Papyrus `GetSpeedLevel` is now 0 gentle, 1 normal, 2 forceful
- New `Data/SKSE/Plugins/SkyrimNet_SexLab/hotkey-map.json`, written by `Config::WriteHotkeyMap` on game start, load and dashboard save, lists every live binding (control, dashboard path, VK, DX, key name, enabled)
- New dashboard toggle **Devious devices are added to tags** (`sexlab.tags.filter_by_devious_devices`, default on): when cast members wear DD heavy bondage, every TargetMenu scene start adds `armbinder` / `yoke` / `cuffs` / `bound` through one pipeline. C++ `BondageCatalog::WornAnimationTags` does a worn keyword scan with no DD dependency. The paths that use it:
  - Method leaf / Start and DOM punish rape: `onAnimDbResolveTags {_form_ids}` → `AnimationDB::AppendMatchingTags`, which keeps the method first.
  - Random: `requestDeviousTags` → `_must_tags`.
  - Scene Creator / Description Editor filter: include tags the player can remove, and removed tags stay removed for the session.
  - YAML action Start: `ExecuteAction`.

  Tags with no matching animation are dropped before any other filter loosening
- One **Scene** view replaces the separate Scene Menu and Description Editor views: it shows the Description Editor when the ControlPanel target is in a SexLab scene, otherwise the Scene Creator, and switches when the target changes or the target's scene starts or ends. The Description Editor's **scene:** pulldown (None / Any / ended scene) is gone; it always edits the target's scene. The view stays open across hotkey presses until you press **Close** (`show_scene_panel`, was `show_scene_creator`)
- Every main panel (Scene, Log, Settings, mode panels) has a **Close** button in the same top-right spot; it returns the view to None and keeps the WebUI open. Scene Creator's own Close button is gone
- The ControlPanel main-panel pulldown now shows **None** whenever no main panel is shown (e.g. after starting a scene from Scene Creator or closing the animation menu)
- Description Editor Save / Cancel / Close buttons are now vertically aligned
- Scene HUD is now two parts: the stage row and actor enjoyment rows (**Show enjoyment bars**) and the controls row (everything else). Fixed the HUD disappearing with **Show enjoyment bars** off
- **Escape** now closes the WebUI and applies your changes, like the hotkey. It no longer closes just the main panel
- Description Editor **Cancel** closes the WebUI and puts each live scene back the way it was when you opened the WebUI: animation list, playing animation, stage, style, each actor's orgasm / speaking / dressed settings, re-dressing anyone undressed since. Stage text already saved stays saved
- Description Editor bottom tabs: **stage descriptions** (the stage table, default) and **animation filter**, whose top row puts the Scene Creator tag / suppress / gender / description filters and a **name** filter (part of the animation name, matched in the DLL) on the left and **SexLab current animations** (the scene's loaded list, scrolling to the filters' height, at least five rows) on the right, with the filtered animations full width below. Clicking a loaded or filtered animation makes it the editor's current animation at once (previewing its stages and actor defaults) and switches the scene to it when the game unpauses (**play**, hotkey, Escape or Save). A filtered animation is added to SexLab's loaded list first
- Fixed adding an animation from the Description Editor replacing the first animation in SexLab's loaded list, so after a reopen the list seemed to be missing the new animation. SexLab's `AddAnimation` overwrote index 0; the list is now rebuilt with the new animation appended. This also works when the scene uses a forced animation list
- Fixed the Description Editor **animation filter** list showing only the playing animation: the scene's pushes put that animation's tags into the include-tag filter, so the animDB query required all of them
- Animation changes mid-scene reload the new animation's orgasm and speaking modifiers, and only ever undress: an actor undressed by one animation stays undressed when the next animation defaults to clothed
- TargetMenu scene-start panel: every field is now a **pulldown_cascade** — shows the current value and opens cascade columns (hover drill, like the TargetMenu) to change it. The **method** row is a direction → method tree that reads `random`: picking a method starts the scene and closes the WebUI; `random` (or Start) has AnimDB pick 3 related animations (one random plus the two sharing the most tags) for the cast and scene setting
- TargetMenu scene-start panel (sex, affection, punish, masturbation, rapes) reorganized: `[Start] style` / **with** / **and** / **victim** / **method** / **intent** / **scene setting**. Subject / Object / relation rows and the Custom button are gone. Target is always in the scene; if **with** is the player the player is the subject, otherwise Target is. **victim** lists only the scene's actors (default Target for rapes / punish, none otherwise); any victim starts a nonconsensual scene. The method cascade's direction column adds **random** (default), which lists every method and picks a direction the method allows. The **raped by** option is removed (use rapes and set the victim)
- SKSE build: SkyrimNet `PublicAPI.h` include path is now `mods/SkyrimNet devkit/CppAPI`
- Description Editor: the Actor table has a new first column with an **orgasm** button per actor (live scenes only). It runs SexLab `ForceOrgasm` on that actor and narrates it once: through the normal SexLab orgasm event when that event would narrate (SeparateOrgasms on, orgasm expected, not a DOM slave), otherwise through `OrgasmCustom`. A press narrates even when orgasm is set to not expected
- Description Editor: new **Stop** button right of Save (shown for a live scene) opens a **Stop scene** dialog: forcefully / normally / gently / silently stop the picked scene and close the WebUI; **custom** opens **Explain why** (text + Submit / Cancel) to stop with your own narration; Cancel just closes the dialog
- TargetMenu → Scene → stop: **stop** / **silent** did nothing when the Scene Creator draft wasn't bound to the live scene (the stop was committed for scene -1 and dropped); they now stop the target's live scene. **explain** now opens the **Explain why** dialog (`window.prompt` doesn't work in PrismaUI, so nothing opened)
- Description Editor: new **style** pulldown left of Save (live scenes only). Changing it sets the scene's style (and animation speed) and sends one "changes from 'x' to 'y'" DirectNarration
- Scene Creator layout: title is now "Scene Creator" with the style pulldown beside Start / Cancel; the range pulldown moved under the actor table; the activity field and the scene-setting preset pulldown / Save dialogs are removed. New **Save** next to "override animation settings" writes the actor table's dressed / O / modifiers to the selected animation (`onAnimRegistrySave`, stage descriptions untouched); disabled unless override is on and exactly one animation with a matching position count is selected
- Scene Creator: the animation list starts with one animation selected; click selects just that row (click again to deselect), Ctrl+click adds rows. Each added animation reorders actors to match its position genders when possible and sets the dressed / O / modifiers columns from its defaults
- Menu hotkey mid-scene with the crosshair on a non-participant (e.g. a DOM mistress) now focuses the player, so the Description Editor opens instead of staying on TargetMenu
- Menu hotkey always toggles ControlPanel: hide immediately when the overlay is visible (any focus actor); open TargetMenu only when hidden
- Ship `PrismaUI/views/SkyrimNet_SexLab/index.html` in the FOMOD zip (`make release` copies `PrismaUI/` into `core`)
- Do not Show/Focus the overlay until DomReady; Escape Unfocus/Hide if the view never loaded (missing HTML no longer pauses the game with a blank overlay)
- Description Editor: with an active scene picked, ◀ previous / next ▶ move the live scene stage and `copy previous` copies the prior stage text; names are buttons that insert `{{sl.actors.N}}` into the active stage; tags on their own right-aligned row; Save now closes the WebUI
- Description Editor: stage nav and tags sit in a bottom-aligned panel beside the actor table (tags above the nav buttons); the names row is gone and actor-table names are buttons that insert `{{sl.actors.N}}`; hint line below both panels; new play/pause button between previous and next toggles the game pause (`onGamePauseSet` → PrismaUI `Unfocus` + `Focus(view, pauseGame)`; resets to paused on Show/Hide), hint moved under the actor table; every action button autosaves dirty descriptions to disk without closing; new **continue scene** button sends DirectNarration "The scene changes to …" with the active stage's description (`onSceneNarrate`)
- Description Editor: the SexLab thread is the source of truth for the stage. ◀/▶ send a relative `_stage_step` (resolved on `thread.stage`); right after `GoToStage` (which sets `thread.stage` synchronously) Papyrus pushes `thread.stage` to the editor, and `StageStart` (also when the game advances on its own) first pushes `thread.stage` as a light `_stage_only` update that moves the active row/nav without reloading stage text; commits dropped while the thread is Advancing, or that change nothing, resync the editor; `BuildWebUISceneMenuState` traces `stage:N/M`
- Description Editor: fixed ◀/▶ while the game is paused stranding the SexLab thread in `Advancing` (later clicks then showed a "dropped (thread not active)" notification). A step now auto-unpauses and re-pauses at `StageStart`; the nav stays greyed until the thread reaches `StageStart` (`_stage_started`); dropped commits are logged only, no on-screen notification
- Description Editor: opening on an active scene no longer rebuilds the scene state up to three times. Stage rows come from one `AnimDb_GetStagesJson` native call instead of 2+ natives per stage (with an O(stages²) backward walk), `AnimationDB::GetStageDescription` / `GetTransition` no longer copy the whole `AnimRow`, and the hotkey open no longer dispatches `WebUI_ConfigureFocusScene` (the overlay-Show seed already carries the scene)
- Description Editor: new per-actor **Actor table** (`#`, name, `O`, speaking modifiers) edits the animation's `orgasm_expected` / `speaking_modifiers`; Save writes them only when edited (`WebUI_OnAnimRegistrySave` now persists `speaking_modifiers`), scene picks load the row via new `onAnimDbQuery` `_type:"anim"`; the **names:** row now sits directly above the stage table
- Description Editor Actor table: **clothed / unclothed** column (anidata `clothed`, saved with orgasm-expected and speaking modifiers), orgasm column shows **O** (expected) or **-**, and actors can be swapped between positions
- New **synonyms** pulldown in the Scene Creator and Description Editor animation filters (shared state, resets to `broad` on close). Scene Creator starts pass the mode to Papyrus (`_synonyms` → `Scene_Creator.synonyms_mode`)
- Scene Creator stays open until closed, starts with one animation selected, adds the selected animation's tags to its filter, and **override animation settings** (`overwrite_toggle`) is off by default
- Third-party ControlPanel modes: JSON dropped into `SKSE/Plugins/SkyrimNet_SexLab/webui/ControlPanel/` is loaded as a ControlPanel mode (`ActionCatalog::LoadControlModes`; mode pulldown, `data_table` / `actor_detail` panels). Papyrus `SkyrimNet_SexLab_WebUI.PushMainPanelData` / `GetFocusActor` / `GetFocusKind`
- DLL hardening: TargetMenu focus actor kept as an `ActorHandle` and cleared on load / new game; non-UTF-8 game strings no longer throw on JSON dump (`SafeDump`); every PrismaUI listener runs guarded and one bad TargetMenu option file is skipped instead of breaking the menu; JSON store writes go through a `.tmp` + move
- WebUI lost-edit fixes: Scene Menu Stop / Update and TargetMenu Stage / Position Done commit at once, so Escape no longer drops them; the Description Editor saves before an animation switch, a focus change and Escape; Scene Creator nearby adds fill only their own row and count toward the 5-actor limit

### Animations
- AniDescriber defaults to tags; HKX inference is disabled (missing stage descriptions fall back to tag text). See [docs/developers/anidescriber.md](docs/developers/anidescriber.md)
- Token stage JSON under `SKSE/Plugins/SkyrimNet_SexLab/animations/` refreshed: several files renamed to their SexLab animation ids (e.g. `Billyy Amazon.json` → `B_B_Amazon.json`), unused Billyy chair / facefuck entries removed

### Install / MCM
- Plugin `manifest.json` / settings `plugin.version` **0.35.0**
- UDNG handler package now carries `webui/TargetMenu/Actor|Scene/options/0600_sexlab_bondage.json` and `bondage/group-devices.json` so the FOMOD entries resolve
- TargetMenu **leash** option and its prompts moved to the SkyrimNet_Leashed plugin (`0700_leash.json` / `0700_sexlab_leash.json` removed)

### Docs
- Hotkeys and numpad layout: [docs/players/hotkeys.md](docs/players/hotkeys.md)
- Tag synonyms: [docs/reference/tag-synonyms.md](docs/reference/tag-synonyms.md); scene setting keys: [docs/reference/scene-settings.md](docs/reference/scene-settings.md)
- Orgasm engine, scene ending and gate: [docs/developers/orgasm-engine.md](docs/developers/orgasm-engine.md); narration bands: [docs/reference/orgasm-narration.md](docs/reference/orgasm-narration.md)
- WebUI Scene view, Description Editor and ControlPanel drop-ins: [docs/developers/webui.md](docs/developers/webui.md)

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
