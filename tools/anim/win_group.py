"""The other winners of the win cutscene (vault/02 Art/Win Cutscene.md, owner
2026-11-20: "get everybody to do stuff"; the order is best performing first).
Slot 1 (the best) plays Win1_1 in every scene; slots 2-5 play these, each
with its own moves on the same song accents (win_clips docstring), its own
final pose and its own hop or spin (Config/WinCutscene slot `root` keys).

    WinS2   the showman   arms out wide on the drop, fist pumps with the
                          gun held out, points at the lead, beckons the
                          lens, a hop, drops to one knee
    WinS3   the cool one  late and smooth: gun onto the shoulder, finger
                          gun at the lens, watches the lead, the gun up to
                          the sky, a stance switch, ends gun down in
                          front, leaning back, chin up
    WinS4   the hype one  bounces from the first hit, both arms up on the
                          drop, a sideways one-handed aim at the lens, a
                          big hop, ends both arms up in a V
    WinS5   the chill one head nods, a salute flicked out, admires the gun,
                          a lazy shrug, ends pointing at the sky, gun easy

Each track is cleared of clipping by win_fix like Win1_1 (cached), then the
hold loop breathes around its cleared last key.
"""

import math

import tp_clips
import win_fix
from tp_clips import Clip
from tp_rig import ALL
from win_clips import TAU, flat_feet, key, two_handed, win

STANCE = dict(rf=(0.66, 0, 0.1, -10), lf=(-0.62, 0, -0.14, 8))
WIDE = dict(rf=(0.9, 0, 0.12, -16), lf=(-0.88, 0, -0.18, 12))
LOW = dict(gun=(-38, 10, 0, 0), lt=(-1.15, -1.05, 0.0))
COIL = dict(hy=-0.42, hr=(5, 2, 0), ch=(-14, 8, 0), hd=(-10, 0, 0), gun=(-24, 18, 0, 0.0), lt=(-0.5, -0.05, -1.25), lp=(-0.8, -1, 0.4))
HIP_L = dict(lt=(-1.05, -0.88, 0.12), lp=(-1, 0.05, 0.55))
AIR = dict(rf=(0.66, 0.4, 0.15, -10), lf=(-0.62, 0.42, -0.35, 8))
RIFLE = dict(ch=(-4, -24, 0), lp=(-0.5, -1, -0.2), lf=(-0.7, 0, -0.75, 10), rf=(0.75, 0, 0.25, -14))


def k(t, base, **kw):
	d = dict(base)
	d.update(kw)
	return (t, key(**d))


def hold_of(track, period=3.2, amp=1.0):
	"""A slow breath around the cleared last key of `track`."""

	def pose(t):
		base = dict(track[-1][1])
		p, y, r = base["gun"]["shoulder"]
		reach = base["gun"].get("reach", 0.0)
		ph = TAU * t / period
		b = math.sin(ph)
		b2 = math.sin(ph * 2 + 0.6)
		hips = base["hips"]
		x, hy, z = hips["pos"]
		base["hips"] = {"pos": (x, hy - 0.02 * amp + 0.02 * amp * b, z), "rot": hips["rot"]}
		base["gun"] = {"shoulder": (p + 1.4 * amp * b, y, r), "reach": reach}
		tip = base["left_arm"]["tip"]
		base["left_arm"] = {"tip": (tip[0], tip[1] + 0.03 * amp * b, tip[2])}
		hd = base["head"]
		base["head"] = (hd[0] - 0.8 * amp * b, hd[1] + 0.8 * amp * b2, hd[2])
		return flat_feet(base)

	return pose


def group_clip(name, track, two=(), skip=()):
	fixed = win_fix.fixed(name, track, skip_left=skip)
	win(Clip(name, "Action4", two_handed(fixed, list(two)), ALL, length=7.3, loop=False, step=1 / 60))
	win(Clip(name + "Hold", "Action4", hold_of(fixed), ALL, length=3.2, loop=True, step=1 / 30))
	return fixed


