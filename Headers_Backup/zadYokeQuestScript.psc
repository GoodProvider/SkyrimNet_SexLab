scriptname zadyokequestscript extends zadheavybondagequestscript conditional
scene property postrapescene auto
zaddreliableforcegreet property fg auto
referencealias property yokerescuer auto
miscobject property itemgold auto
message property zad_yokeremovelockedmsg auto
message property zad_yokeremoveunlockedmsg auto
message property zad_yokeremoveunlockedfailmsg auto
message property zad_yokeremoveloosemsg auto
message property zad_yokeremoveloosefailmsg auto
message property zad_yokestrugglemsg auto
message property zad_yokestruggleloosemsg auto
message property zad_yokestrugglekeymsg auto
message property zad_yokestrugglekeyloosemsg auto
message property zad_yokeimpossiblestrugglemsg auto
perk property merchantcurse auto
spell property merchantcursespell auto
int property merchantcursegoldthreshold = 0 auto
int property merchantcursegoldowed  = 0 auto
int property merchantcursegoldstolen auto
bool property smithescapedialogueenabled = true auto conditional
function updateblacksmithremoval(bool enabledisable=true) Native
bool function attemptremoveyoke() Native
function dostruggle() Native
function devicemenuremove() Native
key function getkey() Native
function devicemenupoststruggle() Native
function devicemenuendurebonds() Native
function devicemenuext(int msgchoice=0) Native
function sexscene(objectreference akspeaker, bool aggressive) Native
function consensualsex(objectreference akspeaker) Native
function rapesex(objectreference akspeaker) Native
function postrape(objectreference akspeaker) Native
function blacksmithremoveheavybondage(objectreference akspeaker) Native
