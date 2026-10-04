https://github.com/GoodProvider/SkyrimNet_SexLab/releases/tag/0.35.1

Requires SkyrimNet 0.25.0 or later (built against SkyrimNet beta26 rc4).

- **Position hotkeys**: new **PgUp / PgDn** scene keys swap the actors' roles forward / back (rebindable in the Plugin settings). The hotkey overlay grows a column to show them.
- **Narrate position changes**: new option (on by default) narrates the new stage description with the actors in their new roles.
- **Description Editor**: **continue scene** now closes the WebUI after sending its narration.
- **TargetMenu cleanup**: the Stop / Stage / Position / Animation entries are gone from the in-scene Scene menu; the Description Editor and the new position hotkeys cover them. If you install by hand (not a mod manager), delete the four old files `0100_stop`, `0200_stage`, `0300_position` and `0400_animation` from the TargetMenu Scene folder.
- **Deny / allow orgasm**: the Transform option is gone. Denying and allowing are plain events again: "Bob forbids Nina from orgasming without permission." / "Bob permits Nina to orgasm."
- **Hug fix**: a single hug no longer leaves you unable to attack with your weapon (e.g. a whip) afterward. Both people now put their weapons away before hugging.
- **Newer Skyrim support**: the SKSE plugin is rebuilt for Skyrim 1.7.x / 1.7.99 and works with SkyrimNet beta26 rc4.
- **Camera**: locking the free camera (Num 3) mid-scene returns the normal third-person camera with mouse look enabled, and when a scene ends the camera goes back to the mode it was in when the scene began (first person stays first person).
- **Mouse mini-game**: right mouse now arouses and left mouse calms during mini-game scenes by default. Turn **Allow right mouse to arouse and left mouse to calm** off in the Mini-game settings to go back to keys only.
