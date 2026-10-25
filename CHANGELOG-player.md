https://github.com/GoodProvider/SkyrimNet_SexLab/releases/tag/0.36.5

Requires SkyrimNet 0.25.0+ (built against beta26 rc4).

## 0.36.5

### Aid
- Food, drink and ingredients that restore health or stamina can be used as Aid, like potions
- The Aid panel opens on the most damaged body part
- Aid and Punish can target the throat (Injury Engine: lungs)

### NPC strategy
- NPCs now press in quick bursts and tire out: stamina to arouse, magicka to calm
- Fixed: NPCs no longer argue with their own strategy. The Arouse and Calm LLM actions are removed
- Removed the settings NPC strategy step interval and LLM mini-game strength

### Controlling a scene you aren't in
- Controlling an NPC (Num *): Arouse, Calm, Deny, Ask, Order, Punish and Aid are your own actions
- The NPC you control keeps playing its strategy and answers Ask and Order
- Fixed: the Ask / Order / Punish key looked disabled in a solo scene you control
- Your HUD Aid, Ask, Order and Punish are always narrated right away

### Punish
- A punished NPC's new strategy now holds for 30 seconds
- The narration says what the punished actor chose
- Tortured past 80% (Injury Engine), the punished actor gives in and submits
- Punished NPCs now see what happened in the scene, so repeated punishment can work
- DOM slaves' open punishment reasons show in the Punish panel

### DOM slaves
- Bar fill = the non-random orgasm score; the % over the bar end = chance the next roll works
- Arouse on an aroused slave fills their aroused timer first

### Target menu
- New "hug" option: a quick hug, not a scene
- Removed the "platonic" option (the scene setting is still in Scene Creator)

### Description Editor
- Nearby actors can be added to a running scene with **+** (up to 5) and taken off with **✕**
- After adding, pick an animation that fits the new group, then Continue
- The animation table has a filter row: favorites star, gender and name filters

### Prompts
- Scene data in prompts is live, even at scene start or with a menu open
- Cum on actors is now kept by the SKSE plugin. Cum recorded before this update is lost

### Bug Fixes
- Fixed: an NPC's Deny Orgasm was refused when the victim was you
- Fixed: Clean Cum, Dress and Undress were never offered to NPCs
- Fixed: scene endings never used the afterglow template
- Fixed: raw `{{sla.ctors.0}}` braces in several animation descriptions

### WebUI
- Fixed: lock-up (paused game, no cursor) when a request came in with the SkyrimNet dashboard open
- The dashboard or any other open menu now closes before the SexLab dialogue
- Scene Creator: new row above the table (Start by, counts, All / None)

## 0.36.4

### Lover's Ledger
- Works with the latest Lover's Ledger
- The virgin-blood line moved from Lover's Ledger into this mod
- New dashboard option **Virgin blood on first vaginal / anal** (Narration, default off)
- It needs Lover's Ledger
- It is added to the scene-start narration on an actor's first time receiving vaginal or anal sex
- New installer option **First vaginal or anal sex causes soreness and bleeding** (off by default)
- It turns the dashboard option on once at first load. You can turn it off again in the dashboard
- The damaged pussy / ass marks of a first time now use the same check

### Dead actors can join scenes (untested)
- SkyrimNet_SexLab no longer changes a corpse's Health
- On SexLab 1.66, pick the new installer option **SexLab 1.66 corpse patch**
- The patch is not needed on SexLab P+
- Don't use the patch with SLSO (SexLab Separate Orgasm)
- Without the patch, the option turns itself off when you unpause and a message names the file

### Scenes (untested)
- NPCs no longer walk out of a scene to follow a sandbox / camp package from a SkyrimNet action mod
- Their packages come back when the scene ends
- AP Anal descriptions: "lays on their hands and knees with feet in the air" (was "there" / "hair")

## 0.36.3

### Scene narration
- The scene-start narration no longer comes up to a minute late
- New dashboard setting **Silence before keep-talking** (Narration, default 8 s, 0 = off)
- After that much silence, an actor in your scene keeps talking. Speakers take turns
- Scenes without a written description now say who receives ("Hulda is receiving anal sex from …")
- So NPCs no longer swap who is doing what to whom

