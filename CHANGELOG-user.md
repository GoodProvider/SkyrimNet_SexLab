https://github.com/GoodProvider/SkyrimNet_SexLab/releases/tag/0.35.2

Requires SkyrimNet 0.25.0 or later (built against SkyrimNet beta26 rc4).

- **Simpler sex / affection picks**: animations with any sex act are now tagged *sexual* (the list is in `sex_tags.json`). The TargetMenu's *sex* is now *sexual*, with no sub-choices. *Affection* and *platonic* just leave out sexual animations, and platonic leaves out kissing too. While Scene Creator is open, clicking *sexual*, *affection* or *platonic* sets the creator's tag filters instead of opening their panel. *Custom* opens Scene Creator already filtered to *sexual*.
- **Scene Creator only lists free actors**: actors already in a scene, or just picked for one that is starting, are no longer offered. In the Control Panel they show as *Name (SexLab)* or *Name (locked)*. Nearby actors you can't pick are greyed out with the reason, e.g. *Name (Ostim)*, *Name (Dead)*, *Name (Combat)*.
- **Take control (Num \*)**: a new key, shown above Num - on the HUD.
  - **Auto play**: in your own scene, press it to let the AI play you (the cell then reads *control*). It picks how you behave, presses the HUD keys for you (stage, speed, pause, deny, end, aid, force, including what to pick in the Aid and Force panels), and after someone speaks it may have you answer. You can still press any key yourself. Press again to take back control. Needs the Multi-Orgasm Mini-game and a SkyrimNet decisions provider.
  - **Control an NPC**: aim at someone in a scene you're not in and press it. The HUD shows that scene "as *name*", and your keys act as that NPC (their stamina and magicka pay). Press again to let go.
- **NPC strategies by the decision model**: in the Multi-Orgasm Mini-game, SkyrimNet's decision model (for example Jev) now picks how each NPC plays: for everyone when a scene starts, and again for an NPC after each line they speak. It weighs the NPC's personality, role, what was just said, how the scene came about, and their Skyrim relationship with each partner. The old strategy actions are gone. Each change shows a notification, and others in the scene notice it ("Lydia appears to be focused on her own enjoyment."). Needs a **decisions** provider in SkyrimNet; without one, NPCs keep the default strategies. Turn off with **Decision model picks NPC strategies** (Mini-game settings). The model only changes a strategy when it is fairly sure; set how sure with **Decision minimum confidence** (Mini-game settings, default 0.6).
- **Mini-game pacing**: orgasms no longer come in the first half of a scene. Each scene's pace is set from its SexLab stage timers, so when everyone plays Mutual, both partners are close (87%) just before the last stage. Pausing, going back a stage or long dialogue add more, so more orgasms are possible. In your own scenes you have to play your part. New settings **Mini-game Mutual target** and **Mini-game passive share** (Enjoyment).
- **Endings when the AI plays everyone**: in the mini-game, when no one is under your control (NPC scenes, or you on auto play), there can still be orgasms along the way, but the last one now comes at the end of the second-to-last stage, and the last stage waits until the reaction to it has been spoken. Uses **Orgasm check before the last stage** (Scene ending settings).
  - The last stage now ends as soon as the reply to the orgasm has been spoken, never more than 30 s later (**Hold last stage for orgasm dialogue**, now 30 s at most).
  - **Auto play stays on** for your later scenes, and across saves, until you press Num \* again. On auto play you no longer always play passive.
  - With a victim, the aggressor always climaxes at the end of the second-to-last stage, even after an earlier orgasm. Whether the victim does depends on the aggressor: forcing an orgasm makes them, teasing holds them back, otherwise it's a roll.
  - Fixed a scene that could stay on its last stage forever after the orgasm reply: it now ends at most 15 s after the last stage's normal time (unless you paused it).
