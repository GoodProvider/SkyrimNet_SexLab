Scriptname SkyrimNet_SexLab_AnimDb extends Quest
SkyrimNet_SexLab_Main Property main Auto
SexLabFramework Property sexlab Auto
Function AnimDb_Open() global native
int Function AnimDb_BeginSync(Bool force_rebuild) global native
int Function AnimDb_PushAnimBatch(String json) global native
Bool Function AnimDb_EndSync() global native
String Function AnimDb_QueryTopNAnims(String filter_json, int n) global native
String Function AnimDb_QueryTopNTags(String filter_json, int n) global native
int Function AnimDb_TotalEnabled() global native
int Function AnimDb_TotalCount() global native
String Function AnimDb_GetByRegistry(String registry) global native
String Function AnimDb_GetStageDescription(String registry, int stage) global native
String Function AnimDb_GetTransition(String registry, int from_stage, int to_stage) global native
String Function AnimDb_SubstituteActors(String desc, String actors_json) global native
String Function AnimDb_GetStagesJson(String registry, int stage_count, String actors_json, int current_stage) global native
Bool Function AnimDb_SaveAnimLocal(String registry, String json) global native
String Function AnimDb_ResolveTags(String tags_csv, int actor_count, String synonyms = "broad") global native
Bool Function AnimDb_CsvHasTag(String tags_csv, String tag) global native
int[] Function AnimDb_ClothedMajority(String[] registries, int position_count) global native
Function Trace(String func, String msg, Bool notification=False) global Native
Function Setup() Native
Function CheckAlignmentOnLoad() Native
int Function RefreshSlotCounts() Native
Bool Function IsAligned() Native
Bool Function CanCheckAlignment() Native
Function PromptAlignmentIfNeeded() Native
Function PromptHotkeyMismatch() Native
Function ShowMismatchPrompt(Bool likely_problem) Native
Function FinishAlignmentPrompt() Native
Function StartSync(Bool force_rebuild=False) Native
Function BeginWalk() Native
Function RebuildDatabase() Native
Function LogWalkSkip(String reason, sslBaseAnimation anim) Native
Function FinishSourceOrDone() Native
String Function BuildAnimJson(sslBaseAnimation anim, int source) Native
String Function EscapeJson(String s) global Native
String Function QueryTopNAnims(String filter_json, int n) Native
String Function QueryTopNTags(String filter_json, int n) Native
int Function TotalEnabled() Native
String Function GetByRegistry(String registry) Native
String Function GetStageDescription(String registry, int stage) Native
String Function GetTransition(String registry, int from_stage, int to_stage) Native
String Function SubstituteActors(String desc, String actors_json) Native
Bool Function SaveAnimLocal(String registry, String json) Native
String Function ResolveTags(String tags_csv, int actor_count, String synonyms = "broad") Native
Bool Function CsvHasTag(String tags_csv, String tag) Native
Bool Property hide_help = false Auto
String Property last_rebuild_timestamp = "never" Auto
Bool Property hotkey_db_checked = false Auto
int Property last_sync_slots_total = 0 Auto
int Property last_sync_db_count = 0 Auto
String Function GetThreadStageDescription(sslThreadController thread, int stage_override = -1) Native
String Function GetThreadStagesJson(sslThreadController thread, int stage_count) Native
String Function GetThreadTransition(sslThreadController thread, int from_stage, int to_stage) Native
int[] Function GetOrgasmExpected(sslThreadController thread) Native
String Function SpeakingDefaultFromOrgasmExpected(int orgasm_expected) global Native
String[] Function GetSpeakingModifiers(sslThreadController thread) Native
int[] Function GetClothed(sslThreadController thread) Native
bool[] Function GetHasDescriptionOrgasmExpected(sslThreadController thread) Native
