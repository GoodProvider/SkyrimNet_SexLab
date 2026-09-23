# Checkpoint v2: `SkyrimNet_SexLab_Scene` → C++ (staged migration)

Supersedes [v1-checkpoint.md](v1-checkpoint.md). Written from
`c:\Skyrim\dev\mods\SkyrimNet_SexLab`, branch `dom`, baseline commit `41cd7cb`.

**How to use this document.** Each stage below is executed in its own chat: build, test
in-game, fix, commit, then move on. A stage is self-contained — read §1–§4 plus your stage's
section and you have everything. Tick your stage in §5 when it lands.

> **Line numbers are as of `41cd7cb`.** They will drift as stages land. Treat them as
> "look near here", and grep for the symbol if it has moved.

---

## 1. Status & provenance

### Nothing from v1 was implemented

Verified at `41cd7cb`: no `SceneTracking.h/.cpp`, no `Papyrus_SceneTracking.cpp`, no
`AllStagesHaveDescription`, no `_scene_sid` handling in `WebUI_OnAnimRegistrySave`,
`Scene.psc` still 3173 lines. v2 starts from a clean tree.

From v1, only the **clothing-sync bug fix** is carried forward, as Stage 0. v1's
`IsTracked`/auto-open pilot is dropped as standalone work; its description logic is absorbed
into Stage 5.

### v1's central conclusion was wrong, and this changes the end state

v1 concluded the ~48 SexLab-calling functions "cannot move to C++ without inventing a new
native bridge into SexLab's Papyrus VM objects — a separate, much larger undertaking."

That bridge is substantially cheaper than v1 assumed. Evidence, all verified in-tree:

**1. Reads do not need function calls at all.**
`RE::BSScript::Object::GetProperty(name)` and `GetVariable(name)` exist in the vendored
CommonLibSSE-NG (`SKSE_Source/lib/CommonLibSSE-NG/include/RE/O/Object.h:31-34`). Nearly
everything `Scene.psc` reads off a SexLab thread is an **auto property** — a plain backing
variable, readable synchronously with no VM pump and no callback:

| Source | Auto properties |
|---|---|
| `extern/Source_SexLab/sslThreadModel.psc:29-52,162,178,184,218` | `Positions`, `Stage`, `Animation`, `Victims`, `Genders`, `ActorCount`, `HasPlayer`, `DisableOrgasms`, `BedRef`, `ActorAlias`, `AdjustKey`, `AnimEvents` |
| `extern/Source_SexLab/sslBaseObject.psc:7-12` | `Registry`, `Name`, `SlotID`, `Enabled` |

Derived helpers then collapse into pure C++ with no VM at all: `thread.IsVictim(a)` is a
lookup in `Victims`; `sexlab.GetGender(a)` is an index into `Genders`.

**2. Writes are an already-solved pattern.**
Every SexLab mutator `Scene.psc` calls returns nothing — `GoToStage`, `SetAnimation`,
`AddAnimation`, `SetAnimations`, `SetForcedAnimations`, `ChangeActors`, `SetVictim`,
`DisableOrgasm`, `UpdateTimer` (`sslThreadController.psc:204,723,833,1080`;
`sslThreadModel.psc:689,782,830,1060,1080,1121,2183`). Fire-and-forget
`vm->DispatchMethodCall` with a null callback covers all of them — the exact idiom already
used ~10 times in `SKSE_Source/src/Papyrus_WebUI.cpp:1090-1116`.

**3. Only a small residue needs a return value** — e.g. `sslBaseAnimation` tag queries, which
are functions rather than auto properties.

---

## 2. Target architecture

### 2.1 The three bridge layers

| Layer | Mechanism | Covers | Rule |
|---|---|---|---|
| **A** | `Object::GetProperty` / `GetVariable` on SexLab's script object | Most reads | Synchronous. **Main thread only.** |
| **B** | `vm->DispatchMethodCall`, null callback | All mutations | Asynchronous — see hazard below |
| **C** | Residue needing a return value | Tag queries, rare | Cache at event time, or a Papyrus callback |

**`PumpVm` is banned from hot paths.** The synchronous VM-pump idiom at
`Papyrus_WebUI.cpp:818-825` is acceptable for a one-off leash check. Re-entrantly pumping the
VM ~20×/actor inside `SetActor` is the single most likely way to destabilize the game. If you
think you need it, you actually need Layer A or a Layer C cache.

### 2.2 Hazards that apply to every stage

**Write/read ordering.** Layer B is asynchronous. A write followed by a read of the same
property can see stale data. C++ must keep its own authoritative shadow of anything it writes
and **never read back its own writes through the bridge**.

**Thread affinity.** Layer A reads and all VM work must happen on the main thread — inside a
native call, or inside `SKSE::GetTaskInterface()->AddTask`. Never from a WebUI listener thread
or a decorator callback.

### 2.3 Eager maintenance, not lazy derivation

**This principle governs every stage from 4 onward.**

`SceneCore` is kept current by SexLab events and API calls pushing into it on the main thread.
Consumers read cached state and never pull.

