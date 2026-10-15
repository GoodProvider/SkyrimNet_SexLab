https://github.com/GoodProvider/SkyrimNet_SexLab/releases/tag/0.35.2

### 0.35.2

- New Narration settings at the top of the dashboard: Start, Stage change, Orgasm, End, Position change, Style change and Strategy / request narration. Each can be turned down to Event, ShortEvent (fades after 30 s) or Silent; Direct (default) keeps today's behaviour. With Orgasm below Direct the scene no longer waits for the orgasm voice. **Narrate position changes** is replaced by Position change narration
- New setting **Disable OrgasmEngine, switch back to SexLab** (Enjoyment): SexLab or SLSO decides enjoyment and orgasms again and the mod just narrates them. The mini-game, NPC strategies and the orgasm check before the last stage are off while it is on; the WebUI orgasm button still works. Applies from the next scene
- SexLab P+ supported: the animation database fills from P+, scenes end after the orgasms instead of looping, pause and stage keys work, and animation / actor changes keep the scene going
- Fixed with SLSO: orgasms sometimes did not count for other mods (Radiant Prostitution clients paid as if they never came) because SLSO's edging swallowed them
- Scene Creator: Start is greyed out until at least one animation is selected
- Aid panel (Num 0): healing spells now have a "Heal up to _ points" field and keep healing at their normal rate until that many points are healed or you run out of magicka; Healing Hands is picked by default
- Aid panel (Num 0): pick who uses the spell or potion (default you) and who it is used on (default someone else in the scene)
- Bondage panel: Start now removes or changes devices that were not in the bundled list (for example some armbinders), and tells you when a device could not be changed
- New Ask / Order / Punish panel (Num .): ask or order someone to change how they play; they answer "agrees to" or "refuses", and a refusal is something they can be punished for
- Strategies renamed to match strategies.json: deny self, deny all, deny, tease, focused; Together, Greedy, Forced orgasm and Accept force are gone, and so is being forced
- Mental break is gone, and so is its dashboard setting
- NPCs now choose their strategy from their own thoughts, what was said and what just happened, not from their current strategy
- Punish: with SkyrimNet_Whipped, the line is followed by how the hit feels
- Mini-game strategies are the same for everyone: Hold back and Cum quick are gone, and victims can now tease, force or be greedy too
- New Num * key: AI auto-plays you, or take control of an NPC's scene
- Auto play stays on across scenes and saves until you press Num * again
- Decision model (e.g. Jev) now picks NPC mini-game strategies
- New Orgasm mode pulldown (also in MCM): Together or Mini-game
- Mini-game pacing: no orgasms in the first half; Mutual ends together
- AI-only scenes: last orgasm at second-to-last stage, then a clean end
- Fixed scenes stuck on their last stage forever
- New Aid (Num 0) and Punish (Num .) panels; NPCs can use them too
- Punish: anyone hurts anyone in the scene, for a reason you type
- Punish reason: pick "change to ..." a strategy, or type a custom one
- The punished one answers; the AI decides how they react
- Punishments work: the punished NPC gives in, wavers or defies, and the narration says so
- Aid and Punish can target a body part; Punish can use weak attack spells
- Aid and Punish spells now show their glow, effects and sounds
- Body part list: face, lips, nipples, back, arms, legs, pussy, cock, ass
- With SkyrimNet_Whipped: Punish wounds the part, Aid heals it
- Whipped: Flames, Frostbite and Sparks leave burns, frostbite, shocks
- Whipped sexual parts greyed until you agree to enable them
- New Clean Cum: TargetMenu option and NPC action, pick who cleans which body part
- Arouse/Calm no longer makes anyone speak
- NPCs now sense enjoyment as closeness to orgasm, not as arousal
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

### 0.35.1

- New PgUp/PgDn keys swap actor positions; new stage narration option
- Removed old TargetMenu Stop/Stage/Position/Animation entries
- Deny/allow orgasm are plain events again (Transform option removed)
- Fixed weapon being unusable after a hug
- Rebuilt SKSE plugin for Skyrim 1.7.x / 1.7.99
- Fixed camera restore after locking free camera and when scenes end
- Right/left mouse arouse/calm by default in mini-game scenes

### 0.35.0

- New Prisma hotkey overlay and Num-pad scene hotkeys
- New optional orgasm mini-game; NPCs can play it too
- Style sets animation speed (gentle, normal, forceful)
