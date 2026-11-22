"""Tempest-Strike line sound sets (2026-11-22). The owner approved the Vandal's
v2 set in game ("solid, except for the inspect"), then asked:
  1. the inspect: electric instead of water, timed to the inspect's key moments;
  2. the same standard for the other guns and the knife: crisp, in sync.

    python -I tools/audio/design_tempest_line.py

Same recipe and rules as tools/audio/design_tempest_vandal.py (real recordings
only, layers aligned on their onsets, one band per layer, glue, levelled to
each gun's own stock sounds +0.8 dB shots / +1 dB foley, no reverb on shots):

  inspect (every gun)  electric only: a charge swell at the start; a crackling
           whoosh for each snap of the move (its peak 0.15 s in, the timeline
           in Config/TempestProfiles fires it 0.15 s before the pose lands); an
           arc whirl for the roll; a zap and metal click for the catch; a small
           click and zap as it settles in the hold
  Stinger  ProPack SMG set + Pole Position HK MP7 (on-gun action, 1 m crack),
           G36C mag foley under the mag sounds
  Marshal  ProPack rifle set + Pole Position Remington 700 7.62 (1 m)
  Bucky    ProPack shotgun set + Pole Position SPAS-12 / Saiga-12 (1 m)
  Sheriff  ProPack revolver set + Pole Position S&W M66 .357 (1 m), S&W M29
           cylinder foley under open / close
  Katana   ProPack knife whooshes (peaks kept at the game's 0.06 / 0.09 s)
           with a crackle trail and a water whip; the Cleave adds a real
           lightning crack; hits with a zap; an unsheathe draw; the inspect's
           own electric timeline

Writes art-source/audio/tempest/line_v1/<Set>_<cue>_NN.wav (git-ignored: built
from licensed libraries) and _reel.wav + _reel.txt.
"""

import json
import os
import sys

import numpy as np
import soundfile as sf

sys.path.insert(0, os.path.dirname(__file__))
import build_gun_sfx as B  # noqa: E402
import design_gun_sfx as D  # noqa: E402
import design_tempest_vandal as V  # noqa: E402
from build_sound_atlas import hp, lp, resample, stereo  # noqa: E402

RATE = V.RATE
OUT = os.path.join(B.ROOT, "art-source", "audio", "tempest", "line_v1")
M, RF, SG, R, P = "gun_submachine_auto_", "gun_rifle_", "gun_shotgun_", "gun_revolver_pistol_", "gun_pistol_"
CRACKLE, ELECTRICITY, ZAP, STUN, ZAP_EGO, ARC = 582631, 398274, 512471, 264779, 536741, 210878
METAL_CLICK, SPLAT, TINY_SPLASH, SPLASH, SWISH, SWORD = 337865, (495118, 495117), 321490, 398032, 321489, 107589
LIGHTNING = 434359


def gdc(name):
	return D.load(name)


def shots_of(name):
	return D.shots(name)


def gdc_shot(name, k, length, lo=None, hi=None, pitch=1.0):
	x = gdc(name)
	found = shots_of(name)
	o, room = found[k % len(found)]
	y = x[o : o + min(int(length * pitch * RATE), room)]
	if pitch != 1.0:
		y = resample(y, 1 / pitch)
	if lo:
		y = hp(y, lo, 2)
	if hi:
		y = lp(y, hi, 2)
	return B.fade(y, 0, min(0.06, len(y) / RATE * 0.3))


def events(name, rel_db=-26.0, gap=0.25):
	"""Onsets (s) of the separate actions in a long foley take (GDC)."""
	x = gdc(name)
	m = np.abs(x).max(axis=1)
	w = int(0.005 * RATE)
	e = np.sqrt(np.convolve(m**2, np.ones(w) / w, "same"))
	thr = e.max() * 10 ** (rel_db / 20)
	out, i = [], 0
	while i < len(e):
		if e[i] > thr:
			out.append(i / RATE)
			i += int(gap * RATE)
		else:
			i += 1
	return out


