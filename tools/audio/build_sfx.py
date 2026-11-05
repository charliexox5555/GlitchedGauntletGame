"""Polish the picked CC0 recordings (knife, then the sound pass) and append
them to the gun atlas, so the game still loads ONE audio asset.

    python -I tools/audio/build_sfx.py             # GameAtlas.flac + tables
    python -I tools/audio/build_sfx.py --preview   # also an audition reel

Reads the uploaded gun atlas (art-source/audio/GunAtlas.flac + .json, made by
build_sound_atlas.py) unchanged, and writes it again with every take in TAKES
appended after its end: the gun and UI slices keep their exact times.

Each take is cut from its recording (art-source/audio/downloads/freesound-
<id>/<id>.ogg, fetched by fetch_audio.py; sources and licences in the vault
note "2026-11-05 Knife and Sound Pass"), then only polished: summed to mono,
the head trimmed to a few ms before the onset (whooshes keep their swell),
the tail cut where it falls 60 dB under the peak (or at the take's length)
with a fade, rumble high-passed, then normalised to a momentary-max loudness
(BS.1770, 400 ms; LihFolk lihfolk-sfx: -18 LUFS for one-shots, our gunshots
sit at -15 to -21) with a -1 dBTP limiter. No synthesis, no layering.

Writes:
  art-source/audio/GameAtlas.flac      48 kHz stereo 16-bit (uploaded as Sounds.ATLAS)
  art-source/audio/GameAtlas.json      name -> [{start, length}]
  src/shared/Config/SoundAtlas.luau    the same, for the game
  art-source/audio/SfxPreview.wav      --preview only (gitignored)
"""

import argparse
import json
import os
import sys

import numpy as np
import soundfile as sf
from scipy import signal

sys.path.insert(0, os.path.dirname(__file__))
from analyze_audio import momentary_max  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
DL = os.path.join(ROOT, "art-source", "audio", "downloads")
BASE_AUDIO = os.path.join(ROOT, "art-source", "audio", "GunAtlas.flac")
BASE_JSON = os.path.join(ROOT, "art-source", "audio", "GunAtlas.json")
OUT_AUDIO = os.path.join(ROOT, "art-source", "audio", "GameAtlas.flac")
OUT_JSON = os.path.join(ROOT, "art-source", "audio", "GameAtlas.json")
OUT_LUAU = os.path.join(ROOT, "src", "shared", "Config", "SoundAtlas.luau")
OUT_PREVIEW = os.path.join(ROOT, "art-source", "audio", "SfxPreview.wav")
RATE = 48000
GAP = 0.25

