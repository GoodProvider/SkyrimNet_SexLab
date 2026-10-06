ScriptName SNSL_JValue
Int function retain(Int object, String tag="") global native
Int function release(Int object) global native
Int function releaseAndRetain(Int previousObject, Int newObject, String tag="") global native
Bool function isExists(Int object) global native
Bool function isArray(Int object) global native
Bool function isMap(Int object) global native
Bool function isFormMap(Int object) global native
Bool function isIntegerMap(Int object) global native
Int function count(Int object) global native
Int function objectFromPrototype(String prototype) global native
Int function readFromFile(String filePath) global native
function writeToFile(Int object, String filePath) global native
String function dump(Int object) global native
String function stats() global native
