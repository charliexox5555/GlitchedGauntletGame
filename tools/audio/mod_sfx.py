"""Synthesized Mod (ability) sounds: sfxr-style presets for the crisp digital
cues (UI pings, Ping pulse, Overclock hum, Rollback rewind, fuse beeps,
loops). PROPOSAL, not wired in yet: see vault/02 Art/Mod Audio.md. Once the
user approves the list, build_sound_atlas.py adds build_mod_clips() to the
atlas so these cost no extra audio upload.

    python -I tools/audio/mod_sfx.py              # one WAV per cue + a reel
    python -I tools/audio/mod_sfx.py --out DIR    # somewhere else

Each preset uses sfxr's parameters in real units, so a sound made in jsfxr
(sfxr.me) can be copied over by ear:
  wave         square | saw | sine | triangle | noise
  freq         start pitch (Hz)              freq_min   floor (Hz)
  slide        pitch slide (octaves/s)       dslide     slide change (oct/s^2)
  vib, vib_hz  vibrato depth (0..1) and rate
  arp, arp_at  pitch jump (ratio) and when (s)
  repeat       restart slide and arpeggio every N s (0 = off)
  duty, duty_slide   square pulse width (0..1) and its change per s
  attack, sustain, punch, decay   envelope (s; punch = sustain boost 0..1)
  lpf, lpf_slide, res   low-pass cutoff (Hz), its slide (oct/s), resonance
  hpf, hpf_slide        high-pass cutoff (Hz) and slide (oct/s)
  phaser, phaser_slide  flanger delay (s) and its change per s
  crush, rate           bit depth (0 = off) and sample-hold rate (Hz, 0 = off)
A cue layers voices: (start s, preset, gain, pan). Loops are crossfaded
end-to-start so they repeat without a click.

Needs numpy, scipy and soundfile (same as the atlas).
"""

import argparse
import os

import numpy as np
import soundfile as sf
from scipy import signal

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT_DIR = os.path.join(ROOT, "art-source", "audio", "ModSfx")  # gitignored
RATE = 48000

DEFAULT = dict(
	wave="square", freq=440.0, freq_min=20.0, slide=0.0, dslide=0.0, vib=0.0, vib_hz=0.0,
	arp=1.0, arp_at=0.0, repeat=0.0, duty=0.5, duty_slide=0.0,
	attack=0.0, sustain=0.1, punch=0.0, decay=0.1,
	lpf=20000.0, lpf_slide=0.0, res=0.0, hpf=0.0, hpf_slide=0.0,
	phaser=0.0, phaser_slide=0.0, crush=0, rate=0, seed=1,
)


# Synth ------------------------------------------------------------------------


def peak(x):
	return max(float(np.max(np.abs(x))), 1e-9)