# name -> list of takes. A take: (freesound id, start s, max length s, options)
# options: kind "hit" (trim to the onset) or "swell" (keep the build-up),
# hp (Hz), lp (Hz), lufs (target), shelf (dB above 4 kHz).
H = {"kind": "hit"}
W = {"kind": "swell", "peak_at": 0.06}
WH = {"kind": "swell", "peak_at": 0.09}  # heavy swings: a longer build
TAKES = {
	# Knife --------------------------------------------------------------------
	# Draw: a knife pulled along a cheese slicer (Streety), a sword drawn from
	# a leather sheath (FunWithSound).
	"KnifeDraw": [(30248, 0.05, 0.55, {**W, "lufs": -21}), (417035, 0.02, 0.6, {**W, "lufs": -21})],
	# Light swings: qubodup's bamboo-stick swishes (one session, so they
	# round-robin cleanly) and a whip swish (snowflakes).
	"KnifeSwing": [
		(60007, 0.0, 0.32, {**W, "hp": 180}),
		(60013, 0.0, 0.36, {**W, "hp": 180}),
		(60006, 0.0, 0.38, {**W, "hp": 180}),
		(72190, 0.0, 0.32, {**W, "hp": 180}),
	],
	# Heavy: lower, longer swishes (a stick swung hard: Dalesome; a double
	# swoosh: martian; a low chop whoosh: dave.des).
	"KnifeSwingHeavy": [
		(352719, 0.0, 0.42, {**WH, "hp": 90}),
		(19312, 0.0, 0.5, {**WH, "hp": 90}),
		(127197, 0.0, 0.48, {**WH, "hp": 90}),
	],
	# Flesh: stabbing a cabbage (ihitokage x2, Mixedupmoviestuff).
	"KnifeHitBody": [
		(395365, 0.05, 0.34, {**H, "hp": 120}),
		(395373, 0.18, 0.34, {**H, "hp": 120}),
		(179222, 0.0, 0.38, {**H, "hp": 120}),
	],
	# Wood: a knife hitting wood (shtran's knife-throw session).
	"KnifeHitWood": [
		(531877, 0.08, 0.3, {**H, "hp": 90}),
		(531877, 0.57, 0.3, {**H, "hp": 90}),
		(531877, 1.76, 0.3, {**H, "hp": 90}),
	],
	# Stone / concrete: a metal axe on a concrete slab (dslrguide), a hatchet
	# on a rock (CamoMano), a metal plate on a stone oven (qubodup).
	"KnifeHitStone": [
		(321477, 0.0, 0.3, {**H, "hp": 120}),
		(431019, 0.02, 0.25, {**H, "hp": 120}),
		(145122, 3.31, 0.3, {**H, "hp": 120}),
	],
	# Metal: two kitchen knives clashing (spycrah), a knife on a steel
	# (Anthousai), a light blade hit (CogFireStudios).
	"KnifeHitMetal": [
		(471095, 0.97, 0.45, {**H, "hp": 150}),
		(336593, 0.02, 0.3, {**H, "hp": 150}),
		(547041, 0.0, 0.4, {**H, "hp": 150}),
	],
	# Inspect: a blade drawn across a steel to start (marcusgar), then the
	# flips: a real balisong clicking open and closed (supersound23).
	"KnifeInspect": [(360946, 0.06, 0.24, {**W, "hp": 200, "lufs": -22})],
	"KnifeFlip": [
		(431533, 1.79, 0.25, {**H, "hp": 250, "lufs": -21}),
		(431533, 4.13, 0.25, {**H, "hp": 250, "lufs": -21}),
		(431533, 6.61, 0.25, {**H, "hp": 250, "lufs": -21}),
	],
	# Sound pass ----------------------------------------------------------------
	# Hit confirm: two clinks of a glass (kbnevel), bright and short.
	"HitConfirm": [
		(119839, 0.14, 0.11, {**H, "hp": 800, "lufs": -20}),
		(119839, 1.62, 0.11, {**H, "hp": 800, "lufs": -20}),
	],
	# Headshot: a fork tapped on a wine glass (jmayoff), a spoon on a glass
	# candle holder (MashedTatoes2).
	"HeadConfirm": [
		(255156, 0.12, 0.38, {**H, "hp": 600, "lufs": -19}),
		(515643, 0.0, 0.3, {**H, "hp": 600, "lufs": -19}),
	],
	# Kill: a metal service bell (AlaskaRobotics). One take: a learned signature.
	"KillConfirm": [(221515, 0.26, 0.65, {**H, "hp": 400, "lufs": -18})],
	# Footsteps, one recording session per surface (Phil25: stone, metal, wood,
	# grass; Nox_Sound: mountain boots in snow).
	"StepConcrete": [(208103, t, 0.2, {**H, "hp": 150, "lufs": -26}) for t in (1.22, 3.99, 5.09, 6.17)],
	"StepMetal": [(208101, t, 0.25, {**H, "hp": 150, "lufs": -26}) for t in (12.52, 13.3, 14.11, 14.9, 15.68, 16.46)],
	"StepWood": [(208104, t, 0.25, {**H, "hp": 120, "lufs": -26}) for t in (4.69, 6.75, 7.9, 9.39, 10.65, 12.9)],
	"StepGrass": [(208102, t, 0.25, {**H, "hp": 120, "lufs": -27}) for t in (0.16, 1.19, 1.71, 2.17, 3.67)],
	"StepSnow": [(613849, t, 0.34, {**H, "hp": 100, "lufs": -25}) for t in (0.02, 1.06, 1.92, 2.78, 3.68, 5.52)],
	# Slide: a sneaker skid on wood (WhiteFire43), sliding on frozen asphalt
	# (Magdaadga).
	"SlideStart": [
		(641386, 1.74, 0.5, {**W, "hp": 150, "lufs": -22}),
		(420392, 24.84, 0.5, {**W, "hp": 150, "lufs": -22}),
		(420392, 2.04, 0.5, {**W, "hp": 150, "lufs": -22}),
	],
	# UI: a real click (JonnyRuss01; kwahmah_02).
	"UiClick": [
		(478197, 0.0, 0.08, {**H, "hp": 500, "lufs": -22}),
		(256116, 0.0, 0.08, {**H, "hp": 500, "lufs": -22}),
	],
}


