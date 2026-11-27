# Сайт бренда «Маргарита Чистова»

Статический мини-сайт женских рубашек больших размеров (50–72). Задача сайта — не продавать онлайн, а показать вещи и перевести посетительницу в личный диалог с автором бренда.

- Концепция, аудитория и тексты: [`docs/tz.md`](docs/tz.md)
- План разработки, требования, юридический блок: [`docs/implementation_plan.md`](docs/implementation_plan.md)
- Ключевые фразы: [`docs/SEO.md`](docs/SEO.md)
- Чек-лист выполнения плана: [`docs/implementation_checklist.md`](docs/implementation_checklist.md)
- История изменений: [`CHANGELOG.md`](CHANGELOG.md)

## Стек

| Слой | Решение |
| --- | --- |
| Генератор | Hugo extended ≥ 0.140 (проект собран на 0.170.1) |
| Контент | Markdown + YAML в `content/` и `data/` |
| Стили | SCSS через Hugo Pipes (`css.Sass`), один файл, `brew install dart-sass` |
| Скрипты | ванильный ES2020, один бандл (`js.Build`), без фреймворков |
| Сборка/деплой | GitHub Actions, rsync + nginx |

Node.js не требуется ни для сборки, ни для работы сайта. Корзины, форм и сбора персональных данных на сайте нет.

## Локальный запуск

```bash
hugo version                 # нужен extended ≥ 0.140
hugo server                  # http://localhost:1313
bash scripts/build.sh dist   # основной сайт + городские поддомены в dist/
hugo --minify --gc --environment production
python3 scripts/check_og.py public   # проверка OG-разметки после сборки

# городской мини-сайт локально
hugo server --config hugo.toml,city-config/moscow.toml --contentDir city-content/moscow
```

Собранный сайт появляется в `public/` (каталог в `.gitignore`).

## Docker

Всё, что нужно для локальной сборки и проверок, есть в контейнерах — Hugo, Dart Sass,
Python с `yamllint`, Node, lychee и Task ставить на машину не требуется.
Сборка мультистадийная: тяжёлый builder отбрасывается, а на выходе — лёгкий образ
`nginx:stable-alpine` только со статикой.

```bash
# собранный сайт в nginx: http://localhost:8080
docker compose up --build

# то же без compose
docker build -t mrsmargaritach:local .
docker run --rm -p 8080:80 mrsmargaritach:local

# проверки как в ci.yml: сборка, YAML/front matter, поля моделей, города,
# Open Graph, html-validate (собирается из контекста — смонтированные
# каталоги не нужны, свежий код подхватывает --build)
docker compose run --rm --build test

# проверки + Lighthouse и lychee
docker compose run --rm --build -e CHECK_LIGHTHOUSE=1 -e CHECK_LINKS=1 test

# hugo server с live-reload: http://localhost:1313
# (каталог проекта монтируется в /site)
docker compose --profile tools up

# shell с тулчейном (hugo, sass, node, lychee, task)
docker compose run --rm --profile tools --entrypoint bash tools
```

Через Taskfile:

```bash
task docker:up       # сайт в nginx
task docker:test     # проверки
task docker:serve    # hugo server
task docker:shell    # shell с тулчейном
```

Стадии (`Dockerfile`):

| Стадия | Что внутри | Назначение |
| --- | --- | --- |
| `tools` | Hugo extended 0.170.1, Dart Sass, Python + yamllint, Node 22, lychee, Task | `hugo server`, ручные проверки, `task` |
| `builder` | `tools` + исходники → `bash scripts/build.sh dist` | сборка основного сайта и городов |
| `test` | `builder` + Chromium | прогон проверок `ci.yml`, Lighthouse |
| `nginx` (по умолчанию) | `nginx:stable-alpine` + `dist/` + `docker/nginx.conf` | финальный образ |

Что учесть:

- `HUGO_BASE_URL` — `baseURL` сборки, по умолчанию `http://localhost:8080/`,
  чтобы ссылки работали в локальном превью. Для образа «как в проде»:
  `HUGO_BASE_URL=https://stilgrad.ru/ docker compose build`.
