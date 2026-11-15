"""Tileable fluid-flow overlay for Moltframe chambers (numpy + Pillow).

    python tools/textures/make_moltframe_flow.py [out_dir]

Writes Moltframe_Flow.png (512x256 RGBA): soft lilac wisps on transparent,
seamless in both directions (integer-frequency Fourier noise, domain-warped
with periodic warps so the tile still wraps). In Roblox two `Texture` layers
of this image drift slowly in opposite directions over each chamber face
(ChamberFlow, client), while the baked chamber colour map stays the static
fallback underneath.
"""
import os
import sys

import numpy as np
from PIL import Image

W, H = 512, 256
rng = np.random.default_rng(7)
y, x = np.mgrid[0:H, 0:W]
u, v = x / W, y / H

def periodic(freqs, amp_fall=1.0, phase=None):
    out = np.zeros((H, W))
    for fx, fy in freqs:
        a = rng.normal() / (1 + (fx * fx + fy * fy) ** .5) ** amp_fall
        b = rng.normal() / (1 + (fx * fx + fy * fy) ** .5) ** amp_fall
        arg = 2 * np.pi * (fx * u + fy * v) + (0 if phase is None else phase)
        out += a * np.cos(arg) + b * np.sin(arg)
    return out / (np.abs(out).max() + 1e-9)

low = [(fx, fy) for fx in range(0, 4) for fy in range(-2, 3) if (fx, fy) != (0, 0)]
mid = [(fx, fy) for fx in range(0, 9) for fy in range(-5, 6) if 2 < fx * fx + fy * fy < 70]
# periodic domain warp (integer cycles keep the tile seamless)
wu = periodic(low, 1.2)
wv = periodic(low, 1.2)
field = np.zeros((H, W))
for fx, fy in mid:
    a, b = rng.normal(), rng.normal()
    k = 1 / (1 + (fx * fx + fy * fy) ** .5) ** 1.3
    arg = 2 * np.pi * (fx * (u + .08 * wu) + fy * (v + .10 * wv))
    field += k * (a * np.cos(arg) + b * np.sin(arg))
field = (field - field.min()) / (field.max() - field.min())
# wisps: thin ridges where the warped field crosses a few iso levels
ridge = np.zeros_like(field)
for level, width, gain in ((.38, .035, .55), (.55, .022, 1.0), (.70, .03, .45)):
    ridge = np.maximum(ridge, gain * np.exp(-((field - level) / width) ** 2))
body = np.clip((field - .45) * 1.4, 0, 1) ** 2 * .35       # faint broad sheen
alpha = np.clip(ridge * .62 + body, 0, .72)
lilac = np.array([214, 168, 248], np.float32)
deep = np.array([150, 82, 214], np.float32)
t = np.clip(ridge, 0, 1)[..., None]
rgb = deep * (1 - t) + lilac * t
img = np.dstack([rgb, alpha[..., None] * 255]).astype(np.uint8)

out_dir = sys.argv[1] if len(sys.argv) > 1 else os.path.join(
    os.path.dirname(__file__), "..", "..", "art-source", "weapons", "Skins", "Moltframe", "_shared")
os.makedirs(out_dir, exist_ok=True)
path = os.path.join(out_dir, "Moltframe_Flow.png")
Image.fromarray(img, "RGBA").save(path)
# seam check: wrap difference vs interior neighbour difference
seam = float(np.abs(img[:, 0, 3].astype(int) - img[:, -1, 3]).mean())
inner = float(np.abs(img[:, 1, 3].astype(int) - img[:, 0, 3]).mean())
print(path, "seam", round(seam, 2), "interior", round(inner, 2))
