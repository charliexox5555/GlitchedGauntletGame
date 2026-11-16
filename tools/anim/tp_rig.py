"""Third-person animation rig for the match body (vault/01 Design/Third Person
Overhaul.md §5): a forward / inverse kinematics model of the standard R15
block body, used by tp_clips.py to key clips the way an animator does, by
placing the GUN, the hips and the feet, and letting the arms and legs follow.

    gun      where the gun's handle sits and points; the right hand is solved
             onto its grip, the left hand onto a point on the gun (its
             LeftGrip), slid back along the barrel when the arm can't reach
    hips     the LowerTorso: offset and lean
    chest    the UpperTorso turn; the head keeps looking where you say
    feet     where each sole is planted; knees follow a pole direction

Everything is in ROOT SPACE: the HumanoidRootPart's frame, origin at its
centre, +X the character's right, +Y up, -Z forward. The floor is at
y = -FLOOR (the root sits 3 studs above it).

Joint numbers are the match body's (shared/MatchBody, arms 1 stud wide, read
in Studio 2026-11-12). A joint's pose is its Motor6D-style Transform:
    child = parent * C0 * Transform * C1^-1
written out as { pitch, yaw, roll } degrees in CFrame.fromEulerAnglesYXZ
order (plus an offset for the hips), the pose text that
tools/studio/pose_text_to_rbxm.py turns into KeyframeSequence files.
"""

import math

import numpy as np

FLOOR = 3.0

# child: (parent, C0 = the joint in the parent's frame, C1 = in the child's frame)
JOINTS = {
	"LowerTorso": ("HumanoidRootPart", (0, -1, 0), (0, -0.2, 0)),
	"UpperTorso": ("LowerTorso", (0, 0.2, 0), (0, -0.8, 0)),
	"Head": ("UpperTorso", (0, 0.8, 0), (0, -0.586, 0)),
	"RightUpperArm": ("UpperTorso", (1, 0.563, 0), (-0.5, 0.3943, 0)),
	"RightLowerArm": ("RightUpperArm", (0, -0.3341, 0), (0, 0.2587, 0)),
	"RightHand": ("RightLowerArm", (0, -0.5009, 0), (0, 0.125, 0)),
	"LeftUpperArm": ("UpperTorso", (-1, 0.563, 0), (0.5, 0.3943, 0)),
	"LeftLowerArm": ("LeftUpperArm", (0, -0.3341, 0), (0, 0.2587, 0)),
	"LeftHand": ("LeftLowerArm", (0, -0.5009, 0), (0, 0.125, 0)),
	"RightUpperLeg": ("LowerTorso", (0.5, -0.2, 0), (0, 0.4208, 0)),
	"RightLowerLeg": ("RightUpperLeg", (0, -0.401, 0), (0, 0.379, 0)),
	"RightFoot": ("RightLowerLeg", (0, -0.5472, 0), (0, 0.1019, 0)),
	"LeftUpperLeg": ("LowerTorso", (-0.5, -0.2, 0), (0, 0.4208, 0)),
	"LeftLowerLeg": ("LeftUpperLeg", (0, -0.401, 0), (0, 0.379, 0)),
	"LeftFoot": ("LeftLowerLeg", (0, -0.5472, 0), (0, 0.1019, 0)),
}
ORDER = list(JOINTS)
UPPER = ["UpperTorso", "Head", "RightUpperArm", "RightLowerArm", "RightHand", "LeftUpperArm", "LeftLowerArm", "LeftHand"]
ARMS = UPPER[2:]
LOWER = ["LowerTorso", "RightUpperLeg", "RightLowerLeg", "RightFoot", "LeftUpperLeg", "LeftLowerLeg", "LeftFoot"]
ALL = ["LowerTorso"] + UPPER + LOWER[1:]

# The gun in the right hand (WeaponService WorldModel GRIP_C0): the handle's
# forward runs out of the hand's underside, its top faces the hand's front.
GRIP_GUN = None  # filled below
# The knife (Config/Animations KNIFE_WORLD_GRIP): blade forward out of the fist.
GRIP_KNIFE = None

# The visible forearm block ends this far past the wrist joint (the hand part
# is hidden inside it); the shin block ends this far past the knee.
WRIST_TO_TIP = 0.275
KNEE_TO_SOLE = 0.379 + 0.5472 + 0.1019 + 0.15
HALF = 0.5  # half a limb's width


