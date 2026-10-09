Scriptname SkyrimNet_SexLab_OrgasmEngine
float Function GetEnjoyment(Actor akActor) global native
Function SetEnjoyment(Actor akActor, float value, String source) global native
Function AddEnjoyment(Actor akActor, float delta, String source) global native
bool Function Arouse(Actor who, Actor target, float mult = 1.0) global native
bool Function Calm(Actor who, Actor target, float mult = 1.0) global native
Function Edge(Actor akActor, float seconds, String source) global native
Function SetRateModifier(Actor akActor, String source, float mult) global native
Function ClearRateModifier(Actor akActor, String source) global native
Function SetOrgasmBlocked(Actor akActor, String source, bool blocked) global native
bool Function IsOrgasmAllowed(Actor akActor) global native
Function RequestOrgasm(Actor akActor, bool force, String source) global native
int Function GetOrgasmCount(Actor akActor) global native
float Function GetSecondsSinceOrgasm(Actor akActor) global native
bool Function IsManaged(Actor akActor) global native
bool Function IsMentallyBroken(Actor akActor) global native
bool Function IsMiniGameEnabled() global native
Function SetRates(float passive, float aggressor, float victim) global native
Function ReloadConfig() global native
Function BeginScene(int sid, Actor[] actors, int[] roles, float[] seeds, bool hasPlayer) global native
Function SetStage(int sid, int stage, int stageCount) global native
Function SetStageTimers(int sid, float[] stageSecs, bool leadIn) global native
Function SetScenePaused(int sid, bool paused) global native
Function GateNarrationSent(int sid, int mark) global native
Function SetEndingTarget(int sid, Actor lead, int target) global native
float Function FinalStageRemaining(int sid) global native
Function SetSceneBlocked(Actor akActor, bool blocked) global native
Function SetOrgasmExpected(Actor akActor, bool expected) global native
Function SetDomSlave(Actor akActor, bool dom) global native
Function SetDomMeter(Actor akActor, float meter) global native
Function SetActorSkills(Actor akActor, int skill, int lewd) global native
Function EndScene(int sid) global native
Function ResetSpeedScale(Actor akActor) global native
int Function GetSpeedLevel(Actor akActor) global native
bool Function ConsumeOwnOrgasm(Actor akActor) global native
int Function NoteExternalOrgasm(Actor akActor, String source) global native
bool Function AllowOrgasm(Actor akActor, Actor allower) global native
SkyrimNet_SexLab_Scene_Manager Function GetManager() global Native
Function Effect_Orgasm(Actor akActor, bool individual, String source) global Native
Function Effect_OrgasmGroup(Actor[] actors, int[] forced, bool individual, String source, Actor allower, Actor allowed, String extras) global Native
Function Effect_GatePassed(Actor[] actors, bool holdStage) global Native
Function Effect_AdvanceToFinal(Actor akActor) global Native
Function Effect_Mirror(Actor akActor, int value) global Native
Function Effect_DomSync(Actor akActor, float miniDelta, float daring, float naivety, float share, bool prepay, bool hasPlayer) global Native
Function Effect_Narrate(String event_type, String msg, Actor source, Actor target) global Native