# WinS2: the showman ---------------------------------------------------------------
S2B = dict(STANCE, hr=(0, -4, 0))
S2UP = dict(gun=(12, -62, -10, 0.5))  # the gun held out wide to the side
# (round 3, after the owner's 2-player reference: #2 drops to one knee next
# to the lead, so the pair reads at two heights; the fist punches at the
# lens on the drop, then rests on the front knee (punched out, it hid their
# own face from the low camera); gun up on the outside)
KNEE = dict(rf=(0.7, 0, 1.05, -10), lf=(-0.65, 0, -0.8, 8))
CHAMP = dict(KNEE, hy=-1.0, hr=(10, -6, 0), ch=(-2, -6, 0), hd=(10, 4, -4), gun=(66, -48, 30, 0.75), lt=(-0.75, -0.5, -1.15), lp=(-1, -0.4, 0.3))
S2 = [
	k(0.00, S2B, hy=-0.06, ch=(-5, 0, -2), hd=(-16, -6, 0), **LOW),
	k(0.40, S2B, hy=-0.03, ch=(-3, 0, -2), hd=(-13, -6, 0), **LOW),
	k(0.70, S2B, hy=-0.07, ch=(-6, 0, -2), hd=(-17, -6, 0), **LOW),
	k(0.80, S2B, hy=-0.02, ch=(2, -4, -1), hd=(7, -22, 0), **LOW),  # 0.68 (a beat late): looks out right
	k(1.05, S2B, hy=-0.03, ch=(1, -4, -1), hd=(4, -16, 0), **LOW),
	k(1.42, S2B, **COIL),
	k(1.56, S2B, hy=0.02, ch=(10, 0, 0), hd=(10, 4, 0), lt=(-1.95, 0.75, -0.3), lp=(-1, -0.3, 0.3), gun=(14, -64, -10, 0.55)),  # snap: both arms out wide
	k(1.68, S2B, hy=-0.02, ch=(12, 0, 0), hd=(12, 4, 0), lt=(-2.05, 0.9, -0.25), lp=(-1, -0.3, 0.3), gun=(18, -68, -10, 0.6)),
	# fist pumps on the beat (2.02, 2.56, 3.10) with knee bounces
	k(1.94, S2B, hy=-0.14, ch=(4, -6, 0), hd=(2, 6, 0), lt=(-1.45, 1.05, -0.4), lp=(-1, -0.4, 0.3), **S2UP),
	k(2.06, S2B, hy=-0.02, ch=(8, -6, -2), hd=(8, 6, -4), lt=(-1.55, 2.3, -0.4), lp=(-1, -0.2, 0.3), **S2UP),
	k(2.30, S2B, hy=-0.14, ch=(4, -6, 0), hd=(2, 6, 0), lt=(-1.45, 1.1, -0.4), lp=(-1, -0.4, 0.3), **S2UP),
	k(2.60, S2B, hy=-0.02, ch=(8, -6, -2), hd=(8, 6, -4), lt=(-1.55, 2.25, -0.4), lp=(-1, -0.2, 0.3), **S2UP),
	k(2.84, S2B, hy=-0.14, ch=(4, -6, 0), hd=(2, 6, 0), lt=(-1.45, 1.1, -0.4), lp=(-1, -0.4, 0.3), **S2UP),
	k(3.12, S2B, hy=-0.02, ch=(8, -6, -2), hd=(8, 6, -4), lt=(-1.55, 2.25, -0.4), lp=(-1, -0.2, 0.3), **S2UP),
	# points at the lead (on their left), the gun comes down to the hip
	k(3.30, S2B, hy=-0.06, hr=(0, 6, 0), ch=(4, 14, 0), hd=(2, 24, 0), lt=(-2.05, 0.9, -0.55), lp=(-1, -0.3, 0.2), gun=(-30, 6, 0, 0.2)),
	k(3.40, S2B, hy=-0.05, hr=(0, 7, 0), ch=(5, 16, 0), hd=(3, 26, 0), lt=(-2.12, 0.98, -0.6), lp=(-1, -0.3, 0.2), gun=(-32, 6, 0, 0.2)),
	k(3.80, S2B, hy=-0.08, hr=(0, 6, 0), ch=(4, 14, 0), hd=(1, 22, 0), lt=(-2.0, 0.88, -0.55), lp=(-1, -0.3, 0.2), gun=(-30, 6, 0, 0.2)),
	# beckons the lens one-handed ("come on"), the gun out low by the side
	k(4.10, S2B, hy=-0.12, hr=(3, 0, 0), ch=(-2, -10, 0), hd=(-2, -4, 0), gun=(-24, -36, 0, 0.4), lt=(-0.7, 0.5, -1.95), lp=(-1, -0.6, 0.1)),
	k(4.22, S2B, hy=-0.16, hr=(3, 0, 0), ch=(-4, -10, 0), hd=(-4, -4, 0), gun=(-26, -36, 0, 0.4), lt=(-0.75, 0.95, -1.35), lp=(-1, -0.4, 0.2)),  # 4.16 the curl
	k(4.44, S2B, hy=-0.12, hr=(3, 0, 0), ch=(-2, -10, 0), hd=(-2, -4, 0), gun=(-24, -36, 0, 0.4), lt=(-0.7, 0.5, -1.95), lp=(-1, -0.6, 0.1)),
	k(4.86, S2B, hy=-0.16, hr=(3, 0, 0), ch=(-4, -10, 0), hd=(-4, -4, 0), gun=(-26, -36, 0, 0.4), lt=(-0.75, 0.95, -1.35), lp=(-1, -0.4, 0.2)),  # 4.80 again
	k(5.12, S2B, hy=-0.1, hr=(2, 0, 0), ch=(0, -8, 0), hd=(0, -2, 0), gun=(-22, -30, 0, 0.35), lt=(-0.9, 0.3, -1.6), lp=(-1, -0.6, 0.2)),
	# the hop on 5.36 (root lift): gun up, fist up, knees tucked
	k(5.26, STANCE, hy=-0.32, hr=(5, 0, 0), ch=(-8, -6, 0), hd=(-6, 0, 0), gun=(-30, -8, 0, 0.3), lt=(-1.25, -0.45, -0.55), lp=(-1, -0.6, 0.3)),
	k(5.42, AIR, hy=0.0, hr=(-3, 0, 0), ch=(8, -4, 0), hd=(8, 0, 0), gun=(76, -20, -12, 0.3), lt=(-1.6, 2.1, -0.4), lp=(-1, -0.2, 0.3)),
	k(5.50, AIR, hy=0.0, hr=(-3, 0, 0), ch=(8, -4, 0), hd=(8, 0, 0), gun=(78, -20, -12, 0.3), lt=(-1.6, 2.15, -0.4), lp=(-1, -0.2, 0.3)),
	k(5.58, STANCE, hy=-0.34, hr=(6, 0, 0), ch=(-8, -6, 0), hd=(-6, 0, 0), gun=(10, -10, 0, 0.3), lt=(-1.35, 0.2, -0.6), lp=(-1, -0.6, 0.3)),
	k(5.90, WIDE, **COIL),
	k(6.08, dict(KNEE, rf=(0.7, 0.1, 0.8, -10)), **dict(COIL, hy=-0.6)),
	# the champion (6.14, a hair after the lead), the punch on 6.80
	k(6.22, CHAMP, hy=-1.08, ch=(-6, -6, 0), hd=(6, 4, -4), lt=(-0.55, 0.5, -2.1)),  # drops to the knee, the punch out
	k(6.32, CHAMP, hy=-1.04, ch=(-4, -6, 0), hd=(12, 4, -5), gun=(70, -50, 32, 0.8), lt=(-0.62, 0.6, -2.0)),
	k(6.54, CHAMP),
	k(6.72, CHAMP, hy=-1.06),
	k(6.86, CHAMP, hy=-0.98, ch=(0, -6, 0), hd=(14, 4, -5), lt=(-0.78, -0.4, -1.2)),  # 6.80 a nod, the fist taps the knee
	k(7.02, CHAMP, hd=(11, 4, -4)),
	k(7.30, CHAMP),
]
group_clip("WinS2", S2)

