"""Designed gunshots (2026-11-09): Valorant / RIVALS-style shots layered from
real, professionally recorded mics of real guns. No synthesis.

    python -I tools/audio/design_gun_sfx.py     # before / after reel of every gun
                                                # (art-source/audio/DesignedPreview.wav)

tools/audio/build_gun_sfx.py uses DESIGNS for every gun's shot, tail and far
version when building the gun atlas.

The owner rejected single field recordings ("dull, boring") and asked for
Valorant / RIVALS punch. A designed shot is built from layers with different
jobs, each a real mic of a real gun:
  crack  the "on gun" (DPA4062) or 1 m mic: the mechanism and the snap
  body   a 1 m mic of the same or a heavier gun: weight in the low mids
  boom   (optional) a mic behind the shooter: the low thump
  tail   the 25-75 m mic, its flight delay removed: the space and the echo
Each layer is filtered to its band and aligned on its onset, then the stack is
glued hard (transient, 4:1 compression, light saturation, smile EQ) and
levelled like the gun atlas (build_gun_sfx short_max targets, -1 dBTP).
Other players hear the gun's own far mic (`far`), polished by build_gun_sfx.

Sources: Sonniss #GameAudioGDC 2016 bundle (Pole Position Production, TS
Sound), free for commercial games, no attribution (licence v2.0, vault/03
Research/Gun Sound Packs (Valorant-style).md); "FFL:" = The Free Firearm
Sound Library (CC0). The libraries live in art-source/audio/library
(gitignored, never committed).
"""

import json
import os
import sys

import numpy as np
import soundfile as sf
from scipy import signal

sys.path.insert(0, os.path.dirname(__file__))
import build_gun_sfx as B  # noqa: E402
from build_sound_atlas import compress, eq, hp, lp, resample, soft_clip, stereo, tighten, transient  # noqa: E402

ROOT = B.ROOT
GDC = os.path.join(ROOT, "art-source", "audio", "library", "GDC2016")
OUT_PREVIEW = os.path.join(ROOT, "art-source", "audio", "DesignedPreview.wav")
RATE = B.RATE


def L(name, length, band, gain=0.0, pitch=1.0, delay=0.0):
	"""A layer: (file name start, seconds, (high-pass, low-pass) Hz, dB, pitch, delay s)."""
	return (name, length, band, gain, pitch, delay)


# Finish presets (the glue): target = loudest 100 ms (build_gun_sfx classes).
PISTOL = dict(target=-11.5, low=2.0, presence=2.5, air=1.5, punch=4.0, hold=0.06, tau=0.16, drive=1.6)
SMALL = dict(target=-12.0, low=1.5, presence=2.5, air=1.5, punch=3.5, hold=0.05, tau=0.12, drive=1.4)
MAGNUM = dict(target=-10.5, low=3.5, presence=2.0, air=1.5, punch=4.5, hold=0.1, tau=0.25, drive=2.0)
SMG = dict(target=-11.5, low=2.0, presence=2.5, air=1.5, punch=3.5, hold=0.05, tau=0.14, drive=1.6)
RIFLE = dict(target=-10.5, low=2.5, presence=2.0, air=1.5, punch=4.0, hold=0.07, tau=0.2, drive=1.6)
MARKSMAN = dict(target=-9.5, low=3.0, presence=2.0, air=1.5, punch=4.5, hold=0.1, tau=0.26, drive=1.8)
SNIPER = dict(target=-8.5, low=3.5, presence=2.0, air=1.5, punch=5.0, hold=0.16, tau=0.45, drive=2.2)
SHOTGUN = dict(target=-9.5, low=3.5, presence=1.5, air=1.0, punch=4.5, hold=0.1, tau=0.25, drive=2.0)
MG = dict(target=-10.5, low=3.0, presence=2.0, air=1.5, punch=3.5, hold=0.06, tau=0.18, drive=1.8)
# Suppressed: still a gunshot (a thump and the action), just tighter and darker.
SUPPRESSED = dict(target=-12.5, low=2.5, presence=1.5, air=-1.0, punch=3.0, hold=0.03, tau=0.08, drive=1.4)

