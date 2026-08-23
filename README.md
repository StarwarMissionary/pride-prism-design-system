# Pride Prism Design System

Pride Prism is a polished, high-contrast Pride theme system for desktop apps. Its default is dark mode, it uses native theming where an app supports it, and it keeps motion optional, restrained, and reversible.

**Live design system:** https://starwarmissionary.github.io/pride-prism-design-system/

## Included

- Shared color, typography, motion, and effect tokens in JSON, CSS, and XAML.
- A native ChatGPT/Codex configuration adapter.
- A permissionless Chrome theme package with no scripts or site access.
- A portable Windows `.theme` package and restore workflow.
- Discord custom-gradient values plus a non-invasive fallback.
- A Steam-safe fallback that does not patch or inject into the client.
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

Pride Prism does not modify signed application binaries. The Chrome package is theme-only and requests no permissions. The Windows installer saves the previous theme path. Discord and Steam fall back safely when their native clients do not expose the requested customization.

## References

- [ChatGPT desktop appearance settings](https://learn.chatgpt.com/docs/reference/settings)
- [Discord custom themes](https://support.discord.com/hc/en-us/articles/207260127-How-to-Change-Discord-Color-Themes-and-Customize-Appearance-Settings)
- [Chrome themes](https://developer.chrome.com/docs/extensions/mv2/themes)
- [Windows theme file format](https://learn.microsoft.com/en-us/windows/win32/controls/themesfileformat-overview)

## License

MIT
