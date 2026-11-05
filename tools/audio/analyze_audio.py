"""Measure candidate recordings so picks are made on numbers, not guesses.

    python -I tools/audio/analyze_audio.py out_dir file_or_folder [...]

For every file (OGG/WAV/FLAC/MP3 that libsndfile reads) it finds the separate
events (hits, steps, swishes) and prints, per event: start and length (to
-40 dB under its peak), peak dBFS, attack (10 % -> 90 % of the envelope, ms),
spectral centroid (Hz), momentary max loudness (BS.1770 K-weighted, 400 ms
window, LUFS) and the file's noise floor and clipping. It also writes one PNG
per file into out_dir: the envelope over a log spectrogram (0-16 kHz) with
the events marked, so the shape of each sound can be seen.

Writes out_dir/analysis.json (the same numbers). Needs numpy, scipy, soundfile.
"""

import json
import os
import struct
import sys
import zlib

import numpy as np
import soundfile as sf
from scipy import signal

RATE = 48000


def load(path):
	x, sr = sf.read(path, always_2d=True)
	x = x.mean(axis=1)
	if sr != RATE:
		x = signal.resample_poly(x, RATE, sr)
	return x.astype(np.float64)


def k_weight(x):
	# ITU-R BS.1770 K-weighting at 48 kHz (pre-filter shelf + RLB high-pass).
	b1 = [1.53512485958697, -2.69169618940638, 1.19839281085285]
	a1 = [1.0, -1.69065929318241, 0.73248077421585]
	b2 = [1.0, -2.0, 1.0]
	a2 = [1.0, -1.99004745483398, 0.99007225036621]
	return signal.lfilter(b2, a2, signal.lfilter(b1, a1, x))


def momentary_max(x):
	k = k_weight(x)
	w = int(0.4 * RATE)
	if len(k) < w:
		k = np.pad(k, (0, w - len(k)))
	c = np.concatenate([[0.0], np.cumsum(k * k)])
	p = (c[w:] - c[:-w]) / w
	return float(-0.691 + 10 * np.log10(max(p.max(), 1e-12)))


def envelope(x, hop=0.005):
	n = int(hop * RATE)
	frames = len(x) // n
	e = np.sqrt((x[: frames * n].reshape(frames, n) ** 2).mean(axis=1) + 1e-12)
	return e, n


def events(x):
	e, n = envelope(x)
	db = 20 * np.log10(e)
	floor = float(np.percentile(db, 10))
	gate = max(floor + 18, db.max() - 45)
	on = db > gate
	out = []
	i = 0
	while i < len(on):
		if on[i]:
			j = i
			gap = 0
			while j < len(on) and gap < 16:  # 80 ms of quiet ends an event
				gap = 0 if on[j] else gap + 1
				j += 1
			out.append((i, j - gap))
			i = j
		else:
			i += 1
	res = []
	for a, b in out:
		seg = e[a:b]
		pk = a + int(seg.argmax())
		pk_db = db[pk]
		# Extend the end to -40 dB under the peak.
		end = pk
		while end < len(db) - 1 and db[end] > pk_db - 40:
			end += 1
		start = a
		while start > 0 and db[start - 1] > pk_db - 40 and db[start - 1] < db[start]:
			start -= 1
		lo, hi = 0.1 * e[pk], 0.9 * e[pk]
		t10 = next((k for k in range(start, pk + 1) if e[k] >= lo), start)
		t90 = next((k for k in range(start, pk + 1) if e[k] >= hi), pk)
		s0, s1 = start * n, end * n
		clip = x[s0:s1]
		if len(clip) < 64:
			continue
		spec = np.abs(np.fft.rfft(clip * np.hanning(len(clip))))
		freqs = np.fft.rfftfreq(len(clip), 1 / RATE)
		cen = float((spec * freqs).sum() / max(spec.sum(), 1e-12))
		res.append(
			{
				"start": round(s0 / RATE, 3),
				"length": round((s1 - s0) / RATE, 3),
				"peak_dbfs": round(float(20 * np.log10(np.abs(clip).max() + 1e-12)), 1),
				"attack_ms": round((t90 - t10) * n / RATE * 1000, 1),
				"peak_at": round(pk * n / RATE - s0 / RATE, 3),
				"centroid_hz": round(cen),
				"lufs_m": round(momentary_max(clip), 1),
			}
		)
	return res, floor


