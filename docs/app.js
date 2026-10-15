import { createTheme, themeCss, contrast } from "./theme/theme.mjs";
const $ = (id) => document.getElementById(id);
const storageKey = "pridePrism.theme.v2";
const kinds = { "flag-colors": "Flag colors", "inspired-palette": "Inspired palettes", "original-palette": "Original palettes" };
const roleNotes = { surface: "Canvas", surfaceRaised: "Panels", surfaceMuted: "Controls", foreground: "Body text", foregroundMuted: "Secondary text", accent: "Action fill", onAccent: "Action text", accentHover: "Hover fill", accentPressed: "Pressed fill", focus: "Focus ring", link: "Links", selection: "Selected fill", selectionText: "Selected text", border: "Control boundary", borderSubtle: "Decorative lines", positive: "Success", warning: "Warning", negative: "Error" };
const textRoles = new Set(["foreground", "foregroundMuted", "link", "positive", "warning", "negative"]);
let catalog, theme, customAccent, toastTimer, celebrationTimer;
let state = { palette: "neutral", intensity: 70, motion: false };
try { const saved = JSON.parse(localStorage.getItem(storageKey)); if (saved && typeof saved === "object") state = { ...state, ...saved }; } catch {}
const kebab = (name) => name.replace(/([a-z0-9])([A-Z])/g, "$1-$2").replace(/([a-z])([0-9])/g, "$1-$2").toLowerCase();
function announce(message) { clearTimeout(toastTimer); $("toast").textContent = message; toastTimer = setTimeout(() => $("toast").textContent = "", 3000); }
function persist() { try { localStorage.setItem(storageKey, JSON.stringify({ ...state, customAccent })); } catch { announce("Browser preferences could not be saved. Exports still work."); } }
async function copy(text, message) { try { await navigator.clipboard.writeText(text); announce(message); } catch { announce("Clipboard unavailable. Use Export CSS instead."); } }
function download(name, content, type) { const url = URL.createObjectURL(new Blob([content], { type })); const a = document.createElement("a"); a.href = url; a.download = name; a.click(); setTimeout(() => URL.revokeObjectURL(url), 1000); }
function el(tag, className, text) { const node = document.createElement(tag); if (className) node.className = className; if (text !== undefined) node.textContent = text; return node; }
function selectPalette(id) { state.palette = id; customAccent = undefined; render(); persist(); announce(theme.palette.label + " selected."); }
function renderGallery() {
  const grid = $("gallery-grid"); grid.replaceChildren();
  for (const preset of catalog.presets) {
    const resolved = createTheme(catalog, preset.id);
    const card = el("button", "gallery-card"); card.type = "button"; card.setAttribute("aria-pressed", String(preset.id === state.palette));
    card.style.setProperty("--card-gradient", resolved.gradient); card.style.setProperty("--card-wash", resolved.gradients.wash); card.style.setProperty("--card-accent", resolved.colors.accent); card.style.setProperty("--card-on-accent", resolved.colors.onAccent);
    const stripes = el("span", "gallery-stripes"); stripes.setAttribute("aria-hidden", "true");
    const head = el("span", "gallery-head"); head.append(el("strong", "", preset.label), el("span", "badge", kinds[preset.kind] ?? preset.kind));
    const meta = el("span", "gallery-meta"); const chip = el("span", "gallery-accent", resolved.colors.accent); meta.append(chip, el("small", "", preset.attribution.name));
    card.append(stripes, head, meta); card.addEventListener("click", () => { selectPalette(preset.id); $("workbench").scrollIntoView({ behavior: matchMedia("(prefers-reduced-motion: reduce)").matches ? "auto" : "smooth", block: "start" }); });
    grid.append(card);
  }
}
function renderRoles(c) {
  const body = $("role-table"); body.replaceChildren();
  for (const [name, value] of Object.entries(c)) {
    const row = el("tr"); const role = el("th", "", roleNotes[name] ?? name); role.scope = "row";
    const variable = el("td"); const code = el("code", "", "--prism-" + kebab(name)); variable.append(code);
    const swatch = el("td", "role-value"); const dot = el("i"); dot.style.background = value; const copyButton = el("button", "swatch", value); copyButton.type = "button"; copyButton.setAttribute("aria-label", "Copy " + name + " " + value); copyButton.addEventListener("click", () => copy(value, "Color copied.")); swatch.append(dot, copyButton);
    const ratio = el("td", "role-contrast"); if (textRoles.has(name)) { const r = contrast(value, c.surface); ratio.textContent = r.toFixed(2) + ":1"; ratio.className += r >= 4.5 ? " pass" : " fail"; } else if (name === "onAccent") { ratio.textContent = contrast(value, c.accent).toFixed(2) + ":1 on accent"; ratio.className += " pass"; } else if (name === "focus" || name === "border") { const r = contrast(value, c.surface); ratio.textContent = r.toFixed(2) + ":1 · 3:1 target"; ratio.className += r >= 3 ? " pass" : " fail"; } else ratio.textContent = "—";
    row.append(role, variable, swatch, ratio); body.append(row);
  }
}
function renderTerminal(t) {
  const sample = $("terminal-sample"); sample.replaceChildren();
  const line = (parts) => { const row = el("span", "term-line"); for (const [text, color] of parts) { const span = el("span", "", text); if (color) span.style.color = color; row.append(span); } sample.append(row); };
  line([["❯ ", t.cursor], ["git ", t.magenta], ["status", t.foreground ?? ""], ["   # ansi colors stay stable", t.brightBlack]]);
  line([["On branch ", t.white], ["main", t.cyan]]);
  line([["  modified:   ", t.yellow], ["tokens/palettes.json", t.white]]);
  line([["  new file:   ", t.green], ["adapters/terminals/README.md", t.white]]);
  line([["  deleted:    ", t.red], ["tools/legacy.cs", t.white]]);
  line([["❯ ", t.cursor], ["", null]]);
}
function render() {
  if (!catalog) return;
  theme = createTheme(catalog, state.palette, customAccent);
  let sheet = $("resolved-theme"); if (!sheet) { sheet = document.createElement("style"); sheet.id = "resolved-theme"; document.head.append(sheet); } sheet.textContent = themeCss(theme);
  document.documentElement.style.setProperty("--decoration-opacity", state.intensity / 100);
  $("palette").value = state.palette; $("palette-badge").textContent = theme.palette.label;
  $("accent").value = theme.colors.accent; $("accent-picker").value = theme.colors.accent;
  $("intensity").value = state.intensity; $("intensity-value").textContent = state.intensity + "%"; $("motion").checked = state.motion;
  $("accent-error").textContent = ""; $("accent").removeAttribute("aria-invalid");
  $("palette-note").textContent = theme.palette.attribution.note;
  $("swatches").replaceChildren();
  theme.palette.colors.forEach((color) => { const b = el("button", "swatch"); b.type = "button"; b.setAttribute("aria-label", "Copy reference color " + color); const swatch = el("i"); swatch.style.background = color; swatch.setAttribute("aria-hidden", "true"); b.append(swatch, document.createTextNode(color)); b.addEventListener("click", () => copy(color, "Color copied.")); $("swatches").append(b); });
  const c = theme.colors;
  $("accent-states").replaceChildren(...[["Accent", c.accent], ["Hover", c.accentHover], ["Pressed", c.accentPressed]].map(([label, fill]) => { const chip = el("span", "state-chip"); chip.style.background = fill; chip.style.color = c.onAccent; chip.append(el("strong", "", label), el("small", "", fill + " · " + contrast(c.onAccent, fill).toFixed(1) + ":1")); return chip; }));
  const pairs = [["Body text", c.foreground, c.surface, 4.5], ["Secondary text", c.foregroundMuted, c.surfaceMuted, 4.5], ["Action text", c.onAccent, c.accent, 4.5], ["Control boundary", c.border, c.surfaceMuted, 3]];
  $("contrast-grid").replaceChildren();
  pairs.forEach(([name, fg, bg, min]) => { const article = el("article", "contrast-card"); const sample = el("span", "contrast-sample", "Aa"); sample.style.color = fg; sample.style.background = bg; const title = el("h3", "", name); const pair = el("p", "", fg + " on " + bg); const value = el("strong", "", contrast(fg, bg).toFixed(2) + ":1"); const verdict = el("small", "", (contrast(fg, bg) >= min ? "Pass" : "Below target") + " · " + min + ":1 target"); article.append(sample, title, pair, value, verdict); $("contrast-grid").append(article); });
  renderRoles(c); renderTerminal(theme.terminal);
  document.querySelectorAll(".gallery-card").forEach((card, index) => card.setAttribute("aria-pressed", String(catalog.presets[index].id === state.palette)));
  const css = themeCss(theme); $("token-code").textContent = css;
  $("build-command").textContent = "node scripts/build-theme.mjs --palette " + state.palette + (customAccent ? ' --accent "' + customAccent + '"' : "");
  ["download-css", "download-json", "copy-css", "palette"].forEach(id => $(id).disabled = false);
  $("preview-status").textContent = state.motion ? "Celebration available on request; reduced motion takes priority." : "Celebration is off. Use Tab to inspect keyboard focus.";
}
function applyAccent(value) {
  if (!/^#[0-9a-f]{6}$/i.test(value)) { $("accent-error").textContent = "Use a six-digit hex color, for example #E866AF. Exports are paused until it is valid."; $("accent").setAttribute("aria-invalid", "true"); ["download-css", "download-json", "copy-css"].forEach(id => $(id).disabled = true); return; }
  customAccent = value.toUpperCase(); render(); persist();
}
try {
  const response = await fetch("./theme/palettes.json"); if (!response.ok) throw new Error("Palette catalog unavailable.");
  catalog = await response.json();
  if (!catalog.presets.some(p => p.id === state.palette)) state.palette = catalog.defaultPreset;
  state.intensity = Number.isFinite(Number(state.intensity)) ? Math.max(0, Math.min(100, Number(state.intensity))) : 70;
  state.motion = state.motion === true;
  customAccent = typeof state.customAccent === "string" && /^#[0-9a-f]{6}$/i.test(state.customAccent) ? state.customAccent : undefined;
  const groups = new Map();
  for (const preset of catalog.presets) { const label = kinds[preset.kind] ?? preset.kind; if (!groups.has(label)) groups.set(label, document.createElement("optgroup")); groups.get(label).label = label; const o = document.createElement("option"); o.value = preset.id; o.textContent = preset.label; groups.get(label).append(o); }
  $("palette").replaceChildren(...groups.values());
  renderGallery();
  render();
  const kitSheet = [...document.styleSheets].find(sheet => sheet.href && sheet.href.endsWith("styles.css"));
  try { $("kit-code").textContent = [...kitSheet.cssRules].filter(rule => rule.cssText.includes("/* kit */") || /^\.(rail|ring|glass-card|kit-aurora|glow-button|foil-text|chevron)/.test(rule.cssText)).map(rule => rule.cssText).join("\n"); } catch { $("kit-code").textContent = "Open docs/styles.css and copy the rules under /* Decoration kit */."; }
} catch (error) { $("load-error").hidden = false; $("load-error").textContent = "The palette catalog could not load. Please reload this page. No desktop settings have changed."; console.error(error); }
$("theme-form").addEventListener("submit", e => e.preventDefault());
$("palette").addEventListener("change", e => selectPalette(e.target.value));
$("accent").addEventListener("input", e => applyAccent(e.target.value.trim()));
$("accent-picker").addEventListener("input", e => applyAccent(e.target.value));
$("reset-accent").addEventListener("click", () => { customAccent = undefined; render(); persist(); });
$("intensity").addEventListener("input", e => { state.intensity = Number(e.target.value); document.documentElement.style.setProperty("--decoration-opacity", state.intensity / 100); $("intensity-value").textContent = state.intensity + "%"; persist(); });
$("motion").addEventListener("change", e => { state.motion = e.target.checked; if (!state.motion) { clearTimeout(celebrationTimer); $("preview").classList.remove("celebrating"); } render(); persist(); });
$("theme-form").addEventListener("reset", e => { e.preventDefault(); if (!catalog) return; clearTimeout(celebrationTimer); $("preview").classList.remove("celebrating"); state = { palette: catalog.defaultPreset, intensity: 70, motion: false }; customAccent = undefined; render(); persist(); announce("Palette preferences reset."); });
$("download-css").addEventListener("click", () => download("pride-prism-" + state.palette + ".css", themeCss(theme), "text/css"));
$("download-json").addEventListener("click", () => download("pride-prism-" + state.palette + ".json", JSON.stringify(theme, null, 2) + "\n", "application/json"));
$("copy-css").addEventListener("click", () => copy(themeCss(theme), "CSS tokens copied."));
$("focus-demo").addEventListener("click", () => $("sample-input").focus());
document.querySelectorAll(".preview-tabs button").forEach(button => button.addEventListener("click", () => { document.querySelectorAll(".preview-tabs button").forEach(b => b.setAttribute("aria-pressed", String(b === button))); $("specimen-title").textContent = { Workspace: "Ready for everyday work", Activity: "Keep important states clear", Settings: "Make space for your preferences" }[button.textContent]; }));
$("celebrate").addEventListener("click", () => {
  if (!state.motion || matchMedia("(prefers-reduced-motion: reduce)").matches) { $("preview-status").textContent = !state.motion ? "Enable the celebration option to preview it." : "Reduced motion is enabled. Showing the static palette."; return; }
  clearTimeout(celebrationTimer); $("preview").classList.remove("celebrating"); void $("preview").offsetWidth; $("preview").classList.add("celebrating");
  $("preview-status").textContent = "A single, gentle 1.5-second accent glow.";
  celebrationTimer = setTimeout(() => { $("preview").classList.remove("celebrating"); $("preview-status").textContent = "Celebration finished."; }, 1500);
});
