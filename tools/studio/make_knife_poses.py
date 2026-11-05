"""Third-person knife clips (2026-11-05, lane F) as pose text for
pose_text_to_rbxm.py, plus contact sheets drawn with a forward-kinematics model
of a block R15 rig (no Studio needed):

    python -I tools/studio/make_knife_poses.py > knife.txt
    python -I tools/studio/pose_text_to_rbxm.py knife.txt
    python -I tools/studio/make_knife_poses.py --sheet out_dir   # PNG sheets + numbers

Clips (Action4, upper body only, so the legs keep running):
  GG_KnifeSlash1  forehand: the chest winds right, the arm cuts high right to
                  low left across the front, follows through, settles.
  GG_KnifeSlash2  backhand: wound across the body, cuts left to right.
  GG_KnifeSlash3  the finisher: knife raised high, chops down and forward.
  GG_KnifeHeavy   both hands: pull back and coil, hold, thrust, hold, recover.
Same lines and contact times as first person (Config/Viewmodel Slash1-3 /
HeavyStab: contact 0.15 s light, 0.19 s for the chop, 0.40 s heavy).

Style (LihFolk Combat Animation Craft; Locomotion and Melee Reference
Numbers): anticipation eased out of the ready pose, the strike linear (it
arrives at speed), contact, deceleration eased out, a follow-through past
the cut, and a settle; the chest leads the arm by a frame on the way in;
the head counter-turns to keep the eyes on the target; the free hand guards.

Joint values: { pitch, yaw, roll } degrees, joint Transforms in
CFrame.fromEulerAnglesYXZ order (the Make*Animations convention): yaw (+Y)
turns a joint left; a right arm at yaw -55 is out to the right, +45 across
the body; arm pitch + raises it forward; torso pitch + leans back.
"""

import math
import os
import struct
import sys
import zlib

import numpy as np

ACTION4 = "Action4"


def ready(breath=0.0):
	# A compact forward guard (round 2, reviewers: the old ready read as
	# splayed): knife hand forward at chest height, blade up and forward,
	# free hand up in front as a guard, chest bladed a little.
	return {
		"UpperTorso": (4 + breath * 1.5, -12, 0),
		"Head": (-breath, 12, 0),
		"RightUpperArm": (62 + breath * 2, 14, 0),
		"RightLowerArm": (72, 0, 0),
		"RightHand": (-24, 0, 0),
		"LeftUpperArm": (78 + breath * 2, -6, 0),
		"LeftLowerArm": (60, 0, 0),
		"LeftHand": (0, 0, 0),
	}


def pose(base=None, **joints):
	p = dict(base or ready())
	for k, v in joints.items():
		p[k] = v
	return p


R = ready()

# Slash1: forehand, high right -> low left.
S1_WIND = pose(
	UpperTorso=(4, -30, 0),
	Head=(0, 24, 0),
	RightUpperArm=(98, -64, -8),
	RightLowerArm=(42, 0, 0),
	RightHand=(0, -28, 0),
	LeftUpperArm=(70, -4, 0),
	LeftLowerArm=(70, 0, 0),
)
S1_CUT = pose(
	UpperTorso=(-4, 18, 0),
	Head=(0, -14, 0),
	RightUpperArm=(90, 26, 0),
	RightLowerArm=(8, 0, 0),
	RightHand=(-55, 45, 0),
	LeftUpperArm=(50, -30, 0),
	LeftLowerArm=(70, 0, 0),
)
S1_FOLLOW = pose(
	UpperTorso=(-8, 34, 0),
	Head=(0, -24, 0),
	RightUpperArm=(82, 42, 4),
	RightLowerArm=(10, 0, 0),
	RightHand=(-50, 55, 0),
	LeftUpperArm=(40, -32, 0),
	LeftLowerArm=(66, 0, 0),
)
S1_SETTLE = pose(UpperTorso=(3, -16, 0), RightUpperArm=(60, 9, 0))