# Shots ------------------------------------------------------------------------------
# 2026-11-22 v3 (owner: the shots sound "too close to the original ... more
# oomph ... sleek and satisfying"): every gun gets a real low thump (a steel
# bulkhead hit, low-passed: the sub punch), its skin layers ~3 dB up, a harder
# glue, +1.5 dB over its stock shot, and its EQ aimed further past stock on the
# lows and presence. Auto guns' shots are cut to one fire interval x 1.5 +
# 30 ms like the stock pack (`cut`), the tail carrying the decay: longer shots
# overlapped five deep in a spray and the voice limit (4 per sound) cut them
# off mid-sound, so sprays felt uneven.
THUMP = "sci-fi metal impact, steel bulkhead hit, low"

GUNS = {
	"Vandal": dict(
		core=V.A + "shot_0{}", takes=8, first=V.A + "shot_00_first_01", last=V.A + "shot_00_last_with_tail_01",
		tail=V.A + "shot_00_tail_only_01", length=0.5, cut=0.185, win=0.08,
		gun=[("AKM_7.62x39mm_1m_left_on_ground", 0.26, 110, 9000, -5.5, 0.97), ("HK_416_5.56mm_on_gun", 0.12, 1200, None, -8.0, 1.0)],
		water=-6.0, zap=(-8.5, -11.0), thump=-10.0,
	),
	"Stinger": dict(
		core=M + "shot_0{}", takes=9, first=M + "shot_00_first_01", last=M + "shot_00_last_with_tail_01",
		tail=M + "shot_00_tail_only_01", length=0.3, cut=0.143, win=0.05,
		gun=[("HK_MP7_4.6mm_on_gun", 0.12, 900, None, -7.0, 1.0), ("HK_MP7_4.6mm_1m_left", 0.2, 140, 9000, -5.0, 0.98)],
		water=-9.0, zap=(-10.0, -14.0), thump=-12.0,
	),
	"Marshal": dict(
		core=RF + "shot_0{}", takes=4, length=1.4,
		gun=[("Remington_700_7.62x51mm_1m_right", 0.5, 100, 9000, -5.0, 0.98)],
		water=-5.0, zap=(-8.0, -11.0), thump=-9.0,
	),
	"Bucky": dict(
		core=SG + "shot_0{}", takes=4, length=1.4,
		gun=[("SAIGA-12_12g_solid_slug_1m_left", 0.45, 90, 8000, -5.0, 1.0), ("SPAS-12_12g_solid_slug_1m_right", 0.3, 600, None, -10.0, 1.0)],
		water=-4.0, zap=(-9.0, -12.0), thump=-8.0,
	),
	"Sheriff": dict(
		core=R + "shot_0{}", takes=4, length=1.0,
		gun=[("Smith_&_Wesson_M66_.357_Magnum_1m_left", 0.35, 110, 9000, -5.0, 1.0)],
		water=-6.0, zap=(-8.5, -12.0), thump=-10.0,
	),
}


def target_of(spec):
	return float(np.mean([B.short_max(V.stock(spec["core"].format(i))) for i in range(1, spec["takes"] + 1)])) + V.LOUDER


# Each gun's glue EQ is matched to its own stock shot (the Vandal's body-forward
# EQ made these boomy: their cores already carry the lows). tune() measures the
# five bands against the stock takes and corrects, aiming a touch over stock on
# the lows and presence (punch and bite), level elsewhere.
BANDS = [(20, 150), (150, 600), (600, 3000), (3000, 8000), (8000, 16000)]
AIM = [2.0, 0.0, 0.0, 2.0, 0.5]


def profile(x, win):
	m = x.mean(axis=1)[: int(win * RATE)]
	sp = np.abs(np.fft.rfft(m * np.hanning(len(m)))) ** 2
	f = np.fft.rfftfreq(len(m), 1 / RATE)
	t = sp.sum()
	return np.array([10 * np.log10(sp[(f >= lo) & (f < hi)].sum() / t + 1e-12) for lo, hi in BANDS])