- `docker/nginx.conf` — контейнерный вариант боевого `deploy/nginx.conf`: только HTTP
  (TLS терминируется снаружи), та же логика хостов `map $host $city_dir`, те же
  301 с алиасов городов. Город проверяется заголовком `Host`:
  `curl -H "Host: ekb.stilgrad.ru" http://localhost:8080/`.
- `SITE_PORT` и `HUGO_PORT` переопределяют порты `8080` и `1313`.
- Образ собирается под архитектуру хоста (`TARGETARCH`): бинарники Hugo, Dart Sass,
  Node, lychee и Task скачиваются под `amd64` или `arm64`. Мультиарх-сборка:
  `docker buildx build --platform linux/amd64,linux/arm64 -t mrsmargaritach:local .`.
- `test` собирается из контекста (`COPY . .`), поэтому проверки не зависят от
  монтирования каталогов хоста: `docker compose run --rm --build test`.
  `SKIP_BUILD=1` отключает пересборку внутри образа.
- `tools` (live-reload) требует смонтированного каталога проекта. Если Docker
  Desktop не отдаёт каталог (File sharing) или Colima запущена без монтирования
  (`colima start --mount-type virtiofs`), скрипт `dev` в контейнере скажет об
  этом прямо — вместо пустого сайта.

## Структура проекта

```text
hugo.toml                      конфигурация, меню, реквизиты, параметры
content/
  _index.md                    главная: тексты блоков
  about/index.md               о бренде
  catalog/_index.md            каталог (две коллекции-силуэта)
  catalog/classic/             коллекция «Классическая рубашка»
    _index.md                  страница коллекции
    olive/index.md             карточка модели «Олива»
    chestnut/index.md          карточка модели «Каштан»
  catalog/long/                коллекция «Удлинённая рубашка»
    _index.md                  страница коллекции
    nutmeg/index.md            карточка модели «Мускатный орех»
    forest-moss/index.md       карточка модели «Лесной мох»
  delivery/index.md            доставка и возврат
  faq/index.md                 вопросы и ответы (front matter `faq`)
  offer/index.md               публичная оферта (черновик)
  privacy/index.md             политика ПД (черновик)
data/
  contacts.yaml                каналы связи и ссылки
  sizes.yaml                   размерная сетка
  fabrics.yaml                 три типа ткани для блока «Ткани и качество»
  benefits.yaml                преимущества на главной
  steps.yaml                   «как это работает»
  reviews.yaml                 отзывы (только consent: true)
layouts/
  _default/{baseof,single,list}.html
  index.html                   14 блоков главной
  404.html
  robots.txt
  partials/                    head, header, footer, breadcrumbs, cta,
                               contact-buttons, sticky-cta, cookie-banner,
                               model-card, size-table, faq, reviews, seo-jsonld
  shortcodes/                  note, quote, figure, cta
assets/
  scss/                        токены, база, сетка, компоненты, утилиты
  js/                          main, consent (Метрика после согласия), filters
  photo/                       фото для страниц вне бандлов: photo/hero.webp на главной
archetypes/                    шаблоны новых страниц: default, model, collection
static/favicon.svg
deploy/nginx.conf              конфиг хостинга
Dockerfile                     мультистадийная сборка: tools → builder → test → nginx
compose.yaml                   compose: site (nginx), test (проверки), tools (hugo server)
docker/nginx.conf              контейнерный конфиг nginx (HTTP-only, те же map/301)
docker/site-common.conf        общие настройки серверов: заголовки, gzip, кэш, 404
docker/check.sh                проверки в контейнере по шагам ci.yml
.lighthouserc.cjs              конфиг Lighthouse CI (главная, каталог, карточки)
.htmlvalidate.json             правила html-validate
scripts/check_og.py            валидатор OG-разметки в собранном public/
scripts/build.sh               мультисборка: основной сайт + городские поддомены
scripts/deploy.sh              раскладка релиза по виртуальным хостам (www-симлинки)
scripts/list_domains.py        домены из alias.stilgrad.md (--column main — канонические)
scripts/sync_city_domains.py   сверка data/cities.yaml с alias.stilgrad.md
alias.stilgrad.md              таблица городов и доменов — источник истины
city-config/<code>.toml        конфиг городской сборки: baseURL + cityCode
city-content/<code>/           городской мини-сайт: лендинг, доставка, каталог, вопросы
data/cities.yaml               факты по городам: ПВЗ, сроки доставки, подборки моделей
.github/workflows/             ci.yml, deploy.yml, links.yml
.editorconfig                  отступы и кодировка для редакторов
```