Today the opposite is true, and it is the root of most of the difficulty. The prompt-render
path calls `GetThreadObj(speaker)` (`Scene.psc:1754-1823`), which **mutates** scene state
(`alignactors()` `:1760`, `updateactor()` `:1782`, `setnames()` `:1787`), calls into **SexLab**
(`thread.positions`, `thread.isvictim` `:1814`), **raycasts** (`speaker.haslos` `:1794`), and
**writes a file** (`MiscUtil.WriteToFile`, `Scene_Manager.psc:~1650`) — all while rendering an
LLM prompt.

Under the target architecture every read path — decorators first, WebUI builders next — is
strictly read-only and VM-free. Practically: **each stage that moves a computed value must
also name the event that recomputes it.** Stage 8 completes that wiring.

### 2.4 Persistence: none

No SKSE co-save serialization. SexLab ends all threads on load, so `SceneCore` matches that
behavior and **clears all scene state on `kPostLoadGame` / `kNewGame`**, next to the existing
`TargetMenuRegistry::Clear()` at `SKSE_Source/src/plugin.cpp:31-36`.

This plugin has zero co-save usage today; do not introduce it. All other persistence in this
plugin is external files (SQLite/JSON under `AnimationDB::PluginDataDir()`).

### 2.5 A structural win to take while migrating

`thread_obj`, `actors_objs`, `position_objs[]` and the per-actor `StorageUtil` keys exist only
to build JSON for SkyrimNet, whose natives take **JSON strings** in and out. Once C++ owns the
data, build that JSON with `nlohmann::json` directly. The entire JContainers retain/release
layer and the cross-save `StorageUtil` handle aliasing — the messiest part of the current
script — gets **deleted rather than ported**. Do not port it and clean up later.

---

## 3. Standing rules

**Carried from v1, restated for a C++ Scene.** The Scene module is the only path between the
WebUI and SexLab's live thread state:

```
WebUI JS → WebUI.cpp listener → SceneCore → SexLabBridge → SexLab
```

Nothing may reach SexLab directly or bypass `SceneCore` as the source of truth. In particular
the existing `WebUI JS → AnimDb → SexLab` shortcut is a violation — it is the bug Stage 0
fixes.

Also standing, from `AGENTS.md` / `CLAUDE.md`:
- Papyrus compiles via the **`compile: pyro`** task only.
- Commit summary fits in the first 72 characters.
- Confidence ≥ 90% before game/script/ESP edits. SE ≠ VR.
- Anything surprising discovered in-game goes in `KNOWLEDGEBASE.md` with a dated heading.

---

## 4. Parity harness

Built in Stage 1, used by every stage marked **parity** in §5.

- A runtime mode in `Config` — `papyrus` / `cpp` / `both`. Follow the existing pattern in
  `SKSE_Source/src/Config.cpp`; `Config::ApplyFromConfig()` is already called from
  `plugin.cpp:29,35`.
- In **`both`**, the Papyrus path stays authoritative and the C++ path is computed alongside.
  Divergence is logged to `SkyrimNet_SexLab.log` via the existing helpers in
  `SKSE_Source/src/WebUI_Log.cpp`. Log the field name, the Papyrus value and the C++ value —
  a bare "mismatch" line is useless three stages later.
- **Exit criterion for every parity stage:** play a full scene in `both` with zero mismatch
  lines, then flip to `cpp` and replay. The *following* stage's first commit deletes the dead
  Papyrus path.

Mechanical stages (marked **direct**) skip the harness — they are too simple to be worth
double-implementing.

---

## 5. Stage list & progress

| # | Stage | Mode | Status |
|---|---|---|---|
| 0 | Clothing-sync bug fix | direct | ☐ |
| 1 | Infrastructure: `SceneCore` + parity harness | direct | ☐ |
| 2 | **SexLabBridge spike (gating)** | parity | ☐ |
| 3 | Leaf helpers | direct | ☐ |
| 4 | Position/actor state model | parity | ☐ |
| 5 | Names, descriptions, JSON | parity | ☐ |
| 5b | Decorator subsystem + `sexlab_get_threads` | parity | ☐ |
| 6 | WebUI build + commit | parity | ☐ |
| 7 | Orgasm pipeline | parity | ☐ |
| 8 | Lifecycle & events | parity | ☐ |
| 9 | Cleanup | direct | ☐ |

---

## Stage 0 — Clothing-sync bug fix (Papyrus only)

**Goal.** Start the migration from correct behavior, and close the standing-rule violation.
No C++ in this stage.

**The bug.** The Description Editor's "dressed" toggle never reaches a live actor. The panel
keeps its own draft (`DE.posDraft`, `index.html:9111,9481-9497`), seeded from AnimDb
*defaults*, not live scene positions. On save, `deSaveToDisk()` (`index.html:9895-9926`) sends
it through `window.onAnimRegistrySave` → `WebUI.cpp:812-822` →
`Scene_Manager.psc:1079-1138` `WebUI_OnAnimRegistrySave`, which has **no `scene_sid` and no
reference to `Scene`/`thread` at all** — it only reshapes `_positions` and calls
`animdb.SaveAnimLocal(...)`. So toggling "dressed" during a live scene changes the animation's
saved default and nothing else. That is the `WebUI → AnimDb → SexLab` shortcut §3 forbids.

Separately, the scene-aware path `WebUI_ApplyLivePositions` (`Scene.psc:2226-2255`) only
bookkeeps `dressed` and never applies clothing. The only code that calls
`Outfit_Dress`/`Outfit_Undress`/`TM_ApplyClothed` is a duplicate block inline at the tail of
`ApplyWebUICommit` (`Scene.psc:2733-2764`), which the editor's save path never reaches.

