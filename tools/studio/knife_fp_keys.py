"""First-person knife keys (Config/Viewmodel TRACKS Slash1-3, HeavyStab,
DrawMelee, InspectMelee), solved from what should be seen on screen.

    python -I tools/studio/knife_fp_keys.py            # Luau tracks to paste
    python -I tools/studio/knife_fp_keys.py --check    # grip / tip on screen per key
    python -I tools/studio/knife_fp_keys.py --write    # put them in Config/Viewmodel (then stylua src)

2026-11-14 (feel-videos pass, vault Playtests/2026-11-14 Gun and Knife Feel
from Videos): every key is now written the way the owner's reference clip was
measured, in screen terms. A key gives where the fist is on screen (x, y from
-1 to 1, 16:9, FOV 80) and how far from the eye (studs), where the blade's tip
points on screen (same terms), and a hint for which way the edge faces (camera
space, made perpendicular to the blade). The tracks are `screen` tracks:
ViewmodelController turns them about the grip in camera axes, so a key's
offset is grip - REST_GRIP and its rotation takes the rest blade frame to the
wanted one, written as CFrame.Angles(x, y, z) degrees. Keys between which the
blade turns more than SLERP_LIMIT are refused (CFrame:Lerp takes the short
way, so a bigger step would spin the wrong way round).

REST_* are the knife's hip hold, measured in play (camera space): the
RightGrip attachment, the blade tip and the blade's edge axis. 2026-11-14
(owner: "look at the hold [in RIVALS], really analyze it and replicate it"):
Config/Weapons Knife viewmodelOffset (0.862, -0.516, -1.445), viewmodelRotation
(78.2, 16.9, -30): the blade upright in the screen's plane, leaning in ~16
degrees, seen nearly edge-on, the guard and the top half of the handle out of
the fist's inner corner (was (0.893, -0.762, -1.455) / (59.2, 9.9, -25), tilted
~30 degrees into the screen, so the handle pointed at the camera).
"""

import math
import sys

import numpy as np

REST_GRIP = np.array([0.8893, -0.5562, -1.5393])
REST_TIP = np.array([0.6532, 0.6513, -1.8602])
REST_EDGE = np.array([-0.4224, -0.3208, -0.8478])
FOV = 80
ASPECT = 16 / 9  # design screen (the reference clips and most players)
T = math.tan(math.radians(FOV / 2))
SLERP_LIMIT = 120  # degrees between two keys (LihFolk Animation Data Hygiene: under 120)


def unit(v):
	v = np.asarray(v, float)
	return v / np.linalg.norm(v)


def frame(blade, edge):
	"""Columns: blade, edge (made perpendicular), their cross."""
	b = unit(blade)
	e = unit(np.asarray(edge, float) - b * np.dot(edge, b))
	return np.stack([b, e, np.cross(b, e)], axis=1)


REST_FRAME = frame(REST_TIP - REST_GRIP, REST_EDGE)


def angles_xyz(r):
	"""R = Rx(X) Ry(Y) Rz(Z) -> degrees (X, Y, Z), as CFrame.Angles."""
	y = math.asin(max(-1.0, min(1.0, r[0, 2])))
	x = math.atan2(-r[1, 2], r[2, 2])
	z = math.atan2(-r[0, 1], r[0, 0])
	return tuple(math.degrees(v) for v in (x, y, z))


def at(sx, sy, depth):
	"""Camera-space point seen at screen (sx, sy) (-1..1), `depth` studs away."""
	return np.array([sx * depth * T * ASPECT, sy * depth * T, -depth])


def screen(p):
	return (p[0] / -p[2] / (T * ASPECT), p[1] / -p[2] / T)


def rz(deg):
	c, s = math.cos(math.radians(deg)), math.sin(math.radians(deg))
	return np.array([[c, -s, 0], [s, c, 0], [0, 0, 1.0]])


REST_SCREEN = screen(REST_GRIP)
BLADE_LEN = float(np.linalg.norm(REST_TIP - REST_GRIP))