def load(fid):
	path = os.path.join(DL, f"freesound-{fid}", f"{fid}.ogg")
	x, sr = sf.read(path, always_2d=True)
	x = x.mean(axis=1)
	if sr != RATE:
		x = signal.resample_poly(x, RATE, sr)
	return x


def env_db(x, ms=1.0):
	n = max(int(RATE * ms / 1000), 1)
	k = np.ones(n) / n
	return 20 * np.log10(np.sqrt(np.convolve(x * x, k, mode="same")) + 1e-9)


def true_peak_db(x):
	return float(20 * np.log10(np.abs(signal.resample_poly(x, 4, 1)).max() + 1e-12))


def limit(x, ceiling_db=-1.0, release=0.04):
	"""A simple peak limiter (lookahead 1 ms, 4x oversampled detection)."""
	ceil = 10 ** (ceiling_db / 20)
	os4 = np.abs(signal.resample_poly(x, 4, 1))[::4][: len(x)]
	need = np.minimum(1.0, ceil / np.maximum(os4, 1e-9))
	look = int(RATE * 0.001)
	need = np.minimum.reduce([np.roll(need, -k) for k in range(look + 1)])
	g = np.empty_like(need)
	cur = 1.0
	a = np.exp(-1 / (release * RATE))
	for i, v in enumerate(need):
		cur = v if v < cur else a * cur + (1 - a) * v
		g[i] = cur
	return x * g


