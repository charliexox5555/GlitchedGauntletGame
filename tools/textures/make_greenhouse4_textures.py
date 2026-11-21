"""Greenhouse4 MaterialVariant colour maps, procedural and soft (map Greenhouse4, 2026-11-21).

    python tools/textures/make_greenhouse4_textures.py

Writes art-source/maps/Greenhouse4/textures/<Variant>_Color.png (512, tiling both ways). Colour maps only, no normal
maps (OldTown4 final-check rule: "not too much texture"). Tintable near-white; the Part colour gives the hue.
  G4_Lawn    a mown lawn: soft mottling and faint mowing stripes (2 stripes a tile)
  G4_Gravel  a raked gravel path: soft mottling and a faint fine speckle
  G4_Tile    the Palm House floor: Victorian quarry tiles, a diagonal two-tone check with thin grout (4 x 4 a tile)
The rest reuses existing soft maps (R4_Brick, OT4_Stone, OT2_Paving, Roof2_Slate colour maps). Our own pixels.
"""

from __future__ import annotations

import os
import sys

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(__file__))
import make_wharf_textures as W  # noqa: E402

OUT = os.path.join(W.ROOT, "art-source", "maps", "Greenhouse4", "textures")
N = W.N
yy, xx = W.yy, W.xx


def save(name: str, c: np.ndarray, mean: float = 0.86) -> None:
	os.makedirs(OUT, exist_ok=True)
	c = np.clip(c - c.mean() + mean, 0, 1)
	Image.fromarray((np.stack([c, c, c], axis=-1) * 255).astype(np.uint8), "RGB").save(os.path.join(OUT, f"{name}_Color.png"))
	print(f"{name}: mean {c.mean():.3f}  std {float(np.std(c)):.3f}")


def lawn():
	mott = W.smooth_noise(5) * 0.6 + W.smooth_noise(14, 2) * 0.4
	stripe = 0.5 + 0.5 * np.sign(np.sin(2 * np.pi * xx / (N / 2)))
	stripe = W.smooth_noise(1, 1) * 0 + stripe
	save("G4_Lawn", 1 - 0.07 * mott - 0.05 * stripe)


def gravel():
	mott = W.smooth_noise(6) * 0.6 + W.smooth_noise(20, 2) * 0.4
	rng = np.random.default_rng(42121)
	speck = rng.random((N, N))
	speck = (speck > 0.93).astype(float) * 0.5 + (speck < 0.05).astype(float) * -0.5
	save("G4_Gravel", 1 - 0.06 * mott + 0.05 * speck)


def tile():
	cells = 4
	cw = N / cells
	cx, cy = (xx // cw).astype(int), (yy // cw).astype(int)
	check = ((cx + cy) % 2).astype(float)
	grout = np.zeros_like(xx)
	for k in range(cells + 1):
		grout = np.maximum(grout, W.groove(xx, k * cw, 2.0))
		grout = np.maximum(grout, W.groove(yy, k * cw, 2.0))
	mott = W.smooth_noise(8, 2)
	tone = (np.sin(cx * 1.9 + cy * 2.7) * 0.5 + 0.5) * 0.03
	save("G4_Tile", 1 - 0.16 * check - 0.04 * mott - tone - 0.2 * grout, 0.8)


if __name__ == "__main__":
	lawn()
	gravel()
	tile()
