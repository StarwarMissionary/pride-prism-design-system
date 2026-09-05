# Windows native preferences adapter

Consumes a generated `theme.json`. The default changes only current-user app/system dark mode and the native title-bar accent. It never applies a `.theme` file, replaces wallpaper/cursors, changes fonts/scaling, restarts Explorer/apps, or patches resources. The old template/wallpaper assets remain available but are not used by this installer.

```powershell
.\adapters\windows\install.ps1 -ThemeJson 'C:\path\to\generated\theme.json' -WhatIf
$result = .\adapters\windows\install.ps1 -ThemeJson 'C:\path\to\generated\theme.json'
.\adapters\windows\restore.ps1 -BackupPath $result.BackupPath
```

## Scope and session requirements

The eight owned values are `AppsUseLightTheme`, `SystemUsesLightTheme` under `HKCU\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize`; `AccentPalette`, `AccentColorMenu`, `StartColorMenu` under `HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Accent`; and `AccentColor`, `ColorizationColor`, `ColorPrevalence` under `HKCU\Software\Microsoft\Windows\DWM`.

This is a Windows 10-specific preference-layout implementation, not a supported native accent-setting API. On the observed layout, Explorer's accent preferences can replace separately written DWM colors when notified. The adapter therefore writes the existing Explorer source values before DWM. It requires existing Explorer menu DWORD values, an existing 32-byte binary palette whose first seven colors are opaque RGBA, and an existing DWORD `ColorizationColor`. Missing values or unexpected formats fail before any preference write; it does not invent another key or palette format.

The accent comes from `colors.accent`. `AccentColorMenu` and DWM `AccentColor` use opaque ABGR DWORDs. `ColorizationColor` uses ARGB and preserves its existing high alpha byte exactly; opacity preferences are not changed. The palette's first seven RGBA entries use deterministic mixes: 55%, 35%, and 18% toward white; the exact accent at index 3; then 18%, 35%, and 55% toward black. `StartColorMenu` is the ABGR DWORD for darker index 4. The final four palette bytes have an unknown purpose and are preserved byte-for-byte. This project ramp does not claim to reproduce Windows' private shade-generation algorithm.

These registry preference names are Windows implementation details, not a documented public global-theme setter. The notification mechanism is the documented [`WM_SETTINGCHANGE`](https://learn.microsoft.com/en-us/windows/win32/winmsg/wm-settingchange) / [`SendMessageTimeout`](https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-sendmessagetimeoutw) API. Verify on the target Windows build. After notification, both install and restore re-read their expected values and return `PersistedMatches` plus explicit typed `PersistedMismatches`. A mismatch is not reported as a successful live color application. Even a match is only an immediate registry observation, not proof of later persistence or visual adoption. There are no background retries or watchers. Native Settings > Personalization > Colors is the fully supported manual fallback. Applications may use their own colors or refresh only on their next normal launch; do not force restarts.

Run as the signed-in user in an interactive session. Session 0, SYSTEM, and noninteractive window stations fail before preference writes. An operator may explicitly invoke the script through a hidden, limited, **interactive-token** scheduled task for that same user; this adapter never creates such a task or silently uses an invisible desktop. Notification timeouts are reported rather than treated as visual success.

## Backups and rollback

Each invocation creates a unique timestamp/GUID directory under `%LOCALAPPDATA%\PridePrism\Windows\Backups`. `snapshot.json` records types, existence, unexpanded strings and binary data for theme, Personalize, Explorer accent, DWM, desktop/wallpaper and cursor/scheme values. The current theme file's exact bytes and hash are also saved when that file exists locally. No wallpaper or cursor assets are changed.

Restore requires an explicit snapshot path and the same user SID. New schema-2 snapshots allow exactly the eight owned values; schema-1 snapshots retain their original five-value allowlist and cannot restore Explorer values that the old run never changed. Restore applies **only values actually changed by that run**, including deleting a value that was originally absent. Already-restored values are harmless. Later conflicting edits stop restoration before writes; `-Force` is an explicit choice to discard those later edits. Snapshot-only wallpaper/cursor values and theme contents are deliberately not restored over newer user choices. Backups remain on disk. Old `previous-theme.txt`/`previous-dwm.json` files are retained but are not exact rollback snapshots for this installer.

For pure validation, dot-source `install.ps1 -LibraryOnly`; it defines helpers without reading or writing the registry, sending notifications, or checking an interactive session. `New-PrismExplorerAccentPalette`, `ConvertTo-PrismAccent`, `New-PrismWindowsChanges`, and `Test-PrismRegistryEntry` can be exercised with synthetic typed snapshots.

The separate [cursor adapter](cursor/) is opt-in and unchanged. The existing full-rainbow scheme is not automatically recolored by a bisexual palette selection.
