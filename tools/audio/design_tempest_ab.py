"""Tempest-Strike shots, round 4: A/B for the owner (2026-11-22). After v3 the
owner said the Stinger, Marshal and Sheriff "mostly just sound like the
original ... we gotta add some stuff to make it sound much better" (the Bucky
is a shotgun, lower priority but not just stock either).

v1-v3 were the stock ProPack shot with layers on top, EQ'd to sit over it, so
the stock shot always led. Here each gun is built from Pole Position's pro
recordings of real guns (Sonniss GDC 2016) as the core, one job per mic:

  crack   the close or on-gun mic: the snap and the mechanism
  body    a 1 m mic of the same or a heavier gun: the weight
  bite    a second gun's close mic, high-passed: a metallic edge
  tail    the 50-55 m mic: the space (its flight delay removed by the onset align)
  thump   the steel bulkhead hit, low-passed (the sub punch, as in v3)
  skin    the Tempest water crack and electric snap (louder than v3)

glued with the class finish (design_gun_sfx: SMG, MARKSMAN, MAGNUM, SHOTGUN),
not EQ'd toward the stock shot, and levelled +1.5 dB over it.

  A  pro-designed only (no stock layer)
  B  the same with the stock ProPack shot tucked under it (-7 dB)

    python -I tools/audio/design_tempest_ab.py            # the A/B takes and reel
    python -I tools/audio/design_tempest_ab.py --set B    # + the picked variant's far / first takes

Writes art-source/audio/tempest/line_v1/ab/<Gun>_<A|B>_fire_NN.wav and
_reel.wav / _reel.txt (stock, A, B per gun; the Stinger also in sprays).
"""

import os
import sys

import numpy as np
import soundfile as sf

sys.path.insert(0, os.path.dirname(__file__))
import build_gun_sfx as B  # noqa: E402
import design_gun_sfx as D  # noqa: E402
import design_tempest_line as L  # noqa: E402
import design_tempest_vandal as V  # noqa: E402
from build_sound_atlas import eq, stereo  # noqa: E402

RATE = V.RATE
OUT = os.path.join(L.OUT, "ab")

# (pro recording, seconds, high-pass, low-pass, dB, pitch)
PRO = {
	"Stinger": dict(
		finish=D.SMG, length=0.3, cut=0.143, stock=L.M + "shot_0{}", stock_takes=9,
		layers=[
			("HK_MP7_4.6mm_on_gun", 0.12, 500, None, 0.0, 1.0),  # crack + action
			("HK_MP7_4.6mm_1m_left", 0.25, 120, 9000, -2.0, 0.98),  # body
			("FN_P90_5.7mm_1m_left", 0.25, 90, 8000, -4.0, 0.95),  # weight
			("Uzi_9mm_1m_right", 0.2, 1500, None, -9.0, 1.04),  # bite
		],
		water=-7.0, zap=(-8.0, -11.0), thump=-10.0, post=[("peak", 300, 4.5, 0.8)],
	),
	"Marshal": dict(
		finish=D.MARKSMAN, length=1.4, stock=L.RF + "shot_0{}", stock_takes=4,
		layers=[
			("Remington_700_7.62x51mm_1m_right", 0.6, 60, None, 0.0, 1.0),  # crack + body
			("Sako_TRG_22_TRG_1m_left", 0.5, 90, 9000, -4.0, 0.97),  # weight
			("Barrett_M98B_.338_Lapua_on_gun", 0.25, 1100, None, -3.0, 1.06),  # bite (the air: the 7.62 mics are dark)
			("Remington_700_7.62x51mm_50m_behind", 1.4, 150, 4500, -10.0, 1.0),  # tail
		],
		water=-4.0, zap=(-7.0, -10.0), thump=-7.0, post=[("peak", 300, 5.0, 0.8), ("high", 7000, 9.0)],
	),
	"Sheriff": dict(
		finish=D.MAGNUM, length=1.0, stock=L.R + "shot_0{}", stock_takes=4,
		layers=[
			("Smith_&_Wesson_M66_.357_Magnum_1m_left", 0.5, 60, None, 0.0, 1.0),  # crack + body
			("Smith_&_Wesson_M29_.44_Magnum_1.5m_behind", 0.6, 40, 9000, -3.0, 0.97),  # boom
			("SIG_P229_9mm_1m_left", 0.15, 1500, None, -9.0, 1.03),  # snap
			("Smith_&_Wesson_M66_.357_Magnum_50m_behind", 1.0, 150, 4500, -11.0, 1.0),  # tail
		],
		water=-5.0, zap=(-7.5, -11.0), thump=-8.0, post=[("peak", 300, 4.0, 0.8)],
	),
	"Bucky": dict(
		finish=D.SHOTGUN, length=1.4, stock=L.SG + "shot_0{}", stock_takes=4,
		layers=[
			("SAIGA-12_12g_solid_slug_1m_left", 0.5, 40, 8000, 0.0, 1.0),  # boom
			("USAS-12_12g_solid_slug_1m_right", 0.35, 60, 7000, -4.0, 0.98),  # body
			("SPAS-12_12g_solid_slug_1m_right", 0.3, 600, None, -6.0, 1.03),  # bite
			("SAIGA-12_12g_solid_slug_55m", 1.4, 120, 4000, -10.0, 1.0),  # tail
		],
		water=-3.0, zap=(-8.0, -11.0), thump=-6.0, post=[("peak", 300, 5.0, 0.8), ("high", 7000, 6.0)],
	),
}


def target(gun):
	p = PRO[gun]
	return float(np.mean([B.short_max(V.stock(p["stock"].format(i + 1))) for i in range(p["stock_takes"])])) + 1.5


