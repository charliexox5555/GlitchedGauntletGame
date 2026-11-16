"""Shot VFX textures, feel pass 2 (2026-11-10): tracers and muzzle flashes.

    python tools/vfx/make_shot_vfx.py

Writes game-ready, straight-alpha PNGs to art-source/vfx/shot/:

  tracer.png         the round's streak, u: tail (left) -> head (right): a long
                     tapering tail that brightens into a hot, rounded head
  tracer_wake.png    the faint line of disturbed air a round leaves (u along
                     it): thin, broken up by noise so it reads as vapour
  flash_front_2x2    muzzle flash seen down the barrel   } from the image-model
  flash_side_2x2     side flame, base at the bottom edge } sheets in src/ (see
  impact_2x2         bullet impact spark burst           } below)

The three 2x2 flipbooks come from generated sheets on pure black in
art-source/vfx/shot/src/ (flash_front.png, flash_side.png, impact_sparks.png;
Codex / ChatGPT image generation, brief in vault/05 Production/Playtests/
2026-11-10 Gunplay Feel Pass 2.md). Each quadrant becomes one frame:
brightness -> alpha with the colour divided back out (the emitters are
additive, so colour x alpha gives the original pixel), the black floor cut,
the flame recentred (front, impact: on its bright centre; side: its base on
the bottom edge) and the frame's edges faded so no quad edge can show.
Missing sources are skipped.

Then upload with tools/opencloud/upload_asset.py (--type Decal) and put the
Image ids in Config/VfxTextures.
"""

from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "art-source" / "vfx" / "shot"
SRC = OUT / "src"
FRAME = 512  # per flipbook frame (sheet 1024)

rng = np.random.default_rng(20261110)


def save(name, rgba):
	OUT.mkdir(parents=True, exist_ok=True)
	arr = (np.clip(rgba, 0, 1) * 255 + 0.5).astype(np.uint8)
	Image.fromarray(arr, "RGBA").save(OUT / name)
	print("wrote", (OUT / name).relative_to(ROOT))


def smooth_noise(width, cells):
	"""1D smooth noise in 0..1, `cells` bumps across `width`."""
	pts = rng.random(cells + 3)
	x = np.linspace(1, cells + 1, width)
	i = np.floor(x).astype(int)
	f = x - i
	f = f * f * (3 - 2 * f)
	return pts[i] * (1 - f) + pts[i + 1] * f


# Tracer -----------------------------------------------------------------------


def tracer():
	w, h = 512, 64
	u = np.linspace(0, 1, w)[None, :]
	v = np.linspace(-1, 1, h)[:, None]
	# Brightness along the streak: a long ease-in tail, a hot head at 0.9,
	# rounded off to nothing by the very tip.
	tail = u**2.2
	head = np.exp(-(((u - 0.9) / 0.07) ** 2))
	tip = np.clip((1 - u) / 0.06, 0, 1) ** 0.6
	along = np.clip(0.55 * tail + 0.9 * head, 0, 1) * tip
	# Cross-section: a tight core that widens toward the head.
	half = 0.16 + 0.5 * u**1.5 + 0.25 * head
	across = np.exp(-((v / half) ** 2) * 2.2)
	a = along * across
	rgba = np.ones((h, w, 4), np.float32)
	rgba[..., 3] = a
	save("tracer.png", rgba)


def tracer_wake():
	w, h = 512, 32
	u = np.linspace(0, 1, w)[None, :]
	v = np.linspace(-1, 1, h)[:, None]
	# Broken along its length (vapour, not a laser), fading in from the muzzle
	# and out toward the far end.
	breaks = 0.55 + 0.45 * smooth_noise(w, 22)[None, :]
	fine = 0.8 + 0.2 * smooth_noise(w, 90)[None, :]
	ends = np.clip(u / 0.08, 0, 1) * np.clip((1 - u) / 0.25, 0, 1) ** 0.7
	wobble = (smooth_noise(w, 14)[None, :] - 0.5) * 0.35
	across = np.exp(-(((v - wobble) / 0.42) ** 2) * 2.0)
	a = breaks * fine * ends * across
	rgba = np.ones((h, w, 4), np.float32)
	rgba[..., 3] = a
	save("tracer_wake.png", rgba)


