"""Top bar v2 images (vault/02 Art/UI Top Bar Draft.md, "v2").

Team blocks are white 9-slice images tinted with ImageColor3: small rounded
outer corners, the inner edge slanted like the brand slash, a baked top-to-
bottom shade (no bottom lip). Plus a stopwatch icon.
Images are drawn at 2x the screen size (SliceScale 0.5) and 4x supersampled.

    python tools/ui/make_topbar_v2_images.py <out_dir>
"""

import math
import sys
from pathlib import Path

from PIL import Image, ImageDraw

SS = 4
H = 160  # 2x of the 80 px block
W = 220
R = 12  # 2x of a 6 px outer radius
SLANT = 40  # 2x of 20 px across the full height
LIP = 0  # no bottom lip: it could not follow the slant and read as a notch (owner, 2026-11-14)


def block(slant_side: str) -> Image.Image:
    w, h, r, s = W * SS, H * SS, R * SS, SLANT * SS
    pts = []

    def arc(cx, cy, a0, a1):
        for i in range(17):
            a = math.radians(a0 + (a1 - a0) * i / 16)
            pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))

    if slant_side == "right":
        arc(r, r, 180, 270)
        pts += [(w, 0), (w - s, h)]
        arc(r, h - r, 90, 180)
    else:
        pts += [(0, 0)]
        arc(w - r, r, 270, 360)
        arc(w - r, h - r, 0, 90)
        pts += [(s, h)]
    mask = Image.new("L", (w, h), 0)
    ImageDraw.Draw(mask).polygon(pts, fill=255)
    # shade: white at the top to 80% at the bottom
    shade = Image.new("RGB", (w, h))
    d = ImageDraw.Draw(shade)
    for y in range(h):
        t = y / h
        v = int(255 - (255 - 205) * t)
        d.line([(0, y), (w, y)], fill=(v, v, v))
    # a 1 px lit line along the top (2 px at 2x)
    d.rectangle([0, 0, w, 2 * SS], fill=(255, 255, 255))
    img = shade.convert("RGBA")
    img.putalpha(mask)
    return img.resize((W, H), Image.LANCZOS)


def stopwatch(size=64) -> Image.Image:
    big = size * SS
    img = Image.new("RGBA", (big, big), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    c = big / 2
    cy = c + 4 * SS
    ro = 24 * SS
    t = 7 * SS
    d.ellipse([c - ro, cy - ro, c + ro, cy + ro], fill=(255, 255, 255, 255))
    d.ellipse([c - ro + t, cy - ro + t, c + ro - t, cy + ro - t], fill=(0, 0, 0, 0))
    # crown + side button
    d.rectangle([c - 7 * SS, cy - ro - 9 * SS, c + 7 * SS, cy - ro - 3 * SS], fill=(255, 255, 255, 255))
    d.rectangle([c - 3 * SS, cy - ro - 4 * SS, c + 3 * SS, cy - ro + 2 * SS], fill=(255, 255, 255, 255))
    # hand to "two o'clock"
    a = math.radians(-50)
    hx, hy = c + math.cos(a) * 13 * SS, cy + math.sin(a) * 13 * SS
    d.line([(c, cy), (hx, hy)], fill=(255, 255, 255, 255), width=6 * SS)
    d.ellipse([c - 4 * SS, cy - 4 * SS, c + 4 * SS, cy + 4 * SS], fill=(255, 255, 255, 255))
    return img.resize((size, size), Image.LANCZOS)


def main():
    out = Path(sys.argv[1] if len(sys.argv) > 1 else ".")
    out.mkdir(parents=True, exist_ok=True)
    block("right").save(out / "team_block_slant_right.png")
    block("left").save(out / "team_block_slant_left.png")
    stopwatch().save(out / "icon_stopwatch.png")
    print("ok")


if __name__ == "__main__":
    main()


def cap(slant_side: str) -> Image.Image:
    """The slanted inner end of a team block, drawn at a fixed size (no 9-slice,
    which squashed the slant into a step). 28 x 80 on screen: an 8 px straight
    part that overlaps the block body's rounded corners, then a 20 px slant.
    Same top-to-bottom shade as the body's UIGradient (white to 205)."""
    w, h = 56 * SS, 160 * SS
    straight, s = 16 * SS, 40 * SS
    if slant_side == "right":
        pts = [(0, 0), (w, 0), (straight, h), (0, h)]
    else:
        pts = [(0, 0), (w, 0), (w, h), (w - straight, h)]
    mask = Image.new("L", (w, h), 0)
    ImageDraw.Draw(mask).polygon(pts, fill=255)
    shade = Image.new("RGB", (w, h))
    d = ImageDraw.Draw(shade)
    for y in range(h):
        v = int(255 - (255 - 205) * (y / h))
        d.line([(0, y), (w, y)], fill=(v, v, v))
    img = shade.convert("RGBA")
    img.putalpha(mask)
    return img.resize((56, 160), Image.LANCZOS)


if __name__ == "__main__" and len(sys.argv) > 1:
    out = Path(sys.argv[1])
    cap("right").save(out / "team_cap_slant_right.png")
    cap("left").save(out / "team_cap_slant_left.png")
    print("caps ok")