# Slash2: backhand, from across the body out to the right.
S2_WIND = pose(
	UpperTorso=(4, 32, 0),
	Head=(0, -24, 0),
	RightUpperArm=(104, 58, 0),
	RightLowerArm=(84, 0, 0),
	RightHand=(0, 34, 0),
	LeftUpperArm=(46, -30, 0),
	LeftLowerArm=(72, 0, 0),
)
S2_CUT = pose(
	UpperTorso=(-4, -14, 0),
	Head=(0, 12, 0),
	RightUpperArm=(90, -24, 0),
	RightLowerArm=(14, 0, 0),
	RightHand=(-50, -45, 0),
	LeftUpperArm=(66, -14, 0),
	LeftLowerArm=(72, 0, 0),
)
S2_FOLLOW = pose(
	UpperTorso=(-6, -28, 0),
	Head=(0, 22, 0),
	RightUpperArm=(64, -40, -6),
	RightLowerArm=(18, 0, 0),
	RightHand=(-45, -50, 0),
	LeftUpperArm=(72, -4, 0),
	LeftLowerArm=(70, 0, 0),
)
S2_SETTLE = pose(UpperTorso=(5, -14, 0), RightUpperArm=(66, 10, 0))

# Slash3: the finisher, an overhead chop down and forward.
S3_WIND = pose(
	UpperTorso=(10, -10, 0),
	Head=(-8, 10, 0),
	RightUpperArm=(166, -12, 0),
	RightLowerArm=(68, 0, 0),
	RightHand=(45, 0, 0),
	LeftUpperArm=(78, -20, 0),
	LeftLowerArm=(60, 0, 0),
)
S3_CUT = pose(
	UpperTorso=(-16, 4, 0),
	Head=(12, -4, 0),
	RightUpperArm=(86, 2, 0),
	RightLowerArm=(8, 0, 0),
	RightHand=(-22, 0, 0),
	LeftUpperArm=(40, -26, 0),
	LeftLowerArm=(66, 0, 0),
)
S3_FOLLOW = pose(
	UpperTorso=(-22, 6, 0),
	Head=(16, -6, 0),
	RightUpperArm=(44, 6, 0),
	RightLowerArm=(18, 0, 0),
	RightHand=(-36, 0, 0),
	LeftUpperArm=(34, -28, 0),
	LeftLowerArm=(64, 0, 0),
)
S3_SETTLE = pose(UpperTorso=(2, -13, 0), RightUpperArm=(59, 12, 0))

# Heavy: both hands, pull back, hold the coil, thrust.
H_COIL = pose(
	UpperTorso=(6, -26, 0),
	Head=(-2, 22, 0),
	RightUpperArm=(36, -26, 0),
	RightLowerArm=(100, 0, 0),
	RightHand=(-62, 0, 0),
	LeftUpperArm=(52, 26, 0),
	LeftLowerArm=(96, 0, 0),
	LeftHand=(0, 0, 0),
)
H_COIL2 = pose(H_COIL, UpperTorso=(7, -28, 0), RightUpperArm=(34, -28, 0))
H_THRUST = pose(
	UpperTorso=(-12, 10, 0),
	Head=(10, -8, 0),
	RightUpperArm=(92, 8, 0),
	RightLowerArm=(4, 0, 0),
	RightHand=(-78, 0, 0),
	LeftUpperArm=(84, 30, 0),
	LeftLowerArm=(30, 0, 0),
	LeftHand=(0, 0, 0),
)
H_OVER = pose(H_THRUST, UpperTorso=(-16, 12, 0), RightUpperArm=(95, 9, 0))
H_SETTLE = pose(UpperTorso=(2, -15, 0), RightUpperArm=(60, 12, 0))

