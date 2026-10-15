/** Pure shared browser/Node theme functions. No storage, network, or DOM access. */
const HEX = /^#[0-9a-f]{6}$/i;
const ID = /^[a-z][a-z0-9-]{0,39}$/;
const MIN_TEXT_CONTRAST = 4.5;

const BASE_COLORS = Object.freeze({
  surface: "#141118",
  surfaceRaised: "#1E1A24",
  surfaceMuted: "#2A2433",
  foreground: "#F6F1F8",
  foregroundMuted: "#C9BFD2",
  focus: "#A6C8FF",
  link: "#A6C8FF",
  selection: "#46314F",
  selectionText: "#F6F1F8",
  border: "#8B7998",
  borderSubtle: "#3E3548",
  positive: "#66D6A4",
  warning: "#E8C66A",
  negative: "#FF7A90"
});

function hex(value, name = "Color") {
  if (typeof value !== "string" || !HEX.test(value)) {
    throw new TypeError(`${name} must be a six-digit hex color such as #E866AF.`);
  }
  return value.toUpperCase();
}

function channels(value) {
  return hex(value).slice(1).match(/../g).map((part) => parseInt(part, 16));
}

function luminance(value) {
  const [red, green, blue] = channels(value).map((channel) => {
    const srgb = channel / 255;
    return srgb <= 0.04045 ? srgb / 12.92 : ((srgb + 0.055) / 1.055) ** 2.4;
  });
  return 0.2126 * red + 0.7152 * green + 0.0722 * blue;
}

/** WCAG sRGB relative-luminance contrast. Inputs must be opaque #RRGGBB. */
export function contrast(a, b) {
  const first = luminance(a);
  const second = luminance(b);
  return (Math.max(first, second) + 0.05) / (Math.min(first, second) + 0.05);
}

function mix(first, second, amount) {
  const target = channels(second);
  return `#${channels(first).map((channel, index) =>
    Math.round(channel + (target[index] - channel) * amount).toString(16).padStart(2, "0")
  ).join("").toUpperCase()}`;
}

function onAccent(background) {
  // Prefer the system's neutral inks; near middle gray, black/white close the
  // small contrast gap that a pair of off-black/off-white inks cannot cover.
  const preferred = [BASE_COLORS.surface, BASE_COLORS.foreground]
    .sort((a, b) => contrast(b, background) - contrast(a, background));
  if (contrast(preferred[0], background) >= MIN_TEXT_CONTRAST) return preferred[0];
  return contrast("#000000", background) >= contrast("#FFFFFF", background) ? "#000000" : "#FFFFFF";
}

function stateAccent(background, foreground, amount, improveContrast) {
  const lightInk = luminance(foreground) > luminance(background);
  const improvingTarget = lightInk ? "#000000" : "#FFFFFF";
  const oppositeTarget = lightInk ? "#FFFFFF" : "#000000";
  const targets = improveContrast ? [improvingTarget, oppositeTarget] : [oppositeTarget, improvingTarget];
  for (const target of targets) {
    for (let step = Math.round(amount * 100); step >= 1; step -= 1) {
      const candidate = mix(background, target, step / 100);
      if (candidate !== background && contrast(foreground, candidate) >= MIN_TEXT_CONTRAST) return candidate;
    }
  }
  return background;
}

function validateCatalog(catalog) {
  if (!catalog || catalog.schemaVersion !== 1 || !Array.isArray(catalog.presets) || !catalog.presets.length) {
    throw new TypeError("Palette catalog must have schemaVersion 1 and a nonempty presets array.");
  }
  const ids = new Set();
  for (const preset of catalog.presets) {
    if (!preset || typeof preset.id !== "string" || !ID.test(preset.id) || ids.has(preset.id)) {
      throw new TypeError("Every palette needs a unique, lowercase id.");
    }
    ids.add(preset.id);
    if (typeof preset.label !== "string" || !preset.label.trim()) throw new TypeError(`Palette ${preset.id} needs a label.`);
    if (!["flag-colors", "inspired-palette", "original-palette"].includes(preset.kind)) throw new TypeError(`Palette ${preset.id} has an invalid kind.`);
    if (!Array.isArray(preset.colors) || !preset.colors.length || preset.colors.length > 32) throw new TypeError(`Palette ${preset.id} needs 1–32 colors.`);
    preset.colors.forEach((color) => hex(color, `Palette ${preset.id} color`));
    hex(preset.accent, `Palette ${preset.id} accent`);
    if (!Array.isArray(preset.weights) || preset.weights.length !== preset.colors.length ||
        !preset.weights.every((weight) => typeof weight === "number" && Number.isFinite(weight) && weight > 0) ||
        !Number.isFinite(preset.weights.reduce((sum, weight) => sum + weight, 0))) {
      throw new TypeError(`Palette ${preset.id} needs a positive, finite weight for each color.`);
    }
    const attribution = preset.attribution;
    if (!attribution || ![attribution.name, attribution.url, attribution.note].every((value) => typeof value === "string" && value.trim())) {
      throw new TypeError(`Palette ${preset.id} needs attribution name, url, and note.`);
    }
    let source;
    try { source = new URL(attribution.url); } catch { throw new TypeError(`Palette ${preset.id} has an invalid attribution URL.`); }
    if (source.protocol !== "https:") throw new TypeError(`Palette ${preset.id} attribution must use HTTPS.`);
  }
  if (!ids.has(catalog.defaultPreset)) throw new TypeError("Catalog defaultPreset must name an existing palette.");
}

