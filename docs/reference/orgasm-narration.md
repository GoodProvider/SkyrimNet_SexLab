# Orgasm narration contract

Canonical gate used by `0550_sexlab_narration.prompt`.

## Gate

```inja
contains(_direct_narration, " is orgasming.") or contains(_direct_narration, " are orgasming") or contains(_direct_narration, " forced to orgasm")
```

These three substrings must stay exact on the whole direct-narration string. The not-orgasming, recovering and denied forms must contain none of them.

## One message per orgasm moment

The LLM cannot answer an endless prompt, so every orgasm moment produces **one** DirectNarration (DN).
- **All actors, every check.** When anyone orgasms (natural, forced, safety net, allow, DOM melt, external SexLab), every other actor at `sexlab.enjoyment.group_join` (default 95) or more joins them. This skips DOM slaves and actors who are denied, edging or cooling down. They all go into the same message.
- **Grouped sentences.** Each actor is in exactly one state. Names in a state are joined as `A` / `A and B` / `A, B, and C`.
- **Budget.** `sexlab.narration.max_chars` (default 350) limits the DN. Lower-priority parts that don't fit go into one `RegisterEvent("sexlab update", …)` sent after the DN (`Scene.SendOrgasmOverflow`).

| State | When | One actor | Group | Priority |
|-------|------|-----------|-------|----------|
| Forced orgasm | WebUI forced request (`RequestOrgasm(…, true, "webui")`) | `Nina is forced to orgasm by Bob. ` | `Nina and Ann are forced to orgasm by Bob. ` | always DN |
| DOM melt | `OrgasmCustom` with DOM's text | `<melt text>. Nina is orgasming. ` | one `<melt text>` with `Nina and Ann`, then `Nina and Ann are orgasming. ` | always DN |
| Orgasming | fired in this group | `Nina is orgasming. ` / `Nina is orgasming. again. ` | `Nina and Ann are orgasming. ` / `… are orgasming again. ` | always DN |
| Denied | not fired, `deny_orgasm` 1 | `Nina is denied orgasm by Bob. ` | `Nina and Ann are denied orgasm by Bob. ` | always DN |
| Recovering | not fired, orgasmed earlier this scene | `Nina is recovering from her orgasm. ` | `Nina and Ann are recovering from their orgasms. ` | budget |
| Not orgasming | everyone else | `Nina isn't orgasming right now. ` | `Nina and Ann aren't orgasming right now. ` | budget |

**Order** (`Scene.OrgasmMessagesToNarration`):
1. Always in the DN: allow prefix, then forced, DOM melt, orgasming and denied.
2. While the budget allows, in this order: cum (`AddCum`), recovering / not orgasming / DOM `HandleOrgasmDenied`, then the folded arouse/calm lines.

The tentacles line is added once.

- **Allow prefix.** `deny_orgasm` 1 → 0 calls `OrgasmEngine.AllowOrgasm(actor, denier)`, which unblocks the actor and checks every actor at once.
  - If anyone is at 100, they fire (plus the group join), and the DN starts with `"<denier> allows <actor> to orgasm. "`.
  - Otherwise the plain `"<denier> allows <actor> to orgasm."` is sent. That is a DN for the player, or an event for the LLM action.
- **Denier.** Stored as `deny_by` on the position obj and persisted beside `deny_orgasm`. It is the player (HUD, Description Editor, TargetMenu) or an aggressor NPC (LLM `SexLab_DenyOrgasm` / `SexLab_AllowOrgasm`; see [../authors/actions.md](../authors/actions.md)). An empty value falls back to the player's name.
- **Folded mini-game lines.** Pending arouse/calm narrations about anyone in the group are taken out of the engine's narrate queue and appended (budget) instead of racing the orgasm DN as their own DN.
- **DOM melt grouping.** `Scene.MeltKey` drops the manager's `". <name> is orgasming."` clause and turns the slave's name into `{n}`. Slaves with the same key share one melt sentence.

## Who triggers orgasms

The C++ OrgasmEngine ([../developers/orgasm-engine.md](../developers/orgasm-engine.md)) decides every orgasm in every scene. SexLab's own trigger is off (`thread.DisableAllOrgasms(true)` in `Scene.Engine_BeginScene`).

- **Engine group:** in each tick, per scene, everyone who fires (at 100, forced, safety net) plus the group join → one `Effect_OrgasmGroup` → `Scene.Orgasm_ApplyGroup`. That calls `thread.ForceOrgasm` per actor, stashes each one (`StashOrgasm`), and then:
  - `individual`: narrates now (`NarrateOrgasmStash`), or joins an open window;
  - safety-net-only groups: `ArmOrgasmWindow`.
