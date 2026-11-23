"""Seamless pattern tiles for Riftforge Legendary skins.

Riftforge_Forged.png: subtle dark machined brushed-metal + angled micro-bevel
forged-obsidian texture (mostly transparent so the MeshPart base color shows).
Riftforge_Plasma.png: flowing violet/magenta dark-matter plasma veins that
drift smoothly across Neon/SmoothPlastic conduits on camera guns.
"""
import math
import os

import numpy as np
from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "art-source", "weapons", "Skins", "_tiles")
N = 256


def _seamless_noise(seed, octaves=4, freq_x=1.0, freq_y=1.0):
    rng = np.random.default_rng(seed)
    acc = np.zeros((N, N), dtype=np.float64)
    yy, xx = np.mgrid[0:N, 0:N] / N * 2.0 * math.pi
    for o in range(octaves):
        f = 2 ** o
        for _ in range(4):
            kx = int(rng.integers(1, 3)) * f * freq_x
            ky = int(rng.integers(1, 3)) * f * freq_y
            ph = rng.random() * 2.0 * math.pi
            acc += np.sin(kx * xx + ky * yy + ph) / f
    return (acc - acc.min()) / (acc.max() - acc.min() + 1e-9)


def forged():
    """Machined dark forged-obsidian armor grain:
    - Fine horizontal brushed-alloy streaks
    - Crisp precision angled tech-hex / machined armor bevel plates
    - Subtle cool-steel metallic sheen variations
    """
    yy, xx = np.mgrid[0:N, 0:N].astype(np.float64)

    # 1. Brushed titanium grain along gun length (X)
    brush = _seamless_noise(19, octaves=3, freq_x=1.0, freq_y=8.0)
    fine = 0.5 + 0.5 * np.sin((yy / N) * 2.0 * math.pi * 40.0 + brush * 1.1)
    grain = 0.6 * brush + 0.4 * fine

    # 2. Precision hexagonal / angled industrial armor lattice (4x4 seamless)
    # Use stretched diamond-hex tiles with beveled dark seam & crisp highlight lip
    sx, sy = 4.0, 4.0
    u = (xx / N) * sx
    v = (yy / N) * sy
    # Brick-staggered chamfered plates
    row = np.floor(v)
    u_st = u + (row % 2) * 0.5
    fu = (u_st % 1.0) - 0.5
    fv = (v % 1.0) - 0.5
    # Octagonal/chamfered plate signed distance (0 at edge, >0 inside)
    d_box = 0.48 - np.maximum(np.abs(fu), np.abs(fv))
    d_cham = 0.72 - (np.abs(fu) + np.abs(fv))
    dist = np.minimum(d_box, d_cham)

    # Per-plate deterministic tonal step
    col_id = (np.floor(u_st).astype(np.int32) % 4)
    row_id = (row.astype(np.int32) % 4)
    rng = np.random.default_rng(77)
    plate_vals = rng.choice([-0.65, -0.35, -0.1, 0.2, 0.55, 0.85], size=(4, 4))
    tone = plate_vals[row_id, col_id]

    seam = np.clip(1.0 - np.abs(dist) * 34.0, 0.0, 1.0)
    bevel_hi = np.clip(1.0 - np.abs(dist - 0.035) * 42.0, 0.0, 1.0) * (fv < 0.0)

    # Fine diagonal carbon-tech micro-hatch inside recessed corner pockets
    diag = np.clip(1.0 - np.abs(((u + v) * 4.0) % 1.0 - 0.5) * 14.0, 0.0, 1.0)
    in_pocket = (dist < 0.0).astype(np.float64)

    img = np.zeros((N, N, 4), dtype=np.float32)
    light = tone > 0
    img[light, 0] = 165
    img[light, 1] = 184
    img[light, 2] = 220
    img[light, 3] = tone[light] * 36 + grain[light] * 22

    img[~light, 0] = 6
    img[~light, 1] = 8
    img[~light, 2] = 14
    img[~light, 3] = (-tone[~light]) * 58 + (1.0 - grain[~light]) * 18

    # Pocket darkening + micro-hatch
    img[..., 0] = img[..., 0] * (1.0 - in_pocket * 0.7) + 8 * in_pocket * 0.7
    img[..., 1] = img[..., 1] * (1.0 - in_pocket * 0.7) + 10 * in_pocket * 0.7
    img[..., 2] = img[..., 2] * (1.0 - in_pocket * 0.7) + 16 * in_pocket * 0.7
    img[..., 3] = np.maximum(img[..., 3], in_pocket * (78 + diag * 35))

    # Crisp machined panel groove
    img[..., 0] = img[..., 0] * (1.0 - seam) + 4 * seam
    img[..., 1] = img[..., 1] * (1.0 - seam) + 5 * seam
    img[..., 2] = img[..., 2] * (1.0 - seam) + 9 * seam
    img[..., 3] = np.maximum(img[..., 3], seam * 135)

    # Crisp upper bevel catchlight
    img[..., 0] = np.clip(img[..., 0] + bevel_hi * 175, 0, 255)
    img[..., 1] = np.clip(img[..., 1] + bevel_hi * 195, 0, 255)
    img[..., 2] = np.clip(img[..., 2] + bevel_hi * 235, 0, 255)
    img[..., 3] = np.clip(np.maximum(img[..., 3], bevel_hi * 70), 0, 155)

    return Image.fromarray(img.astype(np.uint8), "RGBA")


def plasma():
    """Swirling violet-magenta dark-matter energy currents for glowing cores & conduits."""
    n1 = _seamless_noise(71, octaves=4, freq_x=1.0, freq_y=2.0)
    n2 = _seamless_noise(113, octaves=4, freq_x=2.0, freq_y=1.0)
    yy, xx = np.mgrid[0:N, 0:N] / N * 2.0 * math.pi
    warp = np.sin(xx * 2.0 + n1 * 4.2) * 0.5 + np.cos(yy * 3.0 + n2 * 3.8) * 0.5
    ridge1 = np.clip(1.0 - np.abs(warp) / 0.22, 0.0, 1.0) ** 1.5
    ridge2 = np.clip(1.0 - np.abs(n1 - n2) / 0.14, 0.0, 1.0) ** 1.8
    hot = np.clip(ridge1 * 0.85 + ridge2 * 0.95, 0.0, 1.0)
    dark_void = np.clip((0.38 - hot) * 2.2, 0.0, 1.0)

    img = np.zeros((N, N, 4), dtype=np.float32)
    # Deep shadow veins contrast against the bright Neon base color
    img[..., 0] = 35 * dark_void + 255 * hot
    img[..., 1] = 8 * dark_void + 205 * hot
    img[..., 2] = 68 * dark_void + 255 * hot
    img[..., 3] = np.clip(dark_void * 145 + hot * 215, 0, 235)
    return Image.fromarray(img.astype(np.uint8), "RGBA")


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    for name, fn in (("Riftforge_Forged", forged), ("Riftforge_Plasma", plasma)):
        p = os.path.join(OUT, name + ".png")
        fn().save(p)
        print("Wrote", p)
