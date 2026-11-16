"""Headshot and kill sound candidates for the owner to listen to (2026-11-15:
"find a better kill and headshot sound"). Nothing here is uploaded or wired:
it renders WAVs and two reels into art-source/audio/ProPack/audition/ (a
git-ignored folder) and prints how each measures against the live sounds.

    python tools/audio/hit_candidates.py        # batch 1
    python tools/audio/hit_candidates.py 2      # batch 2 (measured on the owner's clip)
    python tools/audio/hit_candidates.py 3      # batch 3 (no sub; also each one after a gunshot)
    python tools/audio/hit_candidates.py 4      # batch 4 (soft low shings, subtle kills)
    python tools/audio/hit_candidates.py 5      # batch 5 (headshots in K13's family: crisp pops, no metal)
    python tools/audio/hit_candidates.py final  # the owner's picks, as cues for migrate_gun_sounds.py
    python tools/audio/hit_candidates.py final-kill  # his kill pick from batch 4 (K13), as the cue kill_F
    python tools/audio/hit_candidates.py final-head  # his headshot pick from batch 5 (H18), as the cue hit_head_F

Rules it follows (vault/02 Art/Sound Library Pick.md §16-18, the owner's ear):
headshot: no metallic ring, nothing high pitched or sharp, weight you can
feel; kill: "a nice little positive kind of thing". Real recordings only
(Sonniss GDC 2016 bundle and the pro pack), layered; no synthesis.
"""

import os
import sys

import numpy as np
import soundfile as sf
from scipy import signal

sys.path.insert(0, os.path.dirname(__file__))
import build_pro_atlas as B  # noqa: E402

RATE = B.RATE
LIBRARY = os.path.join(B.ROOT, "art-source", "audio", "library")
STANDALONE = os.path.join(B.OUT, "standalone")
OUT = os.path.join(B.OUT, "audition", "2026-11-15 headshot and kill")


def find(part):
	for folder, _dirs, files in os.walk(LIBRARY):
		for name in files:
			if part.lower() in name.lower() and name.lower().endswith(".wav"):
				return os.path.join(folder, name)
	raise SystemExit("not in the library: " + part)


def read(path):
	x, sr = sf.read(path, always_2d=True)
	x = x[:, :2] if x.shape[1] >= 2 else np.repeat(x, 2, axis=1)
	if sr != RATE:
		x = signal.resample_poly(x, RATE, sr, axis=0)
	return x - x[:64].mean(axis=0)


def hit(part, length, pre=0.004, lp_hz=None, hp_hz=None):
	"""`length` seconds of a library file from just before its loudest moment."""
	x = read(find(part))
	i = int(np.argmax(np.abs(B.mono(x))))
	# Back up to where that event starts (30 dB under its peak, within 60 ms).
	m = np.abs(B.mono(x))
	lo = max(0, i - int(RATE * 0.06))
	quiet = np.nonzero(m[lo:i] < m[i] * 10 ** (-30 / 20))[0]
	start = lo + int(quiet[-1]) if len(quiet) else lo
	x = x[max(0, start - int(RATE * pre)) :][: int(RATE * length)]
	if hp_hz:
		x = B.hp(x, hp_hz)
	if lp_hz:
		x = B.lp(x, lp_hz)
	return B.fade(x, 0.001, min(0.06, len(x) / RATE * 0.4))


def measure(x):
	m = B.mono(x)
	# Energy per frequency over the whole sound (short frames summed: one
	# window over all of it fades out the start, where the strike is).
	freqs, _t, z = signal.stft(m, RATE, nperseg=2048, noverlap=1536, window="hann")
	spec = (np.abs(z) ** 2).sum(axis=1)
	total = spec.sum() + 1e-12
	env = np.abs(m)
	above = np.nonzero(env > env.max() * 10 ** (-30 / 20))[0]
	return {
		"length": (above[-1] - above[0]) / RATE if len(above) else 0.0,
		"centre": float((spec * freqs).sum() / total),
		"high": float(spec[freqs > 3000].sum() / total),
		"top": float(spec[freqs > 5000].sum() / total),
		"low": float(spec[freqs < 250].sum() / total),
	}


