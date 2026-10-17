https://github.com/GoodProvider/SkyrimNet_SexLab/releases/tag/0.36.0

Requires SkyrimNet 0.25.0 or later (built against SkyrimNet beta26 rc4).

## 0.36.1

### AnimDB bug (untested)
- **AnimDB empty on 0.36.0 (SexLab P+ and 1.6x)**: the 0.36.0 `Scripts/*.pex` were built with `compile: papyrus` (papyrus.exe), which stores the Papyrus literal `"\""` as backslash+quote. Every JSON string built in Papyrus broke, including every `AnimDb_PushAnimBatch` batch, so `EndSync` kept 0 rows. The pex files are rebuilt with pyro, and **`compile: pyro` is the default build task again**. It now uses `C:/Skyrim/tools/Pyro/pyro.exe`; the VS Code extension no longer ships pyro.
- **`make check-pex`** (`python_scripts/check_pex_escapes.py`) fails on any pex with a literal `\"`. `make release` runs it first.
- **`AnimDb_PushAnimBatch`** now logs the parse error, byte offset and nearby text. On a parse failure it retries once with `\"` unescaped, so a bad build still fills the DB. `EndSync` errors when every batch failed to parse.
- `FinishSourceOrDone` notifies "AnimDB build failed" when 0 rows are stored, and its misleading `duplicates=` is renamed `not_stored=`.
- Temporary P+ / AnimDB instrumentation is tagged **`DEBUG-DELETE(pplus-animdb)`**: per-sync batch/row counters, `AnimDb_LastSyncFailures`, `SkyrimNet_SexLab_PPlus.SceneDebug`, first-batch JSON trace, and skipped-id traces. See `checkpoints/pplus_animdb/checkpoint_v01.md`.

### Dead Actor bug (untested)
- **Corpses on SexLab 1.6x**: `sslActorAlias` OnUpdate ends the thread (`EndAnimation(true)`) for an actor that `IsDead() && Health < 1`. `Utilities.CorpseHealth_Floor` raises a corpse to Health 2 before `AddActor` and at each `StageStart`; `CorpseHealth_Restore` puts it back in `Scene.AnimationEnd` (StorageUtil float `skyrimnet_sexlab_corpse_health`). No-op on P+. Temporary instrumentation is tagged **`NECRO-DBG`**; see `checkpoints/necro-animations/checkpoint-v01.md`.

## 0.36.0

### Injury Engine
- **Injury Engine** (optional, formerly SkyrimNet_Whipped): Punish wounds the chosen body part, Aid heals it, and the panels show a torture bar per part. With Injury Engine the spell methods are Flames, Frostbite and Sparks (torture), and a Hits box lands several hits.

### SexLab P+ (untested)
- **SexLab P+ support**: the animation database fills from P+, scenes end after the orgasms instead of looping, pause and stage keys work, and animation / actor changes keep the scene going. See docs/developers/sexlab-pplus.md.

### Force/Punish/Ask/Order
- **Force is now Ask / Order / Punish** (Num .): ask or order someone in the scene to change how they play; they agree or refuse, and a refusal can be punished. Anyone can punish anyone in any scene, with or without the mini-game. Punish sets no strategy: the punished NPC's decision picks the reaction. NPCs punish with the new `SexLab_Scene_Punish` action; `SexLab_Force` is gone.

### Aid
- **Aid** moves to Num Enter: pick caster and target, and healing spells channel up to a chosen number of points.

### NPC strategy
- **Strategies come from `strategies.json`**: passive, mutual, selfish, selfless, deny self, deny all, deny, tease, focused, nonsexual, open to every role. Together, Greedy, Forced orgasm, Accept force, Hold back, Cum quick, the forced state and mental break are gone. **API break** in `OrgasmEngineAPI.h` (Strategy ids, `IsMentallyBroken`, `kMentalBreak`).
- **Decision prompts** read one timeline of recent speech, thoughts and events instead of the current approach.