# The rigid fist (2026-11-14, owner: no fingers, "keep it on the edge of the
# hand"). Measured in play at the hold: the knife Handle's look (the blade)
# and up (the spine) in camera space, the forearm in handle space
# (Config/Viewmodel MELEE_HAND.direction) and the fist's point (its offset).
_LOOK = unit([-0.1909, 0.9458, -0.2628])
_UP = unit([0.4224, 0.3208, 0.8478])
_RIGHT = np.cross(_LOOK, _UP)


def _handle_to_cam(v):
	return v[0] * _RIGHT + v[1] * _UP - v[2] * _LOOK


# 2026-11-14, second try (owner: "seeing the bottom through the hand"): the
# hilt is 0.8 studs guard to pommel and the fist block 0.5 wide, so a handle
# crossing the block pokes out of it. The handle now runs 15 degrees off the
# forearm, inside the block on its inner edge, the guard just past its end
# (Config/Viewmodel MELEE_HAND).
# Pass 2 (owner: "my hand is facing upwards to the sky... it should be more
# straight ahead, and then the knife still points up"): a hammer grip, the
# forearm reaching forward from the lower right (-57 deg on screen, like the
# clip), 60 degrees off the knife; searched in play so that no part of the
# handle that leaves the block can be seen from the camera.
# (Then, owner: "the arm should look normal and the knife being held as if
# there was a hand but there is not"): the forearm block ends at the wrist and
# the whole knife sits just past its end, the pommel at the end face's
# centre, where an unseen hand holds it (the RIVALS look); the forearm
# reaches forward at the clip's screen angle. Nothing of the knife is inside
# the block, so the wrist can bend freely about the forearm's end.
FOREARM_HANDLE = unit([-0.6634, 0.5567, 0.5000])
FIST_HANDLE = np.array([0.0199, -0.0167, 0.285])  # the handle enters the top of the forearm's end
PIVOT_HANDLE = np.array([0.0, 0.0, 0.3])  # MELEE_WRIST_PIVOT: where the handle crosses the forearm
FOREARM = unit(_handle_to_cam(FOREARM_HANDLE))
FIST = _handle_to_cam(FIST_HANDLE)
SHOULDER = np.array([0.08, -1.95, 1.60])  # MELEE_SHOULDER (root ~ camera): on the hold's own forearm line
WRIST_BEND = 20  # MELEE_WRIST_BEND
EYE_CLEAR = 0.45

# A key spec is one of:
#   ("rest",)                       the hold
#   ("near", dsx, dsy, roll)        the hold nudged on screen, rolled (deg)
#   ("held", grip, roll)            the hold's turn, leaned `roll` degrees on
#                                   screen, with the fist at `grip`
#   ("fist", grip, roll[, elbow])   the rigid fist at `grip`, its forearm
#                                   running to the shoulder (or `elbow`, camera
#                                   space), turned `roll` degrees about the
#                                   forearm (+ = supinated); the knife follows
#   ("blend", grip)                 the turn between the keys either side, by
#                                   time (spreads a big turn over hidden keys)
#   ("aim", grip, tip, edge)        grip / tip = (sx, sy, depth); edge = a hint
#                                   for the edge (camera space) or "auto": the
#                                   wrist roll whose rigid forearm comes
#                                   closest to the shoulder side


def forearm_of(grip, r, elbow=None):
	"""The drawn forearm for a key, as ViewmodelController draws it: rigid with
	the knife, bent toward the shoulder (or `elbow`) by at most WRIST_BEND
	about the pivot inside the fist. -> (fist point, forearm, degrees left)."""
	f = r @ FOREARM
	hand = grip + r @ FIST
	want = unit((SHOULDER if elbow is None else np.asarray(elbow, float)) - hand)
	angle = math.degrees(math.acos(max(-1.0, min(1.0, float(np.dot(f, want))))))
	bend = min(angle, WRIST_BEND)
	axis = np.cross(f, want)
	if bend > 1e-3 and np.linalg.norm(axis) > 1e-6:
		turn = _exp(unit(axis) * math.radians(bend))
		pivot = grip + r @ (_handle_to_cam(PIVOT_HANDLE) - _handle_to_cam(np.zeros(3)))
		hand = pivot + turn @ (hand - pivot)
		f = turn @ f
	return hand, unit(f), angle - bend


