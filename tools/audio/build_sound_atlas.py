"""Build the gun sound atlas: one audio file holding every gunshot and UI
sound, played in-game as slices (Sound.PlaybackRegion). One upload instead
of ~30 keeps us inside Open Cloud's monthly audio quota.

    python tools/audio/build_sound_atlas.py

Sources: "The Free Firearm Sound Library" (CC0, Ben Jaszczak et al.),
unpacked to art-source/audio/library/ (gitignored). UI sounds (hit marker,
headshot, kill, dry fire) and the Null beam hum are synthesized here.

Writes:
  art-source/audio/GunAtlas.wav            48 kHz mono 16-bit
  src/shared/Config/SoundAtlas.luau        name -> { start, length }
"""

import json
import os
import wave

import numpy as np

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
LIB = os.path.join(ROOT, "art-source", "audio", "library", "Prepared SFX Library")
OUT_WAV = os.path.join(ROOT, "art-source", "audio", "GunAtlas.wav")
OUT_LUAU = os.path.join(ROOT, "src", "shared", "Config", "SoundAtlas.luau")
RATE = 48000
SLOT = 2.0  # seconds per atlas slot

# name: (file, clip length s, pitch, lowpass Hz or None, gain)
SHOTS = {
	"PPQ": ("Walther PPQ/X_39P.wav", 0.9, 1.0, None, 1.0),
	"Revolver": ("Smith & Wesson 642/V_27P.wav", 1.1, 0.95, None, 1.0),
	"M1911": ("1911/A_42P.wav", 1.0, 1.0, None, 1.0),
	"Bersa": ("Bersa/F_47P.wav", 0.8, 1.08, None, 0.95),
	"Ruger22": ("Ruger Mark III/R_35P.wav", 0.7, 1.0, 2600, 0.8),
	"SwedishK": ("Carl Gustav M45/G_31P.wav", 0.9, 1.0, None, 0.95),
	"PPSh": ("PPSh/P_30P.wav", 0.9, 1.0, None, 0.95),
	"AR15": ("AR-15/D_32P.wav", 1.1, 1.0, None, 1.0),
	"AK47": ("AK-47/C_28P.wav", 1.2, 1.0, None, 1.0),
	"AK47Suppressed": ("AK-47/C_28P.wav", 0.8, 1.05, 1800, 0.75),
	"SKS": ("SKS/U_14P.wav", 1.2, 1.0, None, 1.0),
	"M1917": ("1917/B_24P.wav", 1.3, 0.97, None, 1.0),
	"Arisaka": ("Arisaka/E_25P.wav", 1.2, 0.9, None, 1.0),
	"Savage": ("Savage 10 .300 Blackout/T_27P.wav", 1.5, 1.0, None, 1.0),
	"Tikka": ("Tikka/W_29P.wav", 1.6, 1.0, None, 1.0),
	"Mosin": ("Mosin Nagant/M_21P.wav", 1.8, 0.95, None, 1.0),
	"Nova": ("Nova/O_21P.wav", 1.4, 1.0, None, 1.0),
	"Model12": ("Model 12/K_22P.wav", 1.3, 1.03, None, 1.0),
	"Mossberg": ("Mossberg/N_30P.wav", 1.2, 1.06, None, 0.95),
	"LeverThump": ("Model 1894/L_23P.wav", 1.0, 0.75, 1400, 0.9),
}


def read_wav(path):
	w = wave.open(path)
	ch, width, rate, n = w.getnchannels(), w.getsampwidth(), w.getframerate(), w.getnframes()
	raw = np.frombuffer(w.readframes(n), dtype=np.uint8)
	w.close()
	if width == 3:
		b = raw.reshape(-1, 3).astype(np.int32)
		v = b[:, 0] | (b[:, 1] << 8) | (b[:, 2] << 16)
		v = np.where(v & 0x800000, v - 0x1000000, v).astype(np.float64) / 8388608.0
	elif width == 2:
		v = np.frombuffer(raw.tobytes(), dtype=np.int16).astype(np.float64) / 32768.0
	else:
		raise ValueError(f"unsupported width {width}")
	v = v.reshape(-1, ch).mean(axis=1)
	return v, rate


def resample(x, rate_in, rate_out):
	n = int(round(len(x) * rate_out / rate_in))
	t = np.linspace(0, len(x) - 1, n)
	return np.interp(t, np.arange(len(x)), x)


def lowpass(x, rate, cutoff):
	spec = np.fft.rfft(x)
	f = np.fft.rfftfreq(len(x), 1 / rate)
	spec *= 1 / np.sqrt(1 + (f / cutoff) ** 4)  # gentle 2nd-order-ish rolloff
	return np.fft.irfft(spec, len(x))


def best_onset(x, rate, clip):
	"""Start of the cleanest single shot: a loud onset with silence after it."""
	win = max(1, int(rate * 0.002))
	env = np.convolve(np.abs(x), np.ones(win) / win, mode="same")
	thr = env.max() * 0.25
	above = env > thr
	onsets = []
	i = 0
	gap = int(rate * 0.35)
	while i < len(above):
		if above[i]:
			onsets.append(i)
			i += gap
		else:
			i += 1
	if not onsets:
		return 0
	# Prefer an onset whose next onset is far enough away (clean tail).
	for k, o in enumerate(onsets):
		nxt = onsets[k + 1] if k + 1 < len(onsets) else len(x)
		if (nxt - o) / rate >= clip + 0.1:
			return o
	return onsets[0]


