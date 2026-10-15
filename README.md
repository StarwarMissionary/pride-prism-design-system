# Pride Prism Design System

One dark foundation, your palette, every app. Pride Prism turns an attributed catalog of Pride flag colors and original palettes into a complete dark theme, then generates ready-to-install adapters for the desktop software you already use.

Original concept, inspiration and influence: **Cinder**. Current maintainer: [StarwarMissionary](https://github.com/StarwarMissionary).

[Palette workbench](https://starwarmissionary.github.io/pride-prism-design-system/) · [Foundation audit](docs/FOUNDATION_AUDIT.md) · [Design contract](docs/DESIGN_SYSTEM.md) · [App support](docs/APP_MATRIX.md) · [Verification](docs/VERIFICATION.md)

## What you get

- **Twenty-four palettes.** Sixteen attributed flag palettes, two inspired palettes that are explicitly not flags, and six original palettes, plus a custom accent you can set independently. Every preset passes the same readability gates.
- **A single resolver.** `tokens/theme.mjs` derives eighteen semantic colors, hover and pressed states with tested text contrast, directional and conic identity gradients, a surface-safe wash, per-stripe variables, glass and glow effects, and a stable sixteen-color terminal set. The website and the exporter run the same module.
- **Generated bundles for fourteen targets.** Windows accent and dark mode, Windows Terminal, Alacritty, WezTerm, kitty, VS Code, Steam (Millennium), Discord (Vencord), Chrome, a Chrome start page, Firefox, Obsidian, GTK 4 and KDE Plasma, Codex desktop, Blender and Unity. Each adapter ships with install and rollback notes and never patches an application.
- **Quiet by default.** Decoration is static, celebrations are finite and opt-in, reduced motion is honored, and native layouts, artwork and status colors stay untouched.
- **A live workbench.** The GitHub Pages site previews any palette, measures contrast for every role, shows the decoration kit, and exports CSS and JSON without installing anything.

## Start with the foundation

`tokens/palettes.json` is the attributed public catalog. `tokens/theme.mjs` resolves it into semantic roles. The browser preview and exporter use the same module. Twenty-four presets ship: flag palettes (Bisexual, Rainbow, Transgender, Pansexual, Lesbian, Nonbinary, Asexual, Aromantic, Gay men, Genderfluid, Genderqueer, Agender, Polysexual, Omnisexual, Bear, Leather), two inspired palettes that are explicitly not flags (Progress, Intersex), and original palettes (Neutral, Aurora, Dusk, Ember, Tide, Prism). Use a custom interface accent independently.

Every theme resolves the same groups: `colors` (18 semantic roles), `gradients` (horizontal, vertical, diagonal, conic, and a surface-safe wash of the reference stripes), `effects` (glass, glow and accent wash as CSS values), `terminal` (sixteen dark-tuned ANSI colors plus cursor and selection), `metrics` and `motion`. Stripes are also emitted one per variable (`--prism-stripe-1` …) so adapters can build aurora meshes and foils without a second palette.

The public default is Neutral. A palette is a preference, not an identity declaration. Personal choices belong in browser storage or ignored local output, not the public repository.

## Build a palette bundle

Requires Node.js. From the repository root:

```powershell
node scripts/build-theme.mjs --palette bisexual --output dist/bisexual
node scripts/test-theme.mjs
```

The bundle contains `theme.json`, CSS, XAML and adapter copies with generated colors. Follow the **generated** adapter guide before installing. Do not install raw CSS templates from `adapters/`: their shared variables are injected at build time.

For matching Chrome bitmap assets (Windows PowerShell):

```powershell
./scripts/generate-assets.ps1 -ThemeJson ./dist/bisexual/theme.json -OutputRoot ./dist/bisexual
```

For a custom accent, add `--accent '#E866AF'`. Reference stripes retain their original colors and proportions. Functional action text uses a tested foreground pair; status and focus colors remain independent.

## Application coverage

- Windows: native dark preferences and accent, with typed rollback; wallpaper/cursor preserved.
- Terminals: Windows Terminal fragment, Alacritty, WezTerm and kitty schemes generated from the shared ANSI set.
- VS Code: a local color-theme extension covering workbench, syntax and the integrated terminal.
- Steam: CSS-only scoped patches using an existing optional Millennium installation.
- Discord: current semantic tokens plus legacy fallbacks for an existing Vencord installation.
- Chrome: theme-only package with neutral controls, plus a separate permissionless start page.
- Firefox: a static theme package for the frame, toolbar, popups and sidebar.
- Obsidian: documented CSS variables with a static identity rail.
- Linux desktops: GTK 4 named colors and a KDE Plasma color scheme.
- Codex desktop appearance: a mergeable native configuration snippet; not a universal ChatGPT web theme.
- Blender: a partial theme preset XML, or staged color-only preferences with backup and guarded commit.
- Unity: supported Dark and Colors preferences plus USS for your own editor tools; no editor archive patches.

See [support limits and verification gates](docs/APP_MATRIX.md). Exporting a bundle does not establish that an installed application is fully themed.

## Website and validation

The existing GitHub Pages site stays in `docs/`. No external site framework or account is required.

```powershell
node scripts/build-site.mjs
node scripts/preview-site.mjs
./scripts/validate.ps1
```

Open the printed local URL for preview. Before publishing, regenerate the shared site modules.

## Safety

The foundation does not patch application executables/resources, install client-mod frameworks, change security settings, or restart apps. Installers must preserve user work and explain native/third-party limitations. Local backups and generated personal bundles are excluded from Git.

The repository ships no fixed flag bitmaps or overlay applications. Chrome bitmaps and a wallpaper are painted per bundle by `scripts/generate-assets.ps1` from the selected palette; the only tracked image is the website's social preview.

## Credits

- **Cinder**: original creator of the Pride Prism idea and the inspiration and influence behind its design direction.
- **StarwarMissionary**: current maintainer of this repository, the palette catalog, the exporter and the adapters.
- Reference flag colors are attributed per preset in `tokens/palettes.json`; the cursor adapter credits the upstream Bibata project.

## License

MIT. Reference flag colors are attributed in the catalog; it is non-exhaustive and not a claim of universal identity representation.
