"""Stylized bunker MaterialVariant textures (Lobby rebuild 2026-11-04): seamless 1024 colour / normal / roughness.

    python tools/textures/make_lobby_textures_v2.py            # all
    python tools/textures/make_lobby_textures_v2.py Bunker_Floor

Style (vault/02 Art/Lobby Rebuild 2026-11-04.md): painted, low-frequency, Valorant-like. Big soft value shapes,
crisp panel seams with a light painted edge, almost no micro-noise; lighting carries the contrast. Like the first
set, colour maps are near-neutral light greys (Roblox multiplies them by BasePart.Color), so one variant serves every
wing colour. Uses the periodic helpers of make_lobby_textures.py. TILE must match StudsPerTile in
tools/studio/lobby/Materials_V2.luau.
"""

import sys

import numpy as np

from make_lobby_textures import N, Tile, normal_map, norm_mean, remap, save, smooth

TILE = {
	"Bunker_Concrete": 16.0,  # 2 x 2 cast panels of 8
	"Bunker_Floor": 16.0,  # 4 x 4 tiles of 4
	"Bunker_Metal": 8.0,  # painted steel, soft vertical strokes
	"Bunker_Grate": 4.0,  # 8 slots per tile, for vents and pad centres
}


def seam(d, width, depth):
	# Rounded V-groove: height 0 on the panel, -depth at the seam centre, `width` studs wide.
	t = np.clip(d / (width / 2), 0.0, 1.0)
	return -depth * (1.0 - t * t)


def bunker_concrete():
	t = Tile(TILE["Bunker_Concrete"], 401)
	d, cu, cv, lx, ly = t.grid_dist(8.0, 8.0)
	h = seam(d, 0.32, 0.12)
	big = t.noise(3.0, 12.0, beta=1.2)
	panel_tone = ((cu * 7 + cv * 13) % 5 - 2) * 0.012
	edge = smooth(0.3, 0.12, d) * 0.06  # painted light edge beside each seam
	col = 0.9 + 0.012 * big + panel_tone * 1.6 + edge  # calm: big blotches read as dirt at wall scale
	col = np.where(d < 0.1, col - 0.12, col)
	col = np.where(h < -0.03, col - 0.08, col)
	col = norm_mean(col, 0.9)
	rough = remap(t.noise(2.0, 8.0), 0.72, 0.86)
	save("Bunker_Concrete", col, normal_map(h, t.P, 1.0), rough)


def bunker_floor():
	t = Tile(TILE["Bunker_Floor"], 402)
	d, cu, cv, lx, ly = t.grid_dist(4.0, 4.0)
	h = seam(d, 0.22, 0.08)
	tone = ((cu * 11 + cv * 5) % 7 - 3) * 0.01
	big = t.noise(4.0, 16.0, beta=1.3)
	edge = smooth(0.24, 0.1, d) * 0.05
	col = 0.9 + 0.03 * big + tone + edge
	col = np.where(d < 0.07, col - 0.15, col)
	col = norm_mean(col, 0.9)
	rough = remap(t.noise(1.0, 6.0), 0.5, 0.68)
	save("Bunker_Floor", col, normal_map(h, t.P, 1.0), rough)


def bunker_metal():
	t = Tile(TILE["Bunker_Metal"], 403)
	strokes = t.noise(0.4, 6.0, beta=0.8, ax=0.12, ay=1.0)
	soft = t.noise(2.0, 8.0, beta=1.4)
	col = norm_mean(0.9 + 0.018 * strokes + 0.025 * soft, 0.9)
	h = 0.004 * strokes
	rough = remap(strokes * 0.5 + soft * 0.5, 0.38, 0.52)
	save("Bunker_Metal", col, normal_map(h, t.P, 1.0), rough)


def bunker_grate():
	t = Tile(TILE["Bunker_Grate"], 404)
	# Horizontal slots 0.28 tall every 0.5, with a rounded bar profile between them.
	ph = (t.y % 0.5) / 0.5
	bar = np.clip(np.sin(ph * np.pi) * 1.6, 0.0, 1.0)
	slot = ph > 0.72
	h = np.where(slot, -0.12, -0.12 + 0.12 * bar)
	frame_d, *_ = t.grid_dist(4.0, 4.0)
	h = np.where(frame_d < 0.18, 0.0, h)
	col = np.where(slot & (frame_d >= 0.18), 0.25, 0.9 + 0.04 * bar)
	col = norm_mean(col, 0.82)
	rough = np.where(slot, 0.9, 0.45).astype(np.float32)
	save("Bunker_Grate", col, normal_map(h, t.P, 1.0), rough)


ALL = {
	"Bunker_Concrete": bunker_concrete,
	"Bunker_Floor": bunker_floor,
	"Bunker_Metal": bunker_metal,
	"Bunker_Grate": bunker_grate,
}

if __name__ == "__main__":
	for name in sys.argv[1:] or ALL:
		ALL[name]()
