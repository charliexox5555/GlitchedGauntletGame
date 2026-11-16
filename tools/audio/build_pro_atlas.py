"""Build the private weapon atlas from the licensed recordings.

    python -I tools/audio/build_pro_atlas.py --no-luau  # render for review before upload
    python -I tools/audio/build_pro_atlas.py --luau-only  # generate regions for the reviewed FLAC

Keep the original stereo, transient timing and full duration of every pack
take. Resample 96 -> 48 kHz, de-click discontinuities at file edges, and set
level with a constant gain shared by the takes in each family. The layered
knife, feedback and impacts are separate designed cues. Outputs with audio
stay under the ignored art-source/audio/ProPack directory.
"""

import argparse
import json
import os
import re
import subprocess
import sys

import numpy as np
import soundfile as sf
from scipy import signal

sys.path.insert(0, os.path.dirname(__file__))
from analyze_audio import k_weight  # noqa: E402
from build_sfx import true_peak_db  # noqa: E402

RATE = 48000
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
PACK = os.path.join(ROOT, "vault", "06 Assets", "NewGunSounds")
GUNS = os.path.join(PACK, "Guns")
BONUS = os.path.join(PACK, "ProSoundCollection_BonusSounds")
OUT = os.path.join(ROOT, "art-source", "audio", "ProPack")
OUT_AUDIO = os.path.join(OUT, "ProAtlas.flac")
OUT_JSON = os.path.join(OUT, "ProAtlas.json")
AUDITION = os.path.join(OUT, "audition", "v9")
OUT_LUAU = os.path.join(ROOT, "src", "shared", "Config", "GunAtlas.luau")
GAME_AUDIO = os.path.join(ROOT, "art-source", "audio", "GameAtlas.flac")
GAME_JSON = os.path.join(ROOT, "art-source", "audio", "GameAtlas.json")

GAP = 0.1  # s of silence between slices
CEILING = -1.0  # dBTP for foley and built cues
SHOT_CEILING = -3.0  # dBTP before runtime report trims and level jitter
EDGE_THRESHOLD = 10 ** (-70 / 20)
SHOT_FAMILIES = (
	"pistol_shot_silenced",
	"pistol_shot",
	"revolver_pistol_shot",
	"shotgun_shot",
	"rifle_sniper_shot",
	"rifle_shot",
	"submachine_auto_shot",
	"semi_auto_rifle_shot",
	"machinegun_auto_heavy_shot",
)
WHOOSH_PEAK = {"light": 0.06, "heavy": 0.09}  # Config/Animations KNIFE_FEEL whooshPeak

# Which pack files go in. Left out: the auto "preview" bursts (reference only),
# tank / cannon shots, ambiences, birds, explosions, radios, sci-fi blasters,
# Mod-type sounds (park for the Mod pass) and the announcer voice.
GUN_SKIP = re.compile(r"automatic_preview|tank_cannon|weapon_cannon")
BONUS_TAKE = re.compile(
	r"^(whoosh_swish|foley_cloth_light_fast_movement|punch_|metal_sheet_impacts|metal_small_movement"
	r"|wood_block_sticks|switch_button|foley_soldier_gear)"
)

FOLEY_TARGET = -15.0
QUIET_TARGET = -18.0  # safety switches, scope rings: small clicks stay small
QUIET = re.compile(r"safety_switch|scope_zoom|switch_button")
WHOOSH_TARGET = -14.0
HIT_TARGET = {"HitBody": -13.0, "HitHead": -10.5, "Kill": -11.0, "KillHead": -10.0, "Damage": -14.0}
IMPACT_TARGET = -14.0


def shot_family(name):
	for family in SHOT_FAMILIES:
		if name.startswith("gun_" + family + "_"):
			return family
	return None


def family_of(name):
	"""Files that play together share one gain: a gun's shots + first shot +
	tail; otherwise the take number is dropped (gun_pistol_remove_mag_01..06)."""
	fam = shot_family(name)
	if fam:
		return "shot:" + fam
	return re.sub(r"_\d+$", "", name)


def target_of(name):
	if QUIET.search(name):
		return QUIET_TARGET
	if name.startswith(("whoosh", "foley_cloth")):
		return WHOOSH_TARGET
	return FOLEY_TARGET


# Audio helpers -----------------------------------------------------------------
_cache = {}


def path_of(name):
	return os.path.join(GUNS if name.startswith(("gun_", "weapon_")) else BONUS, name + ".wav")


def load(name):
	if name not in _cache:
		x, sr = sf.read(path_of(name), always_2d=True)
		x = x[:, :2] if x.shape[1] >= 2 else np.repeat(x, 2, axis=1)
		if sr != RATE:
			x = signal.resample_poly(x, RATE, sr, axis=0)
		_cache[name] = x
	return _cache[name]


