"""Plain stand-ins for the rework texture set (Ability VFX Direction -> Texture set).

The owner's ChatGPT runs replace these; until then the effects need something
of the right shape. White (and greys) on transparent, hard edges, no glow.

    python tools/vfx/make_rework_standins.py

Writes art-source/abilities/Rework/v03/Textures/T_<Name>.png (STANDIN in the
note means: replace with the owner's pick, same file name, re-upload).
"""

import math
import os

from PIL import Image, ImageDraw

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "art-source", "abilities", "Rework", "v03", "Textures")

SS = 4  # supersample, then downscale for clean edges


def canvas(px):
	img = Image.new("RGBA", (px * SS, px * SS), (0, 0, 0, 0))
	return img, ImageDraw.Draw(img)


def save(img, px, name):
	img = img.resize((px, px), Image.LANCZOS)
	path = os.path.join(OUT, name)
	img.save(path)
	print(path)


def pts(px, poly):
	s = px * SS
	return [(x * s, y * s) for x, y in poly]


def chip():
	px = 256
	img, d = canvas(px)
	# Four-sided diamond with one corner cut, a light-grey facet on one side.
	body = [(0.5, 0.08), (0.86, 0.46), (0.62, 0.9), (0.38, 0.9), (0.14, 0.5)]
	d.polygon(pts(px, body), fill=(255, 255, 255, 255))
	d.polygon(pts(px, [(0.5, 0.08), (0.5, 0.55), (0.14, 0.5)]), fill=(200, 200, 200, 255))
	save(img, px, "T_Chip.png")


def streak():
	px = 256
	img, d = canvas(px)
	d.polygon(pts(px, [(0.5, 0.02), (0.56, 0.5), (0.5, 0.98), (0.44, 0.5)]), fill=(255, 255, 255, 255))
	save(img, px, "T_Streak.png")


def puff():
	px = 512
	img, d = canvas(px)
	# A lumpy cluster of 8 straight-edged lobes, three flat greys.
	lobes = [
		(0.5, 0.42, 0.22),
		(0.3, 0.5, 0.17),
		(0.7, 0.5, 0.17),
		(0.38, 0.32, 0.15),
		(0.62, 0.32, 0.15),
		(0.22, 0.62, 0.12),
		(0.78, 0.62, 0.12),
		(0.5, 0.62, 0.2),
	]

	def lobe(cx, cy, r, sides=7, rot=0.3):
		return [(cx + r * math.cos(rot + i * 2 * math.pi / sides), cy + r * math.sin(rot + i * 2 * math.pi / sides)) for i in range(sides)]

	for cx, cy, r in lobes:  # dark underside, offset down
		d.polygon(pts(px, lobe(cx, cy + 0.04, r)), fill=(90, 90, 90, 255))
	for cx, cy, r in lobes:  # mid body
		d.polygon(pts(px, lobe(cx, cy, r)), fill=(170, 170, 170, 255))
	for cx, cy, r in lobes[:5]:  # white tops
		d.polygon(pts(px, lobe(cx, cy - 0.04, r * 0.7)), fill=(255, 255, 255, 255))
	save(img, px, "T_Puff.png")


def ring():
	px = 512
	img, d = canvas(px)
	r_out, r_in = 0.45, 0.45 - 0.04 * 0.5 * 2
	n = 16
	gaps = {1, 5, 9, 13}  # four segments get an angled cut
	for i in range(n):
		a0 = i * 2 * math.pi / n
		a1 = (i + 1) * 2 * math.pi / n
		if i in gaps:
			a1 -= (a1 - a0) * 0.35
		quad = [
			(0.5 + r_out * math.cos(a0), 0.5 + r_out * math.sin(a0)),
			(0.5 + r_out * math.cos(a1), 0.5 + r_out * math.sin(a1)),
			(0.5 + r_in * math.cos(a1 - 0.03 * (i in gaps)), 0.5 + r_in * math.sin(a1 - 0.03 * (i in gaps))),
			(0.5 + r_in * math.cos(a0 + 0.03 * (i in gaps)), 0.5 + r_in * math.sin(a0 + 0.03 * (i in gaps))),
		]
		d.polygon(pts(px, quad), fill=(255, 255, 255, 255))
	save(img, px, "T_Ring.png")


def flash():
	px = 512
	img, d = canvas(px)
	d.polygon(pts(px, [(0.02, 0.5), (0.5, 0.46), (0.98, 0.5), (0.5, 0.54)]), fill=(255, 255, 255, 255))
	d.polygon(pts(px, [(0.5, 0.18), (0.535, 0.5), (0.5, 0.82), (0.465, 0.5)]), fill=(255, 255, 255, 255))
	oct_ = [(0.5 + 0.07 * math.cos(math.pi / 8 + i * math.pi / 4), 0.5 + 0.07 * math.sin(math.pi / 8 + i * math.pi / 4)) for i in range(8)]
	d.polygon(pts(px, oct_), fill=(255, 255, 255, 255))
	save(img, px, "T_Flash.png")


def frost_corner():
	px = 1024
	img, d = canvas(px)
	# Angular plates and shards from the top-left corner, within the outer third.
	shards = [
		([(0, 0), (0.33, 0), (0.12, 0.08), (0, 0.06)], 255),
		([(0, 0), (0.06, 0), (0.09, 0.3), (0, 0.24)], 255),
		([(0, 0), (0.22, 0.04), (0.24, 0.2), (0.05, 0.12)], 210),
		([(0.04, 0.06), (0.16, 0.12), (0.2, 0.3), (0.06, 0.22)], 190),
		([(0.2, 0.02), (0.38, 0.05), (0.26, 0.12)], 230),
		([(0.02, 0.2), (0.1, 0.24), (0.04, 0.38)], 230),
		([(0.12, 0.14), (0.3, 0.2), (0.22, 0.26), (0.12, 0.24)], 160),
	]
	for poly, g in shards:
		d.polygon(pts(px, poly), fill=(g, g, g, 255))
	# Fade toward the centre: scale alpha by distance from the corner.
	img = img.resize((px, px), Image.LANCZOS)
	pix = img.load()
	for y in range(px):
		for x in range(px):
			r, g, b, a = pix[x, y]
			if a:
				dist = math.hypot(x, y) / (px * 0.42)
				k = max(0.0, min(1.0, 1.15 - dist))
				pix[x, y] = (r, g, b, int(a * k))
	path = os.path.join(OUT, "T_FrostCorner.png")
	img.save(path)
	print(path)


if __name__ == "__main__":
	os.makedirs(OUT, exist_ok=True)
	chip()
	streak()
	puff()
	ring()
	flash()
	frost_corner()
