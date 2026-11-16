"""The Flash screen's layer textures, v4 (vault/01 Design/Abilities/Flash.md → What a blinded player sees).

    python tools/vfx/make_flash_layers.py

Three clean layers instead of one busy sheet (owner 2026-11-17: "the flash UI looks a little sloppy"),
each white on transparent, 1024 x 1024, drawn at 4x and scaled down (smooth edges), every layer fading
to nothing well inside the image edge (no clipped ends):
  T_FlashBeams.png    a few wide, soft beams (the body of the burst)
  T_FlashStreaks.png  many thin, crisp streaks of different lengths (the sparkle)
  T_FlashHalo.png     a soft ring with a faint inner glow (the hot core's halo)
The game tints and turns them against each other (Util/FlashFx). Plus a preview over the wash colour.
"""

import math
import os
import random

from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "art-source", "vfx", "flash")
S = 1024
K = 4  # supersampling
B = S * K
C = B / 2


def wedge(d, a, w_in, w_out, r0, r1, v):
    pts = [
        (C + math.cos(a - w_in) * r0, C + math.sin(a - w_in) * r0),
        (C + math.cos(a - w_out) * r1, C + math.sin(a - w_out) * r1),
        (C + math.cos(a + w_out) * r1, C + math.sin(a + w_out) * r1),
        (C + math.cos(a + w_in) * r0, C + math.sin(a + w_in) * r0),
    ]
    d.polygon(pts, fill=v)


def ray_layer(seed, count, width, length, value, steps, blur, taper):
    random.seed(seed)
    im = Image.new("L", (B, B), 0)
    for i in range(count):
        layer = Image.new("L", (B, B), 0)
        d = ImageDraw.Draw(layer)
        a = (i + random.uniform(-0.4, 0.4)) / count * 2 * math.pi
        w = math.radians(random.uniform(*width))
        ln = random.uniform(*length) * C
        v = random.randint(*value)
        for k in range(steps):
            u0, u1 = k / steps, (k + 1) / steps
            fade = (1 - u0) ** 1.6
            w0 = w * (taper + (1 - taper) * (1 - u0))
            w1 = w * (taper + (1 - taper) * (1 - u1))
            wedge(d, a, w0, w1, ln * u0, ln * u1, int(v * fade))
        im = Image.composite(layer, im, layer.point(lambda x: 255 if x > 0 else 0)) if False else Image.fromarray(
            __import__("numpy").maximum(__import__("numpy").array(im), __import__("numpy").array(layer)))
    return im.filter(ImageFilter.GaussianBlur(blur * K))


def radial_mask(inner=0.55):
    """1 inside `inner` of the radius, fading to 0 at 0.97 (no hard edge)."""
    import numpy as np
    y, x = np.mgrid[0:B, 0:B]
    r = np.sqrt((x - C) ** 2 + (y - C) ** 2) / C
    m = np.clip((0.97 - r) / (0.97 - inner), 0, 1)
    m = m * m * (3 - 2 * m)  # smoothstep
    return Image.fromarray((m * 255).astype("uint8"))


def finish(alpha, name):
    import numpy as np
    a = np.array(alpha).astype(np.float32) * (np.array(radial_mask()).astype(np.float32) / 255.0)
    a = Image.fromarray(np.clip(a, 0, 255).astype("uint8")).resize((S, S), Image.LANCZOS)
    out = Image.new("RGBA", (S, S), (255, 255, 255, 0))
    out.putalpha(a)
    out.save(os.path.join(OUT, name + ".png"))
    return out


def halo():
    import numpy as np
    y, x = np.mgrid[0:B, 0:B]
    r = np.sqrt((x - C) ** 2 + (y - C) ** 2) / C
    ring = np.exp(-((r - 0.42) / 0.07) ** 2) * 0.32
    glow = np.exp(-(r / 0.32) ** 2) * 0.5
    a = np.clip(ring + glow, 0, 1) * 255
    return Image.fromarray(a.astype("uint8"))


def main():
    os.makedirs(OUT, exist_ok=True)
    beams = finish(ray_layer(3, 18, (4.0, 9.0), (0.8, 0.97), (170, 255), 40, 10, 0.3), "T_FlashBeams")
    streaks = finish(ray_layer(11, 72, (0.25, 0.7), (0.45, 0.97), (150, 255), 40, 1.2, 0.1), "T_FlashStreaks")
    ring = finish(halo(), "T_FlashHalo")
    # preview: the wash, beams (cool), streaks (warm), halo (warm), a core
    prev = Image.new("RGBA", (S, S), (44, 79, 83, 255))
    for img, col in ((beams, (191, 230, 214)), (streaks, (255, 240, 184)), (ring, (255, 240, 184))):
        t = Image.new("RGBA", (S, S), col + (255,))
        t.putalpha(img.getchannel("A"))
        prev.alpha_composite(t)
    core = Image.new("L", (S, S), 0)
    ImageDraw.Draw(core).ellipse((S / 2 - 70, S / 2 - 70, S / 2 + 70, S / 2 + 70), fill=255)
    core = core.filter(ImageFilter.GaussianBlur(40))
    t = Image.new("RGBA", (S, S), (255, 248, 220, 255))
    t.putalpha(core)
    prev.alpha_composite(t)
    prev.save(os.path.join(OUT, "T_FlashLayers_preview.png"))
    print("ok")


if __name__ == "__main__":
    main()
