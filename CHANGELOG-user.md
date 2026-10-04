https://github.com/GoodProvider/SkyrimNet_SexLab/releases/tag/0.35.0

Requires SkyrimNet 0.25.0 or later.

- **Prisma Hotkey**: new Prisma hotkey overlay with improved ability to animation and control a scene
- **Scene hotkeys**: when a scene is active the user will be able to effect it using the num lock hotkeys. You can change this mapping in the Plugin seetings. 
    - **hotkey overlay**: there is an optional hotkey overlay which show the current hotkey mapping during a scene
    - **NPCs can play the arousal mini-game** (when the mini-game is on): they can arouse or calm someone, and an aggressor can allow or deny orgasm. Narration now says how close someone was ("Though aroused…", "Although on the edge…").
- **orgasm minigame**: there is now an optional mini-game that allows the user to delay or encourage other actors from orgasming.
- **Style sets animation speed**: gentle, normal and forceful play slower or faster. Change it with slower / faster, the WebUI style control, or let an NPC change it (new LLM action). The old style hotkey is gone.
- **Better scene endings**: enjoyment rises more slowly, each stage change gives a small boost, and pausing pauses enjoyment. The lead needs 1 orgasm if male or 1-2 if female (adjustable **Scene ending** settings), then the scene moves to the last stage and waits there until the orgasm dialogue has played. Before the last stage, anyone who hasn't come gets one chance based on how close they are, and their climax is narrated together with the spoken reaction.
- **Moans follow speaking modifiers**: actors moan only when pleasure or pain is set; gagged or kissing actors stay quiet.
- **Right animations for the TargetMenu choice**: **cuddle** is now **affection** (romantic, can kiss), and the new **platonic** option is for friends and family. **Sex** picks consensual animations and **rapes** picks anything but affection, aggressive ones first. NPC cuddle / comfort actions no longer start sex animations.
- **Tag synonyms**: searching by tag also finds its synonyms ("doggy" finds "doggystyle"), with a **synonyms** pulldown (broad, strict, none) in the animation filters. Tag-based starts now pick randomly among all matches.
- **Devious Devices aware**: if someone wears an armbinder, yoke or other heavy bondage, scene starts prefer animations they can play, and bondage-only animations are skipped when nobody is bound.
- **One Scene view**: the WebUI shows the Description Editor when your target is in a scene, otherwise the Scene Creator. The Description Editor gained a style pulldown, a Stop button, an orgasm button per actor, clothed and actor-swap columns, an animation filter tab, and **Cancel** restores the scene as it was. Bondage is available from the TargetMenu during a scene too.
- **Clearer stop narration**: stopping a scene says who stopped it (and why, if you explain). When an NPC asks you for a scene, the Yes/No question pops up on its own, with a new **No, explain** that tells the NPC your reason.
- **Cum in character bios**: NPCs notice fresh or drying cum on someone after an orgasm.
- **Fixes**: AnimDB no longer rebuilds on every load (you get a Build/Rebuild prompt if it's out of date); NPC replies no longer fail after WebUI edits made while paused; the Description Editor no longer shows "NULL" text or loses edits on Escape; the leash option now comes from the SkyrimNet Leashed mod.

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
