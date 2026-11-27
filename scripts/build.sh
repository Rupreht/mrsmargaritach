#!/usr/bin/env bash
# Мультисборка сайта: основной домен + городские поддомены.
#
# Использование:
#   scripts/build.sh [DEST] [APEX_BASEURL] [--no-shared-links]
#     DEST         — корень сборки (по умолчанию public)
#     APEX_BASEURL — baseURL основного сайта (пусто — берётся из hugo.toml)
#     --no-shared-links — не заменять одинаковые ассеты городов симлинками:
#                         города остаются самодостаточными и годятся для
#                         отдельного виртуального хоста (деплой, scripts/deploy.sh).
#                         Эквивалент SHARED_ASSETS=0.
#
# Результат:
#   $DEST/                 — stilgrad.ru
#   $DEST/cities/<code>/   — <code>.stilgrad.ru: канонические домены городов
#                            из alias.stilgrad.md (колонка «Основной домен»)
#
# Городская сборка мержит hugo.toml с city-config/<code>.toml и читает
# контент из city-content/<code>; layouts/assets/data общие.
#
# По умолчанию идентичные ассеты в городах не дублируются: css/, js/, photo/,
# favicon.svg и .htaccess одинаковы во всех сборках (общие assets/static и
# контент-хэшированные имена), поэтому вместо копии в каталог города кладётся
# относительный симлинк на экземпляр основного сайта ($DEST/...). Для локального
# nginx и образа Docker это экономит место. С --no-shared-links остаются копии.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Аргументы: два позиционных (DEST, APEX_BASEURL) и флаг --no-shared-links.
# Флаг можно ставить в любом месте; SHARED_ASSETS=0 делает то же самое.
NO_SHARED_LINKS=0
if [ "${SHARED_ASSETS:-1}" = "0" ]; then
  NO_SHARED_LINKS=1
fi
DEST="public"
APEX_BASE=""
POSITIONAL=0
for arg in "$@"; do
  case "$arg" in
    --no-shared-links)
      NO_SHARED_LINKS=1
      continue
      ;;
  esac
  POSITIONAL=$((POSITIONAL + 1))
  case "$POSITIONAL" in
    1) DEST="$arg" ;;
    2) APEX_BASE="$arg" ;;
    *)
      echo "Неизвестный аргумент: $arg" >&2
      echo "Использование: scripts/build.sh [DEST] [APEX_BASEURL] [--no-shared-links]" >&2
      exit 2
      ;;
  esac
done

# Список городов — из alias.stilgrad.md, чтобы конфигурация не расходилась с
# таблицей доменов. Переопределяется переменной окружения CITIES.
if [ -n "${CITIES:-}" ]; then
  CITY_CODES="$CITIES"
else
  CITY_CODES="$(python3 "$SCRIPT_DIR/list_domains.py" --column main --domain stilgrad.ru)"
fi

rm -rf "$DEST"

APEX_ARGS=(--minify --gc --environment production --destination "$DEST")
if [ -n "$APEX_BASE" ]; then
  APEX_ARGS+=(--baseURL "$APEX_BASE")
fi

echo "==> Основной сайт → $DEST"
hugo "${APEX_ARGS[@]}"

# Файлы/каталоги, одинаковые во всех сборках: вместо копии — симлинк на основной
# сайт. Если содержимое вдруг разойдётся (изменилась обработка ассетов), симлинк
# не создаётся — остаётся собственная копия города (безопасный фолбэк).
# В режиме --no-shared-links симлинки не создаются: каждая городская сборка
# самодостаточна и публикуется в отдельный виртуальный хост.
SHARED_ASSETS=(css js photo favicon.svg .htaccess)

for code in $CITY_CODES; do
  echo "==> Городская сборка $code → $DEST/cities/$code"
  hugo --minify --gc --environment production \
    --config "hugo.toml,city-config/${code}.toml" \
    --contentDir "city-content/${code}" \
    --destination "$DEST/cities/${code}"

  if [ "$NO_SHARED_LINKS" -eq 0 ]; then
    for asset in "${SHARED_ASSETS[@]}"; do
      city_asset="$DEST/cities/$code/$asset"
      apex_asset="$DEST/$asset"
      if [ -e "$city_asset" ] && [ -e "$apex_asset" ] \
          && diff -rq "$city_asset" "$apex_asset" >/dev/null 2>&1; then
        rm -rf "$city_asset"
        ln -s "../../$asset" "$city_asset"
      fi
    done
  fi
done

echo "==> Готово: $(find "$DEST" -name index.html | wc -l | tr -d ' ') index.html"
