scriptname sslBaseAnimation extends sslBaseObject
bool property GenderedCreatures auto hidden
int function DataIndex(int Slots, int Position, int Stage, int Slot = 0) Native
int function StageIndex(int Position, int Stage) Native
int function AdjIndex(int Stage, int Slot = 0, int Slots = 4) Native
int function OffsetIndex(int Stage, int Slot) Native
int function FlagIndex(int Stage, int Slot) Native
string[] function FetchPosition(int Position) Native
string[] function FetchStage(int Stage) Native
function GetAnimEvents(string[] AnimEvents, int Stage) Native
string function FetchPositionStage(int Position, int Stage) Native
function SetPositionStage(int Position, int Stage, string AnimationEvent) Native
bool function HasTimer(int Stage) Native
float function GetTimer(int Stage) Native
function SetStageTimer(int Stage, float Timer) Native
float function GetTimersRunTime(float[] StageTimers) Native
float function GetRunTime() Native
float function GetRunTimeLeadIn() Native
float function GetRunTimeAggressive() Native
Sound property SoundFX hidden AutoReadonly
Sound function get() Native
function set(Sound var) Native
Sound function GetSoundFX(int Stage) Native
function SetStageSoundFX(int stage, Sound StageFX) Native
float[] function GetPositionOffsets(string AdjustKey, int Position, int Stage) Native
float[] function GetRawOffsets(int Position, int Stage) Native
float[] function _GetStageAdjustments(string Registrar, string AdjustKey, int Stage) global native
float[] function GetPositionAdjustments(string AdjustKey, int Position, int Stage) Native
float[] function _GetAllAdjustments(string Registrar, string AdjustKey) global native
float[] function GetAllAdjustments(string AdjustKey) Native
bool function _HasAdjustments(string Registrar, string AdjustKey, int Stage) global native
bool function HasAdjustments(string AdjustKey, int Stage) Native
function _PositionOffsets(string Registrar, string AdjustKey, string LastKey, int Stage, float[] RawOffsets) global native
float[] function PositionOffsets(float[] Output, string AdjustKey, int Position, int Stage, int BedTypeID = 0) Native
float[] function RawOffsets(float[] Output, int Position, int Stage) Native
function SetBedOffsets(float forward, float sideward, float upward, float rotate) Native
float[] function GetBedOffsets() Native
function _SetAdjustment(string Registrar, string AdjustKey, int Stage, int Slot, float Adjustment) global native
function SetAdjustment(string AdjustKey, int Position, int Stage, int Slot, float Adjustment) Native
float function _GetAdjustment(string Registrar, string AdjustKey, int Stage, int nth) global native
float function GetAdjustment(string AdjustKey, int Position, int Stage, int Slot) Native
float function _UpdateAdjustment(string Registrar, string AdjustKey, int Stage, int nth, float by) global native
function UpdateAdjustment(string AdjustKey, int Position, int Stage, int Slot, float AdjustBy) Native
function UpdateAdjustmentAll(string AdjustKey, int Position, int Slot, float AdjustBy) Native
function AdjustForward(string AdjustKey, int Position, int Stage, float AdjustBy, bool AdjustStage = false) Native
function AdjustSideways(string AdjustKey, int Position, int Stage, float AdjustBy, bool AdjustStage = false) Native
function AdjustUpward(string AdjustKey, int Position, int Stage, float AdjustBy, bool AdjustStage = false) Native
function AdjustSchlong(string AdjustKey, int Position, int Stage, int AdjustBy) Native
function _ClearAdjustments(string Registrar, string AdjustKey) global native
function RestoreOffsets(string AdjustKey) Native
bool function _CopyAdjustments(string Registrar, string AdjustKey, float[] Array) global native
function CopyAdjustmentsFrom(string AdjustKey, string CopyKey, int Position) Native
string function GetLastKey(int Position) Native
string function InitAdjustments(string AdjustKey, int Position) Native
float[] function GetEmptyAdjustments(int Position) Native
string[] function _GetAdjustKeys(string Registrar) global native
string[] function GetAdjustKeys() Native
string function PickKey(string AdjustKey, int Position) Native
int[] function GetPositionFlags(string AdjustKey, int Position, int Stage) Native
int[] function PositionFlags(int[] Output, string AdjustKey, int Position, int Stage) Native
bool function IsSilent(int Position, int Stage) Native
bool function UseOpenMouth(int Position, int Stage) Native
bool function UseStrapon(int Position, int Stage) Native
int function _GetSchlong(string Registrar, string AdjustKey, string LastKey, int Stage) global native
int function GetSchlong(string AdjustKey, int Position, int Stage) Native
int function GetCumID(int Position, int Stage = 1) Native
int function GetCumSource(int Position, int Stage = 1) Native
bool function IsCumSource(int SourcePosition, int TargetPosition, int Stage = 1) Native
function SetStageCumID(int Position, int Stage, int CumID, int CumSource = -1) Native
int function GetCum(int Position) Native
int function ActorCount() Native
int function StageCount() Native
int function GetGender(int Position) Native
bool function MalePosition(int Position) Native
bool function FemalePosition(int Position) Native
bool function CreaturePosition(int Position) Native
bool function MatchGender(int Gender, int Position) Native
int function FemaleCount() Native
int function MaleCount() Native
bool function IsSexual() Native
function SetContent(int contentType) Native
bool function HasActorRace(Actor ActorRef) Native
bool function HasRace(Race RaceRef) Native
function AddRace(Race RaceRef) Native
bool function HasRaceID(string RaceID) Native
bool function HasValidRaceKey(string[] RaceKeys) Native
int function CountValidRaceKey(string[] RaceKeys) Native
bool function IsPositionRace(int Position, string RaceKey) Native
bool function HasPostionRace(int Position, string[] RaceKeys) Native
string[] function GetRaceTypes() Native
function AddRaceID(string RaceID) Native
function SetRaceKey(string RaceKey) Native
function SetPositionRaceKey(int Position, string RaceKey) Native
function SetRaceIDs(string[] RaceList) Native
string[] function GetRaceIDs() Native
int function AddPosition(int Gender = 0, int AddCum = -1) Native
int function AddCreaturePosition(string RaceKey, int Gender = 2, int AddCum = -1) Native
function AddPositionStage(int Position, string AnimationEvent, float forward = 0.0, float side = 0.0, float up = 0.0, float rotate = 0.0, bool silent = false, bool openmouth = false, bool strapon = true, int sos = 0) Native
function Save(int id = -1) Native
bool function IsInterspecies() Native
float function CalcCenterAdjuster(int Stage) Native
string function GenderTag(int count, string gender) Native
string function GetGenderString(int Gender) Native
string function GetGenderTag(bool Reverse = false) Native
function Initialize() Native
string property RaceType auto hidden
Form[] property CreatureRaces hidden AutoReadonly
form[] function get() Native
bool property IsSexual hidden AutoReadonly
bool function get() Native
bool property IsCreature hidden AutoReadonly
bool function get() Native
bool property IsVaginal hidden AutoReadonly
bool function get() Native
bool property IsAnal hidden AutoReadonly
bool function get() Native
bool property IsOral hidden AutoReadonly
bool function get() Native
bool property IsDirty hidden AutoReadonly
bool function get() Native
bool property IsLoving hidden AutoReadonly
bool function get() Native
bool property IsBedOnly hidden AutoReadonly
bool function get() Native
int property StageCount hidden AutoReadonly
int function get() Native
int property PositionCount hidden AutoReadonly
int function get() Native
int[] property Genders auto hidden
int property Males hidden AutoReadonly
int function get() Native
int property Females hidden AutoReadonly
int function get() Native
int property Creatures hidden AutoReadonly
int function get() Native
int property MaleCreatures hidden AutoReadonly
int function get() Native
int property FemaleCreatures hidden AutoReadonly
int function get() Native
string function get() Native
bool function CheckByTags(int ActorCount, string[] Search, string[] Suppress, bool RequireAll) Native
int property kSilent    = 0 autoreadonly hidden
int property kOpenMouth = 1 autoreadonly hidden
int property kStrapon   = 2 autoreadonly hidden
int property kSchlong   = 3 autoreadonly hidden
int property kCumID     = 4 autoreadonly hidden
int property kCumSrc    = 5 autoreadonly hidden
int property kFlagEnd hidden AutoReadonly
int function get() Native
int[] function FlagsArray(int Position) Native
function FlagsSave(int Position, int[] Flags) Native
int property kForward  = 0 autoreadonly hidden
int property kSideways = 1 autoreadonly hidden
int property kUpward   = 2 autoreadonly hidden
int property kRotate   = 3 autoreadonly hidden
int property kOffsetEnd hidden AutoReadonly
int function get() Native
float[] function OffsetsArray(int Position) Native
function OffsetsSave(int Position, float[] Offsets) Native
function InitArrays(int Position) Native
function ExportOffsets(string Type = "BedOffset") Native
function ImportOffsets(string Type = "BedOffset") Native
function ImportOffsetsDefault(string Type = "BedOffset") Native
function ExportJSON() Native
