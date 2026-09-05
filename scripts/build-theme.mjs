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
  lines.push('', '  <LinearGradientBrush x:Key="PrismIdentityGradient" StartPoint="0,0.5" EndPoint="1,0.5">');
  const total = theme.palette.weights.reduce((sum, weight) => sum + weight, 0);
  let offset = 0;
  theme.palette.colors.forEach((color, index) => {
    lines.push(`    <GradientStop Color="${color}" Offset="${Number((offset / total).toFixed(8))}" />`);
    offset += theme.palette.weights[index];
    lines.push(`    <GradientStop Color="${color}" Offset="${Number((offset / total).toFixed(8))}" />`);
  });
  lines.push("  </LinearGradientBrush>", "");
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
  // Legacy rainbow bitmaps would override these colors and misrepresent a
  // different preset. A separate asset generator can add matching images later.
  delete manifest.theme.images;
  manifest.theme.colors = {
    ...(manifest.theme.colors ?? {}),
    frame: rgb(colors.surfaceRaised),
    frame_inactive: rgb(colors.surface),
    toolbar: rgb(colors.surface),
    toolbar_text: rgb(colors.foreground),
    tab_text: rgb(colors.foreground),
    tab_background_text: rgb(colors.foregroundMuted),
    bookmark_text: rgb(colors.foreground),
    ntp_background: rgb(colors.surface),
    ntp_text: rgb(colors.foreground),
    ntp_link: rgb(colors.link),
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
  if (!contained(DIST_ROOT, output)) throw new Error("Generated output must stay inside this repository's dist directory.");
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
    if (relative.endsWith(".css")) return { relative, bytes: prependTokens(bytes, css) };
    if (relative === "chrome/manifest.json") return { relative, bytes: chromeManifest(bytes, theme) };
    if (relative === "chatgpt/pride-prism-config.toml") return { relative, bytes: codexConfig(theme) };
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
