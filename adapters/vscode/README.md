# VS Code color theme

A generated dark workbench theme: neutral surfaces, the shared selection pair in lists and the editor, the selected accent on the active tab line, activity badge and buttons, and the same sixteen ANSI colors as the terminal adapters. Syntax colors use the semantic roles (strings positive, constants warning, keywords accent, functions link, types focus) so meaning stays stable across palettes.

Build a palette, then install the generated folder as a local extension:

```powershell
node scripts/build-theme.mjs --palette bisexual --output dist/bisexual
Copy-Item -Recurse dist/bisexual/adapters/vscode "$env:USERPROFILE/.vscode/extensions/pride-prism-bisexual"
```

Reload VS Code and choose the theme under Preferences > Color Theme. To undo, pick another theme or delete that extension folder. Nothing is installed automatically and no marketplace account is needed.

Reference: [Color theme guide](https://code.visualstudio.com/api/extension-guides/color-theme), [Theme color reference](https://code.visualstudio.com/api/references/theme-color).