# (name, [(time, pose, easing of the segment that starts here)]); every
# key's arms are nudged clear of the torso afterwards (clear(), below).
CLIPS = [
	(
		"GG_KnifeSlash1",
		[
			(0.0, R, "Cubic/InOut"),
			(0.1, S1_WIND, "Linear/In"),
			(0.15, S1_CUT, "Cubic/Out"),
			(0.23, S1_FOLLOW, "Cubic/InOut"),
			(0.4, S1_SETTLE, "Cubic/InOut"),
			(0.5, R, None),
		],
	),
	(
		"GG_KnifeSlash2",
		[
			(0.0, R, "Cubic/InOut"),
			(0.1, S2_WIND, "Linear/In"),
			(0.15, S2_CUT, "Cubic/Out"),
			(0.23, S2_FOLLOW, "Cubic/InOut"),
			(0.4, S2_SETTLE, "Cubic/InOut"),
			(0.5, R, None),
		],
	),
	(
		"GG_KnifeSlash3",
		[
			(0.0, R, "Cubic/InOut"),
			(0.13, S3_WIND, "Linear/In"),
			(0.19, S3_CUT, "Cubic/Out"),
			(0.27, S3_FOLLOW, "Cubic/InOut"),
			(0.48, S3_SETTLE, "Cubic/InOut"),
			(0.58, R, None),
		],
	),
	(
		"GG_KnifeHeavy",
		[
			(0.0, R, "Cubic/InOut"),
			(0.26, H_COIL, "Linear/In"),
			(0.34, H_COIL2, "Linear/In"),
			(0.4, H_THRUST, "Cubic/Out"),
			(0.45, H_OVER, "Cubic/InOut"),
			(0.56, H_THRUST, "Cubic/InOut"),
			(0.8, H_SETTLE, "Cubic/InOut"),
			(0.9, R, None),
		],
	),
]

def fmt(v):
	return ",".join(f"{x:g}" for x in v)


def line(name, keys):
	length = keys[-1][0]
	parts = []
	for t, p, style in keys:
		joints = []
		for j, v in p.items():
			entry = f"{j}:{fmt(v)}"
			if style:
				entry += "@" + style
			joints.append(entry)
		parts.append(f"{t:g}>" + ";".join(joints))
	return f"{name}|{ACTION4}|0|{length:g}|" + "|".join(parts)


# --- FK model of a block R15 rig (Roblox's default R15 proportions) ----------
# joint: (parent, attachment in parent, attachment in part)
RIG = {
	"UpperTorso": ("LowerTorso", (0, 0.2, 0), (0, -0.78, 0)),
	"Head": ("UpperTorso", (0, 0.8, 0), (0, -0.5, 0)),
	"RightUpperArm": ("UpperTorso", (1.0, 0.56, 0), (-0.5, 0.42, 0)),
	"RightLowerArm": ("RightUpperArm", (0, -0.33, 0), (0, 0.19, 0)),
	"RightHand": ("RightLowerArm", (0, -0.5, 0), (0, 0.12, 0)),
	"LeftUpperArm": ("UpperTorso", (-1.0, 0.56, 0), (0.5, 0.42, 0)),
	"LeftLowerArm": ("LeftUpperArm", (0, -0.33, 0), (0, 0.19, 0)),
	"LeftHand": ("LeftLowerArm", (0, -0.5, 0), (0, 0.12, 0)),
}
SIZE = {
	"LowerTorso": (2, 0.4, 1),
	"UpperTorso": (2, 1.6, 1),
	"Head": (1.2, 1.2, 1.2),
	"RightUpperArm": (1, 1.17, 1),
	"RightLowerArm": (1, 1.05, 1),
	"RightHand": (1, 0.3, 1),
	"LeftUpperArm": (1, 1.17, 1),
	"LeftLowerArm": (1, 1.05, 1),
	"LeftHand": (1, 0.3, 1),
}
# Knife in the right hand (forward grip, blade forward from the fist, in the
# hand's space: GG_KnifeReady holds it blade forward).
KNIFE = ((0, -0.15, 0), (0, -0.15, -1.1))


def yxz(p, y, r):
	x, yy, z = map(math.radians, (p, y, r))
	rx = np.array([[1, 0, 0], [0, math.cos(x), -math.sin(x)], [0, math.sin(x), math.cos(x)]])
	ry = np.array([[math.cos(yy), 0, math.sin(yy)], [0, 1, 0], [-math.sin(yy), 0, math.cos(yy)]])
	rz = np.array([[math.cos(z), -math.sin(z), 0], [math.sin(z), math.cos(z), 0], [0, 0, 1]])
	return ry @ rx @ rz


def mat(r=np.eye(3), p=(0, 0, 0)):
	m = np.eye(4)
	m[:3, :3] = r
	m[:3, 3] = p
	return m


