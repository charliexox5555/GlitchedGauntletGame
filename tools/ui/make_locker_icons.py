"""Flat white icons for the Locker v3 mockup (vault/01 Design/Loadout and Power Deck.md -> Locker v3).

Faceted shapes only (gauntlet-ui-style: no glossy, no 3D, no outline), drawn 4x and scaled down
for clean edges. Writes art-source/ui/locker-v3/icons/<name>.png (256 px, transparent, white).

    python tools/ui/make_locker_icons.py
"""

import math
import os

from PIL import Image, ImageDraw

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "art-source", "ui", "locker-v3", "icons")
S = 256
K = 4  # supersample
W = (255, 255, 255, 255)
CLEAR = (0, 0, 0, 0)


def canvas():
	im = Image.new("RGBA", (S * K, S * K), CLEAR)
	return im, ImageDraw.Draw(im)


def P(points):
	return [(x * K, y * K) for x, y in points]


def bar(d, x0, y0, x1, y1, w, fill=W):
	"""A thick straight bar with square ends from (x0, y0) to (x1, y1)."""
	dx, dy = x1 - x0, y1 - y0
	n = math.hypot(dx, dy)
	ox, oy = -dy / n * w / 2, dx / n * w / 2
	d.polygon(P([(x0 + ox, y0 + oy), (x1 + ox, y1 + oy), (x1 - ox, y1 - oy), (x0 - ox, y0 - oy)]), fill=fill)


def ngon(cx, cy, r, n, rot=0.0):
	return [(cx + r * math.cos(rot + i * 2 * math.pi / n), cy + r * math.sin(rot + i * 2 * math.pi / n)) for i in range(n)]


def save(im, name):
	os.makedirs(OUT, exist_ok=True)
	im.resize((S, S), Image.LANCZOS).save(os.path.join(OUT, name + ".png"))


def close():
	im, d = canvas()
	bar(d, 58, 58, 198, 198, 46)
	bar(d, 198, 58, 58, 198, 46)
	save(im, "close")


def arrow():
	im, d = canvas()
	d.polygon(P([(40, 104), (140, 104), (140, 52), (222, 128), (140, 204), (140, 152), (40, 152)]), fill=W)
	save(im, "arrow")


def eye():
	im, d = canvas()
	outer = [(20, 128), (70, 72), (128, 56), (186, 72), (236, 128), (186, 184), (128, 200), (70, 184)]
	d.polygon(P(outer), fill=W)
	inner = [(52, 128), (88, 92), (128, 82), (168, 92), (204, 128), (168, 164), (128, 174), (88, 164)]
	d.polygon(P(inner), fill=CLEAR)
	d.polygon(P(ngon(128, 128, 36, 6, math.pi / 6)), fill=W)
	save(im, "eye")


def stats():
	im, d = canvas()
	for x, top in ((40, 140), (102, 84), (164, 36)):
		d.polygon(P([(x, top + 10), (x + 10, top), (x + 52, top), (x + 52, 220), (x, 220)]), fill=W)
	save(im, "stats")


def contracts():
	im, d = canvas()
	d.polygon(P([(52, 44), (204, 44), (204, 232), (66, 232), (52, 218)]), fill=W)
	d.polygon(P([(96, 26), (160, 26), (168, 60), (88, 60)]), fill=W)
	d.polygon(P([(70, 70), (186, 70), (186, 214), (70, 214)]), fill=CLEAR)
	bar(d, 88, 142, 120, 176, 26)
	bar(d, 112, 182, 170, 108, 26)
	save(im, "contracts")


def levelup():
	im, d = canvas()
	for y in (30, 110):
		d.polygon(P([(128, y), (220, y + 80), (220, y + 120), (128, y + 40), (36, y + 120), (36, y + 80)]), fill=W)
	save(im, "levelup")


def reward():
	im, d = canvas()
	d.polygon(P([(40, 96), (216, 96), (216, 136), (40, 136)]), fill=W)
	d.polygon(P([(56, 146), (200, 146), (200, 226), (64, 226), (56, 218)]), fill=W)
	d.polygon(P([(116, 96), (140, 96), (140, 226), (116, 226)]), fill=CLEAR)
	d.polygon(P([(128, 92), (84, 40), (60, 58), (92, 92)]), fill=W)
	d.polygon(P([(128, 92), (172, 40), (196, 58), (164, 92)]), fill=W)
	save(im, "reward")


def skin():
	im, d = canvas()
	# a paint brush: angled handle, ferrule, faceted tip
	bar(d, 214, 42, 132, 124, 34)
	bar(d, 136, 120, 112, 144, 50)
	d.polygon(P([(98, 132), (124, 158), (96, 214), (40, 226), (52, 170)]), fill=W)
	save(im, "skin")


def charm():
	im, d = canvas()
	# a key-ring hoop at the top, a short link, and a faceted tag hanging under it
	d.polygon(P(ngon(128, 62, 46, 6, math.pi / 6)), fill=W)
	d.polygon(P(ngon(128, 62, 26, 6, math.pi / 6)), fill=CLEAR)
	bar(d, 128, 104, 128, 136, 20)
	d.polygon(P([(128, 128), (188, 158), (176, 226), (80, 226), (68, 158)]), fill=W)
	d.polygon(P(ngon(128, 180, 14, 6, 0)), fill=CLEAR)
	save(im, "charm")


def star():
	im, d = canvas()
	pts = []
	for i in range(10):
		r = 108 if i % 2 == 0 else 46
		a = -math.pi / 2 + i * math.pi / 5
		pts.append((128 + r * math.cos(a), 136 + r * math.sin(a)))
	d.polygon(P(pts), fill=W)
	save(im, "star")


def card():
	im, d = canvas()
	back = [(60, 50), (164, 30), (196, 196), (92, 216)]
	d.polygon(P(back), fill=(255, 255, 255, 150))
	d.polygon(P([(84, 60), (196, 60), (196, 232), (98, 232), (84, 218)]), fill=W)
	d.polygon(P([(104, 80), (176, 80), (176, 150), (104, 150)]), fill=CLEAR)
	save(im, "card")


def target():
	im, d = canvas()
	d.polygon(P(ngon(128, 128, 100, 8, math.pi / 8)), fill=W)
	d.polygon(P(ngon(128, 128, 72, 8, math.pi / 8)), fill=CLEAR)
	d.polygon(P(ngon(128, 128, 28, 8, math.pi / 8)), fill=W)
	for a, b, c, e in ((128, 10, 128, 60), (128, 196, 128, 246), (10, 128, 60, 128), (196, 128, 246, 128)):
		bar(d, a, b, c, e, 22)
	save(im, "target")


def play():
	im, d = canvas()
	d.polygon(P([(76, 40), (212, 128), (76, 216)]), fill=W)
	save(im, "play")


if __name__ == "__main__":
	for f in (close, arrow, eye, stats, contracts, levelup, reward, skin, charm, star, card, target, play):
		f()
	print(OUT)
