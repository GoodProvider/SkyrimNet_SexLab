scriptname sslThreadModel extends Quest hidden
int property tid hidden AutoReadonly
int function get() Native
bool property IsLocked hidden AutoReadonly
bool function get() Native
sslSystemConfig property Config auto
sslActorLibrary property ActorLib auto
sslThreadLibrary property ThreadLib auto
sslAnimationSlots property AnimSlots auto
sslCreatureAnimationSlots property CreatureSlots auto
sslActorAlias[] property ActorAlias auto hidden
Actor[] property Positions auto hidden
Actor property PlayerRef auto hidden
bool property SortActors auto hidden
bool property HasPlayer auto hidden
bool property AutoAdvance auto hidden
bool property LeadIn auto hidden
bool property FastEnd auto hidden
Race property CreatureRef auto hidden
int property Stage auto hidden
int property ActorCount auto hidden
Sound property SoundFX auto hidden
string property AdjustKey auto hidden
string[] property AnimEvents auto hidden
sslBaseAnimation property Animation auto hidden
sslBaseAnimation property StartingAnimation auto hidden
sslBaseAnimation[] property Animations hidden AutoReadonly
sslBaseAnimation[] function get() Native
float[] property SkillBonus auto hidden
float[] property SkillXP auto hidden
bool[] property IsType auto hidden
bool property IsAggressive hidden AutoReadonly
bool function get() Native
function set(bool value) Native
bool property IsVaginal hidden AutoReadonly
bool function get() Native
function set(bool value) Native
bool property IsAnal hidden AutoReadonly
bool function get() Native
function set(bool value) Native
bool property IsOral hidden AutoReadonly
bool function get() Native
function set(bool value) Native
bool property IsLoving hidden AutoReadonly
bool function get() Native
function set(bool value) Native
bool property IsDirty hidden AutoReadonly
bool function get() Native
function set(bool value) Native
float[] property Timers hidden AutoReadonly
float[] function get() Native
function set(float[] value) Native
float[] property CenterLocation auto hidden
ObjectReference property CenterRef auto hidden
ReferenceAlias property CenterAlias auto hidden
float[] property RealTime auto hidden
float property StartedAt auto hidden
float property TotalTime hidden AutoReadonly
float function get() Native
Actor[] property Victims auto hidden
Actor property VictimRef hidden AutoReadonly
Actor function get() Native
function set(Actor ActorRef) Native
bool property DisableOrgasms auto hidden
int[] property BedStatus auto hidden
ObjectReference property BedRef auto hidden
int property BedTypeID hidden AutoReadonly
int function get() Native
bool property UsingBed hidden AutoReadonly
bool function get() Native
bool property UsingBedRoll hidden AutoReadonly
bool function get() Native
bool property UsingSingleBed hidden AutoReadonly
bool function get() Native
bool property UsingDoubleBed hidden AutoReadonly
bool function get() Native
bool property UseNPCBed hidden AutoReadonly
bool function get() Native
int[] property Genders auto hidden
int property Males hidden AutoReadonly
int function get() Native
int property Females hidden AutoReadonly
int function get() Native
int property MaleCreatures hidden AutoReadonly
int function get() Native
int property FemaleCreatures hidden AutoReadonly
int function get() Native
int property Creatures hidden AutoReadonly
int function get() Native
bool property HasCreature hidden AutoReadonly
bool function get() Native
bool property DebugMode auto hidden
float property t auto hidden
int function AddActor(Actor ActorRef, bool IsVictim = false, sslBaseVoice Voice = none, bool ForceSilent = false) Native
bool function AddActors(Actor[] ActorList, Actor VictimActor = none) Native
sslThreadController function StartThread() Native
bool function UseLimitedStrip() Native
function SetStrip(Actor ActorRef, bool[] StripSlots) Native
function SetNoStripping(Actor ActorRef) Native
function DisableUndressAnimation(Actor ActorRef = none, bool disabling = true) Native
function DisableRedress(Actor ActorRef = none, bool disabling = true) Native
function DisableRagdollEnd(Actor ActorRef = none, bool disabling = true) Native
function DisablePathToCenter(Actor ActorRef = none, bool disabling = true) Native
function ForcePathToCenter(Actor ActorRef = none, bool forced = true) Native
function SetStartAnimationEvent(Actor ActorRef, string EventName = "IdleForceDefaultState", float PlayTime = 0.1) Native
function SetEndAnimationEvent(Actor ActorRef, string EventName = "IdleForceDefaultState") Native
function DisableAllOrgasms(bool OrgasmsDisabled = true) Native
function DisableOrgasm(Actor ActorRef, bool OrgasmDisabled = true) Native
bool function IsOrgasmAllowed(Actor ActorRef) Native
bool function NeedsOrgasm(Actor ActorRef) Native
function ForceOrgasm(Actor ActorRef) Native
function SetVoice(Actor ActorRef, sslBaseVoice Voice, bool ForceSilent = false) Native
sslBaseVoice function GetVoice(Actor ActorRef) Native
bool function IsUsingStrapon(Actor ActorRef) Native
function EquipStrapon(Actor ActorRef) Native
function UnequipStrapon(Actor ActorRef) Native
function SetStrapon(Actor ActorRef, Form ToStrapon) Native
Form function GetStrapon(Actor ActorRef) Native
function SetExpression(Actor ActorRef, sslBaseExpression Expression) Native
sslBaseExpression function GetExpression(Actor ActorRef) Native
int function GetEnjoyment(Actor ActorRef) Native
int function GetPain(Actor ActorRef) Native
int function GetPlayerPosition() Native
int function GetPosition(Actor ActorRef) Native
bool function IsPlayerActor(Actor ActorRef) Native
bool function IsPlayerPosition(int Position) Native
bool function HasActor(Actor ActorRef) Native
bool function PregnancyRisk(Actor ActorRef, bool AllowFemaleCum = false, bool AllowCreatureCum = false) Native
function SetVictim(Actor ActorRef, bool Victimize = true) Native
bool function IsVictim(Actor ActorRef) Native
bool function IsAggressor(Actor ActorRef) Native
int function GetHighestPresentRelationshipRank(Actor ActorRef) Native
int function GetLowestPresentRelationshipRank(Actor ActorRef) Native
function ChangeActors(Actor[] NewPositions) Native
function SetForcedAnimations(sslBaseAnimation[] AnimationList) Native
sslBaseAnimation[] function GetForcedAnimations() Native
function ClearForcedAnimations() Native
function SetAnimations(sslBaseAnimation[] AnimationList) Native
sslBaseAnimation[] function GetAnimations() Native
function ClearAnimations() Native
function SetLeadAnimations(sslBaseAnimation[] AnimationList) Native
sslBaseAnimation[] function GetLeadAnimations() Native
function ClearLeadAnimations() Native
function AddAnimation(sslBaseAnimation AddAnimation, bool ForceTo = false) Native
function SetStartingAnimation(sslBaseAnimation FirstAnimation) Native
int function FilterAnimations() Native
function DisableLeadIn(bool disabling = true) Native
function DisableBedUse(bool disabling = true) Native
function SetBedFlag(int flag = 0) Native
function SetFurnitureIgnored(bool disabling = true) Native
function SetTimers(float[] SetTimers) Native
float function GetStageTimer(int maxstage) Native
int function AreUsingFurniture(Actor[] ActorList) Native
function CenterOnObject(ObjectReference CenterOn, bool resync = true) Native
function CenterOnCoords(float LocX = 0.0, float LocY = 0.0, float LocZ = 0.0, float RotX = 0.0, float RotY = 0.0, float RotZ = 0.0, bool resync = true) Native
bool function CenterOnBed(bool AskPlayer = true, float Radius = 750.0) Native
function SetHook(string AddHooks) Native
string function GetHook() Native
string[] function GetHooks() Native
function RemoveHook(string DelHooks) Native
bool function HasTag(string Tag) Native
bool function AddTag(string Tag) Native
bool function RemoveTag(string Tag) Native
bool function ToggleTag(string Tag) Native
bool function AddTagConditional(string Tag, bool AddTag) Native
string[] function AddString(string[] ArrayValues, string ToAdd, bool RemoveDupes = true) Native
bool function CheckTags(string[] CheckTags, bool RequireAll = true, bool Suppress = false) Native
string[] function GetTags() Native
int function FindSlot(Actor ActorRef) Native
sslActorAlias function ActorAlias(Actor ActorRef) Native
sslActorAlias function PositionAlias(int Position) Native
function Action(string FireState) Native
function SendThreadEvent(string HookEvent) Native
function SetupThreadEvent(string HookEvent) Native
function HookAnimationStarting() Native
function HookAnimationPrepare() Native
function HookStageStart() Native
function HookStageEnd() Native
function HookAnimationEnding() Native
function HookAnimationEnd() Native
int property kPrepareActor = 0 autoreadonly hidden
int property kSyncActor    = 1 autoreadonly hidden
int property kResetActor   = 2 autoreadonly hidden
int property kRefreshActor = 3 autoreadonly hidden
int property kStartup      = 4 autoreadonly hidden
string function Key(string Callback) Native
function QuickEvent(string Callback) Native
function SyncEvent(int id, float WaitTime) Native
function SyncEventDone(int id) Native
function SendTrackedEvent(Actor ActorRef, string Hook = "") Native
function SetupActorEvent(Actor ActorRef, string Callback) Native
function Log(string msg, string src = "") Native
function Fatal(string msg, string src = "", bool halt = true) Native
function UpdateAdjustKey() Native
function RemoveFade() Native
function ApplyFade() Native
sslActorAlias function PickAlias(Actor ActorRef) Native
function ResolveTimers() Native
function SetTID(int id) Native
function InitShares() Native
function Initialize() Native
sslThreadModel function Make() Native
sslThreadModel function Make() Native
sslThreadController function StartThread() Native
int function AddActor(Actor ActorRef, bool IsVictim = false, sslBaseVoice Voice = none, bool ForceSilent = false) Native
bool function AddActors(Actor[] ActorList, Actor VictimActor = none) Native
function FireAction() Native
function EndAction() Native
function SyncDone() Native
function RefreshDone() Native
function PrepareDone() Native
function ResetDone() Native
function StripDone() Native
function OrgasmDone() Native
function StartupDone() Native
function SetAnimation(int aid = -1) Native
function EnableHotkeys(bool forced = false) Native
function RealignActors() Native
bool function HasPlayer() Native
Actor function GetPlayer() Native
Actor function GetVictim() Native
float function GetTime() Native
function SetBedding(int flag = 0) Native