def eq_from(g):
	return [("low", 120, g[0]), ("peak", 350, g[1], 0.8), ("peak", 1500, g[2], 0.7), ("peak", 5000, g[3], 0.8), ("high", 9000, g[4])]


def tune(gun, passes=4):
	spec = GUNS[gun]
	win = spec.get("win", 0.25)
	ref = np.mean([profile(V.stock(spec["core"].format(i + 1)), win) for i in range(spec["takes"])], axis=0)
	gains = np.zeros(5)
	for _ in range(passes):
		spec["eq"] = eq_from(gains)
		got = np.mean([profile(gun_fire(gun, k), win) for k in range(3)], axis=0)
		gains = np.clip(gains + (ref + AIM - got) * 0.8, -9, 9)
	spec["eq"] = eq_from(gains)
	got = np.mean([profile(gun_fire(gun, k), win) for k in range(3)], axis=0)
	print(f"  {gun}: eq {np.round(gains, 1)}  vs stock {np.round(got - ref, 1)}")


def gun_fire(gun, k, base=None, water=None, length=None, zap_on=None, full=False):
	spec = GUNS[gun]
	V.GLUE_EQ = spec.get("eq", [])
	length = length or spec["length"]
	core = V.pro(base or spec["core"].format(k % spec["takes"] + 1))[: int(length * RATE)]
	layers = []
	for name, ln, lo, hi, gain, pitch in spec["gun"]:
		layers.append((gain, gdc_shot(name, k, ln, lo, hi, pitch - 0.01 * (k % 2)), 0.3))
	w = water if water is not None else spec["water"]
	layers.append(V.water_crack(k, 0.09, w))
	on = zap_on if zap_on is not None else (k % 2 == 0)
	layers.append(V.electric_snap(k, gain=spec["zap"][0] if on else spec["zap"][1]))
	layers.append((spec["thump"], thump(k), 0.0))
	x = V.stack(length + 0.05, *V.aligned(core, *layers))[: int(length * RATE)]
	x = B.fade(V.glue(x, spec["target"]), 0, min(0.06, length * 0.3) if length < 0.5 else length * 0.35)
	if spec.get("cut") and not full:
		x = B.fade(x[: int(spec["cut"] * RATE)], 0, 0.03)
	return x


def thump(k):
	"""The sub punch: a real steel bulkhead hit, low-passed to its thump."""
	x = gdc(THUMP)
	i = V.onset(x)
	y = x[max(i - int(0.001 * RATE), 0) : i + int(0.22 * RATE)]
	y = lp(resample(y, 1 / (0.95 + 0.04 * (k % 3))), 160, 2)
	return B.fade(y, 0, 0.1)


def gun_far(gun, k):
	spec = GUNS[gun]
	x = gun_fire(gun, k, water=spec["water"] - 6, zap_on=False, full=True)
	x = B.master_tp(lp(x, 5000, 2), spec["target"] - 2.0)
	if spec.get("cut"):
		x = B.fade(x[: int(spec["cut"] * RATE)], 0, 0.03)
	return x


def auto_last(gun):
	"""The emptying shot: the designed head on the stock last-with-tail, and a
	quiet power-down (the charge fizzling out) under its tail."""
	spec = GUNS[gun]
	head = gun_fire(gun, 0, base=spec["last"], length=0.3, full=True)
	core = V.pro(spec["last"])
	tail = core[int(0.3 * RATE) :]
	fizz = V.seg(V.fs(CRACKLE), 0.5, 0.9, fin=0.05, fout=0.4, lo=1800, hi=9000)
	under = V.stack(1.2, (0.1, V.norm(fizz, -20)))
	out = np.zeros((max(len(core), int(0.3 * RATE) + len(under)), 2))
	out[: len(head)] += head
	out[int(0.3 * RATE) : int(0.3 * RATE) + len(tail)] += tail
	out[int(0.25 * RATE) : int(0.25 * RATE) + len(under)] += under
	return B.tp_limit(B.fade(out, 0, 0.4))


