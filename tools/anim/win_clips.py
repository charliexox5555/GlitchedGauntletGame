"""The end-of-match winner cutscene clips (vault/02 Art/Win Cutscene.md), keyed
on the third-person rig (tp_rig.py) to the ending song, APM "Victory Slam
stinger 1" (8.15 s). Song time = clip time: the cutscene starts the clip and
the song together, so every key below is on a measured accent of the song.

    python -I tools/anim/win_clips.py list
    python -I tools/anim/win_clips.py render out.png Win1_1@0,0.7,1.5 --views=0,90
    python -I tools/anim/win_clips.py check Win1_1 Win1_1Hold
    python -I tools/anim/win_clips.py export Win1_1 Win1_1Hold   # art-source/animations/GG_<Name>.rbxm

Names: Win<team size>_<slot> is the one-shot (it ends on the final pose),
Win<team size>_<slot>Hold the loop that holds that pose with a breath. The
1-player version is Win1_1; the 2-5 player versions slot in as Win2_1,
Win2_2, ... with their own keys, and Config/WinCutscene points each slot at
its clips.

Song accents (PlaybackLoudness at 0.2x speed, 20 ms bins, 2026-11-20):
0.14 slam, 0.68, 1.48 (the band kicks in), 1.82, 2.02 (loudest), 3.14,
4.02 + 4.16, 4.80, 5.36, 5.80, 6.14, 6.80 (last hit), ring-out 6.9-8.05.

Style (memory animation-oomph): every move coils first, snaps in about
60 ms, brakes past its mark and settles; keys on monotone cubics
(spline_sequence), never linear; the gun and the free hand lead.
"""

import math
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(__file__))

import tp_clips  # noqa: E402
from tp_clips import LONG_GRIP, Clip, add, bladed, spline_sequence  # noqa: E402
from tp_rig import ALL, solve, v3  # noqa: E402

TAU = 2 * math.pi
WIN = []  # the clip names this file adds


def win(clip):
	WIN.append(clip.name)
	return add(clip)


# One key's controls. Every key has the same shape (so the controls run on
# splines): hips, chest, head, gun about the right shoulder, the left fist's
# target and elbow pole, both feet.
#   hy, hr      hips drop (studs) and (pitch, yaw, roll) degrees
#   ch          chest (lean back +, turn: - = the left shoulder leads, tilt)
#   hd          head (pitch up +, yaw left +, roll)
#   gun         (pitch up, yaw left, roll about the barrel, reach out)
#   lt, lp      left fist target (root space: +X right, +Y up, -Z forward), elbow pole
#   rf, lf      feet: (x, y above the floor, z, yaw)
def key(hy=0.0, hr=(0, 0, 0), ch=(0, 0, 0), hd=(0, 0, 0), gun=(-36, 8, 0, 0), lt=(-1.2, -0.75, -0.1), lp=(-0.7, -1, 0.15), rf=(0.62, 0, 0.1, -8), lf=(-0.6, 0, -0.12, 5)):
	return {
		"hips": {"pos": (0, hy, 0), "rot": hr},
		"chest": bladed(*ch),
		"head": hd,
		"gun": {"shoulder": gun[:3], "reach": gun[3]},
		"right_pole": (0.9, -1, 0.35),
		"left_arm": {"tip": lt},
		"left_pole": lp,
		"right_foot": {"pos": rf[:3], "yaw": rf[3], "pole": (0.15, 0, -1), "clamp": True},
		"left_foot": {"pos": lf[:3], "yaw": lf[3], "pole": (-0.15, 0, -1), "clamp": True},
	}


def gun_grip(ctrl):
	"""Where the gun's left grip is for these controls (root space)."""
	c = dict(ctrl)
	solve(c)
	g = c.get("_gun_cf")
	if g is None:
		return None
	return tuple(g[:3, 3] + g[:3, :3] @ v3(LONG_GRIP))


