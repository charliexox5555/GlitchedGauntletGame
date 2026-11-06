"""OldTown2 textures: six tintable MaterialVariants (vault/01 Design/Maps/OldTown2.md).

    python tools/textures/make_oldtown2_textures.py [--preview]

Writes art-source/maps/OldTown2/textures/<Variant>_Color.png and _Normal.png, 512 x 512, seamless:
  OT2_Stucco      lime render with soft trowel clouds and a few worn patches showing stone (StudsPerTile 12)
  OT2_Ashlar      dressed limestone blocks in courses, chiselled margins (StudsPerTile 8)
  OT2_Terracotta  barrel roof tiles in rows (StudsPerTile 6)
  OT2_Cobble      setts in rows, darker joints (StudsPerTile 8)
  OT2_Paving      large square plaza flags with joints (StudsPerTile 8)
  OT2_Plank       weathered boards (StudsPerTile 6)
Near-white colour maps (mean about 0.86) so BasePart.Color tints them by role; cavity and wear baked in; normals from
height (OpenGL). Procedural, after the concept's swatches (art-source/maps/OldTown2/concepts/03-kit-sheet.png):
a call noted in the map note.
"""

from __future__ import annotations

import os
import sys

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from make_metro2_textures import N, normal_from_height, smoothstep, wrap_noise, blur_wrap  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "art-source", "maps", "OldTown2", "textures")
RNG = np.random.default_rng(1500)


def save(name, c, h, strength, mean=0.86):
	c = np.clip(c, 0, None)
	c = c * (mean / max(c.mean(), 1e-6))
	c = np.clip(c, 0, 1)
	Image.fromarray((np.stack([c, c, c], -1) * 255).astype(np.uint8)).save(os.path.join(OUT, name + "_Color.png"))
	Image.fromarray(normal_from_height(h, strength)).save(os.path.join(OUT, name + "_Normal.png"))
	print("variant", name)


