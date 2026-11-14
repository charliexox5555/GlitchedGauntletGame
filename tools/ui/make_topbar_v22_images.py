"""Top bar v2.2 images (vault/02 Art/UI Top Bar Draft.md, "v2.2 polish").

- team_cap_flat_{right,left}.png: the slanted inner end of a team block as a
  flat white shape (28 x 80 on screen, drawn 2x). The block body and the cap
  both get the same UIGradient in Roblox, so their colours match exactly.
- soft_shadow.png: a blurred rounded rect for a 9-slice drop shadow.
- bot_headshot_v2.png: a clean helmet-and-visor silhouette for bots (Roblox
  headshots come with a transparent background, so this matches them).

    python tools/ui/make_topbar_v22_images.py <out_dir>
"""

import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

SS = 4


def cap(side):
    w, h = 56 * SS, 160 * SS
    straight = 16 * SS
    pts = [(0, 0), (w, 0), (straight, h), (0, h)] if side == "right" else [(0, 0), (w, 0), (w, h), (w - straight, h)]
    img = Image.new("RGBA", (w, h), (255, 255, 255, 0))
    ImageDraw.Draw(img).polygon(pts, fill=(255, 255, 255, 255))
    return img.resize((56, 160), Image.LANCZOS)


def shadow():
    size, inset, r, blur = 128, 32, 14, 12
    img = Image.new("L", (size, size), 0)
    ImageDraw.Draw(img).rounded_rectangle([inset, inset, size - inset, size - inset], radius=r, fill=255)
    img = img.filter(ImageFilter.GaussianBlur(blur))
    out = Image.new("RGBA", (size, size), (255, 255, 255, 0))
    out.putalpha(img)
    return out


def bot_head():
    S = 300 * SS
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    u = S / 100
    P = lambda pts: [(x * u, y * u) for x, y in pts]
    # shoulders / torso plate (faceted)
    d.polygon(P([(14, 100), (20, 80), (34, 73), (66, 73), (80, 80), (86, 100)]), fill=(196, 204, 214, 255))
    d.polygon(P([(14, 100), (20, 80), (34, 73), (50, 73), (50, 100)]), fill=(214, 221, 229, 255))
    # neck
    d.polygon(P([(42, 62), (58, 62), (60, 75), (40, 75)]), fill=(120, 128, 140, 255))
    # helmet (faceted dome)
    d.polygon(P([(30, 30), (38, 18), (62, 18), (70, 30), (72, 52), (64, 66), (36, 66), (28, 52)]), fill=(226, 232, 239, 255))
    d.polygon(P([(30, 30), (38, 18), (50, 18), (50, 66), (36, 66), (28, 52)]), fill=(240, 244, 248, 255))
    # visor
    d.polygon(P([(33, 38), (67, 38), (65, 50), (35, 50)]), fill=(24, 30, 40, 255))
    d.polygon(P([(36, 40), (52, 40), (51, 43), (36, 43)]), fill=(90, 104, 122, 255))
    return img.resize((300, 300), Image.LANCZOS)


def main():
    out = Path(sys.argv[1] if len(sys.argv) > 1 else ".")
    out.mkdir(parents=True, exist_ok=True)
    cap("right").save(out / "team_cap_flat_right.png")
    cap("left").save(out / "team_cap_flat_left.png")
    shadow().save(out / "soft_shadow.png")
    bot_head().save(out / "bot_headshot_v2.png")
    print("ok")


if __name__ == "__main__":
    main()
