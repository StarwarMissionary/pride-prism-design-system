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

`themeCss(theme)` emits only a `:root` custom-property block. Color and metric names become `--prism-kebab-case` (for example, `surfaceRaised` becomes `--prism-surface-raised`, `space2xl` becomes `--prism-space-2xl`). Motion durations become `--prism-motion-fast`, `--prism-motion-standard`, `--prism-motion-decoration`, and `--prism-motion-celebration`, with `ms` units. Decoration defaults to off/static. The module never adds a global animation reset or host-app layout rules. Adapters own motion consent and reduced-motion handling.

Beyond `colors`, a theme carries `gradients` (`--prism-identity-gradient`, `-vertical`, `-diagonal`, `-conic`, `-wash`), one variable per reference stripe (`--prism-stripe-1` … and `--prism-stripe-count`), `effects` (`--prism-glass`, `--prism-glass-border`, `--prism-glass-blur`, `--prism-glow`, `--prism-accent-wash`; translucent CSS values that reference the emitted variables), and `terminal` (`--prism-ansi-*`). Adapters that cannot use CSS read the same groups from `theme.json`; the XAML export carries the stripes, ANSI colors and the directional gradient brushes.

## Export and validation

From the repository root:

```powershell
node scripts/build-theme.mjs --palette bisexual --output dist/bisexual
node scripts/build-theme.mjs --palette neutral --accent '#E866AF' --output dist/custom
node scripts/test-theme.mjs
```

The exporter writes `theme.json`, `pride-prism.css`, `PridePrism.xaml`, and adapter copies. It injects CSS variables into copied stylesheets, preserving Discord metadata. It also renders generated files from source markers: the Chrome and Firefox manifests, the Codex appearance snippet, terminal schemes, the VS Code theme, Unity USS, GTK named colors and the KDE color scheme. It does not install anything. Output is restricted to this repository's `dist` tree, rejects links, and requires an empty directory or its own generated-output marker before overwriting. Use a fresh output directory after removing source adapters: export does not delete stale files. Local installer `.install-state` directories are excluded from exports.

The Chrome package is exported with colors only. Matching Chrome bitmaps and a wallpaper are painted per bundle by `scripts/generate-assets.ps1`, which also restores the manifest's image references. Native app support is limited by each adapter; a CSS export alone cannot theme an unrelated application.

Regenerate only the three tracked default exports after module/catalog changes:

```powershell
node scripts/build-theme.mjs --write-defaults
```

These are explicitly dark, neutral, project-format JSON/CSS/XAML exports, not a claim of DTCG conformance. The browser site must receive an identical copy of `theme.mjs` and `palettes.json` through its own build/publish workflow. Personal settings belong in local storage or a git-ignored local configuration, never in the public catalog.
