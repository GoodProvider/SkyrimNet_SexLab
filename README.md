# SkyrimNet_SexLab

[![ko-fi](https://ko-fi.com/img/githubbutton_sm.svg)](https://ko-fi.com/goodprovider) 

Adds SkyrimNet (LLM) support to SexLab Framework.

- **Players:** [docs/players/overview.md](docs/players/overview.md) · [hotkeys](docs/players/hotkeys.md) · [requirements](docs/players/requirements.md)
- **Authors:** [actions](docs/authors/actions.md) · [prompts](docs/authors/prompts.md) · [animations](docs/authors/animations.md)
- **Developers:** [papyrus](docs/developers/papyrus.md) · [webui](docs/developers/webui.md)
- **Agents:** [AGENTS.md](AGENTS.md) · [llms.txt](llms.txt) · [release-guide.xml](release-guide.xml) · [documentation-guide.xml](documentation-guide.xml) (portable template for other repos)
- **Changelog:** [CHANGELOG.md](CHANGELOG.md) · [CHANGELOG-user.md](CHANGELOG-user.md)

## Quick start

1. Install requirements ([docs/players/requirements.md](docs/players/requirements.md)). SkyrimNet with narration; 0.25+ uses plugin `goodprovider.sexlab`, older builds use the shipped `prompts/` + `config/actions/` copies.
2. Put `SkyrimNet_SexLab.esp` last; enable narration in SkyrimNet. On 0.25+, plugin `goodprovider.sexlab` should appear under Plugins (External).
3. If Actions fail: Game Data Explorer → `_sexlab` → Refresh (see [FAQ](docs/players/overview.md)).

## Scene keys

These keys work while you control a scene: you are in it, or you took control of the crosshair scene with SexLab's `N`. They sit on the numpad and work with NumLock on or off.

```
-------------------------------------------------------
| 7 previous | 8 pause  | 9 next        | - slower |
| 4 calm     | 5 arouse | 6 deny        | + faster |
| 1 end      | 2        | 3 free camera |          |
-------------------------------------------------------
```

| command  | key     |
|----------|---------|
| previous | Num 7   |
| pause    | Num 8   |
| next     | Num 9   |
| calm     | Num 4   |
| arouse   | Num 5   |
| deny     | Num 6   |
| slower   | Num -   |
| faster   | Num +   |
| end      | Num 1   |
| free camera | Num 3 (SexLab's own key) |

- Calm and arouse are mini-game keys. Mini-game keys 1–4 (top row) pick who you act on.
- `\` opens Start Sex / Edit Stage at any time once it is enabled in the dashboard.
- Every key except free camera can be rebound in the SkyrimNet dashboard. On game start the mod writes the current bindings to `SKSE/Plugins/SkyrimNet_SexLab/hotkey-map.json`.

More detail: [docs/players/hotkeys.md](docs/players/hotkeys.md).

## Extending

| Task | Doc |
|------|-----|
| New LLM action / scene | [docs/authors/actions.md](docs/authors/actions.md), [docs/reference/scene-settings.md](docs/reference/scene-settings.md) |
| Prompt / speaking tokens | [docs/authors/prompts.md](docs/authors/prompts.md), [docs/reference/protocol-tokens.md](docs/reference/protocol-tokens.md) |
| Stage descriptions | [docs/authors/animations.md](docs/authors/animations.md) |
| Papyrus / SKSE | [docs/developers/papyrus.md](docs/developers/papyrus.md), [docs/developers/webui.md](docs/developers/webui.md) |
