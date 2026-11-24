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
| Генератор | Hugo extended ≥ 0.140 (проект собран на 0.169.0) |
| Контент | Markdown + YAML в `content/` и `data/` |
| Стили | SCSS через Hugo Pipes (`css.Sass`), один файл, `brew install dart-sass` |
| Скрипты | ванильный ES2020, один бандл (`js.Build`), без фреймворков |
| Сборка/деплой | GitHub Actions, rsync + nginx |

Node.js не требуется ни для сборки, ни для работы сайта. Корзины, форм и сбора персональных данных на сайте нет.

## Локальный запуск

```bash
hugo version                 # нужен extended ≥ 0.140
hugo server                  # http://localhost:1313
hugo --minify --gc --environment production
python3 scripts/check_og.py public   # проверка OG-разметки после сборки
```

Собранный сайт появляется в `public/` (каталог в `.gitignore`).

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
.lighthouserc.cjs              конфиг Lighthouse CI (главная, каталог, карточки)
.htmlvalidate.json             правила html-validate
scripts/check_og.py            валидатор OG-разметки в собранном public/
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

## OG-превью для соцсетей

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
- CI (`ci.yml`) собирает сайт на каждый push и PR, проверяет YAML и front matter, обязательные поля моделей, OG-разметку (`scripts/check_og.py`), валидность HTML (`html-validate`, блокирующий шаг) и ссылки (`lychee`); Lighthouse CI подключён, но пока с `continue-on-error` — на noindex-сайте SEO-аудит заведомо ниже цели.
- Lighthouse CI (`.lighthouserc.cjs`) собирает список URL из готового `public/`: главная, корень каталога и по одной карточке из каждой коллекции (`/catalog/<collection>/<model>/`). Модели можно добавлять, удалять и переименовывать без правки конфига. Полный обход всех страниц сборки — `LHCI_ALL_PAGES=1 npx --yes @lhci/cli@0.14.0 autorun` (в разы дольше). Аудиты `is-on-https` и `redirects-http` пропущены (`collect.settings.skipAudits`) и отключены в `assert` (`"off"`): в CI сайт отдаётся по `http://localhost`, проверки HTTPS к нему неприменимы. Локально: `hugo --minify --gc && npx --yes @lhci/cli@0.14.0 autorun` (нужен установленный Chrome).
- Деплой — отдельный workflow `deploy.yml`: запускается по `workflow_run` после успешного прогона `ci` на `main` (и вручную через `workflow_dispatch`). Нужны секреты `SSH_HOST`, `SSH_USER`, `SSH_KEY`, `SSH_KNOWN_HOSTS` и переменные `SITE_BASE_URL`, `SITE_HOSTNAME`. Откат ручной — переключить симлинк `www` на предыдущий релиз из `releases/`.
- `links.yml` — ежедневная проверка ссылок на собранном сайте (`lychee` + issue-репорт), собирает сайт тем же шагом `dart sass`.
