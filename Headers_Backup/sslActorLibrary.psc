scriptname sslActorLibrary extends sslSystemLibrary
Faction property AnimatingFaction auto hidden
Faction property GenderFaction auto hidden
Faction property ForbiddenFaction auto hidden
Weapon property DummyWeapon auto hidden
Armor property NudeSuit auto hidden
Spell property CumVaginalOralAnalSpell auto hidden
Spell property CumOralAnalSpell auto hidden
Spell property CumVaginalOralSpell auto hidden
Spell property CumVaginalAnalSpell auto hidden
Spell property CumVaginalSpell auto hidden
Spell property CumOralSpell auto hidden
Spell property CumAnalSpell auto hidden
Spell property Vaginal1Oral1Anal1 auto hidden
Spell property Vaginal2Oral1Anal1 auto hidden
Spell property Vaginal2Oral2Anal1 auto hidden
Spell property Vaginal2Oral1Anal2 auto hidden
Spell property Vaginal1Oral2Anal1 auto hidden
Spell property Vaginal1Oral2Anal2 auto hidden
Spell property Vaginal1Oral1Anal2 auto hidden
Spell property Vaginal2Oral2Anal2 auto hidden
Spell property Oral1Anal1 auto hidden
Spell property Oral2Anal1 auto hidden
Spell property Oral1Anal2 auto hidden
Spell property Oral2Anal2 auto hidden
Spell property Vaginal1Oral1 auto hidden
Spell property Vaginal2Oral1 auto hidden
Spell property Vaginal1Oral2 auto hidden
Spell property Vaginal2Oral2 auto hidden
Spell property Vaginal1Anal1 auto hidden
Spell property Vaginal2Anal1 auto hidden
Spell property Vaginal1Anal2 auto hidden
Spell property Vaginal2Anal2 auto hidden
Spell property Vaginal1 auto hidden
Spell property Vaginal2 auto hidden
Spell property Oral1 auto hidden
Spell property Oral2 auto hidden
Spell property Anal1 auto hidden
Spell property Anal2 auto hidden
Keyword property CumOralKeyword auto hidden
Keyword property CumAnalKeyword auto hidden
Keyword property CumVaginalKeyword auto hidden
Keyword property CumOralStackedKeyword auto hidden
Keyword property CumAnalStackedKeyword auto hidden
Keyword property CumVaginalStackedKeyword auto hidden
Keyword property ActorTypeNPC auto hidden
Furniture property BaseMarker auto hidden
Package property DoNothing auto hidden
function ApplyCum(Actor ActorRef, int CumID) Native
function ClearCum(Actor ActorRef) Native
function AddCum(Actor ActorRef, bool Vaginal = true, bool Oral = true, bool Anal = true) Native
int function CountCum(Actor ActorRef, bool Vaginal = true, bool Oral = true, bool Anal = true) Native
function legacy_AddCum(Actor ActorRef, bool Vaginal = true, bool Oral = true, bool Anal = true) Native
Form[] function StripActor(Actor ActorRef, Actor VictimRef = none, bool DoAnimate = true, bool LeadIn = false) Native
function MakeNoStrip(Form ItemRef) Native
function MakeAlwaysStrip(Form ItemRef) Native
function ClearStripOverride(Form ItemRef) Native
function ResetStripOverrides() Native
bool function IsNoStrip(Form ItemRef) Native
bool function IsAlwaysStrip(Form ItemRef) Native
bool function IsStrippable(Form ItemRef) Native
bool function ContinueStrip(Form ItemRef, bool DoStrip = true) Native
Form function StripSlot(Actor ActorRef, int SlotMask) Native
Form[] function StripSlots(Actor ActorRef, bool[] Strip, bool DoAnimate = false, bool AllowNudesuit = true) Native
function UnstripActor(Actor ActorRef, Form[] Stripped, bool IsVictim = false) Native
int function ValidateActor(Actor ActorRef) Native
bool function CanAnimate(Actor ActorRef) Native
bool function IsValidActor(Actor ActorRef) Native
function ForbidActor(Actor ActorRef) Native
function AllowActor(Actor ActorRef) Native
bool function IsForbidden(Actor ActorRef) Native
function TreatAsMale(Actor ActorRef) Native
function TreatAsFemale(Actor ActorRef) Native
function ClearForcedGender(Actor ActorRef) Native
function TreatAsGender(Actor ActorRef, bool AsFemale) Native
int function GetTrans(Actor ActorRef) Native
int[] function GetTransAll(Actor[] Positions) Native
int[] function TransCount(Actor[] Positions) Native
int function GetGender(Actor ActorRef) Native
int[] function GetGendersAll(Actor[] Positions) Native
int[] function GenderCount(Actor[] Positions) Native
bool function IsCreature(Actor ActorRef) Native
int function MaleCount(Actor[] Positions) Native
int function FemaleCount(Actor[] Positions) Native
int function CreatureCount(Actor[] Positions) Native
int function CreatureMaleCount(Actor[] Positions) Native
int function CreatureFemaleCount(Actor[] Positions) Native
string function MakeGenderTag(Actor[] Positions) Native
string function GetGenderTag(int Females = 0, int Males = 0, int Creatures = 0) Native
function Setup() Native
float property fMaleVoiceDelay hidden AutoReadonly
float function get() Native
float property fFemaleVoiceDelay hidden AutoReadonly
float function get() Native
float property fVoiceVolume hidden AutoReadonly
float function get() Native
float property fCumTimer hidden AutoReadonly
float function get() Native
bool property bDisablePlayer hidden AutoReadonly
bool function get() Native
bool property bScaleActors hidden AutoReadonly
bool function get() Native
bool property bUseCum hidden AutoReadonly
bool function get() Native
bool property bAllowFFCum hidden AutoReadonly
bool function get() Native
bool property bUseStrapons hidden AutoReadonly
bool function get() Native
bool property bReDressVictim hidden AutoReadonly
bool function get() Native
bool property bRagdollEnd hidden AutoReadonly
bool function get() Native
bool property bUseMaleNudeSuit hidden AutoReadonly
bool function get() Native
bool property bUseFemaleNudeSuit hidden AutoReadonly
bool function get() Native
bool property bUndressAnimation hidden AutoReadonly
bool function get() Native
bool[] property bStripMale hidden AutoReadonly
bool[] function get() Native
bool[] property bStripFemale hidden AutoReadonly
bool[] function get() Native
bool[] property bStripLeadInFemale hidden AutoReadonly
bool[] function get() Native
bool[] property bStripLeadInMale hidden AutoReadonly
bool[] function get() Native
bool[] property bStripVictim hidden AutoReadonly
bool[] function get() Native
bool[] property bStripAggressor hidden AutoReadonly
bool[] function get() Native
