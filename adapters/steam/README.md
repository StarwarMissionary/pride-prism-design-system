# Steam adapter

Steam does not expose a native custom-palette setting. This adapter is a CSS-only theme for [Millennium](https://github.com/SteamClientHomebrew/Millennium), the open-source third-party Steam client theming framework. Millennium changes how Steam loads at startup; review its documentation before installing it.

## Install

1. Install Millennium from its [official Windows installation page](https://docs.steambrew.app/users/getting-started/installation).
2. Run `install.ps1`. It resolves the registered Steam path, backs up any existing `PridePrism` theme folder, and copies the adapter to Millennium's active theme directory (`millennium\themes\PridePrism` in current releases, with legacy-path detection).
3. In Steam, open **Steam -> Millennium -> Themes** and choose **Pride Prism**. If the Millennium CLI is available, `millennium themes use PridePrism` performs the same selection.
4. Restart Steam when Millennium requests it.

The theme uses vanilla CSS and contains no executable JavaScript. Motion is limited to a slow edge accent and is disabled by `prefers-reduced-motion`.

## Roll back

Select the default theme in Steam, or run `Start-Process "steam://millennium/settings/themes/disable"`. To remove Millennium itself, use its [official uninstall workflow](https://docs.steambrew.app/users/parting-ways/uninstall).
