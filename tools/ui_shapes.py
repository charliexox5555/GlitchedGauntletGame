"""Panel shapes and icon slices for the game UI (vault/02 Art/UI Design.md → Shapes).

    python tools/ui_shapes.py [icon_sheet.png]

Writes white (tintable) 9-slice shapes and baked plates to art-source/ui/shapes/,
and, given the Figma icon export sheet (14 icons, 256 px each, in ICONS order),
one PNG per icon to art-source/ui/icons/. Shapes are drawn at 4x and scaled
down for clean edges.
"""

import os
import sys

from PIL import Image, ImageDraw

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
SHAPES = os.path.join(ROOT, "art-source", "ui", "shapes")
ICON_DIR = os.path.join(ROOT, "art-source", "ui", "icons")
ICONS = ["Dash", "Updraft", "Molly", "Firewall", "Frost", "Recon", "HealOrb", "Stim", "Recall",
	"Reroll", "Lock", "Shield", "Skull", "Glitch"]
SS = 4  # supersampling


def poly(size, points, fill=None, outline=None, width=0):
	w, h = size
	im = Image.new("RGBA", (w * SS, h * SS), (0, 0, 0, 0))
	d = ImageDraw.Draw(im)
	pts = [(x * SS, y * SS) for x, y in points]
	if fill:
		d.polygon(pts, fill=fill)
	if outline:
		d.line(pts + [pts[0]], fill=outline, width=width * SS, joint="curve")
	return im.resize((w, h), Image.LANCZOS)


def cut(w, h, c):
	# Cut top-left and bottom-right corners (the card shape).
	return [(c, 0), (w, 0), (w, h - c), (w - c, h), (0, h), (0, c)]


def inset(points, k):
	# Rough inward offset so an outline stays inside the shape.
	cx = sum(p[0] for p in points) / len(points)
	cy = sum(p[1] for p in points) / len(points)
	return [(x + (cx - x) * k, y + (cy - y) * k) for x, y in points]


def save(im, name):
	im.save(os.path.join(SHAPES, name + ".png"))
	print(name, im.size)


def main():
	os.makedirs(SHAPES, exist_ok=True)
	white = (255, 255, 255, 255)
	# 9-slice card: 128 px, 32 px cuts. SliceCenter = (32, 32, 96, 96).
	save(poly((128, 128), cut(128, 128, 32), fill=white), "CutFill")
	line = Image.new("RGBA", (128 * SS, 128 * SS), (0, 0, 0, 0))
	d = ImageDraw.Draw(line)
	m = 1.5 * SS
	pts = [(x * SS, y * SS) for x, y in cut(128, 128, 32)]
	pts = [(min(max(x, m), 128 * SS - m), min(max(y, m), 128 * SS - m)) for x, y in pts]
	d.line(pts + [pts[0]], fill=white, width=3 * SS, joint="curve")
	save(line.resize((128, 128), Image.LANCZOS), "CutLine")
	# Key tab (flat hexagon), 300 x 88 (2x of 150 x 44); fill and outline.
	hexa = [(44, 0), (256, 0), (300, 44), (256, 88), (44, 88), (0, 44)]
	save(poly((300, 88), hexa, fill=white), "KeyTabFill")
	save(poly((300, 88), inset(hexa, 0.03), outline=white, width=3), "KeyTabLine")
	# Top bar plates, baked colours (panel fill + soft line), 2x.
	panel = (17, 21, 28, 222)
	stroke = (44, 52, 64, 255)
	strong = (74, 85, 100, 255)
	ally = [(0, 0), (760, 0), (800, 60), (840, 140), (80, 140)]
	save(poly((840, 140), ally, fill=panel, outline=stroke, width=3), "PlateLeft")
	save(poly((840, 140), [(840 - x, y) for x, y in ally], fill=panel, outline=stroke, width=3), "PlateRight")
	timer = [(0, 0), (600, 0), (532, 208), (68, 208)]
	save(poly((600, 208), timer, fill=(17, 21, 28, 240), outline=strong, width=3), "PlateTimer")
	# Kill banner: a slanted band, white (tint + gradient in game), 2x of 520 x 96.
	save(poly((1040, 192), [(60, 0), (1040, 0), (980, 192), (0, 192)], fill=white), "Slant")
	# Shield badge (HUD), white, tint in game: fill and outline.
	shield = [(60, 0), (120, 24), (120, 80), (100, 120), (60, 152), (20, 120), (0, 80), (0, 24)]
	save(poly((120, 152), shield, fill=white), "ShieldFill")
	save(poly((120, 152), inset(shield, 0.03), outline=white, width=4), "ShieldLine")

	if len(sys.argv) > 1:
		os.makedirs(ICON_DIR, exist_ok=True)
		sheet = Image.open(sys.argv[1]).convert("RGBA")
		for i, name in enumerate(ICONS):
			icon = sheet.crop((i * 256, 0, i * 256 + 256, 256))
			icon.save(os.path.join(ICON_DIR, name + ".png"))
		print("icons", len(ICONS))


if __name__ == "__main__":
	main()