### Disable OrgasmEngine
- **Engine off switch** (`sexlab.enjoyment.engine_disabled`): SexLab / SLSO decide enjoyment and orgasms again; the mod only narrates.

### SLO Arouse
- **Arousal and orgasm fixes**: SLO Aroused NG now gets relief for every engine orgasm in Combined mode; SLSO edging no longer swallows our orgasms.

### Bug Fixes
- **Locks cleared on load**: SexLab cancels every scene when a save loads, so actor locks and half-started Scene Creator sessions from the save are released instead of restored.

### WebUI
- **Scenes**: an animation change on SexLab 1.6x restarts at stage 1; animation favorites; Description Editor Start button; Clean Cum option and `sexlab_clean_cum` action; Bondage panel Start handles devices outside `group-devices.json`.
- **Install**: the legacy pre-Beta-25 `config/actions` and `prompts` copies are removed; everything ships in `external/goodprovider.sexlab/`.

### Narration
- **One start narration**: `Scene.AnimationStart` no longer sends a "sexlab update" event with the stage description; the following StageStart's start / change narration is the only one. An NPC-only start the player can see (`Scene.PlayerSeesScene`: within `sexlab.narration.max_distance` and in line of sight) is always a DirectNarration, skipping the cooldown.
- **Narration levels**: start, stage, orgasm, end, position, style and strategy / request narrations can each be Direct, Event, ShortEvent or Silent.

### Inja
- **Inja line breaks**: text sent to SkyrimNet's `ParseString` now goes through `Utilities.ParseInja`, which calls the new native `InjaPrepare` to turn a literal backslash+`n` (how `compile: papyrus` stores a Papyrus newline escape) into a real line break. Do not call `SkyrimNetApi.ParseString` directly.

## 0.35.2

- **Quieter Arouse / Calm**: arousing or calming someone no longer makes anyone speak or adds a line to the orgasm narration; NPCs just briefly know it happened.
- **Simpler sex / affection picks**: animations with any sex act are now tagged *sexual* (the list is in `sex_tags.json`). The TargetMenu's *sex* is now *sexual*, with no sub-choices. *Affection* and *platonic* just leave out sexual animations, and platonic leaves out kissing too. While Scene Creator is open, clicking *sexual*, *affection* or *platonic* sets the creator's tag filters instead of opening their panel. *Custom* opens Scene Creator already filtered to *sexual*.
- **Scene Creator only lists free actors**: actors already in a scene, or just picked for one that is starting, are no longer offered. In the Control Panel they show as *Name (SexLab)* or *Name (locked)*. Nearby actors you can't pick are greyed out with the reason, e.g. *Name (Ostim)*, *Name (Dead)*, *Name (Combat)*.
  - **Scene Creator adding actors**: clicking a nearby actor adds them again. Before, an actor could fail to join (for example as a third actor) and then stay unclickable until the menu was reopened.
- **Take control (Num \*)**: a new key, shown above Num - on the HUD.
  - **Auto play**: in your own scene, press it to let the AI play you (the cell then reads *control*). It picks how you behave, presses the HUD keys for you (stage, speed, pause, deny, end, aid, force, including what to pick in the Aid and Force panels), and after someone speaks it may have you answer. You can still press any key yourself. Press again to take back control. Needs the Multi-Orgasm Mini-game and a SkyrimNet decisions provider.
  - **Control an NPC**: aim at someone in a scene you're not in and press it. The HUD shows that scene "as *name*", and your keys act as that NPC (their stamina and magicka pay). Press again to let go.
