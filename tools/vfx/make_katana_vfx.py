"""Tempest-Strike Katana VFX textures (2026-11-22, owner: the katana's effects
"could be better"; the lightsaber look along the whole blade).

    python tools/vfx/make_katana_vfx.py

Writes art-source/vfx/tempest/raw/glow_band.png: a white band, even along U
(tiles seamlessly left to right), a soft falloff across V with a hot thin core
in the middle. Tinted in game (Util/TempestKatana): the glowing sheath laid
over the edge (Beams), and the swing arcs (Trails; symmetric across V, so it
reads the same whichever attachment is which). Stylised, not photoreal (gun
VFX rule: Valorant-like).
"""

import os

import numpy as np
from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "art-source", "vfx", "tempest", "raw")

W, H = 256, 128


def glow_band():
	v = (np.arange(H) + 0.5) / H * 2 - 1  # -1 .. 1 across the band
	soft = np.exp(-((v / 0.42) ** 2))  # the glow
	core = np.exp(-((v / 0.07) ** 2))  # the hot line
	alpha = np.clip(0.62 * soft + 0.75 * core, 0, 1)
	alpha *= np.clip((1 - np.abs(v)) / 0.08, 0, 1)  # clean edges, no hard cut
	rgb = np.ones((H, W, 3))
	a = np.repeat(alpha[:, None], W, axis=1)
	img = np.dstack([rgb, a[..., None]])
	return Image.fromarray((img * 255).round().astype(np.uint8), "RGBA")


def main():
	os.makedirs(OUT, exist_ok=True)
	path = os.path.join(OUT, "glow_band.png")
	glow_band().save(path)
	print("wrote", path)


if __name__ == "__main__":
	main()
