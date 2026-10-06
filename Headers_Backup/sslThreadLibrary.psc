scriptname sslThreadLibrary extends sslSystemLibrary
FormList property BedsList auto hidden
FormList property DoubleBedsList auto hidden
FormList property BedRollsList auto hidden
Keyword property FurnitureBedRoll auto hidden
bool function CheckActor(Actor CheckRef, int CheckGender = -1) Native
Actor function FindAvailableActor(ObjectReference CenterRef, float Radius = 5000.0, int FindGender = -1, Actor IgnoreRef1 = none, Actor IgnoreRef2 = none, Actor IgnoreRef3 = none, Actor IgnoreRef4 = none, string RaceKey = "") Native
Actor function FindAvailableActorInFaction(Faction FactionRef, ObjectReference CenterRef, float Radius = 5000.0, int FindGender = -1, Actor IgnoreRef1 = none, Actor IgnoreRef2 = none, Actor IgnoreRef3 = none, Actor IgnoreRef4 = none, bool HasFaction = True, string RaceKey = "", bool JustSameFloor = False) Native
Actor function FindAvailableActorWornForm(int slotMask, ObjectReference CenterRef, float Radius = 5000.0, int FindGender = -1, Actor IgnoreRef1 = none, Actor IgnoreRef2 = none, Actor IgnoreRef3 = none, Actor IgnoreRef4 = none, bool AvoidNoStripKeyword = True, bool HasWornForm = True, string RaceKey = "", bool JustSameFloor = False) Native
Actor[] function FindAvailablePartners(actor[] Positions, int total, int males = -1, int females = -1, float radius = 10000.0) Native
Actor[] function FindAnimationPartners(sslBaseAnimation Animation, ObjectReference CenterRef, float Radius = 5000.0, Actor IncludedRef1 = none, Actor IncludedRef2 = none, Actor IncludedRef3 = none, Actor IncludedRef4 = none) Native
Actor[] Function SortActors(Actor[] Positions, bool FemaleFirst = true) Native
bool Function IsLesserGender(int i, int n) Native
Actor[] function SortActors_Legacy(Actor[] Positions, bool FemaleFirst = true) Native
Actor[] function SortActorsByAnimation(actor[] Positions, sslBaseAnimation Animation = none) Native
int function FindNext(Actor[] Positions, sslBaseAnimation Animation, int offset, bool FindCreature) Native
Actor[] function SortCreatures(actor[] Positions, sslBaseAnimation Animation = none) Native
bool function IsBedRoll(ObjectReference BedRef) Native
bool function IsDoubleBed(ObjectReference BedRef) Native
bool function IsSingleBed(ObjectReference BedRef) Native
int function GetBedType(ObjectReference BedRef) Native
bool function IsBedAvailable(ObjectReference BedRef) Native
bool function CheckBed(ObjectReference BedRef, bool IgnoreUsed = true) Native
bool function LeveledAngle(ObjectReference ObjectRef, float Tolerance = 5.0) Native
bool function SameFloor(ObjectReference BedRef, float Z, float Tolerance = 15.0) Native
ObjectReference function FindBed(ObjectReference CenterRef, float Radius = 1000.0, bool IgnoreUsed = true, ObjectReference IgnoreRef1 = none, ObjectReference IgnoreRef2 = none) Native
function TrackActor(Actor ActorRef, string Callback) Native
function TrackFaction(Faction FactionRef, string Callback) Native
function UntrackActor(Actor ActorRef, string Callback) Native
function UntrackFaction(Faction FactionRef, string Callback) Native
bool function IsActorTracked(Actor ActorRef) Native
function SendTrackedEvent(Actor ActorRef, string Hook = "", int id = -1) Native
function SetupActorEvent(Actor ActorRef, string Callback, int id = -1) Native
function Setup() Native
