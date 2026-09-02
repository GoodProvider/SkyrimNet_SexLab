Unreleased ⚗️

- AnimDB no longer rebuilds itself when you load a save. If it is empty or the animation count does not match SexLab, you get a notification and a dialog to Build/Rebuild or Close.
- Start Sex / Edit Stage hotkey now always closes the Control Panel if it is already open (does not matter who is selected).
- The overlay HTML is included in the installer. If it is missing, the hotkey shows a notification instead of pausing the game with a blank screen.

https://github.com/GoodProvider/SkyrimNet_SexLab/releases/tag/0.31.5

- In scenes with a victim, the victim is no longer treated as the person who started the scene.
- SexLab scenes started by DOM or other mods keep their activity description instead of going blank on the first frame.
- During pain or pleasure, NPCs still use one or two vocalizations, but not one stuffed into every few words.
- Those lines stay short (nine words or less; vocalizations do not count).
- When narration is on, the narrative sentence can be a bit longer (up to twenty words) and should move the action forward.

https://github.com/GoodProvider/SkyrimNet_SexLab/releases/tag/0.31.4 ⚗️

- Giving sex actions now ship the missing `no_penis` scene file (suppresses vaginal/anal tags).
- SkyrimNet exposes an orgasm-delay setting for this plugin.
- Docs moved under `docs/` with a short README and agent router (`llms.txt`).
