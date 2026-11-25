"""Riftfang Knife (Riftforge Legendary Melee) Custom Sound Set.

100% real licensed/CC0 recordings (ProPack knife whooshes & impacts + steel bulkhead THUMP +
CC0 Freesound sword, metal latch, slide lock, metal click, electric zap, crackle, stun & lightning).
Exact hit-frame peak alignment (`0.06s` light slash, `0.09s` heavy lunge) so every swing hits crisp!

    python -I tools/audio/design_riftforge_knife.py

Writes art-source/audio/riftforge/knife_v1/*.wav (48 kHz, 16-bit, -1 dBTP).
"""
import json
import os
import sys

import numpy as np
import soundfile as sf

sys.path.insert(0, os.path.dirname(__file__))
import build_gun_sfx as B  # noqa: E402
import design_tempest_vandal as V  # noqa: E402
import design_tempest_line as L  # noqa: E402
from build_sound_atlas import eq, hp, lp, resample, soft_clip, stereo  # noqa: E402

RATE = V.RATE
OUT = os.path.join(B.ROOT, "art-source", "audio", "riftforge", "knife_v1")
os.makedirs(OUT, exist_ok=True)

THUMP = L.THUMP


def _bulkhead(k, pitch_base=0.88, lp_hz=220.0, length=0.18):
	x = L.gdc(THUMP)
	i = V.onset(x)
	y = x[max(i - int(0.001 * RATE), 0) : i + int(length * RATE)]
	p = pitch_base + 0.03 * (k % 3)
	y = lp(resample(y, 1.0 / p), lp_hz, 2)
	return B.fade(y, 0.0, min(0.08, len(y) / RATE * 0.45))


def _mono(x, target_db):
	y = B.master_tp(x, target_db)
	return y.mean(axis=1)


def make_draw():
	"""Snappy tactical unsheathe + fast palm-flip swoosh + 3-scale mechanical lock + plasma zap (0.72s)."""
	length = 0.72
	sw = V.seg(V.fs(V.SWORD), 0.0, 0.42, fin=0.0, fout=0.14, lo=750, hi=11500, pitch=0.86, rel=-24.0)
	wh = V.pro("whoosh_swish_high_fast_01")[: int(0.28 * RATE)]
	# 3 staggered metallic spine-scale lock clicks (Scale1 -> Scale2 -> Scale3!)
	c1 = V.seg(V.fs(V.METAL_CLICK), 0.0, 0.09, fin=0.0, fout=0.03, lo=900, hi=12000, pitch=0.92, rel=-22.0)
	c2 = V.seg(V.fs(V.METAL_CLICK), 0.0, 0.09, fin=0.0, fout=0.03, lo=900, hi=12000, pitch=1.06, rel=-22.0)
	c3 = V.seg(V.fs(V.SLIDE_LOCK), 0.0, 0.14, fin=0.0, fout=0.04, lo=650, hi=12000, pitch=1.02, rel=-22.0)
	zp = V.seg(V.fs(V.ELECTRICITY), 0.15, 0.24, fin=0.0, fout=0.09, lo=1500, hi=12500, pitch=1.05, rel=-22.0)
	sub = _bulkhead(0, pitch_base=0.96, lp_hz=230.0, length=0.14)
	x = V.stack(
		length,
		(0.00, V.norm(sw, -2.0)),
		(0.08, V.norm(wh, -3.5)),
		(0.26, V.norm(c1, -4.5)),
		(0.31, V.norm(c2, -3.5)),
		(0.35, V.norm(c3, -1.5)),
		(0.35, V.norm(sub, -3.5)),
		(0.36, V.norm(zp, -2.5)),
	)
	return _mono(B.fade(x, 0.0, 0.10), -13.5)


