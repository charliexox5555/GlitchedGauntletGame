"""Top bar UI images (vault/02 Art/UI Top Bar Draft.md).

Makes the white 9-slice plates (one sliced corner, the rest rounded), their
hairline outlines, a stand-in headshot for bots, and the sliced-vs-rounded
comparison board. Everything is drawn 4x and scaled down for clean edges.

    python tools/ui/make_topbar_images.py <out_dir>
"""

import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

SS = 4  # supersampling


def plate_points(w, h, r, cut, corner):
    """Polygon of a rounded rect with one 45-degree cut. corner: 'bl' | 'br' | None."""
    import math

    pts = []

    def arc(cx, cy, a0, a1):
        steps = 16
        for i in range(steps + 1):
            a = math.radians(a0 + (a1 - a0) * i / steps)
            pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))

    # top-left, top-right rounded
    arc(r, r, 180, 270)
    arc(w - r, r, 270, 360)
    if corner == "br":
        pts += [(w, h - cut), (w - cut, h)]
    else:
        arc(w - r, h - r, 0, 90)
    if corner == "bl":
        pts += [(cut, h), (0, h - cut)]
    else:
        arc(r, h - r, 90, 180)
    return pts


def shape_image(size, r, cut, corner, line=0, fill=(255, 255, 255, 255)):
    big = size * SS
    img = Image.new("RGBA", (big, big), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.polygon(plate_points(big, big, r * SS, cut * SS, corner), fill=fill)
    if line:
        inner = Image.new("L", (big, big), 0)
        di = ImageDraw.Draw(inner)
        t = line * SS
        pts = plate_points(big - 2 * t, big - 2 * t, max(r * SS - t, 1), max(cut * SS - t * 0.6, 1), corner)
        di.polygon([(x + t, y + t) for x, y in pts], fill=255)
        alpha = img.getchannel("A")
        alpha.paste(0, mask=inner)
        img.putalpha(alpha)
    return img.resize((size, size), Image.LANCZOS)


def head(size, skin, hair, shirt, bg=None):
    """A blocky stand-in headshot (transparent background like Roblox's)."""
    s = size * SS / 52
    img = Image.new("RGBA", (size * SS, size * SS), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    if bg:
        for y in range(size * SS):
            t = y / (size * SS)
            c = tuple(int(bg[0][i] + (bg[1][i] - bg[0][i]) * t) for i in range(3))
            d.line([(0, y), (size * SS, y)], fill=c + (255,))
    P = lambda pts: [(x * s, y * s) for x, y in pts]
    d.polygon(P([(9, 52), (13, 43), (39, 43), (43, 52)]), fill=shirt)
    d.rectangle([22 * s, 36 * s, 30 * s, 44 * s], fill=skin)
    d.polygon(P([(15, 15), (18, 12), (34, 12), (37, 15), (37, 34), (34, 37), (18, 37), (15, 34)]), fill=skin)
    d.polygon(P([(14, 19), (14, 12), (18, 8), (34, 8), (38, 12), (38, 19), (34, 15), (18, 15)]), fill=hair)
    d.rectangle([20 * s, 23 * s, 23 * s, 28 * s], fill=(27, 31, 39))
    d.rectangle([29 * s, 23 * s, 32 * s, 28 * s], fill=(27, 31, 39))
    d.rectangle([23 * s, 31 * s, 29 * s, 32.5 * s], fill=(27, 31, 39, 140))
    return img.resize((size, size), Image.LANCZOS)


def hexc(h):
    return tuple(int(h[i : i + 2], 16) for i in (0, 2, 4))


def comparison(out):
    W, H = 1500, 560
    img = Image.new("RGBA", (W, H), (0, 0, 0, 255))
    d = ImageDraw.Draw(img)
    # bright sky-to-floor backdrop, like the match maps
    for y in range(H):
        t = y / H
        top, bot = hexc("8FB1D1"), hexc("AAB4BF")
        d.line([(0, y), (W, y)], fill=tuple(int(top[i] + (bot[i] - top[i]) * t) for i in range(3)) + (255,))
    fonts = Path("C:/Windows/Fonts")
    def font(size, bold=True):
        for name in ["segoeuib.ttf" if bold else "segoeui.ttf", "arialbd.ttf"]:
            if (fonts / name).exists():
                return ImageFont.truetype(str(fonts / name), size)
        return ImageFont.load_default()
    plate = hexc("10141B")
    ally, enemy = hexc("2FD3E6"), hexc("FF5A4E")
    looks = [("F2C9A0", "2B2118", "3A4A63"), ("C68E5E", "E0B04A", "B8442F"), ("F5D3B5", "C9CED6", "D2A23A"), ("8D5A3B", "1B1B1F", "2F6B57")]

    def portrait(x, y, look, side, rounded, dead=False):
        size = 64
        corner = None if rounded else ("bl" if side == "ally" else "br")
        mask = shape_image(size, 10, 13, corner).getchannel("A")
        bg = head(size, hexc(look[0]), hexc(look[1]), hexc(look[2]), bg=(hexc("2E3644"), hexc("151A22")))
        if dead:
            g = bg.convert("L").convert("RGBA")
            g.putalpha(255)
            bg = Image.blend(g, Image.new("RGBA", g.size, plate + (255,)), 0.55)
        tile = Image.new("RGBA", (size, size), (0, 0, 0, 0))
        tile.paste(bg, (0, 0), mask)
        img.alpha_composite(tile, (x, y))
        line = shape_image(size, 10, 13, corner, line=1.5).getchannel("A").point(lambda a: a * 0.16)
        edge = Image.new("RGBA", (size, size), (255, 255, 255, 0))
        edge.putalpha(line)
        img.alpha_composite(edge, (x, y))
        col = (hexc("3A414C") if dead else (ally if side == "ally" else enemy)) + (255,)
        d.rounded_rectangle([x, y + size + 4, x + size, y + size + 8], radius=2, fill=col)

    def chip(x, y, txt, side, rounded):
        w, h = 66, 64
        corner = None if rounded else ("bl" if side == "ally" else "br")
        m = shape_image(64, 10 if not rounded else 10, 13, corner).resize((w, h)).getchannel("A").point(lambda a: a * 0.86)
        tile = Image.new("RGBA", (w, h), plate + (0,))
        tile.putalpha(m)
        img.alpha_composite(tile, (x, y))
        f = font(38)
        tw = d.textlength(txt, font=f)
        d.text((x + (w - tw) / 2, y + 6), txt, font=f, fill=(ally if side == "ally" else enemy))

    def timer(x, y, t, info):
        w, h = 164, 76
        tile = Image.new("RGBA", (w * SS, h * SS), (0, 0, 0, 0))
        ImageDraw.Draw(tile).rounded_rectangle([0, 0, w * SS - 1, h * SS - 1], radius=12 * SS, fill=plate + (220,))
        img.alpha_composite(tile.resize((w, h), Image.LANCZOS), (x, y))
        f = font(40)
        tw = d.textlength(t, font=f)
        d.text((x + (w - tw) / 2, y + 2), t, font=f, fill=hexc("F4F6F9"))
        f2 = font(14)
        tw = d.textlength(info, font=f2)
        d.text((x + (w - tw) / 2, y + 52), info, font=f2, fill=hexc("A9B2BF"))

    def bar(cy, rounded, label):
        P, G, GAP = 64, 8, 14
        total = (2 * P + G) * 2 + 2 * GAP + 66 * 2 + 5 * 2 + 164
        x = (W - total) // 2
        portrait(x, cy, looks[3], "ally", rounded, dead=True)
        portrait(x + P + G, cy, looks[0], "ally", rounded)
        x += 2 * P + G + GAP
        chip(x, cy, "3", "ally", rounded)
        timer(x + 66 + 5, cy, "1:24", "ROUND 6 · HEAVY")
        chip(x + 66 + 5 + 164 + 5, cy, "2", "enemy", rounded)
        x += 66 * 2 + 10 + 164 + GAP
        portrait(x, cy, looks[1], "enemy", rounded)
        portrait(x + P + G, cy, looks[2], "enemy", rounded)
        f = font(26)
        d.text((60, cy + 18), label, font=f, fill=hexc("10141B"))

    bar(70, False, "A · SLICED")
    bar(330, True, "B · FULLY ROUNDED")
    f = font(18, bold=False)
    d.text((60, H - 40), "Outer-left ally is greyed out (dead). Both at the in-game size for 1920 x 1080 (mock-up font; the game uses Titillium Web + Sarpanch).", font=f, fill=hexc("10141B"))
    img.convert("RGB").save(out / "topbar-compare-sliced-vs-rounded.png")


def main():
    out = Path(sys.argv[1] if len(sys.argv) > 1 else ".")
    out.mkdir(parents=True, exist_ok=True)
    # 9-slice plates: 64 px images, radius 20, cut 26 at 2x of the screen size
    for corner in ("bl", "br"):
        shape_image(64, 20, 26, corner).save(out / f"plate_cut_{corner}.png")
        shape_image(64, 20, 26, corner, line=3).save(out / f"plate_cut_{corner}_line.png")
    head(150, hexc("D9DEE5"), hexc("5B6676"), hexc("3A4A63")).save(out / "bot_headshot.png")
    comparison(out)
    print("ok", sorted(p.name for p in out.iterdir()))


if __name__ == "__main__":
    main()
