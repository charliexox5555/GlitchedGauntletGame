"""Lobby ambience particle sprites (phase 1, step 6), plain numpy + Pillow.

    python tools/vfx/make_lobby_vfx.py            # writes the PNGs + a preview sheet
    python tools/opencloud/upload_asset.py --group 11116787 --type Decal \
        art-source/lobby/vfx/lobby_dust.png "GG Lobby VFX Dust"
    python tools/opencloud/upload_asset.py --group 11116787 --type Decal \
        art-source/lobby/vfx/lobby_wisp.png "GG Lobby VFX Wisp"

Both sprites are WHITE on a straight-alpha transparent film; the ParticleEmitter
colours them (warm sun for the dust, cool grey for the cave wisps).

  lobby_dust.png   64x64    one soft dust mote: a small bright core in a wide
                            gaussian halo, so a 0.1-0.2 stud particle reads as a
                            lit speck, not a hard dot.
  lobby_wisp.png   256x256  a soft steam / dust wisp: tileable fbm noise, eroded
                            and stretched sideways, inside a feathered round
                            mask, so a rotated, slowly growing particle reads as
                            a drifting curl of haze with no visible edge.

Seeds are fixed, so re-running gives the same images.
"""

from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "art-source" / "lobby" / "vfx"
PREVIEW = ROOT / "vault" / "02 Art" / "References" / "lobby" / "art" / "ambience-00-sprites.jpg"


def save_rgba(alpha: np.ndarray, path: Path) -> None:
	a = np.clip(alpha, 0.0, 1.0)
	h, w = a.shape
	rgba = np.zeros((h, w, 4), dtype=np.uint8)
	rgba[..., :3] = 255
	rgba[..., 3] = np.round(a * 255).astype(np.uint8)
	Image.fromarray(rgba, "RGBA").save(path)


def grid(n: int) -> tuple[np.ndarray, np.ndarray]:
	"""Pixel-centre coordinates in -1..1."""
	c = (np.arange(n) + 0.5) / n * 2.0 - 1.0
	return np.meshgrid(c, c)


def dust(n: int = 64) -> np.ndarray:
	x, y = grid(n)
	r2 = x * x + y * y
	core = np.exp(-r2 / (2 * 0.12**2))
	halo = np.exp(-r2 / (2 * 0.34**2)) * 0.45
	a = core + halo
	# Feather to exactly zero at the edge so no square shows.
	edge = np.clip((1.0 - np.sqrt(r2)) / 0.25, 0.0, 1.0)
	return a / a.max() * edge


def value_noise(n: int, cells: int, rng: np.random.Generator) -> np.ndarray:
	"""Tileable smooth value noise, n x n, with `cells` lattice cells per side."""
	lat = rng.random((cells, cells))
	c = np.arange(n) / n * cells
	i0 = np.floor(c).astype(int)
	f = c - i0
	f = f * f * (3 - 2 * f)
	i1 = (i0 + 1) % cells
	i0 = i0 % cells
	fy, fx = np.meshgrid(f, f, indexing="ij")
	y0, x0 = np.meshgrid(i0, i0, indexing="ij")
	y1, x1 = np.meshgrid(i1, i1, indexing="ij")
	a = lat[y0, x0] * (1 - fx) + lat[y0, x1] * fx
	b = lat[y1, x0] * (1 - fx) + lat[y1, x1] * fx
	return a * (1 - fy) + b * fy


def fbm(n: int, rng: np.random.Generator, octaves: int = 5, base: int = 4) -> np.ndarray:
	total = np.zeros((n, n))
	amp, norm = 1.0, 0.0
	for o in range(octaves):
		total += value_noise(n, base * 2**o, rng) * amp
		norm += amp
		amp *= 0.5
	return total / norm


def wisp(n: int = 256) -> np.ndarray:
	rng = np.random.default_rng(29)
	x, y = grid(n)
	# Low-frequency noise only (no grain), domain-warped sideways so the haze curls.
	warp = fbm(n, rng, octaves=2, base=2)
	noise = fbm(n, rng, octaves=3, base=3)
	shift = ((warp - 0.5) * n * 0.25).astype(int)
	cols = (np.arange(n)[None, :] + shift) % n
	noise = noise[np.arange(n)[:, None], cols]
	noise = (noise - noise.min()) / (noise.max() - noise.min())
	# A wide gaussian body (wider than tall) that the noise breaks into soft lobes;
	# the falloff reaches zero well inside the frame, so no edge ever shows.
	r2 = (x / 0.62) ** 2 + (y / 0.42) ** 2
	body = np.exp(-r2 * 1.6)
	a = body * np.clip((noise - 0.12) / 0.75, 0.0, 1.0) ** 1.1
	a *= np.clip((1.0 - np.sqrt(x * x + y * y)) / 0.2, 0.0, 1.0)
	return np.clip(a / np.percentile(a, 99.8), 0.0, 1.0) * 0.8


def main() -> None:
	OUT.mkdir(parents=True, exist_ok=True)
	d = dust()
	w = wisp()
	save_rgba(d, OUT / "lobby_dust.png")
	save_rgba(w, OUT / "lobby_wisp.png")
	# Preview: both sprites over a dark and a warm panel.
	sheet = Image.new("RGB", (1024, 512), (20, 21, 24))
	warm = Image.new("RGB", (512, 512), (120, 96, 66))
	sheet.paste(warm, (512, 0))
	dimg = Image.open(OUT / "lobby_dust.png").resize((256, 256), Image.LANCZOS)
	wimg = Image.open(OUT / "lobby_wisp.png").resize((256, 256), Image.LANCZOS)
	for ox in (0, 512):
		sheet.paste(dimg, (ox + 0, 128), dimg)
		sheet.paste(wimg, (ox + 256, 128), wimg)
	PREVIEW.parent.mkdir(parents=True, exist_ok=True)
	sheet.save(PREVIEW, quality=90)
	print("wrote", OUT / "lobby_dust.png", OUT / "lobby_wisp.png", PREVIEW)


if __name__ == "__main__":
	main()
