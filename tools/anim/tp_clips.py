"""The third-person clips (vault/01 Design/Third Person Overhaul.md §5), keyed
on the rig in tp_rig.py: the gun, hips and feet are placed, the arms and legs
follow.

    python -I tools/anim/tp_clips.py list
    python -I tools/anim/tp_clips.py sheet AimLevel AdsLevel Reload@0,0.2,0.4   # poses for the Studio preview
    python -I tools/anim/tp_clips.py export [Name ...]                         # art-source/animations/GG_<Name>.rbxm

`sheet` writes src/shared/TpPreview.luau (a temporary, Rojo-synced data
module: delete it when done); tools/studio/TpPreviewSheet.luau lays the poses
out in Studio (Edit) on the real block body with the real guns. `export`
writes the KeyframeSequence files; upload each with
tools/opencloud/upload_asset.py and put the ids in Config/Animations.

Style (owner 2026-11-12: "more oomph... not boring, not dull, not compact",
"you're never really holding the gun"; RIVALS / Valorant video study in the
note): the gun leads and both block ends sit ON it; elbows flare so the arms
read as a wide shape from the front; legs carry the energy (long strides, a
clear bounce, whole-body leans); every one-shot has an anticipation, a fast
move, an overshoot and a settle.

Layers (Simulation/Poses plays them by priority, per joint):
    Core      Idle                          whole body
    Movement  Run*, SprintRun, Jump, Fall   hips and legs
    Action    the holds                     chest, head, arms
    Action2   Sprint*, Crouch*              arms / hips and legs
    Action3   Slide                         whole body
    Action4   one-shots (Reload, Draw, Land, SlideIn / Out, knife swings)
"""

import math
import os
import sys
import time

import numpy as np

sys.path.insert(0, os.path.dirname(__file__))

from tp_rig import (  # noqa: E402
	ALL,
	FLOOR,
	GRIP_KNIFE,
	GRIP_SIDEARM,
	HALF,
	KNEE_TO_SOLE,
	LOWER,
	ORDER,
	WRIST_TO_TIP,
	UPPER,
	Clip,
	axis_angle,
	bladed,
	cf,
	ease_in,
	ease_in_out,
	ease_out,
	euler,
	fk,
	linear,
	mix,
	out_back,
	rot_mix,
	sequence,
	solve,
	to_euler,
	unit,
	v3,
)

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
PREVIEW = os.path.join(ROOT, "src", "shared", "TpPreview.luau")
TAU = 2 * math.pi

CLIPS = {}


def add(clip):
	CLIPS[clip.name] = clip
	return clip


def held(name, priority, controls, parts=UPPER):
	pose = solve(controls)
	return add(Clip(name, priority, lambda t: pose, parts, length=1.0, loop=True, step=None))


BREATH_LENGTH = 2.4  # seconds per breath
BREATH = (0.7, 0.25, 0.012)  # chest lean (deg), chest yaw sway (deg, twice per breath), gun rise (studs)


def breathing(name, priority, controls, parts=UPPER):
	"""A hold that keeps living (owner, memory animation-oomph: holds keep
	moving; 2026-11-20: every hold measured dead still): the chest breathes
	and sways a touch, the gun rides up and down with it on the fists, the
	head stays on the target. One breath per BREATH_LENGTH, keyed every 0.1 s."""
	lean, sway, rise = BREATH
	chest = controls["chest"]
	chest = chest if hasattr(chest, "shape") else euler(*chest)
	gun = controls.get("gun")  # (the knife has none: its fist rides instead)
	fist = controls.get("right_arm")
	# The free hand by its block end, riding the gun: its "on_gun" reach
	# solve flipped under these small moves (a 0.045-stud one-frame tick on
	# AimUp / AimDown / AdsDown). In play GripController's IK places it anyway.
	w = fk(solve(controls))
	wrist = (w["LeftHand"] @ np.array([0, 0.125, 0, 1.0]))[:3]
	tip0 = wrist + w["LeftLowerArm"][:3, :3] @ v3(0, -WRIST_TO_TIP, 0)

	def at(t):
		ph = TAU * t / BREATH_LENGTH
		# (The sway once ran at half the breath's rate, so the loop's end
		# didn't meet its start: a 0.004-stud step at the wrap in the engine.)
		b, s_ = math.sin(ph), math.sin(2 * ph + 0.6)
		dy = rise * math.sin(ph - 0.5)
		ctrl = dict(controls)
		ctrl["chest"] = euler(lean * b, sway * s_, 0) @ chest
		if gun is not None:
			ctrl["gun"] = {**gun, "pos": (gun["pos"][0], gun["pos"][1] + dy, gun["pos"][2])}
		elif fist is not None and "fist" in fist:
			x, y, z = fist["fist"]
			ctrl["right_arm"] = {**fist, "fist": (x, y + dy, z)}
		ctrl["left_arm"] = {"tip": (float(tip0[0]), float(tip0[1] + dy), float(tip0[2]))}
		return solve(ctrl)

	return add(Clip(name, priority, at, parts, length=BREATH_LENGTH, loop=True, step=0.1))


# Stance ----------------------------------------------------------------------------

# Standing: straight legs like a regular block character, feet a little wider
# than the hips, the left foot a touch ahead (a right-handed shooter).
STAND = {
	# (Hips at full height: the legs come out dead straight, so the knee
	# joints don't show a kink when standing.)
	"hips": {"pos": (0, 0, 0), "rot": (0, 0, 0)},
	"right_foot": {"pos": (0.6, 0, 0.1), "yaw": -8},
	"left_foot": {"pos": (-0.58, 0, -0.12), "yaw": 5},
}


def standing(ctrl):
	out = dict(STAND)
	out.update(ctrl)
	return out


# Holds -------------------------------------------------------------------------------

# The reference long gun's left grip (the Vandal's; the fist sits under the
# handguard, so the gun shows above it; GripController moves the hand onto each gun's own grip in play).
LONG_GRIP = (0, -0.55, -1.3)
# Where the gun turns about when you look up or down (root space): the
# right shoulder, which sits back because the chest is turned.
AIM_PIVOT = v3(0.6, 0.7, 0.4)
# The rifle stance (2026-11-12, second pass; owner: the first pass still
# looked unnatural, both arms bunched in front of the chest). A real one:
# the chest turned about 40 degrees to the right, so the left shoulder leads
# and the right one sits back; the stock runs back INTO the right shoulder;
# the right hand holds the grip close to the chest with its elbow down; the
# left arm reaches out along the gun to the handguard with its elbow under
# it. Turning the chest is what lets a block arm reach the handguard at all
# (square to the target it gets about 0.2 studs past the grip, and both
# hands end up in one lump). The head stays on the target.
CHEST_TURN = -26  # was -38: the skinned torso showed the turn as a crease (owner 2026-11-12)
# (Rigid-fist pass, 2026-11-12: a stud further out, so the right elbow opens
# to about 55-70 degrees; the long stock still reaches the shoulder.)
HIP_GUN = (0.5, 0.56, -1.0)
SIGHT_GUN = (0.36, 1.0, -1.0)
R_POLE = (0.7, -1, 0.7)  # right elbow: down, a little out and back
L_POLE = (-0.5, -1, -0.2)  # left elbow: down under the gun


def about_shoulder(pos, pitch=0.0, yaw=0.0, roll=0.0):
	"""The hold turned about the right shoulder: (gun pos, gun rot) for a gun
	at `pos` aimed level, swung `pitch` up and `yaw` left about the shoulder
	(the rigid fist keeps its arm shape, so the elbow stays open), and canted
	`roll` about its own barrel."""
	turn = euler(pitch, yaw, 0)
	new_pos = AIM_PIVOT + turn @ (v3(pos) - AIM_PIVOT)
	return tuple(new_pos), (pitch, yaw, roll)


def pitched(pos, pitch):
	"""`pos` (root space) swung `pitch` degrees up about the aim pivot."""
	return tuple(AIM_PIVOT + euler(pitch) @ (v3(pos) - AIM_PIVOT))


# Looking UP the whole upper body leans back and carries the gun (owner
# 2026-11-21, after RIVALS: "looking up ... looks really good" there; RIVALS
# pitches the waist with the aim, Rivals Reference → body): UP_BODY of the
# pitch is a lean at the waist that takes the shoulder and the gun with it,
# the rest turns the gun about that (moved) shoulder. Swung about the
# shoulder alone, the arms rose in front of the face and hid the head from
# the front (the skinned S15 body, 2026-11-21). Looking down is unchanged.
UP_BODY = 0.7
UP_HEAD = 0.85  # the head's share of the pitch looking up (head_share)
WAIST = v3(0, -0.6, 0)  # the waist joint, root space (tp_rig JOINTS)


def chest_pitch(pitch, down_share):
	"""The chest's share of the aim pitch: UP_BODY looking up, else `down_share`."""
	return pitch * (UP_BODY if pitch > 0 else down_share)


def pitched_body(pos, pitch):
	"""`pos` (root space) aimed `pitch` degrees: looking up, leaned back at the
	waist by the body's share and turned about the moved shoulder by the rest
	(UP_BODY); looking down, swung about the shoulder as before (`pitched`)."""
	if pitch <= 0:
		return pitched(pos, pitch)
	lean = euler(pitch * UP_BODY)
	turn = euler(pitch * (1 - UP_BODY))
	leaned = WAIST + lean @ (v3(pos) - WAIST)
	pivot = WAIST + lean @ (AIM_PIVOT - WAIST)
	return tuple(pivot + turn @ (leaned - pivot))


# The recoil poses (2026-11-15, vault Third Person Overhaul §23): each hold at
# the far end of a shot's kick: the gun pulled `back` studs along its barrel
# into the shoulder and a touch up, its muzzle risen `rise` degrees, the chest
# rocked back `rock` degrees and its gun-side shoulder turned back `twist`
# degrees; the head stays on the target. They are never shown whole: the game
# blends a share of them over the hold, by a spring each shot pushes
# (Util/BodyRecoil), so these are sized for the biggest gun at full weight.
LONG_KICK = (0.5, 12, 9, 8)
PISTOL_KICK = (0.45, 17, 5, 4)


def head_share(pitch, up):
	"""How much of the aim pitch the head takes. Looking down it takes nearly
	all of it (round 2, 2026-11-21: the IK prototype, whose head follows the
	aim, read better at -30: the face looks down at the target and meets the
	stock; the clips' head stayed near level). Looking up it keeps `up`, so
	the face still shows over the gun."""
	# (Up: at least UP_HEAD, so the face tips back along the stock above the
	# arms with the waist-led lean, UP_BODY.)
	return 0.95 if pitch < 0 else max(up, UP_HEAD)


def long_hold(pitch=0.0, ads=False, kick=None):
	back, rise, rock, twist = kick or (0, 0, 0, 0)
	if ads:
		# Sights up to the eye: the gun rises, the head tips onto the stock.
		gun, lean = SIGHT_GUN, -7
		head = (pitch * head_share(pitch, 0.75), 0, -9)
	else:
		gun, lean = HIP_GUN, -4
		head = (pitch * head_share(pitch, 0.7), 0, 0)
		# Looking down, the gun also goes out from the body (2026-11-15:
		# swung about the shoulder alone, the right forearm sat inside the
		# chest block on every frame of AimDown; tp_check "arms" 60 / 60).
		if pitch < 0:
			gun = (gun[0], gun[1], gun[2] - 0.3 * min(-pitch / 30.0, 1.0))
	# (Looking down the forearm is already close to the chest: pull back less.)
	if pitch < 0:
		back *= 1 - 0.65 * min(-pitch / 30.0, 1.0)
	gun = (gun[0], gun[1] + 0.12 * back, gun[2] + back)
	return standing(
		{
			"chest": bladed(lean + chest_pitch(pitch, 0.4) + rock, CHEST_TURN - (4 if ads else 0) - twist),
			"head": head,
			"gun": {"pos": pitched_body(gun, pitch), "rot": (pitch + rise, 0, 0)},
			"right_pole": R_POLE,
			"left_arm": {"on_gun": LONG_GRIP},
			"left_pole": L_POLE,
		}
	)


PISTOL_CUP = {"on_gun": (-0.62, -0.5, 0.12), "min_z": 0.0}


def pistol_hold(pitch=0.0, ads=False, kick=None):
	back, rise, rock, twist = kick or (0, 0, 0, 0)
	# A Weaver stance (2026-11-13, owner: the hold "looks weird"; his capture:
	# the right upper arm lay flat across the chest, the revolver at the
	# shoulder). The barrel runs along the rigid forearm, so a gun held on the
	# centre line pulled the right elbow in front of the sternum (measured: the
	# upper arm pointed 64% inward). Now the right arm reaches straight out
	# from its own shoulder (upper arm 96% forward), the gun at chin height
	# about 1.7 studs ahead of the chest, pointing straight ahead; the chest
	# turned 20 degrees so the left shoulder leads, and the support hand comes
	# up to the grip with its elbow down and out (on the rig its upper arm
	# hangs 74% down and the forearm rises to the gun). In play GripController's
	# IK places the support hand on each gun's own grip (Config/Animations
	# GRIP.sidearm), so the support arm there follows the IK.
	if ads:
		gun, lean = (0.3, 1.1, -2.4), -6  # the sights up under the right eye
		head = (pitch * head_share(pitch, 0.75), 0, -6)
	else:
		gun, lean = (0.4, 0.8, -2.3), -4  # the solve slides it back to the arm's reach
		head = (pitch * head_share(pitch, 0.7), 0, 0)
	gun = (gun[0], gun[1] + 0.25 * back, gun[2] + back)
	return standing(
		{
			"chest": bladed(lean + chest_pitch(pitch, 0.35) + rock, -20 - twist),
			"head": head,
			"gun": {"pos": pitched_body(gun, pitch), "rot": (pitch + rise, 0, 0)},
			"right_pole": (0.7, -1, 0.3),
			# Cupping the grip hand from the left and under.
			"grip": GRIP_SIDEARM,
			"left_arm": dict(PISTOL_CUP),
			"left_pole": (-0.7, -1, 0.1),
		}
	)


def kfist(fist, pole, blade):
	"""A knife key on the rigid fist (vault Third Person Overhaul §17): the
	fist's centre at `fist`, the elbow bulging toward `pole`, the blade
	pointing `blade` (squared up across the fist: a hammer grip, the handle
	across the palm, as the first-person knife). tp_rig solves the arm."""
	return {"right_arm": {"fist": fist, "blade": blade}, "right_pole": pole}


KNIFE_READY = kfist((0.7, 0.4, -1.55), (1, -0.6, 0.3), (-0.3, 1, -0.15))


def knife(arm=None, chest=(-8, 16, 0), left=(-0.5, 0.5, -1.5), head=(0, 0, 0), hips=None):
	ctrl = {
		"chest": chest,
		"head": head,
		"grip": GRIP_KNIFE,
		# Blade up and leaning in, on the right; the free hand out front.
		**(arm or KNIFE_READY),
		"left_arm": {"tip": left},
		"left_pole": (-1, -0.4, 0.2),
	}
	if hips:
		ctrl["hips"] = hips
	return standing(ctrl)


for _name, _pitch in (("Up", 45), ("Level", 0), ("Down", -30)):
	breathing("Aim" + _name, "Action", long_hold(_pitch))
	breathing("Ads" + _name, "Action", long_hold(_pitch, True))
	breathing("PistolAim" + _name, "Action", pistol_hold(_pitch))
	breathing("PistolAds" + _name, "Action", pistol_hold(_pitch, True))
	# ...and each one's recoil pose (Action2: over the hold, by weight).
	held("Kick" + _name, "Action2", long_hold(_pitch, kick=LONG_KICK))
	held("AdsKick" + _name, "Action2", long_hold(_pitch, True, kick=LONG_KICK))
	held("PistolKick" + _name, "Action2", pistol_hold(_pitch, kick=PISTOL_KICK))
	held("PistolAdsKick" + _name, "Action2", pistol_hold(_pitch, True, kick=PISTOL_KICK))
