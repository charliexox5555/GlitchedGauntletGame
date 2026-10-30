"""Lobby MaterialVariant textures (phase 1 step 5): seamless 1024 x 1024 colour, normal and roughness maps.

    python tools/textures/make_lobby_textures.py            # all six variants
    python tools/textures/make_lobby_textures.py Lobby_Rock  # one

Writes art-source/lobby/textures/<Variant>_color.png, _normal.png (OpenGL, +Y up) and _roughness.png, plus
_preview.png (colour shaded by the normal under a top-left light, for a quick look).

The looks port the procedural materials in tools/blender/lobbykit.py (_concrete_board, _concrete_polished,
_concrete_dark, _terrazzo, _rock, _oak). Roblox multiplies a MaterialVariant's ColorMap by BasePart.Color (checked
in Studio), so every colour map is a NEAR-NEUTRAL LIGHT GREY with the detail in luminance: the part's Color (the
style-sheet colour) sets the hue, and one variant serves several colours (ConcreteBoard and its shade, ConcreteDark
and honed). Map means sit near 0.9 so the rendered average lands close to the style-sheet colour.

Everything is periodic on the tile: noise is FFT-filtered white noise and every stamped feature wraps around the
edges, so all maps tile without seams. Each variant has a fixed seed. TILE (studs per tile) must match
StudsPerTile in tools/studio/lobby/Materials.luau.
"""

import os
import sys

import numpy as np
from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "art-source", "lobby", "textures")
N = 1024

# Studs per tile (Materials.luau StudsPerTile). Grids land on whole cells:
#   ConcreteBoard 12.8 = 4 x 2 formwork panels of 3.2 x 6.4 (more panel variety than 6.4, still 80 px per stud)
#   ConcreteDark  20   = 4 x 4 saw-cut cells of 5
TILE = {
	"Lobby_ConcreteBoard": 12.8,
	"Lobby_ConcretePolished": 16.0,
	"Lobby_ConcreteDark": 20.0,
	"Lobby_Terrazzo": 12.0,
	"Lobby_Rock": 16.0,
	"Lobby_Oak": 8.0,
}


# ---------------------------------------------------------------- periodic helpers


class Tile:
	def __init__(self, studs, seed):
		self.S = studs
		self.P = N / studs  # pixels per stud
		self.rng = np.random.default_rng(seed)
		f = np.fft.fftfreq(N, d=1.0 / N) / studs  # cycles per stud
		self.fx = f[None, :]
		self.fy = f[:, None]
		c = (np.arange(N) + 0.5) / self.P
		self.x = np.broadcast_to(c[None, :], (N, N))  # studs, right
		self.y = np.broadcast_to(c[:, None], (N, N))  # studs, down the image

	def noise(self, wl_min, wl_max, beta=1.0, ax=1.0, ay=1.0, angle=0.0):
		# Zero-mean, unit-std periodic noise with wavelengths between wl_min and wl_max studs and a 1/f^beta
		# spectrum. ax/ay stretch it: ax < 1 makes features longer along x (grain).
		fx, fy = self.fx, self.fy
		if angle:
			ca, sa = np.cos(angle), np.sin(angle)
			fx, fy = fx * ca + fy * sa, -fx * sa + fy * ca
		f = np.sqrt((fx / ax) ** 2 + (fy / ay) ** 2)
		lo, hi = 1.0 / wl_max, 1.0 / wl_min
		band = 1.0 / (1.0 + (lo / np.maximum(f, 1e-6)) ** 8) / (1.0 + (f / hi) ** 8)
		amp = band * np.power(np.maximum(f, lo * 0.5), -beta)
		amp[0, 0] = 0.0
		w = self.rng.standard_normal((N, N))
		n = np.real(np.fft.ifft2(np.fft.fft2(w) * amp))
		n -= n.mean()
		return (n / (n.std() + 1e-9)).astype(np.float32)

	def grid_dist(self, pu, pv):
		# Distance (studs) to the nearest line of a pu x pv grid, the cell index and local position in the cell.
		cu, cv = np.floor(self.x / pu), np.floor(self.y / pv)
		lx, ly = self.x - cu * pu, self.y - cv * pv
		d = np.minimum(np.minimum(lx, pu - lx), np.minimum(ly, pv - ly))
		return d, cu.astype(int), cv.astype(int), lx, ly

	def roll(self, a, dx, dy):
		return np.roll(np.roll(a, int(dy), axis=0), int(dx), axis=1)

	def stamp(self, target, cx, cy, radius, fn):
		# Calls fn(dx, dy) (studs from the centre) on the wrapped pixel window around (cx, cy) and writes
		# target = max(target, result). Wraps across the edges.
		r = int(np.ceil(radius * self.P)) + 2
		px, py = int(cx * self.P), int(cy * self.P)
		cols = np.arange(px - r, px + r + 1)
		rows = np.arange(py - r, py + r + 1)
		dx = (cols + 0.5) / self.P - cx
		dy = (rows + 0.5) / self.P - cy
		val = fn(dx[None, :], dy[:, None])
		ix = np.ix_(rows % N, cols % N)
		target[ix] = np.maximum(target[ix], val)


