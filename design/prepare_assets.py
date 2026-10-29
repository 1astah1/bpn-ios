#!/usr/bin/env python3
"""Ресурсы приложения из баннера «Включи BPN» (~/banners): 3D-шестигранник, шрифты Geist, иконка.
Запуск: python3 design/prepare_assets.py — результат кладётся в App/Resources (и коммитится)."""
import pathlib
import shutil

from PIL import Image, ImageDraw, ImageFilter

ROOT = pathlib.Path(__file__).resolve().parent.parent
BANNERS = pathlib.Path.home() / "banners"
SPRITES = BANNERS / "bpn" / "out" / "sprites"
RES = ROOT / "App" / "Resources"

KNOB_PX = 300          # шестигранник ~100 pt на @3x
SPIN_STEP = 3          # из 120 кадров оборота берём каждый третий → 40 кадров
FONTS = ["Geist-Medium.ttf", "Geist-SemiBold.ttf", "Geist-Bold.ttf", "Geist-Black.ttf",
         "GeistMono-Medium.ttf", "GeistMono-Bold.ttf"]


def save_png(image: Image.Image, path: pathlib.Path) -> None:
    # Без палитры: квантование даёт рябь на гранях 3D, а полный RGBA на 300 px — всего ~35 КБ кадр.
    image.save(path, optimize=True)


def hex_frames() -> None:
    out = RES / "Hex"
    shutil.rmtree(out, ignore_errors=True)
    out.mkdir(parents=True)
    spin = sorted((SPRITES / "spin").glob("*.png"))[::SPIN_STEP]
    for index, path in enumerate(spin):
        save_png(Image.open(path).convert("RGBA").resize((KNOB_PX, KNOB_PX), Image.LANCZOS), out / f"spin_{index:02d}.png")
    # lit: дуги Wi-Fi загораются по одной, 0 — все серые, 4 — все синие.
    for index, path in enumerate(sorted((SPRITES / "lit").glob("*.png"))):
        save_png(Image.open(path).convert("RGBA").resize((KNOB_PX, KNOB_PX), Image.LANCZOS), out / f"lit_{index}.png")


def fonts() -> None:
    out = RES / "Fonts"
    out.mkdir(parents=True, exist_ok=True)
    for name in FONTS:
        shutil.copy(BANNERS / "fonts" / name, out / name)
    shutil.copy(BANNERS / "fonts" / "geist_src" / "geist-font" / "OFL.txt", out / "Geist-OFL.txt")


def app_icon() -> None:
    size = 1024
    # Фон как у аватарки бота: королевский синий с мягким светом сверху.
    icon = Image.new("RGBA", (size, size))
    draw = ImageDraw.Draw(icon)
    top, bottom = (31, 102, 214), (0, 62, 150)
    for y in range(size):
        t = y / (size - 1)
        draw.line([(0, y), (size, y)], fill=tuple(round(a + (b - a) * t) for a, b in zip(top, bottom)) + (255,))
    glow = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    ImageDraw.Draw(glow).ellipse([size * 0.18, size * 0.12, size * 0.82, size * 0.76], fill=(120, 170, 255, 90))
    icon.alpha_composite(glow.filter(ImageFilter.GaussianBlur(120)))

    hexagon = Image.open(SPRITES / "lit" / "004.png").convert("RGBA")
    box = hexagon.getbbox()
    hexagon = hexagon.crop(box)
    scale = size * 0.66 / max(hexagon.size)
    hexagon = hexagon.resize((round(hexagon.width * scale), round(hexagon.height * scale)), Image.LANCZOS)
    shadow = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    offset = ((size - hexagon.width) // 2, (size - hexagon.height) // 2 + 18)
    shadow.paste((0, 20, 60, 140), offset, hexagon.split()[3])
    icon.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(28)))
    icon.alpha_composite(hexagon, ((size - hexagon.width) // 2, (size - hexagon.height) // 2))

    iconset = RES / "Assets.xcassets" / "AppIcon.appiconset"
    icon.convert("RGB").save(iconset / "icon-1024.png", optimize=True)
    (iconset / "Contents.json").write_text(
        '{\n  "images" : [\n    { "filename" : "icon-1024.png", "idiom" : "universal", "platform" : "ios", "size" : "1024x1024" }\n'
        '  ],\n  "info" : { "author" : "xcode", "version" : 1 }\n}\n'
    )


if __name__ == "__main__":
    hex_frames()
    fonts()
    app_icon()
    total = sum(p.stat().st_size for p in RES.rglob("*") if p.is_file())
    print(f"готово, ресурсы приложения: {total // 1024} КБ")
