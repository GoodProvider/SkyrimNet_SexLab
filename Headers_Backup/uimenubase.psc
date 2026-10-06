Scriptname UIMenuBase extends Quest
bool Property isResetting = false Auto
Function Lock() Native
bool Function WaitLock() Native
Function Unlock() Native
bool Function BlockUntilClosed() Native
bool Function WaitForReset() Native
int Function OpenMenu(Form akForm = None, Form akReceiver = None) Native
string Function GetMenuName() Native
Function ResetMenu() Native
float Function GetResultFloat() Native
int Function GetResultInt() Native
string Function GetResultString() Native
Form Function GetResultForm() Native
int Function GetPropertyInt(string propertyName) Native
bool Function GetPropertyBool(string propertyName) Native
string Function GetPropertyString(string propertyName) Native
float Function GetPropertyFloat(string propertyName) Native
Form Function GetPropertyForm(string propertyName) Native
Alias Function GetPropertyAlias(string propertyName) Native
Function SetPropertyInt(string propertyName, int value) Native
Function SetPropertyBool(string propertyName, bool value) Native
Function SetPropertyString(string propertyName, string value) Native
Function SetPropertyFloat(string propertyName, float value) Native
Function SetPropertyForm(string propertyName, Form value) Native
Function SetPropertyAlias(string propertyName, Alias value) Native
Function SetPropertyIndexInt(string propertyName, int index, int value) Native
Function SetPropertyIndexBool(string propertyName, int index, bool value) Native
Function SetPropertyIndexString(string propertyName, int index, string value) Native
Function SetPropertyIndexFloat(string propertyName, int index, float value) Native
Function SetPropertyIndexForm(string propertyName, int index, Form value) Native
Function SetPropertyIndexAlias(string propertyName, int index, Alias value) Native
Function SetPropertyIntA(string propertyName, int[] value) Native
Function SetPropertyBoolA(string propertyName, bool[] value) Native
Function SetPropertyStringA(string propertyName, string[] value) Native
Function SetPropertyFloatA(string propertyName, float[] value) Native
Function SetPropertyFormA(string propertyName, Form[] value) Native
Function SetPropertyAliasA(string propertyName, Alias[] value) Native