## Как добавить модель

1. Создать коллекцию (если новая): `hugo new content --kind collection catalog/<collection-slug>/_index.md` (подставит поля коллекции из `archetypes/collection.md`).
2. Создать карточку из архетипа: `hugo new content --kind model catalog/<collection-slug>/<model-slug>/index.md` (подставит все поля модели) или скопировать одну из существующих моделей в коллекции.
3. Положить изображения рядом (`cover.webp` первым кадром, затем `01.webp`, `02.webp`).
4. Заполнить `title`, `article`, `color_name`, `color_hex`, `price`, `sizes`, `fabric`, `fabric_id` (для трёх базовых тканей из `data/fabrics.yaml`), `length_cm`, `care`, `details`, `images[].alt`. Проценты в составе — слитно: `97% хлопок, 3% эластан`.
5. Запустить `hugo server` — модель появится на главной и в каталоге без правки шаблонов.

Пока изображений нет, карточка показывает цветной плейсхолдер — вёрстка не ломается.

## Городские поддомены

Шестнадцать городов живут на отдельных поддоменах — так Яндекс.Вебмастер
позволяет привязать регион к хосту. Всё собирается из одного репозитория, а
домены берутся из `alias.stilgrad.md`: канонический хост города — колонка
«Основной домен», домены по IATA и человекочитаемые отдают на него 301.

| Город | Канонический хост | Алиасы (301) |
| --- | --- | --- |
| Москва | `moscow.stilgrad.ru` | `mow`, `msk` |
| Санкт-Петербург | `spb.stilgrad.ru` | `led`, `saint-petersburg` |
| Новосибирск | `nsk.stilgrad.ru` | `ovb`, `novosibirsk` |
| Екатеринбург | `ekb.stilgrad.ru` | `svx`, `ekaterinburg` |
| Казань | `kazan.stilgrad.ru` | `kzn` |
| Красноярск | `krsk.stilgrad.ru` | `kja`, `krasnoyarsk` |
| Нижний Новгород | `nn.stilgrad.ru` | `goj`, `nizhny-novgorod` |
| Челябинск | `chel.stilgrad.ru` | `cek`, `chelyabinsk` |
| Уфа | `ufa.stilgrad.ru` | — |
| Краснодар | `krd.stilgrad.ru` | `krr`, `krasnodar` |
| Самара | `samara.stilgrad.ru` | `kuf` |
| Ростов-на-Дону | `rostov.stilgrad.ru` | `rov`, `rostov-na-donu` |
| Омск | `omsk.stilgrad.ru` | `oms` |
| Воронеж | `voronezh.stilgrad.ru` | `voz` |
| Пермь | `perm.stilgrad.ru` | `pee` |
| Волгоград | `vlg.stilgrad.ru` | `vog`, `volgograd` |

Как устроено:

