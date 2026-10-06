scriptname sslSystemLibrary extends Quest hidden
sslSystemConfig property Config auto
sslActorLibrary property ActorLib auto
sslThreadLibrary property ThreadLib auto
sslActorStats property Stats auto
sslThreadSlots property ThreadSlots auto
sslAnimationSlots property AnimSlots auto
sslCreatureAnimationSlots property CreatureSlots auto
sslVoiceSlots property VoiceSlots auto
sslExpressionSlots property ExpressionSlots auto
Actor property PlayerRef auto
function LoadLibs(bool Forced = false) Native
function Setup() Native
bool property InDebugMode auto hidden
function Log(string msg, string Type = "NOTICE") Native