def rx(deg):
	a = math.radians(deg)
	c, s = math.cos(a), math.sin(a)
	return np.array([[1, 0, 0], [0, c, -s], [0, s, c]])


def ry(deg):
	a = math.radians(deg)
	c, s = math.cos(a), math.sin(a)
	return np.array([[c, 0, s], [0, 1, 0], [-s, 0, c]])


def rz(deg):
	a = math.radians(deg)
	c, s = math.cos(a), math.sin(a)
	return np.array([[c, -s, 0], [s, c, 0], [0, 0, 1]])


def euler(p=0.0, y=0.0, r=0.0):
	"""CFrame.fromEulerAnglesYXZ(pitch, yaw, roll), degrees."""
	return ry(y) @ rx(p) @ rz(r)


def to_euler(m):
	p = math.degrees(math.asin(max(-1.0, min(1.0, -m[1][2]))))
	if abs(m[1][2]) > 0.99999:
		return (p, math.degrees(math.atan2(-m[2][0], m[0][0])), 0.0)
	return (p, math.degrees(math.atan2(m[0][2], m[2][2])), math.degrees(math.atan2(m[1][0], m[1][1])))


def bladed(lean, turn, tilt=0.0):
	"""A chest turned `turn` degrees (negative = to the right, the left
	shoulder forward) that still leans `lean` degrees about the line you aim
	along, not about its own turned axis: lean back (+) / forward (-), `tilt`
	to the side."""
	return rx(lean) @ rz(tilt) @ ry(turn)


def cf(pos=(0, 0, 0), rot=None):
	m = np.eye(4)
	m[:3, 3] = pos
	if rot is not None:
		m[:3, :3] = rot
	return m


def v3(*a):
	return np.array(a if len(a) == 3 else a[0], dtype=float)


def unit(v):
	n = np.linalg.norm(v)
	return v / n if n > 1e-9 else v


def axis_angle(axis, rad):
	x, y, z = unit(axis)
	c, s = math.cos(rad), math.sin(rad)
	t = 1 - c
	return np.array(
		[
			[t * x * x + c, t * x * y - s * z, t * x * z + s * y],
			[t * x * y + s * z, t * y * y + c, t * y * z - s * x],
			[t * x * z - s * y, t * y * z + s * x, t * z * z + c],
		]
	)


def rotation_between(a, b):
	a, b = unit(a), unit(b)
	c = float(np.dot(a, b))
	if c > 0.999999:
		return np.eye(3)
	if c < -0.999999:
		side = np.cross(a, v3(1, 0, 0))
		if np.linalg.norm(side) < 1e-6:
			side = np.cross(a, v3(0, 0, 1))
		return axis_angle(side, math.pi)
	return axis_angle(np.cross(a, b), math.acos(c))


# (Config/Animations GUN_WORLD_GRIP: the gun rides on the FRONT of the fist,
# half a stud out from the hand's centre, so in a level hold the fist is
# under the gun, round the pistol grip, and the whole gun shows above it.
# Through the hand's centre, as it was, the 1-stud block swallowed it.)
GRIP_SIDEARM = cf((0, -0.15, -0.5), rx(-90))
GRIP_KNIFE = cf((0, -0.15, -0.05))
# Long guns (2026-11-12, "rigid fist" pass): the visible fist is rigid on the
# forearm (shared/MatchBody: no wrist bend, no forearm twist), so the gun must
# sit on the fist at one fixed angle and the arm must be posed to suit it.
# The angle is worked out from the rifle stance itself: the forearm runs from
# the grip out to the right, down and back (LONG_FOREARM, in the gun's frame:
# where the elbow can sit an upper arm's length from the shoulder in the hip
# and sights holds), the pistol grip goes down into the fist's end, and the
# fist's front faces the target. A sidearm keeps its barrel along the forearm
# (arms out). Config/Animations GUN_WORLD_GRIP_LONG / _SIDEARM must match:
# `python -I tools/anim/tp_rig.py grips` prints them.
LONG_FOREARM = (0.55, -0.75, 0.5)