- **Shift in the mini-game**: hold **Shift** while arousing or calming to act on the next actor in the list (1→2, 2→1) without changing your focus, so you can arouse your partner and calm yourself without switching back and forth. The HUD shows ⇧ next to who the press hits.
- **Arousal follows enjoyment** (with SLO Aroused NG or OSL Aroused): during a scene, arousal never stays below enjoyment, so characters read as aroused in conversation. Arousal is only raised, never lowered. Turn off with **Arousal never below enjoyment** (Enjoyment settings).
- **Orgasm modes**: new **Orgasm mode** pulldown (Enjoyment settings, and the SkyrimNet_SexLab MCM; changing one changes the other).
  - **Always Orgasm Together at the end**: SexLab's skill, Lewd/Pure, victim/aggressor and relationship rank now matter. A skilled lover or a loved partner gets aroused faster and stays high; an unwilling victim starts slow. Everyone still finishes together at the end.
  - **Multi-Orgasm Mini-game** (default): the same bonus is a constant boost. Nobody is guaranteed an orgasm: several, or none. NPCs play the mini-game themselves using a strategy the AI picks: mutual, selfish, selfless, finish together, tease, passive; victims can reject or try to make it end quickly; aggressors can be greedy or force an orgasm, and a forced partner can give in or resist. Strategies show on the scene HUD.
  - **Enable orgasm mini-game** is replaced by the pulldown. New installs start in Multi-Orgasm Mini-game; a saved choice is kept.
- **Aid (Num 0)**: in the mini-game, a new *aid* cell under Num 1 opens a panel: "*You* *spell or potion* on *actor*". Cast one of your healing or stamina spells (it costs its magicka) or use a healing or stamina potion on yourself or anyone in the scene. It is narrated. Greyed out when you have none.
- **Weak spells in Force**: the Force panel also lists your Novice and Apprentice attack spells (Flames, Sparks, …). The victim takes the spell's smallest damage, never enough to kill, and doesn't turn hostile.
- **You can see Aid and Force spells**: healing glows, fire / frost / shock flashes, the caster's hand effects and the spell sounds now play on the actors. The spell still never starts a fight.
- **NPCs aid and force too**: the AI can have an actor heal or restore someone in the scene with their own spells or potions, and have an aggressor force a victim, with the same rules as your keys.
- **Force (Num .)**: when you are the aggressor, a new *force* cell under Num 3 opens a panel: "You force *victim* to *strategy* by *method*" (slap face, pinch nipple, cover mouth, punch, pull hair, or your own words). It is narrated, and for the **Fear cooldown** (default 30 s) the victim can only give in. Greyed out when the scene has no victim besides you. NPC aggressors who force someone now say how, and giving in or resisting mentions it.
- **Where in Aid and Force**: both panels add a body-part pulldown (body, pussy, ass, nipples, or your own words). The effect is the same; the narration says where ("Bob casts Healing on Nina's pussy.", "Bob slaps Nina's ass and forces Nina to please him."). *body* keeps the old wording. Force methods are now slap, pinch, punch and pull (cover mouth is gone); the body part says where.
- **Orgasm rolls fixed**: partners only climax together when close to the edge (enjoyment plus a small random bonus reaches 100). Before, someone at 30% enjoyment had a 30% chance. **Orgasm roll random bonus** is now under Enjoyment settings.
- **Paused time**: arousal, orgasm cooldowns and edging no longer advance while the game is paused or a menu is open.
- **Animation database check**: Settings shows how many animations the database has next to SexLab's count, and warns when they differ. The control panel title turns into a **Rebuild DB** button (**Build DB** on a new game with no database). Either button closes the menu and starts the rebuild.
- **Mismatch warning on first open**: the first time you press the menu hotkey on a save, a mismatch shows a dialog offering to rebuild. Press the hotkey again to open the menu.
- **Simpler title**: the control panel title is plain "SkyrimNet SexLab" unless extra control modes are installed.
- **Scene Creator adding actors**: clicking a nearby actor adds them again. Before, an actor could fail to join (for example as a third actor) and then stay unclickable until the menu was reopened.
- **Hug narration**: names the right hugger. When Nina hugs you, it says "Nina hugs Bob", not "Bob hugs Nina".
- **Hugs no longer break scenes**: an NPC can't hug, kiss or start a scene with someone who is already in a SexLab or OStim scene. Before, a bystander hugging a scene partner pulled them out of the animation.
- **Next / previous stage keys**: a press while SexLab is still switching stages is now ignored instead of acting on the old stage. The log also records more about stage changes, to track down a report of scenes falling back to stage 1.
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
- **TargetMenu no longer flickers**: a panel opened by hovering now stays open for a second while you move the mouse toward it. Hovering another entry in the same list still switches right away. Moving down a panel's fields no longer makes the panel itself blink.
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
