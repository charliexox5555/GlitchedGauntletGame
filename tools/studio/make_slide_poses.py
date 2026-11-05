"""The third-person slide (GG_SlideIn, GG_Slide, GG_SlideOut) as pose text for
pose_text_to_rbxm.py, checked against the ground with a forward-kinematics
model of the R15 rig (2026-11-04, lane D):

    python tools/studio/make_slide_poses.py > slides.txt
    python tools/studio/pose_text_to_rbxm.py slides.txt

A full-body slide down on the floor: hips ~0.18 studs off the ground, body
leaned back ~34 deg (the chest curled forward so the gun still points ahead),
the lead (right) leg out with the knee soft and the heel on the floor, the
trailing leg bent out to the side with the shin down. No limb passes through
another except the chest box against the raised thighs at the hip crease
(0.27-0.30 studs, as in any seated R15 pose). In: a quick dip with the lead leg kicking out, an
overshoot below the hold, settle (0.24 s). Out: the lead foot plants under the
hips and drives up into the run (0.3 s). Replaces the kneeling scoot from
MakeSlideAnimations.luau, whose folded leg sank 0.8 studs into the floor with
the hips still 0.4 up.

Joint values: { pitch, yaw, roll[, x, y, z] }, degrees / studs, joint
Transforms in CFrame.fromEulerAnglesYXZ order (the Make*Animations
convention). The rig numbers are a standard R15 avatar's rig attachments.
Run with --check to print each key's lowest point per part (0 = the floor).
"""

import math
import sys

import numpy as np

# part: (parent, attachment in parent, attachment in part, part size)
RIG = {
	"LowerTorso": ("HRP", (0, -1.036, 0), (0, -0.315, 0.1), (1.70, 0.566, 0.95)),
	"UpperTorso": ("LowerTorso", (0, 0.085, 0.1), (0, -0.744, 0.044), (1.82, 1.77, 1.11)),
	"RightUpperLeg": ("LowerTorso", (0.5, -0.279, 0.1), (0.076, 0.426, 0.058), (0.76, 1.38, 0.77)),
	"RightLowerLeg": ("RightUpperLeg", (0.027, -0.547, -0.051), (0.005, 0.352, -0.154), (0.74, 1.08, 0.82)),
	"RightFoot": ("RightLowerLeg", (0.002, -0.336, 0.071), (-0.005, 0.033, 0.256), (0.84, 0.63, 1.24)),
	"LeftUpperLeg": ("LowerTorso", (-0.5, -0.279, 0.1), (-0.076, 0.426, 0.058), (0.76, 1.38, 0.77)),
	"LeftLowerLeg": ("LeftUpperLeg", (-0.026, -0.547, -0.051), (-0.005, 0.352, -0.154), (0.74, 1.08, 0.82)),
	"LeftFoot": ("LeftLowerLeg", (-0.002, -0.336, 0.071), (0.004, 0.033, 0.256), (0.84, 0.63, 1.24)),
}
ROOT_HEIGHT = 3.0075  # HumanoidRootPart centre: HipHeight 2.0075 + half its 2-stud height


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


def lowest(frame):
	world = {"HRP": mat(p=(0, ROOT_HEIGHT, 0))}
	out = {}
	for name, (parent, a0, a1, size) in RIG.items():
		v = frame.get(name, (0, 0, 0))
		t = mat(yxz(*v[:3]), v[3:6] if len(v) >= 6 else (0, 0, 0))
		world[name] = world[parent] @ mat(p=a0) @ t @ np.linalg.inv(mat(p=a1))
		h = [s / 2 for s in size]
		corners = [world[name] @ np.array([x, y, z, 1]) for x in (-h[0], h[0]) for y in (-h[1], h[1]) for z in (-h[2], h[2])]
		out[name] = round(min(c[1] for c in corners), 2)
	return out