# Every gun: its layers, its finish, its far mic (what other players hear).
DESIGNS = {
	# Sidearms -------------------------------------------------------------------
	# Duty 9 mm: VP70 on-gun (snap + slide), SIG P229 1 m (body), SIG 50 m (tail).
	"Classic": dict(
		layers=[
			L("HK_VP70_9mm_on_gun", 0.25, (220, None)),
			L("SIG_P229_9mm_1m_left_on_ground", 0.5, (50, 9000), -3, delay=0.001),
			L("SIG_P229_9mm_50m_behind", 0.6, (150, 5000), -12, delay=0.003),
		],
		finish=PISTOL,
		far="SIG_P229_9mm_50m_behind",
	),
	# Quiet operator: a real suppressed .45 (De Lisle), a little higher, with the
	# VP70's action clicking on top.
	"Ghost": dict(
		layers=[
			L("De_Lisle_Carbine_.45ACP_suppressed_1m", 0.45, (80, None), pitch=1.06),
			L("HK_VP70_9mm_on_gun", 0.2, (900, None), -12),
			L("De_Lisle_Carbine_.45ACP_suppressed_55m", 0.5, (150, 4000), -16, delay=0.003),
		],
		finish=SUPPRESSED,
		far="De_Lisle_Carbine_.45ACP_suppressed_55m",
	),
	# Two compact autos: the Glock 18 and the Beretta 93R (both machine pistols).
	"Akimbo": dict(
		layers=[
			L("Glock_18_1m", 0.3, (150, None), pitch=1.04),
			L("Beretta_93R_9mm_1m", 0.4, (60, 9000), -3, pitch=1.04, delay=0.001),
			L("Glock_18_75m", 0.5, (150, 5000), -12, delay=0.003),
		],
		finish=SMALL,
		far="Glock_18_75m",
	),
	# .44 hand cannon: the S&W M29 on a boundary mic and from behind, the .357's
	# 50 m mic for the roll-off.
	"Sheriff": dict(
		layers=[
			L("Smith_&_Wesson_M29_.44_Magnum_2m", 0.6, (60, None)),
			L("Smith_&_Wesson_M29_.44_Magnum_1.5m", 0.8, (40, 9000), -2, delay=0.001),
			L("Smith_&_Wesson_M66_.357_Magnum_50m", 1.0, (150, 5000), -10, delay=0.004),
		],
		finish=MAGNUM,
		far="Smith_&_Wesson_M66_.357_Magnum_50m",
	),
	# Pocket shotgun: USAS-12 crack, SPAS-12 body, both a touch higher.
	"Shorty": dict(
		layers=[
			L("USAS-12_12g_solid_slug_1m", 0.5, (80, None), pitch=1.04),
			L("SPAS-12_12g_solid_slug_1m", 0.6, (40, 8000), -2, pitch=1.04, delay=0.001),
			L("SPAS-12_12g_solid_slug_50m", 0.8, (120, 4500), -11, delay=0.004),
		],
		finish=SHOTGUN,
		far="SPAS-12_12g_solid_slug_50m",
	),
	# SMGs ----------------------------------------------------------------------
	# Uzi: the Uzi and the Mini Uzi, buzzy and bright.
	"Stinger": dict(
		layers=[
			L("Uzi_9mm_1m", 0.25, (150, None), pitch=1.03),
			L("Mini_Uzi_9mm_1m", 0.3, (60, 9000), -3, pitch=1.03, delay=0.001),
			L("Uzi_9mm_75m", 0.6, (150, 5000), -12, delay=0.003),
		],
		finish=SMG,
		far="Uzi_9mm_75m",
	),
	# Suppressed SMG: the Steyr TMP darkened over the De Lisle's real suppressed
	# thump (higher), the MP7's action on top.
	"Spectre": dict(
		layers=[
			L("Steyr_TMP_9mm_1m", 0.3, (100, 7000)),
			L("De_Lisle_Carbine_.45ACP_suppressed_1m", 0.4, (60, 6000), -2, pitch=1.12),
			L("HK_MP7_4.6mm_on_gun", 0.2, (900, None), -11),
			L("Steyr_TMP_9mm_30m", 0.5, (150, 4000), -17, delay=0.003),
		],
		finish=SUPPRESSED,
		far="Steyr_TMP_9mm_30m",
	),
	# Shotguns ------------------------------------------------------------------
	# Pump: TS Sound's 12-gauge slug, the SPAS-12 under it, the SPAS at 50 m.
	"Bucky": dict(
		layers=[
			L("Shotgun_Fire_Slug_01", 0.9, (40, None), pitch=0.98),
			L("SPAS-12_12g_solid_slug_1m", 0.6, (60, 9000), -3, pitch=0.97, delay=0.001),
			L("SPAS-12_12g_solid_slug_50m", 1.0, (120, 4500), -10, delay=0.004),
		],
		finish=SHOTGUN,
		far="SPAS-12_12g_solid_slug_50m",
	),
	# Auto shotgun: the Saiga-12 (an AK shotgun) and the USAS-12 (a real auto shotgun).
	"Judge": dict(
		layers=[
			L("SAIGA-12_12g_solid_slug_1m", 0.5, (60, None)),
			L("USAS-12_12g_solid_slug_1m", 0.4, (80, 9000), -3, delay=0.001),
			L("SAIGA-12_12g_solid_slug_55m", 0.8, (120, 4500), -11, delay=0.004),
		],
		finish=SHOTGUN,
		far="SAIGA-12_12g_solid_slug_55m",
	),
	# Rifles --------------------------------------------------------------------
	# Heavy AK-style rifle: HK416 on-gun (mechanism, crack), AKM 1 m (7.62 weight).
	"Vandal": dict(
		layers=[
			L("HK_416_5.56mm_on_gun", 0.25, (180, None)),
			L("AKM_7.62x39mm_1m_left_on_ground", 0.6, (40, 9000), -2, pitch=0.97, delay=0.001),
			L("AKM_7.62x39mm_55m_in_front", 0.7, (150, 5000), -11, delay=0.004),
		],
		finish=RIFLE,
		far="AKM_7.62x39mm_55m_in_front",
	),
	# Suppressed carbine: the Sako TRG with its real suppressor (higher), the
	# HK416's action on top, a whisper of G36C room.
	"Phantom": dict(
		layers=[
			L("Sako_TRG_22_TRG_silencer", 0.45, (80, None), pitch=1.08),
			L("HK_416_5.56mm_on_gun", 0.2, (700, None), -11),
			L("Heckler_&_Koch_G36C_5.56mm_50m", 0.6, (150, 4000), -17, delay=0.003),
		],
		finish=SUPPRESSED,
		far="Heckler_&_Koch_G36C_5.56mm_50m",
	),
	# Bullpup: the FAMAS and the Tavor (both bullpups).
	"Bulldog": dict(
		layers=[
			L("FAMAS_G2_5.56mm_1m", 0.3, (120, None)),
			L("IMI_Tavor_TAR-21_5.56mm_1m", 0.35, (50, 9000), -2, delay=0.001),
			L("FAMAS_G2_5.56mm_55m", 0.6, (150, 5000), -12, delay=0.003),
		],
		finish=RIFLE,
		far="FAMAS_G2_5.56mm_55m",
	),
	# DMR: the G3's 7.62 crack, the FAL's boom from behind, the G3 at 55 m.
	"Guardian": dict(
		layers=[
			L("HK_G3_7.62x51mm_1m", 0.5, (80, None)),
			L("FN_FAL_7.62x51mm_1.5m_behind", 0.8, (30, 2500), -5, pitch=0.96, delay=0.001),
			L("HK_G3_7.62x51mm_55m", 1.1, (150, 5000), -9, delay=0.004),
		],
		finish=MARKSMAN,
		far="HK_G3_7.62x51mm_55m",
	),
	# Snipers -------------------------------------------------------------------
	# Lever gun: the Remington 700's crack over the Marlin 336 (.30-30 lever)
	# body, the Remington at 50 m.
	"Marshal": dict(
		layers=[
			L("Remington_700_7.62x51mm_1m", 0.6, (80, None)),
			L("FFL:Marlin 336/I_22P.wav", 0.9, (40, 8000), -3, delay=0.001),
			L("Remington_700_7.62x51mm_50m", 1.2, (150, 5000), -10, delay=0.005),
		],
		finish=MARKSMAN,
		far="Remington_700_7.62x51mm_50m",
	),
	# Double rifle: the BAR right at the muzzle, the FAL's boom from behind and
	# the Mosin's body, all a little lower; a long FAL roll.
	"Outlaw": dict(
		layers=[
			L("M1918_Browning_Automatic_Rifle_.30cal_0.1m", 0.5, (80, None), pitch=0.95),
			L("FN_FAL_7.62x51mm_1.5m_behind", 1.0, (30, 2200), -3, pitch=0.9, delay=0.001),
			L("FFL:Mosin Nagant/M_21P.wav", 1.0, (40, 8000), -5, pitch=0.95, delay=0.001),
			L("FN_FAL_7.62x51mm_25m_in_front", 1.6, (120, 5000), -8, pitch=0.95, delay=0.006),
		],
		finish=SNIPER,
		far="FN_FAL_7.62x51mm_25m_in_front",
	),
	# Big-bore bolt sniper: the Barrett M98B .338 on-gun (crack, mechanism), the
	# Barrett at 2 m (body), the FAL from behind (boom), the Remington at 50 m.
	"Operator": dict(
		layers=[
			L("Barrett_M98B_.338_Lapua_on_gun", 0.5, (120, None)),
			L("Barrett_M98B_.338_Lapua_2m_right", 1.0, (40, 9000), -2, delay=0.001),
			L("FN_FAL_7.62x51mm_1.5m_behind", 0.8, (30, 1800), -6, pitch=0.92, delay=0.002),
			L("Remington_700_7.62x51mm_50m", 1.6, (120, 5000), -9, delay=0.006),
		],
		finish=SNIPER,
		far="Barrett_M98B_.338_Lapua_2m_right",
	),
	# Machine guns --------------------------------------------------------------
	# Drum LMG: the Minimi (5.56 LMG), the L86 LSW's action on top.
	"Ares": dict(
		layers=[
			L("L110A2_LMG_5.56mm_belt_fed_1m", 0.3, (100, None)),
			L("Enfield_L86_LSW_5.56mm_on_gun", 0.2, (400, None), -6),
			L("L110A2_LMG_5.56mm_belt_fed_50m", 0.8, (150, 5000), -12, delay=0.003),
		],
		finish=MG,
		far="L110A2_LMG_5.56mm_belt_fed_50m",
	),
	# Belt-fed HMG: the L7A2 GPMG (7.62 belt-fed) over the M1919 .30cal, lower.
	"Odin": dict(
		layers=[
			L("L7A2_GPMG_7.62x51mm_belt_fed_1m", 0.35, (60, None), pitch=0.97),
			L("M1919A4_Browning_Machine_Gun_.30cal_on_turret_1m", 0.4, (40, 7000), -3, pitch=0.95, delay=0.001),
			L("L7A2_GPMG_7.62x51mm_belt_fed_50m", 0.8, (150, 5000), -11, delay=0.004),
		],
		finish=dict(MG, low=3.5),
		far="L7A2_GPMG_7.62x51mm_belt_fed_50m",
	),
}

