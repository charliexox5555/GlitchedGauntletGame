"""The Flash's starburst texture (vault/01 Design/Abilities/Flash.md → What a blinded player sees).

    python tools/vfx/make_flash_starburst.py

Writes art-source/vfx/flash/T_FlashRays.png (1024 x 1024, white on transparent): soft light rays
fanning out from the centre, many widths and lengths, brightest at the core and fading along their
length, plus a hot core. The game tints it (an outer cool layer and an inner warm one) and centres it
on where the flash popped. Our own art; the owner's Valorant screenshot is the reference for the feel.
"""

import math
import os
import random

from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "art-source", "vfx", "flash")
S = 1024
C = S / 2


def rays(seed):
    random.seed(seed)
    im = Image.new("L", (S, S), 0)
    d = ImageDraw.Draw(im)
    n = 34
    for i in range(n):
        a = (i + random.uniform(-0.35, 0.35)) / n * 2 * math.pi
        width = math.radians(random.uniform(1.4, 4.6))
        length = random.uniform(0.62, 1.0) * C * 0.98 # inside the image: no clipped ends
        value = random.randint(110, 255)
        # a thin wedge from the centre, drawn in steps so it fades along its length
        steps = 64
        for k in range(steps):
            r0 = length * k / steps
            r1 = length * (k + 1) / steps
            fade = (1 - k / steps) ** 1.4
            v = int(value * fade)
            w0 = width * (0.35 + 0.65 * (1 - k / steps))
            pts = [
                (C + math.cos(a - w0) * r0, C + math.sin(a - w0) * r0),
                (C + math.cos(a - w0) * r1, C + math.sin(a - w0) * r1),
                (C + math.cos(a + w0) * r1, C + math.sin(a + w0) * r1),
                (C + math.cos(a + w0) * r0, C + math.sin(a + w0) * r0),
            ]
            d.polygon(pts, fill=v)
    im = im.filter(ImageFilter.GaussianBlur(5))
    # the hot core
    core = Image.new("L", (S, S), 0)
    cd = ImageDraw.Draw(core)
    for r, v in ((150, 70), (95, 140), (55, 220), (28, 255)):
        cd.ellipse((C - r, C - r, C + r, C + r), fill=v)
    core = core.filter(ImageFilter.GaussianBlur(26))
    a = Image.eval(Image.merge("RGB", (im, core, core)), lambda x: x)
    alpha = Image.new("L", (S, S))
    alpha.putdata([min(255, p + q) for p, q in zip(im.get_flattened_data(), core.get_flattened_data())])
    # A radial mask: everything fades out before the image's edge (a ray cut
    # by the square border shows as a straight line on screen).
    mask = Image.new("L", (S, S), 0)
    md = ImageDraw.Draw(mask)
    for k in range(64):
        r = C * (1 - k / 64)
        v = int(255 * min(1.0, (k / 64) / 0.45))
        md.ellipse((C - r, C - r, C + r, C + r), fill=v)
    mask = mask.filter(ImageFilter.GaussianBlur(6))
    alpha = Image.eval(alpha, lambda x: x)
    alpha.putdata([p * q // 255 for p, q in zip(alpha.get_flattened_data(), mask.get_flattened_data())])
    out = Image.new("RGBA", (S, S), (255, 255, 255, 0))
    out.putalpha(alpha)
    return out


def main():
    os.makedirs(OUT, exist_ok=True)
    img = rays(17)
    path = os.path.join(OUT, "T_FlashRays.png")
    img.save(path)
    prev = Image.new("RGBA", (S, S), (44, 78, 82, 255))
    tinted = Image.new("RGBA", (S, S), (255, 240, 190, 255))
    tinted.putalpha(img.getchannel("A"))
    prev.alpha_composite(tinted)
    prev.save(os.path.join(OUT, "T_FlashRays_preview.png"))
    print(path)


if __name__ == "__main__":
    main()
