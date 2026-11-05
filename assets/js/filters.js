/* Фильтр каталога по размеру и цвету (FR-5): без перезагрузки, состояние в URL.
   При отключённом JS все карточки остаются видимыми. */
export function initFilters() {
  const form = document.querySelector("[data-filters]");
  const grid = document.querySelector("[data-model-grid]");
  if (!form || !grid) return;

  const sizeSelect = form.querySelector("[data-filter-size]");
  const colorSelect = form.querySelector("[data-filter-color]");
  const counter = document.querySelector("[data-filter-count]");
  const empty = document.querySelector("[data-filter-empty]");
  const cards = Array.from(grid.querySelectorAll("[data-model]"));

  const params = new URLSearchParams(window.location.search);
  const initialSize = params.get("size") || "";
  const initialColor = params.get("color") || "";
  if (sizeSelect && initialSize) sizeSelect.value = initialSize;
  if (colorSelect && initialColor) colorSelect.value = initialColor;

  const apply = (updateUrl) => {
    const size = sizeSelect ? sizeSelect.value : "";
    const color = colorSelect ? colorSelect.value : "";
    let visible = 0;

    cards.forEach((card) => {
      const sizes = (card.dataset.sizes || "").split(" ").filter(Boolean);
      const matchesSize = !size || sizes.includes(size);
      const matchesColor = !color || card.dataset.color === color;
      const show = matchesSize && matchesColor;
      card.hidden = !show;
      if (show) visible += 1;
    });

    if (counter) counter.textContent = visible ? `Моделей: ${visible}` : "";
    if (empty) empty.hidden = visible !== 0;

    if (updateUrl) {
      const next = new URLSearchParams(window.location.search);
      if (size) next.set("size", size); else next.delete("size");
      if (color) next.set("color", color); else next.delete("color");
      const query = next.toString();
      window.history.replaceState({}, "", `${window.location.pathname}${query ? `?${query}` : ""}`);
    }
  };

  [sizeSelect, colorSelect].forEach((select) => {
    if (!select) return;
    select.addEventListener("change", () => apply(true));
  });

  apply(false);
}
