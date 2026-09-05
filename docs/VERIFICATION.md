# Foundation verification

This record distinguishes source tests from installed-app appearance. It is not a certification that every host control is themed or accessible.

## Passed

- Ten palette/export tests, including all ten presets and 468 custom accents: readable action pairs, deterministic CSS/JSON/XAML, reference stripe weights, safe output boundaries and preserved source templates.
- Three adapter-boundary tests: shared token adoption, protected Steam geometry and identical website resolver/catalog assets.
- Eight pure Windows regression groups: channel order, palette ramp and tail preservation, typed snapshots, legacy rollback compatibility and detection of post-notification accent reversion. These tests never access the live registry.
- Fourteen Blender unit tests plus isolated Blender 4.5.11 stage/reload checks. The candidate changes 224 allowed color fields; non-theme preferences and serialized add-on settings are preserved. A guarded, hash-verified preference deployment also passed.
- Windows 10 native preference mapping, backup and post-notification readback. Explorer accent sources and derived DWM colors remained consistent on a later readback; dark mode stayed enabled and existing wallpaper/cursor settings were preserved.
- Browser checks at 320, 390, 768, 900 and 1280 CSS pixels: no horizontal overflow or contrast-card overlap; mobile navigation remains available. Palette selection, invalid/valid custom input, export state, visible focus and opt-in finite celebration were exercised. Switching celebration off cancels it immediately.
- JavaScript/PowerShell parsing and repository whitespace checks.

## Still required before claiming full app coverage

- Steam: separate live visual inspection of Library Home, game details, Store, menus, downloads, Friends/chat, settings and Big Picture. Automated Windows capture/input was unavailable during this pass; source checks and installed files do not substitute for these inspections.
- Chrome and Discord: verify that the running app has loaded its generated package; copying files alone is not evidence of adoption. Browser extension reload controls were unavailable to automation.
- Blender and native Codex appearance: inspect the next normal launch; do not interrupt an active workspace to force a theme refresh.
- Unity: restore any previously patched resources from matching originals before using supported preferences. Protected installation files may require administrator-assisted restoration. The adapter itself never patches binaries.
- Website: actual 200% browser zoom, assistive-technology and forced-colors checks. Reduced-motion behavior is implemented but was not runtime-emulated in this pass.

Keep private deployment paths, account information, screenshots and rollback snapshots outside the public repository. Every new host version or selector change needs renewed host-level acceptance.