def make_slash(k, heavy=False):
	"""Unmistakable Legendary dark-matter electric blade slash (peak aligned to 0.06s light / 0.09s heavy).
	Drops the generic stock knife_whoosh bed in favor of razor forged-steel blade sing,
	front-and-center plasma zap/discharge, mechanical spine-scale flick, and electric crackle tail."""
	want = 0.09 if heavy else 0.06
	length = 1.05 if heavy else 0.50

	# Fast sharp air cut (NOT the stock knife_whoosh!) aligned to peak
	wh_name = f"whoosh_swish_high_fast_0{k % 4 + 1}"
	wh_src = V.pro(wh_name)
	wh_pk = L.pro_peak(wh_name)
	wh_start = max(wh_pk - want, 0.0)
	wh = wh_src[int(wh_start * RATE) : int((wh_start + min(length, 0.40)) * RATE)]

	# Forged titanium blade sing (prominent metallic fang resonance)
	sw = V.seg(
		V.fs(V.SWORD),
		0.0,
		0.34 if heavy else 0.28,
		fin=0.005,
		fout=0.11,
		lo=900 if heavy else 1200,
		hi=12000,
		pitch=(0.76 if heavy else 1.08) + 0.05 * (k % 3),
		rel=-22.0,
	)

	# Spine-scale mechanical flare click right as blade whips through peak
	sc = V.seg(
		V.fs(V.METAL_CLICK),
		0.0,
		0.08,
		fin=0.0,
		fout=0.03,
		lo=1100,
		hi=12500,
		pitch=(0.92 if heavy else 1.12) + 0.06 * (k % 3),
		rel=-22.0,
	)

	# Front-and-center electric plasma discharge + zap bite right on the strike!
	zp_clip = V.ZAP if (k % 2 == 0 and not heavy) else V.ZAP_EGO
	zp = V.seg(
		V.fs(zp_clip),
		0.0,
		0.28 if heavy else 0.22,
		fin=0.0,
		fout=0.09,
		lo=650 if heavy else 950,
		hi=12500,
		pitch=(0.82 if heavy else 1.06) + 0.04 * (k % 3),
		rel=-22.0,
	)
	el_src = V.fs(V.ELECTRICITY)
	el_t = (0.15 + 0.50 * k) % max(0.2, len(el_src) / RATE - 0.38)
	el = V.seg(
		el_src,
		el_t,
		0.34 if heavy else 0.26,
		fin=0.0,
		fout=0.10,
		lo=1400,
		hi=12500,
		pitch=(0.84 if heavy else 1.14) + 0.04 * (k % 3),
		rel=-22.0,
	)
	cr_src = V.fs(V.CRACKLE)
	cr_t = (0.08 + 0.24 * k) % max(0.15, len(cr_src) / RATE - 0.48)
	cr = V.seg(
		cr_src,
		cr_t,
		0.48 if heavy else 0.30,
		fin=0.005,
		fout=0.12,
		lo=1800,
		hi=12500,
		pitch=0.96 if heavy else 1.12,
	)

	layers = [
		(0.0, V.norm(wh, -5.5 if not heavy else -6.5)),
		(max(0.0, want - 0.025), V.norm(sw, -1.0)),
		(max(0.0, want - 0.015), V.norm(sc, -3.5)),
		(want, V.norm(zp, 0.0)),
		(want + 0.004, V.norm(el, -1.5 if not heavy else -0.5)),
		(want + 0.015, V.norm(cr, -3.5 if not heavy else -2.5)),
	]
	if heavy:
		# Pre-strike scale latch + massive sub-bass dark-matter shockwave + thunder tail
		latch = V.seg(V.fs(V.SLIDE_LOCK), 0.0, 0.10, fin=0.0, fout=0.03, lo=700, hi=11500, pitch=0.92, rel=-22.0)
		sub = _bulkhead(k, pitch_base=0.76, lp_hz=195.0, length=0.26)
		st = V.seg(V.fs(V.STUN), 0.1 + 0.2 * k, 0.42, fin=0.01, fout=0.18, lo=280, hi=7800, pitch=0.84)
		lt_src = V.fs(V.LIGHTNING)
		lt_t = (0.12 + 0.30 * k) % max(0.2, len(lt_src) / RATE - 0.90)
		lt = V.seg(lt_src, lt_t, 0.88, fin=0.01, fout=0.35, lo=110, hi=7200, pitch=0.82)
		layers.append((0.0, V.norm(latch, -4.5)))
		layers.append((want, V.norm(sub, 0.0)))
		layers.append((want + 0.01, V.norm(st, -4.0)))
		layers.append((want + 0.02, V.norm(lt, -5.0)))
	mix = V.stack(length, *layers)
	mix = soft_clip(mix * 1.32, 0.93)
	target = -10.5 if heavy else -11.5
	return _mono(B.fade(mix, 0.0, 0.14 if heavy else 0.07), target)


