scriptname sslThreadSlots extends Quest
sslSystemConfig property Config auto
SexLabFramework property SexLab auto hidden
sslThreadController[] property Threads hidden AutoReadonly
sslThreadController[] function get() Native
sslThreadModel function PickModel(float TimeOut = 30.0) Native
sslThreadController function GetController(int tid) Native
int function FindActorController(Actor ActorRef) Native
sslThreadController function GetActorController(Actor ActorRef) Native
bool function IsRunning() Native
int function ActiveThreads() Native
function StopThread(sslThreadController Slot) Native
function StopAll() Native
function Setup() Native
bool function TestSlots() Native
function Setup() Native
function Log(string msg) Native
