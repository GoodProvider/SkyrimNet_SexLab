scriptname sslActorAlias extends ReferenceAlias
Actor property ActorRef auto hidden
bool property ForceOpenMouth auto hidden
bool property OpenMouth hidden AutoReadonly
bool function get() Native
bool property IsSilent hidden AutoReadonly
bool function get() Native
bool property UseStrapon hidden AutoReadonly
bool function get() Native
int property Schlong hidden AutoReadonly
int function get() Native
bool property MalePosition hidden AutoReadonly
bool function get() Native
bool function SetActor(Actor ProspectRef) Native
function ClearAlias() Native
function LoadShares() Native
bool function SetActor(Actor ProspectRef) Native
function PrepareActor() Native
function PathToCenter() Native
function StartAnimating() Native
function SendAnimation() Native
function GetPositionInfo() Native
function SendAnimation() Native
function SyncThread() Native
function SyncActor() Native
function SyncAll(bool Force = false) Native
function RefreshActor() Native
function RefreshLoc() Native
function SyncLocation(bool Force = false) Native
function Snap() Native
function OrgasmEffect() Native
function DoOrgasm(bool Forced = false) Native
function ClearAlias() Native
function Initialize() Native
function SyncAll(bool Force = false) Native
function StopAnimating(bool Quick = false, string ResetAnim = "IdleForceDefaultState") Native
function SendDefaultAnimEvent(bool Exit = False) Native
function AttachMarker() Native
function LockActor() Native
function UnlockActor() Native
function RestoreActorDefaults() Native
function RefreshActor() Native
int function GetGender() Native
function SetVictim(bool Victimize) Native
bool function IsVictim() Native
string function GetActorKey() Native
function SetAdjustKey(string KeyVar) Native
function AdjustEnjoyment(int AdjustBy) Native
int function GetEnjoyment() Native
int function GetPain() Native
int function CalcReaction() Native
function ApplyCum() Native
function DisableOrgasm(bool bNoOrgasm) Native
bool function IsOrgasmAllowed() Native
bool function NeedsOrgasm() Native
function SetVoice(sslBaseVoice ToVoice = none, bool ForceSilence = false) Native
sslBaseVoice function GetVoice() Native
function SetExpression(sslBaseExpression ToExpression) Native
sslBaseExpression function GetExpression() Native
function SetStartAnimationEvent(string EventName, float PlayTime) Native
function SetEndAnimationEvent(string EventName) Native
bool function IsUsingStrapon() Native
function ResolveStrapon(bool force = false) Native
function EquipStrapon() Native
function UnequipStrapon() Native
function SetStrapon(Form ToStrapon) Native
Form function GetStrapon() Native
bool function PregnancyRisk() Native
function OverrideStrip(bool[] SetStrip) Native
bool function ContinueStrip(Form ItemRef, bool DoStrip = true) Native
function Strip() Native
function UnStrip() Native
bool property DoRagdoll hidden AutoReadonly
bool function get() Native
function set(bool value) Native
bool property DoUndress hidden AutoReadonly
bool function get() Native
function set(bool value) Native
bool property DoRedress hidden AutoReadonly
bool function get() Native
function set(bool value) Native
function ForcePathToCenter(bool forced) Native
function DisablePathToCenter(bool disabling) Native
bool property DoPathToCenter AutoReadonly
bool function get() Native
function RefreshExpression() Native
function TrackedEvent(string EventName) Native
function ClearEffects() Native
int property kPrepareActor = 0 autoreadonly hidden
int property kSyncActor    = 1 autoreadonly hidden
int property kResetActor   = 2 autoreadonly hidden
int property kRefreshActor = 3 autoreadonly hidden
int property kStartup      = 4 autoreadonly hidden
function RegisterEvents() Native
function ClearEvents() Native
function Initialize() Native
function Setup() Native
function Log(string msg, string src = "") Native
function PlayLouder(Sound SFX, ObjectReference FromRef, float Volume) Native
function PrepareActor() Native
function PathToCenter() Native
function StartAnimating() Native
function SyncActor() Native
function SyncThread() Native
function SyncLocation(bool Force = false) Native
function RefreshLoc() Native
function Snap() Native
function OrgasmEffect() Native
function DoOrgasm(bool Forced = false) Native
function OffsetCoords(float[] Output, float[] CenterCoords, float[] OffsetBy) global native
bool function IsInPosition(Actor CheckActor, ObjectReference CheckMarker, float maxdistance = 30.0) global native
int function CalcEnjoyment(float[] XP, float[] SkillsAmounts, bool IsLeadin, bool IsFemaleActor, float Timer, int OnStage, int MaxStage) global native
int function IntIfElse(bool check, int isTrue, int isFalse) Native
