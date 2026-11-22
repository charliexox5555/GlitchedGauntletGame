"""Touch control icons (vault/02 Art/UI Mobile Controls.md §4).

White glyphs on transparent, tinted in Roblox with ImageColor3. Our build
style: chunky faceted shapes, chamfered / cut ends, no round caps, no
outlines. Drawn on a 64-unit grid at 16x and scaled to 256 px.

    python tools/ui/make_touch_icons.py [out_dir]   (default art-source/ui/touch)

Also writes touch_sheet.png (all icons on a dark plate) for review.
"""

import math
import sys
from pathlib import Path

from PIL import Image, ImageDraw

OUT = 256
SS = 16  # units -> pixels while drawing (64 units = 1024 px)
WHITE = (255, 255, 255, 255)
CLEAR = (0, 0, 0, 0)


def canvas():
    img = Image.new("RGBA", (64 * SS, 64 * SS), CLEAR)
    return img, ImageDraw.Draw(img)


def px(points):
    return [(x * SS, y * SS) for x, y in points]


def poly(d, points, fill=WHITE):
    d.polygon(px(points), fill=fill)


def rotate(points, deg, cx=32.0, cy=32.0):
    a = math.radians(deg)
    c, s = math.cos(a), math.sin(a)
    return [(cx + (x - cx) * c - (y - cy) * s, cy + (x - cx) * s + (y - cy) * c) for x, y in points]


def ngon(cx, cy, r, n, start=0.0):
    return [
        (cx + r * math.cos(math.radians(start + i * 360 / n)), cy + r * math.sin(math.radians(start + i * 360 / n)))
        for i in range(n)
    ]


def band(cx, cy, r0, r1, a0, a1, step=20):
    """A faceted arc band from angle a0 to a1 (degrees, clockwise on screen)."""
    n = max(1, round(abs(a1 - a0) / step))
    outer, inner = [], []
    for i in range(n + 1):
        a = math.radians(a0 + (a1 - a0) * i / n)
        outer.append((cx + r1 * math.cos(a), cy + r1 * math.sin(a)))
        inner.append((cx + r0 * math.cos(a), cy + r0 * math.sin(a)))
    return outer + inner[::-1]


def bar(x0, y0, x1, y1, c=2.0):
    """A bar with all four corners chamfered by c."""
    return [(x0 + c, y0), (x1 - c, y0), (x1, y0 + c), (x1, y1 - c), (x1 - c, y1), (x0 + c, y1), (x0, y1 - c), (x0, y0 + c)]


def limb(p0, p1, w):
    """A straight limb from p0 to p1, w units thick, square cut ends."""
    (x0, y0), (x1, y1) = p0, p1
    dx, dy = x1 - x0, y1 - y0
    n = math.hypot(dx, dy) or 1.0
    ox, oy = -dy / n * w / 2, dx / n * w / 2
    return [(x0 + ox, y0 + oy), (x1 + ox, y1 + oy), (x1 - ox, y1 - oy), (x0 - ox, y0 - oy)]


def finish(img):
    return img.resize((OUT, OUT), Image.LANCZOS)


# --- icons -------------------------------------------------------------------------


def fire():
    """A round in flight: faceted bullet over its case, three motion dashes behind."""
    img, d = canvas()
    bullet = [(32, 1), (38, 7), (40, 15), (40, 25), (24, 25), (24, 15), (26, 7)]
    case = [(23, 28), (41, 28), (41, 42), (43, 44), (43, 48), (21, 48), (21, 44), (23, 42)]
    shapes = [bullet, case]
    for x0, y0, y1 in ((22, 53, 63), (30.5, 53, 60), (39, 53, 63)):
        shapes.append([(x0, y0), (x0 + 3, y0), (x0 + 3, y1 - 1.5), (x0 + 1.5, y1), (x0, y1 - 1.5)])
    for shape in shapes:
        poly(d, rotate([(x, y * 0.92 + 1) for x, y in shape], 45, 32, 32))
    return finish(img)


def aim():
    """Scope reticle: a 16-sided ring, four cut ticks, a diamond centre."""
    img, d = canvas()
    poly(d, ngon(32, 32, 22.5, 16, 11.25))
    poly(d, ngon(32, 32, 17, 16, 11.25), CLEAR)
    for deg in (0, 90, 180, 270):
        tick = [(29.5, 3), (34.5, 3), (34.5, 15), (32, 18), (29.5, 15)]
        poly(d, rotate(tick, deg))
    poly(d, [(32, 28), (36, 32), (32, 36), (28, 32)])
    return finish(img)


def jump():
    """An up arrow with cut tips over a ground bar."""
    img, d = canvas()
    poly(d, [(32, 5), (55, 28), (55, 31), (41, 31), (41, 44), (23, 44), (23, 31), (9, 31), (9, 28)])
    poly(d, bar(10, 50, 54, 57, 3))
    return finish(img)


def sprint():
    """Two forward chevrons (our » mark), leaning forward."""
    img, d = canvas()
    for dx in (0, 17):
        poly(d, [(7 + dx, 10), (18 + dx, 10), (35 + dx, 32), (18 + dx, 54), (7 + dx, 54), (24 + dx, 32)])
    return finish(img)