def fk(p):
	world = {"LowerTorso": mat(p=(0, 2.2, 0))}
	for part, (parent, a_par, a_part) in RIG.items():
		t = p.get(part, (0, 0, 0))
		world[part] = world[parent] @ mat(p=a_par) @ mat(yxz(*t)) @ np.linalg.inv(mat(p=a_part))
	return world


def lerp_pose(a, b, u):
	return {k: tuple(a[k][i] + (b[k][i] - a[k][i]) * u for i in range(3)) for k in a}


def ease(style, u):
	if not style or style.startswith("Linear"):
		return u
	kind, d = style.split("/")
	if d == "Out":
		return 1 - (1 - u) ** 3
	if d == "In":
		return u**3
	return 4 * u**3 if u < 0.5 else 1 - (-2 * u + 2) ** 3 / 2


def sample(keys, t):
	for (t0, p0, st), (t1, p1, _) in zip(keys, keys[1:]):
		if t0 <= t <= t1:
			u = (t - t0) / (t1 - t0) if t1 > t0 else 1
			return lerp_pose(p0, p1, ease(st, u))
	return keys[-1][1]


def corners(m, size):
	sx, sy, sz = (s / 2 for s in size)
	pts = np.array([[x, y, z, 1] for x in (-sx, sx) for y in (-sy, sy) for z in (-sz, sz)])
	return (m @ pts.T).T[:, :3]


EDGES = [(0, 1), (2, 3), (4, 5), (6, 7), (0, 2), (1, 3), (4, 6), (5, 7), (0, 4), (1, 5), (2, 6), (3, 7)]


class Canvas:
	def __init__(self, w, h):
		self.img = np.full((h, w, 3), 245, np.uint8)
		self.w, self.h = w, h

	def line(self, a, b, col, thick=1):
		n = int(max(abs(b[0] - a[0]), abs(b[1] - a[1]), 1)) * 2
		for i in range(n + 1):
			x = a[0] + (b[0] - a[0]) * i / n
			y = a[1] + (b[1] - a[1]) * i / n
			xi, yi = int(round(x)), int(round(y))
			self.img[max(yi - thick // 2, 0) : yi + thick // 2 + 1, max(xi - thick // 2, 0) : xi + thick // 2 + 1] = col


def project(pt, view, ox, oy, scale):
	# view: yaw of the camera around the character (0 = front), slight pitch.
	r = yxz(-12, view, 0)
	q = r.T @ pt
	return (ox + q[0] * scale, oy - (q[1] - 2.5) * scale)


def write_png(path, rgb):
	h, w, _ = rgb.shape
	raw = b"".join(b"\x00" + rgb[y].tobytes() for y in range(h))

	def chunk(t, d):
		c = struct.pack(">I", len(d)) + t + d
		return c + struct.pack(">I", zlib.crc32(t + d) & 0xFFFFFFFF)

	png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 2, 0, 0, 0))
	open(path, "wb").write(png + chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b""))


def draw_pose(cv, p, view, ox, oy, scale, col, knife_col, thick=1):
	world = fk(p)
	for part, m in world.items():
		c = corners(m, SIZE[part])
		pts = [project(v, view, ox, oy, scale) for v in c]
		for a, b in EDGES:
			cv.line(pts[a], pts[b], col, thick)
	h = world["RightHand"]
	k0 = (h @ np.array([*KNIFE[0], 1]))[:3]
	k1 = (h @ np.array([*KNIFE[1], 1]))[:3]
	cv.line(project(k0, view, ox, oy, scale), project(k1, view, ox, oy, scale), knife_col, thick + 2)
	return k1


def sheets(out):
	os.makedirs(out, exist_ok=True)
	report = {}
	for name, keys in CLIPS:
		length = keys[-1][0]
		cell, cols = 220, len(keys)
		cv = Canvas(cell * cols, cell * 2 + 40)
		for row, view in enumerate((-35, -90)):  # three-quarter (front right), side
			for i, (t, p, _) in enumerate(keys):
				ox, oy = cell * i + cell / 2, 40 + cell * row + cell * 0.62
				# Tip trail of the whole clip, faint.
				prev = None
				for k in range(0, 61):
					tip = draw_tip(sample(keys, length * k / 60), view, ox, oy, 38)
					if prev:
						cv.line(prev, tip, (190, 150, 150))
					prev = tip
				draw_pose(cv, p, view, ox, oy, 38, (40, 40, 60), (200, 30, 30), 1)
		write_png(os.path.join(out, name + ".png"), cv.img)
		# Numbers: tip speed (studs/s) per 1/60 s, peak and when.
		speeds = []
		prev = None
		for k in range(0, int(length * 60) + 1):
			tip = tip_world(sample(keys, k / 60))
			if prev is not None:
				speeds.append((k / 60, float(np.linalg.norm(tip - prev)) * 60))
			prev = tip
		top = max(speeds, key=lambda s: s[1])
		report[name] = {"length": length, "peak_tip_speed": round(top[1], 1), "peak_at": round(top[0], 3)}
	return report


