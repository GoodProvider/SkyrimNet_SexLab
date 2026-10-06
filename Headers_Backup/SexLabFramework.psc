scriptname SexLabFramework extends Quest
string property ModName auto
int function GetVersion() Native
string function GetStringVer() Native
bool property Enabled hidden AutoReadonly
bool function get() Native
bool property IsRunning hidden AutoReadonly
bool function get() Native
int property ActiveAnimations hidden AutoReadonly
int function get() Native
bool property AllowCreatures hidden AutoReadonly
bool function get() Native
bool property CreatureGenders hidden AutoReadonly
bool function get() Native
sslThreadModel function NewThread(float TimeOut = 30.0) Native
int function StartSex(Actor[] Positions, sslBaseAnimation[] Anims, Actor Victim = none, ObjectReference CenterOn = none, bool AllowBed = true, string Hook = "") Native
sslThreadController function QuickStart(Actor Actor1, Actor Actor2 = none, Actor Actor3 = none, Actor Actor4 = none, Actor Actor5 = none, Actor Victim = none, string Hook = "", string AnimationTags = "") Native
int function GetGender(Actor ActorRef) Native
function TreatAsMale(Actor ActorRef) Native
function TreatAsFemale(Actor ActorRef) Native
function TreatAsGender(Actor ActorRef, bool AsFemale) Native
function ClearForcedGender(Actor ActorRef) Native
int[] function GenderCount(Actor[] Positions) Native
int[] function TransGenderCount(Actor[] Positions) Native
int function MaleCount(Actor[] Positions) Native
int function FemaleCount(Actor[] Positions) Native
int function CreatureCount(Actor[] Positions) Native
int function TransMaleCount(Actor[] Positions) Native
int function TransFemaleCount(Actor[] Positions) Native
int function TransCreatureCount(Actor[] Positions) Native
int function ValidateActor(Actor ActorRef) Native
bool function IsValidActor(Actor ActorRef) Native
bool function IsActorActive(Actor ActorRef) Native
function ForbidActor(Actor ActorRef) Native
function AllowActor(Actor ActorRef) Native
bool function IsForbidden(Actor ActorRef) Native
Actor function FindAvailableActor(ObjectReference CenterRef, float Radius = 5000.0, int FindGender = -1, Actor IgnoreRef1 = none, Actor IgnoreRef2 = none, Actor IgnoreRef3 = none, Actor IgnoreRef4 = none) Native
Actor function FindAvailableActorByFaction(Faction FactionRef, ObjectReference CenterRef, float Radius = 5000.0, int FindGender = -1, Actor IgnoreRef1 = none, Actor IgnoreRef2 = none, Actor IgnoreRef3 = none, Actor IgnoreRef4 = none, bool HasFaction = True) Native
Actor function FindAvailableActorWornForm(int slotMask, ObjectReference CenterRef, float Radius = 5000.0, int FindGender = -1, Actor IgnoreRef1 = none, Actor IgnoreRef2 = none, Actor IgnoreRef3 = none, Actor IgnoreRef4 = none, bool AvoidNoStripKeyword = True, bool HasWornForm = True) Native
Actor function FindAvailableCreature(string RaceKey, ObjectReference CenterRef, float Radius = 5000.0, int FindGender = 2, Actor IgnoreRef1 = none, Actor IgnoreRef2 = none, Actor IgnoreRef3 = none, Actor IgnoreRef4 = none) Native
Actor function FindAvailableCreatureByFaction(string RaceKey, Faction FactionRef, ObjectReference CenterRef, float Radius = 5000.0, int FindGender = -1, Actor IgnoreRef1 = none, Actor IgnoreRef2 = none, Actor IgnoreRef3 = none, Actor IgnoreRef4 = none, bool HasFaction = True) Native
Actor function FindAvailableCreatureWornForm(string RaceKey, int slotMask, ObjectReference CenterRef, float Radius = 5000.0, int FindGender = -1, Actor IgnoreRef1 = none, Actor IgnoreRef2 = none, Actor IgnoreRef3 = none, Actor IgnoreRef4 = none, bool AvoidNoStripKeyword = True, bool HasWornForm = True) Native
Actor[] function FindAvailablePartners(Actor[] Positions, int TotalActors, int Males = -1, int Females = -1, float Radius = 10000.0) Native
Actor[] function SortActors(Actor[] Positions, bool FemaleFirst = true) Native
Actor[] function SortActorsByAnimation(Actor[] Positions, sslBaseAnimation Animation = none) Native
Actor[] function SortCreatures(Actor[] Positions, sslBaseAnimation Animation = none) Native
function AddCum(Actor ActorRef, bool Vaginal = true, bool Oral = true, bool Anal = true) Native
function ClearCum(Actor ActorRef) Native
int function CountCum(Actor ActorRef, bool Vaginal = true, bool Oral = true, bool Anal = true) Native
int function CountCumVaginal(Actor ActorRef) Native
int function CountCumOral(Actor ActorRef) Native
int function CountCumAnal(Actor ActorRef) Native
Form[] function StripActor(Actor ActorRef, Actor VictimRef = none, bool DoAnimate = true, bool LeadIn = false) Native
Form[] function StripSlots(Actor ActorRef, bool[] Strip, bool DoAnimate = false, bool AllowNudesuit = true) Native
function UnstripActor(Actor ActorRef, Form[] Stripped, bool IsVictim = false) Native
bool function IsStrippable(Form ItemRef) Native
Form function StripSlot(Actor ActorRef, int SlotMask) Native
Form function WornStrapon(Actor ActorRef) Native
bool function HasStrapon(Actor ActorRef) Native
Form function PickStrapon(Actor ActorRef) Native
Form function EquipStrapon(Actor ActorRef) Native
function UnequipStrapon(Actor ActorRef) Native
Armor function LoadStrapon(string esp, int id) Native
bool function CheckBardAudience(Actor ActorRef, bool RemoveFromAudience = true) Native
ObjectReference function FindBed(ObjectReference CenterRef, float Radius = 1000.0, bool IgnoreUsed = true, ObjectReference IgnoreRef1 = none, ObjectReference IgnoreRef2 = none) Native
bool function IsBedRoll(ObjectReference BedRef) Native
bool function IsDoubleBed(ObjectReference BedRef) Native
bool function IsSingleBed(ObjectReference BedRef) Native
bool function IsBedAvailable(ObjectReference BedRef) Native
bool function AddCustomBed(Form BaseBed, int BedType = 0) Native
bool function SetCustomBedOffset(Form BaseBed, float Forward = 30.0, float Sideward = 0.0, float Upward = 37.0, float Rotation = 0.0) Native
bool function ClearCustomBedOffset(Form BaseBed) Native
float[] function GetBedOffsets(Form BaseBed) Native
sslThreadController function GetController(int tid) Native
int function FindActorController(Actor ActorRef) Native
int function FindPlayerController() Native
sslThreadController function GetActorController(Actor ActorRef) Native
sslThreadController function GetPlayerController() Native
function TrackActor(Actor ActorRef, string Callback) Native
function UntrackActor(Actor ActorRef, string Callback) Native
function TrackFaction(Faction FactionRef, string Callback) Native
function UntrackFaction(Faction FactionRef, string Callback) Native
function SendTrackedEvent(Actor ActorRef, string Hook, int id = -1) Native
bool function IsActorTracked(Actor ActorRef) Native
sslBaseAnimation[] function GetAnimationsByTags(int ActorCount, string Tags, string TagSuppress = "", bool RequireAll = true) Native
sslBaseAnimation[] function GetAnimationsByType(int ActorCount, int Males = -1, int Females = -1, int StageCount = -1, bool Aggressive = false, bool Sexual = true) Native
sslBaseAnimation[] function PickAnimationsByActors(Actor[] Positions, int Limit = 64, bool Aggressive = false) Native
sslBaseAnimation[] function GetAnimationsByDefault(int Males, int Females, bool IsAggressive = false, bool UsingBed = false, bool RestrictAggressive = true) Native
sslBaseAnimation[] function GetAnimationsByDefaultTags(int Males, int Females, bool IsAggressive = false, bool UsingBed = false, bool RestrictAggressive = true, string Tags, string TagsSuppressed = "", bool RequireAll = true) Native
sslBaseAnimation function GetAnimationByName(string FindName) Native
sslBaseAnimation function GetAnimationByRegistry(string Registry) Native
int function FindAnimationByName(string FindName) Native
int function GetAnimationCount(bool IgnoreDisabled = true) Native
string function MakeAnimationGenderTag(Actor[] Positions) Native
string function GetGenderTag(int Females = 0, int Males = 0, int Creatures = 0) Native
sslBaseAnimation[] function MergeAnimationLists(sslBaseAnimation[] List1, sslBaseAnimation[] List2) Native
sslBaseAnimation[] function RemoveTagged(sslBaseAnimation[] Anims, string Tags) Native
int function CountTag(sslBaseAnimation[] Anims, string Tags) Native
int function CountTagUsage(string Tags, bool IgnoreDisabled = true) Native
int function CountCreatureTagUsage(string Tags, bool IgnoreDisabled = true) Native
string[] function GetAllAnimationTags(int ActorCount = -1, bool IgnoreDisabled = true) Native
string[] function GetAllAnimationTagsInArray(sslBaseAnimation[] List) Native
sslBaseAnimation[] function GetCreatureAnimationsByRace(int ActorCount, Race RaceRef) Native
sslBaseAnimation[] function GetCreatureAnimationsByRaceTags(int ActorCount, Race RaceRef, string Tags, string TagSuppress = "", bool RequireAll = true) Native
sslBaseAnimation[] function GetCreatureAnimationsByRaceGenders(int ActorCount, Race RaceRef, int MaleCreatures = 0, int FemaleCreatures = 0, bool ForceUse = false) Native
sslBaseAnimation[] function GetCreatureAnimationsByRaceGendersTags(int ActorCount, Race RaceRef, int MaleCreatures = 0, int FemaleCreatures = 0, string Tags, string TagSuppress = "", bool RequireAll = true) Native
sslBaseAnimation[] function GetCreatureAnimationsByRaceKey(int ActorCount, string RaceKey) Native
sslBaseAnimation[] function GetCreatureAnimationsByRaceKeyTags(int ActorCount, string RaceKey, string Tags, string TagSuppress = "", bool RequireAll = true) Native
sslBaseAnimation[] function GetCreatureAnimationsByActors(int ActorCount, Actor[] Positions) Native
sslBaseAnimation[] function GetCreatureAnimationsByActorsTags(int ActorCount, Actor[] Positions, string Tags, string TagSuppress = "", bool RequireAll = true) Native
sslBaseAnimation function GetCreatureAnimationByName(string FindName) Native
sslBaseAnimation function GetCreatureAnimationByRegistry(string Registry) Native
bool function HasCreatureRaceAnimation(Race CreatureRace, int ActorCount = -1, int Gender = -1) Native
bool function HasCreatureRaceKeyAnimation(string RaceKey, int ActorCount = -1, int Gender = -1) Native
bool function AllowedCreature(Race CreatureRace) Native
bool function AllowedCreatureCombination(Race CreatureRace, Race CreatureRace2) Native
string[] function GetAllCreatureAnimationTags(int ActorCount = -1, bool IgnoreDisabled = true) Native
string[] function GetAllBothAnimationTags(int ActorCount = -1, bool IgnoreDisabled = true) Native
sslBaseVoice function PickVoice(Actor ActorRef) Native
sslBaseVoice function GetVoice(Actor ActorRef) Native
function SaveVoice(Actor ActorRef, sslBaseVoice Saving) Native
function ForgetVoice(Actor ActorRef) Native
sslBaseVoice function GetSavedVoice(Actor ActorRef) Native
bool function HasCustomVoice(Actor ActorRef) Native
sslBaseVoice function GetVoiceByGender(int Gender) Native
sslBaseVoice[] function GetVoicesByGender(int Gender) Native
sslBaseVoice function GetVoiceByName(string FindName) Native
int function FindVoiceByName(string FindName) Native
sslBaseVoice function GetVoiceBySlot(int slot) Native
sslBaseVoice function GetVoiceByTags(string Tags, string TagSuppress = "", bool RequireAll = true) Native
sslBaseVoice[] function GetVoicesByTags(string Tags, string TagSuppress = "", bool RequireAll = true) Native
sslBaseExpression function PickExpression(Actor ActorRef, Actor VictimRef = none) Native
sslBaseExpression function PickExpressionByStatus(Actor ActorRef, bool IsVictim = false, bool IsAggressor = false) Native
sslBaseExpression[] function GetExpressionsByStatus(Actor ActorRef, bool IsVictim = false, bool IsAggressor = false) Native
sslBaseExpression function PickExpressionsByTag(Actor ActorRef, string Tag) Native
sslBaseExpression[] function GetExpressionsByTag(Actor ActorRef, string Tag) Native
sslBaseExpression function GetExpressionByName(string findName) Native
int function FindExpressionByName(string findName) Native
sslBaseExpression function GetExpressionBySlot(int slot) Native
function OpenMouth(Actor ActorRef) Native
function CloseMouth(Actor ActorRef) Native
bool function IsMouthOpen(Actor ActorRef) Native
float[] function GetCurrentMFG(Actor ActorRef) Native
function ClearMFG(Actor ActorRef) Native
function ClearPhoneme(Actor ActorRef) Native
function ClearModifier(Actor ActorRef) Native
function ApplyPresetFloats(Actor ActorRef, float[] Preset) Native
int function GetEnjoyment(int tid, Actor ActorRef) Native
bool function IsVictim(int tid, Actor ActorRef) Native
bool function IsAggressor(int tid, Actor ActorRef) Native
bool function IsUsingStrapon(int tid, Actor ActorRef) Native
bool function PregnancyRisk(int tid, Actor ActorRef, bool AllowFemaleCum = false, bool AllowCreatureCum = false) Native
int function RegisterStat(string Name, string Value, string Prepend = "", string Append = "") Native
function Alter(string Name, string NewName = "", string Value = "", string Prepend = "", string Append = "") Native
int function FindStat(string Name) Native
string function GetActorStat(Actor ActorRef, string Name) Native
int function GetActorStatInt(Actor ActorRef, string Name) Native
float function GetActorStatFloat(Actor ActorRef, string Name) Native
string function SetActorStat(Actor ActorRef, string Name, string Value) Native
int function ActorAdjustBy(Actor ActorRef, string Name, int AdjustBy) Native
string function GetActorStatFull(Actor ActorRef, string Name) Native
string function GetStatFull(string Name) Native
string function GetStat(string Name) Native
int function GetStatInt(string Name) Native
float function GetStatFloat(string Name) Native
string function SetStat(string Name, string Value) Native
int function AdjustBy(string Name, int AdjustBy) Native
int function CalcSexuality(bool IsFemale, int males, int females) Native
int function CalcLevel(float total, float curve = 0.65) Native
string function ParseTime(int time) Native
int function PlayerSexCount(Actor ActorRef) Native
bool function HadPlayerSex(Actor ActorRef) Native
Actor function MostUsedPlayerSexPartner() Native
Actor[] function MostUsedPlayerSexPartners(int MaxActors = 5) Native
Actor function LastSexPartner(Actor ActorRef) Native
bool function HasHadSexTogether(Actor ActorRef1, Actor ActorRef2) Native
Actor function LastAggressor(Actor ActorRef) Native
bool function WasVictimOf(Actor VictimRef, Actor AggressorRef) Native
Actor function LastVictim(Actor ActorRef) Native
bool function WasAggressorTo(Actor AggressorRef, Actor VictimRef) Native
float function AdjustPurity(Actor ActorRef, float amount) Native
function SetSexuality(Actor ActorRef, int amount) Native
function SetSexualityStraight(Actor ActorRef) Native
function SetSexualityBisexual(Actor ActorRef) Native
function SetSexualityGay(Actor ActorRef) Native
int function GetSexuality(Actor ActorRef) Native
string function GetSexualityTitle(Actor ActorRef) Native
string function GetSkillTitle(Actor ActorRef, string Skill) Native
int function GetSkill(Actor ActorRef, string Skill) Native
int function GetSkillLevel(Actor ActorRef, string Skill) Native
float function GetPurity(Actor ActorRef) Native
int function GetPurityLevel(Actor ActorRef) Native
string function GetPurityTitle(Actor ActorRef) Native
bool function IsPure(Actor ActorRef) Native
bool function IsLewd(Actor ActorRef) Native
bool function IsStraight(Actor ActorRef) Native
bool function IsBisexual(Actor ActorRef) Native
bool function IsGay(Actor ActorRef) Native
int function SexCount(Actor ActorRef) Native
bool function HadSex(Actor ActorRef) Native
float function LastSexGameTime(Actor ActorRef) Native
float function DaysSinceLastSex(Actor ActorRef) Native
float function HoursSinceLastSex(Actor ActorRef) Native
float function MinutesSinceLastSex(Actor ActorRef) Native
float function SecondsSinceLastSex(Actor ActorRef) Native
string function LastSexTimerString(Actor ActorRef) Native
float function LastSexRealTime(Actor ActorRef) Native
float function DaysSinceLastSexRealTime(Actor ActorRef) Native
float function HoursSinceLastSexRealTime(Actor ActorRef) Native
float function MinutesSinceLastSexRealTime(Actor ActorRef) Native
float function SecondsSinceLastSexRealTime(Actor ActorRef) Native
string function LastSexTimerStringRealTime(Actor ActorRef) Native
float function AdjustPlayerPurity(float amount) Native
int function GetPlayerPurityLevel() Native
string function GetPlayerPurityTitle() Native
string function GetPlayerSexualityTitle() Native
int function GetPlayerSkillLevel(string Skill) Native
string function GetPlayerSkillTitle(string Skill) Native
sslBaseAnimation function RegisterAnimation(string Registrar, Form CallbackForm = none, ReferenceAlias CallbackAlias = none) Native
sslBaseAnimation function RegisterCreatureAnimation(string Registrar, Form CallbackForm = none, ReferenceAlias CallbackAlias = none) Native
sslBaseVoice function RegisterVoice(string Registrar, Form CallbackForm = none, ReferenceAlias CallbackAlias = none) Native
sslBaseExpression function RegisterExpression(string Registrar, Form CallbackForm = none, ReferenceAlias CallbackAlias = none) Native
sslBaseAnimation function NewAnimationObject(string Token, Form Owner) Native
sslBaseVoice function NewVoiceObject(string Token, Form Owner) Native
sslBaseExpression function NewExpressionObject(string Token, Form Owner) Native
sslBaseAnimation function GetSetAnimationObject(string Token, string Callback, Form Owner) Native
sslBaseVoice function GetSetVoiceObject(string Token, string Callback, Form Owner) Native
sslBaseExpression function GetSetExpressionObject(string Token, string Callback, Form Owner) Native
sslBaseAnimation function NewAnimationObjectCopy(string Token, sslBaseAnimation CopyFrom, Form Owner) Native
sslBaseVoice function NewVoiceObjectCopy(string Token, sslBaseVoice CopyFrom, Form Owner) Native
sslBaseExpression function NewExpressionObjectCopy(string Token, sslBaseExpression CopyFrom, Form Owner) Native
sslBaseAnimation function GetAnimationObject(string Token) Native
sslBaseVoice function GetVoiceObject(string Token) Native
sslBaseExpression function GetExpressionObject(string Token) Native
sslBaseAnimation[] function GetOwnerAnimations(Form Owner) Native
sslBaseVoice[] function GetOwnerVoices(Form Owner) Native
sslBaseExpression[] function GetOwnerExpressions(Form Owner) Native
bool function HasAnimationObject(string Token) Native
bool function HasVoiceObject(string Token) Native
bool function HasExpressionObject(string Token) Native
bool function ReleaseAnimationObject(string Token) Native
bool function ReleaseVoiceObject(string Token) Native
bool function ReleaseExpressionObject(string Token) Native
int function ReleaseOwnerAnimations(Form Owner) Native
int function ReleaseOwnerVoices(Form Owner) Native
int function ReleaseOwnerExpressions(Form Owner) Native
sslBaseAnimation function MakeAnimationRegistered(string Token) Native
sslBaseVoice function MakeVoiceRegistered(string Token) Native
sslBaseExpression function MakeExpressionRegistered(string Token) Native
bool function RemoveRegisteredAnimation(string Registrar) Native
bool function RemoveRegisteredCreatureAnimation(string Registrar) Native
bool function RemoveRegisteredVoice(string Registrar) Native
bool function RemoveRegisteredExpression(string Registrar) Native
Actor[] function MakeActorArray(Actor Actor1 = none, Actor Actor2 = none, Actor Actor3 = none, Actor Actor4 = none, Actor Actor5 = none) Native
sslThreadController function HookController(string argString) Native
sslBaseAnimation function HookAnimation(string argString) Native
int function HookStage(string argString) Native
Actor function HookVictim(string argString) Native
Actor[] function HookActors(string argString) Native
float function HookTime(string argString) Native
bool function HasCreatureAnimation(Race CreatureRace, int Gender = -1) Native
sslBaseAnimation[] function GetAnimationsByTag(int ActorCount, string Tag1, string Tag2 = "", string Tag3 = "", string TagSuppress = "", bool RequireAll = true) Native
sslBaseAnimation[] function GetCreatureAnimationsByTags(int ActorCount, string Tags, string TagSuppress = "", bool RequireAll = true) Native
sslBaseVoice function GetVoiceByTag(string Tag1, string Tag2 = "", string TagSuppress = "", bool RequireAll = true) Native
function ApplyCum(Actor ActorRef, int CumID) Native
form function StripWeapon(Actor ActorRef, bool RightHand = true) Native
sslBaseAnimation[] property Animations hidden AutoReadonly
sslBaseAnimation[] function get() Native
sslBaseAnimation[] property CreatureAnimations hidden AutoReadonly
sslBaseAnimation[] function get() Native
sslBaseVoice[] property Voices hidden AutoReadonly
sslBaseVoice[] function get() Native
sslBaseExpression[] property Expressions hidden AutoReadonly
sslBaseExpression[] function get() Native
sslBaseExpression function RandomExpressionByTag(string Tag) Native
function ApplyPreset(Actor ActorRef, int[] Preset) Native
sslThreadController[] property Threads hidden AutoReadonly
sslThreadController[] function get() Native
bool function IsImpure(Actor ActorRef) Native
int function GetPlayerStatLevel(string Skill) Native
sslSystemConfig property Config auto hidden
Faction property AnimatingFaction auto hidden
Actor property PlayerRef auto hidden
sslActorLibrary property ActorLib auto hidden
sslThreadLibrary property ThreadLib auto hidden
sslActorStats property Stats auto hidden
sslThreadSlots property ThreadSlots auto hidden
sslAnimationSlots property AnimSlots auto hidden
sslCreatureAnimationSlots property CreatureSlots auto hidden
sslVoiceSlots property VoiceSlots auto hidden
sslExpressionSlots property ExpressionSlots auto hidden
sslObjectFactory property Factory auto hidden
function Setup() Native
function Log(string Log, string Type = "NOTICE") Native
sslThreadModel function NewThread(float TimeOut = 30.0) Native
int function StartSex(Actor[] Positions, sslBaseAnimation[] Anims, Actor Victim = none, ObjectReference CenterOn = none, bool AllowBed = true, string Hook = "") Native
sslThreadController function QuickStart(Actor Actor1, Actor Actor2 = none, Actor Actor3 = none, Actor Actor4 = none, Actor Actor5 = none, Actor Victim = none, string Hook = "", string AnimationTags = "") Native
