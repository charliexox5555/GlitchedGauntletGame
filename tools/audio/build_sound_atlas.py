"""Build the sound atlas: one stereo audio file holding every gunshot, foley
and UI sound, played in-game as slices (Sound.PlaybackRegion). One upload
instead of ~100 keeps us inside Open Cloud's monthly audio quota.

    python -I tools/audio/build_sound_atlas.py            # atlas + Luau table
    python -I tools/audio/build_sound_atlas.py --preview  # also an audition WAV

Gunshots are real recordings, only polished: the raw library sounds good
but dull (quiet next to its peaks, a little muddy, long outdoor echoes).
Each shot gets a rumble cut, a little mud out, presence and air in, a
harder front edge, its echo trimmed (snipers keep more of their boom),
gentle glue compression and loudness matched per class. Classes get their
own recordings: machine guns use the last shot of real full-auto bursts,
snipers the big bolt rifles. Each gun gets up to 3 variants (separate
recorded shots) plus a "_Far" version for other players' shots, from the
library's mid-distance mic. The Null beam hum, dry fire, low-ammo tick
and the hit / headshot / kill / damage sounds are synthesized; handling
foley and Ray Trace use Roblox-licensed library sounds (Config/Sounds).

Sources: "The Free Firearm Sound Library" (CC0, Ben Jaszczak et al.),
unpacked to art-source/audio/library/ (gitignored). Needs numpy, scipy
and soundfile.

Writes:
  art-source/audio/GunAtlas.flac          48 kHz stereo 16-bit (uploaded)
  art-source/audio/GunAtlas.json          name -> [{start, length}]
  src/shared/Config/SoundAtlas.luau       the same, for the game
  art-source/audio/AtlasPreview.wav       --preview only (gitignored)
"""

import argparse
import json
import os
import zlib
from fractions import Fraction

import numpy as np
import soundfile as sf
from scipy import signal

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
LIB = os.path.join(ROOT, "art-source", "audio", "library", "Prepared SFX Library")
OUT_AUDIO = os.path.join(ROOT, "art-source", "audio", "GunAtlas.flac")
OUT_JSON = os.path.join(ROOT, "art-source", "audio", "GunAtlas.json")
OUT_LUAU = os.path.join(ROOT, "src", "shared", "Config", "SoundAtlas.luau")
OUT_PREVIEW = os.path.join(ROOT, "art-source", "audio", "AtlasPreview.wav")
RATE = 48000
GAP = 0.25  # silence between slices, so a slice never bleeds into the next
VARIANTS = 3

# DSP --------------------------------------------------------------------------


def stereo(x):
	return x if x.ndim == 2 else np.stack([x, x], axis=1)


def mono(x):
	return x if x.ndim == 1 else x.mean(axis=1)


def peak(x):
	return float(np.abs(x).max()) or 1.0


def db(v):
	return 20 * np.log10(np.maximum(v, 1e-9))


def undb(v):
	return 10 ** (np.asarray(v) / 20)


def butter(x, kind, f, order=2):
	if kind == "band":
		lo, hi = f
		f = (lo, min(hi, RATE * 0.45))
	else:
		f = min(f, RATE * 0.45)
	return signal.sosfilt(signal.butter(order, f, kind, fs=RATE, output="sos"), x, axis=0)


def hp(x, f, order=2):
	return butter(x, "highpass", f, order)


def lp(x, f, order=2):
	return butter(x, "lowpass", f, order)


def bp(x, lo, hi, order=2):
	return butter(x, "band", (lo, hi), order)


def biquad(x, kind, f, gain_db=0.0, q=0.707):
	"""RBJ cookbook peak / low shelf / high shelf."""
	a_ = 10 ** (gain_db / 40)
	w0 = 2 * np.pi * f / RATE
	cs, alpha = np.cos(w0), np.sin(w0) / (2 * q)
	sa = 2 * np.sqrt(a_) * alpha
	if kind == "peak":
		b = [1 + alpha * a_, -2 * cs, 1 - alpha * a_]
		a = [1 + alpha / a_, -2 * cs, 1 - alpha / a_]
	elif kind == "low":
		b = [a_ * ((a_ + 1) - (a_ - 1) * cs + sa), 2 * a_ * ((a_ - 1) - (a_ + 1) * cs), a_ * ((a_ + 1) - (a_ - 1) * cs - sa)]
		a = [(a_ + 1) + (a_ - 1) * cs + sa, -2 * ((a_ - 1) + (a_ + 1) * cs), (a_ + 1) + (a_ - 1) * cs - sa]
	else:  # high shelf
		b = [a_ * ((a_ + 1) + (a_ - 1) * cs + sa), -2 * a_ * ((a_ - 1) + (a_ + 1) * cs), a_ * ((a_ + 1) + (a_ - 1) * cs - sa)]
		a = [(a_ + 1) - (a_ - 1) * cs + sa, 2 * ((a_ - 1) - (a_ + 1) * cs), (a_ + 1) - (a_ - 1) * cs - sa]
	b, a = np.array(b) / a[0], np.array(a) / a[0]
	return signal.lfilter(b, a, x, axis=0)