**Four surgical edits.**

1. **`Scene.psc` `WebUI_ApplyLivePositions`** (`:2226-2255`) — apply the clothing action,
   index-matched to `thread.Positions` exactly like the existing `no_orgasm`/`speaking`
   handling. Insert immediately after the existing
   `thread.DisableOrgasm(positions[i], no_org == 1)` line, inside the same `while i < n` loop
   and `if po > 0` block:
   ```papyrus
   Bool clothed = dressed == 1
   SkyrimNet_SexLab_Actions actions = (manager as Quest) as SkyrimNet_SexLab_Actions
   if actions
       if clothed
           actions.Outfit_Dress(Game.GetPlayer(), positions[i], "silently", "silent")
       else
           actions.Outfit_Undress(Game.GetPlayer(), positions[i], "silently", "silent")
       endif
   endif
   TM_ApplyClothed(positions[i], clothed)
   ```
   This fixes the gap for **every** caller of `WebUI_ApplyLivePositions`.

2. **`Scene.psc` `ApplyWebUICommit`** (`~:2733-2764`) — delete the now-duplicate clothing
   block from the tail loop (the `Bool clothed` / `actions.Outfit_*` / `TM_ApplyClothed(a, …)`
   lines). `WebUI_ApplyLivePositions(obj)` is already called earlier in the same function
   (`:2732`), so after edit 1 the action would otherwise fire twice per commit.
   **Leave `isVictim` / `thread.SetVictim` / `deny` / `mode` / `TM_ApplyOrgasmMode` alone** —
   `WebUI_ApplyLivePositions` does not handle that victim/deny-orgasm nuance, only clothing.

3. **`Scene_Manager.psc` `WebUI_OnAnimRegistrySave`** (`:1079-1138`) — route live updates
   through Scene. Add after the `registry == ""` bail-out:
   ```papyrus
   int scene_sid = JMap.getInt(obj, "_scene_sid", -1)
   if scene_sid >= 0 && JMap.hasKey(obj, "_positions")
       SkyrimNet_SexLab_Scene sl_scene = GetSceneBySid(scene_sid)
       if sl_scene && sl_scene.GetThreadActive()
           sl_scene.WebUI_ApplyLivePositions(obj)
       endif
   endif
   ```
   `obj` already carries `_positions` in the exact shape `WebUI_ApplyLivePositions` expects
   (`{_no_orgasm, _speaking, _dressed}` per entry) — no reshaping. `GetSceneBySid` exists and
   is used the same way at `:1073`.

4. **`index.html` `deSaveToDisk()`** (`:9895-9926`) — attach `_scene_sid` only when this
   registry is the one actually playing in a bound scene:
   ```js
   if (DE.posDirty) {
       payload._positions = DE.posDraft.map(p => ({ _no_orgasm: p._no_orgasm ? 1 : 0, _speaking: p._speaking || '', _dressed: p._dressed ? 1 : 0 }));
       const boundScene = deActiveSceneForRegistry(DE.focusRegistry);
       if (boundScene) payload._scene_sid = boundScene.scene_sid;
   }
   ```
   `deActiveSceneForRegistry` (`:9154-9159`) already resolves the active `SceneInfo` for a
   registry, gated by `deIsSceneBound()` (`:9145-9147`).

This keeps `animdb.SaveAnimLocal` exactly as-is and purely *adds* the live push alongside it.

**Test.** Start a scene; open the Description Editor on the playing registry; toggle "dressed"
for a position; save → the actor's clothing changes immediately in-game. Then edit a registry
that is **not** playing → only the AnimDb default changes, no live actor touched (no
`_scene_sid` attached).

**Exit.** Both behaviors confirmed. Papyrus compiles clean.

---

## Stage 1 — Infrastructure (no logic moves)

**Goal.** Stand up the C++ scaffolding and the parity harness. Deliberately moves **no**
behavior, so a regression here is unambiguous.

**Build.**
- `SKSE_Source/include/SceneCore.h`, `SKSE_Source/src/SceneCore.cpp` — a sid-keyed store.
  Copy the concurrency shape of `AnimationDB` exactly (`SKSE_Source/src/AnimationDB.cpp:16-21`):
  file-scope state in an anonymous namespace, one `std::recursive_mutex`, every public entry
  point takes `std::lock_guard` first, internal helpers suffixed `...Locked`.
  `sid` is the same int already used everywhere as `_scene_sid`.
- `SceneCore::Clear()` called from the `kPostLoadGame || kNewGame` branch of
  `plugin.cpp:31-36`, beside `TargetMenuRegistry::Clear()`. See §2.4.
- The parity mode in `Config` and the mismatch logger. See §4.
- New `.cpp` files are picked up by `file(GLOB "src/*.cpp")` at `CMakeLists.txt:60-61` — a
  CMake re-configure, not a project-file edit.

**Test.** Game loads, DLL initializes, the mode toggle is readable from config and logs its
value at startup. Nothing else changes.

**Exit.** Clean build, clean load, toggle observable in the log.

---

## Stage 2 — SexLabBridge spike ⚠️ **gating**

