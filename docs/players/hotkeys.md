# Hotkeys and in-scene controls

Enable the optional hot key in the SkyrimNet dashboard plugin settings (**Enable Start Sex / Edit Stage hotkey**, default **backslash** `\\`). A dashboard save rebinds the key in-game; you do not need to open the MCM or reload. The in-game MCM only points at that page. Do not bind this to the same key as SkyrimNet_Leashed’s leash panel.

The first time you press it on a save, if the animation database does not match SexLab's animation count, a dialog warns of a likely problem and offers to rebuild the database. Press the hotkey again to open the overlay.

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

## Scene keys (numpad + PgUp / PgDn)

These keys work while you control a scene: you are in it, or you took control of the crosshair scene with SexLab's `N`. They work with NumLock on or off.

```
---------------------------------------------------------------------
| PgUp PosUp | 7 (SkyrimNet) | 8 calm  | 9 arouse      | - slower |
| PgDn PosDn | 4 previous    | 5 pause | 6 next        | + faster |
|            | 1 deny        | 2 end   | 3 free camera |          |
|            | 0 aid         |         | . force       |          |
---------------------------------------------------------------------
```

Num 3 is SexLab's own **Toggle Free Camera** key, set in the SexLab MCM; this mod doesn't bind it, but the HUD shows it. Num 7 is left for SkyrimNet. Num Enter is free.

If you saved keys in the dashboard before this layout, reset them there to get the new defaults.

To rebind a key, open the SkyrimNet dashboard (**Scene HUD** / **Mini-game**) and press the new key. Keep NumLock **on** while you do this, or the browser records Num 7 as Home. Each time the game starts, loads a save, or saves dashboard settings, the mod writes every current binding to `Data/SKSE/Plugins/SkyrimNet_SexLab/hotkey-map.json` (with MO2, look in the overwrite folder).

## Scene HUD (player scenes)

While you are in a SexLab scene, a small HUD appears in the upper left, where the WebUI ControlPanel sits. It has no background, it doesn't pause the game, and it hides whenever a menu or the WebUI is open. Each group can be switched on or off in the dashboard (**Scene HUD** / **Mini-game**):

- **Enjoyment:** one bar per actor. The bar pulses near orgasm and flashes during one.
- **Controls:** a fixed grid laid out like the numpad. Each label names what pressing its key will do.

  ```
   PgUp     Num 7    Num 8    Num 9    Num -
   PosUp             calm     arouse   gentle
   PgDn     Num 4    Num 5    Num 6    Num +
   PosDn    prev     pause    next     forceful
            Num 1    Num 2    Num 3
            deny     end      free 📷
            Num 0             Num .
            aid               force
  ```

  Num 7 is dimmed with no label (it belongs to SkyrimNet).

  - **Num 2** ends the scene.
  - **Num 5** pauses the current stage; the cell then reads *play*. Press again to resume with the rest of the stage's time.
  - **Num 4 / Num 6** go to the previous / next stage.
  - **PgUp / PgDn** (*PosUp* / *PosDn*) swap the actors' roles forward / back (SexLab's swap positions; nothing happens in solo or creature scenes). With **Narrate position changes** on (default), the current stage description is narrated with the actors in their new roles.
  - **Num 1** denies or allows the focus actor's orgasm. The cell reads *deny* or *allow*. A denied actor shows 🔒 after their bar, keeps gaining enjoyment, and cannot orgasm. The change is sent as an event: "<you> forbids <them> from orgasming without permission." / "<you> permits <them> to orgasm." Allowing tests them for orgasm; if they orgasm, the normal orgasm narration starts "You allowed them to orgasm."
  - **Num 3** is SexLab's free camera. While it is on, the cell reads *lock*; press Num 3 again to go back to the normal third-person camera with mouse look. When the scene ends, the camera returns to first or third person, whichever it was when the scene began.
  - **Num - / Num +** step the scene one speed level slower / faster: *gentle* (75%), *normal* (100%), *forceful* (125%). Each cell shows the level a press switches to (at *normal*: *gentle* / *forceful*); at the slowest or fastest level it shows a dimmed *—*. The scene style sets the starting level (gently / normally / forcefully), and a style change resets it. A burst of speed presses gives one narration, and scene start / status messages use the level ("Bob and Alice are forcefully …").
- **How long it takes:** without the mini-game, a scene ends much like plain SexLab. Each actor normally orgasms once near the end, and some a little earlier. A victim usually doesn't. Faster raises the pace and can bring a second orgasm; slower can leave someone short. Pausing or repeating a stage adds time, so it adds enjoyment too.
- **Mini-game** (on by default; **Orgasm mode** = Multi-Orgasm Mini-game):
  - Each actor's row shows a blue **magicka** bar and a green **stamina** bar in front of the enjoyment bar. These are the resources the game spends.
  - **1–4** pick who you act on (▶ marks them).
  - **Num 9** arouses that actor (costs stamina).
  - **Num 8** calms them (costs magicka). Calming someone at 90% or more holds off their orgasm for a few seconds.
  - With **Allow right mouse to arouse and left mouse to calm** on (the default), the **right mouse button** arouses and the **left mouse button** calms too. Clicks are only captured while the HUD is up, so they don't attack or block then.
  - Hold **Shift** while arousing or calming to act on the next actor in the list instead (1→2, 2→3, last→1). Your focus doesn't change, and ⇧ marks who the press hits. Use it to arouse your partner and calm yourself without switching focus.
  - Acting on another actor is narrated.
  - Near the top, an orgasm can land anywhere from 90%.
  - Near the end of the final stage, anyone at 90% or more who hasn't finished still orgasms, unless you calmed them during that stage.
  - **Num .** (*force*, shown only while you are an aggressor) opens the **Force** panel: "You force *victim* to *strategy* by *method*." Pick a victim, what they are forced to do (default: please you), and a method: slap face, pinch nipple, cover mouth, punch, pull hair, one of your **weak attack spells** (Novice or Apprentice spells that damage health, such as Flames or Sparks), or **custom** (type your own). A spell isn't really cast: the victim takes the spell's smallest damage, never enough to kill, and doesn't turn hostile. It is narrated ("Bob punches Nina in the face and forces Nina to please him."). For **Fear cooldown** seconds (Mini-game settings, default 30) the victim can only give in; after that the AI may let them resist. Without a non-player victim the cell is greyed out.
  - **Num 0** (*aid*) opens the **Aid** panel: "*You* *spell or potion* on *actor*." Pick one of your healing or stamina spells or potions and who gets it (you or anyone in the scene). A spell costs its magicka (a spell you can't afford is greyed out); Healing and Healing Hands count as three seconds of casting. A potion is used up. It is narrated ("Bob casts Healing Hands on Nina." / "Bob gives Nina a Potion of Minor Stamina."). Without a spell or potion the cell is greyed out.
  - NPCs can do the same: the AI may have an actor heal or restore someone in the scene (**SexLab_Aid**), or have an aggressor force a victim (**SexLab_Force**, never the player).
  - The optional **mental break** drains the magicka of whoever is being aroused; when it runs out they can't hold back.

All HUD keys are rebindable in the dashboard. While the HUD is up they don't reach SexLab or the game, so a key you share with a SexLab key only does the HUD action.