- **Safety net (final stage, mini-game on or off, no LeadIn):** at 90% of the final stage's timer, each non-DOM actor at 90 or more who hasn't orgasmed, isn't blocked or edging, and wasn't calmed in that stage fires as a non-individual group (stash + window). Actors below 90 don't orgasm; the afterglow says `failed to orgasm` when one was expected.
- **External orgasms** (DOM melt `NoteExternalOrgasm(slave, "dom")`, another plugin's SexLab orgasm `"sexlab"`):
  - The caller stashes that actor (`OrgasmCustom` / `OrgasmIndividual`) and arms the window.
  - The engine's group join for it arrives as a non-individual group in the same window, so both are one DN.
- `Orgasm_ApplyGroup` sends no thread hooks. `Scene.Engine_SetStage` sends `OrgasmStart` on entering the final stage, and `OrgasmEnd` on leaving it or at `AnimationEnd`, as SexLab does.
- `Scene_Manager.OrgasmIndividual` (SexLab's `SexLabOrgasm`) returns early for the engine's own orgasms (`ConsumeOwnOrgasm`). `ForceOrgasm` still sends that event, and it must not narrate a second time.
- The Description Editor / TargetMenu orgasm button sends `RequestOrgasm(actor, force=true, "webui")`. It skips every gate, including `deny_orgasm`, and narrates exactly once, in the forced row.
- Denied at 100: `0550_sexlab_narration.prompt` tells an actor with `deny_orgasm` 1 and `enjoyment` ≥ 100 that their mind is consumed by a need to cum.
- The engine blocks DOM slaves, because DOM rolls its own orgasms.

## Rules

- Dom: `Handler_DOM.DOMSlave_Orgasmed` → `Scene_Manager.OrgasmCustom` appends `". "+name+" is orgasming."`. `Scene.OrgasmCustom` strips it again into the melt key; the builder re-adds the slave in the orgasming sentence.
- `Scene.OrgasmCustom` returns without stash / total bump / DN when the actor's `deny_orgasm==1`. `no_orgasm` (not expected) no longer blocks: it only stops passive gain.
  - DOM rolls its own orgasm (`DOM_Mind.IsOrgasmingAfterArousal`) and ignores SexLab `DisableOrgasm`. Its `should_be_noorgasm` only shifts the odds, so the bridge must gate what it reports.
  - Exception: `ignore_no_orgasm=true` (Description Editor orgasm button, `Scene.WebUI_ForceOrgasm`) narrates anyway.
- The Dom player-orgasm tease (`squirms under your grasp` / `your orgasm submerges you`) is **not** a slave climax. `DOMSlave_Orgasmed` must return without `OrgasmCustom` or DN.
- `StashOrgasm` bumps the actor's total (absolute for SLSO). It never downgrades a forced or melt slot to a plain orgasm within the same window. `orgasm_messages[i]` stays non-empty for every stashed slot (`OrgasmCombined` checks `== ""`).
- Dom Combined fallback: if an orgasm is expected and the totals increased since the last orgasm DN (`orgasm_narrated`) but the custom text raced empty, the slave still goes into the orgasming sentence. A slave with no orgasm at all gets DOM's `HandleOrgasmDenied` text (budget part).
- Combined + Dom last-stage: do **not** DirectNarrate a melt immediately.
  - `OrgasmCustom` / `OrgasmCombined` / `OrgasmIndividual` stash and (re)start a Scene `OnUpdate` window (`sexlab.orgasm.delay`, default 5 s), so every climax is counted. Then one DN holds every orgasm clause.
  - StageStart must not consume the stash while that window is open.
  - The style-change DN is skipped while the stash is pending.
- Window cap: `ArmOrgasmWindow` records `orgasm_window_started_at` on first arm. Later events may restart the timer, but never past **2×** `orgasm_delay` from that start; then it flushes immediately.
- `NarrateOrgasmStash` (used by `FlushOrgasmWindow`) calls `AlignActors()` before `OrgasmMessagesToNarration`, so names and `orgasm_narrated` match `thread.positions`. If `thread` is None, `ClearOrgasmStash` clears the stash without narrating.
- `AnimationStart` (first start / STATUS_SETUP path): if a stash is still pending, flush it before clearing.
- `AnimationEnd` folds a leftover stash into the end DN, keeping room for the intent sentence. The afterglow goes into the overflow event when it doesn't fit.
- A melt during StageEnd / mid-stage-change must still reach `OrgasmCustom`. `GetSceneByActor` / `OrgasmCustom` fall back to `thread_scene` (any state). If the scene is still None, Handler delays 1 s and retries `OrgasmCustom`; it only DirectNarrates (same gate) when the scene is still unreachable.
- Orgasm flush is **DirectNarration**, not RegisterEvent-only. StageStart must not `RegisterEvent` the same orgasm sentence immediately before the DN: `CheckDuplicate` stores that string and blanks the DN, so 0550 never gates. The overflow event never holds a gate string.

If you change the gate in the prompt, update every Papyrus site that builds an orgasm sentence (`Scene.OrgasmMessagesToNarration`, `Handler_DOM` unreachable-scene fallback).

## Example (Papyrus)

[`Scripts/Source/SkyrimNet_SexLab_Scene.psc`](../../Scripts/Source/SkyrimNet_SexLab_Scene.psc), `OrgasmMessagesToNarration`:

```papyrus
must += NamesClause(forced_names, forced_n, "is forced to orgasm by "+player_name+".", "are forced to orgasm by "+player_name+".")
must += melts
must += NamesClause(orgasm_names, orgasm_n, "is orgasming.", "are orgasming.")
must += denied
others += NamesClause(idle_names, idle_n, "isn't orgasming right now.", "aren't orgasming right now.")
```