def make_hit_body(k):
	"""Visceral dark-matter plasma blade hit on body (0.42s)."""
	length = 0.42
	base = V.pro(f"punch_grit_wet_impact_0{k % 5 + 1}")[: int(length * RATE)]
	el = V.seg(V.fs(V.ELECTRICITY), 0.2 + 0.6 * k, 0.20, fin=0.0, fout=0.07, lo=1500, hi=12500, pitch=0.96 + 0.06 * k, rel=-22.0)
	zp = V.seg(V.fs(V.ZAP if k % 2 == 0 else V.ZAP_EGO), 0.0, 0.18, fin=0.0, fout=0.06, lo=800, hi=11000, pitch=0.92, rel=-22.0)
	sub = _bulkhead(k, pitch_base=0.92, lp_hz=210.0, length=0.14)
	x = V.stack(
		length,
		(0.0, V.norm(base, 0.0)),
		(0.0, V.norm(sub, -4.5)),
		(0.004, V.norm(el, -4.0)),
		(0.008, V.norm(zp, -5.5)),
	)
	return _mono(B.fade(x, 0.0, 0.08), -12.5)


def make_hit_wall(k):
	"""Sharp forged-metal + plasma spark ricochet on walls (0.38s)."""
	length = 0.38
	base = V.pro(f"impact_hard-0{k % 3 + 1}")[: int(length * RATE)]
	sw = V.seg(V.fs(V.SWORD), 0.0, 0.20, fin=0.0, fout=0.08, lo=1600, hi=12000, pitch=1.18 + 0.05 * k, rel=-22.0)
	el = V.seg(V.fs(V.ELECTRICITY), 0.4 + 0.5 * k, 0.16, fin=0.0, fout=0.06, lo=2000, hi=12500, pitch=1.12, rel=-22.0)
	x = V.stack(
		length,
		(0.0, V.norm(base, 0.0)),
		(0.002, V.norm(sw, -4.5)),
		(0.005, V.norm(el, -4.0)),
	)
	return _mono(B.fade(x, 0.0, 0.07), -13.5)


def make_inspect_start():
	"""Reverse-grip wrist flick + staggered 3-scale mechanical ripple open + rising plasma hum (0.78s)."""
	length = 0.78
	wh = V.pro("whoosh_swish_high_fast_02")[: int(0.24 * RATE)]
	c1 = V.seg(V.fs(V.LATCH), 0.0, 0.12, fin=0.0, fout=0.04, lo=600, hi=12000, pitch=0.92, rel=-22.0)
	c2 = V.seg(V.fs(V.METAL_CLICK), 0.0, 0.10, fin=0.0, fout=0.03, lo=850, hi=12000, pitch=1.08, rel=-22.0)
	c3 = V.seg(V.fs(V.METAL_CLICK), 0.0, 0.10, fin=0.0, fout=0.03, lo=950, hi=12000, pitch=1.22, rel=-22.0)
	st = V.seg(V.fs(V.STUN), 0.1, 0.56, fin=0.10, fout=0.18, lo=320, hi=7500, pitch=0.96)
	cr = V.seg(V.fs(V.CRACKLE), 0.3, 0.52, fin=0.08, fout=0.16, lo=1800, hi=12000, pitch=1.10)
	x = V.stack(
		length,
		(0.00, V.norm(wh, -3.5)),
		(0.14, V.norm(c1, -2.5)),
		(0.22, V.norm(c2, -2.0)),
		(0.30, V.norm(c3, -1.5)),
		(0.16, V.norm(st, -6.0)),
		(0.20, V.norm(cr, -6.5)),
	)
	return _mono(B.fade(x, 0.0, 0.12), -14.0)


