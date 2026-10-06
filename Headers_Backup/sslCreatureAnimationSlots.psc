scriptname sslCreatureAnimationSlots extends sslAnimationSlots
string function GetRaceKey(Race RaceRef) global native
string function GetRaceKeyByID(string RaceID) global native
function AddRaceID(string RaceKey, string RaceID) global native
bool function HasRaceID(string RaceKey, string RaceID) global native
bool function HasRaceKey(string RaceKey) global native
bool function ClearRaceKey(string RaceKey) global native
bool function HasRaceIDType(string RaceID) global native
bool function HasCreatureType(Actor ActorRef) global native
bool function HasRaceType(Race RaceRef) global native
string[] function GetAllRaceKeys(Race RaceRef = none) global native
string[] function GetAllRaceIDs(string RaceKey) global native
Race[] function GetAllRaces(string RaceKey) global native
sslBaseAnimation[] function GetByRace(int ActorCount, Race RaceRef) Native
sslBaseAnimation[] function GetByRaceTags(int ActorCount, Race RaceRef, string Tags, string TagsSuppressed = "", bool RequireAll = true) Native
sslBaseAnimation[] function GetByRaceKey(int ActorCount, string RaceKey) Native
sslBaseAnimation[] function GetByRaceKeyTags(int ActorCount, string RaceKey, string Tags, string TagsSuppressed = "", bool RequireAll = true) Native
sslBaseAnimation[] function GetByCreatureActors(int ActorCount, Actor[] Positions) Native
sslBaseAnimation[] function GetByCreatureActorsTags(int ActorCount, Actor[] Positions, string Tags, string TagsSuppressed = "", bool RequireAll = true) Native
sslBaseAnimation[] function GetByRaceGenders(int ActorCount, Race RaceRef, int MaleCreatures = 0, int FemaleCreatures = 0, bool ForceUse = false) Native
sslBaseAnimation[] function GetByRaceGendersTags(int ActorCount, Race RaceRef, int MaleCreatures = 0, int FemaleCreatures = 0, string Tags, string TagsSuppressed = "", bool RequireAll = true) Native
sslBaseAnimation[] function FilterCreatureGenders(sslBaseAnimation[] Anims, int MaleCreatures = 0, int FemaleCreatures = 0) Native
bool function RaceHasAnimation(Race RaceRef, int ActorCount = -1, int Gender = -1) Native
bool function RaceKeyHasAnimation(string RaceKey, int ActorCount = -1, int Gender = -1) Native
bool function HasCreature(Actor ActorRef) Native
bool function HasRace(Race RaceRef) Native
bool function AllowedCreature(Race RaceRef) Native
bool function AllowedCreatureCombination(Race RaceRef1, Race RaceRef2) Native
bool function AllowedRaceKeyCombination(string[] Keys1, string[] Keys2) Native
bool function HasAnimation(Race RaceRef, int Gender = -1) Native
function Setup() Native
function RegisterSlots() Native
function RegisterRaces() Native
