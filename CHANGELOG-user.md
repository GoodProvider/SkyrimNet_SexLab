Unreleased ⚗️

- AnimDB no longer rebuilds itself when you load a save. If it is empty or the animation count does not match SexLab, you get a notification and a dialog to Build/Rebuild or Close.
- Start Sex / Edit Stage hotkey now always closes the Control Panel if it is already open (does not matter who is selected).
- The overlay HTML is included in the installer. If it is missing, the hotkey shows a notification instead of pausing the game with a blank screen.

https://github.com/GoodProvider/SkyrimNet_SexLab/releases/tag/0.34.1

Requires SkyrimNet 0.25.0 (Beta 25 rc7) or later.

- Dom last-stage climaxes wait a few seconds (dashboard **Orgasm delay**) so the player and slave are named in one narration instead of overwriting each other.
- An orgasm that was already narrated is not repeated as a second “is orgasming” line.
- When you climax, the Dom tease line is not treated as the slave orgasming.
- A Dom melt that hits between animation stages is retried so it still reaches narration.
- Dom solo masturbation shows up in activity prompts; leftover rows after it stops are ignored.
- Empty-intent Dom scenes no longer say “finish .” with a blank activity.
- When the LLM picks the same start-sex action twice in a row, the scene still starts instead of aborting with no animation.
- Start-sex after the tag editor no longer dies silently if SexLab had marked someone “forbidden”; that flag is cleared and the scene starts unless SexLab still refuses.
- Comfort, affection, punish, and sex actions show for the LLM again (they were hidden by a broken eligibility check).
- Start Sex hotkey opens the menu when the person under the crosshair is already in a SexLab scene.
- JSON export works on older JContainers (no longer requires JC’s `toJsonString`).
