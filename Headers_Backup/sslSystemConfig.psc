scriptname sslSystemConfig extends sslSystemLibrary
SexLabFramework property SexLab auto
int function GetVersion() Native
string function GetStringVer() Native
bool property Enabled hidden AutoReadonly
bool function get() Native
bool property DebugMode hidden AutoReadonly
bool function get() Native
function set(bool value) Native
Faction property AnimatingFaction auto
Faction property GenderFaction auto
Faction property ForbiddenFaction auto
Weapon property DummyWeapon auto
Armor property NudeSuit auto
Armor property CalypsStrapon auto
Form[] property Strapons auto hidden
Spell property SelectedSpell auto
Spell property CumVaginalOralAnalSpell auto
Spell property CumOralAnalSpell auto
Spell property CumVaginalOralSpell auto
Spell property CumVaginalAnalSpell auto
Spell property CumVaginalSpell auto
Spell property CumOralSpell auto
Spell property CumAnalSpell auto
Spell property Vaginal1Oral1Anal1 auto
Spell property Vaginal2Oral1Anal1 auto
Spell property Vaginal2Oral2Anal1 auto
Spell property Vaginal2Oral1Anal2 auto
Spell property Vaginal1Oral2Anal1 auto
Spell property Vaginal1Oral2Anal2 auto
Spell property Vaginal1Oral1Anal2 auto
Spell property Vaginal2Oral2Anal2 auto
Spell property Oral1Anal1 auto
Spell property Oral2Anal1 auto
Spell property Oral1Anal2 auto
Spell property Oral2Anal2 auto
Spell property Vaginal1Oral1 auto
Spell property Vaginal2Oral1 auto
Spell property Vaginal1Oral2 auto
Spell property Vaginal2Oral2 auto
Spell property Vaginal1Anal1 auto
Spell property Vaginal2Anal1 auto
Spell property Vaginal1Anal2 auto
Spell property Vaginal2Anal2 auto
Spell property Vaginal1 auto
Spell property Vaginal2 auto
Spell property Oral1 auto
Spell property Oral2 auto
Spell property Anal1 auto
Spell property Anal2 auto
Keyword property CumOralKeyword auto
Keyword property CumAnalKeyword auto
Keyword property CumVaginalKeyword auto
Keyword property CumOralStackedKeyword auto
Keyword property CumAnalStackedKeyword auto
Keyword property CumVaginalStackedKeyword auto
Keyword property ActorTypeNPC auto
Keyword property SexLabActive auto
Keyword property FurnitureBedRoll auto
Furniture property BaseMarker auto
Package property DoNothing auto
Sound property OrgasmFX auto
Sound property SquishingFX auto
Sound property SuckingFX auto
Sound property SexMixedFX auto
Sound[] property HotkeyUp auto
Sound[] property HotkeyDown auto
Static property LocationMarker auto
FormList property BedsList auto
FormList property BedRollsList auto
FormList property DoubleBedsList auto
Message property UseBed auto
Message property CleanSystemFinish auto
Message property CheckSKSE auto
Message property CheckFNIS auto
Message property CheckSkyrim auto
Message property CheckSexLabUtil auto
Message property CheckPapyrusUtil auto
Message property CheckSkyUI auto
Message property TakeThreadControl auto
Topic property LipSync auto
VoiceType property SexLabVoiceM auto
VoiceType property SexLabVoiceF auto
FormList property SexLabVoices auto
SoundCategory property AudioSFX auto
SoundCategory property AudioVoice auto
Idle property IdleReset auto
GlobalVariable property DebugVar1 auto
GlobalVariable property DebugVar2 auto
GlobalVariable property DebugVar3 auto
GlobalVariable property DebugVar4 auto
GlobalVariable property DebugVar5 auto
bool property RestrictAggressive auto hidden
bool property AllowCreatures auto hidden
bool property NPCSaveVoice auto hidden
bool property UseStrapons auto hidden
bool property RestrictStrapons auto hidden
bool property RedressVictim auto hidden
bool property RagdollEnd auto hidden
bool property UseMaleNudeSuit auto hidden
bool property UseFemaleNudeSuit auto hidden
bool property UndressAnimation auto hidden
bool property UseLipSync auto hidden
bool property UseExpressions auto hidden
bool property RefreshExpressions auto hidden
bool property ScaleActors auto hidden
bool property UseCum auto hidden
bool property AllowFFCum auto hidden
bool property DisablePlayer auto hidden
bool property AutoTFC auto hidden
bool property AutoAdvance auto hidden
bool property ForeplayStage auto hidden
bool property OrgasmEffects auto hidden
bool property RaceAdjustments auto hidden
bool property BedRemoveStanding auto hidden
bool property UseCreatureGender auto hidden
bool property LimitedStrip auto hidden
bool property RestrictSameSex auto hidden
bool property RestrictGenderTag auto hidden
bool property SeparateOrgasms auto hidden
bool property RemoveHeelEffect auto hidden
bool property AdjustTargetStage auto hidden
bool property ShowInMap auto hidden
bool property DisableTeleport auto hidden
bool property SeedNPCStats auto hidden
bool property DisableScale auto hidden
bool property FixVictimPos auto hidden
bool property ForceSort auto hidden
int property AnimProfile auto hidden
int property AskBed auto hidden
int property NPCBed auto hidden
int property OpenMouthSize auto hidden
int property UseFade auto hidden
int property Backwards auto hidden
int property AdjustStage auto hidden
int property AdvanceAnimation auto hidden
int property ChangeAnimation auto hidden
int property ChangePositions auto hidden
int property AdjustChange auto hidden
int property AdjustForward auto hidden
int property AdjustSideways auto hidden
int property AdjustUpward auto hidden
int property RealignActors auto hidden
int property MoveScene auto hidden
int property RestoreOffsets auto hidden
int property RotateScene auto hidden
int property EndAnimation auto hidden
int property ToggleFreeCamera auto hidden
int property TargetActor auto hidden
int property AdjustSchlong auto hidden
float property CumTimer auto hidden
float property ShakeStrength auto hidden
float property AutoSUCSM auto hidden
float property MaleVoiceDelay auto hidden
float property FemaleVoiceDelay auto hidden
float property ExpressionDelay auto hidden
float property VoiceVolume auto hidden
float property SFXDelay auto hidden
float property SFXVolume auto hidden
float property LeadInCoolDown auto hidden
bool[] property StripMale auto hidden
bool[] property StripFemale auto hidden
bool[] property StripLeadInFemale auto hidden
bool[] property StripLeadInMale auto hidden
bool[] property StripVictim auto hidden
bool[] property StripAggressor auto hidden
float[] property StageTimer auto hidden
float[] property StageTimerLeadIn auto hidden
float[] property StageTimerAggr auto hidden
float[] property OpenMouthMale auto hidden
float[] property OpenMouthFemale auto hidden
float[] property BedOffset auto hidden
bool property HasHDTHeels auto hidden
bool property HasNiOverride auto hidden
bool property HasFrostfall auto hidden
bool property HasSchlongs auto hidden
bool property HasMFGFix auto hidden
FormList property FrostExceptions auto hidden
Actor property TargetRef auto hidden
Actor[] property TargetRefs auto hidden
int property LipsPhoneme auto hidden
bool property LipsFixedValue auto hidden
int property LipsMinValue auto hidden
int property LipsMaxValue auto hidden
int property LipsSoundTime auto hidden
float property LipsMoveTime auto hidden
float function GetVoiceDelay(bool IsFemale = false, int Stage = 1, bool IsSilent = false) Native
bool[] function GetStrip(bool IsFemale, bool IsLeadIn = false, bool IsAggressive = false, bool IsVictim = false) Native
bool function UsesNudeSuit(bool IsFemale) Native
bool function HasCreatureInstall() Native
float[] function GetOpenMouthPhonemes(bool isFemale) Native
bool function SetOpenMouthPhonemes(bool isFemale, float[] Phonemes) Native
bool function SetOpenMouthPhoneme(bool isFemale, int id, float value) Native
int function GetOpenMouthExpression(bool isFemale) Native
bool function SetOpenMouthExpression(bool isFemale, int value) Native
bool function AddCustomBed(Form BaseBed, int BedType = 0) Native
bool function SetCustomBedOffset(Form BaseBed, float Forward = 0.0, float Sideward = 0.0, float Upward = 37.0, float Rotation = 0.0) Native
bool function ClearCustomBedOffset(Form BaseBed) Native
float[] function GetBedOffsets(Form BaseBed) Native
Form function GetStrapon() Native
Form function WornStrapon(Actor ActorRef) Native
bool function HasStrapon(Actor ActorRef) Native
Form function PickStrapon(Actor ActorRef) Native
Form function EquipStrapon(Actor ActorRef) Native
function UnequipStrapon(Actor ActorRef) Native
function LoadStrapons() Native
Armor function LoadStrapon(string esp, int id) Native
function SetTargetActor() Native
function AddTargetActor(Actor ActorRef) Native
sslThreadController function GetThreadControlled() Native
function GetThreadControl(sslThreadController TargetThread) Native
function DisableThreadControl(sslThreadController TargetThread) Native
function ToggleFreeCamera() Native
bool function BackwardsPressed() Native
bool function AdjustStagePressed() Native
bool function IsAdjustStagePressed() Native
bool function MirrorPress(int mirrorkey) Native
function ExportProfile(int Profile = 1) Native
function ImportProfile(int Profile = 1) Native
function SwapToProfile(int Profile) Native
bool function SetAdjustmentProfile(string ProfileName) global native
bool function SaveAdjustmentProfile() global native
Spell function GetHDTSpell(Actor ActorRef) Native
Faction property BardExcludeFaction auto
ReferenceAlias property BardBystander1 auto
ReferenceAlias property BardBystander2 auto
ReferenceAlias property BardBystander3 auto
ReferenceAlias property BardBystander4 auto
ReferenceAlias property BardBystander5 auto
bool function CheckBardAudience(Actor ActorRef, bool RemoveFromAudience = true) Native
bool function BystanderClear(Actor ActorRef, ReferenceAlias BardBystander) Native
bool function CheckSystemPart(string CheckSystem) Native
bool function CheckSystem() Native
function Reload() Native
function InitThreadHooks() Native
int function RegisterThreadHook(sslThreadHook Hook) Native
sslThreadHook[] function GetThreadHooks() Native
int function GetThreadHookCount() Native
function Setup() Native
function SetDefaults() Native
function ExportSettings() Native
function ImportSettings() Native
function ExportInt(string Name, int Value) Native
int function ImportInt(string Name, int Value) Native
function ExportBool(string Name, bool Value) Native
bool function ImportBool(string Name, bool Value) Native
function ExportFloat(string Name, float Value) Native
float function ImportFloat(string Name, float Value) Native
function ExportFloatList(string Name, float[] Values, int len) Native
float[] function ImportFloatList(string Name, float[] Values, int len) Native
function ExportBoolList(string Name, bool[] Values, int len) Native
bool[] function ImportBoolList(string Name, bool[] Values, int len) Native
function ExportAnimations() Native
function ImportAnimations() Native
function ExportCreatures() Native
function ImportCreatures() Native
function ExportExpressions() Native
function ImportExpressions() Native
function ExportVoices() Native
function ImportVoices() Native
function StoreActor(Form FormRef) global Native
function RemoveFade(bool forceTest = false) Native
function ApplyFade(bool forceTest = false) Native
function ReloadData() Native
bool property bRestrictAggressive hidden AutoReadonly
bool function get() Native
bool property bAllowCreatures hidden AutoReadonly
bool function get() Native
bool property bUseStrapons hidden AutoReadonly
bool function get() Native
bool property bRedressVictim hidden AutoReadonly
bool function get() Native
bool property bRagdollEnd hidden AutoReadonly
bool function get() Native
bool property bUndressAnimation hidden AutoReadonly
bool function get() Native
bool property bScaleActors hidden AutoReadonly
bool function get() Native
bool property bUseCum hidden AutoReadonly
bool function get() Native
bool property bAllowFFCum hidden AutoReadonly
bool function get() Native
bool property bDisablePlayer hidden AutoReadonly
bool function get() Native
bool property bAutoTFC hidden AutoReadonly
bool function get() Native
bool property bAutoAdvance hidden AutoReadonly
bool function get() Native
bool property bForeplayStage hidden AutoReadonly
bool function get() Native
bool property bOrgasmEffects hidden AutoReadonly
bool function get() Native
