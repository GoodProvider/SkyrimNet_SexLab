Scriptname SkyrimNetApi
int function RegisterDecorator(String decoratorID, String sourceScript, String functionName) Global Native
int function RegisterAction(String actionName, String description,                            String eligibilityScriptName, String eligibilityFunctionName,                            String executionScriptName, String executionFunctionName,                            String triggeringEventTypesCsv, String categoryStr,                            int defaultPriority, String parameterSchemaJson, String customCategory="", String tags="") Global Native
int function RegisterTag(String tagName, String eligibilityScriptName, String eligibilityFunctionName) Global Native
bool function IsActionRegistered(String actionName) Global Native
int function UnregisterAction(String actionName) Global Native
int function ExecuteAction(string actionName, Actor akOriginator, string argsJson) global native
int function ExecuteActionByUUID(string actionName, string originatorUuid, string argsJson) global native
int function SetActionCooldown(string actionName, int cooldownTimeSeconds) global native
int function GetRemainingCooldown(string actionName) global native
int function RegisterShortLivedEvent(String eventId, String eventType, String description,                                     String data, int ttlMs, Actor sourceActor, Actor targetActor) Global Native
int function RegisterShortLivedEventByUUID(String eventId, String eventType, String description,                                     String data, int ttlMs, String sourceUuid = "", String targetUuid = "") Global Native
int function RegisterEvent(String eventType, String content, Actor originatorActor, Actor targetActor) Global Native
int function RegisterEventByUUID(String eventType, String content, String originatorUuid = "", String targetUuid = "") Global Native
int function RegisterDialogue(Actor speaker, String dialogue) Global Native
int function RegisterDialogueByUUID(String speakerUuid, String dialogue) Global Native
int function RegisterDialogueToListener(Actor speaker, Actor listener, String dialogue) Global Native
int function RegisterDialogueToListenerByUUID(String speakerUuid, String listenerUuid, String dialogue) Global Native
int function PurgeDialogue(bool abDeferToCurrentFinished = false) Global Native
int function RegisterPackage(Actor akActor, String packageName, int priority, int flags, bool isPersistent) Global Native
int function UnregisterPackage(Actor akActor, String packageName) Global Native
int function ScheduleDelayedPackageRemoval(Actor akActor, String packageName, int delaySeconds) Global Native
int function ClearAllPackages(Actor akActor) Global Native
int function ClearAllPackagesGlobally() Global Native
int function CancelPendingPackageTasks(Actor akActor) Global Native
int function HasPackage(Actor akActor, String packageName) Global Native
int function ReinforcePackages(Actor akActor) Global Native
int function SendCustomPromptToLLM(String promptName, String variant, String contextJson,                                   Quest callbackQuest, String callbackScriptName, String callbackFunctionName) Global Native
int function SendCustomDecisionToLLM(String templateName, String contextJson,                                      Quest callbackQuest, String callbackScriptName, String callbackFunctionName) Global Native
int function DirectNarration(String content, Actor originatorActor = None, Actor targetActor = None) Global Native
int function DirectNarrationByUUID(String content, String originatorUuid, String targetUuid = "") Global Native
int function RegisterPersistentEvent(String content, Actor originatorActor = None, Actor targetActor = None) Global Native
int function RegisterPersistentEventByUUID(String content, String originatorUuid = "", String targetUuid = "") Global Native
int function TransformDialogue(String dialogueText) Global Native
int function GenerateNPCThought(Actor npcActor, String promptHint) Global Native
String function GetJsonString(String jsonString, String key, String defaultValue) Global Native
int function GetJsonInt(String jsonString, String key, int defaultValue) Global Native
bool function GetJsonBool(String jsonString, String key, bool defaultValue) Global Native
float function GetJsonFloat(String jsonString, String key, float defaultValue) Global Native
Actor function GetJsonActor(String jsonString, String key, Actor defaultValue) Global Native
Actor function FindActorByName(String actorName) Global Native
String function GetEntityUUID(Actor akActor) Global Native
String function GetEntityDisplayNameByUUID(String entityUuid) Global Native
Bool function IsVirtualEntity(String entityUuid) Global Native
Actor function GetActorByUUID(String entityUuid) Global Native
String function JoinStrings(String[] strings, String[] noun) Global Native
String function GetConfigString(String configName, String path, String defaultValue) Global Native
int function GetConfigInt(String configName, String path, int defaultValue) Global Native
bool function GetConfigBool(String configName, String path, bool defaultValue) Global Native
float function GetConfigFloat(String configName, String path, float defaultValue) Global Native
bool function PatchConfig(String name, String jsonPatch) Global Native
String function GetBuildVersion() Global Native
String function GetBuildType() Global Native
string function GetSaveUniqueID() Global Native
bool function IsRecordingInput() Global Native
bool function IsRunningVR() Global Native
int function GetSpeechQueueSize() Global Native
int function GetTimeSinceLastAudioEnded() Global Native
String function RenderTemplate(String templateName, String variableName, String variableValue) Global Native
String function ParseString(String inputStr, String variableName, String variableValue) Global Native
String function UpdateActorDynamicBio(Actor actor) Global Native
String function GenerateDiaryEntry(Actor actor) Global Native
String function GenerateDiaryEntryByUUID(String entityUuid) Global Native
int function RegisterEventSchema(String eventType, String displayName, String description,                                 String fieldsJson, String formatTemplatesJson, bool isEphemeral, int defaultTTLMs,                                 bool shortLivedEnabled = true, bool interrupt = false) Global Native
bool function ValidateEventData(String eventType, String dataJson) Global Native
String function FormatEvent(String eventJson, String mode) Global Native
String function GetSchemaInfo(String eventType) Global Native
String function GetAllEventTypes() Global Native
bool function IsEventTypeRegistered(String eventType) Global Native
String function GetAllSchemasInfo() Global Native
int function RegisterVirtualNPC(String name, String displayName, String voiceId, String conversationMode, String language) Global Native
int function UpdateVirtualNPC(String name, String displayName, String voiceId, String conversationMode, String language) Global Native
int function EnableVirtualNPC(String name) Global Native
int function DisableVirtualNPC(String name) Global Native
String function GetVirtualNPCUUID(String name) Global Native
String function GetVirtualNPCList() Global Native
int function OpenSkyrimNetUI() Global Native
int function TriggerRecordSpeechPressed() Global Native
int function TriggerRecordSpeechReleased(float duration) Global Native
int function TriggerToggleOpenMic() Global Native
int function TriggerTextInput() Global Native
int function TriggerToggleGameMaster() Global Native
int function TriggerToggleContinuousMode() Global Native
int function TriggerToggleWorldEventReactions() Global Native
int function TriggerToggleActions() Global Native
int function TriggerToggleWhisperMode() Global Native
int function TriggerToggleDashboard() Global Native
int function SetDashboardToggleKey(int keyCode) Global Native
int function TriggerTextThought() Global Native
int function TriggerVoiceThoughtPressed() Global Native
int function TriggerVoiceThoughtReleased(float duration) Global Native
int function TriggerTextDialogueTransform() Global Native
int function TriggerVoiceDialogueTransformPressed() Global Native
int function TriggerVoiceDialogueTransformReleased(float duration) Global Native
int function TriggerDirectInput() Global Native
int function TriggerVoiceDirectInputPressed() Global Native
int function TriggerVoiceDirectInputReleased(float duration) Global Native
int function TriggerContinueNarration() Global Native
int function TriggerPlayerThought() Global Native
int function TriggerPlayerDialogue() Global Native
int function TriggerPlayerTTS(String dialogue) Global Native
bool function IsPlayerTTSFinished() Global Native
int function PrepareNPCDialogue(String playerDialogueText) Global Native
bool function IsNPCDialogueReady() Global Native
int function SetCppHotkeysEnabled(bool enabled) Global Native
bool function IsCppHotkeysEnabled() Global Native
bool function ToggleTelepathyEavesdropping() Global Native
bool function IsTelepathyEavesdroppingEnabled() Global Native
function SetTelepathyEavesdroppingEnabled(bool enabled) Global Native
bool function IsContinuousModeEnabled() Global Native
int function TriggerCaptureCrosshairPressed() Global Native
int function TriggerCaptureCrosshairReleased(float holdDuration) Global Native
int function TriggerGenerateDiaryBio() Global Native
int function TriggerInterruptDialogue(bool abDeferToCurrentFinished = false) Global Native
int function TriggerSilentNarration() Global Native
int function AddWorldKnowledge(String content, String conditionExpr, bool alwaysInject, float importance, String displayName) Global Native
int function SetVoiceEffect(Actor akActor, String asEffectId) Global Native
int function ClearVoiceEffect(Actor akActor) Global Native
String function GetVoiceEffect(Actor akActor) Global Native
int function SetVoiceEffectByUUID(String asEntityUUID, String asEffectId) Global Native
int function ClearVoiceEffectByUUID(String asEntityUUID) Global Native
String function GetVoiceEffectByUUID(String asEntityUUID) Global Native
