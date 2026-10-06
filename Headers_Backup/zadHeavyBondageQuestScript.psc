scriptname zadheavybondagequestscript extends quest conditional
sexlabframework property sexlab auto
zadlibs property libs auto
message property customstrugglemsg auto
message property customstruggleimpossiblemsg auto
string[] property struggleidles auto
string[] property struggleidleshob auto
bool property islocked auto
bool property isloose auto
int property strugglecount auto
bool property menumutex auto
bool property disablestruggle auto
bool property disabledial auto conditional
armor property lastinventorydevice auto
armor property lastrendereddevice auto
message property zad_devicemsg auto
key property devicekey auto hidden
function disabledialogue() Native
function enabledialogue() Native
function disablestruggling() Native
function enablestruggling() Native
function setdevicekey(key k) Native
string[] function selectstrugglearray(actor akactor) Native
function strugglescene(actor akactor) Native
int function showdevicemenu(int msgchoice=0) Native
function devicemenuremove() Native
function devicemenupoststruggle() Native
function devicemenuendurebonds() Native
function devicemenuext(int msgchoice=0) Native
function removeheavybondage(keyword kwd) Native
