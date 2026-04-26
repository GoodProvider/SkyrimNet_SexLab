Scriptname SkyrimNet_SexLab_NudeRef extends ReferenceAlias

String storage_key = "skyrimnet_sexlab_storage_items"

sslSystemConfig Config 
sslActorLibrary Lib 

Function Trace(String func, String msg, Bool notification=False) global
EndFunction

Event OnObjectEquipped(Form akBaseObject, ObjectReference akReference)
EndEvent

bool function ContinueStrip(Form ItemRef, bool DoStrip = true)
endFunction