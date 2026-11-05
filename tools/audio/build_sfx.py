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
	# Map ambience (2026-11-05, Dockyard2 first). Beds are seamless loops (the
	# tail crossfaded into the head), stereo for the 2D beds, mono for the
	# positional ones; one-shots are cut whole with short fades.
	# Harbour bed: Baltimore harbour with distant industry (flood-mix).
	"AmbHarbour": [(413334, 45.0, 24.0, {"kind": "loop", "stereo": True, "hp": 40, "lufs_i": -24})],
	# Wind bed: wind through pines, its steadiest stretch (FunWithSound).
	"AmbWind": [(390740, 56.0, 24.0, {"kind": "loop", "stereo": True, "hp": 60, "lufs_i": -26})],
	# Water at the pier edges: boats at a dock, water lapping, flags (clif_creates).
	"AmbWater": [(254130, 1.0, 22.0, {"kind": "loop", "hp": 60, "lufs_i": -22})],
	# Indoors (the sheds): an abandoned warehouse's room tone (Kostrava).
	"AmbRoom": [(240895, 20.0, 24.0, {"kind": "loop", "stereo": True, "hp": 40, "lufs_i": -26})],
	# The crane's motor hum: a real motor recording (Nox_Sound), pitched down at runtime.
	"AmbHum": [(556369, 1.0, 8.0, {"kind": "loop", "hp": 40, "lufs_i": -24, "xfade": 1.0})],
	# Gulls: bursts from a flock (Soojay), and from short gull takes (Lydmakeren).
	"AmbGulls": [
		(462462, 7.5, 3.5, {"kind": "raw", "hp": 300, "lufs": -24}),
		(462462, 50.5, 3.5, {"kind": "raw", "hp": 300, "lufs": -24}),
		(510917, 4.5, 3.5, {"kind": "raw", "hp": 300, "lufs": -24}),
	],
	# Distant horns: a fog horn in San Francisco (tec_studio), a big boat horn (devy32).
	"AmbHorn": [
		(99630, 0.0, 7.8, {"kind": "raw", "hp": 50, "lufs": -22, "fade_out": 1.2}),
		(441223, 1.9, 5.6, {"kind": "raw", "hp": 50, "lufs": -22, "fade_out": 1.0}),
	],
	# Metal creaks on the container stacks (LoafDV, ingudios, NachtmahrTV).
	"AmbCreak": [
		(238289, 0.5, 2.6, {"kind": "raw", "hp": 80, "lufs": -24}),
		(119468, 0.1, 2.9, {"kind": "raw", "hp": 120, "lufs": -24}),
		(556714, 0.25, 3.2, {"kind": "raw", "hp": 60, "lufs": -24}),
	],
	# Rooftops2 (city block). City bed: a Brooklyn rooftop over traffic and an
	# elevated train, its steadiest stretch (SpliceSound).
	"AmbCity": [(369891, 649.0, 24.0, {"kind": "loop", "stereo": True, "hp": 40, "lufs_i": -24})],
	# A rooftop air-conditioning unit (timgormly), for the AC boxes.
	"AmbAC": [(148906, 4.0, 10.0, {"kind": "loop", "hp": 60, "lufs_i": -22, "xfade": 1.0})],
	# Distant sirens echoing off buildings (TRP, Toronto).
	"AmbSiren": [
		(568814, 5.5, 7.0, {"kind": "raw", "stereo": True, "hp": 120, "lufs": -26, "fade_out": 1.5}),
		(568814, 30.5, 7.0, {"kind": "raw", "stereo": True, "hp": 120, "lufs": -26, "fade_out": 1.5}),
	],
	# Car horns in the street below (keweldog, DeVern).
	"AmbCarHorn": [
		(182474, 1.2, 2.4, {"kind": "raw", "hp": 150, "lufs": -26, "fade_out": 0.5}),
		(349922, 0.8, 2.2, {"kind": "raw", "hp": 150, "lufs": -26, "fade_out": 0.5}),
	],
	# Pigeons: a male pigeon cooing (5ro4), and one flying off (Kinoton).
	"AmbPigeon": [
		(701282, 28.0, 2.8, {"kind": "raw", "hp": 200, "lufs": -24}),
		(701282, 22.5, 2.8, {"kind": "raw", "hp": 200, "lufs": -24}),
		(701282, 34.0, 2.8, {"kind": "raw", "hp": 200, "lufs": -24}),
	],
	"AmbFlap": [(689998, 0.4, 2.4, {"kind": "raw", "hp": 150, "lufs": -23, "fade_out": 0.6})],
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


