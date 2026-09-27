# Orgasm narration contract

Canonical gate used by `0550_sexlab_narration.prompt`.

## Gate

```inja
contains(_direct_narration, " is orgasming.")
```

The substring `" is orgasming."` must stay exact on the whole direct-narration string.

## Rules

| Clause type | Must include `" is orgasming."`? |
|-------------|----------------------------------|
| Orgasming actor | **Yes** |
| Denied / non-orgasming | **No** — Combined and Separate: `name+" is not orgasming right now. "`; Dom denied / afterglow: “did not orgasm” / “failed to orgasm” |

- Dom: `Handler_DOM.DOMSlave_Orgasmed` → `Scene_Manager.OrgasmCustom` appends `". "+name+" is orgasming."` on purpose — do not strip without updating the prompt.
- `Scene.OrgasmCustom` returns without stash / total bump / DN when the actor's `no_orgasm==1` (`orgasm_expected` 0, scene-creator or `not_expected`/`deny`). DOM rolls its own orgasm (`DOM_Mind.IsOrgasmingAfterArousal`) and ignores SexLab `DisableOrgasm`; its `should_be_noorgasm` only shifts the odds, so the bridge must gate what it reports. Exception: `ignore_no_orgasm=true` (Description Editor orgasm button, `Scene.WebUI_ForceOrgasm`) narrates anyway.
- Description Editor orgasm button: `thread.ForceOrgasm` fires only `SexLabOrgasm`. When the `OrgasmIndividual` path would narrate (SeparateOrgasms, `no_orgasm` 0, not a DOM slave), nothing else is sent. Otherwise `OrgasmCustom(actor, "", true)` supplies the narration, so each press gives exactly one message.
- Dom player-orgasm tease (`squirms under your grasp` / `your orgasm submerges you`) is **not** a slave climax. `DOMSlave_Orgasmed` must return without `OrgasmCustom` or DN. Combined then names the slave `" is not orgasming right now."` unless a real melt bumped totals that have not been narrated yet (`orgasm_narrated`).
- Combined / `GetIsOrgasming`: Papyrus emits `name+" is orgasming. "` (and `. again.` / tentacles append). Do not strip that substring without updating the prompt.
- Dom Combined fallback: if orgasm expected and totals increased since last orgasm DN (`orgasm_narrated`) but custom text raced empty, still append `name+" is orgasming. "` (same gate). Already-spoken totals (`GetTotalOrgasms == orgasm_narrated`) use `" is not orgasming right now."`, not denied.
- Combined flush (`OrgasmMessagesToNarration`) and `OrgasmIndividual` name every non-orgasming actor with `" is not orgasming right now."` instead of a generic “only listed” sentence. That substring must **not** match the orgasm gate.
- Combined + Dom last-stage: do **not** DirectNarrate a melt immediately. `OrgasmCustom` / `OrgasmCombined` stash into `orgasm_messages` and restart a Scene `OnUpdate` window (`sexlab.orgasm.delay`, default 5s) so player and slave climaxes are both counted, then one DirectNarration contains every `" is orgasming."` clause. StageStart must not consume the stash while that window is open (a later player DN would overwrite the slave). Style-change DN is skipped while the stash is pending.
- Window cap: `ArmOrgasmWindow` records `orgasm_window_started_at` on first arm. Further Combined/Custom events may restart the timer, but never past **2×** `orgasm_delay` from that start — then flush immediately. Prevents a climax stream from deferring the single DN forever.
- `FlushOrgasmWindow` calls `AlignActors()` before `OrgasmMessagesToNarration` (same as StageStart / AnimationEnd) so names and `orgasm_narrated` match `thread.positions`. If `thread` is None, clear the stash without narrating.
- `AnimationStart` (first start / STATUS_SETUP path): if a stash is still pending, flush it before clearing — do not silently discard a melt that landed between AnimationEnd and the next start.
- Melt during StageEnd / mid-stage-change must still reach `OrgasmCustom`. `GetThreadByActor` state `animating`/`prepare` can miss; `GetSceneByActor` / `OrgasmCustom` fall back to `thread_scene` (any state). If the scene is still None, Handler delays 1s then retries `OrgasmCustom`; only DirectNarrates (same `" is orgasming."` gate) when the scene is still unreachable.
- Orgasm flush is **DirectNarration**, not RegisterEvent-only. StageStart must not `RegisterEvent` the same orgasm sentence immediately before DN — `CheckDuplicate` stores that string and blanks the DN, so 0550 never gates.

If you change the gate in the prompt, update every Papyrus narration site that appends it.

## Example (Papyrus)

[`Scripts/Source/SkyrimNet_SexLab_Scene_Manager.psc`](../../Scripts/Source/SkyrimNet_SexLab_Scene_Manager.psc) — `OrgasmCustom`:

```papyrus
Function OrgasmCustom(Actor akActor, String msg)
    SkyrimNet_SexLab_Scene sl_scene = GetSceneByActor(akActor)
    if sl_scene == None
        return
    endif
    sl_scene.OrgasmCustom(akActor, msg + ". "+GetDisplayName(akActor)+" is orgasming.")
EndFunction
```

Combined path also builds clauses in [`Scripts/Source/SkyrimNet_SexLab_Scene.psc`](../../Scripts/Source/SkyrimNet_SexLab_Scene.psc) (`GetIsOrgasming`).
