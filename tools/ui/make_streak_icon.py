"""Faceted flame icon for the lobby bar's SAVE WINSTREAK button (vault/01 Design/Progression.md).
Same look as the bar icons v2 (art-source/ui/lobby-icons/sheet_v2.png): a flat front face, a darker
extruded side, a light top bevel, a shared slight tilt, no curves (angled facets only).
    python tools/ui/make_streak_icon.py  ->  art-source/ui/streak/streak_icon.png (400 px)
"""
import math, os
from PIL import Image, ImageDraw

S = 4  # supersample
W = 400 * S
OUT = os.path.join(os.path.dirname(__file__), "..", "..", "art-source", "ui", "streak", "streak_icon.png")

FRONT = (255, 112, 38)
SIDE = (196, 62, 22)
TOP = (255, 168, 92)
CORE = (255, 214, 92)
CORE_SIDE = (240, 160, 40)

# Outer flame, clockwise, in a 0..100 box (straight facets only).
OUTER = [(50, 4), (64, 20), (70, 34), (78, 26), (86, 44), (88, 62), (82, 80), (68, 94),
         (50, 98), (32, 94), (18, 80), (13, 62), (16, 46), (26, 32), (32, 42), (36, 26)]
INNER = [(52, 46), (62, 60), (66, 72), (62, 84), (50, 90), (38, 84), (35, 72), (41, 62), (46, 66)]

TILT = math.radians(-8)
DEPTH = (5.0, 4.0)  # extrusion toward bottom-right


def tf(p, off=(0.0, 0.0)):
	x, y = p[0] - 50, p[1] - 52
	c, s = math.cos(TILT), math.sin(TILT)
	x, y = x * c - y * s, x * s + y * c
	k = W / 112
	return ((x + off[0]) * k + W / 2 - DEPTH[0] * k / 2, (y + off[1]) * k + W / 2 - DEPTH[1] * k / 2)


def extrude(d, poly, side, top):
	n = len(poly)
	for i in range(n):
		a, b = poly[i], poly[(i + 1) % n]
		quad = [tf(a), tf(b), tf(b, DEPTH), tf(a, DEPTH)]
		# edges facing up-left catch light, the rest are the dark side
		ex, ey = b[0] - a[0], b[1] - a[1]
		nx, ny = ey, -ex  # outward normal for a clockwise polygon (y down)
		d.polygon(quad, fill=top if (nx * -1 + ny * -1) > 0 else side)
	d.polygon([tf(p, DEPTH) for p in poly], fill=side)


img = Image.new("RGBA", (W, W), (0, 0, 0, 0))
d = ImageDraw.Draw(img)
# back extrusion first, then the faces
d.polygon([tf(p, DEPTH) for p in OUTER], fill=SIDE)
extrude(d, OUTER, SIDE, TOP)
d.polygon([tf(p) for p in OUTER], fill=FRONT)
# a light bevel facet on the upper-left of the front face
d.polygon([tf(p) for p in [(50, 4), (36, 26), (32, 42), (26, 32), (16, 46), (22, 46), (28, 40), (34, 48), (40, 28), (50, 12)]], fill=TOP)
# inner core, set into the face (its own small step)
d.polygon([tf(p, (1.2, 1.0)) for p in INNER], fill=CORE_SIDE)
d.polygon([tf(p) for p in INNER], fill=CORE)
img = img.resize((400, 400), Image.LANCZOS)
os.makedirs(os.path.dirname(OUT), exist_ok=True)
img.save(OUT)
print(OUT)
