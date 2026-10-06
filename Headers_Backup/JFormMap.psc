ScriptName JFormMap
Int function object() global native
Int function getInt(Int object, Form key, Int default=0) global native
Float function getFlt(Int object, Form key, Float default=0.0) global native
String function getStr(Int object, Form key, String default="") global native
Int function getObj(Int object, Form key, Int default=0) global native
Form function getForm(Int object, Form key, Form default=None) global native
function setInt(Int object, Form key, Int value) global native
function setFlt(Int object, Form key, Float value) global native
function setStr(Int object, Form key, String value) global native
function setObj(Int object, Form key, Int container) global native
function setForm(Int object, Form key, Form value) global native
Int function insertInt(Int object, Form key, Int value) global native
Float function insertFlt(Int object, Form key, Float value) global native
String function insertStr(Int object, Form key, String value) global native
Int function insertObj(Int object, Form key, Int container) global native
Form function insertForm(Int object, Form key, Form value) global native
Bool function hasKey(Int object, Form key) global native
Int function valueType(Int object, Form key) global native
Int function allKeys(Int object) global native
Form[] function allKeysPArray(Int object) global native
Int function allValues(Int object) global native
Bool function removeKey(Int object, Form key) global native
Int function count(Int object) global native
function clear(Int object) global native
function addPairs(Int object, Int source, Bool overrideDuplicates) global native
Form function nextKey(Int object, Form previousKey=None, Form endKey=None) global native
Form function getNthKey(Int object, Int keyIndex) global native
