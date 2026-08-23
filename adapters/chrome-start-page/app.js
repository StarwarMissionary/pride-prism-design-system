const STORAGE_KEY = "pridePrism.quickLinks.v1";
const PALETTE = ["#E40303", "#FF8C00", "#FFED00", "#008026", "#004DFF", "#750787", "#74D7EE", "#FFAFC8"];
const DEFAULT_SHORTCUTS = [
  { name: "GitHub", url: "https://github.com/" },
  { name: "YouTube", url: "https://www.youtube.com/" },
  { name: "Gmail", url: "https://mail.google.com/" },
  { name: "Pride Prism", url: "https://starwarmissionary.github.io/pride-prism-design-system/" }
];

const clockText = document.querySelector("#clockText");
const dateText = document.querySelector("#dateText");
const greeting = document.querySelector("#greeting");
const searchInput = document.querySelector("#searchInput");
const shortcutGrid = document.querySelector("#shortcutGrid");
const manageButton = document.querySelector("#manageButton");
const shortcutDialog = document.querySelector("#shortcutDialog");
const shortcutForm = document.querySelector("#shortcutForm");
const shortcutName = document.querySelector("#shortcutName");
const shortcutUrl = document.querySelector("#shortcutUrl");
const announcement = document.querySelector("#announcement");

let shortcuts = readShortcuts();
let managing = false;

function readShortcuts() {
  try {
    const value = JSON.parse(localStorage.getItem(STORAGE_KEY));
    if (Array.isArray(value)) {
      return value.filter((item) => item && typeof item.name === "string" && typeof item.url === "string").slice(0, 9);
    }
  } catch {
    // A malformed local preference should never break the start page.
  }
  return [...DEFAULT_SHORTCUTS];
}

function saveShortcuts() {
  localStorage.setItem(STORAGE_KEY, JSON.stringify(shortcuts));
}

function updateClock() {
  const now = new Date();
  clockText.textContent = new Intl.DateTimeFormat(undefined, {
    hour: "numeric",
    minute: "2-digit"
  }).format(now);
  dateText.textContent = new Intl.DateTimeFormat(undefined, {
    weekday: "long",
    month: "long",
    day: "numeric"
  }).format(now);

  const hour = now.getHours();
  greeting.textContent = hour < 12 ? "Good morning." : hour < 18 ? "Good afternoon." : "Good evening.";
}

function monogram(name) {
  return name.trim().slice(0, 1).toUpperCase() || "✦";
}

function removeShortcut(index) {
  const [removed] = shortcuts.splice(index, 1);
  saveShortcuts();
  renderShortcuts();
  announcement.textContent = `${removed.name} removed.`;
}

function renderShortcuts() {
  shortcutGrid.replaceChildren();

  shortcuts.forEach((shortcut, index) => {
    const tile = document.createElement("div");
    tile.className = "shortcut";

    const link = document.createElement("a");
    link.className = "shortcut-link";
    link.href = shortcut.url;
    link.title = shortcut.url;

    const icon = document.createElement("span");
    icon.className = "shortcut-monogram";
    icon.textContent = monogram(shortcut.name);

    const name = document.createElement("span");
    name.className = "shortcut-name";
    name.textContent = shortcut.name;

    const removeButton = document.createElement("button");
    removeButton.className = "remove-shortcut";
    removeButton.type = "button";
    removeButton.setAttribute("aria-label", `Remove ${shortcut.name}`);
    removeButton.textContent = "×";
    removeButton.addEventListener("click", (event) => {
      event.preventDefault();
      event.stopPropagation();
      removeShortcut(index);
    });

    link.append(icon, name);
    tile.append(link, removeButton);
    shortcutGrid.append(tile);
  });

  if (shortcuts.length < 9) {
    const addButton = document.createElement("button");
    addButton.className = "add-shortcut";
    addButton.type = "button";
    addButton.innerHTML = "<span aria-hidden=\"true\">+</span><span>Add shortcut</span>";
    addButton.addEventListener("click", openShortcutDialog);
    shortcutGrid.append(addButton);
  }
}

function openShortcutDialog() {
  shortcutForm.reset();
  shortcutDialog.showModal();
  window.setTimeout(() => shortcutName.focus(), 0);
}

function closeShortcutDialog() {
  shortcutDialog.close();
}

function setManaging(nextValue) {
  managing = nextValue;
  document.body.classList.toggle("is-managing", managing);
  manageButton.setAttribute("aria-pressed", String(managing));
  manageButton.textContent = managing ? "Done" : "Manage";
}

function celebrate() {
  if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) {
    announcement.textContent = "Pride celebrated.";
    return;
  }

  const container = document.querySelector("#celebration");
  const fragment = document.createDocumentFragment();
  for (let index = 0; index < 38; index += 1) {
    const particle = document.createElement("span");
    const angle = (Math.PI * 2 * index) / 38 + Math.random() * 0.16;
    const distance = 120 + Math.random() * Math.min(window.innerWidth, 460);
    particle.className = "prism-particle";
    particle.style.setProperty("--particle-color", PALETTE[index % PALETTE.length]);
    particle.style.setProperty("--rotation", `${Math.round(Math.random() * 180)}deg`);
    particle.style.setProperty("--x", `${Math.cos(angle) * distance}px`);
    particle.style.setProperty("--y", `${Math.sin(angle) * distance}px`);
    particle.style.animationDelay = `${Math.random() * 90}ms`;
    fragment.append(particle);
  }
  container.replaceChildren(fragment);
  window.setTimeout(() => container.replaceChildren(), 1500);
  announcement.textContent = "Pride celebrated.";
}

manageButton.addEventListener("click", () => setManaging(!managing));
document.querySelector("#celebrateButton").addEventListener("click", celebrate);
document.querySelector("#closeDialogButton").addEventListener("click", closeShortcutDialog);
document.querySelector("#cancelDialogButton").addEventListener("click", closeShortcutDialog);

shortcutForm.addEventListener("submit", (event) => {
  event.preventDefault();
  const name = shortcutName.value.trim();
  let url;
  try {
    url = new URL(shortcutUrl.value.trim());
  } catch {
    shortcutUrl.setCustomValidity("Enter a complete web address, including https://");
    shortcutUrl.reportValidity();
    return;
  }

  if (url.protocol !== "https:" && url.protocol !== "http:") {
    shortcutUrl.setCustomValidity("Only http and https addresses are supported.");
    shortcutUrl.reportValidity();
    return;
  }

  shortcutUrl.setCustomValidity("");
  shortcuts.push({ name, url: url.href });
  saveShortcuts();
  renderShortcuts();
  closeShortcutDialog();
  announcement.textContent = `${name} added.`;
});

shortcutUrl.addEventListener("input", () => shortcutUrl.setCustomValidity(""));

document.addEventListener("keydown", (event) => {
  if (event.key === "/" && document.activeElement !== searchInput && !shortcutDialog.open) {
    event.preventDefault();
    searchInput.focus();
  }
  if (event.key === "Escape" && managing) {
    setManaging(false);
  }
});

updateClock();
window.setInterval(updateClock, 1000);
renderShortcuts();
