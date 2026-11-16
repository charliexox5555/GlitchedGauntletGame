"""The damage direction indicator's shape (vault/05 Production/Playtests/
2026-11-15 Gunplay Overhaul.md §12; owner's RIVALS screenshot: a thick red arc
round the crosshair with an arrowhead on its outside, pointing at the shooter).

    python tools/vfx/make_damage_indicator.py

Writes art-source/vfx/hit/damage_arc.png: a white arc band with round ends and
a triangle on its outer side (the top of the image), on transparency. The game
tints it (Config/DamageIndicator color), turns it round the crosshair and
scales it. The numbers below are px at 1080p and are mirrored in
Config/DamageIndicator `art` (the game needs them to sit the arc on its
circle); the image is drawn at 2x. Supersampled 4x. Pillow only.
"""

import math
import os

from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "art-source", "vfx", "hit")

# Design px (1080p). Keep in step with Config/DamageIndicator `art`.
RADIUS = 285  # the band's centre line, from the crosshair
SPAN = 68  # degrees of arc
THICK = 20  # the band
TRI_HALF = 44  # half the arrowhead's base, along the band
TRI_HEIGHT = 50  # the arrowhead, out from the band's outer edge
TRI_ROUND = 3  # its tip's rounding
MARGIN = 6
WIDTH = 368
HEIGHT = 136

SCALE = 2  # image px per design px
SS = 4  # supersampling


def main():
	k = SCALE * SS
	w, h = WIDTH * k, HEIGHT * k
	cx = w / 2
	cy = (MARGIN + TRI_HEIGHT + THICK / 2 + RADIUS) * k
	half = SPAN / 2

	band = Image.new("L", (w, h), 0)
	d = ImageDraw.Draw(band)
	ro = (RADIUS + THICK / 2) * k
	d.arc((cx - ro, cy - ro, cx + ro, cy + ro), 270 - half, 270 + half, fill=255, width=round(THICK * k))
	for sign in (-1, 1):
		a = math.radians(270 + sign * half)
		x, y = cx + math.cos(a) * RADIUS * k, cy + math.sin(a) * RADIUS * k
		r = THICK / 2 * k
		d.ellipse((x - r, y - r, x + r, y + r), fill=255)

	# The arrowhead: its base is buried in the band, its tip a little rounded
	# (blur and threshold rounds the corners).
	tri = Image.new("L", (w, h), 0)
	b = TRI_HALF * k
	base_y = cy - math.sqrt((RADIUS * k) ** 2 - b * b)
	ImageDraw.Draw(tri).polygon([(cx, MARGIN * k), (cx - b, base_y), (cx + b, base_y)], fill=255)
	tri = tri.filter(ImageFilter.GaussianBlur(TRI_ROUND * k)).point(lambda v: 255 if v >= 128 else 0)

	mask = Image.composite(Image.new("L", (w, h), 255), band, tri)
	mask = mask.resize((WIDTH * SCALE, HEIGHT * SCALE), Image.LANCZOS)
	image = Image.new("RGBA", mask.size, (255, 255, 255, 0))
	image.putalpha(mask)
	os.makedirs(OUT, exist_ok=True)
	path = os.path.join(OUT, "damage_arc.png")
	image.save(path)
	print(path, image.size)


if __name__ == "__main__":
	main()