def load_any(fid, stereo):
	path = os.path.join(DL, f"freesound-{fid}", f"{fid}.ogg")
	x, sr = sf.read(path, always_2d=True)
	if x.shape[1] == 1:
		x = np.repeat(x, 2, axis=1)
	if sr != RATE:
		x = signal.resample_poly(x, RATE, sr, axis=0)
	return x if stereo else x.mean(axis=1)


def loudness_i(y):
	"""Integrated loudness, ungated (BS.1770 K-weighting): fine for steady beds."""
	from analyze_audio import k_weight

	mono = y.mean(axis=1) if y.ndim == 2 else y
	k = k_weight(mono)
	return float(-0.691 + 10 * np.log10(np.mean(k * k) + 1e-12))


def take_special(fid, start, length, o):
	"""Seamless loops ("loop") and whole cuts ("raw")."""
	stereo = o.get("stereo", False)
	x = load_any(fid, stereo)
	if o.get("hp"):
		x = signal.sosfilt(signal.butter(2, o["hp"], "hp", fs=RATE, output="sos"), x, axis=0)
	s0 = int(start * RATE)
	n = int(length * RATE)
	if o["kind"] == "loop":
		xf = int(o.get("xfade", 2.0) * RATE)
		body = x[s0 : s0 + n + xf]
		y = body[xf : n + xf].copy()
		t = np.linspace(0, 1, xf)
		fin, fout = np.sqrt(t), np.sqrt(1 - t)
		if y.ndim == 2:
			fin, fout = fin[:, None], fout[:, None]
		# The last xf samples blend into the head, so the end runs on into
		# y[0] (= body[xf]) with no seam.
		y[-xf:] = body[n : n + xf] * fout + body[:xf] * fin
		y *= 10 ** ((o.get("lufs_i", -24) - loudness_i(y)) / 20)
	else:
		y = x[s0 : s0 + n].copy()
		fin = int(0.03 * RATE)
		fout = int(o.get("fade_out", 0.25) * RATE)
		ramp_in, ramp_out = np.linspace(0, 1, fin), np.linspace(1, 0, fout) ** 2
		if y.ndim == 2:
			ramp_in, ramp_out = ramp_in[:, None], ramp_out[:, None]
		y[:fin] *= ramp_in
		y[-fout:] *= ramp_out
		y *= 10 ** ((o.get("lufs", -22) - momentary_max(y if y.ndim == 1 else y.mean(axis=1))) / 20)
	# Peaks over -1 dBTP go through the lookahead limiter (the same gain on
	# both channels), not a whole-take gain cut: one gust mustn't turn the
	# whole bed down.
	def peak_db(v):
		return max(true_peak_db(v[:, c]) for c in range(v.shape[1])) if v.ndim == 2 else true_peak_db(v)

	if peak_db(y) > -1.0:
		if y.ndim == 2:
			lead = np.abs(y).max(axis=1)
			g = limit(lead) / np.maximum(lead, 1e-9)
			y = y * g[:, None]
		else:
			y = limit(y)
	return y, {
		"id": fid,
		"start": round(start, 3),
		"length": round(len(y) / RATE, 3),
		"peak_ms": 0.0,
		"lufs_m": round(loudness_i(y), 1),
		"true_peak": round(peak_db(y), 1),
	}


def take(fid, start, length, o):
	if o["kind"] in ("loop", "raw"):
		return take_special(fid, start, length, o)
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
	# Every slice starts on a whole millisecond (48 samples) and lasts a whole
	# number of them: SoundAtlas stores times to 1 ms, so a loop region lands
	# exactly on its audio (an off-by-24-samples region clicks at the seam).
	MS = RATE // 1000
	lead = int(RATE * GAP)
	lead += (-(len(base) + lead)) % MS
	parts = [base, np.zeros((lead, 2))]
	pos = (len(base) + lead) / RATE
	report = {}
	clips = {}
	for name, takes in TAKES.items():
		regions[name] = []
		clips[name] = []
		report[name] = []
		for fid, start, length, o in takes:
			y, info = take(fid, start, length, o)
			st = y if y.ndim == 2 else np.stack([y, y], axis=1)
			st = st[: len(st) - len(st) % MS]
			regions[name].append({"start": round(pos, 3), "length": round(len(st) / RATE, 3)})
			gap = int(RATE * GAP)
			gap += (-(len(st) + gap)) % MS
			parts += [st, np.zeros((gap, 2))]
			pos += (len(st) + gap) / RATE
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
				reel += [y if y.ndim == 1 else y.mean(axis=1), np.zeros(int(0.35 * RATE))]
			reel.append(np.zeros(int(0.6 * RATE)))
		sf.write(OUT_PREVIEW, np.clip(np.concatenate(reel), -1, 1), RATE, subtype="PCM_16")
		print("preview ->", OUT_PREVIEW)


if __name__ == "__main__":
	main()