# Loading ----------------------------------------------------------------------
_index = None
_cache = {}


def find(name):
	"""A file by (the start of) its name: GDC anywhere, or "FFL:<path>"."""
	global _index
	if name.startswith("FFL:"):
		return os.path.join(B.FFL, name[4:])
	if _index is None:
		_index = {}
		for d, _, files in os.walk(GDC):
			for f in files:
				if f.lower().endswith(".wav"):
					_index.setdefault(f, os.path.join(d, f))
	for f in sorted(_index):
		if f.startswith(name):
			return _index[f]
	raise FileNotFoundError(name)


def load(name):
	if name not in _cache:
		path = os.path.abspath(find(name))
		if len(path) > 250:  # past Windows' MAX_PATH: open it as a long path
			path = chr(92) * 2 + "?" + chr(92) + path
		x, sr = sf.read(path, always_2d=True)
		x = x[:, :2] if x.shape[1] >= 2 else np.repeat(x, 2, axis=1)
		if sr != RATE:
			x = signal.resample_poly(x, RATE, sr, axis=0)
		_cache[name] = x - x[:256].mean(axis=0)
	return _cache[name]


def shots(name):
	return B.shot_onsets(load(name))


def fits(name, length):
	"""The shots that have `length` s of their own before the next one (the
	others are cut short by the next shot); the roomiest ones if none do."""
	found = shots(name)
	fit = [f for f in found if f[1] >= RATE * length]
	return fit or sorted(found, key=lambda f: -f[1])