# WinS3: the cool one --------------------------------------------------------------
S3B = dict(STANCE, hr=(0, 4, 0))
SHOULDER = dict(gun=(74, -8, -14, -0.1))
# (v2: the gun hangs down along the right leg; pointed down in front it hit
# the legs and the clip fixer had to twist it up to the face)
# (round 4: the final is a pose for the camera, the group closed up; #3
# kneels on the left knee, mirroring #2, gun easy by the side, hand on the
# hip, chin up. Earlier: standing, leaning back.)
KNEE_L = dict(rf=(0.65, 0, -0.8, -8), lf=(-0.7, 0, 1.05, 10))
COOLFIN = dict(KNEE_L, hy=-1.0, hr=(10, 6, 0), ch=(-2, 6, 2), hd=(10, -4, 5), gun=(-50, -34, 0, 0.25), **HIP_L)
S3 = [
	k(0.00, S3B, hy=-0.04, ch=(2, 4, 2), hd=(4, 14, 6), **LOW, **{}),
	k(0.68, S3B, hy=-0.04, ch=(2, 4, 2), hd=(4, 14, 6), **LOW),
	k(1.10, S3B, hy=-0.05, ch=(3, 2, 2), hd=(5, 0, 4), **LOW),  # a slow turn to the lens
	k(1.48, S3B, hy=-0.1, ch=(-2, 2, 0), hd=(0, 0, 2), gun=(-10, 12, 0, 0), lt=(-1.15, -0.95, 0.0)),
	k(1.70, S3B, hy=-0.03, ch=(8, 4, 2), hd=(6, 0, 4), lt=(-1.05, -0.85, 0.12), lp=(-1, 0.05, 0.55), **SHOULDER),  # onto the shoulder, late and smooth
	k(1.98, S3B, hy=-0.05, ch=(7, 4, 2), hd=(4, 0, 4), lt=(-1.1, -0.6, -0.3), lp=(-1, -0.4, 0.3), **SHOULDER),
	k(2.10, S3B, hy=-0.02, ch=(9, 6, 6), hd=(8, 6, 10), lt=(-1.7, 0.35, -0.75), lp=(-1, -0.4, 0.2), **SHOULDER),  # 2.02 shrug, palm up
	k(2.40, S3B, hy=-0.04, ch=(8, 5, 5), hd=(6, 4, 8), lt=(-1.65, 0.3, -0.75), lp=(-1, -0.4, 0.2), **SHOULDER),
	k(2.62, S3B, hy=-0.06, ch=(7, 4, 2), hd=(0, 2, 4), lt=(-1.1, -0.7, -0.1), lp=(-1, -0.2, 0.4), **SHOULDER),  # nod
	k(2.90, S3B, hy=-0.04, ch=(8, 4, 2), hd=(5, 2, 4), lt=(-1.05, -0.85, 0.12), lp=(-1, 0.05, 0.55), **SHOULDER),
	k(3.14, S3B, hy=-0.05, ch=(6, 2, 2), hd=(2, 0, 4), lt=(-0.75, 0.3, -1.1), lp=(-0.9, -0.8, 0.3), **SHOULDER),
	k(3.24, S3B, hy=-0.03, ch=(5, -6, 2), hd=(0, -4, 4), lt=(-0.55, 0.55, -2.0), lp=(-1, -0.6, 0.1), **SHOULDER),  # finger gun at the lens
	k(3.32, S3B, hy=-0.03, ch=(7, -6, 2), hd=(2, -4, 4), lt=(-0.6, 0.75, -1.9), lp=(-1, -0.6, 0.1), **SHOULDER),  # the kick
	k(3.80, S3B, hy=-0.05, ch=(6, -4, 2), hd=(1, -2, 4), lt=(-0.62, 0.6, -1.95), lp=(-1, -0.6, 0.1), **SHOULDER),
	# turns to watch the lead, gun lowered, then raises it slowly to the sky
	k(4.10, S3B, hy=-0.06, ch=(4, -8, 0), hd=(2, -30, 0), gun=(-34, 6, 0, 0.2), **HIP_L),
	k(4.50, S3B, hy=-0.07, ch=(4, -8, 0), hd=(3, -28, 2), gun=(-30, 6, 0, 0.2), **HIP_L),
	k(4.86, S3B, hy=-0.02, ch=(8, -2, 0), hd=(8, -6, 0), gun=(82, -10, -12, 0.25), **HIP_L),  # 4.80 the gun goes up
	k(5.14, S3B, hy=-0.04, ch=(8, -2, 0), hd=(6, -4, 0), gun=(84, -10, -12, 0.25), **HIP_L),
	# 5.36: a stance switch, not a spin: dips, steps wide, leans back
	k(5.30, S3B, hy=-0.22, ch=(2, -2, 0), hd=(0, -4, 0), gun=(78, -10, -12, 0.2), **HIP_L),
	k(5.44, WIDE, hy=-0.02, hr=(-3, 6, 0), ch=(12, 4, 2), hd=(10, -2, 4), gun=(82, -12, -12, 0.25), **HIP_L),
	k(5.70, WIDE, hy=-0.06, hr=(-2, 6, 0), ch=(9, 4, 2), hd=(6, -2, 4), gun=(70, -10, -10, 0.2), **HIP_L),
	k(5.92, WIDE, **COIL),
	k(6.10, dict(KNEE_L, lf=(-0.7, 0.1, 0.8, 10)), **dict(COIL, hy=-0.6)),
	# down on one knee (mirroring #2), gun easy, hand on the hip, chin up
	k(6.26, COOLFIN, hy=-1.08, ch=(-6, 6, 2), hd=(6, -4, 5)),  # drops to the knee
	k(6.36, COOLFIN, hy=-1.03, ch=(1, 7, 3), hd=(12, -5, 6)),
	k(6.58, COOLFIN),
	k(6.76, COOLFIN, hy=-1.06),
	k(6.88, COOLFIN, hy=-0.98, ch=(1, 6, 2), hd=(4, -4, 5)),  # 6.80 a slow nod
	k(7.06, COOLFIN, hd=(8, -4, 5)),
	k(7.30, COOLFIN),
]
group_clip("WinS3", S3)