def two_handed(track, windows):
	"""The track on splines, with the left fist carried onto the gun's grip
	over `windows` [(t_on0, t_on1, t_off0, t_off1)]: eased on between the first
	two times, held, eased off between the last two."""
	at = tp_clips.spline_ctrl(track)

	def weight(t):
		w = 0.0
		for a, b, c, d in windows:
			if a <= t <= d:
				if t < b:
					u = (t - a) / (b - a)
				elif t > c:
					u = 1 - (t - c) / (d - c)
				else:
					u = 1.0
				w = max(w, u * u * (3 - 2 * u))
		return w

	def pose(t):
		ctrl = at(t)
		w = weight(t)
		if w > 0:
			grip = gun_grip(ctrl)
			if grip is not None:
				tip = v3(ctrl["left_arm"]["tip"])
				ctrl["left_arm"] = {"tip": tuple(tip + (v3(grip) - tip) * w)}
		return tp_clips.solve_grounded(ctrl)

	return pose


# Win1_1: the 1-player winner (shots in Config/WinCutscene) ----------------------

# The final pose (held from 6.5 s): the champion. Wide stance, chest up,
# the left fist punched up and out on a diagonal (one line from the gun
# hand through the body to the fist), the gun hanging easy in
# the right hand down by the leg, chin level, eyes down on the low camera.
# (v1 had the gun up by the head: from the engine the right fist covered the
# face from any front-right camera.) 
FINAL = dict(
	hy=-0.05,
	hr=(0, -4, 0),
	ch=(6, -8, -6),
	hd=(-8, 8, -8),
	gun=(-38, -28, 0, 0.1),
	lt=(-2.1, 2.1, -0.45),
	lp=(-1, -0.3, 0.4),
	rf=(0.9, 0, 0.12, -16),
	lf=(-0.88, 0, -0.18, 12),
)


def final(**over):
	d = dict(FINAL)
	d.update(over)
	return key(**d)


# Shot A (0-1.48, behind the shoulder): catching breath, head down; up on 0.68.
LOW = dict(gun=(-38, 10, 0, 0), lt=(-1.15, -1.05, 0.0))
A = [
	(0.00, key(hy=-0.05, hr=(0, 4, 3), ch=(-6, 2, -2), hd=(-20, 0, 0), **LOW)),
	(0.14, key(hy=-0.08, hr=(0, 4, 3), ch=(-8, 2, -2), hd=(-22, 0, 0), **LOW)),  # slam: a breath out
	(0.40, key(hy=-0.03, hr=(0, 4, 3), ch=(-3, 2, -2), hd=(-17, 0, 0), **LOW)),
	(0.62, key(hy=-0.06, hr=(0, 4, 3), ch=(-6, 2, -2), hd=(-21, 0, 0), **LOW)),  # coil
	(0.72, key(hy=-0.02, hr=(0, 2, 2), ch=(2, 0, -1), hd=(6, -12, 0), **LOW)),  # 0.68: head up, looks out
	(0.80, key(hy=-0.01, hr=(0, 2, 2), ch=(3, 0, -1), hd=(9, -14, 0), **LOW)),  # overshoot
	(1.00, key(hy=-0.03, hr=(0, 2, 2), ch=(1, 0, -1), hd=(4, -10, 0), **LOW)),
	# 1.10-1.42 the coil for the big move: knees dip, chest folds, gun in
	(1.42, key(hy=-0.42, hr=(4, -4, 0), ch=(-14, 10, 0), hd=(-8, 0, 0), gun=(-12, 34, 0, -0.35), lt=(-0.4, 0.05, -1.3), lp=(-0.7, -1, 0.4))),
]

