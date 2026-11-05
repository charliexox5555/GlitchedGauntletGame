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
	# Same as MakeCombatPoseAnimations knifeReady(0) (GG_KnifeReady).
	return {
		"UpperTorso": (2 + breath * 1.5, -6, 0),
		"Head": (-breath, 6, 0),
		"RightUpperArm": (52 + breath * 2, 10, 0),
		"RightLowerArm": (46, 0, 0),
		"RightHand": (-12, 0, 0),
		"LeftUpperArm": (62 + breath * 2, -26, 0),
		"LeftLowerArm": (72, 0, 0),
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
	RightHand=(0, 14, 0),
	LeftUpperArm=(50, -30, 0),
	LeftLowerArm=(70, 0, 0),
)
S1_FOLLOW = pose(
	UpperTorso=(-8, 32, 0),
	Head=(0, -24, 0),
	RightUpperArm=(70, 64, 4),
	RightLowerArm=(26, 0, 0),
	RightHand=(-6, 18, 0),
	LeftUpperArm=(40, -32, 0),
	LeftLowerArm=(66, 0, 0),
)
S1_SETTLE = pose(UpperTorso=(1, -9, 0), RightUpperArm=(50, 6, 0))

# Slash2: backhand, from across the body out to the right.
S2_WIND = pose(
	UpperTorso=(4, 26, 0),
	Head=(0, -20, 0),
	RightUpperArm=(84, 50, 0),
	RightLowerArm=(78, 0, 0),
	RightHand=(0, 32, 0),
	LeftUpperArm=(46, -30, 0),
	LeftLowerArm=(72, 0, 0),
)
S2_CUT = pose(
	UpperTorso=(-4, -14, 0),
	Head=(0, 12, 0),
	RightUpperArm=(90, -24, 0),
	RightLowerArm=(14, 0, 0),
	RightHand=(0, -18, 0),
	LeftUpperArm=(66, -14, 0),
	LeftLowerArm=(72, 0, 0),
)
S2_FOLLOW = pose(
	UpperTorso=(-6, -28, 0),
	Head=(0, 22, 0),
	RightUpperArm=(76, -62, -8),
	RightLowerArm=(22, 0, 0),
	RightHand=(-6, -24, 0),
	LeftUpperArm=(72, -4, 0),
	LeftLowerArm=(70, 0, 0),
)
S2_SETTLE = pose(UpperTorso=(1, -3, 0), RightUpperArm=(53, 13, 0))

# Slash3: the finisher, an overhead chop down and forward.
S3_WIND = pose(
	UpperTorso=(10, -10, 0),
	Head=(-8, 10, 0),
	RightUpperArm=(166, -12, 0),
	RightLowerArm=(68, 0, 0),
	RightHand=(30, 0, 0),
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
S3_SETTLE = pose(UpperTorso=(-1, -6, 0), RightUpperArm=(49, 10, 0))

# Heavy: both hands, pull back, hold the coil, thrust.
H_COIL = pose(
	UpperTorso=(6, -26, 0),
	Head=(-2, 22, 0),
	RightUpperArm=(36, -26, 0),
	RightLowerArm=(100, 0, 0),
	RightHand=(12, 0, 0),
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
	RightHand=(-10, 0, 0),
	LeftUpperArm=(84, 30, 0),
	LeftLowerArm=(30, 0, 0),
	LeftHand=(0, 0, 0),
)
H_OVER = pose(H_THRUST, UpperTorso=(-16, 12, 0), RightUpperArm=(95, 9, 0))
H_SETTLE = pose(UpperTorso=(0, -8, 0), RightUpperArm=(50, 8, 0))

# (name, [(time, pose, easing of the segment that starts here)])
CLIPS = [
	(
		"GG_KnifeSlash1",
		[
			(0.0, R, "Cubic/InOut"),
			(0.09, S1_WIND, "Linear/In"),
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
			(0.09, S2_WIND, "Linear/In"),
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


def main():
	if len(sys.argv) > 2 and sys.argv[1] == "--sheet":
		for k, v in sheets(sys.argv[2]).items():
			print(k, v)
		return
	print("# Third-person knife clips (tools/studio/make_knife_poses.py)")
	for name, keys in CLIPS:
		print(line(name, keys))


if __name__ == "__main__":
	main()