**Goal.** Prove Layer A works against a live SexLab thread before anything depends on it.
Read-only; nothing consumes the output yet.

**Build.** `SexLabBridge.h/.cpp`:
- Given a `sslThreadController` handed in from Papyrus, resolve its `BSScript::Object` —
  `GetObjectHandlePolicy()->GetHandleForObject(...)` then `FindBoundObject(handle, …)`, the
  pattern at `Papyrus_WebUI.cpp:1126-1145` (note that call site binds to a Scene *form*, not
  the main quest — same shape).
- Read the §1 auto properties and log them.
- In `both` mode, compare each against what Papyrus reports for the same thread and log
  divergence.

Also confirm the derived helpers: `IsVictim` from `Victims`, gender from `Genders`.

**Test.** Start a scene with 2+ actors, a creature scene, and a scene with a victim. Confirm
every property reads correctly and matches Papyrus through several stage changes.

**Exit / the decision point.** Layer A reads match Papyrus for every listed property across
those scenes.

> **If Layer A fails** — properties unreadable, wrong values, or unstable — stop and record
> what failed here before continuing. The fallback is: `Scene.psc` stays a thin Papyrus shim
> that natives call *out* to for each SexLab touch, and Stages 4–8 keep their C++ state model
> but source SexLab data through that shim instead of the bridge. Stages 0–1, 3 and 5b are
> unaffected either way. **Do not begin Stage 4 until this stage has passed or the fallback is
> recorded.**

---

## Stage 3 — Leaf helpers

**Goal.** Move the functions with no SexLab and no game-object dependencies. Mechanical.

**Moves.** `Trace`, `DbgEnter`, `DbgReturn`, `DbgEnd`, `DbgMsg` (`Scene.psc:88-137`),
`GetString` (`:138`), `SpeakingCsvFromIndex` (`:636`), `NotePlayedRegistry` (`:2345`),
`WasRegistryPlayed` (`:2369`), `GetIntentMessage` (`:981`), `GetUUID` (`:749`).

Also fold in `SkyrimNet_SexLab_Scene_Interface.psc` (174 lines) — it is entirely bookkeeping.
Its `status` string field (`STATUS_INACTIVE/SETUP/ACTIVE`, `:55-58`) becomes a plain C++ enum;
note the comment at `:50-54` warning about Auto-vs-AutoReadOnly save corruption, which simply
stops being a concern once the value lives in C++.

`GetUUID` already wraps natives (`SkyrimNetApi.GetEntityUUID` + `UuidToDecimalString`) — in
C++ use `PublicFormIDToUUID` (`CppAPI/PublicAPI.h:135`) directly.

**Mode: direct.** These are too simple to double-implement.

**Test.** Run a scene; confirm log output is unchanged in shape and the played-registry
tracking still works.

---

## Stage 4 — Position/actor state model

**Goal.** The big one. C++ becomes the owner of per-actor scene state.

**Moves.** `position_objs[]`, `actors_objs`, `thread_obj` → C++ structs. `SetActor` (`:660`),
`UpdateActor` (`:762`), `SetPosition` (`:573`), `SetSpeakingObj` (`:585`),
`EnsureActorArraysLargeEnough` (`:546`), `GetObjFromActor` (`:756`), `GetTotalOrgasms` /
`SetTotalOrgasms` (`:902,908`).

**Delete rather than port** (see §2.5): every `JMap`/`JArray`/`JValue.retain`/`release` call in
the moved code, and both per-actor `StorageUtil` keys (`storage_obj_key`,
`storage_total_orgasms_key`, `Scene.psc:30-32`). The orgasm count becomes an ordinary field in
the C++ actor struct.

`SetActor` is the heaviest function in the file — per actor it does one
`SkyrimNetApi.GetEntityUUID`, `sexlab.GetGender`, `actorLib.GetTrans`, `thread.ActorAlias(...)`
and ~18 JMap writes. Gender comes from the bridge's `Genders` array; UUID from
`PublicFormIDToUUID`.

**Cross-object reach-throughs to preserve:** `main.handler_dom.IsDOMSlave`,
`main.race_to_description`, `manager.sexlab/threadSlots/actorLib`,
`manager.SkyrimNet_SexLab_Faction_Victim`.

**Per §2.3:** name the event that refreshes each field you move. Anything you cannot attach to
an event yet, note in the stage's commit message for Stage 8 to pick up.

**Test.** Multi-actor scene, creature scene, victim scene, DOM-slave scene. Parity-clean in
`both`, then replay in `cpp`.

---

## Stage 5 — Names, descriptions, JSON

**Moves.** `GetNames` (`:841`), `SetNames` (`:830`), `GetCreatureDescriptions` (`:874`),
`GetDescription` (`:1733`), `GetDescriptionFromTags` (`:1976`), `GetLocation` (`:1844`),
`GetThreadObj` (`:1754`), `GetThreadJson` (`:1746`), `GetVictimsNamesJsonObj` (`:1827`),
`GetTagsString` (`:1960`).

**Absorbs v1's description work.** Add `AnimationDB::AllStagesHaveDescription(registry)` — the
data is already in memory as `AnimRow::stage_has_description`
(`SKSE_Source/include/AnimationDB.h:37`, a `std::vector<int>`), so this is a real C++ loop with
no JSON round-trip:
```cpp
bool AllStagesHaveDescription(const std::string& registry)
{
    auto row = GetByRegistry(registry);
    if (!row || row->stage_has_description.empty())
        return false;
    for (int v : row->stage_has_description)
        if (v != 1) return false;
    return true;
}
```

