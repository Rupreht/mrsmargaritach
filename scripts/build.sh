#!/usr/bin/env bash
# Мультисборка сайта: основной домен + городские поддомены.
#
# Использование:
#   scripts/build.sh [DEST] [APEX_BASEURL]
#     DEST         — корень сборки (по умолчанию public)
#     APEX_BASEURL — baseURL основного сайта (пусто — берётся из hugo.toml)
#
# Результат:
#   $DEST/                 — stilgrad.ru
#   $DEST/cities/<code>/   — <code>.stilgrad.ru (mow, led, kzn, svx, ovb)
#
# Городская сборка мержит hugo.toml с city-config/<code>.toml и читает
# контент из city-content/<code>; layouts/assets/data общие.
set -euo pipefail

DEST="${1:-public}"
APEX_BASE="${2:-}"
CITIES="${CITIES:-mow led kzn svx ovb}"

rm -rf "$DEST"

APEX_ARGS=(--minify --gc --environment production --destination "$DEST")
if [ -n "$APEX_BASE" ]; then
  APEX_ARGS+=(--baseURL "$APEX_BASE")
fi

echo "==> Основной сайт → $DEST"
hugo "${APEX_ARGS[@]}"

for code in $CITIES; do
  echo "==> Городская сборка $code → $DEST/cities/$code"
  hugo --minify --gc --environment production \
    --config "hugo.toml,city-config/${code}.toml" \
    --contentDir "city-content/${code}" \
    --destination "$DEST/cities/${code}"
done

echo "==> Готово: $(find "$DEST" -maxdepth 2 -name index.html | wc -l | tr -d ' ') index.html"
