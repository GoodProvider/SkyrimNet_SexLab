# Extension panels (TargetMenu)

Another mod can add its own TargetMenu panel without changing `index.html`. It ships a catalog option JSON and a panel script. Example: SkyrimNet_Leashed ships the `leash` panel.

## Option JSON keys

| key | meaning |
|-----|---------|
| `panel` | Panel kind, such as `leash`. Must not be a built-in kind (`scene_start`, `cuddle`, `outfit`, `bondage`, `fields`) |
| `panelScript` | Script path relative to `PrismaUI/views/SkyrimNet_SexLab/`, shipped as an MO2 overlay into that folder |

Other keys (`label`, `requiresPlugin`, `parameterMapping`, …) work the same as for any `papyrus` option. See [docs/developers/webui.md](../developers/webui.md).

## Script API

The script runs once in the overlay page and registers its kind:

```js
registerTargetPanel('leash', {
    render(body, opt) { /* fill the body <div>; called on every redraw */ },
    onOpen(opt)       { /* optional: runs each time the option is opened */ },
    skipHeader: true  // optional: hide the option's label header
});
```

| global | meaning |
|--------|---------|
| `registerTargetPanel(kind, def)` | Registers `def` for `kind`. Ignored unless `def.render` is a function. A later call for the same kind replaces the earlier one |
| `papyrusQuery(script, fn, formId)` | Calls `script.fn(Actor) Global` returning `String` on the actor `formId`. Resolves to the string, or `null` when the call failed (bad name, no actor, no such function) |
| `renderPapyrusPanel()` | Redraws the open panel. Call it after async data arrives |

`script` and `fn` must contain only letters, digits and `_` (128 characters max). Otherwise C++ rejects the call. The C++ side is `onPapyrusQuery({requestId, script, fn, formId})`, which replies with `papyrusQueryResult({requestId, ok, value})`.

## Loading

- The script loads the first time an option with that `panelScript` opens. The panel shows **Loading…** until then.
- Options that share a script are queued while it loads. Each one gets its `onOpen` if it is still the open panel.
- A script that loads but never registers the option's kind shows **Unknown panel: <kind>** and logs a console warning. It is not re-run. A script whose `<script>` tag fails to load (missing file) also shows **Unknown panel**, and it is retried the next time the option opens.
