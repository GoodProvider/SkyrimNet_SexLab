scriptname sslBaseExpression extends sslBaseObject
int property Male       = 0 autoreadonly
int property Female     = 1 autoreadonly
int property MaleFemale = -1 autoreadonly
int property Phoneme  = 0 autoreadonly
int property Modifier = 16 autoreadonly
int property Mood     = 30 autoreadonly
int property PhonemeIDs  = 15 autoreadonly
int property ModifierIDs = 13 autoreadonly
int property MoodIDs     = 16 autoreadonly
string property File hidden AutoReadonly
string function get() Native
int[] property PhaseCounts hidden AutoReadonly
int[] function get() Native
int property PhasesMale hidden AutoReadonly
int function get() Native
int property PhasesFemale hidden AutoReadonly
int function get() Native
function Apply(Actor ActorRef, int Strength, int Gender) Native
function ApplyPhase(Actor ActorRef, int Phase, int Gender) Native
int function PickPhase(int Strength, int Gender) Native
float[] function SelectPhase(int Strength, int Gender) Native
float function GetModifier(Actor ActorRef, int id) global native
float function GetPhoneme(Actor ActorRef, int id) global native
float function GetExpression(Actor ActorRef, bool getId) global native
function ClearPhoneme(Actor ActorRef) global Native
function ClearModifier(Actor ActorRef) global Native
function OpenMouth(Actor ActorRef) global Native
function CloseMouth(Actor ActorRef) global Native
bool function IsMouthOpen(Actor ActorRef) global Native
function ClearMFG(Actor ActorRef) global Native
function TransitPresetFloats(Actor ActorRef, float[] FromPreset, float[] ToPreset, float Speed = 1.0, float Time = 1.0) global Native
function ApplyPresetFloats(Actor ActorRef, float[] Preset) global Native
float[] function GetCurrentMFG(Actor ActorRef) global Native
function SetIndex(int Phase, int Gender, int Mode, int id, int value) Native
function SetPreset(int Phase, int Gender, int Mode, int id, int value) Native
function SetMood(int Phase, int Gender, int id, int value) Native
function SetModifier(int Phase, int Gender, int id, int value) Native
function SetPhoneme(int Phase, int Gender, int id, int value) Native
function EmptyPhase(int Phase, int Gender) Native
function AddPhase(int Phase, int Gender) Native
bool function HasPhase(int Phase, Actor ActorRef) Native
float[] function GenderPhase(int Phase, int Gender) Native
function SetPhase(int Phase, int Gender, float[] Preset) Native
float[] function GetPhonemes(int Phase, int Gender) Native
float[] function GetModifiers(int Phase, int Gender) Native
int function GetMoodType(int Phase, int Gender) Native
int function GetMoodAmount(int Phase, int Gender) Native
int function GetIndex(int Phase, int Gender, int Mode, int id) Native
int function ValidatePreset(float[] Preset) Native
int[] function ToIntArray(float[] FloatArray) global Native
float[] function ToFloatArray(int[] IntArray) global Native
function CountPhases() Native
function Save(int id = -1) Native
function Initialize() Native
bool function ExportJson() Native
bool function ImportJson() Native
function ApplyTo(Actor ActorRef, int Strength = 50, bool IsFemale = true, bool OpenMouth = false) Native
int[] function GetPhase(int Phase, int Gender) Native
int[] function PickPreset(int Strength, bool IsFemale) Native
int function CalcPhase(int Strength, bool IsFemale) Native
function ApplyPreset(Actor ActorRef, int[] Preset) global Native
