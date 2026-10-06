scriptname SKI_ConfigBase extends SKI_QuestBase
string property		JOURNAL_MENU	= "Journal Menu" autoReadonly
string property		MENU_ROOT		= "_root.ConfigPanelFader.configPanel" autoReadonly
int property		STATE_DEFAULT	= 0 autoReadonly
int property		STATE_RESET		= 1 autoReadonly
int property		STATE_SLIDER	= 2 autoReadonly
int property		STATE_MENU		= 3 autoReadonly
int property		STATE_COLOR		= 4 autoReadonly
int property		OPTION_TYPE_EMPTY	= 0x00 autoReadonly
int property		OPTION_TYPE_HEADER	= 0x01 autoReadonly
int property		OPTION_TYPE_TEXT	= 0x02 autoReadonly
int property		OPTION_TYPE_TOGGLE	= 0x03 autoReadonly
int property 		OPTION_TYPE_SLIDER	= 0x04 autoReadonly
int property		OPTION_TYPE_MENU	= 0x05 autoReadonly
int property		OPTION_TYPE_COLOR	= 0x06 autoReadonly
int property		OPTION_TYPE_KEYMAP	= 0x07 autoReadonly
int property		OPTION_FLAG_NONE		= 0x00 autoReadonly
int property		OPTION_FLAG_DISABLED	= 0x01 autoReadonly
int property		OPTION_FLAG_HIDDEN		= 0x02 autoReadonly
int property		OPTION_FLAG_WITH_UNMAP	= 0x04 autoReadonly
int property		LEFT_TO_RIGHT	= 1	autoReadonly
int property		TOP_TO_BOTTOM	= 2 autoReadonly
string property		ModName auto
string[] property	Pages auto
string property		CurrentPage AutoReadonly
string function get() Native
int function GetVersion() Native
string function GetCustomControl(int a_keyCode) Native
function ForcePageReset() Native
function SetTitleText(string a_text) Native
function SetInfoText(string a_text) Native
function SetCursorPosition(int a_position) Native
function SetCursorFillMode(int a_fillMode) Native
int function AddEmptyOption() Native
int function AddHeaderOption(string a_text, int a_flags = 0) Native
int function AddTextOption(string a_text, string a_value, int a_flags = 0) Native
int function AddToggleOption(string a_text, bool a_checked, int a_flags = 0) Native
int function AddSliderOption(string a_text, float a_value, string a_formatString = "{0}", int a_flags = 0) Native
int function AddMenuOption(string a_text, string a_value, int a_flags = 0) Native
int function AddColorOption(string a_text, int a_color, int a_flags = 0) Native
int function AddKeyMapOption(string a_text, int a_keyCode, int a_flags = 0) Native
function AddTextOptionST(string a_stateName, string a_text, string a_value, int a_flags = 0) Native
function AddToggleOptionST(string a_stateName, string a_text, bool a_checked, int a_flags = 0) Native
function AddSliderOptionST(string a_stateName, string a_text, float a_value, string a_formatString = "{0}", int a_flags = 0) Native
function AddMenuOptionST(string a_stateName, string a_text, string a_value, int a_flags = 0) Native
function AddColorOptionST(string a_stateName, string a_text, int a_color, int a_flags = 0) Native
function AddKeyMapOptionST(string a_stateName, string a_text, int a_keyCode, int a_flags = 0) Native
function LoadCustomContent(string a_source, float a_x = 0.0, float a_y = 0.0) Native
function UnloadCustomContent() Native
function SetOptionFlags(int a_option, int a_flags, bool a_noUpdate = false) Native
function SetTextOptionValue(int a_option, string a_value, bool a_noUpdate = false) Native
function SetToggleOptionValue(int a_option, bool a_checked, bool a_noUpdate = false) Native
function SetSliderOptionValue(int a_option, float a_value, string a_formatString = "{0}", bool a_noUpdate = false) Native
function SetMenuOptionValue(int a_option, string a_value, bool a_noUpdate = false) Native
function SetColorOptionValue(int a_option, int a_color, bool a_noUpdate = false) Native
function SetKeyMapOptionValue(int a_option, int a_keyCode, bool a_noUpdate = false) Native
function SetOptionFlagsST(int a_flags, bool a_noUpdate = false, string a_stateName = "") Native
function SetTextOptionValueST(string a_value, bool a_noUpdate = false, string a_stateName = "") Native
function SetToggleOptionValueST(bool a_checked, bool a_noUpdate = false, string a_stateName = "") Native
function SetSliderOptionValueST(float a_value, string a_formatString = "{0}", bool a_noUpdate = false, string a_stateName = "") Native
function SetMenuOptionValueST(string a_value, bool a_noUpdate = false, string a_stateName = "") Native
function SetColorOptionValueST(int a_color, bool a_noUpdate = false, string a_stateName = "") Native
function SetKeyMapOptionValueST(int a_keyCode, bool a_noUpdate = false, string a_stateName = "") Native
function SetSliderDialogStartValue(float a_value) Native
function SetSliderDialogDefaultValue(float a_value) Native
function SetSliderDialogRange(float a_minValue, float a_maxValue) Native
function SetSliderDialogInterval(float a_value) Native
function SetMenuDialogStartIndex(int a_value) Native
function SetMenuDialogDefaultIndex(int a_value) Native
function SetMenuDialogOptions(string[] a_options) Native
function SetColorDialogStartColor(int a_color) Native
function SetColorDialogDefaultColor(int a_color) Native
bool function ShowMessage(string a_message, bool a_withCancel = true, string a_acceptLabel = "$Accept", string a_cancelLabel = "$Cancel") Native
function Error(string a_msg) Native
function OpenConfig() Native
function CloseConfig() Native
function SetPage(string a_page, int a_index) Native
int function AddOption(int a_optionType, string a_text, string a_strValue, float a_numValue, int a_flags) Native
function AddOptionST(string a_stateName, int a_optionType, string a_text, string a_strValue, float a_numValue, int a_flags) Native
int function GetStateOptionIndex(string a_stateName) Native
function WriteOptionBuffers() Native
function ClearOptionBuffers() Native
function SetOptionStrValue(int a_index, string a_strValue, bool a_noUpdate) Native
function SetOptionNumValue(int a_index, float a_numValue, bool a_noUpdate) Native
function SetOptionValues(int a_index, string a_strValue, float a_numValue, bool a_noUpdate) Native
function RequestSliderDialogData(int a_index) Native
function RequestMenuDialogData(int a_index) Native
function RequestColorDialogData(int a_index) Native
function SetSliderValue(float a_value) Native
function SetMenuIndex(int a_index) Native
function SetColorValue(int a_color) Native
function SelectOption(int a_index) Native
function ResetOption(int a_index) Native
function HighlightOption(int a_index) Native
function RemapKey(int a_index, int a_keyCode, string a_conflictControl, string a_conflictName) Native
