#!/usr/bin/env python3
"""Урезанные geoip.dat / geosite.dat для VPN-расширения.

Полные файлы весят ~25 МБ и не влезают в ~50 МБ памяти расширения iOS. Берём из релизов v2fly
только категории, на которые ссылаются правила подписки, — остальные ссылки приложение вырезает
из конфига перед запуском (Shared/GeoData.swift). Списки категорий здесь и там должны совпадать.

Запуск: python3 scripts/build-geodata.py  (без зависимостей, формат protobuf разбирается вручную)
"""
import pathlib
import urllib.request

GEOSITE = ["CATEGORY-RU", "CATEGORY-GOV-RU", "PRIVATE", "YANDEX", "VK", "MAILRU"]
GEOIP = ["RU", "PRIVATE"]

SOURCES = {
    "geosite.dat": ("https://github.com/v2fly/domain-list-community/releases/latest/download/dlc.dat", GEOSITE),
    "geoip.dat": ("https://github.com/v2fly/geoip/releases/latest/download/geoip.dat", GEOIP),
}
OUT_DIR = pathlib.Path(__file__).resolve().parent.parent / "PacketTunnel" / "Resources"


def read_varint(data: bytes, pos: int) -> tuple[int, int]:
    result = shift = 0
    while True:
        byte = data[pos]
        pos += 1
        result |= (byte & 0x7F) << shift
        shift += 7
        if byte < 0x80:
            return result, pos


def entries(data: bytes):
    """GeoSiteList / GeoIPList: repeated поле 1, в каждом записи поле 1 — код категории."""
    pos = 0
    while pos < len(data):
        start = pos
        key, pos = read_varint(data, pos)
        if key != 0x0A:
            raise ValueError(f"неожиданный ключ {key:#x} на позиции {start}")
        length, pos = read_varint(data, pos)
        message = data[pos:pos + length]
        pos += length
        _, inner = read_varint(message, 0)
        code_length, inner = read_varint(message, inner)
        yield message[inner:inner + code_length].decode(), data[start:pos]


def main() -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    for name, (url, wanted) in SOURCES.items():
        with urllib.request.urlopen(url, timeout=60) as response:
            data = response.read()
        kept = {code: raw for code, raw in entries(data) if code in wanted}
        missing = sorted(set(wanted) - kept.keys())
        if missing:
            raise SystemExit(f"{name}: в источнике нет категорий {missing}")
        out = b"".join(kept[code] for code in wanted)
        (OUT_DIR / name).write_bytes(out)
        print(f"{name}: {len(out) // 1024} КБ, категории {', '.join(wanted)}")


if __name__ == "__main__":
    main()