def tip_world(p):
	h = fk(p)["RightHand"]
	return (h @ np.array([*KNIFE[1], 1]))[:3]


def draw_tip(p, view, ox, oy, scale):
	return project(tip_world(p), view, ox, oy, scale)


# --- Overlap check (rubric gate: no limb deeper than 0.05 studs in the torso
# or head). Oriented boxes of the block rig, separating-axis depth; joint
# neighbours are skipped (they always touch at the joint).
PAIRS = [
	(a, b)
	for a in ("RightLowerArm", "RightHand", "LeftLowerArm", "LeftHand", "RightUpperArm", "LeftUpperArm")
	for b in ("UpperTorso", "Head", "LowerTorso")
	if not (a.endswith("UpperArm") and b == "UpperTorso")
] + [("RightHand", "LeftHand"), ("RightLowerArm", "LeftLowerArm")]


def obb_depth(ma, sa, mb, sb):
	"""Smallest overlap along the 15 SAT axes (<= 0: apart)."""
	ra, rb = ma[:3, :3], mb[:3, :3]
	ha, hb = np.array(sa) / 2, np.array(sb) / 2
	d = mb[:3, 3] - ma[:3, 3]
	axes = [ra[:, i] for i in range(3)] + [rb[:, i] for i in range(3)]
	axes += [np.cross(ra[:, i], rb[:, j]) for i in range(3) for j in range(3)]
	best = math.inf
	for ax in axes:
		n = np.linalg.norm(ax)
		if n < 1e-6:
			continue
		ax = ax / n
		pa = sum(ha[i] * abs(np.dot(ra[:, i], ax)) for i in range(3))
		pb = sum(hb[i] * abs(np.dot(rb[:, i], ax)) for i in range(3))
		best = min(best, pa + pb - abs(np.dot(d, ax)))
	return best


def overlaps():
	worst = {}
	for name, keys in CLIPS:
		length = keys[-1][0]
		top = (0.0, None, None)
		for k in range(int(length * 60) + 1):
			w = fk(sample(keys, k / 60))
			w["LowerTorso"] = w["LowerTorso"]
			for a, b in PAIRS:
				depth = obb_depth(w[a], SIZE[a], w[b], SIZE[b])
				if depth > top[0]:
					top = (depth, f"{a}/{b}", round(k / 60, 3))
		worst[name] = {"depth": round(top[0], 3), "pair": top[1], "at": top[2]}
	return worst


def arm_depth(p, side):
	w = fk(p)
	worst = 0.0
	for a, b in PAIRS:
		if a.startswith(side) or b.startswith(side):
			worst = max(worst, obb_depth(w[a], SIZE[a], w[b], SIZE[b]))
	return worst


KEEP = {("UpperTorso", 1), ("RightUpperArm", 1)}


