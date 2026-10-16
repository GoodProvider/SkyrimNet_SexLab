# Checkpoint v01: Ask / Order / Punish panel memory, reasons, hit count; Injury Engine sexual-parts save fix (built, not in-game tested)

Written from `c:\Skyrim\dev\mods\SkyrimNet_SexLab`, branch `main`, baseline commit `09c1a2b`, on top of the
uncommitted hotkeys work (`checkpoints/hotkeys/checkpoint-handoff-v01.md`). Nothing committed. Also touches
the sibling repo `c:\Skyrim\dev\mods\Injury_Engine` (one Papyrus line + changelog).

---

## 1. Goal

- Sexual body part → "Do you wish to enable torture sexual parts?" → **Yes** must change Injury Engine's
  setting permanently (it reverted on the next config load).
- The Ask / Order / Punish panel reopens with the last values, selecting each one when still possible. A
  remembered punishment reason that is gone → another one at random.
- Reasons always include **no reason** and **custom** (so Punish is always offered).
- Punish gets a **Hits** number field with the min / max printed beside it.

## 2. Decisions

- **Root cause of the Yes not sticking:** `Injury_Engine_Main.External_SetSexualParts` patched
  `{"whip":{"body":{…}}}`, the pre-rename key. The in-memory property changed, so it worked until the next
  `ApplyPluginConfig`. Fixed in Injury Engine; SexLab's side (`onInjuryEngineSexualParts` →
  `InjuryEngine::EnableSexualParts`) was already right.
- **Amount = Injury Engine `damage_amount`** (hits). Range 1 to `injury_engine.action.max_strikes`
  (Injury Engine's "Maximum lashes per action", default 10, clamped 1–20). Shown only for punish with Injury
  Engine installed; without it the hit is narration only, so amount is fixed at 1. C++ clamps again.
- Amount > 1 adds " N times" after the act: "Bob punishes Nina by slapping Nina's ass 3 times, because …".
- **no reason** is sent as `reason: ""`; the existing code already drops ", because …".
- **Memory** is a JS variable in the PrismaUI view (`PUNISH_LAST`), saved on accept *and* cancel. It lasts
  for the game session, not across restarts. Subject: the remembered one if present, else `defaultPunisher`.
  A remembered sexual part falls back to *body* if Injury Engine's setting is off again.
- **Reason fallback:** a remembered custom reason is kept as its own entry; a listed reason that is gone
  (another object, or no longer held) → random from the object's current reasons, else *no reason*. A fresh
  open with nothing remembered picks the first held reason (as before), else *no reason*.
- Papyrus / NPC / auto-play punish callers keep amount 1 (default argument).

## 3. Changes

| File | Change |
|------|--------|
| `Injury_Engine/Scripts/Source/Injury_Engine_Main.psc` | `External_SetSexualParts` patches `{"injury_engine":{"body":{"include_sexual_parts":…}}}`. Compiled to `Scripts/Injury_Engine_Main.pex` (see §5.1). |
| `Injury_Engine/CHANGELOG-player.md` | One line under Unreleased. |
| `SKSE_Source/include/Config.h`, `src/Config.cpp` | `GetForeignConfigInt(plugin, path, def)`. |
| `SKSE_Source/include/InjuryEngine.h`, `src/InjuryEngine.cpp` | `MaxStrikes()`; `count` param on `Strike`, `Torture`, `PunishHit`, `PunishText` (replaces hard-coded `damage_amount` 1). |
| `SKSE_Source/include/OrgasmEngine.h`, `src/OrgasmEngine.cpp` | `PunishNarrated(..., amount = 1)` clamps to 1..MaxStrikes (1 without Injury Engine) and threads it through `PunishLocked` (" N times") and `ContinuePunish`. |
| `SKSE_Source/src/WebUI.cpp` | `onPunishResult` reads / logs `amount`. |
| `SKSE_Source/src/Hud.cpp` | `OpenPanel` adds `injuryengineMaxStrikes`. |
| `PrismaUI/views/SkyrimNet_SexLab/index.html` | Hits row (`#punish-amount`, `#punish-amount-range`); `PUNISH_NO_REASON`; `PUNISH_LAST` + `punishRemember`; `punishAmountShown` / `punishAmount`; verb pulldown always offers punish; `punishRenderReason` rewritten (index-based pick, random fallback); `openPunishPanel` restores values and text fields. |
| `SKSE/Plugins/SkyrimNet_SexLab.dll` | Rebuilt (`cmake --build --preset build-release`), clean. |
| `docs/players/hotkeys.md`, `CHANGELOG-player.md`, `docs/reference/json-keys.md`, `KNOWLEDGEBASE.md` | Panel memory, no reason, Hits, payload keys, the key-rename pitfall. |

## 4. Verification (to do in game)

1. Num / → punish → nipples → **Yes**. Save, reload: Injury Engine dashboard shows sexual parts on; the
   pulldown entry isn't dimmed. `Injury_Engine.log`: `External_SetSexualParts enabled:True patched:True`.
2. Punish with Hits 3: `SkyrimNet_SexLab.log` `onPunishResult … amount=3`, `InjuryEngine: torture text … x3`;
   narration "… 3 times". Hits 0 / 11 (max 10) greys out Punish.
3. Reopen: same subject / object / verb / method / part / reason / hits / custom texts.
4. Punish for a refused request, let her agree to it (reason dropped), reopen: another reason or *no reason*.
5. *no reason*: narration has no "because".
6. Without Injury Engine: no Hits row; punish still works.

## 5. Known risks / open questions

1. **Pyro is gone** from the VS Code Papyrus extension (updated to 2026.1014.13, no `pyro/pyro.exe`); the
   `compile: pyro` task in both repos points at the removed 2024 path. `Injury_Engine_Main.pex` was built with
   `C:\Skyrim\dev\skyrim\Papyrus Compiler\PapyrusCompiler.exe` using the ppj's imports and flags. The task
   needs a new pyro path.
2. Users whose saved config already holds `whip.body.include_sexual_parts` keep that stray key; harmless.
3. JS not run outside the game (no Node on this machine) — review only.