- `alias.stilgrad.md` — источник доменов: `code` = «Основной домен», `aliases` = «Домен по IATA» + «Человекочитаемый домен».
- `data/cities.yaml` — единственный источник фактов: сроки, ПВЗ, подборки моделей, `ready`.
- `city-content/<code>/` — контент городского мини-сайта: лендинг, доставка и примерка, вопросы (каталог общий, см. ниже).
- `city-config/<code>.toml` — `baseURL` и `params.cityCode` городской сборки.
- `scripts/build.sh` — мультисборка: `dist/` (основной сайт), `dist/cities/<code>/` (города с **полным каталогом** — одинаковая структура на всех сайтах) и `dist/cdn/` (медиа `catalog/`, `photo/` и `cities.json`). Медиа генерируется один раз и деплоится только на CDN; задаётся `MEDIA_BASE_URL` (по умолчанию — относительные ссылки для локальной разработки).
- `scripts/deploy.sh` — раскладывает один релиз по всем виртуальным хостам: основной сайт (`stilgrad.ru`), города (`<code>.stilgrad.ru`) и CDN (`cdn.stilgrad.ru` — медиа + `cities.json`). Из основного и городских хостов изображения исключаются (они на CDN). `<host>/releases/<RELEASE>/`, атомарный симлинк `www -> releases/<RELEASE>`, prune старых релизов и `touch <host>/reload`. ssh вызывается только неинтерактивно (`BatchMode`, `ConnectTimeout`, `ServerAlive*`), поэтому шаг не висит на приглашениях пароля/подтверждения ключа, а предупреждение о пост-квантовом KEX не засоряет лог; `RSYNC_TIMEOUT` (по умолчанию 600 с) обрывает залипшую передачу, `--stats` показывает объём по каждому хосту, ошибки подписаны именем хоста и шагом (доступ по SSH, rsync, переключение `www`).
- `scripts/build_cities_json.py` — генерирует `cities.json` (список всех городов) для CDN и выпадающего переключателя.
- `python3 scripts/sync_city_domains.py` — сверка `data/cities.yaml` с таблицей (запускается в CI).
- nginx (`deploy/nginx.conf`) — `map $host $city_dir` подставляет root, алиасы отдают 301 на канонический хост; отдельный `server` для `cdn.stilgrad.ru` (CORS + вечный кэш медиа).

### CDN и общий каталог

- Каталог моделей одинаковый на основном домене и на всех городских поддоменах — пользователь не уходит с хоста своего города. Модельные страницы в городах отдают `canonical` на основной домен (без дублей).
- Изображения каталога и hero генерируются один раз и раздаются с `cdn.stilgrad.ru`; все хосты ссылаются на них абсолютными URL (`partials/cdn-url.html`). `og:image` на CDN исключён из проверки `scripts/check_og.py`.
- Переключатель городов в подвале — выпадающий список **всех 16 городов** (серверный рендер + обновление из `cities.json` на CDN).


Правило публикации: `ready` в `data/cities.yaml` управляет только индексацией
(`ready: false` — страница закрыта от индексации, `noindex`). В выпадающем
переключателе показываются все 16 городов. Публиковать (`ready: true`) можно после
сбора фактов: конкретные ПВЗ СДЭК с адресами и режимом, реальные сроки и стоимость
доставки, отзывы с согласием (`consent: true`). Доставка — только СДЭК.



`og:image` выводится на каждой странице: у карточки модели — `images[0].src`, у главной — `hero.image` из `content/_index.md`. Остальные страницы берут общий файл, если он есть: положите `static/og/og-cover.jpg` размером 1200×630 — он подхватится автоматически (параметр `ogImageDefault` в `hugo.toml`). Глобальный оверрайд — `params.ogImage` (он же `Organization.logo`), точечный — поле `og_image` во front matter страницы или модели.

Проверка: `python3 scripts/check_og.py public` — запускается в CI после сборки и падает, если `og:image` нет, URL относительный, файл не найден или размеры не совпадают.

## Что заполнить до запуска

| Параметр | Где | Статус |
| --- | --- | --- |
| Домен и `baseURL` | `hugo.toml` | https://stilgrad.ru/ |
| `noindex = true` → `false` | `hugo.toml` | снимается перед публикацией |
| Номер счётчика Метрики | `hugo.toml` → `params.metrikaId` | TODO |
| ОГРНИП, e-mail | `hugo.toml` → `params` | TODO (L-01) |
| Telegram, MAX, Wildberries, e-mail | `data/contacts.yaml` | TODO |
| Обмеры 50–72 | `data/sizes.yaml` | из `sizes.png` (полуобхват); строка 72 — расчётная |
| Фото съёмки | `content/**/`, `static/images/` | TODO (M3) |
| OG-превью 1200×630 | `static/og/og-cover.jpg` | TODO: пока используется `photo/hero.webp` |
| Юридические тексты | `content/offer`, `content/privacy`, `content/delivery` | политика — редакция от 24.11.2026; оферта и доставка — проверить у юриста |
| Городские факты: ПВЗ, сроки, отзывы | `data/cities.yaml` | TODO: заполнить и поставить `ready: true` |
| DNS поддоменов и wildcard TLS | панель NetAngels | TODO: wildcard `*.stilgrad.ru` — 16 канонических хостов, 24 алиаса и CDN-хост `cdn.stilgrad.ru` |
| Подтверждение прав в Вебмастере | `static/` | TODO: положить HTML-файл Яндекса |