def run():
    """A runner leaning into the stride (Sprint; the » chevrons stay for the stick's lock hint)."""
    img, d = canvas()
    poly(d, ngon(39, 9, 6.5, 8, 22.5))  # head
    poly(d, limb((35, 18), (27, 36), 9))  # torso, leaning forward
    poly(d, limb((27, 34), (41, 40), 7.5))  # front thigh
    poly(d, limb((41, 40), (36, 55), 7))  # front shin
    poly(d, [(32, 52), (41, 52), (41, 58), (30, 58)])  # front foot
    poly(d, limb((26, 35), (17, 47), 7.5))  # back thigh
    poly(d, limb((17, 47), (7, 41), 6.5))  # back shin
    poly(d, limb((34, 21), (45, 27), 6))  # front upper arm
    poly(d, limb((45, 27), (50, 18), 5.5))  # front forearm
    poly(d, limb((31, 21), (21, 27), 6))  # back upper arm
    poly(d, limb((21, 27), (15, 21), 5.5))  # back forearm
    return finish(img)


def slide():
    """A figure sliding feet-first along the ground, leaning back."""
    img, d = canvas()
    poly(d, ngon(18, 19, 6.5, 8, 22.5))  # head
    poly(d, [(14, 26), (23, 24), (35, 39), (35, 46), (27, 46)])  # torso, leaning back
    poly(d, [(30, 40), (56, 45), (56, 51), (29, 47)])  # front leg along the ground
    poly(d, [(33, 39), (44, 33), (47, 37), (37, 44)])  # back knee up
    poly(d, [(14, 28), (19, 30), (11, 45), (6, 43)])  # trailing arm
    poly(d, bar(4, 54, 60, 59, 2.5))  # ground
    return finish(img)


def reload():
    """Two faceted arrow bands chasing round a circle."""
    img, d = canvas()
    for start in (-60, 120):
        poly(d, band(32, 32, 15, 25, start, start + 115, 23))
        a = math.radians(start + 115)
        tip = math.radians(start + 148)
        outer = (32 + 31 * math.cos(a), 32 + 31 * math.sin(a))
        inner = (32 + 9 * math.cos(a), 32 + 9 * math.sin(a))
        point = (32 + 20 * math.cos(tip), 32 + 20 * math.sin(tip))
        poly(d, [outer, point, inner])
    return finish(img)


def scoreboard():
    """Three podium bars with cut tops."""
    img, d = canvas()
    for x0, top in ((8, 30), (26, 12), (44, 38)):
        poly(d, [(x0, top + 4), (x0 + 4, top), (x0 + 13, top), (x0 + 13, 56), (x0, 56)])
    return finish(img)


def settings():
    """An eight-tooth cog with an octagon hole."""
    img, d = canvas()
    pts = []
    for i in range(8):
        base = i * 45
        for deg, r in ((base - 16, 20), (base - 9, 28), (base + 9, 28), (base + 16, 20)):
            a = math.radians(deg)
            pts.append((32 + r * math.cos(a), 32 + r * math.sin(a)))
    poly(d, pts)
    poly(d, ngon(32, 32, 9, 8, 22.5), CLEAR)
    return finish(img)


def melee():
    """A knife on the diagonal: clipped tip, guard, grip."""
    img, d = canvas()
    poly(d, [(57, 7), (53, 18), (30, 41), (23, 34), (46, 11)])  # blade
    poly(d, [(17, 33), (21, 29), (35, 43), (31, 47)])  # guard
    poly(d, [(22, 40), (25, 43), (12, 56), (7, 56), (7, 55)])  # grip
    return finish(img)


def inspect():
    """A faceted magnifier with a cut handle (Inspect the gun)."""
    img, d = canvas()
    poly(d, ngon(26, 26, 19, 16, 11.25))
    poly(d, ngon(26, 26, 12.5, 16, 11.25), CLEAR)
    poly(d, limb((38, 38), (56, 56), 10))
    poly(d, [(26, 18), (29, 24), (35, 26), (29, 28), (26, 34), (23, 28), (17, 26), (23, 24)])  # a glint
    return finish(img)


ICONS = {
    "touch_fire": fire,
    "touch_aim": aim,
    "touch_jump": jump,
    "touch_sprint": sprint,
    "touch_run": run,
    "touch_slide": slide,
    "touch_reload": reload,
    "touch_scoreboard": scoreboard,
    "touch_settings": settings,
    "touch_melee": melee,
    "touch_inspect": inspect,
}


def sheet(images, out):
    cell = 300
    plate = Image.new("RGBA", (cell * len(images), cell + 40), (16, 20, 27, 255))
    d = ImageDraw.Draw(plate)
    for i, (name, im) in enumerate(images.items()):
        x = i * cell + (cell - OUT) // 2
        d.ellipse((i * cell + 14, 14, i * cell + cell - 14, cell - 14), fill=(38, 44, 54, 255))
        icon = im.resize((int(OUT * 0.62), int(OUT * 0.62)), Image.LANCZOS)
        off = (cell - icon.width) // 2
        plate.alpha_composite(icon, (i * cell + off, off))
        d.text((x + 10, cell + 8), name.replace("touch_", ""), fill=(200, 205, 212, 255))
    plate.save(out / "touch_sheet.png")


def main():
    out = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(__file__).resolve().parents[2] / "art-source" / "ui" / "touch"
    out.mkdir(parents=True, exist_ok=True)
    images = {}
    for name, fn in ICONS.items():
        im = fn()
        im.save(out / f"{name}.png")
        images[name] = im
    sheet(images, out)
    print(f"wrote {len(images)} icons + touch_sheet.png to {out}")


if __name__ == "__main__":
    main()
