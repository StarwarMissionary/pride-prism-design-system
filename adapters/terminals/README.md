# Terminal color schemes

Generated from `theme.terminal`: sixteen ANSI colors tuned for the dark neutrals, with the cursor on the selected accent and the shared selection pair. Like status colors, the ANSI set does not change with the identity palette, so diffs, logs and prompts keep stable meaning; the reference stripes are placed in the extended palette (slots 16 and up) where a terminal supports it. Every text-role ANSI color keeps at least 4.5:1 against the canvas.

Build a palette, then use the generated file for your terminal:

| File | Install |
| --- | --- |
| `windows-terminal.json` | A JSON fragment. Copy it to `%LOCALAPPDATA%\Microsoft\Windows Terminal\Fragments\PridePrism\pride-prism.json`, restart Windows Terminal, then set `colorScheme` on a profile. The `schemes[0]` object can also be pasted into `settings.json`. |
| `alacritty.toml` | Add it to `[general] import` in `alacritty.toml`, or paste the `[colors.*]` tables. |
| `wezterm.toml` | Load with `wezterm.color.load_scheme` or copy the `[colors]` table into `config.colors`. |
| `kitty.conf` | `include pride-prism.conf` from `kitty.conf`. |

For a Windows 11 Mica window, add this optional theme to `settings.json` and select it under Appearance (the `frame` keys need Windows Terminal Preview):

```json
{ "name": "Pride Prism", "window": { "applicationTheme": "dark", "useMica": true }, "tab": { "background": "terminalBackground" }, "tabRow": { "background": "#00000000" } }
```

Nothing is installed automatically. Back up the existing configuration first; a scheme file is a reversible, mergeable snippet, not a replacement for the whole configuration.

Reference: [Windows Terminal color schemes](https://learn.microsoft.com/en-us/windows/terminal/customize-settings/color-schemes), [Alacritty configuration](https://alacritty.org/config-alacritty.html), [WezTerm colors](https://wezterm.org/config/appearance.html), [kitty configuration](https://sw.kovidgoyal.net/kitty/conf/).
