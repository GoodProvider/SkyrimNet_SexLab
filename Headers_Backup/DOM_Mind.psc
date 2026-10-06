Scriptname DOM_Mind extends ReferenceAlias
String Property mood Auto
bool Property is_slave Auto Hidden
bool Property is_player_slave Auto Hidden
Float Property submission Auto
Float Property fear_training Auto
Float Property humiliation Auto
Float Property resignation Auto
Float Property respect_training Auto
Float Property vaginal_training Auto
Float Property oral_training Auto
Float Property anal_training Auto
Actor Property actor_owner Auto
Bool Property should_be_naked Auto
Bool Property sex_is_non_consensual Auto
bool Property whipping_active = false Auto Hidden
int Property whipping_reason = 0 Auto Hidden
string Property whipping_reason_name = "no reason" Auto Hidden
string Property current_punishment_type Auto Hidden
int Property current_punishment_reason = 0 Auto Hidden
string Property current_punishment_reason_name = "no reason" Auto Hidden
Float Property MOD_naivety Auto
Function AddNextPunishmentReason(int reason) Native
bool Function IsObedient() Native
bool Function WillObey(int reason, int ifacet, int itraining, float strength=1.0, bool do_msg=true) Native
Function SetObedientTimer(int timer_start = 10) Native
Float Property arousal_factor Hidden AutoReadonly
float Function get() Native
Function set(float value) Native
Int Property is_aroused_for Hidden AutoReadonly
Int Function get() Native
Function set(Int value) Native
Int Property is_enraptured_for Hidden AutoReadonly
Int Function get() Native
Function set(Int value) Native
bool Function IsNotRespectful(float value ) Native
bool function WillObeyDisgraced(int type) Native
Function SetNextPunishmentReasonForceMessage(int reason, String the_message) Native
float function GetDegradedEffect() Native
Function MakeAshamedFor(Float base_amount) Native
String Function GetListOfKnownKinks() Native
string Function GetListOfHiddenKinks() Native
int Function GetNextPunishmentReasonByIndex() Native
bool Function StartPunishing(Actor akAbuser, string the_reason, string type) Native
bool Function StartPunishingByIndex(Actor akAbuser, int ireason, string type) Native
int Function StartComfortingWith(Actor akAbuser, string type) Native
bool Function StartGuilt() Native
Function TrainHumiliation(Float base_amount) Native
Function TrainSubmission(Float base_amount) Native
Function SendNotificationAbuse(string msg) Native
bool Function IsInLove() Native
bool Function IsDevoted() Native
bool Function IsAshamed() Native
Int Property number_of_orgasm Hidden AutoReadonly
Int Function get() Native
Function set(Int value) Native
String Function getTitle() Native
string Property promiseOath = "nothing" Auto Hidden
bool Property is_love_interest Hidden AutoReadonly
bool Function get() Native
Function set(bool value) Native
bool Property should_be_respectful Hidden AutoReadonly
bool Function get() Native
Function set(bool value) Native
bool Property was_respectful Hidden AutoReadonly
bool Function get() Native
Function set(bool value) Native
bool Property should_walk_on_four Hidden AutoReadonly
bool Function get() Native
Function set(bool value) Native
bool Property is_walking_on_four Hidden AutoReadonly
bool Function get() Native
Function set(bool value) Native
bool Property should_be_silent Hidden AutoReadonly
bool Function get() Native
Function set(bool value) Native
bool Property should_be_noorgasm Hidden AutoReadonly
bool Function get() Native
Function set(bool value) Native
bool Property should_wear_armor Hidden AutoReadonly
bool Function get() Native
Function set(bool value) Native
bool Property should_hold_weapons Hidden AutoReadonly
bool Function get() Native
Function set(bool value) Native
Float Property skill_enforcer Hidden AutoReadonly
Float Function get() Native
Function set(Float value) Native
Float Property skill_persuader Hidden AutoReadonly
Float Function get() Native
Function set(Float value) Native
Float Property skill_depraver Hidden AutoReadonly
Float Function get() Native
Function set(Float value) Native
Float Property skill_predator Hidden AutoReadonly
Float Function get() Native
Function set(Float value) Native
Float Property skill_slaver Hidden AutoReadonly
Float Function get() Native
Function set(Float value) Native
Float Property skill_deceiver Hidden AutoReadonly
Float Function get() Native
Function set(Float value) Native
Float Property love_desire Hidden AutoReadonly
Float Function get() Native
Function set(Float value) Native
Float Property love_fascination Hidden AutoReadonly
Float Function get() Native
Function set(Float value) Native
Float Property love_admiration Hidden AutoReadonly
Float Function get() Native
Function set(Float value) Native
Float Property loyal_worship Hidden AutoReadonly
Float Function get() Native
Function set(Float value) Native
Float Property loyal_absolution Hidden AutoReadonly
Float Function get() Native
Function set(Float value) Native
Float Property loyal_devotion Hidden AutoReadonly
Float Function get() Native
Function set(Float value) Native
int Property virgin_status_vaginal Hidden AutoReadonly
int Function get() Native
Function set(int value) Native
int Property virgin_status_oral Hidden AutoReadonly
int Function get() Native
Function set(int value) Native
int Property virgin_status_anal Hidden AutoReadonly
int Function get() Native
Function set(int value) Native
int Property virgin_status_same Hidden AutoReadonly
int Function get() Native
Function set(int value) Native
int Property virgin_status_gang Hidden AutoReadonly
int Function get() Native
Function set(int value) Native
int Property number_of_pain Hidden AutoReadonly
int Function get() Native
Function set(int value) Native
int Property number_of_bondage Hidden AutoReadonly
int Function get() Native
Function set(int value) Native
int Property number_of_shame Hidden AutoReadonly
int Function get() Native
Function set(int value) Native
int Property number_of_rape Hidden AutoReadonly
int Function get() Native
Function set(int value) Native
int Property number_of_sex Hidden AutoReadonly
int Function get() Native
Function set(int value) Native
int Property number_of_sexformoney Hidden AutoReadonly
int Function get() Native
Function set(int value) Native
int Property number_of_sexwithothers Hidden AutoReadonly
int Function get() Native
Function set(int value) Native
int Property number_of_toldoff Hidden AutoReadonly
int Function get() Native
Function set(int value) Native
int Property number_of_praise Hidden AutoReadonly
int Function get() Native
Function set(int value) Native
int Property number_of_comfort Hidden AutoReadonly
int Function get() Native
Function set(int value) Native
int Property number_of_insult Hidden AutoReadonly
int Function get() Native
Function set(int value) Native
int Property number_of_threat Hidden AutoReadonly
int Function get() Native
Function set(int value) Native
int Property number_of_promise Hidden AutoReadonly
int Function get() Native
Function set(int value) Native
int Property number_of_shock Hidden AutoReadonly
int Function get() Native
Function set(int value) Native
int Property number_of_broken Hidden AutoReadonly
int Function get() Native
Function set(int value) Native
int Property number_of_brainwashed Hidden AutoReadonly
int Function get() Native
Function set(int value) Native
int Property number_of_capturedslaves Hidden AutoReadonly
int Function get() Native
Function set(int value) Native
int Property number_of_soldslaves Hidden AutoReadonly
int Function get() Native
Function set(int value) Native
int Property number_of_whoredslaves Hidden AutoReadonly
int Function get() Native
Function set(int value) Native
int Property number_of_ransomedslaves Hidden AutoReadonly
int Function get() Native
Function set(int value) Native
int Property number_of_brokenslaves Hidden AutoReadonly
int Function get() Native
Function set(int value) Native
int Property number_of_recruitedslavers Hidden AutoReadonly
int Function get() Native
Function set(int value) Native
float Property timer_for_broken Hidden AutoReadonly
float Function get() Native
Function set(float value) Native
bool Property should_fight_for_player Hidden AutoReadonly
bool Function get() Native
Function set(bool value) Native
Int Function GetNumberOfNextPunishmentReasons() Native
String Function GetNextPunishmentReason(int islot) Native
Int Function GetNumberOfNextPraiseReasons() Native
String Function GetNextPraiseReason(int islot) Native
bool Function IsCrying() Native
bool Function IsAngry() Native
Float Property pose_training Hidden AutoReadonly
Float Function get() Native
Function set(Float value) Native
DOM_Core Property DOM01 Auto
Float Property PRISM_Sensuality Hidden AutoReadonly
Float Function get() Native
Function set(Float value) Native
Float Property MOD_SocialBoldness Hidden AutoReadonly
Float Function get() Native
Function set(Float value) Native
Float Property MOD_Vaginal Hidden AutoReadonly
Float Function get() Native
Function set(Float value) Native
Float Property MOD_Oral Hidden AutoReadonly
Float Function get() Native
Function set(Float value) Native
Float Property MOD_Anal Hidden AutoReadonly
Float Function get() Native
Function set(Float value) Native
Float Property MOD_Orgasm Hidden AutoReadonly
Float Function get() Native
Function set(Float value) Native
Function IncreaseArousal(float amount, float reason_modifier) Native
Function handleSexOrgasm(bool HasPlayer) Native
float Function getArousalBonus() Native
DOM_Actor Property actor_alias Auto Hidden
bool Property hadOralSex = false Auto Hidden
bool Property hadAnalSex = false Auto Hidden
bool Property hadVaginalSex = false Auto Hidden
bool Property was_allowed_toorgasm = false Auto Hidden
Float Property FACET_Sensuality Hidden AutoReadonly
Float Function get() Native
Function set(Float value) Native
Float Property MOD_Daring Hidden AutoReadonly
Float Function get() Native
Function set(Float value) Native
bool Function IsArousedAfterSex(Float base_chance) Native
bool Function IsOrgasmingAfterArousal(Float base_chance) Native
