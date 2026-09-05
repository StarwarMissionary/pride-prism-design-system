# Chrome theme

Build a chosen palette from the repository root:

```powershell
node scripts/build-theme.mjs --palette bisexual --output dist/bisexual
./scripts/generate-assets.ps1 -ThemeJson dist/bisexual/theme.json -OutputRoot dist/bisexual
```

Load `dist/bisexual/adapters/chrome` as an unpacked theme through Chrome's Extensions page. Installation requires an explicit user choice. This theme-only Manifest V3 package has no scripts, permissions or site access.

For an existing unpacked installation, back up its folder, then replace its files with the generated package **at the same path** and use its Reload control. Chrome may cache theme assets; a successful file copy is not proof the theme reloaded. Never edit Chrome's Preferences files or force a browser restart.

The frame and caption-control area are neutral. A thin identity rail is decorative; window buttons are not tinted pink. Chrome determines exact native caption rendering.

To undo, use Chrome Settings > Appearance > Reset to default, or restore the backed-up unpacked files and reload. The separate start-page extension has its own rollback.
