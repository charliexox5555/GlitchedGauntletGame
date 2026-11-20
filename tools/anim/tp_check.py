"""Per-frame checks for the third-person clips (vault/01 Design/Third Person
Overhaul.md §15, §18), on the rig in tp_rig.py, sampled at 60 Hz:

    python -I tools/anim/tp_check.py RunF RunL Jump ...          # a table per clip
    python -I tools/anim/tp_check.py --speed=RunL:16 ...           # ground speed for the lock

For each clip:
    sink    studs the lowest shin / foot corner goes under the floor
    knee    studs the lowest corner of any thigh or shin block (R15 part box)
            goes under the floor (a kneel can bury a knee with the soles fine)
    lock    for a ground clip: how fast the corner a planted foot stands on
            moves over the ground, as a share of the ground speed (100% = no
            slide; the block has no ankle, so it rolls heel to toe on its
            corners); "slipm" / "slipx" = that speed, studs/s, mean / worst
    legs    the closest the two shins come (segment to segment, studs; under
            about 0.9 the 1-stud blocks pass through each other)
    arms    frames with a hand or forearm centre inside the chest block
    jump    the largest step a hand or foot makes in one 60 Hz frame (studs),
            including a loop's wrap from the last frame to the first
Feet count as planted when the sole's lowest corner is within 0.02 of the floor.
"""

import math
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(__file__))

import tp_clips  # noqa: E402
from tp_rig import FLOOR, HALF, KNEE_TO_SOLE, fk, v3  # noqa: E402

FPS = 60
PLANTED = 0.02

# Ground travel each ground clip is made for: (x, z) per second in root
# space (the body moves this way; a planted foot should move the other way).
TRAVEL = {}


def _travel(name):
	if name in TRAVEL:
		return TRAVEL[name]
	return None


def sole_corners(world, side):
	shin = world[side + "LowerLeg"]
	# The knee: the lower leg's top joint (0.379 above its centre).
	knee = shin @ np.array([0, 0.379, 0, 1.0])
	rot = shin[:3, :3]
	return [knee[:3] + rot @ v3(cx, -KNEE_TO_SOLE, cz) for cx in (-HALF, HALF) for cz in (-HALF, HALF)]


# The engine's leg part boxes (R15, measured in the match place 2026-11-21):
# a kneel can sink a knee with every sole corner above the floor, so the
# "knee" column checks the whole thigh and shin blocks.
LEG_BOXES = {"UpperLeg": (1.0, 1.2166, 1.0), "LowerLeg": (1.0, 1.1931, 1.0)}


def leg_low(world):
	low = 9.0
	for side in ("Right", "Left"):
		for part, (sx, sy, sz) in LEG_BOXES.items():
			m = world[side + part]
			for cx in (-sx / 2, sx / 2):
				for cy in (-sy / 2, sy / 2):
					for cz in (-sz / 2, sz / 2):
						low = min(low, float((m @ np.array([cx, cy, cz, 1.0]))[1]) + FLOOR)
	return low


def shin_segment(world, side):
	shin = world[side + "LowerLeg"]
	knee = (shin @ np.array([0, 0.379, 0, 1.0]))[:3]
	sole = knee + shin[:3, :3] @ v3(0, -KNEE_TO_SOLE + 0.15, 0)
	return knee, sole


def seg_dist(p1, q1, p2, q2):
	d1, d2, r = q1 - p1, q2 - p2, p1 - p2
	a, e, f = float(d1 @ d1), float(d2 @ d2), float(d2 @ r)
	c, b = float(d1 @ r), float(d1 @ d2)
	denom = a * e - b * b
	s = min(max((b * f - c * e) / denom, 0.0), 1.0) if denom > 1e-9 else 0.0
	t = (b * s + f) / e
	if t < 0:
		t, s = 0.0, min(max(-c / a, 0.0), 1.0)
	elif t > 1:
		t, s = 1.0, min(max((b - c) / a, 0.0), 1.0)
	return float(np.linalg.norm((p1 + d1 * s) - (p2 + d2 * t)))


def inside_chest(world, point):
	chest = world["UpperTorso"]
	local = np.linalg.inv(chest) @ np.append(point, 1.0)
	return abs(local[0]) < 0.9 and abs(local[1]) < 0.7 and abs(local[2]) < 0.4


