Scriptname MfgConsoleFuncExt Hidden

; HEADER ONLY for skyrimse-pplus.ppj: P+ sslExpressionUtil references MFG Fix NG's script. Signatures cover P+'s calls.

bool Function SetModifier(Actor act, int id, int value, int speed) native global
bool Function SetPhoneme(Actor act, int id, int value, int speed) native global
bool Function SetExpression(Actor act, int mood, int strength) native global
Function ApplyExpressionPresetSmooth(Actor akActor, float[] expression, bool openMouth, int exprPower, int exprStrModifier, int modStrModifier, int phStrModifier, float speed) native global
bool Function ResetMFG(Actor act) native global
bool Function ResetPhonemes(Actor act) native global
bool Function ResetModifiers(Actor act) native global