def mono(x):
	return x.mean(axis=1) if x.ndim == 2 else x


def fade(x, fin, fout):
	x = x.copy()
	a, b = int(RATE * fin), min(len(x), int(RATE * fout))
	if a:
		x[:a] *= (0.5 - 0.5 * np.cos(np.linspace(0, np.pi, a)))[:, None]
	if b:
		x[-b:] *= (0.5 + 0.5 * np.cos(np.linspace(0, np.pi, b)))[:, None]
	return x


def short_max(x, window=0.1):
	k = k_weight(mono(x))
	w = int(window * RATE)
	if len(k) < w:
		k = np.pad(k, (0, w - len(k)))
	c = np.concatenate([[0.0], np.cumsum(k * k)])
	return float(-0.691 + 10 * np.log10(max(((c[w:] - c[:-w]) / w).max(), 1e-12)))


def tp_db(x):
	return max(true_peak_db(x[:, 0]), true_peak_db(x[:, 1]))


def head(x, below=40.0, pre=0.002):
	m = np.abs(mono(x))
	i = int(np.argmax(m > m.max() * 10 ** (-below / 20)))
	return x[max(0, i - int(RATE * pre)) :]


def tail_trim(x, cap, below=55.0):
	x = x[: int(RATE * cap)]
	m = np.abs(mono(x))
	k = max(1, RATE // 200)
	env = np.convolve(m, np.ones(k) / k, mode="same")
	above = np.nonzero(env > env.max() * 10 ** (-below / 20))[0]
	end = min(len(x), int(above[-1]) + int(RATE * 0.03)) if len(above) else len(x)
	x = x[:end]
	return fade(x, 0, min(0.04, len(x) / RATE * 0.25))


def hp(x, f, order=2):
	sos = signal.butter(order, f, "high", fs=RATE, output="sos")
	return signal.sosfilt(sos, x, axis=0)


def lp(x, f, order=2):
	sos = signal.butter(order, f, "low", fs=RATE, output="sos")
	return signal.sosfilt(sos, x, axis=0)


def norm(x):
	return x / (np.abs(x).max() + 1e-9)


# The library --------------------------------------------------------------------
def library_names():
	names = []
	for fn in sorted(os.listdir(GUNS)):
		if fn.endswith(".wav") and not GUN_SKIP.search(fn):
			names.append(fn[:-4])
	for fn in sorted(os.listdir(BONUS)):
		if fn.endswith(".wav") and BONUS_TAKE.search(fn):
			names.append(fn[:-4])
	return names


def process_file(name):
	"""Keep the complete recording and smooth any edge that would click."""
	x = load(name)
	fin = 0.0005 if np.abs(x[0]).max() > EDGE_THRESHOLD else 0
	fout = 0.003 if np.abs(x[-1]).max() > EDGE_THRESHOLD else 0
	return fade(x, fin, fout) if fin or fout else x


def whoosh(name, kind):
	"""A swish placed so its envelope peak lands WHOOSH_PEAK[kind] s in (cut
	in front if it peaks later, silence in front if it peaks sooner)."""
	x = load(name)
	m = np.abs(mono(x))
	k = int(RATE * 0.02)
	env = np.convolve(m, np.ones(k) / k, mode="same")
	pk = int(np.argmax(env))
	want = int(RATE * WHOOSH_PEAK[kind])
	if pk >= want:
		y = fade(x[pk - want :], 0.02, 0)
	else:
		y = np.concatenate([np.zeros((want - pk, 2)), x])
	return tail_trim(y, 0.4 if kind == "light" else 0.5, below=45.0)


def mix(*layers):
	"""(take, gain dB re its own peak, delay s) layers; each take peak-normalised first."""
	n = max(int(RATE * d) + len(t) for t, _, d in layers)
	out = np.zeros((n, 2))
	for t, g, d in layers:
		i = int(RATE * d)
		out[i : i + len(t)] += norm(t) * 10 ** (g / 20)
	return out


def cut(name, length, hp_hz=None, lp_hz=None, start=0.0, below=40.0):
	x = head(load(name)[int(RATE * start) :], below=below, pre=0.001)
	x = x[: int(RATE * length)]
	if hp_hz:
		x = hp(x, hp_hz)
	if lp_hz:
		x = lp(x, lp_hz)
	return fade(x, 0.001, min(0.05, len(x) / RATE * 0.35))


def built_clips():
	"""name -> (variants, target). Knife whooshes and the layered hits."""
	out = {}
	cl = "foley_cloth_light_fast_movement_"
	# 2026-11-13 (owner): the knife uses the pack's whoosh_swish files, light
	# slashes the small ones, the heavy stab the high fast ones, each placed so
	# its peak lands on the strike. The cloth swishes stay as an alternative.
	ws = "whoosh_swish_"
	out["knife_whoosh"] = ([whoosh(ws + "small_0" + n, "light") for n in "1234"], WHOOSH_TARGET)
	out["knife_whoosh_heavy"] = ([whoosh(ws + "high_fast_0" + n, "heavy") for n in "1234"], WHOOSH_TARGET)
	out["knife_whoosh_cloth"] = ([whoosh(cl + n, "light") for n in ("02", "03", "10", "14")], WHOOSH_TARGET)
	out["knife_whoosh_cloth_heavy"] = ([whoosh(cl + n, "heavy") for n in ("12", "04", "05")], WHOOSH_TARGET)
	body = ["punch_general_body_impact_0" + str(i) for i in (2, 3, 5)]
	wet = ["punch_grit_wet_impact_0" + str(i) for i in (1, 4, 5)]
	slap = ["punch_slap_whack_hit_01", "punch_slap_whack_hit_02"]
	wood = ["wood_block_sticks_hit_clap_0" + str(i) for i in (1, 2, 3, 4)]
	sheet = ["metal_sheet_impacts_0" + str(i) for i in (1, 2, 3, 4, 5)]
	small = ["metal_small_movement_0" + str(i) for i in (1, 2, 3)]
	snap = cut(slap[0], 0.035, hp_hz=1500)
	# Body hit (your bullet lands): A a punch + a slap's snap; B the wet punches.
	out["hit_body_A"] = ([mix((cut(b, 0.16), 0, 0), (snap, -8, 0)) for b in body], HIT_TARGET["HitBody"])
	out["hit_body_B"] = ([cut(w, 0.18) for w in wet], HIT_TARGET["HitBody"])
	# Headshot: A the wood block's bright tonal "tock" over a punch; B a slap + a sheet-metal ring.
	out["hit_head_A"] = (
		[mix((cut(w, 0.25), 0, 0), (cut(body[k % 3], 0.14), -7, 0)) for k, w in enumerate(wood[:3])],
		HIT_TARGET["HitHead"],
	)
	out["hit_head_B"] = (
		[mix((cut(s, 0.2), 0, 0), (cut(sheet[0], 0.18, hp_hz=1500), -6, 0.002)) for s in slap],
		HIT_TARGET["HitHead"],
	)
	# Kill (the game climbs its pitch per kill): A a sheet-metal clang over a wet punch;
	# B the wood block's ring over a slap.
	out["kill_A"] = ([mix((cut(sheet[1], 0.7), 0, 0), (cut(wet[0], 0.25), -3, 0))], HIT_TARGET["Kill"])
	out["kill_B"] = ([mix((cut(wood[3], 0.4), 0, 0), (cut(slap[1], 0.22), -4, 0))], HIT_TARGET["Kill"])
	out["kill_head_A"] = (
		[mix((cut(sheet[1], 0.7), 0, 0), (cut(wet[0], 0.25), -3, 0), (cut(wood[0], 0.25), -4, 0.004))],
		HIT_TARGET["KillHead"],
	)
	# Damage taken: a muffled body thud.
	out["damage"] = ([cut("punch_general_body_impact_01", 0.25, lp_hz=1800)], HIT_TARGET["Damage"])
	# Bullet / blade on surfaces (short, layered).
	out["impact_hard"] = (
		[mix((cut(s, 0.14, hp_hz=700), 0, 0), (cut(small[k % 3], 0.09, hp_hz=2000), -12, 0.003)) for k, s in enumerate(slap * 2)][:3],
		IMPACT_TARGET,
	)
	out["impact_metal"] = ([cut(s, 0.35, hp_hz=300) for s in sheet[1:4]], IMPACT_TARGET)
	out["impact_wood"] = ([cut(w, 0.2, lp_hz=6000) for w in wood[1:4]], IMPACT_TARGET)
	out["impact_soft"] = ([cut(w, 0.18, lp_hz=2500) for w in wet], IMPACT_TARGET)
	return out


def level_family(takes, target, runtime_peak=0.0):
	"""One gain for the family: toward `target` (median of the takes' loudest
	100 ms), never over CEILING dBTP. Cap playback makeup at runtime_peak."""
	loud = float(np.median([short_max(t) for t in takes]))
	g = target - loud
	peak = max(tp_db(t) for t in takes)
	g = min(g, CEILING - 0.1 - peak)
	makeup = max(0.0, min(target - loud - g, runtime_peak - peak - g))
	return [t * 10 ** (g / 20) for t in takes], makeup


# Movement and the headshot (2026-11-13, owner) ------------------------------
# CC0 recordings from Freesound, fetched with tools/audio/fetch_audio.py (each
# sound page's licence checked; source.json beside each file; the ledger is in
# the vault note "02 Art/Sound Library Pick" §15). They live in
# art-source/audio/downloads (git-ignored) and are cut here into single takes.
DL = os.path.join(ROOT, "art-source", "audio", "downloads")
STEP_TARGET = -16.0
MOVE_TARGET = -15.0


def fs_load(fid):
	d = os.path.join(DL, f"freesound-{fid}")
	f = [os.path.join(d, n) for n in os.listdir(d) if not n.endswith(".json")][0]
	x, sr = sf.read(f, always_2d=True)
	x = x[:, :2] if x.shape[1] >= 2 else np.repeat(x, 2, axis=1)
	if sr != RATE:
		x = signal.resample_poly(x, RATE, sr, axis=0)
	return x - x[:64].mean(axis=0)


def steps_of(fid, count=6, length=0.28, hp_hz=60):
	"""The `count` most consistent single footfalls of a running recording:
	onsets (5 ms envelope peaks), each cut from 4 ms before to the next step
	(at most `length` s), spread across the file."""
	x = fs_load(fid)
	m = mono(x)
	hop = RATE // 200
	n = len(m) // hop
	e = 20 * np.log10(np.sqrt(np.mean(m[: n * hop].reshape(n, hop) ** 2, axis=1)) + 1e-9)
	pk, _ = signal.find_peaks(e, height=e.max() - 18, distance=40, prominence=8)
	if len(pk) == 0:
		return []
	med = float(np.median(e[pk]))
	good = [p for p in pk if abs(e[p] - med) < 3.0]
	if len(good) > count:
		good = [good[int(i)] for i in np.linspace(0, len(good) - 1, count)]
	out = []
	for i, p in enumerate(good):
		# back up from the envelope peak to the step's start (-24 dB)
		j = p
		while j > 0 and e[j - 1] > e[p] - 24 and p - j < 20:
			j -= 1
		a = max(0, j * hop - int(RATE * 0.004))
		nxt = [q for q in pk if q > p]
		b = min(a + int(RATE * length), (nxt[0] * hop - int(RATE * 0.02)) if nxt else len(m))
		seg = hp(x[a:b], hp_hz)
		out.append(fade(seg, 0.002, min(0.05, (b - a) / RATE * 0.3)))
	return out


def brightest(x, window=0.25):
	"""The `window` s with the most energy above 3 kHz (an unsheathe's ring)."""
	h = hp(x, 3000, 4)
	m = mono(h) ** 2
	w = int(RATE * window)
	c = np.concatenate([[0.0], np.cumsum(m)])
	i = int(np.argmax(c[w:] - c[:-w]))
	return x[max(0, i - int(RATE * 0.01)) : i + w]


def speed(x, rate):
	"""Faster and higher together (varispeed), like a sped-up recording."""
	return signal.resample(x, int(len(x) / rate), axis=0)


def movement_clips():
	out = {}

	def put(name, takes, target):
		lev, short = level_family([t for t in takes if len(t)], target)
		out[name] = (lev, short)

	put("step_concrete", steps_of("170505") + steps_of("151227", 2), STEP_TARGET)
	put("step_metal", steps_of("19310") + steps_of("786977", 2), STEP_TARGET)
	put("step_wood", steps_of("389658", 6, 0.22), STEP_TARGET)
	put("step_grass", steps_of("411148", 6, 0.24), STEP_TARGET)
	put("step_gravel", steps_of("750797", 6, 0.3), STEP_TARGET)
	# slide: a sneaker skid (its first 0.7 s) with the pack's fast cloth swell
	skid = fs_load("68247")
	m = mono(skid)
	hop = RATE // 200
	n = len(m) // hop
	e = 20 * np.log10(np.sqrt(np.mean(m[: n * hop].reshape(n, hop) ** 2, axis=1)) + 1e-9)
	pk, _ = signal.find_peaks(e, height=e.max() - 12, distance=300)
	cloth = cut("foley_cloth_light_fast_movement_04", 0.6)
	skids = []
	for p in pk[:3]:
		a = max(0, p * hop - int(RATE * 0.06))
		s = fade(hp(skid[a : a + int(RATE * 0.7)], 80), 0.004, 0.15)
		skids.append(mix((s, 0, 0), (cloth, -8, 0)))
	put("slide_skid", skids, MOVE_TARGET)
	# land: a stone landing, a heavy step under it, the pack's gear rattle
	landing = fs_load("422754")
	stomp = steps_of("170505", 3)
	gear = [cut("foley_soldier_gear_equipment_movement_grab_item_0" + k, 0.3) for k in "123"]
	put(
		"land",
		[mix((landing, 0, 0), (stomp[k], -4, 0.004), (gear[k], -10, 0.01)) for k in range(3)],
		MOVE_TARGET,
	)
	# jump: the pack's short cloth flicks
	put("jump", [cut("foley_cloth_light_fast_movement_" + k, 0.3) for k in ("13", "14", "15")], -18.0)
	# Headshot (owner: "high pitched metallic, like a knife swing, high pitch and
	# sped up", RIVALS / Valorant): a sword unsheathe's ring, sped up 1.5x, over
	# a sped-up fast whoosh. A/B/C = the three unsheathe recordings.
	whoosh_fast = [speed(cut("whoosh_swish_high_fast_0" + k, 0.25), 1.6) for k in "1234"]
	for letter, fid in (("A", "581594"), ("B", "320521"), ("C", "107589")):
		ring = speed(brightest(fs_load(fid), 0.3), 1.5)
		ring = fade(hp(ring, 1500), 0.002, 0.06)
		takes = [mix((ring, 0, 0), (whoosh_fast[k], -7, 0)) for k in range(3)]
		put("hit_head_shing_" + letter, takes, HIT_TARGET["HitHead"])
	# 2026-11-14 (owner: the shing is "too metallic, too sharp"): softer takes,
	# the unsheathe ring only 1.25x faster, low-passed at 5.5 kHz and well
	# under a sped-up whoosh and a short punch.
	ring_b = fade(lp(hp(speed(brightest(fs_load("320521"), 0.3), 1.25), 1200), 5500), 0.002, 0.08)
	ring_a = fade(lp(hp(speed(brightest(fs_load("581594"), 0.3), 1.25), 1200), 5500), 0.002, 0.08)
	whoosh_soft = [speed(cut("whoosh_swish_high_fast_0" + k, 0.25), 1.35) for k in "1234"]
	body = [cut("punch_general_body_impact_0" + k, 0.12) for k in "235"]
	put(
		"hit_head_soft_A",
		[mix((whoosh_soft[k], 0, 0), (ring_b, -9, 0.004), (body[k], -6, 0)) for k in range(3)],
		HIT_TARGET["HitHead"],
	)
	put(
		"hit_head_soft_B",
		[mix((whoosh_soft[k + 1], 0, 0), (ring_a, -12, 0.004), (body[k], -4, 0)) for k in range(3)],
		HIT_TARGET["HitHead"],
	)
	# 2026-11-14 (owner: the soft shing is "still too high pitched and annoying
	# ... not satisfying"): no ring at all. A slap slowed to 0.85x (lower) and
	# low-passed at 5 kHz over a wet crunch and a body thud (B: no slap, deeper).
	slaps = [lp(speed(cut(n, 0.2), 0.85), 5000) for n in ("punch_slap_whack_hit_01", "punch_slap_whack_hit_02")]
	grit = [cut("punch_grit_wet_impact_0" + k, 0.18) for k in "134"]
	thuds = [cut("punch_general_body_impact_0" + k, 0.14) for k in "235"]
	put(
		"hit_head_crunch",
		[mix((slaps[k % 2], 0, 0), (grit[k], -3, 0), (thuds[k], -4, 0)) for k in range(3)],
		HIT_TARGET["HitHead"],
	)
	put(
		"hit_head_crunch_B",
		[mix((grit[k], 0, 0), (thuds[k], -2, 0)) for k in range(3)],
		HIT_TARGET["HitHead"],
	)
	# Kill (owner: "a nice little positive kind of thing", RIVALS / Valorant):
	# a CC0 game pop over a short pack punch; the game climbs its pitch per kill.
	pop = fade(head(fs_load("669918"), pre=0.001)[: int(RATE * 0.3)], 0.001, 0.08)
	pop2 = fade(head(fs_load("878606"), pre=0.001)[: int(RATE * 0.5)], 0.001, 0.12)
	thump = cut("punch_general_body_impact_02", 0.14)
	put("kill_C", [mix((pop, 0, 0), (thump, -7, 0))], HIT_TARGET["Kill"])
	put("kill_D", [mix((pop2, 0, 0), (thump, -7, 0))], HIT_TARGET["Kill"])
	put("kill_head_C", [mix((pop, 0, 0), (thump, -7, 0), (ring_b, -14, 0.01))], HIT_TARGET["KillHead"])
	put("kill_head_D", [mix((pop2, 0, 0), (thump, -7, 0), (ring_b, -14, 0.01))], HIT_TARGET["KillHead"])
	return out


def build():
	families = {}
	for name in library_names():
		families.setdefault(family_of(name), []).append(name)

	clips, gains = {}, {}
	for family, names in families.items():
		raw = [process_file(name) for name in names]
		if family.startswith("shot:"):
			# Preserve the pack's shot-to-tail balance and relative take levels.
			peak = max(tp_db(take) for take in raw)
			gain = 10 ** ((SHOT_CEILING - peak) / 20)
			leveled, shortfall = [take * gain for take in raw], 0
		else:
			leveled, shortfall = level_family(raw, target_of(names[0]))
		for name, take in zip(names, leveled):
			clips[name] = [take]
			gains[name] = 10 ** (shortfall / 20)

	for name, (variants, target) in built_clips().items():
		leveled, shortfall = level_family(variants, target, runtime_peak=CEILING)
		clips[name] = leveled
		gains[name] = 10 ** (shortfall / 20)
	for name, (leveled, shortfall) in movement_clips().items():
		clips[name] = leveled
		gains[name] = 10 ** (shortfall / 20)
	return clips, gains


def pack(clips):
	gap = np.zeros((round(RATE * GAP), 2))
	parts, regions, cursor = [gap], {}, len(gap)
	for name, variants in clips.items():
		regions[name] = []
		for take in variants:
			regions[name].append({"start": cursor / RATE, "length": len(take) / RATE})
			parts.extend((take, gap))
			cursor += len(take) + len(gap)
	return np.concatenate(parts), regions


def lua_num(v):
	return f"{v:.6f}".rstrip("0").rstrip(".") or "0"


def write_luau(regions, gains):
	lines = [
		"--!strict",
		"-- Generated by tools/audio/build_pro_atlas.py. Do not edit by hand.",
		"-- Full-length gun atlas (Config/Sounds GUN_ATLAS): every gun-relevant file of the",
		"-- bought pro pack as its own slice, named by its file name, plus the built",
		"-- knife whooshes and hit / kill / impact sounds. Seconds into the audio;",
		"-- `gain`: capped playback makeup applied by AudioController.",
		"-- Config/GunSounds maps the guns to these names.",
		"",
		"export type Region = { start: number, length: number, gain: number? }",
		"",
		"local atlas: { [string]: { Region } } = {",
	]
	for name, rs in regions.items():
		g = gains.get(name, 1.0)
		extra = f", gain = {lua_num(g)}" if g > 1.005 else ""
		items = ", ".join(f"{{ start = {lua_num(r['start'])}, length = {lua_num(r['length'])}{extra} }}" for r in rs)
		key = name if re.match(r"^[A-Za-z_][A-Za-z0-9_]*$", name) else f'["{name}"]'
		lines.append(f"\t{key} = {{ {items} }},")
	lines += ["}", "", "return table.freeze(atlas)", ""]
	with open(OUT_LUAU, "w", encoding="utf-8", newline="\n") as f:
		f.write("\n".join(lines))
	subprocess.run(["stylua", OUT_LUAU], check=True, cwd=ROOT)


# Audition ------------------------------------------------------------------------
def write_wav(path, y):
	os.makedirs(os.path.dirname(path), exist_ok=True)
	sf.write(path, np.clip(y, -1, 1).astype(np.float32), RATE, subtype="PCM_16")


def category(name):
	if name.startswith(("step_", "slide_", "land", "jump")):
		return "01 movement (CC0 steps, slide, land, jump)"
	if name.startswith(("knife_", "hit_", "kill", "damage", "impact_")):
		return "00 built (knife, hits, impacts)"
	m = re.match(r"gun_(pistol_shot_silenced|pistol|revolver_pistol|rifle_sniper|semi_auto_rifle|rifle|shotgun|submachine_auto|machinegun_auto_heavy)", name)
	if m:
		kind = "shots" if "_shot" in name else "handling"
		return f"{m.group(1)} {kind}"
	return "bonus " + re.sub(r"_\d+$", "", name)


def audition(clips):
	for name, takes in clips.items():
		for k, take in enumerate(takes, 1):
			suffix = f"_v{k}" if len(takes) > 1 else ""
			write_wav(os.path.join(AUDITION, category(name), name + suffix + ".wav"), take)
	readme = [
		"Full-length gun atlas audition. Individual WAVs are the decoded atlas slices at baked level.",
		"Guns/ contains equip, inspect, ADS, shot sequences, dry fire and reloads for each weapon.",
		"Reels use the playback pitch and volume ranges and tail fades. They omit positional roll-off",
		"and SoundGroup effects. A single gain is applied to a reel if needed to retain headroom.",
	]
	with open(os.path.join(AUDITION, "README.txt"), "w", encoding="utf-8") as f:
		f.write("\n".join(readme) + "\n")


WEAPONS = os.path.join(ROOT, "src", "shared", "Config", "Weapons.luau")
LUNE = os.path.join(os.path.expanduser("~"), ".rokit", "tool-storage", "lune-org", "lune", "0.11.0", "lune.exe")
DUMP = os.path.join(ROOT, "tools", "audio", "dump_gun_sounds.luau")
# Config/Audio (Util/GunAudio): keep in step.
FIRST_SHOT_GAP = 0.12
TAIL_FADE = dict(share=0.8, min=0.03, max=0.12)
VOLUME_JITTER_DB = {"Gun": 0.75, "Foley": 1.5}
GROUP = {"Gun": 1.0, "Foley": 0.65}  # Config/Audio GROUP_VOLUME


def weapons():
	"""Config/Weapons: gun -> (fire interval, fire mode, magazine size, has ADS)."""
	text = open(WEAPONS, encoding="utf-8").read()
	out = {}
	for m in re.finditer(r"\n\t(\w+) = \{\n(.*?)\n\t\},", text, re.S):
		body = m.group(2)
		fi = re.search(r"\bfireInterval = ([0-9.]+)", body)
		mode = re.search(r'fireMode = "(\w+)"', body)
		mag = re.search(r"\bmagSize = ([0-9]+)", body)
		out[m.group(1)] = (
			float(fi.group(1)) if fi else 0.2,
			mode.group(1) if mode else "Semi",
			int(mag.group(1)) if mag else 0,
			"noAds = true" not in body,
		)
	return out


def mapping(guns):
	"""Config/GunSounds as the game sees it (run with Lune): gun -> slot -> {id, volume, pitch}."""
	r = subprocess.run([LUNE, "run", DUMP, *guns], cwd=ROOT, capture_output=True, text=True, check=True)
	return json.loads(r.stdout)


class Picker:
	"""AudioController's take picker: random, never the same take twice running."""

	def __init__(self, rng):
		self.rng = rng
		self.last = {}
		self.remaining = {}

	def take(self, clips, gains, sound, group="Foley"):
		names = sound["id"].split(":", 1)[1].split("|")
		pool = [(n, k) for n in names for k in range(len(clips.get(n, [])))]
		if not pool:
			return None
		key = sound["id"]
		bag = self.remaining.get(key)
		if not bag:
			bag = list(self.rng.permutation(len(pool)))
			if len(bag) > 1 and bag[-1] == self.last.get(key):
				bag[-1], bag[0] = bag[0], bag[-1]
			self.remaining[key] = bag
		i = bag.pop()
		self.last[key] = i
		n, k = pool[i]
		lo, hi = (sound.get("pitch") or [1, 1])[:2]
		pitch = lo + self.rng.random() * (hi - lo)
		jitter = self.rng.uniform(-1, 1) * VOLUME_JITTER_DB[group]
		level = sound["volume"] * gains.get(n, 1.0) * 10 ** (jitter / 20)
		v = clips[n][k]
		if abs(pitch - 1) > 1e-3:
			v = signal.resample(v, int(len(v) / pitch), axis=0)
		return v * level


def gun_reels(clips, gains):
	"""audition/Guns/<Gun>.wav: each gun played by the game's own logic
	(Util/GunAudio): equip, inspect, a tap, a 3-round burst, a long spray to
	the last round (automatic guns), dry fire, reload parts. Volumes, random
	pitch and level as in the game. <Gun> pack preview.wav: the pack's own
	automatic preview for that gun's family, to compare."""
	W = weapons()
	guns = [g for g in W if g != "Knife"] + ["Knife"]
	M = mapping(guns)
	rng = np.random.default_rng(13)
	cues = []
	for gun in guns:
		if gun not in M:
			continue
		slots = M[gun]
		fi, mode, mag, has_ads = W[gun]
		pick = Picker(rng)
		out = np.zeros((RATE * 60, 2))
		state = {"last": -1e9, "tail": None}  # last shot time, (start s, take) of the ringing tail
		t = 0.3
		marks = []

		def put(v, at, until=None, group="Foley"):
			if v is None:
				return
			i = int(at * RATE)
			seg = v
			if until is not None:
				n = max(1, int((until - at) * RATE))
				seg = v[:n].copy()
				fade_begin = max(0, n - round(RATE * fade_time))
				if fade_begin < len(seg):
					ramp = np.linspace(1, 0, n - fade_begin)
					seg[fade_begin:] *= ramp[: len(seg) - fade_begin, None]
			seg = seg * GROUP.get(group, 1.0)
			out[i : i + len(seg)] += seg[: max(0, len(out) - i)]

		fade_time = min(max(fi * TAIL_FADE["share"], TAIL_FADE["min"]), TAIL_FADE["max"])

		def shot(at, last_round=False):
			first = at - state["last"] > fi + FIRST_SHOT_GAP
			state["last"] = at
			if state["tail"] is not None:  # the next shot fades the ringing tail
				put(state["tail"][1], state["tail"][0], until=at + fade_time, group="Gun")
				state["tail"] = None
			use_last = last_round and "fireLast" in slots
			s = slots["fireLast"] if use_last else slots["fireFirst"] if first and "fireFirst" in slots else slots["fire"]
			put(pick.take(clips, gains, s, "Gun"), at, group="Gun")
			if "tail" in slots and not use_last:
				state["tail"] = (at, pick.take(clips, gains, slots["tail"], "Gun"))

		def flush():
			if state["tail"] is not None:
				put(state["tail"][1], state["tail"][0], group="Gun")
				state["tail"] = None

		def foley(slot, at):
			if slot in slots:
				put(pick.take(clips, gains, slots[slot]), at)

		marks.append(f"{t:5.1f} equip")
		foley("draw", t)
		foley("drawWhoosh", t)
		foley("rack", t + 0.45)
		t += 1.1
		marks.append(f"{t:5.1f} inspect")
		foley("inspect", t)
		t += 1.6
		if has_ads:
			marks.append(f"{t:5.1f} ADS in, out")
			foley("aimIn", t)
			foley("aimOut", t + 0.5)
			t += 1.1
		if gun == "Knife":
			marks.append(f"{t:5.1f} slashes 1-2-3, heavy, hits")
			for k in range(3):
				put(pick.take(clips, gains, slots["fire"], "Gun"), t + k * 0.45, group="Gun")
			t += 1.6
			put(pick.take(clips, gains, slots["heavy"], "Gun"), t, group="Gun")
			t += 0.6
			for slot in ("hitBody", "hitWall", "hitMetal", "hitWood", "hitSoft"):
				foley(slot, t)
				t += 0.6
		else:
			gap = max(fi, 2.9)
			marks.append(f"{t:5.1f} single taps")
			for k in range(3):
				shot(t + k * max(gap, 0.6))
				if mode in ("Pump", "Bolt"):
					foley("rack", t + k * max(gap, 0.6) + fi * 0.35)
			t += 3 * max(gap, 0.6) + 0.4
			flush()
			t += 1.0
			taps = min(mag, 12)
			marks.append(f"{t:5.1f} {taps} shots at full rate")
			for k in range(taps):
				shot(t + k * fi)
				if mode in ("Pump", "Bolt"):
					foley("rack", t + k * fi + fi * 0.35)
			t += taps * fi
			flush()
			t += 2.9
			if mode == "Auto" and mag > 0:
				n = mag
				marks.append(f"{t:5.1f} spray of {n} to the last round")
				for k in range(n):
					shot(t + k * fi, last_round=(k == n - 1))
				t += n * fi
				flush()
				t += 2.9
			marks.append(f"{t:5.1f} dry fire, reload")
			foley("dryFire", t)
			t += 0.6
			for slot in ("magOut", "open", "eject", "shellIn", "shellIn", "magIn", "close", "rack"):
				if slot in slots:
					foley(slot, t)
					t += 0.7
		reel = out[: int((t + 1.5) * RATE)]
		gain_db = min(0, CEILING - tp_db(reel))
		write_wav(os.path.join(AUDITION, "Guns", gun + ".wav"), reel * 10 ** (gain_db / 20))
		cues.append(f"{gun}: " + "; ".join(marks))
	# the pack's own automatic previews, beside the guns that use each family
	for fam, guns_of in (
		("gun_submachine_auto_shot_00_automatic_preview_01", ("Stinger", "Spectre")),
		("gun_semi_auto_rifle_shot_00_automatic_preview_01", ("Vandal", "Phantom", "Bulldog")),
		("gun_machinegun_auto_heavy_shot_00_automatic_preview_01", ("Ares", "Odin")),
	):
		x = load(fam)
		for g in guns_of:
			write_wav(os.path.join(AUDITION, "Guns", g + " pack preview.wav"), x * 10 ** (-6 / 20))
	with open(os.path.join(AUDITION, "Guns", "cues.txt"), "w", encoding="utf-8") as f:
		f.write("Seconds into each <Gun>.wav (game logic: Util/GunAudio)\n\n" + "\n".join(cues) + "\n")



def main():
	ap = argparse.ArgumentParser()
	mode = ap.add_mutually_exclusive_group()
	mode.add_argument("--no-luau", action="store_true")
	mode.add_argument("--luau-only", action="store_true")
	ap.add_argument("--no-audition", action="store_true")
	args = ap.parse_args()
	if args.luau_only:
		with open(OUT_JSON, encoding="utf-8") as f:
			meta = json.load(f)
		write_luau(meta["regions"], meta["gains"])
		return

	os.makedirs(OUT, exist_ok=True)
	clips, gains = build()
	audio, regions = pack(clips)
	sf.write(OUT_AUDIO, audio, RATE, subtype="PCM_16", compression_level=1.0)
	size = os.path.getsize(OUT_AUDIO)
	if size >= 20_000_000 or len(audio) >= RATE * 420:
		raise ValueError(f"Atlas exceeds Roblox size or duration limit: {size} bytes, {len(audio)/RATE:.1f} s")
	with open(OUT_JSON, "w", encoding="utf-8") as f:
		json.dump({"regions": regions, "gains": gains}, f, indent=1)
	if not args.no_luau:
		write_luau(regions, gains)

	print(f"atlas: {len(audio) / RATE:.1f} s, {size / 1e6:.2f} MB, {len(regions)} cues")
	if not args.no_audition:
		audition(clips)
		gun_reels(clips, gains)
		print(f"audition: {AUDITION}")


if __name__ == "__main__":
	main()
