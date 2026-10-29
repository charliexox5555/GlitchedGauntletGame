"""Build the 9 Mod HUD icons: hand-authored SVG -> 256x256 PNG -> contact sheet.

    python tools/icons/make_mod_icons.py

Writes art-source/abilities/Icons/<ModId>.svg and <ModId>.png (white glyph on
transparent, so the HUD can tint and frame it) and contact_sheet.png (every
icon on dark slate, cyan and orange-red tiles, at 128 px and at 48 px, plus a
3-slot HUD mock with a cooldown sweep).

Style: Valorant ability-icon language. One flat white glyph per Mod, sharp
mitred corners, simple geometric shapes, no text. Strokes and gaps are at
least 14 px on the 256 canvas (about 2.6 px at 48 px) so they survive the
phone HUD. Glyphs stay inside a 24 px safe margin.

Renderer: headless Chrome or Edge (already installed on Windows).
Pillow does the post-pass and the contact sheet.
"""

import math
import os
import shutil
import subprocess
import sys
import tempfile

from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "art-source", "abilities", "Icons")
SIZE = 256
MARGIN = 24

SLATE = (30, 37, 48)
CYAN = (0, 229, 255)
ORANGE = (255, 90, 54)
SHEET_BG = (14, 17, 22)

# ---------------------------------------------------------------- geometry helpers


def pts(points):
	return " ".join(f"{x:.2f},{y:.2f}" for x, y in points)


def poly(points):
	return f'<polygon points="{pts(points)}"/>'


def polyline(points):
	return f'<polyline points="{pts(points)}"/>'


def chevron_up(cx, top, w, h, t):
	"""Solid upward chevron: apex at (cx, top), arms w wide and h tall, t thick (vertical)."""
	return poly([(cx, top), (cx + w, top + h), (cx + w, top + h + t), (cx, top + t), (cx - w, top + h + t), (cx - w, top + h)])


def polar(cx, cy, r, deg):
	a = math.radians(deg)
	return cx + r * math.cos(a), cy + r * math.sin(a)


def arc(cx, cy, r, a0, a1):
	"""Arc path from angle a0 to a1 (degrees, screen space: increasing = clockwise)."""
	x0, y0 = polar(cx, cy, r, a0)
	x1, y1 = polar(cx, cy, r, a1)
	large = 1 if abs(a1 - a0) > 180 else 0
	sweep = 1 if a1 > a0 else 0
	return f'<path d="M {x0:.2f} {y0:.2f} A {r} {r} 0 {large} {sweep} {x1:.2f} {y1:.2f}"/>'


def ellipse_arc(cx, cy, rx, ry, upper):
	"""Upper (back) or lower (front) half of an ellipse."""
	sweep = 1 if upper else 0  # SVG sweep 1 = clockwise on screen, which goes over the top
	return f'<path d="M {cx - rx} {cy} A {rx} {ry} 0 0 {sweep} {cx + rx} {cy}"/>'


# A glyph is a list of layers drawn in order. Each layer is
#   ("fill", svg)                  solid white shape
#   ("stroke", svg, width)         white outline, mitred
#   ("cut", svg)                   negative space cut out of everything below
# and may add gap=<px>: everything already drawn is knocked out around this
# layer by that many px, so overlapping parts stay separate at small sizes.


def layer(kind, svg, width=0, gap=0, cap="butt"):
	return {"kind": kind, "svg": svg, "w": width, "gap": gap, "cap": cap}


def build_svg(layers):
	defs = []
	body = ""
	for i, l in enumerate(layers):
		if l["kind"] == "cut" or l["gap"]:
			if l["kind"] == "cut":
				knock = f'<g fill="black">{l["svg"]}</g>'
			elif l["kind"] == "fill":
				knock = f'<g fill="black" stroke="black" stroke-width="{2 * l["gap"]}" stroke-linejoin="miter">{l["svg"]}</g>'
			else:
				knock = f'<g fill="none" stroke="black" stroke-width="{l["w"] + 2 * l["gap"]}" stroke-linecap="{l["cap"]}" stroke-linejoin="miter">{l["svg"]}</g>'
			defs.append(
				f'<mask id="k{i}" maskUnits="userSpaceOnUse" x="0" y="0" width="{SIZE}" height="{SIZE}">'
				f'<rect width="{SIZE}" height="{SIZE}" fill="white"/>{knock}</mask>'
			)
			body = f'<g mask="url(#k{i})">{body}</g>'
		if l["kind"] == "fill":
			body += f'<g fill="#FFFFFF">{l["svg"]}</g>'
		elif l["kind"] == "stroke":
			body += (
				f'<g fill="none" stroke="#FFFFFF" stroke-width="{l["w"]}" stroke-linecap="{l["cap"]}" '
				f'stroke-linejoin="miter" stroke-miterlimit="10">{l["svg"]}</g>'
			)
	return (
		f'<svg xmlns="http://www.w3.org/2000/svg" width="{SIZE}" height="{SIZE}" viewBox="0 0 {SIZE} {SIZE}">'
		f"<defs>{''.join(defs)}</defs>{body}</svg>\n"
	)


