scriptname SexLabUtil hidden
int function GetVersion() global Native
string function GetStringVer() global Native
bool function SexLabIsActive() global Native
bool function SexLabIsReady() global Native
SexLabFramework function GetAPI() global Native
sslSystemConfig function GetConfig() global Native
int function StartSex(actor[] sexActors, sslBaseAnimation[] anims, actor victim = none, ObjectReference centerOn = none, bool allowBed = true, string hook = "") global Native
sslThreadModel function NewThread(float timeout = 30.0) global Native
sslThreadController function QuickStart(actor a1, actor a2 = none, actor a3 = none, actor a4 = none, actor a5 = none, actor victim = none, string hook = "", string animationTags = "") global Native
string function ActorName(Actor ActorRef) global Native
int function GetGender(Actor ActorRef) global Native
bool function IsActorActive(Actor ActorRef) global Native
bool function IsValidActor(Actor ActorRef) global Native
bool function HasCreature(Actor ActorRef) global Native
bool function HasRace(Race RaceRef) global Native
string function MakeGenderTag(Actor[] Positions) global Native
string function GetGenderTag(int Females = 0, int Males = 0, int Creatures = 0) global Native
string function GetReverseGenderTag(int Females = 0, int Males = 0, int Creatures = 0) global Native
bool function IsActor(Form FormRef) global Native
bool function IsImportant(Actor ActorRef, bool Strict = false) global Native
int function GetPluginVersion() global native
bool function HasKeywordSub(form ObjRef, string LookFor) global native
string function RemoveSubString(string InputString, string RemoveString) global native
function PrintConsole(string output) global native
function VehicleFixMode(int mode) global native
float function FloatIfElse(bool isTrue, float returnTrue, float returnFalse = 0.0) global native
int function IntIfElse(bool isTrue, int returnTrue, int returnFalse = 0) global native
string function StringIfElse(bool isTrue, string returnTrue, string returnFalse = "") global native
Form function FormIfElse(bool isTrue, Form returnTrue, Form returnFalse = none) global native
Actor function ActorIfElse(bool isTrue, Actor returnTrue, Actor returnFalse = none) global native
ObjectReference function ObjectIfElse(bool isTrue, ObjectReference returnTrue, ObjectReference returnFalse = none) global native
ReferenceAlias function AliasIfElse(bool isTrue, ReferenceAlias returnTrue, ReferenceAlias returnFalse = none) global native
Actor[] function MakeActorArray(Actor Actor1 = none, Actor Actor2 = none, Actor Actor3 = none, Actor Actor4 = none, Actor Actor5 = none) global native
int function IntMinMaxValue(int[] searchArray, bool findHighestValue = true) global native
int function IntMinMaxIndex(int[] searchArray, bool findHighestValue = true) global native
float function FloatMinMaxValue(float[] searchArray, bool findHighestValue = true) global native
int function FloatMinMaxIndex(float[] searchArray, bool findHighestValue = true) global native
float function GetCurrentGameRealTime() global native
float function GetCurrentGameTimeHours() global Native
float function GetCurrentGameTimeMinutes() global Native
float function GetCurrentGameTimeSeconds() global Native
function Wait(float seconds) global Native
function Log(string msg, string source, string type = "NOTICE", string display = "trace", bool minimal = true) global Native
function DebugLog(string Log, string Type = "NOTICE", bool DebugMode = false) global Native
float function Timer(float Timestamp, string Log) global Native
function EnableFreeCamera(bool Enabling = true, float sucsm = 5.0) global Native
