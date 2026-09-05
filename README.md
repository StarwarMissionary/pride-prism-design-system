# Pride Prism Design System

A dark, palette-selectable foundation for desktop themes. Shared neutrals, tested control colors, static identity decoration and adapter-specific native layouts.

[Palette workbench](https://starwarmissionary.github.io/pride-prism-design-system/) · [Foundation audit](docs/FOUNDATION_AUDIT.md) · [Design contract](docs/DESIGN_SYSTEM.md) · [App support](docs/APP_MATRIX.md) · [Verification](docs/VERIFICATION.md)

## Start with the foundation

`tokens/palettes.json` is the attributed public catalog. `tokens/theme.mjs` resolves it into semantic roles. The browser preview and exporter use the same module. Choose from Bisexual, Rainbow, Progress-inspired, Transgender, Pansexual, Lesbian, Nonbinary, Asexual, Aromantic and Neutral; use a custom interface accent independently.

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
- Steam: CSS-only scoped patches using an existing optional Millennium installation.
- Discord: surface-token CSS for an existing Vencord installation.
- Chrome: theme-only package with neutral controls, plus a separate permissionless start page.
- Codex desktop appearance: a mergeable native configuration snippet; not a universal ChatGPT web theme.
- Blender: staged, color-only preferences with backup and guarded commit.
- Unity: supported Dark and Colors preferences; no editor archive patches.

See [support limits and verification gates](docs/APP_MATRIX.md). Exporting a bundle does not establish that an installed application is fully themed.

## Website and validation

The existing GitHub Pages site stays in `docs/`. No external site framework or account is required.

```powershell
node scripts/build-site.mjs
node scripts/preview-site.mjs
./scripts/validate.ps1
```

Open the printed local URL for preview. Before publishing, regenerate the shared site modules. The validator does not build or run the optional legacy overlay unless `-BuildOptionalOverlay` is explicitly supplied.

## Safety

The foundation does not patch application executables/resources, install client-mod frameworks, change security settings, or restart apps. Installers must preserve user work and explain native/third-party limitations. Local backups and generated personal bundles are excluded from Git.

`tools/PridePrankLab` is a legacy optional experiment, not the theme engine or a required app. Its independent palette/effect UI is not the shared-system configuration surface; continuous border/accent effects now start disabled. Do not use it to claim native application coverage.

## License

MIT. Reference flag colors are attributed in the catalog; it is non-exhaustive and not a claim of universal identity representation.
