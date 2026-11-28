# Changelog

Все заметные изменения проекта. Формат — [Keep a Changelog](https://keepachangelog.com/ru/1.1.0/),
версии — [Semantic Versioning](https://semver.org/lang/ru/).

## [Unreleased]

### Added

- **Электронная коммерция Яндекс.Метрики**: счётчик инициализируется с `ecommerce: true`, контейнер `window.dataLayer` объявляется до `init` в `assets/js/consent.js` и в новом `assets/js/ecommerce.js`. Шаблоны отдают данные товара через `data-ec-*` (партиал `layouts/partials/product-data.html`, а также `model-card.html`, `single.html`, `list.html`). Модуль `assets/js/ecommerce.js` отправляет события `impressions` (список моделей), `click` (переход на карточку из списка) и `detail` (просмотр карточки) с `currencyCode: "RUB"`; `add`/`remove`/`purchase` не используются — на сайте нет корзины, заказ оформляется в личном диалоге.

## [0.1.1] — 2026-11-28

### Changed

- **FAQ городских поддоменов**: ответ на вопрос «Можно оплатить при получении?» приведён к одной формулировке — «Да, наложенным платежом.» — во всех 16 городах. Из ответа убраны приписки про онлайн-ссылку и наличные при самовывозе (в Екатеринбурге — тоже): вопрос узкий, лишние варианты оплаты живут на страницах «Доставка и примерка».

### Removed

- **`areaServed` из JSON-LD**: поле убрано у `Organization` и `Place` в `layouts/partials/seo-jsonld.html` — городской контекст остаётся в `address` и `name`/`url` узлов.
- **Мёртвый шаблон `layouts/city-catalog/single.html`**: городской «Каталог» рендерит общий `layouts/_default/list.html` — ни один конфиг или файл контента не задаёт `type: city-catalog` (городские `catalog/index.md` удалены ещё в `35732cb`), поэтому Hugo этот шаблон не выбирал и правки в нём на вывод не влияли. Удалён, чтобы не путать при следующих правках. Проверено пересборкой: HTML всех 16 городских каталогов и лендингов не изменился.

### Fixed

- **Фото моделей в блоке «Модели» на главной городского поддомена**: карточки собирались вручную из `featured` в `data/cities.yaml`, где нет путей к изображениям, поэтому вместо обложки выводился цветной свотч. `layouts/partials/city-home.html` теперь берёт настоящую страницу каталога по `collection`+`slug` (`site.GetPage`) и рендерит её партиалом `model-card.html` — с обложкой, `srcset`/`sizes`, `alt` и всеми полями; изображения идут через `responsive-img.html`/`cdn-url.html` (CDN в проде), ссылки остаются локальными (`relURL`) — пользователь не уходит с хоста города. Если карточка не найдена, остаётся прежний цветной плейсхолдер как фолбэк (комментарий к `featured` в `data/cities.yaml` уточнён). Городская страница «Каталог» настоящие карточки показывала и раньше — её рендерит общий `layouts/_default/list.html`.
- **CTA «Подобрать размер для в Москву» на главной городского поддомена**: заголовок собирался как `printf "Подобрать размер для %s" .name_to`, а `name_to` — это «в Москву», «в Уфу» (винительный падеж для «доставка в …»), поэтому получалось «Подобрать размер для в Москву». В `layouts/partials/city-home.html` заголовок заменён на нейтральное «Подобрать размер для Вас».

### Security

- **Переключатель городов больше не уводит на произвольный URL**: `assets/js/main.js` (`initCitySwitcher`) подставлял `value` выбранного пункта прямо в `window.location.href` — подменённый `<option>` или значение из `cities.json` мог отправить пользователя на чужой домен или на `javascript:`-адрес. Теперь переход выполняется только на `http:`/`https:`-адрес, хост которого входит в список городов из тех же данных (`allowedHosts`), остальные значения игнорируются. Закрывает code scanning alert «DOM text reinterpreted as HTML» (`14c381e`).

## [0.1.0] — 2026-11-28

### Added

- **Общий CDN-хост `cdn.stilgrad.ru`**: медиа каталога и hero (`catalog/`, `photo/`) и `cities.json` генерируются один раз и деплоятся только на CDN; основной сайт и все городские поддомены ссылаются на него абсолютными URL (`layouts/partials/cdn-url.html`, переменная `MEDIA_BASE_URL`). `og:image` на CDN исключён из проверки `scripts/check_og.py`.
- **Одинаковый каталог на всех сайтах**: городские сборки монтируют общий `content/catalog` (Hugo mounts в `scripts/build.sh`); модельные страницы в городах отдают `canonical` на основной домен. Пользователь не уходит с хоста своего города.
- **Выпадающий переключатель городов** в подвале — все 16 городов + «Основной сайт»; список подтягивается из `cities.json` на CDN, с серверным `<noscript>`-фолбэком.
- `scripts/build_cities_json.py` — генерация `cities.json` (список всех городов) для CDN.
- `deploy/nginx.conf` — `server` для `cdn.stilgrad.ru` (CORS, вечный кэш медиа).
- Городские поддомены для локального поиска: 16 городов, канонический хост каждого — «Основной домен» из `alias.stilgrad.md` (`moscow`, `spb`, `nsk`, `ekb`, `kazan`, `krsk`, `nn`, `chel`, `ufa`, `krd`, `samara`, `rostov`, `omsk`, `voronezh`, `perm`, `vlg`), домены по IATA и человекочитаемые — алиасы с 301-редиректами. Данные — `data/cities.yaml`, контент — `city-content/<code>/`, конфиги — `city-config/<code>.toml`.
- Шаблоны городского мини-сайта: лендинг (`partials/city-home.html`), «Доставка и примерка» и «Вопросы» (`layouts/city/single.html`), «Каталог» с подборкой моделей основного домена (рендерит общий `layouts/_default/list.html`; неиспользуемый `layouts/city-catalog/single.html` удалён в [Unreleased]), переключатель городов в подвале.
- JSON-LD городской сборки: `Organization` с `areaServed`, `Place` с адресом самовывоза (Екатеринбург).
- `scripts/build.sh` — мультисборка: основной сайт в `dist/`, города в `dist/cities/<code>/`; список городов берётся из `alias.stilgrad.md` (`scripts/list_domains.py --column main`).
- `scripts/deploy.sh` — мультихостовый деплой: один релиз раскладывается на все виртуальные хосты (`<host>/releases/<RELEASE>`, `www -> releases/<RELEASE>`, prune старых релизов, `touch <host>/reload`); список городов — из `alias.stilgrad.md`.
- `scripts/list_domains.py` — уникальные домены из таблицы `alias.stilgrad.md` с фильтром по колонкам (`iata`, `human`, `main`).
- `scripts/sync_city_domains.py` — сверка `data/cities.yaml` с `alias.stilgrad.md`: коды, алиасы, наличие `city-config/<code>.toml` и `city-content/<code>/_index.md`; шаг CI и задача `task domains:check`.
- `deploy/nginx.conf` — wildcard-хосты `*.stilgrad.ru`, `map $host $city_dir` для root, 301 с алиасов на канонический хост города, catch-all неизвестных поддоменов.
- CI: проверка `data/cities.yaml` (обязательные поля, уникальность кодов и алиасов, наличие конфига и контента), сверка с `alias.stilgrad.md` и наличия городских сборок.
- Архетип `archetypes/city.md`; `docs/SEO.md` — раздел «Локальная стратегия (городские поддомены)».
- Контентная модель «каталог → коллекция → модели»: дочерние секции (коллекции) внутри каталога, с шаблоном, различающим корень каталога и страницу коллекции.
- Коллекция «Осенний кэжуал» с тремя моделями: «Каштан» (МК-ОС001), «Мускатный орех» (МК-ОС002), «Лесной мох» (МК-ОС003). Каждая модель содержит id/артикул, название, фасон/крой, материал, цвет, детали, стоимость, наличие и размеры.
- Архетип коллекции: `archetypes/collection.md`.
- Поля `collection`, `article`, `details` в архетипе модели `archetypes/model.md`.
- Каркас сайта на Hugo: `hugo.toml`, `content/`, `data/`, `layouts/`, `assets/`, `static/`, `deploy/`, `.github/workflows/`.
- Контентные страницы: главная, каталог и карточка модели «Олива», о бренде, доставка и возврат, FAQ, оферта, политика ПД, 404.
- Данные: `data/contacts.yaml`, `data/sizes.yaml`, `data/benefits.yaml`, `data/steps.yaml`, `data/reviews.yaml`.
- Шаблоны: базовый layout, шапка, подвал, хлебные крошки, CTA и кнопки каналов, sticky-панель, cookie-баннер, карточка модели, размерная таблица, аккордеон FAQ, отзывы, JSON-LD (`Organization`, `Product`, `BreadcrumbList`, `FAQPage`).
- Shortcode'ы `note`, `quote`, `figure`, `cta`.
- Дизайн-система в SCSS: токены, база, сетка, компоненты, утилиты; мобильная и десктопная вёрстка.
- JS: загрузка Яндекс.Метрики только после согласия, цели на клики по каналам, фильтр каталога по размеру и цвету с состоянием в URL, sticky-CTA.
- CI: `ci.yml` (сборка, проверка обязательных полей моделей), `deploy.yml` (rsync + переключение симлинка).
- Архетипы контента: `archetypes/default.md`, `archetypes/model.md` — новая модель создаётся командой `hugo new content catalog/<collection>/<slug>/index.md` со всеми полями.
- `.editorconfig` — единые отступы и кодировка.
- `README.md` — структура проекта, локальный запуск, чек-лист заполнения перед запуском.
- `CHANGELOG.md` — этот файл.
- `docs/implementation_checklist.md` — чек-лист выполнения `docs/implementation_plan.md`: статусы по D-1…D-8, 2.2–2.13, FR-1…FR-16, L-01…L-15, перечень дефектов и блокеров запуска.
- Цель Метрики `scroll_75` (глубина прокрутки 75% на главной и карточке модели).
- CI: шаг `yamllint` для `data/` и проверка front matter через PyYAML; шаг `html-validate` по собранному `public/`; шаг Lighthouse CI на `/`, `/catalog/` и карточку модели.
- `.github/workflows/rollback.yml` — откат на предыдущий (или указанный) релиз переключением симлинка `current`.
- `lighthouserc.json` — конфиг Lighthouse CI: три URL, пороги Performance 0.9, Accessibility 0.95, SEO 0.95.
- `data/fabrics.yaml` — три типа ткани (смесовая 50/50, хлопок 97% с эластаном 3%, двухслойный муслин 100% хлопок) для блока «Ткани и качество» и карточки модели.
- Партиал `layouts/partials/fabric-card.html` — карточка типа ткани с составом, ощущениями, уходом и назначением.
- Необязательное поле `subtitle` в `data/fabrics.yaml` и его вывод в карточке ткани: у двухслойного муслина — «Лёгкое дыхание каждый день».
- Коллекции-силуэты в каталоге: `/catalog/classic/` («Классическая рубашка») и `/catalog/long/` («Удлинённая рубашка»).
- Подпись силуэта на карточке модели и в характеристиках карточки; превью двух коллекций в блоке «Модели» на главной.
- Декларация соответствия ТР ТС 017/2011 (ЕАЭС N RU Д-RU.РА10.В.84620/23 от 28.12.2023) в футере и на карточке модели через параметры `declarationNumber` и `declarationDate` в `hugo.toml`.
- Поля `fabric_id` и `length_cm` в архетипе модели; поля `model_type`, `silhouette`, `length_note` в архетипе коллекции.
- Партиал `layouts/partials/og-image.html` — единый резолвер OG-изображения: `params.ogImage` → `og_image` страницы → `images[0]` → `ogImageDefault` → `hero.image`. Ищет файл среди ресурсов страницы, `assets/` и `static/`, отдаёт абсолютный URL, MIME-тип, размеры и alt.
- Валидатор `scripts/check_og.py` (Python 3, без зависимостей): обязательные OG-теги, абсолютность URL, наличие `og:image` в сборке, MIME/расширение, размеры и пропорции, соответствие заявленных размеров фактическим, `twitter:image`.
- Задача `task test:og` и шаг `Open Graph` в `.github/workflows/ci.yml`.
- Параметр `ogImageDefault` в `hugo.toml`: готовое OG-превью 1200×630 (`static/og/og-cover.jpg`) подхватывается автоматически, как только файл появится.
- Поле `og_image` в архетипах `default.md` и `model.md` — точечный оверрайд OG-превью.
- Адаптивные изображения: партиал `layouts/partials/responsive-img.html` — ресайз WebP q78 на лету (ширины 480/800/1200/1600, только до исходного размера), `srcset` + `sizes`, сохранены `width`/`height`; применён к hero главной, cover и дополнительным фото модели, карточкам каталога и `figure`.
- Preload LCP-изображения: партиал `layouts/partials/lcp-image.html` — hero главной и cover модели, `<link rel="preload" as="image" imagesrcset imagesizes fetchpriority="high">` в `<head>`; `imagesrcset` собран поверх экранирования Go через `safeHTML`.
- `Dockerfile` — мультистадийная сборка: стадия `tools` (Hugo extended 0.170.1, Dart Sass, Python + yamllint, Node 22, lychee, Task — всё с проверкой SHA256), `builder` (`scripts/build.sh dist`), `test` (+ Chromium для Lighthouse) и финальный лёгкий `nginx:stable-alpine` только со статикой.
- `compose.yaml` — сервисы `site` (собранный сайт в nginx, `http://localhost:8080`), `test` (проверки `ci.yml` в контейнере) и `tools` (`hugo server` с live-reload).
- `docker/check.sh` — проверки в контейнере по шагам `ci.yml`: сборка, `yamllint`, front matter, обязательные поля моделей, городские данные и сборки, Open Graph, `html-validate`; Lighthouse и lychee — по флагам `CHECK_LIGHTHOUSE` и `CHECK_LINKS`.
- `docker/dev.sh` — запуск `hugo server` в контейнере с подсказкой, если каталог проекта не смонтирован (Colima без общих каталогов, Docker Desktop без file sharing).
- `docker/nginx.conf` и `docker/site-common.conf` — контейнерный вариант боевого `deploy/nginx.conf`: HTTP-only, та же логика `map $host $city_dir`, те же 301 с алиасов городов, схема редиректа берётся из `X-Forwarded-Proto`.
- `Taskfile.yaml` — задачи `docker:build`, `docker:run`, `docker:up`, `docker:test`, `docker:test:full`, `docker:serve`, `docker:shell`.
- `.dockerignore` — в контекст сборки не попадают `.git`, `public/`, `dist/`, `resources/`, `.lighthouseci/`, `.env`.

### Changed

- **CDN-архитектура**: `scripts/build.sh` теперь собирает города с полным каталогом (Hugo mounts) и CDN-набор `dist/cdn/` (`catalog/`, `photo/`, `cities.json`); флаг `--no-shared-links` устарел. `scripts/deploy.sh` публикует медиа только на `cdn.stilgrad.ru` (`CDN_HOST`), а из основного и городских хостов изображения исключает. `deploy.yml` задаёт `MEDIA_BASE_URL` и `CDN_HOST`.
- Переключатель городов в подвале показывает все 16 городов (ранее — только `ready: true`); `ready` влияет только на индексацию.
- `city-content/<code>/catalog/index.md` удалены — каталог общий для всех сайтов.
- `docker/nginx.conf` — обновлён под новую раскладку (медиа относительно локально / CDN в проде).
- `deploy.yml` — публикует релиз на все виртуальные хосты (`stilgrad.ru` и 16 городских поддоменов), а не в один каталог `SITE_HOSTNAME`: у каждого хоста свой `releases/<RELEASE>` и симлинк `www`. Переменная `SITE_HOSTNAME` больше не нужна.
- `scripts/build.sh` — флаг `--no-shared-links` (и `SHARED_ASSETS=0`) собирает городские поддомены самодостаточными, без относительных симлинков на основной сайт: так каждая городская сборка публикуется в отдельный виртуальный хост.
- `scripts/build.sh` больше не дублирует идентичные ассеты в городских сборках: `css/`, `js/`, `photo/`, `favicon.svg` и `.htaccess` кладутся в `dist/cities/<code>/` относительными симлинками на копию основного сайта (`../../css` и т. п.) — на хостинге и в образе nginx файлы хранятся в одном экземпляре; если содержимое разошлось, остаётся собственная копия города.
- Домены городских поддоменов приведены к таблице `alias.stilgrad.md`: каноническими стали «основные» домены (`mow → moscow`, `led → spb`, `ovb → nsk`, `svx → ekb`, `kzn → kazan`), а домены по IATA и человекочитаемые отдают на них 301. Добавлены 11 городов (`krsk`, `nn`, `chel`, `ufa`, `krd`, `samara`, `rostov`, `omsk`, `voronezh`, `perm`, `vlg`) в статусе `ready: false`; каталоги `city-config/` и `city-content/` переименованы под новые коды.
- `baseURL` приведён к боевому домену `https://stilgrad.ru/`; в `params` добавлены `mainBaseURL` и `domain`.
- Деплой публикует `dist/` (мультисборка) вместо `public/`; сборка — через `scripts/build.sh`.
- `layouts/index.html`, `header.html`, `footer.html`, `seo-jsonld.html`, `baseof.html` учитывают городской контекст (`site.Params.cityCode`).
- Каталог: `color_name` и `color_hex`, `description`, `seo.description`, `alt` и `details` моделей приведены в соответствие с артикулами и тканями. Названия цветов уникальны и взяты из характеристик (латте, холодный белый, бирюзовый, малахит, глубокий чёрный, голубой лёд, молочный), hex соответствуют названиям; `details` описывают свойства ткани из `data/fabrics.yaml` по `fabric_id`, у «Малахита» блок `details` добавлен.
- Структура каталога: сезонная коллекция «Осенний кэжуал» расформирована (тестовые данные), модели распределены между коллекциями `classic` и `long`. URL моделей изменились; сайт до запуска закрыт от индексации, редиректы не требуются.
- `content/catalog/_index.md`, `content/_index.md`, `README.md` — описания и структура обновлены под две коллекции и блок тканей.
- `layouts/index.html` — блок «Модели» показывает превью коллекций, блок «Ткани и качество» выводит карточки из `data/fabrics.yaml`.
- `layouts/_default/single.html`, `layouts/_default/list.html`, `layouts/partials/model-card.html`, `layouts/partials/footer.html` — силуэт, длина и декларация.
- Проценты в составе тканей приведены к единому виду без пробела: `97%`, `3%`, `100%`.
- Состав смесовой ткани указан без процентов: «хлопок, полиэстер, эластан».
- Тексты карточки муслина обновлены: «ощущения», уход и назначение переписаны под «лёгкое дыхание каждый день».
- `lighthouserc.json` — тестовая карточка переехала на `/catalog/classic/chestnut/`.
- `layouts/_default/list.html` — различает корень каталога (список коллекций) и страницу коллекции (модели с фильтрами). На корне каталога выводятся отдельные модели и блоки коллекций; на странице коллекции — прежний фильтр по размеру и цвету.
- `content/catalog/_index.md` — описание и интро обновлены для новой контентной модели.
- `README.md` — структура проекта и инструкция «Как добавить модель» обновлены для иерархии каталог → коллекция → модели.
- `docs/tz.md` переформатирован: единая нумерация разделов, таблицы для палитры, шрифтов, контактов и реквизитов, согласованные кавычки и тире. Содержание сохранено, расхождения по размерам вынесены в §6 и остаются открытым вопросом P0-4.
- `implementation_plan.md` перенесён в `docs/implementation_plan.md`; ссылки на строки ТЗ заменены ссылками на разделы (§1–§5), обновлено число строк аудируемого документа (196).
- Фильтр каталога размечен без `<form>`: `div role="group"` вместо формы — приведено к FR-16 «на сайте нет форм».
- `deploy.yml`: секреты переименованы в `SSH_HOST`, `SSH_USER`, `SSH_KEY`, `SSH_KNOWN_HOSTS` (как в п. 2.10), добавлен шаг записи `known_hosts`, хранение 5 последних релизов (`KEEP_RELEASES`) и отдельный шаг перезагрузки nginx.
- `Taskfile.yaml`: задача `test:html` теперь зависит от `build`, чтобы lychee проверял свежую сборку.
- `.htmlvalidate.json`: включён набор правил `html-validate:recommended`, отключены правила про inline-стили и пустые элементы.
- `data/sizes.yaml` переписан по реальной сетке владелицы (`sizes.png`): размеры 50–72, полуобхват груди/талии/бёдер с вилкой ±1 см для 50–60 и ±2 см для 62-го и больше, длина по спинке 77/79/81 см. Строка 72 расчётная — в исходной сетке она заканчивается на 70-м, шаг 2 см сохранён.
- `intl` в `data/sizes.yaml` исправлен: одна международная ступень на каждый размер (50 → XL, 52 → XXL, 54 → 3XL … 70 → 11XL, 72 → 12XL) вместо повторяющихся XL/XXL/3XL.
- `layouts/partials/size-table.html` — заголовки приведены к данным: группа «Полуобхват» (грудь / талия / бёдра); подпись таблицы на главной и карточке — «Мерки изделия в сантиметрах».
- `content/delivery/index.md` — раздел «Доставка и возврат» переписан по тексту владелицы: убран блок «Оплата», стоимость доставки описана как индивидуальный расчёт по тарифам СДЭК, возврат и обмен оформлены пошагово (7 дней, условия, обратная доставка, брак, возврат денег).
- `deploy.yml` стал самостоятельным workflow: запускается по `workflow_run` после успешного прогона `ci` на `main` (и вручную через `workflow_dispatch`). Job `deploy` удалён из `ci.yml`, `secrets: inherit` больше не нужен.
- `ci.yml` остался только проверкой: re-run сборки на `main` больше не запускает деплой повторно, а PR не показывают пропущенную job `Deploy`.
- Контактный e-mail заменён на `stilgrad@gmail.com`: `data/contacts.yaml` (подпись и `mailto:`-ссылка), оферта (`content/offer/index.md`, реквизиты продавца) и политика конфиденциальности (`content/privacy/index.md`, контакт оператора).
- Политика ПД приведена к утверждённой редакции от 24.11.2026: бренд «Маргарита Чистова», домен `stilgrad.ru`, реквизиты ИП, цели и правовые основания обработки, cookie и «Яндекс.Метрика», сроки хранения, права посетителя и контакты для обращений; статус черновика снят.
- Боевой домен `stilgrad.ru` прописан в `hugo.toml` (`baseURL`), `deploy/nginx.conf`, `.lycheeignore` и `README.md`.
- Lighthouse CI ускорен: вместо обхода всех страниц сборки проверяются четыре URL — главная, `/catalog/` и по одной карточке из каждой коллекции. Полный обход доступен через `LHCI_ALL_PAGES=1 npx @lhci/cli autorun`. Аудиты `is-on-https` и `redirects-http` исключены из прогона (`collect.settings.skipAudits`) и отключены в `assert` (`"off"`): в CI сайт открывается по `http://localhost`, поэтому проверки HTTPS заведомо не проходили.
- `.htmlvalidate.json`: правило `valid-id` переведено в режим `relaxed`. Id заголовков юридических страниц (`1-термины-и-определения`, `2-статус-продавца` и т. п.) генерирует Hugo из нумерованных заголовков (`autoHeadingIDType = "github"`); по HTML5 они валидны, но не проходили строгую проверку «id должен начинаться с буквы». Тексты оферты, политики и доставки не переписывались.
- `ci.yml`: шаг `HTML-validate` стал блокирующим — `continue-on-error` снят, прогон по собранному `public/` даёт 0 ошибок (п. 2.10).
- `Taskfile.yaml`: новая задача `test:validate` — html-validate по свежей сборке `public/`.
- `html-validate` обновлён 9.7.1 → 11.21.1 в `ci.yml` и `Taskfile.yaml`; версия закреплена точно. Причина — `npm warn deprecated glob@10.5.0`: линтер версии 9 тянул `glob@^10`, в 11.x этой зависимости нет, предупреждение исчезло. В `recommended` за 10–11-ю мажорные версии добавились три правила — `autocomplete-password`, `valid-for`, `presentation-role-style`; на разметке сайта (17 страниц) ни одно не срабатывает: форм и полей пароля нет, `<label>` только оборачивает контрол (без `for`), `role="presentation"` не используется.
- `ci.yml`: шаг `HTML-validate` собирает список файлов через `find` и падает, если в `public/` нет HTML (раньше пустой глоб давал молчаливый зелёный результат), и печатает число проверенных страниц. Блок `Node.js` (`actions/setup-node@v7.1.0`) ставит Node 24 — `html-validate@11` требует Node ^22.22 || >=24.8. Вывод npm при установке пакета приглушён (`npm_config_loglevel: error`), ошибки npm остаются в логе.
- Проверка ссылок вынесена из `ci.yml` в ручной workflow `links.yml`: lychee проверяет внешние адреса (контакты, маркетплейсы, городские поддомены `*.stilgrad.ru`), которые отвечают только после деплоя, поэтому на push/PR она давала ложные падения. Запуск — Actions → Links → Run workflow (`workflow_dispatch`) или `repository_dispatch`, плюс ночной прогон по расписанию; результат уходит в issue, сборка не блокируется.

### Removed

- Самовывоз: доставка — только СДЭК. Из `data/cities.yaml` (Екатеринбург), контента Екатеринбурга, страницы доставки и документации убраны адрес «Екатеринбург, Сахарова 29/4» и упоминания самовывоза.

### Fixed

- CTA дублировался внизу текстовых страниц (`/about/`, `/faq/`, `/delivery/`): `layouts/_default/single.html` добавлял блок «Написать мне» после CTA, уже вставленного в контент через shortcode. Автоматический CTA оставлен только в каталоге и на главной; у CTA-шорткода внутри `.prose` появился отступ сверху (`margin-top`), чтобы блок не слипался с предыдущим текстом.
- Фото первого экрана на главной не выводилось: картинка лежала в корневой папке `photo/`, которая не входит в пайплайн Hugo, а шаблон искал её только среди ресурсов страницы (`Resources.GetMatch`), которых у branch bundle главной нет. Файл перенесён в `assets/photo/hero.webp`, `layouts/index.html` ищет изображение среди ресурсов страницы, затем среди глобальных ассетов и подставляет `width`/`height` из файла.
- `.hero__image` ограничена габаритами плейсхолдера (`aspect-ratio: 4 / 5`, `max-height: 62vh`, `object-fit: cover`), чтобы вертикальное фото не растягивало первый экран.
- `_components.scss`: у блока `.filters` не было закрывающей скобки — футер, заметки, страница 404 и все медиазапросы (480/768/1024) компилировались вложенными в `.filters` и не применялись. Блок закрыт, лишние объявления перенесены внутрь него.
- `head.html`: в условии `eq .Section " catalog"` был лишний пробел — `og:type` для карточек моделей всегда оставался `website` вместо `product`.
- Sticky-панель: атрибут `hidden` перебивался правилом `display: flex`, поэтому панель была видна всегда. Добавлено глобальное `[hidden] { display: none !important }`, JS ставит класс `has-sticky-cta`, который резервирует 76 px снизу — панель больше не перекрывает футер.
- `deploy/nginx.conf`: добавлен `error_page 404 /404.html` — без него кастомная страница 404 не отдавалась.
- Хлебные крошки: глобальное правило `li + li { margin-top: var(--space-2) }` из `_base.scss` сдвигало каждый следующий пункт вниз, поэтому «Главная», «Каталог» и «Рубашка «Олива»» стояли не в одну линию. В `.breadcrumbs__list` добавлены `align-items: baseline` и сброс `margin-top` у пунктов (как в `.site-footer__list`).
- `og:image` отсутствовал на главной и текстовых страницах: `head.html` смотрел только на пустой `params.ogImage` и на `images[0]` карточек каталога. Теперь `og:image` формируется партиалом `og-image.html` из `hero.image` главной (`content/_index.md`), обложек моделей и `ogImageDefault`; добавлены `og:image:type`, `width`, `height`, `alt`, а также `twitter:image` и `twitter:image:alt`.

- Ссылки `tel:` не проходили html-validate (правило `tel-non-breaking`, 166 ошибок по всем страницам): номер в футере рвался переносом строки на узких экранах. Пробелы и дефисы в тексте номера теперь неразрывные (`&nbsp;`, `&#8209;`). Форматирование вынесено в партиал `layouts/partials/phone.html` и используется в `footer.html` («Связаться» и «Реквизиты») и `contact-buttons.html`, включая fallback без каналов; в `content/delivery/index.md` сущности прописаны прямо в тексте ссылки. Итог прогона — 0 ошибок, шаг `HTML-validate` в `ci.yml` стал блокирующим.
- `links.yml`: не хватало шага `dart sass`, поэтому ежедневная проверка ссылок падала на сборке (`no Dart Sass binary found in $PATH`). Шаг добавлен, `Links` снова собирает сайт.
- Lighthouse CI падал с `Lighthouse was unable to reliably load the page ... (Status code: 404)`: в конфиге был жёстко прописан URL карточки `/catalog/classic/chestnut/`, которой больше нет после перераспределения моделей по коллекциям. Конфиг переехал из `lighthouserc.json` в `.lighthouserc.cjs` и собирает список URL из готового `public/`: главная, `/catalog/` и по одной карточке из каждой коллекции (`/catalog/<collection>/<model>/`), поэтому новые и переименованные модели проверяются без правки конфига.
- CI падал на шаге «Проверка городских данных и сборок» с `moscow: нет алиаса msk (есть в таблице)`: в `alias.stilgrad.md` у Москвы человекочитаемый домен `msk.stilgrad.ru`, а в `data/cities.yaml` алиас не был описан. `msk` добавлен в `aliases` Москвы (`mow`, `msk`) и в 301-редиректы nginx (`deploy/nginx.conf`, `docker/nginx.conf`); таблицы алиасов в `README.md` и `docs/SEO.md` синхронизированы.
- Lighthouse CI проверял все 16 городских лендингов из `public/cities/`, из-за чего прогон заметно удлинялся. `cityUrls()` в `.lighthouserc.cjs` ограничена списком `CITY_URL_CODES` — `moscow` и `ekb`; остальные города по-прежнему собираются и проверяются в CI, но в Lighthouse не входят.
- Деплой «зависал» на первом хосте: лог обрывался после предупреждения ssh `connection is not using a post-quantum key exchange algorithm`, шаг молча ждал. `scripts/deploy.sh` теперь работает только в неинтерактивном режиме (`BatchMode=yes`, `StrictHostKeyChecking=yes`, `ConnectTimeout=20`, `ServerAliveInterval=15`/`ServerAliveCountMax=4`), глушит это предупреждение (`-o WarnWeakCrypto=no` — с проверкой поддержки через `ssh -G`, чтобы не сломать старые клиенты), передаёт те же опции в rsync (`-e`), обрывает залипшую передачу по `--timeout` (`RSYNC_TIMEOUT`, по умолчанию 600 с) и печатает видимые маркеры: проверка доступа до раскладки, «файлы загружены, переключаю www» после rsync и адрес хоста в сообщении об ошибке. `--stats` показывает объём передачи по каждому хосту.
- `scripts/deploy.sh`: вызов без exclude-шаблонов (CDN-хост) падал в bash 3.2 (macOS) с `excludes[@]: unbound variable` под `set -u` — пустой массив больше не разыменовывается.

### Docs

- Раздел 2.5 плана приведён в соответствие с фактической структурой шаблонов (добавлены `contact-buttons`, `breadcrumbs`, `sticky-cta`, `reviews`, `robots.txt`).
- `README.md`: в структуре проекта появилась папка `assets/photo/`.
- `README.md`: архетип модели указан как `model.md` (было `catalog`), перечислены все workflow (`build`, `deploy`, `links`, `rollback`) и конфиги (`lighthouserc.json`, `.htmlvalidate.json`); добавлена ссылка на чек-лист выполнения плана.
- `README.md`: обновлён блок «Примечания» — статус CI, Lighthouse, html-validate и порядок включения деплоя.
- `docs/implementation_plan.md`: в шапку добавлена ссылка на чек-лист выполнения со свежими статусами.
- `docs/implementation_plan.md` обновлён до версии 2.1: типы ткани, две коллекции-силуэта, декларация, правило типографики, критерии приёмки 13–14.
- `docs/implementation_checklist.md` обновлён до версии 1.1: новые URL, `data/fabrics.yaml`, статус L-11.
- `docs/tz.md` — в требования к галерее добавлены две коллекции-силуэта.
- `README.md`: раздел «OG-превью для соцсетей», команда `python3 scripts/check_og.py public`, `scripts/` в структуре проекта и строка про OG-превью 1200×630 в списке задач до запуска.
- `docs/implementation_checklist.md`: обновлены FR-12, «OG + Twitter Card» и B-10 — `og:image` выводится на всех страницах, механизм поддержки файла 1200×630 готов.
- `README.md`: в описании `scripts/deploy.sh` — неинтерактивный ssh (BatchMode и таймауты), `RSYNC_TIMEOUT` и подписанные ошибки по хостам.

### Security

- `noindex = true` по умолчанию: сайт закрыт от индексации до готовности юридических страниц и реквизитов.
- Метрика и Вебвизор не загружаются до согласия на cookie; отзывы без `consent: true` не публикуются.
- Деплой проверяет SSH-хост по `known_hosts` (секрет `SSH_KNOWN_HOSTS`), ключ используется только для выкладки.

## [0.0.1] — 2026-11-04

### Added

- Исходное техническое задание `docs/tz.md`.
- Ключевые фразы `docs/SEO.md`.
- План разработки (аудит ТЗ, требования, юридический блок).
