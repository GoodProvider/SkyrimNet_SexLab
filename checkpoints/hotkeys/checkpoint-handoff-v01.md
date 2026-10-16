# Checkpoint handoff v01: HUD aid → Num =, ask / order / punish → Num / (built, not in-game tested)

Written from `c:\Skyrim\dev\mods\SkyrimNet_SexLab`, branch `main`, baseline commit `09c1a2b`.
Nothing committed. Untracked `extern/`, `bug-logs/`, `checkpoints/full/` and the two `*-handoff.md` files
at the repo root are unrelated; leave them alone.

---

## 1. Goal

- Aid hotkey default: Num 0 → **Num =**, drawn in the HUD's top row above Num 8 (calm).
- Ask / Order / Punish hotkey default: Num . → **Num /**, drawn in the top row above Num 9 (arouse).
- The HUD's old bottom row (0 aid / . punish) is gone.

## 2. Decisions (user)

- **Num = is `VK_OEM_NEC_EQUAL` (0x92, 146) → DirectInput `0x8D` (DIK_NUMPADEQUALS).** Most 104/105-key
  PC keyboards have no Num = key; those users rebind Aid in the dashboard. The docs and manifest say so.
- **"as <name>"** (driving an NPC with Num \*) now spans grid columns 0–1 instead of 0–3, so the aid /
  ask cells keep their place. Aid is hidden while driving an NPC anyway; ask stays visible.

## 3. Changes

| File | Change |
|------|--------|
| `SKSE_Source/src/Hud.cpp` | `kBindings`: `punish` default `VK_DIVIDE`, `aid` default `VK_OEM_NEC_EQUAL`. `DxLabel`: `0xB5` → "Num /", `0x8D` → "Num =". |
| `SKSE_Source/src/Config.cpp` | `HotkeyVkToDx`: `VK_OEM_NEC_EQUAL` → `0x8D` (MapVirtualKey has no scancode for it). `VK_DIVIDE` already mapped to `0x80 \| sc` = `0xB5`. |
| `PrismaUI/views/SkyrimNet_SexLab/hud.html` | Top row: off / off (or "as <name>" spanning 2) · aid · ask · take control. Bottom row removed. `COLUMN_LABELS`: `aid` sizer moved col 1 → col 2. `.acting` `grid-column: 1 / span 2`. Comments updated. |
| `SKSE/Plugins/SkyrimNet/config/plugins/SkyrimNet_SexLab/manifest.yaml` | `sexlab.minigame.key_aid` default 96 → 146 (+ "no Num = key" note). `sexlab.minigame.key_force` default 110 → 111; renamed "Ask / order / punish hotkey"; stale "Force panel" description replaced. |
| `docs/players/hotkeys.md` | Both grids; Num / and Num = in the key bullets; Num 0 / Num . / Num Enter listed as free; Num = note. |
| `CHANGELOG-player.md` | One line under 0.35.2. |
| `KNOWLEDGEBASE.md` | "Num 0" → "Aid key (Num =)" in the stale eligibility note. |
| `SKSE/Plugins/SkyrimNet_SexLab.dll` | Rebuilt (`cmake --build --preset build-release`), compiled clean. |

Not changed: `Scripts/Source/SkyrimNet_SexLab_Actions.psc:858` comment still says "Num 0 / Num ." — comment
only, not worth a Papyrus recompile. Older CHANGELOG entries keep the old key names (history).

## 4. Why `key_force` changed too

Punish reads `sexlab.hud.key_punish` (not in the manifest). While that holds its default, `Hud.cpp` reads
the legacy `sexlab.minigame.key_force` (`KeyBinding::legacyPath`) with the new default as fallback. If the
manifest still shipped 110 there, punish would stay on Num . — so the manifest default had to move to 111.

## 5. Known risks / open questions

1. **Saved configs keep the old keys.** If SkyrimNet has already written 96 / 110 into the user's config,
   they stay on Num 0 / Num . until reset in the dashboard (hotkeys.md already says to reset).
2. **Num = capture untested.** Unknown whether the SkyrimNet dashboard's key capture records VK 146 for a
   physical Num = key (Apple keypads may report a different VK / scancode, e.g. scancode 0x59). If it
   records something else, `HotkeyVkToDx` needs another case.
3. **Num = in-game untested.** Need to confirm Skyrim's DirectInput keyboard reports Num = as `0x8D`.

## 6. In-game test steps

1. Fresh / reset Scene HUD + Mini-game keys in the dashboard; start a player scene with the mini-game.
2. HUD top row: `Num =` *aid* over Num 8, `Num /` *ask* over Num 9, `Num *` *auto* at right. No bottom row;
   columns don't shift width when aid greys out.
3. Num / opens Ask / Order / Punish. Num = (if the keyboard has one) opens Aid; otherwise bind Aid to Num 0
   and confirm the cell reads "Num 0".
4. Aim at an NPC in another scene, Num \*: "as <name>" fits columns 0–1, ask visible, aid hidden.
5. `Data/SKSE/Plugins/SkyrimNet_SexLab/hotkey-map.json`: aid dx 141 (0x8D), punish dx 181 (0xB5).
6. Disable mini-game: aid cell hidden (slot kept), ask still works.

## 7. Next

- Run §6, then commit (summary e.g. "HUD: aid to Num =, ask/order/punish to Num /, top row").
