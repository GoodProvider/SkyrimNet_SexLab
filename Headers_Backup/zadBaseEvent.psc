scriptname zadbaseevent extends referencealias
zadlibs property libs auto
bool property process = false auto hidden
int property probability = -1 auto hidden
string property name auto
string property help = "" auto
int property defaultprobability auto
bool function filter(actor akactor, int chancemod = 0) Native
bool function haskeywords(actor akactor) Native
function execute(actor akactor) Native
function eval(actor akactor) Native
function registerdeviceeffect() Native