def eq(x, bands):
	for band in bands:
		x = biquad(x, *band)
	return x


def envelope(x, attack, release):
	"""Peak envelope follower (both channels)."""
	m = np.abs(x).max(axis=1) if x.ndim == 2 else np.abs(x)
	ca, cr = np.exp(-1 / (attack * RATE)), np.exp(-1 / (release * RATE))
	out = np.empty(len(m))
	e = 0.0
	for i, v in enumerate(m.tolist()):
		c = ca if v > e else cr
		e = c * e + (1 - c) * v
		out[i] = e
	return out


def gain(x, g):
	return x * (g[:, None] if x.ndim == 2 else g)


def transient(x, amount_db):
	"""Boost the attack: gain follows how far a fast envelope leads a slow one."""
	fast = envelope(x, 0.0003, 0.02)
	slow = envelope(x, 0.010, 0.02)
	lead = np.clip(db(fast) - db(slow), 0, 12) / 12
	return gain(x, undb(lead * amount_db))


def compress(x, thresh, ratio, attack, release, knee=6.0):
	lvl = db(envelope(x, attack, release))
	over = lvl - thresh
	slope = 1 - 1 / ratio
	gr = np.where(
		over <= -knee / 2,
		0,
		np.where(over >= knee / 2, over * slope, slope * (over + knee / 2) ** 2 / (2 * knee)),
	)
	return gain(x, undb(-gr))


def oversampled(x, fn, factor=4):
	"""Run a waveshaper at 4x rate so its new harmonics don't alias back down."""
	up = signal.resample_poly(x, factor, 1, axis=0)
	return signal.resample_poly(fn(up), 1, factor, axis=0)[: len(x)]


def saturate(x, drive, mix=1.0):
	"""tanh drive at a fixed reference level, so drive means the same everywhere."""
	p = peak(x)
	y = oversampled(x, lambda u: np.tanh(u / p * drive) / np.tanh(drive) * p)
	return x * (1 - mix) + y * mix


def soft_clip(x, ceiling=0.89):
	return oversampled(x, lambda u: np.tanh(u / ceiling) * ceiling)


def tighten(x, hold, tau):
	"""Cut a long tail short: full level for `hold`, then an exponential decay."""
	t = np.arange(len(x)) / RATE
	return gain(x, np.where(t < hold, 1.0, np.exp(-(t - hold) / tau)))


def fit(x, length, fade=0.3):
	"""Trim/pad to `length` s, with a short fade in and a smooth fade out."""
	n = int(RATE * length)
	x = stereo(x)[:n]
	if len(x) < n:
		x = np.pad(x, ((0, n - len(x)), (0, 0)))
	x = x.copy()
	f = int(n * fade)
	x[-f:] *= (np.cos(np.linspace(0, np.pi, f)) * 0.5 + 0.5)[:, None]
	a = int(RATE * 0.0015)
	x[:a] *= np.linspace(0, 1, a)[:, None]
	return x


def pan(x, p):
	"""Constant-power pan of a mono signal: -1 left .. 1 right."""
	a = (p + 1) * np.pi / 4
	return np.stack([mono(x) * np.cos(a), mono(x) * np.sin(a)], axis=1) * np.sqrt(2)


def place(dst, src, at):
	"""Add src into dst starting at `at` seconds (both stereo)."""
	i = int(at * RATE)
	src = stereo(src)
	n = min(len(src), len(dst) - i)
	if n > 0:
		dst[i : i + n] += src[:n]
	return dst


def loudness(x, window=0.15):
	"""Punch loudness: K-weighted-ish RMS of the first `window` s, in dB."""
	k = biquad(hp(mono(x), 60), "high", 1500, 4.0)
	seg = k[: int(RATE * window)]
	return float(db(np.sqrt(np.mean(seg**2)) + 1e-12))


def master(x, target, ceiling=0.89, window=0.15):
	"""Match loudness to `target` after soft clipping (a few passes, since
	the clipper takes some level back), then a hard safety clip."""
	g = target - loudness(x, window)
	for _ in range(4):
		y = soft_clip(x * undb(g), ceiling)
		err = target - loudness(y, window)
		if abs(err) < 0.1:
			break
		g += err
	return np.clip(y, -0.98, 0.98)


_ir_cache = {}


