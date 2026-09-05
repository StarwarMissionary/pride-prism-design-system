# Native Codex desktop appearance

Build a palette first. The generated `pride-prism-config.toml` is a mergeable dark-appearance snippet, not a replacement for the whole user config and not a universal ChatGPT web theme.

Back up the current config, then merge only the desktop appearance keys. Preserve model, project, security, connection, fonts and unrelated preferences. Do not patch application binaries or inject scripts into the UI.

The desktop appearance settings support Dark and native surface/ink/accent choices. The app derives additional shades from these controls, so literal pixel equality across every app is not promised. Save without forcing a restart; verify live adoption separately or leave it for the next normal launch.

Rollback: restore just the prior appearance keys from the backup, keeping subsequent unrelated edits.

[Native appearance settings](https://learn.chatgpt.com/docs/reference/settings).