def hold(chatter=0.0):
	"""The slide hold; `chatter` (-1..1) is the scrape buzz in the hips and heel.
	Re-solved 2026-11-05 with a body-overlap check (LihFolk quality-score
	animation gate): the trailing leg goes out to the side instead of folding
	through the lead thigh (it overlapped it by 0.37 studs)."""
	return {
		"LowerTorso": (33.5, 0, 6 + chatter * 1.5, 0, -1.54 - abs(chatter) * 0.03, 0.35),
		"UpperTorso": (-24, -8, -10 - chatter * 0.8),
		"RightUpperLeg": (78 + chatter * 2, -21, -3),
		"RightLowerLeg": (-40 - chatter * 3, 0, 0),
		"RightFoot": (-29 + chatter * 4, 0, 0),
		"LeftUpperLeg": (88, 25, 31),
		"LeftLowerLeg": (-60, 0, 0),
		"LeftFoot": (-10, 0, 0),
	}


# Mid-sprint, where a slide starts and the run picks up after one.
STRIDE = {
	"LowerTorso": (-10, 0, 0, 0, -0.2, 0),
	"UpperTorso": (4, 0, 0),
	"RightUpperLeg": (32, 0, 0),
	"RightLowerLeg": (-44, 0, 0),
	"RightFoot": (10, 0, 0),
	"LeftUpperLeg": (-16, 0, 0),
	"LeftLowerLeg": (-52, 0, 0),
	"LeftFoot": (22, 0, 0),
}
# Anticipation: the hips dip, the lead leg kicks out, the trailing knee turns out.
KICK = {
	"LowerTorso": (12, 0, 5, 0, -0.79, 0.15),
	"UpperTorso": (-12, -4, -4),
	"RightUpperLeg": (58, 0, -3),
	"RightLowerLeg": (-6, 0, 0),
	"RightFoot": (-30, 0, 0),
	"LeftUpperLeg": (44, 6, 32),
	"LeftLowerLeg": (-111, 0, 0),
	"LeftFoot": (38, 0, 0),
}
# Overshoot: lower and further back than the hold, then settle into it.
DROP = dict(hold())
DROP["LowerTorso"] = (37, 0, 7, 0, -1.6, 0.4)
DROP["UpperTorso"] = (-27, -9, -11)
# Out: the lead foot plants under the hips, then drives up, chest forward.
PLANT = {
	"LowerTorso": (4, 0, 6, 0, -0.98, 0.15),
	"UpperTorso": (-6, -4, -4),
	"RightUpperLeg": (72, 0, -3),
	"RightLowerLeg": (-103, 0, 0),
	"RightFoot": (36, 0, 0),
	"LeftUpperLeg": (62, 8, 37),
	"LeftLowerLeg": (-124, 0, 0),
	"LeftFoot": (43, 0, 0),
}
RISE = {
	"LowerTorso": (-12, 0, 0, 0, -0.26, 0),
	"UpperTorso": (6, 0, 0),
	"RightUpperLeg": (55, 0, 0),
	"RightLowerLeg": (-42, 0, 0),
	"RightFoot": (11, 0, 0),
	"LeftUpperLeg": (-28, 0, 0),
	"LeftLowerLeg": (-44, 0, 0),
	"LeftFoot": (14, 0, 0),
}


def enc(frame, style=None):
	parts = []
	for name, v in frame.items():
		s = name + ":" + ",".join("%.2f" % x for x in v)
		parts.append(s + ("@" + style if style else ""))
	return ";".join(parts)


def clip(name, priority, loop, keys):
	length = keys[-1][0]
	body = "|".join("%g>%s" % (t, enc(f, style)) for t, f, style in keys)
	return "%s|%s|%d|%g|%s" % (name, priority, 1 if loop else 0, length, body)


def main():
	if "--check" in sys.argv:
		for name, f in [("hold", hold()), ("kick", KICK), ("drop", DROP), ("plant", PLANT), ("rise", RISE)]:
			print(name, lowest(f))
		return
	print(clip("GG_SlideIn", "Action4", False, [(0, STRIDE, None), (0.07, KICK, "Cubic/Out"), (0.15, DROP, "Cubic/InOut"), (0.24, hold(), None)]))
	print(clip("GG_Slide", "Action3", True, [(0, hold(0), None), (0.06, hold(1), None), (0.13, hold(-0.6), None), (0.19, hold(0.4), None), (0.26, hold(0), None)]))
	print(clip("GG_SlideOut", "Action4", False, [(0, hold(), None), (0.1, PLANT, "Cubic/Out"), (0.2, RISE, "Cubic/InOut"), (0.3, STRIDE, None)]))


if __name__ == "__main__":
	main()