# Shot B (1.48-3.14, front three-quarter): the snap up, a stomp, the flex.
UP = dict(gun=(80, -12, -18, 0))
B = [
	(1.53, key(hy=0.04, hr=(-3, -6, 0), ch=(11, -6, 2), hd=(10, 0, 0), gun=(82, -12, -18, 0), lt=(-1.75, -0.15, -0.35), lp=(-1, -0.6, 0.3))),  # 1.48 snap (~60 ms)
	(1.62, key(hy=0.0, hr=(-3, -6, 0), ch=(13, -7, 2), hd=(12, 0, 0), gun=(87, -12, -20, 0), lt=(-1.85, -0.05, -0.3), lp=(-1, -0.6, 0.3))),  # overshoot
	(1.74, key(hy=-0.06, hr=(0, -4, 0), ch=(6, -6, 1), hd=(6, 0, 0), lt=(-1.55, -0.35, -0.3), lp=(-1, -0.6, 0.3), lf=(-0.62, 0.38, -0.5, 6), **UP)),  # left foot up
	(1.85, key(hy=-0.16, hr=(-4, -4, 0), ch=(2, -8, 0), hd=(2, 0, -2), lt=(-1.45, -0.4, -0.35), lp=(-1, -0.6, 0.3), lf=(-0.64, 0, -0.85, 8), **UP)),  # 1.82 stomp
	(1.94, key(hy=-0.1, hr=(-2, -4, 0), ch=(2, -6, 0), hd=(3, 4, -3), lt=(-0.55, 0.35, -1.05), lp=(-0.8, -1, 0.4), lf=(-0.64, 0, -0.85, 8), **UP)),  # flex coil: fist tucked in front of the belly
	(2.06, key(hy=-0.06, hr=(-2, 4, 0), ch=(7, 10, -4), hd=(4, 10, -8), lt=(-2.05, 0.95, -0.5), lp=(-1, -0.3, 0.3), lf=(-0.64, 0, -0.85, 8), **UP)),  # 2.02 the flex: the arm snaps out wide, chest open (v2's fist thrust at the lens hid the face)
	(2.13, key(hy=-0.05, hr=(-2, 5, 0), ch=(9, 12, -5), hd=(6, 12, -9), lt=(-2.15, 1.08, -0.45), lp=(-1, -0.3, 0.3), lf=(-0.64, 0, -0.85, 8), **UP)),  # brake past it
	(2.32, key(hy=-0.07, hr=(-2, 4, 0), ch=(6, 9, -4), hd=(3, 9, -8), lt=(-2.0, 0.9, -0.5), lp=(-1, -0.3, 0.3), lf=(-0.64, 0, -0.85, 8), **UP)),
	(2.56, key(hy=-0.13, hr=(-2, 4, 0), ch=(4, 9, -4), hd=(-2, 9, -8), lt=(-1.95, 0.78, -0.5), lp=(-1, -0.3, 0.3), lf=(-0.64, 0, -0.85, 8), **UP)),  # groove nod
	(2.84, key(hy=-0.07, hr=(-2, 4, 0), ch=(6, 9, -4), hd=(3, 9, -8), lt=(-2.0, 0.88, -0.5), lp=(-1, -0.3, 0.3), lf=(-0.64, 0, -0.85, 8), **UP)),
	(3.06, key(hy=-0.1, hr=(-2, -6, 0), ch=(1, -10, 0), hd=(-2, 4, -4), lt=(-0.5, 0.65, -1.15), lp=(-0.9, -0.6, 0.4), lf=(-0.64, 0, -0.85, 8), **UP)),  # pull in
]

# Shot C (3.14-4.02, close side): the "too easy" flick, chin up.
C = [
	(3.20, key(hy=-0.05, hr=(-2, -2, 0), ch=(6, -2, 3), hd=(12, 20, 4), lt=(-1.75, 0.55, 0.35), lp=(-1, -0.2, 0.4), lf=(-0.64, 0, -0.85, 8), gun=(80, -12, -18, 0))),  # 3.14 flick out
	(3.28, key(hy=-0.04, hr=(-2, -2, 0), ch=(8, -1, 4), hd=(15, 24, 5), lt=(-1.85, 0.45, 0.45), lp=(-1, -0.2, 0.4), lf=(-0.64, 0, -0.85, 8), gun=(82, -12, -18, 0))),  # brake
	(3.50, key(hy=-0.08, hr=(-2, -2, 0), ch=(5, -2, 3), hd=(10, 16, 3), lt=(-1.6, 0.2, 0.3), lp=(-1, -0.4, 0.4), lf=(-0.64, 0, -0.85, 8), gun=(77, -12, -18, 0))),
	(3.66, key(hy=-0.11, hr=(-2, -2, 0), ch=(4, -2, 3), hd=(8, 12, 2), lt=(-1.5, 0.05, 0.2), lp=(-1, -0.5, 0.4), lf=(-0.64, 0, -0.85, 8), gun=(80, -12, -18, 0))),  # gun bounce on the beat
	(3.92, key(hy=-0.16, hr=(-2, 0, 0), ch=(9, -4, 2), hd=(6, 6, 0), lt=(-1.35, -0.1, -0.5), lp=(-1, -0.6, 0.2), lf=(-0.64, 0, -0.85, 8), gun=(88, -10, -18, 0))),  # anticipation: gun lifts
]