def candidates():
	thud = B.cut("punch_general_body_impact_03", 0.12)
	thump = B.cut("punch_general_body_impact_02", 0.14)
	drum = hit("Impact_Drum Hit_03", 0.2, lp_hz=2500)
	whip = hit("Swoosh_Rope_Whip_075", 0.12, lp_hz=6000, hp_hz=500)
	wood = B.lp(B.cut("wood_block_sticks_hit_clap_02", 0.22), 3500)
	stab = hit("Stab_Punch_Hit_136", 0.16)
	crunch = hit("Crunch_Rip_024", 0.12, lp_hz=5000, hp_hz=200)
	pop_toy = hit("Pop Toy_TS 02", 0.12)
	keeper = hit("Keeper_Punch_01", 0.16)
	glass = B.lp(B.speed(hit("Wine Glass Hit Higher Pitch", 0.5), 0.6), 5000)[: int(RATE * 0.3)]
	glass = B.fade(glass, 0.001, 0.12)
	pickup = hit("ItemPickUp16", 0.4)
	notify = hit("Notification01", 0.45, lp_hz=3000)
	# Each headshot is high-passed at 170 Hz after mixing: the punches and the
	# drum are mostly sub-bass, and with them at full the first renders came
	# out duller than the live sound (80-96% of the energy under 250 Hz).
	def clear(x):
		return B.hp(x, 170)

	head = {
		"H1 whip crack over a thud": clear(B.mix((whip, 0, 0), (thud, -10, 0))),
		"H2 wood thock on a drum": clear(B.mix((wood, 0, 0), (drum, -14, 0))),
		"H3 punch and crunch": B.lp(clear(B.mix((stab, 0, 0), (crunch, -4, 0))), 3500),
		"H4 whip crack on a heavy punch": B.hp(B.mix((whip, -2, 0), (keeper, -3, 0), (wood, -10, 0.002)), 110),
	}
	kill = {
		"K1 pickup chime over a thump": B.mix((pickup, 0, 0), (thump, -8, 0)),
		"K2 notification over a thump": B.mix((notify, 0, 0), (thump, -8, 0)),
		"K3 toy pop with a low glass ring": B.mix((pop_toy, 0, 0), (glass, -12, 0.01), (thump, -7, 0)),
		"K4 low glass ring on a drum": B.mix((glass, 0, 0.004), (pop_toy, -4, 0), (drum, -6, 0)),
	}
	return head, kill


def tuned(part, from_hz, to_hz, length, lp_hz=None):
	"""A tonal library hit played faster or slower so its strongest partial
	(`from_hz`, measured) lands on `to_hz`."""
	x = B.speed(hit(part, length * to_hz / from_hz + 0.06), to_hz / from_hz)
	# Past the strike's click (the first few ms: it is many times louder than
	# the ring, so with it the ring all but vanished under a thump).
	x = x[int(RATE * 0.007) :][: int(RATE * length)]
	if lp_hz:
		x = B.lp(x, lp_hz)
	return B.fade(x, 0.003, length * 0.6)


def blend(low, tone, share, delay=0.004):
	"""`low` with `tone` on top, scaled so the tone carries `share` of the
	energy (peak levels mislead here: a thump has many times a ring's energy
	at the same peak)."""
	gain = np.sqrt(share / (1 - share) * (low**2).sum() / ((tone**2).sum() + 1e-12))
	i = int(RATE * delay)
	out = np.zeros((max(len(low), i + len(tone)), 2))
	out[: len(low)] += low
	out[i : i + len(tone)] += tone * gain
	return out


GLASS = 3316.0  # the wine glass's strongest partial, Hz (measured)


def sub_thump():
	return hit("Impact_Drum Hit_03", 0.3, lp_hz=140)


def glass_ding(scale, length=0.3):
	"""The clip's two strong partials (5,027 and 3,094 Hz), times `scale`."""
	high = tuned("Wine Glass Hit Higher Pitch", GLASS, 5027 * scale, length)
	low = tuned("Wine Glass Hit Higher Pitch", GLASS, 3094 * scale, length)
	return B.mix((high, 0, 0), (low, -5, 0))


