Unreleased ⚗️

- Target Menu: **cuddle** is now **affection** (romantic, can kiss), and the new **platonic** option is for friends and family (cuddle, hug, head pat, hold hands, no kissing). **sex** only picks consensual sex animations, **punish** spanks any genders, and **rapes** picks anything except affection animations, aggressive ones first. Pressing Start without choosing a method now stays inside the option instead of picking any animation.
- Animations made for Devious Devices bondage are only chosen when someone in the scene is wearing it.
- Scene setting files can use tag synonyms (broad by default) and new keys such as `tags_any` and `exclude_settings`; see the scene settings doc.
- Scene keys moved to the numpad: 7 previous, 8 pause, 9 next, 4 calm, 5 arouse, 6 deny, - slower, + faster, 1 end (3 stays SexLab's free camera). They work with NumLock on or off. The style hotkey is gone; use slower / faster. The game writes your current keys to `SKSE/Plugins/SkyrimNet_SexLab/hotkey-map.json`; see the README for the layout.
- Enjoyment rises much more slowly, so actors no longer orgasm over and over. Each stage change gives a small boost. Just before the last stage, anyone who hasn't come gets one chance to, based on how close they are; if they do, the scene moves straight to the last stage.
- New **Scene ending** settings: the lead (the aggressor if there is a victim, otherwise whoever started it) needs 1 orgasm if male or 1-2 if female (adjustable). Once they get there, the scene jumps to the last stage and waits there until the orgasm dialogue has finished playing. If you saved the Enjoyment settings before, reset them to get the new defaults. Pausing a stage now also pauses enjoyment.
- Tag synonyms: searching animations by tag now also finds that tag's synonyms. For example, "doggy" finds "doggystyle" animations, and "titjob" finds "boobjob". This applies to LLM scene starts and to the Scene Creator / Description Editor animation filters. A new **synonyms** pulldown in those filters picks broad (default), strict, or none (exact tags only). You can edit the lists in `SKSE/Plugins/SkyrimNet_SexLab/synonyms-broad.json` and `synonyms-strict.json`; the edits load when you load a save.
- Scenes started from tags now choose randomly among all matching animations, not the same alphabetical few.
- New setting **Devious devices are added to tags** (on by default): if someone in the scene wears an armbinder, yoke, front cuffs or other heavy bondage, scenes started from the TargetMenu (any method, random, Custom, DOM punish) prefer animations they can play, and the Scene Creator and Description Editor animation filter start with that tag. A tag with no matching animation is dropped, and in the Scene Creator you can always remove the tags yourself.
- AnimDB no longer rebuilds itself when you load a save. If it is empty or the animation count does not match SexLab, you get a notification and a dialog to Build/Rebuild or Close.
- Start Sex / Edit Stage hotkey now always closes the Control Panel if it is already open (does not matter who is selected).
- When an NPC starts a scene with you, the Yes/No question now appears by itself. If the WebUI is open it pops up on top, and the WebUI stays as it was after you answer; if the WebUI is closed, only the question is shown. **Yes** opens the Scene Creator, **Yes (Random)** starts a random scene, **No (Silent)** and **No** close it (No narrates your refusal). New **No, explain**: type a reason and press Accept, and the NPC hears "Bob rejects Nina's request for ..., because <your reason>." Cancel goes back to the question.
- The overlay HTML is included in the installer. If it is missing, the hotkey shows a notification instead of pausing the game with a blank screen.
- Description Editor stage text boxes: click and drag to select text (follows line wrap in either direction); Shift+click extends, double-click selects a word.
- LLM actions and prompts ship in both the Beta 25 plugin folder and the older SkyrimNet folders, so this version still works on pre-0.25 SkyrimNet.

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
