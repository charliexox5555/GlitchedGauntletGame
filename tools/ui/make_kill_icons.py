"""Kill pop emblems and its ring (vault/02 Art/UI Feed and Spectate.md).

White shapes, tinted in Roblox with ImageColor3; drawn 4x and scaled down.
Faceted like the rest of the HUD icons (angled plates, no round blade tips).
- kill_sword.png: one blade pointing up, crossguard, grip, diamond pommel
- kill_blades.png: two blades crossed
- kill_shard.png: a diamond shard cut in three, the slices knocked sideways
  (the glitch colour split is done in Roblox: cyan and pink copies offset behind)
- kill_ring_seg.png: one of 5 ring segments (the top one); rotate by 72 deg
- kill_wave.png: a full ring (straight-edged, 40 sides) for the shockwave
- status_seg.png: one of 24 status-ring segments (the top one); rotate by 15 deg

    python tools/ui/make_kill_icons.py <out_dir>
"""

import math
import sys
from pathlib import Path

from PIL import Image, ImageDraw

SS = 4
SIZE = 128


def canvas(size=SIZE):
    return Image.new("RGBA", (size * SS, size * SS), (0, 0, 0, 0))


def done(img, size=SIZE):
    return img.resize((size, size), Image.LANCZOS)


def sword_points(cx, cy, s):
    """A sword pointing up, centred on (cx, cy); s = scale (1 = 128 px icon)."""
    u = SS * s

    def p(x, y):
        return (cx + x * u, cy + y * u)

    blade = [p(0, -54), p(9, -40), p(9, 14), p(-9, 14), p(-9, -40)]
    fuller = [p(0, -44), p(2.5, -38), p(2.5, 8), p(-2.5, 8), p(-2.5, -38)]
    guard = [p(-28, 14), p(-24, 20), p(24, 20), p(28, 14), p(24, 22 - 14), p(-24, 22 - 14)]
    guard = [p(-30, 17), p(-25, 11), p(25, 11), p(30, 17), p(25, 23), p(-25, 23)]
    grip = [p(-5, 23), p(5, 23), p(5, 41), p(-5, 41)]
    pommel = [p(0, 39), p(8, 47), p(0, 55), p(-8, 47)]
    return blade, fuller, guard, grip, pommel


def draw_sword(d, cx, cy, s, rot=0.0):
    parts = sword_points(cx, cy, s)
    if rot:
        c, sn = math.cos(rot), math.sin(rot)
        parts = [
            [(cx + (x - cx) * c - (y - cy) * sn, cy + (x - cx) * sn + (y - cy) * c) for x, y in poly]
            for poly in parts
        ]
    blade, fuller, guard, grip, pommel = parts
    white = (255, 255, 255, 255)
    d.polygon(blade, fill=white)
    d.polygon(fuller, fill=(255, 255, 255, 110))  # a lit ridge down the blade
    d.polygon(guard, fill=white)
    d.polygon(grip, fill=white)
    d.polygon(pommel, fill=white)


def sword():
    img = canvas()
    d = ImageDraw.Draw(img)
    c = SIZE * SS / 2
    draw_sword(d, c, c + 2 * SS, 1.0)
    return done(img)


def blades():
    img = canvas()
    d = ImageDraw.Draw(img)
    c = SIZE * SS / 2
    draw_sword(d, c, c + 4 * SS, 0.92, math.radians(-38))
    draw_sword(d, c, c + 4 * SS, 0.92, math.radians(38))
    return done(img)