/** Ordered hard stops scaled to a unit (100% for linear, 360deg for conic). */
function identityStops(colors, weights, unit, scale) {
  const total = weights.reduce((sum, weight) => sum + weight, 0);
  let used = 0;
  return colors.map((color, index) => {
    const start = Number((used / total * scale).toFixed(6));
    used += weights[index];
    const end = Number((used / total * scale).toFixed(6));
    return `${color} ${start}${unit} ${end}${unit}`;
  }).join(", ");
}

function identityGradient(palette, angle = "90deg") {
  return `linear-gradient(${angle}, ${identityStops(palette.colors, palette.weights, "%", 100)})`;
}

/** Decorative derivations of the reference stripes. Static values only. */
function identityGradients(palette) {
  // The wash keeps every stripe readable as a tint over the canvas, so even
  // black or near-surface stripes remain visible as a band.
  const washed = palette.colors.map((color) => mix(BASE_COLORS.surface, color, 0.24));
  return {
    horizontal: identityGradient(palette),
    vertical: identityGradient(palette, "180deg"),
    diagonal: identityGradient(palette, "135deg"),
    conic: `conic-gradient(from -90deg, ${identityStops(palette.colors, palette.weights, "deg", 360)})`,
    wash: `linear-gradient(90deg, ${identityStops(washed, palette.weights, "%", 100)})`
  };
}

/** Translucent surface effects. CSS-only: they reference the emitted variables. */
const EFFECTS = Object.freeze({
  glass: "color-mix(in srgb, var(--prism-surface-raised) 64%, transparent)",
  glassBorder: "color-mix(in srgb, var(--prism-foreground) 14%, transparent)",
  glassBlur: "16px",
  glow: "0 0 0 1px color-mix(in srgb, var(--prism-accent) 40%, transparent), 0 8px 32px color-mix(in srgb, var(--prism-accent) 22%, transparent)",
  accentWash: "color-mix(in oklab, var(--prism-accent) 8%, var(--prism-surface-raised))"
});

/** Sixteen ANSI colors tuned for the dark neutrals. Like status colors, they
 * do not change with the identity palette; cursor and selection do. */
const ANSI = Object.freeze({
  black: BASE_COLORS.surfaceMuted,
  red: BASE_COLORS.negative,
  green: BASE_COLORS.positive,
  yellow: BASE_COLORS.warning,
  blue: BASE_COLORS.link,
  magenta: "#D9A3F5",
  cyan: "#7FD9E4",
  white: BASE_COLORS.foregroundMuted,
  brightBlack: BASE_COLORS.border,
  brightRed: "#FFA3B2",
  brightGreen: "#93E5BF",
  brightYellow: "#F2D996",
  brightBlue: "#C4DAFF",
  brightMagenta: "#E8C2FA",
  brightCyan: "#A8E7EE",
  brightWhite: BASE_COLORS.foreground
});

