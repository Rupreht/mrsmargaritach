#!/usr/bin/env bash
# hugo server в контейнере (сервис tools в compose.yaml).
# Исходники должны быть смонтированы в /site: live-reload читает файлы хоста.
set -euo pipefail

if [ ! -f hugo.toml ]; then
    cat >&2 <<'MSG'
В /site нет исходников — каталог проекта не смонтирован в контейнер.

Docker Desktop: Settings → Resources → File sharing должен включать домашний каталог.
Colima: каталог проекта должен быть в списке монтирования
        (colima start --mount-type virtiofs, либо colima start --mount <путь>:w).

Проверки без монтирования работают и так:
    docker compose run --rm --build test
MSG
    exit 1
fi

exec hugo server \
    --bind 0.0.0.0 \
    --baseURL "${HUGO_BASE_URL:-http://localhost:1313/}" \
    --disableFastRender \
    "$@"
