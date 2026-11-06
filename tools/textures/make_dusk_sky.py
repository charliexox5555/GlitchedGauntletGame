#!/usr/bin/env python3
"""Rooftops2 dusk skybox (maps v5): six seamless cube faces, a lilac zenith over a peach horizon with soft pink
cloud bands, sampled from the concept board (art-source/maps/Rooftops2/concepts/01-overview.png, 02-hero-pit.png).

Every pixel's colour comes from its view direction (elevation, azimuth), so the faces meet without seams. Clouds
are periodic noise in azimuth, stretched flat near the horizon. Roblox Sky face names: Bk = +Z, Ft = -Z,
Rt = -X, Lf = +X, Up, Dn (checked in Studio: the
other way round left a seam). Clouds stay below 32 degrees, so the Up and Dn faces are pure gradient and their
rotation can't show a seam.

Run: python tools/textures/make_dusk_sky.py   -> art-source/maps/Rooftops2/sky/Sky_<Face>.png (1024)
"""

from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "art-source" / "maps" / "Rooftops2" / "sky"
N = 1024

# elevation (degrees) -> colour, from the concept
STOPS = [
	(-90, (214, 170, 160)),
	(0, (250, 198, 170)),  # peach horizon
	(6, (246, 190, 178)),
	(16, (226, 178, 196)),  # pink
	(34, (190, 168, 214)),  # lilac
	(60, (150, 146, 206)),
	(90, (128, 128, 196)),  # zenith blue-violet
]
CLOUD_LIT = np.array((255, 222, 206), float)
CLOUD_SHADE = np.array((206, 168, 196), float)


def gradient(el):
	xs = [s[0] for s in STOPS]
	out = np.zeros(el.shape + (3,))
	for c in range(3):
		out[..., c] = np.interp(el, xs, [s[1][c] for s in STOPS])
	return out


def periodic_noise(az, el, seed):
	"""Sum of sines periodic in azimuth (radians), smooth in elevation."""
	rng = np.random.default_rng(seed)
	n = np.zeros_like(az)
	amp = 1.0
	for octave in range(5):
		k = 2 ** octave + 1  # 2, 3, 5, 9, 17: no half-turn repeat
		for _ in range(3):
			ph, fe, pe = rng.uniform(0, 2 * np.pi), rng.uniform(4, 9) * (octave + 1), rng.uniform(0, 2 * np.pi)
			n += amp * np.sin(k * az + ph + 0.8 * np.sin(fe * el + pe))
		amp *= 0.55
	return n / 4.0


def face_dirs(face):
	t = (np.arange(N) + 0.5) / N * 2 - 1
	u, v = np.meshgrid(t, -t)  # u right, v up in the image
	one = np.ones_like(u)
	# Roblox: +Y up; faces seen from inside the cube
	if face == "Bk":
		d = (-u, v, one)  # +Z
	elif face == "Ft":
		d = (u, v, -one)  # -Z
	elif face == "Lf":
		d = (one, v, u)  # +X
	elif face == "Rt":
		d = (-one, v, -u)  # -X
	elif face == "Up":
		d = (u, one, v)
	else:
		d = (u, -one, -v)
	x, y, z = d
	r = np.sqrt(x * x + y * y + z * z)
	return x / r, y / r, z / r


def render(face):
	x, y, z = face_dirs(face)
	el = np.degrees(np.arcsin(np.clip(y, -1, 1)))
	az = np.arctan2(z, x)
	col = gradient(el)
	# cloud band 3-30 degrees, flattened toward the horizon
	e = np.radians(np.clip(el, 0, 90))
	flat = np.log1p(e * 3.0)
	n = periodic_noise(az, flat, 7) + 0.6 * periodic_noise(az * 1.0, flat * 2.3, 11)
	band = np.clip((el - 2.5) / 5.0, 0, 1) * np.clip((32 - el) / 12.0, 0, 1)
	cover = np.clip((n + 0.02) * 1.5, 0, 1) * band
	lit = np.clip(0.5 + 0.5 * periodic_noise(az, flat * 3.1, 23), 0, 1)
	cloud = CLOUD_SHADE + (CLOUD_LIT - CLOUD_SHADE) * lit[..., None]
	col = col * (1 - cover[..., None] * 0.85) + cloud * (cover[..., None] * 0.85)
	return Image.fromarray(np.clip(col, 0, 255).astype(np.uint8))


def main():
	OUT.mkdir(parents=True, exist_ok=True)
	for f in ("Bk", "Ft", "Lf", "Rt", "Up", "Dn"):
		render(f).save(OUT / f"Sky_{f}.png")
	print("wrote", OUT)


if __name__ == "__main__":
	main()
