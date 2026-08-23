# Pride Prism Windows cursor

This adapter installs the rounded [Bibata Rainbow Modern](https://github.com/ful1e5/Bibata_Cursor_Rainbow) cursor artwork as a reversible per-user Windows scheme. The upstream project is GPL-3.0 licensed. No upstream binaries are stored in this repository: `install.ps1` downloads the official v1.1.2 Windows release and verifies its SHA-256 hash before use.

To keep the desktop calm, normal pointers are frozen to their first rainbow frame. Only the standard **Working in Background** and **Busy** roles retain the upstream animation.

## Install

Run `install.ps1`. It saves the original cursor registry values to `%LOCALAPPDATA%\PridePrism\cursor-backup.json`, installs the cursor files under `%LOCALAPPDATA%\PridePrism\Cursors`, registers the scheme, and refreshes all 17 pointer roles in the signed-in desktop session without logging out or restarting.

## Restore

Run `restore.ps1`. It restores the exact values captured before the first Pride Prism cursor installation and refreshes all pointer roles immediately. Installed cursor assets remain on disk so the operation is recoverable and the scheme can be reapplied later.
