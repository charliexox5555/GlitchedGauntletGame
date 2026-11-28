"""Level badge for the lobby name tag: a flat-top faceted hexagon (bevel facets lit from the top-left),
greyscale so ImageColor3 tints it in Studio. Out: art-source/ui/nametag/level_badge.png (256 px).

    python tools/ui/nametag_badge.py
"""

import math
import os

from PIL import Image, ImageDraw

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "art-source", "ui", "nametag", "level_badge.png")
SS = 4  # supersample
SIZE = 256


def hexagon(cx: float, cy: float, rx: float, ry: float) -> list[tuple[float, float]]:
	# flat top: corners at 0, 60, ... degrees
	return [(cx + rx * math.cos(math.radians(a)), cy + ry * math.sin(math.radians(a))) for a in range(0, 360, 60)]


def main() -> None:
	s = SIZE * SS
	img = Image.new("RGBA", (s, s), (0, 0, 0, 0))
	d = ImageDraw.Draw(img)
	cx, cy = s / 2, s / 2
	outer = hexagon(cx, cy, s * 0.48, s * 0.44)
	inner = hexagon(cx, cy, s * 0.37, s * 0.33)
	# light from the top-left: facet shade by its outward normal
	light = (-0.45, -0.89)
	for i in range(6):
		a, b = outer[i], outer[(i + 1) % 6]
		c, e = inner[(i + 1) % 6], inner[i]
		mx, my = (a[0] + b[0]) / 2 - cx, (a[1] + b[1]) / 2 - cy
		n = math.hypot(mx, my)
		dot = (mx * light[0] + my * light[1]) / n
		v = int(150 + 105 * max(dot, 0) - 70 * max(-dot, 0))
		d.polygon([a, b, c, e], fill=(v, v, v, 255))
	d.polygon(inner, fill=(205, 205, 205, 255))
	img = img.resize((SIZE, SIZE), Image.LANCZOS)
	img.save(OUT)
	print(OUT)


if __name__ == "__main__":
	main()
