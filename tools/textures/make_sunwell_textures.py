"""Stylized surface textures for the Sunwell Works lobby (owner 2026-11-12: "walls need some texture, nothing too realistic").

    python tools/textures/make_sunwell_textures.py

Painterly, low-contrast, tileable maps: broad soft value shifts, overlapping brush dabs and a little grain. Colour maps
are near white so the part colour tints them (one map serves every wall colour). Writes
art-source/lobby/textures/SW_<Name>_color.png / _normal.png / _roughness.png / _preview.png (1024 px, seamless).

    SW_Plaster  walls, cast frames, ceilings   broad dabs, soft mottling            16 studs per tile
    SW_Floor    floors                          trowel sweeps, faint scuffs          20 studs per tile
    SW_Steel    painted structural steel        long horizontal strokes, fine grain  10 studs per tile

Upload each map with tools/opencloud/upload_asset.py --type Decal; tools/studio/sunwell_p1/upload_data.py packs the ids
and Build_SW1.materials() makes the MaterialVariants. Kept deliberately faint and matte: the owner found a PBR texture
pack "too realistic" (2026-11-12); these only break up flat colour.
"""
import os

import numpy as np
from PIL import Image

N = 1024
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "art-source", "lobby", "textures")


def fft_noise(rng, falloff, aniso=(1.0, 1.0)):
	"""Periodic noise: white noise filtered in frequency space. falloff = how fast high frequencies die; aniso stretches it."""
	f = np.fft.fft2(rng.standard_normal((N, N)))
	ky = np.fft.fftfreq(N)[:, None] * N * aniso[1]
	kx = np.fft.fftfreq(N)[None, :] * N * aniso[0]
	k = np.sqrt(kx * kx + ky * ky)
	k[0, 0] = 1.0
	out = np.real(np.fft.ifft2(f / k ** falloff))
	out -= out.mean()
	return out / (np.abs(out).max() + 1e-9)


def dabs(rng, count, wmin, wmax, hmin, hmax, tilt, amp):
	"""Overlapping soft-edged brush dabs, wrapped round the tile edges."""
	img = np.zeros((N, N), np.float32)
	yy, xx = np.mgrid[0:N, 0:N].astype(np.float32)
	for _ in range(count):
		cx, cy = rng.uniform(0, N, 2)
		w, h = rng.uniform(wmin, wmax), rng.uniform(hmin, hmax)
		a = rng.normal(0, tilt)
		dx = (xx - cx + N / 2) % N - N / 2
		dy = (yy - cy + N / 2) % N - N / 2
		u = dx * np.cos(a) + dy * np.sin(a)
		v = -dx * np.sin(a) + dy * np.cos(a)
		m = np.clip(1.2 - np.maximum(np.abs(u) / w, np.abs(v) / h), 0, 1)
		m = m * m * (3 - 2 * m)
		img += m * rng.normal(0, amp)
	return img


def normal_map(height, strength):
	gx = (np.roll(height, -1, 1) - np.roll(height, 1, 1)) * strength
	gy = (np.roll(height, -1, 0) - np.roll(height, 1, 0)) * strength
	nz = np.ones_like(height)
	ln = np.sqrt(gx * gx + gy * gy + nz * nz)
	n = np.stack([-gx / ln, gy / ln, nz / ln], -1)
	return ((n * 0.5 + 0.5) * 255).clip(0, 255).astype(np.uint8)


def save(name, value, height, rough, tint):
	"""value is centred on 0; the colour map is a near-white tinted grey so Part.Color sets the hue."""
	v = 0.9 + value
	col = np.stack([v * tint[0], v * tint[1], v * tint[2]], -1)
	os.makedirs(OUT, exist_ok=True)
	Image.fromarray((col.clip(0, 1) * 255).astype(np.uint8)).save(os.path.join(OUT, f"{name}_color.png"))
	Image.fromarray(normal_map(height, 1.0)).save(os.path.join(OUT, f"{name}_normal.png"))
	Image.fromarray((rough.clip(0, 1) * 255).astype(np.uint8)).save(os.path.join(OUT, f"{name}_roughness.png"))
	prev = np.tile((col.clip(0, 1) * 255).astype(np.uint8), (2, 2, 1))[::4, ::4]
	Image.fromarray(prev).save(os.path.join(OUT, f"{name}_preview.png"))
	return float(value.min()), float(value.max())


def plaster():
	rng = np.random.default_rng(11)
	broad = fft_noise(rng, 2.6) * 0.02
	strokes = dabs(rng, 260, 50, 150, 14, 40, 0.5, 0.009)
	grain = fft_noise(rng, 0.9) * 0.004
	v = broad + strokes + grain
	h = strokes * 9 + broad * 4 + grain * 2
	rough = 0.9 + strokes * 0.6 + broad * 0.5
	return save("SW_Plaster", v, h * 0.7, rough, (1.0, 0.985, 0.96))


def floor():
	rng = np.random.default_rng(23)
	broad = fft_noise(rng, 2.5) * 0.026
	sweeps = dabs(rng, 220, 110, 300, 20, 55, 0.5, 0.008)
	scuff = np.clip(fft_noise(rng, 1.6, (0.25, 1.0)), 0.6, 1.0) - 0.6
	grain = fft_noise(rng, 0.7) * 0.004
	v = broad + sweeps - scuff * 0.02 + grain
	h = sweeps * 5 + broad * 3 + grain * 2
	rough = 0.8 + sweeps * 1.0 + broad * 0.8
	return save("SW_Floor", v, h * 0.5, rough, (1.0, 0.99, 0.975))


def steel():
	rng = np.random.default_rng(37)
	broad = fft_noise(rng, 2.5) * 0.016
	strokes = dabs(rng, 220, 160, 420, 6, 16, 0.04, 0.008)
	grain = fft_noise(rng, 0.8, (0.2, 1.0)) * 0.005
	v = broad + strokes + grain
	h = strokes * 6 + grain * 3
	rough = 0.72 + strokes * 1.0 + broad * 0.5
	return save("SW_Steel", v, h * 0.5, rough, (0.985, 0.99, 1.0))


if __name__ == "__main__":
	for fn in (plaster, floor, steel):
		print(fn.__name__, "value range", fn())