def reverb_ir(rt60, seed, damp=5500.0, predelay=0.006):
	key = (rt60, seed, damp, predelay)
	if key in _ir_cache:
		return _ir_cache[key]
	rng = np.random.default_rng(seed)
	n = int(RATE * rt60 * 1.1)
	t = np.arange(n) / RATE
	# Separate noise for the two bands: filtered copies of the same noise are
	# out of phase at the crossover and would cancel into a sweeping notch.
	body = lp(rng.normal(size=(n, 2)) * (10 ** (-3 * t / rt60))[:, None], damp)
	air = hp(rng.normal(size=(n, 2)) * (10 ** (-3 * t / (rt60 * 0.3)))[:, None], damp) * 0.4
	ir = body + air
	ir[: int(RATE * 0.002)] *= np.linspace(0, 1, int(RATE * 0.002))[:, None]
	# A couple of early reflections so it reads as a room, not a hiss.
	for d, g in ((0.011, 0.5), (0.019, 0.35), (0.027, 0.25)):
		ir[int(d * RATE), 0] += g * 30
		ir[int((d + 0.003) * RATE), 1] += g * 30
	ir /= np.sqrt(np.sum(ir**2) / 2)
	ir = np.pad(ir, ((int(predelay * RATE), 0), (0, 0)))
	_ir_cache[key] = ir
	return ir


def reverb(x, rt60, seed=7, damp=5500.0, predelay=0.006):
	ir = reverb_ir(rt60, seed, damp, predelay)
	src = hp(mono(x), 150)
	wet = np.stack([signal.fftconvolve(src, ir[:, c])[: len(x)] for c in (0, 1)], axis=1)
	return wet


def resample(x, ratio):
	"""Resample by `ratio` (out/in); used for both 96k->48k and pitch."""
	f = Fraction(ratio).limit_denominator(400)
	return signal.resample_poly(x, f.numerator, f.denominator, axis=0)


def seed(*parts):
	"""Stable per-name random seed (hash() changes every run)."""
	return zlib.crc32(":".join(map(str, parts)).encode())


# Recordings -------------------------------------------------------------------

_files = {}


def load(path):
	if path not in _files:
		x, rate = sf.read(os.path.join(LIB, path), always_2d=True)
		_files[path] = (stereo(x[:, :2] if x.shape[1] >= 2 else x[:, 0]), rate)
	return _files[path]


def shot_onsets(x, rate, spacing=0.9):
	"""Starts of the separate full-power shots in a recording."""
	m = np.abs(x).max(axis=1)
	hop = rate // 1000
	n = len(m) // hop
	env = m[: n * hop].reshape(n, hop).max(axis=1)
	top = env.max()
	onsets = []
	i = 0
	while i < n:
		if env[i] > top * 0.5:
			# back up to where the shot starts rising
			j = i
			while j > 0 and env[j - 1] > top * 0.02 and i - j < 15:
				j -= 1
			onsets.append(max(0, j * hop - int(rate * 0.001)))
			i += int(spacing * 1000)
		else:
			i += 1
	return onsets


def t_axis(seconds):
	return np.arange(int(RATE * seconds)) / RATE


def thump(f0, f1, tau_f, tau_a, drive=2.5):
	"""Low-end punch: a sine sweeping f0 -> f1, saturated for harmonics."""
	t = t_axis(tau_a * 6 + 0.02)
	f = f1 + (f0 - f1) * np.exp(-t / tau_f)
	y = np.sin(2 * np.pi * np.cumsum(f) / RATE) * (1 - np.exp(-t / 0.0012)) * np.exp(-t / tau_a)
	y = saturate(y, drive)
	return y / peak(y)


MODES = (1.0, 1.47, 2.09, 2.56, 3.31, 4.08, 5.2)


def clack(rng, base, tau, n_s=0.12, modes=MODES, noise=0.6, knock=0.0):
	"""One metal-on-metal hit: inharmonic decaying partials + a noise tick."""
	t = t_axis(n_s)
	y = np.zeros(len(t))
	for k, r in enumerate(modes):
		f = base * r * (1 + rng.uniform(-0.03, 0.03))
		if f > RATE * 0.45:
			continue
		a = rng.uniform(0.5, 1.0) / (k + 1) ** 0.6
		d = tau * rng.uniform(0.6, 1.4) / (1 + 0.25 * k)
		y += a * np.sin(2 * np.pi * f * t + rng.uniform(0, 6.28)) * np.exp(-t / d)
	tick = hp(rng.normal(size=len(t)), 2500) * np.exp(-t / 0.0015)
	y = y / peak(y) + tick / peak(tick) * noise
	if knock:
		y += np.sin(2 * np.pi * knock * t) * np.exp(-t / 0.025) * 0.8
	y *= 1 - np.exp(-t / 0.0002)
	return y / peak(y)


def tone(freqs, taus, seconds, amps=None, detune=0.0):
	"""Bell-ish partials, optionally detuned left/right for width."""
	t = t_axis(seconds)
	out = np.zeros((len(t), 2))
	amps = amps or [1.0] * len(freqs)
	for f, tau, a in zip(freqs, taus, amps):
		env = (1 - np.exp(-t / 0.0006)) * np.exp(-t / tau)
		out[:, 0] += a * np.sin(2 * np.pi * f * (1 - detune) * t) * env
		out[:, 1] += a * np.sin(2 * np.pi * f * (1 + detune) * t) * env
	end = int(RATE * min(0.03, seconds * 0.3))
	out[-end:] *= (np.cos(np.linspace(0, np.pi, end)) * 0.5 + 0.5)[:, None]  # no click at the cut
	return out / peak(out)