def pick(name, k, length):
	fit = fits(name, length)
	return fit[k % len(fit)]


def combo(gun, k):
	"""Which shot of each layer variant k uses."""
	return tuple(k % len(fits(sp[0], sp[1] * sp[4])) for sp in DESIGNS[gun]["layers"])


# A variant whose layers would repeat an earlier one's exactly (recordings
# with a single clean shot) is made different instead: a small pitch change
# and a shifted layer balance, so round-robin never plays the same file.
VARIANT_PITCH = (1.0, 0.972, 1.03)
VARIANT_GAIN = (0.0, -1.5, 1.5)  # dB on the body layer


def layer(spec, k, pitch_mul=1.0, gain_add=0.0):
	name, length, band, gain, pitch, delay = spec
	pitch *= pitch_mul
	gain += gain_add
	x = load(name)
	onset, room = pick(name, k, length * pitch)
	n = int(RATE * (length * pitch + 0.02))
	seg = x[onset : onset + min(n, room)]
	if pitch != 1:
		seg = resample(seg, 1 / pitch)
	lo, hi = band
	if lo:
		seg = hp(seg, lo, 2)
	if hi:
		seg = lp(seg, hi, 2)
	seg = B.fade(seg, 0, min(0.03, len(seg) / RATE * 0.2))
	# each layer peaks at 0 dBFS before its gain, so the gains are the balance
	return seg / (np.abs(seg).max() + 1e-9) * 10 ** (gain / 20), delay


