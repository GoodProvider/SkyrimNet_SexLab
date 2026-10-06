ScriptName JArray
Int function object() global native
Int function objectWithSize(Int size) global native
Int function objectWithInts(Int[] values) global native
Int function objectWithStrings(String[] values) global native
Int function objectWithFloats(Float[] values) global native
Int function objectWithBooleans(Bool[] values) global native
Int function objectWithForms(Form[] values) global native
Int function subArray(Int object, Int startIndex, Int endIndex) global native
function addFromArray(Int object, Int source, Int insertAtIndex=-1) global native
function addFromFormList(Int object, FormList source, Int insertAtIndex=-1) global native
Int function getInt(Int object, Int index, Int default=0) global native
Float function getFlt(Int object, Int index, Float default=0.0) global native
String function getStr(Int object, Int index, String default="") global native
Int function getObj(Int object, Int index, Int default=0) global native
Form function getForm(Int object, Int index, Form default=None) global native
Int[] function asIntArray(Int object) global native
Float[] function asFloatArray(Int object) global native
String[] function asStringArray(Int object) global native
Form[] function asFormArray(Int object) global native
Int function findInt(Int object, Int value, Int searchStartIndex=0) global native
Int function findFlt(Int object, Float value, Int searchStartIndex=0) global native
Int function findStr(Int object, String value, Int searchStartIndex=0) global native
Int function findObj(Int object, Int container, Int searchStartIndex=0) global native
Int function findForm(Int object, Form value, Int searchStartIndex=0) global native
Int function countInteger(Int object, Int value) global native
Int function countFloat(Int object, Float value) global native
Int function countString(Int object, String value) global native
Int function countObject(Int object, Int container) global native
Int function countForm(Int object, Form value) global native
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
function clear(Int object) global native
function eraseIndex(Int object, Int index) global native
function eraseRange(Int object, Int first, Int last) global native
Int function eraseInteger(Int object, Int value) global native
Int function eraseFloat(Int object, Float value) global native
Int function eraseString(Int object, String value) global native
Int function eraseObject(Int object, Int container) global native
Int function eraseForm(Int object, Form value) global native
Int function valueType(Int object, Int index) global native
function swapItems(Int object, Int index1, Int index2) global native
Int function sort(Int object) global native
Int function unique(Int object) global native
Int function reverse(Int object) global native
Bool function writeToIntegerPArray(Int object, Int[] targetArray, Int writeAtIdx=0, Int stopWriteAtIdx=-1, Int readIdx=0, Int defaultRead=0) global native
Bool function writeToFloatPArray(Int object, Float[] targetArray, Int writeAtIdx=0, Int stopWriteAtIdx=-1, Int readIdx=0, Float defaultRead=0.0) global native
Bool function writeToFormPArray(Int object, Form[] targetArray, Int writeAtIdx=0, Int stopWriteAtIdx=-1, Int readIdx=0, Form defaultRead=None) global native
Bool function writeToStringPArray(Int object, String[] targetArray, Int writeAtIdx=0, Int stopWriteAtIdx=-1, Int readIdx=0, String defaultRead="") global native
