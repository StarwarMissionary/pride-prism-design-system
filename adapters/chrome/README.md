# Chrome adapter

This is a theme-only Manifest V3 extension. It contains no JavaScript, content scripts, permissions, network access, or browsing-data access.

Generate assets from the repository root:

```powershell
./scripts/generate-assets.ps1
```

Then load the `adapters/chrome` directory as an unpacked extension from `chrome://extensions` with Developer mode enabled. Installing or loading an extension should always be an explicit user-confirmed action.
