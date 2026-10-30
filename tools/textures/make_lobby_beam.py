"""Lobby sunbeam textures for the fake god rays under the oculus (tools/studio/lobby/Lighting.luau).

    python tools/textures/make_lobby_beam.py

Writes art-source/lobby/textures/Lobby_SunBeam.png and Lobby_DustMote.png.

Lobby_SunBeam: white RGB, all the shape in alpha. Roblox maps a Beam texture's X axis ACROSS the beam
width and its Y axis along the beam (Attachment0 -> Attachment1); tested in Studio 2026-10-29 with both
orientations. So the image varies only along X: a soft falloff to both edges plus a few faint shafts and
gaps (dust streaks parallel to the ray). The
along-the-beam fade is the Beam's Transparency sequence, so one texture serves every beam.
Lobby_DustMote: a small soft dot for the slow dust emitter in the shaft.
"""

import os

import numpy as np
from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "art-source", "lobby", "textures")


def smoothstep(e0, e1, x):
	t = np.clip((x - e0) / (e1 - e0), 0.0, 1.0)
	return t * t * (3 - 2 * t)


def sunbeam(w=256, h=128, seed=7):
	rng = np.random.default_rng(seed)
	y = (np.arange(w) + 0.5) / w * 2 - 1  # -1..1 across the beam (image X)
	# Soft shoulders that reach zero well inside the ribbon edge (no visible edge line at any width).
	edge = smoothstep(0.92, 0.0, np.abs(y)) ** 1.6
	# Streaks: a sum of soft bands of random width, position and strength (low frequency, so no aliasing).
	streak = np.full(w, 0.62)
	for _ in range(9):
		c = rng.uniform(-0.8, 0.8)
		s = rng.uniform(0.03, 0.12)
		a = rng.uniform(-0.22, 0.38)
		streak += a * np.exp(-((y - c) ** 2) / (2 * s * s))
	streak = np.clip(streak, 0.25, 1.0)
	prof = edge * streak
	prof = prof / prof.max()
	alpha = np.tile(prof[None, :], (h, 1))
	img = np.zeros((h, w, 4), np.uint8)
	img[..., :3] = 255
	img[..., 3] = np.round(alpha * 255).astype(np.uint8)
	return Image.fromarray(img, "RGBA")


def mote(n=64):
	v = (np.arange(n) + 0.5) / n * 2 - 1
	r = np.sqrt(v[None, :] ** 2 + v[:, None] ** 2)
	a = np.exp(-(r**2) / (2 * 0.22**2)) * smoothstep(1.0, 0.8, r)
	img = np.zeros((n, n, 4), np.uint8)
	img[..., :3] = 255
	img[..., 3] = np.round(a / a.max() * 255).astype(np.uint8)
	return Image.fromarray(img, "RGBA")


if __name__ == "__main__":
	os.makedirs(OUT, exist_ok=True)
	sunbeam().save(os.path.join(OUT, "Lobby_SunBeam.png"))
	mote().save(os.path.join(OUT, "Lobby_DustMote.png"))
	print("wrote", OUT)
