"""Metro2 textures: six tintable MaterialVariants and the sign art (vault/01 Design/Maps/Metro2.md).

    python tools/textures/make_metro2_textures.py [--preview]

Writes to art-source/maps/Metro2/textures/:
  * <Variant>_Color.png and <Variant>_Normal.png at 512 x 512, seamless both ways (built on a wrapping grid):
      Metro2_Tile      glazed wall tile, 1 x 0.5-stud tiles in running bond (StudsPerTile 4)
      Metro2_Floor     terrazzo floor tiles, 2 x 2 studs, joints (StudsPerTile 4)
      Metro2_Concrete  smooth cast concrete with formwork joints and tie holes (StudsPerTile 8)
      Metro2_Steel     brushed stainless (StudsPerTile 4)
      Metro2_Ballast   track ballast stones (StudsPerTile 6)
      Metro2_Granite   speckled granite for plinths, copings and stairs (StudsPerTile 4)
    Colour maps are near-white (mean about 0.86) so BasePart.Color tints them by role; wear and cavity shading are
    baked in (LihFolk "Baking Lighting and Detail into Textures"). Normals come from the height maps, OpenGL (+Y up).
  * sign/*.png: the station's signs, rendered from real fonts (Bahnschrift: a DIN-style transit face shipped
    with Windows), never built from parts (Map Quality Standard section 3, Text and signage).
--preview also writes Metro2_textures_preview.png (variants and signs on one sheet) next to them.
These were made procedurally (a call noted in the map note); a Codex trim sheet can replace any row later.
"""

from __future__ import annotations

import math
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "art-source", "maps", "Metro2", "textures")
SIGN = os.path.join(OUT, "sign")
N = 512
RNG = np.random.default_rng(20261106)
FONT = "C:/Windows/Fonts/bahnschrift.ttf"


# ---------------------------------------------------------------- helpers

def font(size: int, style: str = "Bold") -> ImageFont.FreeTypeFont:
	f = ImageFont.truetype(FONT, size)
	try:
		f.set_variation_by_name(style)
	except Exception:
		pass
	return f


def wrap_noise(n: int, cells: int, octaves: int = 4, seed: int = 0) -> np.ndarray:
	"""Tileable value noise in 0..1 (bilinear lattice that wraps)."""
	rng = np.random.default_rng(seed)
	out = np.zeros((n, n))
	amp, tot = 1.0, 0.0
	for o in range(octaves):
		c = cells * 2**o
		lat = rng.random((c, c))
		ys = np.arange(n) * c / n
		y0 = np.floor(ys).astype(int)
		fy = ys - y0
		fy = fy * fy * (3 - 2 * fy)
		y1 = (y0 + 1) % c
		a = lat[y0][:, y0] * (1 - fy)[None, :] + lat[y0][:, y1] * fy[None, :]
		b = lat[y1][:, y0] * (1 - fy)[None, :] + lat[y1][:, y1] * fy[None, :]
		out += amp * (a * (1 - fy)[:, None] + b * fy[:, None])
		tot += amp
		amp *= 0.5
	return out / tot


def blur_wrap(a: np.ndarray, r: float) -> np.ndarray:
	"""Gaussian blur that wraps (pad by tiling, blur, crop)."""
	if r <= 0:
		return a
	from scipy.ndimage import gaussian_filter

	return gaussian_filter(a.astype(np.float64), r, mode="wrap")


def normal_from_height(h: np.ndarray, strength: float) -> np.ndarray:
	dx = (np.roll(h, -1, 1) - np.roll(h, 1, 1)) * 0.5 * strength
	dy = (np.roll(h, -1, 0) - np.roll(h, 1, 0)) * 0.5 * strength
	nx, ny, nz = -dx, dy, np.ones_like(h)  # image rows go down; OpenGL +Y up
	ln = np.sqrt(nx * nx + ny * ny + nz * nz)
	n = np.stack([nx / ln, ny / ln, nz / ln], -1)
	return ((n * 0.5 + 0.5) * 255).astype(np.uint8)


def save_variant(name: str, colour: np.ndarray, height: np.ndarray, strength: float, mean: float = 0.86):
	c = np.clip(colour, 0, None)
	lum = c.mean() if c.ndim == 2 else c.mean(axis=2).mean()
	c = c * (mean / max(lum, 1e-6))
	c = np.clip(c, 0, 1)
	if c.ndim == 2:
		c = np.stack([c, c, c], -1)
	Image.fromarray((c * 255).astype(np.uint8)).save(os.path.join(OUT, name + "_Color.png"))
	Image.fromarray(normal_from_height(height, strength)).save(os.path.join(OUT, name + "_Normal.png"))
	print("variant", name)


