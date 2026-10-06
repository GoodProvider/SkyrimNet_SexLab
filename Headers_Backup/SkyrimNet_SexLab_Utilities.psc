Scriptname SkyrimNet_SexLab_Utilities
Function Trace(String func, String msg, Bool notification=False) global Native
bool Function IsSexLabPPlus() global Native
sslBaseAnimation[] Function PickOneAnimation(sslBaseAnimation[] animations) global Native
String Function GetDisplayName(Actor akActor) global Native
String Function GetRaceKeyForActor(SexLabFramework sexlab, Actor akActor) global Native
String Function IntToHex(int value) global Native
String Function UuidToDecimalString(String entityUuid) global native
String Function GetTimestamp() global Native
String Function JoinActors(Actor[] actors, int num_actors=-1) global Native
String Function JoinActorsMasked(Actor[] actors, int[] mask, int num_actors = -1) global Native
String Function JoinNouns(String[] strings, int num_nouns = -1, bool add_is_are=false) global Native
String Function JoinNounsMasked(String[] strings, int[] mask, int num_strings = -1, bool add_is_are = false) global Native
String Function JoinIsAre(String joined, int total, bool add_is_are) global Native
String Function JoinStringsToJson(String[] strings, int num_strings=-1) global Native
String Function JoinStringsToJsonMasked(String[] strings, int[] mask=None, int num_strings=-1) global Native
String Function JoinActorsToJson(Actor[] actors, int num_actors=-1) global Native
String Function JoinActorsToJsonMasked(Actor[] actors, int[] mask, int num_actors=-1) global Native
String Function JoinStrings(String[] strings, int num_strings=-1) global Native
String Function JoinIntsToJson(int[] ints, int num_ints=-1) global Native
String Function JoinJArrayStrToJson(int array) global Native
Function ContinueActivity(Actor source=None, Actor target=None, bool optional_is_dropped=False) global Native
Bool Function NarrationCoolOffAllows(Actor source, Actor target) global Native
bool Function DirectNarration_Optional(String event_type, String msg, Actor source=None, Actor target=None, bool optional_is_dropped=False) global Native
Function SendDirectNarration(String msg, Actor source=None, Actor target=None, bool purge_dialogue=False) global Native
Function DirectNarration_Flush(String msg, Actor source, Actor target, bool purge_dialogue) global Native
bool Function QueueDirectNarration(String msg, Actor source, Actor target, bool purge_dialogue) global native
Function DirectNarration(String msg, Actor source=None, Actor target=None, bool purge_dialogue=False) global Native
Function RegisterEvent(String event_name, String msg, Actor source=None, Actor target=None) global Native
Function RegisterEventForce(String event_name, String msg, Actor source=None, Actor target=None) global Native
String Function CheckDuplicate(String func, Actor source, String msg, Bool allow_continue_fallback=True, Actor target=None) global Native
String Function JsonBool(bool value) global Native
String Function JsonLowerCaseKeys(String json) global native
int Function VkToDxScanCode(int vk) global native
Function SetAnimSpeed(Actor akActor, float speed) global native
Function ClearAnimSpeed(Actor akActor) global native
float Function GetAnimSpeed(Actor akActor) global native
String Function JsonQuote(String s) global native
String Function JsonForm(Form akForm) global Native
String Function JValueToJsonString(int obj) global Native
String Function JMapToJson(int obj) global Native
String Function JMapValueToJson(int obj, String map_key) global Native
String Function JArrayToJson(int obj) global Native
String Function JArrayValueToJson(int obj, int index) global Native
String Function JFormMapToJson(int obj) global Native
String Function JFormMapValueToJson(int obj, Form map_key) global Native
String Function JIntMapToJson(int obj) global Native
String Function JIntMapValueToJson(int obj, int map_key) global Native
String Function ObjectToLowerCaseKeyJson(int obj) global Native
String Function RenderSlPrompt(String template_name, int obj, String fallback="") global Native
int[] Function EnsureIntsLargeEnough(int[] ints, int total, int default=0) global Native
String[] Function EnsureStringsLargeEnough(String[] strings, int num_strings, String default="") global Native
Actor[] Function EnsureActorsLargeEnough(Actor[] actors_current, int total) global Native
String Function ReplaceWord(String asSource, String asToFind, String asReplacement) global Native