def grip_from_forearm(forearm, handle):
	"""The gun in the hand's frame, for a hand whose +Y (toward the elbow)
	is `forearm` in the gun's frame, its front (-Z) toward the muzzle; the
	gun's handle sits at `handle` in the hand's frame."""
	y = unit(v3(forearm))
	z = v3(0, 0, 1) - y * y[2]
	z = unit(z)
	x = np.cross(y, z)
	hand_in_gun = np.column_stack([x, y, z])  # the hand's axes, in gun space
	gun_in_hand = hand_in_gun.T
	return cf(handle, gun_in_hand)


GRIP_LONG = grip_from_forearm(LONG_FOREARM, (0, -0.25, -0.05))
# The level hip hold's gun, from the right shoulder joint (root space, chest
# turned as in the rifle stance): `gun = {"shoulder": (pitch, yaw, roll)}`
# poses the gun as this hold swung about the shoulder.
HOLD_OFFSET = (-0.4542, 0.0862, -1.1054)
GRIP_GUN = GRIP_LONG


def fk(pose):
	"""World (root space) CFrame of every part for a pose { joint: 4x4 Transform }."""
	world = {"HumanoidRootPart": np.eye(4)}
	for name in ORDER:
		parent, c0, c1 = JOINTS[name]
		world[name] = world[parent] @ cf(c0) @ pose.get(name, np.eye(4)) @ cf(-v3(c1))
	return world


def two_bone(root_rot, pivot, target, e, b, pole, bend):
	"""A limb from `pivot` (world) to `target` (world): `e` = the middle joint
	in the upper part's pivot frame, `b` = middle joint to the end, straight
	down the lower part. The middle joint only pitches (`bend` +1 forward like
	an elbow, -1 back like a knee). Returns the upper part's rotation in its
	parent's frame (`root_rot`) and the middle joint's pitch in degrees."""
	to = root_rot.T @ (v3(target) - v3(pivot))
	d = np.linalg.norm(to)
	ex, ey = e[0], e[1]
	lo = math.sqrt(ex * ex + (abs(ey) - b) ** 2) + 1e-3
	hi = math.sqrt(ex * ex + (abs(ey) + b) ** 2) - 1e-4
	d = max(lo, min(hi, d))
	cos_t = (d * d - ex * ex - ey * ey - b * b) / (-2 * ey * b)
	theta = math.acos(max(-1.0, min(1.0, cos_t))) * bend
	p = v3(ex, ey - b * math.cos(theta), -b * math.sin(theta))
	w = unit(to) if np.linalg.norm(to) > 1e-9 else v3(0, -1, 0)
	r0 = rotation_between(p, w)
	# Swivel about the pivot-to-target line so the middle joint goes toward
	# the pole.
	mid = r0 @ v3(ex, ey, 0)
	perp = mid - w * float(np.dot(mid, w))
	want = root_rot.T @ unit(v3(pole))
	want = want - w * float(np.dot(want, w))
	if np.linalg.norm(perp) > 1e-6 and np.linalg.norm(want) > 1e-6:
		a, c = unit(perp), unit(want)
		ang = math.atan2(float(np.dot(np.cross(a, c), w)), float(np.dot(a, c)))
		r0 = axis_angle(w, ang) @ r0
	return r0, math.degrees(theta)


def twist_y(m):
	"""The part of rotation `m` that is a turn about its own Y axis, degrees."""
	return math.degrees(math.atan2(m[0][2] - m[2][0], m[0][0] + m[2][2]))