breathing("KnifeReady", "Action", knife())

# Idle --------------------------------------------------------------------------------

IDLE_LENGTH = 3.2


def idle(t):
	return solve(idle_ctrl(t))


def idle_ctrl(t):
	b = math.sin(TAU * t / IDLE_LENGTH)
	return (
		standing(
			{
				# Breathing: the hips ease down and up, the chest rocks, a slow
				# weight shift from foot to foot.
				# (2026-11-13: the foot is rigid on the shin, so a bent knee tilts
				# the sole. Each foot now sits a little ahead of its hip, under the
				# knee, so the shin stands within 4 degrees of upright: a shin corner
				# dug 0.16 studs into the floor with the right foot set back.)
				"hips": {"pos": (0.025 * math.sin(TAU * t / IDLE_LENGTH + 1.2), -0.05 - 0.012 * b, 0), "rot": (0, -10, 0.6 * b)},
				"left_foot": {"pos": (-0.5, 0, -0.33), "yaw": -4},
				"right_foot": {"pos": (0.59, 0, -0.21), "yaw": -14},
				"chest": (-2 + 1.4 * b, 0, 0),
				"head": (0, 0, 0),
				"right_arm": {"fk": ((2, 0, 5 + b), (10, 0, 0), (0, 0, 0))},
				"left_arm": {"fk": ((2, 0, -5 - b), (10, 0, 0), (0, 0, 0))},
			}
		)
	)


add(Clip("Idle", "Core", idle, ALL, length=IDLE_LENGTH, loop=True, step=0.1))

# Control keys ------------------------------------------------------------------------

def _mix_ctrl(a, b, t):
	"""Two control values blended: tuples / numbers linearly, rotation
	matrices (bladed chests) by the shortest turn, dicts key by key."""
	if isinstance(a, dict) and isinstance(b, dict):
		return {k: _mix_ctrl(a[k], b[k], t) if k in a and k in b else (b[k] if k in b else a[k]) for k in set(a) | set(b)}
	if hasattr(a, "shape") or hasattr(b, "shape"):
		ma = a if hasattr(a, "shape") else euler(*a)
		mb = b if hasattr(b, "shape") else euler(*b)
		return rot_mix(ma, mb, t)
	if isinstance(a, tuple) and isinstance(b, tuple):
		return tuple(x + (y - x) * t for x, y in zip(a, b))
	if isinstance(a, (int, float)) and isinstance(b, (int, float)) and not isinstance(a, bool):
		return a + (b - a) * t
	return b if t >= 0.5 else a


def solve_grounded(ctrl, iters=16):
	"""solve(), with each "clamp" foot lifted until its lowest corner is on
	the floor: the rig's own clamp stops after 3 tries, which leaves a tilted
	shin's corner under the floor when lifting the foot also tilts it."""
	ctrl = dict(ctrl)
	pose = solve(ctrl)
	for _ in range(iters):
		world = fk(pose)
		moved = False
		for side in ("right", "left"):
			spec = ctrl.get(side + "_foot")
			if not spec or not spec.get("clamp"):
				continue
			shin = world[side.capitalize() + "LowerLeg"]
			knee = shin @ np.array([0, 0.379, 0, 1.0])
			low = min((knee[:3] + shin[:3, :3] @ v3(cx, -KNEE_TO_SOLE, cz))[1] for cx in (-HALF, HALF) for cz in (-HALF, HALF)) + FLOOR
			if low < -5e-4:
				x, y, z = spec["pos"]
				ctrl[side + "_foot"] = {**spec, "pos": (x, y - low, z)}
				moved = True
		if not moved:
			break
		pose = solve(ctrl)
	return pose


def ctrl_sequence(track, end=None, solver=solve):
	"""Keys [(time, controls, ease into this key)], blended and solved per
	frame. `end` = (time, pose, ease): after the last control key, blend the
	solved pose into this one (the gun hold, whose targets ride the gun).
	`solver`: solve_grounded for clips whose feet must stay on the floor."""

	def at(t):
		if end is not None and t > track[-1][0]:
			t0, (t1, pose, ease) = track[-1][0], end
			u = ease((t - t0) / (t1 - t0)) if t1 > t0 else 1.0
			return mix(solver(track[-1][1]), pose, min(u, 1.0))
		if t <= track[0][0]:
			return solver(track[0][1])
		for i in range(1, len(track)):
			t0, t1 = track[i - 1][0], track[i][0]
			if t <= t1:
				ease = track[i][2] if len(track[i]) > 2 else ease_in_out
				u = ease((t - t0) / (t1 - t0)) if t1 > t0 else 1.0
				return solver(_mix_ctrl(track[i - 1][1], track[i][1], u))
		return solver(track[-1][1])

	return at


def _pchip_slopes(ts, ys):
	"""Monotone cubic (Fritsch-Carlson) slopes at each key, ends clamped to 0:
	velocity is continuous through every key, nothing overshoots between two
	keys, and a repeated key is a true hold."""
	n = len(ts)
	h = np.diff(ts)
	d = np.diff(ys, axis=0) / h[:, None]
	m = np.zeros_like(ys)
	for i in range(1, n - 1):
		for c in range(ys.shape[1]):
			a, b = d[i - 1, c], d[i, c]
			if a * b <= 0:
				m[i, c] = 0.0
			else:
				w1, w2 = 2 * h[i] + h[i - 1], h[i] + 2 * h[i - 1]
				m[i, c] = (w1 + w2) / (w1 / a + w2 / b)
	return m


def _rot_log(r):
	c = max(-1.0, min(1.0, (np.trace(r) - 1) / 2))
	ang = math.acos(c)
	if ang < 1e-9:
		return np.zeros(3)
	axis = np.array([r[2, 1] - r[1, 2], r[0, 2] - r[2, 0], r[1, 0] - r[0, 1]]) / (2 * math.sin(ang))
	return axis * ang


def _rot_exp(v):
	ang = float(np.linalg.norm(v))
	if ang < 1e-9:
		return np.eye(3)
	return axis_angle(v / ang, ang)


def _flatten(ctrl, base, path=()):
	"""(path, kind) and floats for every control value; matrices as a turn
	from the first key's matrix (`base`), so they spline as rotation vectors."""
	out = []
	if isinstance(ctrl, dict):
		for k in sorted(ctrl):
			out += _flatten(ctrl[k], base, path + (k,))
	elif hasattr(ctrl, "shape") and ctrl.shape == (3, 3):
		b = base.get(path, ctrl)
		out.append((path, "rot", list(_rot_log(b.T @ ctrl))))
	elif isinstance(ctrl, tuple) and all(isinstance(x, (int, float)) for x in ctrl):
		out.append((path, "tuple", [float(x) for x in ctrl]))
	elif isinstance(ctrl, (int, float)) and not isinstance(ctrl, bool):
		out.append((path, "num", [float(ctrl)]))
	else:
		out.append((path, "const", ctrl))
	return out


def _rebuild(items, base):
	ctrl = {}
	for path, kind, value in items:
		node = ctrl
		for k in path[:-1]:
			node = node.setdefault(k, {})
		if kind == "rot":
			node[path[-1]] = base[path] @ _rot_exp(np.array(value))
		elif kind == "tuple":
			node[path[-1]] = tuple(value)
		elif kind == "num":
			node[path[-1]] = value[0]
		else:
			node[path[-1]] = value
	return ctrl


def _norm_feet(ctrl):
	"""Foot specs with every field the rig reads (its defaults filled in), so
	keys written with and without a pole or a clamp spline as one shape."""
	out = dict(ctrl)
	for side, sx in (("right", 1), ("left", -1)):
		spec = out.get(side + "_foot")
		if spec is not None:
			out[side + "_foot"] = {"yaw": 0.0, "pole": (sx * 0.12, 0, -1), "clamp": False, **spec}
	return out


def grounded(ctrl):
	"""Both feet kept on or above the floor by solve_grounded (spline paths
	between a dive and a kneel swung a shin 0.33 under it, 2026-11-20)."""
	out = dict(ctrl)
	for side in ("right_foot", "left_foot"):
		if side in out:
			out[side] = {**out[side], "clamp": True}
	return out


def tip_of(world, side):
	"""The block end (forearm + hand, to the fingertips) of a solved pose:
	what an arm's {"tip": ...} target places."""
	hand = world[side + "Hand"]
	fore = world[side + "LowerArm"][:3, :3]
	wrist = (hand @ np.array([0, 0.125, 0, 1.0]))[:3]
	return tuple(float(x) for x in wrist + fore @ v3(0, -WRIST_TO_TIP, 0))


def spline_ctrl(track):
	"""The controls of a key track on monotone cubics (see spline_sequence),
	as a function of time; None when the keys don't share one shape."""
	track = [(key[0], _norm_feet(key[1])) + tuple(key[2:]) for key in track]
	base = {}

	def find_mats(c, path=()):
		if isinstance(c, dict):
			for k in c:
				find_mats(c[k], path + (k,))
		elif hasattr(c, "shape") and c.shape == (3, 3):
			base.setdefault(path, c)

	for key in track:
		find_mats(key[1])
	flat = [_flatten(key[1], base) for key in track]
	shape = [[(p, k, len(v) if k != "const" else 0) for p, k, v in f] for f in flat]
	if any(s != shape[0] for s in shape):
		return None
	ts = np.array([key[0] for key in track], dtype=float)
	channels = []
	for j, (path, kind, _) in enumerate(flat[0]):
		if kind == "const":
			channels.append(None)
			continue
		ys = np.array([f[j][2] for f in flat], dtype=float)
		channels.append((ys, _pchip_slopes(ts, ys)))

	def ctrl_at(t):
		t = min(max(t, ts[0]), ts[-1])
		i = int(np.searchsorted(ts, t, side="right")) - 1
		i = min(max(i, 0), len(ts) - 2)
		h = ts[i + 1] - ts[i]
		s = (t - ts[i]) / h if h > 0 else 1.0
		h00, h10, h01, h11 = 2 * s**3 - 3 * s**2 + 1, s**3 - 2 * s**2 + s, -2 * s**3 + 3 * s**2, s**3 - s**2
		items = []
		for j, (path, kind, value) in enumerate(flat[0]):
			ch = channels[j]
			if ch is None:
				items.append((path, kind, flat[i if s < 0.5 else i + 1][j][2]))
				continue
			ys, m = ch
			v = h00 * ys[i] + h10 * h * m[i] + h01 * ys[i + 1] + h11 * h * m[i + 1]
			items.append((path, kind, list(v)))
		return _rebuild(items, base)

	return ctrl_at


def spline_sequence(track, end=None, solver=solve):
	"""ctrl_sequence on splines (owner, memory animation-oomph: "PCHIP
	splines"). Keys [(time, controls[, ignored ease])]: every control value
	runs on a monotone cubic through its keys, so the velocity is continuous
	at every key (a pair of eased segments meets at two different speeds:
	measured 72 -> 31 studs/s in one 30 Hz key on Throw's release). Timing is
	set by the key times; a repeated key holds. `end` as in ctrl_sequence.
	(Controls whose shape changes between keys fall back to ctrl_sequence.)"""
	ctrl_at = spline_ctrl(track)
	if ctrl_at is None:
		return ctrl_sequence(track, end, solver)
	t_last = track[-1][0]

	def at(t):
		if end is not None and t > t_last:
			t0, (t1, pose, ease) = t_last, end
			u = ease((t - t0) / (t1 - t0)) if t1 > t0 else 1.0
			return mix(solver(ctrl_at(t_last)), pose, min(u, 1.0))
		return solver(ctrl_at(t))

	return at


def pose_spline(track, hits=()):
	"""tp_rig.sequence on splines: each joint's turn (a rotation vector from
	its first key) and offset run on monotone cubics through the solved key
	poses, so a move flows through a key instead of stopping on it
	(2026-11-20: the rifle reload stopped dead at 5 of its keys, the pistol
	reload at 4: the owner's "stiff posed keys"). Keys [(time, pose[, ease])],
	eases ignored. `hits`: key times that are impacts (a magazine slapped
	home): the move arrives and leaves at speed there instead of easing."""
	ts = np.array([key[0] for key in track], dtype=float)
	parts = [p for p in ORDER if any(p in key[1] for key in track)]
	base = {p: track[0][1].get(p, np.eye(4))[:3, :3] for p in parts}
	ys = {}
	for p in parts:
		rows = []
		for key in track:
			m_ = key[1].get(p, np.eye(4))
			rows.append(np.concatenate([m_[:3, 3], _rot_log(base[p].T @ m_[:3, :3])]))
		ys[p] = np.array(rows)
	slopes = {}
	for p in parts:
		m = _pchip_slopes(ts, ys[p])
		left, right = m.copy(), m.copy()
		d = np.diff(ys[p], axis=0) / np.diff(ts)[:, None]
		for i, t in enumerate(ts):
			if any(abs(t - h) < 1e-6 for h in hits) and 0 < i < len(ts) - 1:
				left[i], right[i] = 1.5 * d[i - 1], 1.5 * d[i]
		slopes[p] = (left, right)

	def at(t):
		t = min(max(t, ts[0]), ts[-1])
		i = min(max(int(np.searchsorted(ts, t, side="right")) - 1, 0), len(ts) - 2)
		h = ts[i + 1] - ts[i]
		u = (t - ts[i]) / h if h > 0 else 1.0
		h00, h10, h01, h11 = 2 * u**3 - 3 * u**2 + 1, u**3 - 2 * u**2 + u, -2 * u**3 + 3 * u**2, u**3 - u**2
		out = {}
		for p in parts:
			y, (left, right) = ys[p], slopes[p]
			v = h00 * y[i] + h10 * h * right[i] + h01 * y[i + 1] + h11 * h * left[i + 1]
			out[p] = cf(tuple(v[:3]), base[p] @ _rot_exp(v[3:]))
		return out

	return at


# Locomotion ------------------------------------------------------------------------

# Pass 4 (2026-11-13, lane A of "Handoff - Grades to 9-10"). Measured on the
# rig first (tools/anim/tp_check.py): the run's planted feet still slid 24% of
# the ground speed, the strafes 78% (their shins passed THROUGH each other,
# 0.01 studs apart: lock 65% hid only part of it), the backpedal 67%, and
# every shin corner dug 0.24 to 0.31 under the floor. The block leg has no
# ankle (Config/Avatar LIMB_SKIN tip = false: the foot is rigid on the
# shin), so a "locked" sole centre still rocks as the leg sweeps over it.
#
# How a gait works now (Gait below):
# - A planted foot stands on an EDGE of its block and rolls over the foot:
#   the heel-side edge (the edge facing away from the travel) from landing,
#   then the toe-side edge once that one is lower, the way a rocker sole rolls.
#   The edge it stands on is pinned to the ground (moves back at exactly the
#   ground speed), so nothing slides and nothing digs in.
# - The swing is a Hermite curve from lift-off to the next landing that
#   leaves and lands with the ground's speed, lifting the knee early.
# - Strafes run in LANES: the left foot a half stud in front, the right a
#   half stud behind (the shooter's bladed stance), so the feet pass each
#   other front and back like a cross-step and the shins never meet; the
#   hips lean into the move.
# - Walks (no flight: each foot down 60% of the cycle) carry the slow speeds
#   (aimed movement is 6 to 13 studs/s, Config/Weapons adsMoveMultiplier);
#   runs (a flight phase: each foot down about a third) the fast ones.
#   Simulation/Poses cross-fades them by speed and keeps them on the same
#   phase, so the right foot lands at phase 0 in every gait.
# LihFolk "R15 Run Cycle Key Poses" (contact, down, passing, up; pelvis turn
# within 8 degrees; rate = speed / clip ground speed), "Locomotion Systems"
# (gaits that cannot slide, phase-preserving gait swaps).
RUN_LENGTH = 0.38  # one full cycle (two steps); RunF / B / L / R share it (they blend)
SPRINT_LENGTH = 0.36  # SprintRun and its upper-body clips share this one
WALK_LENGTH = 0.36  # WalkF / B / L / R
RUN_SPEED = 16.0  # Config/Animations RUN_SPEED
SPRINT_SPEED = 22.0  # Config/Animations SPRINT_RUN_SPEED
WALK_SPEED = 10.0  # Config/Animations WALK_CLIP_SPEED
CROUCH_SPEED = 9.0  # Config/Animations CROUCH_WALK_SPEED