def write_png(path, rgb):
	h, w, _ = rgb.shape
	raw = b"".join(b"\x00" + rgb[y].tobytes() for y in range(h))

	def chunk(t, d):
		c = struct.pack(">I", len(d)) + t + d
		return c + struct.pack(">I", zlib.crc32(t + d) & 0xFFFFFFFF)

	png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 2, 0, 0, 0))
	png += chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b"")
	open(path, "wb").write(png)


def picture(x, evs, path, max_s=8.0):
	x = x[: int(max_s * RATE)]
	f, t, z = signal.spectrogram(x, RATE, nperseg=1024, noverlap=768)
	keep = f <= 16000
	z = 10 * np.log10(z[keep] + 1e-14)
	z = np.clip((z - (z.max() - 80)) / 80, 0, 1)[::-1]
	h_spec = 160
	cols = min(len(t), 900)
	idx = np.linspace(0, len(t) - 1, cols).astype(int)
	rows = np.linspace(0, z.shape[0] - 1, h_spec).astype(int)
	img = z[rows][:, idx]
	spec_rgb = np.stack([img ** 0.7, img ** 1.4, img * 0.6 + 0.15 * (img > 0.05)], axis=2)
	e, n = envelope(x)
	db = np.clip((20 * np.log10(e) + 60) / 60, 0, 1)
	env_rgb = np.full((60, cols, 3), 0.08)
	ei = np.linspace(0, len(db) - 1, cols).astype(int)
	for c, v in enumerate(db[ei]):
		env_rgb[60 - int(v * 59) - 1 :, c] = (0.85, 0.85, 0.85)
	rgb = np.concatenate([env_rgb, spec_rgb], axis=0)
	dur = len(x) / RATE
	for ev in evs:
		for key, col in (("start", (0.2, 1, 0.2)), ("end", (1, 0.3, 0.3))):
			at = ev["start"] if key == "start" else ev["start"] + ev["length"]
			if at < dur:
				rgb[:, min(int(at / dur * cols), cols - 1)] = col
	write_png(path, (np.clip(rgb, 0, 1) * 255).astype(np.uint8))


def main():
	out = sys.argv[1]
	os.makedirs(out, exist_ok=True)
	files = []
	for p in sys.argv[2:]:
		if os.path.isdir(p):
			files += [
				os.path.join(r, f)
				for r, _, fs in os.walk(p)
				for f in fs
				if f.lower().endswith((".ogg", ".wav", ".flac", ".mp3"))
			]
		else:
			files.append(p)
	result = {}
	for path in sorted(files):
		name = os.path.splitext(os.path.basename(path))[0]
		x = load(path)
		evs, floor = events(x)
		clipped = int((np.abs(x) > 0.999).sum())
		result[name] = {"path": path, "duration": round(len(x) / RATE, 2), "floor_db": round(floor, 1), "clipped": clipped, "events": evs}
		picture(x, evs, os.path.join(out, name + ".png"))
		print(f"{name}: {len(x) / RATE:.2f}s floor {floor:.0f} dB clipped {clipped}")
		for ev in evs[:8]:
			print(
				f"   @{ev['start']:6.2f} len {ev['length']:.2f} pk {ev['peak_dbfs']:6.1f} atk {ev['attack_ms']:5.1f}ms"
				f" cen {ev['centroid_hz']:5d} lufs {ev['lufs_m']:6.1f}"
			)
		if len(evs) > 8:
			print(f"   ... {len(evs)} events")
	json.dump(result, open(os.path.join(out, "analysis.json"), "w"), indent=1)


if __name__ == "__main__":
	main()
