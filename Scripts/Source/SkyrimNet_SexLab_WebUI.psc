Scriptname SkyrimNet_SexLab_WebUI

; hasStrippedItems: focus actor has skyrimnet_sexlab_storage_items (actionSwitch gate)
; editTagsPlayer / editTagsNonPlayer: MCM Tag Edit toggles cached for TargetMenu → Scene Creator.
; Returns false when the PrismaUI overlay cannot show (missing view / not DomReady).
Bool Function Target_Menu_Open(Actor target, Bool hasStrippedItems, Bool editTagsPlayer, Bool editTagsNonPlayer) global native
Function Target_Menu_Refresh(Bool hasStrippedItems) global native
Function Sex_Menu_Open(Form thread, bool has_player) global native
Function YesNo_Open(String question, int creator_sid) global native
; Solo choice list: json { title, options:[{type:"papyrus", label, plugin, questFormId, scriptName,
; executionFunctionName, closeWebUI, parameterMapping}] }. Opens the WebUI when it is closed; Close / Esc picks nothing.
Function Choice_Open(String json) global native
Function SceneCreator_Open(String state_json) global native
; Soft refresh Scene Menu state without HideAll / showPanel (connection pulldown / main panel switch).
Function SceneCreator_Configure(String state_json) global native
; Soft push BondagePanel group/device wearing state (Handler_UDNG).
Function Bondage_Configure(String state_json) global native
Function Animation_Menu_Open(Form thread, Form sl_scene) global native
Function Animation_Menu_Show(String state_json) global native
; Soft refresh Animation panel without showPanel.
Function Animation_Menu_Configure(String state_json) global native
Function SceneConnections_Show(String state_json) global native
; Seed JS SceneInfo map (all active threads + Scene Creator draft).
Function SceneInfos_Seed(String state_json) global native
Function WebUI_HideAllPanels() global native
; Close overlay (clear TargetMenu session, hide panels, Unfocus). Handler Done uses this.
Function WebUI_CloseOverlay() global native
; Closes the YesNo gate dialogue's "Opening Scene Creator..." placeholder when no SceneCreator_Open
; actually follows Yes (no active creator for the sid, or it already opened once). No-op if the
; WebUI was already open before the dialogue (YesNo_Open's on-top path, nothing to clean up).
Function WebUI_CloseYesNoIfSolo() global native
; MCM: enable/disable C++ menu hotkey and set DX scancode (Escape unchanged).
Function WebUI_SetHotkey(int dxScanCode, bool enabled) global native
; After Target_Menu_Open: JS picks ControlPanel default (preferredFormId or nearest non-player).
Function WebUI_AfterTargetOpen(Actor preferred, Bool preferExplicit) global native
; Hotkey open / actor focus: open the Scene view (DE if the target is in a scene, else Scene Creator) while show_scene_panel is set.
Function WebUI_MaybeRestoreScenePanel() global native
; Scene start/end with the Scene view selected: DE (inScene) or Scene Creator.
Function WebUI_RerouteScenePanel(Bool inScene) global native
; True when PrismaUI overlay is visible (inverse of WebUI_IsHidden).
Bool Function WebUI_IsOverlayVisible() global native
; Push last AnimDb rebuild timestamp into C++ for Settings panel.
Function WebUI_SetLastRebuildTimestamp(String timestamp) global native
Function WebUI_SetSexLabAnimCount(int sexlabCount) global native
; Push SexLab gender + race_key enrich result to Scene Creator JS (actorAnimMetaResult).
Function ActorAnimMeta_Result(String json) global native
; TargetMenu Start: consume one-shot skip so this scene does not open Scene Creator.
Bool Function ConsumeSkipSceneCreator() global native
String Function TraceLog(String script_name, String func, String msg) global native

; --- Profiler (WebUI Profile panel; checkpoints/profile/checkpoint-04.md) ---
; Span open: returns the span id, or 0 when recording is off. source: "papyrus" or "wait".
Int Function Prof_Begin(String source, String probe_key, Int slThread) global native
; Span close; id 0 returns at once.
Function Prof_End(Int id, String detail) global native
; Instant event, recorded only while recording is on.
Function Prof_Mark(String probe_key, Int slThread, String detail) global native
; Instant event written even while recording is off (calibration brackets only).
Function Prof_CalibMark(String probe_key) global native
; Gated natives: no-ops unless the profiler is in its `starting` state.
Function Prof_SetRecording(Bool on) global native
Function Prof_EnterProfiling() global native
Function Prof_CalibrateCpp(Int n, Bool on) global native

; C++ Start Profiling dispatches this. Measures the disabled and recording probe costs, then turns
; recording on for gameplay. No Utility.Wait and no Trace, so the windows hold only probe cost.
Function Prof_Calibrate(Int n) global
    Prof_CalibMark("calib.off.start")
    Int i = 0
    While i < n
        Prof_End(Prof_Begin("papyrus", "calib.pair", -1), "")
        i += 1
    EndWhile
    Prof_CalibMark("calib.off.end")

    Prof_CalibMark("calib.mark.off.start")
    i = 0
    While i < n
        Prof_Mark("calib.mark", -1, "")
        i += 1
    EndWhile
    Prof_CalibMark("calib.mark.off.end")

    Prof_CalibrateCpp(n, false)
    Prof_SetRecording(true)

    Prof_CalibMark("calib.on.start")
    i = 0
    While i < n
        Prof_End(Prof_Begin("papyrus", "calib.pair", -1), "")
        i += 1
    EndWhile
    Prof_CalibMark("calib.on.end")

    Prof_CalibMark("calib.mark.on.start")
    i = 0
    While i < n
        Prof_Mark("calib.mark", -1, "")
        i += 1
    EndWhile
    Prof_CalibMark("calib.mark.on.end")

    Prof_CalibrateCpp(n, true)
    Prof_EnterProfiling()
EndFunction

; Times a blocking wait as source "wait". No call sites yet.
Function Prof_Wait(Float secs, String probe_key) global
    Int id = Prof_Begin("wait", probe_key, -1)
    Utility.Wait(secs)
    Prof_End(id, "")
EndFunction
; Dashboard Verbose logging (sexlab.debug.verbose), read live.
Bool Function IsVerbose() global native
; Dashboard Dead actors can join scenes (sexlab.actors.dead_allowed), read live. False unless the SexLab 1.66
; corpse patch matched at the last CorpsePatchMismatch (or P+). The patched sslActorAlias / sslActorLibrary call it.
Bool Function IsDeadAllowed() global native
; Re-hashes Data/Scripts sslActorAlias.pex / sslActorLibrary.pex: the first missing or mismatched file, or "".
String Function CorpsePatchMismatch(Bool pplus) global native
; TraceLog only when Verbose logging is on; tagged [V]. Guard costly message building with IsVerbose().
Function DebugLog(String script_name, String func, String msg) global native
; Soft availability (dead/combat/SexLab+OStim factions/3D). Papyrus adds StorageUtil + SexLab IsValidActor.
Bool Function IsAvailableActor(Actor akActor) global native
; Push filtered nearby actor list JSON [{name,formId},...] — C++ adds uuids and calls setNearbyActors.
Function SetNearbyActorsJson(String json) global native
Function WebUI_PushMainPanelData(String json) global native
Function WebUI_PushCascadeChoices(String json) global native
Actor Function WebUI_GetFocusActor() global native
String Function WebUI_GetFocusKind() global native
; True when the selected main panel is `panel` (e.g. "description_editor_panel").
Bool Function WebUI_IsMainPanelOpen(String panel) global native