def take(fid, start, length, o):
	x = load(fid)
	seg = x[int(start * RATE) : int((start + length + 0.05) * RATE)]
	if o.get("hp"):
		seg = signal.sosfilt(signal.butter(2, o["hp"], "hp", fs=RATE, output="sos"), seg)
	if o.get("lp"):
		seg = signal.sosfilt(signal.butter(2, o["lp"], "lp", fs=RATE, output="sos"), seg)
	e = env_db(seg)
	pk = int(e.argmax())
	top = e[pk]
	# Head: search back from the peak for where it was 30 dB (a hit) or
	# 40 dB (a swell) quieter. A hit keeps at most 12 ms before its peak (the
	# transient lands on the frame); a swell is cut or padded so its peak sits
	# `peak_at` seconds in, the same for every variant of a name, so the game
	# can time it to the blade.
	gate = top - (30 if o["kind"] == "hit" else 40)
	below = np.where(e[: pk + 1] < gate)[0]
	on = int(below[-1]) if len(below) else 0
	pad = 0
	if o["kind"] == "hit":
		on = max(on, pk - int(0.012 * RATE))
	else:
		want = int(o.get("peak_at", 0.06) * RATE)
		if pk - on > want:
			on = pk - want
		else:
			pad = want - (pk - on)
	# Tail: where it stays 60 dB under the peak, capped at the take's length.
	under = np.where(e[pk:] < top - 60)[0]
	end = pk + (int(under[0]) if len(under) else len(e) - pk)
	end = min(end, on + int(length * RATE))
	y = np.concatenate([np.zeros(pad), seg[on:end]])
	fin = min(int(0.002 * RATE), len(y) // 4)
	fout = min(int((0.04 if o["kind"] == "swell" else 0.03) * RATE), len(y) // 3)
	y[pad : pad + fin] *= np.linspace(0, 1, fin)
	y[-fout:] *= np.linspace(1, 0, fout) ** 2
	# Loudness, then the limiter; a short transient that the limiter pulled
	# under its target gets up to 4 dB more (limited again).
	target = o.get("lufs", -18.0)
	y *= 10 ** ((target - momentary_max(y)) / 20)
	if true_peak_db(y) > -1.0:
		y = limit(y)
		short = target - momentary_max(y)
		if short > 0.5:
			y = limit(y * 10 ** (min(short, 4.0) / 20))
	pk = pad + (pk - on)
	return y, {
		"id": fid,
		"start": round(start + on / RATE, 3),
		"length": round(len(y) / RATE, 3),
		"peak_ms": round(pk / RATE * 1000, 1),
		"lufs_m": round(momentary_max(y), 1),
		"true_peak": round(true_peak_db(y), 1),
	}


def write_luau(regions):
	lines = [
		"--!strict",
		"-- Generated by tools/audio/build_sfx.py (on top of build_sound_atlas.py's",
		"-- gun atlas). Do not edit by hand. Where each sound sits inside the atlas",
		"-- audio (seconds). Each name has one or more variants; the game picks one",
		"-- per play. \"<Gun>_Far\" is the version other players hear. Gunshots:",
		"-- CC0 recordings (\"The Free Firearm Sound Library\"), polished. Knife and",
		"-- sound-pass slices: CC0 Freesound recordings, polished (sources in the",
		"-- vault note \"2026-11-05 Knife and Sound Pass\"). The old feedback",
		"-- slices (HitTick, HeadDing, Kill, Damage, LowAmmo) are synthesized.",
		"",
		"export type Region = { start: number, length: number }",
		"",
		"local atlas: { [string]: { Region } } = {",
	]
	for name, variants in regions.items():
		vs = [f"{{ start = {r['start']}, length = {r['length']} }}" for r in variants]
		if len(vs) == 1:
			lines.append(f"\t{name} = {{ {vs[0]} }},")
		else:
			lines.append(f"\t{name} = {{")
			lines += [f"\t\t{v}," for v in vs]
			lines.append("\t},")
	lines += ["}", "", "return table.freeze(atlas)"]
	with open(OUT_LUAU, "w", newline="\n") as f:
		f.write("\n".join(lines) + "\n")


def main():
	ap = argparse.ArgumentParser()
	ap.add_argument("--preview", action="store_true")
	args = ap.parse_args()
	base, sr = sf.read(BASE_AUDIO, always_2d=True)
	assert sr == RATE
	regions = json.load(open(BASE_JSON))
	parts = [base, np.zeros((int(RATE * GAP), 2))]
	pos = len(base) / RATE + GAP
	report = {}
	clips = {}
	for name, takes in TAKES.items():
		regions[name] = []
		clips[name] = []
		report[name] = []
		for fid, start, length, o in takes:
			y, info = take(fid, start, length, o)
			st = np.stack([y, y], axis=1)
			regions[name].append({"start": round(pos, 3), "length": round(len(y) / RATE, 3)})
			parts += [st, np.zeros((int(RATE * GAP), 2))]
			pos += len(y) / RATE + GAP
			clips[name].append(y)
			report[name].append(info)
			print(
				f"{name:16s} {fid:>7} {info['length']:.2f}s peak {info['peak_ms']:5.1f}ms"
				f" {info['lufs_m']:6.1f} LUFS-M tp {info['true_peak']:5.1f}"
			)
	atlas = np.concatenate(parts)
	sf.write(OUT_AUDIO, np.clip(atlas, -1, 1), RATE, subtype="PCM_16")
	with open(OUT_JSON, "w", newline="\n") as f:
		json.dump(regions, f, indent=1)
	json.dump(report, open(os.path.join(ROOT, "art-source", "audio", "SfxTakes.json"), "w"), indent=1)
	write_luau(regions)
	print(f"atlas {len(atlas) / RATE:.1f}s, {os.path.getsize(OUT_AUDIO) / 1e6:.1f} MB -> {OUT_AUDIO}")
	if args.preview:
		reel = []
		for name, ys in clips.items():
			for y in ys:
				reel += [y, np.zeros(int(0.35 * RATE))]
			reel.append(np.zeros(int(0.6 * RATE)))
		sf.write(OUT_PREVIEW, np.clip(np.concatenate(reel), -1, 1), RATE, subtype="PCM_16")
		print("preview ->", OUT_PREVIEW)


if __name__ == "__main__":
	main()
