"""The free pack's Mod HUD icons (Shock Dart, Flash, Roller), until the
owner's ChatGPT icons replace them (vault/02 Art/UI Art Brief (ChatGPT).md).

    python tools/icons/make_free_pack_icons.py

White flat glyphs on transparent at 512 px, like the HUD's other icons:
sharp mitred corners, simple geometric shapes, no round curves (angled
plates), strokes at least 28 px so they survive 48 px. Writes
art-source/abilities/Icons/FreePack/<ModId>.png and a contact sheet.
"""

import math
import os

from PIL import Image, ImageDraw

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "art-source", "abilities", "Icons", "FreePack")
S = 512
SS = 4  # supersampling
WHITE = (255, 255, 255, 255)
CLEAR = (0, 0, 0, 0)


def canvas():
	im = Image.new("RGBA", (S * SS, S * SS), CLEAR)
	return im, ImageDraw.Draw(im)


def P(points):
	return [(x * SS, y * SS) for x, y in points]


def rot(points, cx, cy, deg):
	a = math.radians(deg)
	c, s = math.cos(a), math.sin(a)
	return [(cx + (x - cx) * c - (y - cy) * s, cy + (x - cx) * s + (y - cy) * c) for x, y in points]


def octagon(cx, cy, r):
	return [(cx + r * math.cos(math.radians(22.5 + 45 * i)), cy + r * math.sin(math.radians(22.5 + 45 * i))) for i in range(8)]


def finish(im, name):
	im = im.resize((S, S), Image.LANCZOS)
	path = os.path.join(OUT, name + ".png")
	im.save(path)
	return im


def shock_dart():
	im, d = canvas()
	# A bolt flying up-right: the shaft, a faceted head, and a lightning
	# zigzag crossing the shaft behind the head.
	cx, cy = 256, 256
	ang = -45
	shaft = [(96, 244), (330, 244), (330, 268), (96, 268)]
	head = [(310, 222), (400, 256), (310, 290), (330, 256)]
	fl1 = [(96, 244), (140, 244), (112, 206), (78, 206)]
	fl2 = [(96, 268), (140, 268), (112, 306), (78, 306)]
	for poly in (shaft, head, fl1, fl2):
		d.polygon(P(rot(poly, cx, cy, ang)), fill=WHITE)
	# The zigzag (a bolt), across the head end.
	bolt = [(300, 120), (360, 120), (318, 214), (372, 214), (250, 392), (282, 262), (230, 262)]
	# Small, in the free corner below the head (clear of the dart).
	bx, by = 301, 256
	bolt = [(370 + (x - bx) * 0.55, 352 + (y - by) * 0.55) for x, y in bolt]
	d.polygon(P(bolt), fill=WHITE)
	return finish(im, "ShockDart")


def flash():
	im, d = canvas()
	cx, cy = 256, 256
	# A four-point star (two crossed diamonds), long rays on the axes.
	big = [(cx, cy - 210), (cx + 46, cy - 46), (cx + 210, cy), (cx + 46, cy + 46), (cx, cy + 210), (cx - 46, cy + 46), (cx - 210, cy), (cx - 46, cy - 46)]
	d.polygon(P(big), fill=WHITE)
	small = [(cx, cy - 120), (cx + 28, cy - 28), (cx + 120, cy), (cx + 28, cy + 28), (cx, cy + 120), (cx - 28, cy + 28), (cx - 120, cy), (cx - 28, cy - 28)]
	d.polygon(P(rot(small, cx, cy, 45)), fill=WHITE)
	# A dark core (cut out), so the star reads as light, not a blob.
	d.polygon(P(rot(octagon(cx, cy, 34), cx, cy, 0)), fill=CLEAR)
	return finish(im, "Flash")


def roller():
	im, d = canvas()
	# Side view: a low wedge body nose-left, two octagon wheels, an eye slit.
	body = [(70, 300), (130, 210), (380, 196), (440, 236), (452, 300)]
	d.polygon(P(body), fill=WHITE)
	# Eye slit on the nose (cut).
	eye = [(120, 246), (196, 234), (204, 256), (126, 266)]
	d.polygon(P(eye), fill=CLEAR)
	# Wheels with a gap ring cut round them.
	for wx in (150, 372):
		d.polygon(P(octagon(wx, 330, 78)), fill=CLEAR)
		d.polygon(P(octagon(wx, 330, 62)), fill=WHITE)
		d.polygon(P(octagon(wx, 330, 22)), fill=CLEAR)
	# Fin on the back.
	d.polygon(P([(330, 198), (362, 132), (392, 132), (380, 202)]), fill=WHITE)
	return finish(im, "Roller")


def main():
	os.makedirs(OUT, exist_ok=True)
	icons = [shock_dart(), flash(), roller()]
	sheet = Image.new("RGBA", (3 * 200 + 40, 240), (30, 37, 48, 255))
	for i, ic in enumerate(icons):
		tile = Image.new("RGBA", (180, 180), (0, 229, 255, 255) if i != 1 else (255, 90, 54, 255))
		tile.alpha_composite(ic.resize((150, 150), Image.LANCZOS), (15, 15))
		sheet.alpha_composite(tile, (20 + i * 200, 30))
	sheet.save(os.path.join(OUT, "contact_sheet.png"))
	print("wrote", OUT)


if __name__ == "__main__":
	main()
