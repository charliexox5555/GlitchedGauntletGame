"""Metro4 MaterialVariant textures, procedural and soft (map Metro4, 2026-11-20).

    python tools/textures/make_metro4_textures.py

Writes art-source/maps/Metro4/textures/<Variant>_Color.png and _Normal.png (512, tiling both ways), at the Wharf v2
strength (owner: v1 was "a bit much"): colour variation and bump halved through make_wharf_textures.AMP.
  Metro_Tile    station floor: 2 x 2 square tiles a tile (2.5 studs each at 5 studs a tile), thin grout
  Metro_Brick   running-bond brick, 8 courses a tile, soft mortar
  Metro_Facade  a city facade for the far buildings: 3 x 3 windows a tile, a floor band under each row
The rest of the map reuses Wharf_Concrete / Asphalt / Ribbed / Plate. Our own pixels.
"""

from __future__ import annotations

import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(__file__))
import make_wharf_textures as W  # noqa: E402

W.OUT = os.path.join(W.ROOT, "art-source", "maps", "Metro4", "textures")
N = W.N
yy, xx = W.yy, W.xx


def tile():
	mott = W.smooth_noise(6, 2)
	grout = np.maximum(W.groove(xx, 0, 2.5), W.groove(yy, 0, 2.5))
	grout = np.maximum(grout, np.maximum(W.groove(xx, N / 2, 2.5), W.groove(yy, N / 2, 2.5)))
	# each tile a touch different in tone
	q = ((xx // (N / 2)) + 2 * (yy // (N / 2))).astype(int)
	tones = np.array([0.0, 0.025, -0.015, 0.01])[q % 4]
	color = 1 - 0.05 * mott - 0.22 * grout + tones
	height = -grout * 1.2 + mott * 0.2
	return W.save("Metro_Tile", color, height, 2.0)


def brick():
	courses = 8
	ch = N / courses
	row = (yy // ch).astype(int)
	off = (row % 2) * (N / 4)
	bw = N / 2
	u = (xx + off) % bw
	mortar = np.maximum(W.groove(yy % ch, 0, 2.2) * 1.0, np.clip(1 - np.abs(u - 0) / 2.2, 0, 1) + np.clip(1 - np.abs(u - bw) / 2.2, 0, 1))
	tone = (np.sin(row * 1.7 + ((xx + off) // bw) * 2.3) * 0.5 + 0.5) * 0.06
	mott = W.smooth_noise(8, 2)
	color = 1 - tone - 0.05 * mott - 0.25 * np.clip(mortar, 0, 1)
	height = -np.clip(mortar, 0, 1) * 1.4 + mott * 0.2
	return W.save("Metro_Brick", color, height, 2.4)


def facade():
	cells = 3
	cw = N / cells
	u = xx % cw
	v = yy % cw
	win = ((u > cw * 0.18) & (u < cw * 0.82) & (v > cw * 0.2) & (v < cw * 0.72)).astype(float)
	band = ((v > cw * 0.84) & (v < cw * 0.94)).astype(float)
	mott = W.smooth_noise(4)
	color = 1 - 0.9 * win - 0.12 * band - 0.04 * mott  # dark windows (they stay dark after the soft scale)
	height = -win * 1.0 + band * 0.4
	return W.save("Metro_Facade", color, height, 3.0)


def facade2():
	"""v2 city facade (owner: v1 buildings looked dull, not professional): 3 x 3 windows a tile (8 studs each at
	24 studs a tile), each with a light frame, a cross mullion, a sill and a head shadow, glass darker at the top
	(a sky reflection gradient). Raw values are strong because save() halves them."""
	cells = 3
	cw = N / cells
	u = xx % cw
	v = yy % cw
	fx0, fx1, fy0, fy1 = cw * 0.2, cw * 0.8, cw * 0.18, cw * 0.74
	frame = ((u > fx0 - 6) & (u < fx1 + 6) & (v > fy0 - 6) & (v < fy1 + 6)).astype(float)
	glass = ((u > fx0) & (u < fx1) & (v > fy0) & (v < fy1)).astype(float)
	mull = glass * (np.clip(1 - np.abs(u - cw / 2) / 2.5, 0, 1) + np.clip(1 - np.abs(v - (fy0 + fy1) / 2) / 2.5, 0, 1))
	sill = ((u > fx0 - 9) & (u < fx1 + 9) & (v > fy1 + 6) & (v < fy1 + 13)).astype(float)
	shadow = ((u > fx0 - 9) & (u < fx1 + 9) & (v > fy1 + 13) & (v < fy1 + 19)).astype(float)
	grad = np.clip((v - fy0) / (fy1 - fy0), 0, 1)
	mott = W.smooth_noise(4)
	color = 1 + 0.25 * (frame - glass) - glass * (1.3 - 0.45 * grad) + 0.9 * np.clip(mull, 0, 1) * glass + 0.2 * sill - 0.35 * shadow - 0.05 * mott
	height = frame * 0.4 - glass * 0.8 + sill * 0.6
	return W.save("Metro_Facade2", color, height, 2.0)


if __name__ == "__main__":
	tile()
	brick()
	facade()
	facade2()
