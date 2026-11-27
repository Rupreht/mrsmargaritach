#!/usr/bin/env bash
# Проверки сборки в контейнере — те же шаги, что в .github/workflows/ci.yml.
#
# Запуск:
#   docker compose run --rm --build test                       # без Lighthouse
#   docker compose run --rm --build -e CHECK_LIGHTHOUSE=1 test  # + Lighthouse
#   docker run --rm mrsmargaritach:test                        # сборка внутри образа
#
# Скрипт собирает сайт сам, поэтому одинаково работает и на смонтированном
# каталоге, и на исходниках, скопированных в образ.
#
# Переменные окружения:
#   DIST             — каталог сборки (по умолчанию dist)
#   SKIP_BUILD       — 1: не пересобирать сайт, проверять готовый каталог
#   CHECK_LIGHTHOUSE — 1: дополнительно прогнать Lighthouse CI
#   CHECK_LINKS      — 1: дополнительно прогнать lychee по сборке
set -euo pipefail

DIST="${DIST:-dist}"
export LHCI_STATIC_DIST_DIR="$DIST"

step() {
    printf '\n==> %s\n' "$1"
}

step "Окружение"
hugo version
sass --version
node --version
python3 --version
lychee --version
task --version

if [ "${SKIP_BUILD:-0}" != "1" ]; then
    step "Мультисборка: основной сайт + городские поддомены → $DIST"
    bash scripts/build.sh "$DIST"
else
    step "Сборка пропущена (SKIP_BUILD=1), проверяется $DIST"
    test -f "$DIST/index.html"
fi

step "yamllint по data/"
yamllint -d "{extends: relaxed, rules: {line-length: disable}}" data/

step "YAML и front matter контента"
python3 - <<'PY'
import pathlib
import sys

import yaml

errors = []
for path in sorted(pathlib.Path("content").rglob("*.md")):
    text = path.read_text(encoding="utf-8")
    if not text.startswith("---"):
        continue
    parts = text.split("---", 2)
    if len(parts) < 3:
        errors.append(f"{path}: незакрытый front matter")
        continue
    try:
        yaml.safe_load(parts[1])
    except yaml.YAMLError as exc:
        errors.append(f"{path}: {exc}")

# Front matter городского контента лежит вне content/, общий чек его не видит.
for path in sorted(pathlib.Path("city-content").rglob("*.md")):
    text = path.read_text(encoding="utf-8")
    parts = text.split("---", 2)
    if len(parts) < 3:
        errors.append(f"{path}: незакрытый front matter")
        continue
    try:
        yaml.safe_load(parts[1])
    except yaml.YAMLError as exc:
        errors.append(f"{path}: {exc}")

if errors:
    print("\n".join(errors))
    sys.exit(1)
print("YAML и front matter валидны")
PY

step "Обязательные поля моделей"
python3 - <<'PY'
import pathlib
import sys

errors = []
for path in pathlib.Path("content/catalog").glob("*/*/index.md"):
    text = path.read_text(encoding="utf-8")
    for field in ("price:", "sizes:", "images:", "alt:"):
        if field not in text:
            errors.append(f"{path}: нет поля {field}")
if errors:
    print("\n".join(errors))
    sys.exit(1)
print("Обязательные поля на месте")
PY

step "Городские данные и сборки"
python3 - <<'PY'
import pathlib
import sys

import yaml

errors = []
cities = yaml.safe_load(pathlib.Path("data/cities.yaml").read_text(encoding="utf-8"))
required = ("code", "name", "name_in", "name_to", "prefill", "seo")
seen_codes, seen_aliases = set(), set()
for city in cities:
    code = city.get("code", "")
    for field in required:
        if not city.get(field):
            errors.append(f"{code or '?'}: нет поля {field}")
    # ready — обязательный булев флаг; false означает «не публиковать».
    if "ready" not in city or not isinstance(city["ready"], bool):
        errors.append(f"{code or '?'}: нет булева поля ready")
    if code in seen_codes:
        errors.append(f"{code}: код повторяется")
    seen_codes.add(code)
    for alias in city.get("aliases") or []:
        if alias in seen_aliases:
            errors.append(f"{alias}: алиас повторяется")
        seen_aliases.add(alias)
    for suffix in ("seo.title", "seo.description"):
        section, key = suffix.split(".")
        if not (city.get(section) or {}).get(key):
            errors.append(f"{code}: нет {suffix}")
    if not pathlib.Path(f"city-config/{code}.toml").is_file():
        errors.append(f"{code}: нет city-config/{code}.toml")
    if not pathlib.Path(f"city-content/{code}/_index.md").is_file():
        errors.append(f"{code}: нет city-content/{code}/_index.md")

if errors:
    print("\n".join(errors))
    sys.exit(1)
print(f"Города: {len(cities)} — поля и конфиги на месте")
PY

python3 scripts/sync_city_domains.py

for code in $(python3 scripts/list_domains.py --column main --domain stilgrad.ru); do
    test -f "$DIST/cities/$code/index.html"
    test -f "$DIST/cities/$code/sitemap.xml"
    test -f "$DIST/cities/$code/robots.txt"
    # Идентичные ассеты — симлинки на копию основного сайта (без дублей).
    for asset in css js photo favicon.svg .htaccess; do
        test -L "$DIST/cities/$code/$asset"
        test -e "$DIST/cities/$code/$asset"
    done
done
echo "Городские сборки на месте"

step "Open Graph"
python3 scripts/check_og.py "$DIST"

step "HTML-validate"
COUNT=$(find "$DIST" -type f -name '*.html' | wc -l | tr -d ' ')
if [ "$COUNT" -eq 0 ]; then
    echo "HTML-validate: в $DIST нет HTML-файлов"
    exit 1
fi
find "$DIST" -type f -name '*.html' -print0 | xargs -0 npx --yes html-validate@11.21.1
echo "HTML-validate: $COUNT страниц, ошибок нет"

if [ "${CHECK_LINKS:-0}" = "1" ]; then
    step "Lychee: проверка ссылок"
    lychee --root-dir "$DIST" --accept '200..299,498' \
        --user-agent "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36" \
        "$DIST"
fi

if [ "${CHECK_LIGHTHOUSE:-0}" = "1" ]; then
    step "Lighthouse CI"
    npx --yes @lhci/cli@0.16.x autorun
fi

step "Проверка результата сборки"
test -f "$DIST/index.html"
test -f "$DIST/404.html"
test -f "$DIST/sitemap.xml"
test -f "$DIST/favicon.svg"
test -f "$DIST/.htaccess"
test -f "$DIST/robots.txt"
echo "Ключевые файлы на месте"

step "Готово"