def auto_tail(gun):
	core = V.stock(GUNS[gun]["tail"])
	shimmer = V.seg(V.fs(ELECTRICITY), 0.2, 1.4, fin=0.15, fout=0.7, lo=3500, hi=11000)
	x = core.copy()
	x[: len(shimmer)] += stereo(V.norm(shimmer, -22.0))[: len(x)] * np.abs(core).max()
	return B.tp_limit(B.fade(x, 0.02, 0.5))


# Handling -----------------------------------------------------------------------------
def level_of(name):
	"""The stock slice's loudest 100 ms + 1 dB (the raw take when it has no slice)."""
	try:
		return B.short_max(V.stock(name)) + 1.0
	except FileNotFoundError:
		return B.short_max(V.pro(name)) + 1.0


def mech(base, extra, length):
	"""A stock handling take + layers (each (gain, clip, delay ms) aligned on it)."""
	x = V.pro(base)[: int(length * RATE)]
	return V.foley(V.aligned(x, *extra), length, level_of(base))


def splash_small(k):
	return V.seg(V.fs((TINY_SPLASH, 737234, 737232, SPLASH)[k % 4]), 0.1, 0.2, fout=0.1, lo=700, rel=-24)


def zap_small(k, length=0.08, lo=2200):
	return V.seg(V.fs(ZAP), 0.11, length, fout=0.05, lo=lo, pitch=1.0 + 0.05 * (k % 3))


def chirp(k):
	return V.seg(V.fs(ZAP_EGO), 0.12, 0.12, fout=0.06, lo=2000, pitch=1.2 + 0.05 * (k % 2))


def mag_out(base, k):
	burst = V.seg(V.fs(SPLASH if k % 2 == 0 else 737234), 0.1, 0.35, fout=0.15, lo=500, rel=-24)
	return mech(base, [(-4, burst, 0.5), (-13, V.seg(V.fs(CRACKLE), 0.55, 0.3, fout=0.15, lo=2200), 60.0)], 0.6)


def mag_in(base, k):
	clack = V.seg(V.fs(119494), 0.84, 0.15, fout=0.06, lo=300, rel=-20)
	slap = V.seg(V.fs(SPLAT[k % 2]), 0.1, 0.18, fout=0.08, lo=350, rel=-24)
	zap = V.seg(V.fs(STUN), 0.11, 0.12, fout=0.08, lo=2200, pitch=1.06)
	return mech(base, [(-3, clack, 0.0), (-6, slap, 0.8), (-10, zap, 25.0)], 0.5)


def rack(base, k, length=0.8):
	x = V.pro(base)[: int(length * RATE)]
	fwd = int(np.argmax(np.abs(x).max(axis=1)))
	layers = [(0.0, x), (max(fwd / RATE - 0.002, 0), V.norm(chirp(k), -12))]
	return V.foley(layers, length, level_of(base))


def dry(base, k):
	return mech(base, [(-10, zap_small(k), 2.0)], 0.3)


def shell_in(base, k):
	return mech(base, [(-8, splash_small(k), 1.0), (-14, zap_small(k, 0.05, 3000), 3.0)], 0.4)


def cyl(base, k, foley_name, water_gain, zap_gain):
	"""A cylinder open / close: the stock take, a real S&W M29 action under it, water, a zap."""
	ev = events(foley_name)
	t = ev[(2 * k + (0 if "open" in base else 1)) % len(ev)]
	real = V.seg(gdc(foley_name), max(t - 0.005, 0), 0.25, fout=0.1, lo=250)
	return mech(base, [(-6, real, 0.0), (water_gain, splash_small(k), 1.0), (zap_gain, zap_small(k), 1.5)], 0.45)


def eject(base, k):
	drops = V.seg(V.fs(SPLASH), 0.2, 0.4, fout=0.2, lo=900, rel=-24)
	return mech(base, [(-7, drops, 5.0)], 0.5)


