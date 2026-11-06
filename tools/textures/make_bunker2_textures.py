"""Bunker2 MaterialVariant textures (vault/01 Design/Maps/Bunker2.md -> Textures): six seamless 512 colour + normal maps.

    python tools/textures/make_bunker2_textures.py [Bunk2_Board ...]

Made from the kit-sheet concept's swatch row (art-source/maps/Bunker2/concepts/03-kit-sheet.png): board-formed concrete,
bunker paint, honed floor, painted steel plate, brushed steel, brushed brass. Colour maps are near-white (mean ~0.86)
so BasePart.Color tints them by role (tools/maps/bunker2_style.py); wear is baked in (chips, tie holes, seams), not
added as decals. TILE must match StudsPerTile in bunker2_style.VARIANTS. Writes art-source/maps/Bunker2/textures/
<Name>_color.png / _normal.png / _preview.png (the roughness map is written but not uploaded).
Uses the periodic helpers of make_lobby_textures.py at N = 512.
"""

import os
import sys

import numpy as np

import make_lobby_textures as T

T.N = 512
T.OUT = os.path.join(T.ROOT, "art-source", "maps", "Bunker2", "textures")
Tile, normal_map, norm_mean, remap, save, smooth = T.Tile, T.normal_map, T.norm_mean, T.remap, T.save, T.smooth

TILE = {
	"Bunk2_Board": 8.0,
	"Bunk2_Paint": 8.0,
	"Bunk2_Floor": 16.0,
	"Bunk2_Steel": 8.0,
	"Bunk2_Brushed": 4.0,
	"Bunk2_Brass": 4.0,
}


def groove(d, width, depth):
	t = np.clip(d / (width / 2), 0.0, 1.0)
	return -depth * (1.0 - t * t)


def dots(t, centres, radius, depth):
	"""Round holes (tie holes, rivets as negative depth = bumps) at the given stud centres: height field."""
	h = np.zeros((T.N, T.N), np.float32)

	def fn(dx, dy):
		r = np.sqrt(dx * dx + dy * dy)
		return np.clip(1.0 - r / radius, 0.0, 1.0) ** 0.6

	for cx, cy in centres:
		t.stamp(h, cx, cy, radius, fn)
	return h * depth


def board():
	# Formwork panels 4 wide x 2 tall, board lines every 0.5 inside them, a tie hole at each panel's quarter points,
	# a light lip along the panel joints, soft per-panel tone and faint vertical bleed streaks.
	t = Tile(TILE["Bunk2_Board"], 611)
	d, cu, cv, lx, ly = t.grid_dist(4.0, 2.0)
	h = groove(d, 0.14, 0.06)
	board_d = np.abs(((t.y + 0.25) % 0.5) - 0.25)
	h += groove(board_d, 0.05, 0.012) * (d > 0.12)
	ties = [(u * 4.0 + 1.0, v * 2.0 + 1.0) for u in range(2) for v in range(4)] + [(u * 4.0 + 3.0, v * 2.0 + 1.0) for u in range(2) for v in range(4)]
	hole = dots(t, ties, 0.09, 1.0)
	h -= hole * 0.05
	grain = t.noise(0.08, 0.6, beta=0.8, ax=0.25)  # long horizontal board grain
	big = t.noise(1.5, 8.0, beta=1.3)
	streak = t.noise(0.3, 3.0, beta=1.0, ax=4.0, ay=0.25)  # vertical bleed
	tone = ((cu * 7 + cv * 3) % 5 - 2) * 0.018
	col = 0.88 + 0.03 * big + 0.012 * grain + 0.014 * streak + tone
	col += smooth(0.14, 0.05, d) * 0.04  # light lip beside each joint
	col = np.where(d < 0.035, col - 0.13, col)
	col -= hole * 0.22
	col = norm_mean(col, 0.86)
	save("Bunk2_Board", col, normal_map(h + grain * 0.004, t.P, 1.0), remap(t.noise(1.0, 6.0), 0.7, 0.85))


