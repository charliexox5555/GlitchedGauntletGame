"""Crop Blender portrait renders to their alpha box and fit them into 1024 x 1024 with a
5 px margin, like the other <Gun>_<Line>_HD.png portraits.

    python tools/render/fit_portraits.py Arcade
"""
import sys
from pathlib import Path

from PIL import Image

LINE = sys.argv[1]
DIR = Path(__file__).resolve().parents[2] / "art-source/ui/item-portraits"
for raw in sorted(DIR.glob("_raw_*.png")):
    gun = raw.stem[5:]
    im = Image.open(raw).convert("RGBA")
    box = im.getchannel("A").point(lambda a: 255 if a > 8 else 0).getbbox()
    im = im.crop(box)
    scale = 1014 / max(im.size)
    im = im.resize((round(im.width * scale), round(im.height * scale)), Image.LANCZOS)
    out = Image.new("RGBA", (1024, 1024), (0, 0, 0, 0))
    out.paste(im, ((1024 - im.width) // 2, (1024 - im.height) // 2), im)
    out.save(DIR / f"{gun}_{LINE}_HD.png")
    raw.unlink()
    print(gun, out.size)
# side-on icons: fit into 1024 x 301 (the ItemIcons size), right side, muzzle right
ICONS = DIR.parent / "item-icons"
for raw in sorted(DIR.glob("_side_*.png")):
    gun = raw.stem[6:]
    im = Image.open(raw).convert("RGBA")
    im = im.crop(im.getchannel("A").point(lambda a: 255 if a > 8 else 0).getbbox())
    scale = min(1018 / im.width, 296 / im.height)
    im = im.resize((round(im.width * scale), round(im.height * scale)), Image.LANCZOS)
    out = Image.new("RGBA", (1024, 301), (0, 0, 0, 0))
    out.paste(im, ((1024 - im.width) // 2, (301 - im.height) // 2), im)
    out.save(ICONS / f"{gun}_{LINE}.png")
    raw.unlink()
    print("icon", gun)