def solve(ctrl):
	"""Controls -> { joint: Transform }. See the module docstring; every
	control is optional (a missing one leaves that part at rest)."""
	pose = {}
	hips = ctrl.get("hips", {})
	pose["LowerTorso"] = cf(hips.get("pos", (0, 0, 0)), euler(*hips.get("rot", (0, 0, 0))))
	chest_ctrl = ctrl.get("chest", (0, 0, 0))
	# (pitch, yaw, roll), or a rotation matrix (see `bladed`).
	pose["UpperTorso"] = cf(rot=chest_ctrl if isinstance(chest_ctrl, np.ndarray) else euler(*chest_ctrl))
	world = fk(pose)
	chest = world["UpperTorso"][:3, :3]
	# The head: its own turn in root space ("head"), or with the chest ("head_local").
	if "head_local" in ctrl:
		pose["Head"] = cf(rot=euler(*ctrl["head_local"]))
	else:
		pose["Head"] = cf(rot=chest.T @ euler(*ctrl.get("head", (0, 0, 0))))

	gun = ctrl.get("gun")
	gun_cf = None
	if gun and "shoulder" in gun:
		# The hold turned about the REAL right shoulder (wherever the chest
		# and hips put it): pitch / yaw swing the gun and arm together, roll
		# cants the gun about its barrel, `reach` (+ out) slides it along.
		pitch, yaw, roll = gun["shoulder"]
		pivot = (world["UpperTorso"] @ cf(JOINTS["RightUpperArm"][1]))[:3, 3]
		turn = euler(pitch, yaw, 0)
		offset = v3(HOLD_OFFSET) + v3(0, 0, -gun.get("reach", 0.0))
		gun_cf = cf(pivot + turn @ offset, turn @ rz(roll))
	elif gun:
		gun_cf = cf(gun["pos"], euler(*gun.get("rot", (0, 0, 0))))
	for side, sx in (("Right", 1), ("Left", -1)):
		spec = ctrl.get(side.lower() + "_arm")
		upper, lower, hand = side + "UpperArm", side + "LowerArm", side + "Hand"
		shoulder = (world["UpperTorso"] @ cf(JOINTS[upper][1]))[:3, 3]
		e = v3(0.5 * sx, -(0.3943 + 0.3341), 0)
		b = 0.2587 + 0.5009
		pole = ctrl.get(side.lower() + "_pole", (sx * 0.6, -1, 0.4))
		hand_rot = None
		target = None
		tip = False
		if spec is not None and "fist" in spec:
			# A held melee weapon on the rigid fist: the fist's centre goes to
			# `fist`, the elbow toward the pole (a two-bone solve, so the arm
			# always reaches), the forearm runs from the fist to that elbow
			# with no twist and no wrist bend, and the fist rolls about it so
			# the blade points `blade` (squared up across the fist). The
			# weapon rides the hand on `grip`.
			target = v3(spec["fist"])
			b_len = 0.2587 + 0.5009 + 0.125
			r_upper, theta = two_bone(chest, shoulder, target, e, b_len, pole, 1)
			elbow = shoulder + chest @ r_upper @ e
			y = unit(elbow - target)
			# The knife's blade runs out of the fist's FRONT (the hand's -Z;
			# Config/Animations KNIFE_WORLD_GRIP, measured on the model).
			f = v3(spec["blade"]) - y * float(np.dot(v3(spec["blade"]), y))
			f = unit(f) if np.linalg.norm(f) > 1e-6 else unit(np.cross(y, v3(1, 0, 0)))
			z = -f
			rh = np.column_stack([np.cross(y, z), y, z])
			d = unit(elbow - shoulder)
			e_dir = unit(e)
			r0 = rotation_between(e_dir, d)

			def twist_at(deg, d=d, r0=r0, rh=rh):
				ru = axis_angle(d, math.radians(deg)) @ r0
				return abs(twist_y(ru.T @ rh)), ru

			# Two upper-arm rolls leave the forearm untwisted, half a turn
			# apart: the elbow bending the natural way, or bent backwards.
			# Taking whichever the scan met first let a swing hop between
			# them in one frame (2026-11-13, the owner's "the arm flicks":
			# KnifeSlash2's elbow went from bent back to bent forward in
			# 1/60 s). Only the natural bend is taken: the hinge's
			# sin(angle) = (ru^T rh)[2][1] stays >= 0, as two_bone bends it.
			# (A soft preference, growing with how far the elbow bends back,
			# so a nearly straight arm doesn't flicker between the two.)
			def back_bend(deg, d=d, r0=r0, rh=rh):
				ru = axis_angle(d, math.radians(deg)) @ r0
				return max(0.0, -float((ru.T @ rh)[2][1]))

			# `upper_ref` (optional, a 3x3 rotation): the upper arm's
			# orientation wanted, so a sequence keeps the answer it had a frame
			# ago instead of hopping to an equally good one half a turn away
			# (tp_clips knife_sequence slerps it between its keys' answers).
			# The skinned forearm doesn't show twist (Config/Avatar LIMB_SKIN
			# twist = false): the visible fist follows the upper arm's roll, so
			# a hop here is a visible flick, and a little twist is not.
			ref = spec.get("upper_ref")

			def score(deg, ref=ref):
				s = twist_at(deg)[0] + 60.0 * back_bend(deg)
				if ref is not None:
					ru = twist_at(deg)[1]
					c = (float(np.trace(ru.T @ ref)) - 1.0) / 2.0
					s = 0.15 * s + math.degrees(math.acos(max(-1.0, min(1.0, c))))
				return s

			best_deg = min(range(0, 360, 3), key=score)
			lo, hi = best_deg - 3.0, best_deg + 3.0
			for _ in range(24):
				m1, m2 = lo + (hi - lo) / 3, hi - (hi - lo) / 3
				if score(m1) < score(m2):
					hi = m2
				else:
					lo = m1
			_, ru = twist_at((lo + hi) / 2)
			ctrl["_roll"] = ((lo + hi) / 2) % 360.0
			pose[upper] = cf(rot=chest.T @ ru)
			pose[lower] = cf(rot=ru.T @ rh)
			pose[hand] = np.eye(4)
			hand_world = cf(elbow - rh @ v3(0, b_len, 0), rh)
			ctrl["_gun_cf"] = hand_world @ ctrl.get("grip", GRIP_KNIFE)
			continue
		if side == "Right" and gun_cf is not None and spec is None and ctrl.get("rigid", True):
			# The rigid fist: the hand IS the forearm's end (pose[hand] = I,
			# no forearm twist), so the gun fixes the forearm; the gun is slid
			# (keeping its turn) until the elbow is an upper arm's length from
			# the shoulder; the upper arm takes the roll that leaves the elbow
			# twist-free.
			grip = ctrl.get("grip", GRIP_GUN)
			hand_cf = gun_cf @ np.linalg.inv(grip)
			rh = hand_cf[:3, :3]
			k = rh @ v3(0, 0.5009 + 0.125 + 0.2587, 0)  # hand centre to elbow
			elbow = hand_cf[:3, 3] + k
			e_vec = v3(0.5 * sx, -(0.3943 + 0.3341), 0)
			reach = float(np.linalg.norm(e_vec))
			want = shoulder + unit(elbow - shoulder) * reach
			delta = want - elbow
			gun_cf = gun_cf.copy()
			gun_cf[:3, 3] += delta
			hand_cf = gun_cf @ np.linalg.inv(grip)
			elbow = want
			d = unit(elbow - shoulder)
			r0 = rotation_between(unit(e_vec), d)

			def twist_at(deg, d=d, r0=r0, rh=rh):
				ru = axis_angle(d, math.radians(deg)) @ r0
				return abs(twist_y(ru.T @ rh)), ru

			best_deg = min(range(0, 360, 3), key=lambda a: twist_at(a)[0])
			lo, hi = best_deg - 3.0, best_deg + 3.0
			for _ in range(24):  # ternary search on the bracket
				m1, m2 = lo + (hi - lo) / 3, hi - (hi - lo) / 3
				if twist_at(m1)[0] < twist_at(m2)[0]:
					hi = m2
				else:
					lo = m1
			residual, ru = twist_at((lo + hi) / 2)
			ctrl["_twist_residual"] = residual
			pose[upper] = cf(rot=chest.T @ ru)
			pose[lower] = cf(rot=ru.T @ rh)
			pose[hand] = np.eye(4)
			ctrl["_gun_cf"] = gun_cf
			continue
		if side == "Right" and gun_cf is not None and spec is None:
			grip = ctrl.get("grip", GRIP_GUN)
			hand_cf = gun_cf @ np.linalg.inv(grip)
			hand_rot = hand_cf[:3, :3]
			target = (hand_cf @ cf((0, 0.125, 0)))[:3, 3]
		elif spec is not None and "on_gun" in spec and gun_cf is not None:
			# A point in the gun's frame (its LeftGrip): the block's end goes
			# there, slid back toward the handle until the arm can reach.
			point = v3(spec["on_gun"])
			reach = (math.sqrt(0.25 + (0.7284 + b + WRIST_TO_TIP) ** 2)) * spec.get("reach", 0.96)
			for _ in range(40):
				target = (gun_cf @ cf(point))[:3, 3]
				if np.linalg.norm(target - shoulder) <= reach or point[2] >= spec.get("min_z", -0.25):
					break
				point = point + v3(0, 0, 0.05)
			tip = True
		elif spec is not None and "tip" in spec:
			target = v3(spec["tip"])
			tip = True
		elif spec is not None and "wrist" in spec:
			target = v3(spec["wrist"])
		if target is None:
			if spec is not None and "fk" in spec:
				u, l, h = spec["fk"]
				pose[upper] = cf(rot=euler(*u))
				pose[lower] = cf(rot=euler(*l))
				pose[hand] = cf(rot=euler(*h))
			continue
		length = b + (WRIST_TO_TIP if tip else 0)
		r_upper, theta = two_bone(chest, shoulder, target, e, length, pole, 1)
		twist = 0.0
		fore = chest @ r_upper @ rx(theta)
		if hand_rot is not None:
			rel = fore.T @ hand_rot
			twist = max(-70.0, min(70.0, twist_y(rel)))
			pose[hand] = cf(rot=ry(twist).T @ rel)
		elif spec is not None:
			twist = spec.get("twist", 0.0)
			pose[hand] = cf(rot=euler(*spec.get("hand", (0, 0, 0))))
		pose[upper] = cf(rot=r_upper)
		pose[lower] = cf(rot=rx(theta) @ ry(twist))

	hips_cf = world["LowerTorso"]
	hips_rot = hips_cf[:3, :3]
	for side, sx in (("Right", 1), ("Left", -1)):
		spec = ctrl.get(side.lower() + "_foot")
		if spec is None:
			continue
		upper, lower = side + "UpperLeg", side + "LowerLeg"
		hip = (hips_cf @ cf(JOINTS[upper][1]))[:3, 3]
		e = v3(0, -(0.4208 + 0.401), 0)
		pole = spec.get("pole", (sx * 0.12, 0, -1))
		pos = v3(spec["pos"]) + v3(0, -FLOOR, 0)
		yaw = spec.get("yaw", 0.0)
		for _ in range(3):
			r_upper, theta = two_bone(hips_rot, hip, pos, e, KNEE_TO_SOLE, pole, -1)
			shin = hips_rot @ r_upper @ rx(theta) @ ry(yaw)
			# The shin and foot are one block, so a tilted shin tilts the sole
			# and a corner dips under the floor. "clamp" lifts the foot until
			# the lowest corner is on the floor (airborne and striding feet;
			# a planted foot wants a near-upright shin instead).
			if not spec.get("clamp", False):
				break
			knee = hip + hips_rot @ r_upper @ e
			low = min(
				(knee + shin @ v3(cx, -KNEE_TO_SOLE, cz))[1] for cx in (-HALF, HALF) for cz in (-HALF, HALF)
			)
			if low >= -FLOOR - 1e-3:
				break
			pos = pos + v3(0, -FLOOR - low, 0)
		pose[upper] = cf(rot=r_upper)
		pose[lower] = cf(rot=rx(theta) @ ry(yaw))
		pose[side + "Foot"] = np.eye(4)
	return pose


