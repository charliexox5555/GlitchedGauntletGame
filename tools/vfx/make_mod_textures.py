"""Textures for the Mod props (numpy + Pillow, no Blender).

    python tools/vfx/make_mod_textures.py [--preview out.png]

Writes art-source/abilities/Textures/FirewallGrid.png: the Firewall panel's grid, white on transparent so the
game tints it per team (Decal.Color3) on top of the see-through Neon panel. 10 x 10 cells with a glowing rim; it
looks the same rotated, since a Decal's orientation on a MeshPart face isn't controllable.
Upload: python tools/opencloud/upload_asset.py --group 11116787 --type Decal <png> "GG Mod FirewallGrid"
"""

import os
import sys

import numpy as np
from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "art-source", "abilities", "Textures")
SIZE = 512
CELLS = 10


def firewall_grid():
	t = (np.arange(SIZE) + 0.5) / SIZE
	u, v = np.meshgrid(t, t)
	# Distance to the nearest grid line, in cell units (0 on a line, 0.5 mid-cell).
	du = np.abs((u * CELLS) - np.round(u * CELLS))
	dv = np.abs((v * CELLS) - np.round(v * CELLS))
	d = np.minimum(du, dv)
	line = np.clip(1 - d / 0.035, 0, 1) ** 1.5 * 0.75 + np.exp(-((d / 0.09) ** 2)) * 0.18
	edge = np.minimum(np.minimum(u, 1 - u), np.minimum(v, 1 - v))
	rim = np.exp(-edge / 0.025) * 0.95 + np.exp(-edge / 0.12) * 0.25
	alpha = np.clip(np.maximum(line, rim), 0, 1)
	rgba = np.zeros((SIZE, SIZE, 4), np.uint8)
	rgba[..., :3] = 255
	rgba[..., 3] = (alpha * 255).astype(np.uint8)
	return Image.fromarray(rgba, "RGBA")


def main():
	os.makedirs(OUT, exist_ok=True)
	img = firewall_grid()
	path = os.path.join(OUT, "FirewallGrid.png")
	img.save(path)
	if "--preview" in sys.argv:
		bg = Image.new("RGBA", img.size, (12, 14, 20, 255))
		tint = Image.new("RGBA", img.size, (0, 229, 255, 255))
		tint.putalpha(img.getchannel("A"))
		bg.alpha_composite(tint)
		bg.convert("RGB").save(sys.argv[sys.argv.index("--preview") + 1])
	print(path)


if __name__ == "__main__":
	main()
