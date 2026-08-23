# Pride Prism Design System

Pride Prism is a polished, high-contrast Pride theme system for desktop apps. Its default is dark mode, it uses native theming where an app supports it, and it keeps motion optional, restrained, and reversible.

**Live design system:** https://starwarmissionary.github.io/pride-prism-design-system/

## Included

- Shared color, typography, motion, and effect tokens in JSON, CSS, and XAML.
- A native ChatGPT/Codex configuration adapter.
- A permissionless Chrome theme package with no scripts or site access.
- A separate permissionless Chrome start page with local shortcuts and opt-in celebration.
- A portable Windows `.theme` package plus a per-user rainbow cursor scheme and restore workflow.
- Discord custom-gradient values plus a no-restart theme for existing Vencord installs.
- A Millennium-compatible Steam theme, kept CSS-only and reversible.
- The optional Pride Prank Lab overlay for live celebration effects across supported desktop windows.

## Default character

- Deep violet surfaces with white text.
- Magenta focus/accent color.
- Classic Pride and Progress Pride palettes for decoration and semantic states.
- No continuous confetti, flashing, or full-screen tint by default.
- Slow five-second accent transitions; celebration bursts are explicit.

## Quick start

1. Review the tokens in `tokens/pride-prism.tokens.json`.
2. Use the adapter README for the target application.
3. Run `scripts/validate.ps1` before distributing changes.

The Windows and Chrome adapters include generated bitmap assets. Recreate them with `scripts/generate-assets.ps1`.

## Safety and reversibility

Pride Prism does not modify signed application binaries. The Chrome package is theme-only and requests no permissions. The Windows installers save the previous theme and cursor values before making per-user changes. Discord can use its native Nitro editor or the local Vencord theme when Vencord is already installed. Steam's client does not expose custom palettes, so its CSS-only adapter requires the optional third-party, open-source Millennium framework; the adapter README documents installation and rollback.

## References

- [ChatGPT desktop appearance settings](https://learn.chatgpt.com/docs/reference/settings)
- [Discord custom themes](https://support.discord.com/hc/en-us/articles/207260127-How-to-Change-Discord-Color-Themes-and-Customize-Appearance-Settings)
- [Chrome themes](https://developer.chrome.com/docs/extensions/mv2/themes)
- [Windows theme file format](https://learn.microsoft.com/en-us/windows/win32/controls/themesfileformat-overview)
- [Millennium installation](https://docs.steambrew.app/users/getting-started/installation)
- [Millennium theme template](https://github.com/SteamClientHomebrew/ThemeTemplate)

## License

MIT
