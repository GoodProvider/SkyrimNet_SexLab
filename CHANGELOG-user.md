https://github.com/GoodProvider/SkyrimNet_SexLab/releases/tag/0.34.0

Requires SkyrimNet 0.25.0 (Beta 25 rc7) or later.

- LLM actions and prompts now install as SkyrimNet plugin `goodprovider.sexlab`. After updating, it should show under Plugins as External. Leftover files in the old `prompts/` and `config/actions/` folders are ignored. Do not use Import Old Content for this mod’s files or your copy will hide later updates.
- Everything moved from MCM to SkyrimNet 
- If a scene has no animation tags, SexLab chooses the animation instead of loading the whole catalog.
- After a scene, afterglow and cum lines come from prompt files (`afterglow.prompt`, `cum.prompt`) instead of hard-coded Papyrus sentences.
    - this allows users to edit them without recompiling. 
- Orgasm narration names who is orgasming and who is not, without treating the “not orgasming” line as an orgasm.
- If SkyrimNet_Leashed is installed, the SkyMessage includes a leash option and opens SkyrimNet_Leashed’s panel. 
- Change-outfit and stop action helper prompts moved under `helpers/sexlab/`. Refresh Actions in Game Data Explorer if those descriptions look missing.
