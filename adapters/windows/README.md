# Windows adapter

The installer uses the documented Windows `.theme` format. It copies the generated wallpaper into `%LOCALAPPDATA%\PridePrism`, saves the previous theme path, installs a dark-mode theme under the current user's theme directory, and opens it through the normal Windows theme handler.

```powershell
./install.ps1
```

Restore the previously recorded theme:

```powershell
./restore.ps1
```