# Shot D (4.02-5.80, wide orbit): the gun swings down into two hands, a
# sweep, a lean back, a spin-hop on 5.36, the coil for the final.
RIFLE = dict(ch=(-4, -24, 0), lp=(-0.5, -1, -0.2), lf=(-0.7, 0, -0.75, 10), rf=(0.75, 0, 0.25, -14))
D = [
	(4.08, key(hy=-0.3, hr=(4, 6, 0), hd=(-6, 14, 0), gun=(-2, 18, -10, 0.35), lt=(-0.6, 0.0, -1.3), **RIFLE)),  # 4.02 swing down
	(4.18, key(hy=-0.36, hr=(5, 8, 0), hd=(-8, 18, 0), gun=(-8, 20, -4, 0.3), lt=(-0.6, -0.05, -1.3), **RIFLE)),  # 4.16 caught (brake)
	(4.34, key(hy=-0.32, hr=(4, 8, 0), hd=(-5, 16, 0), gun=(-4, 18, 0, 0.25), lt=(-0.6, 0.0, -1.3), **RIFLE)),
	(4.74, key(hy=-0.28, hr=(3, -10, 0), hd=(-3, -14, 0), gun=(-2, -14, 0, 0.15), lt=(-0.6, 0.0, -1.3), **RIFLE)),  # sweep across
	(4.86, key(hy=-0.12, hr=(-4, -12, 0), ch=(9, -20, 0), hd=(8, -12, 0), gun=(22, -16, 0, 0), lt=(-0.6, 0.3, -1.2), lp=(-0.5, -1, -0.2), lf=(-0.7, 0, -0.75, 10), rf=(0.75, 0, 0.25, -14))),  # 4.80 lean back, muzzle up
	(5.14, key(hy=-0.1, hr=(-3, -8, 0), ch=(6, -14, 0), hd=(6, -6, 0), gun=(14, -6, 0, 0), lt=(-0.6, 0.2, -1.2), lp=(-0.5, -1, -0.2), lf=(-0.7, 0, -0.75, 10), rf=(0.75, 0, 0.25, -14))),
	# the spin-hop on 5.36: coil, take off, a full turn in the air (the root
	# turns: Config/WinCutscene slot `root` keys), knees tucked, land and
	# absorb. (v2-v5 rolled the gun a full turn instead: the rigid fist
	# follows the roll, so the forearm folded up past the chin.)
	(5.26, key(hy=-0.3, hr=(5, 0, 0), ch=(-8, -6, 0), hd=(-6, 0, 0), gun=(-34, -6, 0, 0.3), lt=(-1.25, -0.45, -0.55), lp=(-1, -0.6, 0.3), lf=(-0.7, 0, -0.75, 10), rf=(0.75, 0, 0.25, -14))),  # coil
	(5.34, key(hy=0.06, hr=(-2, 0, 0), ch=(5, -4, 0), hd=(3, 0, 0), gun=(-24, -14, 0, 0.35), lt=(-1.6, 0.05, -0.4), lp=(-1, -0.5, 0.3), lf=(-0.7, 0, -0.75, 10), rf=(0.75, 0, 0.25, -14))),  # take off
	(5.42, key(hy=0.0, hr=(-2, 0, 0), ch=(4, -4, 0), hd=(2, 0, 0), gun=(-18, -20, 0, 0.4), lt=(-1.75, 0.35, -0.3), lp=(-1, -0.4, 0.3), lf=(-0.62, 0.42, -0.4, 10), rf=(0.66, 0.38, 0.15, -14))),  # in the air, arms out
	(5.50, key(hy=0.0, hr=(-2, 0, 0), ch=(3, -4, 0), hd=(1, 0, 0), gun=(-20, -18, 0, 0.4), lt=(-1.7, 0.25, -0.35), lp=(-1, -0.4, 0.3), lf=(-0.62, 0.42, -0.4, 10), rf=(0.66, 0.38, 0.15, -14))),
	(5.57, key(hy=-0.34, hr=(6, 0, 0), ch=(-8, -6, 0), hd=(-6, 0, 0), gun=(-30, -8, 0, 0.3), lt=(-1.35, -0.35, -0.6), lp=(-1, -0.6, 0.3), lf=(-0.7, 0, -0.75, 10), rf=(0.75, 0, 0.25, -14))),  # land, absorb
	(5.68, key(hy=-0.16, hr=(2, 0, 0), ch=(-2, -6, 0), hd=(-1, 0, 0), gun=(-26, -6, 0, 0.3), lt=(-1.4, -0.3, -0.55), lp=(-1, -0.6, 0.3), lf=(-0.75, 0, -0.5, 10), rf=(0.8, 0, 0.2, -14))),
	# the coil for the final (5.80): low, folded, gun in, feet already wide
	(5.86, key(hy=-0.5, hr=(6, 4, 0), ch=(-16, 8, 0), hd=(-14, 0, 0), gun=(-28, 16, 0, -0.05), lt=(-0.45, -0.1, -1.25), lp=(-0.8, -1, 0.4), lf=(-0.88, 0, -0.18, 12), rf=(0.9, 0, 0.12, -16))),
	(6.06, key(hy=-0.56, hr=(7, 4, 0), ch=(-18, 8, 0), hd=(-16, 0, 0), gun=(-32, 16, 0, -0.08), lt=(-0.43, -0.12, -1.22), lp=(-0.8, -1, 0.4), lf=(-0.88, 0, -0.18, 12), rf=(0.9, 0, 0.12, -16))),
]

