"""Design the Smoke and Electric Shock power cues (battle pass powers, 2026-11-27).

The owner disliked the placeholder library picks, so these are built the way the Arcade cues were:
licensed recordings (the project's ProPack and the Sonniss GDC 2016 bundle, both royalty-free for the
game, never redistributed) layered with our own synthesis (filtered noise, sweeps, sub thumps, crackle
generators). Outputs are private 48 kHz mono WAVs in art-source/audio/powers/ (git-ignored) plus an
audition reel _Reel.wav / _Reel.txt.

    python tools/audio/design_powers.py
"""
import glob
import json
from pathlib import Path

import numpy as np
import soundfile as sf

from build_sound_atlas import bp, hp, lp, resample
from build_gun_sfx import fade

RATE = 48000
ROOT = Path(__file__).resolve().parents[2]
PACK = ROOT / "art-source/audio/ProPack"
GDC = ROOT / "art-source/audio/library/GDC2016"
OUT = ROOT / "art-source/audio/powers"

# Library sources: (glob under GDC2016, start s, length s)
SRC = {
	"hairspray": "*/Kevin Durr - Essential Bathroom Sounds/hairspray 2.wav",
	"compressor": "*/Collected Transients - Machine Emanation/Air Compressor_Stress Adjustment_Contact.wav",
	"airpuff": "*/JC Sound - Early Gasoline Engines/EGEngines_johndeeretypeE_fastairpuff_chuff_airpipe_compressed.wav",
	"sweetener": "*/SoundMorph - INTERVENTION/Explosives - Sweetners_07.wav",
	"boom": "*/Bottle Rocket Fx - Impact Collection/Impact_Boom_Distorted_02.wav",
	"thunderdrum": "*/MatiasMacSD - FEEL TEXTURES VOL 1/TextureThunderDrum_008.wav",
	"signum": "*/Blik Blinks - SIGNUM_ Sci-fi Cinematic SFX Pack/Signum_source_composite_impact_2.wav",
	"vaporize": "*/Alexander Kopeikin - Sci-Fi Metal Elements HD/sci-fi metal destruction tone, vaporizing metal, cracking.wav",
	"energy": "*/SoundMorph - Future Weapons 2/Future Weapons 2 - Energy Gun - shot_single_2.wav",
	"buzz": "*/ShapingWaves -  CIRCUITS/SW007_Circuits_009_Electric_Hum_Buzz_Noisy.wav",
	"static": "*/SoundMorph - Lost Transmissions/Lost Transmissions - Static Passbys_51.wav",
	"rod": "*/SoundBits -  Just Whoosh 3 _ Whoosh Essentials/Whoosh_Rod_Pole_022.wav",
	"shaver": "*/Soundreorganized - Everyday Actions 1/Shaving,Electric,DifferentPositions,Buzz,Close.wav",
}

_cache = {}


def load(key):
	if key not in _cache:
		path = sorted(glob.glob(str(GDC / SRC[key])))[0]
		x, rate = sf.read(path, always_2d=True)
		x = x.mean(axis=1)
		_cache[key] = x if rate == RATE else resample(x, RATE / rate)
	return _cache[key]


def pack(family, take):
	x, rate = sf.read(PACK / "audition" / f"bonus {family}" / f"{family}_{take:02}.wav", always_2d=True)
	x = x.mean(axis=1)
	return x if rate == RATE else resample(x, RATE / rate)


def n(sec):
	return max(1, round(sec * RATE))


def norm(x, db=0.0):
	return x * (10 ** (db / 20) / max(np.abs(x).max(), 1e-9))


def fades(x, fin=0.001, fout=0.02):
	return fade(x[:, None], fin, min(fout, len(x) / RATE * 0.4))[:, 0]


def cut(key, start, length, speed=1.0, db=0.0, low=None, high=None, onset=False):
	"""A slice of a library recording, optionally pitched (speed > 1 = higher), filtered, normalized."""
	x = load(key)
	i = n(start)
	if onset:  # snap to the first transient after `start`
		seg = np.abs(x[i:i + n(2)])
		i += max(0, int(np.argmax(seg > seg.max() * 0.12)) - n(0.002))
	x = x[i:i + n(length * speed)]
	if speed != 1.0:
		x = resample(x, 1 / speed)
	if high:
		x = lp(x, high, 2)
	if low:
		x = hp(x, low, 2)
	return norm(fades(x, 0.001, 0.03), db)


def place(parts, length=None):
	total = max(n(at) + len(x) for at, x in parts)
	out = np.zeros(max(total, n(length) if length else 0))
	for at, x in parts:
		i = n(at)
		out[i:i + len(x)] += x
	return out


