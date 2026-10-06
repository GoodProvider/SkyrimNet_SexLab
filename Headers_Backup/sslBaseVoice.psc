scriptname sslBaseVoice extends sslBaseObject
Sound property Hot auto
Sound property Mild auto
Sound property Medium auto
Topic property LipSync auto hidden
string[] property RaceKeys auto hidden
int property Gender auto hidden
bool property Male hidden AutoReadonly
bool function get() Native
bool property Female hidden AutoReadonly
bool function get() Native
bool property Creature hidden AutoReadonly
bool function get() Native
function MoveLips(Actor ActorRef, Sound SoundRef = none, float Strength = 1.0) global Native
function MoveLipsEx(Actor ActorRef, Sound SoundRef = none, float Strength = 1.0, int SoundCut = 0, float MoveTime = 0.2, int Phoneme = 1, int MinValue = 20, int MaxValue = 50, bool IsFixedValue = false, bool UseMFG = false) global Native
function PlayMoan(Actor ActorRef, int Strength = 30, bool IsVictim = false, bool UseLipSync = false) Native
function PlayMoanEx(Actor ActorRef, int Strength = 30, bool IsVictim = false, bool UseLipSync = false, int SoundCut = 0, float MoveTime = 0.2, int Phoneme = 1, int MinValue = 20, int MaxValue = 50, bool IsFixedValue = false, bool UseMFG = false) Native
function Moan(Actor ActorRef, int Strength = 30, bool IsVictim = false) Native
function MoanNoWait(Actor ActorRef, int Strength = 30, bool IsVictim = false, float Volume = 1.0) Native
Sound function GetSound(int Strength, bool IsVictim = false) Native
function LipSync(Actor ActorRef, int Strength, bool ForceUse = false) Native
function TransitUp(Actor ActorRef, int from, int to) global Native
function TransitDown(Actor ActorRef, int from, int to) global Native
bool function CheckGender(int CheckGender) Native
function SetRaceKeys(string RaceList) Native
function AddRaceKey(string RaceKey) Native
bool function HasRaceKey(string RaceKey) Native
bool function HasRaceKeyMatch(string[] RaceList) Native
function Save(int id = -1) Native
function Initialize() Native
