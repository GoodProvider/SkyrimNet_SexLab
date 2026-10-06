ScriptName JMap
Int function object() global native
Int function getInt(Int object, String key, Int default=0) global native
Float function getFlt(Int object, String key, Float default=0.0) global native
String function getStr(Int object, String key, String default="") global native
Int function getObj(Int object, String key, Int default=0) global native
Form function getForm(Int object, String key, Form default=None) global native
function setInt(Int object, String key, Int value) global native
function setFlt(Int object, String key, Float value) global native
function setStr(Int object, String key, String value) global native
function setObj(Int object, String key, Int container) global native
function setForm(Int object, String key, Form value) global native
Int function insertInt(Int object, String key, Int value) global native
Float function insertFlt(Int object, String key, Float value) global native
String function insertStr(Int object, String key, String value) global native
Int function insertObj(Int object, String key, Int container) global native
Form function insertForm(Int object, String key, Form value) global native
Bool function hasKey(Int object, String key) global native
Int function valueType(Int object, String key) global native
Int function allKeys(Int object) global native
String[] function allKeysPArray(Int object) global native
Int function allValues(Int object) global native
Bool function removeKey(Int object, String key) global native
Int function count(Int object) global native
function clear(Int object) global native
function addPairs(Int object, Int source, Bool overrideDuplicates) global native
String function nextKey(Int object, String previousKey="", String endKey="") global native
String function getNthKey(Int object, Int keyIndex) global native
