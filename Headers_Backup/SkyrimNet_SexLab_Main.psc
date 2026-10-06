Scriptname SkyrimNet_SexLab_Main extends Quest
SkyrimNet_SexLab_AnimDb Property animdb Auto
SkyrimNet_SexLab_Handler_DOM_Interface Property handler_dom Auto
Bool Property ostimnet_found = False Auto
SexLabFramework Property sexlab Auto
Faction Property SkyrimNet_SexLab_Faction_Victim Auto
GlobalVariable Property skyrimnet_sexlab_active_sex Auto
bool Property active_sex AutoReadonly
bool Function Get() Native
Function Set(bool value) Native
Function Trace(String func, String msg, Bool notification=False) global Native
bool Property rape_allowed = true Auto
bool Property sex_edit_tags_player = true Auto
bool Property sex_edit_tags_nonplayer = False Auto
float Property orgasm_delay = 5.0 Auto
int Property narration_max_chars = 350 Auto
bool Property voice_follows_speaking = true Auto
String Property storage_actor_lock_key = "skyrimnet_sexlab_scene_actor_lock" AutoReadOnly
String Property storage_items_key = "skyrimnet_sexlab_storage_items" AutoReadOnly
String Property storage_arousal_key = "skyrimnet_sexlab_arousal_level" AutoReadOnly
String Property storage_thread_ejaculated = "skyrimnet_sexlab_thread_ejaculated" AutoReadOnly
float Property direct_narration_cool_off Auto
float Property direct_narration_max_distance Auto
float Property direct_narration_max_distance_default Auto
float Property direct_narration_last_time Auto
int Property race_to_description Auto
int Property counter Auto
Function Setup() Native
Bool Function Setup_CheckLinks() Native
Function StoreStrippedItems(Actor akActor, Form[] forms) Native
Form[] Function UnStoreStrippedItems(Actor akActor) Native
Bool Function HasStrippedItems(Actor akActor) Native