# Easing -------------------------------------------------------------------------


def linear(t):
	return t


def ease_in(t):
	return t * t * t


def ease_out(t):
	return 1 - (1 - t) ** 3


def ease_in_out(t):
	return 4 * t * t * t if t < 0.5 else 1 - ((-2 * t + 2) ** 3) / 2


def out_back(t, s=1.70158):
	"""Overshoots the target, then settles."""
	t -= 1
	return 1 + t * t * ((s + 1) * t + s)


def sine(t):
	return 0.5 - 0.5 * math.cos(math.pi * t)


def lerp(a, b, t):
	if isinstance(a, (int, float)):
		return a + (b - a) * t
	return tuple(lerp(x, y, t) for x, y in zip(a, b))


def keys(track, t, loop=None):
	"""Value of a keyed track [(time, value, ease into this key)] at t.
	`loop` = the clip length: the track wraps (first key repeats at the end)."""
	if loop:
		t = t % loop
		track = list(track) + [(track[0][0] + loop, track[0][1], track[0][2] if len(track[0]) > 2 else linear)]
	if t <= track[0][0]:
		return track[0][1]
	for i in range(1, len(track)):
		t0, v0 = track[i - 1][0], track[i - 1][1]
		t1, v1 = track[i][0], track[i][1]
		if t <= t1:
			ease = track[i][2] if len(track[i]) > 2 else ease_in_out
			return lerp(v0, v1, ease((t - t0) / (t1 - t0)) if t1 > t0 else 1.0)
	return track[-1][1]