def stack(layers, length):
	out = np.zeros((int(RATE * length), 2))
	for seg, delay in layers:
		i = int(RATE * delay)
		n = min(len(seg), len(out) - i)
		out[i : i + n] += stereo(seg)[:n]
	return out


def finish(x, target, low, presence, air, punch, hold, tau, drive, tail_scale=1.0):
	"""The glue: Valorant-style squeezed and forward."""
	x = eq(x, [("low", 90, low), ("peak", 320, -3.0, 0.9), ("peak", 2600, presence, 0.8), ("high", 9000, air)])
	x = transient(x, punch)
	x = compress(x, -22, 4.0, 0.003, 0.08)  # hard glue
	x = soft_clip(x / (np.abs(x).max() + 1e-9) * 10 ** (drive / 20)) * 0.89  # a touch of saturation
	x = tighten(x, hold * tail_scale, tau * tail_scale)
	x = B.fade(x, 0.001, len(x) / RATE * 0.3)
	return B.master_tp(x, target)


def designed(gun, k, length, auto=False):
	"""Variant k of a gun's designed shot, `length` s long. Automatic guns keep
	more tail: during a spray it's cut anyway, and on release it's the room."""
	d = DESIGNS[gun]
	f = dict(d["finish"])
	target = f.pop("target")
	# the crack layer is the loudest: if it repeats an earlier variant's take, vary it
	repeat = any(combo(gun, j)[0] == combo(gun, k)[0] for j in range(k))
	pm = VARIANT_PITCH[k % 3] if repeat else 1.0
	layers = [
		layer(sp, k, pm, VARIANT_GAIN[k % 3] if (repeat and i == 1) else 0.0) for i, sp in enumerate(d["layers"])
	]
	return finish(stack(layers, length), target, tail_scale=2.2 if auto else 1.0, **f)


def far_raw(gun, length):
	"""The gun's own far mic, one clean shot (build_gun_sfx polishes it)."""
	name = DESIGNS[gun]["far"]
	x = load(name)
	onset, room = pick(name, 0, length)
	return x[onset : onset + min(int(RATE * (length + 0.05)), room)]


def target(gun):
	return DESIGNS[gun]["finish"]["target"]


# Reel -------------------------------------------------------------------------
def current(name, k):
	"""A slice of the live gun atlas (v1), for the before / after."""
	audio, _ = sf.read(B.OUT_AUDIO, always_2d=True)
	r = json.load(open(B.OUT_JSON))[name][k % 3]
	a = int(round(r["start"] * RATE))
	return audio[a : a + int(round(r["length"] * RATE))]


def main():
	w = B.weapon_data()
	out = np.zeros((int(RATE * 400), 2))
	cues, t = [], 0.5
	vol = B.FIRE_VOL * B.GROUP["Gun"]

	def put(clip, at):
		i = int(at * RATE)
		out[i : i + len(clip)] += stereo(clip) * vol

	for gun in DESIGNS:
		auto = w[gun]["fireMode"] == "Auto"
		fi = w[gun]["fireInterval"]
		count, gap = (8, fi) if auto else (4, max(fi, 0.35))
		c = B.CLASSES[B.GUNS[gun]["cls"]]
		length = max(c["length"], 0.9) if auto else c["length"]
		new = [designed(gun, k, length, auto) for k in range(3)]
		cues.append(f"{t:6.2f}  {gun} NEW")
		for i in range(count):
			v = new[i % 3]
			if auto and i < count - 1:
				v = v[: int(RATE * (B.TAIL_AFTER * fi + B.XFADE))]
			put(v, t + i * gap)
		t += count * gap + 1.4
	out = out[: int(RATE * t)]
	out *= 0.98 / max(np.abs(out).max(), 0.98)
	sf.write(OUT_PREVIEW, out.astype(np.float32), RATE, subtype="PCM_16")
	with open(OUT_PREVIEW.replace(".wav", ".txt"), "w", encoding="utf-8") as f:
		f.write("DesignedPreview.wav: every gun's designed shot at game volume" + chr(10) * 2)
		f.write(chr(10).join(cues) + chr(10))
	print("wrote", OUT_PREVIEW, f"({t:.0f} s)")


if __name__ == "__main__":
	main()
