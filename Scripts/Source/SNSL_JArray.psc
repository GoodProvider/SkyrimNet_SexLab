;/  Ordered collection. C++-backed replacement for JArray -- see SNSL_JValue.psc for why.
    Signatures mirror JArray's so a call site can migrate with a straight `JArray.` ->
    `SNSL_JArray.` rename. Negative indices count from the end, matching JContainers.
/;
ScriptName SNSL_JArray

;/  Creates a new container object. Returns the container's identifier.
/;
Int function object() global native

;/  Creates a new array of the given size, filled with None items.
/;
Int function objectWithSize(Int size) global native

;/  Returns the item at @index, or @default if out of range / wrong type. Negative index counts
    from the end.
/;
Int function getInt(Int object, Int index, Int default=0) global native
Float function getFlt(Int object, Int index, Float default=0.0) global native
String function getStr(Int object, Int index, String default="") global native
Int function getObj(Int object, Int index, Int default=0) global native
Form function getForm(Int object, Int index, Form default=None) global native

;/  Replaces the value at @index. Negative index counts from the end. No-op if out of range.
/;
function setInt(Int object, Int index, Int value) global native
function setFlt(Int object, Int index, Float value) global native
function setStr(Int object, Int index, String value) global native
function setObj(Int object, Int index, Int container) global native
function setForm(Int object, Int index, Form value) global native

;/  Appends @value/@container to the end. If @addToIndex >= 0 it inserts at that index instead.
/;
function addInt(Int object, Int value, Int addToIndex=-1) global native
function addFlt(Int object, Float value, Int addToIndex=-1) global native
function addStr(Int object, String value, Int addToIndex=-1) global native
function addObj(Int object, Int container, Int addToIndex=-1) global native
function addForm(Int object, Form value, Int addToIndex=-1) global native

;/  Returns count of items in the array.
/;
Int function count(Int object) global native

;/  0 - no value, 1 - none, 2 - int, 3 - float, 4 - form, 5 - object, 6 - string.
/;
Int function valueType(Int object, Int index) global native
