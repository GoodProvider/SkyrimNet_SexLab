Scriptname SkyrimNet_SexLab_Utilities

; ------------------------------------------------------------
; Trace for Utilities
; ------------------------------------------------------------

Function Trace(String func, String msg, Bool notification=False) global
EndFunction
String Function GetTimestamp() global
EndFunction

; ------------------------------------------------------------
; Combines Actors or Strings into natural language list 
; will make a natural sentence with comma and 'and' 
; filter is an int[] array 0 - false and 1 - true
; ------------------------------------------------------------
String Function JoinActors(ACtor[] actors, String noun = "") global 
EndFunction 

String Function JoinActorsFiltered(Actor[] actors, int[] filter,  String Noun = "", Bool ignore_filter=False) global 
EndFunction 

String Function JoinStrings(String[] strings, bool add_is_are=False) global 
EndFunction 

String Function JoinStringsFiltered(String[] strings, int[] filter, Bool add_is_are = false) global 
EndFunction

String Function JoinIsAre(String joined, int total, bool add_is_are) global
EndFunction 

String Function JoinStringToArray(String[] strings, int[] filter) global 
EndFunction 

; ------------------------------------------------------------
; Narration Wrappers 
; ------------------------------------------------------------

Function ContinueActivity(Actor source=None, Actor target=None, bool optional=False) global 
EndFunction 

Function DirectNarration_Optional(String event_type, String msg, Actor source=None, Actor target=None, bool optional=False) global
EndFunction

Function DirectNarration(String msg, Actor source=None, Actor target=None) global
EndFunction


Function RegisterEvent(String event_name, String msg, Actor source=None, Actor target=None) global
EndFunction

String Function CheckDuplicate(String func, Actor source, String msg) global
EndFunction
