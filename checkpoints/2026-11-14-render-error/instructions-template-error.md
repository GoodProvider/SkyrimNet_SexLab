# Fix for the "0050_sexlab_activity" RenderTemplate error

Thanks for the logs. They show what's going on.

## What's happening

Your SkyrimNet.log has this error every time SkyrimNet builds a full prompt during a SexLab scene:

    RenderTemplate : Exception during rendering of template 'submodules/user_final_instructions/0050_sexlab_activity'
    [json.exception.out_of_range.404] unresolved reference token 'source'

The `0550_sexlab_narration` prompt fails the same way.

Your log shows SkyrimNet **1.0.0**. On that version, the scene data SkyrimNet_SexLab gives to the prompt arrives in the wrong form, and the prompt breaks. On SkyrimNet 1.1.1 and later this doesn't happen.

Your log also shows SkyrimNet_SexLab **0.37.0**. The current release is 0.37.3.

## What to do

1. Update **SkyrimNet** to **1.1.1 or newer**.
2. Update **SkyrimNet_SexLab** to **0.37.3** or newer. The next release also makes these two prompts handle this case without erroring.
3. Start a new game session, start a SexLab scene, and talk to someone in the scene.

## If the error still shows up

1. Turn on **Verbose** logging in SkyrimNet.
2. Reproduce the error: start a SexLab scene and talk to a participant.
3. Quit the game, then send these two files **from that same session**:
   - `SkyrimNet.log`
   - `SkyrimNet_SexLab.log`

   Both are in `Documents\My Games\Skyrim Special Edition\SKSE\`.

`Papyrus.0.log` isn't needed for this issue.

Please also say which SkyrimNet and SkyrimNet_SexLab versions you have installed.
