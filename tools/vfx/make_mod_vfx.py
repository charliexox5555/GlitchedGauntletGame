"""Renders the Mod VFX texture set (stylized, Valorant-style: crisp rings,
hex patterns, chevrons; no realistic smoke) with numpy + Pillow.

    python tools/vfx/make_mod_vfx.py            # writes art-source/vfx/mods/*.png + contact sheet

Every texture is white on a transparent background (straight alpha) so the game
tints it per viewer (cyan ally / orange-red enemy / magenta glitch) with
Decal.Color3, ImageColor3, ParticleEmitter.Color or Beam.Color. Upload each
as a Decal, then read the Image id in Studio (Art Direction -> VFX) and put it
in src/shared/Config/VfxTextures.luau (MOD_* keys).
"""

from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "art-source" / "vfx" / "mods"
SIZE = 512


def grid(size=SIZE):
	"""x, y in -1..1 (y up), radius, angle."""
	c = (np.arange(size) + 0.5) / size * 2 - 1
	x, y = np.meshgrid(c, -c)
	return x, y, np.hypot(x, y), np.arctan2(y, x)


def smooth(edge0, edge1, v):
	t = np.clip((v - edge0) / (edge1 - edge0), 0, 1)
	return t * t * (3 - 2 * t)


def band(v, center, half, soft):
	"""1 inside |v - center| < half, soft edges."""
	d = np.abs(v - center)
	return 1 - smooth(half, half + soft, d)


def save(name, alpha):
	a = np.clip(alpha, 0, 1)
	rgba = np.zeros(a.shape + (4,), dtype=np.uint8)
	rgba[..., :3] = 255
	rgba[..., 3] = (a * 255).round().astype(np.uint8)
	OUT.mkdir(parents=True, exist_ok=True)
	path = OUT / f"{name}.png"
	Image.fromarray(rgba, "RGBA").save(path)
	return path


def ring():
	"""Crisp thin ring with an inner glow falloff (shockwaves, danger rings)."""
	_, _, r, _ = grid()
	core = band(r, 0.9, 0.025, 0.012)
	glow = np.exp(-((r - 0.9) / 0.09) ** 2) * 0.45 * (r < 0.9)
	return np.maximum(core, glow)


def ring_dashed():
	"""Segmented ring with tick marks (zone rims, placement previews)."""
	_, _, r, a = grid()
	core = band(r, 0.92, 0.02, 0.01)
	dashes = (np.cos(a * 36) > -0.35).astype(float)
	ticks = band(r, 0.84, 0.035, 0.01) * (np.cos(a * 12) > 0.94)
	return np.maximum(core * dashes, ticks)


def scan():
	"""Scan pulse: a bright leading edge fading inward (Ping)."""
	_, _, r, _ = grid()
	edge = band(r, 0.94, 0.02, 0.012)
	trail = np.clip((r - 0.45) / 0.49, 0, 1) ** 3 * (r < 0.94) * 0.55
	return np.maximum(edge, trail)


def hex_tile():
	"""Tileable hex grid lines (domes, the Firewall panel): 4 hexes across and
	2 lattice rows down, so the 512 x 443 image repeats exactly. Use it as a
	Texture with StudsPerTileV = 0.866 x StudsPerTileU."""
	sx, sy = 1.0, np.sqrt(3)  # lattice cell
	cols, rows = 4, 2
	w = SIZE
	h = int(round(w * rows * sy / (cols * sx)))
	px = (np.arange(w) + 0.5) / w * cols * sx
	py = (np.arange(h) + 0.5) / h * rows * sy
	px, py = np.meshgrid(px, py)

	def mod(a, m):
		return a - m * np.floor(a / m)

	# Two offset lattices; each pixel belongs to the nearer hex centre.
	ax, ay = mod(px, sx) - sx / 2, mod(py, sy) - sy / 2
	bx, by = mod(px - sx / 2, sx) - sx / 2, mod(py - sy / 2, sy) - sy / 2
	use_a = ax * ax + ay * ay < bx * bx + by * by
	gx = np.abs(np.where(use_a, ax, bx))
	gy = np.abs(np.where(use_a, ay, by))
	# Hex distance: 0.5 on the edges.
	d = np.maximum(gx * 0.5 + gy * (np.sqrt(3) / 2), gx)
	return smooth(0.44, 0.49, d) * 0.9


def chevron():
	"""Stacked chevrons pointing DOWN the image: on a part's Top face that is
	the part's LookVector (the Launch Pad's launch direction)."""
	x, y, _, _ = grid()
	y = -y
	out = np.zeros_like(x)
	for i, cy in enumerate((-0.45, 0.05, 0.55)):
		v = y - cy + np.abs(x) * 0.8
		arm = band(v, 0, 0.09, 0.02) * (np.abs(x) < 0.62)
		out = np.maximum(out, arm * (0.55 + 0.225 * i))
	return out


def glow():
	"""Soft round glow (cores, light pops)."""
	_, _, r, _ = grid()
	return np.exp(-(r / 0.42) ** 2) * (r < 1)


def sparkle():
	"""Four-point star (sparkles, heal motes)."""
	x, y, r, _ = grid()
	arms = np.maximum(np.exp(-(np.abs(x) / 0.06) ** 1.4), np.exp(-(np.abs(y) / 0.06) ** 1.4))
	return np.clip(arms * np.exp(-(r / 0.75) ** 2) + np.exp(-(r / 0.14) ** 2), 0, 1)


def cross():
	"""Rounded plus (heal particles)."""
	x, y, _, _ = grid()
	bar = lambda a, b: band(a, 0, 0.17, 0.03) * band(b, 0, 0.62, 0.03)  # noqa: E731
	return np.maximum(bar(x, y), bar(y, x))


TEXTURES = {
	"ring": ring,
	"ring_dashed": ring_dashed,
	"scan": scan,
	"hex": hex_tile,
	"chevron": chevron,
	"glow": glow,
	"sparkle": sparkle,
	"cross": cross,
}


def main():
	paths = [save(name, fn()) for name, fn in TEXTURES.items()]
	# Contact sheet on dark grey, tinted cyan, for review.
	tile = 160
	sheet = Image.new("RGB", (tile * len(paths), tile), (24, 26, 30))
	for i, p in enumerate(paths):
		im = Image.open(p).resize((tile, tile))
		color = Image.new("RGB", im.size, (0, 229, 255))
		sheet.paste(color, (i * tile, 0), im)
	sheet.save(OUT / "contact_sheet.png")
	for p in paths:
		print(p.relative_to(ROOT).as_posix())


if __name__ == "__main__":
	main()