def smoothstep(e0, e1, x):
	t = np.clip((x - e0) / (e1 - e0), 0, 1)
	return t * t * (3 - 2 * t)


# ---------------------------------------------------------------- variants

def tile():
	# 4 x 4 studs: 3 x 3 square tiles of 1.33 studs (the concepts' large cream tile), stack bond; grout 4 px,
	# a rounded glaze edge.
	tw = th = N / 3
	g = 4
	y, x = np.mgrid[0:N, 0:N].astype(np.float64)
	row = (y // th).astype(int)
	xs = x
	col = (xs // tw).astype(int)
	lx, ly = xs - col * tw, y - row * th
	d = np.minimum.reduce([lx, tw - lx, ly, th - ly])  # distance to the tile's edge
	grout = d < g / 2
	edge = smoothstep(g / 2, g / 2 + 7, d)  # the glaze rounds over the edge
	tone = RNG.normal(1.0, 0.025, (8, 8))[row % 8, col % 8]
	glaze = 0.97 + 0.06 * wrap_noise(N, 6, 3, 1)
	c = np.where(grout, 0.6, (0.9 + 0.1 * edge) * tone * glaze)
	h = np.where(grout, 0.0, 0.55 + 0.45 * edge) + 0.02 * wrap_noise(N, 16, 2, 2)
	save_variant("Metro2_Tile", c, blur_wrap(h, 0.8), 6.0)


def floor():
	# 4 x 4 studs: 2 x 2 terrazzo tiles of 2 studs; 3 px joints; chips of three sizes and tones.
	y, x = np.mgrid[0:N, 0:N].astype(np.float64)
	t = 256
	d = np.minimum.reduce([x % t, t - x % t, y % t, t - y % t])
	joint = d < 1.5
	base = 0.9 + 0.06 * (wrap_noise(N, 4, 3, 3) - 0.5)
	chips = np.zeros((N, N))
	for count, rmin, rmax, tone in ((2600, 0.6, 1.6, -0.22), (700, 1.4, 3.2, -0.14), (500, 1.0, 2.4, 0.08)):
		cx, cy = RNG.random(count) * N, RNG.random(count) * N
		r = RNG.uniform(rmin, rmax, count)
		tv = tone * RNG.uniform(0.6, 1.3, count)
		for i in range(count):
			x0, x1 = int(cx[i] - r[i] - 1), int(cx[i] + r[i] + 2)
			y0, y1 = int(cy[i] - r[i] - 1), int(cy[i] + r[i] + 2)
			yy, xx = np.mgrid[y0:y1, x0:x1]
			m = (xx - cx[i]) ** 2 + ((yy - cy[i]) * 1.2) ** 2 < r[i] ** 2
			chips[yy[m] % N, xx[m] % N] = tv[i]
	c = np.where(joint, 0.6, base + chips)
	h = np.where(joint, 0.0, 1.0) - 0.04 * (chips < -0.1)
	save_variant("Metro2_Floor", c, blur_wrap(h, 0.7), 4.0)


def concrete():
	# 8 x 8 studs: soft mottling, a formwork joint every 4 studs (both ways), tie holes on a 2-stud grid inside.
	y, x = np.mgrid[0:N, 0:N].astype(np.float64)
	mott = wrap_noise(N, 5, 5, 4)
	fine = wrap_noise(N, 64, 2, 5)
	c = 0.86 + 0.12 * (mott - 0.5) + 0.04 * (fine - 0.5)
	h = 0.3 * mott + 0.1 * fine
	p = 256
	dj = np.minimum(np.minimum(x % p, p - x % p), np.minimum(y % p, p - y % p))
	j = dj < 1.5
	c = np.where(j, c * 0.78, c)
	h = np.where(j, h - 0.6, h)
	for cy in range(64, N, 128):
		for cx in range(64, N, 128):
			rr = (x - cx) ** 2 + (y - cy) ** 2
			hole = rr < 16
			ring = (rr >= 16) & (rr < 30)
			c = np.where(hole, c * 0.62, np.where(ring, c * 0.92, c))
			h = np.where(hole, h - 0.8, h)
	save_variant("Metro2_Concrete", c, blur_wrap(h, 1.0), 3.0)


def steel():
	# 4 x 4 studs: horizontal brushing (noise stretched along X), faint scuffs.
	s = np.zeros((N, N))
	for k, amp in ((512, 0.5), (128, 0.3), (32, 0.2)):
		lines = RNG.random((N, 1))
		col = np.repeat(lines, N, axis=1)
		s += amp * blur_wrap(col, 0.6)
	s = blur_wrap(s / s.max(), 1.5)
	streak = wrap_noise(N, 3, 3, 6)
	# round 2: a calm satin finish (the strong brushing read as stacked slabs and streaks in Studio)
	c = 0.86 + 0.025 * (s - 0.5) + 0.04 * (streak - 0.5)
	save_variant("Metro2_Steel", c, s * 0.2, 0.6)


def ballast():
	# 6 x 6 studs: packed stones (a wrapping Voronoi with per-stone tone), dark gaps, a little dust.
	k = 900
	pts = RNG.random((k, 2)) * N
	tone = RNG.uniform(0.75, 1.1, k)
	y, x = np.mgrid[0:N, 0:N].astype(np.float64)
	best = np.full((N, N), 1e9)
	second = np.full((N, N), 1e9)
	idx = np.zeros((N, N), int)
	for i, (px, py) in enumerate(pts):
		dx = np.abs(x - px)
		dx = np.minimum(dx, N - dx)
		dy = np.abs(y - py)
		dy = np.minimum(dy, N - dy)
		d = dx * dx + dy * dy
		closer = d < best
		second = np.where(closer, best, np.minimum(second, d))
		idx = np.where(closer, i, idx)
		best = np.where(closer, d, best)
	edge = np.sqrt(second) - np.sqrt(best)
	dome = smoothstep(0, 10, edge)
	c = tone[idx] * (0.3 + 0.7 * dome**0.7) * (0.95 + 0.1 * wrap_noise(N, 32, 2, 7))
	save_variant("Metro2_Ballast", c, dome, 5.0)


def granite():
	# 4 x 4 studs: fine three-tone speckle over a soft cloud.
	base = 0.88 + 0.08 * (wrap_noise(N, 6, 4, 8) - 0.5)
	r = RNG.random((N, N))
	spk = np.where(r < 0.08, -0.25, np.where(r < 0.16, -0.1, np.where(r > 0.95, 0.08, 0.0)))
	spk = blur_wrap(spk, 0.6)
	c = base + spk
	save_variant("Metro2_Granite", c, spk * -1 + 0.1 * wrap_noise(N, 32, 2, 9), 1.5)


# ---------------------------------------------------------------- signs

INK = (43, 46, 53)  # charcoal
CREAM = (239, 232, 218)
COBALT = (58, 90, 156)
SAGE = (94, 143, 116)
AMBER = (255, 181, 71)


def text_c(d: ImageDraw.ImageDraw, xy, s, f, fill, anchor="mm"):
	d.text(xy, s, font=f, fill=fill, anchor=anchor)


def sign_name():
	# The station-name panel: cream enamel, a charcoal keyline, MERIDIAN. End colour comes from the modelled frame.
	w, h = 1024, 256
	im = Image.new("RGB", (w, h), CREAM)
	d = ImageDraw.Draw(im)
	d.rounded_rectangle((10, 10, w - 10, h - 10), 18, outline=INK, width=8)
	text_c(d, (w / 2, h / 2 + 4), "MERIDIAN", font(150, "Bold"), INK)
	im.save(os.path.join(SIGN, "Name.png"))


def sign_platform(n: int, dest: str, colour):
	w, h = 1024, 256
	im = Image.new("RGB", (w, h), INK)
	d = ImageDraw.Draw(im)
	d.ellipse((40, 38, 220, 218), fill=colour)
	text_c(d, (130, 132), str(n), font(130, "Bold"), (255, 255, 255))
	d.text((260, 70), "PLATFORM %d" % n, font=font(56, "SemiBold"), fill=(200, 204, 212))
	d.text((260, 130), dest, font=font(84, "Bold"), fill=(255, 255, 255))
	im.save(os.path.join(SIGN, "Platform%d.png" % n))


def sign_departures():
	# The landmark's board, shown self-lit (SurfaceGui ImageLabel, LightInfluence 0): amber rows on black.
	w, h = 1024, 256
	im = Image.new("RGB", (w, h), (14, 14, 16))
	d = ImageDraw.Draw(im)
	d.text((28, 14), "DEPARTURES", font=font(40, "Bold"), fill=(255, 244, 224))
	d.text((w - 28, 14), "08:12", font=font(40, "Bold"), fill=(255, 244, 224), anchor="ra")
	d.line((28, 66, w - 28, 66), fill=(80, 60, 30), width=3)
	rows = [("08:14", "1", "NORTHGATE", "2 min"), ("08:16", "2", "RIVERSIDE", "4 min"), ("08:21", "1", "NORTHGATE", "9 min")]
	f = font(44, "SemiBold")
	for i, (t, p, dest, m) in enumerate(rows):
		yy = 82 + i * 56
		d.text((28, yy), t, font=f, fill=AMBER)
		d.text((180, yy), p, font=f, fill=AMBER)
		d.text((250, yy), dest, font=f, fill=AMBER)
		d.text((w - 28, yy), m, font=f, fill=AMBER, anchor="ra")
	# dot-matrix grain: every third row of pixels a touch darker
	a = np.asarray(im).astype(np.float64)
	a[::3] *= 0.82
	Image.fromarray(a.astype(np.uint8)).save(os.path.join(SIGN, "Departures.png"))


def sign_clock():
	# Station clock face at 10:10: bar markers, slim hands, the centre cap is modelled.
	s = 512
	im = Image.new("RGB", (s, s), (246, 243, 236))
	d = ImageDraw.Draw(im)
	c = s / 2
	for i in range(60):
		a = math.radians(i * 6)
		big = i % 5 == 0
		r0, r1 = (c - 70, c - 18) if big else (c - 38, c - 18)
		wdt = 16 if big else 5
		x0, y0 = c + r0 * math.sin(a), c - r0 * math.cos(a)
		x1, y1 = c + r1 * math.sin(a), c - r1 * math.cos(a)
		d.line((x0, y0, x1, y1), fill=INK, width=wdt)
	text_c(d, (c, c + 92), "MERIDIAN", font(30, "SemiBold"), (120, 122, 128))

	def hand(deg, length, width, tail=30, fill=INK):
		a = math.radians(deg)
		x1, y1 = c + length * math.sin(a), c - length * math.cos(a)
		x0, y0 = c - tail * math.sin(a), c + tail * math.cos(a)
		d.line((x0, y0, x1, y1), fill=fill, width=width)

	hand(305, 140, 18)  # hour, at about ten past ten
	hand(60, 205, 12)  # minute
	hand(200, 190, 4, tail=50, fill=(196, 64, 52))  # seconds
	# Round: transparent outside the dial, so the square art sits on the round face plate.
	mask = Image.new("L", (s, s), 0)
	ImageDraw.Draw(mask).ellipse((2, 2, s - 3, s - 3), fill=255)
	im = im.convert("RGBA")
	im.putalpha(mask)
	im.save(os.path.join(SIGN, "Clock.png"))


def sign_route():
	# Line diagram for the platform walls: two lines through Meridian, station ticks and names.
	w, h = 1024, 512
	im = Image.new("RGB", (w, h), CREAM)
	d = ImageDraw.Draw(im)
	d.rectangle((0, 0, w, 64), fill=INK)
	d.text((28, 32), "LINE 1 / LINE 2", font=font(36, "Bold"), fill=CREAM, anchor="lm")
	names = ["NORTHGATE", "ELM PARK", "MERIDIAN", "OLD MARKET", "RIVERSIDE"]
	xs = [110 + i * 200 for i in range(5)]
	d.line((xs[0], 210, xs[-1], 210), fill=COBALT, width=22)
	d.line((xs[0], 320, xs[1] + 60, 320), fill=SAGE, width=22)
	d.line((xs[1] + 60, 320, xs[2], 210), fill=SAGE, width=22)
	d.line((xs[2], 210, xs[3] - 60, 320), fill=SAGE, width=22)
	d.line((xs[3] - 60, 320, xs[-1], 320), fill=SAGE, width=22)
	for i, x in enumerate(xs):
		big = i == 2
		r = 26 if big else 16
		d.ellipse((x - r, 210 - r, x + r, 210 + r), fill=(255, 255, 255), outline=INK, width=7)
		d.text((x, 150), names[i], font=font(30 if big else 26, "Bold" if big else "SemiBold"), fill=INK, anchor="mm")
	d.text((28, 440), "You are here: MERIDIAN", font=font(30, "SemiBold"), fill=INK)
	im.save(os.path.join(SIGN, "RouteMap.png"))


def sign_plate(name, text, bg, fg, w=512, h=128, size=78):
	im = Image.new("RGB", (w, h), bg)
	d = ImageDraw.Draw(im)
	text_c(d, (w / 2, h / 2 + 2), text, font(size, "Bold"), fg)
	im.save(os.path.join(SIGN, name + ".png"))


def sign_exit():
	w, h = 512, 128
	im = Image.new("RGB", (w, h), INK)
	d = ImageDraw.Draw(im)
	# an up arrow: straight on, through the portal it hangs over
	d.polygon([(70, 22), (110, 62), (84, 62), (84, 106), (56, 106), (56, 62), (30, 62)], fill=(255, 255, 255))
	d.text((150, h / 2 + 2), "EXIT", font=font(80, "Bold"), fill=(255, 255, 255), anchor="lm")
	im.save(os.path.join(SIGN, "Exit.png"))


def sign_dest(name: str, n: int):
	# Train cab destination screen, self-lit amber on black.
	w, h = 512, 96
	im = Image.new("RGB", (w, h), (14, 14, 16))
	d = ImageDraw.Draw(im)
	d.text((24, h / 2), str(n), font=font(64, "Bold"), fill=AMBER, anchor="lm")
	d.text((w / 2 + 20, h / 2), name, font=font(60, "SemiBold"), fill=AMBER, anchor="mm")
	a = np.asarray(im).astype(np.float64)
	a[::3] *= 0.8
	Image.fromarray(a.astype(np.uint8)).save(os.path.join(SIGN, "Dest%d.png" % n))


def sign_spawn_way():
	# On the spawn baffle, facing the spawn: the station roundel and the way out both sides.
	w, h = 1024, 512
	im = Image.new("RGB", (w, h), INK)
	d = ImageDraw.Draw(im)
	d.ellipse((392, 40, 632, 280), outline=CREAM, width=28)
	d.rectangle((352, 136, 672, 184), fill=CREAM)
	text_c(d, (512, 160), "MERIDIAN", font(34, "Bold"), INK)
	text_c(d, (512, 360), "PLATFORMS", font(96, "Bold"), CREAM)
	for sx in (-1, 1):
		x0 = 512 + sx * 380
		pts = [(x0 + sx * 70, 360), (x0, 300), (x0, 336), (x0 - sx * 60, 336), (x0 - sx * 60, 384), (x0, 384), (x0, 420)]
		d.polygon(pts, fill=AMBER)
	d.text((w / 2, 470), "Trains every 4 minutes", font=font(34, "SemiBold"), fill=(200, 204, 212), anchor="mm")
	im.save(os.path.join(SIGN, "SpawnWay.png"))


def sign_mind_gap():
	# Floor marking beside the platform edge (decal, flush): ochre on transparent.
	w, h = 1024, 128
	im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
	d = ImageDraw.Draw(im)
	text_c(d, (w / 2, h / 2), "MIND THE GAP", font(96, "Bold"), (226, 214, 180, 235))
	im.save(os.path.join(SIGN, "MindGap.png"))


def sign_spawn(letter, colour):
	w = h = 512
	im = Image.new("RGB", (w, h), CREAM)
	d = ImageDraw.Draw(im)
	d.ellipse((36, 36, w - 36, h - 36), fill=colour)
	text_c(d, (w / 2, h / 2 + 10), letter, font(330, "Bold"), (255, 255, 255))
	im.save(os.path.join(SIGN, "Spawn%s.png" % letter))


def sign_vending():
	# Machine front: a lit product grid (cans and bottles), the keypad and coin slot on the right.
	w, h = 256, 512
	im = Image.new("RGB", (w, h), (34, 36, 42))
	d = ImageDraw.Draw(im)
	d.rectangle((14, 20, 176, 430), fill=(226, 230, 236))
	cols = [(200, 74, 58), (47, 95, 191), (232, 196, 92), (60, 140, 108), (230, 230, 226)]
	for r in range(6):
		yy = 34 + r * 66
		d.rectangle((18, yy + 50, 172, yy + 54), fill=(150, 154, 160))
		for k in range(4):
			xx = 26 + k * 38
			c = cols[(r * 2 + k) % len(cols)]
			if (r + k) % 3 == 0:
				d.rounded_rectangle((xx + 6, yy + 4, xx + 22, yy + 50), 6, fill=c)
				d.rectangle((xx + 10, yy, xx + 18, yy + 6), fill=c)
			else:
				d.rounded_rectangle((xx + 2, yy + 14, xx + 26, yy + 50), 4, fill=c)
	d.rectangle((190, 120, 240, 250), fill=(70, 74, 82))
	for r in range(4):
		for k in range(3):
			d.rectangle((196 + k * 15, 128 + r * 28, 206 + k * 15, 146 + r * 28), fill=(200, 204, 210))
	d.rectangle((200, 280, 230, 300), fill=(16, 16, 18))
	d.rectangle((24, 446, 166, 490), fill=(16, 16, 18))
	im.save(os.path.join(SIGN, "Vending.png"))


def poster(name, bg, accent, words, shape):
	# Fallback lightbox posters (fictional brands) in case Codex's are not in: flat shapes and at most 3 words.
	w, h = 512, 768
	im = Image.new("RGB", (w, h), bg)
	d = ImageDraw.Draw(im)
	if shape == "cup":
		d.ellipse((126, 150, 386, 200), fill=accent)
		d.polygon([(130, 176), (382, 176), (350, 430), (162, 430)], fill=accent)
		d.arc((340, 230, 440, 350), -90, 90, fill=accent, width=22)
		for k in range(3):
			d.arc((200 + k * 40, 60, 240 + k * 40, 140), 200, 340, fill=CREAM, width=8)
	elif shape == "arch":
		d.rectangle((96, 140, 416, 470), fill=accent)
		d.pieslice((96, 40, 416, 260), 180, 360, fill=accent)
		d.rectangle((176, 250, 336, 470), fill=bg)
		d.pieslice((176, 190, 336, 310), 180, 360, fill=bg)
	elif shape == "rails":
		for k in range(7):
			yy = 120 + k * 50
			d.rectangle((120 - k * 10, yy, 392 + k * 10, yy + 16), fill=accent)
		d.line((180, 110, 70, 470), fill=CREAM, width=14)
		d.line((332, 110, 442, 470), fill=CREAM, width=14)
	else:
		for k in range(4):
			r = 60 + k * 50
			d.arc((256 - r, 330 - r, 256 + r, 330 + r), 220, 320, fill=accent, width=22)
		d.ellipse((236, 310, 276, 350), fill=accent)
	f = font(64, "Bold")
	for i, wd in enumerate(words):
		d.text((w / 2, 540 + i * 74), wd, font=f, fill=CREAM if bg != CREAM else INK, anchor="mm")
	im.save(os.path.join(SIGN, name + ".png"))


def main():
	os.makedirs(SIGN, exist_ok=True)
	tile()
	floor()
	concrete()
	steel()
	ballast()
	granite()
	sign_name()
	sign_platform(1, "NORTHGATE", COBALT)
	sign_platform(2, "RIVERSIDE", SAGE)
	sign_departures()
	sign_clock()
	sign_route()
	sign_exit()
	sign_plate("Tickets", "TICKETS", INK, CREAM)
	sign_plate("Coffee", "MERIDIAN COFFEE", (92, 62, 40), CREAM, size=54)
	sign_plate("Staff", "STAFF ONLY", CREAM, INK, size=66)
	sign_plate("Platforms", "PLATFORMS", INK, CREAM, size=70)
	sign_mind_gap()
	sign_spawn_way()
	sign_dest("NORTHGATE", 1)
	sign_dest("RIVERSIDE", 2)
	sign_spawn("A", SAGE)
	sign_spawn("B", COBALT)
	sign_vending()
	poster("PosterCoffee", (92, 62, 40), (226, 196, 150), ["SLOW", "MORNINGS"], "cup")
	poster("PosterMuseum", CREAM, COBALT, ["ARCHES", "CITY MUSEUM"], "arch")
	poster("PosterRail", SAGE, CREAM, ["SEE IT", "BY RAIL"], "rails")
	poster("PosterPhone", COBALT, CREAM, ["ALWAYS", "ON TIME"], "signal")
	if "--preview" in sys.argv:
		names = sorted(f for f in os.listdir(OUT) if f.endswith("_Color.png"))
		sheet = Image.new("RGB", (256 * len(names), 512), (40, 40, 40))
		for i, n in enumerate(names):
			sheet.paste(Image.open(os.path.join(OUT, n)).convert("RGB").resize((256, 256)), (i * 256, 0))
			sheet.paste(Image.open(os.path.join(OUT, n.replace("_Color", "_Normal"))).convert("RGB").resize((256, 256)), (i * 256, 256))
		sheet.save(os.path.join(OUT, "Metro2_textures_preview.png"))
	print("done")


if __name__ == "__main__":
	main()
