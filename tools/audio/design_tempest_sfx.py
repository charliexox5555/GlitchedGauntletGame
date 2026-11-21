"""Design the Tempest-Strike Vandal's foley from CC0 Freesound recordings.

    python -I tools/audio/design_tempest_sfx.py

Sources: art-source/audio/downloads/freesound-<id>/ (fetched by fetch_audio.py,
CC0 checked on each sound page; ledger in vault 02 Art/Skins/TempestStrike/
Tempest Audio.md). Real water and electric recordings, cut, pitched, layered;
nothing synthesised. Writes art-source/audio/tempest/<cue>.wav (48 kHz mono,
peak -1 dBFS) and an audition reel art-source/audio/tempest/_reel.wav.
The gunshot stays the stock Vandal's (custom shots are a later pass).
"""

import glob
import os

import numpy as np
import soundfile as sf
from scipy.signal import butter, resample_poly, sosfilt

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
SRC = os.path.join(ROOT, "art-source", "audio", "downloads")
OUT = os.path.join(ROOT, "art-source", "audio", "tempest")
SR = 48000


def load(sid):
	path = glob.glob(os.path.join(SRC, f"freesound-{sid}", "*.ogg"))[0]
	x, sr = sf.read(path, always_2d=True)
	x = x.mean(1)
	if sr != SR:
		g = np.gcd(SR, sr)
		x = resample_poly(x, SR // g, sr // g)
	return x / max(np.abs(x).max(), 1e-9)


def cut(x, t0, t1, fin=0.004, fout=0.03):
	y = x[int(t0 * SR) : int(t1 * SR)].copy()
	n_in, n_out = int(fin * SR), int(fout * SR)
	if n_in:
		y[:n_in] *= np.linspace(0, 1, n_in)
	if n_out:
		y[-n_out:] *= np.linspace(1, 0, n_out) ** 2
	return y


def pitch(x, ratio):
	# resampling: ratio > 1 is higher and shorter (a designed pitch, like a sampler)
	up, down = int(round(1000 / ratio)), 1000
	g = np.gcd(up, down)
	return resample_poly(x, up // g, down // g)


def db(x, gain):
	return x * 10 ** (gain / 20)


def filt(x, lo=None, hi=None):
	if lo:
		x = sosfilt(butter(2, lo, "highpass", fs=SR, output="sos"), x)
	if hi:
		x = sosfilt(butter(2, hi, "lowpass", fs=SR, output="sos"), x)
	return x


def mix(*layers):
	n = max(int(off * SR) + len(y) for off, y in layers)
	out = np.zeros(n)
	for off, y in layers:
		i = int(off * SR)
		out[i : i + len(y)] += y
	return out


def finish(x, tail=0.04):
	x = filt(x, lo=90)
	n = int(tail * SR)
	x[-n:] *= np.linspace(1, 0, n) ** 2
	return x / np.abs(x).max() * 10 ** (-1 / 20)


def cues():
	swish = load(321489)  # Water Swish
	pipe = load(855838)  # Whoosh, plastic water pipe
	splash = load(398032)  # Splash
	tiny = load(321490)  # Tiny Splash
	squish = load(737232)  # Short Water Squish
	wsplash = load(737234)  # Water Splash
	swirl = load(478722)  # Water Swirl
	zap = load(512471)  # Electric zap
	zap1 = load(136542)  # ELECTRIC_ZAP_001
	spark = load(189630)  # Spark
	stun = load(264779)  # stun gun 1/10 s
	crackle = load(582631)  # Long Crackle 04
	return {
		# equip: a rising water swish with air under it
		"draw": mix(
			(0, pitch(cut(swish, 0.06, 0.82, fout=0.12), 1.12)),
			(0.04, db(filt(cut(pipe, 0.06, 0.36), hi=6000), -6)),
		),
		# the plates lock: a short bright zap on a small splash
		"drawLock": mix(
			(0, db(pitch(cut(zap, 0, 0.22), 0.9), -1)),
			(0.01, db(cut(wsplash, 0.0, 0.34, fout=0.08), -6)),
		),
		# inspect start: water turning over, a thread of static
		"inspect": mix(
			(0, cut(swirl, 0.02, 0.92, fin=0.05, fout=0.3)),
			(0.28, db(cut(crackle, 0.12, 0.5, fout=0.1), -15)),
		),
		# the barrel roll: a deeper water whoosh round the gun
		"inspectRoll": mix(
			(0, pitch(cut(swish, 0.05, 0.8, fout=0.15), 0.85)),
			(0.03, db(pitch(cut(pipe, 0.05, 0.4), 0.8), -4)),
		),
		# the hands catch it: a wet slap and a spark
		"inspectCatch": mix(
			(0, cut(squish, 0.0, 0.4, fout=0.1)),
			(0.0, db(cut(spark, 0.0, 0.17), -3)),
			(0.01, db(cut(wsplash, 0.0, 0.3, fout=0.08), -7)),
		),
		# the old magazine bursts into water, with a fizz of static
		"magOut": mix(
			(0, pitch(cut(splash, 0.03, 0.7, fout=0.18), 1.15)),
			(0.0, db(cut(stun, 0.1, 0.28), -9)),
		),
		# water gathers into the new magazine (a reversed splash, rising)
		"magForm": filt(
			cut(pitch(cut(tiny, 0.18, 0.62, fout=0.002), 1.1)[::-1], 0, 0.36, fin=0.08, fout=0.01),
			hi=9000,
		),
		# the water magazine seats: a hard zap and a splash under the stock click
		"magSeat": mix(
			(0, db(cut(zap1, 0.3, 0.62, fout=0.08), -2)),
			(0.0, db(cut(wsplash, 0.0, 0.3, fout=0.08), -6)),
		),
	}


def main():
	os.makedirs(OUT, exist_ok=True)
	reel = []
	for name, x in cues().items():
		x = finish(x)
		sf.write(os.path.join(OUT, f"{name}.wav"), x.astype(np.float32), SR, subtype="PCM_16")
		print(f"{name}: {len(x) / SR:.2f} s")
		reel += [x, np.zeros(int(0.6 * SR))]
	sf.write(os.path.join(OUT, "_reel.wav"), np.concatenate(reel).astype(np.float32), SR, subtype="PCM_16")


if __name__ == "__main__":
	main()
