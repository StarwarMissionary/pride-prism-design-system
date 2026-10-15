# Application support and verification

Generated bundles share color roles. Native support and runtime verification are separate.

| App | Delivery path | Scope | Limits / required acceptance |
| --- | --- | --- | --- |
| [Windows](../adapters/windows/) | Per-user preferences | Dark mode, native accent | Not every Win32 app follows Windows colors. Preserve wallpaper/cursor; run in interactive user session; inspect after broadcast. |
| [Terminals](../adapters/terminals/) | Generated scheme files | Windows Terminal, Alacritty, WezTerm, kitty | Mergeable snippets; nothing is written to a live config. Key names follow each tool's documentation; verify after the next launch. |
| [VS Code](../adapters/vscode/) | Local extension folder | Workbench, syntax, integrated terminal | Install by copying into the extensions directory; no marketplace publishing. Semantic highlighting uses the documented scope fallbacks. |
| [Firefox](../adapters/firefox/) | Static theme package | Frame, toolbar, URL bar, popups, sidebar, new tab | Temporary load via about:debugging; permanent install requires signing. Manifest V2 is the documented theme format. |
| [Obsidian](../adapters/obsidian/) | Theme folder | Documented CSS variables, identity rail | Dark mode only; light mode keeps defaults. Variables beyond the documented foundation set may change between Obsidian releases. |
| [Linux desktops](../adapters/linux/) | GTK 4 `gtk.css`, Plasma `.colors` | Named colors, color sets | Apps with their own stylesheets may override GTK named colors. Plasma section/key names follow shipped schemes, not a formal spec. |
| [Steam](../adapters/steam/) | Existing Millennium, CSS-only | Library, game details, downloads, menus/settings, Friends/Chat, Store/Community, Big Picture | Third-party client framework. Each view needs live visual checks; aliases can change with Steam updates. Never infer full coverage from one window. |
| [Discord](../adapters/discord/) | Existing Vencord CSS | Exposed surface/text tokens, static identity rail | Third-party client modification, not Discord's native theming API. Legacy controls use safe dark selection fills; role/presence colors preserved. Live compatibility varies. |
| [Chrome](../adapters/chrome/) | Theme-only extension | Native frame/toolbar/new-tab colors, optional generated bitmaps | No site access. Chrome owns caption controls and cached theme resources; reload the existing package to adopt updates. |
| [Chrome start page](../adapters/chrome-start-page/) | Permissionless extension | Search, clock, local shortcuts, finite celebration | Separate from browser chrome. Retain the installed extension path/id to preserve local shortcut storage. |
| [ChatGPT / Codex](../adapters/chatgpt/) | Native desktop appearance snippet | Dark surface, accent, text and semantic config | This schema applies to Codex desktop appearance, not every ChatGPT product. Preserve all unrelated config; loading behavior varies. No UI injection or forced restart. |
| [Blender](../adapters/blender/) | Partial preset XML, or staged preferences | Allowed interface colors only | The XML applies only listed attributes on top of the active theme. Preserve font metrics, ThemeStyle, scene/material/wire colors and add-ons; the staged path adds an isolated test and closed-app guarded commit. |
| [Unity](../adapters/unity/) | Supported preferences plus generated USS | Dark theme, exposed Colors choices, custom editor windows | Partial palette support. USS styles only windows that import it. No documented arbitrary full-editor palette import; never patch resource archives or project files. |

## Release vocabulary

- **Generated:** source bundle built and static contract checks passed.
- **Installed:** backed-up settings/assets copied successfully.
- **Loaded:** app has demonstrably read the new settings/assets.
- **Visually verified:** specific named app views inspected with content and control states.
- **Pending:** requires a user action or a currently unavailable verification surface.

Do not collapse these states into “done.” Source validation does not prove an installed app's appearance.
