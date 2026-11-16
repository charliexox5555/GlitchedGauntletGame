"""The shared backdrop for every Mod card (vault/02 Art/UI Art Brief (ChatGPT).md → Card art v2).

    python tools/ui/make_card_backdrop.py

One plate, the same behind all 12 cards (owner 2026-11-17: "they all look exactly the same, a simple
backdrop"). Theme "Gauntlet stage": a dark slate room, a floor plane with a soft lit edge, a big
cut-corner panel behind the subject (our UI plate: one 45° cut on the top right, a lit top edge, a
hairline), a faint diagonal slash (the brand mark), a soft neutral pool of light where the subject
stands, and the bottom 35% fading dark for the card's text. No colour: each card adds its own light.

Writes art-source/ui/chatgpt/card_backdrop.png (1024 x 768) and card_backdrop_example.png (the same
plate with a sample subject light, to show how a card's colour sits on it).
"""

import os

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "art-source", "ui", "chatgpt")
W, H = 1024, 768
K = 2  # drawn at 2x
SW, SH = W * K, H * K

TOP = np.array((42, 49, 59), float)      # #2A313B slate
BOTTOM = np.array((20, 24, 30), float)   # #14181E charcoal
FLOOR = np.array((30, 35, 43), float)
PANEL = np.array((34, 40, 49), float)    # a step lighter than the wall behind it
TEXT_DARK = np.array((18, 21, 26), float)  # #12151A


def lerp(a, b, t):
    return a + (b - a) * t


def build(light=None):
    y = np.linspace(0, 1, SH)[:, None, None]
    img = lerp(TOP, BOTTOM, y) * np.ones((SH, SW, 3))
    horizon = int(SH * 0.60)
    # the floor plane: a slightly lighter band below the horizon, darkening toward the viewer
    fy = np.linspace(0, 1, SH - horizon)[:, None, None]
    img[horizon:] = lerp(FLOOR, BOTTOM, fy ** 0.8) * np.ones((SH - horizon, SW, 3))
    base = Image.fromarray(np.clip(img, 0, 255).astype("uint8"))
    d = ImageDraw.Draw(base, "RGBA")
    # a second, bigger and darker plate further back, cut on the other side (depth)
    bx0, by0, bx1 = int(SW * 0.12), int(SH * 0.04), int(SW * 0.66)
    bcut = int(SW * 0.07)
    back = [(bx0 + bcut, by0), (bx1, by0), (bx1, horizon), (bx0, horizon), (bx0, by0 + bcut)]
    d.polygon(back, fill=(27, 32, 40, 255))
    d.line([(bx0, by0 + bcut), (bx0 + bcut, by0), (bx1, by0)], fill=(255, 255, 255, 18), width=2 * K)
    # the floor's tile grid, very faint, converging to the middle of the horizon
    for i in range(-9, 10):
        d.line([(SW * 0.5 + i * SW * 0.035, horizon), (SW * 0.5 + i * SW * 0.16, SH)], fill=(255, 255, 255, 7), width=K)
    for j in range(1, 7):
        yy0 = horizon + (SH - horizon) * (j / 7) ** 1.7
        d.line([(0, yy0), (SW, yy0)], fill=(255, 255, 255, 6), width=K)
    # the panel behind the subject: our UI plate (one 45° cut, top right)
    px0, py0, px1, py1 = int(SW * 0.30), int(SH * 0.13), int(SW * 0.84), horizon
    cut = int(SW * 0.06)
    plate = [(px0, py0), (px1 - cut, py0), (px1, py0 + cut), (px1, py1), (px0, py1)]
    d.polygon(plate, fill=tuple(int(v) for v in PANEL) + (255,))
    # its lit top edge and a hairline round it
    d.line([(px0, py0), (px1 - cut, py0), (px1, py0 + cut)], fill=(255, 255, 255, 46), width=3 * K)
    d.line(plate + [plate[0]], fill=(255, 255, 255, 22), width=K)
    # the brand slash: one faint diagonal band across the panel
    s0 = int(SW * 0.58)
    slash = [(s0, py0), (s0 + int(SW * 0.06), py0), (s0 - int(SW * 0.10), py1), (s0 - int(SW * 0.16), py1)]
    d.polygon(slash, fill=(255, 255, 255, 9))
    # the floor's lit edge at the horizon and a faint seam toward the viewer
    d.line([(0, horizon), (SW, horizon)], fill=(255, 255, 255, 30), width=2 * K)
    # a soft neutral pool of light where the subject stands, and its colour light (examples only)
    pool = Image.new("L", (SW, SH), 0)
    pd = ImageDraw.Draw(pool)
    cx, cy = SW * 0.5, horizon + SH * 0.03
    pd.ellipse((cx - SW * 0.22, cy - SH * 0.045, cx + SW * 0.22, cy + SH * 0.045), fill=60)
    pool = pool.filter(ImageFilter.GaussianBlur(28 * K))
    tint = light or (255, 255, 255)
    base = Image.composite(Image.new("RGB", (SW, SH), tint), base, pool)
    if light:
        back = Image.new("L", (SW, SH), 0)
        ImageDraw.Draw(back).ellipse((SW * 0.30, SH * 0.12, SW * 0.70, SH * 0.62), fill=70)
        back = back.filter(ImageFilter.GaussianBlur(60 * K))
        base = Image.composite(Image.new("RGB", (SW, SH), light), base, back)
    # the bottom 35% fades to the text dark; a soft vignette
    arr = np.array(base).astype(float)
    yy = np.linspace(0, 1, SH)[:, None]
    fade = np.clip((yy - 0.65) / 0.35, 0, 1) ** 1.2
    arr = arr * (1 - fade[..., None]) + TEXT_DARK * fade[..., None]
    xx = np.linspace(-1, 1, SW)[None, :]
    vig = 1 - 0.28 * np.clip(xx ** 2 + ((yy - 0.45) * 1.6) ** 2 - 0.35, 0, 1)
    arr = arr * vig[..., None]
    out = Image.fromarray(np.clip(arr, 0, 255).astype("uint8")).resize((W, H), Image.LANCZOS)
    return out


def main():
    os.makedirs(OUT, exist_ok=True)
    build().save(os.path.join(OUT, "card_backdrop.png"))
    build((255, 140, 60)).save(os.path.join(OUT, "card_backdrop_example.png"))
    print("ok")


if __name__ == "__main__":
    main()
