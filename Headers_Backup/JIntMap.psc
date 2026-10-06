ScriptName JIntMap
Int function object() global native
Int function getInt(Int object, Int key, Int default=0) global native
Float function getFlt(Int object, Int key, Float default=0.0) global native
String function getStr(Int object, Int key, String default="") global native
Int function getObj(Int object, Int key, Int default=0) global native
Form function getForm(Int object, Int key, Form default=None) global native
function setInt(Int object, Int key, Int value) global native
function setFlt(Int object, Int key, Float value) global native
function setStr(Int object, Int key, String value) global native
function setObj(Int object, Int key, Int container) global native
function setForm(Int object, Int key, Form value) global native
Int function insertInt(Int object, Int key, Int value) global native
Float function insertFlt(Int object, Int key, Float value) global native
String function insertStr(Int object, Int key, String value) global native
Int function insertObj(Int object, Int key, Int container) global native
Form function insertForm(Int object, Int key, Form value) global native
Bool function hasKey(Int object, Int key) global native
Int function valueType(Int object, Int key) global native
Int function allKeys(Int object) global native
Int[] function allKeysPArray(Int object) global native
Int function allValues(Int object) global native
Bool function removeKey(Int object, Int key) global native
Int function count(Int object) global native
function clear(Int object) global native
function addPairs(Int object, Int source, Bool overrideDuplicates) global native
Int function nextKey(Int object, Int previousKey=0, Int endKey=0) global native
Int function getNthKey(Int object, Int keyIndex) global native
