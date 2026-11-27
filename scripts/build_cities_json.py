#!/usr/bin/env python3
"""Генерирует cities.json — список городов для CDN и переключателя в подвале.

Источник — data/cities.yaml (единственный источник фактов). На CDN файл лежит
один раз (cdn.<domain>/cities.json), все хосты читают его через JS.

Запуск:
    python3 scripts/build_cities_json.py [--out PATH] [--cities FILE] [--domain stilgrad.ru]

Коды выхода:
    0 — файл записан;
    2 — исходный файл не найден или не разобран.
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

import yaml

REPO_ROOT = Path(__file__).resolve().parent.parent
DEFAULT_CITIES = REPO_ROOT / "data" / "cities.yaml"


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Генерирует cities.json из data/cities.yaml.")
    parser.add_argument("--out", type=Path, required=True, help="куда записать JSON")
    parser.add_argument("--cities", type=Path, default=DEFAULT_CITIES, help="данные городов")
    parser.add_argument("--domain", default="stilgrad.ru", help="основной домен")
    args = parser.parse_args(argv)

    try:
        cities = yaml.safe_load(args.cities.read_text(encoding="utf-8")) or []
    except (OSError, yaml.YAMLError) as exc:
        print(f"Не удалось прочитать {args.cities}: {exc}", file=sys.stderr)
        return 2

    result = []
    for city in cities:
        code = city.get("code")
        if not code:
            continue
        result.append(
            {
                "code": code,
                "name": city.get("name") or code,
                "url": f"https://{code}.{args.domain}/",
                "ready": bool(city.get("ready", False)),
            }
        )

    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(
        json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    print(f"cities.json: {len(result)} городов → {args.out}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