- **NPC strategies by the decision model**: in the Multi-Orgasm Mini-game, SkyrimNet's decision model (for example Jev) now picks how each NPC plays: for everyone when a scene starts, and again for an NPC after each line they speak. It weighs the NPC's personality, role, what was just said, how the scene came about, and their Skyrim relationship with each partner. The old strategy actions are gone. Others in the scene may notice a change ("Lydia appears to be focused on her own enjoyment."); there is no popup notification. Needs a **decisions** provider in SkyrimNet; without one, NPCs keep the default strategies. Turn off with **Decision model picks NPC strategies** (Mini-game settings). The model only changes a strategy when it is fairly sure; set how sure with **Decision minimum confidence** (Mini-game settings, default 0.6).
- **Mini-game pacing**: orgasms no longer come in the first half of a scene. Each scene's pace is set from its SexLab stage timers, so when everyone plays Mutual, both partners are close (87%) just before the last stage. Pausing, going back a stage or long dialogue add more, so more orgasms are possible. In your own scenes you have to play your part. New settings **Mini-game Mutual target** and **Mini-game passive share** (Enjoyment).
  - **Orgasm rolls fixed**: partners only climax together when close to the edge (enjoyment plus a small random bonus reaches 100). Before, someone at 30% enjoyment had a 30% chance. **Orgasm roll random bonus** is now under Enjoyment settings.
  - **Paused time**: arousal, orgasm cooldowns and edging no longer advance while the game is paused or a menu is open.
- **Endings when the AI plays everyone**: in the mini-game, when no one is under your control (NPC scenes, or you on auto play), there can still be orgasms along the way, but the last one now comes at the end of the second-to-last stage, and the last stage waits until the reaction to it has been spoken. Uses **Orgasm check before the last stage** (Scene ending settings).
  - The last stage now ends as soon as the reply to the orgasm has been spoken, never more than 30 s later (**Hold last stage for orgasm dialogue**, now 30 s at most).
  - **Auto play stays on** for your later scenes, and across saves, until you press Num \* again. On auto play you no longer always play passive.
  - With a victim, the aggressor always climaxes at the end of the second-to-last stage, even after an earlier orgasm. Whether the victim does depends on the aggressor: forcing an orgasm makes them, teasing holds them back, otherwise it's a roll.
  - Fixed a scene that could stay on its last stage forever after the orgasm reply: it now ends at most 15 s after the last stage's normal time (unless you paused it).
- **Orgasm modes**: new **Orgasm mode** pulldown (Enjoyment settings, and the SkyrimNet_SexLab MCM; changing one changes the other).
  - **Always Orgasm Together at the end**: SexLab's skill, Lewd/Pure, victim/aggressor and relationship rank now matter. A skilled lover or a loved partner gets aroused faster and stays high; an unwilling victim starts slow. Everyone still finishes together at the end.
  - **Multi-Orgasm Mini-game** (default): the same bonus is a constant boost. Nobody is guaranteed an orgasm: several, or none. NPCs play the mini-game themselves using a strategy the AI picks: mutual, selfish, selfless, finish together, tease, passive; victims can reject or try to make it end quickly; aggressors can be greedy or force an orgasm, and a forced partner can give in or resist. Strategies show on the scene HUD.
  - **Enable orgasm mini-game** is replaced by the pulldown. New installs start in Multi-Orgasm Mini-game; a saved choice is kept.
- **Aid and Force keys**:
  - **Aid (Num 0)**: in the mini-game, a new *aid* cell under Num 1 opens a panel: "*You* *spell or potion* on *actor*". Cast one of your healing or stamina spells (it costs its magicka) or use a healing or stamina potion on yourself or anyone in the scene. It is narrated. Greyed out when you have none.
  - **Force (Num .)**: when you are the aggressor, a new *force* cell under Num 3 opens a panel: "You force *victim* to *strategy* by *method*" (slap, pinch, punch, pull, or your own words). It is narrated, and for the **Fear cooldown** (default 2 s) the victim can only give in. Greyed out when the scene has no victim besides you. NPC aggressors who force someone now say how, and giving in or resisting mentions it.
  - **Where in Aid and Force**: both panels add a body-part pulldown (body, pussy, ass, nipples, or your own words). The effect is the same; the narration says where ("Bob casts Healing on Nina's pussy.", "Bob slaps Nina's ass and forces Nina to please him."). *body* keeps the old wording. Force methods are now slap, pinch, punch and pull (cover mouth is gone); the body part says where.
  - **Weak spells in Force**: the Force panel also lists your Novice and Apprentice attack spells (Flames, Sparks, …). The victim takes the spell's smallest damage, never enough to kill, and doesn't turn hostile.
  - **You can see Aid and Force spells**: healing glows, fire / frost / shock flashes, the caster's hand effects and the spell sounds now play on the actors. The spell still never starts a fight.
  - **NPCs aid and force too**: the AI can have an actor heal or restore someone in the scene with their own spells or potions, and have an aggressor force a victim, with the same rules as your keys.
