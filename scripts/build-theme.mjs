import { lstat, mkdir, readFile, readdir, realpath, writeFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { createTheme, themeCss } from "../tokens/theme.mjs";

const REPO_ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const DIST_ROOT = path.join(REPO_ROOT, "dist");
const MARKER = ".pride-prism-export.json";
const MARKER_TEXT = '{"generator":"Pride Prism","schemaVersion":1}\n';

export async function readCatalog() {
  return JSON.parse(await readFile(path.join(REPO_ROOT, "tokens", "palettes.json"), "utf8"));
}

const json = (value) => `${JSON.stringify(value, null, 2)}\n`;
const pascal = (value) => value[0].toUpperCase() + value.slice(1);

/** Native WPF color/brush exports, with the same ordered hard stops as CSS. */
export function themeXaml(theme) {
  const lines = [
    '<ResourceDictionary xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"',
    '                    xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml">',
    '  <!-- Generated dark tokens. Reference stripes are decoration, not status colors. -->'
  ];
  for (const [name, value] of Object.entries(theme.colors)) {
    lines.push(`  <Color x:Key="Prism${pascal(name)}">${value}</Color>`);
  }
  lines.push("");
  for (const name of Object.keys(theme.colors)) {
    lines.push(`  <SolidColorBrush x:Key="Prism${pascal(name)}Brush" Color="{StaticResource Prism${pascal(name)}}" />`);
  }
  lines.push("");
  theme.palette.colors.forEach((color, index) => lines.push(`  <Color x:Key="PrismStripe${index + 1}">${color}</Color>`));
  lines.push(`  <sys:Int32 x:Key="PrismStripeCount" xmlns:sys="clr-namespace:System;assembly=mscorlib">${theme.palette.colors.length}</sys:Int32>`);
  lines.push("");
  for (const [name, value] of Object.entries(theme.terminal)) lines.push(`  <Color x:Key="PrismAnsi${pascal(name)}">${value}</Color>`);
  const total = theme.palette.weights.reduce((sum, weight) => sum + weight, 0);
  const brushes = [["PrismIdentityGradient", "0,0.5", "1,0.5", theme.palette.colors], ["PrismIdentityGradientVertical", "0.5,0", "0.5,1", theme.palette.colors],
    ["PrismIdentityGradientDiagonal", "0,0", "1,1", theme.palette.colors], ["PrismIdentityWash", "0,0.5", "1,0.5", theme.gradients.wash.match(/#[0-9A-F]{6}/g)]];
  for (const [key, start, end, colors] of brushes) {
    lines.push("", `  <LinearGradientBrush x:Key="${key}" StartPoint="${start}" EndPoint="${end}">`);
    let offset = 0;
    colors.forEach((color, index) => {
      lines.push(`    <GradientStop Color="${color}" Offset="${Number((offset / total).toFixed(8))}" />`);
      offset += theme.palette.weights[index];
      lines.push(`    <GradientStop Color="${color}" Offset="${Number((offset / total).toFixed(8))}" />`);
    });
    lines.push("  </LinearGradientBrush>");
  }
  lines.push("");
  for (const [suffix, metric] of [["Small", "radiusSm"], ["Medium", "radiusMd"], ["Large", "radiusLg"]]) {
    lines.push(`  <CornerRadius x:Key="PrismRadius${suffix}">${parseFloat(theme.metrics[metric])}</CornerRadius>`);
  }
  for (const name of ["fast", "standard", "decoration", "celebration"]) {
    lines.push(`  <Duration x:Key="PrismMotion${pascal(name)}">0:0:${(theme.motion[`${name}Ms`] / 1000).toFixed(3)}</Duration>`);
  }
  lines.push("</ResourceDictionary>");
  return `${lines.join("\n")}\n`;
}

function prependTokens(source, css) {
  const text = source.toString("utf8").replace(/^\uFEFF/, "");
  // Keep charset declarations and Discord's mandatory leading metadata comment.
  const charset = text.match(/^\s*@charset\s+["'][^"']+["'];\s*/i)?.[0] ?? "";
  const rest = text.slice(charset.length);
  const comment = rest.match(/^\s*\/\*\*[\s\S]*?\*\/\s*/)?.[0] ?? "";
  const metadata = /@name\b/.test(comment) ? comment : "";
  return `${charset}${metadata}${css}\n${rest.slice(metadata.length)}`;
}

const rgb = (hex) => hex.slice(1).match(/../g).map((part) => parseInt(part, 16));

function chromeManifest(source, theme) {
  const manifest = JSON.parse(source.toString("utf8"));
  const colors = theme.colors;
  manifest.name = `Pride Prism — ${theme.palette.label}`;
  manifest.description = "A dark, neutral workspace with a locally chosen Pride Prism palette.";
  manifest.theme ??= {};
  // Bitmaps are palette-specific. scripts/generate-assets.ps1 paints them into
  // the bundle and restores this block; the source package ships colors only.
  delete manifest.theme.images;
  // Keys follow chrome/browser/themes/browser_theme_pack.cc; unknown keys are
  // silently dropped by Chrome, so every name here is one it accepts.
  manifest.theme.colors = {
    ...(manifest.theme.colors ?? {}),
    frame: rgb(colors.surfaceRaised),
    frame_inactive: rgb(colors.surface),
    frame_incognito: rgb(colors.surfaceRaised),
    frame_incognito_inactive: rgb(colors.surface),
    toolbar: rgb(colors.surface),
    toolbar_text: rgb(colors.foreground),
    toolbar_button_icon: rgb(colors.foreground),
    tab_text: rgb(colors.foreground),
    tab_background_text: rgb(colors.foregroundMuted),
    tab_background_text_inactive: rgb(colors.foregroundMuted),
    tab_background_text_incognito: rgb(colors.foregroundMuted),
    tab_background_text_incognito_inactive: rgb(colors.foregroundMuted),
    background_tab: rgb(colors.surfaceRaised),
    background_tab_inactive: rgb(colors.surface),
    bookmark_text: rgb(colors.foreground),
    omnibox_background: rgb(colors.surfaceRaised),
    omnibox_text: rgb(colors.foreground),
    ntp_background: rgb(colors.surface),
    ntp_text: rgb(colors.foreground),
    ntp_link: rgb(colors.link),
    ntp_header: rgb(colors.border),
    button_background: rgb(colors.surfaceMuted)
  };
  manifest.theme.tints = { ...(manifest.theme.tints ?? {}), buttons: [-1, 0, 0.8] };
  return json(manifest);
}

function codexConfig(theme) {
  const colors = theme.colors;
  return [
    "# Generated dark appearance snippet. Review and merge; this is not an installer.",
    "# This desktop appearance format is for Codex, not a universal ChatGPT web theme.",
    "",
    "[desktop]",
    'appearanceTheme = "dark"',
    "",
    "[desktop.appearanceDarkChromeTheme]",
    `accent = "${colors.accent}"`,
    "contrast = 86",
    `ink = "${colors.foreground}"`,
    "opaqueWindows = true",
    `surface = "${colors.surface}"`,
    "",
    "[desktop.appearanceDarkChromeTheme.semanticColors]",
    `diffAdded = "${colors.positive}"`,
    `diffRemoved = "${colors.negative}"`,
    `skill = "${colors.warning}"`,
    ""
  ].join("\n");
}

const ANSI_ORDER = ["black", "red", "green", "yellow", "blue", "magenta", "cyan", "white"];
const bright = (name) => `bright${pascal(name)}`;
const schemeName = (theme) => `Pride Prism — ${theme.palette.label}`;
const tomlString = (value) => JSON.stringify(value);

/** Windows Terminal JSON fragment: drop into %LOCALAPPDATA%\Microsoft\Windows Terminal\Fragments\PridePrism\. */
function windowsTerminalScheme(theme) {
  const { terminal, colors } = theme;
  const scheme = { name: schemeName(theme), background: colors.surface, foreground: colors.foreground, cursorColor: terminal.cursor, selectionBackground: terminal.selection };
  for (const name of ANSI_ORDER) scheme[name === "magenta" ? "purple" : name] = terminal[name];
  for (const name of ANSI_ORDER) scheme[name === "magenta" ? "brightPurple" : bright(name)] = terminal[bright(name)];
  return json({ schemes: [scheme] });
}

/** VS Code color theme extension: package.json plus the *-color-theme.json file. */
function vscodePackage(theme) {
  return json({
    name: `pride-prism-${theme.palette.id}`,
    displayName: schemeName(theme),
    description: "Dark neutral workbench with a locally chosen Pride Prism palette.",
    version: "2.0.0",
    publisher: "local",
    license: "MIT",
    engines: { vscode: "^1.85.0" },
    categories: ["Themes"],
    contributes: { themes: [{ label: schemeName(theme), uiTheme: "vs-dark", path: "./themes/pride-prism-color-theme.json" }] }
  });
}

function vscodeTheme(theme) {
  const c = theme.colors;
  const t = theme.terminal;
  const alpha = (value, amount) => `${value}${Math.round(amount * 255).toString(16).padStart(2, "0").toUpperCase()}`;
  const colors = {
    focusBorder: c.focus, foreground: c.foreground, descriptionForeground: c.foregroundMuted, disabledForeground: c.foregroundMuted,
    errorForeground: c.negative, "icon.foreground": c.foregroundMuted, "selection.background": c.selection, "textLink.foreground": c.link,
    "textLink.activeForeground": c.focus, "widget.border": c.borderSubtle,
    "editor.background": c.surface, "editor.foreground": c.foreground, "editor.selectionBackground": c.selection,
    "editor.inactiveSelectionBackground": alpha(c.selection, 0.6), "editor.lineHighlightBackground": c.surfaceRaised,
    "editor.findMatchBackground": alpha(c.warning, 0.35), "editor.findMatchHighlightBackground": alpha(c.warning, 0.2),
    "editorCursor.foreground": c.accent, "editorLineNumber.foreground": c.border, "editorLineNumber.activeForeground": c.foreground,
    "editorIndentGuide.background1": c.borderSubtle, "editorIndentGuide.activeBackground1": c.border,
    "editorWidget.background": c.surfaceRaised, "editorWidget.border": c.border, "editorSuggestWidget.selectedBackground": c.selection,
    "editorHoverWidget.background": c.surfaceRaised, "editorHoverWidget.border": c.border,
    "editorError.foreground": c.negative, "editorWarning.foreground": c.warning, "editorInfo.foreground": c.link,
    "editorGutter.addedBackground": c.positive, "editorGutter.modifiedBackground": c.warning, "editorGutter.deletedBackground": c.negative,
    "editorBracketMatch.border": c.focus, "editorBracketMatch.background": alpha(c.focus, 0.15),
    "sideBar.background": c.surfaceRaised, "sideBar.foreground": c.foregroundMuted, "sideBar.border": c.borderSubtle,
    "sideBarTitle.foreground": c.foreground, "sideBarSectionHeader.background": c.surfaceRaised, "sideBarSectionHeader.foreground": c.foreground,
    "activityBar.background": c.surface, "activityBar.foreground": c.foreground, "activityBar.inactiveForeground": c.foregroundMuted,
    "activityBar.border": c.borderSubtle, "activityBar.activeBorder": c.accent,
    "activityBarBadge.background": c.accent, "activityBarBadge.foreground": c.onAccent,
    "editorGroupHeader.tabsBackground": c.surface, "editorGroup.border": c.borderSubtle,
    "tab.activeBackground": c.surfaceRaised, "tab.inactiveBackground": c.surface, "tab.activeForeground": c.foreground,
    "tab.inactiveForeground": c.foregroundMuted, "tab.activeBorderTop": c.accent, "tab.border": c.borderSubtle,
    "titleBar.activeBackground": c.surface, "titleBar.activeForeground": c.foreground, "titleBar.inactiveBackground": c.surface,
    "titleBar.inactiveForeground": c.foregroundMuted, "titleBar.border": c.borderSubtle,
    "statusBar.background": c.surfaceRaised, "statusBar.foreground": c.foregroundMuted, "statusBar.border": c.borderSubtle,
    "statusBar.noFolderBackground": c.surfaceRaised, "statusBar.debuggingBackground": c.selection, "statusBar.debuggingForeground": c.selectionText,
    "statusBarItem.remoteBackground": c.accent, "statusBarItem.remoteForeground": c.onAccent,
    "list.activeSelectionBackground": c.selection, "list.activeSelectionForeground": c.selectionText,
    "list.inactiveSelectionBackground": alpha(c.selection, 0.6), "list.hoverBackground": c.surfaceMuted, "list.focusOutline": c.focus,
    "list.highlightForeground": c.link, "list.errorForeground": c.negative, "list.warningForeground": c.warning,
    "input.background": c.surface, "input.border": c.border, "input.foreground": c.foreground, "input.placeholderForeground": c.foregroundMuted,
    "inputOption.activeBorder": c.focus, "inputOption.activeBackground": c.selection, "inputValidation.errorBorder": c.negative,
    "dropdown.background": c.surface, "dropdown.border": c.border, "dropdown.foreground": c.foreground,
    "button.background": c.accent, "button.foreground": c.onAccent, "button.hoverBackground": c.accentHover,
    "button.secondaryBackground": c.surfaceMuted, "button.secondaryForeground": c.foreground, "button.secondaryHoverBackground": c.selection,
    "badge.background": c.selection, "badge.foreground": c.selectionText, "progressBar.background": c.accent,
    "panel.background": c.surface, "panel.border": c.borderSubtle, "panelTitle.activeBorder": c.accent,
    "panelTitle.activeForeground": c.foreground, "panelTitle.inactiveForeground": c.foregroundMuted,
    "terminal.background": c.surface, "terminal.foreground": c.foreground, "terminal.selectionBackground": c.selection,
    "terminalCursor.foreground": t.cursor, "terminal.border": c.borderSubtle,
    "terminal.ansiBlack": t.black, "terminal.ansiRed": t.red, "terminal.ansiGreen": t.green, "terminal.ansiYellow": t.yellow,
    "terminal.ansiBlue": t.blue, "terminal.ansiMagenta": t.magenta, "terminal.ansiCyan": t.cyan, "terminal.ansiWhite": t.white,
    "terminal.ansiBrightBlack": t.brightBlack, "terminal.ansiBrightRed": t.brightRed, "terminal.ansiBrightGreen": t.brightGreen,
    "terminal.ansiBrightYellow": t.brightYellow, "terminal.ansiBrightBlue": t.brightBlue, "terminal.ansiBrightMagenta": t.brightMagenta,
    "terminal.ansiBrightCyan": t.brightCyan, "terminal.ansiBrightWhite": t.brightWhite,
    "gitDecoration.addedResourceForeground": c.positive, "gitDecoration.modifiedResourceForeground": c.warning,
    "gitDecoration.deletedResourceForeground": c.negative, "gitDecoration.untrackedResourceForeground": c.positive,
    "gitDecoration.ignoredResourceForeground": c.border, "gitDecoration.conflictingResourceForeground": c.negative,
    "diffEditor.insertedTextBackground": alpha(c.positive, 0.14), "diffEditor.removedTextBackground": alpha(c.negative, 0.14),
    "notifications.background": c.surfaceRaised, "notifications.border": c.border, "notificationLink.foreground": c.link,
    "quickInput.background": c.surfaceRaised, "quickInputList.focusBackground": c.selection, "quickInputList.focusForeground": c.selectionText,
    "pickerGroup.border": c.borderSubtle, "pickerGroup.foreground": c.link,
    "menu.background": c.surfaceRaised, "menu.foreground": c.foreground, "menu.selectionBackground": c.selection,
    "menu.selectionForeground": c.selectionText, "menu.border": c.border, "menubar.selectionBackground": c.surfaceMuted,
    "scrollbarSlider.background": alpha(c.border, 0.4), "scrollbarSlider.hoverBackground": alpha(c.border, 0.6), "scrollbarSlider.activeBackground": c.border,
    "breadcrumb.foreground": c.foregroundMuted, "breadcrumb.focusForeground": c.foreground, "breadcrumb.activeSelectionForeground": c.foreground,
    "minimap.selectionHighlight": c.selection, "peekView.border": c.focus, "peekViewEditor.background": c.surfaceRaised,
    "peekViewResult.background": c.surfaceRaised, "peekViewTitle.background": c.surfaceMuted
  };
  const scope = (name, scopes, settings) => ({ name, scope: scopes, settings });
  const tokenColors = [
    scope("Comments", ["comment", "punctuation.definition.comment"], { foreground: c.foregroundMuted, fontStyle: "italic" }),
    scope("Strings", ["string", "string.quoted", "string.template"], { foreground: c.positive }),
    scope("Numbers and constants", ["constant.numeric", "constant.language", "constant.character", "constant.other"], { foreground: c.warning }),
    scope("Keywords and storage", ["keyword", "storage.type", "storage.modifier", "keyword.operator.new"], { foreground: c.accent }),
    scope("Operators", ["keyword.operator"], { foreground: c.foregroundMuted }),
    scope("Functions", ["entity.name.function", "support.function", "meta.function-call entity.name.function"], { foreground: c.link }),
    scope("Types and classes", ["entity.name.type", "entity.name.class", "entity.name.namespace", "support.type", "support.class"], { foreground: c.focus }),
    scope("Variables and parameters", ["variable", "variable.parameter", "meta.definition.variable.name"], { foreground: c.foreground }),
    scope("Properties and attributes", ["variable.other.property", "entity.other.attribute-name", "support.type.property-name"], { foreground: t.brightCyan }),
    scope("Tags", ["entity.name.tag", "punctuation.definition.tag"], { foreground: c.accent }),
    scope("Punctuation", ["punctuation", "meta.brace"], { foreground: c.foregroundMuted }),
    scope("Invalid", ["invalid", "invalid.illegal"], { foreground: c.negative }),
    scope("Markup headings", ["markup.heading", "markup.heading entity.name"], { foreground: c.accent, fontStyle: "bold" }),
    scope("Markup emphasis", ["markup.italic"], { fontStyle: "italic" }),
    scope("Markup strong", ["markup.bold"], { fontStyle: "bold" }),
    scope("Markup links", ["markup.underline.link", "string.other.link"], { foreground: c.link }),
    scope("Diff inserted", ["markup.inserted"], { foreground: c.positive }),
    scope("Diff deleted", ["markup.deleted"], { foreground: c.negative }),
    scope("Diff changed", ["markup.changed"], { foreground: c.warning })
  ];
  return json({ $schema: "vscode://schemas/color-theme", name: schemeName(theme), type: "dark", semanticHighlighting: true, colors, tokenColors });
}

/** Unity UI Toolkit USS for custom editor windows; built-in editor chrome is untouched. */
function unityUss(theme) {
  const c = theme.colors;
  const rgbCss = (value) => `rgb(${rgb(value).join(", ")})`;
  const entries = {
    "window-background": c.surfaceRaised, "default-background": c.surface, "default-text": c.foreground, "default-text-hover": c.foreground,
    "window-text": c.foregroundMuted, "default-border": c.border, "highlight-background": c.selection,
    "highlight-background-inactive": c.surfaceMuted, "highlight-text": c.selectionText, "highlight-text-inactive": c.foregroundMuted,
    "label-text": c.foreground, "label-text-focus": c.foreground, "toolbar-background": c.surfaceRaised, "toolbar-border": c.borderSubtle,
    "app_toolbar-background": c.surface, "tab-background": c.surfaceRaised, "tab-background-checked": c.surfaceMuted, "tab-text": c.foregroundMuted,
    "button-background": c.surfaceMuted, "button-background-hover": c.selection, "button-background-pressed": c.accentPressed,
    "button-background-focus": c.surfaceMuted, "button-text": c.foreground, "button-border": c.border, "button-border-pressed": c.focus,
    "input_field-background": c.surface, "input_field-border": c.border, "input_field-border-focus": c.focus, "input_field-border-hover": c.border,
    "input_field-text": c.foreground, "object_field-background": c.surface, "object_field-border": c.borderSubtle,
    "dropdown-background": c.surfaceRaised, "dropdown-border": c.border, "dropdown-text": c.foreground,
    "toggle-background": c.surface, "toggle-border": c.border, "toggle-text": c.foreground,
    "slider_groove-background": c.surfaceMuted, "slider_thumb-background": c.accent, "slider_thumb-border": c.border,
    "scrollbar_thumb-background": c.border, "scrollbar_groove-background": c.surface,
    "progress-background": c.surfaceMuted, "progress-inner-background": c.accent,
    "helpbox-background": c.surfaceRaised, "helpbox-border": c.borderSubtle, "helpbox-text": c.foregroundMuted,
    "error-text": c.negative, "warning-text": c.warning, "link-text": c.link
  };
  const lines = [`/* ${schemeName(theme)} — Unity UI Toolkit variables for your own editor windows.`,
    " * Import from a custom EditorWindow stylesheet. Unity's built-in editor UI is not restyled;",
    " * use Edit > Preferences > General > Editor Theme > Dark for the native theme. */", ":root {"];
  for (const [name, value] of Object.entries(entries)) lines.push(`  --unity-colors-${name}: ${rgbCss(value)};`);
  lines.push(`  --prism-identity-start: ${rgbCss(theme.palette.colors[0])};`, `  --prism-identity-end: ${rgbCss(theme.palette.colors.at(-1))};`, "}", "",
    ".pride-prism-window { background-color: var(--unity-colors-window-background); color: var(--unity-colors-default-text); }",
    ".pride-prism-window .unity-button { background-color: var(--unity-colors-button-background); color: var(--unity-colors-button-text); border-color: var(--unity-colors-button-border); border-radius: 6px; }",
    ".pride-prism-window .unity-button:hover { background-color: var(--unity-colors-button-background-hover); }",
    ".pride-prism-window .unity-button:active { background-color: var(--unity-colors-button-background-pressed); }",
    ".pride-prism-window .unity-text-field__input { background-color: var(--unity-colors-input_field-background); border-color: var(--unity-colors-input_field-border); color: var(--unity-colors-input_field-text); }",
    ".pride-prism-window .unity-text-field__input:focus { border-color: var(--unity-colors-input_field-border-focus); }",
    ".pride-prism-identity-rail { height: 3px; background-color: var(--prism-identity-start); }", "");
  return lines.join("\n");
}

function alacrittyConfig(theme) {
  const { terminal, colors } = theme;
  const block = (title, entries) => [`[${title}]`, ...entries.map(([key, value]) => `${key} = ${tomlString(value)}`), ""];
  const lines = [`# ${schemeName(theme)} — merge into alacritty.toml or import with [general] import.`, ""];
  lines.push(...block("colors.primary", [["background", colors.surface], ["foreground", colors.foreground], ["dim_foreground", colors.foregroundMuted]]));
  lines.push(...block("colors.cursor", [["text", colors.onAccent], ["cursor", terminal.cursor]]));
  lines.push(...block("colors.selection", [["text", terminal.selectionText], ["background", terminal.selection]]));
  lines.push(...block("colors.normal", ANSI_ORDER.map((name) => [name, terminal[name]])));
  lines.push(...block("colors.bright", ANSI_ORDER.map((name) => [name, terminal[bright(name)]])));
  theme.palette.colors.forEach((color, index) => lines.push("[[colors.indexed_colors]]", `index = ${16 + index}`, `color = ${tomlString(color)}`, ""));
  return lines.join("\n");
}

function weztermScheme(theme) {
  const { terminal, colors } = theme;
  const list = (names) => `[${names.map((name) => tomlString(terminal[name])).join(", ")}]`;
  return [
    `# ${schemeName(theme)} — load with wezterm.color.load_scheme or copy into config.colors.`,
    "[metadata]", `name = ${tomlString(schemeName(theme))}`, "",
    "[colors]",
    `foreground = ${tomlString(colors.foreground)}`, `background = ${tomlString(colors.surface)}`,
    `cursor_bg = ${tomlString(terminal.cursor)}`, `cursor_fg = ${tomlString(colors.onAccent)}`, `cursor_border = ${tomlString(terminal.cursor)}`,
    `selection_fg = ${tomlString(terminal.selectionText)}`, `selection_bg = ${tomlString(terminal.selection)}`,
    `scrollbar_thumb = ${tomlString(colors.border)}`, `split = ${tomlString(colors.borderSubtle)}`,
    `ansi = ${list(ANSI_ORDER)}`, `brights = ${list(ANSI_ORDER.map(bright))}`, ""
  ].join("\n");
}

function kittyConfig(theme) {
  const { terminal, colors } = theme;
  const lines = [`# ${schemeName(theme)} — include from kitty.conf.`,
    `foreground ${colors.foreground}`, `background ${colors.surface}`,
    `selection_foreground ${terminal.selectionText}`, `selection_background ${terminal.selection}`,
    `cursor ${terminal.cursor}`, `cursor_text_color ${colors.onAccent}`,
    `url_color ${colors.link}`, `active_border_color ${colors.accent}`, `inactive_border_color ${colors.borderSubtle}`,
    `active_tab_foreground ${colors.selectionText}`, `active_tab_background ${colors.selection}`,
    `inactive_tab_foreground ${colors.foregroundMuted}`, `inactive_tab_background ${colors.surfaceRaised}`, ""];
  ANSI_ORDER.forEach((name, index) => lines.push(`color${index} ${terminal[name]}`));
  ANSI_ORDER.forEach((name, index) => lines.push(`color${index + 8} ${terminal[bright(name)]}`));
  lines.push("", "# Reference stripes in the extended palette.");
  theme.palette.colors.forEach((color, index) => lines.push(`color${16 + index} ${color}`));
  return `${lines.join("\n")}\n`;
}

/** Firefox static theme (Manifest V2 is the documented theme format). */
function firefoxManifest(theme) {
  const colors = theme.colors;
  return json({
    manifest_version: 2,
    name: schemeName(theme),
    version: "2.0.0",
    description: "A dark, neutral browser frame with a locally chosen Pride Prism palette.",
    browser_specific_settings: { gecko: { id: "pride-prism@starwarmissionary.github.io" } },
    theme: {
      colors: {
        frame: colors.surfaceRaised, frame_inactive: colors.surface,
        tab_background_text: colors.foregroundMuted, tab_selected: colors.surface, tab_text: colors.foreground, tab_line: colors.accent,
        toolbar: colors.surface, toolbar_text: colors.foreground,
        toolbar_field: colors.surfaceRaised, toolbar_field_text: colors.foreground, toolbar_field_border: colors.borderSubtle,
        toolbar_field_focus: colors.surfaceRaised, toolbar_field_text_focus: colors.foreground, toolbar_field_border_focus: colors.focus,
        toolbar_field_highlight: colors.selection, toolbar_field_highlight_text: colors.selectionText,
        popup: colors.surfaceRaised, popup_text: colors.foreground, popup_border: colors.borderSubtle,
        popup_highlight: colors.selection, popup_highlight_text: colors.selectionText,
        sidebar: colors.surface, sidebar_text: colors.foreground, sidebar_border: colors.borderSubtle,
        sidebar_highlight: colors.selection, sidebar_highlight_text: colors.selectionText,
        ntp_background: colors.surface, ntp_text: colors.foreground,
        icons: colors.foregroundMuted, icons_attention: colors.accent,
        button_background_hover: colors.surfaceMuted, button_background_active: colors.selection,
        bookmark_text: colors.foreground
      },
      properties: { color_scheme: "dark", content_color_scheme: "dark" }
    }
  });
}

/** GTK 4 / libadwaita named-color overrides for ~/.config/gtk-4.0/gtk.css. */
function gtkCss(theme) {
  const colors = theme.colors;
  const named = {
    accent_bg_color: colors.accent, accent_fg_color: colors.onAccent, accent_color: colors.link,
    window_bg_color: colors.surface, window_fg_color: colors.foreground,
    view_bg_color: colors.surfaceRaised, view_fg_color: colors.foreground,
    headerbar_bg_color: colors.surfaceRaised, headerbar_fg_color: colors.foreground, headerbar_border_color: colors.borderSubtle,
    headerbar_backdrop_color: colors.surface,
    sidebar_bg_color: colors.surfaceRaised, sidebar_fg_color: colors.foreground, sidebar_backdrop_color: colors.surface, sidebar_border_color: colors.borderSubtle,
    card_bg_color: colors.surfaceMuted, card_fg_color: colors.foreground,
    popover_bg_color: colors.surfaceRaised, popover_fg_color: colors.foreground,
    dialog_bg_color: colors.surfaceRaised, dialog_fg_color: colors.foreground,
    thumbnail_bg_color: colors.surfaceMuted, thumbnail_fg_color: colors.foreground,
    destructive_bg_color: colors.negative, destructive_fg_color: colors.surface, destructive_color: colors.negative,
    success_bg_color: colors.positive, success_fg_color: colors.surface, success_color: colors.positive,
    warning_bg_color: colors.warning, warning_fg_color: colors.surface, warning_color: colors.warning,
    error_bg_color: colors.negative, error_fg_color: colors.surface, error_color: colors.negative
  };
  const lines = [`/* ${schemeName(theme)} — GTK 4 / libadwaita named colors. Merge into ~/.config/gtk-4.0/gtk.css. */`,
    "/* Named colors remain supported alongside the libadwaita 1.6 CSS variables. */"];
  for (const [name, value] of Object.entries(named)) lines.push(`@define-color ${name} ${value};`);
  return `${lines.join("\n")}\n`;
}

/** KDE Plasma color scheme for ~/.local/share/color-schemes/. */
function kdeColors(theme) {
  const colors = theme.colors;
  const triplet = (value) => rgb(value).join(",");
  const set = (background, alternate, foreground = colors.foreground) => ({
    BackgroundAlternate: alternate, BackgroundNormal: background,
    DecorationFocus: colors.focus, DecorationHover: colors.accentHover,
    ForegroundActive: colors.accent, ForegroundInactive: colors.foregroundMuted, ForegroundLink: colors.link,
    ForegroundNegative: colors.negative, ForegroundNeutral: colors.warning, ForegroundNormal: foreground,
    ForegroundPositive: colors.positive, ForegroundVisited: colors.accentPressed
  });
  const sections = {
    "Colors:Button": set(colors.surfaceMuted, colors.surfaceRaised),
    "Colors:Complementary": set(colors.surface, colors.surfaceRaised),
    "Colors:Header": set(colors.surfaceRaised, colors.surface),
    "Colors:Selection": set(colors.selection, colors.surfaceMuted, colors.selectionText),
    "Colors:Tooltip": set(colors.surfaceRaised, colors.surfaceMuted),
    "Colors:View": set(colors.surface, colors.surfaceRaised),
    "Colors:Window": set(colors.surfaceRaised, colors.surfaceMuted),
    General: { ColorScheme: `PridePrism${pascal(theme.palette.id.replace(/-([a-z0-9])/g, (_, char) => char.toUpperCase()))}`, Name: schemeName(theme), shadeSortColumn: "true" },
    WM: { activeBackground: colors.surfaceRaised, activeBlend: colors.accent, activeForeground: colors.foreground,
      inactiveBackground: colors.surface, inactiveBlend: colors.borderSubtle, inactiveForeground: colors.foregroundMuted }
  };
  const lines = [];
  for (const [section, entries] of Object.entries(sections)) {
    lines.push(`[${section}]`);
    for (const [key, value] of Object.entries(entries)) lines.push(`${key}=${/^#/.test(value) ? triplet(value) : value}`);
    lines.push("");
  }
  return lines.join("\n");
}

/** Files produced from the theme instead of copied. Keys are adapter-relative paths. */
export const GENERATED = {
  "chrome/manifest.json": chromeManifest,
  "chatgpt/pride-prism-config.toml": (_source, theme) => codexConfig(theme),
  "terminals/windows-terminal.json": (_source, theme) => windowsTerminalScheme(theme),
  "terminals/alacritty.toml": (_source, theme) => alacrittyConfig(theme),
  "terminals/wezterm.toml": (_source, theme) => weztermScheme(theme),
  "terminals/kitty.conf": (_source, theme) => kittyConfig(theme),
  "firefox/manifest.json": (_source, theme) => firefoxManifest(theme),
  "linux/gtk.css": (_source, theme) => gtkCss(theme),
  "linux/PridePrism.colors": (_source, theme) => kdeColors(theme),
  "vscode/package.json": (_source, theme) => vscodePackage(theme),
  "vscode/themes/pride-prism-color-theme.json": (_source, theme) => vscodeTheme(theme),
  "unity/PridePrism.uss": (_source, theme) => unityUss(theme)
};

async function adapterFiles(directory, prefix = "") {
  const result = [];
  const entries = (await readdir(directory, { withFileTypes: true })).sort((a, b) => a.name < b.name ? -1 : a.name > b.name ? 1 : 0);
  for (const entry of entries) {
    // Installer snapshots are private local state, never distributable assets.
    if (entry.name === ".install-state") continue;
    const source = path.join(directory, entry.name);
    const relative = prefix ? `${prefix}/${entry.name}` : entry.name;
    if (entry.isSymbolicLink()) throw new Error(`Refusing to export adapter symlink: ${relative}`);
    if (entry.isDirectory()) result.push(...await adapterFiles(source, relative));
    else if (entry.isFile()) result.push({ relative, bytes: await readFile(source) });
    else throw new Error(`Unsupported adapter entry: ${relative}`);
  }
  return result;
}

function contained(root, target) {
  const relative = path.relative(root, target);
  return relative === "" || (!relative.startsWith(`..${path.sep}`) && relative !== ".." && !path.isAbsolute(relative));
}

async function assertNoOutputLinks(directory) {
  for (const entry of await readdir(directory, { withFileTypes: true })) {
    if (entry.isSymbolicLink()) throw new Error("A generated output directory must not contain symlinks or junctions.");
    if (entry.isDirectory()) await assertNoOutputLinks(path.join(directory, entry.name));
  }
}

async function assertSafeOutput(requested) {
  if (typeof requested !== "string" || !requested.trim()) throw new TypeError("Output must be a nonempty directory path.");
  const output = path.resolve(REPO_ROOT, requested);
  // Strictly inside dist: exporting into the dist root itself would mark it as
  // a bundle and let a later export overwrite sibling bundles.
  if (output === DIST_ROOT || !contained(DIST_ROOT, output)) throw new Error("Generated output must stay inside this repository's dist directory.");
  // Reject junctions/symlinks anywhere from the repository to the destination.
  const parts = path.relative(REPO_ROOT, output).split(path.sep);
  let current = REPO_ROOT;
  for (const part of parts) {
    current = path.join(current, part);
    let info;
    try { info = await lstat(current); } catch (error) { if (error.code === "ENOENT") break; throw error; }
    if (!info.isDirectory() || info.isSymbolicLink()) throw new Error("Output must contain only real directories, not links or files.");
    if (!contained(await realpath(REPO_ROOT), await realpath(current))) throw new Error("Resolved output escaped the repository.");
  }
  try {
    const entries = await readdir(output);
    await assertNoOutputLinks(output);
    if (entries.length && (!entries.includes(MARKER) || await readFile(path.join(output, MARKER), "utf8") !== MARKER_TEXT)) {
      throw new Error("Refusing to overwrite a nonempty directory that is not a Pride Prism export.");
    }
  } catch (error) { if (error.code !== "ENOENT") throw error; }
  return output;
}

/** Export into an empty/previously generated dist directory. Never install. */
export async function buildTheme({ palette, accent, output } = {}) {
  const catalog = await readCatalog();
  const theme = createTheme(catalog, palette ?? catalog.defaultPreset, accent);
  const outputRoot = await assertSafeOutput(output ?? `dist/${theme.palette.id}`);
  const css = themeCss(theme);
  const sources = await adapterFiles(path.join(REPO_ROOT, "adapters"));
  const rendered = sources.map(({ relative, bytes }) => {
    if (Object.hasOwn(GENERATED, relative)) return { relative, bytes: GENERATED[relative](bytes, theme) };
    if (relative.endsWith(".css")) return { relative, bytes: prependTokens(bytes, css) };
    return { relative, bytes };
  });
  await mkdir(outputRoot, { recursive: true });
  await writeFile(path.join(outputRoot, MARKER), MARKER_TEXT);
  await writeFile(path.join(outputRoot, "theme.json"), json(theme));
  await writeFile(path.join(outputRoot, "pride-prism.css"), css);
  await writeFile(path.join(outputRoot, "PridePrism.xaml"), themeXaml(theme));
  for (const { relative, bytes } of rendered) {
    const destination = path.join(outputRoot, "adapters", relative);
    await mkdir(path.dirname(destination), { recursive: true });
    await writeFile(destination, bytes);
  }
  return { theme, output: outputRoot, adapterFileCount: rendered.length };
}

/** Explicit maintenance operation: regenerate the tracked neutral exports only. */
export async function writeDefaultTokens() {
  const catalog = await readCatalog();
  if (catalog.defaultPreset !== "neutral") throw new Error("Tracked default tokens must use the neutral preset.");
  const theme = createTheme(catalog);
  const tokenRoot = path.join(REPO_ROOT, "tokens");
  await writeFile(path.join(tokenRoot, "pride-prism.tokens.json"), json(theme));
  await writeFile(path.join(tokenRoot, "pride-prism.css"), themeCss(theme));
  await writeFile(path.join(tokenRoot, "PridePrism.xaml"), themeXaml(theme));
  return theme;
}

function parseArguments(args) {
  if (args.length === 1 && args[0] === "--help") return { help: true };
  if (args.length === 1 && args[0] === "--write-defaults") return { defaults: true };
  const options = {};
  const flags = { "--palette": "palette", "--accent": "accent", "--output": "output" };
  for (let index = 0; index < args.length; index += 2) {
    const key = Object.hasOwn(flags, args[index]) ? flags[args[index]] : undefined;
    const value = args[index + 1];
    if (!key || Object.hasOwn(options, key) || value === undefined || value.startsWith("--")) {
      throw new Error("Use --palette ID, --accent '#RRGGBB', and --output dist/name once each; see --help.");
    }
    options[key] = value;
  }
  return options;
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  try {
    const options = parseArguments(process.argv.slice(2));
    if (options.help) console.log("node scripts/build-theme.mjs --palette ID [--accent '#RRGGBB'] [--output dist/name]\nnode scripts/build-theme.mjs --write-defaults\nExports local files only. Existing adapter source files and app settings are never changed.");
    else if (options.defaults) {
      await writeDefaultTokens();
      console.log("Regenerated the three tracked neutral token exports.");
    } else {
      const result = await buildTheme(options);
      console.log(`Exported ${result.theme.palette.label} to ${result.output} (${result.adapterFileCount} adapter files).`);
    }
  } catch (error) {
    console.error(`Theme export failed: ${error.message}`);
    process.exitCode = 1;
  }
}
