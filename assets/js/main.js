import { initConsent, resetConsent, trackGoal } from "./consent.js";
import { initFilters } from "./filters.js";

/* Цели Метрики (FR-14): data-channel → имя цели. */
const CHANNEL_GOALS = {
  telegram: "click_tg",
  vk: "click_vk",
  whatsapp: "click_wa",
  max: "click_max",
  phone: "click_phone",
  wildberries: "click_wb",
};

function initTracking() {
  document.addEventListener("click", (event) => {
    const target = event.target.closest("[data-channel], [data-goal]");
    if (!target) return;

    const params = {};
    if (target.dataset.model) params.model_slug = target.dataset.model;

    const goal = target.dataset.goal || CHANNEL_GOALS[target.dataset.channel];
    if (goal) trackGoal(goal, params);
  });
}

/* Sticky-панель появляется после первого экрана и не перекрывает футер (FR-8). */
function initStickyCta() {
  const bar = document.querySelector("[data-sticky-cta]");
  if (!bar) return;

  const trigger = document.querySelector(".hero") || document.querySelector("main");
  if (!trigger || !("IntersectionObserver" in window)) {
    bar.hidden = false;
    return;
  }

  const observer = new IntersectionObserver(
    (entries) => {
      entries.forEach((entry) => {
        bar.hidden = entry.isIntersecting;
      });
    },
    { rootMargin: "-40% 0px 0px 0px" }
  );

  observer.observe(trigger);
}

function initConsentSettings() {
  document.querySelectorAll("[data-consent-settings]").forEach((button) => {
    button.addEventListener("click", resetConsent);
  });
}

function start() {
  initConsent();
  initFilters();
  initTracking();
  initStickyCta();
  initConsentSettings();
}

if (document.readyState === "loading") {
  document.addEventListener("DOMContentLoaded", start);
} else {
  start();
}
