# Blender 4.5 color-only adapter

`theme_adapter.py` consumes generated `theme.json` files. It changes an explicit allowlist of UI widget colors and Preferences/Properties/Outliner/top/status-bar surfaces. It preserves existing alpha, roundness, sizes, shading parameters, font styles and all viewport, material, object, collection, bone, wire, gizmo, axis, animation-state and node colors. Other editors retain their existing backgrounds. Motion/metrics tokens do not change Blender preferences.

No scene/project/startup file, installed application resource, layout or keymap is modified. Merely importing the Python module does nothing. Deployment is two explicit commands: **stage**, then **commit**. The adapter passed unit tests and isolated stage/reload checks on Blender 4.5.11, including preservation of non-theme preferences and serialized add-on settings. This is not a claim of complete visual coverage; each deployment still requires the guarded staging checks and inspection in the actual app.

## Stage without changing live preferences

Stage copies the existing `userpref.blend` into a unique directory, redirects Blender's CONFIG/scripts/extensions paths there, creates `before-theme.xml` for theme-only rollback, applies only color fields, and saves a candidate **in the copy**. A second independent Blender process reloads that candidate and compares every writable Theme/ThemeStyle field to the expected result. The operation stops on an unsupported API, missing color field, failed save, changed source hash, or preservation mismatch.

Staging starts two hidden background Blender processes. It uses offline mode and disables blend-file auto-execution; it does not copy `startup.blend` or pass a scene filename. **Copied preferences can still initialize installed add-ons**, including repositories with explicit paths. These flags are not an add-on sandbox. Review that implication before using the required `--allow-preference-addons` acknowledgment. No staging or launch occurs without it. Never point a worker command at live CONFIG.

```powershell
$blenderConfig = Join-Path $env:APPDATA 'Blender Foundation\Blender\4.5\config'
python -B .\adapters\blender\theme_adapter.py stage `
  --theme-json 'C:\path\to\generated\theme.json' `
  --blender 'C:\Program Files\Blender Foundation\Blender 4.5\blender.exe' `
  --config-dir "$blenderConfig" `
  --allow-preference-addons
```

The result prints `stage_dir`, not a claim that the live app changed. Inspect the candidate and both worker logs before proceeding. Artifacts remain under `%LOCALAPPDATA%\PridePrism\Blender\Staging`; no older backup is overwritten. `backup\userpref.blend` is the full original preference file. Theme snapshots intentionally contain no add-on settings or credentials.

## Explicit commit and rollback

Commit is Windows-only and refuses while any `blender.exe` is running. It verifies the original/live preference hash and every relevant candidate/backup hash, then atomically replaces only `userpref.blend`. It never closes Blender; save your work and close it normally first. The colors appear on its next normal launch. No preset file is installed or selected automatically; existing preset labels may remain until you explicitly install `candidate-theme.xml`.

```powershell
$blenderConfig = Join-Path $env:APPDATA 'Blender Foundation\Blender\4.5\config'
python -B .\adapters\blender\theme_adapter.py commit `
  --stage-dir 'C:\path\returned\by\stage' `
  --config-dir "$blenderConfig"
```

For theme-only rollback, use Blender Preferences > Themes > Install with that stage's `before-theme.xml`, then save preferences if auto-save is disabled. This can update an existing window without touching its scene. A full `userpref.blend` backup is an emergency fallback only, with Blender closed: restoring it also reverts unrelated preference changes made since backup. Older preference backups and existing preset XML files are not overwritten.

Never combine factory settings with a save to live CONFIG. Blender's factory-startup path bypasses both startup and preference loading; that would lose the baseline this adapter must preserve. Missing/failed add-ons can have their own initialization effects in a staging process; review logs and do not commit if they report preference changes or errors. The explicit theme-field comparison is not a proof that third-party add-ons were side-effect-free.

## Evidence and tests

Installed Blender 4.5.11 source was checked: `scripts/startup/bl_operators/userpref.py` implements `preferences.theme_install`; `scripts/startup/bl_ui/space_userpref.py` maps XML only to `preferences.themes[0]` and `preferences.ui_styles[0]`; `scripts/modules/rna_xml.py` provides the same theme export utility used by Blender. The script fails closed on other major/minor versions.

- [Themes and live XML import](https://docs.blender.org/manual/en/latest/editors/preferences/themes.html)
- [Theme importer API](https://docs.blender.org/api/main/bpy.ops.preferences.html#bpy.ops.preferences.theme_install)
- [Preferences versus startup contents](https://docs.blender.org/manual/en/4.5/getting_started/configuration/defaults.html)
- [Blender 4.5.11 preference load/save source](https://github.com/blender/blender/blob/v4.5.11/source/blender/windowmanager/intern/wm_files.cc)

Pure, non-Blender checks: `python -B -m unittest discover -s adapters/blender -p 'test_*.py'`.
