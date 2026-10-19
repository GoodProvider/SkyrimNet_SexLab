# Review v03 — 0.36.1 commit d3c86c0 (threads JSON, Lover's Ledger, Aid potions)

Reviewed: `git show d3c86c0` against `0264d45` (2026-10-18). Papyrus, SKSE, `index.html`, and `aid_accept.prompt`. This is a second, independent pass over the same tree as v02. v02 was written at 13:40, and the tree was committed unchanged at 14:00.

## Verdict

**Ready to ship once the edge cases below are accepted or fixed.** Potions were tested in game and work (user, 2026-10-18). v02's five findings were not changed in `d3c86c0`. This pass found one more (new finding 1): it only shows up when the actor who applies the potion is not the scene partner the line names. The normal test, where the giver is the partner, works. Nothing here crashes, leaks a JSON store root, or touches another mod's JContainers data.

## What checked out (beyond v02's table)

| Fact | Source |
|------|--------|
| `GetThreadsJson` has no early return between `SNSL_JMap.object()` and `SNSL_JValue.release(obj)`. A failed `JsonLowerCaseKeys` falls back to `"{}"` and still releases. | Scene_Manager.psc:1855-1943 |
| `JValue.retain(threads_dom)` is paired with the release that was already there. The DOM loop only reads children of the retained array. | Scene_Manager.psc:1880, :1941 |
| `onAidResult` runs `NeedsConsent` / `AidAskConsent` inside `AddTask`, so `g_aidOffer` and `ListOptions` stay on the game thread, as their comments say. `onAidOfferResult` also hops to the game thread before it reads the token. | WebUI.cpp:892-925, :930-953 |
| `RequestAidAccept` calls `done` on the game thread in every path: no route, not queued, failed, and answered. An answer the game cannot read counts as accept (`key != "refuse"`). | StrategyDecision.cpp:852-908 |
| `NeedsConsent` only matches carried potions, so spells and body parts never wait for an answer. `Apply` checks the inventory again when the answer arrives. A potion used up in the meantime gives no line and no refusal. | Aid.cpp:610-616, :553-558 |
| `aid_accept.prompt` uses the same `decnpc` / `sexlab_get_threads(focus_uuid)` / `render_character_profile` calls as `minigame_strategy.prompt`. The question key `accept` and the choices `accept` / `refuse` match what C++ reads back (`answers.accept.choice`). | prompts/decisions/sexlab/*.prompt |
| `GetSceneSpeedLevel` returns -1 for an actor in no scene, so `StyleWord` adds no adverb. It does not fall back to "gently". | OrgasmEngine.cpp:3661-3671 |
| `Engine_SetSkills` (and with it `SetSceneActs`) also runs from `CheckAnimationChange`, `StageStart`, and the live WebUI edit paths, so the acts follow animation changes. | Scene.psc:768, :3265, :5037, :5662 |
| `TT_LoversLedger.esp` is ESL-flagged (header flags 0x200). `IsInstalled` uses `GetModByName != 255`, the same check this repo already uses for ESL-flagged `SkyrimNet_DOM.esp` and `TT_OStimNet.esp`. That is consistent, not a new risk. | LoversLedger.psc:14, Main.psc:145, :187 |
| Lover's Ledger view, offer dialog, and part labels write text with `textContent` only. | index.html `renderLoversLedger`, `openAidOffer` |

## Findings

### New in v03

1. **Shared potion effects go to the giver, not to the partner the line names (medium; edge case outside the in-game test).**
   `Apply` (Aid.cpp:568-601) restores `share` to the target and, when `split`, the other half to `c`, the **caster**. `PotionLine` picks the partner (`ScenePartner`) only for the sentence. The partner never gets anything.
   - Player (a bystander) → Amy, part `ass`, Bob in Amy anally. Line: "… on Bob's dick and it is thrust into Amy's ass." Amy gets half, **the player** gets half and the spell visuals (`PlaySpellVisuals(c, c, …)`), and Bob gets nothing.
   - Amy applies a potion to her own ass while Bob is in her: `caster == target` sets `split = false` (:570). The line still says it is thrust in from Bob's dick, Amy gets everything, Bob gets nothing.
   - The effect is right when the giver is the partner (Amy puts the potion on Bob's dick and he is in her; the player in the scene uses it on their partner). That is the usual setup, which is why the in-game test passed.

   Suggested fix: have `PotionLine` return the partner (`RE::Actor*`) instead of a `bool`, and restore / show the visuals on that partner instead of `c`. Split whenever a partner exists, whoever the caster is. This replaces v02 finding 2's last bullet.

2. **Acts for the potion lines use P+ scene tags too (medium; same cause as v02 finding 1).**
   `SetSceneActs(..., AnimHasTag("Vaginal"), …)` (Scene.psc:1843) → `AnimTag` → on P+ `SceneHasTag(anim.Registry, …)` (Scene.psc:4598-4600). These are the scene's tags, not the stage's. A P+ scene that is oral at stage 1 and anal at stage 3 reports all three acts from the start, so the potion line claims a penetration that is not happening yet. Fix this together with v02 finding 1: use stage tags on P+, and call `SetSceneActs` on stage change, not only on animation change. Nit: the same line has a long run of spaces before the third argument.

3. **The player is asked to consent to a pick the player just made (minor, design question).**
   The Yes/No offer (`AidAskConsent`, WebUI.cpp:738-761) is reached only from the Aid panel, which only the player drives. Choosing an NPC subject and the player as target, then Drink, opens "X offers you a … potion. Drink it?". That is a second confirmation of what the player just picked. "No" also records a punish reason for the NPC against the player (`AddPunishReason(giver, receiver, …)`, WebUI.cpp:727), for refusing an offer the NPC never chose to make. Decide whether the player-as-target path should skip consent (and the punish reason), or whether the extra step is intended role-play. Also only one offer can be pending (`g_aidOffer`): a second offer overwrites the token, and the first dialog's answer is dropped as stale with no narration.

4. **`ActorFromBase` rescans every form on misses that will always miss (low; adds to v02 finding 3).**
   A lover whose base has no reference left (deleted, or never placed) misses `LookupRef` every time. After the 5 s window, each panel refresh rebuilds the whole base→ref index (`GetAllForms` walk under the form-map read lock, Papyrus_Utilities.cpp:250-266). The ControlPanel refreshes the view on every focus change, so changing targets every few seconds walks every form each time. Suggested: remember the base IDs known to miss until the next rebuild, or only rebuild when the form count changes.

5. **`GetThreadsJson` counts a DOM thread whose bridge failed as kept (nit).**
   `dom_kept += 1` (Scene_Manager.psc:1925) runs even when `thread_snsl` is 0, so the `--- dom threads:N kept:M` trace overstates what reached the JSON. Move it inside `if thread_snsl`.

### Carried from v02 (still open in d3c86c0)

| v02 # | Summary | Status |
|-------|---------|--------|
| 1 | First-time sentences: dropped on the `hold_stash` path and on a stashed orgasm folded into the start; not checked on animation change; P+ passes scene tags, not stage tags; a None position blanks every line; not in any changelog. | Open. Scene.psc:3330 unchanged. See new finding 2 for the shared tag cause. |
| 2 | Potion partner choice: `HasPenis` uses base sex (futa / SOS wrong); the anal partner is "any other actor"; vaginal beats anal when both tags are set. | Open (Aid.cpp:210-214, :276-292). The effect half of this is now new finding 1. |
| 3 | `ActorFromBase` keeps the first reference it finds (corpse / disabled duplicate), and a miss within 5 s returns None. | Open (Papyrus_Utilities.cpp:226-229, :262-263). See new finding 4. |
| 4 | `CHANGELOG-player.md` says any offer opens Yes/No; only `drink` does. `orgasm-engine.md` puts the consent sentence next to `SexLab_Aid`, which never asks. | Open. |
| 5 | `PotionKindOf` labels a health + stamina potion "healing". | Open (Aid.cpp:216-218). |

## Suggested fix order

1. New finding 1 and v02 finding 2 together, in one `PotionLine` change (a bystander or self-applied potion goes to the wrong actor; this changes gameplay, not just narration).
2. v02 finding 1 + new finding 2 together: one P+ stage-tag helper used by both `FirstTimesSentence` and `SetSceneActs`, called on stage change.
3. v02 finding 4 changelog/doc text, and a decision on new finding 3.
4. v02 findings 3, 5 and new findings 4, 5 when convenient.

## Build

Not rebuilt in this pass. `d3c86c0` says "Rebuilt pex (pyro, check-pex clean) and release DLL"; that was not re-run here.

## In-game test checklist

v02's checklist (rows 1-10) still applies. Potion rows 5-9 were covered by the user's in-game test (2026-10-18). Rows 11-13 below are setups that test likely did not cover. Add:

| # | Setup | Expect (today) / after fix |
|---|-------|----------------------------|
| 11 | Player not in the scene. Bob anal with Amy. Aid: subject player, target Amy, stamina potion, `ass`. | Today: `Aid: … split true` in the log, and the player's stamina rises. After the fix, Bob's stamina rises and the player's does not. |
| 12 | Same scene, subject Amy, target Amy, `ass`. | Today: the line names Bob's dick, `split false`, and only Amy gets stamina. After the fix, Bob gets half. |
| 13 | P+ scene: oral stage 1, anal later. Potion on `ass` at stage 1. | Today: the split line fires at stage 1 (`OrgasmEngine: scene … acts … anal true`). After the fix, the "pushes … up … ass" line fires, then the split line from the anal stage on. |
| 14 | Aid: subject NPC, target player, Drink, answer No. | Today: "Player refused X's … potion." is narrated and becomes the NPC's punish reason against the player. Confirm whether that is wanted (new finding 3). |
| 15 | Lover's Ledger: an NPC with a lover whose reference was deleted. Change ControlPanel targets every few seconds. | `ActorFromBase: indexed` appears on each refresh after 5 s (new finding 4). |