def sweep_noise(rng, seconds, path, q=1.6):
	"""Noise through a band-pass whose centre follows path(t) (STFT shaping)."""
	n = int(RATE * seconds)
	x = rng.normal(size=n)
	f, tt, z = signal.stft(x, RATE, nperseg=512)
	for i, ti in enumerate(tt):
		c, a = path(min(ti / seconds, 1.0))
		z[:, i] *= a * np.exp(-0.5 * (np.log(np.maximum(f, 1) / c) * q) ** 2)
	_, y = signal.istft(z, RATE, nperseg=512)
	y = y[:n]
	return y / peak(y)


# Gunshots ---------------------------------------------------------------------
# Real recordings only. The raw library sounds good but dull: quiet next to
# its peaks, a little muddy, and long outdoor echoes. Each shot gets a light
# polish: rumble cut, a little mud out, presence and air in, a harder front
# edge, the echo trimmed (snipers keep more of their boom), gentle glue
# compression and loudness matched per class.

# Class presets.
#   length       clip length (s)
#   hold, tau    the recording's tail is kept for `hold` s, then fades (tau s)
#   low          low shelf at 100 Hz (dB): weight for the heavy classes
#   presence     peak at 3.2 kHz (dB); air: high shelf at 10 kHz (dB)
#   punch        transient boost (dB); target: loudness (dB)
#   lowpass      for suppressed guns and the launcher
CLASSES = {
	"pistol": dict(length=0.7, hold=0.06, tau=0.12, low=0.5, presence=3, air=2.5, punch=4, target=-12.5),
	"heavy_pistol": dict(length=0.95, hold=0.08, tau=0.17, low=3, presence=2.5, air=2, punch=4.5, target=-11.0),
	"machine_pistol": dict(length=0.5, hold=0.04, tau=0.08, low=0, presence=3.5, air=2.5, punch=3.5, target=-13.0),
	"suppressed": dict(length=0.5, hold=0.03, tau=0.07, low=0, presence=2, air=0, punch=3, target=-16.0, lowpass=3000),
	"smg": dict(length=0.55, hold=0.05, tau=0.09, low=1, presence=3, air=2.5, punch=3.5, target=-13.0),
	"rifle": dict(length=0.8, hold=0.07, tau=0.14, low=1.5, presence=3, air=2.5, punch=4, target=-12.0),
	"rifle_suppressed": dict(
		length=0.55, hold=0.04, tau=0.08, low=0.5, presence=2, air=0, punch=3, target=-15.5, lowpass=2600
	),
	"heavy_rifle": dict(length=0.9, hold=0.08, tau=0.16, low=2.5, presence=2.5, air=2, punch=4, target=-11.5),
	"marksman": dict(length=1.0, hold=0.09, tau=0.2, low=2.5, presence=3, air=2, punch=4.5, target=-11.0),
	"mg": dict(length=0.6, hold=0.05, tau=0.1, low=2.5, presence=2.5, air=2, punch=3.5, target=-12.5),
	"heavy_mg": dict(length=0.65, hold=0.05, tau=0.11, low=3.5, presence=2, air=1.5, punch=3.5, target=-12.0),
	"sniper": dict(length=1.8, hold=0.15, tau=0.4, low=3, presence=2.5, air=2, punch=5, target=-9.5),
	"shotgun": dict(length=1.1, hold=0.1, tau=0.22, low=3, presence=2, air=1.5, punch=4.5, target=-10.0),
	"launcher": dict(length=0.9, hold=0.08, tau=0.16, low=4, presence=0, air=0, punch=3, target=-12.0, lowpass=1600),
}

