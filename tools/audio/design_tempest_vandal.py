"""Tempest-Strike Vandal sound set v2 (2026-11-22, owner: "I couldn't get a good
Vandal shot sound ... layer sounds together well ... work on Vandal sounds for
all the sounds I need"). Every cue the skin plays, built from real recordings
only (the project's gun-audio rule: Valorant-style designed punch, real pro
recordings layered, never synth):

  gun core   ProPack semi-auto rifle set (what the Vandal plays today), the
             Pole Position AKM 7.62x39 1 m mic (the Vandal's real-world gun)
             and the HK416 on-gun mic (the action), Sonniss GDC 2016 licence
  water      CC0 Freesound splashes, splats, swishes (art-source/audio/downloads)
  electric   CC0 Freesound discharge snaps, zaps and crackle

Layers are aligned on their onsets (0-2 ms after the core), each kept to its
own band (core: lows and body; water: high-passed 600 Hz+; electric: 2.5 kHz+;
only the core carries the sub), glued (design_gun_sfx.finish, the RIFLE
preset) and levelled against the stock shot (+0.8 dB: the skin must never
feel weaker). No reverb on shots or clicks.

    python -I tools/audio/design_tempest_vandal.py

Writes art-source/audio/tempest/vandal_v2/<cue>_NN.wav (48 kHz, 16-bit,
-1 dBTP; shots stereo, foley mono) and _reel.wav + _reel.txt: the stock shot,
the new shots (single taps, then sprays at the Vandal's fire rate), then
every handling cue. Nothing is uploaded until the owner approves.
"""

import json
import os
import sys

import numpy as np
import soundfile as sf

sys.path.insert(0, os.path.dirname(__file__))
import build_gun_sfx as B  # noqa: E402
import design_gun_sfx as D  # noqa: E402
from build_sound_atlas import compress, eq, hp, lp, resample, soft_clip, stereo, transient  # noqa: E402

ROOT = B.ROOT
RATE = B.RATE
PRO = os.path.join(ROOT, "art-source", "audio", "ProPack")
FS = os.path.join(ROOT, "art-source", "audio", "downloads")
OUT = os.path.join(ROOT, "art-source", "audio", "tempest", "vandal_v2")
A = "gun_semi_auto_rifle_"
LOUDER = 0.8  # dB over the stock shot's loudest 100 ms

_cache = {}


def _read(path):
	if path not in _cache:
		x, sr = sf.read(path, always_2d=True)
		x = x[:, :2] if x.shape[1] >= 2 else np.repeat(x, 2, axis=1)
		if sr != RATE:
			x = resample(x, sr / RATE) if False else _rs(x, sr)
		_cache[path] = x - x[:64].mean(axis=0)
	return _cache[path]


