Scriptname DOM_Actor extends ReferenceAlias
DOM_Mind Property mind Auto
String Property behaviour Auto
DOM_BurlapSack Property the_bag_iam_in = None Auto Hidden
bool property is_group_order Auto
bool Property is_trainer = false Auto Hidden
ObjectReference Property CampMarker = None Auto Hidden
String Function getTitle() Native
String Function getName() Native
int Function GetTraineeCount() Native
DOM_Actor Function GetTrainee(int i) Native
int Property actorSex Auto Hidden
int Property prevPoseId Auto
Function EndBehaviour() Native
bool Property is_behaviour_masturbate = false Auto Hidden
Function entermasturbateKneeling(actor akabuser) Native
Function entermasturbateLaying(actor akabuser) Native
Function entermasturbatestanding(actor akabuser) Native
function masturbateharder(actor akabuser) Native
Bool Function WillObeyDisgraced(float mod) Native
Function Anim_SexlabWithNPC(Actor akOther, string tag, bool punishment, string reason_name = "") Native
Function SetSendExternalEvents(bool status) Native
bool Property sendExternalEventToggleExt = false Auto Hidden
Function SetSendExternalEventsExt(bool status) Native
bool Property sendExternalEventToggleExt2 = false Auto Hidden
Function SetSendExternalEventsExt2(bool status) Native
bool Property sendExternalEventToggleExt3 = false Auto Hidden
Function SetSendExternalEventsExt3(bool status) Native
Function Interact_StripNoChoice(Actor akAbuser, bool do_anim) Native
Function SetShouldBeNaked(Actor akAbuser) Native
Function Anim_PoseByString(String pose) Native
Function UnsetShouldBeNaked(Actor akAbuser) Native
Function Anim_DressUp(bool do_bottom) Native
Function StartPraising(Actor akAbuser, string reason="", string type="") Native
Function StartPromising(Actor akAbuser, string oath) Native
Function StartInsultingWith(Actor akAbuser, string type) Native
bool Function hasTears() Native
Function StartSexWithNPC(Actor akAbuser, string type, bool aggro) Native
Function Interact_Undress(Actor akAbuser) Native
Function Interact_UndressNoChoice(Actor akAbuser, bool do_anim) Native
Function Interact_UndressNoAnim(Actor akAbuser) Native
bool function cananswer() Native
Function StartPunishingByActor(Actor akAbuser, string reason, string type) Native
Function StartPunishing(Actor akAbuser, string reason_name = "", string type = "") Native
Function ChooseAnswerNo(Actor akTarget) Native
Function ChooseAnswerYes(Actor akTarget) Native
bool Property wait_for_equipment = false Auto Hidden
bool Property canIdle Hidden AutoReadonly
bool Function get() Native
Function set(bool value) Native
bool Property is_in_dungeon Hidden AutoReadonly
bool Function get() Native
Function set(bool value) Native
bool Property is_in_city Hidden AutoReadonly
bool Function get() Native
Function set(bool value) Native
bool Property is_naked Hidden AutoReadonly
bool Function get() Native
Function set(bool value) Native
bool Property is_shamed Hidden AutoReadonly
bool Function get() Native
Function set(bool value) Native
bool Property has_shield_in_inventory = false Auto Hidden
bool Property has_body_armor_in_inventory = false Auto Hidden
bool Property has_armor_in_inventory = false Auto Hidden
bool Property has_clothes_in_inventory = false Auto Hidden
bool Property has_cuffs_crossed Hidden AutoReadonly
bool Function get() Native
Function set(bool value) Native
bool Property has_cuffs_front Hidden AutoReadonly
bool Function get() Native
Function set(bool value) Native
bool Property has_cuffs_boxtied Hidden AutoReadonly
bool Function get() Native
Function set(bool value) Native
bool Property has_cuffs_back Hidden AutoReadonly
bool Function get() Native
Function set(bool value) Native
bool Property has_mouth_gag Hidden AutoReadonly
bool Function get() Native
Function set(bool value) Native
bool Property has_arms_device Hidden AutoReadonly
bool Function get() Native
Function set(bool value) Native
bool Property has_dwarven_device Hidden AutoReadonly
bool Function get() Native
Function set(bool value) Native
bool Property has_dd_suit Hidden AutoReadonly
bool Function get() Native
Function set(bool value) Native
bool Property has_petsuit Hidden AutoReadonly
bool Function get() Native
Function set(bool value) Native
bool Property has_straitjacket Hidden AutoReadonly
bool Function get() Native
Function set(bool value) Native
bool Property has_cuffs Hidden AutoReadonly
bool Function get() Native
Function set(bool value) Native
bool Property has_armbinder Hidden AutoReadonly
bool Function get() Native
Function set(bool value) Native
bool Property has_yoke Hidden AutoReadonly
bool Function get() Native
Function set(bool value) Native
bool Property has_disablekick Hidden AutoReadonly
bool Function get() Native
Function set(bool value) Native
bool Property has_device Hidden AutoReadonly
bool Function get() Native
Function set(bool value) Native
bool Property has_collar Hidden AutoReadonly
bool Function get() Native
Function set(bool value) Native
bool Property has_blindfold Hidden AutoReadonly
bool Function get() Native
Function set(bool value) Native
bool Property has_leash Hidden AutoReadonly
bool Function get() Native
Function set(bool value) Native
bool Property has_plug_anal Hidden AutoReadonly
bool Function get() Native
Function set(bool value) Native
bool Property has_plug_vaginal Hidden AutoReadonly
bool Function get() Native
Function set(bool value) Native
bool Property has_weapon_in_inventory Hidden AutoReadonly
bool Function get() Native
Function set(bool value) Native
Float Property has_weapon Hidden AutoReadonly
Float Function get() Native
Function set(Float value) Native
Float Property dirty_level Hidden AutoReadonly
Float Function get() Native
Function set(Float value) Native
Float Property wet_level Hidden AutoReadonly
Float Function get() Native
Function set(Float value) Native
Float Property has_body_armor Hidden AutoReadonly
Float Function get() Native
Function set(Float value) Native
Float Property has_armor Hidden AutoReadonly
Float Function get() Native
Function set(Float value) Native
Float Property has_shield Hidden AutoReadonly
Float Function get() Native
Function set(Float value) Native
bool Property has_shame_clothes Hidden AutoReadonly
bool Function get() Native
Function set(bool value) Native
bool Property has_lingerie Hidden AutoReadonly
bool Function get() Native
Function set(bool value) Native
bool Property has_heels Hidden AutoReadonly
bool Function get() Native
Function set(bool value) Native
bool Property is_restrained Hidden AutoReadonly
bool Function get() Native
Function set(bool value) Native
bool Property is_bounded Hidden AutoReadonly
bool Function get() Native
Function set(bool value) Native
bool Property is_jailed = false Auto Hidden
bool Property is_leashed Hidden AutoReadonly
bool Function get() Native
Function set(bool value) Native
Float Property has_jewelry Hidden AutoReadonly
Float Function get() Native
Function set(Float value) Native
int Property has_gold Hidden AutoReadonly
int Function get() Native
Function set(int value) Native
Function OnSexStartNPC(Actor akPartner, bool hasPlayer, bool isNotConsensual) Native
Function OnSexEnd() Native
Actor Property akRef Auto Hidden
DOM_Actor Function GetTrainer() Native
String Function GetBehaviourTitle() Native
String Function GetOnDutyTitle() Native
Function EnterJailTravel(int imode) Native
Function SetFollowMode(int imode) Native
Function EnterFollowPlayer() Native
Function SetShouldWalkOnFour(Actor akAbuser) Native
Function UnsetShouldWalkOnFour(Actor akAbuser) Native
bool Function IsTied() Native
bool Property is_behaviour_pose Auto Hidden
Function SetWaitMode(int imode) Native
Function EnterWaitSandbox() Native
Function EnterFollowTarget(Actor followTarget) Native
Function DoChair(Actor akAbuser) Native
Function DoLight(Actor akAbuser) Native
Function DoFlowers(Actor akAbuser) Native
Function DoDrinks(Actor akAbuser) Native
Function DoCute(Actor akAbuser) Native
Function DoDance(Actor akAbuser) Native
Function DoMusic(Actor akAbuser) Native
Function DoSubmissive(Actor akAbuser) Native
Function DoAssPresentation(Actor akAbuser) Native
Function DoBreastsPresentation(Actor akAbuser) Native
Function DoPussyPresentation(Actor akAbuser) Native
Function StartThreatening(Actor akAbuser, string reason) Native
Function StartComfortingWith(Actor akAbuser, string type) Native
Function Interact_LookAtMe(Actor akAbuser) Native
Function Interact_TurnAround(Actor akAbuser) Native
Function Interact_ComeHere(Actor akAbuser) Native
Function Interact_Mark(Actor akAbuser) Native
Function Interact_Unmark() Native
Function Interact_Brand(Actor akAbuser) Native
Function Interact_unbrand() Native
bool Function HasMark() Native
bool Function HasBrand() Native
Function Interact_UndressAll(Actor akAbuser) Native
Function Interact_Strip(Actor akAbuser) Native
Function Interact_StripAll(Actor akAbuser) Native
Function SendOrderEquipInventory(bool do_anim) Native
Function HoldNoWeapons() Native
Function HoldWeapons(Actor akAbuser) Native
Function WearNoArmor() Native
Function WearArmor(Actor akAbuser) Native
Function DoShower(Actor akAbuser) Native
Function DoBathMaster(Actor akAbuser) Native
Function DoBathMe(Actor akAbuser) Native
Function SetTrainer(DOM_Actor theTrainer) Native
Function SeparateFromTrainer() Native
Function GatherTrainees() Native
Function DisplayTrainees() Native
Function UnloadAllTrainees() Native
Function SecureTrainees() Native
Function ChainTrainees() Native
Function RestrainTraineesInFurniture() Native
Function MasturbateTrainees() Native
Function EnterPunishTrainees() Native
Function EnterTrainSexTrainees() Native
Function EnterTrainOrgy() Native
bool Property has_sex_alone = false Auto Hidden
Actor Function GetCurrentSexTrainer() Native
Function SendExternalEventSS(string the_event, string type) Native
