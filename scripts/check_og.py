#!/usr/bin/env python3
"""Валидатор Open Graph-разметки собранного сайта Hugo.

Проверяет обязательные OG-теги, абсолютность URL, наличие файла og:image
в сборке и соответствие заявленных размеров фактическим.

Запуск:
    python3 scripts/check_og.py [public_dir] [--strict]

Коды выхода:
    0 — ошибок нет;
    1 — есть ошибки (или предупреждения при --strict);
    2 — каталог сборки не найден.
"""
from __future__ import annotations

import argparse
import struct
import sys
from html.parser import HTMLParser
from pathlib import Path
from urllib.parse import unquote, urlparse

REQUIRED_PROPERTIES = (
    "og:title",
    "og:description",
    "og:type",
    "og:url",
    "og:image",
    "og:site_name",
    "og:locale",
)
SUPPORTED_EXTENSIONS = {".jpg", ".jpeg", ".png", ".gif", ".webp"}
MIN_SIZE = 200  # минимум для превью Facebook
MAX_RATIO = 3.0
TARGET_SIZE = (1200, 630)


class PageMeta(HTMLParser):
    """Собирает meta-теги и canonical со страницы."""

    def __init__(self) -> None:
        super().__init__(convert_charrefs=True)
        self.properties = {}
        self.names = {}
        self.canonical = ""

    def handle_starttag(self, tag, attrs):
        attributes = {name.lower(): value or "" for name, value in attrs}
        if tag == "meta":
            content = attributes.get("content", "")
            prop = attributes.get("property", "")
            name = attributes.get("name", "")
            if prop:
                self.properties.setdefault(prop, []).append(content)
            elif name:
                self.names.setdefault(name, []).append(content)
        elif tag == "link" and attributes.get("rel", "").lower() == "canonical":
            self.canonical = attributes.get("href", "")


def absolute_url(value):
    """Возвращает разобранный URL или None, если он не абсолютный http(s)."""
    parsed = urlparse(value.strip())
    if parsed.scheme in ("http", "https") and parsed.netloc:
        return parsed
    return None


def _webp_size(handle):
    handle.seek(12)
    chunk = handle.read(8)
    if len(chunk) < 8:
        return None
    fourcc = chunk[:4]
    if fourcc == b"VP8X":
        data = handle.read(10)
        if len(data) < 10:
            return None
        width = int.from_bytes(data[4:7], "little") + 1
        height = int.from_bytes(data[7:10], "little") + 1
        return width, height
    if fourcc == b"VP8 ":
        handle.seek(26)  # RIFF (12) + заголовок чанка (8) + frame tag и start code (6)
        data = handle.read(4)
        if len(data) < 4:
            return None
        return (
            int.from_bytes(data[0:2], "little") & 0x3FFF,
            int.from_bytes(data[2:4], "little") & 0x3FFF,
        )
    if fourcc == b"VP8L":
        handle.seek(21)  # RIFF (12) + заголовок чанка (8) + сигнатура (1)
        data = handle.read(4)
        if len(data) < 4:
            return None
        bits = int.from_bytes(data, "little")
        return (bits & 0x3FFF) + 1, ((bits >> 14) & 0x3FFF) + 1
    return None


def _jpeg_size(handle):
    handle.seek(2)
    while True:
        byte = handle.read(1)
        if not byte:
            return None
        if byte != b"\xff":
            continue
        marker = handle.read(1)
        while marker == b"\xff":
            marker = handle.read(1)
        if not marker:
            return None
        code = marker[0]
        if code == 0x01 or code in (0xD8, 0xD9) or 0xD0 <= code <= 0xD7:
            continue
        raw_length = handle.read(2)
        if len(raw_length) < 2:
            return None
        length = int.from_bytes(raw_length, "big")
        if 0xC0 <= code <= 0xCF and code not in (0xC4, 0xC8, 0xCC):
            handle.read(1)  # точность
            data = handle.read(4)
            if len(data) < 4:
                return None
            height = int.from_bytes(data[0:2], "big")
            width = int.from_bytes(data[2:4], "big")
            return width, height
        handle.seek(length - 2, 1)


def image_size(path):
    """Читает фактические размеры WebP, JPEG, PNG или GIF без внешних библиотек."""
    with path.open("rb") as handle:
        head = handle.read(32)
        if head.startswith(b"\x89PNG\r\n\x1a\n") and len(head) >= 24:
            return struct.unpack(">II", head[16:24])
        if head[:6] in (b"GIF87a", b"GIF89a") and len(head) >= 10:
            return struct.unpack("<HH", head[6:10])
        if head[:4] == b"RIFF" and head[8:12] == b"WEBP":
            return _webp_size(handle)
        if head[:2] == b"\xff\xd8":
            return _jpeg_size(handle)
    return None


def find_image(public_dir, url_path):
    """Находит файл изображения в сборке с учётом subpath в baseURL."""
    path = unquote(url_path).lstrip("/")
    if not path:
        return None
    candidate = public_dir / path
    if candidate.is_file():
        return candidate
    parts = path.split("/")
    for index in range(1, len(parts)):
        candidate = public_dir.joinpath(*parts[index:])
        if candidate.is_file():
            return candidate
    return None


