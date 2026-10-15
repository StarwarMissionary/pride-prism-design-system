import test from "node:test";
import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { mkdir, mkdtemp, readFile, readdir, realpath, rm, writeFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { spawnSync } from "node:child_process";
import { contrast, createTheme, themeCss } from "../tokens/theme.mjs";
import { GENERATED, buildTheme, readCatalog, themeXaml } from "./build-theme.mjs";

const REPO_ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const DIST_ROOT = path.join(REPO_ROOT, "dist");
const catalog = await readCatalog();
const requiredIds = ["bisexual", "rainbow", "progress-inspired", "trans", "pan", "lesbian7", "nonbinary", "ace", "aro", "neutral",
  "gay-men", "genderfluid", "genderqueer", "agender", "polysexual", "omnisexual", "bear", "leather", "intersex-inspired",
  "aurora", "dusk", "ember", "tide", "prism"];
const ansiNames = ["black", "red", "green", "yellow", "blue", "magenta", "cyan", "white", "brightBlack", "brightRed", "brightGreen", "brightYellow", "brightBlue", "brightMagenta", "brightCyan", "brightWhite", "cursor", "selection", "selectionText"];
const colorNames = ["surface", "surfaceRaised", "surfaceMuted", "foreground", "foregroundMuted", "accent", "onAccent", "accentHover", "accentPressed", "focus", "link", "selection", "selectionText", "border", "borderSubtle", "positive", "warning", "negative"];
const kebab = (name) => name.replace(/([a-z0-9])([A-Z])/g, "$1-$2").replace(/([a-z])([0-9])/g, "$1-$2").toLowerCase();

function assertContrast(foreground, background, minimum, label) {
  const ratio = contrast(foreground, background);
  assert.ok(ratio >= minimum, `${label}: ${ratio.toFixed(4)}:1 is below ${minimum}:1 (${foreground} / ${background})`);
}

test("catalog schema, attribution, generic default, and requested presets", () => {
  assert.equal(catalog.schemaVersion, 1);
  assert.equal(catalog.defaultPreset, "neutral");
  const ids = catalog.presets.map((preset) => preset.id);
  assert.equal(new Set(ids).size, ids.length);
  requiredIds.forEach((id) => assert.ok(ids.includes(id), `Missing preset: ${id}`));
  for (const id of ["progress-inspired", "intersex-inspired"]) {
    const inspired = catalog.presets.find((preset) => preset.id === id);
    assert.equal(inspired.kind, "inspired-palette");
    assert.match(inspired.label, /not a flag/i);
  }
  for (const preset of catalog.presets.filter((entry) => entry.kind === "original-palette")) {
    assert.match(preset.label + preset.attribution.note, /original/i, `${preset.id} must declare itself original`);
  }
  for (const preset of catalog.presets) {
    const theme = createTheme(catalog, preset.id);
    assert.deepEqual(Object.keys(theme.colors), colorNames);
    assert.equal(theme.mode, "dark");
    assert.ok(!Object.hasOwn(theme, "$schema"), "Do not claim DTCG schema conformance.");
    assert.equal(preset.colors.length, preset.weights.length);
    assert.ok(preset.weights.every((weight) => Number.isFinite(weight) && weight > 0));
    assert.ok(preset.attribution.name && preset.attribution.note && preset.attribution.url.startsWith("https://"));
    assert.equal(theme.motion.decorativeDefault, "off");
    assert.equal(theme.motion.decorationMs, 0);
  }
});

test("known WCAG contrast values and strict hex inputs", () => {
  assert.equal(contrast("#000000", "#FFFFFF"), 21);
  assert.equal(contrast("#ABCDEF", "#ABCDEF"), 1);
  assert.equal(contrast("#abcdef", "#FFFFFF"), contrast("#FFFFFF", "#ABCDEF"));
  assert.ok(Math.abs(contrast("#F6F1F8", "#141118") - 16.79) < 0.01);
  for (const value of ["red", "#fff", "#FFFFFFFF", "#12GG00", " #FFFFFF", null, 123, "#000000; color:red"]) {
    assert.throws(() => contrast(value, "#FFFFFF"), TypeError);
    assert.throws(() => createTheme(catalog, "neutral", value), TypeError);
  }
});

test("every preset retains readable controls, text, statuses, links and focus", () => {
  const defaultColors = createTheme(catalog).colors;
  for (const preset of catalog.presets) {
    const { colors } = createTheme(catalog, preset.id);
    for (const surface of [colors.surface, colors.surfaceRaised, colors.surfaceMuted]) {
      for (const role of ["foreground", "foregroundMuted", "link", "positive", "warning", "negative"]) {
        assertContrast(colors[role], surface, 4.5, `${preset.id} ${role}`);
      }
      assertContrast(colors.focus, surface, 3, `${preset.id} focus`);
      assertContrast(colors.border, surface, 3, `${preset.id} control boundary`);
    }
    for (const state of ["accent", "accentHover", "accentPressed"]) assertContrast(colors.onAccent, colors[state], 4.5, `${preset.id} ${state} label`);
    assertContrast(colors.selectionText, colors.selection, 4.5, `${preset.id} selection`);
    for (const role of ["surface", "surfaceRaised", "surfaceMuted", "positive", "warning", "negative", "link", "focus"]) {
      assert.equal(colors[role], defaultColors[role], `${role} must not change with identity palette`);
    }
  }
});

test("terminal colors are readable, stable, and track cursor/selection only", () => {
  const neutral = createTheme(catalog);
  assert.deepEqual(Object.keys(neutral.terminal), ansiNames);
  for (const preset of catalog.presets) {
    const { terminal, colors } = createTheme(catalog, preset.id);
    for (const name of ansiNames.filter((entry) => !["black", "selection", "cursor"].includes(entry))) {
      assertContrast(terminal[name], colors.surface, 4.5, `${preset.id} ansi ${name}`);
      if (name !== "selectionText") assert.equal(terminal[name], neutral.terminal[name], `${name} must not change with identity palette`);
    }
    assert.equal(terminal.cursor, colors.accent);
    assert.equal(terminal.selection, colors.selection);
    assertContrast(terminal.selectionText, terminal.selection, 4.5, `${preset.id} terminal selection`);
  }
});

test("decorative derivations keep the reference stripe order and proportions", () => {
  const theme = createTheme(catalog, "bisexual");
  assert.equal(theme.gradients.horizontal, theme.gradient);
  assert.equal(theme.gradients.vertical, theme.gradient.replace("90deg", "180deg"));
  assert.equal(theme.gradients.diagonal, theme.gradient.replace("90deg", "135deg"));
  assert.equal(theme.gradients.conic, "conic-gradient(from -90deg, #D60270 0deg 144deg, #9B4F96 144deg 216deg, #0038A8 216deg 360deg)");
  assert.match(theme.gradients.wash, /^linear-gradient\(90deg, #[0-9A-F]{6} 0% 40%, #[0-9A-F]{6} 40% 60%, #[0-9A-F]{6} 60% 100%\)$/);
  const wash = theme.gradients.wash.match(/#[0-9A-F]{6}/g);
  for (const tint of wash) assert.ok(contrast(tint, theme.colors.surface) < 3, "Wash tints stay a background, not a text color.");
  const dark = createTheme(catalog, "leather");
  assert.notEqual(dark.gradients.wash.match(/#[0-9A-F]{6}/g)[0], dark.colors.surface, "Black stripes must still produce a visible tint.");
  for (const value of Object.values(theme.effects)) assert.doesNotMatch(value, /#[0-9a-f]{6}/i, "Effects reference variables, never literal colors.");
  assert.ok(theme.effects.glass.includes("--prism-surface-raised") && theme.effects.glow.includes("--prism-accent"));
});

test("custom accents keep one readable foreground through every action state", () => {
  const accents = new Set(["#000000", "#FFFFFF", "#777777", "#808080", "#E866AF", "#0038A8"]);
  for (let gray = 0; gray <= 255; gray += 1) accents.add(`#${gray.toString(16).padStart(2, "0").repeat(3)}`);
  for (const red of [0, 51, 102, 153, 204, 255]) for (const green of [0, 51, 102, 153, 204, 255]) for (const blue of [0, 51, 102, 153, 204, 255]) {
    accents.add(`#${[red, green, blue].map((value) => value.toString(16).padStart(2, "0")).join("")}`);
  }
  for (const accent of accents) {
    const theme = createTheme(catalog, "neutral", accent);
    assert.equal(theme.colors.accent, accent.toUpperCase(), "Do not silently change a custom accent.");
    for (const state of ["accent", "accentHover", "accentPressed"]) assertContrast(theme.colors.onAccent, theme.colors[state], 4.5, `${accent} ${state}`);
    assert.notEqual(theme.colors.accentHover, theme.colors.accent);
    assert.notEqual(theme.colors.accentPressed, theme.colors.accent);
  }
});

test("ordered stripe proportions use exact hard stops; reference colors remain separate", () => {
  const theme = createTheme(catalog, "bisexual");
  assert.deepEqual(theme.palette.weights, [2, 1, 2]);
  assert.deepEqual(theme.palette.colors, ["#D60270", "#9B4F96", "#0038A8"]);
  assert.equal(theme.gradient, "linear-gradient(90deg, #D60270 0% 40%, #9B4F96 40% 60%, #0038A8 60% 100%)");
  assert.equal(createTheme(catalog, "bisexual", "#123456").gradient, theme.gradient);
  assert.match(themeXaml(theme), /Color="#D60270" Offset="0\.4"/);
  assert.match(themeXaml(theme), /Color="#9B4F96" Offset="0\.4"/);
  assert.match(themeXaml(theme), /Color="#0038A8" Offset="0\.6"/);
});

test("theme and CSS are deterministic, independent, and complete", () => {
  const before = JSON.stringify(catalog);
  const first = createTheme(catalog, "bisexual");
  const second = createTheme(catalog, "bisexual");
  assert.deepEqual(first, second);
  assert.equal(themeCss(first), themeCss(second));
  const css = themeCss(first);
  assert.equal((css.match(/:root\s*\{/g) ?? []).length, 1);
  assert.equal((css.match(/\{/g) ?? []).length, 1, "Only the :root variable block is allowed.");
  assert.equal((css.match(/\}/g) ?? []).length, 1);
  assert.doesNotMatch(css, /@media|@keyframes|^\s*(?:animation|transition)\s*:/m);
  for (const [name, value] of Object.entries(first.colors)) {
    assert.ok(css.includes(`--prism-${kebab(name)}: ${value};`), name);
    assert.ok(themeXaml(first).includes(`<Color x:Key="Prism${name[0].toUpperCase() + name.slice(1)}">${value}</Color>`));
  }
  for (const [name, value] of Object.entries(first.metrics)) assert.ok(css.includes(`--prism-${kebab(name)}: ${value};`), name);
  assert.ok(css.includes("--prism-space-2xl: 32px;"), "Digit boundaries are hyphenated in variable names.");
  for (const [name, value] of Object.entries(first.motion)) {
    const duration = name.endsWith("Ms");
    assert.ok(css.includes(`--prism-motion-${kebab(duration ? name.slice(0, -2) : name)}: ${value}${duration ? "ms" : ""};`), name);
  }
  assert.ok(css.includes(`--prism-identity-gradient: ${first.gradient};`));
  for (const name of ["vertical", "diagonal", "conic", "wash"]) assert.ok(css.includes(`--prism-identity-${name}: ${first.gradients[name]};`), name);
  first.palette.colors.forEach((color, index) => assert.ok(css.includes(`--prism-stripe-${index + 1}: ${color};`)));
  assert.ok(css.includes(`--prism-stripe-count: ${first.palette.colors.length};`));
  for (const [name, value] of Object.entries(first.effects)) assert.ok(css.includes(`--prism-${kebab(name)}: ${value};`), name);
  for (const [name, value] of Object.entries(first.terminal)) assert.ok(css.includes(`--prism-ansi-${kebab(name)}: ${value};`), name);
  assert.ok(themeXaml(first).includes('<LinearGradientBrush x:Key="PrismIdentityGradientVertical"'));
  assert.ok(themeXaml(first).includes('<Color x:Key="PrismStripe1">#D60270</Color>'));
  assert.ok(themeXaml(first).includes('<Color x:Key="PrismAnsiBrightWhite">#F6F1F8</Color>'));
  first.palette.colors[0] = "#000000";
  first.palette.weights[0] = 500;
  first.palette.attribution.name = "Changed";
  first.colors.surface = "#FFFFFF";
  assert.equal(JSON.stringify(catalog), before);
  assert.deepEqual(createTheme(catalog, "bisexual"), second);
});

test("invalid catalog or preset fails clearly", () => {
  assert.throws(() => createTheme(catalog, "missing"), /Unknown palette/);
  assert.throws(() => createTheme(null), /catalog/i);
  const invalidChanges = [
    (value) => { value.schemaVersion = 2; },
    (value) => { value.defaultPreset = "missing"; },
    (value) => { value.presets = []; },
    (value) => { value.presets.push(value.presets[0]); },
    (value) => { value.presets[0].id = "../escape"; },
    (value) => { value.presets[0].colors = []; },
    (value) => { value.presets[0].colors[0] = "pink"; },
    (value) => { value.presets[0].weights = [1]; },
    (value) => { value.presets[0].weights[0] = 0; },
    (value) => { value.presets[0].weights[0] = -1; },
    (value) => { value.presets[0].weights[0] = Infinity; },
    (value) => { value.presets[0].weights[0] = NaN; },
    (value) => { value.presets[0].kind = "universal-brand"; },
    (value) => { value.presets[0].attribution = {}; },
    (value) => { value.presets[0].attribution.url = "javascript:alert(1)"; }
  ];
  for (const change of invalidChanges) {
    const invalid = structuredClone(catalog);
    change(invalid);
    assert.throws(() => createTheme(invalid), TypeError);
  }
});

test("tracked exports are generated from the neutral default", async () => {
  const theme = createTheme(catalog);
  assert.deepEqual(JSON.parse(await readFile(path.join(REPO_ROOT, "tokens/pride-prism.tokens.json"), "utf8")), theme);
  assert.equal(await readFile(path.join(REPO_ROOT, "tokens/pride-prism.css"), "utf8"), themeCss(theme));
  assert.equal(await readFile(path.join(REPO_ROOT, "tokens/PridePrism.xaml"), "utf8"), themeXaml(theme));
});

async function hashes(directory, prefix = "") {
  const result = {};
  for (const entry of (await readdir(directory, { withFileTypes: true })).sort((a, b) => a.name < b.name ? -1 : a.name > b.name ? 1 : 0)) {
    if (entry.name === ".install-state") continue;
    const relative = prefix ? `${prefix}/${entry.name}` : entry.name;
    const source = path.join(directory, entry.name);
    if (entry.isDirectory()) Object.assign(result, await hashes(source, relative));
    else if (entry.isFile()) result[relative] = createHash("sha256").update(await readFile(source)).digest("hex");
  }
  return result;
}

test("export is deterministic, injects CSS, preserves sources and generates native color mappings", async (context) => {
  await mkdir(DIST_ROOT, { recursive: true });
  const temporary = await mkdtemp(path.join(DIST_ROOT, ".test-theme-"));
  context.after(async () => {
    // Cleanup only this harness's resolved, uniquely created export directory.
    const resolved = await realpath(temporary);
    assert.equal(path.dirname(resolved).toLowerCase(), (await realpath(DIST_ROOT)).toLowerCase());
    assert.ok(path.basename(resolved).startsWith(".test-theme-"));
    await rm(resolved, { recursive: true });
  });
  const before = await hashes(path.join(REPO_ROOT, "adapters"));
  const first = await buildTheme({ palette: "bisexual", output: path.join(temporary, "first") });
  const second = await buildTheme({ palette: "bisexual", output: path.join(temporary, "second") });
  assert.deepEqual(await hashes(first.output), await hashes(second.output));
  const firstHashes = await hashes(first.output);
  await buildTheme({ palette: "bisexual", output: first.output });
  assert.deepEqual(await hashes(first.output), firstHashes);
  assert.deepEqual(await hashes(path.join(REPO_ROOT, "adapters")), before, "Exporter must never change source adapters.");
  assert.equal(first.adapterFileCount, Object.keys(before).length);
  const css = themeCss(first.theme);
  for (const relative of Object.keys(before).filter((name) => name.endsWith(".css") && !Object.hasOwn(GENERATED, name))) {
    const output = await readFile(path.join(first.output, "adapters", relative), "utf8");
    assert.equal(output.split(css).length - 1, 1, `${relative} must contain one generated token block`);
  }
  for (const relative of Object.keys(GENERATED)) {
    assert.ok(Object.hasOwn(before, relative), `${relative} needs a source marker so bundles stay self-describing`);
    const output = await readFile(path.join(first.output, "adapters", relative), "utf8");
    assert.doesNotMatch(output, /Source marker/, `${relative} must be generated, not copied`);
  }
  const discord = await readFile(path.join(first.output, "adapters/discord/PridePrism.theme.css"), "utf8");
  assert.match(discord, /^\/\*\*[\s\S]*?@name Pride Prism[\s\S]*?\*\//);
  assert.ok(discord.indexOf("@name Pride Prism") < discord.indexOf("--prism-surface:"));
  const manifest = JSON.parse(await readFile(path.join(first.output, "adapters/chrome/manifest.json"), "utf8"));
  assert.deepEqual(manifest.theme.colors.frame, [30, 26, 36]);
  assert.deepEqual(manifest.theme.colors.toolbar, [20, 17, 24]);
  assert.deepEqual(manifest.theme.colors.button_background, [42, 36, 51]);
  assert.deepEqual(manifest.theme.tints.buttons, [-1, 0, 0.8]);
  assert.equal(manifest.theme.images, undefined);
  const snippet = await readFile(path.join(first.output, "adapters/chatgpt/pride-prism-config.toml"), "utf8");
  assert.ok(snippet.includes(`accent = "${first.theme.colors.accent}"`));
  assert.ok(snippet.includes(`diffAdded = "${first.theme.colors.positive}"`));
  assert.ok(snippet.includes(`diffRemoved = "${first.theme.colors.negative}"`));
  assert.ok(snippet.includes("opaqueWindows = true"));
  assert.deepEqual(JSON.parse(await readFile(path.join(first.output, "theme.json"), "utf8")), first.theme);

  const occupied = path.join(temporary, "occupied");
  await mkdir(occupied);
  await writeFile(path.join(occupied, "keep.txt"), "Keep user content.");
  await assert.rejects(buildTheme({ output: occupied }), /nonempty/);
  assert.equal(await readFile(path.join(occupied, "keep.txt"), "utf8"), "Keep user content.");
  await assert.rejects(buildTheme({ output: "tokens" }), /dist directory/);
  await assert.rejects(buildTheme({ output: "dist" }), /dist directory/);
  await assert.rejects(buildTheme({ output: "dist/" }), /dist directory/);
  await assert.rejects(buildTheme({ output: "dist/../../outside" }), /dist directory/);
  await assert.rejects(buildTheme({ output: "dist/invalid", accent: "red" }), /six-digit hex/);
});

test("CLI rejects malformed or unknown arguments before creating output", () => {
  const script = path.join(REPO_ROOT, "scripts/build-theme.mjs");
  for (const args of [["--unknown"], ["--palette"], ["--palette", "neutral", "--palette", "bisexual"], ["--accent", "red"], ["--palette", "missing"], ["--write-defaults", "--palette", "bisexual"], ["toString", "invalid"], ["__proto__", "invalid"]]) {
    const result = spawnSync(process.execPath, [script, ...args], { encoding: "utf8", cwd: REPO_ROOT, windowsHide: true });
    assert.equal(result.status, 1, JSON.stringify(args));
    assert.match(result.stderr, /Theme export failed:/);
  }
  const help = spawnSync(process.execPath, [script, "--help"], { encoding: "utf8", cwd: REPO_ROOT, windowsHide: true });
  assert.equal(help.status, 0);
  assert.match(help.stdout, /--write-defaults/);
});