### Scene start messages
- The scene-start narration is shorter
- First times (Lover's Ledger) and who is intersex now go out as an event just before it
- Only the virgin-blood line (when that Lover's Ledger option is on) stays in the start narration

### Dead actors can join scenes
- New SkyrimNet dashboard option **Dead actors can join scenes** (Actions, default off)
- When on, corpses show in the TargetMenu and can be picked for a scene
- Necro scenes on SexLab 1.6x are no longer cancelled right after they start
- That includes necro scenes started by another mod
- The corpse stays dead. NPC dialogue actions never pick a corpse

### Actor Info layout
- The Actor Info title (source, name, gender) now runs across the top of the view, not down the left

## 0.36.2

### Victim scene ending
- With a victim, the stage before the last waits for the aggressor's orgasm (Multi-Orgasm Mini-game)
- Everyone else then gets their chance to orgasm with them, and the scene moves to the last stage
- New MCM setting **Longest wait for the aggressor** (Scene ending, default 120 s, 0 = no limit)
- An aggressor's early orgasm no longer ends the scene

### NPC-only ending hold
- Without the player, the last stage waits half as long for the orgasm dialogue (15 s, not 30)

### Actor Info view
- New **Actor Info** view in the WebUI, replacing the Lover's Ledger view
- With TT Lover's Ledger: encounter counts, favorite acts and lovers; click a lover to target them
- Without it: SexLab's stats (sex count, last partner, sexuality, purity, skills)
- Pick an actor's gender (male / female / intersex) for SexLab. OStim still uses the body
- Changing the actor in the ControlPanel keeps the view open and shows the new actor

### Futa / intersex
- SexLab P+: a female with a The New Gentleman penis now counts as futa when picking animations
- Intersex actors can fill male or female positions

### OStim TargetMenu
- New **OStim** option in the TargetMenu when OStimNet is installed; OStim plays the scene
- Pick who joins, the victim, the method and the intent as usual

### Aid panel potions
- The Aid panel remembers what you picked last time
- Potions can be **drunk**
- An NPC offered one (to drink or on the lips) can accept or refuse; a refusal can be punished
- When an NPC offers you one, you get a Yes / No choice
- Stamina potions offer drink, lips, ass, pussy and penis
- A potion on ass, pussy, lips or penis during a matching act is shared by both, with narration
- An Aid spell on an undamaged part or someone at full health still shows its effect and is narrated

### Punish panel
- A custom reason no longer punishes straight away: OK sets the reason, and Punish starts it
- An NPC's current mini-game behavior is offered as a reason ("Nina appears to be focused on…")
- Punish and Aid list damaged parts first, worst on top, in red; hover one for its torture bar
- With TT Lover's Ledger, a first vaginal or anal scene marks pussy or ass as damaged

### Verbose logging
- New SkyrimNet dashboard option **Debug > Verbose logging**. Turn it on when reporting a bug
- It adds much more detail to the logs and shows in the prompts what the SexLab sections saw
- Turn it off afterwards: the extra lines are also sent to the LLM
- Fixed: onlookers were sometimes told they could or couldn't see a scene from another's position
- Fixed: characters in a scene didn't know about it in what they said in its first seconds

### Scene start messages (untested)
- When SexLab refuses an actor, a message says why ("SexLab: Lydia can't join - dead")

### Recursion warning bug (untested)
- Fixed: a repeating "JMapValueToJson … stuck in a recursion loop" warning, sometimes then a crash
- It could also damage another mod's saved data (seen with a tears/drool overlay mod)
- Less log spam after loading a save mid-scene

### Enjoyment runaway bug
- Fixed: on SexLab P+, enjoyment could run far out of range during a scene

### Slow P+ start bug (untested)
- Fixed: on SexLab P+, scenes from the animation database could take close to a minute to start

## 0.36.1

### AnimDB bug
- Fixed: the animation database stayed empty on 0.36.0 (every rebuild "finished" with 0 animations). Rebuild it once after updating
- A failed animation database build now says so instead of "ready"

### Dead Actor bug (untested)
- Fixed: necro animations with a corpse (e.g. FunnyBizness) ended right after starting on SexLab 1.6x

## 0.36.0

### Injury Engine
- Injury Engine (optional): Punish wounds a body part, Aid heals it
- Injury Engine: torture bar per body part; Aid opens on the most hurt part
- Injury Engine: Punish spells are Flames, Frostbite and Sparks; Hits box for several hits
- Injury Engine sexual body parts stay off until you agree to enable them

### SexLab P+
- SexLab P+ supported: database, scene endings, pause and stage keys all work 

### Force/Punish/Ask/Order 
- Force is now Ask / Order / Punish (Num .): ask or order a change, punish a refusal
- Punish anyone in any scene, for a reason, by slap, pinch, punch, pull or a spell
- The punished one answers; the AI decides how they react
- NPCs can punish too (new Scene Punish action)

### Aid
- Aid moves to Num Enter; pick who casts and on whom
- Aid healing spells keep healing up to the points you choose

### NPC strategy 
- Strategies renamed (deny self, deny all, focused, ...) and open to every role
- Together, Greedy, Forced orgasm, Accept force, Hold back, Cum quick and mental break removed
- NPCs pick strategies from what was said and what just happened
- NPCs sense enjoyment as closeness to orgasm, not as arousal

### Disable OrgasmEngine 
- New setting to switch orgasms back to SexLab / SLSO (Enjoyment)
- Fixed SLSO edging hiding orgasms from other mods

### SLO Arouse 
- SLO Aroused NG: every orgasm now lowers arousal (optional)

### Bug Fixes 
- Fixed actors staying locked ("Name (locked)") after loading a save
- Changing animation mid-scene restarts at stage 1

### WebUI 
- Animation favorites in Scene Creator (★ column and filter)
- Description Editor: Start button plays the picked animation at once
- Scene Creator: Start greyed until an animation is selected
- Fixed Scene Creator opening empty for NPC-started scenes
- New Clean Cum option and NPC action
- Bondage panel: Start now changes devices missing from the bundled list
- Old pre-Beta-25 action and prompt copies removed

## 0.35.2

- New Num * key: AI auto-plays you, or take control of an NPC's scene
- Auto play stays on across scenes and saves until you press Num * again
- Decision model (e.g. Jev) now picks NPC mini-game strategies
- New Orgasm mode pulldown (also in MCM): Together or Mini-game
- Mini-game pacing: no orgasms in the first half; Mutual ends together
- AI-only scenes: last orgasm at second-to-last stage, then a clean end
- Fixed scenes stuck on their last stage forever
- New Aid (Num 0) and Force (Num .) panels; NPCs can use them too
- Aid and Force can target a body part; Force can use weak attack spells
- Aid and Force spells now show their glow, effects and sounds
- Arouse/Calm no longer makes anyone speak
- Hold Shift to arouse/calm the other actor without changing focus
- Arousal never falls below enjoyment during scenes (optional)
- Arousal, cooldowns and edging no longer advance while paused or in a menu
- Animations with sex acts tagged "sexual"; affection/platonic skip them
- Scene Creator lists only free actors; blocked ones greyed with reason
- Fixed Scene Creator not letting you add a nearby actor again
- Settings warns on animation DB mismatch; Rebuild DB button added
- Fixed hug narration naming the wrong actor
- NPCs can't hug/kiss/start scenes with actors already in a scene
- Stage keys ignored while SexLab is switching stages
- Menus open much faster; TargetMenu no longer flickers
- Description Editor: actor toggles are per-scene; new Load button
- Leash panel moved to SkyrimNet_Leashed; update it with this version

## 0.35.1

- New PgUp/PgDn keys swap actor positions; new stage narration option
- Removed old TargetMenu Stop/Stage/Position/Animation entries
- Deny/allow orgasm are plain events again (Transform option removed)
- Fixed weapon being unusable after a hug
- Rebuilt SKSE plugin for Skyrim 1.7.x / 1.7.99
- Fixed camera restore after locking free camera and when scenes end
- Right/left mouse arouse/calm by default in mini-game scenes

## 0.35.0

- New Prisma hotkey overlay and Num-pad scene hotkeys
- New optional orgasm mini-game; NPCs can play it too
- Style sets animation speed (gentle, normal, forceful)