def eye_gap(hand, along, length=2.4):
	t = max(0.0, min(length, float(np.dot(-hand, along))))
	return float(np.linalg.norm(hand + along * t))


def auto_roll(grip, blade, prev_r, elbow=None):
	b = unit(blade)
	u = unit(np.cross(b, [0.0, 0.0, 1.0]) if abs(b[2]) < 0.95 else np.cross(b, [1.0, 0.0, 0.0]))
	v = np.cross(b, u)
	best = None
	for step in range(180):
		phi = math.radians(step * 2)
		r = frame(b, math.cos(phi) * u + math.sin(phi) * v) @ REST_FRAME.T
		hand, along, angle = forearm_of(grip, r, elbow)
		score = -angle / 90
		if prev_r is not None:
			score -= 0.9 * turn_between(prev_r, r) / 180
		if eye_gap(hand, along) < EYE_CLEAR:
			score -= 1
		if best is None or score > best[0]:
			best = (score, r)
	return best[1]


def solve(spec, prev_r=None):
	"""-> (grip camera-space, rotation matrix from the rest frame)."""
	kind = spec[0]
	if kind == "rest":
		return REST_GRIP.copy(), np.eye(3)
	if kind == "fist":
		_, grip, roll = spec[:3]
		elbow = np.array(spec[3]) if len(spec) > 3 else SHOULDER
		g = at(*grip)
		r = np.eye(3)
		for _ in range(4):
			want = unit(elbow - (g + r @ FIST))
			r = _exp(want * math.radians(roll)) @ rot_between(FOREARM, want)
		return g, r
	if kind == "held":
		_, grip, roll = spec
		return at(*grip), rz(roll)
	if kind == "near":
		_, dsx, dsy, roll = spec
		g = at(REST_SCREEN[0] + dsx, REST_SCREEN[1] + dsy, -REST_GRIP[2])
		return g, rz(roll)
	_, grip, tip, edge = spec[:4]
	elbow = spec[4] if len(spec) > 4 else None
	g = at(*grip)
	if isinstance(edge, str):
		return g, auto_roll(g, at(*tip) - g, prev_r, elbow)
	return g, frame(at(*tip) - g, edge) @ REST_FRAME.T


def _log(r):
	"""Rotation matrix -> rotation vector."""
	c = max(-1.0, min(1.0, (np.trace(r) - 1) / 2))
	ang = math.acos(c)
	if ang < 1e-6:
		return np.zeros(3)
	w = np.array([r[2, 1] - r[1, 2], r[0, 2] - r[2, 0], r[1, 0] - r[0, 1]])
	if math.sin(ang) < 1e-4:  # ~180 degrees
		vals, vecs = np.linalg.eigh((r + r.T) / 2)
		axis = vecs[:, int(np.argmax(vals))]
		return axis * ang
	return w / (2 * math.sin(ang)) * ang


def _exp(v):
	ang = float(np.linalg.norm(v))
	if ang < 1e-9:
		return np.eye(3)
	k = v / ang
	kx = np.array([[0, -k[2], k[1]], [k[2], 0, -k[0]], [-k[1], k[0], 0]])
	return np.eye(3) + math.sin(ang) * kx + (1 - math.cos(ang)) * kx @ kx


def rot_between(a, b):
	"""The smallest rotation taking unit a onto unit b."""
	a, b = unit(a), unit(b)
	v = np.cross(a, b)
	c = float(np.dot(a, b))
	if np.linalg.norm(v) < 1e-9:
		return np.eye(3) if c > 0 else _exp(unit(np.cross(a, [1.0, 0, 0])) * math.pi)
	return _exp(unit(v) * math.acos(max(-1.0, min(1.0, c))))


def slerp(r0, r1, a):
	return r0 @ _exp(_log(r0.T @ r1) * a)


def turn_between(r0, r1):
	c = (np.trace(r1 @ r0.T) - 1) / 2
	return math.degrees(math.acos(max(-1.0, min(1.0, c))))


OUT, IN, INOUT = "Out", "In", "InOut"
LIN = ("Linear", None)

