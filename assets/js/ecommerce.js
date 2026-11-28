/* Электронная коммерция Яндекс.Метрики (FR-14, п. 2.9).
   Контейнер данных — window.dataLayer (стандарт, совместим с ecommerce: true).
   События пушатся всегда; Метрика читает dataLayer только после инициализации
   счётчика (после согласия на cookie). Данные товара берутся из data-ec-*
   атрибутов, которые выставляют шаблоны. */

const CURRENCY = "RUB";

function ensureDataLayer() {
  window.dataLayer = window.dataLayer || [];
}

/* Читает данные товара из data-атрибутов элемента карточки. */
function productFrom(el) {
  const data = el && el.dataset;
  if (!data) return null;

  const id = data.ecId || "";
  const name = data.ecName || "";
  if (!id && !name) return null;

  return {
    id,
    name,
    brand: data.ecBrand || "",
    category: data.ecCategory || "",
    variant: data.ecVariant || "",
    price: Number(data.ecPrice) || 0,
  };
}

function pushEcommerce(action, products) {
  if (!products || !products.length) return;
  ensureDataLayer();
  const ecommerce = { currencyCode: CURRENCY };
  ecommerce[action] = { products };
  window.dataLayer.push({ ecommerce });
}

/* Просмотр списка товаров: все карточки страницы одним событием impressions. */
function initEcommerceImpressions() {
  const items = document.querySelectorAll("[data-ec-position]");
  if (!items.length) return;

  const products = [];
  items.forEach((item, index) => {
    const card = item.querySelector("[data-ec-id]") || item;
    const product = productFrom(card);
    if (!product) return;
    product.list = item.dataset.ecList || "";
    product.position = Number(item.dataset.ecPosition) || index + 1;
    products.push(product);
  });

  pushEcommerce("impressions", products);
}

/* Просмотр карточки товара. */
function initEcommerceDetail() {
  const el = document.querySelector("[data-ec-detail]");
  if (!el) return;
  const product = productFrom(el);
  if (product) pushEcommerce("detail", [product]);
}

/* Клик по товару из списка (переход на карточку). */
function initEcommerceClicks() {
  document.addEventListener("click", (event) => {
    const link = event.target.closest("a[href]");
    if (!link) return;

    const card = link.closest("[data-ec-id]");
    if (!card) return;

    const holder = card.closest("[data-ec-position]");
    if (!holder) return;

    const product = productFrom(card);
    if (!product) return;
    product.list = holder.dataset.ecList || "";
    product.position = Number(holder.dataset.ecPosition) || 1;
    pushEcommerce("click", [product]);
  });
}

export function initEcommerce() {
  ensureDataLayer();
  initEcommerceImpressions();
  initEcommerceDetail();
  initEcommerceClicks();
}