Tag queries (`GetDescriptionFromTags` calls `thread.Animation.HasTag` many times) are the
Layer **C** residue — cache the animation's tag set at event time and match in C++. Do **not**
call `HasTag` per query.

**Critical for Stage 5b:** `GetThreadObj` currently mutates and raycasts (§2.3). This stage
splits it: the cached, speaker-independent snapshot is built here; the `speaker_*` fields are
dropped entirely in Stage 5b. Do not port `alignactors()`/`updateactor()`/`setnames()` calls
into the C++ read path — they belong on events.

**Note the pre-existing `bool Property tracking`** (`Scene.psc:64`). It is an unrelated
debug/print toggle for `StageStart()`'s `Debug.Notification` logging and reads
`animdb.GetHasDescriptionOrgasmExpected(thread)`, which evaluates only the *current* stage.
Leave it alone; do not confuse it with "all stages have a description".

---

## Stage 5b — Decorator subsystem + `sexlab_get_threads`

**Goal.** Build the decorator subsystem as reusable infrastructure, and migrate the one
decorator that required the scene migration. **All decorators move to C++ after this plan**
(§8), so do not build this as a one-off.

### Entry conditions — check these first

1. **Stages 4 and 5 are landed.** This decorator can only be VM-free if its inputs are
   already in `SceneCore`.
2. **Event wiring is partially pulled forward from Stage 8.** A VM-free decorator needs its
   inputs event-maintained, but the handlers live in Stage 8. This stage brings forward
   exactly the subset it needs — the `AnimationStart` / `StageStart` / `AnimationEnd`
   refreshes for `active`, `status`, `description`, `style`, `names`, `victims`, `location`,
   plus the `alignactors` / `updateactor` work `GetThreadObj` does at render time today.
   Stage 8 then completes the rest rather than starting from nothing. **Do not start this
   stage assuming Stage 8 has run.**
3. **Settle the `CppAPI` include path.** `CMakeLists.txt:78` points at
   `../../SkyrimNet/CppAPI` → `c:\Skyrim\dev\mods\SkyrimNet\CppAPI`, **which does not exist**.
   The two copies on this machine differ by five API versions:
   `skyrimnet beta25 rc6\CppAPI` is v5-era; `SkyrimNet Tester\CppAPI` declares v10.
   Decorator registration needs v5+, so either works here — but prefer the newer one so later
   stages can use v6–v10 (actor busy state, world knowledge, custom LLM prompts). Point the
   build at a real, known header before writing code.
4. **Extend the CMake glob.** `CMakeLists.txt:60` globs `src/*.cpp` **non-recursively**, so
   `src/decorators/` needs adding. Worth doing properly — every decorator lands there. Flat
   fallback if you prefer: `src/Decorator_<name>.cpp`.

### The subsystem

- **One** central registrar, `Decorators::RegisterAll()`, listing every decorator. Call it
  from `SexLabNet::InitSkyrimNetAPI()` (`SKSE_Source/src/Config.cpp:84`, already invoked at
  `plugin.cpp:23`). Registration is
  `PublicRegisterDecorator(name, description, std::function<std::string(RE::Actor*)>)`
  (`CppAPI/PublicAPI.h:496`).
  **The pointer is `nullptr` on a SkyrimNet older than v5** — null-check it and leave the
  Papyrus registration in place in that case rather than silently registering nothing.
- **One file per decorator**, each exposing a single symbol the registrar references.
  `src/decorators/sexlab_get_threads.cpp` is the first. Adding one later = one new file plus
  one line in the registrar.
- A small shared header for what every body needs: the JSON-return convention (build with
  `nlohmann::json`, replacing the `JMap` + `ObjectToLowerCaseKeyJson` + `JValue.release`
  boilerplate repeated in every Papyrus body), `"{}"` on an invalid actor, and the
  main-thread cache helper described below.
- Papyrus `RegisterDecorators()` (`Decorators.psc:19-27`) loses one line per migrated
  decorator, and that decorator's body is deleted.

### The cross-cutting thread-safety rule

**Decorator callbacks must be thread-safe and run off the main thread during prompt render.**
A callback may never do Layer-A script reads or any VM work. Every decorator must resolve to
one of:

- **(a)** serve from `SceneCore`'s cached state under its mutex,
- **(b)** read plugin config,
- **(c)** read a value refreshed on the main thread and cached — this is what the shared helper
  is for.

§8 pre-assigns a category to every remaining decorator so the follow-on sweep never
re-litigates this.

### `sexlab_get_threads` — C++ only, zero Papyrus on the call path

This is a hard constraint. Today `Decorators.psc:20,29-38` forwards to
`Scene_Manager.GetThreadsJson()` (`:1552+`), which walks `ThreadSlots.Threads` and calls
`GetThreadObj(speaker)` per thread — mutating, calling SexLab, raycasting and writing a file,
all on the render path (§2.3).

**Everything not speaker-relative is served from `SceneCore`'s cached snapshot**, maintained
by the events pulled forward in entry condition 2. The decorator is **strictly read-only** —
category (a). That is also what makes it thread-safe.