# Keys from a frame-by-frame study of the owner's knife clip (60 fps;
# art-source/reference/feel-videos, frames in its frames/ folder; vault note
# 2026-11-14 Gun and Knife Feel from Videos, pass 2). Screen positions are
# the clip's, measured per frame. Pass 2 (owner: "the slashes... stay
# upright", "the right click... a hesitation", "the inspect... the knife
# doesn't move at all"):
# - In the clip the blade never stands up during a slash: it LIES OVER and
#   TRAILS the fist (pointing back the way it came, ~40-50 degrees off
#   vertical) while the forearm sweeps like a wiper from a low pivot. Keys
#   give the fist and the tip on screen; the forearm's roll is solved
#   ("auto") so the arm comes from the shoulder side. The hold (60 degrees
#   between knife and forearm, MELEE_HAND) is what lets the roll lay the
#   blade over.
# - Forehand: tell (1 frame), off screen low right to wind up (~5 frames),
#   one sweep from the upper right to the lower left in ~5 frames, off,
#   back up from below. Backhand: tell (blade leans left), whip down-left,
#   the LOAD (blade out left, in line with a forearm crossing the body,
#   ~8 frames), release, sweep right with the blade trailing up-left, out
#   bottom right.
# Timing for oomph: a tell, a held coil, a strike of ~70 ms, a braking
# follow-through, a rise past the hold and a settle (monotone spline).
ATTACKS = {
	"Slash1": (0.6, 0.28, [
		(0.03, ("near", 0.04, 0.02, -8), None),
		(0.12, ("aim", (1.0, -1.35, 1.2), (1.5, -0.6, 1.5), "auto"), None),
		(0.18, ("aim", (1.15, -0.15, 1.1), (1.6, 0.6, 1.5), "auto"), None),
		(0.21, ("aim", (0.75, 0.15, 1.0), (1.1, 1.0, 1.4), "auto"), None),
		(0.235, ("aim", (0.45, 0.1, 1.0), (0.95, 0.9, 1.5), "auto"), None),
		(0.258, ("aim", (0.15, -0.03, 1.0), (0.72, 0.78, 1.6), "auto"), None),
		(0.28, ("aim", (-0.24, -0.2, 1.0), (0.15, 0.3, 1.7), "auto"), None),
		(0.305, ("aim", (-0.6, -0.56, 1.0), (-0.18, -0.08, 1.7), "auto"), None),
		(0.33, ("aim", (-0.92, -0.92, 1.0), (-0.42, -0.42, 1.7), "auto"), None),
		(0.42, ("aim", (-1.25, -1.4, 1.0), (-0.9, -0.95, 1.6), "auto"), None),
		(0.5, ("aim", (-1.32, -1.5, 1.0), (-1.0, -1.05, 1.6), "auto"), None),
		(0.64, ("blend", (-0.2, -1.75, 1.2)), None),
		(0.74, ("blend", (0.35, -1.35, 1.3)), None),
		(0.83, ("near", 0.0, -0.2, 0), None),
		(0.9, ("near", 0.0, 0.045, -3), None),
		(0.96, ("near", 0.0, -0.01, 1), None),
	]),
	"Slash2": (0.6, 0.385, [
		(0.03, ("near", -0.03, 0.0, 12), None),
		(0.07, ("aim", (-0.2, -0.85, 1.05), (-0.95, -0.7, 1.3), "auto", (1.5, -1.7, 0.8)), None),
		(0.12, ("aim", (-0.55, -0.42, 1.0), (-1.25, -0.15, 1.25), "auto", (1.5, -1.7, 0.6)), None),
		(0.27, ("aim", (-0.62, -0.45, 1.0), (-1.32, -0.2, 1.25), "auto", (1.5, -1.7, 0.6)), None),
		(0.33, ("aim", (-0.42, -0.2, 1.0), (-1.0, 0.25, 1.4), "auto", (1.4, -1.7, 0.8)), None),
		(0.36, ("aim", (-0.28, -0.12, 1.0), (-0.75, 0.35, 1.6), "auto"), None),
		(0.385, ("aim", (-0.06, -0.12, 1.0), (-0.6, 0.36, 1.7), "auto"), None),
		(0.415, ("aim", (0.22, -0.4, 1.0), (-0.14, 0.16, 1.7), "auto"), None),
		(0.445, ("blend", (0.55, -0.85, 1.0)), None),
		(0.53, ("blend", (1.0, -1.35, 1.05)), None),
		(0.58, ("blend", (1.08, -1.45, 1.05)), None),
		(0.7, ("blend", (0.8, -1.7, 1.2)), None),
		(0.8, ("near", 0.0, -0.2, 0), None),
		(0.9, ("near", 0.0, 0.045, 3), None),
		(0.96, ("near", 0.0, -0.01, -1), None),
	]),
	# Third in a chain: a second forehand, coiled higher, swept flatter and
	# lower across the chest.
	"Slash3": (0.6, 0.29, [
		(0.03, ("near", 0.04, 0.03, -8), None),
		(0.12, ("aim", (1.05, -0.9, 1.2), (1.5, -0.1, 1.5), "auto"), None),
		(0.19, ("aim", (1.2, 0.3, 1.1), (1.6, 1.0, 1.5), "auto"), None),
		(0.22, ("aim", (0.78, 0.0, 1.0), (1.2, 0.75, 1.4), "auto"), None),
		(0.245, ("aim", (0.45, -0.12, 1.0), (1.0, 0.62, 1.5), "auto"), None),
		(0.268, ("aim", (0.12, -0.22, 1.0), (0.68, 0.5, 1.6), "auto"), None),
		(0.29, ("aim", (-0.25, -0.35, 1.0), (0.2, 0.18, 1.7), "auto"), None),
		(0.315, ("aim", (-0.62, -0.62, 1.0), (-0.18, -0.15, 1.7), "auto"), None),
		(0.34, ("aim", (-0.95, -0.95, 1.0), (-0.45, -0.45, 1.7), "auto"), None),
		(0.43, ("aim", (-1.28, -1.38, 1.0), (-0.92, -0.95, 1.6), "auto"), None),
		(0.51, ("aim", (-1.34, -1.48, 1.0), (-1.02, -1.05, 1.6), "auto"), None),
		(0.65, ("blend", (-0.2, -1.75, 1.2)), None),
		(0.75, ("blend", (0.35, -1.35, 1.3)), None),
		(0.84, ("near", 0.0, -0.2, 0), None),
		(0.91, ("near", 0.0, 0.045, -3), None),
		(0.96, ("near", 0.0, -0.01, 1), None),
	]),
	# Heavy, one flowing move (owner: "a hesitation between it"): a dip, down
	# and back into the cocked pose without stopping (a slow creep, never a
	# dead hold), a ~50 ms thrust with both fists (MELEE_HEAVY_HAND), carried
	# out a little further, the forearm rolls the blade back up, past the
	# hold, settle.
	"HeavyStab": (0.9, 0.42, [
		(0.05, ("fist", (0.46, -0.6, 1.42), -4), None),
		(0.15, ("fist", (0.6, -0.92, 1.3), -10), None),
		(0.21, ("blend", (0.35, -0.8, 1.15)), None),
		(0.27, ("aim", (0.06, -0.62, 1.02), (0.0, -0.12, 2.3), "auto", (2.0, -1.3, -0.4)), None),
		(0.36, ("aim", (0.08, -0.68, 0.94), (0.01, -0.16, 2.25), "auto", (2.0, -1.3, -0.4)), None),
		(0.42, ("aim", (0.02, -0.45, 1.6), (-0.04, -0.06, 2.8), "auto", (1.9, -1.4, -0.3)), None),
		(0.5, ("aim", (0.0, -0.44, 1.74), (-0.05, -0.06, 2.95), "auto", (1.9, -1.4, -0.3)), None),
		(0.58, ("aim", (0.03, -0.46, 1.62), (-0.03, -0.07, 2.8), "auto", (1.9, -1.4, -0.3)), None),
		(0.63, ("blend", (0.12, -0.52, 1.5)), None),
		(0.68, ("fist", (0.24, -0.58, 1.38), 35), None),
		(0.78, ("fist", (0.42, -0.5, 1.4), 18), None),
		(0.87, ("near", 0.0, 0.045, -5), None),
		(0.94, ("near", 0.0, -0.012, 2), None),
	]),
}

