# Windows adapter

The installer uses the documented Windows `.theme` format. It copies the generated wallpaper into `%LOCALAPPDATA%\PridePrism`, saves the previous theme and title-bar accent preference, installs a dark-mode theme under the current user's theme directory, and opens it through the normal Windows theme handler. Violet title-bar accents are enabled so native application frames participate in the theme.

```powershell
./install.ps1
```

Restore the previously recorded theme:

```powershell
./restore.ps1
```

## Cursor scheme

The separate [`cursor`](cursor/) adapter installs Pride Prism's rainbow pointer set for the current user without a restart. It preserves the original cursor registry values and includes its own restore script.
