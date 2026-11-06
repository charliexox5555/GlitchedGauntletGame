"""Snowpeak2 MaterialVariant textures (vault/01 Design/Maps/Snowpeak2.md -> Textures): six seamless 512 colour + normal maps.

    python tools/textures/make_snowpeak2_textures.py [Snow2_Timber ...]

From the concepts (art-source/maps/Snowpeak2/concepts/02-hero, 03-kit-sheet): horizontal timber boards with grain and
dark seams, coursed fieldstone, soft snow with sparkle and drift ripples, standing-seam metal roofing, granite rock,
and deck planks. Near-white colour maps (mean ~0.86) tinted by BasePart.Color per role
(tools/maps/snowpeak2_style.py). TILE must match StudsPerTile in snowpeak2_style.VARIANTS.
"""

import os
import sys

import numpy as np

import make_lobby_textures as T

T.N = 512
T.OUT = os.path.join(T.ROOT, "art-source", "maps", "Snowpeak2", "textures")
Tile, normal_map, norm_mean, remap, save, smooth = T.Tile, T.normal_map, T.norm_mean, T.remap, T.save, T.smooth

TILE = {
	"Snow2_Timber": 8.0,
	"Snow2_Stone": 8.0,
	"Snow2_Snow": 16.0,
	"Snow2_Roof": 8.0,
	"Snow2_Rock": 16.0,
	"Snow2_Plank": 8.0,
}


def groove(d, width, depth):
	t = np.clip(d / (width / 2), 0.0, 1.0)
	return -depth * (1.0 - t * t)


def timber():
	# Horizontal boards 0.8 tall, staggered butt joints, long grain, a few knots, dark seams.
	t = Tile(TILE["Snow2_Timber"], 711)
	bh = 0.8
	row = np.floor(t.y / bh).astype(int)
	ly = t.y - row * bh
	dseam = np.minimum(ly, bh - ly)
	off = (row * 2.7) % 8.0
	lx = (t.x + off) % 4.0
	djoint = np.minimum(lx, 4.0 - lx)
	h = groove(dseam, 0.1, 0.06) + groove(djoint, 0.06, 0.03)
	grain = t.noise(0.05, 1.2, beta=0.7, ax=0.12)
	big = t.noise(1.0, 6.0, beta=1.2)
	tone = ((row * 7) % 5 - 2) * 0.025
	col = 0.86 + 0.05 * grain + 0.025 * big + tone
	col = np.where(dseam < 0.04, col - 0.3, col)
	col = np.where(djoint < 0.025, col - 0.2, col)
	col = norm_mean(col, 0.84)
	save("Snow2_Timber", col, normal_map(h + grain * 0.006, t.P, 1.0), remap(t.noise(1.0, 6.0), 0.6, 0.8))


def stone():
	# Coursed fieldstone: rows 0.9-1.3 tall, stones 1.2-2.4 long, deep mortar joints, per-stone tone and rounded faces.
	t = Tile(TILE["Snow2_Stone"], 712)
	rng = np.random.default_rng(712)
	rows = [0.0]
	while rows[-1] < 8.0 - 0.9:
		rows.append(rows[-1] + rng.choice([1.0, 1.15, 1.3, 0.9]))
	rows[-1] = 8.0
	h = np.zeros((T.N, T.N), np.float32)
	col = np.zeros((T.N, T.N), np.float32)
	for r in range(len(rows) - 1):
		y0, y1 = rows[r], rows[r + 1]
		xs = [0.0]
		while xs[-1] < 8.0 - 1.2:
			xs.append(xs[-1] + rng.uniform(1.2, 2.4))
		xs[-1] = 8.0
		shift = rng.uniform(0, 8)
		band = (t.y >= y0) & (t.y < y1)
		xx = (t.x + shift) % 8.0
		for i in range(len(xs) - 1):
			x0, x1 = xs[i], xs[i + 1]
			m = band & (xx >= x0) & (xx < x1)
			dx = np.minimum(xx - x0, x1 - xx)
			dy = np.minimum(t.y - y0, y1 - t.y)
			d = np.minimum(dx, dy)
			face = np.clip(d / 0.35, 0, 1) ** 0.5 * 0.08
			h = np.where(m, face, h)
			col = np.where(m, 0.86 + rng.uniform(-0.07, 0.07) + 0.0 * d, col)
	speck = t.noise(0.04, 0.3, beta=0.5)
	big = t.noise(0.5, 3.0, beta=1.0)
	col = col + 0.03 * speck + 0.03 * big
	col = np.where(h < 0.012, 0.55, col)  # mortar
	col = norm_mean(col, 0.82)
	save("Snow2_Stone", col, normal_map(h + speck * 0.003, t.P, 1.5), remap(t.noise(1.0, 6.0), 0.75, 0.9))