# The pull-out (owner, pass 1: "feels good"): the fist swings up and flicks;
# the knife is tossed, turns once in the air and is caught; the catch knocks
# the fist down, it rises past the hold and settles. The free arm comes last.
DRAW = (0.75, [
	(0.0, ("fist", (0.8, -1.7, 1.3), 30), None),
	(0.2, ("fist", (0.5, -0.85, 1.32), 10), None),
	(0.28, ("fist", (0.42, -0.36, 1.4), -4), None),
	(0.36, ("fist", (0.43, -0.6, 1.42), 3), None),
	(0.52, ("fist", (0.42, -0.52, 1.42), 1), None),
	(0.6, ("fist", (0.41, -0.46, 1.42), 0), None),
	(0.68, ("fist", (0.42, -0.62, 1.42), -4), None),
	(0.8, ("near", 0.0, 0.03, 2.5), None),
	(0.9, ("near", 0.0, -0.008, -1), None),
])
DRAW_TOSS = [
	(0.0, (0, 0, 0), (0, 0, 0)),
	(0.28, (0, 0, 0), (0, 0, 0)),
	(0.36, (0, 0, -0.28), (0, 100, 0)),
	(0.44, (0, 0, -0.4), (0, 200, 0)),
	(0.52, (0, 0, -0.25), (0, 300, 0)),
	(0.6, (0, 0, 0), (0, 360, 0)),
	(1.0, (0, 0, 0), (0, 360, 0)),
]
DRAW_TOSS_PIVOT = (0, 0, -0.4)

