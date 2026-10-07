# Orgasm narration contract

Canonical gate used by `0550_sexlab_narration.prompt`.

## Gate

```inja
contains(_direct_narration, " is orgasming.") or contains(_direct_narration, " are orgasming") or contains(_direct_narration, " forced to orgasm")
```

These three substrings must stay exact on the whole direct-narration string. The not-orgasming, recovering and denied forms must contain none of them.

## One message per orgasm moment

The LLM cannot answer an endless prompt, so every orgasm moment produces **one** DirectNarration (DN).
- **All actors, every check.** When anyone orgasms (natural, forced, safety net, allow, DOM melt, external SexLab), every other actor rolls once (enjoyment + random(0, `random_bonus`) must reach 100), and passers join them. In the second-to-last stage, when the lead's orgasm reaches their target (the scene jumps), everyone still out rolls again with `stage_spike` added to the roll, so a final-stage orgasm happens now, in this message. A fail there is final for the scene. At a gate pass, others at `sexlab.enjoyment.group_join_final` (default 90) or more join. This skips DOM slaves and actors who are denied, edging or cooling down. They all go into the same message.
- **Grouped sentences.** Each actor is in exactly one state. Names in a state are joined as `A` / `A and B` / `A, B, and C`.
- **Budget.** `sexlab.narration.max_chars` (default 350) limits the DN. Lower-priority parts that don't fit go into one `RegisterEvent("sexlab update", …)` sent after the DN (`Scene.SendOrgasmOverflow`).

| State | When | One actor | Group | Priority |
|-------|------|-----------|-------|----------|
| Forced orgasm | WebUI forced request (`RequestOrgasm(…, true, "webui")`) | `Nina is forced to orgasm by Bob. ` | `Nina and Ann are forced to orgasm by Bob. ` | always DN |
| DOM melt | `OrgasmCustom` with DOM's text | `<melt text>. Nina is orgasming. ` | one `<melt text>` with `Nina and Ann`, then `Nina and Ann are orgasming. ` | always DN |
| Orgasming | fired in this group | `Nina is orgasming. ` / `Nina is orgasming. again. ` | `Nina and Ann are orgasming. ` / `… are orgasming again. ` | always DN |
| Denied | not fired, `deny_orgasm` 1 | `<lead-in>Nina was denied an orgasm by Bob. ` | `<lead-in>Nina and Ann were denied an orgasm by Bob. ` | always DN |
| Recovering | not fired, orgasmed earlier this scene | `Nina is recovering from her orgasm. ` | `Nina and Ann are recovering from their orgasms. ` | budget |
| Not orgasming | everyone else | `<lead-in>Nina is not orgasming right now. ` | `<lead-in>Nina and Ann are not orgasming right now. ` | budget |

**Lead-in** (`Scene.EnjoymentBand` / `BandLeadIn`, live enjoyment from `Scene.LiveEnjoyment`). Denied and not-orgasming actors are grouped by band, so each band gets its own sentence (lowest first; denied is grouped by denier and then by band):

| Enjoyment | Lead-in |
|-----------|---------|
| 0–30 | *(none)* |
| 31–60 | `Though aroused, ` |
| 61–89 | `Although close, ` |
| 90+ | `Although on the edge, ` |

**Order** (`Scene.OrgasmMessagesToNarration`):
1. Always in the DN: allow prefix, then forced, DOM melt, orgasming and denied.
2. While the budget allows, in this order: cum (`AddCum`), recovering / not orgasming / DOM `HandleOrgasmDenied`, then the folded arouse/calm lines.

The tentacles line is added once.

- **Allow prefix.** `deny_orgasm` 1 → 0 calls `OrgasmEngine.AllowOrgasm(actor, denier)`, which unblocks the actor and checks every actor at once.
  - The allowed actor takes the normal orgasm test at once (enjoyment + the mini-game random bonus ≥ 100, or a pending request; not cooling / edging / out after the final roll). Everyone else fires only at 100. Whoever fires (plus the group join) gets the normal orgasm DN, starting with `"<denier> allowed <actor> to orgasm. "`.
  - Otherwise the plain event `"<denier> permits <actor> to orgasm."` is sent (every source: HUD, Description Editor, LLM action).
  - Deny sends the event `"<denier> forbids <actor> from orgasming without permission."`
