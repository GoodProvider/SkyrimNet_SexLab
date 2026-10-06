scriptname sslObjectFactory extends sslSystemLibrary
int function Male() global Native
int function Female() global Native
int function MaleFemale() global Native
int function Creature() global Native
int function CreatureMale() global Native
int function CreatureFemale() global Native
int function Vaginal() global Native
int function Oral() global Native
int function Anal() global Native
int function VaginalOral() global Native
int function VaginalAnal() global Native
int function OralAnal() global Native
int function VaginalOralAnal() global Native
Sound function Squishing() global Native
Sound function Sucking() global Native
Sound function SexMix() global Native
Sound function Squirting() global Native
int function Phoneme() global Native
int function Modifier() global Native
int function Expression() global Native
sslBaseAnimation[] function GetOwnerAnimations(Form Owner) Native
sslBaseAnimation function NewAnimation(string Token, Form Owner) Native
sslBaseAnimation function GetSetAnimation(string Token, string Callback, Form Owner) Native
sslBaseAnimation function NewAnimationCopy(string Token, sslBaseAnimation CopyFrom, Form Owner) Native
sslBaseAnimation function GetAnimation(string Token) Native
int function FindAnimation(string Token) Native
bool function HasAnimation(string Token) Native
bool function ReleaseAnimation(string Token) Native
int function ReleaseOwnerAnimations(Form Owner) Native
sslBaseAnimation function MakeAnimationRegistered(string Token) Native
sslBaseVoice[] function GetOwnerVoices(Form Owner) Native
sslBaseVoice function NewVoice(string Token, Form Owner) Native
sslBaseVoice function GetSetVoice(string Token, string Callback, Form Owner) Native
sslBaseVoice function NewVoiceCopy(string Token, sslBaseVoice CopyFrom, Form Owner) Native
sslBaseVoice function GetVoice(string Token) Native
int function FindVoice(string Token) Native
bool function HasVoice(string Token) Native
bool function ReleaseVoice(string Token) Native
int function ReleaseOwnerVoices(Form Owner) Native
sslBaseVoice function MakeVoiceRegistered(string Token) Native
sslBaseExpression[] function GetOwnerExpressions(Form Owner) Native
sslBaseExpression function NewExpression(string Token, Form Owner) Native
sslBaseExpression function GetSetExpression(string Token, string Callback, Form Owner) Native
sslBaseExpression function NewExpressionCopy(string Token, sslBaseExpression CopyFrom, Form Owner) Native
sslBaseExpression function GetExpression(string Token) Native
int function FindExpression(string Token) Native
bool function HasExpression(string Token) Native
bool function ReleaseExpression(string Token) Native
int function ReleaseOwnerExpressions(Form Owner) Native
sslBaseExpression function MakeExpressionRegistered(string Token) Native
function SendCallback(string Token, int Slot, Form CallbackForm = none, ReferenceAlias CallbackAlias = none) global Native
function Setup() Native
function Cleanup() Native
sslBaseAnimation function CopyAnimation(sslBaseAnimation Copy, sslBaseAnimation Orig) Native
sslBaseVoice function CopyVoice(sslBaseVoice Copy, sslBaseVoice Orig) Native
sslBaseExpression function CopyExpression(sslBaseExpression Copy, sslBaseExpression Orig) Native
int function Misc() global Native
int function Sexual() global Native
int function Foreplay() global Native
