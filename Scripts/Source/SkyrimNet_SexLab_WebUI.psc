Scriptname SkyrimNet_SexLab_WebUI

; hasStrippedItems: focus actor has skyrimnet_sexlab_storage_items (actionSwitch gate)
; editTagsPlayer / editTagsNonPlayer: MCM Tag Edit toggles cached for TargetMenu → Scene Creator.
; Returns false when the PrismaUI overlay cannot show (missing view / not DomReady).
Bool Function Target_Menu_Open(Actor target, Bool hasStrippedItems, Bool editTagsPlayer, Bool editTagsNonPlayer) global native
Function Target_Menu_Refresh(Bool hasStrippedItems) global native
Function Sex_Menu_Open(Form thread, bool has_player) global native
Function YesNo_Open(String question, int creator_sid) global native
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
