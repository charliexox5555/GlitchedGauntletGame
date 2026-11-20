"""The lobby plate set as 9-slice images (vault/02 Art/UI Polish Pass.md -> 3).

    python -I tools/ui/make_plates.py

One greyscale PNG per shape: the fill with its light baked in (bright top,
a little deeper toward the bottom, a darker lip), white so ImageColor3 tints
it. Each is used with ScaleType.Slice and the SliceCenter printed below and
written to art-source/ui/plates/v2/slices.json; the shape's ends / corners
live in the fixed outer columns, so a plate stretches to any size and scales
on hover as ONE piece (no caps, no seams). Drawn at 4x and downsampled for
clean edges. Also writes preview.png: each shape tinted with the lobby
colours at a few sizes, sliced the way Roblox slices them.

Shapes (128 x 96 unless said):
  slant      both ends slanted (the current plate look, parallelogram)
  slant_r    left end square-cut, right end slanted (tabs, price flags)
  cut1       rectangle, one cut corner top-right (Soft Edge plate)
  cut2       two opposite cut corners, top-left and bottom-right (cards)
  cell       rectangle with small 45-degree chamfers on all corners (cells, rows)
  shadow     soft dark shadow under a lifted plate (a 9-slice blur), 160 x 128
"""

import json
import os

from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "art-source", "ui", "plates", "v2")
SS = 4  # supersample

W, H = 128, 96
END = 32  # fixed end columns (the slant reach), px at 1x
LIP = 8  # the darker lip at the bottom, px at 1x
CUT = 18  # a cut corner's leg, px at 1x
CHAMFER = 6


def poly(name):
	"""The shape's outline at 1x, as (x, y) points."""
	if name == "slant":
		return [(END - 4, 0), (W, 0), (W - END + 4, H), (0, H)]
	if name == "slant_r":
		return [(0, 0), (W, 0), (W - END + 4, H), (0, H)]
	if name == "cut1":
		return [(0, 0), (W - CUT, 0), (W, CUT), (W, H), (0, H)]
	if name == "cut2":
		return [(CUT, 0), (W, 0), (W, H - CUT), (W - CUT, H), (0, H), (0, CUT)]
	if name == "cell":
		c = CHAMFER
		return [(c, 0), (W - c, 0), (W, c), (W, H - c), (W - c, H), (c, H), (0, H - c), (0, c)]
	raise ValueError(name)


SLICES = {
	# left, top, right, bottom of the stretchy middle (Roblox SliceCenter)
	"slant": (END, 0, W - END, H),
	"slant_r": (8, 0, W - END, H),
	"cut1": (8, CUT + 2, W - CUT - 2, H - LIP - 2),
	"cut2": (CUT + 2, CUT + 2, W - CUT - 2, H - CUT - 2),
	"cell": (CHAMFER + 2, CHAMFER + 2, W - CHAMFER - 2, H - LIP - 2),
}


def light(size):
	"""The baked light, white = 255: bright top, deeper bottom, a darker lip."""
	w, h = size
	img = Image.new("L", (w, h))
	px = img.load()
	lip = LIP * SS
	for y in range(h):
		if y >= h - lip:
			v = 158  # the lip (~0.62)
		else:
			t = y / max(h - lip - 1, 1)
			v = int(255 - 26 * t)  # 1.0 at the top -> ~0.9 above the lip
			if y < 2 * SS:
				v = 255  # a thin bright top line
		for x in range(w):
			px[x, y] = v
	return img


def shape(name):
	w, h = W * SS, H * SS
	mask = Image.new("L", (w, h), 0)
	ImageDraw.Draw(mask).polygon([(x * SS, y * SS) for x, y in poly(name)], fill=255)
	lum = light((w, h))
	rgba = Image.merge("RGBA", (lum, lum, lum, mask))
	return rgba.resize((W, H), Image.LANCZOS)


