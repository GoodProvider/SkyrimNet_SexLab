# OStimNet: how the SKSE plugin uses SkyrimNet custom LLM calls

This is an agent-facing summary of how `extern/OStimNet/SKSE_Source` sends "Game Master" evaluations through SkyrimNet's `PublicSendCustomPromptToLLM`. It covers:

- how the context is built;
- which prompt is rendered;
- how the JSON answer gets back to the game;
- how failures are handled.

Use it as a reference pattern before you write a similar evaluation for SexLab.

These are not in-character NPC dialogue, and they are not SkyrimNet actions. OStimNet uses the LLM as an out-of-character judge. Typical questions are "who is willing, and in what role?", "which position next?" and "pull out or not?". The judge returns strict JSON, and C++ turns that JSON into game state or a Papyrus mod event.

All paths below are relative to `extern/OStimNet/`. `SkyrimNetIntegration.cpp` means `SKSE_Source/src/SkyrimNetIntegration.cpp`.

---

## 1. API surface

Header: [SKSE_Source/src/api/SkyrimNet_PublicAPI.h](../extern/OStimNet/SKSE_Source/src/api/SkyrimNet_PublicAPI.h)

```cpp
// v8+
bool (*PublicSendCustomPromptToLLM)(const char* promptName, const char* variant,
                                    const char* contextJson,
                                    std::function<void(const char* response, int success)> callback);
```

| Arg / return | Meaning |
|---|---|
| `promptName` | The template path, relative to the bundle's `prompts/` root and without `.prompt`. |
| `variant` | The SkyrimNet LLM variant (model profile). `""` means the default. |
| `contextJson` | A JSON object whose keys are injected as template variables before rendering. |
| `callback` | Runs on a **SkyrimNet ThreadPool worker**. `success` is 1 or 0. `response` is the raw LLM text, or an error string. The pointer is only valid for the duration of the call. |
| return | `true` means the request was queued. `false` means it failed immediately. |

Other API functions the LLM path relies on:

