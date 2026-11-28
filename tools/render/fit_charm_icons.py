"""Crop charm icon renders to their alpha box and fit them to 512 x 512 (8 px margin).

    python tools/render/fit_charm_icons.py
"""
from pathlib import Path

from PIL import Image

DIR = Path(__file__).resolve().parents[2] / "art-source/ui/charm-icons"
for raw in sorted(DIR.glob("_raw_*.png")):
    name = raw.stem[5:]
    im = Image.open(raw).convert("RGBA")
    im = im.crop(im.getchannel("A").point(lambda a: 255 if a > 8 else 0).getbbox())
    scale = 496 / max(im.size)
    im = im.resize((round(im.width * scale), round(im.height * scale)), Image.LANCZOS)
    out = Image.new("RGBA", (512, 512), (0, 0, 0, 0))
    out.paste(im, ((512 - im.width) // 2, (512 - im.height) // 2), im)
    out.save(DIR / f"{name}.png")
    raw.unlink()
    print(name)