# WinS4: the hype one --------------------------------------------------------------
S4B = dict(STANCE, hr=(0, -6, 0))
BOTH = dict(gun=(84, -24, -14, 0.25), lt=(-1.55, 2.25, -0.35), lp=(-1, -0.2, 0.3))
VFIN = dict(WIDE, hy=-0.05, hr=(0, -4, 0), ch=(10, -4, 0), hd=(6, 0, 0), gun=(70, -42, 30, 0.6), lt=(-1.9, 2.05, -0.35), lp=(-1, -0.1, 0.3))
S4 = [k(0.00, S4B, hy=-0.04, ch=(-2, 0, 0), hd=(-8, 0, 0), **LOW)]
for i, t in enumerate((0.14, 0.41, 0.68, 0.95, 1.22)):  # bouncing on every half beat
	down = i % 2 == 0
	S4.append(k(t + 0.04, S4B, hy=-0.16 if down else -0.02, ch=(-4 if down else 2, 0, 0), hd=(-10 if down else -2, 0, 0), **LOW))
S4 += [
	k(1.42, S4B, **COIL),
	k(1.53, S4B, hy=0.06, ch=(12, -4, 0), hd=(12, 0, 0), **BOTH),  # both arms up on the drop
	k(1.64, S4B, hy=0.02, ch=(14, -4, 0), hd=(14, 0, 0), gun=(88, -26, -16, 0.3), lt=(-1.65, 2.45, -0.35), lp=(-1, -0.2, 0.3)),
	k(1.90, S4B, hy=-0.16, ch=(6, -4, 0), hd=(4, 0, 0), gun=(80, -22, -14, 0.2), lt=(-1.45, 1.2, -0.45), lp=(-1, -0.4, 0.3)),
	k(2.04, S4B, hy=0.0, ch=(10, -4, 0), hd=(10, 0, 0), gun=(84, -24, -14, 0.25), lt=(-1.6, 2.35, -0.35), lp=(-1, -0.2, 0.3)),
	k(2.30, S4B, hy=-0.16, ch=(6, -4, 0), hd=(4, 0, 0), gun=(80, -22, -14, 0.2), lt=(-1.45, 1.2, -0.45), lp=(-1, -0.4, 0.3)),
	k(2.58, S4B, hy=0.0, ch=(10, -4, 0), hd=(10, 0, 0), gun=(84, -24, -14, 0.25), lt=(-1.6, 2.35, -0.35), lp=(-1, -0.2, 0.3)),
	k(2.84, S4B, hy=-0.16, ch=(6, -4, 0), hd=(4, 0, 0), gun=(80, -22, -14, 0.2), lt=(-1.45, 1.2, -0.45), lp=(-1, -0.4, 0.3)),
	# points at the lens, leaning in
	k(3.18, S4B, hy=-0.1, hr=(6, 0, 0), ch=(-6, -10, 0), hd=(-4, -2, 0), gun=(-20, 4, 0, 0.3), lt=(-0.6, 0.7, -2.05), lp=(-1, -0.6, 0.1)),
	k(3.28, S4B, hy=-0.12, hr=(7, 0, 0), ch=(-8, -11, 0), hd=(-5, -2, 0), gun=(-22, 4, 0, 0.3), lt=(-0.55, 0.78, -2.12), lp=(-1, -0.6, 0.1)),
	k(3.70, S4B, hy=-0.1, hr=(6, 0, 0), ch=(-6, -10, 0), hd=(-3, -2, 0), gun=(-20, 4, 0, 0.3), lt=(-0.6, 0.7, -2.02), lp=(-1, -0.6, 0.1)),
	# one-handed, the gun turned on its side, aimed at the lens; rocks back on 4.80
	k(4.08, S4B, hy=-0.14, hr=(3, -6, 0), ch=(-4, -14, 0), hd=(-6, 6, -10), gun=(-6, 4, 80, 0.6), **HIP_L),
	k(4.18, S4B, hy=-0.18, hr=(4, -6, 0), ch=(-6, -15, 0), hd=(-7, 6, -12), gun=(-8, 4, 86, 0.65), **HIP_L),
	k(4.74, S4B, hy=-0.16, hr=(4, -6, 0), ch=(-5, -15, 0), hd=(-6, 6, -12), gun=(-7, 4, 86, 0.65), **HIP_L),
	k(4.84, S4B, hy=-0.06, hr=(-3, -6, 0), ch=(8, -12, 0), hd=(4, 6, -8), gun=(16, 4, 80, 0.5), **HIP_L),  # the rock back
	k(5.12, S4B, hy=-0.1, hr=(0, -6, 0), ch=(2, -12, 0), hd=(0, 4, -8), gun=(2, 4, 70, 0.5), **HIP_L),
	# the big hop on 5.36, both arms up
	k(5.26, STANCE, hy=-0.36, hr=(6, 0, 0), ch=(-10, -6, 0), hd=(-8, 0, 0), gun=(-30, -8, 0, 0.3), lt=(-1.25, -0.45, -0.55), lp=(-1, -0.6, 0.3)),
	k(5.42, AIR, hy=0.0, ch=(12, -4, 0), hd=(12, 0, 0), **BOTH),
	k(5.52, AIR, hy=0.0, ch=(12, -4, 0), hd=(12, 0, 0), **BOTH),
	k(5.60, STANCE, hy=-0.38, hr=(6, 0, 0), ch=(-8, -6, 0), hd=(-6, 0, 0), gun=(20, -16, -8, 0.3), lt=(-1.4, 0.6, -0.5), lp=(-1, -0.5, 0.3)),
	k(5.92, WIDE, **COIL),
	k(6.08, WIDE, **dict(COIL, hy=-0.5)),
	# both arms up in a V
	k(6.20, VFIN, hy=0.06, ch=(13, -4, 0), hd=(10, 0, 0), gun=(76, -40, 26, 0.5), lt=(-1.8, 1.9, -0.35)),
	k(6.30, VFIN, hy=0.02, ch=(15, -5, 0), hd=(12, 0, 0), gun=(80, -44, 32, 0.65), lt=(-2.0, 2.2, -0.35)),
	k(6.52, VFIN),
	k(6.72, VFIN, hy=-0.12, gun=(66, -40, 28, 0.55), lt=(-1.8, 1.8, -0.35)),
	k(6.86, VFIN, hy=0.0, ch=(13, -4, 0), gun=(78, -44, 32, 0.65), lt=(-2.0, 2.2, -0.35)),
	k(7.04, VFIN),
	k(7.30, VFIN),
]
group_clip("WinS4", S4)