def _rs(x, sr):
	from scipy.signal import resample_poly

	g = np.gcd(RATE, sr)
	return resample_poly(x, RATE // g, sr // g, axis=0)


def pro(name):
	"""A ProPack raw file (standalone), stereo."""
	return _read(os.path.join(PRO, "standalone", name + ".wav"))


def stock(name):
	"""A ProPack audition slice: exactly what the game plays today."""
	for d in os.listdir(os.path.join(PRO, "audition")):
		p = os.path.join(PRO, "audition", d, name + ".wav")
		if os.path.exists(p):
			return _read(p)
	raise FileNotFoundError(name)


def fs(sid):
	return _read(os.path.join(FS, f"freesound-{sid}", f"{sid}.ogg"))


def onset(x, rel_db=-30.0):
	"""First sample within rel_db of the clip's peak."""
	m = np.abs(x).max(axis=1)
	thr = m.max() * 10 ** (rel_db / 20)
	return int(np.argmax(m > thr))


def seg(x, start, length, fin=0.0, fout=0.02, lo=None, hi=None, pitch=1.0, rel=None):
	"""A slice from `start` s (or from the first onset after it when rel is set)."""
	i = int(start * RATE)
	if rel is not None:
		i += onset(x[i : i + int(0.5 * RATE)], rel)
		i = max(0, i - int(0.001 * RATE))
	y = x[i : i + int(length * pitch * RATE) + 64].copy()
	if pitch != 1.0:
		y = resample(y, 1 / pitch)
	if lo:
		y = hp(y, lo, 2)
	if hi:
		y = lp(y, hi, 2)
	return B.fade(y, fin, min(fout, len(y) / RATE * 0.5))


def norm(y, gain_db=0.0):
	return y / (np.abs(y).max() + 1e-9) * 10 ** (gain_db / 20)


def stack(length, *layers):
	"""(seconds offset, clip) layers into one stereo buffer."""
	out = np.zeros((int(length * RATE), 2))
	for at, y in layers:
		i = int(at * RATE)
		n = min(len(y), len(out) - i)
		if n > 0:
			out[i : i + n] += stereo(y)[:n]
	return out


def aligned(core, *layers):
	"""Each (gain dB, clip, delay ms) layer starts `delay` ms after the core's onset."""
	c0 = onset(core)
	out = [(0.0, core)]
	for g, y, delay_ms in layers:
		o = onset(y)
		at = (c0 - o) / RATE + delay_ms / 1000
		if at < 0:
			y = y[int(-at * RATE) :]
			at = 0.0
		out.append((at, norm(y, g)))
	return out


# Sources ------------------------------------------------------------------------
# CC0 Freesound ids (ledger: vault 02 Art/Skins/TempestStrike/Tempest Audio.md)
WATER_SPLASHES = 207371  # Phil25 "Water Splashes": ~40 real splash transients
ELECTRICITY = 398274  # FlashTrauma "Electricity": 8 bright discharge snaps
SPLAT = (495118, 495117)  # nebulasnails "Wet Splat" 1, 2
SPLASH = 398032  # swordofkings128 "Splash"
TINY_SPLASH = 321490  # dslrguide
WATER_SWISH = 321489  # dslrguide
SQUISH = 737232  # qubodup "Short Water Squish"
WATER_SPLASH_Q = 737234  # qubodup "Water Splash"
SWIRL = 478722  # Joao_Janz "Water Swirl"
PIPE_WHOOSH = 855838  # Sadiquecat
OUT_OF_WATER = 389987  # morganveilleux "coming out of water - woosh"
SCHLORP = 557647  # Clagnar
BUBBLES = 683100  # florianreichel "multiple bubbles bursting"
ZAP = 512471  # michael_grinnell "Electric zap"
STUN = 264779  # AnthonyChan0 "Civilian Stun Gun"
ZAP_EGO = 536741  # egomassive "Zap"
CRACKLE = 582631  # ironcross32 "Long Crackle 04"
SLIDE_LOCK = 119494  # ingudios "Slide lock 1"
METAL_CLICK = 337865  # newagesoup "metal-click"
AR_RELOAD = 815879  # qubodup "Assault Rifle Reload"
LATCH = 481789  # Crinkem "Metallic latch release"
SWORD = 107589  # Qat "unsheath_sword"
LIGHTNING = 434359  # csengeri "Close lightning strike"


def splash_hits():
	"""The cleanest short, loud splash transients in WATER_SPLASHES (start s)."""
	x = fs(WATER_SPLASHES)
	m = np.abs(x).max(axis=1)
	w = int(0.004 * RATE)
	e = np.sqrt(np.convolve(m**2, np.ones(w) / w, "same"))
	peak = e.max()
	hits, i = [], 0
	while i < len(e) - 1:
		if e[i] > peak * 0.35:
			j = i + int(0.25 * RATE)
			hits.append((e[i : i + int(0.03 * RATE)].max(), i / RATE))
			i = j
		else:
			i += 1
	hits.sort(reverse=True)
	return [t for _, t in hits[:10]]


def zap_hits():
	return [0.168, 0.395, 1.202, 1.639, 2.506, 2.684, 2.91, 1.202]


def water_crack(k, length=0.085, gain=-11.0):
	t = splash_hits()[k % 10]
	y = seg(fs(WATER_SPLASHES), t - 0.01, length, fout=0.03, lo=650, rel=-24, pitch=0.94 + 0.03 * (k % 3))
	return (gain, y, 0.6)


def electric_snap(k, length=0.045, gain=-13.0):
	t = zap_hits()[k % 8]
	y = seg(fs(ELECTRICITY), t - 0.01, length, fout=0.02, lo=2500, rel=-20, pitch=1.0 + 0.04 * ((k * 3) % 4 - 1.5))
	return (gain, y, 1.2)


# Shots ---------------------------------------------------------------------------
def gun_core(k, base):
	"""The stock ProPack shot + the AKM's 7.62 crack + the HK416 action."""
	core = pro(base)
	akm = D.load("AKM_7.62x39mm_1m_left_on_ground")
	o, room = D.shots("AKM_7.62x39mm_1m_left_on_ground")[k % 3]
	ak = akm[o : o + int(0.26 * RATE)]
	ak = hp(lp(resample(ak, 1 / (0.97 - 0.01 * (k % 2))), 9000, 2), 110, 2)
	hk = D.load("HK_416_5.56mm_on_gun")
	o2, _ = D.shots("HK_416_5.56mm_on_gun")[k % 6]
	act = hp(hk[o2 : o2 + int(0.12 * RATE)], 1200, 2)
	return core, [(-5.5, B.fade(ak, 0, 0.08), 0.3), (-12.0, B.fade(act, 0, 0.05), 0.0)]


def fire(k, base=None, water_gain=-11.0, water_len=0.085, length=0.5, with_zap=None):
	base = base or f"{A}shot_0{k % 8 + 1}"
	core, gun = gun_core(k, base)
	core = core[: int(length * RATE)]
	layers = list(gun) + [water_crack(k, water_len, water_gain)]
	zap_on = with_zap if with_zap is not None else (k % 2 == 0)
	layers.append(electric_snap(k, gain=-13.0 if zap_on else -19.0))
	x = stack(length + 0.05, *aligned(core, *layers))[: int(length * RATE)]
	return B.fade(glue(x, TARGET), 0, 0.06)


# The glue for the shot (2026-11-22 v2): the RIFLE preset's 320 Hz cut and the
# high-passed layers left the first build 6 dB thin in the low mids against
# the stock shot, so: body kept, a dip at 1.2 kHz (honk), presence and punch.
GLUE_EQ = [("low", 90, 6.5), ("peak", 230, 1.0, 0.8), ("peak", 1300, -5.5, 0.7), ("peak", 3300, 3.0, 0.8), ("high", 8000, 3.5)]


def glue(x, target):
	from build_sound_atlas import tighten

	x = eq(x, GLUE_EQ)
	x = transient(x, 4.0)
	x = compress(x, -22, 4.0, 0.003, 0.08)
	x = soft_clip(x / (np.abs(x).max() + 1e-9) * 10 ** (1.6 / 20)) * 0.89
	x = tighten(x, 0.07, 0.2)
	x = B.fade(x, 0.001, len(x) / RATE * 0.3)
	return B.master_tp(x, target)


def fire_last():
	"""The emptying shot: the stock last-with-tail + the Tempest layers + a
	quiet power-down (the charge fizzling out, water draining) under the tail."""
	core = pro(f"{A}shot_00_last_with_tail_01")
	head = fire(0, base=f"{A}shot_00_last_with_tail_01", length=0.5)
	n = len(core)
	tail = core[int(0.5 * RATE) :]
	fizz = seg(fs(CRACKLE), 0.5, 0.9, fin=0.05, fout=0.4, lo=1800, hi=9000)
	drain = seg(fs(SCHLORP), 0.1, 0.8, fin=0.04, fout=0.3, lo=300, hi=6000, pitch=0.8)
	under = stack(1.4, (0.12, norm(fizz, -20)), (0.18, norm(drain, -18)))
	out = np.zeros((max(n, int(0.5 * RATE) + len(under)), 2))
	out[: len(head)] += head
	out[int(0.5 * RATE) : int(0.5 * RATE) + len(tail)] += tail * 10 ** (LEVEL_GAIN / 20)
	out[int(0.3 * RATE) : int(0.3 * RATE) + len(under)] += under * 10 ** (LEVEL_GAIN / 20)
	return B.tp_limit(B.fade(out, 0, 0.4))


def shot_tail():
	"""The room tail after every shot: the stock tail + a faint static shimmer."""
	core = stock(f"{A}shot_00_tail_only_01")
	shimmer = seg(fs(ELECTRICITY), 0.2, 1.6, fin=0.15, fout=0.8, lo=3500, hi=11000)
	x = core.copy()
	x[: len(shimmer)] += stereo(norm(shimmer, -22.0))[: len(x)] * np.abs(core).max()
	return B.tp_limit(B.fade(x, 0.02, 0.5))


def fire_far(k):
	"""What other players hear: the finished shot, darker and with its skin layers
	pulled back (a Vandal first)."""
	x = fire(k, water_gain=-15.0, with_zap=False)
	x = lp(x, 5000, 2)
	return B.master_tp(x, TARGET - 2.0)


# Handling ------------------------------------------------------------------------
def foley(layers, length, target=-14.0):
	x = stack(length, *layers)
	x = hp(x, 70, 2)
	x = compress(x, -20, 2.5, 0.004, 0.08)
	x = B.fade(x, 0, min(0.06, length * 0.3))
	return B.master_tp(x, target)


def first(x):
	return onset(x) / RATE


def dry_fire(k):
	click = pro(f"{A}dry_fire_0{k % 4 + 1}")
	z = seg(fs(ZAP), 0.11, 0.08, fout=0.05, lo=2000, pitch=1.0 + 0.05 * k)
	return foley(aligned(click[: int(0.3 * RATE)], (-10, z, 2.0)), 0.3, -19.5)


def mag_out(k):
	click = pro(f"{A}magazine_unload_0{k % 4 + 1}")
	burst = seg(fs(SPLASH if k % 2 == 0 else WATER_SPLASH_Q), 0.1, 0.35, fout=0.15, lo=500, rel=-24)
	fizz = seg(fs(CRACKLE), 0.55, 0.3, fout=0.15, lo=2200)
	x = click[: int(0.6 * RATE)]
	layers = aligned(x, (-4, burst, 0.5))
	layers.append((first(x) + 0.06, norm(fizz, -12)))
	return foley(layers, 0.6, -15.0)


def mag_form():
	gather = seg(fs(SCHLORP), 0.12, 0.45, fin=0.02, fout=0.02, lo=250)[::-1]
	pop = seg(fs(BUBBLES), 0.15, 0.08, fout=0.05, lo=400, rel=-20)
	rise = seg(fs(SPLASH), 0.1, 0.4, lo=600, rel=-24)[::-1]
	return foley([(0.0, norm(gather, -3)), (0.02, norm(rise, -8)), (0.43, norm(pop, -5))], 0.55, -18.0)


def mag_in(k):
	click = pro(f"{A}magazine_load_0{k % 5 + 1}")[: int(0.5 * RATE)]
	clack = seg(fs(SLIDE_LOCK), 0.84, 0.15, fout=0.06, lo=300, rel=-20)
	slap = seg(fs(SPLAT[k % 2]), 0.1, 0.18, fout=0.08, lo=350, rel=-24)
	zap = seg(fs(STUN), 0.11, 0.12, fout=0.08, lo=2200, pitch=1.06)
	layers = aligned(click, (-3, clack, 0.0), (-6, slap, 0.8))
	layers.append((first(click) + 0.025, norm(zap, -10)))
	return foley(layers, 0.5, -14.2)


def rack(k):
	cock = pro(f"{A}cock_0{k % 5 + 1}")
	chirp = seg(fs(ZAP_EGO), 0.12, 0.12, fout=0.06, lo=2000, pitch=1.25)
	# the forward stroke is the cock's loudest hit
	m = np.abs(cock).max(axis=1)
	fwd = int(np.argmax(m))
	n = min(len(cock), int(0.8 * RATE))
	return foley([(0.0, cock[:n]), (max(fwd / RATE - 0.002, 0), norm(chirp, -12))], 0.8, -15.0)


def draw():
	swish = seg(fs(WATER_SWISH), 0.1, 0.45, fout=0.15, lo=300)
	air = seg(fs(PIPE_WHOOSH), 0.0, 0.5, fin=0.05, fout=0.2, lo=200)
	shing = seg(fs(SWORD), 0.0, 0.5, lo=1500, rel=-24)
	return foley([(0.0, norm(swish, -2)), (0.03, norm(air, -8)), (0.32, norm(shing, -9))], 0.85, -17.0)


def draw_lock():
	click = seg(fs(METAL_CLICK), 0.35, 0.15, fout=0.06, lo=400, rel=-20)
	zap = seg(fs(ZAP), 0.11, 0.1, fout=0.06, lo=2000)
	splash = seg(fs(TINY_SPLASH), 0.43, 0.25, fout=0.12, lo=600, rel=-24)
	return foley(aligned(click, (-6, zap, 1.0), (-8, splash, 1.5)), 0.4, -14.5)


def inspect():
	swirl = seg(fs(SWIRL), 0.0, 0.9, fin=0.03, fout=0.3, lo=250)
	static = seg(fs(ELECTRICITY), 1.2, 0.5, fin=0.08, fout=0.3, lo=3000)
	sw = pro(f"{A}safety_switch_01")[: int(0.3 * RATE)]
	return foley([(0.0, norm(sw, -6)), (0.05, norm(swirl, -2)), (0.25, norm(static, -16))], 1.0, -16.0)


def inspect_roll():
	whoosh = seg(fs(OUT_OF_WATER), 0.0, 0.6, fin=0.02, fout=0.25, lo=200)
	air = seg(fs(PIPE_WHOOSH), 0.0, 0.5, fout=0.2, lo=300, pitch=1.15)
	crackle = seg(fs(CRACKLE), 0.55, 0.35, fin=0.05, fout=0.2, lo=3000)
	return foley([(0.0, norm(whoosh, -2)), (0.04, norm(air, -7)), (0.15, norm(crackle, -18))], 0.7, -16.5)


def inspect_catch():
	slap = seg(fs(SQUISH), 0.1, 0.25, fout=0.1, lo=300, rel=-24)
	click = pro(f"{A}safety_switch_02")[: int(0.25 * RATE)]
	spark = seg(fs(ZAP), 0.11, 0.07, fout=0.04, lo=2500, pitch=1.1)
	return foley(aligned(click, (-2, slap, 0.5), (-12, spark, 1.0)), 0.4, -14.5)


def aim_in():
	swish = seg(fs(WATER_SWISH), 0.1, 0.3, fout=0.12, lo=1200, pitch=1.15)
	return foley([(0.0, norm(swish, 0))], 0.32, -22.0)


def reload_spin():
	whoosh = seg(fs(OUT_OF_WATER), 0.0, 0.45, fout=0.2, lo=300, pitch=1.2)
	hum = seg(fs(ELECTRICITY), 2.5, 0.45, fin=0.1, fout=0.2, lo=2500)
	return foley([(0.0, norm(whoosh, -2)), (0.05, norm(hum, -16))], 0.55, -17.0)


def impact(k):
	splash = seg(fs((TINY_SPLASH, WATER_SPLASH_Q, SQUISH, SPLASH)[k % 4]), 0.1, 0.22, fout=0.1, lo=700, rel=-24)
	zap = seg(fs(ZAP), 0.11, 0.06, fout=0.04, lo=2500, pitch=1.0 + 0.06 * k)
	return foley(aligned(splash, (-8, zap, 0.5)), 0.3, -18.0)


# Build ---------------------------------------------------------------------------
TARGET = 0.0
LEVEL_GAIN = 0.0


def write(name, x, mono=False):
	y = x.mean(axis=1) if mono and x.ndim == 2 else x
	sf.write(os.path.join(OUT, name + ".wav"), y.astype(np.float32), RATE, subtype="PCM_16")


def main():
	global TARGET, LEVEL_GAIN
	os.makedirs(OUT, exist_ok=True)
	ref = [B.short_max(stock(f"{A}shot_0{i}")) for i in range(1, 9)]
	TARGET = float(np.mean(ref)) + LOUDER
	LEVEL_GAIN = 0.0
	clips = {}
	for k in range(8):
		clips[f"fire_{k + 1:02d}"] = fire(k)
	clips["fireFirst_01"] = fire(0, base=f"{A}shot_00_first_01", water_gain=-7.0, water_len=0.12, with_zap=True)
	clips["fireLast_01"] = fire_last()
	clips["tail_01"] = shot_tail()
	for k in range(4):
		clips[f"fireFar_{k + 1:02d}"] = fire_far(k)
	for k in range(3):
		clips[f"dryFire_{k + 1:02d}"] = dry_fire(k)
		clips[f"magOut_{k + 1:02d}"] = mag_out(k)
		clips[f"magIn_{k + 1:02d}"] = mag_in(k)
		clips[f"rack_{k + 1:02d}"] = rack(k)
	clips["magForm_01"] = mag_form()
	clips["draw_01"] = draw()
	clips["drawLock_01"] = draw_lock()
	clips["inspect_01"] = inspect()
	clips["inspectRoll_01"] = inspect_roll()
	clips["inspectCatch_01"] = inspect_catch()
	clips["aimIn_01"] = aim_in()
	clips["reloadSpin_01"] = reload_spin()
	for k in range(4):
		clips[f"impact_{k + 1:02d}"] = impact(k)
	shots = ("fire", "fireFirst", "fireLast", "tail", "fireFar")
	report = {}
	for name, x in clips.items():
		write(name, x, mono=not name.startswith(shots))
		report[name] = dict(len=round(len(x) / RATE, 3), short_max=round(B.short_max(x), 1), tp=round(B.tp_db(x), 2))
	reel(clips)
	json.dump(dict(target=round(TARGET, 2), stock=[round(r, 2) for r in ref], clips=report),
		open(os.path.join(OUT, "_levels.json"), "w"), indent=1)
	print("target", round(TARGET, 2), "stock", [round(r, 1) for r in ref])
	for n, r in report.items():
		print(f"  {n:16s} {r['len']:5.2f}s  loud {r['short_max']:6.1f}  tp {r['tp']:5.2f}")


def reel(clips):
	w = B.weapon_data()["Vandal"]
	fi = w["fireInterval"]
	out = np.zeros((int(RATE * 90), 2))
	cues, t = [], 0.5

	def put(x, at):
		i = int(at * RATE)
		out[i : i + len(x)] += stereo(x)

	def label(s):
		cues.append(f"{t:6.2f}  {s}")

	label("STOCK Vandal: 4 taps")
	for i in range(4):
		put(stock(f"{A}shot_0{i + 1}"), t + i * 0.45)
	t += 2.4
	label("NEW Tempest Vandal: 4 taps")
	for i in range(4):
		put(clips[f"fire_{i + 1:02d}"], t + i * 0.45)
	t += 2.4
	label("STOCK: 10-round spray")
	for i in range(10):
		x = stock(f"{A}shot_0{i % 8 + 1}")
		put(x[: int((fi + 0.02) * RATE)] if i < 9 else x, t + i * fi)
	put(stock(f"{A}shot_00_tail_only_01"), t + 9 * fi + 0.08)
	t += 10 * fi + 2.4
	label("NEW: 10-round spray (fireFirst, fire, tail)")
	for i in range(10):
		x = clips["fireFirst_01"] if i == 0 else clips[f"fire_{i % 8 + 1:02d}"]
		put(x[: int((fi + 0.02) * RATE)] if i < 9 else x, t + i * fi)
	put(clips["tail_01"], t + 9 * fi + 0.08)
	t += 10 * fi + 2.4
	label("NEW: last round (fireLast), then dry fire")
	put(clips["fireLast_01"], t)
	put(clips["dryFire_01"], t + 2.0)
	t += 3.0
	label("NEW: far (what others hear), 4 taps")
	for i in range(4):
		put(clips[f"fireFar_{i + 1:02d}"], t + i * 0.45)
	t += 2.6
	for name in ("draw_01", "drawLock_01", "aimIn_01", "magOut_01", "magForm_01", "magIn_01", "reloadSpin_01",
		"rack_01", "inspect_01", "inspectRoll_01", "inspectCatch_01", "impact_01", "impact_02"):
		label("NEW: " + name)
		put(clips[name], t)
		t += len(clips[name]) / RATE + 0.7
	out = out[: int(RATE * t)]
	out *= 0.98 / max(np.abs(out).max(), 0.98)
	sf.write(os.path.join(OUT, "_reel.wav"), out.astype(np.float32), RATE, subtype="PCM_16")
	with open(os.path.join(OUT, "_reel.txt"), "w", encoding="utf-8") as f:
		f.write("Tempest-Strike Vandal sound set v2: audition reel (times in seconds)\n\n" + "\n".join(cues) + "\n")


if __name__ == "__main__":
	main()
