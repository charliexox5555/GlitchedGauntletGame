"""Box geometry for the win cutscene clip checks (win_check, win_fix): the
R15 block body's parts and the long gun as oriented boxes, a separating-axis
overlap depth, and every arm / gun overlap with the body in one pose."""

import math

import numpy as np

from tp_rig import GRIP_GUN, KNEE_TO_SOLE

# (centre offset in the part's frame, size)
BOX = {
	"LowerTorso": ((0, 0, 0), (2, 0.4, 1)),
	"UpperTorso": ((0, 0, 0), (2, 1.6, 1)),
	"Head": ((0, 0, 0), (1.2, 1.2, 1.2)),
	"RightUpperArm": ((0, 0, 0), (1, 1.17, 1)),
	"LeftUpperArm": ((0, 0, 0), (1, 1.17, 1)),
	"RightLowerArm": ((0, -0.1, 0), (1, 1.05, 1)),
	"LeftLowerArm": ((0, -0.1, 0), (1, 1.05, 1)),
	"RightHand": ((0, 0, 0), (1, 0.3, 1)),
	"LeftHand": ((0, 0, 0), (1, 0.3, 1)),
	"RightUpperLeg": ((0, 0, 0), (1, 0.84, 1)),
	"LeftUpperLeg": ((0, 0, 0), (1, 0.84, 1)),
	"RightLowerLeg": ((0, 0.379 - KNEE_TO_SOLE / 2, 0), (1, KNEE_TO_SOLE, 1)),
	"LeftLowerLeg": ((0, 0.379 - KNEE_TO_SOLE / 2, 0), (1, KNEE_TO_SOLE, 1)),
}
GUN = ((0, 0.05, -0.9), (0.26, 0.55, 3.4))

BODY = ["UpperTorso", "LowerTorso", "Head", "RightUpperLeg", "LeftUpperLeg", "RightLowerLeg", "LeftLowerLeg"]
ARMS = {
	"Right": ["RightUpperArm", "RightLowerArm", "RightHand"],
	"Left": ["LeftUpperArm", "LeftLowerArm", "LeftHand"],
}
# joint neighbours (touching by design)
SKIP = {
	("RightUpperArm", "UpperTorso"),
	("LeftUpperArm", "UpperTorso"),
}
SHRINK = 0.04  # blocks that only kiss don't count


def box(world, part, spec=None):
	off, size = spec or BOX[part]
	m = world[part] if isinstance(part, str) and part in world else part
	r = m[:3, :3]
	c = m[:3, 3] + r @ np.array(off, dtype=float)
	h = np.array(size, dtype=float) / 2 - SHRINK
	return c, r, h


def overlap(a, b):
	"""Penetration depth of two oriented boxes (0 = apart)."""
	ca, ra, ha = a
	cb, rb, hb = b
	d = cb - ca
	axes = [ra[:, i] for i in range(3)] + [rb[:, i] for i in range(3)]
	for i in range(3):
		for j in range(3):
			x = np.cross(ra[:, i], rb[:, j])
			n = np.linalg.norm(x)
			if n > 1e-6:
				axes.append(x / n)
	depth = math.inf
	for ax in axes:
		pa = sum(ha[k] * abs(float(np.dot(ra[:, k], ax))) for k in range(3))
		pb = sum(hb[k] * abs(float(np.dot(rb[:, k], ax))) for k in range(3))
		o = pa + pb - abs(float(np.dot(d, ax)))
		if o <= 0:
			return 0.0
		depth = min(depth, o)
	return depth


def wrist(world, side):
	"""Degrees between the forearm and the hand (0 = straight)."""
	a = world[side + "LowerArm"][:3, :3]
	b = world[side + "Hand"][:3, :3]
	c = (np.trace(a.T @ b) - 1) / 2
	return math.degrees(math.acos(max(-1.0, min(1.0, c))))


def frame_hits(world):
	hits = []
	boxes = {p: box(world, p) for p in BOX}
	gun = world["RightHand"] @ GRIP_GUN
	gc, gr, gh = gun[:3, 3] + gun[:3, :3] @ np.array(GUN[0]), gun[:3, :3], np.array(GUN[1]) / 2 - SHRINK
	gun_box = (gc, gr, gh)
	for side, parts in ARMS.items():
		other = ARMS["Left" if side == "Right" else "Right"]
		for p in parts:
			for q in BODY + other:
				if (p, q) in SKIP:
					continue
				dep = overlap(boxes[p], boxes[q])
				if dep > 0:
					hits.append((p, q, dep))
	# (not the gun against its own upper arm: the stock rests there in every
	# hold, the game's rifle hold included)
	for q in BODY + ARMS["Left"]:
		dep = overlap(gun_box, boxes[q])
		if dep > 0:
			hits.append(("Gun", q, dep))
	return hits