**The speaker-relative fields are deleted, not ported.**

SkyrimNet's LOS is **not on the C++ ABI** — verified across both `CppAPI` copies including
v10; there is no LOS or distance entry point at any version (history `PublicAPI.h:53-61`,
bindings `:665-795`). What SkyrimNet has is **built-in Inja decorators** usable from prompt
templates: `has_line_of_sight(actorUUID, npc.UUID)` and `distance_between(...)`, confirmed in
SkyrimNet's own test prompt
`library/skyrimnet.base/prompts/submodules/test_decorators/0100_actor_decorators.prompt:2,139-148`.

That is better than a C++ entry point. Drop `speaker_name`, `speaker_distance` and
`speaker_los` from the decorator's JSON and let the prompt call SkyrimNet's built-ins:
- No raycast anywhere in our code — the thread-safety question disappears rather than being
  mitigated, and this decorator needs no category (c) helper.
- The output becomes **speaker-independent**, so it is a pure cached snapshot with zero
  per-call work.
- We use SkyrimNet's implementation rather than maintaining a parallel one.

*Fallback only if a prompt-side replacement proves inexpressible:* native
`RE::Actor::HasLineOfSight` (`Actor.h:605`) plus `GetPosition()` (`TESObjectREFR.h:413`),
behind the main-thread cache. This is the fallback, not the plan.

### Prompt edits

Both consuming prompts wrap the decorator in a pause guard and fall back to a stale cached
file (`0050_sexlab_activity.prompt:1-17`, `0550_sexlab_narration.prompt:1-11`):

```jinja
{% if not isTimePaused %}
     {% set sexlab = sexlab_get_threads(npc.UUID) -%}
     {% set sexlab.source = "sexlab_get_threads" %}
     {% if not sexlab.threads %}
          {% set sexlab = read_json("SkyrimNet_SexLab/threads.json") %}
          {% set sexlab.source = "file" %}
     {% endif %}
{% else %}
     {% set sexlab = read_json("SkyrimNet_SexLab/threads.json") %}
     {% set sexlab.source = "file" %}
{% endif %}
```

**C++ is safe to call while the game is paused; Papyrus is not** — that is the entire reason
for the `isTimePaused` guard. The second fallback (`not sexlab.threads`) exists because the
Papyrus call could fail or return empty; a C++ decorator serving from `SceneCore` returns the
truth, so falling back to a stale file would be actively wrong.

**Remove both fallbacks.** Each block collapses to the unconditional:
```jinja
{% set sexlab = sexlab_get_threads(npc.UUID) %}
```
Prompts then get *live* scene data while paused instead of stale file data — a behavioral
improvement, not just a cleanup.

Also rewrite the distance/LOS branches at `0050_sexlab_activity.prompt:33-36` (a three-branch
bucket — the only consumer of `speaker_los`/`speaker_distance`) to use `has_line_of_sight` /
`distance_between`. `0550_sexlab_narration.prompt` calls the decorator but uses neither field.

⚠️ **Both prompts exist in two locations** — the shipping copy under
`SKSE/Plugins/SkyrimNet/external/goodprovider.sexlab/prompts/...` and a mirror under
`SKSE/Plugins/SkyrimNet/prompts/...`. **Apply every prompt edit to both.**

### `threads.json`: keep writing it, stop reading it

It stays as a developer artifact for inspecting exactly what is handed to SkyrimNet. Where it
is written changes, and that removes a real cost.

Today `MiscUtil.WriteToFile(threads_filename, json, append=False)` sits at the tail of
`GetThreadsJson` (`Scene_Manager.psc:~1650`), so **every decorator call writes the file from
the render path**. The `SaveThreadsJson()` wrapper (`:1548-1550`) is otherwise called only at
event time — `Scene.psc:1072,1083,1228` and `Handler_DOM.psc:223`.

**Target:** `SceneCore` builds the snapshot JSON **once at event time**, caches the string,
and writes `threads.json` at that same moment. The decorator returns the cached string — no
build, no file I/O, no VM on the render path. Delete `SaveThreadsJson` and the Papyrus writer.

This works only because dropping the `speaker_*` fields made the output speaker-independent,
which gives a nice property: the debug file is now **byte-identical to what SkyrimNet actually
receives**, rather than the separately-built approximation it is today.

### DOM threads: an explicit temporary shim

`GetThreadsJson` merges `main.handler_dom.GetThreads()` (`Scene_Manager.psc:1590-1592`), a
JContainers array owned by the separate SkyrimNet_DOM mod's Papyrus.

**DOM's thread state gets this same C++ treatment later**, so do not bake in the Papyrus
shape. `SceneCore` exposes a DOM-thread interface **in its own C++ terms**, fed for now by a
snapshot Papyrus pushes when DOM threads change. When DOM migrates it writes to that same
interface directly and the push path is deleted. The decorator never calls into DOM either
way, and its code does not change when DOM migrates.

### KNOWLEDGEBASE entry (required)

Add a dated entry recording: C++ decorators are safe to invoke while the game is paused
whereas Papyrus decorators are not; this is why the `isTimePaused` guard and the
`threads.json` cache existed; the guard is removed for any decorator once its body is fully
native.

### Tests