def g36_mag(base, k, out):
	ev = events("Heckler_&_Koch_G36C_5.56mm_foley")
	t = ev[(2 * k + (0 if out else 1)) % len(ev)]
	real = V.seg(gdc("Heckler_&_Koch_G36C_5.56mm_foley"), max(t - 0.005, 0), 0.3, fout=0.1, lo=200)
	clip = mag_out(base, k) if out else mag_in(base, k)
	x = V.stack(len(clip) / RATE, *V.aligned(clip, (-8, real, 0.0)))
	return B.master_tp(x, level_of(base))


# Inspect (electric) -------------------------------------------------------------------
SNAP_PEAK = 0.15  # s into an inspectSnap file where its whoosh peaks


def shaped(x, env_src):
	"""x following env_src's loudness (a crackle riding a whoosh's swell)."""
	m = np.abs(env_src).max(axis=1) if env_src.ndim == 2 else np.abs(env_src)
	w = int(0.01 * RATE)
	e = np.convolve(m, np.ones(w) / w, "same")
	e = e / (e.max() + 1e-9)
	n = min(len(x), len(e))
	y = x[:n].copy()
	y *= e[:n, None] if y.ndim == 2 else e[:n]
	return y


def insp_start():
	ff = V.seg(gdc("CK_Force_Field_Loop"), 2.0, 0.9, fin=0.3, fout=0.35, lo=250)
	hum = V.seg(V.fs(ELECTRICITY), 2.4, 0.8, fin=0.2, fout=0.3, lo=2500)
	tick = V.seg(V.fs(CRACKLE), 0.12, 0.08, fout=0.05, lo=2500)
	return V.foley([(0.0, V.norm(ff, -2)), (0.08, V.norm(hum, -12)), (0.02, V.norm(tick, -14))], 0.95, -18.0)


def insp_snap(k):
	w = gdc("Whoosh_Rod_Pole")
	pk = 0.23
	whoosh = V.seg(w, pk - SNAP_PEAK, 0.4, fout=0.15, lo=300, pitch=1.0 + 0.06 * (k % 2))
	crackle = V.seg(V.fs(CRACKLE), 0.4 - SNAP_PEAK, 0.4, fout=0.15, lo=2200)
	crackle = shaped(stereo(crackle), stereo(whoosh))
	zap = zap_small(k, 0.07)
	return V.foley([(0.0, V.norm(whoosh, -3)), (0.0, V.norm(crackle, -6)), (SNAP_PEAK - 0.004, V.norm(zap, -9))], 0.45, -17.0)


def insp_roll():
	pass_by = V.seg(gdc("Whoosh_ShaverPassBy"), 0.6, 1.9, fin=0.05, fout=0.3, lo=200, pitch=1.9)
	arc = V.seg(V.fs(ARC), 1.0, 0.9, fin=0.1, fout=0.3, lo=1500)
	arc = shaped(stereo(arc), stereo(pass_by))
	return V.foley([(0.0, V.norm(pass_by, -2)), (0.0, V.norm(arc, -7))], 1.0, -16.5)


def insp_catch(k=0):
	click = V.seg(V.fs(METAL_CLICK), 0.35, 0.15, fout=0.06, lo=400, rel=-20)
	zap = zap_small(k, 0.1, 2000)
	spark = V.seg(V.fs(ELECTRICITY), 0.16, 0.05, fout=0.03, lo=3000)
	return V.foley(V.aligned(click, (-3, zap, 0.5), (-9, spark, 1.0)), 0.4, -15.0)


def insp_settle():
	click = V.seg(gdc("light_switch_019"), 0.0, 0.15, fout=0.06, lo=300, rel=-24)
	zap = zap_small(1, 0.05, 3000)
	return V.foley(V.aligned(click, (-12, zap, 1.0)), 0.3, -19.0)