# Atlas name: (near recording(s), mid-distance recording, class, pitch, shots).
# shots: "single" picks separate shots from the first file; "burst" picks the
# last shot of each full-auto burst across the files (the only shots in a
# burst with a clean tail), so machine guns sound like machine guns. The
# names are the recorded gun's; Config/Sounds maps them to our guns.
GUNS = {
	# Sidearms
	"PPQ": ("Walther PPQ/X_39P.wav", "Walther PPQ/X_31P.wav", "pistol", 1.0, "single"),  # Byte
	"Revolver": ("Smith & Wesson 642/V_27P.wav", "Smith & Wesson 642/V_22P.wav", "heavy_pistol", 0.9, "single"),  # Root
	"M1911": ("1911/A_42P.wav", "1911/A_34P.wav", "pistol", 0.97, "single"),  # Dual Boot
	"Bersa": ("Bersa/F_47P.wav", "Bersa/F_41P.wav", "machine_pistol", 1.08, "single"),  # Flicker
	"Ruger22": ("Ruger Mark III/R_35P.wav", "Ruger Mark III/R_30P.wav", "suppressed", 1.0, "single"),  # Mute
	"Mossberg": ("Mossberg/N_30P.wav", "Mossberg/N_26P.wav", "shotgun", 1.08, "single"),  # Splinter
	# SMGs
	"SwedishK": ("Carl Gustav M45/G_31P.wav", "Carl Gustav M45/G_20P.wav", "smg", 1.03, "single"),  # Bandwidth
	"PPSh": ("PPSh/P_30P.wav", "PPSh/P_16P.wav", "smg", 1.05, "single"),  # Burst Buffer
	# Rifles
	"AR15": ("AR-15/D_32P.wav", "AR-15/D_24P.wav", "rifle", 1.0, "single"),  # Pulse
	"AK47Suppressed": ("AK-47/C_28P.wav", "AK-47/C_31P.wav", "rifle_suppressed", 1.04, "single"),  # Bitrate
	"Marlin": ("Marlin 336/I_22P.wav", "Marlin 336/I_17P.wav", "heavy_rifle", 0.97, "single"),  # Overwrite
	"SKS": ("SKS/U_14P.wav", "SKS/U_19P.wav", "marksman", 1.0, "single"),  # Checksum
	# Machine guns: real full-auto bursts
	"AKBurst": (("AK-47/C_27P.wav", "AK-47/C_29P.wav"), "AK-47/C_36P.wav", "mg", 0.96, "burst"),  # Overflow
	"PPShBurst": (("PPSh/P_34P.wav", "PPSh/P_32P.wav", "PPSh/P_30P.wav"), "PPSh/P_22P.wav", "heavy_mg", 0.8, "burst"),  # Flood
	# Snipers: the big bolt guns, keeping their boom
	"Springfield": ("1917/B_24P.wav", "1917/B_16P.wav", "sniper", 1.0, "single"),  # Long Poll
	"Tikka": ("Tikka/W_29P.wav", "Tikka/W_24P.wav", "sniper", 1.04, "single"),  # Handshake
	"Mosin": ("Mosin Nagant/M_21P.wav", "Mosin Nagant/M_26P.wav", "sniper", 0.93, "single"),  # Kernel
	# Shotguns
	"Nova": ("Nova/O_21P.wav", "Nova/O_17P.wav", "shotgun", 0.97, "single"),  # Hard Reset
	"Model12": ("Model 12/K_22P.wav", "Model 12/K_17P.wav", "shotgun", 1.03, "single"),  # Crash
	# Wildcard
	"LeverThump": ("Model 1894/L_23P.wav", "Model 1894/L_17P.wav", "launcher", 0.75, "single"),  # Loopback
}