# ---------------------------------------------------------------- the 9 glyphs


def blink():
	# Notched dart flying right, with staggered speed bars trailing it.
	def bar(x0, x1, y0, h):
		s = 10  # slant: the bars lean forward
		return poly([(x0 + s, y0), (x1 + s, y0), (x1, y0 + h), (x0, y0 + h)])

	return [
		layer("fill", poly([(134, 50), (230, 128), (134, 206), (160, 128)])),
		layer("fill", bar(54, 118, 80, 20)),
		layer("fill", bar(26, 132, 118, 20)),
		layer("fill", bar(70, 118, 156, 20)),
	]


def launch_pad():
	# Flat hex pad seen side-on, two chevrons launching up off it.
	return [
		layer("fill", chevron_up(128, 28, 72, 56, 30)),
		layer("fill", chevron_up(128, 86, 72, 56, 30)),
		layer("fill", poly([(30, 206), (62, 186), (194, 186), (226, 206), (194, 226), (62, 226)])),
		layer("cut", '<rect x="80" y="199" width="96" height="14"/>'),
	]


def packet():
	# Grenade: round body with a cut seam, fuse cap, spoon lever and pull ring.
	return [
		layer("fill", '<circle cx="120" cy="150" r="76"/>'),
		layer("cut", '<rect x="40" y="140" width="160" height="16"/>'),
		layer("fill", '<rect x="92" y="56" width="56" height="34"/>', gap=8),
		layer("stroke", polyline([(140, 66), (192, 66), (214, 92), (214, 132)]), width=18, gap=8),
		layer("stroke", '<circle cx="66" cy="62" r="22"/>', width=14, gap=6),
	]


def firewall():
	# Brick wall: 4 courses, staggered joints, chamfered outer corners.
	x0, x1, h, g = 34, 222, 30, 14
	rows = [
		[(x0, 122), (122 + g, x1)],
		[(x0, 78), (78 + g, 166), (166 + g, x1)],
		[(x0, 122), (122 + g, x1)],
		[(x0, 78), (78 + g, 166), (166 + g, x1)],
	]
	top = 128 - (4 * h + 3 * g) / 2
	shapes = []
	for r, bricks in enumerate(rows):
		y = top + r * (h + g)
		for a, b in bricks:
			c = 10  # chamfer on the wall's outer corners only
			tl = c if (a == x0 and r == 0) else 0
			tr = c if (b == x1 and r == 0) else 0
			bl = c if (a == x0 and r == 3) else 0
			br = c if (b == x1 and r == 3) else 0
			shapes.append(poly([(a + tl, y), (b - tr, y), (b, y + tr), (b, y + h - br), (b - br, y + h), (a + bl, y + h), (a, y + h - bl), (a, y + tl)]))
	return [layer("fill", "".join(shapes))]


def lag_field():
	# Hourglass standing in a zone ring: back half of the ring behind it, front half in front.
	cx, cy, rx, ry = 128, 194, 94, 22
	glass = poly([(84, 52), (172, 52), (134, 118), (134, 122), (172, 188), (84, 188), (122, 122), (122, 118)])
	return [
		layer("stroke", ellipse_arc(cx, cy, rx, ry, upper=True), width=14),
		layer("fill", '<rect x="66" y="26" width="124" height="18"/>' + '<rect x="66" y="188" width="124" height="18"/>', gap=8),
		layer("fill", glass, gap=8),
		layer("cut", poly([(106, 70), (150, 70), (128, 104)])),
		layer("stroke", ellipse_arc(cx, cy, rx, ry, upper=False), width=14, gap=8),
	]


