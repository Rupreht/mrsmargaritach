/* Счётчик Яндекс.Метрики: грузится только после согласия (FR-10, п. 2.9). */
const CONSENT_KEY = "mm_consent_v1";
const DAY = 24 * 60 * 60 * 1000;

function readConsent() {
  try {
    const raw = localStorage.getItem(CONSENT_KEY);
    if (!raw) return null;
    const data = JSON.parse(raw);
    if (!data || typeof data.analytics !== "boolean") return null;
    if (data.expires && Date.now() > data.expires) return null;
    return data;
  } catch (error) {
    return null;
  }
}

function saveConsent(analytics) {
  const data = { analytics, date: new Date().toISOString(), expires: Date.now() + 365 * DAY };
  try {
    localStorage.setItem(CONSENT_KEY, JSON.stringify(data));
  } catch (error) {
    /* приватный режим: согласие не сохраняем, аналитику не включаем */
  }
  return data;
}

function loadMetrika(id) {
  if (!id || window.__mmMetrikaLoaded) return;
  window.__mmMetrikaLoaded = true;

  window.ym = window.ym || function () {
    (window.ym.a = window.ym.a || []).push(arguments);
  };
  window.ym.l = Date.now();

  const script = document.createElement("script");
  script.async = true;
  script.src = "https://mc.yandex.ru/metrika/tag.js";
  document.head.appendChild(script);

  window.ym(Number(id), "init", {
    clickmap: true,
    trackLinks: true,
    accurateTrackBounce: true,
    webvisor: true,
  });
}

export function trackGoal(goal, params) {
  if (typeof window.ym !== "function") return;
  const id = document.body.dataset.metrikaId;
  if (!id) return;
  window.ym(Number(id), "reachGoal", goal, params || {});
}

export function initConsent() {
  const banner = document.querySelector("[data-consent-banner]");
  const metrikaId = banner?.dataset.metrikaId || "";
  const stored = readConsent();

  if (stored) {
    if (stored.analytics) loadMetrika(metrikaId);
    return;
  }

  if (!banner) return;
  banner.hidden = false;
  document.body.classList.add("has-cookie-banner");

  banner.addEventListener("click", (event) => {
    const button = event.target.closest("[data-consent]");
    if (!button) return;
    const analytics = button.dataset.consent === "accept";
    saveConsent(analytics);
    if (analytics) loadMetrika(metrikaId);
    banner.hidden = true;
    document.body.classList.remove("has-cookie-banner");
  });
}

export function resetConsent() {
  try {
    localStorage.removeItem(CONSENT_KEY);
  } catch (error) {
    /* ничего не делаем: баннер покажется при следующей загрузке */
  }
  window.location.reload();
}