def check(clip, travel=None, full=True):
	n = max(1, round(clip.length * FPS))
	times = [clip.length * i / n for i in range(n + (0 if clip.loop else 1))]
	frames = []
	for t in times:
		pose = tp_clips.full_pose(clip, t) if full else clip.pose(t)
		frames.append(fk(pose))
	sink = 0.0
	knee = 0.0
	legs = 9.0
	arms = 0
	jump = 0.0
	slip = 0.0
	slip_frames = 0
	planted_frames = 0
	prev = None
	ends = ("RightHand", "LeftHand", "RightFoot", "LeftFoot")
	soles = []
	for w in frames:
		low = {}
		for side in ("Right", "Left"):
			corners = sole_corners(w, side)
			low[side] = min(c[1] for c in corners) + FLOOR
			sink = max(sink, -low[side])
		soles.append({side: (sole_corners(w, side), low[side]) for side in ("Right", "Left")})
		knee = max(knee, -leg_low(w))
		k1, s1 = shin_segment(w, "Right")
		k2, s2 = shin_segment(w, "Left")
		legs = min(legs, seg_dist(k1, s1, k2, s2))
		if "UpperTorso" in clip.parts:
			for part in ("RightHand", "LeftHand", "RightLowerArm", "LeftLowerArm"):
				if inside_chest(w, w[part][:3, 3]):
					arms += 1
					break
		if prev is not None:
			jump = max(jump, max(float(np.linalg.norm(w[p][:3, 3] - prev[p][:3, 3])) for p in ends))
		prev = w
	if clip.loop and len(frames) > 1:
		w, p0 = frames[0], frames[-1]
		jump = max(jump, max(float(np.linalg.norm(w[p][:3, 3] - p0[p][:3, 3])) for p in ends))
	if travel is not None:
		ground = v3(travel[0], 0, travel[1])
		speed = float(np.linalg.norm(ground))
		count = len(soles)
		for i in range(count if clip.loop else count - 1):
			a, b = soles[i], soles[(i + 1) % count]
			for side in ("Right", "Left"):
				if a[side][1] < PLANTED and b[side][1] < PLANTED:
					planted_frames += 1
					# The corner the block stands on (it rolls heel to toe: no ankle).
					k = min(range(4), key=lambda j: a[side][0][j][1])
					v = (b[side][0][k] - a[side][0][k]) * FPS
					v[1] = 0
					# Over the ground: the sole's root-space velocity plus the body's.
					over = float(np.linalg.norm(v + ground))
					slip = max(slip, over)
					slip_frames += over
		mean_slip = slip_frames / planted_frames if planted_frames else float("nan")
		lock = 100 * (1 - mean_slip / speed) if speed > 0 else float("nan")
	else:
		lock, mean_slip = float("nan"), float("nan")
	return {
		"sink": sink,
		"knee": knee,
		"lock": lock,
		"mean_slip": mean_slip,
		"slip": slip,
		"planted": planted_frames,
		"legs": legs,
		"arms": arms,
		"jump": jump,
		"frames": len(frames),
	}


def main():
	speeds = {}
	names = []
	for arg in sys.argv[1:]:
		if arg.startswith("--speed="):
			for item in arg[8:].split(","):
				k, _, v = item.partition(":")
				speeds[k] = v
			continue
		names.append(arg)
	names = names or list(tp_clips.CLIPS)
	print("%-14s %6s %6s %6s %6s %6s %6s %5s %6s %6s" % ("clip", "sink", "knee", "lock%", "slipm", "slipx", "legs", "arms", "jump", "planted"))
	for name in names:
		clip = tp_clips.CLIPS[name]
		travel = tp_clips.GROUND.get(name) if hasattr(tp_clips, "GROUND") else None
		if name in speeds:
			travel = tuple(float(x) for x in speeds[name].split("/"))
		r = check(clip, travel)
		print(
			"%-14s %6.3f %6.3f %6.1f %6.2f %6.2f %6.2f %5d %6.3f %6d"
			% (name, r["sink"], r["knee"], r["lock"], r["mean_slip"], r["slip"], r["legs"], r["arms"], r["jump"], r["planted"])
		)


if __name__ == "__main__":
	main()