# The ground speed each ground clip is made for, (x, z) studs/s in root space
# (the way the body travels): tools/anim/tp_check.py measures the lock with it.
GROUND = {}

# A block sole's points (shin frame, from the sole's centre): edge middles
# and corners. The one a foot stands on is picked by the travel.
SOLE_POINTS = [(0.0, 0.5), (0.0, -0.5), (0.5, 0.0), (-0.5, 0.0)] + [(x, z) for x in (-0.5, 0.5) for z in (-0.5, 0.5)]


def _shin(pose, side):
	return fk(pose)[side + "LowerLeg"][:3, :3]


def _sole_offset(rot, point):
	"""Root-space offset from the sole's centre to a sole point (x, z)."""
	return rot @ v3(point[0], 0, point[1])


class Gait:
	"""A foot-locked cycle. `travel` = (x, z), the unit way the body moves in
	root space; `speed` studs/s; `length` s a cycle; `duty` the share of the
	cycle each foot is down; `hips(ph)` -> the hips control at cycle phase ph.
	`homes` = {side: (x, z)}, where each foot's stance is centred. The right
	foot lands at phase 0, the left at 0.5 (every gait, so they blend).
	`lift` how high the swing carries the sole; `kick` the share of the ground
	speed the foot leaves and lands with; `poles` = {side: knee direction}."""

	def __init__(self, travel, speed, length, duty, lift, hips, homes, poles, yaws=None, kick=0.9, samples=96, lock=1.0, offsets=None):
		self.length, self.duty, self.lift, self.kick = length, duty, lift, kick
		self.hips, self.homes, self.poles = hips, homes, poles
		self.yaws = yaws or {"right": -6, "left": 6}
		self.b = unit(v3(travel[0], 0, travel[1]))
		self.gv = -self.b * speed * lock  # a planted point's velocity in root space
		self.samples = samples
		self.offsets = offsets or {"right": 0.0, "left": 0.5}
		self.table = {side: self._foot(side) for side in ("right", "left")}

	def _ctrl(self, ph, side, pos, clamp):
		return {
			"hips": self.hips(ph % 1.0),
			side + "_foot": {"pos": tuple(pos), "yaw": self.yaws[side], "pole": self.poles[side], "clamp": clamp},
		}

	def _pinned(self, ph, side, point, want, guess):
		"""The sole centre target that puts sole `point` at `want` (floor coords)."""
		target = v3(want) - guess
		rot = None
		# A damped fixed point: the shin's turn depends on the target.
		for _ in range(40):
			rot = _shin(solve(self._ctrl(ph, side, target, False)), side.capitalize())
			err = v3(want) - (target + _sole_offset(rot, point))
			if float(np.linalg.norm(err)) < 5e-4:
				break
			target = target + 0.6 * err
		return target, rot

	def _stance(self, side, start):
		"""Sole-centre targets over the stance for a landing with the sole's
		centre at `start`. The foot rolls: whichever sole point is lowest is
		pinned where it touched and carried back at the ground speed; when
		another point gets lower (heel to toe, an edge to its corner), that one
		takes over where it is."""
		n = max(8, round(self.samples * self.duty))
		ts = self.duty * self.length
		o = self.offsets[side]
		big = side.capitalize()
		rot = _shin(solve(self._ctrl(o, side, start, True)), big)
		lowest = lambda r: min(SOLE_POINTS, key=lambda p: float(_sole_offset(r, p)[1]) + 1e-4 * (abs(p[0]) + abs(p[1])))
		point = lowest(rot)
		pin = v3(start) + _sole_offset(rot, point)
		pin[1] = 0.0
		pin_u = 0.0
		guess = _sole_offset(rot, point)
		out = []
		for i in range(n + 1):
			u = i / n
			ph = o + u * self.duty
			want = pin + self.gv * (u - pin_u) * ts
			target, rot = self._pinned(ph, side, point, want, guess)
			now = lowest(rot)
			if now != point and float(_sole_offset(rot, now)[1]) < float(_sole_offset(rot, point)[1]) - 1e-3:
				point = now
				pin = target + _sole_offset(rot, point)
				pin[1] = 0.0
				pin_u = u
				target, rot = self._pinned(ph, side, point, pin, _sole_offset(rot, point))
			guess = _sole_offset(rot, point)
			out.append((u, target))
		return out

	def _foot(self, side):
		home = v3(self.homes[side][0], 0, self.homes[side][1])
		ts = self.duty * self.length
		# Land ahead of home by half the stance travel, then centre the
		# stance's sole on home (two passes).
		start = home - self.gv * ts / 2
		start[1] = 0.0
		for _ in range(3):
			stance = self._stance(side, start)
			mean = np.mean([t for _, t in stance], axis=0)
			shift = home - mean
			shift[1] = 0.0
			start = start + shift
		stance = self._stance(side, start)
		return stance

	def foot(self, side, ph):
		"""(sole-centre target, planted) for a foot at cycle phase ph."""
		q = (ph - self.offsets[side]) % 1.0
		stance = self.table[side]
		if q <= self.duty:
			u = q / self.duty
			n = len(stance) - 1
			k = min(int(u * n), n - 1)
			f = u * n - k
			return stance[k][1] * (1 - f) + stance[k + 1][1] * f, True
		# The swing: from lift-off back to the next landing.
		u = (q - self.duty) / (1 - self.duty)
		a, b = stance[-1][1], stance[0][1]
		dt = 1.0 / (len(stance) - 1)
		va = (stance[-1][1] - stance[-2][1]) / dt  # per unit of stance
		vb = (stance[1][1] - stance[0][1]) / dt
		scale = (1 - self.duty) / self.duty * self.kick  # into swing units
		m0, m1 = va * scale, vb * scale
		m0[1] = m1[1] = 0.0
		h00 = 2 * u**3 - 3 * u**2 + 1
		h10 = u**3 - 2 * u**2 + u
		h01 = -2 * u**3 + 3 * u**2
		h11 = u**3 - u**2
		p = h00 * a + h10 * m0 + h01 * b + h11 * m1
		# The knee comes up early (the heel kicks up behind), then the foot
		# reaches out and comes down.
		p[1] = a[1] * (1 - u) + b[1] * u + self.lift * math.sin(math.pi * (u**0.72))
		return p, False

	def __call__(self, t):
		ph = (t / self.length) % 1.0
		ctrl = {"hips": self.hips(ph)}
		for side in ("right", "left"):
			pos, planted = self.foot(side, ph)
			ctrl[side + "_foot"] = {"pos": tuple(pos), "yaw": self.yaws[side], "pole": self.poles[side], "clamp": not planted}
		return solve(ctrl)


def gait_hips(travel, duty, base, bob, lean, twist=5.0, roll=3.0, side_lean=0.0, sway=0.05, surge=0.03, low_at=None, turn=0.0):
	"""The hips over a cycle: lowest a beat after each foot lands (`low_at`,
	the share of the stance; mid-stance by default), highest between steps;
	a small surge; a turn and a roll with the stride; a lean into the travel."""
	dx, dz = travel
	low = duty * (0.5 if low_at is None else low_at)

	def hips(ph):
		y = base - bob * (0.5 + 0.5 * math.cos(2 * TAU * (ph - low)))
		s = surge * math.sin(2 * TAU * (ph - low))
		yaw = twist * math.cos(TAU * ph) * (1 if dz <= 0 else -1) * (1 - abs(dx))
		return {
			"pos": (sway * math.sin(TAU * ph) + dx * s, y, dz * s),
			"rot": (lean, yaw + turn, roll * math.sin(TAU * ph) + side_lean),
		}

	return hips


FWD_HOMES = {"right": (0.52, 0.02), "left": (-0.52, -0.02)}
FWD_POLES = {"right": (0.15, 0, -1), "left": (-0.15, 0, -1)}


# Leg clips are keyed 60 times a second: the engine blends joint turns
# linearly between keys, and at 30 a quick 0.22 s strafe cycle has 7 keys, so
# the feet cut corners (measured in the engine: back-left run 0.07 studs under
# the floor, crouch-left 85% lock; replaying the 1/30 keys on the rig gives
# the same numbers, 1/60 keys give 0.00 and 98-99%).
KEY_STEP = 1 / 60


def ground_clip(name, priority, travel, speed, length, gait):
	GROUND[name] = (travel[0] * speed, travel[1] * speed)
	return add(Clip(name, priority, gait, LOWER, length=length, step=KEY_STEP))


def run_gait(travel, speed, length, duty, lift, bob, lean, base, **hip_args):
	"""A forward or backward gait: the feet pass each other a hip apart."""
	return Gait(travel, speed, length, duty, lift, gait_hips(travel, duty, base, bob, lean, **hip_args), FWD_HOMES, FWD_POLES)


# Every direction from one recipe (dir_gait): forward or back settings at 0
# and 180 degrees, the side shuffle's at 90, interpolated between, so the
# diagonals (45 / 135) are real clips with their own foot paths. Blending a
# forward clip with a strafe clip measured 53% lock in the engine: two foot
# paths averaged are on neither. Simulation/Poses picks the two clips either
# side of the move direction.
#
# Sideways it is a side shuffle, not a cross-step: crossing feet on the block
# body put the shins through each other (measured 0.01 studs apart), and
# players read a cross-step strafe as clumsy and slow to change direction.
# The lead foot lands, the trail foot closes to it `close` of a cycle later
# (never past it), then both push off into a low hop; the feet run in lanes
# (one a little ahead) so they never meet.
#
# The strafes take quicker steps than the forward run (a 0.22 s cycle, so
# each foot sweeps 1.6 studs, not 2.2: the long sweep needed a wide, squat
# straddle). Simulation/Poses plays every leg clip on one shared phase and
# cycle rate (speed over the blended stride), so clips of different lengths
# still blend in step.
RUN_FAMILY = {
	"speed": RUN_SPEED,
	"f": {"length": RUN_LENGTH, "duty": 0.34, "lift": 0.8, "bob": 0.1, "lean": -8, "base": -0.12, "twist": 5, "roll": 3},
	"b": {"length": RUN_LENGTH, "duty": 0.36, "lift": 0.55, "bob": 0.08, "lean": 5, "base": -0.12, "twist": 3, "roll": 3},
	# (Engine review: the first shuffle, 0.36 duty with a long hop, read as a
	# crouched hop from the front. More ground contact, a lower lift and the
	# hips up: knees bend 60 degrees on average, the forward run's 92.)
	"s": {"length": 0.22, "duty": 0.46, "close": 0.12, "lift": 0.24, "bob": 0.05, "lean": -4, "base": 0.0, "width": 0.66, "lane": 0.4, "side_lean": 6},
}
WALK_FAMILY = {
	"speed": WALK_SPEED,
	"f": {"length": WALK_LENGTH, "duty": 0.58, "lift": 0.3, "bob": 0.05, "lean": -4, "base": -0.08, "twist": 5, "roll": 3},
	"b": {"length": WALK_LENGTH, "duty": 0.6, "lift": 0.28, "bob": 0.04, "lean": 3, "base": -0.08, "twist": 3, "roll": 3},
	"s": {"length": 0.3, "duty": 0.6, "close": 0.15, "lift": 0.3, "bob": 0.05, "lean": -4, "base": -0.06, "width": 0.62, "lane": 0.4, "side_lean": 3},
}
SIDE_POLES = {"right": (0.3, 0, -1), "left": (-0.3, 0, -1)}
DIRECTIONS = {"F": 0, "FR": 45, "R": 90, "BR": 135, "B": 180, "BL": -135, "L": -90, "FL": -45}


def _lerp(a, b, t):
	if isinstance(a, tuple):
		return tuple(x + (y - x) * t for x, y in zip(a, b))
	return a + (b - a) * t


def dir_travel(angle):
	a = math.radians(angle)
	return (round(math.sin(a), 6), round(-math.cos(a), 6))


def dir_gait(angle, family, homes_f=None, poles_f=None, poles_s=None, yaw_f=6):
	"""The gait for moving `angle` degrees from straight ahead (90 = right),
	from a family's forward ("f"), back ("b") and side ("s") settings."""
	dx, dz = dir_travel(angle)
	t = abs(dx)  # 0 straight ahead or back, 1 straight sideways
	front = family["f"] if dz <= 0 else family["b"]
	side = family["s"]
	num = {k: _lerp(front[k], side[k], t) for k in ("length", "duty", "lift", "bob", "lean", "base")}
	right = dx > 0
	close = side["close"] if right else 1.0 - side["close"]
	left_at = _lerp(0.5, close, t) if t > 0 else 0.5
	side_low = (side["duty"] + side["close"]) / side["duty"] / 2
	sign = 1 if dx > 0 else -1
	homes_f = homes_f or FWD_HOMES
	poles_f = poles_f or FWD_POLES
	poles_s = poles_s or SIDE_POLES
	# The lanes (one foot a little ahead) must lie across the travel, or the
	# feet run along the line between them and meet: left foot ahead for
	# forward-right and back-left, right foot ahead for forward-left and
	# back-right.
	lane = side["lane"] * (-1 if dx * dz > 1e-6 else 1)
	# `ahead`: both lanes moved forward under the body (the crouch: a foot
	# left behind a low crouch folds its leg into a kneel).
	ahead = side.get("ahead", 0.0)
	side_homes = {"right": (side["width"], lane - ahead), "left": (-side["width"], -lane - ahead)}
	hips = gait_hips(
		(dx, dz),
		num["duty"],
		num["base"],
		num["bob"],
		num["lean"],
		twist=front.get("twist", 0) * (1 - t),
		roll=front.get("roll", 0) * (1 - t),
		side_lean=-sign * side["side_lean"] * t,
		sway=0.05 * (1 - t),
		low_at=_lerp(0.5, side_low, t),
	)
	return Gait(
		(dx, dz),
		family["speed"],
		num["length"],
		num["duty"],
		num["lift"],
		hips,
		{k: _lerp(homes_f[k], side_homes[k], t) for k in ("right", "left")},
		{k: _lerp(poles_f[k], poles_s[k], t) for k in ("right", "left")},
		yaws={"right": _lerp(-yaw_f, -4 + 8 * dx, t), "left": _lerp(yaw_f, 4 + 8 * dx, t)},
		offsets={"right": 0.0, "left": left_at % 1.0},
	), num["length"]


def dir_clips(prefix, priority, family, names=None, **kw):
	for suffix, angle in DIRECTIONS.items():
		name = (names or {}).get(suffix, prefix + suffix)
		gait, length = dir_gait(angle, family, **kw)
		ground_clip(name, priority, dir_travel(angle), family["speed"], length, gait)


