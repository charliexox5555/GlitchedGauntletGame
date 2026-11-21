"""Wharf MaterialVariant textures, procedural and faint (map Wharf, 2026-11-20).

    python tools/textures/make_wharf_textures.py [--preview]

Writes art-source/maps/Wharf/textures/<Variant>_Color.png and <Variant>_Normal.png (512 x 512, tiling both ways):
  Wharf_Concrete  10-stud slab with saw-cut joints on its edges and a faint trowel mottle
  Wharf_Asphalt   fine aggregate speckle and a soft low-frequency patching
  Wharf_Plank     five 1-stud boards with dark gaps, staggered butt joints and a faint grain
  Wharf_Ribbed    profiled sheet: trapezoid ribs across the tile (vertical on a wall)
  Wharf_Plate     steel deck plate: a weld seam on two edges, two bolt pairs, a faint mill mottle

Style Bible / gauntlet-build-style: textures faint (about +-4% value), matte, low-frequency, no fine noise that
reads as grain at game distance; Color is near-white (mean ~0.86) so BasePart.Color sets the hue. Normal maps
are OpenGL (+Y up) from a height field, as Roblox expects. Our own pixels, nothing sampled from RIVALS.
"""

from __future__ import annotations

import os
import sys

import numpy as np
from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "art-source", "maps", "Wharf", "textures")
N = 512
RNG = np.random.default_rng(20261120)


def smooth_noise(cells: int, octaves: int = 3) -> np.ndarray:
	"""Tiling value noise in [0, 1]: random grids, bicubic-upsampled with wrap, summed."""
	acc = np.zeros((N, N))
	amp, tot = 1.0, 0.0
	for o in range(octaves):
		c = cells * (2**o)
		g = RNG.random((c, c))
		big = np.tile(g, (3, 3))
		im = Image.fromarray((big * 255).astype(np.uint8)).resize((N * 3, N * 3), Image.BICUBIC)
		a = np.asarray(im, dtype=float)[N : 2 * N, N : 2 * N] / 255.0
		acc += a * amp
		tot += amp
		amp *= 0.5
	acc /= tot
	return (acc - acc.min()) / (acc.max() - acc.min() + 1e-9)


def normal_from_height(h: np.ndarray, strength: float) -> np.ndarray:
	dx = (np.roll(h, -1, axis=1) - np.roll(h, 1, axis=1)) * 0.5 * strength
	dy = (np.roll(h, -1, axis=0) - np.roll(h, 1, axis=0)) * 0.5 * strength
	nz = np.ones_like(h)
	n = np.stack([-dx, dy, nz], axis=-1)  # OpenGL: +Y up (image rows go down, so flip dy)
	n /= np.linalg.norm(n, axis=-1, keepdims=True)
	return ((n * 0.5 + 0.5) * 255).astype(np.uint8)


# Owner 2026-11-20 (after Wharf v1): "the textures might be a bit much". v2 keeps the patterns and halves both
# the colour variation and the bump.
AMP = 0.5


def save(name: str, color: np.ndarray, height: np.ndarray, strength: float) -> Image.Image:
	os.makedirs(OUT, exist_ok=True)
	c = np.clip(color, 0, 1)
	c = (c - c.mean()) * AMP + 0.86  # tintable near-white, softened
	strength *= AMP
	c = np.clip(c, 0, 1)
	rgb = (np.stack([c, c, c], axis=-1) * 255).astype(np.uint8)
	img = Image.fromarray(rgb, "RGB")
	img.save(os.path.join(OUT, f"{name}_Color.png"))
	Image.fromarray(normal_from_height(height, strength), "RGB").save(os.path.join(OUT, f"{name}_Normal.png"))
	sd = float(np.std(c))
	print(f"{name}: mean {c.mean():.3f}  std {sd:.3f}  (+-{100 * sd / c.mean():.1f}% value)")
	return img


