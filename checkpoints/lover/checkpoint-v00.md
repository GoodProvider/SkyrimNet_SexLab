# Checkpoint v00: "Lover's Ledger" ControlPanel main panel (built, not in-game tested)

Written from `C:\Skyrim\dev\mods\SkyrimNet_SexLab`, branch `main`, baseline commit `0264d45`, on 2026-10-17, on top
of uncommitted work already in the tree (info.json, fomod, PPlus pex, zz-plan.md). Source for the data side:
`C:\Skyrim\dev\mods\Lover-s-Ledger` (TT Lover's Ledger: `TT_LoversLedger.esp`, `SKSE/Plugins/LoversLedger.dll`).

---

## 1. Goal

Add a ControlPanel **views** entry, **Lover's Ledger**, listed only when Lover's Ledger is installed. It shows
everything the ledger holds for the ControlPanel target: summary counts, top actions did / got, and the lovers
list (score and per-lover stats).

## 2. Decisions

- **Dedicated builtin panel** (`lovers_ledger_panel`, host `#lovers-ledger-panel`) with sections and a lovers
  table. The user chose this over the generic `actor_detail` host, which only does flat label:value rows.
- **Data path: Papyrus → JSON → overlay.** Our DLL does not link to LoversLedger.dll. A new isolated script,
  `SkyrimNet_SexLab_LoversLedger.psc`, is the only SexLab script that references `TTLL_Store`, so nothing else
  breaks when Lover's Ledger is absent. It builds one payload and sends it with the existing native
  `WebUI_PushMainPanelData` → JS `setMainPanelData` (`panel: "lovers_ledger"`).
- **Gating:** MainPanels JSON `0800_lovers_ledger.json` with `requiresPlugin: TT_LoversLedger.esp` and
  `requiresDll: LoversLedger.dll` (`PassesRequiresPlugin`, `SKSE_Source/src/ActionCatalog.cpp:220`). Papyrus also
  checks `Game.GetModByName("TT_LoversLedger.esp") != 255` before touching `TTLL_Store`.
- **Open hook:** builtin MainPanels entries get optional `plugin` / `questFormId` / `scriptName` /
  `openFunction` / `closeFunction`, dispatched by the existing `DispatchPapyrusNoArg` (the `papyrus` type already
  does this). Generic, so later builtins can use it. Open → `SkyrimNet_SexLab_Menu.WebUI_LoversLedgerOpen`
  (quest `SkyrimNet_SexLab.esp` 0x800, where Menu is bound).
- **Refresh on target change:** `Menu.WebUI_OnControlActorFocus` re-pushes when
  `WebUI_IsMainPanelOpen("lovers_ledger_panel")`. Re-selecting the view also re-runs the open.
- **Lover lookup needs a new native.** Verified in `Lover-s-Ledger/SKSE_Source/src/Papyrus_LoversLedger.cpp:59-76,
  205`: `GetLoverInt` / `GetLoverFlt` / `GetLoverScore` take `RE::Actor*` and return 0 for null. `GetAllLovers`
  returns TESNPC base forms, and `(ActorBase as Actor)` is always None (the LL comment "None if unloaded" is
  misleading). No PO3 / SKSE Papyrus function maps a base to its unique reference. So our DLL gets
  `Actor Function ActorFromBase(ActorBase base) global native` (Utilities): player base → PlayerRef, otherwise a
  lazily built TESNPC → Actor map from `TESForm::GetAllForms()`, rebuilt on a miss. Unique NPC references are
  persistent, so this works when the lover's cell is unloaded.
- Caps: 25 lovers, 10 actions per side (`topK`), to keep the PrismaUI Invoke small.
- Read-only. No edit controls (LL's own SKSE Menu Framework window already edits).

## 3. Changes (status: built)

| File | Change |
|------|--------|
| `SKSE/Plugins/SkyrimNet_SexLab/webui/MainPanels/0800_lovers_ledger.json` | New builtin entry, gated, with open hook. |
| `SKSE_Source/src/ActionCatalog.cpp` | `OpenMainPanelEntry` / `CloseMainPanelEntry` builtin branch: dispatch optional `openFunction` / `closeFunction` (shared helper with the `papyrus` branch). |
| `SKSE_Source/src/Papyrus_Utilities.cpp` | `ActorFromBase` native + register. |
| `Scripts/Source/SkyrimNet_SexLab_Utilities.psc` | `ActorFromBase` declaration. |
| `Scripts/Source/SkyrimNet_SexLab_LoversLedger.psc` | New. `BuildPanelJson(Actor target)`; uses `JsonQuote`. |
| `Scripts/Source/SkyrimNet_SexLab_Menu.psc` | `WebUI_LoversLedgerOpen()`; refresh in `WebUI_OnControlActorFocus`. |
| `Headers_Source/LoversLedger/TTLL_Store.psc` | Compile-only copy of LL's header (not shipped as pex). |
| `skyrimse.ppj`, `skyrimse-pplus.ppj` | Import `.\Headers_Source\LoversLedger`. |
| `PrismaUI/views/SkyrimNet_SexLab/index.html` | `#lovers-ledger-panel` host; id in the builtin panel lists; `renderLoversLedger`; `textContent` only. |
| `docs/developers/webui.md`, CHANGELOG ×3 | 0.36.1 "Lover's Ledger view (untested)" entries; webui.md MainPanels (builtin hooks + starter). |
| `SKSE/Plugins/SkyrimNet_SexLab.dll` | Rebuilt (Release preset), copied. |
| `Scripts/*.pex` | pyro: main 4 ok (Menu, LoversLedger, Utilities, Scene), P+ bridge 1 ok. |

Payload:

```json
{ "panel": "lovers_ledger", "id": "lovers_ledger_panel", "name": "Lydia", "formId": 123, "unique": true,
  "empty": "", "now": 210.5,
  "summary": { "exclusive": 12, "group": 3, "solo": 1, "sameSex": 2, "others": 4,
               "icDid": 5, "icGot": 7, "lastDaysAgo": 3.2 },
  "did": [ { "name": "vaginal", "count": 9 } ], "got": [ { "name": "oral", "count": 6 } ],
  "lovers": [ { "name": "Player", "formId": 20, "score": 8.2, "exclusive": 10, "group": 2,
                "orgasms": 14, "icDid": 3, "icGot": 4, "lastDaysAgo": 3.2 } ] }
```

`lastDaysAgo` is -1 when `lasttime` is 0 (never).

## 4. Verification

Done: steps 1–2. `check_pex_escapes`: 29 checked, 0 bad.

To do in game: steps 3–6.

1. `compile: pyro` on `skyrimse.ppj` (and the P+ project) + `make check-pex`: 0 bad.
2. Build SKSE Release; DLL copied to `SKSE/Plugins/`.
3. Without Lover's Ledger: no "Lover's Ledger" in views; no Papyrus errors about `TTLL_Store`.
4. With Lover's Ledger: target an NPC with history (or the player) → summary, actions, lovers by score; numbers
   match LL's own window. Lovers in unloaded cells still show stats (ActorFromBase).
5. Change the ControlPanel target with the view open → page refreshes. Non-unique NPC → "No ledger entries".
6. `SkyrimNet_SexLab.log`: `DispatchPapyrusNoArg: SkyrimNet_SexLab_Menu::WebUI_LoversLedgerOpen`.

## 5. Open questions / risks

0. **Scene.pex false positive.** pyro rebuilt `SkyrimNet_SexLab_Scene.pex` from unchanged source with a different string
   order, and one bytecode pair read as `\"` (`check_pex_escapes` scans raw bytes, not the string table). The
   committed Scene.pex was restored (`git checkout`). The checker can flag a pyro build; a string-table-only scan
   would fix that.
0. The overlay JS was not syntax-checked (no node on this machine). Check the PrismaUI console on first open.
0. The DLL build includes other uncommitted C++ changes already in the tree (BondageCatalog.cpp, JsonStore.cpp).

1. The apostrophe in the label "Lover's Ledger": check that `configureControlPanel` sends labels JSON-escaped
   and never inside a single-quoted JS string.
2. `GetAllForms` walk on first use: one pass over all forms under the read lock. Expected a few ms; logged.
3. Sentinel focus (no Actor): panel shows "No target".
4. Target is the player: the ledger keys on the player's TESNPC; expected to work, confirm in game.

## 6. Next steps

In-game verification (section 4, steps 3–6), then checkpoint v01 with the results. Possible follow-ups: an
NPC-wide roster (`TTLL_Store.GetAllNPCs`) as a `data_table` sentinel, and player-doc wording.