dir_clips("Run", "Movement", RUN_FAMILY)
# The walk set: aimed movement and anything under about 12 studs/s.
dir_clips("Walk", "Movement", WALK_FAMILY)
SPRINT_RUN = run_gait((0, -1), SPRINT_SPEED, SPRINT_LENGTH, 0.3, 1.05, 0.13, -15, -0.16, twist=8, roll=5)
ground_clip("SprintRun", "Movement", (0, -1), SPRINT_SPEED, SPRINT_LENGTH, SPRINT_RUN)


# The run's upper body (Action2, in step with SprintRun: Simulation/Poses
# keeps the two tracks on the same time): the gun comes down to a low ready
# across the body and swings with the stride; the chest twists against the
# hips.
def sprint_long(t):
	ph = t / SPRINT_LENGTH
	c, s = math.cos(TAU * ph), math.sin(TAU * ph)
	return solve(
		standing(
			{
				"chest": bladed(-10, -22 - 9 * c, 2 * s),
				"head": (-3, 0, 0),
				"gun": {
					"pos": (0.45 + 0.07 * s, 0.1 + 0.08 * math.cos(2 * TAU * ph), -1.0),
					"rot": (-32 + 5 * math.cos(2 * TAU * ph), 30 + 6 * s, 10),
				},
				"right_pole": (0.8, -1, 0.6),
				"left_arm": {"on_gun": LONG_GRIP},
				"left_pole": (-0.8, -1, 0.1),
			}
		)
	)


def sprint_pistol(t):
	# Running with a sidearm (2026-11-13): one-handed at a low ready, the
	# pistol by the right hip pointing down and ahead (the barrel runs along
	# the rigid forearm, so the forearm points with it), swinging a little
	# with the stride; the free arm pumps opposite the right leg. (Before, the
	# gun was folded low across the body with both forearms inside the chest
	# on every frame.)
	ph = t / SPRINT_LENGTH
	c, s = math.cos(TAU * ph), math.sin(TAU * ph)
	return solve(
		standing(
			{
				"chest": (-10, -8 * c, 2 * s),
				"head": (-3, 0, 0),
				"grip": GRIP_SIDEARM,
				"gun": {
					"pos": (0.95, -0.35 + 0.06 * math.cos(2 * TAU * ph), -1.25 + 0.12 * c),
					"rot": (-48 + 6 * c, 4, 0),
				},
				"right_pole": (1, -0.2, 0.6),
				# Right foot forward at phase 0: the left arm swings forward then.
				"left_arm": {"tip": (-1.2, -0.1 - 0.25 * c, -0.35 - 0.95 * c)},
				"left_pole": (-0.8, -0.3, 1),
			}
		)
	)


# The knife: both arms pump, opposite the legs.
def sprint_knife(t):
	ph = t / SPRINT_LENGTH
	c = math.cos(TAU * ph)
	return solve(
		standing(
			{
				"chest": (-12, -12 * c, 0),
				"head": (-3, 0, 0),
				"grip": GRIP_KNIFE,
				# Right foot forward at phase 0: the right arm is back then. The
				# knife pumps with the fist, blade forward, the forearm swinging.
				**kfist((1.15, -0.3 + 0.15 * c, -0.4 + 0.85 * c), (0.8, -0.3, 1), (0, 0.4, -1)),
				"left_arm": {"tip": (-1.2, -0.1 - 0.25 * c, -0.35 - 0.95 * c)},
				"left_pole": (-0.8, -0.3, 1),
			}
		)
	)


add(Clip("Sprint", "Action2", sprint_long, UPPER, length=SPRINT_LENGTH))
add(Clip("SprintPistol", "Action2", sprint_pistol, UPPER, length=SPRINT_LENGTH))
add(Clip("SprintKnife", "Action2", sprint_knife, UPPER, length=SPRINT_LENGTH))

# Air ---------------------------------------------------------------------------------

AIR_TUCK = {
	"hips": {"pos": (0, 0.05, 0), "rot": (-20, 0, 0)},
	# The left knee drives up, the right leg trails.
	"left_foot": {"pos": (-0.55, 1.0, -0.55), "pole": (-0.1, 0.3, -1)},
	"right_foot": {"pos": (0.58, 0.35, 0.75), "pole": (0.1, 0, -1)},
}
AIR_FALL = {
	"hips": {"pos": (0, 0, 0), "rot": (-8, 0, 0)},
	"left_foot": {"pos": (-0.62, 0.6, -0.4), "pole": (-0.2, 0.2, -1)},
	"right_foot": {"pos": (0.62, 0.35, 0.35), "pole": (0.2, 0, -1)},
}
PUSH_OFF = {
	"hips": {"pos": (0, -0.3, 0), "rot": (-12, 0, 0)},
	"left_foot": {"pos": (-0.58, 0, -0.2)},
	"right_foot": {"pos": (0.6, 0, 0.25)},
}

# Pass 4 (2026-11-13): keyed as controls and solved every frame (they were
# solved poses blended, which dug the landing 0.44 studs into the floor), and
# timed to the real jump: 4.4 studs at Workspace gravity rises in 0.21 s and,
# at 1.6x gravity on the way down, falls in 0.17 s. Roblox's Animate plays
# Jump for 0.31 s, then Fall (Config/Animations ANIMATE). LihFolk "Timing
# Spacing and Frame Charts": a landing is 2 to 4 frames down, 4 to 8 back up.
JUMP_LENGTH = 0.32
TAKE_OFF = {
	# The legs still extended from the push, the right foot trailing.
	"hips": {"pos": (0, 0.04, 0), "rot": (-8, 0, 0)},
	"left_foot": {"pos": (-0.56, 0.1, -0.2), "pole": (-0.15, 0, -1), "clamp": True},
	"right_foot": {"pos": (0.58, 0.1, 0.32), "pole": (0.15, 0, -1), "clamp": True},
}
KNEE_DRIVE = {
	# The left knee drives up, the right leg trails long behind.
	"hips": {"pos": (0, 0.04, 0), "rot": (-14, 0, 0)},
	"left_foot": {"pos": (-0.55, 0.85, -0.5), "pole": (-0.1, 0.3, -1), "clamp": True},
	"right_foot": {"pos": (0.58, 0.32, 0.62), "pole": (0.1, 0, -1), "clamp": True},
}
APEX = {
	# Tucked at the top: both knees up, the right one catching up.
	"hips": {"pos": (0, 0.05, 0), "rot": (-16, 0, 0)},
	"left_foot": {"pos": (-0.56, 1.0, -0.4), "pole": (-0.15, 0.3, -1), "clamp": True},
	"right_foot": {"pos": (0.6, 0.72, 0.12), "pole": (0.15, 0.2, -1), "clamp": True},
}
REACH = {
	# Opening up for the ground: the feet reach down, a little apart.
	"hips": {"pos": (0, 0, 0), "rot": (-7, 0, 0)},
	"left_foot": {"pos": (-0.62, 0.45, -0.32), "pole": (-0.2, 0.2, -1), "clamp": True},
	"right_foot": {"pos": (0.64, 0.26, 0.22), "pole": (0.2, 0, -1), "clamp": True},
}
add(
	Clip(
		"Jump",
		"Movement",
		ctrl_sequence([(0.0, TAKE_OFF), (0.08, KNEE_DRIVE, ease_in_out), (0.18, APEX, ease_in_out), (JUMP_LENGTH, REACH, ease_in_out)], solver=solve_grounded),
		LOWER,
		length=JUMP_LENGTH,
		loop=False,
		step=KEY_STEP,
	)
)


def fall(t):
	# The reach, with a slow pedal of the legs so a long fall isn't frozen.
	s = math.sin(TAU * t / 0.8)
	c = math.cos(TAU * t / 0.8)
	return solve_grounded(
		{
			"hips": {"pos": (0, 0, 0), "rot": (-7 + 2 * s, 0, 1.5 * s)},
			"left_foot": {"pos": (-0.62, 0.45 + 0.08 * s, -0.32 - 0.06 * c), "pole": (-0.2, 0.2, -1), "clamp": True},
			"right_foot": {"pos": (0.64, 0.26 - 0.08 * s, 0.22 + 0.06 * c), "pole": (0.2, 0, -1), "clamp": True},
		}
	)


add(Clip("Fall", "Movement", fall, LOWER, length=0.8, loop=True, step=0.1))

# The landing: the feet come down where the reach had them, the hips drop
# into a squash in 4 frames, hold a beat, and come back up with a small
# overshoot into the stance. Simulation/Poses plays it only when you land
# slow (moving fast, the run's own bounce carries the landing).
# (The feet land where the idle stands, so they don't shuffle as it hands back.)
LAND_FEET = {
	"left_foot": {"pos": (-0.5, 0, -0.33), "yaw": -4, "pole": (-0.25, 0, -1), "clamp": True},
	"right_foot": {"pos": (0.59, 0, -0.21), "yaw": -14, "pole": (0.25, 0, -1), "clamp": True},
}
LAND_TOUCH = {"hips": {"pos": (0, -0.04, 0), "rot": (-7, 0, 0)}, **LAND_FEET}
LAND_DOWN = {"hips": {"pos": (0, -0.58, 0.1), "rot": (-18, 0, 0)}, **LAND_FEET}
LAND_HOLD = {"hips": {"pos": (0, -0.52, 0.08), "rot": (-15, 0, 0)}, **LAND_FEET}
LAND_UP = {"hips": {"pos": (0, -0.03, 0), "rot": (2, 0, 0)}, **LAND_FEET}
add(
	Clip(
		"Land",
		"Action4",
		ctrl_sequence(
			[
				(0.0, LAND_TOUCH),
				(0.065, LAND_DOWN, ease_out),
				(0.12, LAND_HOLD, ease_in_out),
				(0.27, LAND_UP, ease_in_out),
				# Ends on the idle's own stance, which it hands back to.
				(0.36, {k: v for k, v in idle_ctrl(0.0).items() if k in ("hips", "left_foot", "right_foot")}, ease_in_out),
			],
			solver=solve_grounded,
		),
		LOWER,
		length=0.36,
		loop=False,
		step=KEY_STEP,
	)
)

# Crouch ------------------------------------------------------------------------------

CROUCH = {
	# Down on the haunches: the left foot ahead and flat, the right knee low.
	"hips": {"pos": (0, -1.12, 0.2), "rot": (-10, -6, 0)},  # was -1.22: nearer the crouch walk's height
	"left_foot": {"pos": (-0.6, 0, -0.62), "yaw": 6, "pole": (-0.25, 0.4, -1), "clamp": True},
	"right_foot": {"pos": (0.62, 0.05, 0.62), "yaw": -12, "pole": (0.35, -0.5, -1), "clamp": True},
}
held("Crouch", "Action2", CROUCH, LOWER)


# The crouch walk (pass 4): the same foot-locked gait as the run set (feet
# rolling on their edges, pinned to the ground), low and quick, each foot
# down 55% of the cycle (no flight), short quick steps. Sideways it shuffles in lanes like the
# strafes, so the shins never meet. Made for 9 studs/s (Movement.CROUCH_SPEED).
CROUCH_LENGTH = 0.3  # was 0.46: a folded leg can't reach a long stance (its shin lay flat)
CROUCH_DUTY = 0.55
CROUCH_POLES = {"right": (0.3, 0.1, -1), "left": (-0.3, 0.1, -1)}
# (Round 3, 2026-11-21: the side and diagonal shuffles left the back-lane foot
# so far behind the hips that its leg folded into a kneel at the end of each
# stance, the knee 0.26-0.38 into the floor. The lanes now sit 0.4 ahead, the
# side stance is 0.8 wide and 0.06 higher, and the knees point outward, so
# the swinging knee no longer comes in to the middle. tp_check: knee 0.000 in
# all six, lock 98.1-99.8% (was 98.5-99.8), shins 0.92-1.24 apart (was
# 0.93-1.21). Forward and back are unchanged.)
CROUCH_SIDE_POLES = {"right": (0.6, 0.1, -1), "left": (-0.6, 0.1, -1)}
CROUCH_FAMILY = {
	"speed": CROUCH_SPEED,
	"f": {"length": CROUCH_LENGTH, "duty": CROUCH_DUTY, "lift": 0.3, "bob": 0.04, "lean": -13, "base": -0.98, "twist": 3, "roll": 2.5},
	"b": {"length": CROUCH_LENGTH, "duty": CROUCH_DUTY, "lift": 0.3, "bob": 0.04, "lean": -13, "base": -0.98, "twist": 3, "roll": 2.5},
	# Crouched knees reach forward, so the side lanes are wider (shins 0.93 apart at worst).
	"s": {"length": CROUCH_LENGTH, "duty": CROUCH_DUTY, "close": 0.3, "lift": 0.28, "bob": 0.04, "lean": -13, "base": -0.92, "width": 0.8, "lane": 0.55, "ahead": 0.4, "side_lean": 5},
}
dir_clips(
	"CrouchWalk",
	"Action2",
	CROUCH_FAMILY,
	names={"F": "CrouchWalk"},
	homes_f={"right": (0.58, 0.05), "left": (-0.58, -0.05)},
	poles_f=CROUCH_POLES,
	poles_s=CROUCH_SIDE_POLES,
	yaw_f=8,
)

# Slide -------------------------------------------------------------------------------


def slide_ctrl(shake=0.0):
	return {
		# Sat back on the right hip, the left leg shot out in front, the gun
		# still out ahead in the right hand, the left hand skimming the floor.
		"hips": {"pos": (0, -1.82 + shake, 0.35), "rot": (30, -14, -7)},
		"chest": (6, 6, 0),
		"head": (-4, 0, 0),
		"left_foot": {"pos": (-0.5, 0.42, -2.05), "pole": (-0.1, 1, 0), "yaw": 0, "clamp": True},
		"right_foot": {"pos": (0.62, 0.02, -0.45), "pole": (0.5, 1, -0.3), "yaw": -20, "clamp": True},
		"gun": {"pos": (0.5, -1.45 + shake, -1.15), "rot": (4, 6, -22)},
		"right_pole": (1, -0.6, 0.2),
		"left_arm": {"tip": (-1.45, -2.93, 0.95)},
		"left_pole": (-1, 0.1, 1),
	}


def slide(t):
	return solve_grounded(slide_ctrl(0.025 * math.sin(TAU * t / 0.2)))


add(Clip("Slide", "Action3", slide, ALL, length=0.4, loop=True, step=0.05))

HOLD = long_hold()
HOLD_POSE = solve(HOLD)
RUN_CONTACT = SPRINT_RUN(0.0)


def gait_ctrl(gait, ph):
	"""A gait's controls at cycle phase ph (hips and both feet)."""
	out = {"hips": gait.hips(ph % 1.0)}
	for side in ("right", "left"):
		pos, planted = gait.foot(side, ph)
		out[side + "_foot"] = {"pos": tuple(pos), "yaw": gait.yaws[side], "pole": gait.poles[side], "clamp": True}
	return out


def upper_fade(pose_fn, hold, t0, t1, into=True):
	"""pose_fn's legs as they are; its upper body faded from the solved `hold`
	(into=True: over [t0, t1] from the hold into pose_fn) or back to it. The
	game plays the hold's own joint values over the run, so a one-shot that
	starts or ends in the run must start or end on exactly those."""

	def at(t):
		pose = dict(pose_fn(t))
		u = min(max((t - t0) / (t1 - t0), 0.0), 1.0)
		w = ease_in_out(u) if into else 1.0 - ease_in_out(u)
		for name in UPPER:
			pose[name] = mix({name: hold[name]}, {name: pose[name]}, w)[name]
		return pose

	return at