def groove(u: np.ndarray, centre: float, width: float) -> np.ndarray:
	"""0..1 profile of a V-groove across u (pixels, wrapping)."""
	d = np.abs(((u - centre + N / 2) % N) - N / 2)
	return np.clip(1 - d / width, 0, 1)


yy, xx = np.mgrid[0:N, 0:N].astype(float)


def concrete():
	mott = smooth_noise(4) * 0.6 + smooth_noise(12, 2) * 0.4
	joint = np.maximum(groove(xx, 0, 3.0), groove(yy, 0, 3.0))  # saw cut on the tile edge (every 10 studs)
	color = 1 - 0.06 * mott - 0.18 * joint
	height = -joint * 1.6 + mott * 0.3
	return save("Wharf_Concrete", color, height, 2.2)


def asphalt():
	speck = RNG.random((N, N))
	speck = (speck > 0.985).astype(float) * 0.5 + (speck < 0.012).astype(float) * -0.5
	patch = smooth_noise(3)
	color = 1 - 0.07 * patch + 0.035 * speck
	height = speck * 0.25 + patch * 0.2
	return save("Wharf_Asphalt", color, height, 1.4)


def plank():
	boards = 5
	bw = N / boards
	color = np.ones((N, N))
	height = np.zeros((N, N))
	grain = smooth_noise(2, 2)
	for b in range(boards):
		x0 = b * bw
		inb = (xx >= x0) & (xx < x0 + bw)
		tone = 1 - 0.05 * RNG.random()
		# grain runs along the board (along y)
		g = np.sin((xx - x0) / bw * np.pi * (3 + b % 2) + grain * 6.0) * 0.5 + 0.5
		color = np.where(inb, tone - 0.03 * g, color)
		# one butt joint per board, staggered
		jy = (b * 0.37 % 1.0) * N
		j = groove(yy, jy, 2.0)
		color = np.where(inb, color - 0.16 * j, color)
		height = np.where(inb, -j * 1.2 + g * 0.15, height)
	gap = np.zeros((N, N))
	for b in range(boards):
		gap = np.maximum(gap, groove(xx, b * bw, 2.5))
	color = color - 0.3 * gap
	height = height - gap * 2.0
	return save("Wharf_Plank", color, height, 2.0)


def ribbed():
	ribs = 4  # one rib per stud at 4 studs a tile
	p = N / ribs
	u = (xx % p) / p
	# trapezoid profile: crest 0..0.3, slope, valley 0.45..0.8, slope
	prof = np.interp(u, [0.0, 0.3, 0.42, 0.8, 0.92, 1.0], [1, 1, 0, 0, 1, 1])
	mott = smooth_noise(3)
	color = 1 - 0.07 * (1 - prof) - 0.04 * mott
	height = prof * 1.0
	return save("Wharf_Ribbed", color, height, 5.0)


def plate():
	mott = smooth_noise(5, 2)
	weld = np.maximum(groove(xx, 0, 4.0), groove(yy, 0, 4.0))
	bolts = np.zeros((N, N))
	for bx, by in ((0.12, 0.12), (0.88, 0.12), (0.12, 0.88), (0.88, 0.88)):
		d = np.hypot(xx - bx * N, yy - by * N)
		bolts = np.maximum(bolts, np.clip(1 - d / 7.0, 0, 1))
	color = 1 - 0.05 * mott - 0.12 * weld + 0.05 * bolts
	height = weld * 0.8 + bolts * 1.2 + mott * 0.2
	return save("Wharf_Plate", color, height, 2.5)


if __name__ == "__main__":
	imgs = [concrete(), asphalt(), plank(), ribbed(), plate()]
	if "--preview" in sys.argv:
		sheet = Image.new("RGB", (N * len(imgs) // 2, N // 2), "white")
		for i, im in enumerate(imgs):
			sheet.paste(im.resize((N // 2, N // 2)), (i * N // 2, 0))
		path = os.path.join(ROOT, "vault", "02 Art", "References", "maps", "wharf", "wharf-variants-preview.png")
		os.makedirs(os.path.dirname(path), exist_ok=True)
		sheet.save(path)
		print("preview", path)