def t(sec):
	return np.arange(n(sec)) / RATE


def noise(sec, seed):
	return np.random.default_rng(seed).standard_normal(n(sec))


def env_exp(sec, decay, attack=0.001):
	tt = t(sec)
	return np.minimum(1, tt / max(attack, 1e-4)) * np.exp(-tt / decay)


def sweep(sec, f0, f1, decay=None, shape="sine", curve=1.0):
	tt = t(sec)
	k = (tt / sec) ** curve
	f = f0 * (f1 / f0) ** k
	ph = 2 * np.pi * np.cumsum(f) / RATE
	x = np.sin(ph) if shape == "sine" else np.sign(np.sin(ph)) * 0.6
	if decay:
		x *= np.exp(-tt / decay)
	return x


def crackle(sec, density, seed, lo=1800, hi=9000, decay_rate=None):
	"""Sparse electric crackle: random impulses (density/s, thinning over time if `decay_rate`) rung through a band."""
	rng = np.random.default_rng(seed)
	x = np.zeros(n(sec))
	tt = 0.0
	while tt < sec:
		d = density * (np.exp(-tt / decay_rate) if decay_rate else 1)
		tt += rng.exponential(1 / max(d, 1))
		i = n(tt)
		if i >= len(x):
			break
		ln = n(rng.uniform(0.001, 0.006))
		burst = rng.standard_normal(ln) * np.exp(-np.arange(ln) / max(ln / 3, 1)) * rng.uniform(0.3, 1)
		x[i:i + ln] += burst[: len(x) - i]
	return bp(x, lo, hi, 2)


def crack(sec, seed, lo=900):
	"""A thunder crack: a cluster of razor-sharp broadband transients (the 'ear-splitting' part)."""
	rng = np.random.default_rng(seed)
	out = np.zeros(n(sec))
	for k in range(9):
		at = rng.uniform(0, 0.05) if k else 0.0
		ln = n(rng.uniform(0.03, 0.12))
		b = rng.standard_normal(ln) * np.exp(-np.arange(ln) / (ln / rng.uniform(3, 6))) * rng.uniform(0.5, 1)
		i = n(at)
		out[i:i + ln] += b[: len(out) - i]
	out = hp(out, lo, 2)
	return np.tanh(norm(out) * 2.2)


def rumble(sec, seed, lo=35, hi=420, swells=5, decay=1.4):
	"""Rolling thunder: low noise in slow, uneven swells that die away."""
	rng = np.random.default_rng(seed)
	x = lp(hp(noise(sec, seed), lo, 2), hi, 3)
	tt = t(sec)
	e = np.zeros_like(tt)
	for _ in range(swells):
		c = rng.uniform(0.05, sec * 0.7)
		w = rng.uniform(0.15, 0.6)
		e += rng.uniform(0.4, 1) * np.exp(-((tt - c) / w) ** 2)
	e = (0.35 + e) * np.exp(-tt / decay)
	return x * e


def sub(sec, f0, f1, decay):
	return sweep(sec, f0, f1, decay=decay, curve=0.5) * np.minimum(1, t(sec) / 0.002)


def crush(x, bits=5, hold=6):
	"""Glitch: sample-and-hold + bit reduction."""
	y = np.repeat(x[::hold], hold)[: len(x)]
	q = 2 ** (bits - 1)
	return np.round(y * q) / q


def stutter(x, seg=0.03, repeats=3):
	s = x[: n(seg)]
	return np.concatenate([s] * repeats + [x])


def limit(x, drive=1.6, ceiling=-0.8):
	return norm(np.tanh(norm(x) * drive), ceiling)


def loopable(x, xf=0.25):
	"""Crossfade the tail into the head so it loops without a seam."""
	k = n(xf)
	head, tail = x[:k], x[-k:]
	w = np.linspace(0, 1, k)
	mixed = tail * (1 - w) + head * w
	return np.concatenate([mixed, x[k:-k]])


def trim(x, sec):
	x = x[: n(sec)]
	return fades(x, 0.0008, 0.04)


# Smoke ---------------------------------------------------------------------------------------------------