- **Shift in the mini-game**: hold **Shift** while arousing or calming to act on the next actor in the list (1→2, 2→1) without changing your focus, so you can arouse your partner and calm yourself without switching back and forth. The HUD shows ⇧ next to who the press hits.
- **Arousal follows enjoyment** (with SLO Aroused NG or OSL Aroused): during a scene, arousal never stays below enjoyment, so characters read as aroused in conversation. Arousal is only raised, never lowered. Turn off with **Arousal never below enjoyment** (Enjoyment settings).
- **Animation database check**: Settings shows how many animations the database has next to SexLab's count, and warns when they differ. The control panel title turns into a **Rebuild DB** button (**Build DB** on a new game with no database). Either button closes the menu and starts the rebuild.
  - **Mismatch warning on first open**: the first time you press the menu hotkey on a save, a mismatch shows a dialog offering to rebuild. Press the hotkey again to open the menu.
- **Hugs and stage keys**:
  - **Hug narration**: names the right hugger. When Nina hugs you, it says "Nina hugs Bob", not "Bob hugs Nina".
  - **Hugs no longer break scenes**: an NPC can't hug, kiss or start a scene with someone who is already in a SexLab or OStim scene. Before, a bystander hugging a scene partner pulled them out of the animation.
  - **Next / previous stage keys**: a press while SexLab is still switching stages is now ignored instead of acting on the old stage. The log also records more about stage changes, to track down a report of scenes falling back to stage 1.
- **Menus**:
  - **Faster menu**: the menu and the Description Editor open much faster during a scene, and stage changes refresh without lag.
  - **TargetMenu no longer flickers**: a panel opened by hovering now stays open for a second while you move the mouse toward it. Hovering another entry in the same list still switches right away. Moving down a panel's fields no longer makes the panel itself blink.
  - **Simpler title**: the control panel title is plain "SkyrimNet SexLab" unless extra control modes are installed.
  - **Description Editor actors**: the orgasm, dressed, victim and speaking toggles now change only the scene you're in, right away. They're saved as the animation's defaults only when you press **Save**. Stage descriptions still save as you go.
  - **Load button**: new **Load** next to Save puts the scene back to the animation's saved defaults.
- **Leash panel**: now ships with SkyrimNet_Leashed. Update SkyrimNet_Leashed together with this version, or the Leash option shows "Unknown panel: leash".

---- 
## 0.35.1 

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
## 0.35.0 

- **Prisma Hotkey**: new Prisma hotkey overlay with improved ability to animation and control a scene
- **Scene hotkeys**: when a scene is active the user will be able to effect it using the num lock hotkeys. You can change this mapping in the Plugin seetings. 
    - **hotkey overlay**: there is an optional hotkey overlay which show the current hotkey mapping during a scene
    - **NPCs can play the arousal mini-game** (when the mini-game is on): they can arouse or calm someone, and an aggressor can allow or deny orgasm. Narration now says how close someone was ("Though aroused…", "Although on the edge…").
- **orgasm minigame**: there is now an optional mini-game that allows the user to delay or encourage other actors from orgasming.
- **Style sets animation speed**: gentle, normal and forceful play slower or faster. Change it with slower / faster, the WebUI style control, or let an NPC change it (new LLM action). The old style hotkey is gone.
