# Dólar

Argentine exchange rates in the Omarchy bar. A pill shows the rate you care
about; the panel behind it lists every rate [dolarapi.com](https://dolarapi.com)
publishes, along with the brecha against the official rate.

No API key, no account, no configuration required to start.

```
bar:   ···   Blue 1.545  ···

┌────────────────────────────────────┐
│  Dólar Blue                brecha  │
│  1.545                     +1,0 %  │
│  ────────────────────────────────  │
│  Blue               1.525 / 1.545  │
│  Oficial            1.480 / 1.530  │
│  Tarjeta            1.924 / 1.989  │
│  MEP          1.522,80 / 1.530,40  │
│  CCL          1.589,70 / 1.592,90  │
│  Cripto       1.579,59 / 1.583,32  │
│  Mayorista          1.503 / 1.512  │
│  ────────────────────────────────  │
│  actualizado 17:58 compra / venta  │
└────────────────────────────────────┘
```

The interface is in Spanish, since that is what the rates are called by the
people who check them.

## Origen

Este plugin nació como una demo para la primera juntada de Omarchy en Buenos
Aires.

Se eligió la cotización del dólar porque es un dato útil que la gente consulta
seguido, y porque [dolarapi.com](https://dolarapi.com) no pide credenciales,
así cualquiera puede instalarlo y verlo funcionando en un comando.

> **Omarchy Buenos Aires Meetup 001** — 16 de septiembre de 2026, CABA.
> Evento organizado por la comunidad. No es un evento oficial de Omarchy ni de Omacom Foundation.
> [luma.com/j73j85lb](https://luma.com/j73j85lb)

*Built as a demo for the first Omarchy meetup in Buenos Aires. The rest of this
README is in English; the plugin's interface is in Spanish, since that is the
language the rates are quoted in.*

## Walking the build

The history is seven tagged checkpoints rather than a flat import. Each one
passes `omarchy plugin validate` and `qmllint`, and was run in a real bar
before being tagged, so you can check one out and watch the widget gain a
feature:

| tag | what it adds |
|---|---|
| `v1-pill` | The smallest thing that works: ~100 lines, no panel, `curl` in a subprocess, one number in the bar. |
| `v2-panel` | Extracts `Panel.qml`; all seven markets, the brecha, Argentine number formatting. |
| `v3-resiliente` | Keeps the last good rates when a fetch fails, retries three times, says so honestly. |
| `v4-etiqueta` | Labels the pill with the market name instead of a glyph, and turns on `allowMultiple`. |
| `v5-click` | Click a row or scroll the pill to switch markets; the choice persists to a state file. |
| `v6-teclado` | Keyboard navigation — `j`/`k`, `Enter`, `r`, `Esc`. |
| `v7-cache` | Caches the rates so it cold-starts with numbers even offline. |

```bash
git checkout v1-pill && omarchy restart shell   # then walk forward
```

## Install

```bash
omarchy plugin add https://github.com/xymbol/omarchy-dolar --enable
```

Then click the pill, or run `omarchy-shell shell summon io.github.xymbol.dolar '{}'`.

## Configure

Everything is optional. Settings live on the widget's entry in
`~/.config/omarchy/shell.json`, which hot-reloads on save:

```json
{
  "id": "io.github.xymbol.dolar",
  "market": "blue",
  "showSide": "venta",
  "refreshSeconds": 300,
  "showBrecha": true
}
```

| Key | Default | Meaning |
|---|---|---|
| `market` | `"blue"` | Which rate the bar pill shows. One of `blue`, `oficial`, `tarjeta`, `bolsa` (MEP), `contadoconliqui` (CCL), `cripto`, `mayorista`. |
| `showSide` | `"venta"` | Which side of the spread: `venta`, `compra`, or `ambos` for `1.525 / 1.545`. The first two name dolarapi's own fields, so they stay in Spanish. |
| `refreshSeconds` | `300` | Seconds between refreshes. Floored at 60 — dolarapi is free and unauthenticated, so please do not hammer it. |
| `showBrecha` | `true` | Show the gap against the official rate. Hidden automatically when `market` is `oficial`. |
| `markets` | *(all)* | Array of market keys to restrict and reorder the panel, e.g. `["blue", "tarjeta"]`. |
| `icon` | *(market name)* | Replaces the market name on the pill with a glyph. See below. |

### Two pills at once

`allowMultiple` is on, so you can watch the blue and the card rate side by side
by adding the widget twice with different `market` values:

```json
{ "id": "io.github.xymbol.dolar", "market": "blue" },
{ "id": "io.github.xymbol.dolar", "market": "tarjeta" }
```

Each pill labels itself, so they stay distinguishable, and each remembers its
own selection independently.

### Icon

By default the pill is prefixed with the market's name — `Blue 1.545` — because
the rate can be switched from the panel, so the pill has to say which one it is
showing. Set `icon` to swap that label for a glyph instead. These are all
present in JetBrainsMono Nerd Font:

| Glyph | Codepoint | Name |
|---|---|---|
| `` | U+F155 | nf-fa-dollar |
| `󰯅` | U+F0BC5 | md-cash-multiple |
| `󰄔` | U+F0114 | md-cash |
| `󰋒` | U+F02D2 | md-currency-usd |

## Changing the rate

The panel is not read-only. **Click any row** and the bar pill switches to that
market; **scroll the pill** to step through the same list without opening the
panel at all. The choice persists across restarts in
`~/.local/state/omarchy/settings/dolar.json`.

It is fully keyboard-driven, which is the point on a distro you mostly drive
without a pointer:

| Key | Action |
|---|---|
| `j` / `k`, `↓` / `↑` | Move the cursor, wrapping at both ends |
| `Enter` / `Space` | Switch the pill to the row under the cursor |
| `r` | Refresh now |
| `Esc` | Close the panel |
| `Tab` / `Shift+Tab` | Move to the next / previous bar panel |

The cursor opens on whichever row is currently showing, and the mouse drives
the same cursor rather than a highlight of its own, so pointer and keyboard
never disagree about which row is current. The active market stays accent-
coloured while the cursor moves, so you can always see both what you have and
what you are about to pick.

Omarchy 4.0.2 has no built-in settings UI for plugin widgets — the manifest
accepts `settingsForm` and `schema`, but nothing in the shell reads them yet —
so a plugin that wants to be adjustable has to offer its own affordances and
persist the result itself. This one does.

The `market` value in `shell.json` stays meaningful: it is the **default**, used
until something is stored, and it is the key each pill's selection is filed
under, which is what lets two pills remember different rates.

## Behaviour

- **Middle click** the pill forces a refresh. **Left click** toggles the panel.
- Deleting the state file resets every pill to its configured `market`, live — no restart.
- The last good response stays on screen when a refresh fails, so closing the
  laptop lid and reopening it somewhere else shows the previous number rather
  than a blank pill. The footer says `sin conexión · último dato 17:58` while
  that is the case.
- A failed fetch retries three times, four seconds apart, before falling back to
  the normal interval — enough to cover wifi reassociating after a resume.
- The panel timestamp is the most recent one in the payload. dolarapi stamps
  each rate separately and they drift apart: the oficial stops updating at
  18:00 while the blue keeps moving.

## Notes

Amounts are formatted the Argentine way — `.` groups thousands, `,` is the
decimal mark — regardless of the system locale, which on most machines is not
`es-AR`.

Data from [dolarapi.com](https://dolarapi.com). This plugin is not affiliated
with them; be a good citizen about the refresh interval.

## License

MIT — see [LICENSE](LICENSE).
