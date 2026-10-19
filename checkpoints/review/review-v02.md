# Review v02 — 0.36.1 working tree (threads JSON, Lover's Ledger, Aid potions)

Reviewed: uncommitted diff against `HEAD` (2026-10-18). Papyrus, SKSE, the Aid prompt, and `index.html`.
Lover's Ledger contracts checked against `C:\Skyrim\dev\mods\Lover-s-Ledger` (`TTLL_Store.psc`, `TTLL_SexlabIntegration.psc`, `FirstTimes.cpp`, `Papyrus_LoversLedger.cpp`).

Already on `HEAD` and not re-read: OStim TargetMenu, corpse health (`NECRO-DBG`), the AnimDB pyro fix itself. This pass covers what is still in the working tree, including the removal of the `DEBUG-DELETE(pplus-animdb)` instrumentation.

## Verdict

**Ready for in-game testing.** Nothing here recreates the JContainers cycle, and the new panels fail closed when their mods are absent. Three behavior bugs should be fixed or explicitly accepted before the features are called done. They mis-narrate; they do not crash or free another mod's data.

## What checked out

| Fact | Source |
|------|--------|
| `GetThreadsJson` builds the root and the `threads` array on the JSON store. Each SexLab thread is a `dump` + `objectFromPrototype` copy, so the scene's retained root is never parented into the temporary tree. `release` of the root frees that tree. | Scene_Manager.psc:1851-1942, JsonStore.cpp `AttachChild` |
| DOM threads stay in JContainers. `JValue.retain` is paired with the existing `JValue.release`. A per-thread `objectFromPrototype(ObjectToLowerCaseKeyJson(...))` bridges them. A failed bridge is skipped. | Scene_Manager.psc:1878-1927 |
| `JValueToJsonString` and every map/array helper take `depth` and return `null` past 32, with one trace. | Utilities.psc `JValueToJsonString` |
| Dead SNSL handles log once per session. `isExists` stays quiet. `WithCaller` publishes the VM stack so `TraceStack` names the Papyrus caller. `g_mutex` is recursive; `TraceStack` only walks the stack. | JsonStore.cpp:107-118, Papyrus_Json.cpp |
| `Mirror_Apply` and `ApplySexLabVoice` re-probe `isExists` before `getInt`. | Scene.psc:1119, :2874 |
| `GetFile(0)` in `BondageCatalog::OriginFile` and `JsonStore::MakeFormRef` matches the knowledgebase rule (defining plugin, not the last override). | KNOWLEDGEBASE.md "Bondage device ids named the override patch" |
| Lover's Ledger property paths are lowercased inside `LoversLedgerService::ParsePropertyPath`, so `exclusivesex` / `totalinternalclimax.did` resolve. | LoversLedgerService.cpp |
| `GetAllLovers` returns NPC bases. `ActorFromBase` is the right native. The player base short-circuits to the player. Ledger numbers go through `UniqueBaseID`, so a wrong reference still returns the right counts. | Papyrus_LoversLedger.cpp:43-78, Papyrus_Utilities.cpp:250-266 |
| Lover's Ledger UI writes names with `textContent`. A lover row with `formId` 0 is not clickable. | index.html `renderLoversLedger` |
| Builtin `openFunction` / `closeFunction` go through the same `DispatchEntryFunction` as the `papyrus` type. | ActionCatalog.cpp |
| `WebUI_MaybeRestoreScenePanel` leaves a non-Scene view up. That matches the updated knowledgebase and `webui.md`. | Papyrus_WebUI.cpp:1808 |
| Aid panel sends `penis` as `cock`. Drink stays `drink`, so Use stays enabled (`partLocation` returns the part name). Potions pass `points: 0`, so `StartChannel` falls through to `Apply`. A refused offer does not call `Apply`, so the potion stays. Escape on the offer answers No. | index.html `aidAccept`, `handleGlobalEscape`; Aid.cpp:584-589 |
| `SetSceneActs` runs from `Engine_SetSkills`, which runs after `BeginScene`, so the scene exists. Acts live on the scene, not the anchor. | Scene.psc:1818, :1842 |
| `SexLab_Aid` (`AidAction`) calls `Apply` with an empty location. No consent, no body-part line, full effect on the target. The panel path is the one that asks. | Papyrus_OrgasmEngine.cpp:168-175 |
| P+ AnimDB debug counters, `SceneDebug`, and `AnimDb_LastSyncFailures` are gone. `EndSync` still errors when every batch was dropped and the row map is empty. | AnimationDB.cpp, AnimDb.psc, PPlus.psc |

