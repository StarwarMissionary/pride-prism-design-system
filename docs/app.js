const root = document.documentElement;
const toast = document.querySelector("#toast");
const intensity = document.querySelector("#intensity");
const intensityOutput = document.querySelector("#intensity-output");
const celebrate = document.querySelector("#celebrate");

document.querySelector("#year").textContent = new Date().getFullYear();

let toastTimer;
function showToast(message) {
  toast.textContent = message;
  toast.classList.add("show");
  clearTimeout(toastTimer);
  toastTimer = setTimeout(() => toast.classList.remove("show"), 1800);
}

async function copyText(value) {
  try {
    await navigator.clipboard.writeText(value);
    showToast(`Copied ${value}`);
  } catch {
    showToast("Copy unavailable in this browser");
  }
}

document.querySelectorAll("[data-copy]").forEach((button) => {
  button.addEventListener("click", () => copyText(button.dataset.copy));
});

document.querySelectorAll("[data-copy-target]").forEach((button) => {
  button.addEventListener("click", () => {
    const target = document.getElementById(button.dataset.copyTarget);
    if (target) copyText(target.innerText);
  });
});

intensity.addEventListener("input", () => {
  const value = Number(intensity.value);
  intensityOutput.value = `${value}%`;
  root.style.setProperty("--demo-intensity", String(value / 100));
});

celebrate.addEventListener("click", () => {
  if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) {
    showToast("Reduced motion is enabled");
    return;
  }
  document.body.classList.remove("is-celebrating");
  requestAnimationFrame(() => document.body.classList.add("is-celebrating"));
  setTimeout(() => document.body.classList.remove("is-celebrating"), 3800);
});
