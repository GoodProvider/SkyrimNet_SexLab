Scriptname Race extends Form Hidden
int Function GetSpellCount() native
Spell Function GetNthSpell(int n) native
bool Function IsRaceFlagSet(int n) native
Function SetRaceFlag(int n) native
Function ClearRaceFlag(int n) native
VoiceType Function GetDefaultVoiceType(bool female) native
Function SetDefaultVoiceType(bool female, VoiceType voice) native
Armor Function GetSkin() native
Function SetSkin(Armor skin) native
int Function GetNumPlayableRaces() native global
Race Function GetNthPlayableRace(int n) native global
Race Function GetRace(string editorId) native global
int property kRace_Playable						= 0x00000001 AutoReadOnly
int property kRace_FaceGenHead					= 0x00000002 AutoReadOnly
int property kRace_Child						= 0x00000004 AutoReadOnly
int property kRace_TiltFrontBack				= 0x00000008 AutoReadOnly
int property kRace_TiltLeftRight				= 0x00000010 AutoReadOnly
int property kRace_NoShadow						= 0x00000020 AutoReadOnly
int property kRace_Swims						= 0x00000040 AutoReadOnly
int property kRace_Flies						= 0x00000080 AutoReadOnly
int property kRace_Walks						= 0x00000100 AutoReadOnly
int property kRace_Immobile						= 0x00000200 AutoReadOnly
int property kRace_NotPushable					= 0x00000400 AutoReadOnly
int property kRace_NoCombatInWater				= 0x00000800 AutoReadOnly
int property kRace_NoRotatingToHeadTrack		= 0x00001000 AutoReadOnly
int property kRace_UseHeadTrackAnim				= 0x00008000 AutoReadOnly
int property kRace_SpellsAlignWithMagicNode		= 0x00010000 AutoReadOnly
int property kRace_UseWorldRaycasts				= 0x00020000 AutoReadOnly
int property kRace_AllowRagdollCollision		= 0x00040000 AutoReadOnly
int property kRace_CantOpenDoors				= 0x00100000 AutoReadOnly
int property kRace_AllowPCDialogue				= 0x00200000 AutoReadOnly
int property kRace_NoKnockdowns					= 0x00400000 AutoReadOnly
int property kRace_AllowPickpocket				= 0x00800000 AutoReadOnly
int property kRace_AlwaysUseProxyController		= 0x01000000 AutoReadOnly
int property kRace_AllowMultipleMembraneShaders	= 0x20000000 AutoReadOnly
int property kRace_AvoidsRoads					= 0x80000000 AutoReadOnly
bool Function IsPlayable() Native
Function MakePlayable() Native
Function MakeUnplayable() Native
bool Function IsChildRace() Native
Function MakeChildRace() Native
Function MakeNonChildRace() Native
bool Function CanFly() Native
Function MakeCanFly() Native
Function MakeNonFlying() Native
bool Function CanSwim() Native
Function MakeCanSwim() Native
Function MakeNonSwimming() Native
bool Function CanWalk() Native
Function MakeCanWalk() Native
Function MakeNonWalking() Native
bool Function IsImmobile() Native
Function MakeImmobile() Native
Function MakeMobile() Native
bool Function IsNotPushable() Native
Function MakeNotPushable() Native
Function MakePushable() Native
bool Function NoKnockdowns() Native
Function MakeNoKnockdowns() Native
Function ClearNoKNockdowns() Native
bool Function NoCombatInWater() Native
Function SetNoCombatInWater() Native
Function ClearNoCombatInWater() Native
bool Function AvoidsRoads() Native
Function SetAvoidsRoads() Native
Function ClearAvoidsRoads() Native
bool Function AllowPickpocket() Native
Function SetAllowPickpocket() Native
Function ClearAllowPickpocket() Native
bool Function AllowPCDialogue() Native
Function SetAllowPCDialogue() Native
Function ClearAllowPCDialogue() Native
bool Function CantOpenDoors() Native
Function SetCantOpenDoors() Native
Function ClearCantOpenDoors() Native
bool Function NoShadow() Native
Function SetNoShadow() Native
Function ClearNoShadow() Native
