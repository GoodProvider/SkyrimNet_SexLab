scriptname sslBaseObject extends ReferenceAlias hidden
sslSystemConfig property Config auto hidden
int property SlotID auto hidden
string property Name auto hidden
bool property Enabled auto hidden
string property Registry auto hidden
bool property Registered hidden AutoReadonly
bool function get() Native
string[] function GetRawTags() Native
string[] function GetTags() Native
bool function HasTag(string Tag) Native
bool function AddTag(string Tag) Native
bool function RemoveTag(string Tag) Native
function AddTags(string[] TagList) Native
function SetTags(string TagList) Native
bool function ToggleTag(string Tag) Native
bool function AddTagConditional(string Tag, bool AddTag) Native
bool function CheckTags(string[] CheckTags, bool RequireAll = true, bool Suppress = false) Native
bool function ParseTags(string[] TagList, bool RequireAll = true) Native
bool function TagSearch(string[] TagList, string[] Suppress, bool RequireAll) Native
bool function HasOneTag(string[] TagList) Native
bool function HasAllTag(string[] TagList) Native
Form property Storage auto hidden
bool property Ephemeral hidden AutoReadonly
bool function get() Native
function MakeEphemeral(string Token, Form OwnerForm) Native
string function Key(string type = "") Native
function Log(string Log, string Type = "NOTICE") Native
bool property Saved hidden AutoReadonly
bool function get() Native
function Save(int id = -1) Native
function Initialize() Native