# The inspect, pass 2 (owner: "boring... the knife doesn't move at all";
# moving the knife is fine if natural): up to the middle, the forearm rolls
# the face to you past the pose and settles, a drift; a dip and a flick: the
# knife is TOSSED and flips end over end in the air while the fist waits,
# caught with a dip; the forearm rolls right over to show the other face,
# past and settle, a drift; and it lowers back to the hold.
# 2026-11-15 (owner: the second turn "too blocky and staged"). It was two
# even turns, 72 then 47 degrees over 0.37 s, rolling and tipping together,
# then a hold that moved 10 degrees in 0.65 s. The clip, frame by frame
# (14.05-14.40 s): the wrist ROLLS the blade about its own length to edge-on
# while it still stands up (~100 ms), then it WHIPS over to the left, pivoting
# on a fist that barely moves (~130 ms, 30-40 degrees a frame), lands pointing
# left a little below level, and keeps tipping slowly through the hold. So:
# "split" keys roll first (0.555-0.59), then swing (0.59-0.63); the hold
# after it tips a further ~14 degrees.
INSPECT = (3.4, [
	(0.08, ("near", -0.06, 0.04, 10), None),
	(0.15, ("aim", (0.12, -0.42, 1.15), (-0.34, 0.5, 1.4), (-1, -0.25, 0)), None),
	(0.2, ("aim", (0.12, -0.42, 1.15), (-0.26, 0.5, 1.4), (-1, -0.2, 0)), None),
	(0.32, ("aim", (0.11, -0.41, 1.14), (-0.29, 0.52, 1.4), (-1, -0.2, 0.05)), None),
	(0.36, ("aim", (0.11, -0.48, 1.14), (-0.29, 0.44, 1.4), (-1, -0.2, 0.05)), None),
	(0.39, ("aim", (0.11, -0.34, 1.14), (-0.29, 0.58, 1.4), (-1, -0.2, 0.05)), None),
	(0.45, ("aim", (0.11, -0.47, 1.15), (-0.29, 0.45, 1.4), (-1, -0.2, 0.05)), None),
	(0.52, ("aim", (0.11, -0.4, 1.15), (-0.29, 0.52, 1.4), (-1, -0.2, 0.05)), None),
	(0.55, ("aim", (0.11, -0.5, 1.15), (-0.29, 0.42, 1.4), (-1, -0.2, 0.05)), None),
	(0.572, ("split", (0.11, -0.45, 1.15), 0.5, 0.0), None),
	(0.59, ("split", (0.105, -0.43, 1.155), 0.94, 0.07), None),
	(0.603, ("split", (0.1, -0.42, 1.16), 1.0, 0.42), None),
	(0.616, ("split", (0.09, -0.4, 1.18), 1.0, 0.84), None),
	(0.63, ("aim", (0.08, -0.38, 1.2), (-0.46, -0.66, 1.4), "auto"), None),
	(0.7, ("aim", (0.085, -0.39, 1.2), (-0.42, -0.72, 1.41), "auto"), None),
	(0.85, ("aim", (0.1, -0.42, 1.2), (-0.33, -0.82, 1.42), "auto"), None),
	(0.92, ("blend", (0.3, -0.58, 1.3)), None),
	(0.97, ("near", 0.0, 0.02, 3), None),
])
# The inspect's toss (handle space; the blade along -Z, which is up on screen
# while the face is turned to you): up along the blade, one end-over-end turn
# about the flat's normal (X) in the screen's plane, caught at 0.53.
INSPECT_TOSS = [
	(0.0, (0, 0, 0), (0, 0, 0)),
	(0.39, (0, 0, 0), (0, 0, 0)),
	(0.43, (0, 0, -0.3), (120, 0, 0)),
	(0.47, (0, 0, -0.42), (240, 0, 0)),
	(0.505, (0, 0, -0.22), (330, 0, 0)),
	(0.53, (0, 0, 0), (360, 0, 0)),
	(1.0, (0, 0, 0), (360, 0, 0)),
]
INSPECT_TOSS_PIVOT = (0, 0, -0.4)