def clear(p, limit=0.01):
	"""Moves the joints the least it takes to keep the limbs out of the torso
	and head while the blade tip and the guard hand stay where the key put
	them (the arc is what reads), coordinate descent over the arms and the
	chest twist."""
	p = dict(p)
	names = [
		("RightUpperArm", 0),
		("RightUpperArm", 1),
		("RightUpperArm", 2),
		("RightLowerArm", 0),
		("RightHand", 0),
		("RightHand", 1),
		("LeftUpperArm", 0),
		("LeftUpperArm", 1),
		("LeftLowerArm", 0),
		("UpperTorso", 1),
	]
	base = [p[j][i] for j, i in names]
	w0 = fk(p)
	tip0 = (w0["RightHand"] @ np.array([*KNIFE[1], 1]))[:3]
	hand0 = w0["LeftHand"][:3, 3]

	def build(v):
		q = dict(p)
		for (j, i), x in zip(names, v):
			t = list(q[j])
			t[i] = x
			q[j] = tuple(t)
		return q

	def cost(v):
		q = build(v)
		w = fk(q)
		d = 0.0
		for a, b in PAIRS:
			d = max(d, obb_depth(w[a], SIZE[a], w[b], SIZE[b]))
		tip = (w["RightHand"] @ np.array([*KNIFE[1], 1]))[:3]
		hand = w["LeftHand"][:3, 3]
		move = np.sum((tip - tip0) ** 2) / 0.15**2 + np.sum((hand - hand0) ** 2) / 0.4**2
		# The chest twist and the knife arm's swing (yaw) carry the read:
		# moving them costs more than raising the arm or opening the elbow.
		dev = sum(((x - b0) / (15 if (j, i) in KEEP else 45)) ** 2 for x, b0, (j, i) in zip(v, base, names))
		return max(0.0, d - limit) * 900 + move + dev

	v = list(base)
	best = cost(v)
	for step in (12, 6, 3):
		improved = True
		while improved:
			improved = False
			for k, (j, i) in enumerate(names):
				for dlt in (-step, step):
					u = list(v)
					u[k] += dlt
					if abs(u[k] - base[k]) > 60 or (j.endswith("LowerArm") and not 0 <= u[k] <= 135):
						continue
					# A real wrist and forearm: flexion within 80 deg; the hand's
					# yaw is the forearm's turn (pronation), within 85.
					if j == "RightHand" and abs(u[k]) > (80 if i == 0 else 85):
						continue
					c = cost(u)
					if c < best - 1e-9:
						best, v, improved = c, u, True
	return build(v)


def main():
	if len(sys.argv) > 1 and sys.argv[1] == "--overlap":
		for k, v in overlaps().items():
			print(k, v)
		return
	if len(sys.argv) > 2 and sys.argv[1] == "--sheet":
		for k, v in sheets(sys.argv[2]).items():
			print(k, v)
		return
	print("# Third-person knife clips (tools/studio/make_knife_poses.py)")
	for name, keys in CLIPS:
		print(line(name, keys))
	# The ready loop (was MakeCombatPoseAnimations' GG_KnifeReady), with the
	# same cleared arms the clips start and end on, and a slow breath.
	breath = [(0.0, READY_CLEARED, "Cubic/InOut"), (1.2, clear(ready(1)), "Cubic/InOut"), (2.4, READY_CLEARED, None)]
	print(line("GG_KnifeReady", breath).replace("|Action4|0|", "|Action|1|", 1))



# Clear every key once (the ready pose too, so GG_KnifeReady matches).
_cleared = {}


def _clear_cached(p):
	k = id(p)
	if k not in _cleared:
		_cleared[k] = clear(p)
	return _cleared[k]


def _segment_depth(p0, p1, st):
	worst = 0.0
	for k in range(1, 12):
		q = lerp_pose(p0, p1, ease(st, k / 12))
		w = fk(q)
		for a, b in PAIRS:
			worst = max(worst, obb_depth(w[a], SIZE[a], w[b], SIZE[b]))
	return worst


def _split(keys):
	"""An ease-in-out segment whose in-betweens cut into the body gets a
	cleared midpoint key (its easing split into In / Out halves, so the
	timing is unchanged)."""
	out = []
	for (t0, p0, st), (t1, p1, _) in zip(keys, keys[1:]):
		if st == "Cubic/InOut" and _segment_depth(p0, p1, st) > 0.05:
			mid = clear(lerp_pose(p0, p1, 0.5))
			out += [(t0, p0, "Cubic/In"), (round((t0 + t1) / 2, 4), mid, "Cubic/Out")]
		else:
			out.append((t0, p0, st))
	out.append(keys[-1])
	return out


CLIPS[:] = [(name, _split([(t, _clear_cached(p), st) for t, p, st in keys])) for name, keys in CLIPS]
READY_CLEARED = _clear_cached(R)


if __name__ == "__main__":
	main()
