https://github.com/GoodProvider/SkyrimNet_SexLab/releases/tag/0.36.0

Requires SkyrimNet 0.25.0+ (built against beta26 rc4).

## 0.36.1

### AnimDB bug (untested)
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

### SexLab P+ (untested)
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
