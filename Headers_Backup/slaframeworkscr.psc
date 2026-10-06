scriptname slaframeworkscr extends quest
actor property playerref auto
slamainscr property slamain auto
slaconfigscr property slaconfig auto
formlist property slaarousedvoicelist auto
formlist property slaunarousedvoicelist auto
faction property slaarousal auto
faction property slaarousalblocked auto
faction property slaarousallocked auto
faction property slaexposure auto
faction property slaexhibitionist auto
faction property slagenderpreference auto
faction property slatimerate auto
faction property slaexposurerate auto
globalvariable property sla_nextmaintenance  auto
int property slaarousalcap = 100 autoreadonly
sexlabframework property sexlab auto
int function getversion() Native
int function getgenderpreference(actor akref, bool forconfig = false) Native
function setgenderpreference(actor akref, int gender) Native
bool function isactorexhibitionist(actor akref) Native
function setactorexhibitionist(actor akref, bool val = false) Native
float function getactortimerate(actor akref) Native
float function setactortimerate(actor akref, float val) Native
float function updateactortimerate(actor akref, float val) Native
float function getactorexposurerate(actor akref) Native
float function setactorexposurerate(actor akref, float val) Native
float function updateactorexposurerate(actor akref, float val) Native
int function getactorexposure(actor akref) Native
int function setactorexposure(actor akref, int val) Native
int function updateactorexposure(actor akref, int val, string debugmsg = "") Native
float function getactordayssincelastorgasm(actor akref) Native
function updateactororgasmdate(actor akref) Native
bool function isactorarousallocked(actor akref) Native
function setactorarousallocked(actor akref, bool val) Native
bool function isactorarousalblocked(actor akref) Native
function setactorarousalblocked(actor akref, bool val) Native
int function getactorarousal(actor akref) Native
actor function getmostarousedactorinlocation() Native
function updatesosposition(actor akref, int akarousal) Native
function handleerection(actor akref, int position) Native
int function getactorhourssincelastsex(actor akref) Native
float function getactordayssincelastsex(actor akref) Native