def voice(p, detune=0.0):
	"""Render one sfxr-style voice (mono)."""
	d = dict(DEFAULT, **p)
	n = int(RATE * (d["attack"] + d["sustain"] + d["decay"]))
	t = np.arange(n) / RATE
	a, s, k = d["attack"], d["sustain"], d["decay"]
	env = np.ones(n)
	if a > 0:
		env[t < a] = t[t < a] / a
	mid = (t >= a) & (t < a + s)
	env[mid] = 1 + d["punch"] * (1 - (t[mid] - a) / max(s, 1e-9))
	tail = t >= a + s
	env[tail] = np.clip(1 - (t[tail] - a - s) / max(k, 1e-9), 0, 1)

	tr = np.mod(t, d["repeat"]) if d["repeat"] > 0 else t
	f = d["freq"] * (1 + detune) * 2 ** (d["slide"] * tr + 0.5 * d["dslide"] * tr**2)
	if d["arp_at"] > 0:
		f = np.where(tr >= d["arp_at"], f * d["arp"], f)
	f = np.maximum(f, d["freq_min"])
	if d["vib"] > 0:
		f = f * (1 + d["vib"] * np.sin(2 * np.pi * d["vib_hz"] * t))
	ph = np.cumsum(f) / RATE
	frac = np.mod(ph, 1.0)

	w = d["wave"]
	if w == "square":
		duty = np.clip(d["duty"] + d["duty_slide"] * t, 0.05, 0.95)
		y = np.where(frac < duty, 1.0, -1.0)
	elif w == "saw":
		y = 2 * frac - 1
	elif w == "sine":
		y = np.sin(2 * np.pi * ph)
	elif w == "triangle":
		y = 2 * np.abs(2 * frac - 1) - 1
	elif w == "noise":  # sfxr: a new random value 32 times per cycle
		idx = np.floor(ph * 32).astype(np.int64)
		y = np.random.default_rng(d["seed"]).uniform(-1, 1, int(idx[-1]) + 2)[idx]
	else:
		raise ValueError(w)
	y = y * env

	if d["phaser"] > 0:  # flanger: add a copy delayed by a moving offset
		off = np.clip(d["phaser"] + d["phaser_slide"] * t, 0, 0.02) * RATE
		src = np.clip(np.arange(n) - off, 0, n - 1)
		y = y + np.interp(src, np.arange(n), y)
	if d["lpf"] < 20000 or d["lpf_slide"] != 0:
		y = svf_lowpass(y, d["lpf"] * 2 ** (d["lpf_slide"] * t), d["res"])
	if d["hpf"] > 0:
		y = onepole_highpass(y, d["hpf"] * 2 ** (d["hpf_slide"] * t))
	if d["rate"] > 0:  # sample-and-hold "decimate"
		hold = np.floor(t * d["rate"]) / d["rate"]
		y = y[np.minimum((hold * RATE).astype(np.int64), n - 1)]
	if d["crush"] > 0:
		q = 2 ** (d["crush"] - 1)
		y = np.round(y / peak(y) * q) / q
	return y


def svf_lowpass(x, cutoff, res):
	"""Resonant state-variable low-pass with a per-sample cutoff (the
	trapezoidal "zero-delay" form, stable at any cutoff and resonance)."""
	g = np.tan(np.pi * np.clip(cutoff, 20, RATE * 0.45) / RATE)
	k = 2 - 1.9 * float(np.clip(res, 0, 1))
	a1 = 1 / (1 + g * (g + k))
	a2 = g * a1
	a3 = g * a2
	ic1 = ic2 = 0.0
	out = np.empty_like(x)
	for i in range(len(x)):
		v3 = x[i] - ic2
		v1 = a1[i] * ic1 + a2[i] * v3
		v2 = ic2 + a2[i] * ic1 + a3[i] * v3
		ic1 = 2 * v1 - ic1
		ic2 = 2 * v2 - ic2
		out[i] = v2
	return out


def onepole_highpass(x, cutoff):
	a = np.exp(-2 * np.pi * np.clip(cutoff, 1, RATE * 0.45) / RATE)
	out = np.empty_like(x)
	prev_x = prev_y = 0.0
	for i in range(len(x)):
		prev_y = a[i] * (prev_y + x[i] - prev_x)
		prev_x = x[i]
		out[i] = prev_y
	return out


