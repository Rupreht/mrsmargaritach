#!/usr/bin/env bash
# Мультихостовый деплой: основной сайт + городские поддомены.
#
# На хостинге каждый виртуальный хост — отдельная директория в домашнем
# каталоге SSH-пользователя:
#
#   <host>/releases/<RELEASE>/   — файлы релиза
#   <host>/www -> releases/<RELEASE>
#   <host>/reload                — маркер перезагрузки nginx (touch)
#
# Один и тот же RELEASE раскладывается на все хосты: основной сайт — в
# APEX_HOST (stilgrad.ru), городские сборки — в <code>.stilgrad.ru.
# Переключение www атомарно (ln -sfn), старые релизы удаляются, последние
# KEEP_RELEASES остаются для ручного отката:
#
#   ssh ... "ln -sfn releases/<старый-RELEASE> <host>/www"
#
# Городские сборки должны быть самодостаточными: собирайте их с
# `scripts/build.sh dist ... --no-shared-links`, иначе симлинки ../../css
# уведут за пределы каталога виртуального хоста.
#
# Использование:
#   SSH_USER=c48944 SSH_HOST=h31.netangels.ru \
#     scripts/deploy.sh <RELEASE> [DEST]
#
# Переменные окружения:
#   SSH_USER       — пользователь хостинга (обязательно);
#   SSH_HOST       — сервер хостинга (обязательно);
#   APEX_HOST      — каталог основного сайта (по умолчанию stilgrad.ru);
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

# deploy_site <host-dir> <source-dir> <rsync-exclude|"">
deploy_site() {
  host="$1"
  src="$2"
  exclude="$3"
  releases_dir="$host/releases"

  echo "==> $host <- $src (release $RELEASE)"

  # Каталог releases может отсутствовать у нового виртуального хоста.
  ssh "$SSH_TARGET" "mkdir -p '$releases_dir'"

  # Публикуем в новый каталог, не трогая активный релиз. --delete страхует
  # от остатков, если релиз с таким именем уже существует.
  if [ -n "$exclude" ]; then
    rsync -az --delete --exclude "$exclude" \
      "$src/" "$SSH_TARGET:$releases_dir/$RELEASE/"
  else
    rsync -az --delete \
      "$src/" "$SSH_TARGET:$releases_dir/$RELEASE/"
  fi

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

# Основной сайт: городские сборки в его релиз не кладём — они публикуются
# отдельными виртуальными хостами.
deploy_site "$APEX_HOST" "$DEST" "cities/"

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
  deploy_site "$code.stilgrad.ru" "$DEST/cities/$code" ""
done

echo "==> Готово: release $RELEASE опубликован на всех хостах"
