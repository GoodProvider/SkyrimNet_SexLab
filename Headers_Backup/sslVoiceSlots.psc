scriptname sslVoiceSlots extends Quest
int property Slotted auto hidden
sslBaseVoice[] property Voices hidden AutoReadonly
sslBaseVoice[] function get() Native
sslSystemConfig property Config auto
Actor property PlayerRef auto
sslBaseVoice[] function FilterTaggedVoices(sslBaseVoice[] VoiceList, string[] Tags, bool HasTag = true) global Native
sslBaseVoice[] function GetAllGender(int Gender) Native
sslBaseVoice function PickGender(int Gender = 1) Native
sslBaseVoice function PickVoice(Actor ActorRef) Native
sslBaseVoice function GetByTags(string Tags, string TagsSuppressed = "", bool RequireAll = true) Native
sslBaseVoice[] function GetAllByTags(string Tags, string TagsSuppressed = "", bool RequireAll = true) Native
sslBaseVoice function PickByRaceKey(string RaceKey) Native
int function FindSaved(Actor ActorRef) Native
sslBaseVoice function GetSaved(Actor ActorRef) Native
string function GetSavedName(Actor ActorRef) Native
function SaveVoice(Actor ActorRef, sslBaseVoice Saving) Native
function ForgetVoice(Actor ActorRef) Native
bool function HasCustomVoice(Actor ActorRef) Native
sslBaseVoice[] function GetList(bool[] Valid) Native
string[] function GetNames(sslBaseVoice[] SlotList) Native
sslBaseVoice function GetBySlot(int index) Native
bool function IsRegistered(string Registrar) Native
int function FindByRegistrar(string Registrar) Native
int function FindByName(string FindName) Native
sslBaseVoice function GetByName(string FindName) Native
sslBaseVoice function GetbyRegistrar(string Registrar) Native
int function PageCount(int perpage = 125) Native
int function FindPage(string Registrar, int perpage = 125) Native
string[] function GetSlotNames(int page = 1, int perpage = 125) Native
sslBaseVoice[] function GetSlots(int page = 1, int perpage = 125) Native
string[] function GetNormalSlotNames(bool WithRandom = false) Native
int function GetCount(int flag = 0) Native
function RegisterSlots() Native
int function Register(string Registrar) Native
sslBaseVoice function RegisterVoice(string Registrar, Form CallbackForm = none, ReferenceAlias CallbackAlias = none) Native
bool function UnregisterVoice(string Registrar) Native
function Setup() Native
function Log(string msg) Native
function Setup() Native
bool function TestSlots() Native
