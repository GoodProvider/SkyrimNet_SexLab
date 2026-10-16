# Hotkeys checkpoint v02: ask / order / punish → Num ., aid → Num Enter (uncommitted, not in-game tested)

Follows [hotkeys-chekpoints-v01.md](hotkeys-chekpoints-v01.md) (`038c423`: aid Num =, ask Num /, top row).
This reverts the keys to the bottom of the numpad. **Not committed.** The working tree still holds the
Punish-panel / Injury Engine edits (see v01). `Hud.cpp`, `Config.cpp`, `hotkeys.md`, `CHANGELOG-player.md`,
`KNOWLEDGEBASE.md` and the DLL mix both sets of changes.

## 1. What changed

- **Ask / Order / Punish** default Num / → **Num .** (`VK_DECIMAL`, DX 0x53), drawn under Num 3.
- **Aid** default Num = → **Num Enter** (`VK_RETURN`, DX 0x9C), drawn to the right of Num ., under Num +.
- Top row holds only Num \*; "as <name>" spans columns 0–3 again.

```
                                       Num *
   <as npc>                            auto|control
   PgUp     Num 7    Num 8    Num 9    Num -
   PosUp             calm     arouse   gentle
   PgDn     Num 4    Num 5    Num 6    Num +
   PosDn    prev     pause    next     forceful
            Num 1    Num 2    Num 3
            deny     end      free 📷
                              Num .    Num Enter
                              ask      aid
```

## 2. Where

| File | Change |
|------|--------|
| `SKSE_Source/src/Hud.cpp` | `kBindings`: punish `VK_DECIMAL`, aid `VK_RETURN`. `DxLabel`: `0x9C` "Num Enter". |
| `SKSE_Source/src/Config.cpp` | `HotkeyVkToDx`: `VK_RETURN` in the `0x80 \| sc` list → 0x9C. |
| `PrismaUI/views/SkyrimNet_SexLab/hud.html` | Top row 4 off cells + Num \*; new bottom row (ask col 3, aid col 4); `COLUMN_LABELS` aid col 2 → 4; `.acting` span 4. |
| `manifest.yaml` | `key_force` 111 → 110 ("Default Num ."); `key_aid` 146 → 13 ("Default Num Enter"). |
| `docs/players/hotkeys.md`, `CHANGELOG-player.md`, `KNOWLEDGEBASE.md` | Grids, key names, Num Enter quirk. |
| `SKSE/Plugins/SkyrimNet_SexLab.dll` | Rebuilt (`build-release`, clean). |

## 3. Gotcha

Num Enter and main Enter share `VK_RETURN`; the dashboard stores VK only. Every Enter binding now means
Num Enter (DX 0x9C), so main Enter can't be bound.

## 4. In-game test

1. Reset Scene HUD + Mini-game keys; start a player mini-game scene.
2. Top row only Num \*; ask under Num 3, aid to its right; no column width jumps when aid greys out.
3. Num . opens Ask / Order / Punish; Num Enter opens Aid; main Enter does nothing HUD-related.
4. Num \* on an NPC in another scene: "as <name>" spans columns 0–3.
5. `hotkey-map.json`: punish dx 83, aid dx 156.