def smoke_cues():
	c = {}
	grab = norm(pack("foley_soldier_gear_equipment_movement_grab_item", 3)[: n(0.25)], -3)
	tick = norm(pack("metal_small_movement", 2)[: n(0.12)], -8)
	valve = norm(bp(noise(0.12, 11), 3000, 9000) * env_exp(0.12, 0.03), -14)
	grab = grab * env_exp(len(grab) / RATE, 0.07, attack=0.002)
	c["smoke_equip"] = trim(place([(0, hp(grab, 120)), (0.05, tick * env_exp(0.12, 0.03)), (0.08, valve)]), 0.3)

	ping = sweep(0.2, 3400, 3200, decay=0.05) * 0.6 + sweep(0.2, 5100, 5000, decay=0.03) * 0.3
	pull = norm(pack("metal_small_movement", 5)[: n(0.1)], -4)
	c["smoke_pin"] = trim(place([(0, hp(pull, 400)), (0.03, norm(ping, -6))]), 0.25)

	whoosh = cut("rod", 0.0, 0.5, speed=1.15, high=9000, low=250, onset=True)
	c["smoke_throw"] = trim(whoosh, 0.4)

	clink = pack("metal_sheet_impacts", 4)
	i = max(0, int(np.argmax(np.abs(clink) > np.abs(clink).max() * 0.2)) - n(0.001))
	clink = clink[i:i + n(0.25)]
	clink = norm(hp(clink, 600) * env_exp(0.25, 0.045, attack=0.0005), -2)
	ring = norm(sweep(0.25, 2100, 2050, decay=0.06) + 0.5 * sweep(0.25, 3300, 3280, decay=0.04), -12)
	c["smoke_bounce"] = trim(place([(0, clink), (0.002, ring)]), 0.25)

	# The pop: a sharp pressurised burst (real aerosol + air chuff), a soft low whump, an airy bloom tail.
	spray = cut("hairspray", 0.88, 0.32, speed=0.82, low=700, high=12000, db=0, onset=True)
	chuff = cut("airpuff", 0.42, 0.25, speed=0.9, low=150, high=8000, db=-4, onset=True)
	burst = norm(bp(noise(0.4, 21), 1500, 11000) * env_exp(0.4, 0.07, attack=0.0015), -3)
	whump = norm(sub(0.6, 120, 42, 0.18) + 0.6 * lp(noise(0.6, 22), 200, 3) * env_exp(0.6, 0.12), -4)
	bloom_n = lp(hp(noise(1.4, 23), 300, 2), 3500, 2)
	bloom = norm(bloom_n * (np.minimum(1, t(1.4) / 0.08) * np.exp(-t(1.4) / 0.45)), -10)
	c["smoke_pop"] = limit(place([(0, burst), (0, spray), (0.01, chuff), (0, whump), (0.05, bloom)]), 1.3, -0.8)[: n(1.4)]
	c["smoke_pop"] = fades(c["smoke_pop"], 0.0005, 0.25)

	# The loop: soft rolling air, slow swells, no tones.
	air = lp(hp(noise(4.5, 31), 200, 2), 2600, 3)
	tt = t(4.5)
	roll = 0.75 + 0.25 * np.sin(2 * np.pi * tt / 2.25) * np.sin(2 * np.pi * tt / 1.5 + 1)
	c["smoke_loop"] = norm(loopable(air * roll, 0.5), -6)

	exhale = lp(hp(noise(1.2, 41), 250, 2), 4000, 2)
	tt = t(1.2)
	shape = np.minimum(1, tt / 0.12) * np.exp(-tt / 0.35)
	falling = np.array([1.0])
	c["smoke_fade"] = fades(norm(exhale * shape * falling, -4), 0.002, 0.3)
	return c


# Electric Shock --------------------------------------------------------------------------------------------