## Changelog

Проект ведёт [`CHANGELOG.md`](CHANGELOG.md) в формате [Keep a Changelog](https://keepachangelog.com/ru/1.1.0/), версии — по [Semantic Versioning](https://semver.org/lang/ru/).

Правила:

1. Любое изменение поведения сайта, контентной модели или документации попадает в раздел `[Unreleased]`.
2. Разделы — `Added`, `Changed`, `Fixed`, `Removed`, `Docs`, `Security`.
3. При релизе `[Unreleased]` превращается в версию с датой, ссылки на теги — внизу файла.
4. Запись пишется для владелицы и разработчика: что изменилось и что делать.

## Примечания

- Сборка использует Dart Sass (транспилер по умолчанию в Hugo 0.169): локально нужен бинарник `sass`, в CI — шаг `dart sass` (`dw-labs-org/dart-sass-gha`) во всех workflow со сборкой. Без него сборка падает с `no Dart Sass binary found in $PATH`.
- Шрифты пока системные: самохостинг woff2 (Cormorant Garamond + Inter) — задача этапа M4.
- CI (`ci.yml`) собирает сайт на каждый push и PR, проверяет YAML и front matter, обязательные поля моделей, OG-разметку (`scripts/check_og.py`) и валидность HTML (`html-validate@11.21.1`, блокирующий шаг); Lighthouse CI подключён и тоже блокирующий. Проверки ссылок в `ci.yml` нет: lychee ходит по уже развёрнутым доменам, для push/PR это ложные падения — см. `links.yml`.
- `html-validate` запускается через `npx` и требует Node ≥ 22.22 (в CI нужная версия ставится шагом `actions/setup-node`). Сам сайт по-прежнему собирается Hugo без Node; локальный прогон — `task test:validate`.
- Lighthouse CI (`.lighthouserc.cjs`) собирает список URL из готового `public/`: главная, корень каталога, по одной карточке из каждой коллекции (`/catalog/<collection>/<model>/`) и городские лендинги Москвы и Екатеринбурга (`/cities/moscow/`, `/cities/ekb/`, константа `CITY_URL_CODES`). Модели можно добавлять, удалять и переименовывать без правки конфига. Полный обход всех страниц сборки — `LHCI_ALL_PAGES=1 npx --yes @lhci/cli@0.14.0 autorun` (в разы дольше). Аудиты `is-on-https` и `redirects-http` пропущены (`collect.settings.skipAudits`) и отключены в `assert` (`"off"`): в CI сайт отдаётся по `http://localhost`, проверки HTTPS к нему неприменимы. Локально: `hugo --minify --gc && npx --yes @lhci/cli@0.14.0 autorun` (нужен установленный Chrome).
- Деплой — отдельный workflow `deploy.yml`: запускается по `workflow_run` после успешного прогона `ci` на `main` (и вручную через `workflow_dispatch`). Нужны секреты `SSH_HOST`, `SSH_USER`, `SSH_KEY`, `SSH_KNOWN_HOSTS` и переменная `SITE_BASE_URL`. На хостинге каждый виртуальный хост — отдельный каталог в домашней директории SSH-пользователя (`stilgrad.ru/`, `moscow.stilgrad.ru/`, …): `scripts/deploy.sh` кладёт релиз в `<host>/releases/<RELEASE>`, атомарно переключает `<host>/www` и делает `touch <host>/reload`. Шаг деплоя неинтерактивный: ssh без запросов пароля и подтверждений, с таймаутами — при неверном ключе или `known_hosts` он падает сразу с сообщением «Нет доступа по SSH к …», а не висит в логе. Хранятся 5 последних релизов; откат — вручную переключить `www` на предыдущий релиз: `ssh … "ln -sfn releases/<старый-ts> <host>/www"`.
- `links.yml` — ручная проверка ссылок (`lychee` + issue-репорт): Actions → Links → Run workflow, плюс ночной прогон по расписанию. Собирает сайт тем же шагом `dart sass` и проверяет внешние адреса и городские поддомены, которые отвечают только после деплоя; в блокирующий `ci.yml` не входит.
