ScriptName SNSL_JArray
Int function object() global native
Int function objectWithSize(Int size) global native
Int function getInt(Int object, Int index, Int default=0) global native
Float function getFlt(Int object, Int index, Float default=0.0) global native
String function getStr(Int object, Int index, String default="") global native
Int function getObj(Int object, Int index, Int default=0) global native
Form function getForm(Int object, Int index, Form default=None) global native
function setInt(Int object, Int index, Int value) global native
function setFlt(Int object, Int index, Float value) global native
function setStr(Int object, Int index, String value) global native
function setObj(Int object, Int index, Int container) global native
function setForm(Int object, Int index, Form value) global native
function addInt(Int object, Int value, Int addToIndex=-1) global native
function addFlt(Int object, Float value, Int addToIndex=-1) global native
function addStr(Int object, String value, Int addToIndex=-1) global native
function addObj(Int object, Int container, Int addToIndex=-1) global native
function addForm(Int object, Form value, Int addToIndex=-1) global native
Int function count(Int object) global native
Int function valueType(Int object, Int index) global native
function eraseIndex(Int object, Int index) global native
Int function findForm(Int object, Form form) global native
function clear(Int object) global native
