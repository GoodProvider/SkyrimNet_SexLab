# Hotkeys checkpoint v01: aid → Num =, ask / order / punish → Num / (committed, not in-game tested)

Repo `c:\Skyrim\dev\mods\SkyrimNet_SexLab`, branch `main`. Hotkey work is **committed** as `038c423`
("HUD: aid to Num =, ask/order/punish to Num /, in top row"), on top of `09c1a2b`. Not pushed.
Earlier handoff for the same work: [checkpoint-handoff-v01.md](checkpoint-handoff-v01.md).

**Working tree is not clean, but none of the pending changes are hotkey work.** Uncommitted edits in
`Hud.cpp`, `Config.cpp`, `index.html`, `InjuryEngine.*`, `OrgasmEngine.*`, `WebUI.cpp`, `hotkeys.md`,
`CHANGELOG-player.md`, `KNOWLEDGEBASE.md`, `json-keys.md` and the DLL belong to the Punish-panel /
Injury Engine work (remembered picks, Hits box, `GetForeignConfigInt`, `injuryengineMaxStrikes`); see
`checkpoints/punish/checkpoint-v01.md`. Don't fold them into a hotkeys commit. Untracked `extern/`,
`bug-logs/`, `checkpoints/full/`, `%SystemDrive%/` and the root `*-handoff.md` files are unrelated.

---

## 1. What changed (in `038c423`)

- **Aid** default Num 0 → **Num =**, drawn in the HUD top row above Num 8 (calm).
- **Ask / Order / Punish** default Num . → **Num /**, drawn in the top row above Num 9 (arouse).
- Old HUD bottom row (0 aid / . punish) removed. Num 0, Num . and Num Enter are now free.
- While driving an NPC (Num \*), "as <name>" spans grid columns 0–1 (was 0–3) so aid / ask keep their slots.

New HUD controls grid:

```
                     Num =    Num /    Num *
   <as npc>          aid      ask      auto|control
   PgUp     Num 7    Num 8    Num 9    Num -
   PosUp             calm     arouse   gentle
   PgDn     Num 4    Num 5    Num 6    Num +
   PosDn    prev     pause    next     forceful
            Num 1    Num 2    Num 3
            deny     end      free 📷
```

## 2. Where

| File | Change |
|------|--------|
| `SKSE_Source/src/Hud.cpp` | `kBindings`: `punish` → `VK_DIVIDE`, `aid` → `VK_OEM_NEC_EQUAL`. `DxLabel`: `0xB5` "Num /", `0x8D` "Num =". |
| `SKSE_Source/src/Config.cpp` | `HotkeyVkToDx`: `VK_OEM_NEC_EQUAL` → `0x8D` (DIK_NUMPADEQUALS; MapVirtualKey has none). `VK_DIVIDE` was already `0x80 \| sc` = `0xB5`. |
| `PrismaUI/views/SkyrimNet_SexLab/hud.html` | aid (col 2) + ask (col 3) in top row; bottom row deleted; `COLUMN_LABELS` `aid` sizer col 1 → 2; `.acting` `grid-column: 1 / span 2`. |
| `SKSE/Plugins/SkyrimNet/config/plugins/SkyrimNet_SexLab/manifest.yaml` | `sexlab.minigame.key_aid` 96 → 146; `sexlab.minigame.key_force` 110 → 111, renamed "Ask / order / punish hotkey", stale Force-panel text replaced. |
| `docs/players/hotkeys.md`, `CHANGELOG-player.md`, `KNOWLEDGEBASE.md` | Grids, key names, "no Num = key" note, changelog line. |
| `SKSE/Plugins/SkyrimNet_SexLab.dll` | Rebuilt with `cmake --build --preset build-release` (clean). |

## 3. Decisions (user)

- Num = = `VK_OEM_NEC_EQUAL` (0x92 / 146) → DX `0x8D`, label "Num =". Users without the key rebind Aid
  in the dashboard (**Mini-game** / **Aid hotkey**).
- "as <name>" shrinks to columns 0–1 rather than getting its own row or hiding aid / ask.

## 4. Gotcha: why `key_force` changed

Punish reads `sexlab.hud.key_punish` (not in the manifest). While that holds its default, `Hud.cpp`
reads the legacy `sexlab.minigame.key_force` (`KeyBinding::legacyPath`). The manifest default there had to
move to 111, otherwise punish would stay on Num ..

## 5. Open risks

1. Saved configs holding 96 / 110 keep Num 0 / Num . until the user resets keys in the dashboard.
2. Untested: does the SkyrimNet dashboard key capture record VK 146 for a real Num = key? Apple keypads
   may report another VK / scancode (e.g. scancode 0x59). If so, add a case to `HotkeyVkToDx`.
3. Untested: does Skyrim's DirectInput keyboard report Num = as `0x8D`?
4. `Scripts/Source/SkyrimNet_SexLab_Actions.psc:858` comment still says "Num 0 / Num ." (comment only;
   left to avoid a Papyrus recompile).

## 6. In-game test

1. Reset Scene HUD + Mini-game keys in the dashboard; start a player scene with the mini-game.
2. Top row: `Num =` aid over Num 8, `Num /` ask over Num 9, `Num *` at right; no bottom row; no
   column width jumps when aid greys out.
3. Num / opens Ask / Order / Punish. Num = opens Aid (or bind Aid to Num 0; cell then reads "Num 0").
4. Aim at an NPC in another scene, Num \*: "as <name>" fits columns 0–1, ask visible, aid hidden.
5. `Data/SKSE/Plugins/SkyrimNet_SexLab/hotkey-map.json`: aid dx 141 (0x8D), punish dx 181 (0xB5).
6. Mini-game off: aid slot kept but hidden, ask still works.

## 7. Next

- Run §6. If Num = capture fails (risk 2), fix `HotkeyVkToDx` and write v02.
- Push `038c423` when the user asks.
