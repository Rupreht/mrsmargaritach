#!/usr/bin/env python3
"""Сверка городской конфигурации с таблицей alias.stilgrad.md.

Единственный источник доменов — markdown-таблица `alias.stilgrad.md`:

* колонка «Основной домен» → канонический поддомен города (`code`);
* колонки «Домен по IATA» и «Человекочитаемый домен» → алиасы (301).

Скрипт проверяет, что `data/cities.yaml` описывает ровно те города и алиасы,
что в таблице, и что для каждого города есть `city-config/<code>.toml` и
`city-content/<code>/_index.md`. Ничего не пишет — только проверяет.

Запуск:
    python3 scripts/sync_city_domains.py [--table ФАЙЛ] [--cities ФАЙЛ]

Коды выхода:
    0 — конфигурация согласована с таблицей;
    1 — есть расхождения;
    2 — файл не найден или не разобран.
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path

import yaml

REPO_ROOT = Path(__file__).resolve().parent.parent
DEFAULT_TABLE = REPO_ROOT / "alias.stilgrad.md"
DEFAULT_CITIES = REPO_ROOT / "data" / "cities.yaml"

# Подписи колонок таблицы -> роли.
COLUMN_ROLES = {
    "основной домен": "main",
    "домен по iata": "iata",
    "человекочитаемый домен": "human",
}
REQUIRED_ROLES = ("main", "iata", "human")


def split_row(line: str) -> list[str]:
    """Разбивает строку markdown-таблицы на ячейки."""
    return [cell.strip().strip("*`_ ") for cell in line.strip().strip("|").split("|")]


def is_separator(cells: list[str]) -> bool:
    """Строка-разделитель вида | --- | :--- |."""
    return all(set(cell) <= set(":-") and cell for cell in cells if cell)


def host(value: str, domain: str) -> str:
    """Возвращает поддомен (метку) для хоста вида `xxx.stilgrad.ru`."""
    suffix = f".{domain}"
    value = value.strip().lower()
    if value.endswith(suffix):
        return value[: -len(suffix)]
    return value


def read_table(path: Path, domain: str) -> dict[str, dict]:
    """Читает таблицу: {канонический поддомен: {"city": ..., "aliases": [...]}}."""
    roles: dict[str, int] = {}
    city_index: int | None = None
    result: dict[str, dict] = {}

    for line in path.read_text(encoding="utf-8").splitlines():
        if not line.lstrip().startswith("|"):
            continue
        cells = split_row(line)
        lowered = [cell.lower() for cell in cells]

        if not roles:
            for label, role in COLUMN_ROLES.items():
                if label in lowered:
                    roles[role] = lowered.index(label)
            if all(role in roles for role in REQUIRED_ROLES):
                city_index = lowered.index("город") if "город" in lowered else None
            continue

        if is_separator(cells):
            continue

        main = host(cells[roles["main"]], domain)
        if not main:
            continue
        aliases = [
            host(cells[roles[role]], domain)
            for role in ("iata", "human")
            if roles[role] < len(cells) and cells[roles[role]]
        ]
        aliases = [alias for alias in dict.fromkeys(aliases) if alias and alias != main]
        name = cells[city_index] if city_index is not None else ""
        if main in result:
            raise ValueError(f"{main}: канонический домен повторяется в таблице")
        result[main] = {"city": name, "aliases": aliases}

    if not result:
        raise ValueError(f"в {path} не найдено ни одной строки города")
    return result


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="Проверяет, что data/cities.yaml согласован с alias.stilgrad.md.",
    )
    parser.add_argument("--table", type=Path, default=DEFAULT_TABLE, help="таблица доменов")
    parser.add_argument("--cities", type=Path, default=DEFAULT_CITIES, help="данные городов")
    parser.add_argument(
        "--domain",
        default="stilgrad.ru",
        help="основной домен: из хостов таблицы берётся только поддомен",
    )
    args = parser.parse_args(argv)

    try:
        table = read_table(args.table, args.domain)
        cities = yaml.safe_load(args.cities.read_text(encoding="utf-8")) or []
    except (OSError, ValueError, yaml.YAMLError) as exc:
        print(f"Не удалось прочитать конфигурацию: {exc}", file=sys.stderr)
        return 2

    errors: list[str] = []
    by_code = {city.get("code"): city for city in cities}

    for code, expected in table.items():
        city = by_code.get(code)
        if city is None:
            errors.append(f"{code}: города нет в {args.cities.name} (ждём «{expected['city']}»)")
            continue
        actual = list(city.get("aliases") or [])
        missing = [alias for alias in expected["aliases"] if alias not in actual]
        extra = [alias for alias in actual if alias not in expected["aliases"]]
        for alias in missing:
            errors.append(f"{code}: нет алиаса {alias} (есть в таблице)")
        for alias in extra:
            errors.append(f"{code}: алиас {alias} отсутствует в таблице")
        if not (REPO_ROOT / "city-config" / f"{code}.toml").is_file():
            errors.append(f"{code}: нет city-config/{code}.toml")
        if not (REPO_ROOT / "city-content" / code / "_index.md").is_file():
            errors.append(f"{code}: нет city-content/{code}/_index.md")

    for code in by_code:
        if code not in table:
            errors.append(f"{code}: города нет в {args.table.name}")

    if errors:
        print("\n".join(errors))
        return 1

    aliases_total = sum(len(item["aliases"]) for item in table.values())
    print(
        f"Города согласованы с {args.table.name}: "
        f"{len(table)} канонических доменов, {aliases_total} алиасов"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
