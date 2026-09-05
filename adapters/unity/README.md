# Unity native-settings checklist

This adapter is deliberately read-only. It turns generated `theme.json` colors into a native Preferences checklist; it does not launch Unity, write EditorPrefs/registry values, compile scripts into projects, change layouts, or patch resource archives.

```powershell
.\adapters\unity\show-settings.ps1 -ThemeJson 'C:\path\to\generated\theme.json' | Format-Table -Wrap
```

In the user's normal Unity session, open Edit > Preferences. Select General > Editor Theme > Dark. Optional, bounded palette accents are Colors > Scene > Selected Outline (`colors.accent`) and Selected Children Outline (`colors.focus`), preserving each color's existing alpha. Record previous native values before changing them; rollback uses those same controls. Keep font/scaling, layouts, grids, material diagnostics and Playmode Tint unchanged. Preferences do not require a project asset or scene edit. If an existing view does not refresh, leave it until its next normal refresh/launch; no restart or domain reload is forced.

Unity documents Light/Dark and particular Colors controls, not an arbitrary global editor palette importer. Its `EditorPrefs` API documents storage and generic get/set operations, but does not establish a supported public contract for built-in theme keys. The audit found hashed binary color preference names locally; this adapter does not guess, encode or write them. Native Dark cannot by itself reproduce every bespoke background color across Unity's mixed UI frameworks.

## Existing resource patches and separate restoration

The native controls referenced here are supported by Unity 2022.3 and 6000.4. If an earlier theme modified `Editor\Data\Resources\unity editor resources`, native settings do not undo those patches. A separately maintained matching-version original backup may be stored under `%LOCALAPPDATA%\Unity\PridePrismThemeBackups\<version>\unity editor resources.original`; confirm its provenance and version before use.

Restoration is a separate operator action and may require administrator access to Program Files. Preserve/hash each current patched archive before any restoration; verify the backup against the recorded original for that exact installed version; close editors normally; never copy between versions. Stop on access denial; do not elevate or work around permissions automatically. Do not layer further resource patches on an existing modification. A successful archive restoration takes effect on the next normal launch and needs its own verification.

## Official references

- [Unity 6.4 General: Editor Theme](https://docs.unity3d.com/6000.4/Documentation/Manual/preferences-general.html)
- [Unity 6.4 Colors: selected outlines and Playmode Tint](https://docs.unity3d.com/6000.4/Documentation/Manual/preferences-colors.html)
- [Unity 2022.3 Preferences](https://docs.unity3d.com/2022.3/Documentation/Manual/Preferences.html)
- [EditorPrefs API](https://docs.unity3d.com/6000.4/Documentation/ScriptReference/EditorPrefs.html)
