Scriptname SkyrimNet_SexLab_WebUI
Bool Function Target_Menu_Open(Actor target, Bool hasStrippedItems, Bool editTagsPlayer, Bool editTagsNonPlayer) global native
Function Target_Menu_Refresh(Bool hasStrippedItems) global native
Function Sex_Menu_Open(Form thread, bool has_player) global native
Function YesNo_Open(String question, int creator_sid) global native
Function SceneCreator_Open(String state_json) global native
Function SceneCreator_Configure(String state_json) global native
Function Bondage_Configure(String state_json) global native
Function Animation_Menu_Open(Form thread, Form sl_scene) global native
Function Animation_Menu_Show(String state_json) global native
Function Animation_Menu_Configure(String state_json) global native
Function SceneConnections_Show(String state_json) global native
Function SceneInfos_Seed(String state_json) global native
Function WebUI_HideAllPanels() global native
Function WebUI_CloseOverlay() global native
Function WebUI_CloseYesNoIfSolo() global native
Function WebUI_SetHotkey(int dxScanCode, bool enabled) global native
Function WebUI_AfterTargetOpen(Actor preferred, Bool preferExplicit) global native
Function WebUI_MaybeRestoreScenePanel() global native
Function WebUI_RerouteScenePanel(Bool inScene) global native
Bool Function WebUI_IsOverlayVisible() global native
Function WebUI_SetLastRebuildTimestamp(String timestamp) global native
Function WebUI_SetSexLabAnimCount(int sexlabCount) global native
Function ActorAnimMeta_Result(String json) global native
Bool Function ConsumeSkipSceneCreator() global native
String Function TraceLog(String script_name, String func, String msg) global native
Bool Function IsAvailableActor(Actor akActor) global native
Function SetNearbyActorsJson(String json) global native
Function WebUI_PushMainPanelData(String json) global native
Function WebUI_PushCascadeChoices(String json) global native
Actor Function WebUI_GetFocusActor() global native
String Function WebUI_GetFocusKind() global native
Bool Function WebUI_IsMainPanelOpen(String panel) global native
