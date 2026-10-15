# Linux desktop color schemes

Two generated files cover the common desktop toolkits. Neither patches an application; both are per-user preference files.

## GTK 4 / libadwaita

`gtk.css` defines libadwaita's named colors (`accent_bg_color`, `window_bg_color`, `view_bg_color`, `headerbar_bg_color`, `card_bg_color`, `popover_bg_color`, `dialog_bg_color`, status colors) from the shared roles. Back up `~/.config/gtk-4.0/gtk.css`, append the generated file, and reopen apps. Named colors remain supported alongside the CSS variables libadwaita 1.6 introduced; applications that ship their own stylesheet may override parts of it.

## KDE Plasma

`PridePrism.colors` is a Plasma color scheme. Copy it to `~/.local/share/color-schemes/` and select it under System Settings > Colors & Themes > Colors. Window, View, Button, Header, Selection and Tooltip sets use the surface tiers; focus, hover, link and status colors use the independent semantic roles; the title-bar blend uses the accent.

To undo, select the previous scheme or remove the file. Semantic colors (positive, neutral, negative) stay stable across palettes.

Reference: [libadwaita CSS variables](https://gnome.pages.gitlab.gnome.org/libadwaita/doc/1-latest/css-variables.html), [KDE color schemes](https://develop.kde.org/docs/plasma/theme/).
