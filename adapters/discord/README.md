# Discord surface adapter

This CSS adapter requires an **existing** Vencord installation. Vencord is a third-party client modification, not Discord's native appearance API. The theme does not install it or patch Discord application files.

Build the palette, then back up the existing theme and copy the generated `dist/<palette>/adapters/discord/PridePrism.theme.css` into `%APPDATA%/Vencord/themes`. Enable Pride Prism in Vencord Themes. If already enabled, its file watcher may reload it; verify the result rather than forcing Discord to restart.

Shared surfaces, text and a static identity rail are themed. Presence, roles, media and native progress are preserved. Legacy brand buttons use a dark selection fill because their text/icon foregrounds cannot reliably be paired with arbitrary bright accents.

To undo, disable the theme or restore the backed-up CSS. Never replace unrelated QuickCSS.

The historical `pride-prism-gradient.json` is a legacy native-Nitro experiment, not a generated foundation adapter. It must not be used as the selected palette's source of truth. Native Nitro availability and coverage differ from Vencord; this bundle does not automate account or sync settings.
