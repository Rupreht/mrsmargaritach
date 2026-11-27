#!/usr/bin/env bash
# Мультисборка сайта: основной домен + городские поддомены + CDN-набор.
#
# Использование:
#   scripts/build.sh [DEST] [APEX_BASEURL] [MEDIA_BASEURL]
#     DEST         — корень сборки (по умолчанию public)
#     APEX_BASEURL — baseURL основного сайта (пусто — из hugo.toml)
#     MEDIA_BASEURL — база CDN для медиа, например https://cdn.stilgrad.ru/
#                     (пусто — относительные ссылки, локальная разработка).
#                     Можно задать переменной окружения MEDIA_BASE_URL.
#
# Результат:
#   $DEST/                 — stilgrad.ru (HTML, css/, js/; медиа — на CDN)
#   $DEST/cities/<code>/   — <code>.stilgrad.ru: полный каталог + городские страницы
#   $DEST/cdn/             — CDN-набор: catalog/, photo/, cities.json
#
# Городская сборка монтирует общий content/catalog рядом с city-content/<code>
# (одинаковая структура каталога на всех сайтах) и читает layouts/assets/data
# общие. Медиа (catalog/, photo/) генерируется один раз и публикуется только на CDN;
# все хосты ссылаются на него абсолютными URL (MEDIA_BASE_URL).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

DEST="public"
APEX_BASE=""
MEDIA_BASE="${MEDIA_BASE_URL:-}"
POSITIONAL=0
for arg in "$@"; do
  case "$arg" in
    # Устаревший флаг: каталог больше не дублируется по хостам (медиа на CDN).
    --no-shared-links) continue ;;
  esac
  POSITIONAL=$((POSITIONAL + 1))
  case "$POSITIONAL" in
    1) DEST="$arg" ;;
    2) APEX_BASE="$arg" ;;
    3) MEDIA_BASE="$arg" ;;
    *)
      echo "Неизвестный аргумент: $arg" >&2
      echo "Использование: scripts/build.sh [DEST] [APEX_BASEURL] [MEDIA_BASEURL]" >&2
      exit 2
      ;;
  esac
done

# Шаблоны читают базу CDN через os.Getenv "MEDIA_BASE_URL".
export MEDIA_BASE_URL="$MEDIA_BASE"

# Список городов — из alias.stilgrad.md; переопределяется переменной CITIES.
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

# Конфиг монтирования для городской сборки: город + общий каталог + общие
# ассеты/data/layouts. Файл пересоздаётся под каждый город (нужно расширение .toml).
mounts_dir="$(mktemp -d)"
mounts_file="$mounts_dir/mounts.toml"
trap 'rm -rf "$mounts_dir"' EXIT

for code in $CITY_CODES; do
  cat > "$mounts_file" <<EOF
[module]
  [[module.mounts]]
    source = "city-content/${code}"
    target = "content"
  [[module.mounts]]
    source = "content/catalog"
    target = "content/catalog"
  [[module.mounts]]
    source = "assets"
    target = "assets"
  [[module.mounts]]
    source = "static"
    target = "static"
  [[module.mounts]]
    source = "data"
    target = "data"
  [[module.mounts]]
    source = "layouts"
    target = "layouts"
  [[module.mounts]]
    source = "i18n"
    target = "i18n"
  [[module.mounts]]
    source = "archetypes"
    target = "archetypes"
EOF

  echo "==> Городская сборка $code → $DEST/cities/$code"
  hugo --minify --gc --environment production \
    --config "hugo.toml,city-config/${code}.toml,${mounts_file}" \
    --destination "$DEST/cities/${code}"
done

# CDN-набор: медиа (catalog/photo) в одном экземпляре + список городов.
# catalog/ и photo/ на самих хостах не нужны — они раздаются с CDN.
echo "==> CDN-набор → $DEST/cdn"
mkdir -p "$DEST/cdn"
for media in catalog photo; do
  if [ -d "$DEST/$media" ]; then
    cp -Rl "$DEST/$media" "$DEST/cdn/$media" 2>/dev/null \
      || cp -R "$DEST/$media" "$DEST/cdn/$media"
  fi
done
python3 "$SCRIPT_DIR/build_cities_json.py" \
  --out "$DEST/cdn/cities.json" --domain "${DOMAIN:-stilgrad.ru}"

echo "==> Готово: $(find "$DEST" -name index.html | wc -l | tr -d ' ') index.html"