def final():
	"""The owner's picks from batch 2 (2026-11-15: "H5 and K5"), as game cues:
	  hit_head_E   H5, three takes a few % apart in pitch (the clip's ding
	               moves from 5,027 down to 4,441 Hz between hits)
	  kill_E       K5 (the game climbs its pitch per kill, Audio.KILL_LADDER)
	  kill_head_E  K5 with H5's ding on top
	Written into the standalone folder and its queue (tools/audio/
	migrate_gun_sounds.py uploads them and regenerates Config/GunSoundAssets):
	these cues are not in the atlas, so their queue entries are marked
	"standalone" and a later re-export keeps them."""
	import hashlib
	import json

	sub = sub_thump()
	thump = B.cut("punch_general_body_impact_02", 0.14)
	rise = B.mix((glass_ding(0.46, 0.22), 0, 0), (glass_ding(0.615, 0.3), 0, 0.075))
	kill = blend(B.mix((sub, 0, 0), (thump, -9, 0)), rise, 0.15, 0)
	cues = {
		"hit_head_E": ([blend(sub, glass_ding(k), 0.1) for k in (1.0, 0.955, 0.91)], B.HIT_TARGET["HitHead"]),
		"kill_E": ([kill], B.HIT_TARGET["Kill"]),
		"kill_head_E": ([blend(kill, glass_ding(1.0), 0.06, 0.03)], B.HIT_TARGET["KillHead"]),
	}
	queue_cues(cues)


def final_kill():
	"""The owner's kill pick from batch 4 (2026-11-15: "I like K13. We'll go
	with K13"): the soft bubble pop on a thud, as the cue kill_F, at the level
	he heard it (3 dB under the old kill target). Used for the headshot kill
	too until a headshot is picked (he passed on every headshot so far)."""
	_head, kill = batch4()
	queue_cues({"kill_F": ([kill["K13 soft bubble pop on a thud"]], B.HIT_TARGET["Kill"] - 3.0)})


def final_head():
	"""The owner's headshot pick from batch 5 (2026-11-15: "H18"): the bright
	pop with a dry crack, as the cue hit_head_F. Three takes: as he heard it,
	and 3% lower and higher (half a semitone), so headshots in a row are not
	one sample repeated."""
	head, _kill = batch5()
	x = head["H18 bright pop with a dry crack"]
	queue_cues({"hit_head_F": ([x, B.speed(x, 0.97), B.speed(x, 1.03)], B.HIT_TARGET["HitHead"])})


def queue_cues(cues):
	"""Writes `cues` ({name: (takes, level target)}) as standalone WAVs and
	queue entries for tools/audio/migrate_gun_sounds.py. Only these cues'
	files are written: the others in the queue stay byte for byte."""
	import hashlib
	import json

	queue_path = os.path.join(STANDALONE, "queue.json")
	with open(queue_path, encoding="utf-8") as f:
		queue = json.load(f)
	queue = [item for item in queue if item["cue"] not in cues]
	for cue, (takes, target) in cues.items():
		takes, makeup = B.level_family(takes, target)
		for index, take in enumerate(takes, 1):
			stem = f"{cue}-{index:02d}" if len(takes) > 1 else cue
			path = os.path.join(STANDALONE, stem + ".wav")
			sf.write(path, np.clip(take, -1, 1), RATE, subtype="PCM_16")
			m = measure(take)
			print("%-16s %4.0f ms  centre %5.0f Hz  above 3 kHz %4.1f%%  below 250 Hz %4.1f%%  makeup %.1f dB" % (stem, len(take) / RATE * 1000, m["centre"], m["high"] * 100, m["low"] * 100, makeup))
			with open(path, "rb") as f:
				digest = hashlib.sha256(f.read()).hexdigest()
			queue.append(
				{
					"bank": "gun",
					"cue": cue,
					"variant": index,
					"filename": stem + ".wav",
					"duration": len(take) / RATE,
					"gain": float(10 ** (makeup / 20)),
					"sha256": digest,
					"standalone": True,
				}
			)
	tmp = queue_path + ".tmp"
	with open(tmp, "w", encoding="utf-8") as f:
		f.write(json.dumps(queue, indent=2) + "\n")
	os.replace(tmp, queue_path)
	print("queued", ", ".join(cues), "in", queue_path)


