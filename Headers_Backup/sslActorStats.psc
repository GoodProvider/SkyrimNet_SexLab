scriptname sslActorStats extends sslSystemLibrary
int function FindStat(string Stat) Native
int function RegisterStat(string Stat, string Value, string Prepend = "", string Append = "") Native
int function GetNumStats() Native
string function GetNthStat(int i) Native
function Alter(string Name, string NewName = "", string Value = "", string Prepend = "", string Append = "") Native
bool function ClearStat(Actor ActorRef, string Stat) Native
function SetStat(Actor ActorRef, string Stat, string Value) Native
int function AdjustBy(Actor ActorRef, string Stat, int Adjust) Native
bool function HasStat(Actor ActorRef, string Stat) Native
string function GetStat(Actor ActorRef, string Stat) Native
string function GetStatString(Actor ActorRef, string Stat) Native
float function GetStatFloat(Actor ActorRef, string Stat) Native
int function GetStatInt(Actor ActorRef, string Stat) Native
int function GetStatLevel(Actor ActorRef, string Stat, float Curve = 0.85) Native
string function GetStatTitle(Actor ActorRef, string Stat, float Curve = 0.85) Native
string function GetStatDefault(string Stat) Native
string function GetStatPrepend(string Stat) Native
string function GetStatAppend(string Stat) Native
string function GetStatFull(Actor ActorRef, string Stat) Native
int function CalcSexuality(bool IsFemale, int Males, int Females) Native
float function CalcLevelFloat(float Total, float Curve = 0.85) Native
int function CalcLevel(float Total, float Curve = 0.85) Native
string function ZeroFill(string num) Native
string function ParseTime(int time) Native
bool function IsSkilled(Actor ActorRef) global native
function _SeedActor(Actor ActorRef, float RealTime, float GameTime) global native
function SeedActor(Actor ActorRef) Native
float function _GetSkill(Actor ActorRef, int Stat) global native
int function GetSkill(Actor ActorRef, string Skill) Native
float function GetSkillFloat(Actor ActorRef, string Skill) Native
function _SetSkill(Actor ActorRef, int Stat, float Value) global native
function SetSkill(Actor ActorRef, string Skill, int Amount) Native
function SetSkillFloat(Actor ActorRef, string Skill, float Amount) Native
float function _AdjustSkill(Actor ActorRef, int Stat, float By) global native
function AdjustSkill(Actor ActorRef, string Skill, int Amount) Native
function AdjustSkillFloat(Actor ActorRef, string Skill, float Amount) Native
int function GetSkillLevel(Actor ActorRef, string Skill, float Curve = 0.85) Native
string function GetSkillTitle(Actor ActorRef, string Skill, float Curve = 0.85) Native
string function GetTitle(int Level) Native
float[] function GetSkills(Actor ActorRef) global native
float[] function GetSkillLevels(Actor ActorRef) Native
function AddSkillXP(Actor ActorRef, float Foreplay = 0.0, float Vaginal = 0.0, float Anal = 0.0, float Oral = 0.0) Native
int function GetPure(Actor ActorRef) Native
int function GetPureLevel(Actor ActorRef) Native
string function GetPureTitle(Actor ActorRef) Native
int function GetLewd(Actor ActorRef) Native
int function GetLewdLevel(Actor ActorRef) Native
string function GetLewdTitle(Actor ActorRef) Native
bool function IsPure(Actor ActorRef) Native
bool function IsLewd(Actor ActorRef) Native
float function GetPurity(Actor ActorRef) Native
float function AdjustPurity(Actor ActorRef, float Adjust) Native
string function GetPurityTitle(Actor ActorRef) Native
int function GetPurityLevel(Actor ActorRef) Native
function AddPurityXP(Actor ActorRef, float Pure, float Lewd, bool IsAggressive, bool IsVictim, bool WithCreature, int ActorCount, int HadRelation) Native
function AddSex(Actor ActorRef, float TimeSpent = 0.0, bool WithPlayer = false, bool IsAggressive = false, int Males = 0, int Females = 0, int Creatures = 0) Native
int function SexCount(Actor ActorRef) Native
bool function HadSex(Actor ActorRef) Native
int function PlayerSexCount(Actor ActorRef) Native
bool function HadPlayerSex(Actor ActorRef) Native
Actor function LastSexPartner(Actor ActorRef) Native
bool function HasHadSexTogether(Actor ActorRef1, Actor ActorRef2) Native
Actor function LastAggressor(Actor ActorRef) Native
bool function WasVictimOf(Actor VictimRef, Actor AggressorRef) Native
Actor function LastVictim(Actor ActorRef) Native
bool function WasAggressorTo(Actor AggressorRef, Actor VictimRef) Native
Form[] function CleanActorList(Actor ActorRef, string List) Native
Actor function LastActorInList(Actor ActorRef, string List) Native
Actor function MostUsedPlayerSexPartner() Native
Actor function MostUsedPlayerSexPartner2() Native
Actor[] function MostUsedPlayerSexPartners(int MaxActors = 5) Native
function AdjustSexuality(Actor ActorRef, int Males, int Females) Native
int function GetSexuality(Actor ActorRef) Native
string function GetSexualityTitle(Actor ActorRef) Native
bool function IsStraight(Actor ActorRef) Native
bool function IsBisexual(Actor ActorRef) Native
bool function IsGay(Actor ActorRef) Native
float function LastSexGameTime(Actor ActorRef) Native
float function DaysSinceLastSex(Actor ActorRef) Native
float function HoursSinceLastSex(Actor ActorRef) Native
float function MinutesSinceLastSex(Actor ActorRef) Native
float function SecondsSinceLastSex(Actor ActorRef) Native
string function LastSexTimerString(Actor ActorRef) Native
float function LastSexRealTime(Actor ActorRef) Native
float function SecondsSinceLastSexRealTime(Actor ActorRef) Native
float function MinutesSinceLastSexRealTime(Actor ActorRef) Native
float function HoursSinceLastSexRealTime(Actor ActorRef) Native
float function DaysSinceLastSexRealTime(Actor ActorRef) Native
string function LastSexTimerStringRealTime(Actor ActorRef) Native
int function GetHighestRelationshipRankInList(Actor ActorRef, Actor[] ActorList) global Native
function RecordThread(Actor ActorRef, int Gender, int HadRelation, float StartedAt, float RealTime, float GameTime, bool WithPlayer, Actor VictimRef, int[] Genders, float[] SkillXP) global native
function AddPartners(Actor ActorRef, Actor[] AllPositions, Actor[] Victims) Native
function TrimList(Actor ActorRef, string List, int count) Native
function _ResetStats(Actor ActorRef) global native
function ResetStats(Actor ActorRef) Native
function EmptyStats(Actor ActorRef) Native
Actor[] function GetAllSkilledActors() global native
function ClearNPCSexSkills() Native
function Setup() Native
function ClearCustomStats(Form FormRef) Native
function UpgradeLegacyStats(Form FormRef, bool IsImportant) Native
function ClearLegacyStats(Form FormRef) Native
int function GetGender(Actor ActorRef) Native
int function StatID(string Name) Native
int property kForeplay hidden AutoReadonly
int function get() Native
int property kVaginal hidden AutoReadonly
int function get() Native
int property kAnal hidden AutoReadonly
int function get() Native
int property kOral hidden AutoReadonly
int function get() Native
int property kPure hidden AutoReadonly
int function get() Native
int property kLewd hidden AutoReadonly
int function get() Native
int property kMales hidden AutoReadonly
int function get() Native
int property kFemales hidden AutoReadonly
int function get() Native
int property kCreatures hidden AutoReadonly
int function get() Native
int property kMasturbation hidden AutoReadonly
int function get() Native
int property kAggressor hidden AutoReadonly
int function get() Native
int property kVictim hidden AutoReadonly
int function get() Native
int property kSexCount hidden AutoReadonly
int function get() Native
int property kPlayerSex hidden AutoReadonly
int function get() Native
int property kSexuality hidden AutoReadonly
int function get() Native
int property kTimeSpent hidden AutoReadonly
int function get() Native
int property kLastRealTime hidden AutoReadonly
int function get() Native
int property kLastGameTime hidden AutoReadonly
int function get() Native
int property kVaginalCount hidden AutoReadonly
int function get() Native
int property kAnalCount hidden AutoReadonly
int function get() Native
int property kOralCount hidden AutoReadonly
int function get() Native
int property kStatCount hidden AutoReadonly
int function get() Native
string function PrintSkills(Actor ActorRef) Native
int function get() Native
int property kArousalModifier hidden AutoReadonly
int function get() Native
bool function HasInt(Actor ActorRef, string Stat) Native
bool function HasFloat(Actor ActorRef, string Stat) Native
bool function HasStr(Actor ActorRef, string Stat) Native
int function GetInt(Actor ActorRef, string Stat) Native
float function GetFloat(Actor ActorRef, string Stat) Native
string function GetStr(Actor ActorRef, string Stat) Native
function SetInt(Actor ActorRef, string Stat, int Value) Native
function SetFloat(Actor ActorRef, string Stat, float Value) Native
function SetStr(Actor ActorRef, string Stat, string Value) Native
function ClearInt(Actor ActorRef, string Stat) Native
function ClearFloat(Actor ActorRef, string Stat) Native
function ClearStr(Actor ActorRef, string Stat) Native
function AdjustInt(Actor ActorRef, string Stat, int Amount) Native
function AdjustFloat(Actor ActorRef, string Stat, float Amount) Native
function Tester() Native
function Tester() Native