# Flipbooks from generated sheets ----------------------------------------------

FLOOR = 0.035  # brightness treated as black (image models never give exact 0)


def edge_fade(size, margin):
	"""1 in the middle, easing to 0 over `margin` (share of the frame) at each edge."""
	x = np.linspace(0, 1, size)
	ramp = np.clip(np.minimum(x, 1 - x) / margin, 0, 1)
	ramp = ramp * ramp * (3 - 2 * ramp)
	return ramp[None, :] * ramp[:, None]


def to_additive(rgb):
	"""Straight-alpha RGBA whose colour x alpha is `rgb` (0..1), black floor cut."""
	lum = rgb.max(axis=2)
	a = np.clip((lum - FLOOR) / (1 - FLOOR), 0, 1)
	color = rgb / np.maximum(lum, 1e-4)[..., None]
	return np.dstack([np.clip(color, 0, 1), a])


def shift(img, dx, dy):
	"""Moves `img` by whole pixels, filling with zeros."""
	out = np.zeros_like(img)
	h, w = img.shape[:2]
	x0, x1 = max(dx, 0), min(w + dx, w)
	y0, y1 = max(dy, 0), min(h + dy, h)
	out[y0:y1, x0:x1] = img[y0 - dy : y1 - dy, x0 - dx : x1 - dx]
	return out


def frames(path):
	im = Image.open(path).convert("RGB")
	side = min(im.size)
	im = im.crop((0, 0, side, side)).resize((FRAME * 2, FRAME * 2), Image.LANCZOS)
	arr = np.asarray(im, np.float32) / 255
	return [
		arr[y : y + FRAME, x : x + FRAME] for y in (0, FRAME) for x in (0, FRAME)
	]


def centred(frame):
	"""The frame moved so its bright centre (weighted by brightness^3) is in the middle."""
	rgba = to_additive(frame)
	w = rgba[..., 3] ** 3
	total = w.sum()
	if total < 1e-6:
		return rgba
	ys, xs = np.mgrid[0:FRAME, 0:FRAME]
	cx, cy = (w * xs).sum() / total, (w * ys).sum() / total
	return shift(rgba, int(round(FRAME / 2 - cx)), int(round(FRAME / 2 - cy)))


def based(frame):
	"""The frame moved so the flame's base (its lowest bright rows) sits bottom-centre."""
	rgba = to_additive(frame)
	a = rgba[..., 3]
	rows = np.where(a.max(axis=1) > 0.25)[0]
	if len(rows) == 0:
		return rgba
	bottom = rows.max()
	band = a[max(bottom - FRAME // 10, 0) : bottom + 1] ** 2
	xs = np.arange(FRAME)[None, :]
	cx = (band * xs).sum() / max(band.sum(), 1e-6)
	return shift(rgba, int(round(FRAME / 2 - cx)), FRAME - 1 - bottom)


def sheet(name, source, place, fade_bottom):
	path = SRC / source
	if not path.exists():
		print("skipped (no source):", path.relative_to(ROOT))
		return
	fade = edge_fade(FRAME, 0.07)
	if not fade_bottom:
		# The side flame starts on the bottom edge: fade the other three only.
		x = np.linspace(0, 1, FRAME)
		side = np.clip(np.minimum(x, 1 - x) / 0.07, 0, 1)
		top = np.clip(x / 0.07, 0, 1)
		fade = side[None, :] * top[:, None]
	out = np.zeros((FRAME * 2, FRAME * 2, 4), np.float32)
	for i, frame in enumerate(frames(path)):
		rgba = place(frame)
		rgba[..., 3] *= fade
		y, x = (i // 2) * FRAME, (i % 2) * FRAME
		out[y : y + FRAME, x : x + FRAME] = rgba
	save(name, out)


def main():
	tracer()
	tracer_wake()
	sheet("flash_front_2x2.png", "flash_front.png", centred, True)
	sheet("flash_side_2x2.png", "flash_side.png", based, False)
	sheet("impact_2x2.png", "impact_sparks.png", centred, True)


if __name__ == "__main__":
	main()