| Function | Ver | Used for |
|---|---|---|
| `FindFunctions()` | – | Loads `SkyrimNet.dll` with `LoadLibraryA` and resolves every pointer with `GetProcAddress`. It is called once from `kDataLoaded` ([plugin.cpp:220](../extern/OStimNet/SKSE_Source/plugin.cpp#L220)) through `SkyrimNetIntegration::InitSkyrimNetAPI()`. A pointer from a newer API version stays `nullptr` on an older SkyrimNet, so **every call site null-checks it**. |
| `PublicFormIDToUUID(formId)` | – | Converts actors to SkyrimNet UUIDs for the template. See `ActorToUUID` / `ActorRefIDToUUID` ([SkyrimNetIntegration.cpp:68](../extern/OStimNet/SKSE_Source/src/SkyrimNetIntegration.cpp#L68)). |
| `PublicRegisterDecorator(name, desc, fn(Actor*)→string)` | v5 | Registers the data the templates *pull* (§3). |
| `PublicGetPluginConfigValue(plugin, path, default)` | – | Live settings, including the variant (§4). |

---

## 2. Call sites at a glance

All eight live in [SkyrimNetIntegration.cpp](../extern/OStimNet/SKSE_Source/src/SkyrimNetIntegration.cpp). The prompts live in `SKSE/Plugins/SkyrimNet/external/tetherball88.ostimnet/prompts/ostimnet_evaluations/`.

| C++ function (line) | Trigger | Prompt (`ostimnet_evaluations/…`) | Response JSON | Output |
|---|---|---|---|---|
| `EvaluatePreStartSexualScene` ([L819](../extern/OStimNet/SKSE_Source/src/SkyrimNetIntegration.cpp#L819)) | Papyrus native `OStimNet.EvaluatePreStartSexualScene`, called by the StartNewSex / StartCareScene flows | `ostimnet_evaluate_prestart_sexual` | `{reason, scene:{mainActors[], secondaryActors[], sexualPosition, sexualActivity} \| null}` | Mod event `ostimnet_sexual_evaluation_finished` |
| `EvaluateExternalSexualThread` ([L1016](../extern/OStimNet/SKSE_Source/src/SkyrimNetIntegration.cpp#L1016)) | `OStimEventListener::HandleStart` for a thread OStimNet did not start ([OStimEventListener.h:279](../extern/OStimNet/SKSE_Source/src/OStimEventListener.h#L279)), or the Papyrus native | `ostimnet_evaluate_external_sexual_thread` | `{reason, scene:{intent, mainActors[], secondaryActors[]} \| null}` | **No event.** It writes `ThreadDataStore` (OStimNet flag, intent, sexual, roles) directly and calls `ClaimPendingNonOStimNetThread`. |
| `EvaluateNonSexualScene` ([L1190](../extern/OStimNet/SKSE_Source/src/SkyrimNetIntegration.cpp#L1190)) | Papyrus native | `ostimnet_evaluate_nonsexual_scene` | `{start: bool, ...}` | `ostimnet_nonsexual_evaluation_finished`. Roles are not taken from the LLM: main = initiator, secondary = everyone else. |
| `EvaluateJoinOngoingSex` ([L1357](../extern/OStimNet/SKSE_Source/src/SkyrimNetIntegration.cpp#L1357)) | Papyrus native | `ostimnet_evaluate_join_ongoing_sex` | `{scene:{intent, mainActors[], secondaryActors[]} \| null}` | `ostimnet_join_sex_evaluation_finished` |
| `EvaluateInviteToSex` ([L1523](../extern/OStimNet/SKSE_Source/src/SkyrimNetIntegration.cpp#L1523)) | Papyrus native | `ostimnet_evaluate_invite_to_sex` | same as join | `ostimnet_invite_sex_evaluation_finished` |
| `EvaluateLocationScan` ([L1707](../extern/OStimNet/SKSE_Source/src/SkyrimNetIntegration.cpp#L1707)) | `LocationScanService::RunScan`: a meaningful cell/location change (fingerprint), then a delay, a cooldown and a location-type filter, with no OStim thread active. The manual hotkey forces a scan ([plugin.cpp:120](../extern/OStimNet/SKSE_Source/plugin.cpp#L120)). | `ostimnet_scan_location` | `{reason, scene:{intent, mainActors[], secondaryActors[], sexualPosition, sexualActivity, furniture} \| null}` | `ostimnet_location_scan_result` |
| `EvaluateScheduledSceneAdvance` ([L1840](../extern/OStimNet/SKSE_Source/src/SkyrimNetIntegration.cpp#L1840)) | The `ScheduledEvalService` background loop, once the per-thread interval has elapsed (`tton.gameMaster.scheduledEvalIntervalSeconds`, with a player/NPC toggle each), or `TriggerPlayerAdvance` | `ostimnet_evaluate_scene_advance` | `{scene:{sexualPosition, sexualActivity} \| null}` | `ostimnet_scene_change_schedule_finished`, plus `onDone()` on every terminal path to clear the in-flight lock |
| `EvaluatePulloutDecision` ([L1957](../extern/OStimNet/SKSE_Source/src/SkyrimNetIntegration.cpp#L1957)) | `PulloutService::CheckActiveThreads`: the thread is stalled at the climax edge and no actor answered through the `PulloutDecision` action within the timeout ([PulloutService.cpp:683](../extern/OStimNet/SKSE_Source/src/PulloutService.cpp#L683)) | `ostimnet_evaluate_pullout_decision` | `{reason, decision:"pullout"\|"finish_inside"}` | `PulloutService::OnLLMDecision` / `OnLLMFailure`. A missing `decision` defaults to `finish_inside`. |

**Mod-event `numArg` codes:**

| numArg | Meaning |
|---|---|
| `1.0` | Success. |
| `2.0` | `scene: null`, `start:false`, or not enough participants. |
| `3.0` | The LLM excluded some of the original participants (prestart and location scan only). |
| `0.0` | The player picked **Ignore** on the failure modal. |

`strArg` carries a result JSON of **FormIDs** (uint32), not UUIDs or names. Common keys are `main`, `secondary`, `originalParticipants`, `excluded`, `intent`, `evalId`, `threadID`, `sexualPosition` and `sexualActivities`. `evalId` is an opaque string that Papyrus passes in and gets back, so it can match the response to its request.

The Papyrus consumers are registered in [Scripts/Source/TTON_MainController.psc:43-50](../extern/OStimNet/Scripts/Source/TTON_MainController.psc#L43). The natives are bound in [SKSE_Source/src/Papyrus/PapyrusFunctions.h:701-718](../extern/OStimNet/SKSE_Source/src/Papyrus/PapyrusFunctions.h#L701), which lower-cases `intent`/`activity` before the call.

---

## 3. How the context is built: push vs pull

Context reaches the prompt by two channels. C++ sends **identities and the few facts only it knows**. The template **pulls everything heavy** (bios, memories, events) at render time through SkyrimNet built-ins and OStimNet decorators.

### 3a. Push: `contextJson` built in C++

Every `Evaluate*` builds a small `nlohmann::json` on the calling thread and passes `ctx.dump()`:

| Key | Type | Built from | Used by |
|---|---|---|---|
| `actors` | `[uuid]` | `ActorRefIDToUUID(fid)` for each participant | prestart, external, nonsexual, scene_advance, pullout |
| `actorNames` | string `"A, B and C"` | `ThreadDataStore::GetActorDisplayName` (trimmed `GetDisplayFullName`) → `FormatActorList` | same |
| `participant_count` | int | vector size. For join and invite it **includes** the newcomers. | most |
| `intent` / `activity` | string | Papyrus arg, or `ThreadDataStore::GetIntent(threadID)` | prestart, nonsexual, scene_advance, pullout |
| `threadID` | int | arg | external, join, invite, scene_advance, pullout |
| `initiator` | uuid \| null | nonsexual only | nonsexual |
| `currentActors` / `currentActorNames` / `currentIntent` | uuids / string / string | the thread's current actors from `ThreadDataStore` | join, invite |
| `joiner`, `joinerName`, `joinerFormID` | uuid / string / uint | join only | join |
| `inviter*`, `invitees`, `inviteeNames` | likewise | invite only | invite |
| `currentSceneDescription` | string | `OStimNet::GetSceneDescription(threadID)` | scene_advance, pullout |
| `participant1..5_formid` / `_name` | uint / string | legacy flat slots ("in case the template needs them") | prestart, external, nonsexual |
| `location`, `enableAggressiveIntent` | string / bool | `LocationScanService::BuildContextJson` ([LocationScanService.cpp:394](../extern/OStimNet/SKSE_Source/src/LocationScanService.cpp#L394)). This is the **entire** location-scan context. | scan |

Actors go in as **UUIDs** so the template can call `decnpc(uuid)` and `render_character_profile(..., uuid)`. Names go in pre-formatted for prose. The same names are later used to map the answer back (§5).

### 3b. Pull: what the templates fetch themselves

Every evaluation prompt follows the same skeleton (for example `ostimnet_evaluate_prestart_sexual.prompt`):

```jinja
[system]
## Participant Profiles
{% for actor in actors %}
  {% set actorData = decnpc(actor) %}
  ### {{ actorData.name }}
  {{ render_character_profile("tton_gm", actor) }}     {# custom bio mode #}
{% endfor %}
## Recent Events
{{ render_template("helpers\\ostimnet_recent_events") }}
... task, rules (render_template of ostimnet_intents/*), option lists via decorators ...
{% raw %}{ "reason": "...", "scene": { ... } }{% endraw %}   {# output schema #}
[end system]
[user]
... "Return raw JSON only. Start with {, end with }." ...
[end user]
```

| Pulled piece | Source |
|---|---|
| Per-actor bio | `render_character_profile("tton_gm", uuid)` renders `prompts/submodules/character_bio/9999_tton_gm.prompt`, which is gated on `render_mode == "tton_gm"`. It contains SkyrimNet's `bio_summary`, a **conception/pregnancy cue** (Fertility Mode / BeeingFemale faction ranks, only when `ostimnet_settings.internalClimaxPromptCue`), background, personality, appearance, relationships (plus `ttll_relations`/`ttm_relations`), long-term memories and the `7100_memories` include. |
| Recent events | `helpers/ostimnet_recent_events.prompt`: `get_recent_events(30, filter)`, with time-gap markers, location changes, and GM dialogue deduplicated to the latest entry. |
| Intent rules | `render_template("ostimnet_intents\\…")` and `ostimnet_intents_definitions\\ostimnet_intent_<intent>_{roles,willingness,preferences,description}`, branched on the pushed `intent`/`currentIntent`. |
| Option lists | The decorators `ostimnet_available_positions`, `ostimnet_available_furniture_types` (through `helpers/ostimnet_furniture_bit`), `ostimnet_thread_phase` and `ostimnet_settings`. |
| Candidate pool (scan only) | `get_nearby_actors_not_in_ostim(player.UUID).actorIds`. The scan pushes **no** actor list, so the template finds its own candidates. |

### 3c. Decorators registered by OStimNet

Registered in `SkyrimNetIntegration::Register()` ([L213](../extern/OStimNet/SKSE_Source/src/SkyrimNetIntegration.cpp#L213)) through the logging wrapper `RegisterDecorator` ([L45](../extern/OStimNet/SKSE_Source/src/SkyrimNetIntegration.cpp#L45)). Each receives an `RE::Actor*` and returns a string. JSON strings can be dotted into from Inja.

**Data decorators** (used by the evaluation prompts and the regular dialogue submodules):

| Decorator | Returns |
|---|---|
| `ostimnet_active_scenes` | `{scenes:[BuildSceneJson…]}`: threadID, description, intent, isSexual, actors/spectators/main/secondary UUIDs and names |
| `ostimnet_actor_scene` | The same object for this actor's thread, or `{"scene":null}`. |
| `ostimnet_actor_thread_id` / `ostimnet_spectator_thread_id` | thread ID or `-1` |
| `ostimnet_actor_thread_intent` / `ostimnet_actor_is_sexual` | string / `"true"`/`"false"`/`""` |
| `get_nearby_actors_in_ostim` / `get_nearby_actors_not_in_ostim` | `{actorIds:[uuid], actorsNameString}` within `tton.nearbyActors.radius` |
| `ostimnet_available_positions` | Position IDs with display names (OStimNavigator) |
| `ostimnet_available_sexual_actions` | Sexual action keywords, excluding cum/3pp/facial (OStimNavigator) |
| `ostimnet_available_furniture_types` | `bed(distance 4.6m),…` for furniture types with at least 5 nearby sex scenes (OStimNavigator) |
| `ostimnet_thread_phase` | `{currentPhase, nextPhase, currentPhaseActions, nextPhaseActions}` or `""` |
| `ostimnet_sex_pace_direction` | `increase` / `decrease` / `both` / `""` |
| `ostimnet_settings` | `{enableAggressiveIntent, playerSelectionChance, internalClimaxPromptCue}` |
| `ocum_description` | Prose describing the OCum overlays on the actor |

**Eligibility gates** (return `available`/`unavailable` and are used by the action YAML `eligibilityRules`): `is_start_new_sex_available`, `is_start_care_scene_available`, `is_spectate_sex_available`, `is_spectate_sex_flee_available`, `is_join_ongoing_sex_available`, `is_sex_scene_position_change_available`, `is_sex_scene_intent_change_available`, `is_sex_scene_pace_change_available`, `is_invite_to_your_sex_available`, `is_stop_sex_available`, `is_pullout_decision_available`. They combine faction checks, the `skyrimnet_sexlab_ostim_player` global, child and combat checks, and `ConfirmationModal` cooldowns.

---

## 4. Prompt name, variant and config

- **Prompt name** is `"ostimnet_evaluations/<file>"`, which resolves to `SKSE/Plugins/SkyrimNet/external/tetherball88.ostimnet/prompts/ostimnet_evaluations/<file>.prompt`. The bundle id comes from `manifest.json` (`tetherball88.ostimnet`, `min_skyrimnet_version 0.25.0`).
- **Variant** is `Config::GmLlmVariant()` → `tton.gm.gmLlmVariant`, default `gamemaster_evaluation` ([Config.cpp:82](../extern/OStimNet/SKSE_Source/src/Config.cpp#L82)). The user picks it in SkyrimNet's plugin config UI. The options (`default`, `gamemaster_evaluation`, `action_evaluation`, …) are listed in `SKSE/Plugins/SkyrimNet/config/plugins/OStimNet/manifest.yaml`. All eight calls use the same variant.
- **Config reads** go through `Config::GetValue(path, fallback)`, which calls `PublicGetPluginConfigValue("OStimNet", path, default)`. The default comes from `manifest.yaml`'s `schema.fields[].defaultValue`, which is loaded once with yaml-cpp, or from a hard-coded fallback. Values are re-read on every call, so changes take effect live.

---

## 5. The canonical call shape

Every `Evaluate*` follows this template. Copy the structure, not the duplication.

```cpp
bool EvaluateX(...) {
    if (!PublicSendCustomPromptToLLM) { log; return false; }           // API v8 gate

    // (1) Snapshot on the calling thread: name→FormID map, UUIDs, names
    std::map<std::string, RE::FormID> nameToFormID;                     // display name → FormID
    nlohmann::json uuids = nlohmann::json::array(); std::vector<std::string> names;
    for (fid : participants) { name = GetActorDisplayName(actor); nameToFormID[name] = fid;
                               names.push_back(name); uuids.push_back(ActorRefIDToUUID(fid)); }
    nlohmann::json ctx; ctx["actors"] = uuids; ctx["actorNames"] = FormatActorList(names); ...
    std::string contextJson = ctx.dump();
    std::string promptName  = "ostimnet_evaluations/...";
    std::string llmVariant  = Config::GetSingleton().GmLlmVariant();

    // (2) Self-referencing callback so Retry can resend the identical request
    auto callbackHolder = std::make_shared<std::function<void(const char*, int)>>();
    *callbackHolder = [callbackHolder, nameToFormID, contextJson, promptName, llmVariant, ...]
                      (const char* response, int success) {
        // (3) Staleness guard (thread still valid / still OStimNet / scan generation unchanged)
        // (4) Failure → Retry/Ignore modal
        auto retry  = [=]{ PublicSendCustomPromptToLLM(promptName.c_str(), llmVariant.c_str(),
                                                       contextJson.c_str(), *callbackHolder); };
        auto ignore = [=]{ FireModEvent("..._finished", ignoreJson, 0.0f); };
        if (!success || !response || !*response) { ShowLLMRetryModal(..., retry, ignore); return; }

        // (5) Lenient parse
        auto resp = nlohmann::json::parse(response, nullptr, /*exceptions=*/false);
        if (resp.is_discarded()) resp = parse(JsonService::SanitizeLLMJson(response), ...);
        if (resp.is_discarded()) { ShowLLMRetryModal(..., retry, ignore); return; }

        // (6) Semantic "no" → numArg 2
        if (!resp.contains("scene") || resp["scene"].is_null()) { FireModEvent(..., 2.0f); return; }

        // (7) Names → FormIDs, plus the role guardrail
        result["main"]      = JsonService::ResolveNamesToFormIDs(scene, "mainActors", nameToFormID, tag);
        result["secondary"] = JsonService::ResolveNamesToFormIDs(scene, "secondaryActors", nameToFormID, tag);
        if (result["secondary"].empty() && result["main"].size() > 1) move last main → secondary;

        // (8) Back to Papyrus on the game thread
        FireModEvent("..._finished", result.dump().c_str(), 1.0f);   // AddTask → ModCallbackEvent
    };

    bool queued = PublicSendCustomPromptToLLM(promptName.c_str(), llmVariant.c_str(),
                                              contextJson.c_str(), *callbackHolder);
    if (!queued) log;
    return queued;
}
```

Helpers it relies on:

| Helper | File | What it does |
|---|---|---|
| `JsonService::SanitizeLLMJson` | [JsonService.h:160](../extern/OStimNet/SKSE_Source/src/JsonService.h#L160) | Strips a UTF-8 BOM, then keeps the first `{` through the last `}`. This handles code fences and surrounding prose. |
| `JsonService::ResolveNamesToFormIDs` | [JsonService.h:121](../extern/OStimNet/SKSE_Source/src/JsonService.h#L121) | Turns an array of names into FormIDs with an exact-match lookup in the snapshot map. Unknown names are dropped and logged together with the list of known names. |
| `ShowLLMRetryModal` | [SkyrimNetIntegration.cpp:170](../extern/OStimNet/SKSE_Source/src/SkyrimNetIntegration.cpp#L170) | Queues a `MessageBoxData` (Retry/Ignore) through `SKSE::GetTaskInterface()->AddTask`. |
| `FireModEvent` | [ModEventDispatch.h:10](../extern/OStimNet/SKSE_Source/src/ModEventDispatch.h#L10) | Copies its arguments, then `AddTask` → `SKSE::ModCallbackEvent`, so it is safe to call from the worker thread. |
| `BuildSceneJson` | [SkyrimNetIntegration.cpp:97](../extern/OStimNet/SKSE_Source/src/SkyrimNetIntegration.cpp#L97) | Builds the scene object shared by the `ostimnet_active_scenes` and `ostimnet_actor_scene` decorators. |

**Why names instead of UUIDs in the answer?** LLMs copy display names reliably and garble 64-bit numbers. The prompt lists exactly the eligible names ("NEVER consider characters not listed in Participant Profiles"), and C++ maps them back with the map it captured before the call. Names the model invents simply fail to resolve.

**Why does the prestart call return 3.0?** `ResolveNamesToFormIDs` only maps names that were in the original set, so `main + secondary < originalParticipants` means the LLM excluded someone. The result then carries `excluded[]`, and Papyrus decides whether to continue with fewer actors. If more than one actor was requested and at most one was resolved, the call returns 2.0 instead.

---

## 6. Gotchas (observed in the source)

1. **Threading contract is bent.** The header says the callback runs on a ThreadPool worker and must not call `RE::`. Several callbacks do anyway: `EvaluateExternalSexualThread` calls `LookupByID` and mutates `ThreadDataStore`, and scene_advance and pullout call `g_ostimThreadInterface->IsThreadValid`. In addition, `EvaluateScheduledSceneAdvance` and `EvaluatePulloutDecision` are *invoked* from `ScheduledEvalService`'s own `std::thread`, so their context building (`GetActorPtrs`, `GetSceneDescription`, OStim API reads) is not on the game thread either. For new code, snapshot on the game thread and route game-state work through `AddTask`, as `FireModEvent` does.
2. **Name collisions.** `nameToFormID` is a `std::map<string, FormID>`, so two participants with the same display name collapse into one entry, and the earlier one becomes unresolvable.
3. **Location-scan mismatch.** The C++ snapshot uses `actor->GetName()` and a **hard-coded 2000-unit** radius over `highActorHandles` ([LocationScanService.cpp:256-276](../extern/OStimNet/SKSE_Source/src/LocationScanService.cpp#L256)). The template's candidate list comes from `get_nearby_actors_not_in_ostim` with the configurable `tton.nearbyActors.radius`, and other prompts use `GetDisplayFullName`. If the radius is changed, or a display name differs from the base name, a candidate can be offered to the LLM and then fail to resolve. In that case the result is numArg 3.0.
4. **Stale scans.** Location-scan callbacks compare `scanGen` against `LocationScanService::GetGeneration()` and drop superseded results. The thread-based evaluations re-check `IsThreadValid` / `IsOStimNet` / `IsRegisteredAndPending` instead.
5. **Inconsistent guardrail.** `EvaluateInviteToSex` does not apply the empty-secondary → move-last-main rule that the other role-assigning calls use.
6. **Empty payload.** A location-scan `scene:null` fires `ostimnet_location_scan_result` with an **empty** `strArg` (numArg 2.0), not a JSON object.
7. **Retry reuses a frozen context.** `contextJson` is captured once at queue time. The pulled pieces (events, bios, decorators) are re-rendered on each retry, so a retried prompt can see newer events alongside an older actor list.
8. **`ostimnet_thread_phase(0)`.** `ostimnet_evaluate_scene_advance.prompt` calls the decorator with UUID `0` rather than an actor UUID. The decorator returns `""` for a null actor, so the "Encounter Phase" block probably never renders. This is unverified: it depends on how SkyrimNet resolves UUID 0.
9. **One variant for everything.** All evaluations share `tton.gm.gmLlmVariant`. You cannot send the cheap ones (pullout) to a cheaper model separately.

---

## 7. Applying this in SkyrimNet_SexLab

- The Papyrus binding in this repo has a different callback shape. [Headers/SkyrimNetApi.psc](../Headers/SkyrimNetApi.psc) declares `SendCustomPromptToLLM(promptName, variant, contextJson, callbackQuest, callbackScriptName, callbackFunctionName)`. The response arrives as a Papyrus function call rather than as a C++ lambda. There is also `SendCustomDecisionToLLM(templateName, contextJson, …)`. Neither is used by active source today. The only reference is under `ignored/`.
- Prompts for this mod belong under `SKSE/Plugins/SkyrimNet/external/goodprovider.sexlab/prompts/`. For prompt authoring conventions see [docs/authors/prompts.md](../docs/authors/prompts.md). For decorator and action contracts see [docs/developers/papyrus.md](../docs/developers/papyrus.md) and [docs/authors/actions.md](../docs/authors/actions.md).
- Reusable ideas, in order of value:
  1. Push UUIDs plus formatted names, and pull bios and events in the template.
  2. Ask for names back and resolve them against a snapshot map.
  3. Parse leniently with first-`{`-to-last-`}` sanitization.
  4. Treat `scene: null` as an explicit "no" result.
  5. Use a stable numArg code table and echo an `evalId`.
  6. Re-check staleness before you act on a late answer.
