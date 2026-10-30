"""Lobby skybox: a clean, clear-day gradient sky for the oculus and the light wells.

    python tools/textures/make_lobby_sky.py

Writes art-source/lobby/textures/Lobby_Sky_{Up,Dn,Ft,Bk,Lf,Rt}.png. The colour depends only on elevation, so
every face joins seamlessly whatever its in-plane orientation (side faces: image top = up). From inside the
bunker the sky is only ever seen as a disc through a knife-edge rim (Turrell skyspace), so it is a soft,
pale, slightly warm-at-the-horizon blue rather than the saturated default Roblox zenith, with no clouds.
"""

import os

import numpy as np
from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "art-source", "lobby", "textures")
N = 512

ZENITH = np.array([0x74, 0xA6, 0xD9], float)
MID = np.array([0x9C, 0xC2, 0xE6], float)
HORIZON = np.array([0xD8, 0xE3, 0xEA], float)
GROUND = np.array([0x5A, 0x5C, 0x60], float)


def colour(elev):
	# elev: sin(elevation) in -1..1
	e = np.clip(elev, -1, 1)[..., None]
	up = np.clip(e, 0, 1)
	t1 = np.clip(up / 0.35, 0, 1) ** 0.8  # horizon -> mid over the first ~20 degrees
	t2 = np.clip((up - 0.35) / 0.65, 0, 1) ** 1.2  # mid -> zenith
	sky = HORIZON * (1 - t1) + MID * t1
	sky = sky * (1 - t2) + ZENITH * t2
	down = np.clip(-e / 0.08, 0, 1)
	return sky * (1 - down) + GROUND * down


def face(kind):
	v = (np.arange(N) + 0.5) / N * 2 - 1
	a, b = np.meshgrid(v, -v)  # a: right, b: up in image space
	if kind == "Up":
		d = np.stack([a, np.ones_like(a), b], -1)
	elif kind == "Dn":
		d = np.stack([a, -np.ones_like(a), b], -1)
	else:
		d = np.stack([a, b, np.ones_like(a)], -1)  # any side face: image up = world up
	d = d / np.linalg.norm(d, axis=-1, keepdims=True)
	c = colour(d[..., 1])
	rng = np.random.default_rng(3)
	c = c + rng.uniform(-0.6, 0.6, c.shape)  # dither against banding
	return Image.fromarray(np.clip(np.round(c), 0, 255).astype(np.uint8), "RGB")


if __name__ == "__main__":
	os.makedirs(OUT, exist_ok=True)
	for k in ["Up", "Dn", "Ft", "Bk", "Lf", "Rt"]:
		face(k).save(os.path.join(OUT, f"Lobby_Sky_{k}.png"))
	print("wrote", OUT)
