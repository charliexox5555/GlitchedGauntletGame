"""Generates the realistic weapon VFX textures (new direction, 2026-10-25).

    python tools/vfx/make_real_vfx.py [--preview <png>]

Plain numpy + Pillow, no Blender: every texture is built from fractal value
noise and simple shapes, saved as a straight-alpha PNG in art-source/vfx/real/.
Sheets marked 2x2 are flipbooks for FlipbookLayout.Grid2x2 (frames left to
right, top to bottom), each frame a different random variant.

  flash_front_2x2  muzzle flash seen down the barrel: hot core, 4-6 ragged
                   petals; colour baked (white-yellow core -> orange edge)
  flash_side_2x2   muzzle flame seen from the side, base at the bottom edge,
                   pointing up; colour baked
  smoke_2x2        soft billowing puff, light grey, lit from above (tinted)
  dust_2x2         grainy impact dust with ragged edges (tinted per surface)
  chips_2x2        one rock chip per frame, shaded (tinted per surface)
  hole             bullet hole: dark core, chipped rim, cracks, soot; neutral
                   greys so ImageColor3 can warm or cool it per material

Seeded, so re-running gives the same images.
"""

import argparse
import math
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "art-source" / "vfx" / "real"
FRAME = 256

rng = np.random.default_rng(20261025)


# Noise ------------------------------------------------------------------------


