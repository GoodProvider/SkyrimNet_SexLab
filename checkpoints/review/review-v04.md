# Review v04 — 0.36.1 commit d3c86c0: potion offer decision

Follows v03 (same tree, `d3c86c0`, 2026-10-18). No code has changed since v03. This pass records the user's decision on v03 finding 3, with the spec it now needs. Every other open item from v02 and v03 is carried as it was.

## Verdict

**Ready to ship once the edge cases are accepted or fixed. v03 finding 3 is no longer a question. It is a small feature to build: two new buttons.**

## Decision on v03 finding 3 (2026-10-18)

The potion offer stays, even when the player made the pick themselves in the Aid panel. **This is intended role-play.** The player sets up the offer and then plays the receiver's answer. The punish reason that a refusal records also stays.

The dialog goes from two buttons to four. Every button narrates directly. Yes applies the potion. No records a punish reason.

| Button | Narration (direct) | Effect |
|--------|--------------------|--------|
| Yes | "Amy drinks Bob's stamina potion." | Potion applied |
| Yes, custom | "Amy drinks Bob's stamina potion, because <text>." | Potion applied |
| No | "Amy refused Bob's stamina potion." | Punish reason = that line |
| No, custom | "Amy refused Bob's stamina potion, because <text>." | Punish reason = the full line with the text |

When Injury Engine is installed and the potion heals, the line goes to `InjuryEngine::Heal`, as it does today. The custom text is added before that hand-off, so Injury Engine narrates the line with the reason in it.

### Implementation spec

| Area | Change | Where |
|------|--------|-------|
| Aid | New `WithBecause(line, because)`. Empty text leaves the line as is. Otherwise it drops the trailing `.`, strips a leading "because " (as OrgasmEngine.cpp:2996 does), and appends `", because " + text`, with the `.` added back only if the line had one. `Apply` gets `const std::string& because = ""`, applied right after `line` is built, before the Injury Engine hand-off and the return. | Aid.h:42-50, Aid.cpp:569 |
| WebUI C++ | `AidFinishConsent` gets `because`. Refuse: `WithBecause(RefusalReason(...), because)` is narrated and kept as the punish reason. Accept: passed into `Apply`. The NPC decision path and lips-on-player pass `""`. `onAidOfferResult` reads `reason`, passes it through the task, and logs it. The `AidAskConsent` comment notes the role-play intent. | WebUI.cpp:713-766, :929-953 |
| index.html | `#aid-offer-panel` uses the `#yesno-panel` layout: a choices block (Yes, Yes custom, No, No custom) and an "Explain why" block (textarea, Accept disabled until there is text, Cancel). `aidOfferAnswer(accept, reason)` sends `{token, accept, reason}`. The explain helpers are copied from `yesNoExplain*`. Open and hide reset to the choices. Escape in the explain block goes back to the choices; Escape on the choices still answers No. | index.html:2460-2468, :8943-8974, :3526 |
| Docs | KNOWLEDGEBASE Aid section: the decision, the four buttons, and the single pending offer (`g_aidOffer`; a second offer makes the first answer stale). Three changelogs: the four buttons and `reason` in `onAidOfferResult`. Fix the CHANGELOG-player.md:23 wording from v02 finding 4 in the same edit. `docs/developers/webui.md` gets the listener field if it lists listeners. | KNOWLEDGEBASE.md:58-64, CHANGELOG*.md |

Build: a release DLL only. Papyrus does not change.

The single pending offer (`g_aidOffer`) stays as a low note. A second offer replaces the token, and the first dialog's answer is dropped as stale with no narration. The decision did not cover it.

## Open findings (carried, unchanged in d3c86c0)

| # | Summary | Severity | Source |
|---|---------|----------|--------|
| v03-1 | Split potion effects go to the caster, not the partner the line names (bystander or self-applied potion). | medium | Aid.cpp:568-601 |
| v03-2 | P+ uses scene tags, not stage tags, for `SetSceneActs`. It is not refreshed on stage change. | medium | Scene.psc:1843, :4598-4600 |
| v03-3 | **Decided: build the spec above.** | — | — |
| v03-4 | `ActorFromBase` rebuilds the whole index on lookups that will always miss, on every panel refresh. | low | Papyrus_Utilities.cpp:250-266 |
| v03-5 | `dom_kept` counts a DOM thread whose bridge failed. | nit | Scene_Manager.psc:1925 |
| v02-1 | First-time sentences: hold_stash or stashed orgasm drops them, no check on animation change, P+ scene tags, a None position blanks every line, no changelog entry. | medium | Scene.psc:3330 |
| v02-2 | Potion partner choice: `HasPenis` checks base sex, anal partner is "any other actor", vaginal beats anal. | medium | Aid.cpp:210-214, :276-292 |
| v02-3 | `ActorFromBase` keeps the first reference it finds (corpse or disabled duplicate). A miss within 5 s returns None. | low | Papyrus_Utilities.cpp:226-229, :262-263 |
| v02-4 | Changelog and doc consent wording (any offer vs drink only; `SexLab_Aid` never asks). | low | CHANGELOG-player.md:23, orgasm-engine.md |
| v02-5 | `PotionKindOf` labels a health + stamina potion "healing". | nit | Aid.cpp:216-218 |

## Suggested fix order

1. v03-1 + v02-2: one `PotionLine` change. The partner gets the split effect and visuals.
2. v02-1 + v03-2: one P+ stage-tag helper, called on stage change.
3. v03-3: the four-button offer (spec above), with v02-4 fixed in the same changelog edit.
4. v02-3, v02-5, v03-4, v03-5 when convenient.

## In-game test checklist

v03 rows 1-13 and 15 still apply. Row 14 is replaced. Rows 16-19 are new.

| # | Setup | Expect |
|---|-------|--------|
| 14 | Aid: subject NPC, target player, Drink, No. | "Player refused X's … potion." is narrated and becomes the NPC's punish reason against the player. This is intended. |
| 16 | Same setup, Yes custom "I'm exhausted". | "Player drinks X's stamina potion, because I'm exhausted." Stamina rises and the potion leaves X. |
| 17 | Same setup, No custom "because I don't trust you". | The line has exactly one "because". No effect, and the potion stays. In Punish with X as punisher, the reason list shows the full line. |
| 18 | Open the explain block, then press Escape, then Cancel. | Both go back to the four buttons. Escape on the four buttons answers No. |
| 19 | Injury Engine installed, health potion, Yes custom. | The Injury Engine heal narration includes ", because <text>". |

Log line to check: `onAidOfferResult token=… accept=… reason='…'`.