def cells(rows, cols_fn, mortar, jitter=0.0, seed=0):
	"""Running-bond blocks: rows of height N/rows, each row split by cols_fn(row) widths; returns
	(edge distance, block id) arrays."""
	rng = np.random.default_rng(seed)
	y, x = np.mgrid[0:N, 0:N].astype(np.float64)
	rh = N / rows
	row = (y // rh).astype(int)
	ly = y - row * rh
	d = np.zeros((N, N))
	bid = np.zeros((N, N), int)
	for r in range(rows):
		widths = cols_fn(r, rng)
		edges = np.cumsum([0] + widths)
		edges = edges * N / edges[-1]
		off = rng.uniform(0, N)
		m = row == r
		xs = (x[m] + off) % N
		k = np.searchsorted(edges, xs, side="right") - 1
		lx = xs - edges[k]
		w = np.diff(edges)[k]
		d[m] = np.minimum.reduce([lx, w - lx, ly[m], rh - ly[m]])
		bid[m] = r * 100 + k
	return d, bid


def stucco():
	cloud = wrap_noise(N, 3, 5, 11)
	trowel = wrap_noise(N, 14, 3, 12)
	worn = 0.0 * smoothstep(0.7, 0.75, wrap_noise(N, 6, 4, 13))  # r1: no worn patches (they read as camo blotches)
	c = 0.9 + 0.05 * (cloud - 0.5) + 0.04 * (trowel - 0.5)
	# worn patches: the stone under the render shows through, a little darker with an edge
	edge = 0.0 * smoothstep(0.66, 0.7, wrap_noise(N, 6, 4, 13))
	c = c - 0.1 * worn - 0.08 * edge
	h = 0.4 * trowel - 0.5 * worn
	save("OT2_Stucco", c, blur_wrap(h, 1.0), 2.5)


def ashlar():
	d, bid = cells(4, lambda r, g: list(g.uniform(1.2, 2.2, 3)), 3, seed=14)
	tone = RNG.uniform(0.92, 1.06, 1000)[bid % 1000]
	mortar = d < 2.5
	margin = smoothstep(2.5, 10, d)
	grain = wrap_noise(N, 40, 3, 15)
	c = np.where(mortar, 0.66, tone * (0.86 + 0.1 * margin) * (0.95 + 0.1 * grain))
	h = np.where(mortar, 0.0, 0.6 + 0.4 * margin) + 0.08 * grain
	save("OT2_Ashlar", c, blur_wrap(h, 0.8), 4.0)


def terracotta():
	# barrel tiles: columns of round ridges, rows with an overlap shadow
	y, x = np.mgrid[0:N, 0:N].astype(np.float64)
	cols, rows = 8, 6
	u = (x / (N / cols)) % 1.0
	row = (y // (N / rows)).astype(int)
	v = (y / (N / rows)) % 1.0
	ridge = np.sin(u * np.pi) ** 0.8
	overlap = smoothstep(0.75, 1.0, v)
	tone = RNG.uniform(0.9, 1.08, (rows, cols))[row % rows, (x // (N / cols)).astype(int) % cols]
	c = tone * (0.72 + 0.28 * ridge) * (1 - 0.35 * overlap) * (0.95 + 0.1 * wrap_noise(N, 24, 3, 16))
	h = ridge * (0.5 + 0.5 * v) - 0.4 * overlap
	save("OT2_Terracotta", c, blur_wrap(h, 0.8), 6.0)


def cobble():
	d, bid = cells(10, lambda r, g: list(g.uniform(0.8, 1.25, 9)), 3, seed=17)
	tone = RNG.uniform(0.78, 1.1, 2000)[bid % 2000]
	dome = smoothstep(1.0, 11, d) ** 0.6
	c = tone * (0.4 + 0.6 * dome) * (0.95 + 0.1 * wrap_noise(N, 48, 2, 18))
	save("OT2_Cobble", c, dome, 5.0)


def paving():
	d, bid = cells(2, lambda r, g: [1.0, 1.0] if r % 2 == 0 else [1.0, 1.0], 2, seed=19)
	tone = RNG.uniform(0.94, 1.05, 1000)[bid % 1000]
	joint = d < 2
	grain = wrap_noise(N, 20, 4, 20)
	chip = smoothstep(0.7, 0.75, wrap_noise(N, 30, 2, 21))
	c = np.where(joint, 0.62, tone * (0.9 + 0.08 * (grain - 0.5)) - 0.06 * chip)
	h = np.where(joint, 0.0, 1.0) + 0.1 * grain
	save("OT2_Paving", c, blur_wrap(h, 0.7), 3.0)


def plank():
	y, x = np.mgrid[0:N, 0:N].astype(np.float64)
	rows = 6
	row = (y // (N / rows)).astype(int)
	v = (y / (N / rows)) % 1.0
	gap = (v < 0.04) | (v > 0.96)
	streak = wrap_noise(N, 4, 4, 22)
	fib = np.repeat(RNG.random((N, 1)), N, axis=1)
	tone = RNG.uniform(0.85, 1.08, rows)[row]
	c = np.where(gap, 0.45, tone * (0.88 + 0.1 * (streak - 0.5) + 0.06 * (blur_wrap(fib, 0.5) - 0.5)))
	h = np.where(gap, 0.0, 1.0) + 0.1 * fib
	save("OT2_Plank", c, blur_wrap(h, 0.6), 3.0)


def main():
	os.makedirs(OUT, exist_ok=True)
	stucco()
	ashlar()
	terracotta()
	cobble()
	paving()
	plank()
	if "--preview" in sys.argv:
		names = sorted(f for f in os.listdir(OUT) if f.endswith("_Color.png"))
		sheet = Image.new("RGB", (256 * len(names), 512))
		for i, n in enumerate(names):
			sheet.paste(Image.open(os.path.join(OUT, n)).convert("RGB").resize((256, 256)), (i * 256, 0))
			sheet.paste(Image.open(os.path.join(OUT, n.replace("_Color", "_Normal"))).convert("RGB").resize((256, 256)), (i * 256, 256))
		sheet.save(os.path.join(OUT, "OldTown2_textures_preview.png"))


if __name__ == "__main__":
	main()