## Findings

1. **First-time sentences are dropped on two start paths, and P+ is given the wrong tags (important).**
   `StageStart` calls `FirstTimesSentence` only inside `status != STATUS_ACTIVE`, and only in the branch that builds `narration`.
   - `hold_stash` narrates `desc` and never asks Lover's Ledger. `status` is then `ACTIVE`, so later stages never ask either. (Scene.psc:3322-3323)
   - When a stashed orgasm is taken at that same start, `first_times` is appended to `narration` and then ignored: the event is `desc`. The orgasm DN that follows is the stash text only. (Scene.psc:3330-3338, :3433-3458)
   - An animation change is the `else` branch. Switching from a non-sexual stage to a vaginal one never reports a first.
   - Tags are `GetTagsString` → `AnimRawTags`. On P+ that is `SceneTags` (`GetSceneTags`), not `StageTags`. Lover's Ledger's contract is "On P+ pass stage tags" (`TTLL_Store.psc` `DescribeFirstTimes`). A scene tagged Vaginal because a later stage is vaginal reports "first time … vaginal" at stage 1. A stage-1 animation with no vaginal tag misses the first that happens at stage 3.
   - `DescribeFirstTimes` returns `""` if any position is null (`Papyrus_LoversLedger.cpp:274`). One empty slot blanks every line.
   - This call is not in any changelog. `CHANGELOG.md` describes the panel only.

   Suggested fix: append the sentence to whichever start string is actually sent (`desc` and the hold path), and on P+ pass `PPlus.StageTags` for the current stage. Call again when the animation changes if the new stage's tags differ. Skip None positions before the call.

2. **Potion "thrust into" picks the wrong partner (important for the new lines, harmless to the restore).**
   `Aid.cpp` `PotionLine` (:272-298) and `HasPenis` (:210-214).
   - Penis is `ActorBase` sex male. A futa or an SOS penis is not a partner, so the split line does not fire and the receiver gets the whole potion. A male base with no penis still counts.
   - The anal hole is the first other actor in position order, including the giver and including someone with no ass in the act (`:279-280`, lambda always true). "… on Bob's dick and it is thrust into Amy's ass" when Amy is just the other person in the scene.
   - Cock prefers vaginal over anal whenever both tags are set (`:275` before `:279`). 1.6x animations often carry both tags, so the line says pussy for an anal animation.
   - The effect split follows that choice. A wrong partner still halves the restore onto the giver.

   Suggested fix: treat the partner as whoever `GetSceneActs` says is on the other side of that act, using the same anatomy Lover's Ledger already computes (penis / vagina bits), and do not split unless that partner exists. When both tags are set, prefer the part the player picked (`ass` → anal, `pussy` → vaginal).

3. **`ActorFromBase` keeps the first reference (medium).**
   `RebuildBaseToRef` uses `emplace` (`Papyrus_Utilities.cpp:226-229`). `GetAllForms` order is undefined, so a dead body, a disabled duplicate, or a temporary clone wins and stays until that reference's base no longer matches. Ledger counts stay correct (`UniqueBaseID`). Clicking the row focuses that reference (`onMainPanelRow`), which can select a corpse. A miss inside 5 seconds of a non-empty index returns None without rebuilding (`:262-263`); the row then shows the base name and cannot be clicked.

   Suggested fix: prefer the loaded, enabled, living reference, and replace a dead or disabled one when a better reference is seen.