def luau_v(v):
	return "Vector3.new(" + ", ".join(f"{x:.3f}".rstrip("0").rstrip(".") if abs(x) > 5e-4 else "0" for x in v) + ")"


def emit(name, length, hit, keys, check, extra=()):
	T1, T3, T4 = "\t" * 2, "\t" * 3, "\t" * 4
	if check:
		print(f"{name}: length {length}" + (f", hit {hit}" if hit is not None else ""))
	else:
		print(f"{T1}{name} = {{")
		for line in (f"length = {length},", 'pivot = "Grip",', "own = true,", "screen = true,", "smooth = true,"):
			print(T3 + line)
		if hit is not None:
			print(f"{T3}hit = {hit},")
		print(T3 + "keys = {")
	if keys[0][0] > 0:
		keys = [(0.0, ("rest",), None)] + keys
	keys = keys + [(1.0, ("rest",), None)]
	solved = []
	prev_r = None
	for t, spec, _style in keys:
		if spec[0] in ("blend", "split"):
			solved.append(None)
			continue
		g, r = solve(spec, prev_r)
		solved.append((g, r))
		prev_r = r
	for i, (t, spec, _style) in enumerate(keys):
		if spec[0] in ("blend", "split"):
			lo = max(j for j in range(i) if solved[j] is not None and keys[j][1][0] not in ("blend", "split"))
			hi = min(j for j in range(i + 1, len(keys)) if keys[j][1][0] not in ("blend", "split"))
		if spec[0] == "blend":
			a = (t - keys[lo][0]) / (keys[hi][0] - keys[lo][0])
			solved[i] = (at(*spec[1]), slerp(solved[lo][1], solved[hi][1], a))
		elif spec[0] == "split":
			# ("split", grip, roll, swing): between the keys either side, the
			# turn split in two: `roll` (0..1) of the roll about the blade's own
			# length and `swing` (0..1) of the blade's change of direction. So a
			# wrist can roll the blade first and tip it over after, as one
			# overlapped move, instead of doing both evenly (a slerp).
			_, grip, roll, swing = spec
			a_r, b_r = solved[lo][1], solved[hi][1]
			blade0 = unit(REST_TIP - REST_GRIP)
			over = rot_between(a_r @ blade0, b_r @ blade0)
			twist = a_r.T @ over.T @ b_r
			solved[i] = (at(*grip), slerp(np.eye(3), over, swing) @ a_r @ slerp(np.eye(3), twist, roll))
	prev_r = None
	out = []
	for (t, spec, _style), (grip, r) in zip(keys, solved):
		step = turn_between(prev_r, r) if prev_r is not None else 0
		if step > SLERP_LIMIT:
			raise SystemExit(f"{name} t={t}: blade turns {step:.0f} deg from the last key")
		prev_r = r
		pos = grip - REST_GRIP
		rot = angles_xyz(r)
		if check:
			tip = grip + (r @ unit(REST_TIP - REST_GRIP)) * BLADE_LEN
			hand, along, off = forearm_of(grip, r)
			gx, gy = screen(grip)
			tx, ty = screen(tip)
			end = hand + along * 0.5
			ax, ay = screen(end) if end[2] < -0.05 else (float("nan"), float("nan"))
			hx, hy = screen(hand)
			arm = math.degrees(math.atan2(ay - hy, ax - hx))
			print(f"  t={t:.3f} grip ({gx:+.2f},{gy:+.2f}) tip ({tx:+.2f},{ty:+.2f}) turn {step:4.0f}  arm {arm:5.0f}deg off-shoulder {off:3.0f} eye {eye_gap(hand, along):.2f}")
			continue
		if spec[0] == "rest" and t in (0, 1):
			out.append(f"{T4}key({t:g}, ZERO, ZERO),")
		else:
			out.append(f"{T4}key({t:g}, {luau_v(pos)}, {luau_v(rot)}),")
	if not check:
		print("\n".join(out))
		print(T3 + "},")
		for line in extra:
			print(T3 + line)
		print(T1 + "},")



