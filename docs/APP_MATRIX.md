# Application support and verification

Generated bundles share color roles. Native support and runtime verification are separate.

| App | Delivery path | Scope | Limits / required acceptance |
| --- | --- | --- | --- |
| [Windows](../adapters/windows/) | Per-user preferences | Dark mode, native accent | Not every Win32 app follows Windows colors. Preserve wallpaper/cursor; run in interactive user session; inspect after broadcast. |
| [Steam](../adapters/steam/) | Existing Millennium, CSS-only | Library, game details, downloads, menus/settings, Friends/Chat, Store/Community, Big Picture | Third-party client framework. Each view needs live visual checks; aliases can change with Steam updates. Never infer full coverage from one window. |
| [Discord](../adapters/discord/) | Existing Vencord CSS | Exposed surface/text tokens, static identity rail | Third-party client modification, not Discord's native theming API. Legacy controls use safe dark selection fills; role/presence colors preserved. Live compatibility varies. |
| [Chrome](../adapters/chrome/) | Theme-only extension | Native frame/toolbar/new-tab colors, optional generated bitmaps | No site access. Chrome owns caption controls and cached theme resources; reload the existing package to adopt updates. |
| [Chrome start page](../adapters/chrome-start-page/) | Permissionless extension | Search, clock, local shortcuts, finite celebration | Separate from browser chrome. Retain the installed extension path/id to preserve local shortcut storage. |
| [ChatGPT / Codex](../adapters/chatgpt/) | Native desktop appearance snippet | Dark surface, accent, text and semantic config | This schema applies to Codex desktop appearance, not every ChatGPT product. Preserve all unrelated config; loading behavior varies. No UI injection or forced restart. |
| [Blender](../adapters/blender/) | Native theme colors via staged preferences | Allowed interface colors only | Preserve font metrics, ThemeStyle, scene/material/wire colors and add-ons. An isolated test and closed-app guarded commit precede adoption. |
| [Unity](../adapters/unity/) | Supported preferences | Dark theme and exposed Colors choices | Partial palette support. No documented arbitrary full-editor palette import; never patch resource archives or project files. |

## Release vocabulary

- **Generated:** source bundle built and static contract checks passed.
- **Installed:** backed-up settings/assets copied successfully.
- **Loaded:** app has demonstrably read the new settings/assets.
- **Visually verified:** specific named app views inspected with content and control states.
- **Pending:** requires a user action or a currently unavailable verification surface.

Do not collapse these states into “done.” Source validation does not prove an installed app's appearance. The optional legacy overlay is not evidence of native theming and is not a required dependency.