def snow():
	# Soft snow: low-frequency drift ripples, faint footprint-sized dimples, fine sparkle.
	t = Tile(TILE["Snow2_Snow"], 713)
	drift = t.noise(2.0, 12.0, beta=1.4, ax=0.6)
	ripple = t.noise(0.4, 2.0, beta=1.0, ax=0.4, angle=0.5)
	sparkle = np.clip(t.noise(0.03, 0.08, beta=0.0) - 2.2, 0, 1)
	col = 0.9 + 0.025 * drift + 0.012 * ripple + 0.08 * sparkle
	col = norm_mean(col, 0.88)
	h = drift * 0.05 + ripple * 0.012
	save("Snow2_Snow", col, normal_map(h, t.P, 1.0), remap(t.noise(1.0, 6.0), 0.55, 0.75))


def roof():
	# Standing-seam metal roofing: raised seams every 1.6 studs, faint vertical streaks.
	t = Tile(TILE["Snow2_Roof"], 714)
	lx = t.x % 1.6
	d = np.minimum(lx, 1.6 - lx)
	h = np.clip(1.0 - d / 0.08, 0, 1) * 0.05
	streak = t.noise(0.2, 4.0, beta=1.0, ax=6.0, ay=0.2)
	col = 0.84 + 0.02 * streak + np.clip(1.0 - d / 0.08, 0, 1) * 0.1 - np.clip(1.0 - np.abs(d - 0.12) / 0.04, 0, 1) * 0.08
	col = norm_mean(col, 0.84)
	save("Snow2_Roof", col, normal_map(h, t.P, 1.0), remap(t.noise(1.0, 6.0), 0.4, 0.6))


def rock():
	t = Tile(TILE["Snow2_Rock"], 715)
	cr = t.noise(0.3, 4.0, beta=1.3, ax=1.8)
	fine = t.noise(0.05, 0.4, beta=0.6)
	crack = np.abs(t.noise(0.6, 3.0, beta=1.2)) < 0.05
	col = 0.84 + 0.05 * cr + 0.03 * fine
	col = np.where(crack, col - 0.2, col)
	col = norm_mean(col, 0.82)
	save("Snow2_Rock", col, normal_map(cr * 0.08 + fine * 0.01 - crack * 0.04, t.P, 1.0), remap(t.noise(1.0, 6.0), 0.8, 0.95))


def plank():
	# Deck planks along X: 1.0 wide, butt joints every 4 (staggered), nail heads.
	t = Tile(TILE["Snow2_Plank"], 716)
	row = np.floor(t.y / 1.0).astype(int)
	ly = t.y - row
	dseam = np.minimum(ly, 1.0 - ly)
	lx = (t.x + (row * 1.7) % 4.0) % 4.0
	dj = np.minimum(lx, 4.0 - lx)
	grain = t.noise(0.05, 1.0, beta=0.7, ax=0.12)
	tone = ((row * 5) % 4 - 1.5) * 0.03
	col = 0.86 + 0.05 * grain + tone
	col = np.where(dseam < 0.05, col - 0.35, col)
	col = np.where(dj < 0.03, col - 0.25, col)
	col = norm_mean(col, 0.84)
	h = groove(dseam, 0.12, 0.05) + groove(dj, 0.06, 0.03)
	save("Snow2_Plank", col, normal_map(h + grain * 0.005, t.P, 1.0), remap(t.noise(1.0, 6.0), 0.6, 0.8))


ALL = {"Snow2_Timber": timber, "Snow2_Stone": stone, "Snow2_Snow": snow, "Snow2_Roof": roof, "Snow2_Rock": rock, "Snow2_Plank": plank}

if __name__ == "__main__":
	for n in sys.argv[1:] or list(ALL):
		ALL[n]()