def check_page(page_path, public_dir):
    """Проверяет одну страницу. Возвращает (errors, warnings)."""
    parser = PageMeta()
    parser.feed(page_path.read_text(encoding="utf-8", errors="replace"))
    parser.close()

    errors = []
    warnings = []
    props = parser.properties

    for prop in REQUIRED_PROPERTIES:
        values = props.get(prop, [])
        if not values:
            errors.append('нет <meta property="%s">' % prop)
            continue
        if len(values) > 1:
            errors.append("дублируется %s (%d раза)" % (prop, len(values)))
        if not values[0].strip():
            errors.append("пустой content у %s" % prop)

    for prop, values in props.items():
        if prop.startswith("og:") and len(values) > 1 and prop not in REQUIRED_PROPERTIES:
            errors.append("дублируется %s (%d раза)" % (prop, len(values)))

    og_url = absolute_url(props.get("og:url", [""])[0])
    if props.get("og:url") and props["og:url"][0].strip() and not og_url:
        errors.append("og:url не абсолютный URL: %s" % props["og:url"][0])

    canonical = urlparse(parser.canonical) if parser.canonical else None
    if og_url and canonical and canonical.netloc and og_url.netloc != canonical.netloc:
        errors.append(
            "og:url (%s) и canonical (%s) на разных хостах" % (og_url.netloc, canonical.netloc)
        )

    image_values = props.get("og:image", [])
    og_image = absolute_url(image_values[0]) if image_values else None
    if image_values and image_values[0].strip() and not og_image:
        errors.append("og:image не абсолютный URL: %s" % image_values[0])

    declared = None
    width_values = props.get("og:image:width", [])
    height_values = props.get("og:image:height", [])
    if width_values and height_values:
        try:
            declared = (int(width_values[0]), int(height_values[0]))
        except ValueError:
            errors.append("og:image:width/height должны быть целыми числами")
    elif og_image:
        warnings.append("нет og:image:width/height — соцсети не знают пропорции превью")

    if og_image:
        if not props.get("og:image:alt", [""])[0].strip():
            warnings.append("нет og:image:alt — превью будет без описания")
        if not props.get("og:image:type", [""])[0].strip():
            warnings.append("нет og:image:type")

        page_host = (og_url or canonical).netloc if (og_url or canonical) else ""
        if page_host and og_image.netloc != page_host:
            warnings.append("og:image на другом хосте: %s" % og_image.netloc)

        extension = Path(unquote(og_image.path)).suffix.lower()
        if extension not in SUPPORTED_EXTENSIONS:
            errors.append(
                "og:image в формате %s — нужен JPG, PNG, GIF или WebP"
                % (extension or "без расширения")
            )

        image_path = find_image(public_dir, og_image.path)
        if not image_path:
            errors.append("файл og:image не найден в сборке: %s" % og_image.path)
        else:
            size = image_size(image_path)
            if not size:
                warnings.append("не удалось прочитать размеры og:image: %s" % og_image.path)
            else:
                width, height = size
                if width < MIN_SIZE or height < MIN_SIZE:
                    errors.append(
                        "og:image меньше %d×%d: %d×%d" % (MIN_SIZE, MIN_SIZE, width, height)
                    )
                elif max(width, height) / min(width, height) > MAX_RATIO:
                    errors.append("соотношение сторон og:image больше 3:1: %d×%d" % (width, height))
                if declared and declared != size:
                    errors.append(
                        "og:image:width/height (%d×%d) не совпадают с файлом (%d×%d)"
                        % (declared[0], declared[1], width, height)
                    )
                if size != TARGET_SIZE:
                    warnings.append(
                        "og:image %d×%d — рекомендуется %d×%d"
                        % (width, height, TARGET_SIZE[0], TARGET_SIZE[1])
                    )
                if image_path.suffix.lower() == ".webp":
                    warnings.append(
                        "og:image в WebP — Facebook не показывает WebP-превью, "
                        "для совместимости нужен JPG/PNG"
                    )

    twitter_card = parser.names.get("twitter:card", [""])[0].strip()
    if not twitter_card:
        warnings.append("нет twitter:card")
    else:
        twitter_image = parser.names.get("twitter:image", [""])[0].strip()
        if twitter_card == "summary_large_image" and not twitter_image:
            warnings.append("twitter:card=summary_large_image без twitter:image")
        elif twitter_image and og_image:
            if urlparse(twitter_image).path != og_image.path:
                warnings.append("twitter:image отличается от og:image")

    return errors, warnings


def main(argv):
    parser = argparse.ArgumentParser(description="Проверка Open Graph-разметки сборки Hugo.")
    parser.add_argument(
        "public_dir",
        nargs="?",
        default="public",
        help="каталог сборки Hugo (по умолчанию public)",
    )
    parser.add_argument(
        "--strict",
        action="store_true",
        help="считать предупреждения ошибками",
    )
    args = parser.parse_args(argv)

    public_dir = Path(args.public_dir)
    if not public_dir.is_dir():
        print("Каталог сборки не найден: %s" % public_dir, file=sys.stderr)
        print("Сначала соберите сайт: hugo --minify --gc", file=sys.stderr)
        return 2

    pages = sorted(public_dir.rglob("*.html"))
    if not pages:
        print("В %s нет HTML-файлов" % public_dir, file=sys.stderr)
        return 2

    errors = []
    warnings = {}
    for page in pages:
        page_name = page.relative_to(public_dir).as_posix()
        page_errors, page_warnings = check_page(page, public_dir)
        for message in page_errors:
            errors.append("%s: %s" % (page_name, message))
        for message in page_warnings:
            warnings.setdefault(message, []).append(page_name)

    for message in errors:
        print("ОШИБКА  %s" % message)
    for message, pages_with_warning in sorted(warnings.items()):
        print("ВНИМАНИЕ %s (страниц: %d)" % (message, len(pages_with_warning)))

    print()
    print(
        "Проверено страниц: %d. Ошибок: %d, предупреждений: %d."
        % (len(pages), len(errors), len(warnings))
    )
    if errors or (args.strict and warnings):
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))

