scriptname zadeventslots extends quest
zadlibs property libs auto
string[] property registry auto
zadbaseevent[] property slots auto
int property slotted auto
int property processnum = 0 auto
int function register(string name, zadbaseevent theevent) Native
zadbaseevent function getbyname(string name) Native
function initialize() Native
function reset() Native
function loaddefaults() Native
function updateprocessnum() Native
function checkallevents() Native
bool function processoneevent(actor akactor) Native
function doregister() Native
bool function processevents(actor akactor) Native
function updateglobalevent() Native
function maintenance() Native
