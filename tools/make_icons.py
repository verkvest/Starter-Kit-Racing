#!/usr/bin/env python3
"""Original Veldash icons and splash. Shapes only, no embedded font."""

from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
INK = (20, 52, 60, 255)
INK_DEEP = (16, 32, 39, 255)
AMBER = (240, 162, 2, 255)
CREAM = (246, 241, 231, 255)
YELLOW = (242, 196, 48, 255)
RED = (196, 64, 48, 255)
WHEEL = (28, 32, 36, 255)

IOS = [1024, 180, 167, 152, 136, 128, 120, 114, 87, 80, 76, 60, 58, 40]


def truck(draw: ImageDraw.ImageDraw, box, scale: float) -> None:
    x0, y0, x1, y1 = box
    w = x1 - x0
    h = y1 - y0
    body = (x0 + w * 0.08, y0 + h * 0.38, x0 + w * 0.78, y0 + h * 0.72)
    cabin = (x0 + w * 0.48, y0 + h * 0.16, x0 + w * 0.78, y0 + h * 0.40)
    draw.rounded_rectangle(body, radius=max(2, int(10 * scale)), fill=YELLOW)
    draw.rounded_rectangle(cabin, radius=max(2, int(8 * scale)), fill=YELLOW)
    window = (x0 + w * 0.54, y0 + h * 0.22, x0 + w * 0.74, y0 + h * 0.36)
    draw.rounded_rectangle(window, radius=max(1, int(4 * scale)), fill=CREAM)
    r = h * 0.16
    for cx in (x0 + w * 0.28, x0 + w * 0.66):
        cy = y0 + h * 0.74
        draw.ellipse((cx - r, cy - r, cx + r, cy + r), fill=WHEEL)
        hub = r * 0.42
        draw.ellipse((cx - hub, cy - hub, cx + hub, cy + hub), fill=CREAM)


def chevron(draw: ImageDraw.ImageDraw, cx: float, cy: float, s: float, color) -> None:
    draw.polygon(
        [
            (cx - s * 0.55, cy - s * 0.42),
            (cx + s * 0.05, cy),
            (cx - s * 0.55, cy + s * 0.42),
            (cx - s * 0.28, cy),
        ],
        fill=color,
    )


def mark(size: int, background, with_bg: bool = True) -> Image.Image:
    img = Image.new("RGBA", (size, size), background if with_bg else (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    m = size * 0.08
    if with_bg:
        d.rounded_rectangle((m, m, size - m, size - m), radius=size * 0.18, fill=INK)
    cx = size * 0.5
    cy = size * 0.46
    rad = size * 0.34
    d.ellipse((cx - rad, cy - rad, cx + rad, cy + rad), outline=AMBER, width=max(2, size // 48))
    chevron(d, cx - size * 0.16, cy - size * 0.02, size * 0.22, CREAM)
    chevron(d, cx + size * 0.02, cy - size * 0.02, size * 0.22, AMBER)
    truck(d, (size * 0.22, size * 0.50, size * 0.78, size * 0.84), size / 1024)
    return img


def flatten(img: Image.Image, color) -> Image.Image:
    base = Image.new("RGB", img.size, color[:3])
    base.paste(img, mask=img.split()[-1])
    return base


def mono(size: int) -> Image.Image:
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    cx = size * 0.5
    cy = size * 0.42
    rad = size * 0.30
    d.ellipse((cx - rad, cy - rad, cx + rad, cy + rad), outline=(255, 255, 255, 255), width=max(2, size // 40))
    chevron(d, cx - size * 0.08, cy, size * 0.28, (255, 255, 255, 255))
    return img


def splash() -> Image.Image:
    w, h = 1280, 720
    img = Image.new("RGB", (w, h), INK[:3])
    d = ImageDraw.Draw(img)
    d.rounded_rectangle((80, 70, 1200, 650), radius=48, outline=AMBER[:3], width=8)
    # Block letters VELDASH, 5x7, hand-placed.
    glyphs = {
        "V": ["10001", "10001", "10001", "10001", "10001", "01010", "00100"],
        "E": ["11111", "10000", "10000", "11110", "10000", "10000", "11111"],
        "L": ["10000", "10000", "10000", "10000", "10000", "10000", "11111"],
        "D": ["11110", "10001", "10001", "10001", "10001", "10001", "11110"],
        "A": ["01110", "10001", "10001", "11111", "10001", "10001", "10001"],
        "S": ["01111", "10000", "10000", "01110", "00001", "00001", "11110"],
        "H": ["10001", "10001", "10001", "11111", "10001", "10001", "10001"],
    }
    word = "VELDASH"
    cell = 18
    gap = 16
    letter_w = 5 * cell
    total = len(word) * letter_w + (len(word) - 1) * gap
    x = (w - total) // 2
    y = 210
    for ch in word:
        rows = glyphs[ch]
        for ry, row in enumerate(rows):
            for rx, bit in enumerate(row):
                if bit == "1":
                    d.rounded_rectangle(
                        (x + rx * cell, y + ry * cell, x + rx * cell + cell - 3, y + ry * cell + cell - 3),
                        radius=3,
                        fill=CREAM[:3],
                    )
        x += letter_w + gap
    d.rectangle((440, 430, 840, 446), fill=AMBER[:3])
    # Small truck under the bar.
    badge = mark(280, INK, with_bg=False)
    img.paste(flatten(badge, INK), (500, 460), badge)
    return img


def main() -> None:
    icons = ROOT / "icons"
    icons.mkdir(exist_ok=True)
    master = mark(1024, INK, True)
    opaque = flatten(master, INK)
    opaque.save(ROOT / "icon.png", "PNG")
    opaque.save(icons / "icon_1024x1024.png", "PNG")
    for side in IOS:
        flatten(master.resize((side, side), Image.Resampling.LANCZOS), INK).save(icons / f"icon_{side}.png", "PNG")
    flatten(master.resize((192, 192), Image.Resampling.LANCZOS), INK).save(icons / "icon_192.png", "PNG")
    # Adaptive icons: content stays inside the center 66%.
    fg = Image.new("RGBA", (432, 432), (0, 0, 0, 0))
    inner = mark(280, INK, True)
    fg.paste(inner, (76, 76), inner)
    fg.save(icons / "adaptive_foreground.png", "PNG")
    Image.new("RGB", (432, 432), INK[:3]).save(icons / "adaptive_background.png", "PNG")
    mono(432).save(icons / "adaptive_monochrome.png", "PNG")
    splash().save(ROOT / "splash-screen.png", "PNG")
    print("icons written")


if __name__ == "__main__":
    main()
