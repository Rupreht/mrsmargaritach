# Сайт бренда «Маргарита Чистова»

Статический мини-сайт женских рубашек больших размеров (54–72). Задача сайта — не продавать онлайн, а показать вещи и перевести посетительницу в личный диалог с автором бренда.

- Концепция, аудитория и тексты: [`docs/tz.md`](docs/tz.md)
- План разработки, требования, юридический блок: [`docs/implementation_plan.md`](docs/implementation_plan.md)
- Ключевые фразы: [`docs/SEO.md`](docs/SEO.md)
- История изменений: [`CHANGELOG.md`](CHANGELOG.md)

## Стек

| Слой | Решение |
| --- | --- |
| Генератор | Hugo extended ≥ 0.140 (проект собран на 0.169.0) |
| Контент | Markdown + YAML в `content/` и `data/` |
| Стили | SCSS через Hugo Pipes (`css.Sass`), один файл |
| Скрипты | ванильный ES2020, один бандл (`js.Build`), без фреймворков |
| Сборка/деплой | GitHub Actions, rsync + nginx |

Node.js не требуется ни для сборки, ни для работы сайта. Корзины, форм и сбора персональных данных на сайте нет.

## Локальный запуск

```bash
hugo version                 # нужен extended ≥ 0.140
hugo server                  # http://localhost:1313
hugo --minify --gc --environment production
```

Собранный сайт появляется в `public/` (каталог в `.gitignore`).

## Структура проекта

```text
hugo.toml                      конфигурация, меню, реквизиты, параметры
content/
  _index.md                    главная: тексты блоков
  about/index.md               о бренде
  catalog/_index.md            каталог (список коллекций)
  catalog/autumn-casual/       коллекция «Осенний кэжуал»
    _index.md                  страница коллекции
    chestnut/index.md          карточка модели «Каштан»
    nutmeg/index.md            карточка модели «Мускатный орех»
    forest-moss/index.md       карточка модели «Лесной мох»
  catalog/olive/index.md       карточка модели (вне коллекции)
  delivery/index.md            доставка и возврат
  faq/index.md                 вопросы и ответы (front matter `faq`)
  offer/index.md               публичная оферта (черновик)
  privacy/index.md             политика ПД (черновик)
data/
  contacts.yaml                каналы связи и ссылки
  sizes.yaml                   размерная сетка
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
archetypes/                    шаблоны новых страниц: default, catalog, collection
static/favicon.svg
deploy/nginx.conf              конфиг хостинга
.github/workflows/             build.yml, deploy.yml
.editorconfig                  отступы и кодировка для редакторов
```

## Как добавить модель

1. Создать коллекцию (если новая): `hugo new content --kind collection catalog/<collection-slug>/_index.md` (подставит поля коллекции из `archetypes/collection.md`).
2. Создать карточку из архетипа: `hugo new content --kind model catalog/<collection-slug>/<model-slug>/index.md` (подставит все поля модели) или скопировать одну из существующих моделей в коллекции.
3. Положить изображения рядом (`cover.webp` первым кадром, затем `01.webp`, `02.webp`).
4. Заполнить `title`, `article`, `color_name`, `color_hex`, `price`, `sizes`, `fabric`, `care`, `details`, `images[].alt`.
5. Запустить `hugo server` — модель появится на главной и в каталоге без правки шаблонов.

Пока изображений нет, карточка показывает цветной плейсхолдер — вёрстка не ломается.

## Что заполнить до запуска

| Параметр | Где | Статус |
| --- | --- | --- |
| Домен и `baseURL` | `hugo.toml` | TODO |
| `noindex = true` → `false` | `hugo.toml` | снимается перед публикацией |
| Номер счётчика Метрики | `hugo.toml` → `params.metrikaId` | TODO |
| ОГРНИП, e-mail | `hugo.toml` → `params` | TODO (L-01) |
| Telegram, MAX, Wildberries, e-mail | `data/contacts.yaml` | TODO |
| Реальные обмеры 54–72 | `data/sizes.yaml` | черновик, подтвердить у владелицы |
| Фото съёмки | `content/**/`, `static/images/` | TODO (M3) |
| Юридические тексты | `content/offer`, `content/privacy`, `content/delivery` | черновики, проверить у юриста |

## Changelog

Проект ведёт [`CHANGELOG.md`](CHANGELOG.md) в формате [Keep a Changelog](https://keepachangelog.com/ru/1.1.0/), версии — по [Semantic Versioning](https://semver.org/lang/ru/).

Правила:

1. Любое изменение поведения сайта, контентной модели или документации попадает в раздел `[Unreleased]`.
2. Разделы — `Added`, `Changed`, `Fixed`, `Removed`, `Docs`, `Security`.
3. При релизе `[Unreleased]` превращается в версию с датой, ссылки на теги — внизу файла.
4. Запись пишется для владелицы и разработчика: что изменилось и что делать.

## Примечания

- В `hugo.toml` используется транспилер `libsass` (работает в Hugo extended без внешних бинарников). В Hugo 0.153+ он помечен deprecated: перед обновлением Hugo нужно поставить Dart Sass и переключить `transpiler` на `dartsass`.
- Шрифты пока системные: самохостинг woff2 (Cormorant Garamond + Inter) — задача этапа M4.
- Lighthouse, lychee и html-validate в CI пока не подключены (см. `docs/implementation_plan.md`, п. 2.10).