# Shot E (5.80-8.15, the low hero shot): the snap into the final pose on
# 6.14, a nod and a gun bounce on the last hit (6.80), then held.
E = [
	(6.20, final(hy=0.05, ch=(9, -6, -4), hd=(-2, 8, -8), gun=(-34, -20, 0, 0.05), lt=(-1.95, 1.95, -0.45))),  # 6.14 SNAP up (60 ms)
	(6.30, final(hy=0.02, ch=(11, -7, -5), hd=(0, 8, -9), gun=(-40, -30, 1, 0.1), lt=(-2.2, 2.3, -0.48))),  # overshoot
	(6.52, final()),
	(6.72, final(hy=-0.09, lt=(-1.95, 1.8, -0.42))),  # the fist dips
	(6.86, final(hy=-0.02, ch=(8, -6, -4), hd=(-12, 8, -9), lt=(-2.18, 2.28, -0.47))),  # 6.80 punch + nod
	(7.02, final(hd=(-6, 8, -8), lt=(-2.08, 2.06, -0.45))),
	(7.30, final()),
]

# The groove keys sit on the cubic, which brakes and settles on its own; the
# left fist goes onto the gun from the 4.02 swing to the 5.20 twirl.
WIN1_1 = A + B + C + D + E
win(Clip("Win1_1", "Action4", two_handed(WIN1_1, [(4.06, 4.18, 5.14, 5.3)]), ALL, length=7.3, loop=False, step=1 / 60))


def win1_hold(t):
	# A slow breath on the final pose: the chest rises, the gun rocks a
	# touch on the shoulder, the head settles; 3.2 s, so it never pulses.
	ph = TAU * t / 3.2
	b = math.sin(ph)
	b2 = math.sin(ph * 2 + 0.6)
	return tp_clips.solve_grounded(
		final(
			hy=FINAL["hy"] - 0.02 + 0.02 * b,
			ch=(FINAL["ch"][0] + 1.2 * b, FINAL["ch"][1] + 0.6 * b2, FINAL["ch"][2]),
			hd=(FINAL["hd"][0] - 0.8 * b, FINAL["hd"][1] + 0.8 * b2, FINAL["hd"][2]),
			gun=(FINAL["gun"][0] + 1.4 * b, FINAL["gun"][1], FINAL["gun"][2], 0),
			lt=(FINAL["lt"][0], FINAL["lt"][1] + 0.03 * b, FINAL["lt"][2]),
		)
	)


win(Clip("Win1_1Hold", "Action4", win1_hold, ALL, length=3.2, loop=True, step=1 / 30))


# Commands -------------------------------------------------------------------------


def main():
	cmd = sys.argv[1] if len(sys.argv) > 1 else "list"
	if cmd == "list":
		for name in WIN:
			c = tp_clips.CLIPS[name]
			print("%-14s %-8s %.2fs %s" % (name, c.priority, c.length, "loop" if c.loop else "once"))
	elif cmd == "render":
		import tp_render

		sys.argv = [sys.argv[0]] + sys.argv[2:]
		tp_render.main()
	elif cmd == "check":
		import tp_check

		sys.argv = [sys.argv[0]] + sys.argv[2:]
		tp_check.main()
	elif cmd == "export":
		tp_clips.export(sys.argv[2:] or WIN)


if __name__ == "__main__":
	main()
