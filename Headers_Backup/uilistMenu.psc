Scriptname UIListMenu extends UIMenuBase
string property		ROOT_MENU		= "CustomMenu" autoReadonly
string Property 	MENU_ROOT		= "_root.listMenu." autoReadonly
int Function GetResultInt() Native
float Function GetResultFloat() Native
string Function GetResultString() Native
Function SetPropertyInt(string propertyName, int value) Native
Function SetPropertyBool(string propertyName, bool value) Native
Function SetPropertyStringA(string propertyName, string[] value) Native
int Function AddEntryItem(string entryName, int entryParent = -1, int entryCallback = -1, bool entryHasChildren = false) Native
Function SetPropertyIndexInt(string propertyName, int index, int value) Native
Function SetPropertyIndexBool(string propertyName, int index, bool value) Native
Function SetPropertyIndexString(string propertyName, int index, string value) Native
int Function GetPropertyInt(string propertyName) Native
Function OnInit() Native
Function ResetMenu() Native
int Function OpenMenu(Form aForm = None, Form aReceiver = None) Native
string Function GetMenuName() Native
