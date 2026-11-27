#!/usr/bin/env bash
# Мультихостовый деплой: основной сайт + городские поддомены + CDN.
#
# На хостинге каждый виртуальный хост — отдельная директория в домашнем
# каталоге SSH-пользователя:
#
#   <host>/releases/<RELEASE>/   — файлы релиза
#   <host>/www -> releases/<RELEASE>
#   <host>/reload                — маркер перезагрузки nginx (touch)
#
# Один и тот же RELEASE раскладывается на все хосты: основной сайт — в
# APEX_HOST (stilgrad.ru), городские сборки — в <code>.stilgrad.ru, медиа
# (каталог, hero) и cities.json — в CDN_HOST (cdn.stilgrad.ru).
# Медиа генерируется один раз и лежит ТОЛЬКО на CDN: из основного и городских
# хостов изображения исключаются (страницы ссылаются на cdn.<domain>).
#
# Переключение www атомарно (ln -sfn), старые релизы удаляются, последние
# KEEP_RELEASES остаются для ручного отката:
#
#   ssh ... "ln -sfn releases/<старый-RELEASE> <host>/www"
#
# Использование:
#   SSH_USER=c48944 SSH_HOST=h31.netangels.ru \
#     scripts/deploy.sh <RELEASE> [DEST]
#
# Переменные окружения:
#   SSH_USER       — пользователь хостинга (обязательно);
#   SSH_HOST       — сервер хостинга (обязательно);
#   APEX_HOST      — каталог основного сайта (по умолчанию stilgrad.ru);
#   CDN_HOST       — каталог CDN (по умолчанию cdn.stilgrad.ru);
#   KEEP_RELEASES  — сколько релизов хранить на каждом хосте (по умолчанию 5);
#   CITIES         — коды городов через пробел (по умолчанию — из
#                    alias.stilgrad.md, колонка «Основной домен»).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

RELEASE="${1:-}"
DEST="${2:-dist}"
SSH_USER="${SSH_USER:-}"
SSH_HOST="${SSH_HOST:-}"
APEX_HOST="${APEX_HOST:-stilgrad.ru}"
CDN_HOST="${CDN_HOST:-cdn.stilgrad.ru}"
KEEP_RELEASES="${KEEP_RELEASES:-5}"

if [ -z "$RELEASE" ]; then
  echo "Использование: SSH_USER=... SSH_HOST=... scripts/deploy.sh <RELEASE> [DEST]" >&2
  exit 2
fi
if [ -z "$SSH_USER" ] || [ -z "$SSH_HOST" ]; then
  echo "Не заданы SSH_USER и/или SSH_HOST" >&2
  exit 2
fi
if [ ! -d "$DEST" ]; then
  echo "Нет каталога сборки: $DEST" >&2
  exit 2
fi

# Не даём удалить единственный релиз: www всегда должен указывать на живой.
case "$KEEP_RELEASES" in
  ''|*[!0-9]*) KEEP_RELEASES=5 ;;
esac
if [ "$KEEP_RELEASES" -lt 1 ]; then
  KEEP_RELEASES=1
fi

SSH_TARGET="${SSH_USER}@${SSH_HOST}"

# deploy_site <host-dir> <source-dir> [rsync-exclude ...]
# Медиа (изображения) на хостах не нужно: оно на CDN, поэтому в exclude
# передаём шаблоны расширений.
deploy_site() {
  host="$1"
  src="$2"
  shift 2
  local -a excludes=("$@")
  releases_dir="$host/releases"

  echo "==> $host <- $src (release $RELEASE)"

  # Каталог releases может отсутствовать у нового виртуального хоста.
  ssh "$SSH_TARGET" "mkdir -p '$releases_dir'"

  local -a rsync_args=(-az --delete)
  local ex
  for ex in "${excludes[@]}"; do
    rsync_args+=(--exclude "$ex")
  done

  # Публикуем в новый каталог, не трогая активный релиз. --delete страхует
  # от остатков, если релиз с таким именем уже существует.
  rsync "${rsync_args[@]}" "$src/" "$SSH_TARGET:$releases_dir/$RELEASE/"

  # Атомарно переключаем www, удаляем старые релизы, перезагружаем nginx.
  ssh "$SSH_TARGET" "
    set -e
    cd '$host'
    ln -sfn 'releases/$RELEASE' www
    ls -1dt releases/*/ | tail -n +$((KEEP_RELEASES + 1)) | xargs -r rm -rf
    echo \"$host -> \$(readlink www)\"
    touch reload
  "
}

# Изображения раздаются с CDN — на остальных хостах они не нужны.
MEDIA_EXCLUDES=("*.webp" "*.jpg" "*.jpeg" "*.png" "*.JPG" "*.JPEG" "*.PNG")

# Основной сайт: городские сборки и CDN-набор лежат отдельными хостами.
deploy_site "$APEX_HOST" "$DEST" "cities/" "cdn/" "${MEDIA_EXCLUDES[@]}"

# CDN: медиа (catalog/, photo/) и cities.json — в одном экземпляре.
if [ -d "$DEST/cdn" ]; then
  deploy_site "$CDN_HOST" "$DEST/cdn"
else
  echo "Нет CDN-набора: $DEST/cdn (соберите scripts/build.sh с MEDIA_BASE_URL)" >&2
  exit 1
fi

# Городские поддомены: канонические коды из alias.stilgrad.md.
if [ -n "${CITIES:-}" ]; then
  CITY_CODES="$CITIES"
else
  CITY_CODES="$(python3 "$SCRIPT_DIR/list_domains.py" --column main --domain stilgrad.ru)"
fi

for code in $CITY_CODES; do
  if [ ! -d "$DEST/cities/$code" ]; then
    echo "Нет городской сборки: $DEST/cities/$code" >&2
    exit 1
  fi
  deploy_site "$code.stilgrad.ru" "$DEST/cities/$code" "${MEDIA_EXCLUDES[@]}"
done

echo "==> Готово: release $RELEASE опубликован на всех хостах (медиа — на $CDN_HOST)"