# Katana ---------------------------------------------------------------------------------
def pro_peak(name):
	x = V.pro(name)
	return int(np.argmax(np.abs(x).max(axis=1))) / RATE


def katana_swing(k, heavy=False):
	base = ("knife_whoosh_heavy-0{}" if heavy else "knife_whoosh-0{}").format(k % 4 + 1)
	x = V.pro(base)
	want = 0.09 if heavy else 0.06  # Animations.KNIFE_FEEL.whooshPeak: the strike lands on it
	pk = pro_peak(base)
	start = max(pk - want, 0)
	core = x[int(start * RATE) : int((start + (0.8 if heavy else 0.5)) * RATE)]
	crackle = V.seg(V.fs(CRACKLE), 0.4 - want, 0.45, fout=0.2, lo=2400)
	crackle = shaped(stereo(crackle), core)
	whip = V.seg(gdc("Swoosh_Rope_Whip"), 0.14 - want, 0.3, fout=0.12, lo=700)
	layers = [(0.0, core), (0.0, V.norm(crackle, -9)), (0.0, V.norm(whip, -12))]
	if heavy:
		ev = [t for t in (5.429, 4.662)]
		# owner 2026-11-22: v2 "cuts off too early", v3 (2.4 s at -7) "a bit too
		# much": a ~1.1 s ring that fades out, well under the swing (-13)
		crack = V.seg(V.fs(LIGHTNING), ev[k % 2] - 0.004, 1.1, fout=0.6, lo=80, hi=6500)
		layers.append((want, V.norm(crack, -13)))
		layers.append((want, V.norm(V.seg(V.fs(SPLASH), 0.1, 0.4, fout=0.2, lo=400, rel=-24), -10)))
	length = 1.3 if heavy else 0.5
	x = V.foley(layers, length, B.short_max(core) + 1.5)
	# keep the peak where the game expects it
	return x


def katana_hit(k):
	base = f"punch_grit_wet_impact_0{k % 5 + 1}"
	return mech(base, [(-9, zap_small(k, 0.1, 2000), 1.0), (-8, V.seg(V.fs(SPLAT[k % 2]), 0.1, 0.2, fout=0.1, lo=400, rel=-24), 0.5)], 0.45)


def katana_wall(k):
	base = f"impact_hard-0{k % 3 + 1}"
	return mech(base, [(-10, zap_small(k, 0.08, 2200), 1.0), (-10, splash_small(k), 0.5)], 0.4)


def katana_draw():
	shing = V.seg(V.fs(SWORD), 0.0, 0.55, lo=900, rel=-24)
	zap = V.seg(V.fs(ZAP_EGO), 0.12, 0.25, fout=0.12, lo=1800)
	swish = V.seg(V.fs(SWISH), 0.1, 0.35, fout=0.12, lo=500)
	return V.foley([(0.0, V.norm(shing, -1)), (0.04, V.norm(zap, -9)), (0.0, V.norm(swish, -10))], 0.7, -15.0)


def katana_draw_whoosh(k):
	base = f"whoosh_swish_high_fast_0{k % 4 + 1}"
	x = V.pro(base)[: int(0.3 * RATE)]
	crackle = shaped(stereo(V.seg(V.fs(CRACKLE), 0.3, 0.3, fout=0.1, lo=2500)), x)
	return V.foley([(0.0, x), (0.0, V.norm(crackle, -10))], 0.3, level_of(base))


def katana_wave():
	"""The water-and-lightning wave running down the blade (0.5 s): a crackle run."""
	run = V.seg(V.fs(ARC), 2.0, 0.55, fin=0.05, fout=0.2, lo=1800)
	crackle = V.seg(V.fs(CRACKLE), 0.5, 0.5, fin=0.03, fout=0.2, lo=2500)
	return V.foley([(0.0, V.norm(run, -3)), (0.05, V.norm(crackle, -8))], 0.6, -19.0)


# Build ------------------------------------------------------------------------------------
def write(name, x, mono=False):
	y = x.mean(axis=1) if mono and x.ndim == 2 else x
	sf.write(os.path.join(OUT, name + ".wav"), y.astype(np.float32), RATE, subtype="PCM_16")


