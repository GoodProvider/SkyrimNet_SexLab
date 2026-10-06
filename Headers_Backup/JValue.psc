ScriptName JValue
function enableAPILog(Bool arg0) global native
Int function retain(Int object, String tag="") global native
Int function release(Int object) global native
Int function releaseAndRetain(Int previousObject, Int newObject, String tag="") global native
function releaseObjectsWithTag(String tag) global native
Int function zeroLifetime(Int object) global native
Int function addToPool(Int object, String poolName) global native
function cleanPool(String poolName) global native
Int function shallowCopy(Int object) global native
Int function deepCopy(Int object) global native
Bool function isExists(Int object) global native
Bool function isArray(Int object) global native
Bool function isMap(Int object) global native
Bool function isFormMap(Int object) global native
Bool function isIntegerMap(Int object) global native
Bool function empty(Int object) global native
Int function count(Int object) global native
function clear(Int object) global native
Int function readFromFile(String filePath) global native
Int function readFromDirectory(String directoryPath, String extension="") global native
Int function objectFromPrototype(String prototype) global native
function writeToFile(Int object, String filePath) global native
String function toJsonString(Int object) global native
Int function solvedValueType(Int object, String path) global native
Bool function hasPath(Int object, String path) global native
Float function solveFlt(Int object, String path, Float default=0.0) global native
Int function solveInt(Int object, String path, Int default=0) global native
String function solveStr(Int object, String path, String default="") global native
Int function solveObj(Int object, String path, Int default=0) global native
Form function solveForm(Int object, String path, Form default=None) global native
Bool function solveFltSetter(Int object, String path, Float value, Bool createMissingKeys=false) global native
Bool function solveIntSetter(Int object, String path, Int value, Bool createMissingKeys=false) global native
Bool function solveStrSetter(Int object, String path, String value, Bool createMissingKeys=false) global native
Bool function solveObjSetter(Int object, String path, Int value, Bool createMissingKeys=false) global native
Bool function solveFormSetter(Int object, String path, Form value, Bool createMissingKeys=false) global native
Float function evalLuaFlt(Int object, String luaCode, Float default=0.0) global native
Int function evalLuaInt(Int object, String luaCode, Int default=0) global native
String function evalLuaStr(Int object, String luaCode, String default="") global native
Int function evalLuaObj(Int object, String luaCode, Int default=0) global native
Form function evalLuaForm(Int object, String luaCode, Form default=None) global native
