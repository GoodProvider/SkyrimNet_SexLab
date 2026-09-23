;/  Associative string-keyed container. C++-backed replacement for JMap -- see SNSL_JValue.psc for
    why. Signatures mirror JMap's so a call site can migrate with a straight `JMap.` ->
    `SNSL_JMap.` rename. Keys are lowercased (ASCII) on both insert and lookup, so existing mixed-
    case reads (e.g. getForm(obj, "formRendered")) keep working unchanged.
/;
ScriptName SNSL_JMap

;/  Creates a new container object. Returns the container's identifier.
/;
Int function object() global native

;/  Returns the value associated with @key, or @default if absent / wrong type.
/;
Int function getInt(Int object, String key, Int default=0) global native
Float function getFlt(Int object, String key, Float default=0.0) global native
String function getStr(Int object, String key, String default="") global native
Int function getObj(Int object, String key, Int default=0) global native
Form function getForm(Int object, String key, Form default=None) global native

;/  Inserts @key: @value. Replaces any existing pair with the same @key (lowercased).
/;
function setInt(Int object, String key, Int value) global native
function setFlt(Int object, String key, Float value) global native
function setStr(Int object, String key, String value) global native
function setObj(Int object, String key, Int container) global native
function setForm(Int object, String key, Form value) global native

;/  0 - no value, 1 - none, 2 - int, 3 - float, 4 - form, 5 - object, 6 - string.
/;
Int function valueType(Int object, String key) global native

;/  Iteration, identical contract to JMap.nextKey:
        string key = SNSL_JMap.nextKey(map, previousKey="", endKey="")
        while key != ""
          <retrieve values here>
          key = SNSL_JMap.nextKey(map, key, endKey="")
        endwhile
/;
String function nextKey(Int object, String previousKey="", String endKey="") global native

;/  Returns a new SNSL_JArray containing all keys.
/;
Int function allKeys(Int object) global native

;/  Returns count of pairs in the container.
/;
Int function count(Int object) global native