def shock_cues():
	c = {}
	# Arm: a rising electric charge with crackle and a snap at the top.
	# a real electric buzz sped up as it arms (pitch rising), over a filtered noise riser
	bz = load("buzz")[n(10): n(10) + n(1.2)]
	speeds = np.linspace(0.7, 2.2, n(0.5))
	idx = np.clip(np.cumsum(speeds) * (len(bz) / np.sum(speeds)) * 0.999, 0, len(bz) - 1).astype(int)
	rise = hp(bz[idx], 150) * np.linspace(0.25, 1, n(0.5)) ** 1.5
	rise = rise + 0.6 * norm(bp(noise(0.5, 50), 800, 9000) * np.linspace(0, 1, n(0.5)) ** 2)
	arm_crk = crackle(0.5, 90, 51, decay_rate=None) * np.linspace(0.2, 1, n(0.5))
	snap = norm(crack(0.12, 52, lo=1500), -6)
	c["shock_equip"] = trim(limit(place([(0, norm(rise, -6)), (0, norm(arm_crk, -8)), (0.4, snap)]), 1.2, -1), 0.5)

	# Throw: whoosh + zap tail.
	wh = cut("rod", 0.0, 0.45, speed=1.05, high=10000, low=200, onset=True)
	zap = norm(cut("energy", 0.0, 0.35, speed=1.2, low=300, onset=True), -4)
	c["shock_throw"] = trim(limit(place([(0, wh), (0.08, zap), (0.1, norm(crackle(0.3, 120, 53, decay_rate=0.12), -8))]), 1.2, -1), 0.45)

	# Flight / beacon loops: buzzing orb (real electric buzz + synthetic AM hum + crackle).
	def orb(sec, seed, base, speed, db):
		bz = load("buzz")[n(6): n(6) + n(sec * speed)]
		bz = resample(bz, 1 / speed)[: n(sec)]
		tt = t(sec)
		hum = np.sin(2 * np.pi * base * tt) * (0.75 + 0.25 * np.sin(2 * np.pi * (base / 22) * tt))
		hum += 0.4 * np.sign(np.sin(2 * np.pi * base * 2 * tt)) * 0.3
		mix = norm(hp(bz, 100), -3) + norm(lp(hum, 1800), -8) + norm(crackle(sec, 45, seed), -9)
		return norm(loopable(mix, 0.3), db)

	c["shock_flight"] = orb(2.3, 61, 110, 1.15, -4)
	c["shock_beacon"] = orb(2.3, 62, 70, 0.85, -5)

	# Latch: a hard snap + rising whine.
	snap = crack(0.2, 71, lo=1200)
	hit = cut("energy", 0.0, 0.3, speed=0.9, low=200, onset=True)
	whine = sweep(0.6, 900, 2600, curve=0.7) * np.minimum(1, t(0.6) / 0.05) * np.exp(-t(0.6) / 0.35)
	whine = whine + 0.5 * sweep(0.6, 1350, 3900, curve=0.7) * np.exp(-t(0.6) / 0.3)
	c["shock_latch"] = trim(limit(place([(0, norm(snap, -2)), (0, norm(hit, -4)), (0.04, norm(whine, -9)),
	                                     (0.02, norm(crackle(0.5, 160, 72, decay_rate=0.2), -8))]), 1.4, -1), 0.7)

	# Warning (for the marked player): an ominous rising sky charge with static build.
	tt = t(0.7)
	drone = sweep(0.7, 55, 110, curve=1.5) + 0.5 * sweep(0.7, 82, 165, curve=1.5)
	statb = bp(noise(0.7, 81), 1200, 7000) * (tt / 0.7) ** 2
	rise = sweep(0.7, 400, 2200, curve=2.2) * (tt / 0.7) ** 1.5
	build = 0.15 + 0.85 * (tt / 0.7) ** 1.3
	w = place([(0, norm(drone, -4)), (0, norm(statb, -10)), (0, norm(rise, -12)),
	           (0, norm(crackle(0.7, 40, 82) * (tt / 0.7), -10))])[: n(0.7)]
	c["shock_warning"] = trim(limit(w * build, 1.1, -1), 0.7)

	# Charge: the storm gathering overhead, crackling build ending exactly at the strike (0.9 s).
	tt = t(0.9)
	gather = lp(noise(0.9, 91), 500, 3) * (tt / 0.9) ** 1.6
	crk = crackle(0.9, 60, 92) * (0.2 + (tt / 0.9) ** 2 * 2)
	reverse = sweep(0.9, 60, 180, curve=2.5) * (tt / 0.9) ** 2
	c["shock_charge"] = fades(limit(place([(0, norm(gather, -6)), (0, norm(crk, -6)), (0, norm(reverse, -8))]), 1.2, -1),
	                         0.05, 0.004)[: n(0.9)]

	# THE SMITE: crack + huge sub boom + library booms + sizzle + long rolling thunder.
	L = 3.6
	cr = crack(0.25, 101, lo=700)
	cr2 = crack(0.4, 102, lo=250) * 0.7
	sweet = cut("sweetener", 0.0, 2.5, speed=0.85, db=0, onset=True)
	boom = cut("boom", 0.0, 3.0, speed=0.8, high=3500, db=0, onset=True)
	sig = cut("signum", 0.0, 2.0, speed=0.9, db=0, onset=True)
	drum = cut("thunderdrum", 0.3, 3.0, speed=0.75, high=2000, db=0)
	subb = sub(2.2, 85, 28, 0.7)
	thump = lp(noise(0.5, 103), 160, 3) * env_exp(0.5, 0.12)
	siz = crackle(1.6, 260, 104, lo=2500, hi=11000, decay_rate=0.4)
	vap = cut("vaporize", 0.15, 1.2, speed=1.0, low=1500, onset=True)
	roll = rumble(L, 105, swells=6, decay=1.3)
	# two late rolls of thunder (the sky answering), so the tail rolls instead of only dying away
	roll2 = rumble(2.2, 106, swells=3, decay=0.9) * np.minimum(1, t(2.2) / 0.25)
	parts = [
		(0.000, norm(cr, 0)), (0.008, norm(cr2, -4)),
		(0.000, norm(subb, -1)), (0.000, norm(thump, -3)),
		(0.005, norm(sweet, -4)), (0.010, norm(boom, -5)), (0.0, norm(sig, -7)),
		(0.03, norm(siz, -8)), (0.02, norm(vap, -12)),
		(0.10, norm(roll, -3)), (0.35, norm(drum, -8)), (1.05, norm(roll2, -6)),
	]
	s = place(parts)[: n(L)]
	s = limit(s, 2.0, -0.6)
	c["shock_strike"] = fades(s, 0.0003, 0.6)

	# Chain arc zap.
	arc = crackle(0.6, 400, 111, lo=1500, hi=10000, decay_rate=0.15)
	ez = cut("energy", 0.0, 0.4, speed=1.35, low=400, onset=True)
	c["shock_chain"] = trim(limit(place([(0, norm(crack(0.15, 112, lo=1800), -3)), (0, norm(arc, -4)), (0.01, norm(ez, -6))]), 1.4, -1), 0.6)

	# Storm Call bolt: a smaller glitched thunder crack (bit-crushed, stuttered).
	small = place([(0, norm(crack(0.2, 121, lo=600), 0)), (0, norm(sub(1.0, 95, 35, 0.3), -3)),
	               (0.05, norm(rumble(1.5, 122, swells=3, decay=0.5), -5)), (0.0, norm(cut("signum", 0.0, 1.2, speed=1.2, onset=True), -8))])
	glitchy = crush(small, bits=6, hold=4) * 0.6 + small * 0.6
	glitchy = stutter(glitchy, seg=0.028, repeats=2)
	c["shock_storm_bolt"] = fades(limit(glitchy, 1.6, -1)[: n(1.5)], 0.0005, 0.4)

	# Fizzle: dying sparks.
	dying = crackle(0.6, 120, 131, decay_rate=0.15)
	pop = sweep(0.3, 1600, 300, decay=0.08)
	c["shock_fizzle"] = trim(norm(place([(0, norm(dying, -2)), (0, norm(pop, -10))]), -2), 0.6)
	return c