# The way in and out (pass 4): the legs keyed as controls and solved per
# frame (the old clips blended solved poses and swung a leg 0.76 studs
# through the floor); the upper body cross-fades from and back to the gun
# hold itself. In: from the run's stride (left foot reaching ahead), the left
# leg kicks out, the right folds under, the hips drop past the slide's height
# (the impact) and settle. Out: the extended foot plants, the body rises over
# it and lands in the run's footfall (Simulation/Poses lines the run up so
# its own footfall comes right then).
SLIDE_KICK = {
	**slide_ctrl(),
	"hips": {"pos": (0, -0.85, 0.15), "rot": (10, -8, -3)},
	"chest": (0, 0, 0),
	"left_foot": {"pos": (-0.5, 0.55, -1.45), "pole": (-0.1, 1, -0.3), "yaw": 0, "clamp": True},
	"right_foot": {"pos": (0.6, 0.0, 0.1), "pole": (0.4, 0.5, -1), "yaw": -14, "clamp": True},
	"gun": {"pos": (0.5, -0.4, -1.15), "rot": (0, 4, -10)},
	"left_arm": {"tip": (-1.2, -1.4, 0.0)},
	"left_pole": (-1, -0.2, 0.6),
}
RUN_IN = {**SLIDE_KICK, **gait_ctrl(SPRINT_RUN, 0.4)}  # (its upper body is the hold, faded in)
SLIDE_IMPACT = {**slide_ctrl(-0.13), "hips": {"pos": (0, -1.95, 0.32), "rot": (35, -14, -7)}}
SLIDE_SETTLE = slide_ctrl()
SLIDE_IN_LENGTH = 0.28
SLIDE_REACH = (0.02, 0.28)  # when the free hand leaves the gun and reaches the floor
SLIDE_IN_KEYS = [(0.0, RUN_IN), (0.09, SLIDE_KICK, ease_in_out), (0.18, SLIDE_IMPACT, ease_in_out), (SLIDE_IN_LENGTH, SLIDE_SETTLE, ease_in_out)]
_SPLINED = {}


def ctrl_at(track, t):
	"""The controls of a key track at time t: on splines when its keys share
	one shape (2026-11-20: eased segments stopped dead at every key, so the
	slide's body halted at the kick and popped at the impact), else blended
	segment by segment."""
	key = id(track)
	if key not in _SPLINED:
		_SPLINED[key] = (track, spline_ctrl(track))
	fn = _SPLINED[key][1]
	if fn is not None:
		return fn(t)
	if t <= track[0][0]:
		return dict(track[0][1])
	for i in range(1, len(track)):
		t0, t1 = track[i - 1][0], track[i][0]
		if t <= t1:
			ease = track[i][2] if len(track[i]) > 2 else ease_in_out
			return _mix_ctrl(track[i - 1][1], track[i][1], ease((t - t0) / (t1 - t0)) if t1 > t0 else 1.0)
	return dict(track[-1][1])


def grip_point(ctrl):
	"""Where the long gun's left grip is for these controls (root space)."""
	g = ctrl["gun"]
	return tuple((v3(g["pos"]) + euler(*g.get("rot", (0, 0, 0))) @ v3(LONG_GRIP)))


def hand_to(track, t, t0, t1, to_floor=True, on_point=grip_point, rest_pole=L_POLE):
	"""Controls at t with the left hand's target carried in space between
	the weapon's grip (`on_point`) and the track's own floor reach over
	[t0, t1]; its elbow from the hold's (`rest_pole`) to the track's."""
	ctrl = ctrl_at(track, t)
	u = ease_in_out(min(max((t - t0) / (t1 - t0), 0.0), 1.0))
	w = u if to_floor else 1.0 - u
	on, off = v3(on_point(ctrl)), v3(ctrl["left_arm"]["tip"])
	ctrl["left_arm"] = {"tip": tuple(on + (off - on) * w)}
	ctrl["left_pole"] = tuple(v3(rest_pole) + (v3(ctrl["left_pole"]) - v3(rest_pole)) * w)
	return ctrl


def slide_in(t):
	# The left hand rides the gun through the kick, then goes for the floor.
	# (2026-11-20: over 0.02-0.28 s, was 0.06-0.22: the hand dived at 55
	# studs/s, 72 with the knife; now 39 / 53, and it lands as the body settles.)
	return solve_grounded(hand_to(SLIDE_IN_KEYS, t, SLIDE_REACH[0], SLIDE_REACH[1]))


add(Clip("SlideIn", "Action4", upper_fade(slide_in, HOLD_POSE, 0.0, 0.09), ALL, length=SLIDE_IN_LENGTH, loop=False, step=KEY_STEP))
SLIDE_POSE = solve_grounded(slide_ctrl())
SLIDE_PUSH = {
	**slide_ctrl(),
	# The left foot plants ahead and takes the weight, the body comes up and
	# forward over it, the right leg gathers under.
	"hips": {"pos": (0, -0.8, 0.0), "rot": (-16, -6, -2)},
	"chest": (-4, 0, 0),
	"left_foot": {"pos": (-0.58, 0, -0.75), "pole": (-0.15, 0.2, -1), "yaw": 4, "clamp": True},
	"right_foot": {"pos": (0.6, 0.35, 0.55), "pole": (0.2, 0, -1), "yaw": -8, "clamp": True},
	"gun": {"pos": (0.5, -0.05, -1.1), "rot": (0, 2, -6)},
	"left_arm": {"tip": (-0.7, -0.5, -0.9)},
	"left_pole": (-0.8, -1, 0.3),
}
SLIDE_OUT_LENGTH = 0.3  # Config/Animations SLIDE_OUT_LENGTH
RUN_OUT = {**SLIDE_PUSH, **gait_ctrl(SPRINT_RUN, 0.0)}  # (upper body: the hold, faded back)
SLIDE_OUT_KEYS = [(0.0, slide_ctrl()), (0.15, SLIDE_PUSH, ease_in_out), (SLIDE_OUT_LENGTH, RUN_OUT, ease_in_out)]


def slide_out(t):
	# The hand comes off the floor back to the gun as the body rises.
	return solve_grounded(hand_to(SLIDE_OUT_KEYS, t, 0.02, 0.22, to_floor=False))


add(Clip("SlideOut", "Action4", upper_fade(slide_out, HOLD_POSE, 0.12, SLIDE_OUT_LENGTH, into=False), ALL, length=SLIDE_OUT_LENGTH, loop=False, step=KEY_STEP))

# Sidearm and knife slides (2026-11-13, owner: "keep getting it up"). The
# three slide clips key the whole body, so a pistol or knife holder used to
# slide with the rifle's arms and pop to their own hold as the slide ended.
# Each weapon kind now has its own upper body on the rigid fist: the pistol
# out ahead one-handed, the knife fist forward with the blade up; the left
# hand rides that weapon's own grip (the pistol's cup, the knife's guard
# hand) before it reaches for the floor; the way in and out fade from and
# back to that kind's hold. Legs, hips and timing are the rifle slide's.
def _pistol_cup(ctrl):
	g = ctrl["gun"]
	return tuple(v3(g["pos"]) + euler(*g.get("rot", (0, 0, 0))) @ v3(PISTOL_CUP["on_gun"]))


KNIFE_GUARD = (-0.5, 0.5, -1.5)  # knife(): the free hand out front
SLIDE_KINDS = {
	"Pistol": {
		"hold": pistol_hold(),
		"slide": lambda shake: {"grip": GRIP_SIDEARM, "gun": {"pos": (0.32, -1.38 + shake, -1.5), "rot": (4, 2, -8)}, "right_pole": (1, -0.6, 0.2)},
		"kick": {"grip": GRIP_SIDEARM, "gun": {"pos": (0.25, -0.3, -1.55), "rot": (0, 0, -4)}, "right_pole": (0.8, -0.8, 0.3)},
		"push": {"grip": GRIP_SIDEARM, "gun": {"pos": (0.3, 0.0, -1.95), "rot": (0, 0, -2)}, "right_pole": (0.8, -0.8, 0.3)},
		"on_point": _pistol_cup,
		"rest_pole": (-0.7, -1, 0.1),
	},
	"Knife": {
		"hold": knife(),
		"slide": lambda shake: {"grip": GRIP_KNIFE, **kfist((0.85, -1.35 + shake, -1.0), (1, -0.4, 0.5), (-0.2, 0.7, -1))},
		"kick": {"grip": GRIP_KNIFE, **kfist((0.8, -0.25, -1.15), (1, -0.5, 0.4), (-0.25, 0.9, -0.6))},
		"push": {"grip": GRIP_KNIFE, **kfist((0.75, 0.15, -1.3), (1, -0.6, 0.3), (-0.3, 1, -0.3))},
		"on_point": lambda ctrl: KNIFE_GUARD,
		"rest_pole": (-1, -0.4, 0.2),
	},
}


def _swap_upper(ctrl, upper):
	"""A slide key with the right arm's weapon controls replaced."""
	out = {k: v for k, v in ctrl.items() if k not in ("gun", "grip", "right_arm", "right_pole")}
	out.update(upper)
	return out


def _slide_kind(kind, spec):
	hold_pose = solve(spec["hold"])

	def ctrl(shake=0.0):
		return _swap_upper(slide_ctrl(shake), spec["slide"](shake))

	def hold_loop(t):
		return solve_grounded(ctrl(0.025 * math.sin(TAU * t / 0.2)))

	add(Clip("Slide" + kind, "Action3", hold_loop, ALL, length=0.4, loop=True, step=0.05))
	kick = _swap_upper(SLIDE_KICK, spec["kick"])
	impact = _swap_upper(SLIDE_IMPACT, spec["slide"](-0.13))
	keys_in = [(0.0, {**kick, **gait_ctrl(SPRINT_RUN, 0.4)}), (0.09, kick, ease_in_out), (0.18, impact, ease_in_out), (SLIDE_IN_LENGTH, ctrl(), ease_in_out)]
	push = _swap_upper(SLIDE_PUSH, spec["push"])
	keys_out = [(0.0, ctrl()), (0.15, push, ease_in_out), (SLIDE_OUT_LENGTH, {**push, **gait_ctrl(SPRINT_RUN, 0.0)}, ease_in_out)]
	hand = {"on_point": spec["on_point"], "rest_pole": spec["rest_pole"]}

	def into(t):
		return solve_grounded(hand_to(keys_in, t, SLIDE_REACH[0], SLIDE_REACH[1], **hand))

	def out_of(t):
		return solve_grounded(hand_to(keys_out, t, 0.02, 0.22, to_floor=False, **hand))

	add(Clip("SlideIn" + kind, "Action4", upper_fade(into, hold_pose, 0.0, 0.09), ALL, length=SLIDE_IN_LENGTH, loop=False, step=KEY_STEP))
	add(
		Clip(
			"SlideOut" + kind,
			"Action4",
			upper_fade(out_of, hold_pose, 0.12, SLIDE_OUT_LENGTH, into=False),
			ALL,
			length=SLIDE_OUT_LENGTH,
			loop=False,
			step=KEY_STEP,
		)
	)


# Unarmed (owner 2026-11-21: in the lobby, with no gun, the body "is like it's
# holding a gun ... it needs to look good, idle, running, sliding, crouching").
# Simulation/Poses plays these when the player holds nothing: the upper body
# only (Action, over the Core idle and the leg cycles), so the legs, hips and
# their timing stay the movement clips'. Arms by FK angles (shoulder, elbow,
# wrist; a positive shoulder pitch swings the arm forward). The swing follows
# the shared stride phase (the right foot lands at phase 0, so the LEFT arm is
# forward then) and Poses keeps each clip on the leg cycle's phase.


def _arm(pitch, bend, out=5.0, wrist=0.0):
	"""FK for one arm: shoulder `pitch` forward, rolled `out` from the side,
	the elbow bent `bend` forward, the wrist `wrist`."""
	return {"fk": ((pitch, 0, out), (bend, 0, 0), (wrist, 0, 0))}


def _arms_ctrl(chest, head, right, left):
	out = standing({"chest": chest, "head": head})
	out["right_arm"] = right
	out["left_arm"] = {"fk": tuple((a, -b, -c) for (a, b, c) in left["fk"])}
	return out


def unarmed_idle_ctrl(t):
	b = math.sin(TAU * t / IDLE_LENGTH)
	s2 = math.sin(TAU * t / IDLE_LENGTH + 1.3)
	# Square to the front (the Core idle's hips are bladed 10 degrees), the
	# arms hanging loose a little ahead of the body, elbows soft, a slow breath.
	return _arms_ctrl(
		(-1 + 1.6 * b, 9, 0),
		(1.5 * b, -6, 0),
		_arm(4 + 1.5 * s2, 12 + 2 * b, 6 + 0.8 * b, 6),
		_arm(4 - 1.5 * s2, 12 + 2 * b, 6 + 0.8 * b, 6),
	)


def _swing_clip(name, length, swing, back, bend_fwd, bend_back, twist, lean, out=7.0):
	"""An arm swing in step with the legs: at phase 0 the left arm is fully
	forward (`swing` degrees) and the right fully back (`back`), elbows bent
	`bend_fwd` on the forward swing and `bend_back` behind; the chest
	counter-turns `twist` degrees against the hips and leans `lean`."""

	def at(t):
		ph = t / length
		c = math.cos(TAU * ph)  # 1: left arm forward, -1: right arm forward
		# A swing spends more time at its ends than in the middle (pendulum),
		# and the elbow folds as the arm comes forward.
		def arm(fwd):
			w = (fwd + 1) / 2  # 0 back .. 1 forward
			pitch = -back + (swing + back) * w
			bend = bend_back + (bend_fwd - bend_back) * w
			return _arm(pitch, bend, out, 4 + 6 * w)

		return solve(
			_arms_ctrl(
				(lean, twist * c, 0),
				(-lean * 0.6, -twist * c * 0.7, 0),
				arm(-c),
				arm(c),
			)
		)

	return add(Clip(name, "Action", at, UPPER, length=length, loop=True, step=0.03))


add(Clip("UnarmedIdle", "Action", lambda t: solve(unarmed_idle_ctrl(t)), UPPER, length=IDLE_LENGTH, loop=True, step=0.1))
# Walk: an easy swing; run: elbows bent, a full swing; sprint: pumping.
_swing_clip("UnarmedWalk", WALK_LENGTH, swing=24, back=20, bend_fwd=26, bend_back=10, twist=4, lean=-1)
_swing_clip("UnarmedRun", RUN_LENGTH, swing=48, back=38, bend_fwd=80, bend_back=45, twist=7, lean=-4)
_swing_clip("SprintUnarmed", SPRINT_LENGTH, swing=62, back=50, bend_fwd=95, bend_back=60, twist=9, lean=-6)
# The sprint arms are an Action2 layer like the other sprint uppers (Poses SPRINT_SET).
CLIPS["SprintUnarmed"].priority = "Action2"


def unarmed_crouch(t):
	b = math.sin(TAU * t / 1.0)
	# The arms loose and a little ahead, out from the sides so they clear the
	# thighs, the hands low.
	return solve(
		_arms_ctrl(
			(-6 + 0.8 * b, 6, 0),
			(4, -4, 0),
			# (v1 34 / 52 raised the fists to the chest: a boxer's guard.)
			_arm(16 + b, 24, 12, 6),
			_arm(13 - b, 20, 12, 6),
		)
	)


add(Clip("UnarmedCrouch", "Action", unarmed_crouch, UPPER, length=1.0, loop=True, step=0.1))

