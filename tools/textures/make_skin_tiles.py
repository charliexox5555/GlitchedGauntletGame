"""Seamless pattern tiles for flat-material skins (round two, 2026-11-14).

Each tile is mostly transparent: only the pattern marks are opaque, so the
MeshPart's own flat Color shows through (LihFolk: tiling Texture over
Part.Color). Applied in Studio as Texture objects with StudsPerTileU/V.

    python tools/textures/make_skin_tiles.py   -> art-source/weapons/Skins/_tiles/*.png
"""
import math
import os

import numpy as np
from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "art-source", "weapons", "Skins", "_tiles")
N = 256


def rgba(rgb, alpha):
    a = np.clip(alpha, 0, 1)
    img = np.zeros((N, N, 4), np.uint8)
    img[..., 0], img[..., 1], img[..., 2] = rgb
    img[..., 3] = (a * 255).astype(np.uint8)
    return Image.fromarray(img, "RGBA")


def wave():
    """Overlapping wave scales (round two polish): rows of fans, each lower row
    covering the one above, four concentric champagne rings per fan with a
    heavier outer ring. The first version (separate small arches with gaps)
    read as a grid of icons in Studio. 4 fans across, 16 half-rows down;
    seamless. Anti-aliased lines."""
    R = N / 8.0                                      # fan radius: 4 fans across (centres 2R apart)
    yy, xx = np.mgrid[0:N, 0:N].astype(float) + .5
    best_cy = np.full((N, N), -1e9)
    best_d = np.zeros((N, N))
    rows = int(N / (R / 2))                          # half-radius row spacing
    for j in range(-2, rows + 3):                    # top to bottom: lower rows win
        cy = j * R / 2
        off = (j % 2) * R
        for i in range(-1, 5):
            cx = i * 2 * R + off
            for dx in (-N, 0, N):                    # wrap for a seamless tile
                for dy in (-N, 0, N):
                    d = np.hypot(xx - (cx + dx), yy - (cy + dy))
                    inside = (d < R) & (yy <= cy + dy)  # upper half-disc only
                    win = inside & (cy + dy > best_cy)
                    best_cy = np.where(win, cy + dy, best_cy)
                    best_d = np.where(win, d, best_d)
    alpha = np.zeros((N, N))
    for k, w in ((1.0, 1.7), (.75, 1.1), (.5, 1.1), (.25, 1.1)):
        alpha = np.maximum(alpha, np.clip(w + .5 - np.abs(best_d - R * k + w * .5), 0, 1))
    alpha[best_cy < -1e8] = 0
    return rgba((214, 176, 102), alpha)


def carbon():
    """Twill weave: 45-degree checker of light and dark bars, semi-opaque."""
    y, x = np.mgrid[0:N, 0:N] / N * 8.0
    u, v = x + y, x - y
    ck = ((np.floor(u) + np.floor(v)) % 2).astype(float)
    shade = np.where(ck > 0, 1.0, 0.0)
    img = np.zeros((N, N, 4), np.uint8)
    img[..., :3] = np.where(shade[..., None] > 0, 70, 12)
    img[..., 3] = 120
    return Image.fromarray(img, "RGBA")


def _seamless_noise(seed, octaves=4):
    rng = np.random.default_rng(seed)
    acc = np.zeros((N, N))
    y, x = np.mgrid[0:N, 0:N] / N * 2 * math.pi
    for o in range(octaves):
        f = 2 ** o
        for _ in range(3):
            a, b, ph = rng.integers(1, 3, 2) * f, None, rng.random() * 6.28
            acc += np.sin(a[0] * x + a[1] * y + ph) / f
    return (acc - acc.min()) / (acc.max() - acc.min())


def foil():
    """Thermal-foil crinkle, faceted (round two polish): seamless Voronoi cells,
    each a flat facet lit lighter or darker like crumpled foil catching light,
    with thin dark creases between them. Crisp edges instead of the first
    version's soft noise smudges (read as hand-drawn in Studio)."""
    rng = np.random.default_rng(11)
    pts = rng.random((64, 2)) * N
    shade = rng.choice([-1.0, -.55, 0.0, .45, .85, 1.0], size=len(pts))
    yy, xx = np.mgrid[0:N, 0:N].astype(float) + .5
    d1 = np.full((N, N), 1e9); d2 = np.full((N, N), 1e9); idx = np.zeros((N, N), int)
    for k, (px, py) in enumerate(pts):
        for dx in (-N, 0, N):
            for dy in (-N, 0, N):
                d = np.hypot((xx - px - dx) * .6, yy - py - dy)   # wrinkles run along the gun
                closer = d < d1
                d2 = np.where(closer, d1, np.minimum(d2, d))
                idx = np.where(closer, k, idx)
                d1 = np.where(closer, d, d1)
    s = shade[idx]
    crease = np.clip(1.2 - (d2 - d1) * 1.4, 0, 1)    # ~1 px dark line on cell borders
    img = np.zeros((N, N, 4), np.float32)
    light = s > 0
    img[light, :3] = (255, 244, 214)
    img[light, 3] = s[light] * 95
    img[~light, :3] = (60, 38, 8)
    img[~light, 3] = -s[~light] * 85
    img[..., :3] = img[..., :3] * (1 - crease[..., None]) + np.array((40, 24, 4)) * crease[..., None]
    img[..., 3] = np.maximum(img[..., 3], crease * 140)
    return Image.fromarray(np.clip(img, 0, 255).astype(np.uint8), "RGBA")


def ruby():
    """Jewel marbling: brighter red veins over the part's deep red."""
    n = _seamless_noise(7)
    vein = np.clip(1 - np.abs(n - .55) / .035, 0, 1)
    return rgba((190, 44, 56), vein * .40)          # subtle: read as depth, not stains


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    for name, fn in (("Giltfold_Wave", wave), ("Payload_Carbon", carbon), ("Payload_Foil", foil), ("Sealwork_Ruby", ruby)):
        p = os.path.join(OUT, name + ".png")
        fn().save(p)
        print(p)
