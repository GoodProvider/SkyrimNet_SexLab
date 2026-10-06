scriptname slaconfigscr extends ski_configbase
keyword property karmorcuirass auto
keyword property kclothingbody auto
slainternalscr property slautil auto
int[] property slaslotmaskvalues auto hidden
actor property slapuppetactor auto
actor property slanakedactor auto hidden
actor property slamostarousedactorinlocation auto hidden
int property slaarousalofmostarousedactorinloc auto
bool property iscloakeffect auto
bool property isdesirespell auto
bool property isusesos auto
bool property isextendednpcnaked auto
bool property wantspurging = false auto hidden
float property timeratehalflife auto hidden
int property sexoveruseeffect = 5 auto hidden
float property defaultexposurerate = 2.0 auto hidden
int property notificationkey = 49 auto hidden
float property cellscanfreq = 120.00 auto hidden
bool property maleanimation = false auto hidden
bool property femaleanimation = false auto hidden
bool property uselos = false auto hidden
bool property isnakedonly = true auto hidden
bool property bdisabled = false auto hidden
int function getversion() Native
function resettodefault() Native
function displayactorstatus(actor akref) Native
function displaypuppetmaster(actor akref) Native
function displaylistofwornitems(actor akref) Native
form[] function removeform(form item, form[] itemlist) Native
function initslotmaskvalues() Native
form[] function getequippedarmors(actor akref) Native