# Blending solved poses ----------------------------------------------------------


def rot_mix(a, b, t):
	"""Rotation a turned the fraction t of the way to rotation b (shortest way)."""
	d = a.T @ b
	c = max(-1.0, min(1.0, (np.trace(d) - 1) / 2))
	ang = math.acos(c)
	if ang < 1e-6:
		return a.copy()
	if math.pi - ang < 1e-4:
		# Half a turn: any axis from the symmetric part.
		w = np.sqrt(np.maximum((np.diag(d) + 1) / 2, 0))
		axis = unit(w if np.linalg.norm(w) > 1e-6 else v3(0, 1, 0))
	else:
		axis = v3(d[2][1] - d[1][2], d[0][2] - d[2][0], d[1][0] - d[0][1]) / (2 * math.sin(ang))
	return a @ axis_angle(axis, ang * t)


def mix(a, b, t):
	"""Pose a blended toward pose b, joint by joint."""
	out = {}
	for name in ORDER:
		ma, mb = a.get(name, np.eye(4)), b.get(name, np.eye(4))
		out[name] = cf(lerp(tuple(ma[:3, 3]), tuple(mb[:3, 3]), t), rot_mix(ma[:3, :3], mb[:3, :3], t))
	return out


def sequence(track):
	"""A pose track [(time, pose, ease into this key)] -> pose(t)."""

	def at(t):
		if t <= track[0][0]:
			return track[0][1]
		for i in range(1, len(track)):
			t0, t1 = track[i - 1][0], track[i][0]
			if t <= t1:
				ease = track[i][2] if len(track[i]) > 2 else ease_in_out
				return mix(track[i - 1][1], track[i][1], ease((t - t0) / (t1 - t0)) if t1 > t0 else 1.0)
		return track[-1][1]

	return at


