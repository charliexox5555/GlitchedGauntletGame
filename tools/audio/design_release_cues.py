"""Release 1 audio pass (2026-11-28): the cues that were missing or stand-ins.

- Toxic Cloud (Smoke G path): its own pop and loop, an acid sizzle and bubbling over the smoke.
- Power UI: ModReady (soft rising two-note), ModDenied (a low double "nuh-uh"), ModCancel (a short
  falling swish), ModRaise (a light gear grab as a held power comes up).

Same method and libraries as design_powers.py (licensed ProPack + Sonniss GDC 2016 layers, our own synthesis).
Owner taste: soft and round, no metal rings, no harsh highs on UI. Outputs private 48 kHz mono WAVs in
art-source/audio/release1/ (git-ignored) and an audition reel _Reel.wav / _Reel.txt.

    python tools/audio/design_release_cues.py
"""
import json
from pathlib import Path

import numpy as np
import soundfile as sf

from build_sound_atlas import bp, hp, lp
from design_powers import (
	RATE,
	ROOT,
	cut,
	env_exp,
	fades,
	limit,
	loopable,
	n,
	noise,
	norm,
	pack,
	place,
	sub,
	sweep,
	t,
	trim,
)

OUT = ROOT / "art-source/audio/release1"


def soft_tone(sec, f, attack=0.008, decay=0.12, harmonics=(1.0, 0.25, 0.08)):
	"""A round, ring-free tone: a sine with a couple of quiet harmonics and a soft attack."""
	tt = t(sec)
	x = sum(a * np.sin(2 * np.pi * f * (i + 1) * tt) for i, a in enumerate(harmonics))
	shape = np.minimum(1, tt / attack) * np.exp(-tt / decay)
	return x * shape


def bubbles(sec, seed, rate=18, lo=180, hi=650):
	"""Random small bubble pops: short upward-gliding sines (acid bubbling)."""
	rng = np.random.default_rng(seed)
	out = np.zeros(n(sec))
	count = int(sec * rate)
	for _ in range(count):
		start = rng.uniform(0, sec - 0.08)
		f0 = rng.uniform(lo, hi)
		d = rng.uniform(0.025, 0.06)
		blip = sweep(d, f0, f0 * rng.uniform(1.6, 2.4), decay=d / 2.5)
		i = n(start)
		out[i:i + len(blip)] += blip * rng.uniform(0.3, 1.0)
	return out


def toxic_cues():
	c = {}
	# The pop: the smoke burst's body (pressurised air + whump) with a wet acid sizzle and a burst of bubbles.
	spray = cut("hairspray", 0.88, 0.32, speed=0.78, low=600, high=10000, db=-2, onset=True)
	whump = norm(sub(0.6, 110, 40, 0.18) + 0.6 * lp(noise(0.6, 52), 200, 3) * env_exp(0.6, 0.12), -4)
	sizzle = norm(bp(noise(1.2, 53), 2500, 9000) * (np.minimum(1, t(1.2) / 0.04) * np.exp(-t(1.2) / 0.4)), -9)
	pops = norm(bubbles(0.9, 54, rate=40), -10)
	c["toxic_pop"] = fades(limit(place([(0, spray), (0, whump), (0.03, sizzle), (0.06, pops)]), 1.3, -0.8)[: n(1.3)], 0.0005, 0.25)
	# The loop: the smoke's rolling air, lower, with a steady bubbling and a faint sizzle.
	air = lp(hp(noise(4.5, 61), 180, 2), 2000, 3)
	tt = t(4.5)
	roll = 0.75 + 0.25 * np.sin(2 * np.pi * tt / 2.25) * np.sin(2 * np.pi * tt / 1.5 + 1)
	bub = bubbles(4.5, 62, rate=10)
	hiss = bp(noise(4.5, 63), 3000, 8000) * 0.12
	c["toxic_loop"] = norm(loopable(air * roll * 0.8 + bub * 0.5 + hiss, 0.5), -6)
	return c


def ui_cues():
	c = {}
	# Ready: two soft rising notes (a fifth), round, quick.
	a = soft_tone(0.35, 660, decay=0.09)
	b = soft_tone(0.4, 990, decay=0.12)
	c["ui_ready"] = trim(norm(place([(0, a * 0.8), (0.07, b)]), -2), 0.45)
	# Denied: a low double "nuh-uh", filtered so it's a soft buzz, never harsh.
	def thud(sec, f):
		tt = t(sec)
		x = np.sign(np.sin(2 * np.pi * f * tt)) * 0.5 + np.sin(2 * np.pi * f * tt)
		return lp(x, 900, 2) * np.minimum(1, tt / 0.004) * np.exp(-tt / 0.05)
	c["ui_denied"] = trim(norm(place([(0, thud(0.12, 196)), (0.11, thud(0.14, 165))]), -2), 0.3)
	# Cancel: a short falling swish with a little low blip at the end.
	sw = bp(noise(0.25, 71), 500, 5000) * np.linspace(1, 0.2, n(0.25)) * np.minimum(1, t(0.25) / 0.01)
	blip = soft_tone(0.15, 440, decay=0.05) * 0.5
	c["ui_cancel"] = trim(norm(place([(0, sw), (0.1, blip)]), -3), 0.3)
	# Raise: a light gear grab and a tiny air whoosh as the held power comes up.
	grab = pack("foley_soldier_gear_equipment_movement_grab_item", 2)[: n(0.22)]
	grab = hp(grab, 200) * env_exp(0.22, 0.06, attack=0.002)
	air = bp(noise(0.2, 81), 800, 6000) * (np.minimum(1, t(0.2) / 0.05) * np.exp(-t(0.2) / 0.06)) * 0.3
	c["ui_raise"] = trim(norm(place([(0, grab), (0.02, air)]), -4), 0.25)
	return c


ORDER = ["toxic_pop", "toxic_loop", "ui_ready", "ui_denied", "ui_cancel", "ui_raise"]
LOOPS = {"toxic_loop"}


def main():
	OUT.mkdir(parents=True, exist_ok=True)
	made = {**toxic_cues(), **ui_cues()}
	info = {}
	for key in ORDER:
		x = norm(made[key], -3 if key in LOOPS else -0.8)
		x = np.pad(x, (0, max(0, n(0.12) - len(x))))
		made[key] = x
		sf.write(OUT / f"{key}.wav", x, RATE, subtype="PCM_16")
		info[key] = {"length": round(len(x) / RATE, 3), "peak": round(float(np.abs(x).max()), 3), "loop": key in LOOPS}
	(OUT / "_cues.json").write_text(json.dumps(info, indent=2) + "\n", encoding="utf-8")
	parts, at, lines = [], 0.3, []
	for key in ORDER:
		x = made[key]
		if key in LOOPS:
			x = np.concatenate([x, x])
		parts.append((at, x * 0.9))
		lines.append(f"{at:7.2f}s  {key}")
		at += len(x) / RATE + 0.6
	sf.write(OUT / "_Reel.wav", place(parts), RATE, subtype="PCM_16")
	(OUT / "_Reel.txt").write_text("\n".join(lines) + "\n", encoding="utf-8")
	for k, v in info.items():
		print(k, v)


if __name__ == "__main__":
	main()