def value_noise(size, cells):
	"""Smooth noise in 0..1: a random grid upscaled bicubically."""
	grid = rng.random((cells + 3, cells + 3)).astype(np.float32)
	img = Image.fromarray((grid * 255).astype(np.uint8), "L")
	big = img.resize((size * (cells + 3) // cells,) * 2, Image.BICUBIC)
	off = size // cells
	arr = np.asarray(big, dtype=np.float32)[off : off + size, off : off + size] / 255
	return arr


def fbm(size, base=4, octaves=5, gain=0.5):
	total = np.zeros((size, size), np.float32)
	amp, norm = 1.0, 0.0
	cells = base
	for _ in range(octaves):
		total += value_noise(size, cells) * amp
		norm += amp
		amp *= gain
		cells *= 2
	return total / norm


def grid(size):
	"""Coordinates in -1..1, y up."""
	t = (np.arange(size, dtype=np.float32) + 0.5) / size * 2 - 1
	x, y = np.meshgrid(t, -t)
	return x, y


def smoothstep(a, b, v):
	t = np.clip((v - a) / (b - a), 0, 1)
	return t * t * (3 - 2 * t)


def ramp(v, stops):
	"""Colour ramp: stops = [(t, (r, g, b)), ...] with t ascending."""
	v = np.clip(v, 0, 1)
	out = np.zeros(v.shape + (3,), np.float32)
	for (t0, c0), (t1, c1) in zip(stops, stops[1:]):
		m = (v >= t0) & (v <= t1)
		k = ((v - t0) / max(t1 - t0, 1e-6))[m][:, None]
		out[m] = np.array(c0) * (1 - k) + np.array(c1) * k
	return out


def rgba(rgb, alpha):
	a = np.clip(alpha, 0, 1)
	img = np.concatenate([np.clip(rgb, 0, 255), (a * 255)[..., None]], axis=-1)
	return Image.fromarray(img.astype(np.uint8), "RGBA")


def sheet(frames):
	out = Image.new("RGBA", (FRAME * 2, FRAME * 2), (0, 0, 0, 0))
	for i, f in enumerate(frames):
		out.paste(f, ((i % 2) * FRAME, (i // 2) * FRAME))
	return out


# Fire colours: intensity 0..1 -> deep orange -> amber -> yellow -> near white.
FIRE = [
	(0.0, (150, 40, 5)),
	(0.25, (235, 95, 20)),
	(0.5, (255, 165, 50)),
	(0.75, (255, 220, 120)),
	(1.0, (255, 250, 235)),
]


# Muzzle flash ---------------------------------------------------------------------


def polar_streaks(r, a, across, along):
	"""Noise stretched along the radius: fast across the angle, slow outward."""
	n = fbm(FRAME, 8, 4)
	ix = ((a / math.tau + 0.5) * across % 1.0) * (FRAME - 1)
	iy = np.clip(r * along, 0, 1) * (FRAME - 1)
	return n[iy.astype(int), ix.astype(int)]


def flash_front():
	x, y = grid(FRAME)
	r = np.hypot(x, y)
	a = np.arctan2(y, x)
	streak = polar_streaks(r, a, 3.0, 0.35)
	# Outline radius per angle: a burst of uneven tongues around a hot disc.
	reach = np.full_like(r, 0.3)
	count = rng.integers(5, 8)
	start = rng.random() * math.tau
	for i in range(count):
		ang = start + i * math.tau / count + rng.normal(0, 0.3)
		length = rng.uniform(0.55, 0.97)
		width = rng.uniform(0.22, 0.42)
		d = np.angle(np.exp(1j * (a - ang)))
		reach = np.maximum(reach, 0.3 + (length - 0.3) * np.exp(-((d / width) ** 2)))
	reach *= 0.8 + 0.4 * streak
	v = np.clip(1 - r / reach, 0, 1) ** 0.75
	v *= 0.55 + 0.6 * streak
	core = np.exp(-((r / 0.17) ** 2))
	v = np.clip(np.maximum(v, core) + core * 0.3, 0, 1)
	alpha = smoothstep(0.02, 0.3, v)
	return rgba(ramp(v, FIRE), alpha)


def flash_side():
	x, y = grid(FRAME)
	u = (y + 1) / 2  # 0 at the bottom edge (the muzzle), 1 at the top
	n = fbm(FRAME, 8, 4)
	# Streaks along the flame: fast across it, slow along it.
	streak = n[(np.clip(u * 0.3, 0, 1) * (FRAME - 1)).astype(int), (((x + 1) / 2 * 2.5) % 1 * (FRAME - 1)).astype(int)]
	length = rng.uniform(0.6, 0.95)
	tip = length * (0.7 + 0.45 * fbm(FRAME, 6, 3))
	t = u / tip
	# Narrow at the muzzle, a bulge where the gas expands, a ragged tongue.
	half = 0.07 + 0.2 * np.exp(-(((t - 0.22) / 0.28) ** 2)) + 0.06 * (1 - np.clip(t, 0, 1))
	xx = x + (n - 0.5) * 0.25 * np.clip(t, 0, 1)
	body = (1 - smoothstep(half * 0.3, half, np.abs(xx))) * (1 - smoothstep(0.7, 1.0, t))
	body *= 0.5 + 0.65 * streak
	body *= 1 - 0.55 * np.clip(t, 0, 1)
	hot = np.exp(-((x / 0.09) ** 2 + ((u - 0.06) / 0.08) ** 2))
	# Small side jets just ahead of the muzzle (gas leaving the brake ports).
	jets = np.zeros_like(x)
	for side in (-1, 1):
		jx = x - side * 0.2
		jets += np.exp(-((jx / 0.15) ** 2 + ((u - 0.1 - np.abs(jx) * 0.25) / 0.035) ** 2)) * 0.55
	v = np.clip(np.maximum(np.maximum(body, hot), jets * (0.6 + 0.5 * streak)), 0, 1)
	alpha = smoothstep(0.03, 0.28, v)
	return rgba(ramp(v, FIRE), alpha)


# Smoke and dust ------------------------------------------------------------------------


def puff(grain, edge_noise, softness):
	x, y = grid(FRAME)
	r = np.hypot(x, y)
	n = fbm(FRAME, 4, 6)
	g = fbm(FRAME, 16, 3)
	radius = 0.62 + (n - 0.5) * edge_noise
	density = 1 - smoothstep(radius - softness, radius, r)
	density *= 0.55 + 0.6 * n
	density = density * (1 - grain) + density * g * grain * 1.6
	# Light from above: the top of the puff is brighter.
	shade = 0.72 + 0.28 * np.clip(y * 0.7 + (n - 0.5) * 0.8 + 0.3, 0, 1)
	rgb = np.repeat((shade * 255)[..., None], 3, axis=-1)
	return rgba(rgb, np.clip(density, 0, 1) ** 1.2)


def smoke():
	return puff(grain=0.0, edge_noise=0.55, softness=0.45)


def dust():
	return puff(grain=0.55, edge_noise=0.8, softness=0.3)


def chip():
	from PIL import ImageDraw

	sides = int(rng.integers(5, 8))
	angles = np.sort(rng.random(sides) * math.tau)
	radii = rng.uniform(0.5, 0.9, sides)
	c = FRAME / 2
	pts = [(c + math.cos(t) * r * c * 0.9, c - math.sin(t) * r * c * 0.9) for t, r in zip(angles, radii)]
	mask = Image.new("L", (FRAME, FRAME), 0)
	ImageDraw.Draw(mask).polygon(pts, fill=255)
	inside = np.asarray(mask, dtype=np.float32) / 255
	x, y = grid(FRAME)
	n = fbm(FRAME, 10, 4)
	# Two facets: lit on the upper left, in shade on the lower right.
	facet = np.where(x * 0.6 - y * 0.8 < rng.uniform(-0.2, 0.2), 0.88, 0.52)
	light = facet + (n - 0.5) * 0.3
	rgb = np.repeat((np.clip(light, 0.2, 1) * 255)[..., None], 3, axis=-1)
	return rgba(rgb, inside)


# Bullet hole -----------------------------------------------------------------------------


def hole():
	size = FRAME
	x, y = grid(size)
	r = np.hypot(x, y)
	a = np.arctan2(y, x)
	n = fbm(size, 8, 5)
	n2 = fbm(size, 20, 3)
	core_r = 0.16 + (n - 0.5) * 0.08
	rim_r = 0.42 + (fbm(size, 5, 4) - 0.5) * 0.22
	core = 1 - smoothstep(core_r - 0.03, core_r + 0.02, r)
	crater = 1 - smoothstep(rim_r - 0.1, rim_r, r)
	# Radial cracks running out of the crater.
	cracks = np.zeros_like(r)
	for _ in range(rng.integers(5, 9)):
		ang = rng.random() * math.tau
		length = rng.uniform(0.48, 0.7)
		d = np.abs(np.angle(np.exp(1j * (a - ang - (n - 0.5) * 0.35))))
		line = np.exp(-((d * r / 0.016) ** 2)) * (r > rim_r * 0.8) * (1 - smoothstep(length - 0.15, length, r))
		cracks = np.maximum(cracks, line)
	soot = np.exp(-((r / 0.7) ** 2)) * (0.5 + 0.5 * n)
	# Value: black core, dark crater walls with light chipped edges, darker soot outside.
	value = 0.62 - 0.25 * soot
	value = np.where(crater > 0, 0.32 + 0.3 * n2, value)
	value = value * (1 - core) + 0.04 * core
	value = value * (1 - cracks * 0.7)
	rgb = np.repeat((np.clip(value, 0, 1) * 255)[..., None], 3, axis=-1)
	alpha = np.maximum(np.maximum(core, crater * 0.95), np.maximum(cracks * 0.9, soot * 0.55))
	alpha *= 1 - smoothstep(0.85, 1.0, r)
	return rgba(rgb, alpha)


# Main --------------------------------------------------------------------------------------


def main():
	ap = argparse.ArgumentParser()
	ap.add_argument("--preview", type=str, default=None)
	args = ap.parse_args()
	OUT.mkdir(parents=True, exist_ok=True)
	images = {
		"flash_front_2x2": sheet([flash_front() for _ in range(4)]),
		"flash_side_2x2": sheet([flash_side() for _ in range(4)]),
		"smoke_2x2": sheet([smoke() for _ in range(4)]),
		"dust_2x2": sheet([dust() for _ in range(4)]),
		"chips_2x2": sheet([chip() for _ in range(4)]),
		"hole": hole(),
	}
	for name, img in images.items():
		path = OUT / f"{name}.png"
		img.save(path)
		print("wrote", path.relative_to(ROOT))
	if args.preview:
		tile = 384
		prev = Image.new("RGBA", (tile * 3, tile * 2), (58, 60, 64, 255))
		for i, img in enumerate(images.values()):
			bg = Image.new("RGBA", (tile, tile), (40, 42, 46, 255) if i < 2 else (120, 122, 126, 255))
			bg.alpha_composite(img.resize((tile, tile)))
			prev.paste(bg, ((i % 3) * tile, (i // 3) * tile))
		prev.save(args.preview)


if __name__ == "__main__":
	main()
