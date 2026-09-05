import { createTheme, themeCss, contrast } from "./theme/theme.mjs";
const $ = (id) => document.getElementById(id);
const storageKey = "pridePrism.theme.v2";
let catalog, theme, customAccent, toastTimer, celebrationTimer;
let state = { palette: "neutral", intensity: 70, motion: false };
try { const saved = JSON.parse(localStorage.getItem(storageKey)); if (saved && typeof saved === "object") state = { ...state, ...saved }; } catch {}
function announce(message) { clearTimeout(toastTimer); $("toast").textContent = message; toastTimer = setTimeout(() => $("toast").textContent = "", 3000); }
function persist() { try { localStorage.setItem(storageKey, JSON.stringify({ ...state, customAccent })); } catch { announce("Browser preferences could not be saved. Exports still work."); } }
async function copy(text, message) { try { await navigator.clipboard.writeText(text); announce(message); } catch { announce("Clipboard unavailable. Use Export CSS instead."); } }
function download(name, content, type) { const url = URL.createObjectURL(new Blob([content], { type })); const a = document.createElement("a"); a.href = url; a.download = name; a.click(); setTimeout(() => URL.revokeObjectURL(url), 1000); }
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
  theme.palette.colors.forEach((color) => { const b = document.createElement("button"); b.type = "button"; b.className = "swatch"; b.setAttribute("aria-label", "Copy reference color " + color); const swatch = document.createElement("i"); swatch.style.background = color; swatch.setAttribute("aria-hidden","true"); b.append(swatch, document.createTextNode(color)); b.addEventListener("click", () => copy(color, "Color copied.")); $("swatches").append(b); });
  const c = theme.colors;
  const pairs = [["Body text",c.foreground,c.surface,4.5],["Secondary text",c.foregroundMuted,c.surfaceMuted,4.5],["Action text",c.onAccent,c.accent,4.5],["Control boundary",c.border,c.surfaceMuted,3]];
  $("contrast-grid").replaceChildren();
  pairs.forEach(([name,fg,bg,min]) => { const article = document.createElement("article"); article.className = "contrast-card"; const title = document.createElement("h3"); title.textContent = name; const pair = document.createElement("p"); pair.textContent = fg + " on " + bg; const value = document.createElement("strong"); value.textContent = contrast(fg,bg).toFixed(2) + ":1"; const verdict = document.createElement("small"); verdict.textContent = (contrast(fg,bg) >= min ? "Pass" : "Below target") + " · " + min + ":1 target"; article.append(title,pair,value,verdict); $("contrast-grid").append(article); });
  const css = themeCss(theme); $("token-code").textContent = css;
  $("build-command").textContent = "node scripts/build-theme.mjs --palette " + state.palette + (customAccent ? ' --accent "' + customAccent + '"' : "");
  ["download-css","download-json","copy-css","palette"].forEach(id => $(id).disabled = false);
  $("preview-status").textContent = state.motion ? "Celebration available on request; reduced motion takes priority." : "Celebration is off. Use Tab to inspect keyboard focus.";
}
function applyAccent(value) {
  if (!/^#[0-9a-f]{6}$/i.test(value)) { $("accent-error").textContent = "Use a six-digit hex color, for example #E866AF. Exports are paused until it is valid."; $("accent").setAttribute("aria-invalid","true"); ["download-css","download-json","copy-css"].forEach(id => $(id).disabled = true); return; }
  customAccent = value.toUpperCase(); render(); persist();
}
try {
  const response = await fetch("./theme/palettes.json"); if (!response.ok) throw new Error("Palette catalog unavailable.");
  catalog = await response.json();
  if (!catalog.presets.some(p => p.id === state.palette)) state.palette = catalog.defaultPreset;
  state.intensity = Number.isFinite(Number(state.intensity)) ? Math.max(0,Math.min(100,Number(state.intensity))) : 70;
  state.motion = state.motion === true;
  customAccent = typeof state.customAccent === "string" && /^#[0-9a-f]{6}$/i.test(state.customAccent) ? state.customAccent : undefined;
  $("palette").replaceChildren(...catalog.presets.map(p => { const o = document.createElement("option"); o.value = p.id; o.textContent = p.label; return o; }));
  render();
} catch (error) { $("load-error").hidden = false; $("load-error").textContent = "The palette catalog could not load. Please reload this page. No desktop settings have changed."; console.error(error); }
$("theme-form").addEventListener("submit", e => e.preventDefault());
$("palette").addEventListener("change", e => { state.palette = e.target.value; customAccent = undefined; render(); persist(); announce(theme.palette.label + " selected."); });
$("accent").addEventListener("input", e => applyAccent(e.target.value.trim()));
$("accent-picker").addEventListener("input", e => applyAccent(e.target.value));
$("reset-accent").addEventListener("click", () => { customAccent = undefined; render(); persist(); });
$("intensity").addEventListener("input", e => { state.intensity = Number(e.target.value); document.documentElement.style.setProperty("--decoration-opacity",state.intensity / 100); $("intensity-value").textContent = state.intensity + "%"; persist(); });
$("motion").addEventListener("change", e => { state.motion = e.target.checked; if (!state.motion) { clearTimeout(celebrationTimer); $("preview").classList.remove("celebrating"); } render(); persist(); });
$("theme-form").addEventListener("reset", e => { e.preventDefault(); if (!catalog) return; clearTimeout(celebrationTimer); $("preview").classList.remove("celebrating"); state = { palette:catalog.defaultPreset,intensity:70,motion:false }; customAccent = undefined; render(); persist(); announce("Palette preferences reset."); });
$("download-css").addEventListener("click", () => download("pride-prism-" + state.palette + ".css", themeCss(theme), "text/css"));
$("download-json").addEventListener("click", () => download("pride-prism-" + state.palette + ".json", JSON.stringify(theme,null,2) + "\n", "application/json"));
$("copy-css").addEventListener("click", () => copy(themeCss(theme), "CSS tokens copied."));
$("focus-demo").addEventListener("click", () => $("sample-input").focus());
document.querySelectorAll(".preview-tabs button").forEach(button => button.addEventListener("click", () => { document.querySelectorAll(".preview-tabs button").forEach(b => b.setAttribute("aria-pressed",String(b === button))); $("specimen-title").textContent = {Workspace:"Ready for everyday work",Activity:"Keep important states clear",Settings:"Make space for your preferences"}[button.textContent]; }));
$("celebrate").addEventListener("click", () => {
  if (!state.motion || matchMedia("(prefers-reduced-motion: reduce)").matches) { $("preview-status").textContent = !state.motion ? "Enable the celebration option to preview it." : "Reduced motion is enabled. Showing the static palette."; return; }
  clearTimeout(celebrationTimer); $("preview").classList.remove("celebrating"); void $("preview").offsetWidth; $("preview").classList.add("celebrating");
  $("preview-status").textContent = "A single, gentle 1.5-second accent glow.";
  celebrationTimer = setTimeout(() => { $("preview").classList.remove("celebrating"); $("preview-status").textContent = "Celebration finished."; },1500);
});
