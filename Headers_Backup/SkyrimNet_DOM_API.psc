Scriptname SkyrimNet_DOM_API
Function Trace(String func, String msg, Bool Notification = false) global Native
Function Trace_Helper(String File, String Func, String msg, Bool Notification=false) global Native
DOM_Actor Function GetDOM_Actor(String File, String Func, Actor akActor, bool error_non_dom_actor=false, bool Notification=false) global Native
DOM_Actor Function GetSlave(String File, String Func, Actor akActor, bool error_non_dom_actor=false, bool Notification=false) global Native
Bool Function IsDOMSlave(Actor akActor) global Native
bool Function Ostim_IsInOstim(Actor akActor) global Native
Function AddPunishmentReason(String file, String func, Actor superior, Actor slaveActor, DOM_Actor slave, String reason_name) global Native
int Function GetThreads() global Native
Function Start_Masturbate(String intent, Actor speaker, Actor superior, String position="") global Native
Function StartScene_Consensual_Two(String intent, Actor speaker, Actor Superior, Actor target, string style="", string method="", String direction="", String setting_name="") global Native
Function StartScene_Nonconsensual_Two(String intent, Actor speaker, Actor superior, Actor target=None, Actor victim, string method="", String direction="", String setting_name="") global Native
Function StartScene_Nonconsensual_Two_SpeakerVictim(String intent, Actor speaker, Actor superior, Actor target, string method="", String direction="", String setting_name="") global Native
Function StartScene_Nonconsensual_Two_TargetVictim(String intent, Actor speaker, Actor superior, Actor target, string method="", String direction="", String setting_name="") global Native
