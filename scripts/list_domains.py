#!/usr/bin/env python3
"""Вывод уникальных доменов из markdown-таблицы alias.stilgrad.md.

Скрипт читает таблицу городов и собирает домены из колонок, в заголовке
которых есть слово «домен» («Домен по IATA», «Человекочитаемый домен»,
«Основной домен»). Пустые ячейки и прочерки игнорируются, повторы
схлопываются: `moscow.stilgrad.ru` встречается и как человекочитаемый,
и как основной домен — в выводе он будет один раз.

Запуск:
    python3 scripts/list_domains.py [ФАЙЛ] [--column {iata,human,main} ...]
                                    [--domain stilgrad.ru] [--sort]

    ФАЙЛ                — путь к таблице (по умолчанию alias.stilgrad.md
                          в корне репозитория);
    --column, -c        — какие колонки читать (можно указать несколько раз);
                          по умолчанию — все колонки с доменами;
    --domain, -d        — оставить только поддомены этой зоны и вывести сами
                          метки (`moscow.stilgrad.ru` → `moscow`); используется
                          при сборке городов;
    --sort, -s          — сортировать по алфавиту вместо порядка в таблице.

Коды выхода:
    0 — домены найдены и выведены;
    1 — в таблице не найдено ни одного домена;
    2 — файл не найден или его не удалось прочитать.
"""
from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
DEFAULT_TABLE = REPO_ROOT / "alias.stilgrad.md"

# Подписи колонок -> ключи для --column.
COLUMN_KEYS = {
    "iata": "iata",
    "человекочитаемый": "human",
    "основной": "main",
}

# Домен: метки, разделённые точками, без пробелов и кириллицы.
DOMAIN_RE = re.compile(
    r"(?<![\w.-])(?:[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z]{2,24}(?![\w.-])",
    re.IGNORECASE,
)


def split_row(line: str) -> list[str]:
    """Разбивает строку markdown-таблицы на ячейки."""
    cells = line.strip().strip("|").split("|")
    return [cell.strip().strip("*`_ ") for cell in cells]


def is_separator(cells: list[str]) -> bool:
    """Строка-разделитель вида | --- | :--- |."""
    return all(re.fullmatch(r":?-{3,}:?", cell) for cell in cells if cell)


def domain_columns(header: list[str], wanted: list[str] | None) -> list[int]:
    """Индексы колонок с доменами (с учётом фильтра --column)."""
    indexes = []
    for index, label in enumerate(header):
        lowered = label.lower()
        if "домен" not in lowered:
            continue
        if wanted:
            keys = {
                COLUMN_KEYS[prefix]
                for prefix in COLUMN_KEYS
                if prefix in lowered
            }
            if not keys & set(wanted):
                continue
        indexes.append(index)
    return indexes


def collect_domains(path: Path, wanted: list[str] | None) -> list[str]:
    """Уникальные домены в порядке появления в таблице."""
    seen: dict[str, None] = {}
    columns: list[int] | None = None
    for line in path.read_text(encoding="utf-8").splitlines():
        if not line.lstrip().startswith("|"):
            continue
        cells = split_row(line)
        if columns is None:
            if "домен" not in " ".join(cells).lower():
                continue  # ещё не дошли до шапки таблицы
            columns = domain_columns(cells, wanted)
            continue
        if is_separator(cells):
            continue
        for index in columns:
            if index >= len(cells):
                continue
            for domain in DOMAIN_RE.findall(cells[index]):
                seen.setdefault(domain.lower(), None)
    return list(seen)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="Выводит уникальные домены из markdown-таблицы alias.stilgrad.md.",
    )
    parser.add_argument(
        "path",
        nargs="?",
        type=Path,
        default=DEFAULT_TABLE,
        help=f"таблица с доменами (по умолчанию {DEFAULT_TABLE.name})",
    )
    parser.add_argument(
        "-c",
        "--column",
        action="append",
        choices=sorted(COLUMN_KEYS.values()),
        help="колонка: iata (по коду IATA), human (человекочитаемая), "
        "main (основная); можно указать несколько раз",
    )
    parser.add_argument(
        "-d",
        "--domain",
        help="оставить только поддомены этой зоны и вывести сами метки",
    )
    parser.add_argument(
        "-s",
        "--sort",
        action="store_true",
        help="сортировать домены по алфавиту",
    )
    args = parser.parse_args(argv)

    try:
        domains = collect_domains(args.path, args.column)
    except OSError as exc:
        print(f"Не удалось прочитать {args.path}: {exc}", file=sys.stderr)
        return 2

    if args.domain:
        suffix = "." + args.domain.strip(".")
        domains = [
            domain[: -len(suffix)] for domain in domains if domain.endswith(suffix)
        ]

    if not domains:
        print(f"В {args.path} не найдено ни одного домена", file=sys.stderr)
        return 1

    if args.sort:
        domains.sort()
    print("\n".join(domains))
    return 0


if __name__ == "__main__":
    sys.exit(main())
