ScriptName SNSL_JMap
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
Int function valueType(Int object, String key) global native
String function nextKey(Int object, String previousKey="", String endKey="") global native
Int function allKeys(Int object) global native
Int function count(Int object) global native
Bool function hasKey(Int object, String key) global native
function removeKey(Int object, String key) global native
function clear(Int object) global native