def cue(layers, width=0.0, room=0.0, target=-14.0, loop=0.0):
	"""Mix (start, preset, gain, pan) voices into a stereo clip, then master.
	width detunes left/right; room adds a short reverb; loop (s) makes a
	seamless loop of that length."""
	parts = []
	for at, p, g, pn in layers:
		lv, rv = voice(p, -width), voice(p, width)
		parts.append((int(at * RATE), lv * g * (1 - max(pn, 0)), rv * g * (1 + min(pn, 0))))
	n = max(o + len(l) for o, l, _ in parts)
	out = np.zeros((n, 2))
	for o, l, r in parts:
		out[o : o + len(l), 0] += l
		out[o : o + len(r), 1] += r
	if room > 0:
		rng = np.random.default_rng(11)
		ir_t = np.arange(int(RATE * 0.5)) / RATE
		ir = rng.normal(size=(len(ir_t), 2)) * np.exp(-ir_t / 0.09)[:, None]
		wet = np.stack([signal.fftconvolve(out[:, c], ir[:, c])[:n] for c in range(2)], 1)
		out = out + wet / peak(wet) * peak(out) * room
	if loop > 0:
		out = make_loop(out, loop)
	else:
		fade = min(int(RATE * 0.01), n // 4)
		out[-fade:] *= np.linspace(1, 0, fade)[:, None]
	return master(out, target)


def make_loop(x, seconds, xfade=0.08):
	"""Equal-power crossfade of the clip's overhang into its start."""
	n, f = int(RATE * seconds), int(RATE * xfade)
	assert len(x) >= n + f, "render the loop voices xfade s longer than the loop"
	k = np.linspace(0, np.pi / 2, f)[:, None]
	y = x[:n].copy()
	y[:f] = x[:f] * np.sin(k) + x[n : n + f] * np.cos(k)
	return y


def master(x, target, ceiling=0.89):
	"""RMS-match to target dBFS (over the loud part), then peak-limit."""
	rms = np.sqrt(np.mean(x[np.abs(x).max(1) > peak(x) * 0.1] ** 2))
	y = x * 10 ** (target / 20) / max(rms, 1e-9)
	return np.tanh(y / ceiling) * ceiling if peak(y) > ceiling else y


# Presets ----------------------------------------------------------------------
# Atlas names start with "Mod". Loops end in "Loop". Where both are listed,
# the caster/teammate version and the enemy version (heard in 3D, or 2D when
# it targets you) are separate clips so they never blur.

BLIP = dict(wave="square", duty=0.5, attack=0.0, lpf=7000)


def ready():
	"""Cooldown ready: a soft rising two-note blip (E6 -> B6)."""
	a = dict(BLIP, freq=1318.5, arp=1.5, arp_at=0.055, sustain=0.07, decay=0.14, duty=0.25)
	sub = dict(wave="sine", freq=659.25, arp=1.5, arp_at=0.055, sustain=0.07, decay=0.12)
	return cue([(0, a, 0.5, 0), (0, sub, 0.6, 0)], width=0.003, room=0.15, target=-18)


def denied():
	"""Can't use (on cooldown, blocked): a low double buzz, "bzz-bzz"."""
	b = dict(wave="square", freq=150, duty=0.35, repeat=0.085, slide=-1.0, sustain=0.15, decay=0.03,
		lpf=1800, crush=5)
	return cue([(0, b, 1.0, 0)], target=-19)


def cancel():
	"""Held Mod put away: a quick falling blip."""
	b = dict(BLIP, freq=1100, slide=-4.0, sustain=0.03, decay=0.07, duty=0.3)
	return cue([(0, b, 1.0, 0)], target=-20)


def raise_():
	"""Held Mod raised (shared; the game pitches it per Mod): a rising
	digital chirp over a soft air swish."""
	chirp = dict(BLIP, freq=500, slide=5.0, sustain=0.05, decay=0.08, duty=0.2, lpf=5000)
	swish = dict(wave="noise", freq=1500, attack=0.04, sustain=0.06, decay=0.1, lpf=1500, lpf_slide=3.0, hpf=400)
	return cue([(0, swish, 0.5, 0), (0.03, chirp, 0.45, 0)], width=0.002, target=-19)


def ping_cast():
	"""Ping, caster: sonar "pwomm" with a rising scan sweep and echo."""
	sonar = dict(wave="sine", freq=1046.5, sustain=0.02, decay=0.9, vib=0.004, vib_hz=7)
	body = dict(wave="triangle", freq=523.25, sustain=0.02, decay=0.5)
	scan = dict(wave="saw", freq=300, slide=3.5, attack=0.02, sustain=0.12, decay=0.15, lpf=2500,
		lpf_slide=4.0, res=0.6, crush=6)
	return cue([(0, scan, 0.3, 0), (0.12, sonar, 0.8, 0), (0.12, body, 0.5, 0)], width=0.004, room=0.5, target=-13)


def ping_pulse_enemy():
	"""Ping, heard in 3D by everyone near the pulse: lower and harder, so
	enemies know a scan just went out."""
	sonar = dict(wave="sine", freq=740, sustain=0.02, decay=0.8)
	grit = dict(wave="square", freq=370, duty=0.3, sustain=0.03, decay=0.35, lpf=1600, crush=4)
	return cue([(0, sonar, 0.8, 0), (0, grit, 0.35, 0)], room=0.4, target=-13)


def ping_revealed():
	"""Ping, 2D to an enemy who just got revealed: two sharp alert chirps."""
	c = dict(BLIP, freq=1975.5, repeat=0.11, sustain=0.19, decay=0.03, duty=0.2, lpf=9000)
	return cue([(0, c, 1.0, 0)], target=-16)


def overclock_on():
	"""Overclock start: a saw spin-up with a crunchy front edge."""
	spin = dict(wave="saw", freq=180, slide=3.2, attack=0.01, sustain=0.32, decay=0.12, lpf=1200,
		lpf_slide=4.0, res=0.5)
	kick = dict(wave="square", freq=90, slide=-2.0, sustain=0.03, decay=0.08, lpf=900, crush=4)
	return cue([(0, kick, 0.5, 0), (0, spin, 0.8, 0)], width=0.004, target=-14)


def overclock_loop():
	"""Overclock hum on the gun (3D, the "gun hums" tell): a fast-vibrato
	electric whine over a buzzing saw. 1 s loop."""
	whine = dict(wave="sine", freq=1480, vib=0.01, vib_hz=18, sustain=1.1, decay=0.0)
	buzz = dict(wave="saw", freq=110, vib=0.02, vib_hz=9, sustain=1.1, decay=0.0, lpf=900, res=0.4)
	return cue([(0, buzz, 0.7, 0), (0, whine, 0.25, 0)], width=0.003, target=-20, loop=1.0)


def overclock_off():
	"""Overclock end: the spin-up reversed, a falling power-down."""
	down = dict(wave="saw", freq=900, slide=-3.5, sustain=0.3, decay=0.15, lpf=2000, lpf_slide=-3.0)
	return cue([(0, down, 1.0, 0)], width=0.004, target=-17)


def rollback_rewind():
	"""Rollback, caster: VHS rewind, fast falling chirps through a flanger."""
	chirps = dict(wave="saw", freq=1600, slide=-14.0, repeat=0.05, sustain=0.42, decay=0.06, lpf=4500,
		phaser=0.003, phaser_slide=0.01, crush=6, rate=16000)
	wow = dict(wave="noise", freq=4000, attack=0.05, sustain=0.32, decay=0.1, lpf=3000, hpf=600, rate=8000)
	return cue([(0, chirps, 0.7, 0), (0, wow, 0.25, 0)], width=0.006, target=-14)


def rollback_snap():
	"""Rollback, 3D at both ends of the jump: a glitchy crushed snap that
	everyone hears (where they left and where they landed)."""
	snap = dict(wave="noise", freq=6000, sustain=0.03, decay=0.12, crush=3, rate=6000)
	drop = dict(wave="sine", freq=420, slide=-5.0, sustain=0.02, decay=0.18)
	return cue([(0, snap, 0.6, 0), (0, drop, 0.8, 0)], target=-13)


def beeps(times, freq, duty, lpf, length):
	b = dict(wave="square", freq=freq, duty=duty, sustain=0.035, decay=0.025, lpf=lpf)
	return [(at, b, 1.0, 0) for at in times]


FUSE_TIMES = (0.0, 0.34, 0.6, 0.8, 0.94, 1.04, 1.11, 1.16)  # 1.2 s fuse, speeding up


def packet_fuse():
	"""Packet fuse (caster and team, 3D): accelerating beeps over 1.2 s."""
	return cue(beeps(FUSE_TIMES, 1568, 0.5, 6000, 1.2), target=-17)


def packet_danger():
	"""Packet, enemies inside the danger ring (2D): the same rhythm higher and
	harsher, so "get out" is unmistakable."""
	return cue(beeps(FUSE_TIMES, 2349, 0.15, 10000, 1.2), target=-14)


def lag_loop():
	"""Lag Field zone hum (3D): a slow, warbling, bit-crushed drone. 1 s loop
	(the 4 Hz wobble is a whole number of cycles per second)."""
	drone = dict(wave="saw", freq=82.4, vib=0.06, vib_hz=4, sustain=1.1, decay=0.0, lpf=700, res=0.5, crush=6)
	air = dict(wave="noise", freq=800, sustain=1.1, decay=0.0, lpf=1200, hpf=300, rate=6000)
	return cue([(0, drone, 0.8, 0), (0, air, 0.2, 0)], width=0.004, target=-21, loop=1.0)


def lag_slowed():
	"""Lag Field, 2D to an enemy entering the zone: a tape-slowdown dive."""
	dive = dict(wave="saw", freq=700, slide=-2.5, sustain=0.3, decay=0.12, lpf=2200, lpf_slide=-2.0,
		crush=5, rate=11000)
	return cue([(0, dive, 1.0, 0)], width=0.005, target=-16)


def heal_loop():
	"""Patch Up heal beam (3D, enemies can hear someone healing): a soft
	shimmering major chord with tremolo. 1 s loop."""
	chord = [
		(0, dict(wave="sine", freq=f, vib=0.003, vib_hz=6, sustain=1.1, decay=0.0), g, pn)
		for f, g, pn in ((523.25, 0.6, -0.2), (659.25, 0.45, 0.2), (783.99, 0.4, 0), (1567.98, 0.15, 0))
	]
	sparkle = dict(wave="noise", freq=9000, sustain=1.1, decay=0.0, hpf=6000, rate=0)
	return cue(chord + [(0, sparkle, 0.06, 0)], width=0.003, target=-21, loop=1.0)


def heal_done():
	"""Patch Up finished: a rising major arpeggio (C6 E6 G6)."""
	notes = [(i * 0.06, dict(wave="sine", freq=f, sustain=0.03, decay=0.25), 0.7, 0)
		for i, f in enumerate((1046.5, 1318.5, 1568.0))]
	return cue(notes, width=0.003, room=0.3, target=-17)


def wall_hit(variant):
	"""Firewall bullet impact: a short crackle (2 variants)."""
	z = dict(wave="noise", freq=5000 + 900 * variant, sustain=0.01, decay=0.06, hpf=1500, crush=4,
		seed=40 + variant)
	tone = dict(wave="square", freq=880 + 120 * variant, slide=-3.0, duty=0.2, sustain=0.01, decay=0.05, lpf=4000)
	return cue([(0, z, 0.7, 0), (0, tone, 0.35, 0)], target=-17)


def build_mod_clips():
	"""name -> list of variant clips (stereo float arrays), the same shape as
	build_sound_atlas.build_clips()."""
	return {
		"ModReady": [ready()],
		"ModDenied": [denied()],
		"ModCancel": [cancel()],
		"ModRaise": [raise_()],
		"ModPingCast": [ping_cast()],
		"ModPingPulse": [ping_pulse_enemy()],
		"ModPingRevealed": [ping_revealed()],
		"ModOverclockOn": [overclock_on()],
		"ModOverclockLoop": [overclock_loop()],
		"ModOverclockOff": [overclock_off()],
		"ModRollbackRewind": [rollback_rewind()],
		"ModRollbackSnap": [rollback_snap()],
		"ModPacketFuse": [packet_fuse()],
		"ModPacketDanger": [packet_danger()],
		"ModLagLoop": [lag_loop()],
		"ModLagSlowed": [lag_slowed()],
		"ModHealLoop": [heal_loop()],
		"ModHealDone": [heal_done()],
		"ModWallHit": [wall_hit(v) for v in range(2)],
	}


def main():
	ap = argparse.ArgumentParser()
	ap.add_argument("--out", default=OUT_DIR, help="folder for the WAVs")
	args = ap.parse_args()
	os.makedirs(args.out, exist_ok=True)
	reel = []
	for name, variants in build_mod_clips().items():
		for i, clip in enumerate(variants):
			sf.write(os.path.join(args.out, f"{name}_{i + 1}.wav"), np.clip(clip, -1, 1), RATE, subtype="PCM_16")
			rep = 3 if name.endswith("Loop") else 1  # loops play 3 times to hear the seam
			reel += [np.tile(clip, (rep, 1)), np.zeros((int(RATE * 0.6), 2))]
		print(f"{name:20s} {len(variants)} x {len(variants[0]) / RATE:.2f}s", flush=True)
	out = np.concatenate(reel)
	sf.write(os.path.join(args.out, "_Reel.wav"), np.clip(out, -1, 1), RATE, subtype="PCM_16")
	print(f"reel {len(out) / RATE:.0f}s -> {args.out}")


if __name__ == "__main__":
	main()