def make_inspect_spin():
	"""Smooth forged-steel wrist-roll turn + electric plasma wave sweep down the blade (0.72s)."""
	length = 0.72
	sw = V.seg(V.fs(V.SWORD), 0.0, 0.32, fin=0.01, fout=0.12, lo=1000, hi=11500, pitch=0.96, rel=-22.0)
	wh = V.pro("whoosh_swish_high_fast_03")[: int(0.24 * RATE)]
	st = V.seg(V.fs(V.STUN), 0.08, 0.48, fin=0.05, fout=0.16, lo=300, hi=8200, pitch=1.08)
	cr = V.seg(V.fs(V.CRACKLE), 0.12, 0.56, fin=0.04, fout=0.16, lo=1600, hi=12500, pitch=1.14)
	el = V.seg(V.fs(V.ELECTRICITY), 0.15, 0.22, fin=0.0, fout=0.08, lo=1800, hi=12500, pitch=1.12, rel=-22.0)
	x = V.stack(
		length,
		(0.00, V.norm(wh, -4.5)),
		(0.04, V.norm(sw, -1.5)),
		(0.08, V.norm(st, -4.5)),
		(0.10, V.norm(cr, -3.5)),
		(0.18, V.norm(el, -2.5)),
	)
	return _mono(B.fade(x, 0.01, 0.12), -12.5)


def make_inspect_lock():
	"""Snappy 3->2->1 spine scale SLAM shut + crisp metallic latch finish (0.48s)."""
	length = 0.48
	c1 = V.seg(V.fs(V.METAL_CLICK), 0.0, 0.09, fin=0.0, fout=0.03, lo=950, hi=12000, pitch=1.16, rel=-22.0)
	c2 = V.seg(V.fs(V.METAL_CLICK), 0.0, 0.09, fin=0.0, fout=0.03, lo=900, hi=12000, pitch=1.00, rel=-22.0)
	sl = V.seg(V.fs(V.SLIDE_LOCK), 0.0, 0.18, fin=0.0, fout=0.05, lo=600, hi=12000, pitch=0.90, rel=-22.0)
	sub = _bulkhead(2, pitch_base=0.94, lp_hz=230.0, length=0.14)
	zp = V.seg(V.fs(V.ZAP_EGO), 0.0, 0.18, fin=0.0, fout=0.07, lo=1400, hi=12000, pitch=1.10, rel=-22.0)
	x = V.stack(
		length,
		(0.00, V.norm(c1, -3.5)),
		(0.055, V.norm(c2, -2.5)),
		(0.11, V.norm(sl, -1.0)),
		(0.115, V.norm(sub, -2.5)),
		(0.12, V.norm(zp, -3.5)),
	)
	return _mono(B.fade(x, 0.0, 0.08), -13.0)


def write_wav(name, data):
	path = os.path.join(OUT, name + ".wav")
	sf.write(path, data.astype(np.float32), RATE, subtype="PCM_16")
	return {"name": name, "path": path, "length": round(len(data) / RATE, 3)}


def main():
	manifest = []
	manifest.append(write_wav("RFK_draw_01", make_draw()))
	for k in range(3):
		manifest.append(write_wav(f"RFK_fire_0{k + 1}", make_slash(k, heavy=False)))
	for k in range(2):
		manifest.append(write_wav(f"RFK_heavy_0{k + 1}", make_slash(k, heavy=True)))
	for k in range(3):
		manifest.append(write_wav(f"RFK_hitBody_0{k + 1}", make_hit_body(k)))
		manifest.append(write_wav(f"RFK_hitWall_0{k + 1}", make_hit_wall(k)))
	manifest.append(write_wav("RFK_inspectStart_01", make_inspect_start()))
	manifest.append(write_wav("RFK_inspectSpin_01", make_inspect_spin()))
	manifest.append(write_wav("RFK_inspectLock_01", make_inspect_lock()))

	with open(os.path.join(OUT, "manifest.json"), "w", newline="\n") as f:
		json.dump(manifest, f, indent=2)
	print(f"Designed {len(manifest)} Riftfang Knife WAVs -> {OUT}")


if __name__ == "__main__":
	main()