def ping():
	# Eye (solid almond, ring-cut iris, solid pupil) with sonar arcs either side.
	eye = '<path d="M 58 128 Q 128 54 198 128 Q 128 202 58 128 Z"/>'
	return [
		layer("fill", eye),
		layer("cut", '<circle cx="128" cy="128" r="30"/>'),
		layer("fill", '<circle cx="128" cy="128" r="17"/>'),
		layer("stroke", arc(128, 128, 96, 145, 215) + arc(128, 128, 96, -35, 35), width=16),
	]


def patch_up():
	# Chunky plus inside a hex frame.
	hexagon = [polar(128, 128, 92, -90 + 60 * i) for i in range(6)]
	a, w = 54, 21  # arm half-length, half-width
	plus = poly(
		[
			(128 - w, 128 - a), (128 + w, 128 - a), (128 + w, 128 - w), (128 + a, 128 - w),
			(128 + a, 128 + w), (128 + w, 128 + w), (128 + w, 128 + a), (128 - w, 128 + a),
			(128 - w, 128 + w), (128 - a, 128 + w), (128 - a, 128 - w), (128 - w, 128 - w),
		]
	)
	return [
		layer("stroke", poly(hexagon), width=16),
		layer("fill", plus),
	]


def overclock():
	# Bold lightning bolt.
	return [layer("fill", poly([(140, 24), (56, 142), (114, 142), (92, 232), (200, 100), (142, 100), (180, 24)]))]


def rollback():
	# Anticlockwise arrow around a rewind (<<) mark.
	cx, cy, r, t = 128, 136, 80, 22
	head_at = -78
	px, py = polar(cx, cy, r, head_at)
	tx, ty = math.sin(math.radians(head_at)), -math.cos(math.radians(head_at))  # anticlockwise tangent
	nx, ny = math.cos(math.radians(head_at)), math.sin(math.radians(head_at))  # outward normal
	hw, hl = 30, 46
	head = poly([(px + nx * hw, py + ny * hw), (px + tx * hl, py + ty * hl), (px - nx * hw, py - ny * hw)])
	rewind = poly([(84, 136), (126, 106), (126, 166)]) + poly([(126, 136), (168, 106), (168, 166)])
	return [
		layer("stroke", arc(cx, cy, r, head_at, 210), width=t),
		layer("fill", head),
		layer("fill", rewind),
	]


MODS = [
	("Dash", "Dash", blink),
	("LaunchPad", "Launch Pad", launch_pad),
	("Packet", "Packet", packet),
	("Firewall", "Firewall", firewall),
	("LagField", "Lag Field", lag_field),
	("Ping", "Ping", ping),
	("PatchUp", "Patch Up", patch_up),
	("Overclock", "Overclock", overclock),
	("Rollback", "Rollback", rollback),
]

# ---------------------------------------------------------------- rendering


def find_browser():
	for p in [
		r"C:\Program Files\Google\Chrome\Application\chrome.exe",
		r"C:\Program Files (x86)\Google\Chrome\Application\chrome.exe",
		r"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe",
		r"C:\Program Files\Microsoft\Edge\Application\msedge.exe",
	]:
		if os.path.exists(p):
			return p
	for name in ("chrome", "msedge", "chromium"):
		p = shutil.which(name)
		if p:
			return p
	sys.exit("No Chrome/Edge found to render SVG.")


def render(browser, svg_path, png_path, profile):
	uri = "file:///" + svg_path.replace("\\", "/")
	subprocess.run(
		[
			browser, "--headless=new", "--disable-gpu", "--hide-scrollbars", "--no-first-run",
			"--force-device-scale-factor=1", "--default-background-color=00000000",
			f"--user-data-dir={profile}", f"--window-size={SIZE},{SIZE}", f"--screenshot={png_path}", uri,
		],
		check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
	)
	# Glyphs are pure white: force RGB to white so edges never fringe dark when the HUD tints them.
	img = Image.open(png_path).convert("RGBA")
	if img.size != (SIZE, SIZE):
		img = img.crop((0, 0, SIZE, SIZE))
	alpha = img.getchannel("A")
	out = Image.new("RGBA", img.size, (255, 255, 255, 0))
	out.putalpha(alpha)
	out.save(png_path, optimize=True)
	return out


def font(size):
	for name in ("segoeuib.ttf", "arialbd.ttf", "arial.ttf"):
		try:
			return ImageFont.truetype(name, size)
		except OSError:
			pass
	return ImageFont.load_default()