/** Create an independent dark theme. Invalid presets/accents fail explicitly. */
export function createTheme(catalog, presetId = catalog?.defaultPreset, customAccent) {
  validateCatalog(catalog);
  const preset = catalog.presets.find((entry) => entry.id === presetId);
  if (!preset) throw new RangeError(`Unknown palette: ${String(presetId)}.`);
  const accent = hex(customAccent === undefined ? preset.accent : customAccent, "Accent");
  const ink = onAccent(accent);
  const palette = {
    id: preset.id,
    label: preset.label,
    kind: preset.kind,
    colors: preset.colors.map((color) => hex(color)),
    weights: [...preset.weights],
    accent: hex(preset.accent),
    attribution: { ...preset.attribution }
  };
  return {
    schemaVersion: 1,
    name: "Pride Prism",
    mode: "dark",
    palette,
    colors: {
      surface: BASE_COLORS.surface,
      surfaceRaised: BASE_COLORS.surfaceRaised,
      surfaceMuted: BASE_COLORS.surfaceMuted,
      foreground: BASE_COLORS.foreground,
      foregroundMuted: BASE_COLORS.foregroundMuted,
      accent,
      onAccent: ink,
      accentHover: stateAccent(accent, ink, 0.12, true),
      accentPressed: stateAccent(accent, ink, 0.08, false),
      focus: BASE_COLORS.focus,
      link: BASE_COLORS.link,
      selection: BASE_COLORS.selection,
      selectionText: BASE_COLORS.selectionText,
      border: BASE_COLORS.border,
      borderSubtle: BASE_COLORS.borderSubtle,
      positive: BASE_COLORS.positive,
      warning: BASE_COLORS.warning,
      negative: BASE_COLORS.negative
    },
    gradient: identityGradient(palette),
    gradients: identityGradients(palette),
    effects: { ...EFFECTS },
    terminal: { ...ANSI, cursor: accent, selection: BASE_COLORS.selection, selectionText: BASE_COLORS.selectionText },
    metrics: {
      spaceXs: "4px", spaceSm: "8px", spaceMd: "12px", spaceLg: "16px", spaceXl: "24px", space2xl: "32px",
      radiusSm: "6px", radiusMd: "12px", radiusLg: "18px",
      fontUi: '"Segoe UI Variable", "Segoe UI", system-ui, sans-serif',
      fontCode: '"Cascadia Code", ui-monospace, Consolas, monospace',
      fontSizeSmall: "0.8125rem", fontSizeBody: "0.9375rem", fontSizeTitle: "1.25rem",
      lineHeight: 1.5, fontWeightRegular: 400, fontWeightStrong: 650,
      controlBorderWidth: "1px", focusWidth: "2px", focusOffset: "2px", identityThickness: "3px"
    },
    motion: {
      fastMs: 160,
      standardMs: 280,
      decorationMs: 0,
      celebrationMs: 1500,
      easing: "cubic-bezier(0.22, 1, 0.36, 1)",
      decorativeDefault: "off",
      reducedMotion: "disable-decorative"
    }
  };
}

function kebab(value) {
  // Split before capitals and before digits so `space2xl` becomes `space-2xl`.
  return value.replace(/([a-z0-9])([A-Z])/g, "$1-$2").replace(/([a-z])([0-9])/g, "$1-$2").toLowerCase();
}

/** Variables only: callers own layout, component states, and motion opt-in. */
export function themeCss(theme) {
  const declarations = Object.entries(theme.colors).map(([name, value]) => `  --prism-${kebab(name)}: ${hex(value)};`);
  declarations.push(`  --prism-identity-gradient: ${theme.gradient};`);
  for (const [name, value] of Object.entries(theme.gradients)) {
    if (name !== "horizontal") declarations.push(`  --prism-identity-${kebab(name)}: ${value};`);
  }
  theme.palette.colors.forEach((color, index) => declarations.push(`  --prism-stripe-${index + 1}: ${hex(color)};`));
  declarations.push(`  --prism-stripe-count: ${theme.palette.colors.length};`);
  for (const [name, value] of Object.entries(theme.effects)) declarations.push(`  --prism-${kebab(name)}: ${value};`);
  for (const [name, value] of Object.entries(theme.terminal)) declarations.push(`  --prism-ansi-${kebab(name)}: ${hex(value)};`);
  for (const [name, value] of Object.entries(theme.metrics)) declarations.push(`  --prism-${kebab(name)}: ${value};`);
  for (const [name, value] of Object.entries(theme.motion)) {
    const duration = name.endsWith("Ms");
    declarations.push(`  --prism-motion-${kebab(duration ? name.slice(0, -2) : name)}: ${value}${duration ? "ms" : ""};`);
  }
  return `/* Generated Pride Prism tokens. Static decoration is the default. */\n:root {\n${declarations.join("\n")}\n}\n`;
}
