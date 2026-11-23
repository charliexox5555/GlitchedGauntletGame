"""Riftforge Phantom v2 FULL REPLACEMENT Legendary Sound Set (Prelude-to-Chaos inspired).

100% real recordings only (ProPack + Sonniss GDC 2016 Pole Position guns + steel bulkhead
THUMP + CC0 Freesound electric/lightning/metal recordings in art-source/audio/downloads).
Replaces BOTH stock Phantom shots AND stock Phantom handling foley completely (same
architecture as TempestAudio in GunAudio.luau + WeaponController.luau + ViewmodelController.luau).

    python -I tools/audio/design_riftforge_v2.py

Writes art-source/audio/riftforge/v2/*.wav (48 kHz, 16-bit, -1 dBTP).
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
import design_tempest_line as L  # noqa: E402
from build_sound_atlas import eq, hp, lp, resample, soft_clip, stereo  # noqa: E402

RATE = V.RATE
OUT = os.path.join(B.ROOT, "art-source", "audio", "riftforge", "v2")
os.makedirs(OUT, exist_ok=True)

# Stock Phantom ProPack prefix (gun_semi_auto_rifle_*)
A = V.A
THUMP = L.THUMP
CUT = 0.165  # Phantom fireInterval ~0.091s -> 1.5x + 30ms so sprays never cut off!
LOUDER_DB = 1.4  # Unmistakably punchier & heavier than stock Phantom!


def _target_shot():
	return float(np.mean([B.short_max(V.stock(A + f"shot_0{i}")) for i in range(1, 9)])) + LOUDER_DB


def _target_foley():
	return float(np.mean([B.short_max(V.stock(A + f"magazine_load_0{i}")) for i in range(1, 5)])) + 1.5


TARGET_SHOT = _target_shot()
TARGET_FOLEY = _target_foley()


def _bulkhead(k, pitch_base=0.82, lp_hz=185.0, length=0.22):
	"""Heavy forged-obsidian sub-bass chest thump from real steel bulkhead impact."""
	x = L.gdc(THUMP)
	i = V.onset(x)
	y = x[max(i - int(0.001 * RATE), 0) : i + int(length * RATE)]
	p = pitch_base + 0.03 * (k % 3)
	y = lp(resample(y, 1.0 / p), lp_hz, 2)
	return B.fade(y, 0.0, min(0.09, len(y) / RATE * 0.45))


def _plasma_bite(k, length=0.14):
	"""Crisp Prelude-to-Chaos high-voltage plasma crack + metallic overtone from real CC0 recordings."""
	e_src = V.fs(V.ELECTRICITY)
	z_src = V.fs(V.ZAP if k % 2 == 0 else V.ZAP_EGO)
	c_src = V.fs(V.CRACKLE)

	# Pick distinct discharge transients per variation
	e_start = (0.12 + 0.52 * (k % 6)) % max(0.2, len(e_src) / RATE - 0.3)
	e_clip = V.seg(e_src, e_start, length, fin=0.0, fout=0.035, lo=1600, hi=12500, pitch=0.92 + 0.05 * (k % 3), rel=-22.0)

	z_start = (0.05 + 0.18 * (k % 4)) % max(0.15, len(z_src) / RATE - 0.25)
	z_clip = V.seg(z_src, z_start, min(length, 0.11), fin=0.0, fout=0.03, lo=950, hi=10500, pitch=0.84 + 0.04 * (k % 3), rel=-24.0)

	c_start = (0.4 + 0.7 * k) % max(0.5, len(c_src) / RATE - 0.3)
	c_clip = V.seg(c_src, c_start, length, fin=0.004, fout=0.04, lo=2400, hi=13000, pitch=1.02 + 0.03 * (k % 2))

	# Metallic forged resonant ring (real blade/latch transient)
	m_src = V.fs(V.SWORD if k % 2 == 0 else V.SLIDE_LOCK)
	m_clip = V.seg(m_src, 0.0, 0.085, fin=0.0, fout=0.03, lo=1400, hi=6800, pitch=0.72 + 0.03 * (k % 3), rel=-20.0)

	mix = V.stack(
		length + 0.02,
		(0.0, V.norm(e_clip, 0.0)),
		(0.002, V.norm(z_clip, -2.5)),
		(0.004, V.norm(m_clip, -7.5)),
		(0.010, V.norm(c_clip, -9.0)),
	)[: int(length * RATE)]
	return B.fade(mix, 0.0, 0.03)


def _glue_plasma(x, target_db):
	"""Heavy industrial plasma glue: chesty low punch + dark-matter presence bite."""
	y = eq(
		x,
		[
			("low", 105, 3.2),
			("peak", 320, -1.5, 0.9),
			("peak", 1800, 2.4, 0.8),
			("peak", 5200, 3.0, 0.85),
			("high", 10500, 1.2),
		],
	)
	y = soft_clip(y * 1.45, 0.92)
	return B.master_tp(y, target_db)


def make_shot(k, base=None, full=False, far=False):
	length = 0.36
	core = V.pro(base or f"{A}shot_0{(k % 8) + 1}")[: int(length * RATE)]
	# Tighten & darken stock core slightly so our heavy plasma/GDC layers dominate!
	core = lp(core, 7800, 2)
	hk = L.gdc_shot("HK_416_5.56mm_on_gun", k, 0.13, lo=900, hi=12000, pitch=0.90 - 0.015 * (k % 2))
	ak = L.gdc_shot("AKM_7.62x39mm_1m_left_on_ground", k, 0.24, lo=95, hi=6500, pitch=0.88 - 0.015 * (k % 3))
	sub = _bulkhead(k, pitch_base=0.80, lp_hz=175.0, length=0.22)
	bite = _plasma_bite(k, length=0.16)

	layers = [
		(-4.5, ak, 0.0),
		(-6.5, hk, 0.4),
		(-4.8 if not far else -8.5, sub, 0.0),
		(-3.8 if not far else -10.5, bite, 0.5),
	]
	x = V.stack(length + 0.04, *V.aligned(V.norm(core, -3.2), *layers))[: int(length * RATE)]
	if far:
		x = B.master_tp(lp(x, 4600, 2), TARGET_SHOT - 2.2)
	else:
		x = _glue_plasma(x, TARGET_SHOT)
	x = B.fade(x, 0.0, 0.04)
	if not full:
		x = B.fade(x[: int(CUT * RATE)], 0.0, 0.028)
	return x


def make_tail():
	"""1.55s dark-matter industrial plasma tail: real rifle decay + distant thunder crackle."""
	length = 1.55
	t_core = V.pro(A + "shot_00_tail_only_01")[: int(length * RATE)]
	lt = V.seg(V.fs(V.LIGHTNING), 0.15, length, fin=0.03, fout=0.45, lo=160, hi=4200, pitch=0.72)
	cr = V.seg(V.fs(V.CRACKLE), 0.2, 0.95, fin=0.02, fout=0.35, lo=1800, hi=9500, pitch=0.88)
	x = V.stack(
		length,
		(0.0, V.norm(lp(t_core, 5200, 2), -2.0)),
		(0.02, V.norm(lt, -5.5)),
		(0.03, V.norm(cr, -10.5)),
	)
	return B.fade(B.master_tp(x, TARGET_SHOT - 4.5), 0.004, 0.35)


def make_last():
	"""Dramatic empty-mag final shot: overdriven plasma punch + metallic power-down fizzle tail."""
	head = make_shot(0, base=A + "shot_00_last_with_tail_01", full=True)
	tail = make_tail()
	# Falling plasma power-down discharge
	z_down = V.seg(V.fs(V.ZAP_EGO), 0.0, 0.55, fin=0.01, fout=0.22, lo=400, hi=8500, pitch=0.58, rel=-26.0)
	sw = V.seg(V.fs(V.SWORD), 0.0, 0.45, fin=0.01, fout=0.20, lo=700, hi=5500, pitch=0.55, rel=-22.0)
	length = 1.65
	x = V.stack(
		length,
		(0.0, head),
		(0.07, V.norm(tail, -3.0)),
		(0.09, V.norm(z_down, -6.0)),
		(0.06, V.norm(sw, -9.5)),
	)
	return B.fade(B.master_tp(x, TARGET_SHOT + 0.4), 0.0, 0.30)


# =============================================================================
# FULL REPLACEMENT HANDLING CUES (MONO, CRISP, IN-SYNC WITH CUSTOM TRACKS!)
# =============================================================================
def _mono_master(x, target_db=None):
	y = B.master_tp(x, target_db or TARGET_FOLEY)
	return y.mean(axis=1)


def make_draw():
	"""Heavy magnetic draw + reactor spin-up swell (0.75s)."""
	length = 0.75
	sw = V.seg(V.fs(V.SWORD), 0.0, 0.45, fin=0.01, fout=0.14, lo=450, hi=8500, pitch=0.68, rel=-24.0)
	lt = V.seg(V.fs(V.LATCH), 0.0, 0.22, fin=0.0, fout=0.06, lo=300, hi=9000, pitch=0.82, rel=-22.0)
	st = V.seg(V.fs(V.STUN), 0.1, 0.55, fin=0.12, fout=0.18, lo=350, hi=7200, pitch=0.78)
	cr = V.seg(V.fs(V.CRACKLE), 0.5, 0.45, fin=0.08, fout=0.14, lo=1600, hi=10500, pitch=0.95)
	x = V.stack(
		length,
		(0.02, V.norm(sw, -4.5)),
		(0.08, V.norm(lt, -3.0)),
		(0.10, V.norm(st, -6.5)),
		(0.18, V.norm(cr, -8.5)),
	)
	return _mono_master(B.fade(x, 0.005, 0.12), TARGET_FOLEY + 0.5)


def make_cowl_slam(k=0):
	"""Violent industrial armor-cowl SLAM + barrel plasma surge (replaces bolt rack & draw lock!)."""
	length = 0.58
	sub = _bulkhead(k, pitch_base=0.88 + 0.03 * k, lp_hz=260.0, length=0.22)
	sl = V.seg(V.fs(V.SLIDE_LOCK), 0.0, 0.22, fin=0.0, fout=0.06, lo=550, hi=12000, pitch=0.76 + 0.03 * k, rel=-22.0)
	mc = V.seg(V.fs(V.METAL_CLICK), 0.0, 0.16, fin=0.0, fout=0.04, lo=900, hi=12000, pitch=0.85, rel=-22.0)
	zap = V.seg(V.fs(V.ELECTRICITY), 0.2 + 0.5 * k, 0.28, fin=0.0, fout=0.10, lo=1400, hi=12000, pitch=0.95, rel=-22.0)
	cr = V.seg(V.fs(V.CRACKLE), 0.3 + 0.4 * k, 0.36, fin=0.02, fout=0.14, lo=1800, hi=11000, pitch=1.08)
	x = V.stack(
		length,
		(0.00, V.norm(sl, -1.5)),
		(0.015, V.norm(sub, -1.0)),
		(0.02, V.norm(mc, -4.0)),
		(0.025, V.norm(zap, -2.5)),
		(0.06, V.norm(cr, -7.5)),
	)
	return _mono_master(B.fade(x, 0.0, 0.10), TARGET_FOLEY + 1.8)


def make_mag_out(k=0):
	"""Reactor latch release + spent energy-cell plasma discharge pop (0.52s)."""
	length = 0.52
	lt = V.seg(V.fs(V.LATCH), 0.0, 0.20, fin=0.0, fout=0.05, lo=400, hi=11000, pitch=0.88 + 0.04 * k, rel=-22.0)
	ar = V.seg(V.fs(V.AR_RELOAD), 0.05 + 0.3 * k, 0.25, fin=0.0, fout=0.06, lo=280, hi=9500, pitch=0.85, rel=-20.0)
	zp = V.seg(V.fs(V.ZAP_EGO if k == 0 else V.ZAP), 0.0, 0.30, fin=0.0, fout=0.10, lo=700, hi=11000, pitch=0.72 + 0.05 * k, rel=-24.0)
	el = V.seg(V.fs(V.ELECTRICITY), 0.4 + 0.6 * k, 0.26, fin=0.0, fout=0.09, lo=1600, hi=12000, pitch=0.84, rel=-22.0)
	x = V.stack(
		length,
		(0.00, V.norm(lt, -2.0)),
		(0.01, V.norm(ar, -4.5)),
		(0.025, V.norm(zp, -2.0)),
		(0.04, V.norm(el, -5.0)),
	)
	return _mono_master(B.fade(x, 0.0, 0.10), TARGET_FOLEY + 1.2)


def make_mag_form():
	"""Converging magnetic plasma swell forming fresh energy cell in the magwell (0.55s)."""
	length = 0.55
	st = V.seg(V.fs(V.STUN), 0.2, length, fin=0.16, fout=0.05, lo=380, hi=9000, pitch=1.12)
	cr = V.seg(V.fs(V.CRACKLE), 0.8, length, fin=0.18, fout=0.06, lo=1500, hi=12000, pitch=1.18)
	# Crescendo envelope so energy visibly/audibly builds into the MagIn SLAM!
	env = np.linspace(0.25, 1.0, int(length * RATE))[:, None] ** 1.4
	x = V.stack(length, (0.0, V.norm(st, -2.5)), (0.0, V.norm(cr, -4.5))) * env
	return _mono_master(B.fade(x, 0.04, 0.04), TARGET_FOLEY + 0.6)


def make_mag_in(k=0):
	"""Heavy magnetic bulkhead SLAM + crisp plasma lock charge (0.48s)."""
	length = 0.48
	sub = _bulkhead(k + 1, pitch_base=0.84 + 0.03 * k, lp_hz=240.0, length=0.22)
	sl = V.seg(V.fs(V.SLIDE_LOCK), 0.0, 0.20, fin=0.0, fout=0.05, lo=500, hi=11500, pitch=0.90 + 0.03 * k, rel=-22.0)
	el = V.seg(V.fs(V.ELECTRICITY), 0.8 + 0.5 * k, 0.24, fin=0.0, fout=0.08, lo=1500, hi=12500, pitch=1.08, rel=-22.0)
	mc = V.seg(V.fs(V.METAL_CLICK), 0.0, 0.14, fin=0.0, fout=0.04, lo=1000, hi=12000, pitch=0.96, rel=-22.0)
	x = V.stack(
		length,
		(0.00, V.norm(mc, -3.0)),
		(0.01, V.norm(sub, -0.5)),
		(0.015, V.norm(sl, -2.0)),
		(0.025, V.norm(el, -3.5)),
	)
	return _mono_master(B.fade(x, 0.0, 0.09), TARGET_FOLEY + 1.8)


def make_inspect_start():
	"""Reactor cowls unlocking + floating dark-matter crystal levitation hum (0.90s)."""
	length = 0.90
	lt = V.seg(V.fs(V.LATCH), 0.0, 0.22, fin=0.0, fout=0.05, lo=400, hi=11000, pitch=0.78, rel=-22.0)
	sw = V.seg(V.fs(V.SWORD), 0.0, 0.45, fin=0.02, fout=0.14, lo=500, hi=8500, pitch=0.64, rel=-22.0)
	st = V.seg(V.fs(V.STUN), 0.05, 0.72, fin=0.14, fout=0.22, lo=280, hi=6800, pitch=0.84)
	cr = V.seg(V.fs(V.CRACKLE), 0.2, 0.72, fin=0.12, fout=0.22, lo=1600, hi=11000, pitch=1.02)
	x = V.stack(
		length,
		(0.02, V.norm(lt, -2.0)),
		(0.06, V.norm(sw, -4.5)),
		(0.14, V.norm(st, -4.5)),
		(0.16, V.norm(cr, -6.0)),
	)
	return _mono_master(B.fade(x, 0.005, 0.16), TARGET_FOLEY + 0.8)


def make_inspect_roll():
	"""High-voltage plasma arc whirl during the 360-deg magnetic barrel roll (0.95s)."""
	length = 0.95
	lt = V.seg(V.fs(V.LIGHTNING), 0.08, 0.75, fin=0.10, fout=0.22, lo=300, hi=9500, pitch=1.15)
	cr = V.seg(V.fs(V.CRACKLE), 0.6, 0.82, fin=0.10, fout=0.20, lo=1400, hi=12500, pitch=1.22)
	el = V.seg(V.fs(V.ELECTRICITY), 0.1, 0.35, fin=0.01, fout=0.12, lo=1800, hi=12500, pitch=1.05, rel=-22.0)
	sw = V.seg(V.fs(V.SWORD), 0.0, 0.45, fin=0.05, fout=0.15, lo=400, hi=7500, pitch=0.85, rel=-22.0)
	x = V.stack(
		length,
		(0.04, V.norm(sw, -4.0)),
		(0.08, V.norm(lt, -4.0)),
		(0.10, V.norm(cr, -3.5)),
		(0.28, V.norm(el, -3.0)),
	)
	return _mono_master(B.fade(x, 0.02, 0.16), TARGET_FOLEY + 1.0)


def make_impact(k=0):
	"""Crisp electric plasma wall impact crackle (0.28s)."""
	length = 0.28
	el = V.seg(V.fs(V.ELECTRICITY), 0.15 + 0.65 * k, 0.20, fin=0.0, fout=0.07, lo=1200, hi=12500, pitch=0.95 + 0.08 * k, rel=-22.0)
	zp = V.seg(V.fs(V.ZAP if k % 2 == 0 else V.ZAP_EGO), 0.0, 0.18, fin=0.0, fout=0.06, lo=800, hi=11000, pitch=1.02 + 0.05 * k, rel=-22.0)
	sub = _bulkhead(k, pitch_base=1.15, lp_hz=260.0, length=0.12)
	x = V.stack(
		length,
		(0.00, V.norm(el, -1.0)),
		(0.003, V.norm(zp, -3.0)),
		(0.00, V.norm(sub, -6.5)),
	)
	return _mono_master(B.fade(x, 0.0, 0.06), TARGET_FOLEY + 0.5)


def write_wav(name, data):
	path = os.path.join(OUT, name + ".wav")
	sf.write(path, data, RATE, subtype="PCM_16")
	dur = len(data) / RATE
	return {"name": name, "path": path, "length": round(dur, 3), "channels": 1 if data.ndim == 1 else data.shape[1]}


def main():
	manifest = []
	for k in range(6):
		manifest.append(write_wav(f"RF_fire_0{k + 1}", make_shot(k)))
	manifest.append(write_wav("RF_fireFirst_01", make_shot(0, base=A + "shot_00_first_01")))
	manifest.append(write_wav("RF_fireLast_01", make_last()))
	manifest.append(write_wav("RF_tail_01", make_tail()))
	for k in range(3):
		manifest.append(write_wav(f"RF_fireFar_0{k + 1}", make_shot(k, far=True)))
	manifest.append(write_wav("RF_draw_01", make_draw()))
	manifest.append(write_wav("RF_drawLock_01", make_cowl_slam(0)))
	for k in range(2):
		manifest.append(write_wav(f"RF_magOut_0{k + 1}", make_mag_out(k)))
	manifest.append(write_wav("RF_magForm_01", make_mag_form()))
	for k in range(2):
		manifest.append(write_wav(f"RF_magIn_0{k + 1}", make_mag_in(k)))
	manifest.append(write_wav("RF_rack_01", make_cowl_slam(1)))
	manifest.append(write_wav("RF_inspectStart_01", make_inspect_start()))
	manifest.append(write_wav("RF_inspectRoll_01", make_inspect_roll()))
	manifest.append(write_wav("RF_inspectLock_01", make_cowl_slam(2)))
	for k in range(3):
		manifest.append(write_wav(f"RF_impact_0{k + 1}", make_impact(k)))

	mpath = os.path.join(OUT, "manifest.json")
	with open(mpath, "w", newline="\n") as f:
		json.dump(manifest, f, indent=2)
	print(f"Designed {len(manifest)} Riftforge v2 WAVs -> {OUT} (target shot={TARGET_SHOT:.1f} dB, foley={TARGET_FOLEY:.1f} dB)")


if __name__ == "__main__":
	main()
