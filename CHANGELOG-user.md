https://github.com/GoodProvider/SkyrimNet_SexLab/releases/tag/0.35.2

Requires SkyrimNet 0.25.0 or later (built against SkyrimNet beta26 rc4).

- **Mini-game pacing**: orgasms no longer come in the first half of a scene. Each scene's pace is set from its SexLab stage timers, so when everyone plays Mutual, both partners are close (87%) just before the last stage. Pausing, going back a stage or long dialogue add more, so more orgasms are possible. In your own scenes you have to play your part. New settings **Mini-game Mutual target** and **Mini-game passive share** (Enjoyment).
- **Shift in the mini-game**: hold **Shift** while arousing or calming to act on the next actor in the list (1→2, 2→1) without changing your focus, so you can arouse your partner and calm yourself without switching back and forth. The HUD shows ⇧ next to who the press hits.
- **Arousal follows enjoyment** (with SLO Aroused NG or OSL Aroused): during a scene, arousal never stays below enjoyment, so characters read as aroused in conversation. Arousal is only raised, never lowered. Turn off with **Arousal never below enjoyment** (Enjoyment settings).
- **Orgasm modes**: new **Orgasm mode** pulldown (Enjoyment settings, and the SkyrimNet_SexLab MCM; changing one changes the other).
  - **Always Orgasm Together at the end**: SexLab's skill, Lewd/Pure, victim/aggressor and relationship rank now matter. A skilled lover or a loved partner gets aroused faster and stays high; an unwilling victim starts slow. Everyone still finishes together at the end.
  - **Multi-Orgasm Mini-game** (default): the same bonus is a constant boost. Nobody is guaranteed an orgasm: several, or none. NPCs play the mini-game themselves using a strategy the AI picks: mutual, selfish, selfless, finish together, tease, passive; victims can reject or try to make it end quickly; aggressors can be greedy or force an orgasm, and a forced partner can give in or resist. In your scenes a notification shows each change. Strategies show on the scene HUD.
  - **Enable orgasm mini-game** is replaced by the pulldown. New installs start in Multi-Orgasm Mini-game; a saved choice is kept.
- **Force (Num .)**: when you are the aggressor, a new *force* cell under Num 3 opens a panel: "You force *victim* to *strategy* by *method*" (slap face, pinch nipple, cover mouth, punch, pull hair, or your own words). It is narrated, and for the **Fear cooldown** (default 30 s) the victim can only give in. Greyed out when the scene has no victim besides you. NPC aggressors who force someone now say how, and giving in or resisting mentions it.
- **Orgasm rolls fixed**: partners only climax together when close to the edge (enjoyment plus a small random bonus reaches 100). Before, someone at 30% enjoyment had a 30% chance. **Orgasm roll random bonus** is now under Enjoyment settings.
- **Paused time**: arousal, orgasm cooldowns and edging no longer advance while the game is paused or a menu is open.
- **Animation database check**: Settings shows how many animations the database has next to SexLab's count, and warns when they differ. The control panel title turns into a **Rebuild DB** button (**Build DB** on a new game with no database). Either button closes the menu and starts the rebuild.
- **Mismatch warning on first open**: the first time you press the menu hotkey on a save, a mismatch shows a dialog offering to rebuild. Press the hotkey again to open the menu.
- **Simpler title**: the control panel title is plain "SkyrimNet SexLab" unless extra control modes are installed.
- **Scene Creator adding actors**: clicking a nearby actor adds them again. Before, an actor could fail to join (for example as a third actor) and then stay unclickable until the menu was reopened.
- **Hug narration**: names the right hugger. When Nina hugs you, it says "Nina hugs Bob", not "Bob hugs Nina".
- **Faster menu**: the menu and the Description Editor open much faster during a scene, and stage changes refresh without lag.
- **Description Editor actors**: the orgasm, dressed, victim and speaking toggles now change only the scene you're in, right away. They're saved as the animation's defaults only when you press **Save**. Stage descriptions still save as you go.
- **Load button**: new **Load** next to Save puts the scene back to the animation's saved defaults.
- **Leash panel**: now ships with SkyrimNet_Leashed. Update SkyrimNet_Leashed together with this version, or the Leash option shows "Unknown panel: leash".

---- 
### 0.35.1 

- **Position hotkeys**: new **PgUp / PgDn** scene keys swap the actors' roles forward / back (rebindable in the Plugin settings). The hotkey overlay grows a column to show them.
- **Narrate position changes**: new option (on by default) narrates the new stage description with the actors in their new roles.
- **Description Editor**: **continue scene** now closes the WebUI after sending its narration.
- **TargetMenu cleanup**: the Stop / Stage / Position / Animation entries are gone from the in-scene Scene menu; the Description Editor and the new position hotkeys cover them. If you install by hand (not a mod manager), delete the four old files `0100_stop`, `0200_stage`, `0300_position` and `0400_animation` from the TargetMenu Scene folder.
- **Deny / allow orgasm**: the Transform option is gone. Denying and allowing are plain events again: "Bob forbids Nina from orgasming without permission." / "Bob permits Nina to orgasm."
- **Hug fix**: a single hug no longer leaves you unable to attack with your weapon (e.g. a whip) afterward. Both people now put their weapons away before hugging.
- **Newer Skyrim support**: the SKSE plugin is rebuilt for Skyrim 1.7.x / 1.7.99 and works with SkyrimNet beta26 rc4.
- **Camera**: locking the free camera (Num 3) mid-scene returns the normal third-person camera with mouse look enabled, and when a scene ends the camera goes back to the mode it was in when the scene began (first person stays first person).
- **Mouse mini-game**: right mouse now arouses and left mouse calms during mini-game scenes by default. Turn **Allow right mouse to arouse and left mouse to calm** off in the Mini-game settings to go back to keys only.

---- 
### 0.35.0 

- **Prisma Hotkey**: new Prisma hotkey overlay with improved ability to animation and control a scene
- **Scene hotkeys**: when a scene is active the user will be able to effect it using the num lock hotkeys. You can change this mapping in the Plugin seetings. 
    - **hotkey overlay**: there is an optional hotkey overlay which show the current hotkey mapping during a scene
    - **NPCs can play the arousal mini-game** (when the mini-game is on): they can arouse or calm someone, and an aggressor can allow or deny orgasm. Narration now says how close someone was ("Though aroused…", "Although on the edge…").
- **orgasm minigame**: there is now an optional mini-game that allows the user to delay or encourage other actors from orgasming.
- **Style sets animation speed**: gentle, normal and forceful play slower or faster. Change it with slower / faster, the WebUI style control, or let an NPC change it (new LLM action). The old style hotkey is gone.
