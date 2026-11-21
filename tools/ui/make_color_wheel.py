"""The Settings colour picker's hue / saturation wheel (vault/02 Art/UI Settings.md).

    python tools/ui/make_color_wheel.py   ->  art-source/ui/settings/color_wheel.png

Hue goes clockwise from red at the top (yellow right-top, cyan bottom, like the
owner's RIVALS reference); saturation rises from white at the centre to full at
the rim; value is 1 (the picker's brightness bar darkens it in Roblox). The
rim is anti-aliased into transparency. SettingsController reads a point with
the same maths: hue = atan2(dx, -dy) / 2pi, sat = distance / radius.
"""

import colorsys
import math
import os

from PIL import Image

SIZE = 512
SS = 4  # supersampling for the rim
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "art-source", "ui", "settings", "color_wheel.png")


def main():
	big = SIZE * SS
	r = big / 2
	img = Image.new("RGBA", (big, big))
	px = img.load()
	for y in range(big):
		dy = y + 0.5 - r
		for x in range(big):
			dx = x + 0.5 - r
			d = math.hypot(dx, dy)
			if d > r:
				px[x, y] = (0, 0, 0, 0)
				continue
			hue = (math.atan2(dx, -dy) / (2 * math.pi)) % 1
			sat = min(d / (r - SS), 1)
			cr, cg, cb = colorsys.hsv_to_rgb(hue, sat, 1)
			px[x, y] = (round(cr * 255), round(cg * 255), round(cb * 255), 255)
	img = img.resize((SIZE, SIZE), Image.LANCZOS)
	os.makedirs(os.path.dirname(OUT), exist_ok=True)
	img.save(OUT)
	print(OUT)


if __name__ == "__main__":
	main()
