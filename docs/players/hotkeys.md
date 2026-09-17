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
- **Leash** (`SkyrimNet_Leashed.esp`): opens the SkyrimNet_Leashed PrismaUI leash panel (same as that mod’s panel hotkey). Shown only when Leashed is loaded. Does not require Leashed’s own hotkey to be enabled. On the PrismaUI Target Menu, **leash** (target not collared) or **unleash** (target collared) closes this overlay first, then opens Leashed’s vertical bar.

## In SexLab animation

- Change sex style (Tag Editor dialogs on)
- Add / edit per-stage description
- Set whether a given actor expects an orgasm

Stage JSON format: [../authors/animations.md](../authors/animations.md).

## WebUI menus

In-game PrismaUI target / sex menus (SKSE DLL). Build and paths: [../developers/webui.md](../developers/webui.md). Target Menu **leash** / **unleash** (when `SkyrimNet_Leashed.esp` is loaded) hide this overlay and open Leashed’s vertical bar. The option JSON lives in the Leashed zip.