def tile(color, size, radius):
	t = Image.new("RGBA", (size, size), (0, 0, 0, 0))
	ImageDraw.Draw(t).rounded_rectangle((0, 0, size - 1, size - 1), radius, fill=color + (255,))
	return t


def contact_sheet(icons):
	big, small, pad = 128, 48, 16
	cell = big + pad
	cols = len(icons)
	width = pad + cols * cell
	label_font, head_font = font(15), font(18)
	bands = [("Dark slate", SLATE), ("Ally cyan", CYAN), ("Enemy orange-red", ORANGE)]
	band_h = 28 + big + 10 + small + 2 * pad
	hud_h = 28 + 96 + pad
	height = pad + 26 + len(bands) * band_h + hud_h
	sheet = Image.new("RGBA", (width, height), SHEET_BG + (255,))
	d = ImageDraw.Draw(sheet)

	y = pad
	for i, (_, name, _) in enumerate(MODS):
		x = pad + i * cell
		tw = d.textlength(name, font=label_font)
		d.text((x + (big - tw) / 2, y), name, font=label_font, fill=(220, 226, 235))
	y += 26

	for title, color in bands:
		d.text((pad, y), f"{title}: 128 px / 48 px", font=head_font, fill=(150, 160, 175))
		y += 28
		for i, img in enumerate(icons):
			x = pad + i * cell
			sheet.alpha_composite(tile(color, big, 14), (x, y))
			sheet.alpha_composite(img.resize((big - 24, big - 24), Image.LANCZOS), (x + 12, y + 12))
			sx = x + (big - small) // 2
			sheet.alpha_composite(tile(color, small, 6), (sx, y + big + 10))
			sheet.alpha_composite(img.resize((small - 8, small - 8), Image.LANCZOS), (sx + 4, y + big + 14))
		y += big + 10 + small + 2 * pad

	# HUD mock: 3 slots bottom-centre at phone size, middle one cooling down.
	d.text((pad, y), "HUD mock (48 px slots, Packet on cooldown)", font=head_font, fill=(150, 160, 175))
	y += 28
	slot = 48
	strip = Image.new("RGBA", (width, 96), (40, 52, 46, 255))
	sd = ImageDraw.Draw(strip)
	for i in range(0, width, 24):
		sd.line((i, 0, i - 60, 96), fill=(46, 60, 52, 255), width=10)
	picks = [0, 2, 8]
	gx = width // 2 - (3 * slot + 2 * 12) // 2
	for n, k in enumerate(picks):
		x, sy = gx + n * (slot + 12), 24
		sd.ellipse((x, sy, x + slot, sy + slot), fill=(16, 20, 26, 220), outline=CYAN + (255,), width=2)
		glyph = icons[k].resize((slot - 14, slot - 14), Image.LANCZOS)
		if n == 1:
			glyph.putalpha(glyph.getchannel("A").point(lambda a: a * 45 // 100))
		strip.alpha_composite(glyph, (x + 7, sy + 7))
		if n == 1:
			sweep = Image.new("RGBA", (slot, slot), (0, 0, 0, 0))
			ImageDraw.Draw(sweep).pieslice((2, 2, slot - 3, slot - 3), -90, -90 + 360 * 0.6, fill=(0, 0, 0, 120))
			strip.alpha_composite(sweep, (x, sy))
	sheet.alpha_composite(strip, (0, y))
	return sheet


def main():
	os.makedirs(OUT, exist_ok=True)
	browser = find_browser()
	icons = []
	with tempfile.TemporaryDirectory() as profile:
		for mod_id, _, fn in MODS:
			svg_path = os.path.join(OUT, f"{mod_id}.svg")
			png_path = os.path.join(OUT, f"{mod_id}.png")
			with open(svg_path, "w", encoding="utf-8") as f:
				f.write(build_svg(fn()))
			img = render(browser, svg_path, png_path, profile)
			bbox = img.getchannel("A").getbbox()
			inside = bbox and min(bbox[0], bbox[1]) >= MARGIN - 2 and max(bbox[2], bbox[3]) <= SIZE - MARGIN + 2
			print(f"{mod_id:10s} bbox={bbox} {'ok' if inside else 'OUTSIDE SAFE MARGIN'}")
			icons.append(img)
	sheet = contact_sheet(icons)
	sheet.convert("RGB").save(os.path.join(OUT, "contact_sheet.png"), optimize=True)
	print("wrote", os.path.relpath(OUT, ROOT))


if __name__ == "__main__":
	main()