def batch2():
	"""Batch 2 (the owner passed on batch 1). Measured on his own hits clip
	this time: RIVALS' headshot is a deep sub thump (peak ~35 Hz, 20 dB down
	in ~0.2 s) under a clean bell-like ding: partials near 3.1, 5.0 and
	6.5 kHz (20 dB down in ~0.2 s; pitch moved a few % between hits), with
	about 10% of the energy above 3 kHz. Batch 1 had no ding at all. The
	ding here is a wine glass (strongest partial 3,316 Hz, same decay) and a
	glass clink, tuned to those pitches and to lower ones (the owner found
	earlier high takes annoying; those were a noisy sword ring, not a clean
	tone)."""
	CLINK, CHIME = 2719.0, 1529.0
	sub = sub_thump()
	thump = B.cut("punch_general_body_impact_02", 0.14)
	ding = glass_ding

	clink = tuned("Glasses handle 03", CLINK, 3094, 0.16)
	chime = tuned("chime-texture-011", CHIME, 2064, 0.4)
	pickup = hit("ItemPickUp16", 0.3)
	head = {
		"H5 thump and glass ding, the clip's pitch": blend(sub, ding(1.0), 0.1),
		"H6 thump and glass ding, a fourth lower": blend(sub, ding(0.75), 0.1),
		"H7 thump and glass ding, an octave lower": blend(sub, ding(0.5), 0.1),
		"H8 thump and a short glass clink": blend(sub, clink, 0.1),
	}
	rise = B.mix((ding(0.46, 0.22), 0, 0), (ding(0.615, 0.3), 0, 0.075))
	kill = {
		"K5 two rising glass notes on a thump": blend(B.mix((sub, 0, 0), (thump, -9, 0)), rise, 0.15, 0),
		"K6 one low glass ding on a thump": blend(B.mix((sub, 0, 0), (thump, -9, 0)), ding(0.4, 0.35), 0.15, 0),
		"K7 chime on a thump": B.mix((chime, -4, 0), (sub, 0, 0), (thump, -9, 0)),
		"K8 pickup pop with a glass ding": B.mix((pickup, 0, 0), (ding(0.615, 0.3), -8, 0.03), (sub, -4, 0)),
	}
	return head, kill


def batch3():
	"""Batch 3 (2026-11-15, later: the owner picked H5 and K5 from batch 2 by
	ear, then did not like them in the game). He did not say why. What the
	numbers show: 80-88% of their energy is a sub thump under 250 Hz (as
	measured on his clip's sound), the ding sits above 3 kHz, and between
	500 Hz and 2 kHz there is next to nothing (-41 dB in the headshot's
	loudest 100 ms, against -20 to -30 dB here). So on speakers with little
	bass it is a thin ting. This batch has no sub: a short dry knock
	(high-passed) with the ring carrying 40-50% of the energy; 2-4 dB more
	above 2 kHz than H5 / K5 and a filled middle. Each is also written
	"in a fight": after a rifle shot, the way it plays in the game."""
	CLINK, CHIME = 2719.0, 1529.0
	slap = B.cut("punch_slap_whack_hit_01", 0.09, hp_hz=180)
	punch = B.cut("punch_general_body_impact_02", 0.12, hp_hz=90)
	wood = B.cut("wood_block_sticks_hit_clap_01", 0.08, hp_hz=250)
	metal = B.cut("metal_sheet_impacts_01", 0.07, hp_hz=500)
	ding = glass_ding
	clink = tuned("Glasses handle 03", CLINK, 3094, 0.16)
	chime = tuned("chime-texture-011", CHIME, 2064, 0.4)
	rise = B.mix((ding(0.46, 0.2), 0, 0), (ding(0.615, 0.28), 0, 0.07))
	head = {
		"H9 slap and a bright glass ding": blend(slap, ding(1.0, 0.22), 0.4),
		"H10 metal tick and a glass clink (a dink)": blend(metal, clink, 0.45),
		"H11 wood knock and a lower glass ding": blend(wood, ding(0.75, 0.24), 0.45),
		"H12 glass ding with a soft punch under it": blend(punch, ding(1.0, 0.3), 0.5),
	}
	kill = {
		"K9 punch and two rising glass notes": blend(punch, rise, 0.45, 0),
		"K10 punch and a chime": blend(punch, chime, 0.4, 0),
		"K11 slap and a low glass ding": blend(slap, ding(0.5, 0.32), 0.45, 0),
		"K12 wood knock and two rising glass notes": blend(wood, rise, 0.5, 0),
	}
	return head, kill


