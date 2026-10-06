scriptname sslUtility hidden
sslBaseAnimation[] function PushAnimation(sslBaseAnimation var, sslBaseAnimation[] Array) global Native
sslBaseAnimation[] function IncreaseAnimation(int by, sslBaseAnimation[] Array) global Native
sslBaseAnimation[] function EmptyAnimationArray() global Native
sslBaseAnimation[] function MergeAnimationLists(sslBaseAnimation[] List1, sslBaseAnimation[] List2) global Native
sslBaseAnimation[] function FilterTaggedAnimations(sslBaseAnimation[] Anims, string[] Tags, bool HasTag = true) global Native
sslBaseAnimation[] function RemoveTaggedAnimations(sslBaseAnimation[] Anims, string[] Tags) global Native
bool[] function FindTaggedAnimations(sslBaseAnimation[] Anims, string[] Tags) global Native
sslBaseAnimation function AnimationIfElse(bool isTrue, sslBaseAnimation returnTrue, sslBaseAnimation returnFalse) global Native
sslBaseAnimation[] function AnimationArrayIfElse(bool isTrue, sslBaseAnimation[] returnTrue, sslBaseAnimation[] returnFalse) global Native
sslBaseAnimation[] function ShuffleAnimations(sslBaseAnimation[] Anims) global Native
sslBaseAnimation[] function RemoveDupesFromList(sslBaseAnimation[] List, sslBaseAnimation[] Removing, bool PreventAll = true) global Native
string[] function GetAnimationNames(sslBaseAnimation[] List) global Native
string[] function GetAllAnimationTagsInArray(sslBaseAnimation[] List) global Native
int function IndexTravel(int CurrentIndex, int ArrayLength, bool Reverse = false) global Native
string function Trim(string var) global Native
string function RemoveString(string str, string toRemove, int startindex = 0) global Native
string function MakeArgs(string delimiter, string arg1, string arg2 = "", string arg3 = "", string arg4 = "", string arg5 = "") global Native
Actor[] function MakeActorArray(Actor Actor1 = none, Actor Actor2 = none, Actor Actor3 = none, Actor Actor4 = none, Actor Actor5 = none) global Native
bool[] function BoolArray(int size) global Native
float[] function FloatArray(int size) global Native
int[] function IntArray(int size) global Native
string[] function StringArray(int size) global Native
Form[] function FormArray(int size) global Native
Actor[] function ActorArray(int size) global Native
string[] function ArgString(string args, string delimiter = ",") global Native
Actor[] function PushActor(Actor var, Actor[] Array) global Native
int function CountNone(form[] Array) global Native
int function CountTrue(bool[] Array) global Native
int function CountEmpty(string[] Array) global Native
int[] function SliceIntArray(int[] Array, int startindex = 0, int endindex = -1) global Native
float function AddFloatValues(float[] Array) global Native
int function AddIntValues(int[] Array) global Native
int[] function IncreaseInt(int by, int[] Array) global Native
int[] function TrimIntArray(int[] Array, int len) global Native
int[] function PushInt(int var, int[] Array) global Native
int[] function MergeIntArray(int[] Push, int[] Array) global Native
int function ClampInt(int value, int min, int max) global Native
int[] function EmptyIntArray() global Native
int function WrapIndex(int index, int len) global Native
float[] function IncreaseFloat(int by, float[] Array) global Native
float[] function TrimFloatArray(float[] Array, int len) global Native
float[] function PushFloat(float var, float[] Array) global Native
float[] function MergeFloatArray(float[] Push, float[] Array) global Native
float function ClampFloat(float value, float min, float max) global Native
float[] function EmptyFloatArray() global Native
string[] function IncreaseString(int by, string[] Array) global Native
string[] function TrimStringArray(string[] Array, int len) global Native
string[] function PushString(string var, string[] Array) global Native
string[] function MergeStringArray(string[] Push, string[] Array) global Native
string[] function ClearEmpty(string[] Array) global Native
string[] function EmptyStringArray() global Native
bool[] function IncreaseBool(int by, bool[] Array) global Native
bool[] function TrimBoolArray(bool[] Array, int len) global Native
bool[] function PushBool(bool var, bool[] Array) global Native
bool[] function MergeBoolArray(bool[] Push, bool[] Array) global Native
bool[] function EmptyBoolArray() global Native
form[] function IncreaseForm(int by, form[] Array) global Native
form[] function PushForm(form var, form[] Array) global Native
form[] function MergeFormArray(form[] Push, form[] Array) global Native
Form[] function ClearNone(Form[] Array) global Native
form[] function EmptyFormArray() global Native
sslBaseAnimation[] function AnimationArray(int size) global Native
sslBaseVoice[] function VoiceArray(int size) global Native
sslBaseExpression[] function ExpressionArray(int size) global Native
sslBaseObject[] function BaseObjectArray(int size) global Native