1. Run a scene, trigger LLM dialogue, diff the decorator output in `SkyrimNet.log` against the
   Papyrus JSON captured beforehand — equivalent apart from the three deliberately removed
   `speaker_*` fields (key order may differ).
2. Both prompts still render. The rewritten branches at `0050:33-36` gate correctly — test
   with the speaker **inside** the scene, **nearby but outside** it, and **far away with no
   line of sight**.
3. `Papyrus.0.log` shows **no** Papyrus activity on the render path. This is the stage's
   defining requirement.
4. **Pause test** — start a scene, open a menu / pause, trigger dialogue, confirm the data is
   live and current. This path previously always served stale `threads.json`.
5. `threads.json` is still written, updates on scene events, and matches the decorator output
   byte-for-byte.

---

## Stage 6 — WebUI build + commit

**Moves.** `BuildWebUIAnimationMenuState` (`:2084`), `BuildWebUISceneMenuObject` (`:2381`),
`BuildWebUISceneMenuState` (`:2516`), `WebUI_ApplyLivePositions` (`:2226`),
`WebUI_OnMenuPrevNext` (`:2322`), `WebUI_OnAnimUpdate` (`:2537`), `ApplyWebUICommit` (`:2639`),
the `TM_*` appliers (`:2999-3081`), `SeedOverlayFromAnimDb` (`:2908`), and the user-defaults
layer (`:2832-2902`).

**First use of Layer B mutations** — `thread.DisableOrgasm`, `SetVictim`, `GoToStage`,
`SetAnimation`/`AddAnimation`/`SetAnimations`/`SetForcedAnimations`, `ChangeActors`.
Re-read the write/read-ordering hazard in §2.2 before starting: keep the authoritative value
in `SceneCore` and never read it back through the bridge.

`WebUI_OnAnimUpdate` carries a 128-entry cap and eviction logic at `:2580-2633` — port the
behavior deliberately, don't approximate it.

**Delete on sight:** `WebUI_OnMenuClose` (`:2190`) and `WebUI_OnMenuLiveUpdate` (`:2211`) are
dead — no `onMenuClose` / `onMenuLiveUpdate` references remain in `index.html`.

§3 applies with full force here: the JS → C++ → `SceneCore` → bridge direction is the only
allowed one.

---

## Stage 7 — Orgasm pipeline

**Moves.** The orgasm window timer — `ArmOrgasmWindow` (`:1584`), `FlushOrgasmWindow` (`:1610`),
and `Event OnUpdate()` (`:1642`), which is the Scene's **only** Papyrus event. It is driven by
`RegisterForSingleUpdate` and re-arms itself in menu mode (`:1644`, `Utility.IsInMenuMode` →
re-register 0.5s). Replace with a C++ timer.

Also `OrgasmHelper` (`:1444`), `OrgasmMessagesToNarration` (`:1476`), `AddCum` (`:1661`),
`MarkOrgasmNarrated` (`:1544`), `GetOrgasmDelay` (`:1573`), `GetIsOrgasming` (`:926`),
`ThreadHasDomSlave` (`:1558`).

**Stays in Papyrus:** `AddCum` calls `sslObjectFactory.vaginal()/oral()/anal()` — object
construction, not a property read. Route via Layer B or keep a thin shim; do not attempt
Layer A here.

Note the DOM path deliberately uses the Scene's own `OnUpdate` rather than
`thread.UpdateTimer` (see the comment at `:1326-1332`) — preserve that distinction.

---

## Stage 8 — Lifecycle & events

**Goal.** Complete the eager-maintenance wiring (§2.3) and move pool ownership.

**Moves.** `Setup` (`:188`), `Setup_CheckLinks` (`:308`), `Release` (`:451`), `Initialize`
(`:147`), `AlignActors` (`:788`), `ReconcileVictimFactions` (`:388`), `PickNonVictimInitiator`
(`:340`), `SexLab_Thread_LOS` (`:1941`), `SetThread`/`GetThread` (`:951,960`).

**The event handlers.** SexLab mod events are registered on the **Manager**, not the Scene
(`Scene_Manager.psc:1355-1373`):

| SexLab hook | Manager handler | Scene method |
|---|---|---|
| `HookAnimationStart` | `AnimationStart` `:1376` | `Scene.AnimationStart()` `:1036` |
| `HookStageStart` | `StageStart` `:1396` | `Scene.StageStart()` `:1079` |
| `HookAnimationEnd` | `AnimationEnd` `:1416` | `Scene.AnimationEnd()` `:1225` |
| `HookOrgasmStart` | `OrgasmCombined` `:1478` | `Scene.OrgasmCombined()` `:1333` |
| `SexLabOrgasm` (SLSO) | `OrgasmIndividual` `:1494` | `Scene.OrgasmIndividual()` `:1365` |
| — (DOM, plain call) | `OrgasmCustom` `:1526` | `Scene.OrgasmCustom()` `:1399` |

These must remain Papyrus entry points — SexLab dispatches mod events into the VM — but each
becomes a thin stub calling a native. **Finish the refresh wiring any earlier stage deferred**
(Stage 4's notes, Stage 5b's pulled-forward subset).