def shard():
    """A tall diamond, cut into three slices, the middle one knocked right."""
    img = canvas()
    u = SS
    c = SIZE / 2
    full = [(c, 8), (c + 30, 60), (c, 120), (c - 30, 60)]  # the diamond (in 128 px units)
    cuts = [(46, 52), (74, 82)]  # slice bands (y ranges)
    offsets = [0, 8, -5]  # x shift per slice: top, middle, bottom

    def clip(poly, y0, y1):
        # Sutherland-Hodgman against the band y0..y1
        def edge(pts, keep, inter):
            out = []
            for i in range(len(pts)):
                a, b = pts[i - 1], pts[i]
                ia, ib = keep(a), keep(b)
                if ib:
                    if not ia:
                        out.append(inter(a, b))
                    out.append(b)
                elif ia:
                    out.append(inter(a, b))
            return out

        def at(y):
            return lambda a, b: (a[0] + (b[0] - a[0]) * (y - a[1]) / (b[1] - a[1]), y)

        pts = edge(poly, lambda q: q[1] >= y0, at(y0))
        return edge(pts, lambda q: q[1] <= y1, at(y1))

    bands = [(0, cuts[0][0]), (cuts[0][1], cuts[1][0]), (cuts[1][1], 128)]
    d = ImageDraw.Draw(img)
    for (y0, y1), dx in zip(bands, offsets):
        piece = clip(full, y0, y1)
        if piece:
            d.polygon([((x + dx) * u, y * u) for x, y in piece], fill=(255, 255, 255, 255))
            # the left facet a little dimmer, for a cut-gem read
            left = [(x, y) for x, y in piece if x <= c + 0.01]
            if len(left) >= 2:
                facet = left + [(c, max(y for _, y in left)), (c, min(y for _, y in left))]
                d.polygon([((x + dx) * u, y * u) for x, y in facet], fill=(255, 255, 255, 170))
    return done(img)


def ring_seg():
    """The top one of 5 segments of a ring, as a straight-edged arc (faceted)."""
    size = 256
    img = Image.new("RGBA", (size * SS, size * SS), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    c = size * SS / 2
    r_out, r_in = 124 * SS, 108 * SS
    gap = math.radians(7)
    a0, a1 = -math.pi / 2 - math.radians(36) + gap / 2, -math.pi / 2 + math.radians(36) - gap / 2
    steps = 12
    outer = [(c + r_out * math.cos(a0 + (a1 - a0) * i / steps), c + r_out * math.sin(a0 + (a1 - a0) * i / steps)) for i in range(steps + 1)]
    inner = [(c + r_in * math.cos(a1 - (a1 - a0) * i / steps), c + r_in * math.sin(a1 - (a1 - a0) * i / steps)) for i in range(steps + 1)]
    d.polygon(outer + inner, fill=(255, 255, 255, 255))
    return img.resize((size, size), Image.LANCZOS)


def wave():
    """A full ring for the shockwave that bursts out on a kill."""
    size = 256
    img = Image.new("RGBA", (size * SS, size * SS), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    c = size * SS / 2
    r_out, r_in = 124 * SS, 112 * SS
    n = 40
    outer = [(c + r_out * math.cos(2 * math.pi * i / n), c + r_out * math.sin(2 * math.pi * i / n)) for i in range(n)]
    d.polygon(outer, fill=(255, 255, 255, 255))
    inner = [(c + r_in * math.cos(2 * math.pi * i / n), c + r_in * math.sin(2 * math.pi * i / n)) for i in range(n)]
    d.polygon(inner, fill=(0, 0, 0, 0))
    return img.resize((size, size), Image.LANCZOS)


def status_seg():
    """The top one of 24 segments of the status tray's draining ring."""
    size = 256
    img = Image.new("RGBA", (size * SS, size * SS), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    c = size * SS / 2
    r_out, r_in = 126 * SS, 104 * SS
    half = math.radians(7.5) - math.radians(1.6)
    a0, a1 = -math.pi / 2 - half, -math.pi / 2 + half
    pts = [
        (c + r_out * math.cos(a0), c + r_out * math.sin(a0)),
        (c + r_out * math.cos(a1), c + r_out * math.sin(a1)),
        (c + r_in * math.cos(a1), c + r_in * math.sin(a1)),
        (c + r_in * math.cos(a0), c + r_in * math.sin(a0)),
    ]
    d.polygon(pts, fill=(255, 255, 255, 255))
    return img.resize((size, size), Image.LANCZOS)


def main():
    out = Path(sys.argv[1] if len(sys.argv) > 1 else "art-source/ui/hud")
    out.mkdir(parents=True, exist_ok=True)
    sword().save(out / "kill_sword.png")
    blades().save(out / "kill_blades.png")
    shard().save(out / "kill_shard.png")
    ring_seg().save(out / "kill_ring_seg.png")
    wave().save(out / "kill_wave.png")
    status_seg().save(out / "status_seg.png")
    print("wrote", out)


if __name__ == "__main__":
    main()