def build():
	os.makedirs(OUT, exist_ok=True)
	V.LOUDER = 1.5  # v3: a clear step over each stock shot
	V.TARGET = float(np.mean([B.short_max(V.stock(f"{V.A}shot_0{i}")) for i in range(1, 9)])) + V.LOUDER
	for spec in GUNS.values():
		spec["target"] = target_of(spec)
	for gun in GUNS:
		tune(gun)
	c = {}
	# shared electric inspect
	c["Insp_start_01"] = insp_start()
	c["Insp_snap_01"], c["Insp_snap_02"] = insp_snap(0), insp_snap(1)
	c["Insp_roll_01"] = insp_roll()
	c["Insp_catch_01"] = insp_catch()
	c["Insp_settle_01"] = insp_settle()
	# Vandal and Stinger (auto): short shots, a first, a last with its tail, the tail
	for gun, n in (("Vandal", 8), ("Stinger", 6)):
		for k in range(n):
			c[f"{gun}_fire_{k + 1:02d}"] = gun_fire(gun, k)
		c[f"{gun}_fireFirst_01"] = gun_fire(gun, 0, base=GUNS[gun]["first"], water=GUNS[gun]["water"] + 2, zap_on=True)
		c[f"{gun}_fireLast_01"] = auto_last(gun)
		c[f"{gun}_tail_01"] = auto_tail(gun)
		for k in range(4 if gun == "Vandal" else 3):
			c[f"{gun}_fireFar_{k + 1:02d}"] = gun_far(gun, k)
	for k in range(3):
		c[f"Stinger_magOut_{k + 1:02d}"] = g36_mag(f"{M}magazine_unload_0{k % 3 + 1}", k, True)
		c[f"Stinger_magIn_{k + 1:02d}"] = g36_mag(f"{M}magazine_load_0{k % 4 + 1}", k, False)
		c[f"Stinger_rack_{k + 1:02d}"] = rack(f"{M}cock_0{k % 4 + 1}", k)
		c[f"Stinger_dryFire_{k + 1:02d}"] = dry(f"{M}dry_fire_0{k % 3 + 1}", k)
	# Marshal
	for k in range(4):
		c[f"Marshal_fire_{k + 1:02d}"] = gun_fire("Marshal", k)
		c[f"Marshal_rack_{k + 1:02d}"] = rack(f"{RF}cock_0{k % 4 + 1}", k)
		c[f"Marshal_shellIn_{k + 1:02d}"] = shell_in(f"{RF}load_bullet_0{2 * k + 1}", k)
	for k in range(3):
		c[f"Marshal_fireFar_{k + 1:02d}"] = gun_far("Marshal", k)
		c[f"Marshal_dryFire_{k + 1:02d}"] = dry(f"{RF}dry_fire_0{k % 4 + 1}", k)
	# Bucky
	for k in range(4):
		c[f"Bucky_fire_{k + 1:02d}"] = gun_fire("Bucky", k)
		c[f"Bucky_rack_{k + 1:02d}"] = rack(f"{SG}cock_0{k % 5 + 1}", k)
		c[f"Bucky_shellIn_{k + 1:02d}"] = shell_in(f"{SG}load_bullet_0{2 * k + 1}", k)
	for k in range(3):
		c[f"Bucky_fireFar_{k + 1:02d}"] = gun_far("Bucky", k)
	for k in range(2):
		c[f"Bucky_dryFire_{k + 1:02d}"] = dry(f"{SG}dry_fire_0{k + 1}", k)
	# Sheriff
	for k in range(4):
		c[f"Sheriff_fire_{k + 1:02d}"] = gun_fire("Sheriff", k)
		c[f"Sheriff_shellIn_{k + 1:02d}"] = shell_in(f"{R}load_bullet_0{k % 5 + 1}", k)
	for k in range(3):
		c[f"Sheriff_fireFar_{k + 1:02d}"] = gun_far("Sheriff", k)
		c[f"Sheriff_rack_{k + 1:02d}"] = rack(f"{R}cock_0{k % 5 + 1}", k, 0.5)
		c[f"Sheriff_open_{k + 1:02d}"] = cyl(f"{R}cylinder_open_0{k % 3 + 1}", k, "Smith_&_Wesson_M29_.44_Magnum_foley", -5, -14)
		c[f"Sheriff_close_{k + 1:02d}"] = cyl(f"{R}cylinder_close_0{k % 4 + 1}", k, "Smith_&_Wesson_M29_.44_Magnum_foley", -12, -8)
		c[f"Sheriff_eject_{k + 1:02d}"] = eject(f"{P}load_bullet_0{2 * k + 1}", k)
		c[f"Sheriff_dryFire_{k + 1:02d}"] = dry(f"{R}dry_fire_0{k % 5 + 1}", k)
	# Katana
	for k in range(4):
		c[f"Katana_fire_{k + 1:02d}"] = katana_swing(k)
	for k in range(2):
		c[f"Katana_heavy_{k + 1:02d}"] = katana_swing(k, heavy=True)
	for k in range(3):
		c[f"Katana_hitBody_{k + 1:02d}"] = katana_hit(k)
		c[f"Katana_hitWall_{k + 1:02d}"] = katana_wall(k)
		c[f"Katana_drawWhoosh_{k + 1:02d}"] = katana_draw_whoosh(k)
	c["Katana_draw_01"] = katana_draw()
	c["Katana_wave_01"] = katana_wave()
	report = {}
	stereo_cues = ("fire", "fireFirst", "fireLast", "tail", "fireFar")
	for name, x in c.items():
		write(name, x, mono=name.split("_")[1] not in stereo_cues)
		report[name] = dict(len=round(len(x) / RATE, 3), loud=round(B.short_max(x), 1), tp=round(B.tp_db(x), 2),
			peak=round(int(np.argmax(np.abs(x if x.ndim == 2 else x[:, None]).max(axis=1))) / RATE, 3))
	json.dump(dict(targets={g: round(s["target"], 2) for g, s in GUNS.items()}, clips=report),
		open(os.path.join(OUT, "_levels.json"), "w"), indent=1)
	reel(c)
	for n, r in report.items():
		print(f"  {n:24s} {r['len']:5.2f}s loud {r['loud']:6.1f} tp {r['tp']:6.2f} peak@{r['peak']:.3f}")


