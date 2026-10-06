ScriptName DOM_Core extends Quest
DOM_SlaveManager Property DOM02 Auto
DOM_Sexlab Property DOMSexlab Auto
float Property train_speed_orgasm = 0.25 Auto Hidden
Faction Property DOMActionMasturbating Auto
Faction Property DOMHistoryFaction Auto
Faction Property DOMActorFamilyHistory Auto
Faction Property DOMPromised Auto
bool Property sendDOMExternalEventToggle = false Auto Hidden
String Function GetMood(Actor akTarget) Native
String Function DOMMoodMessage(Actor akTarget) Native
String Function GetJSONPunishmentReasonNameByIndex(int index, int actorSex) Native
Int Function GetJSONPunishmentReasonIndexByName(string the_reason) Native
String Function NPCStatsMessage(Actor akTarget) Native
String Function NPCMoodMessage(Actor akTarget) Native
String Function DOMTraitsMessage(Actor akTarget) Native
String Function NPCFeelingsMessage(Actor akTarget) Native
DOM_Actor Function GetActor(Actor akRef) Native
bool Property cryingPunishmentToggle = true Auto Hidden
bool Property cryingPraiseToggle = true Auto Hidden
int Function GetJSONNumberOfPraisingTypes() Native
String Function GetJSONPraisingTypeNameByIndex(int index) Native
int Function GetJSONNumberOfPunishmentTypes() Native
String Function GetJSONPunishmentTypeNameByIndex(int index) Native
bool Function IsFleeing(Actor akTarget) Native
float Property train_speed_tell = 100.0 Auto Hidden
Float Function GetPredatorModifier(Actor akAbuser) Native
Function TrainSkillPredator(Actor akAbuser, Float base_amount) Native
DOM_Diary Property DOM04 Auto
float Property train_speed_arousal = 0.50 Auto Hidden
Float Function GetDeceiverModifier(Actor akAbuser) Native
