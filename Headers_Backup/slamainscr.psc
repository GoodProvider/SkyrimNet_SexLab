scriptname slamainscr extends quest
slainternalscr property slautil auto
slaconfigscr property slaconfig auto
spell property slacloakspell auto
spell property sladesirespell auto
globalvariable property slanexttimeplayernaked auto
quest property slascanall auto
quest property slanakednpc auto
keyword property armorcuirass auto
keyword property clothingbody auto
faction property slanaked auto
globalvariable property sla_nextmaintenance  auto
globalvariable property sla_animatefemales auto
globalvariable property sla_animatemales auto
globalvariable property sla_animationthreshhold auto
globalvariable property sla_uselineofsight auto
formlist property sla_nakedarmorlist auto
float property updatefrequency = 120.00 auto hidden
sexlabframework property sexlab auto
actor property playerref auto
globalvariable property gamedayspassed auto
int[] property actortypes auto hidden
int function isanimatingfemales() Native
function setisanimatingfemales(int newvalue) Native
int function isanimatingmales() Native
function setisanimatingmales(int newvalue) Native
int function getanimationthreshold() Native
function setanimationthreshold(int newvalue) Native
int function getuselos() Native
int function getnakedonly() Native
function setnakedonly(int newvalue) Native
int function getdisabled() Native
function setdisabled(int newvalue) Native
function setuselos(int newvalue) Native
function setupdatefrequency(float newfreq) Native
function setcleaningtime() Native
function maintenance() Native
function startcleaning() Native
bool function issexlabactive() Native
int function getallactors(int locknum) Native
int function lockscan(int locknum) Native
bool function unlockscan(int locknum) Native
bool function checkforlock(int locknum) Native
function checkforlocks() Native
function updatenakedarousal(actor akref, actor aknaked) Native
bool function isactornaked(actor akref) Native
bool function isactornakedvanilla(actor akref) Native
bool function isactornakedextended(actor akref) Native
form[] function getequippedarmors(actor akref) Native
function updatecloakeffect() Native
int function getversion() Native
function updatekeyregistery() Native
function setversion(int  newversion) Native
function updatedesirespell() Native
function startpcmasturbation() Native
function arousenpcswithinradius(actor akcenter, float radius) Native
float function getanimationduration(sslthreadcontroller bthread) Native
function onplayerarousalupdate(int arousal) Native
function cleanactorstorage() Native
bool function isactor(form formref) Native
bool function isimportant(actor actorref) Native
function clearfromactorstorage(form formref) Native
