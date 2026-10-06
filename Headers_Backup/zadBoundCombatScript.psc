scriptname zadboundcombatscript extends quest hidden
zadlibs property libs auto
zadconfig property config auto
package property npcboundcombatpackage auto
package property npcboundcombatpackagesandbox auto
spell property armbinderdebuff auto
formlist property zad_list_bcperks auto
function updatevalues() Native
function config_abc() Native
function maintenance_abc() Native
bool function hascompatibledevice(actor akactor) Native
int function getprimaryaastate(actor akactor) Native
int function getsecondaryaastate(actor akactor) Native
int function selectanimationset(actor akactor) Native
function evaluateaa(actor akactor) Native
function clearaa(actor akactor) Native
function resetexternalaa(actor akactor) Native
function applybcperks(actor akactor) Native
function removebcperks(actor akactor) Native
function apply_npc_abc(actor akactor) Native
function remove_npc_abc(actor akactor) Native
function cleanupnpcs() Native
function apply_abc(actor akactor) Native
function remove_abc(actor akactor) Native
function apply_hbc(actor akactor) Native
function remove_hbc(actor akactor) Native
