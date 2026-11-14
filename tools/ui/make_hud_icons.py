"""Bottom combat HUD icons (vault/02 Art/UI Combat HUD Mockup.md).

White icons, tinted in Roblox with ImageColor3; drawn 4x and scaled down.
- icon_health.png: a chunky plus with chamfered ends (faceted, our build style)
- icon_shield.png: a faceted shield
- icon_reload.png: two arrow plates chasing each other (for the reload state)

    python tools/ui/make_hud_icons.py <out_dir>
"""

import sys
from pathlib import Path

from PIL import Image, ImageDraw

SS = 4


def canvas(size=64):
    return Image.new("RGBA", (size * SS, size * SS), (0, 0, 0, 0))


def done(img, size=64):
    return img.resize((size, size), Image.LANCZOS)


def health():
    img = canvas()
    d = ImageDraw.Draw(img)
    u = SS
    a, b, c = 23 * u, 41 * u, 3 * u  # arm from a to b, chamfer c
    pts = [
        (a, 8 * u + c), (a + c, 8 * u), (b - c, 8 * u), (b, 8 * u + c), (b, a),
        (56 * u - c, a), (56 * u, a + c), (56 * u, b - c), (56 * u - c, b), (b, b),
        (b, 56 * u - c), (b - c, 56 * u), (a + c, 56 * u), (a, 56 * u - c), (a, b),
        (8 * u + c, b), (8 * u, b - c), (8 * u, a + c), (8 * u + c, a), (a, a),
    ]
    d.polygon(pts, fill=(255, 255, 255, 255))
    return done(img)


def shield():
    img = canvas()
    d = ImageDraw.Draw(img)
    u = SS
    pts = [(32, 4), (56, 12), (54, 34), (44, 50), (32, 60), (20, 50), (10, 34), (8, 12)]
    d.polygon([(x * u, y * u) for x, y in pts], fill=(255, 255, 255, 255))
    # a lit left half for a faceted read
    inner = [(32, 10), (32, 53), (22, 46), (14, 33), (13, 16)]
    d.polygon([(x * u, y * u) for x, y in inner], fill=(255, 255, 255, 120))
    return done(img)


def reload():
    img = canvas()
    d = ImageDraw.Draw(img)
    u = SS
    top = [(10, 26), (14, 14), (44, 14), (44, 6), (58, 20), (44, 34), (44, 26)]
    bot = [(54, 38), (50, 50), (20, 50), (20, 58), (6, 44), (20, 30), (20, 38)]
    for pts in (top, bot):
        d.polygon([(x * u, y * u) for x, y in pts], fill=(255, 255, 255, 255))
    return done(img)


def main():
    out = Path(sys.argv[1] if len(sys.argv) > 1 else ".")
    out.mkdir(parents=True, exist_ok=True)
    health().save(out / "icon_health.png")
    shield().save(out / "icon_shield.png")
    reload().save(out / "icon_reload.png")
    print("ok")


if __name__ == "__main__":
    main()