# WinS5: the chill one -------------------------------------------------------------
S5B = dict(STANCE, hr=(0, 6, 0))
SKY = dict(WIDE, hy=-0.05, hr=(0, 4, 0), ch=(8, 6, -4), hd=(10, -10, -4), gun=(-56, -26, 0, 0.3), lt=(-1.25, 2.6, -0.25), lp=(-1, -0.3, 0.3))
S5 = [k(0.00, S5B, hy=-0.04, ch=(2, 2, 0), hd=(0, 10, 0), **SHOULDER, **HIP_L)]
for i, t in enumerate((0.14, 0.68, 1.22)):  # head nods on the beat
	S5.append(k(t + 0.06, S5B, hy=-0.07, ch=(1, 2, 0), hd=(-7, 10, 0), **SHOULDER, **HIP_L))
	S5.append(k(t + 0.3, S5B, hy=-0.04, ch=(2, 2, 0), hd=(1, 10, 0), **SHOULDER, **HIP_L))
S5 += [
	k(1.60, S5B, hy=-0.03, ch=(7, 2, 0), hd=(6, 0, 0), **SHOULDER, **HIP_L),  # leans back, chin up
	k(1.92, S5B, hy=-0.04, ch=(6, 0, 0), hd=(4, -4, 0), lt=(-1.05, 1.55, -0.55), lp=(-1, 0.3, 0.2), **SHOULDER),  # hand to the brow
	k(2.10, S5B, hy=-0.02, ch=(8, 4, 0), hd=(6, 4, -4), lt=(-1.95, 1.55, -0.6), lp=(-1, 0.1, 0.2), **SHOULDER),  # 2.02 the salute flicks out
	k(2.40, S5B, hy=-0.05, ch=(6, 2, 0), hd=(3, 6, -2), lt=(-1.6, 0.3, -0.5), lp=(-1, -0.4, 0.3), **SHOULDER),
	k(2.70, S5B, hy=-0.06, ch=(5, 2, 0), hd=(-5, 8, 0), **SHOULDER, **HIP_L),
	k(2.96, S5B, hy=-0.04, ch=(6, 2, 0), hd=(2, 8, 0), **SHOULDER, **HIP_L),
	k(3.24, S5B, hy=-0.07, ch=(5, 2, 0), hd=(-6, 8, 0), gun=(78, -8, -14, -0.1), **HIP_L),  # gun bounce on the beat
	k(3.50, S5B, hy=-0.04, ch=(6, 2, 0), hd=(2, 8, 0), **SHOULDER, **HIP_L),
	k(3.78, S5B, hy=-0.07, ch=(5, 2, 0), hd=(-6, 8, 0), **SHOULDER, **HIP_L),
	# two hands: brings the gun round and admires it, tilting it
	k(4.10, dict(RIFLE, ch=(0, -16, 0)), hy=-0.16, hr=(2, 10, 0), hd=(-14, 20, 0), gun=(6, 24, -30, 0.3), lt=(-0.6, 0.2, -1.25)),
	k(4.50, dict(RIFLE, ch=(0, -16, 0)), hy=-0.18, hr=(2, 10, 0), hd=(-16, 22, 4), gun=(10, 26, -50, 0.3), lt=(-0.6, 0.25, -1.25)),
	k(4.84, dict(RIFLE, ch=(2, -14, 0)), hy=-0.14, hr=(1, 8, 0), hd=(-10, 18, 0), gun=(12, 22, -20, 0.3), lt=(-0.6, 0.3, -1.25)),
	k(5.10, dict(RIFLE, ch=(2, -10, 0)), hy=-0.18, hr=(1, 4, 0), hd=(-4, 8, 0), gun=(0, 10, 0, 0.3), lt=(-0.6, 0.1, -1.25)),
	# 5.36: a lazy shrug instead of a spin, palm up, head tilted
	k(5.26, S5B, hy=-0.08, ch=(2, 2, 0), hd=(-2, 6, 0), gun=(-30, 4, 0, 0.25), lt=(-1.2, -0.5, -0.5), lp=(-1, -0.5, 0.3)),
	k(5.40, S5B, hy=0.0, ch=(8, 4, 6), hd=(4, 8, 12), gun=(-22, 4, 0, 0.3), lt=(-1.75, 0.45, -0.7), lp=(-1, -0.4, 0.2)),
	k(5.62, S5B, hy=-0.06, ch=(4, 2, 2), hd=(0, 6, 4), gun=(-28, 4, 0, 0.25), lt=(-1.3, -0.4, -0.5), lp=(-1, -0.5, 0.3)),
	k(5.92, WIDE, **COIL),
	k(6.10, WIDE, **dict(COIL, hy=-0.44)),
	# points at the sky, gun easy by the leg
	k(6.24, SKY, hy=0.05, ch=(10, 6, -4), hd=(12, -10, -4), lt=(-1.2, 2.35, -0.3)),
	k(6.34, SKY, hy=0.02, ch=(12, 7, -5), hd=(15, -10, -5), lt=(-1.3, 2.75, -0.22)),
	k(6.56, SKY),
	k(6.74, SKY, hy=-0.08, lt=(-1.2, 2.4, -0.28)),
	k(6.88, SKY, hy=-0.01, ch=(10, 6, -4), hd=(14, -10, -4), lt=(-1.28, 2.7, -0.22)),
	k(7.06, SKY),
	k(7.30, SKY),
]
group_clip("WinS5", S5, two=[(4.06, 4.16, 5.1, 5.24)], skip=[4.10, 4.50, 4.84, 5.10])
