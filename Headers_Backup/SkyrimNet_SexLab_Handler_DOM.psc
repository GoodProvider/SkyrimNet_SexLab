Scriptname SkyrimNet_SexLab_Handler_DOM extends SkyrimNet_SexLab_Handler_DOM_Interface
Function Trace(String func, String msg, Bool notification=False) Native
bool Function Setup() Native
Bool Function Setup_CheckLinks() Native
Bool Function IsDOMSlave(Actor akActor) Native
String Function HandleOrgasmDenied(Actor akActor) Native
Function DOMSlave_Orgasmed(Actor slave, String msg) Native
Function DelayMeltNarration(Actor slave, String msg) Native
Bool Function Orgasm_Desired(Actor akActor) Native
DOM_Mind Function GetMind(Actor akActor, String func) Native
Function AddArousal(Actor akActor, float delta) Native
float Function EstimateChance(DOM_Mind mind, Actor akActor) Native
bool Function IsMale(Actor akActor) Native
bool Function IsRefractory(DOM_Mind mind, Actor akActor) Native
float Function OrgasmMeter(Actor akActor) Native
Bool Function CouldOrgasm(Actor akActor) Native
float Function DomArousalValue(DOM_Mind mind, Actor akActor, float amount, float reason) Native
Function PushStep(DOM_Mind mind, Actor akActor, float amount, float reason) Native
Function DomSync(Actor akActor, float miniDelta, float daring, float naivety, bool prepay, bool hasPlayer) Native
Function StepRoll(Actor akActor, bool hasPlayer, float share) Native
int Function GetThreads() Native
Function Start_Masturbate(String intent, Actor speaker, Actor superior, String position="") Native
Function StartScene_Consensual_Two(String intent, Actor speaker, Actor superior, Actor target, string style="", string method="", String direction="", String setting_name="") Native
Function StartScene_Nonconsensual_Two(String intent, Actor speaker, Actor superior, Actor target, Actor victim, string method="", String direction="", String setting_name="") Native
Function StartScene_Nonconsensual_Two_SpeakerVictim(String intent, Actor speaker, Actor superior, Actor target, string method="", String direction="", String setting_name="") Native
Function StartScene_Nonconsensual_Two_TargetVictim(String intent, Actor speaker, Actor superior, Actor target, string method="", String direction="", String setting_name="") Native