**Pool ownership → C++.** `Scene_Manager.psc` owns a 10-slot `sl_scenes` array plus a generic
fallback, a `Form[] thread_scene` binding table indexed by SexLab `tid`, and
`GetSceneInactive` / `GetSceneByThread` / `GetSceneByActor` / `GetSceneBySid`
(`:386-460,619-625`). `sid` is just the array index. Note `GetSceneBySid` does **not** map -1
to the generic scene — preserve or fix deliberately, don't change it by accident.

There is **no Papyrus state machine** anywhere in Scene/Interface/Manager — every `GetState()`
is a read of *SexLab's* thread state (`"animating"` / `"prepare"`). The Scene's own lifecycle
is the `status` string already turned into an enum in Stage 3.

---

## Stage 9 — Cleanup

- Delete every shadowed Papyrus path and the parity toggle.
- `Scene.psc` reduced to SexLab event stubs and the Layer C residue.
- Delete `Scene_Interface.psc` if fully absorbed.
- Update `docs/developers/papyrus.md`, `docs/developers/webui.md`, and `AGENTS.md` key-paths
  if the source layout changed.
- Final `KNOWLEDGEBASE.md` entry summarizing the migration and any quirks found along the way.

---

## 6. Verification (every stage)

1. **`compile: pyro`** task — Papyrus clean. This task only, per `AGENTS.md`.
2. CMake re-configure + build. The DLL deploys via the existing POST_BUILD copy to
   `$SKYRIM_MODS_FOLDER/SkyrimNet SexLab/SKSE/Plugins/` (`CMakeLists.txt:120-133`). Note the
   **space** in that folder name, and that the repo's own `SKSE/Plugins/SkyrimNet_SexLab.dll`
   is the checked-in shipping copy, not the build output.
3. In-game: start a scene, run it to completion through several stages. Watch
   `SkyrimNet_SexLab.log` for parity mismatches and `Papyrus.0.log` for Papyrus errors.
4. **Save/reload mid-scene** — confirm C++ state clears and no scene is stranded (§2.4).
5. Parity stages: zero mismatches in `both`, then replay in `cpp`.

Log paths on this machine (Documents is OneDrive-redirected):

| Log | Path |
|---|---|
| SkyrimNet_SexLab | `C:\Users\bhuff\OneDrive\Documents\my games\Skyrim Special Edition\SKSE\SkyrimNet_SexLab.log` |
| SkyrimNet | `...\SKSE\SkyrimNet.log` |
| Papyrus | `...\Skyrim Special Edition\Logs\Script\Papyrus.0.log` |
| Crash | `...\SKSE\crash-*.log` |

---

## 7. Reference: patterns to copy

| Need | Copy from |
|---|---|
| Native binding module | `Papyrus_AnimationDB.cpp:294-311` + `plugin.cpp:40-63` |
| Mutex + in-memory mirror | `AnimationDB.cpp:16-21` |
| C++ → Papyrus method call | `Papyrus_WebUI.cpp:1090-1116` |
| C++ → Papyrus, bound to a Scene form | `Papyrus_WebUI.cpp:1126-1145` |
| Return value from Papyrus (⚠️ not hot paths) | `Papyrus_WebUI.cpp:788-874` |
| Variable-arity VM args | `ActionDispatch.cpp:202-235` |
| "Remember a Papyrus script instance" | `TargetMenuRegistry` — store FormID + script name, re-bind on use. There is **no** persisted VMHandle utility, and don't add one. |
| JS → C++ listeners | `WebUI.cpp:634-840` |
| C++ → JS | `WebUI_Invoke` / `WebUI_InteropCall` (`WebUI.cpp:536-556`). ⚠️ `WebUI.h:52-54` warns against PrismaUI's native `InteropCall` — it corrupts args. |

---

## 8. Follow-on: remaining decorators

**Not stages in this plan.** After Stage 5b the subsystem exists, so each of these is one new
file under `src/decorators/` plus one line in `Decorators::RegisterAll()`. Categories are
pre-assigned per §5b's thread-safety rule so the sweep never has to re-litigate it.

Note that **two of these never depended on the scene migration at all** and can be taken any
time after Stage 5b.

| Decorator | Papyrus body | Becomes | Depends on |
|---|---|---|---|
| `sexlab_intent` | `Decorators.psc:61-77` → `GetSceneByActor(a).intent` | **(a)** `SceneCore` lookup — trivial | Stage 4 |
| `sexlab_activities` | `:79-92` → `sl_scene.GetDescription()` | **(a)** `SceneCore` lookup | Stage 5 |
| `sexlab_ostim_player` | `:95-98` → `GetConfigInt("Plugin_SkyrimNet_SexLab", "sexlab.ostim.player")` | **(b)** config read — independent of everything | Stage 5b only |
| `sexlab_get_player_los_distance` | `:100-117` → `GetDistance` + `HasLOS` | **(c)** *must* use the main-thread cache helper — `HasLOS` is a raycast | Stage 5b only |
| `sexlab_nudity` | `:119-145`, currently commented out at `:25` | **(c)** `GetEquippedArmorInSlot` slots 32/52/49 | revive only if wanted |

**Endpoint:** `SkyrimNet_SexLab_Decorators.psc` is deleted entirely and its
`RegisterDecorators()` caller updated.

Beyond that: **DOM's thread state** gets the same treatment, writing directly into the
`SceneCore` DOM interface that Stage 5b establishes, with the Papyrus push path deleted.