# Clips ---------------------------------------------------------------------------


class Clip:
	"""`pose(t)` -> the solved pose at time t (seconds). `parts` = the joints
	the clip keys (the rest stay with whatever plays under it). `step`:
	seconds between baked keys (None: one held pose, keyed at 0 and 1)."""

	def __init__(self, name, priority, pose, parts, length=1.0, loop=True, step=1 / 30):
		self.name, self.priority, self.pose, self.parts = name, priority, pose, parts
		self.length, self.loop, self.step = length, loop, step

	def times(self):
		if self.step is None:
			return [0.0, self.length]
		n = max(1, round(self.length / self.step))
		return [self.length * i / n for i in range(n + 1)]

	def frames(self):
		return [(t, self.pose(0.0 if self.step is None else t)) for t in self.times()]

	def text(self):
		out = [self.name, self.priority, "1" if self.loop else "0", "%.4f" % self.length]
		for t, pose in self.frames():
			joints = []
			for name in self.parts:
				m = pose.get(name, np.eye(4))
				p, y, r = to_euler(m[:3, :3])
				entry = "%s:%.2f,%.2f,%.2f" % (name, p, y, r)
				if np.linalg.norm(m[:3, 3]) > 1e-5:
					entry += ",%.4f,%.4f,%.4f" % tuple(m[:3, 3])
				joints.append(entry)
			out.append("%.4f>%s" % (t, ";".join(joints)))
		return "|".join(out)


if __name__ == "__main__":
	import sys as _sys

	if len(_sys.argv) > 1 and _sys.argv[1] == "grips":
		for name, m in (("GUN_WORLD_GRIP_LONG", GRIP_LONG), ("GUN_WORLD_GRIP_SIDEARM", GRIP_SIDEARM)):
			r = m[:3, :3]
			vals = [m[0, 3], m[1, 3], m[2, 3]] + [r[i][j] for i in range(3) for j in range(3)]
			print("%s = CFrame.new(%s)," % (name, ", ".join("%.5f" % v for v in vals)))
