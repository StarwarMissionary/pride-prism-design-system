# Steam adapter

Steam does not expose a native custom-palette setting. This adapter is a CSS-only theme for [Millennium](https://github.com/SteamClientHomebrew/Millennium), the open-source third-party Steam client theming framework. Millennium changes how Steam loads at startup; review its documentation before installing it.

## Shared foundation

The four source stylesheets map Steam-specific `--pp-*` aliases to the shared `--prism-*` tokens. They do not carry independent color palettes. Build a palette bundle before installing: the build prepends the selected shared tokens to each stylesheet. Do not install the raw source CSS on its own.

Dark neutral surfaces, text, selection, focus and button states come from the shared foundation. The selected Pride palette appears in static header/menu accents. Steam retains its native Play/purchase buttons, presence and download-status colors, discounts, review indicators, game artwork and controller focus geometry. Partial native coverage is intentional; this is not a promise to recolor every Steam surface.

## Install

1. Install Millennium from its [official Windows installation page](https://docs.steambrew.app/users/getting-started/installation).
2. From the repository root, generate the bisexual bundle (or select another palette supported by the shared catalog):

   ```powershell
   node scripts/build-theme.mjs --palette bisexual --output dist/bisexual
   ```

   Generation writes local export files only; it does not install or select a Steam theme.
3. Review the generated theme at `dist/bisexual/adapters/steam/PridePrism`. When ready to change the installed theme, run the **generated** installer from the repository root:

   ```powershell
   .\dist\bisexual\adapters\steam\install.ps1
   ```

   It resolves the registered Steam path, backs up any existing `PridePrism` theme folder, and copies the generated adapter to Millennium's active theme directory (`millennium\themes\PridePrism` in current releases, with legacy-path detection). On current Millennium releases it also backs up the configuration, selects Pride Prism, enables scoped CSS, and keeps executable theme JavaScript disabled.
4. The adapter uses Millennium's default scoped patches: Library and desktop shell, Friends and Chat, Big Picture, and Steam webviews each receive their own stylesheet. The installer leaves global Quick CSS unchanged. If it detects older Pride Prism rules, review that file, save a backup and remove only the obsolete rules; it may also contain unrelated user customizations. Mixed or unknown Quick CSS is never cleared automatically.
5. Restart Steam only when required by Millennium or the installation workflow.

The theme uses vanilla CSS and contains no executable JavaScript or continuous decorative animation. Its own hover transitions are finite and respect `prefers-reduced-motion`; Steam's native connection/status feedback is not globally disabled.

## Surface boundaries and verification

- Library backgrounds target real content panels. Full-pane `AppDetailsOverlayTransitionGroup` layers remain transparent, and the theme does not force the sidebar width, positioning, clipping or visibility.
- Friends decorates `friendListHeaderContainer`, never the overlaid `chatTitleBar` hit-area. The existing list-only Away label readability repair remains scoped so collapsed chat navigation stays collapsed.
- Downloads styles page/panel backgrounds and named text fields. Charts, progress fills, status hues and nonempty hero artwork remain native.
- Store styles the actual navigation/dropdown wrapper and capsule text panels. No takeover tint, artwork overlay, global link recoloring, card clipping or discount override is added.
- Big Picture styles the actual non-VR menu panel, Quick Access and footer surfaces. The full-window `MainMenuEmbedded` overlay, zero-width `MainNavMenuAnchor`, transparent/true-black home modes, artwork and native focus-ring geometry are not repainted or resized.

Before distribution, verify the generated stylesheet token references and selector safety, then check these boundaries in a user-authorized Steam session. Include Library details and sidebar resizing, empty/active Downloads, Friends presence and collapsed groups, Store navigation/dropdowns and artwork, and controller navigation in Big Picture. Exercise hover, selected, disabled and keyboard/controller focus states. Source validation alone does not establish compatibility with a particular Steam/Millennium version.

## Roll back

Select the default theme in Steam, or run `Start-Process "steam://millennium/settings/themes/disable"`. The installer preserves the previous theme directory and Millennium configuration with timestamped backup names. Restore the relevant backup if needed. To remove Millennium itself, use its [official uninstall workflow](https://docs.steambrew.app/users/parting-ways/uninstall).