UNARMED_HOLD = unarmed_idle_ctrl(0.0)
# The slide with nothing in hand: the right arm out ahead for balance, the
# left hand skimming the floor (the rifle slide's); in and out from and back
# to the relaxed stance.
SLIDE_KINDS["Unarmed"] = {
	"hold": UNARMED_HOLD,
	"slide": lambda shake: {"right_arm": {"tip": (1.05, -0.75 + shake, -1.45)}, "right_pole": (1, -0.3, 0.5)},
	"kick": {"right_arm": {"tip": (1.15, 0.15, -1.2)}, "right_pole": (1, -0.4, 0.5)},
	"push": {"right_arm": {"tip": (1.2, 0.35, -1.35)}, "right_pole": (1, -0.5, 0.4)},
	"on_point": lambda ctrl: (-0.9, -0.45, -1.05),
	"rest_pole": (-1, -0.4, 0.2),
}


for _kind, _spec in SLIDE_KINDS.items():
	_slide_kind(_kind, _spec)

# Gun handling ------------------------------------------------------------------------


def long_with(gun_pos, gun_rot, left, chest=None, head=(0, 0, 0), r_pole=R_POLE, l_pole=L_POLE):
	return solve(
		standing(
			{
				"chest": bladed(-4, CHEST_TURN) if chest is None else chest,
				"head": head,
				"gun": {"pos": gun_pos, "rot": gun_rot},
				"right_pole": r_pole,
				"left_arm": left,
				"left_pole": l_pole,
			}
		)
	)


# The reload (re-keyed 2026-11-15). Seen in a playtest from outside: tipped 36
# to 44 degrees up about the shoulder, the grip rose to the height of the
# face, so the right forearm covered the face and the rifle stood up over the
# head. A tipped-up gun can't be held low on this rig (the fist is rigid with
# the gun, so the forearm tips up with it and the hand ends at the chin). So
# the gun now drops to a LOW READY instead: muzzle down and out, canted so the
# magazine well turns toward the off hand, at belly height; the chest leans
# over it and the head looks down at it; the face stays clear. The slap bumps
# the gun up and it drops back (a rebound, not a stop) before it swings up to
# the shoulder, a little past the hold.
def low_ready(pitch, yaw, roll, lift=0.0):
	"""The long gun swung `pitch` (negative: down) about the aim pivot from a
	point 0.38 studs out from the hold (nearer, the right forearm enters the chest block), turned `yaw` left and canted `roll`."""
	return pitched((HIP_GUN[0], HIP_GUN[1] + lift, HIP_GUN[2] - 0.38), pitch), (pitch, yaw, roll)


LOW = low_ready(-26, 10, -24)
LOW_AWAY = low_ready(-28, 11, -27)  # the hold keeps moving while the off hand is away
LOW_HIT = low_ready(-20, 9, -21, 0.05)  # the slap lifts it
LOW_BACK = low_ready(-28, 10, -25)  # ...and it drops back past where it was
LOOK = (-24, 8, 0)
BELT = (-0.75, -0.85, -0.55)  # where the off hand finds a magazine: the left hip
MAG_UNDER = {"on_gun": (0, -1.05, -0.42), "min_z": -1}
MAG_IN = {"on_gun": (0, -0.7, -0.42), "min_z": -1}
add(
	Clip(
		"Reload",
		"Action4",
		pose_spline(
			[
				(0.0, HOLD_POSE),
				# The gun drops to a low ready and cants.
				(0.12, long_with(*LOW, {"on_gun": LONG_GRIP}, chest=bladed(-10, -28), head=LOOK), ease_out),
				# The off hand drops for a magazine...
				(0.3, long_with(*LOW_AWAY, {"tip": BELT}, chest=bladed(-9, -27), head=LOOK, l_pole=(-1, -0.2, 0.6)), ease_in_out),
				# ...brings it up under the gun...
				(0.5, long_with(*LOW, dict(MAG_UNDER), chest=bladed(-10, -28), head=LOOK), ease_in_out),
				# ...and slaps it home: the gun jumps, then drops back.
				(0.56, long_with(*LOW_HIT, dict(MAG_IN), chest=bladed(-8, -28), head=LOOK), ease_in),
				(0.64, long_with(*LOW_BACK, dict(MAG_IN), chest=bladed(-10, -29), head=LOOK), ease_out),
				# The off hand goes forward to the handguard as the gun swings up past the hold.
				(0.8, long_with(*about_shoulder(HIP_GUN, 7, 2, -4), {"on_gun": LONG_GRIP}, chest=bladed(-3, -30), head=(-4, 2, 0)), ease_in_out),
				# Down through the hold, then settle.
				(0.91, long_with((0.5, 0.52, -1.02), (-4, 0, 0), {"on_gun": LONG_GRIP}), ease_in_out),
				(1.0, HOLD_POSE, ease_out),
			],
			hits=(0.56,),
		),
		UPPER,
		length=1.0,
		loop=False,
	)
)

PISTOL = pistol_hold()
PISTOL_POSE = solve(PISTOL)


def pistol_with(gun_pos, gun_rot, left, chest=None, head=(0, 0, 0), l_pole=(-0.7, -1, 0.1)):
	return solve(
		standing(
			{
				"chest": bladed(-4, -14) if chest is None else chest,
				"head": head,
				"grip": GRIP_SIDEARM,
				"gun": {"pos": gun_pos, "rot": gun_rot},
				"right_pole": (0.7, -1, 0.3),
				"left_arm": left,
				"left_pole": l_pole,
			}
		)
	)


PULLED = ((0.4, 0.75, -1.4), (26, -16, 26))  # (rigid fist: 50 up folded the elbow shut)
add(
	Clip(
		"PistolReload",
		"Action4",
		pose_spline(
			[
				(0.0, PISTOL_POSE),
				(0.13, pistol_with(*PULLED, dict(PISTOL_CUP), chest=bladed(-2, -8), head=LOOK, l_pole=(-1, -0.2, 0.6)), ease_out),
				# (A belt point a little wider than the rifle's: the left forearm grazed the chest on the way.)
				(0.3, pistol_with(*PULLED, {"tip": (-1.0, -0.85, -0.6)}, chest=bladed(-2, -2), head=LOOK, l_pole=(-1, -0.2, 0.6))),
				# (2026-11-20, on splines: the hand comes up OUTSIDE the chest; the
				# straight joint-space path grazed it at 0.38-0.43 s.)
				(0.41, pistol_with(*PULLED, {"tip": (-1.15, -0.5, -1.0)}, chest=bladed(-2, -5), head=LOOK, l_pole=(-1, -0.2, 0.6))),
				(0.5, pistol_with(*PULLED, {"on_gun": (-0.1, -1.15, 0.1), "min_z": 0.0}, chest=bladed(-2, -8), head=LOOK, l_pole=(-1, -0.2, 0.6))),
				(0.57, pistol_with((0.4, 0.82, -1.4), (32, -16, 26), {"on_gun": (-0.1, -0.85, 0.1), "min_z": 0.0}, head=LOOK), ease_in),
				(0.72, pistol_with((0.3, 0.72, -1.3), (20, -6, 10), dict(PISTOL_CUP), head=(-6, 0, 0)), ease_out),
				# Punched back out past the hold, then settle.
				(0.88, pistol_with((0.7, 1.0, -2.5), (-4, 0, 0), dict(PISTOL_CUP)), ease_in_out),
				(1.0, PISTOL_POSE, ease_out),
			],
			hits=(0.57,),
		),
		UPPER,
		length=1.0,
		loop=False,
	)
)

# A swap: the new gun comes up from low on the right, the off hand meets it,
# and it lands in the hold with a small overshoot.
add(
	Clip(
		"Draw",
		"Action4",
		pose_spline(
			[
				(
					0.0,
					long_with(
						(1.0, -0.5, -0.75),
						(-70, 0, 14),
						{"tip": (-1.2, -1.05, -0.4)},
						chest=bladed(-2, -10),
						head=(-6, 0, 0),
						r_pole=(1, -0.3, 1),
						l_pole=(-1, -0.4, 0.8),
					),
				),
				(0.2, long_with((0.7, 0.2, -0.95), (-22, 4, 8), {"tip": (-0.3, 0.2, -1.3)}, chest=bladed(-3, -26)), ease_in),
				(0.36, long_with((0.5, 0.62, -1.05), (6, 0, -3), {"on_gun": LONG_GRIP}), ease_out),
				(0.5, HOLD_POSE, ease_in_out),
			]
		),
		UPPER,
		length=0.5,
		loop=False,
	)
)

# Knife -------------------------------------------------------------------------------


def knife_sequence(track):
	"""ctrl_sequence for knife keys, with the blade turned smoothly: each
	key's fist orientation is solved once, the orientation is slerped between
	keys, and the blade is read off it. Blending the blade VECTORS linearly
	(2026-11-13, the owner's "the arm flicks") nearly cancelled them out when
	two keys pointed ~180 degrees apart, so the fist's roll was undefined for a
	frame and flipped (measured: KnifeSlash3's forearm turned 171 degrees in one
	60 Hz frame, KnifeSlash / Slash2 about 50 into the recovery)."""
	frames, uppers = [], []
	for key in track:
		w = fk(solve(dict(key[1])))
		frames.append(w["RightHand"][:3, :3])
		uppers.append(w["RightUpperArm"][:3, :3])

	def at(t):
		if t <= track[0][0]:
			return solve(dict(track[0][1]))
		for i in range(1, len(track)):
			t0, t1 = track[i - 1][0], track[i][0]
			if t <= t1:
				ease = track[i][2] if len(track[i]) > 2 else ease_in_out
				u = ease((t - t0) / (t1 - t0)) if t1 > t0 else 1.0
				ctrl = _mix_ctrl(track[i - 1][1], track[i][1], u)
				rot = rot_mix(frames[i - 1], frames[i], u)
				arm = dict(ctrl["right_arm"])
				arm["blade"] = tuple(rot @ v3(0, 0, -1))
				# The upper arm turned smoothly between the keys' own answers
				# (no hop to an equally good one half a turn away).
				arm["upper_ref"] = rot_mix(uppers[i - 1], uppers[i], u)
				ctrl["right_arm"] = arm
				return solve(ctrl)
		return solve(dict(track[-1][1]))

	return at


def knife_spline(track):
	"""knife_sequence on splines (2026-11-20): the controls run on monotone
	cubics (spline_ctrl) and the fist's and upper arm's turns on cubics of
	their rotation vectors, so nothing starts, stops or holds dead at a key
	unless two keys say so. Same key format (eases ignored)."""
	frames, uppers = [], []
	for key in track:
		w = fk(solve(dict(key[1])))
		frames.append(w["RightHand"][:3, :3])
		uppers.append(w["RightUpperArm"][:3, :3])
	ctrl_fn = spline_ctrl(track)
	ts = np.array([key[0] for key in track], dtype=float)

	def turns(mats):
		ys = np.array([_rot_log(mats[0].T @ m_) for m_ in mats])
		return ys, _pchip_slopes(ts, ys)

	fist, upper = turns(frames), turns(uppers)

	def turn_at(mats, ys_m, t):
		ys, m = ys_m
		i = min(max(int(np.searchsorted(ts, t, side="right")) - 1, 0), len(ts) - 2)
		h = ts[i + 1] - ts[i]
		s_ = (t - ts[i]) / h if h > 0 else 1.0
		v = (2 * s_**3 - 3 * s_**2 + 1) * ys[i] + (s_**3 - 2 * s_**2 + s_) * h * m[i] + (-2 * s_**3 + 3 * s_**2) * ys[i + 1] + (s_**3 - s_**2) * h * m[i + 1]
		return mats[0] @ _rot_exp(v)

	def at(t):
		t = min(max(t, ts[0]), ts[-1])
		ctrl = ctrl_fn(t)
		arm = dict(ctrl["right_arm"])
		arm["blade"] = tuple(turn_at(frames, fist, t) @ v3(0, 0, -1))
		arm["upper_ref"] = turn_at(uppers, upper, t)
		ctrl["right_arm"] = arm
		return solve(ctrl)

	return at


def swing(name, length, track):
	# Controls blended and solved every frame (not solved poses blended): the
	# fist stays on its path and the elbow never folds shut on the way; the
	# blade turns smoothly (knife_sequence).
	return add(Clip(name, "Action4", knife_sequence(track), UPPER, length=length, loop=False, step=KEY_STEP))


READY = knife()
GUARD = (-0.8, 0.35, -0.85)  # the free hand pulled in while the knife works

# The swings, re-keyed for the rigid fist (§17): each key places the fist, the
# way its forearm runs back to the elbow, and where the blade points.
# Forehand: winds up high on the right, cuts down across to the left.
swing(
	"KnifeSlash",
	0.52,
	[
		(0.0, READY, linear),
		(
			0.1,
			knife(kfist((1.2, 1.0, -0.75), (0.45, -0.75, 0.5), (-0.4, 0.85, 0.35)), chest=(-2, -16, 0), left=(-0.4, 0.55, -1.55)),
			ease_in_out,
		),
		(0.17, knife(kfist((0.15, 0.45, -1.75), (0.55, -0.3, 0.8), (-1, 0.15, -0.2)), chest=(-12, 22, 0), left=GUARD), linear),
		(0.26, knife(kfist((-0.5, 0.0, -1.3), (0.85, -0.1, 0.5), (-0.6, -0.55, 0.55)), chest=(-10, 34, 0), left=GUARD), ease_out),
		(0.52, READY, ease_in_out),
	],
)
# Backhand: from across the body, back out to the right.
swing(
	"KnifeSlash2",
	0.52,
	[
		(0.0, READY, linear),
		(0.1, knife(kfist((-0.35, 0.85, -1.15), (0.8, -0.35, 0.5), (-0.55, 0.75, 0.35)), chest=(-6, 30, 0), left=GUARD), ease_in_out),
		(0.17, knife(kfist((0.6, 0.5, -1.75), (0.3, -0.45, 0.85), (1, 0.15, -0.25)), chest=(-10, -10, 0), left=GUARD), linear),
		(
			0.26,
			knife(kfist((1.35, 0.25, -0.95), (0.05, -0.55, 0.85), (0.7, -0.45, 0.55)), chest=(-8, -26, 0), left=(-0.5, 0.45, -1.3)),
			ease_out,
		),
		(0.52, READY, ease_in_out),
	],
)
# The chop: up over the shoulder, down the middle.
swing(
	"KnifeSlash3",
	0.56,
	[
		(0.0, READY, linear),
		(
			0.1,
			knife(kfist((0.8, 1.75, -0.4), (0.25, -0.9, 0.35), (0, 0.45, 0.9)), chest=(8, -6, 0), left=(-0.45, 0.6, -1.5), head=(4, 0, 0)),
			ease_in_out,
		),
		(0.19, knife(kfist((0.45, 0.5, -1.75), (0.2, -0.25, 0.95), (0, -0.2, -1)), chest=(-18, 4, 0), left=GUARD), linear),
		(0.28, knife(kfist((0.4, -0.3, -1.3), (0.15, 0.35, 0.92), (0, -0.85, -0.5)), chest=(-24, 6, 0), left=GUARD), ease_out),
		(0.56, READY, ease_in_out),
	],
)
# The heavy: pulled back and coiled, held, then a straight thrust (blade
# forward, the arm driving straight out from the shoulder).
COIL = knife(kfist((1.25, 0.3, -0.5), (0.6, -0.5, 0.7), (0.1, 0.25, -1)), chest=(-4, -32, 0), left=(-0.35, 0.6, -1.65))
THRUST = knife(kfist((0.25, 0.5, -2.0), (0.6, -0.6, 0.4), (-0.15, 0.1, -1)), chest=(-14, 28, 0), left=(-0.95, 0.2, -0.5))
# (2026-11-20, on splines; the owner's "stiff posed keys" were all here: the
# clip jumped to 15 studs/s from rest, the coil held dead still for 0.1 s, the
# thrust hit 55 studs/s and stopped dead at contact, then held dead again.
# Now the coil keeps creeping back (anticipation), the thrust brakes into the
# contact at 0.40 s, carries 0.14 studs past it and settles back.)
COIL_DEEP = knife(kfist((1.32, 0.28, -0.38), (0.6, -0.5, 0.7), (0.1, 0.25, -1)), chest=(-3, -36, 0), left=(-0.35, 0.62, -1.7))
THRUST_PAST = knife(kfist((0.2, 0.47, -2.14), (0.6, -0.6, 0.4), (-0.15, 0.08, -1)), chest=(-16, 32, 0), left=(-1.0, 0.18, -0.42))
add(
	Clip(
		"KnifeHeavy",
		"Action4",
		knife_spline(
			[
				(0.0, READY),
				(0.2, COIL),
				(0.31, COIL_DEEP),
				(0.4, THRUST),
				(0.45, THRUST_PAST),
				(0.58, THRUST),
				(0.9, READY),
			]
		),
		UPPER,
		length=0.9,
		loop=False,
		step=KEY_STEP,
	)
)