def finish(x, length_s, fade_share=0.4):
	n = int(RATE * length_s)
	x = x[:n]
	if len(x) < n:
		x = np.pad(x, (0, n - len(x)))
	fade = int(n * fade_share)
	x[-fade:] *= np.linspace(1, 0, fade) ** 2
	x[: int(RATE * 0.002)] *= np.linspace(0, 1, int(RATE * 0.002))
	peak = np.abs(x).max()
	if peak > 0:
		x = x / peak * 0.95
	return x


def gunshot(spec):
	path, clip, pitch, lp, gain = spec
	x, rate = read_wav(os.path.join(LIB, path))
	start = max(0, best_onset(x, rate, clip) - int(rate * 0.004))
	seg = x[start : start + int(rate * (clip / pitch + 0.1))]
	if lp:
		seg = lowpass(seg, rate, lp)
	# Pitch by resampling (also changes length, which is what a pitch shift sounds like).
	seg = resample(seg, rate * pitch, RATE)
	return finish(seg, clip) * gain


# Synthesized UI sounds -------------------------------------------------------

def t_axis(seconds):
	return np.arange(int(RATE * seconds)) / RATE


def hit_tick():
	t = t_axis(0.09)
	noise = np.random.default_rng(1).normal(0, 1, len(t))
	click = lowpass(noise, RATE, 5000) * np.exp(-t * 90)
	ping = np.sin(2 * np.pi * 2300 * t) * np.exp(-t * 55)
	return finish(click * 0.6 + ping * 0.8, 0.09, 0.5) * 0.8


def head_ding():
	t = t_axis(0.45)
	tone = sum(a * np.sin(2 * np.pi * f * t) for f, a in ((1560, 1.0), (3120, 0.35), (4710, 0.18)))
	return finish(tone * np.exp(-t * 9), 0.45, 0.6) * 0.85


def kill_sound():
	t = t_axis(0.5)
	a = np.sin(2 * np.pi * 1180 * t) * np.exp(-t * 14)
	b = np.where(t > 0.07, np.sin(2 * np.pi * 1770 * (t - 0.07)) * np.exp(-(t - 0.07) * 10), 0)
	thump = np.sin(2 * np.pi * 70 * t) * np.exp(-t * 18)
	return finish(a * 0.6 + b * 0.8 + thump * 0.7, 0.5, 0.5) * 0.9


def dry_fire():
	t = t_axis(0.12)
	noise = np.random.default_rng(2).normal(0, 1, len(t))
	click = lowpass(noise, RATE, 3500) * np.exp(-t * 160)
	tick = np.sin(2 * np.pi * 900 * t) * np.exp(-t * 120)
	return finish(click + tick * 0.5, 0.12, 0.4) * 0.7


def beam_hum():
	# 1 s seamless loop: a buzzing low tone with a wobble (Null's beam).
	t = t_axis(1.0)
	base = 110  # whole cycles in 1 s, so it loops cleanly
	tone = sum(np.sin(2 * np.pi * base * k * t) / k for k in range(1, 9))
	wobble = 1 + 0.25 * np.sin(2 * np.pi * 6 * t)
	noise = lowpass(np.random.default_rng(3).normal(0, 1, len(t)), RATE, 2500) * 0.15
	x = (tone * wobble + noise)
	return x / np.abs(x).max() * 0.6


def impact_thud():
	t = t_axis(0.18)
	noise = np.random.default_rng(4).normal(0, 1, len(t))
	body = lowpass(noise, RATE, 900) * np.exp(-t * 35)
	crack = lowpass(noise, RATE, 6000) * np.exp(-t * 220) * 0.4
	return finish(body + crack, 0.18, 0.5) * 0.8


SYNTH = {
	"HitTick": hit_tick,
	"HeadDing": head_ding,
	"Kill": kill_sound,
	"DryFire": dry_fire,
	"BeamHum": beam_hum,
	"Impact": impact_thud,
}


def main():
	clips = {}
	for name, spec in SHOTS.items():
		clips[name] = gunshot(spec)
		print(f"{name:16s} {len(clips[name]) / RATE:.2f}s")
	for name, fn in SYNTH.items():
		clips[name] = fn()
		print(f"{name:16s} {len(clips[name]) / RATE:.2f}s (synth)")

	names = list(clips)
	total = np.zeros(int(RATE * SLOT * len(names)))
	regions = {}
	for i, name in enumerate(names):
		start = i * SLOT
		a = int(start * RATE)
		clip = clips[name]
		total[a : a + len(clip)] = clip
		regions[name] = {"start": round(start, 4), "length": round(len(clip) / RATE, 4)}

	pcm = (np.clip(total, -1, 1) * 32767).astype("<i2")
	with wave.open(OUT_WAV, "wb") as w:
		w.setnchannels(1)
		w.setsampwidth(2)
		w.setframerate(RATE)
		w.writeframes(pcm.tobytes())

	lines = [
		"--!strict",
		"-- Generated by tools/audio/build_sound_atlas.py. Do not edit by hand.",
		"-- Where each sound sits inside the atlas audio (seconds). Gunshots are",
		"-- CC0 recordings from \"The Free Firearm Sound Library\" (Ben Jaszczak et al.);",
		"-- UI sounds are synthesized.",
		"",
		"return table.freeze({",
	]
	for name in names:
		r = regions[name]
		lines.append(f"\t{name} = {{ start = {r['start']}, length = {r['length']} }},")
	lines.append("})")
	with open(OUT_LUAU, "w", newline="\n") as f:
		f.write("\n".join(lines) + "\n")
	print(f"atlas {len(total) / RATE:.1f}s, {os.path.getsize(OUT_WAV) / 1e6:.1f} MB -> {OUT_WAV}")
	json.dump(regions, open(OUT_WAV.replace(".wav", ".json"), "w"), indent=1)


if __name__ == "__main__":
	main()
