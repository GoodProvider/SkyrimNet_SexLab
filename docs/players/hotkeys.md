# Hotkeys and in-scene controls

Enable the optional hot key in the SkyrimNet dashboard plugin settings (**Enable Start Sex / Edit Stage hotkey**, default **backslash** `\\`). A dashboard save rebinds the key in-game; you do not need to open the MCM or reload. The in-game MCM only points at that page. Do not bind this to the same key as SkyrimNet_Leashed’s leash panel.

## Out of animation

- Start a sexual act with crosshair NPC, or between NPCs not under crosshair
- Dress / undress under crosshair (including silently)
- **Punish:** spanking, spanking nude, whip, rape
- **Affection** (SexLab): hug, kiss, cuddle, spoon, headpat
- **Player rapes** / **rapes player**
- OstimNet installed: swap SexLab vs OStim framework
- Domination slave (`SkyrimNet_DOM.esp`): starts route through DOM handler APIs
- **Leash** (`SkyrimNet_Leashed.esp`): opens the SkyrimNet_Leashed PrismaUI leash panel (same as that mod’s panel hotkey). Shown only when Leashed is loaded. Does not require Leashed’s own hotkey to be enabled. On the PrismaUI Target Menu, **leash** closes this overlay first, then opens Leashed.

## In SexLab animation

- Change sex style (Tag Editor dialogs on)
- Add / edit per-stage description
- Set whether a given actor expects an orgasm

Stage JSON format: [../authors/animations.md](../authors/animations.md).

## WebUI menus

In-game PrismaUI target / sex menus (SKSE DLL). Build and paths: [../developers/webui.md](../developers/webui.md). Target Menu **leash** (when `SkyrimNet_Leashed.esp` is loaded) hides this overlay and opens Leashed’s bar.

While this overlay is open, other mods’ hotkeys (including SexLab stage/adjust keys) are ignored so you can type in description fields. The mouse still moves and WebUI text fields accept typing. Escape and this mod’s menu hotkey still work.

## Scene HUD (player scenes)

While you are in a SexLab scene, a small HUD appears in the upper left, where the WebUI ControlPanel sits. It has no background, it doesn't pause the game, and it hides whenever a menu or the WebUI is open. Each group can be switched on or off in the dashboard (**Scene HUD** / **Mini-game**):

- **Enjoyment:** one bar per actor. The bar pulses near orgasm and flashes during one.
- **Controls:** **End** ends the scene; **Home** pauses the current stage (the HUD shows *Paused*; press again to resume with the rest of the stage's time); **←/→** go to the previous/next stage; **Page Down** denies or allows the focus actor's orgasm (the button at the end of the row reads *deny* or *allow*; a denied actor shows 🔒 after their bar, keeps gaining enjoyment, and cannot orgasm); **↓/↑** step the scene one speed level slower/faster: *slow and gentle* (50%), *gentle* (75%), *normal* (100%), *forceful* (125%), *fast and forceful* (150%). The current level shows between *slower* and *faster*; the scene style sets the starting level (gently / normally / forcefully) and a style change resets it. A burst of speed presses gives one narration, and scene start / status messages use the level ("Bob and Alice are fast and forcefully …").
- **How long it takes:** without the mini-game, a scene ends much like plain SexLab. Each actor normally orgasms once near the end, and some a little earlier. A victim usually doesn't. Faster raises the pace and can bring a second orgasm; slower can leave someone short. Pausing or repeating a stage adds time, so it adds enjoyment too.
- **Mini-game** (off by default):
  - Each actor's row shows a blue **magicka** bar and a green **stamina** bar in front of the enjoyment bar. These are the resources the game spends.
  - **1–4** pick who you act on (▶ marks them).
  - **Right mouse button** arouses that actor (costs stamina).
  - **Left mouse button** calms them (costs magicka). Calming someone at 90% or more holds off their orgasm for a few seconds.
  - Acting on another actor is narrated.
  - Near the top, an orgasm can land anywhere from 90%.
  - Near the end of the final stage, anyone at 90% or more who hasn't finished still orgasms, unless you calmed them during that stage.
  - The optional **mental break** drains the magicka of whoever is being aroused; when it runs out they can't hold back.

All HUD keys are rebindable in the dashboard. While the HUD is up they don't reach SexLab or the game, so `End` doesn't also trigger SexLab's own end key and the mouse buttons don't attack.