VIEWMODEL = "src/shared/Config/Viewmodel.luau"
TRACK_NAMES = ("Slash1", "Slash2", "Slash3", "HeavyStab", "DrawMelee", "InspectMelee")


def write():
	"""Solve every track and put it in Config/Viewmodel in place of the old one
	(each two-tab `<Name> = {` line down to its closing two-tab `},`). Run
	stylua after."""
	import contextlib
	import io

	t2, t3 = "\t" * 2, "\t" * 3
	buf = io.StringIO()
	with contextlib.redirect_stdout(buf):
		emit_all(False)
	blocks, cur = {}, None
	for line in buf.getvalue().rstrip("\n").split("\n"):
		if line.startswith(t2) and not line.startswith(t3) and line.strip().endswith("= {"):
			cur = line.strip().split(" ")[0]
			blocks[cur] = []
		blocks[cur].append(line)
	lines = open(VIEWMODEL, encoding="utf-8").read().split("\n")
	for name in TRACK_NAMES:
		start = lines.index(t2 + name + " = {")
		end = next(i for i in range(start + 1, len(lines)) if lines[i] == t2 + "},")
		lines[start : end + 1] = blocks[name]
	open(VIEWMODEL, "w", encoding="utf-8", newline="\n").write("\n".join(lines))
	print("wrote", ", ".join(TRACK_NAMES), "into", VIEWMODEL, "(now run: stylua src)")


def main():
	if "--write" in sys.argv:
		write()
		return
	emit_all("--check" in sys.argv)


def emit_all(check):
	for name, (length, hit, keys) in ATTACKS.items():
		emit(name, length, hit, keys, check)
	toss = ["toss = {"]
	for t, pos, rot in DRAW_TOSS:
		toss.append(f"\tkey({t:g}, {luau_v(pos)}, {luau_v(rot)}),")
	toss.append("},")
	toss.append(f"tossPivot = {luau_v(DRAW_TOSS_PIVOT)},")
	emit("DrawMelee", DRAW[0], None, DRAW[1], check, toss)
	toss = ["toss = {"]
	for t, pos, rot in INSPECT_TOSS:
		toss.append(f"\tkey({t:g}, {luau_v(pos)}, {luau_v(rot)}),")
	toss.append("},")
	toss.append(f"tossPivot = {luau_v(INSPECT_TOSS_PIVOT)},")
	emit("InspectMelee", INSPECT[0], None, INSPECT[1], check, toss)


if __name__ == "__main__":
	main()