4. **Player changelog overstates the player's Yes/No (minor).**
   `CHANGELOG-player.md` says an NPC offering "one" opens Yes/No. The code and `CHANGELOG-developer.md` only do that for `drink`. Lips on the player are applied immediately (`WebUI.cpp:746-749`). `SexLab_Aid` never reaches `NeedsConsent` (finding table above). `docs/developers/orgasm-engine.md` puts the consent sentence in the bullet that also covers `SexLab_Aid`, which still uses the old "gives a potion" line.

5. **Healing potion kind is "healing" whenever health > 0 (minor).**
   `PotionKindOf` (`Aid.cpp:216-218`) labels a potion that restores both health and stamina as healing. The drink line and the accept prompt say "healing potion". The stamina still applies.

## Build (2026-10-18)

Not rebuilt in this pass. Timestamps: every touched `.pex` and `SKSE/Plugins/SkyrimNet_SexLab.dll` (12:47) are newer than their sources. `Scene.pex` 12:19 matches `Scene.psc` 12:19. `Menu.pex` 10/17 15:20 is after `Menu.psc` 15:20. `check-pex` was not re-run here.

## In-game test checklist

Traces: `GetThreadsJson`, `JValueToJsonString` "depth cap", `dead handle`, `ActorFromBase: indexed`, `OrgasmEngine: scene … acts`, `StrategyDecision: aid accept`, `Aid offer`, `FirstTimesSentence`.

| # | Setup | Expect |
|---|-------|--------|
| 1 | SexLab 1.6x scene running, decorator `sexlab_get_threads` (or any prompt that calls it). | `SkyrimNet_SexLab.log` `Get_Threads json:` is this mod's payload (`counter`, `threads`). No "recursion loop" dialog. No other mod's overlay data in that JSON. |
| 2 | Save mid-scene, load, let the enjoyment mirror tick. | At most one `dead handle` line per handle. Papyrus log has a `SkyrimNet_SexLab JSON store:` stack on the first one. Voices and enjoyment still update. |
| 3 | Lover's Ledger installed. Open the view on a unique NPC who has lovers. Change the ControlPanel target. Click a lover. | Summary, did/got, and lover rows match the ledger. The view stays open across the target change and refreshes. Clicking a lover selects them. A non-unique NPC shows the "not unique" empty line. |
| 4 | Lover's Ledger installed. Start a scene that is someone's first (and a scene that is not). | Start narration includes "This is the first time …" only when it is a first. Watch finding 1: an orgasm folded into that same start, and a P+ scene whose vaginal tag is on a later stage. |
| 5 | Aid panel, stamina potion, NPC target, part drink, then lips. | Decision request `sexlab/aid_accept`. Accept drinks / applies and removes one potion. Refuse narrates "X refused Y's stamina potion." and the potion remains. The refuse shows up as a punish reason. |
| 6 | Aid panel, NPC subject, player target, drink, then lips. | Drink opens Yes / No (`Aid offer` in the log). No leaves the potion. Lips applies with no dialogue (finding 4). |
| 7 | Vaginal scene, potion on pussy; anal scene, potion on ass; same animation tagged both. | Split line names the penetrating actor and the matching hole. Half the restore on each. Finding 2: both-tags and a female-only anal scene. |
| 8 | Injury Engine on, healing potion, drink and pussy. | Injury Engine narrates. Drink does not also get a second line from us. |
| 9 | Close the Aid panel with a potion and a custom part, reopen. | The same subject, target, potion, part, and typed points come back when they are still legal. |
| 10 | P+ AnimDB rebuild after this tree. | No `DEBUG` / `LastSyncFailures` / `SceneDebug` lines. DB row count is non-zero. |
