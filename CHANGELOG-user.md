https://github.com/GoodProvider/SkyrimNet_SexLab/releases/tag/0.33.0

Requires SkyrimNet 0.25.0 (Beta 25) or later.

- LLM actions and prompts now install as SkyrimNet plugin `goodprovider.sexlab`. After updating, it should show under Plugins as External. Leftover files in the old `prompts/` and `config/actions/` folders are ignored. Do not use Import Old Content for this mod’s files or your copy will hide later updates.
- SexLab options (hotkey, narration, rape actions, Ostim vs SexLab, and the rest) are in the SkyrimNet dashboard plugin settings. The MCM only points there. The Start Sex hotkey default is backslash (`\`). Enabling or remapping that hotkey in the dashboard applies as soon as you save; you do not need to open the MCM or reload.
- On SexLab P+, scenes this mod starts no longer hop through every matching animation. A tagged search keeps one animation, and a scene is forced to end after two minutes if enjoyment-wait would loop.
- If a scene has no animation tags, SexLab chooses the animation instead of loading the whole catalog.
- After a scene, afterglow and cum lines come from prompt files (`afterglow.prompt`, `cum.prompt`) instead of hard-coded Papyrus sentences.
    - this allows users to edit them without recompiling. 
- Orgasm narration names who is orgasming and who is not, without treating the “not orgasming” line as an orgasm.
- If SkyrimNet_Leashed is installed, the SkyMessage includes a leash optoin and open SkyrimNet_Leashed's panel 
- Change-outfit and stop action helper prompts moved under `helpers/sexlab/`. Refresh Actions in Game Data Explorer if those descriptions look missing.
