scriptName SkyMessage hidden
function Delete(int messageBoxId) global native
string function Show(string bodyText, string button1, string button2 = "", string button3 = "", string button4 = "", string button5 = "", string button6 = "", string button7 = "", string button8 = "", string button9 = "", string button10 = "", bool getIndex = false, float waitInterval = 0.1, float timeoutSeconds = 0.0) global Native
string function ShowArray(string bodyText, string[] buttons, bool getIndex = false, float waitInterval = 0.1, float timeoutSeconds = 0.0) global Native
int function Show_NonBlocking(string bodyText, string button1, string button2 = "", string button3 = "", string button4 = "", string button5 = "", string button6 = "", string button7 = "", string button8 = "", string button9 = "", string button10 = "") global native
int function ShowArray_NonBlocking(string bodyText, string[] buttons) global native
string function GetResultText(int messageBoxId, bool deleteResultOnAccess = true) global native
int function GetResultIndex(int messageBoxId, bool deleteResultOnAccess = true) global native
bool function IsMessageResultAvailable(int messageBoxId) global native
