scriptname sslExpressionSlots extends Quest
int property Slotted auto hidden
sslBaseExpression[] property Expressions hidden AutoReadonly
sslBaseExpression[] function get() Native
sslSystemConfig property Config auto
Actor property PlayerRef auto
sslBaseExpression function PickExpression(Actor ActorRef, Actor VictimRef = none) Native
sslBaseExpression function PickByStatus(Actor ActorRef, bool IsVictim = false, bool IsAggressor = false) Native
sslBaseExpression[] function GetByStatus(Actor ActorRef, bool IsVictim = false, bool IsAggressor = false) Native
sslBaseExpression function RandomByTag(string Tag, bool ForFemale = true) Native
sslBaseExpression[] function GetByTag(string Tag, bool ForFemale = true) Native
sslBaseExpression function SelectRandom(bool[] Valid) Native
sslBaseExpression[] function GetList(bool[] Valid) Native
string[] function GetNames(sslBaseExpression[] SlotList) Native
sslBaseExpression function GetBySlot(int index) Native
bool function IsRegistered(string Registrar) Native
int function FindByRegistrar(string Registrar) Native
int function FindByName(string FindName) Native
sslBaseExpression function GetByName(string FindName) Native
sslBaseExpression function GetbyRegistrar(string Registrar) Native
int function PageCount(int perpage = 125) Native
int function FindPage(string Registrar, int perpage = 125) Native
string[] function GetSlotNames(int page = 1, int perpage = 125) Native
sslBaseExpression[] function GetSlots(int page = 1, int perpage = 125) Native
function RegisterSlots() Native
int function Register(string Registrar) Native
sslBaseExpression function RegisterExpression(string Registrar, Form CallbackForm = none, ReferenceAlias CallbackAlias = none) Native
bool function UnregisterExpression(string Registrar) Native
function Setup() Native
function Log(string msg) Native
function Setup() Native
bool function TestSlots() Native