def burst_last_onsets(x, rate):
	"""Starts of the last shot of each full-auto burst in a recording."""
	m = np.abs(x).max(axis=1)
	hop = rate // 1000
	n = len(m) // hop
	env = m[: n * hop].reshape(n, hop).max(axis=1)
	peaks, _ = signal.find_peaks(env, height=env.max() * 0.35, distance=45)
	bursts = []
	for p in peaks:
		if bursts and p - bursts[-1][-1] < 350:
			bursts[-1].append(p)
		else:
			bursts.append([p])
	onsets = []
	for b in bursts:
		if len(b) < 2:
			continue
		p = b[-1]
		gap = b[-1] - b[-2]
		# back up from the peak to where this shot rises out of the last one
		j = p
		while j > p - min(15, gap // 2) and env[j - 1] < env[j]:
			j -= 1
		onsets.append(max(0, j * hop - int(rate * 0.0005)))
	return onsets


def shots(near, mode):
	"""(path, onset) for every usable shot in the near recording(s)."""
	if mode == "burst":
		paths = (near,) if isinstance(near, str) else near
		return [(path, o) for path in paths for o in burst_last_onsets(*load(path))]
	x, rate = load(near)
	return [(near, o) for o in shot_onsets(x, rate)]


def take(path, onset, pitch, length):
	x, rate = load(path)
	seg = x[onset : onset + int(rate * (length / pitch + 0.05))]
	seg = resample(seg, RATE / rate / pitch)
	return seg - seg[:64].mean(axis=0)  # remove any DC offset


def polish(x, c, length):
	x = hp(x, 45, 4)
	if c.get("lowpass"):
		x = lp(x, c["lowpass"], 2)
	x = eq(x, [
		("low", 100, c["low"]),
		("peak", 350, -2.0, 1.0),
		("peak", 3200, c["presence"], 0.8),
		("high", 10000, c["air"]),
	])
	x = transient(x, c["punch"])
	x = tighten(x, c["hold"], c["tau"])
	x = compress(x, -18, 2.5, 0.005, 0.1)
	return master(fit(x, length, 0.35), c["target"])


def gunshot(name, variant):
	near, _, cls, pitch, mode = GUNS[name]
	c = CLASSES[cls]
	found = shots(near, mode)
	path, onset = found[variant % len(found)]
	# Where the file has fewer shots than variants, nudge the pitch instead.
	if variant >= len(found):
		pitch *= (1.0, 0.975, 1.02)[variant % 3]
	return polish(take(path, onset, pitch, c["length"] + 0.1), c, c["length"])


def gunshot_far(name):
	"""Other players' version: the library's mid-distance mic, mono, duller,
	a bit more of its natural room, quieter."""
	_, mid, cls, pitch, mode = GUNS[name]
	c = CLASSES[cls]
	length = min(1.9, c["length"] * 1.4 + 0.3)
	found = shots(mid, mode) or shots(mid, "single")
	path, onset = found[0]
	x = mono(take(path, onset, pitch, length + 0.1))
	x = hp(x, 90, 4)
	x = lp(x, min(c.get("lowpass", 99999), 5000), 2)
	x = tighten(x, c["hold"] * 1.5, c["tau"] * 2)
	x = compress(stereo(x), -20, 2.5, 0.006, 0.12)
	return master(fit(stereo(mono(x)), length, 0.35), c["target"] - 3.5)


# Energy weapons -----------------------------------------------------------------


def beam_hum():
	"""Null's beam: a 1 s seamless loop (every frequency is a whole number of
	cycles per second, the noise is periodic)."""
	t = t_axis(1.0)
	out = np.zeros((len(t), 2))
	for c, base in enumerate((110, 111)):
		tone_ = sum(np.sin(2 * np.pi * base * h * t) / h for h in range(1, 10))
		wobble = 1 + 0.3 * np.sin(2 * np.pi * 6 * t + c)
		whine = np.sin(2 * np.pi * (880 + c * 2) * t) * 0.15
		out[:, c] = tone_ * wobble + whine
	rng = np.random.default_rng(3)
	spec = rng.normal(size=len(t) // 2 + 1) + 1j * rng.normal(size=len(t) // 2 + 1)
	f = np.fft.rfftfreq(len(t), 1 / RATE)
	spec *= np.exp(-0.5 * ((f - 2500) / 1500) ** 2)
	hiss = np.fft.irfft(spec, len(t))
	out += stereo(hiss / peak(hiss)) * 0.25
	out = np.tanh(out / peak(out) * 1.6)
	return out / peak(out) * 0.7  # no fades: it loops


def disc_launch(variant):
	"""Loopback: the lever-action thump under a spinning-disc "fwip"."""
	body = gunshot("LeverThump", variant)
	rng = np.random.default_rng(200 + variant)
	whirr = sweep_noise(rng, 0.35, lambda k: (1800 - 1200 * k, np.sin(np.pi * k) ** 0.7), q=3)
	t = t_axis(0.35)
	whirr *= 0.6 + 0.4 * np.sin(2 * np.pi * 38 * t)
	place(body, pan(whirr * 0.35, 0.1), 0.02)
	return master(body, -12.0)


# Foley ------------------------------------------------------------------------


def foley(events, length, target, seed, room=0.12):
	"""Mix (time, mono clip, gain, pan) events, add a small room, master."""
	out = np.zeros((int(RATE * length), 2))
	for at, clip, g, p in events:
		place(out, pan(clip * g, p), at)
	out = hp(out, 80)
	out += reverb(out, 0.35, seed=seed, damp=7000, predelay=0.003) * room
	return master(fit(out, length, 0.25), target, 0.8)


def dry_fire():
	r = np.random.default_rng(29)
	return foley([
		(0.0, clack(r, 3600, 0.003), 0.9, 0.25),
		(0.012, clack(r, 2500, 0.004, knock=700), 0.6, 0.25),
	], 0.14, -18.0, 29, room=0.06)


def low_ammo():
	"""A hollow "tink" from a near-empty mag, layered on the shot."""
	r = np.random.default_rng(30)
	hollow = tone([1400, 2950, 4300], [0.05, 0.03, 0.02], 0.15, amps=[1.0, 0.5, 0.3])
	out = np.zeros((int(RATE * 0.16), 2))
	place(out, hollow * 0.7, 0.0)
	place(out, pan(clack(r, 4200, 0.004), 0.3) * 0.5, 0.0)
	return master(fit(out, 0.16, 0.4), -19.0, 0.8)


# Feedback ---------------------------------------------------------------------


def hit_tick(variant):
	"""Body hit: a short, bright, dry "tk" that cuts through gunfire."""
	r = np.random.default_rng(40 + variant)
	base = (2600, 2750)[variant]
	t = t_axis(0.07)
	ping = tone([base, base * 2.32, base * 4.25], [0.012, 0.007, 0.004], 0.07, amps=[1.0, 0.45, 0.25])
	click = hp(r.normal(size=len(t)), 4000) * np.exp(-t / 0.0012)
	body = np.sin(2 * np.pi * 900 * t) * np.exp(-t / 0.006)
	out = ping + stereo(click / peak(click) * 0.6 + body * 0.5)
	return master(fit(out, 0.07, 0.4), -12.0, 0.85)


def head_ding():
	"""Headshot: the tick plus a bright metallic ding with a stereo shimmer."""
	t_len = 0.42
	ding = tone(
		[1900, 3800, 5244, 6650, 10260],
		[0.22, 0.14, 0.09, 0.06, 0.035],
		t_len,
		amps=[1.0, 0.55, 0.5, 0.25, 0.15],
		detune=0.003,
	)
	out = np.zeros((int(RATE * t_len), 2))
	place(out, ding * 0.9, 0.0)
	place(out, hit_tick(0) * 0.7, 0.0)
	return master(fit(out, t_len, 0.5), -11.0, 0.85)


def kill_sound(head):
	"""Kill confirm: a saturated thump, a rising two-note chime and a sparkle."""
	r = np.random.default_rng(50 + head)
	t_len = 0.75 if head else 0.65
	out = np.zeros((int(RATE * t_len), 2))
	place(out, stereo(thump(150, 70, 0.02, 0.05, 3.0)) * 0.35, 0.0)
	bell = (1.0, 2.0, 3.01, 4.2)
	a = tone([1318 * k for k in bell], [0.16, 0.1, 0.07, 0.05], 0.4, amps=[1, 0.4, 0.25, 0.15], detune=0.002)
	b = tone([1976 * k for k in bell], [0.28, 0.16, 0.1, 0.06], 0.6, amps=[1, 0.4, 0.25, 0.15], detune=0.003)
	place(out, a * 0.6, 0.0)
	place(out, b * 0.75, 0.065)
	if head:
		c = tone([2637 * k for k in bell], [0.3, 0.18, 0.1, 0.06], 0.6, amps=[1, 0.4, 0.2, 0.1], detune=0.004)
		place(out, c * 0.55, 0.12)
	rise = sweep_noise(r, 0.12, lambda k: (2500 + 6000 * k, k**2), q=1.5)
	place(out, stereo(hp(rise, 2000)) * 0.25, 0.0)
	place(out, hit_tick(1) * 0.5, 0.0)
	out += reverb(out, 0.6, seed=51, damp=8000) * 0.12
	return master(fit(out, t_len, 0.55), -10.5, 0.85)


def damage(variant):
	"""You got hit: a muffled thud with a gritty edge. Felt more than heard."""
	r = np.random.default_rng(60 + variant)
	t = t_axis(0.22)
	thud = thump(130 + 15 * variant, 75, 0.02, 0.04, 2.5)
	dull = bp(r.normal(size=len(t)), 200, 900) * np.exp(-t / 0.035)
	grit = saturate(bp(r.normal(size=len(t)), 900, 2600) * np.exp(-t / 0.012), 3.0)
	out = np.zeros((len(t), 2))
	place(out, stereo(thud) * 0.6, 0.0)
	place(out, stereo(dull / peak(dull)) * 0.5, 0.0)
	place(out, stereo(grit / peak(grit)) * 0.3, 0.003)
	return master(fit(out, 0.22, 0.4), -14.0, 0.85)


def impact():
	r = np.random.default_rng(4)
	t = t_axis(0.18)
	body = lp(r.normal(size=len(t)), 1200) * np.exp(-t / 0.03)
	snap = hp(r.normal(size=len(t)), 4000) * np.exp(-t / 0.003)
	out = stereo(body / peak(body) + snap / peak(snap) * 0.5)
	return master(fit(out, 0.18, 0.5), -16.0, 0.85)


# Atlas ------------------------------------------------------------------------


def build_clips():
	"""name -> list of variant clips (stereo float arrays)."""
	clips = {}
	for name in GUNS:
		if name == "LeverThump":
			clips[name] = [disc_launch(v) for v in range(VARIANTS)]
		else:
			clips[name] = [gunshot(name, v) for v in range(VARIANTS)]
		clips[name + "_Far"] = [gunshot_far(name)]
		print(f"{name:16s} {VARIANTS} variants + far", flush=True)
	clips["BeamHum"] = [beam_hum()]
	clips["DryFire"] = [dry_fire()]
	clips["LowAmmo"] = [low_ammo()]
	clips["HitTick"] = [hit_tick(v) for v in range(2)]
	clips["HeadDing"] = [head_ding()]
	clips["Kill"] = [kill_sound(False)]
	clips["KillHead"] = [kill_sound(True)]
	clips["Damage"] = [damage(v) for v in range(2)]
	clips["Impact"] = [impact()]
	return clips


def pack(clips):
	pos = GAP
	regions = {}
	parts = [np.zeros((int(RATE * GAP), 2))]
	for name, variants in clips.items():
		regions[name] = []
		for clip in variants:
			regions[name].append({"start": round(pos, 3), "length": round(len(clip) / RATE, 3)})
			parts.append(clip)
			parts.append(np.zeros((int(RATE * GAP), 2)))
			pos += len(clip) / RATE + GAP
	return np.concatenate(parts), regions


def write_luau(regions):
	lines = [
		"--!strict",
		"-- Generated by tools/audio/build_sound_atlas.py. Do not edit by hand.",
		"-- Where each sound sits inside the atlas audio (seconds). Each name has",
		"-- one or more variants; the game picks one per play. \"<Gun>_Far\" is the",
		"-- version other players hear. Gunshots are layered from CC0 recordings",
		"-- (\"The Free Firearm Sound Library\", Ben Jaszczak et al.) and synthesized",
		"-- layers; foley and UI sounds are synthesized.",
		"",
		"export type Region = { start: number, length: number }",
		"",
		"local atlas: { [string]: { Region } } = {",
	]
	for name, variants in regions.items():
		vs = [f"{{ start = {r['start']}, length = {r['length']} }}" for r in variants]
		if len(vs) == 1:
			lines.append(f"\t{name} = {{ {vs[0]} }},")
		else:  # StyLua's layout, so the generated file passes stylua --check
			lines.append(f"\t{name} = {{")
			lines += [f"\t\t{v}," for v in vs]
			lines.append("\t},")
	lines += ["}", "", "return table.freeze(atlas)"]
	with open(OUT_LUAU, "w", newline="\n") as f:
		f.write("\n".join(lines) + "\n")


# Preview ----------------------------------------------------------------------

# (atlas name, game gun, seconds between shots, shots in the demo burst)
PREVIEW_GUNS = [
	("PPQ", "Byte", 0.16, 4), ("Revolver", "Root", 0.45, 3), ("Bersa", "Flicker", 0.09, 10),
	("Ruger22", "Mute", 0.18, 4), ("Mossberg", "Splinter", 0.3, 3), ("M1911", "Dual Boot", 0.085, 12),
	("SwedishK", "Bandwidth", 0.075, 14), ("PPSh", "Burst Buffer", 0.06, 6),
	("AR15", "Pulse", 0.07, 6), ("AK47Suppressed", "Bitrate", 0.095, 12), ("Marlin", "Overwrite", 0.115, 10),
	("SKS", "Checksum", 0.22, 4), ("AKBurst", "Overflow", 0.09, 14), ("PPShBurst", "Flood", 0.06, 20),
	("Springfield", "Long Poll", 1.1, 2), ("Tikka", "Handshake", 0.25, 3), ("Mosin", "Kernel", 1.5, 2),
	("Nova", "Hard Reset", 0.85, 2), ("Model12", "Crash", 0.28, 4),
	("LeverThump", "Loopback", 0.55, 3),
]


def preview(clips):
	"""An audition reel: each gun's variants, a burst with hit ticks, the far
	version; then feedback and foley. Mimics the runtime's pitch jitter."""
	rng = np.random.default_rng(9)
	reel = []

	def seg(seconds):
		return np.zeros((int(RATE * seconds), 2))

	for name, _label, interval, burst in PREVIEW_GUNS:
		vs = clips[name]
		s = seg(0.2 + len(vs) * 0.7 + burst * interval + 1.2 + 2.0)
		at = 0.2
		for v in vs:  # each variant on its own
			place(s, v, at)
			at += 0.7
		last = -1
		for i in range(burst):  # a burst the way the game plays it
			k = rng.integers(len(vs))
			while len(vs) > 1 and k == last:
				k = rng.integers(len(vs))
			last = k
			shot = resample(vs[k], 1 / (1 + rng.uniform(-0.03, 0.03)))
			place(s, shot * 0.8, at + i * interval)
			if i % 2 == 0:
				place(s, clips["HitTick"][i // 2 % 2] * 0.5, at + i * interval + 0.05)
		at += burst * interval + 0.15
		place(s, clips["Kill"][0] * 0.6, at)
		at += 1.0
		place(s, clips[name + "_Far"][0] * 0.7, at)  # as an enemy hears it
		reel.append(s)
	tail = seg(14)
	at = 0.3
	for n in ("HitTick", "HitTick", "HeadDing", "Kill", "KillHead", "Damage", "Damage", "DryFire", "LowAmmo"):
		v = clips[n][rng.integers(len(clips[n]))]
		place(tail, v, at)
		at += max(0.45, len(v) / RATE + 0.2)
	reel.append(tail[: int(RATE * (at + 0.5))])
	out = np.concatenate(reel)
	sf.write(OUT_PREVIEW, np.clip(out, -1, 1), RATE, subtype="PCM_16")
	print(f"preview {len(out) / RATE:.0f}s -> {OUT_PREVIEW}")


def main():
	ap = argparse.ArgumentParser()
	ap.add_argument("--preview", action="store_true", help="also render the audition reel")
	args = ap.parse_args()
	clips = build_clips()
	atlas, regions = pack(clips)
	sf.write(OUT_AUDIO, np.clip(atlas, -1, 1), RATE, subtype="PCM_16")
	with open(OUT_JSON, "w", newline="\n") as f:
		json.dump(regions, f, indent=1)
	write_luau(regions)
	print(f"atlas {len(atlas) / RATE:.1f}s, {os.path.getsize(OUT_AUDIO) / 1e6:.1f} MB -> {OUT_AUDIO}")
	if args.preview:
		preview(clips)


if __name__ == "__main__":
	main()
