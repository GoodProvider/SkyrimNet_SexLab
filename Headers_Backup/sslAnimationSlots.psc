scriptname sslAnimationSlots extends Quest
int property Slotted auto hidden
sslBaseAnimation[] property Animations hidden AutoReadonly
sslBaseAnimation[] function get() Native
Actor property PlayerRef auto
sslSystemConfig property Config auto
sslActorLibrary property ActorLib auto
sslThreadLibrary property ThreadLib auto
sslBaseAnimation[] function GetByTags(int ActorCount, string Tags, string TagsSuppressed = "", bool RequireAll = true) Native
sslBaseAnimation[] function GetByCommonTags(int ActorCount, string CommonTags, string Tags, string TagsSuppressed = "", bool RequireAll = true) Native
sslBaseAnimation[] function GetByType(int ActorCount, int Males = -1, int Females = -1, int StageCount = -1, bool Aggressive = false, bool Sexual = true) Native
sslBaseAnimation[] function PickByActors(Actor[] Positions, int Limit = 64, bool Aggressive = false) Native
sslBaseAnimation[] function GetByDefault(int Males, int Females, bool IsAggressive = false, bool UsingBed = false, bool RestrictAggressive = true) Native
sslBaseAnimation[] function GetByDefaultTags(int Males, int Females, bool IsAggressive = false, bool UsingBed = false, bool RestrictAggressive = true, string Tags, string TagsSuppressed = "", bool RequireAll = true) Native
sslBaseAnimation function GetBySlot(int index) Native
sslBaseAnimation function GetByName(string FindName) Native
sslBaseAnimation function GetbyRegistrar(string Registrar) Native
int function FindByRegistrar(string Registrar) Native
int function FindByName(string FindName) Native
bool function IsRegistered(string Registrar) Native
sslBaseAnimation[] function GetList(bool[] Valid) Native
string[] function GetNames(sslBaseAnimation[] SlotList) Native
int function CountTag(sslBaseAnimation[] Anims, string Tags) Native
int function GetCount(bool IgnoreDisabled = true) Native
int function FindFirstTagged(string Tags, bool IgnoreDisabled = true, bool Reverse = false) Native
int function CountTagUsage(string Tags, bool IgnoreDisabled = true) Native
string[] function GetAllTags(int ActorCount = -1, bool IgnoreDisabled = true) Native
function ClearAnimCache() Native
bool function ValidateCache() Native
bool function IsCached(string CacheName) Native
sslBaseAnimation[] function CheckCache(string CacheName) Native
function CacheAnims(string CacheName, sslBaseAnimation[] Anims) Native
sslBaseAnimation[] function GetCacheSlot(int i) Native
int function OldestCache() Native
function InvalidateByAnimation(sslBaseAnimation removing) Native
function InvalidateByTags(string Tags) Native
function InvalidateBySlot(int i) Native
string function CacheInfo(int i) Native
function OutputCacheLog() Native
int function PageCount(int perpage = 125) Native
int function FindPage(string Registrar, int perpage = 125) Native
string[] function GetSlotNames(int page = 1, int perpage = 125) Native
sslBaseAnimation[] function GetSlots(int page = 1, int perpage = 125) Native
function RegisterSlots() Native
int function Register(string Registrar) Native
sslBaseAnimation function RegisterAnimation(string Registrar, Form CallbackForm = none, ReferenceAlias CallbackAlias = none) Native
bool function UnregisterAnimation(string Registrar) Native
bool function IsSuppressed(string Registrar) Native
function NeverRegister(string Registrar) Native
function AllowRegister(string Registrar) Native
int function ClearSuppressed() Native
int function GetDisabledCount() Native
int function GetSuppressedCount() Native
int function SuppressDisabled() Native
string[] function GetSuppressedList() Native
function PreloadCategoryLoaders() Native
string property JLoaders auto hidden
function Setup() Native
string property CacheID auto hidden
string[] function GetTagCache(bool IgnoreCache = false) Native
bool function HasTagCache(string Tag ,bool IgnoreCache = false) Native
function ClearTagCache() Native
function DoCache() Native
function Log(string msg) Native
function Setup() Native
bool function TestSlots() Native
sslBaseAnimation[] function RemoveTagged(sslBaseAnimation[] Anims, string Tags) Native
sslBaseAnimation[] function MergeLists(sslBaseAnimation[] List1, sslBaseAnimation[] List2) Native
bool[] function FindTagged(sslBaseAnimation[] Anims, string Tags) Native