def batch4():
	"""Batch 4 (2026-11-15, the owner after batch 3): the headshot should be
	"a shing... a nice one", "nothing too annoying"; "a lot of these have a
	really high pitched ding, which is annoying"; the kill "subtle enough
	where subconsciously the player likes it... nothing over the top".
	Why the earlier shings pierced (2026-11-13/14): they were sword draws
	played 1.25-1.5x faster, and those recordings already sit at 6-9 kHz.
	Here the blade sounds are the ones that are low by nature (an unsheathe
	with its ring at 2.9 kHz, a light clang at 1.8 kHz) or a bright draw
	slowed down, all low-passed at 4-5 kHz, eased in over a few ms (the
	"sh") and laid on a soft, quiet body thud. Nothing rings above 5 kHz.
	The kills are short, low and quiet (levelled 3 dB under the old kill):
	a soft pop or a warm low note on a muffled thud."""
	body = B.cut("punch_general_body_impact_02", 0.12, lp_hz=1500)

	def shing(fid, rate, lp_hz, length=0.22, ease=0.008, start=None):
		x = B.fs_load(fid)
		x = B.brightest(x, length * rate) if start is None else x[int(RATE * start) :][: int(RATE * length * rate)]
		x = B.speed(x, rate) if rate != 1 else x
		x = B.lp(B.hp(x, 500), lp_hz)
		return B.fade(x[: int(RATE * length)], ease, length * 0.55)

	def soft(fid, length, lp_hz=None, rate=1.0, hp_hz=70):
		x = B.head(B.fs_load(fid), pre=0.002)[: int(RATE * length * rate)]
		x = B.speed(x, rate) if rate != 1 else x
		# Rumble and any DC offset out first (the thud's centre measured 20 Hz).
		x = B.hp(x, hp_hz)
		if lp_hz:
			x = B.lp(x, lp_hz)
		return B.fade(x, 0.002, length * 0.5)

	low_shing = shing("107589", 0.8, 4000)
	head = {
		"H13 soft shing (a sword unsheathed, as recorded)": blend(body, shing("107589", 1.0, 5000), 0.65),
		"H14 lower shing (the same, slowed)": blend(body, low_shing, 0.65),
		"H15 long smooth shing (a bright draw, slowed a lot)": blend(body, shing("581594", 0.55, 4500, 0.26, 0.012), 0.65),
		"H16 soft ring (a light blade clang)": blend(body, shing("351372", 1.0, 4500, 0.24, 0.005), 0.6),
		"H17 short shing (a small sword, slowed)": blend(body, shing("30248", 0.8, 4500, 0.18), 0.65),
	}
	thud = soft("275160", 0.16, 900)
	knock = B.cut("punch_general_body_impact_02", 0.1, lp_hz=1200)
	kill = {
		"K13 soft bubble pop on a thud": B.mix((soft("669918", 0.2, 3000, 0.9), 0, 0), (thud, -5, 0)),
		"K14 soft two-note pop": B.mix((soft("878606", 0.26, 3000), 0, 0), (knock, -8, 0)),
		"K15 warm low note on a knock": B.mix((soft("538149", 0.28, 2500, hp_hz=300), 0, 0), (knock, -6, 0)),
		"K16 muffled thud with a bowl's low hum": blend(thud, soft("421829", 0.3, 2000, hp_hz=300), 0.45, 0),
		"K17 thud with a faint low shing": blend(knock, low_shing, 0.3, 0.01),
	}
	return head, kill


def batch5():
	"""Batch 5, headshots only (2026-11-15: the owner passed on every
	headshot of batch 4, "either too dull, and the shings are too metallic...
	like nails on a chalkboard", and took K13, the soft bubble pop, as the
	kill). So far he has turned down metal (rings, shings), high clean tones
	(dings) and anything low-passed until it is dull, and liked a round pop.
	These are K13's family made crisper and higher for the headshot: pops
	and a wood tock with a short dry crack on the front for bite. No metal,
	no ring, nothing low-passed."""

	def take(fid, length, rate=1.0, hp_hz=120):
		x = B.head(B.fs_load(fid), pre=0.002)[: int(RATE * length * rate)]
		x = B.speed(x, rate) if rate != 1 else x
		return B.fade(B.hp(x, hp_hz), 0.001, length * 0.5)

	crack = B.cut("punch_slap_whack_hit_01", 0.045, hp_hz=1500)
	wood = B.cut("wood_block_sticks_hit_clap_01", 0.09, hp_hz=300)
	thud = B.cut("punch_general_body_impact_02", 0.1, hp_hz=90, lp_hz=1500)
	pop = take("669918", 0.2)
	head = {
		"H18 bright pop with a dry crack": B.mix((take("669918", 0.18, 1.26), 0, 0), (crack, -7, 0), (thud, -9, 0)),
		"H19 pop and crack, K13's pitch": B.mix((pop, 0, 0), (crack, -4, 0), (thud, -8, 0)),
		"H20 two quick rising pops": B.mix((pop, 0, 0), (take("669918", 0.16, 1.335), -1, 0.05), (thud, -9, 0)),
		"H21 wood tock on a pop": B.mix((wood, 0, 0), (take("669918", 0.18, 1.12), -3, 0.004), (thud, -9, 0)),
		"H22 two-note pop, higher and short": B.mix((take("878606", 0.2, 1.2), 0, 0), (crack, -8, 0), (thud, -9, 0)),
	}
	_h, kills = batch4()
	return head, {"K13 soft bubble pop on a thud (now the kill sound)": kills["K13 soft bubble pop on a thud"]}