# Which gun each clip is shown with in the preview.
# Mods, hits, death, victory (2026-11-12, owner: "everything to 9-10"; these
# replace the Studio-generated clips of tools/studio/MakeModAnimations /
# MakeSlamAnimations / MakePoseAnimations, made for the old thin-arm body).
#
# How they are made (the professional way, and checked by
# tools/anim checks in the vault note): every key is a set of CONTROLS (hips,
# feet, hand targets, chest), blended and SOLVED EVERY FRAME, so a planted
# foot stays on the floor and a hand on its target the whole way (blending
# solved joint angles swung the feet through the floor between a kneel and a
# stand). A one-shot then blends into the gun hold it hands back to. The held
# Mod item sits in the right hand (Services/ModService); the gun is hidden
# while it is up.
#
# Dash and Flinch play over the gun hold and the run, so they key what they
# must and no more: the dash the hips and legs (a planted lunge), the flinch
# the hips and head. Keying UpperTorso would wipe the rifle stance's chest
# turn for that moment.


R_ITEM_POLE = (0.9, -1, 0.35)  # a held item's elbow: down and out
L_OPEN_POLE = (-0.7, -1, 0.15)


def arms(chest, right, left, head=(0, 0, 0), r_pole=R_ITEM_POLE, l_pole=L_OPEN_POLE):
	"""Upper-body controls from block-end targets (root space)."""
	return {
		"chest": chest,
		"head": head,
		"right_arm": {"tip": right},
		"right_pole": r_pole,
		"left_arm": {"tip": left},
		"left_pole": l_pole,
	}


def stood(ctrl):
	return {**STAND, **ctrl}


STAND_HOLD = solve({**HOLD, **STAND})

# The held item up by the right shoulder, ready, the free hand reaching out
# toward the target: a broad silhouette that reads "about to use something".
# (Review 1: the item at head height in front hid the face, and a bent free
# arm read as a boxer's guard. Targets past the arm's reach give straight arms.)
MOD_HOLD_R = (1.35, 1.05, -0.55)
MOD_HOLD_L = (-0.35, 0.5, -2.4)
MOD_HOLD = stood(arms(bladed(-4, -8), MOD_HOLD_R, MOD_HOLD_L))


def mod_hold(t):
	# (Round 3, "a touch flat": one slow breath was all it did. Now the
	# shoulders also sway a little side to side out of step with the breath,
	# the item hand weighs the item (a small bob twice a breath) and the free
	# hand drifts with the chest; the head stays on target. Every term repeats
	# over the loop, so the seam is clean.)
	ph = TAU * t / 2.4
	b = math.sin(ph)
	sway = math.sin(ph + 1.2)
	weigh = math.sin(2 * ph + 0.6)
	return solve(
		stood(
			arms(
				bladed(-4 - 1.5 * b, -8 + 3.0 * sway, 1.2 * sway),
				(MOD_HOLD_R[0] + 0.03 * sway, MOD_HOLD_R[1] + 0.05 * b + 0.035 * weigh, MOD_HOLD_R[2] - 0.03 * weigh),
				(MOD_HOLD_L[0] + 0.05 * sway, MOD_HOLD_L[1] + 0.05 * b, MOD_HOLD_L[2] - 0.03 * b),
				head=(0, -2.0 * sway, 0),
			)
		)
	)


add(Clip("ModHold", "Action", mod_hold, UPPER, length=2.4))

# Overhand throw: coil (chest turned right, the item cocked behind the head,
# the free arm pointing at the target), a held beat, the snap over the top,
# follow through across the body, back to the gun.
add(
	Clip(
		"Throw",
		"Action4",
		spline_sequence(
			[
				(0.0, MOD_HOLD),
				# (Chest turns kept within 22 degrees: the hips belong to the run
				# under this clip, so a 40-degree chest turn twisted the torso
				# like a screw. The pointing arm aims past its reach: straight.)
				# (Round 2, seen in the engine from the front-right: the cocked hand hid
				# behind the head and the pointing arm bent up at head height, so the
				# wind-up read as "arms raised". Now the item is up above and behind
				# the head and the free arm points straight at the target.)
				(0.12, stood(arms(bladed(6, -20), (1.15, 1.85, 0.55), (-0.4, 1.05, -2.75), r_pole=(1, 0.4, 0.35))), ease_out),
				# (2026-11-20, on splines: a 60 ms snap (was 50, the owner's ~60 ms),
				# the pointing arm starts to tuck in as the throw goes, and a longer
				# way back to the gun; tp_measure peak 1494 -> 1294 studs/s² right,
				# 1363 -> 1073 left, both velocity-continuous.)
				(0.17, stood(arms(bladed(9, -22), (1.05, 2.15, 0.7), (-0.5, 1.0, -2.8), r_pole=(1, 0.6, 0.3)))),
				(0.23, stood(arms(bladed(-16, 16), (0.4, 1.45, -1.75), (-0.85, 0.55, -1.05), r_pole=(1, -0.3, 0.2))), ease_in),
				(0.36, stood(arms(bladed(-22, 22), (-0.35, -0.15, -1.25), (-1.1, 0.1, 0.1), r_pole=(1, -0.6, 0.3))), ease_out),
				# (Round 2: out in front on the way back to the gun; the hand cut
				# through the chest at 0.50-0.55 s.)
				(0.47, stood(arms(bladed(-12, 4), (0.45, 0.55, -1.55), (-0.75, 0.55, -1.45), r_pole=(1, -0.6, 0.3)))),
			],
			end=(0.68, STAND_HOLD, ease_in_out),
		),
		UPPER,
		length=0.68,
		loop=False,
		step=KEY_STEP,
	)
)

# Underhand lob: lean in, the arm swings down and back, then forward and up
# soft, released at chest height.
add(
	Clip(
		"Lob",
		"Action4",
		spline_sequence(
			[
				(0.0, MOD_HOLD),
				# (Round 2: the free arm sat in a boxer's guard; it reaches out front now.)
				(0.14, stood(arms(bladed(-14, -14), (0.85, -0.45, 0.6), (-0.55, 0.65, -2.4), r_pole=(1, 0, 0.6)))),
				# (Round 2: the swing goes wide of the hip; it grazed the belly at 0.18 s.)
				(0.2, stood(arms(bladed(-12, -2), (1.05, -0.05, -0.55), (-0.65, 0.55, -2.1), r_pole=(1, -0.2, 0.4)))),
				(0.26, stood(arms(bladed(-8, 10), (0.4, 0.5, -1.55), (-0.75, 0.45, -1.7), r_pole=(0.9, -1, 0.1))), ease_in),
				(0.38, stood(arms(bladed(-6, 14), (0.35, 1.1, -1.45), (-0.8, 0.35, -0.7), r_pole=(0.9, -1, 0))), ease_out),
			],
			end=(0.62, STAND_HOLD, ease_in_out),
		),
		UPPER,
		length=0.62,
		loop=False,
	)
)


# Cast (Firewall): the free hand draws back low by the left hip, then shoves
# up and out to the front-left and holds, trembling, while the wall goes up.
# (Round 3: from the owner's angle, front-right and close, a straight shove
# came at the camera and kept about 57% of its travel on screen. Now it rises
# from the hip to face height (vertical travel keeps about 98%), goes a little
# left (across the screen), and the chest swings 30 degrees behind it, the
# left shoulder driving in.)
def cast_push(tremor):
	return stood(
		arms(
			bladed(-14, -14),
			(1.05, 0.95, 0.15),
			(-0.6 + 0.015 * tremor, 1.2 + 0.02 * tremor, -1.95),
			l_pole=(-1, -0.8, 0.2),
		)
	)


add(
	Clip(
		"Cast",
		"Action4",
		spline_sequence(
			[
				(0.0, MOD_HOLD),
				# (2026-11-20: the free hand drew back 0.3 studs less, it was inside
				# the chest at 0.08 s; and a key out in front on the way back to the
				# gun, the right hand cut through the chest at 0.82-0.88 s.)
				# (Round 3: drawn back low and out by the left hip, the left
				# shoulder back, so the shove travels up and across.)
				(0.1, stood(arms(bladed(-4, 16), (1.25, 0.95, -0.2), (-0.95, 0.2, 0.05), l_pole=(-1, -0.2, 0.6)))),
				(0.24, cast_push(0), ease_out),
				(0.4, cast_push(1)),
				(0.7, cast_push(-1)),
				(0.85, stood(arms(bladed(-4, -10), (0.75, 0.9, -1.25), (-0.5, 0.95, -1.9)))),
			],
			end=(1.08, STAND_HOLD, ease_in_out),
		),
		UPPER,
		length=1.08,
		loop=False,
	)
)

# Place: a quick drop onto the right knee, the item pressed to the floor in
# front, then back up to the gun (whole body: the legs kneel).
KNEEL_LEGS = {
	# (Review 1: a deep, forward kneel crumpled into a lump. Upright now: the
	# right knee down, the left knee up, the hand clearly reaching the floor.)
	# (Round 2, measured in the engine: the kneel buried the right knee 0.39
	# under the floor. Now down on the crouch's stance, no knee on the floor;
	# the body bends over to put the item down.)
	"hips": {"pos": (0, -1.12, 0.2), "rot": (-8, -4, 0)},
	"left_foot": {"pos": (-0.6, 0, -0.62), "yaw": 6, "pole": (-0.25, 0.4, -1), "clamp": True},
	"right_foot": {"pos": (0.62, 0.05, 0.62), "yaw": -12, "pole": (0.35, -0.5, -1), "clamp": True},
}
STAND_LEGS = {
	"hips": {"pos": (0, 0, 0), "rot": (0, 0, 0)},
	"left_foot": {"pos": (-0.58, 0, -0.12), "yaw": 6, "pole": (-0.2, 0.3, -1)},
	"right_foot": {"pos": (0.6, 0, 0.1), "yaw": -8, "pole": (0.2, -0.6, -1), "clamp": True},
}
add(
	Clip(
		"Place",
		"Action4",
		# (2026-11-20, on splines with both feet kept out of the floor: the
		# kneel sank a shin 0.14 and the press held dead still for 0.12 s; now
		# the hand keeps pressing down a touch while it is on the floor.)
		spline_sequence(
			[
				(0.0, grounded({**STAND_LEGS, **arms(bladed(-4, -8), MOD_HOLD_R, MOD_HOLD_L)})),
				(0.15, grounded({**KNEEL_LEGS, **arms(bladed(-28, -6), (0.55, -1.9, -1.15), (-0.85, -1.35, -0.95), r_pole=(1, 0.2, 0.4), l_pole=(-1, 0, 0.3))})),
				(0.28, grounded({**KNEEL_LEGS, **arms(bladed(-46, -4), (0.5, -2.85, -1.2), (-1.05, -2.15, -1.1), r_pole=(1, 0.3, 0.4), l_pole=(-1, 0, 0.3))})),
				(0.4, grounded({**KNEEL_LEGS, **arms(bladed(-48, -4), (0.52, -2.88, -1.26), (-1.07, -2.2, -1.12), r_pole=(1, 0.3, 0.4), l_pole=(-1, 0, 0.3))})),
				(0.58, grounded({**STAND_LEGS, **arms(bladed(-6, -10), (0.7, 0.4, -0.7), (-0.6, 0.3, -1.0))})),
			],
			end=(0.72, STAND_HOLD, ease_out),
			solver=solve_grounded,
		),
		ALL,
		length=0.72,
		loop=False,
	)
)

# Heal: pull the device in to the chest, then thrust it out at the target.
add(
	Clip(
		"Heal",
		"Action4",
		spline_sequence(
			[
				(0.0, MOD_HOLD),
				# (Round 3: from the owner's angle, front-right and close, the
				# straight thrust came at the camera. Now the device cocks back low
				# by the right hip, the right shoulder back, and sweeps up and in
				# to the front at shoulder height as the chest swings 30 degrees
				# behind it; the free arm swings back the other way. Seen in the
				# engine: any end in front of the chest put a big fist block over
				# the face at the owner's range, so it ends out front-right beside
				# the face (as round 2) and the read comes from the drop: it
				# starts low by the hip, so the push is mostly an upward sweep.)
				(0.08, stood(arms(bladed(2, -18), (1.1, 0.1, 0.35), (-0.7, 0.55, -1.5), r_pole=(1, -0.3, 0.6)))),
				# (Round 2: both arms crossed the chest at the thrust and it read as a
				# block; the device stays right of the chest's middle, the free arm
				# out to the side.)
				(0.18, stood(arms(bladed(-15, 12), (0.85, 1.0, -1.9), (-1.2, -0.05, 0.45), r_pole=(1, -0.6, 0.3), l_pole=(-1, -0.2, 0.6))), ease_out),
				(0.32, stood(arms(bladed(-13, 10), (0.88, 0.95, -1.82), (-1.2, 0.0, 0.4), r_pole=(1, -0.6, 0.3), l_pole=(-1, -0.2, 0.6)))),
				# Both hands come back to the gun out in front (they cut through the
				# chest at 0.43 s).
				(0.43, stood(arms(bladed(-9, -10), (0.65, 0.75, -1.6), (-0.75, 0.55, -1.55), r_pole=(1, -0.6, 0.3)))),
			],
			end=(0.6, STAND_HOLD, ease_in_out),
		),
		UPPER,
		length=0.6,
		loop=False,
	)
)


# Dashes: a planted lunge into the burst (hips and legs; the arms keep the
# gun): the body drops and leans the way it goes, the lead foot reaching,
# then springs back past upright and settles on its feet.
def dash(lean, lead):
	lx, lz = lead
	rest = {**STAND_LEGS, "hips": {"pos": (0, -0.07, 0), "rot": (0, 0, 0)}}
	hit = {
		"hips": {"pos": (0.26 * lx, -0.34, 0.26 * lz), "rot": lean},
		"right_foot": {"pos": (0.6 + 0.45 * max(lx, 0), 0, 0.1 + 0.5 * lz), "yaw": -8, "clamp": True},
		"left_foot": {"pos": (-0.58 + 0.45 * min(lx, 0), 0, -0.12 - 0.5 * lz), "yaw": 6, "clamp": True},
	}
	back = {**STAND_LEGS, "hips": {"pos": (0, -0.05, 0), "rot": tuple(-0.18 * a for a in lean)}}
	# Round 2 (2026-11-21, owner: "we really have to work on the mods"): the
	# lunge held dead still from 0.06 to 0.2 s. Now on splines: a quick
	# compression first, the lunge keeps sinking and leaning a touch deeper
	# through the burst (the trailing foot dragging), then springs back past
	# upright and settles.
	load = {**rest, "hips": {"pos": (-0.04 * lx, -0.14, -0.04 * lz), "rot": tuple(0.12 * a for a in lean)}}
	deep = {
		**hit,
		"hips": {"pos": (0.31 * lx, -0.41, 0.31 * lz), "rot": tuple(1.15 * a for a in lean)},
		"right_foot": {**hit["right_foot"], "pos": (hit["right_foot"]["pos"][0] - 0.06 * lx, 0, hit["right_foot"]["pos"][2] - 0.06 * lz)},
		"left_foot": {**hit["left_foot"], "pos": (hit["left_foot"]["pos"][0] - 0.06 * lx, 0, hit["left_foot"]["pos"][2] - 0.06 * lz)},
	}
	keys = [(0.0, rest), (0.03, load), (0.08, hit), (0.2, deep), (0.3, back), (0.38, rest)]
	return spline_sequence([(t, grounded(k)) for t, k in keys], solver=solve_grounded)


