"""Map MaterialVariant textures cut from an approved concept trim sheet.

    python tools/textures/make_map_variants.py Rooftops2 [--preview]

Reads art-source/maps/<Map>/concepts/06-material-trim-sheet.png (near-white, tintable rows made from the
concept prompts) and writes, per row listed in ROWS, art-source/maps/<Map>/textures/<Variant>_Color.png
and <Variant>_Normal.png at 512 x 512:
  * the row is cropped inside its gutters, made horizontally seamless (cross-fade of the two ends),
    then repeated vertically to a square, so it tiles both ways as a MaterialVariant;
  * Color keeps the painted shading (baked cavity / edge wear, as LihFolk "Baking Lighting and Detail into
    Textures" asks) normalised to a mean of ~0.86, so BasePart.Color tints it and the role colours still read;
  * Normal is derived from the luminance (blurred height, Sobel), OpenGL convention (+Y up), as Roblox expects.
--preview also writes <Map>_variants_preview.png (all rows side by side) for the vault note.

Phone budget (vault/01 Design/Maps/<Map>.md -> Texture plan): 6 variants x 2 maps x 512.
"""

from __future__ import annotations

import os
import sys

import numpy as np
from PIL import Image, ImageFilter

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
N = 512

# Variant name: (y0, y1[, repeats]) of the row in the 1254 x 1254 sheet (measured from the gutters), repeats down the tile.
ROWS = {
	"Rooftops2": {
		"Roof2_Plaster": (16, 90, 2),  # a plain panel, inside its chipped edges: stretched, 2 per tile (no banding)
		"Roof2_Brick": (110, 214),
		"Roof2_Terracotta": (224, 318),
		"Roof2_Slate": (330, 435),
		"Roof2_Gravel": (448, 529, 3),
		"Roof2_Plank": (971, 1059),
	},
	"Dockyard2": {
		"Dock2_Corrugated": (209, 357, 1),  # stretched once: continuous vertical ribs, no seams
		"Dock2_Cladding": (373, 508),
		"Dock2_Grate": (524, 648),
		"Dock2_Plank": (664, 798),
		"Dock2_Concrete": (814, 904, 2),  # slab joints every half tile
		"Dock2_Plate": (1044, 1139, 2),
	},
}
X_MARGIN = 10  # the sheet's outer border
# Calmer rows (contrast of the shading, normal strength): plaster read as big creases at 12 studs a tile in Studio.
CALM = {"Roof2_Plaster": (0.45, 2.0)}


def seamless_x(a: np.ndarray, blend: int = 48) -> np.ndarray:
	"""Cross-fade the right end into the left so the strip wraps horizontally."""
	w = a.shape[1]
	core = a[:, : w - blend].copy()
	t = np.linspace(0.0, 1.0, blend)[None, :, None] if a.ndim == 3 else np.linspace(0.0, 1.0, blend)[None, :]
	core[:, :blend] = a[:, w - blend :] * (1 - t) + a[:, :blend] * t
	return core


def make(map_name: str, name: str, y0: int, y1: int, sheet: Image.Image, out: str, reps: int | None = None) -> Image.Image:
	row = np.asarray(sheet.crop((X_MARGIN, y0, sheet.width - X_MARGIN, y1)).convert("RGB"), float) / 255.0
	row = seamless_x(row)
	h, w = row.shape[:2]
	# Scale the row to the tile width, then repeat it down until the tile is square.
	if reps is None:
		rh = max(1, round(h * N / w))
		reps = max(1, round(N / rh))
	rh = N // reps
	strip = Image.fromarray((row * 255).astype(np.uint8)).resize((N, rh), Image.LANCZOS)
	tile = Image.new("RGB", (N, N))
	for i in range(reps):
		tile.paste(strip, (0, i * rh))
	if reps * rh < N:  # rounding remainder: stretch the last copy
		tile.paste(strip.resize((N, N - (reps - 1) * rh)), (0, (reps - 1) * rh))
	lum = np.asarray(tile.convert("L"), float) / 255.0
	# Colour: grey shading only (tinted in Studio), mean ~0.86, floor 0.45 so tints never go muddy.
	k, strength = CALM.get(name, (0.9, 6.0))
	c = lum / max(lum.mean(), 1e-3) * 0.86
	c = np.clip(0.86 + (c - 0.86) * k, 0.45, 1.0)
	Image.fromarray((np.repeat(c[..., None], 3, 2) * 255).astype(np.uint8)).save(os.path.join(out, f"{name}_Color.png"))
	# Normal: blurred luminance as height, wrapped Sobel.
	hgt = np.asarray(tile.convert("L").filter(ImageFilter.GaussianBlur(1.2)), float) / 255.0
	dx = (np.roll(hgt, -1, 1) - np.roll(hgt, 1, 1)) * 0.5
	dy = (np.roll(hgt, -1, 0) - np.roll(hgt, 1, 0)) * 0.5
	nx, ny, nz = -dx * strength, dy * strength, np.ones_like(hgt)
	ln = np.sqrt(nx * nx + ny * ny + nz * nz)
	nrm = np.stack([nx / ln, ny / ln, nz / ln], -1) * 0.5 + 0.5
	Image.fromarray((nrm * 255).astype(np.uint8)).save(os.path.join(out, f"{name}_Normal.png"))
	return tile


def main() -> None:
	map_name = sys.argv[1]
	sheet = Image.open(os.path.join(ROOT, "art-source", "maps", map_name, "concepts", "06-material-trim-sheet.png"))
	out = os.path.join(ROOT, "art-source", "maps", map_name, "textures")
	os.makedirs(out, exist_ok=True)
	tiles = [(n, make(map_name, n, r[0], r[1], sheet, out, *r[2:])) for n, r in ROWS[map_name].items()]
	if "--preview" in sys.argv:
		prev = Image.new("RGB", (len(tiles) * 260, 280), (40, 40, 40))
		for i, (n, t) in enumerate(tiles):
			c = Image.open(os.path.join(out, f"{n}_Color.png")).resize((256, 256))
			prev.paste(c, (i * 260 + 2, 2))
		prev.save(os.path.join(out, f"{map_name}_variants_preview.png"))
	print("wrote", len(tiles), "variants to", out)


if __name__ == "__main__":
	main()