ORDER = ["smoke_equip", "smoke_pin", "smoke_throw", "smoke_bounce", "smoke_pop", "smoke_loop", "smoke_fade",
         "shock_equip", "shock_throw", "shock_flight", "shock_beacon", "shock_latch", "shock_warning",
         "shock_charge", "shock_strike", "shock_chain", "shock_storm_bolt", "shock_fizzle"]
LOOPS = {"smoke_loop", "shock_flight", "shock_beacon"}


def main():
	OUT.mkdir(parents=True, exist_ok=True)
	made = {**smoke_cues(), **shock_cues()}
	info = {}
	for key in ORDER:
		x = made[key]
		x = norm(x, -3 if key in LOOPS else -0.8)
		x = np.pad(x, (0, max(0, n(0.12) - len(x))))
		made[key] = x
		sf.write(OUT / f"{key}.wav", x, RATE, subtype="PCM_16")
		head = np.abs(x[: n(0.01)]).max()
		info[key] = {"length": round(len(x) / RATE, 3), "peak": round(float(np.abs(x).max()), 3),
		             "head10ms": round(float(head), 3), "loop": key in LOOPS}
	(OUT / "_cues.json").write_text(json.dumps(info, indent=2) + "\n", encoding="utf-8")
	parts, at, lines = [], 0.3, []
	for key in ORDER:
		x = made[key]
		if key in LOOPS:
			x = np.concatenate([x, x])  # twice: hear the seam
		parts.append((at, x * 0.9))
		lines.append(f"{at:7.2f}s  {key}")
		at += len(x) / RATE + 0.6
	reel = place(parts)
	sf.write(OUT / "_Reel.wav", reel, RATE, subtype="PCM_16")
	(OUT / "_Reel.txt").write_text("\n".join(lines) + "\n", encoding="utf-8")
	for k, v in info.items():
		print(k, v)


if __name__ == "__main__":
	main()
