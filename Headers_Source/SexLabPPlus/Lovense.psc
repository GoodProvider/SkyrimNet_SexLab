Scriptname Lovense Hidden

; HEADER ONLY for skyrimse-pplus.ppj: P+ sslLovense references SkyrimLovense's script. Signatures cover P+'s calls.

int Function GetConnectedCount() native global
String[] Function GetToysByCategory(String asCategory) native global
String Function GetToyCategory(String asToy) native global
bool Function FunctionRequest(String[] asActions, int[] aiStrengths, float afDuration, float afLoopRunningSec = 0.0, float afLoopPauseSec = 0.0, String asToy = "", bool abStopPrevious = true) native global
bool Function StopRequest(String asToy = "") native global
