# Firefox theme

A static theme package generated from the shared roles: neutral frame and toolbar, accent-colored active tab line and attention icons, shared selection colors in the URL bar and popups. No scripts, permissions or site access.

Build a palette, then load `dist/<palette>/adapters/firefox` through `about:debugging` > This Firefox > Load Temporary Add-on (select `manifest.json`). Temporary themes last for the session; signing through [addons.mozilla.org](https://extensionworkshop.com/documentation/publish/) is required for a permanent install. Firefox's theme API uses Manifest V2, which is the documented format for static themes.

To undo, choose another theme under Settings > Extensions & Themes. The generated `properties.color_scheme` keeps Firefox's own dark palette for pages that follow the browser scheme.

Reference: [theme manifest key](https://developer.mozilla.org/en-US/docs/Mozilla/Add-ons/WebExtensions/manifest.json/theme).