def reel(c):
	out = np.zeros((int(RATE * 160), 2))
	cues, t = [], 0.5

	def put(x, at):
		i = int(at * RATE)
		out[i : i + len(x)] += stereo(x)

	def label(s):
		cues.append(f"{t:6.2f}  {s}")

	for gun, spec in GUNS.items():
		label(f"{gun}: STOCK x3")
		for i in range(3):
			put(V.stock(spec["core"].format(i + 1)), t + i * 0.5)
		t += 1.5 + spec["length"] + 0.6
		label(f"{gun}: NEW x3")
		for i in range(3):
			put(c[f"{gun}_fire_{i + 1:02d}"], t + i * 0.5)
		t += 1.5 + spec["length"] + 0.8
	for name in sorted(n for n in c if not n.split("_")[1].startswith("fire") and n.split("_")[1] != "tail"):
		label(name)
		put(c[name], t)
		t += len(c[name]) / RATE + 0.45
	out = out[: int(RATE * t)]
	out *= 0.98 / max(np.abs(out).max(), 0.98)
	sf.write(os.path.join(OUT, "_reel.wav"), out.astype(np.float32), RATE, subtype="PCM_16")
	with open(os.path.join(OUT, "_reel.txt"), "w", encoding="utf-8") as f:
		f.write("Tempest-Strike line sound sets: audition reel (seconds)\n\n" + "\n".join(cues) + "\n")


if __name__ == "__main__":
	build()
