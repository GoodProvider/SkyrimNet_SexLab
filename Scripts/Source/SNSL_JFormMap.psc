;/  Form-keyed associative container. C++-backed replacement for JFormMap -- see SNSL_JValue.psc
    for why. Signatures mirror JFormMap's so a call site can migrate with a straight
    `JFormMap.` -> `SNSL_JFormMap.` rename.
/;
ScriptName SNSL_JFormMap

Int function object() global native

Int function getObj(Int object, Form key, Int default=0) global native
function setObj(Int object, Form key, Int container) global native

;/  0 - no value, 1 - none, 2 - int, 3 - float, 4 - form, 5 - object, 6 - string.
/;
Int function valueType(Int object, Form key) global native

;/  Iteration, identical contract to JFormMap.nextKey (endKey defaults to None).
/;
Form function nextKey(Int object, Form previousKey=None, Form endKey=None) global native