- **Denier.** Stored as `deny_by` on the position obj and persisted beside `deny_orgasm`. It is the player (HUD, Description Editor, TargetMenu) or an aggressor NPC (LLM `SexLab_DenyOrgasm` / `SexLab_AllowOrgasm`; see [../authors/actions.md](../authors/actions.md)). An empty value falls back to the player's name.
- **Folded mini-game lines.** Pending arouse/calm narrations about anyone in the group are taken out of the engine's narrate queue and appended (budget) instead of racing the orgasm DN as their own DN.
- **DOM melt grouping.** `Scene.MeltKey` drops the manager's `". <name> is orgasming."` clause and turns the slave's name into `{n}`. Slaves with the same key share one melt sentence.

## Who triggers orgasms

The C++ OrgasmEngine ([../developers/orgasm-engine.md](../developers/orgasm-engine.md)) decides every orgasm in every scene. SexLab's own trigger is off (`thread.DisableAllOrgasms(true)` in `Scene.Engine_BeginScene`).

- **Engine group:** in each tick, per scene, everyone who fires (at 100, forced, safety net) plus the group join → one `Effect_OrgasmGroup` → `Scene.Orgasm_ApplyGroup`. That calls `thread.ForceOrgasm` per actor, stashes each one (`StashOrgasm`), and then:
  - `individual`: narrates now (`NarrateOrgasmStash`), or joins an open window;
  - final stage (unless the dialogue hold is on): always the window. When the window would flush, `OrgasmWindow_HoldForFinish` checks `OrgasmEngine.FinalStageRemaining`. If the stage ends inside the window cap (2× `orgasm_delay` from its start), it waits and `AnimationEnd` folds the stash into the finish DN (`"Bob is orgasming. Nina is orgasming. again. … Nina and Bob finish."`). Otherwise it flushes on its own;
  - safety-net-only groups: `ArmOrgasmWindow`.
- **Gate (`sexlab.ending.gate`, no LeadIn):** just before the final stage (early by the measured DN→speech time), each actor who hasn't orgasmed rolls once (enjoyment + random(0, `random_bonus`) + `stage_spike` must reach 100). The passers are stashed and narrated **at once** as one DirectNarration (`Scene.Engine_GatePassed`, direct even in NPC-only scenes; an open orgasm window is folded in). Anyone else at `group_join_final` or more (repeat orgasms too) joins the pass. Their `ForceOrgasm` follows as a `gate` group when the bars fill in the final stage, with no second narration (`Orgasm_ApplyGroup` skips stash and DN for source `gate`). The final stage starts when the narration's voice starts, and is held until the orgasm dialogue has played (`sexlab.ending.dialogue_hold_max`). The lead reaching their orgasm target (`sexlab.ending.target_*`) does the same jump and hold, but only from the second-to-last stage. An aggressive NPC lead reaching the target at any stage holds the current stage until the orgasm dialogue has played, then ends the animation.
- **Safety net (gate off or no timers, final stage, no LeadIn):** at 90% of the final stage's timer, each non-DOM actor at 90 or more who hasn't orgasmed, isn't blocked or edging, and wasn't calmed in that stage fires as a non-individual group (stash + window). Actors below 90 don't orgasm; the afterglow says `failed to orgasm` when one was expected.
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
- `NarrateOrgasmStash` is not re-entrant: `OrgasmMessagesToNarration` yields on external calls, and two groups narrating at once interleave on the shared slot arrays (crossed sentences, 2026-10-03). A second caller while `orgasm_narrating` is set arms the window instead.
- `StageStart` does not take the stash while `Orgasm_ApplyGroup` is still stashing its group (`orgasm_group_pending`, set before the `ForceOrgasm` loop and cleared after the window is armed or the DN is sent), or while another caller is narrating. It reads the hold once (`hold_stash`). Before this, a final-stage StageStart that yielded in the middle of a group took only the first actor's slot. That gave two DNs, "Bob is orgasming. … Nina is recovering" followed by "Nina is orgasming." (2026-10-03).
- Final-stage `StageStart` sends no `continue activity` DN (the orgasm / finish DN follows); a scene change there is `RegisterEventForce` only.
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
must += denied   ; BandLeadIn(band) + "was denied an orgasm by <denier>." per (denier, band)
; per enjoyment band, lowest first:
others += BandLeadIn(band_i) + NamesClause(band_names, band_n, "is not orgasming right now.", "are not orgasming right now.")
```
