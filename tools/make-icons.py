#!/usr/bin/env python3
"""Draws the original placeholder icon set (crook and star) from flat shapes. No third-party art.
Run: python3 -I tools/make-icons.py   (needs Pillow)"""
import math, os
from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BLUE, GREEN, GOLD, CREAM = (45, 63, 115), (79, 138, 75), (246, 199, 68), (244, 234, 210)
SS = 4  # supersampling


def star(cx, cy, r_out, r_in):
    pts = []
    for i in range(10):
        a = -math.pi / 2 + i * math.pi / 5
        r = r_out if i % 2 == 0 else r_in
        pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    return pts


def crook_points():
    pts = [(50, 114 - i) for i in range(0, 69)]  # staff from y=114 up to y=46
    for i in range(1, 181):  # half circle, centre (36, 46), radius 14, right -> top -> left
        a = i * math.pi / 180.0
        pts.append((36 + 14 * math.cos(a), 46 - 14 * math.sin(a)))
    pts += [(22, 46 + i) for i in range(1, 9)]
    return pts


def hill_points(k, ox, oy, width_units=128.0, bottom=128.0):
    pts = [(ox, oy + 100 * k)]
    for i in range(0, 65):
        t = i / 64.0
        y = (1 - t) ** 2 * 100 + 2 * (1 - t) * t * 76 + t * t * 100
        pts.append((ox + width_units * t * k, oy + y * k))
    pts += [(ox + width_units * k, oy + bottom * k), (ox, oy + bottom * k)]
    return pts


def draw_fg(d, k, ox, oy):
    d.polygon([(ox + x * k, oy + y * k) for x, y in star(88, 40, 20, 8.5)], fill=GOLD)
    w = 9 * k
    for x, y in crook_points():
        px, py = ox + x * k, oy + y * k
        d.ellipse([px - w / 2, py - w / 2, px + w / 2, py + w / 2], fill=CREAM)


def render(size, bg=True, fg=True, tile=False, scale=1.0):
    """Square image of `size` px with the 128-unit design scaled by `scale` around the centre."""
    big = size * SS
    img = Image.new("RGBA", (big, big), BLUE + (255,) if bg else (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    k = big / 128.0 * scale
    off = (big - 128 * k) / 2.0
    if bg:
        d.polygon(hill_points(k, off, off), fill=GREEN)
    if fg:
        draw_fg(d, k, off, off)
    if tile:
        mask = Image.new("L", (big, big), 0)
        ImageDraw.Draw(mask).rounded_rectangle([4 * k, 4 * k, 124 * k, 124 * k], radius=24 * k, fill=255)
        img.putalpha(mask)
    return img.resize((size, size), Image.LANCZOS)


def save(img, rel):
    path = os.path.join(ROOT, rel)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.save(path)


def main():
    # Legacy square launcher icons (rounded tile on transparent).
    for name, px in (("mdpi", 48), ("hdpi", 72), ("xhdpi", 96), ("xxhdpi", 144), ("xxxhdpi", 192)):
        save(render(px, tile=True), f"icons/launcher-{name}-{px}.png")
    main192 = render(192, tile=True)
    save(main192, "icons/launcher-main-192.png")
    # Adaptive: background full bleed, foreground inside the centre safe zone (66%).
    save(render(432, fg=False, bg=True), "icons/launcher-adaptive-background-432.png")
    save(render(432, bg=False, fg=True, scale=0.62), "icons/launcher-adaptive-foreground-432.png")
    # Monochrome (themed icon): the same shapes in one colour.
    mono = render(432, bg=False, fg=True, scale=0.62)
    alpha = mono.getchannel("A")
    mono_img = Image.new("RGBA", mono.size, (255, 255, 255, 0))
    mono_img.putalpha(alpha)
    save(mono_img, "icons/launcher-adaptive-monochrome-432.png")
    # Android template resources.
    res = "android/build/res"
    for dens, px, fgpx in (("mdpi", 48, 108), ("hdpi", 72, 162), ("xhdpi", 96, 216), ("xxhdpi", 144, 324), ("xxxhdpi", 192, 432)):
        save(render(px, tile=True), f"{res}/mipmap-{dens}-v4/icon.webp")
        save(render(fgpx, bg=False, fg=True, scale=0.62), f"{res}/mipmap-{dens}-v4/icon_foreground.webp")
    save(main192, f"{res}/mipmap/icon.webp")
    save(render(432, bg=False, fg=True, scale=0.62), f"{res}/mipmap/icon_foreground.webp")
    save(render(432, fg=False, bg=True), f"{res}/mipmap/icon_background.webp")
    save(render(432, bg=False, fg=True, scale=0.62), f"{res}/drawable/splash_icon.webp")
    # TV banner 320x180: blue and hill, the crook and star centred.
    w, h = 320, 180
    k = 1.2 * SS
    big = Image.new("RGBA", (w * SS, h * SS), BLUE + (255,))
    d = ImageDraw.Draw(big)
    d.rectangle([0, 128 * SS, w * SS, h * SS], fill=GREEN)
    ox, oy = (w * SS - 128 * k) / 2.0, (h * SS - 128 * k) / 2.0
    d.polygon([(0, 128 * SS), (w * SS, 128 * SS), (w * SS, 118 * SS), (w * SS / 2, 100 * SS), (0, 118 * SS)], fill=GREEN)
    draw_fg(d, k, ox, oy)
    save(big.resize((w, h), Image.LANCZOS).convert("RGB"), f"{res}/drawable-xhdpi/banner.png")


if __name__ == "__main__":
    main()