def shadow():
	sw, sh, pad = 160, 128, 16
	img = Image.new("L", (sw * SS, sh * SS), 0)
	ImageDraw.Draw(img).rectangle(
		[pad * SS, pad * SS + 4 * SS, (sw - pad) * SS, (sh - pad) * SS + 4 * SS], fill=150
	)
	img = img.filter(ImageFilter.GaussianBlur(9 * SS)).resize((sw, sh), Image.LANCZOS)
	black = Image.new("L", (sw, sh), 0)
	return Image.merge("RGBA", (black, black, black, img)), (40, 40, sw - 40, sh - 40)


def slice9(img, rect, size, scale=1.0):
	"""Draw img 9-sliced into size (like Roblox, SliceScale = scale)."""
	l, t, r, b = rect
	iw, ih = img.size
	tw, th = size
	L, T, R, B = int(l * scale), int(t * scale), int((iw - r) * scale), int((ih - b) * scale)
	out = Image.new("RGBA", size, (0, 0, 0, 0))
	xs_src = [(0, l), (l, r), (r, iw)]
	ys_src = [(0, t), (t, b), (b, ih)]
	xs_dst = [(0, L), (L, tw - R), (tw - R, tw)]
	ys_dst = [(0, T), (T, th - B), (th - B, th)]
	for (sy0, sy1), (dy0, dy1) in zip(ys_src, ys_dst):
		for (sx0, sx1), (dx0, dx1) in zip(xs_src, xs_dst):
			if sx1 <= sx0 or sy1 <= sy0 or dx1 <= dx0 or dy1 <= dy0:
				continue
			part = img.crop((sx0, sy0, sx1, sy1)).resize((dx1 - dx0, dy1 - dy0), Image.LANCZOS)
			out.alpha_composite(part, (dx0, dy0))
	return out


def tint(img, rgb):
	r, g, b, a = img.split()
	lum = r
	ch = [lum.point(lambda v, c=c: int(v * c / 255)) for c in rgb]
	return Image.merge("RGBA", (*ch, a))


def main():
	os.makedirs(OUT, exist_ok=True)
	made = {}
	for name in ["slant", "slant_r", "cut1", "cut2", "cell"]:
		img = shape(name)
		img.save(os.path.join(OUT, f"plate_{name}.png"))
		made[name] = (img, SLICES[name])
	sh, sh_rect = shadow()
	sh.save(os.path.join(OUT, "plate_shadow.png"))
	with open(os.path.join(OUT, "slices.json"), "w") as f:
		json.dump(
			{k: {"size": [W, H], "sliceCenter": list(v[1])} for k, v in made.items()}
			| {"shadow": {"size": list(sh.size), "sliceCenter": list(sh_rect)}},
			f,
			indent=1,
		)

	# preview board: the lobby's colours at a few sizes
	bg = (19, 19, 22)
	board = Image.new("RGBA", (1280, 760), bg + (255,))
	cols = {
		"navy": (20, 20, 23),
		"navyHi": (37, 37, 40),
		"white": (255, 255, 255),
		"gold": (255, 200, 61),
		"cyan": (63, 224, 242),
		"red": (255, 77, 94),
	}
	# lift the dark ones so they read on the dark board
	cols["navy"] = (44, 44, 50)
	cols["navyHi"] = (64, 64, 70)
	y = 24
	for name, (img, rect) in made.items():
		x = 24
		for (w, h), cname in zip([(320, 72), (200, 56), (140, 44), (420, 110)], ["navyHi", "white", "gold", "cyan"]):
			sc = 0.5 if h < 60 else (0.75 if h < 100 else 1.0)
			s = sh_img = slice9(sh, sh_rect, (w + 40, h + 40), 0.6)
			board.alpha_composite(s, (x - 20, y - 14))
			board.alpha_composite(tint(slice9(img, rect, (w, h), sc), cols[cname]), (x, y))
			x += w + 24
		y += 140 if name != "cell" else 120
	board.convert("RGB").save(os.path.join(OUT, "preview.png"))
	for k, (_, r) in made.items():
		print(k, "SliceCenter", r)
	print("shadow SliceCenter", sh_rect)


if __name__ == "__main__":
	main()