def paint():
	# Bunker paint over concrete: roller texture, a few chips showing lighter concrete with dark rims, soft scuffs.
	t = Tile(TILE["Bunk2_Paint"], 612)
	roll = t.noise(0.1, 0.5, beta=0.6, ax=0.5)
	big = t.noise(2.0, 8.0, beta=1.2)
	chipn = t.noise(0.35, 2.5, beta=1.6)
	chip = smooth(2.6, 2.85, chipn)  # sparse chips
	rim = smooth(2.4, 2.6, chipn) - chip
	scuff = smooth(1.2, 2.2, t.noise(0.4, 2.5, beta=1.0, ax=0.3)) * 0.05
	col = 0.86 + 0.02 * big + 0.01 * roll - scuff
	col = col * (1 - chip) + 1.0 * chip - rim * 0.06
	col = norm_mean(col, 0.86)
	h = roll * 0.004 - chip * 0.03 + big * 0.003
	save("Bunk2_Paint", col, normal_map(h, t.P, 1.0), remap(t.noise(1.0, 6.0), 0.5, 0.7))


def floor():
	# Honed concrete: saw cuts every 8 studs, aggregate speckle, soft cloud, faint long scuffs.
	t = Tile(TILE["Bunk2_Floor"], 613)
	d, cu, cv, lx, ly = t.grid_dist(8.0, 8.0)
	h = groove(d, 0.16, 0.06)
	speck = t.noise(0.04, 0.12, beta=0.0)
	cloud = t.noise(2.0, 16.0, beta=1.4)
	scuff = t.noise(0.2, 4.0, beta=1.0, ax=0.15, angle=0.4)
	tone = ((cu * 5 + cv * 3) % 4 - 1.5) * 0.015
	col = 0.88 + 0.035 * cloud + 0.018 * np.clip(speck, -2, 2) + 0.005 * scuff + tone
	col = np.where(d < 0.05, col - 0.18, col)
	col += smooth(0.16, 0.06, d) * 0.03
	col = norm_mean(col, 0.86)
	save("Bunk2_Floor", col, normal_map(h + speck * 0.002, t.P, 1.0), remap(t.noise(1.0, 8.0), 0.45, 0.65))


def steel():
	# Painted steel plate: plates 4 wide x 8 tall with welded seams, rivet rows 0.4 in from each seam, edge wear on the
	# plate edges, faint vertical rain streaks.
	t = Tile(TILE["Bunk2_Steel"], 614)
	d, cu, cv, lx, ly = t.grid_dist(4.0, 8.0)
	h = groove(d, 0.1, 0.035)
	riv = []
	for u in range(2):
		for k in range(10):
			y = 0.4 + k * 0.8
			riv += [(u * 4.0 + 0.35, y), (u * 4.0 + 3.65, y)]
	bumps = dots(t, riv, 0.09, 1.0)
	h += bumps * 0.03
	wear = smooth(0.25, 0.05, d) * smooth(0.6, 1.6, t.noise(0.1, 0.8, beta=1.0))
	big = t.noise(1.5, 8.0, beta=1.2)
	streak = t.noise(0.2, 3.0, beta=1.0, ax=5.0, ay=0.2)
	col = 0.86 + 0.025 * big + 0.012 * streak + wear * 0.14 + bumps * 0.06
	col = np.where(d < 0.03, col - 0.15, col)
	col = norm_mean(col, 0.84)
	save("Bunk2_Steel", col, normal_map(h, t.P, 1.0), remap(t.noise(1.0, 6.0), 0.45, 0.65))


def brushed(name, seed, cloud_amp):
	t = Tile(TILE[name], seed)
	fine = t.noise(0.02, 0.6, beta=0.5, ax=0.08)  # long horizontal strokes
	big = t.noise(0.8, 4.0, beta=1.2)
	col = 0.86 + 0.035 * fine + cloud_amp * big
	col = norm_mean(col, 0.86)
	save(name, col, normal_map(fine * 0.0025, t.P, 1.0), remap(t.noise(0.5, 3.0), 0.3, 0.45))


ALL = {
	"Bunk2_Board": board,
	"Bunk2_Paint": paint,
	"Bunk2_Floor": floor,
	"Bunk2_Steel": steel,
	"Bunk2_Brushed": lambda: brushed("Bunk2_Brushed", 615, 0.02),
	"Bunk2_Brass": lambda: brushed("Bunk2_Brass", 616, 0.035),
}

if __name__ == "__main__":
	names = sys.argv[1:] or list(ALL)
	for n in names:
		ALL[n]()
