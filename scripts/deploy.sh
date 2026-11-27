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
#                    alias.stilgrad.md, колонка «Основной домен»);
#   RSYNC_TIMEOUT  — I/O-таймаут rsync в секундах: если передача не двигается
#                    дольше, шаг падает с ошибкой (по умолчанию 600).
#
# ssh везде вызывается в неинтерактивном режиме (BatchMode + таймауты): в CI нет
# tty, и без этого ssh «висит» на приглашении пароля или подтверждении host key,
# а шаг деплоя просто замолкает в логе.
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
RSYNC_TIMEOUT="${RSYNC_TIMEOUT:-600}"

# Неинтерактивный ssh: без запросов пароля и подтверждений, с таймаутами, чтобы
# шаг падал с внятной ошибкой, а не висел. StrictHostKeyChecking=yes — ключ хоста
# уже записан из секрета SSH_KNOWN_HOSTS в ~/.ssh/known_hosts (шаг в deploy.yml).
SSH_OPTS=(
  -o BatchMode=yes
  -o StrictHostKeyChecking=yes
  -o ConnectTimeout=20
  -o ServerAliveInterval=15
  -o ServerAliveCountMax=4
)

# Предупреждение «connection is not using a post-quantum key exchange algorithm»
# (OpenSSH 10+) глушится опцией WarnWeakCrypto=no. На старых клиентах такой опции
# нет — неизвестная опция для ssh фатальна, поэтому проверяем поддержку заранее:
# ssh -G разбирает конфиг без подключения к серверу.
if ssh -o WarnWeakCrypto=no -G "$SSH_TARGET" >/dev/null 2>&1; then
  SSH_OPTS+=(-o WarnWeakCrypto=no)
fi

# rsync запускает ssh сам — передаём ему те же опции.
RSYNC_SSH="ssh"
for opt in "${SSH_OPTS[@]}"; do
  printf -v quoted '%q' "$opt"
  RSYNC_SSH+=" $quoted"
done

# Проверка доступа до раскладки: иначе первая же ошибка ключа выглядит как
# «тишина» в логе после строки про хост.
echo "==> Проверка SSH: $SSH_TARGET ($(ssh -V 2>&1))"
if ! ssh "${SSH_OPTS[@]}" "$SSH_TARGET" true; then
  echo "Нет доступа по SSH к $SSH_TARGET — проверьте секреты SSH_KEY и SSH_KNOWN_HOSTS" >&2
  exit 1
fi

# deploy_site <host-dir> <source-dir> [rsync-exclude ...]
# Медиа (изображения) на хостах не нужно: оно на CDN, поэтому в exclude
# передаём шаблоны расширений.
deploy_site() {
  local host="$1"
  local src="$2"
  shift 2
  # Пустой список exclude — обычный случай (CDN), но под set -u обращение к
  # пустому массиву в старом bash (3.2 на macOS) — ошибка, поэтому цикл под guard.
  local -a excludes=()
  if [ "$#" -gt 0 ]; then
    excludes=("$@")
  fi
  local releases_dir="$host/releases"

  echo "==> $host <- $src (release $RELEASE)"

  # Каталог releases может отсутствовать у нового виртуального хоста.
  if ! ssh "${SSH_OPTS[@]}" "$SSH_TARGET" "mkdir -p '$releases_dir'"; then
    echo "Не удалось создать $releases_dir на $SSH_TARGET" >&2
    exit 1
  fi

  # --timeout: обрыв «залипшей» передачи с ошибкой вместо бесконечного ожидания;
  # --stats: в логе видно, сколько реально передано на хост (диагностика медленного
  # деплоя без спама --progress по каждому файлу).
  local -a rsync_args=(-az --delete --stats "--timeout=$RSYNC_TIMEOUT" -e "$RSYNC_SSH")
  if [ "${#excludes[@]}" -gt 0 ]; then
    local ex
    for ex in "${excludes[@]}"; do
      rsync_args+=(--exclude "$ex")
    done
  fi

  # Публикуем в новый каталог, не трогая активный релиз. --delete страхует
  # от остатков, если релиз с таким именем уже существует.
  if ! rsync "${rsync_args[@]}" "$src/" "$SSH_TARGET:$releases_dir/$RELEASE/"; then
    echo "rsync не загрузил $src на $host (release $RELEASE)" >&2
    exit 1
  fi
  echo "==> $host: файлы загружены, переключаю www"

  # Атомарно переключаем www, удаляем старые релизы, перезагружаем nginx.
  if ! ssh "${SSH_OPTS[@]}" "$SSH_TARGET" "
    set -e
    cd '$host'
    ln -sfn 'releases/$RELEASE' www
    ls -1dt releases/*/ | tail -n +$((KEEP_RELEASES + 1)) | xargs -r rm -rf
    echo \"$host -> \$(readlink www)\"
    touch reload
  "; then
    echo "Не удалось переключить www на $host (release $RELEASE)" >&2
    exit 1
  fi
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
