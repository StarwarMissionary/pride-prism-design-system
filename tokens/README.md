# Shared theme contract

`palettes.json` is the reusable public reference catalog. `theme.mjs` is the same pure module used by the browser preview and Node exporter. It does not read preferences, contact a service, or modify a page. Public defaults are neutral; a palette choice is not a declaration of personal identity.

```js
import { createTheme, themeCss, contrast } from "./theme.mjs";
const theme = createTheme(catalog, "bisexual");
const custom = createTheme(catalog, "neutral", "#E866AF");
```

Accents and contrast inputs accept only opaque six-digit `#RRGGBB` hex. Invalid input throws. `createTheme` validates the catalog, keeps reference colors and stripe proportions, selects a readable `onAccent`, and derives hover/pressed colors that retain at least 4.5:1 text contrast. Link, focus, and status colors stay independent of the selected identity palette. Black/white text is used only when the neutral inks cannot meet that contrast threshold.

`theme.colors` is the semantic contract. Use `foreground` on neutral surfaces and `onAccent` on `accent`, `accentHover`, and `accentPressed`. `accent` is a control fill, not a general-purpose body-text color. `border` supplies a visible boundary for controls even when a custom accent resembles the surface. `borderSubtle` is decorative and must not be the sole indicator of a control. Place focus rings outside a control with the defined offset, or use a contrasting separator. Never use identity colors as substitutes for success, warning, or error semantics. Status labels/icons must supplement color.

The `gradient` is a hard-stop, ordered decorative rail; it is not a universal representation of a flag. In particular, `progress-inspired` is explicitly a palette rather than the original chevron flag. Reference colors are digital approximations with attribution; adjusted UI accents are separate values.

`themeCss(theme)` emits only a `:root` custom-property block. Color and metric names become `--prism-kebab-case` (for example, `surfaceRaised` becomes `--prism-surface-raised`). Motion durations become `--prism-motion-fast`, `--prism-motion-standard`, `--prism-motion-decoration`, and `--prism-motion-celebration`, with `ms` units. Decoration defaults to off/static. The module never adds a global animation reset or host-app layout rules. Adapters own motion consent and reduced-motion handling.

## Export and validation

From the repository root:

```powershell
node scripts/build-theme.mjs --palette bisexual --output dist/bisexual
node scripts/build-theme.mjs --palette neutral --accent '#E866AF' --output dist/custom
node scripts/test-theme.mjs
```

The exporter writes `theme.json`, `pride-prism.css`, `PridePrism.xaml`, and adapter copies. It injects CSS variables into copied stylesheets, preserving Discord metadata. It also renders a dark Codex appearance snippet and neutral Chrome manifest colors. It does not install anything. Output is restricted to this repository's `dist` tree, rejects links, and requires an empty directory or its own generated-output marker before overwriting. Use a fresh output directory after removing source adapters: export does not delete stale files. Local installer `.install-state` directories are excluded from exports.

Fixed legacy Chrome image references are omitted because those bitmap files do not represent every preset. Matching wallpapers/Chrome bitmaps require a separate asset-generation step. Native app support is limited by each adapter; a CSS export alone cannot theme an unrelated application.

Regenerate only the three tracked default exports after module/catalog changes:

```powershell
node scripts/build-theme.mjs --write-defaults
```

These are explicitly dark, neutral, project-format JSON/CSS/XAML exports, not a claim of DTCG conformance. The browser site must receive an identical copy of `theme.mjs` and `palettes.json` through its own build/publish workflow. Personal settings belong in local storage or a git-ignored local configuration, never in the public catalog.