def designed(gun, k, variant, full=False):
	p = PRO[gun]
	length = p["length"]
	layers = []
	for name, ln, lo, hi, gain, pitch in p["layers"]:
		layers.append((gain, L.gdc_shot(name, k, ln, lo, hi, pitch * (1 - 0.012 * (k % 3))), 0.3))
	# the crack layer is the reference the others align to
	core = layers.pop(0)[1]
	layers.append(V.water_crack(k, 0.1, p["water"]))
	on = k % 2 == 0
	layers.append(V.electric_snap(k, gain=p["zap"][0] if on else p["zap"][1]))
	layers.append((p["thump"], L.thump(k), 0.0))
	if variant == "B":
		stock = V.pro(p["stock"].format(k % p["stock_takes"] + 1))[: int(length * RATE)]
		layers.append((-7.0, stock, 0.0))
	x = V.stack(length + 0.05, *V.aligned(V.norm(core), *layers))[: int(length * RATE)]
	f = dict(p["finish"])
	f.pop("target")
	x = D.finish(x, target(gun), **f)
	# the class finish scoops the low mids (its 320 Hz cut + the thump): a body
	# lift, and air for the recordings that are dark on top, then re-levelled
	if p.get("post"):
		x = B.master_tp(eq(x, p["post"]), target(gun))
	x = B.fade(x, 0, min(0.06, length * 0.3) if length < 0.5 else length * 0.35)
	if p.get("cut") and not full:
		x = B.fade(x[: int(p["cut"] * RATE)], 0, 0.03)
	return x


def far(gun, k, variant):
	"""What other players hear: the designed shot with its skin layers pulled
	back, darker and 2 dB down (cut to the fire interval on auto guns)."""
	p = PRO[gun]
	keep = p["water"], p["zap"]
	p["water"], p["zap"] = p["water"] - 6, (p["zap"][1] - 3, p["zap"][1] - 3)
	x = designed(gun, k, variant, full=True)
	p["water"], p["zap"] = keep
	x = B.master_tp(L.lp(x, 5000, 2), target(gun) - 2.0)
	if p.get("cut"):
		x = B.fade(x[: int(p["cut"] * RATE)], 0, 0.03)
	return x


def write_set(variant):
	"""The chosen variant's in-game takes (owner picked B for all, 2026-11-22):
	fire, fireFar and the Stinger's fireFirst (water up, snap on)."""
	for gun in PRO:
		for k in range(3):
			x = far(gun, k, variant)
			sf.write(os.path.join(OUT, f"{gun}_{variant}_fireFar_{k + 1:02d}.wav"), x.astype(np.float32), RATE, subtype="PCM_16")
	p = PRO["Stinger"]
	keep = p["water"]
	p["water"] += 2
	x = designed("Stinger", 0, variant)
	p["water"] = keep
	sf.write(os.path.join(OUT, f"Stinger_{variant}_fireFirst_01.wav"), x.astype(np.float32), RATE, subtype="PCM_16")


def main():
	os.makedirs(OUT, exist_ok=True)
	if "--set" in sys.argv:
		write_set(sys.argv[sys.argv.index("--set") + 1])
		return
	clips = {}
	for gun in PRO:
		for variant in ("A", "B"):
			for k in range(6 if gun == "Stinger" else 4):
				x = designed(gun, k, variant)
				clips[f"{gun}_{variant}_fire_{k + 1:02d}"] = x
				sf.write(os.path.join(OUT, f"{gun}_{variant}_fire_{k + 1:02d}.wav"), x.astype(np.float32), RATE, subtype="PCM_16")
	reel(clips)
	for n, x in clips.items():
		if n.endswith("_01"):
			print(f"  {n:22s} {len(x) / RATE:5.2f}s loud {B.short_max(x):6.1f} tp {B.tp_db(x):6.2f}")


def reel(clips):
	w = B.weapon_data()
	out = np.zeros((int(RATE * 120), 2))
	cues, t = [], 0.5

	def put(x, at):
		i = int(at * RATE)
		out[i : i + len(x)] += stereo(x)

	def label(s):
		cues.append(f"{t:6.2f}  {s}")

	for gun, p in PRO.items():
		gap = 0.6 if p["length"] < 0.5 else p["length"] * 0.75
		label(f"{gun}: STOCK x3")
		for i in range(3):
			put(V.stock(p["stock"].format(i + 1)), t + i * gap)
		t += 3 * gap + 0.9
		for variant in ("A", "B"):
			label(f"{gun}: {variant} x3" + ("  (pro-designed, no stock)" if variant == "A" else "  (pro-designed + stock under it)"))
			for i in range(3):
				put(clips[f"{gun}_{variant}_fire_{i + 1:02d}"], t + i * gap)
			t += 3 * gap + 0.9
		if gun == "Stinger":
			fi = w[gun]["fireInterval"]
			tail = V.stock(L.M + "shot_00_tail_only_01")
			for variant in ("STOCK", "A", "B"):
				label(f"Stinger spray: {variant}")
				for i in range(12):
					x = V.stock(L.M + f"shot_0{i % 9 + 1}") if variant == "STOCK" else clips[f"Stinger_{variant}_fire_{i % 6 + 1:02d}"]
					put(x, t + i * fi)
				put(tail, t + 11 * fi + 0.05)
				t += 12 * fi + 2.2
	out = out[: int(RATE * t)]
	out *= 0.98 / max(np.abs(out).max(), 0.98)
	sf.write(os.path.join(OUT, "_reel.wav"), out.astype(np.float32), RATE, subtype="PCM_16")
	with open(os.path.join(OUT, "_reel.txt"), "w", encoding="utf-8") as f:
		f.write("Tempest-Strike shots round 4: A/B (seconds)\nA = pro-designed only, B = pro-designed + the stock shot under it\n\n" + "\n".join(cues) + "\n")


if __name__ == "__main__":
	main()