for name, lean, lead in (
	# (Round 2, seen in the engine: the hips' tilt carries the whole upper body,
	# so an 18-degree lean pointed the gun at the floor for the burst. About
	# half the tilt now; the lunge comes more from the hips dropping and moving.)
	("DashForward", (-9, 0, 0), (0, -1)),
	("DashBack", (7, 0, 0), (0, 1)),
	("DashLeft", (-3, 4, 9), (-1, 0)),
	("DashRight", (-3, -4, -9), (1, 0)),
):
	add(Clip(name, "Action4", dash(lean, lead), LOWER, length=0.38, loop=False))

# Updraft: the knees snap up on the launch, then the legs drop into the fall.
UPDRAFT_TUCK = {
	"hips": {"pos": (0, 0.1, 0), "rot": (-11, 0, 0)},  # (Round 2: was -22; the gun pointed at the floor)
	"right_foot": {"pos": (0.5, 1.15, -0.25), "yaw": -8, "pole": (0.2, 0.3, -1)},
	"left_foot": {"pos": (-0.5, 0.95, 0.0), "yaw": 6, "pole": (-0.2, 0.3, -1)},
}
UPDRAFT_TUCK_HIGH = {
	"hips": {"pos": (0, 0.14, 0), "rot": (-13, 0, 0)},
	"right_foot": {"pos": (0.5, 1.3, -0.35), "yaw": -8, "pole": (0.2, 0.3, -1)},
	"left_foot": {"pos": (-0.5, 1.1, -0.08), "yaw": 6, "pole": (-0.2, 0.3, -1)},
}
add(
	Clip(
		"Updraft",
		"Action4",
		# Round 2: the tuck held dead still from 0.08 to 0.32 s; now the knees
		# keep coming up (the launch carries them) before the legs drop.
		pose_spline(
			[
				(0.0, solve(STAND)),
				(0.08, solve(UPDRAFT_TUCK)),
				(0.3, solve(UPDRAFT_TUCK_HIGH)),
				(0.6, solve(AIR_FALL)),
			]
		),
		LOWER,
		length=0.6,
		loop=False,
	)
)

# Updraft Crash Down: the dive (looped while diving), pitched at the ground,
# legs trailing, the gun pointed down ahead, the free fist drawn back low and
# ready; then the landing on the right knee with the free fist on the floor,
# the gun out wide, and back up.
DIVE = {
	"hips": {"pos": (0, 0, 0), "rot": (-32, 0, 0)},
	"right_foot": {"pos": (0.45, 0.55, 1.0), "yaw": -6, "pole": (0.2, -0.4, 1)},
	"left_foot": {"pos": (-0.45, 0.75, 0.8), "yaw": 6, "pole": (-0.2, -0.4, 1)},
	"chest": (-22, 0, 0),
	"head": (-30, 0, 0),
	"gun": {"shoulder": (-45, 0, 0)},
	"right_pole": (0.8, -0.6, 0.6),
	"left_arm": {"tip": (-0.9, 0.35, -0.55)},
	"left_pole": (-1, 0.1, 0.6),
}


def dive(t):
	w = math.sin(TAU * t / 0.4)
	return solve({**DIVE, "hips": {"pos": (0, 0, 0), "rot": (-32 + 2 * w, 0, 1.5 * w)}})


add(Clip("UpdraftSlam", "Action4", dive, ALL, length=0.4))

IMPACT = {
	# (Round 2, measured in the engine: the knee-down landing buried the right
	# knee 0.73 under the floor, and any kneel high enough to clear it left the
	# fist a stud off the floor. Now a three-point landing: both feet planted
	# deep on the crouch's stance (no knee on the floor), the body bent over
	# with the free fist down by the floor, the gun out wide.)
	"hips": {"pos": (0, -1.12, 0.2), "rot": (-12, -6, 0)},
	"left_foot": {"pos": (-0.6, 0, -0.62), "yaw": 6, "pole": (-0.25, 0.4, -1), "clamp": True},
	"right_foot": {"pos": (0.62, 0.05, 0.62), "yaw": -12, "pole": (0.35, -0.5, -1), "clamp": True},
	"chest": (-40, 6, 0),
	"head": (2, 0, 0),
	"gun": {"shoulder": (-8, -45, 0)},
	"right_pole": (1, -0.4, 0.6),
	"left_arm": {"tip": (-1.0, -2.88, -0.65)},
	"left_pole": (-1, 0.4, 0.2),
}
RISE = {**IMPACT, "hips": {"pos": (0, -1.05, 0.18), "rot": (-10, -5, 0)}, "chest": (-30, 4, 0), "head": (4, 0, 0)}
RISE_HALF = {
	**RISE,
	"hips": {"pos": (0, -0.7, 0.1), "rot": (-10, 0, 0)},
	"right_foot": {"pos": (0.62, 0, 0.45), "yaw": -10, "clamp": True},
	"left_foot": {"pos": (-0.6, 0, -0.35), "yaw": 8},
	"chest": (-10, 0, 0),
	"gun": {"shoulder": (-6, -15, 0)},
	"left_arm": {"tip": (-0.7, -0.4, -0.8)},
}
add(
	Clip(
		"UpdraftSlamLand",
		"Action4",
		spline_sequence(
			[
				(0.0, grounded(DIVE)),
				(0.11, grounded(IMPACT), ease_out),  # (0.1: the fist met the floor at 946 studs/s², over the 900 pop line)
				(0.34, grounded(RISE), ease_in_out),
				(0.5, grounded(RISE_HALF), ease_in_out),
				(0.62, grounded({**RISE_HALF, **STAND_LEGS, "chest": (-4, 0, 0)}), ease_in_out),
			],
			solver=solve_grounded,
			end=(0.7, STAND_HOLD, ease_out),
		),
		ALL,
		length=0.7,
		loop=False,
	)
)

# Flinch: a hit knocks the hips back and the head snaps, then a quick recovery
# that overshoots a touch (over everything at FLINCH_WEIGHT; hips and head
# only, the run keeps the legs).
FLINCH_REST = solve({"hips": {"pos": (0, -0.07, 0), "rot": (0, 0, 0)}})
FLINCH_HIT = solve({"hips": {"pos": (0, -0.08, 0.12), "rot": (10, 0, -4)}, "head_local": (14, 0, 3)})
FLINCH_BACK = solve({"hips": {"pos": (0, -0.06, -0.02), "rot": (-2, 0, 1)}, "head_local": (-3, 0, 0)})
add(
	Clip(
		"Flinch",
		"Action4",
		# Round 2: on splines with the hit as an impact (it arrives at speed
		# and rebounds at speed; it eased to a stop at every key before).
		pose_spline([(0.0, FLINCH_REST), (0.05, FLINCH_HIT), (0.2, FLINCH_BACK), (0.34, FLINCH_REST)], hits=(0.05,)),
		["LowerTorso", "Head"],
		length=0.34,
		loop=False,
	)
)

# Death (on the falling copy; DeathFxController tips it over after the
# buckle, Config/Juice DEATH.buckle = 0.28): the knees go, the chest slumps,
# the head drops and the arms hang, the gun sagging in the hand.
DEATH_BUCKLE = {
	"hips": {"pos": (0, -0.75, 0.18), "rot": (-14, 0, 5)},
	"right_foot": {"pos": (0.6, 0, 0.1), "yaw": -8, "clamp": True},
	"left_foot": {"pos": (-0.58, 0, -0.12), "yaw": 5, "clamp": True},
	"chest": euler(-28, -8, -4),
	"head": (-36, 0, 6),
	"gun": {"shoulder": (-50, 10, 18)},
	"right_pole": (1, -0.2, 0.4),
	"left_arm": {"tip": (-0.95, -1.9, -0.15)},
	"left_pole": (-1, 0.1, 0.3),
}
DEATH_SLUMP = {
	**DEATH_BUCKLE,
	"hips": {"pos": (0, -0.95, 0.24), "rot": (-20, 0, 7)},
	"chest": euler(-40, -10, -6),
	"head": (-48, 0, 10),
	# The arms hang lower as the body sinks (review 1: an arm stuck out
	# sideways at the waist, its target not sinking with the body).
	"gun": {"shoulder": (-62, 10, 18)},
	"left_arm": {"tip": (-0.95, -2.2, -0.2)},
}
# The hold, written the way the buckle is (gun about the shoulder, the free
# hand by its block end, the buckle's feet): two different ways of placing
# the arms can't blend, and the switch threw the hands 1.5 studs in a frame
# (tp_measure, 2026-11-20). HOLD_OFFSET is this hold's gun from the shoulder.
DEATH_START = {
	**DEATH_BUCKLE,
	"hips": {"pos": (0, 0, 0), "rot": (0, 0, 0)},
	"right_foot": {**DEATH_BUCKLE["right_foot"], "yaw": -8},
	"left_foot": {**DEATH_BUCKLE["left_foot"], "yaw": 6},
	"chest": HOLD["chest"],
	"head": HOLD["head"],
	"gun": {"shoulder": (0, 0, 0)},
	"right_pole": HOLD["right_pole"],
	"left_arm": {"tip": tip_of(fk(HOLD_POSE), "Left")},
	"left_pole": HOLD["left_pole"],
}
add(
	Clip(
		"Death",
		"Action4",
		spline_sequence([(0.0, DEATH_START), (0.28, DEATH_BUCKLE, ease_in), (0.6, DEATH_SLUMP, ease_out)]),
		ALL,
		length=0.6,
		loop=False,
	)
)


# Victory (the winners on the match-end scene, looped): the gun held up high,
# two fist pumps with the free hand, a bounce in the knees on each.
def victory(t):
	# (Review 1: both hands up in front of the face hid the head, and the
	# knees knocked in. Now the gun goes up beside the head on the right, the
	# fist pumps high on the left, the knees point out over the feet.)
	ph = (t % 1.6) / 1.6
	pump = max(0.0, math.sin(TAU * 2 * ph))
	bounce = 0.05 * pump
	return solve(
		{
			# (Review 3: deeper knees with the poles wide read as bow-legged.)
			"hips": {"pos": (0, -0.04 - bounce, 0), "rot": (2, 0, 0)},
			"right_foot": {"pos": (0.6, 0, 0.05), "yaw": -10, "pole": (0.15, 0, -1), "clamp": True},
			"left_foot": {"pos": (-0.6, 0, -0.05), "yaw": 8, "pole": (-0.15, 0, -1), "clamp": True},
			# (Review 2, measured in the engine: a 12-degree lean back put the head
			# 0.6 behind the raised fists, so from the front the arms hid the
			# face. Upright now, the fists wide and level with the head.)
			"chest": bladed(2 + 2 * pump, -4),
			"head": (6 + 3 * pump, 0, 0),
			"gun": {"shoulder": (72, -14, -16)},
			"right_pole": (1, -0.5, 0.3),
			"left_arm": {"tip": (-1.8, 0.9 + 1.2 * pump, 0.15)},
			"left_pole": (-1, -0.6, 0.2),
		}
	)


add(Clip("Victory", "Action4", victory, ALL, length=1.6))


GUN = {"Pistol": "Sheriff", "SprintPistol": "Sheriff", "Knife": "Knife", "SprintKnife": "Knife"}
NO_GUN = ("Idle",)


def gun_for(name):
	if name in NO_GUN:
		return "None"
	for key, gun in GUN.items():
		if name.split("+")[-1].startswith(key):
			return gun
	return "Vandal"


# Preview / export ---------------------------------------------------------------


def full_pose(clip, t):
	"""The clip's pose with what plays under it in the game filled in, so the
	preview shows a whole body: a hold over legs-only clips, standing legs
	under arms-only ones."""
	pose = dict(clip.pose(t))
	if "LowerTorso" not in clip.parts:
		under = solve(STAND)
		for name in LOWER:
			pose[name] = under[name]
	if "UpperTorso" not in clip.parts:
		for name in UPPER:
			pose[name] = HOLD_POSE[name]
	return pose


def sheet(args):
	# Each pose is laid out once per view: 0 = from the front, 90 = its right
	# side, 180 = from behind, -90 = its left side (--views=0,90).
	views = [0, 90]
	rows = []
	for arg in args:
		if arg.startswith("--views="):
			views = [int(v) for v in arg[8:].split(",")]
			continue
		name, _, times = arg.partition("@")
		gun = None
		if ":" in name:
			name, gun = name.split(":")
		# "SprintRun+Sprint": clips layered the way the game plays them.
		layers = [CLIPS[n] for n in name.split("+")]
		clip = layers[0]
		if times.startswith("n"):
			n = int(times[1:])
			ts = [clip.length * i / n for i in range(n)]
		elif times:
			ts = [float(t) for t in times.split(",")]
		else:
			ts = [0.0]
		for t in ts:
			pose = full_pose(clip, t)
			for layer in layers[1:]:
				over = layer.pose(t)
				for part in layer.parts:
					pose[part] = over[part]
			world = fk(pose)
			parts = []
			for part, m in world.items():
				nums = list(m[:3, 3]) + list(m[:3, :3].flatten())
				parts.append(part + ":" + ",".join(("%.3f" % n).rstrip("0").rstrip(".") for n in nums))
			for yaw in views:
				rows.append("%s@%.2f|%s|%d|%s" % (name, t, gun or gun_for(name), yaw, ";".join(parts)))
	with open(PREVIEW, "w", encoding="utf-8", newline="\n") as f:
		f.write("--!strict\n-- Temporary: poses for tools/studio/TpPreviewSheet.luau (tools/anim/tp_clips.py sheet). Delete when done.\nreturn [==[\n")
		f.write("\n".join(rows))
		f.write("\n]==]\n")
	print("wrote %d poses to %s" % (len(rows), PREVIEW))


def export(names):
	sys.path.insert(0, os.path.join(ROOT, "tools", "studio"))
	import tempfile

	import pose_text_to_rbxm

	with tempfile.TemporaryDirectory() as tmp:
		for name in names or list(CLIPS):
			clip = CLIPS[name]
			line = "GG_" + clip.text()
			# (rojo's build now and then fails on a file another process has
			# open; a stale file uploaded as new is worse than a retry.)
			for attempt in range(4):
				try:
					print(pose_text_to_rbxm.build(line, tmp))
					break
				except Exception:
					if attempt == 3:
						raise
					time.sleep(0.5)


def main():
	cmd = sys.argv[1] if len(sys.argv) > 1 else "list"
	if cmd == "list":
		for name, clip in CLIPS.items():
			print("%-18s %-8s %.2fs %s" % (name, clip.priority, clip.length, "loop" if clip.loop else "once"))
	elif cmd == "sheet":
		sheet(sys.argv[2:])
	elif cmd == "export":
		export(sys.argv[2:])


if __name__ == "__main__":
	main()