def in_a_fight(x, kill=False):
	"""`x` the way it plays in the game: after a rifle shot (the hit sounds
	play Audio.HIT_DELAY after it, at Audio.HIT_VOLUME), three times."""
	shot = B.mix(
		(B.load("gun_semi_auto_rifle_shot_00_first_01"), 0, 0),
		(B.load("gun_semi_auto_rifle_shot_00_tail_only_01"), -6, 0),
	)
	shot = levelled(shot, -7.0)
	one = np.zeros((int(RATE * 0.75), 2))
	n = min(len(shot), len(one))
	one[:n] += shot[:n]
	i = int(RATE * (0.08 if kill else 0.05))
	m = min(len(x), len(one) - i)
	one[i : i + m] += x[:m] * 0.8
	return np.clip(np.concatenate([one, one, one]), -1, 1)


def levelled(x, target):
	return B.level_family([x], target)[0][0]


def reel(items, repeats=2, gap=0.45):
	silence = np.zeros((int(RATE * gap), 2))
	long_gap = np.zeros((int(RATE * 0.9), 2))
	parts = []
	for x in items:
		for _ in range(repeats):
			parts += [x, silence]
		parts.append(long_gap)
	return np.concatenate(parts)


def main():
	global OUT
	if len(sys.argv) > 1 and sys.argv[1] == "final":
		final()
		return
	if len(sys.argv) > 1 and sys.argv[1] == "final-head":
		final_head()
		return
	if len(sys.argv) > 1 and sys.argv[1] == "final-kill":
		final_kill()
		return
	second = len(sys.argv) > 1 and sys.argv[1] == "2"
	fifth = len(sys.argv) > 1 and sys.argv[1] == "5"
	fourth = fifth or (len(sys.argv) > 1 and sys.argv[1] == "4")  # the quieter kill level
	third = fourth or (len(sys.argv) > 1 and sys.argv[1] == "3")  # these: also "in a fight"
	if second:
		OUT += ", batch 2"
	elif fifth:
		OUT += ", batch 5"
	elif fourth:
		OUT += ", batch 4"
	elif third:
		OUT += ", batch 3"
	os.makedirs(OUT, exist_ok=True)
	head, kill = batch5() if fifth else batch4() if fourth else batch3() if third else batch2() if second else candidates()
	# What is in the game now: H5 / K5 since batch 3, the older cues before.
	live_head = read(os.path.join(STANDALONE, "hit_head_E-01.wav" if third else "hit_head_A-01.wav"))
	live_kill = read(os.path.join(STANDALONE, "kill_E.wav" if third else "kill_C.wav"))
	rows = []
	for group, live, made, target, reel_name in (
		("headshot", live_head, head, B.HIT_TARGET["HitHead"], "Headshot reel.wav"),
		("kill", live_kill, kill, B.HIT_TARGET["Kill"] - (3.0 if fourth else 0.0), "Kill reel.wav"),
	):
		order = [("0 live " + group, live)]
		for name, x in made.items():
			order.append((name, levelled(x, target)))
		for name, x in order:
			B.write_wav(os.path.join(OUT, name + ".wav"), x)
			if third:
				os.makedirs(os.path.join(OUT, "in a fight"), exist_ok=True)
				B.write_wav(
					os.path.join(OUT, "in a fight", name + ", after a shot.wav"),
					in_a_fight(x, group == "kill"),
				)
			m = measure(x)
			rows.append(
				"%-52s %4.0f ms   centre %5.0f Hz   above 3 kHz %4.1f%%   above 5 kHz %4.1f%%   below 250 Hz %4.1f%%"
				% (name, m["length"] * 1000, m["centre"], m["high"] * 100, m["top"] * 100, m["low"] * 100)
			)
		B.write_wav(os.path.join(OUT, reel_name), reel([x for _, x in order]))
		rows.append("")
	text = "\n".join(
		[
			"Headshot and kill candidates, 2026-11-15. Nothing here is in the game yet.",
			"Each reel plays the LIVE sound twice, then each candidate twice, in the order below.",
			"",
		]
		+ rows
	)
	with open(os.path.join(OUT, "README.txt"), "w", encoding="utf-8") as f:
		f.write(text + "\n")
	print(text)
	print("wrote", OUT)


if __name__ == "__main__":
	main()
