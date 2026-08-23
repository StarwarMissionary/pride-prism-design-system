# Steam adapter

Steam does not expose a native custom-palette setting. This adapter is a CSS-only theme for [Millennium](https://github.com/SteamClientHomebrew/Millennium), the open-source third-party Steam client theming framework. Millennium changes how Steam loads at startup; review its documentation before installing it.

## Install

1. Install Millennium from its [official Windows installation page](https://docs.steambrew.app/users/getting-started/installation).
2. Run `install.ps1`. It resolves the registered Steam path, backs up any existing `PridePrism` theme folder, and copies the adapter to Millennium's active theme directory (`millennium\themes\PridePrism` in current releases, with legacy-path detection). On current Millennium releases it also backs up the configuration, selects Pride Prism, enables scoped CSS, and keeps executable theme JavaScript disabled.
3. The adapter uses Millennium's default scoped patches: Library and desktop shell, Friends and Chat, Big Picture, and Steam webviews each receive their own stylesheet. If an older Pride Prism install generated global Quick CSS, the installer preserves it as `quick.css.backup-*` and removes that obsolete global injection so the Library layout and auxiliary windows do not interfere with one another.
4. Restart Steam when Millennium requests it.

The theme uses vanilla CSS and contains no executable JavaScript. Motion is limited to a slow edge accent and is disabled by `prefers-reduced-motion`.

## Roll back

Select the default theme in Steam, or run `Start-Process "steam://millennium/settings/themes/disable"`. The installer preserves the previous theme directory and Millennium configuration with timestamped backup names. Restore the relevant backup if needed. To remove Millennium itself, use its [official uninstall workflow](https://docs.steambrew.app/users/parting-ways/uninstall).