def smooth(e0, e1, x):
	t = np.clip((x - e0) / (e1 - e0), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


def remap(n, lo, hi):
	# Unit-std noise -> [lo, hi] (about +-2 sigma), clipped.
	return lo + (hi - lo) * np.clip(n * 0.25 + 0.5, 0.0, 1.0)


def normal_map(height, P, strength=1.0):
	# Height in studs -> OpenGL tangent-space normal (+Y = up the image), wrapping at the edges.
	dhdx = (np.roll(height, -1, axis=1) - np.roll(height, 1, axis=1)) * (P / 2.0)
	dhd_row = (np.roll(height, -1, axis=0) - np.roll(height, 1, axis=0)) * (P / 2.0)
	nx = -dhdx * strength
	ny = dhd_row * strength  # up the image = -row, so -dh/dy_up = +dh/drow
	nz = np.ones_like(height)
	ln = np.sqrt(nx * nx + ny * ny + nz * nz)
	return np.stack([nx / ln, ny / ln, nz / ln], axis=-1)


def save(name, color, normal, rough):
	os.makedirs(OUT, exist_ok=True)
	c = np.clip(color, 0.0, 1.0)
	if c.ndim == 2:
		c = np.stack([c, c, c], axis=-1)
	Image.fromarray((c * 255 + 0.5).astype(np.uint8), "RGB").save(os.path.join(OUT, f"{name}_color.png"))
	nm = ((normal * 0.5 + 0.5) * 255 + 0.5).clip(0, 255).astype(np.uint8)
	Image.fromarray(nm, "RGB").save(os.path.join(OUT, f"{name}_normal.png"))
	r = (np.clip(rough, 0.0, 1.0) * 255 + 0.5).astype(np.uint8)
	Image.fromarray(r, "L").save(os.path.join(OUT, f"{name}_roughness.png"))
	# Preview: colour x lambert from a light up and to the left (catches inverted normals: grooves must shade
	# dark on their top edge... i.e. the edge facing away from the light).
	light = np.array([-0.4, 0.55, 0.73])
	light /= np.linalg.norm(light)
	lam = np.clip((normal * light).sum(-1), 0.0, 1.0)
	pv = c * (0.25 + 0.75 * lam / light[2])[..., None]
	Image.fromarray((np.clip(pv, 0, 1) * 255).astype(np.uint8), "RGB").save(os.path.join(OUT, f"{name}_preview.png"))
	print(f"{name}: colour mean {c.mean():.3f} min {c.min():.3f} max {c.max():.3f}, rough {rough.mean():.2f}")


def norm_mean(f, mean):
	return f * (mean / f.mean())


# ---------------------------------------------------------------- variants


def concrete_board():
	# Board-formed concrete: 3.2 x 6.4 formwork panels, 0.1 V-groove seams, 6 tie holes per panel (2 x 3, inset 0.4)
	# with a faint lighter cone-plug ring and a faint stain below, +-3% tone per panel, soft mottling (a different
	# patch of the mottle field per panel, so seams show a pour change), faint horizontal formwork grain, pinholes.
	t = Tile(TILE["Lobby_ConcreteBoard"], 11)
	PW, PH = 3.2, 6.4
	d, cu, cv, lx, ly = t.grid_dist(PW, PH)
	groove = np.clip(1.0 - d / 0.05, 0.0, 1.0)  # V profile, 0.1 wide
	mottle_f = t.noise(0.6, 8.0, 1.1)
	fine_f = t.noise(0.08, 0.6, 0.6)
	grain_f = t.noise(0.05, 6.0, 1.0, ax=0.06, ay=1.0)
	pores_f = t.noise(0.03, 0.12, 0.0)
	cols, rows = int(round(t.S / PW)), int(round(t.S / PH))
	tone = np.ones((N, N), np.float32)
	mottle = np.zeros((N, N), np.float32)
	grain = np.zeros((N, N), np.float32)
	fine = np.zeros((N, N), np.float32)
	for i in range(cols):
		for j in range(rows):
			m = (cu == i) & (cv == j)
			tone[m] = 1.0 + t.rng.uniform(-0.035, 0.035)
			ox, oy = t.rng.integers(0, N, 2)
			mottle[m] = t.roll(mottle_f, ox, oy)[m]
			grain[m] = t.roll(grain_f, oy, ox)[m]
			fine[m] = t.roll(fine_f, ox // 2, oy // 3)[m]
	# Tie holes and their plug rings (positions in panel space; V runs up, image y runs down: holes are symmetric).
	hx = np.minimum(np.abs(lx - 0.4), np.abs(lx - (PW - 0.4)))
	hy_all = [np.abs(ly - yy) for yy in (0.4, PH / 2, PH - 0.4)]
	hy = np.minimum(np.minimum(hy_all[0], hy_all[1]), hy_all[2])
	hr = np.sqrt(hx * hx + hy * hy)
	hole = 1.0 - smooth(0.05, 0.07, hr)
	plug = smooth(0.06, 0.075, hr) * (1.0 - smooth(0.1, 0.115, hr))
	# Stain: a faint streak running ~1.4 down the wall from each hole (down = +image y).
	sw = remap(t.noise(0.3, 2.0), 0.05, 0.12)
	across = 1.0 - smooth(0.0, 1.0, hx / sw)
	streak = np.zeros((N, N), np.float32)
	for yy in (0.4, PH / 2, PH - 0.4):
		dy = ly - yy
		streak = np.maximum(streak, smooth(0.08, 0.25, dy) * (1.0 - smooth(0.25, 1.4, dy)))
	streak = streak * across * (1.0 - hole)
	pores = smooth(2.3, 2.9, pores_f) * (1.0 - groove)

	f = tone * remap(mottle, 0.94, 1.05) * remap(grain, 0.975, 1.025) * remap(fine, 0.975, 1.025)
	f *= 1.0 - 0.28 * groove**0.8
	f *= 1.0 - 0.28 * hole
	f *= 1.0 + 0.06 * plug
	f *= 1.0 - 0.045 * streak
	f *= 1.0 - 0.22 * pores
	color = norm_mean(f, 0.9)
	rough = remap(mottle, 0.84, 0.74) + 0.08 * hole + 0.05 * groove
	h = -0.035 * groove - 0.05 * hole + 0.004 * plug - 0.008 * pores
	h += 0.0012 * fine + 0.0012 * grain
	save("Lobby_ConcreteBoard", color, normal_map(h, t.P), rough)


def concrete_polished():
	# Polished (trowelled) concrete: cloudy tone, faint sparse aggregate (some lighter, some darker), satin roughness
	# with smudges and faint trowel swirls; almost flat.
	t = Tile(TILE["Lobby_ConcretePolished"], 22)
	cloud = remap(t.noise(1.5, 16.0, 1.2), 0.94, 1.05)
	speck = np.zeros((N, N), np.float32)
	speck_dark = np.zeros((N, N), np.float32)
	count = int(t.S * t.S * 3.0)
	for _ in range(count):
		cx, cy = t.rng.uniform(0, t.S, 2)
		r = t.rng.uniform(0.025, 0.07)
		k = t.rng.uniform(0.35, 1.0)
		tgt = speck if t.rng.random() < 0.55 else speck_dark
		t.stamp(tgt, cx, cy, r, lambda dx, dy, r=r, k=k: k * (1.0 - smooth(r * 0.6, r, np.sqrt(dx * dx + dy * dy))))
	f = cloud * (1.0 + 0.08 * speck - 0.12 * speck_dark)
	f *= remap(t.noise(0.05, 0.3, 0.3), 0.985, 1.015)
	color = norm_mean(f, 0.9)
	smudge = t.noise(0.8, 8.0, 1.0)
	swirl = np.zeros((N, N), np.float32)
	# Trowel swirls: overlapping faint arcs (shinier where the steel trowel burnished).
	for _ in range(60):
		cx, cy = t.rng.uniform(0, t.S, 2)
		R = t.rng.uniform(0.8, 2.2)
		a0 = t.rng.uniform(0, 2 * np.pi)
		span = t.rng.uniform(0.8, 2.0)

		def arc(dx, dy, R=R, a0=a0, span=span):
			rr = np.sqrt(dx * dx + dy * dy)
			a = np.mod(np.arctan2(dy, dx) - a0, 2 * np.pi)
			on = (a < span).astype(np.float32) * np.sin(np.clip(a / span, 0, 1) * np.pi)
			return on * (1.0 - smooth(0.0, 0.35, np.abs(rr - R)))

		t.stamp(swirl, cx, cy, R + 0.4, arc)
	# Satin, not glossy: Roblox has no screen-space reflections, so a low roughness mirrors the sky probe and
	# the floor turns blue indoors (seen in Studio). 0.36-0.5 keeps a soft sheen with visible smudges.
	rough = remap(smudge, 0.5, 0.36) - 0.06 * swirl + 0.06 * speck_dark
	h = 0.0007 * t.noise(0.15, 1.5, 0.8) - 0.002 * speck_dark
	save("Lobby_ConcretePolished", color, normal_map(h, t.P), rough)


def concrete_dark():
	# Honed dark concrete: matte, fine light aggregate specks, saw-cut joints on a 5-stud grid (slight tone change
	# per slab), faint cloud.
	t = Tile(TILE["Lobby_ConcreteDark"], 33)
	d, cu, cv, _, _ = t.grid_dist(5.0, 5.0)
	cut = 1.0 - smooth(0.02, 0.045, d)
	slab = np.ones((N, N), np.float32)
	cells = int(round(t.S / 5.0))
	for i in range(cells):
		for j in range(cells):
			slab[(cu == i) & (cv == j)] = 1.0 + t.rng.uniform(-0.025, 0.025)
	cloud = remap(t.noise(0.8, 12.0, 1.1), 0.9, 1.06)
	speck = np.zeros((N, N), np.float32)
	for _ in range(int(t.S * t.S * 5.0)):
		cx, cy = t.rng.uniform(0, t.S, 2)
		r = t.rng.uniform(0.02, 0.05)
		k = t.rng.uniform(0.4, 1.0)
		t.stamp(speck, cx, cy, r, lambda dx, dy, r=r, k=k: k * (1.0 - smooth(r * 0.5, r, np.sqrt(dx * dx + dy * dy))))
	f = slab * cloud * (1.0 + 0.2 * speck) * remap(t.noise(0.04, 0.25, 0.2), 0.96, 1.04)
	f *= 1.0 - 0.5 * cut
	color = norm_mean(f, 0.86)
	rough = remap(t.noise(1.0, 10.0), 0.5, 0.64) + 0.2 * cut - 0.05 * speck
	h = -0.03 * cut + 0.002 * t.noise(0.1, 1.0, 0.5)
	save("Lobby_ConcreteDark", color, normal_map(h, t.P), rough)


def terrazzo():
	# Terrazzo: warm matrix (the Color) with fine light chips in two sizes and ~30% grey chips; angular chips
	# (rotated diamonds of random aspect); polished, satin.
	t = Tile(TILE["Lobby_Terrazzo"], 44)
	matrix = remap(t.noise(1.0, 12.0, 1.0), 0.97, 1.03) * remap(t.noise(0.04, 0.3, 0.2), 0.985, 1.015)
	light = np.zeros((N, N), np.float32)
	grey = np.zeros((N, N), np.float32)
	for dens, rlo, rhi in ((5.0, 0.05, 0.09), (22.0, 0.022, 0.04)):
		for _ in range(int(t.S * t.S * dens)):
			cx, cy = t.rng.uniform(0, t.S, 2)
			r = t.rng.uniform(rlo, rhi)
			a = t.rng.uniform(0, np.pi)
			asp = t.rng.uniform(0.55, 1.0)
			k = t.rng.uniform(0.75, 1.0)
			tgt = grey if t.rng.random() < 0.15 else light

			def chip(dx, dy, r=r, a=a, asp=asp, k=k):
				u = dx * np.cos(a) + dy * np.sin(a)
				v = (-dx * np.sin(a) + dy * np.cos(a)) / asp
				m = np.abs(u) + np.abs(v)  # diamond: angular chips like crushed marble
				return k * (1.0 - smooth(r * 0.8, r, m))

			t.stamp(tgt, cx, cy, r / 0.55, chip)
	base = matrix * 0.85
	f = base * (1.0 - light) + 1.0 * light
	f = f * (1.0 - grey) + 0.68 * grey
	color = f
	rough = remap(t.noise(0.6, 8.0), 0.36, 0.48) - 0.04 * light  # satin (see the polished concrete note)
	h = 0.002 * (light + grey) + 0.0008 * t.noise(0.1, 1.0)
	save("Lobby_Terrazzo", color, normal_map(h, t.P), rough)


def rock():
	# Granite: grain, small light and dark crystals, faint strata and sparse hairline cracks. The facets come from the
	# meshes, and the rock meshes use box-projected stud UVs, so every facet edge is a UV seam: the texture keeps NO
	# large-scale tone (nothing longer than ~2 studs), otherwise seams and the 16-stud tile show as a blotchy grid
	# (seen in Studio on RockWall_R68). Tone drift and occlusion come from the lighting on the facets.
	t = Tile(TILE["Lobby_Rock"], 55)
	tone = remap(t.noise(0.6, 2.0, 1.0), 0.95, 1.05)
	grain = remap(t.noise(0.06, 0.4, 0.5), 0.86, 1.12)
	fine = remap(t.noise(0.2, 1.0, 0.8), 0.94, 1.06)
	strata = remap(t.noise(0.2, 2.0, 1.0, ax=0.25, ay=1.0, angle=0.25), 0.95, 1.05)
	cryst = t.noise(0.035, 0.12, 0.0)
	light_x = smooth(1.5, 2.2, cryst)
	dark_x = smooth(1.7, 2.4, -cryst) * smooth(-0.5, 1.0, t.noise(0.4, 2.0))
	# Cracks: zero crossings of smooth noise, kept where a mask noise is high (sparse, broken hairlines).
	wx = t.noise(0.6, 3.0, 1.0)
	cn = t.noise(4.0, 16.0, 1.5) + 0.12 * wx
	gx = (np.roll(cn, -1, axis=1) - np.roll(cn, 1, axis=1)) * (t.P / 2.0)
	gy = (np.roll(cn, -1, axis=0) - np.roll(cn, 1, axis=0)) * (t.P / 2.0)
	dist = np.abs(cn) / (np.sqrt(gx * gx + gy * gy) + 1e-4)  # studs to the zero line (first order)
	mask = smooth(0.6, 1.6, t.noise(3.0, 12.0, 1.0))
	crack = (1.0 - smooth(0.004, 0.016, dist)) * mask
	f = tone * grain * fine * strata
	f *= 1.0 + 0.32 * light_x - 0.35 * dark_x
	f *= 1.0 - 0.18 * crack
	color = norm_mean(f, 0.87)
	rough = remap(t.noise(0.06, 0.4, 0.5), 0.82, 0.68) + 0.04 * crack
	h = 0.012 * t.noise(0.3, 1.6, 1.2) + 0.006 * t.noise(0.05, 0.3, 0.6) + 0.002 * light_x - 0.012 * crack
	save("Lobby_Rock", color, normal_map(h, t.P), rough)


def oak():
	# Warm oak, straight fine grain along U (horizontal): long irregular late-wood streaks, a finer streak layer and
	# a per-board tone shift (boards 1 stud wide in V). Low contrast (#86603C..#9E7246 around #94683F).
	t = Tile(TILE["Lobby_Oak"], 66)
	rows = int(round(t.S))
	board = np.floor(t.y).astype(int)
	tone = np.ones((N, N), np.float32)
	streak = np.zeros((N, N), np.float32)
	finegr = np.zeros((N, N), np.float32)
	s_f = t.noise(0.05, 8.0, 1.0, ax=0.035, ay=1.0)
	w_f = t.noise(0.5, 8.0, 1.0)
	f_f = t.noise(0.01, 4.0, 0.6, ax=0.02, ay=1.0)
	for j in range(rows):
		m = board == j
		tone[m] = 1.0 + t.rng.uniform(-0.05, 0.05)
		ox, oy = t.rng.integers(0, N, 2)
		# A gentle warp of the grain so it is not ruler-straight.
		streak[m] = t.roll(s_f, ox, oy)[m]
		finegr[m] = t.roll(f_f, oy, ox)[m]
	warp = (w_f * 0.02 * t.P).astype(int)
	idx = (np.arange(N)[:, None] + warp) % N
	streak = np.take_along_axis(streak, idx, axis=0)
	tg = 0.75 * streak + 0.25 * finegr
	lo, hi = 0x86 / 0x94, 0x9E / 0x94
	f = (lo + (hi - lo) * smooth(-1.2, 1.2, tg)) * tone
	f *= 1.0 - 0.04 * (1.0 - smooth(0.0, 0.012, np.abs(t.y - np.round(t.y))))  # hairline board joint
	color = norm_mean(f, 0.9)
	rough = remap(tg, 0.55, 0.45)
	h = 0.0015 * finegr - 0.002 * (1.0 - smooth(0.0, 0.015, np.abs(t.y - np.round(t.y))))
	save("Lobby_Oak", color, normal_map(h, t.P), rough)


ALL = {
	"Lobby_ConcreteBoard": concrete_board,
	"Lobby_ConcretePolished": concrete_polished,
	"Lobby_ConcreteDark": concrete_dark,
	"Lobby_Terrazzo": terrazzo,
	"Lobby_Rock": rock,
	"Lobby_Oak": oak,
}

if __name__ == "__main__":
	names = sys.argv[1:] or list(ALL)
	for name in names:
		ALL[name]()
