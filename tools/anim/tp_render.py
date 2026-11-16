"""Quick offline pictures of tp_clips poses (no Studio needed): each part a
shaded block, drawn from the side and the front (or any yaw), a strip of
frames per clip, the floor as a line. For looking at a clip while Studio is
busy; the engine review still decides the grade.

    python -I tools/anim/tp_render.py out.png RunL@n8 Jump@0,0.1,0.2 --views=90,0
    python -I tools/anim/tp_render.py out.png RunL@n8 --views=90,0 --trail   # ground moves under the body

View yaw: 0 = from the front, 90 = from the character's right side, 180 =
from behind, -90 = its left side. `--trail` slides each frame along the
ground by the clip's travel (tp_clips.GROUND), so a planted foot should
stay put across a strip.
"""

import math
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(__file__))

import matplotlib  # noqa: E402

matplotlib.use("Agg")
import matplotlib.pyplot as plt  # noqa: E402
from matplotlib.patches import Polygon  # noqa: E402

import tp_clips  # noqa: E402
from tp_rig import FLOOR, KNEE_TO_SOLE, fk  # noqa: E402

# Block per part: (centre offset in the part's frame, size), the R15 block
# body's parts with the shin and foot drawn as one block (they are rigid).
BOXES = {
	"LowerTorso": ((0, 0, 0), (2, 0.4, 1)),
	"UpperTorso": ((0, 0, 0), (2, 1.6, 1)),
	"Head": ((0, 0, 0), (1.2, 1.2, 1.2)),
	"RightUpperArm": ((0, 0, 0), (1, 1.17, 1)),
	"LeftUpperArm": ((0, 0, 0), (1, 1.17, 1)),
	"RightLowerArm": ((0, -0.1, 0), (1, 1.25, 1)),
	"LeftLowerArm": ((0, -0.1, 0), (1, 1.25, 1)),
	"RightUpperLeg": ((0, 0, 0), (1, 0.84, 1)),
	"LeftUpperLeg": ((0, 0, 0), (1, 0.84, 1)),
	"RightLowerLeg": ((0, 0.379 - KNEE_TO_SOLE / 2, 0), (1, KNEE_TO_SOLE, 1)),
	"LeftLowerLeg": ((0, 0.379 - KNEE_TO_SOLE / 2, 0), (1, KNEE_TO_SOLE, 1)),
}
COLOURS = {
	"Right": np.array([0.85, 0.45, 0.35]),
	"Left": np.array([0.35, 0.55, 0.85]),
	"Torso": np.array([0.6, 0.6, 0.6]),
	"Head": np.array([0.95, 0.8, 0.45]),
}
FACES = [(0, 1, 3, 2), (4, 5, 7, 6), (0, 1, 5, 4), (2, 3, 7, 6), (0, 2, 6, 4), (1, 3, 7, 5)]


def colour(part):
	if part == "_gun":
		return np.array([0.18, 0.18, 0.2])
	for key in ("Right", "Left", "Head"):
		if part.startswith(key):
			return COLOURS[key]
	return COLOURS["Torso"]


GUN_BOXES = {
	# a stand-in gun drawn on the right hand's grip: (grip, centre in the gun frame, size)
	"pistol": (None, (0, 0.05, -0.35), (0.22, 0.5, 1.15)),
	"long": (None, (0, 0.05, -0.9), (0.26, 0.55, 3.4)),
	"knife": (None, (0, 0, -0.55), (0.08, 0.3, 1.1)),
}


def gun_world(world, kind):
	from tp_rig import GRIP_GUN, GRIP_KNIFE, GRIP_SIDEARM

	grip = {"pistol": GRIP_SIDEARM, "long": GRIP_GUN, "knife": GRIP_KNIFE}[kind]
	return world["RightHand"] @ grip


def draw(ax, world, yaw, shift, gun=None):
	"""Orthographic view: camera turned `yaw` degrees about Y from the front."""
	a = math.radians(yaw)
	# Camera right / forward (into the screen) in root space; the front view
	# looks along +Z (the character faces -Z).
	right = np.array([-math.cos(a), 0, math.sin(a)])
	into = np.array([math.sin(a), 0, math.cos(a)])
	light = np.array([0.4, 0.8, -0.45])
	light /= np.linalg.norm(light)
	polys = []
	items = list(BOXES.items())
	if gun:
		world = dict(world)
		world["_gun"] = gun_world(world, gun)
		items.append(("_gun", (GUN_BOXES[gun][1], GUN_BOXES[gun][2])))
	for part, (off, size) in items:
		m = world[part]
		c = m[:3, 3] + m[:3, :3] @ np.array(off) + shift
		h = np.array(size) / 2
		corners = [c + m[:3, :3] @ (h * np.array([sx, sy, sz])) for sx in (-1, 1) for sy in (-1, 1) for sz in (-1, 1)]
		for f in FACES:
			pts = [corners[i] for i in f]
			n = np.cross(pts[1] - pts[0], pts[2] - pts[0])
			if np.linalg.norm(n) < 1e-9:
				continue
			n /= np.linalg.norm(n)
			centre = np.mean(pts, axis=0)
			if np.dot(n, centre - c) < 0:
				n = -n
			if np.dot(n, into) > 0:
				continue  # facing away
			shade = 0.55 + 0.45 * max(0.0, float(np.dot(n, light)))
			depth = float(np.dot(centre, into))
			xy = [(float(np.dot(p, right)), p[1]) for p in pts]
			polys.append((depth, xy, np.clip(colour(part) * shade, 0, 1)))
	for _, xy, col in sorted(polys, key=lambda p: -p[0]):
		ax.add_patch(Polygon(xy, closed=True, facecolor=col, edgecolor=(0.15, 0.15, 0.15), linewidth=0.4))


def main():
	out = sys.argv[1]
	views = [90, 0]
	trail = False
	gun = None
	specs = []
	for arg in sys.argv[2:]:
		if arg.startswith("--views="):
			views = [int(v) for v in arg[8:].split(",")]
		elif arg == "--trail":
			trail = True
		elif arg.startswith("--gun="):
			gun = arg[6:]
		else:
			specs.append(arg)
	rows = []
	for spec in specs:
		name, _, times = spec.partition("@")
		layers = [tp_clips.CLIPS[n] for n in name.split("+")]
		clip = layers[0]
		if times.startswith("n"):
			n = int(times[1:])
			ts = [clip.length * i / n for i in range(n)]
		elif times:
			ts = [float(t) for t in times.split(",")]
		else:
			ts = [0.0]
		for yaw in views:
			rows.append((name, yaw, clip, layers, ts))
	cols = max(len(r[4]) for r in rows)
	fig, axes = plt.subplots(len(rows), cols, figsize=(1.9 * cols, 2.6 * len(rows)), squeeze=False)
	for r, (name, yaw, clip, layers, ts) in enumerate(rows):
		travel = getattr(tp_clips, "GROUND", {}).get(name.split("+")[0])
		for c in range(cols):
			ax = axes[r][c]
			ax.set_aspect("equal")
			ax.axis("off")
			if c >= len(ts):
				continue
			t = ts[c]
			pose = tp_clips.full_pose(clip, t)
			for layer in layers[1:]:
				over = layer.pose(t)
				for part in layer.parts:
					pose[part] = over[part]
			draw(ax, fk(pose), yaw, np.zeros(3), gun)
			ax.plot([-3, 3], [-FLOOR, -FLOOR], color="k", linewidth=1)
			if trail and travel is not None:
				a = math.radians(yaw)
				rvec = np.array([-math.cos(a), 0, math.sin(a)])
				g = -np.array([travel[0], 0, travel[1]]) * t
				along = float(np.dot(g, rvec))
				# Ground marks every half stud, moving with the ground.
				for k in range(-12, 13):
					x = ((0.5 * k + along + 6) % 12) - 6
					ax.plot([x, x], [-FLOOR - 0.2, -FLOOR], color="k", linewidth=0.6)
			ax.set_xlim(-2.8, 2.8)
			ax.set_ylim(-3.3, 2.6)
			ax.set_title("%s %d° t=%.2f" % (name, yaw, t), fontsize=6)
	plt.tight_layout()
	plt.savefig(out, dpi=110)
	print("wrote", out)


if __name__ == "__main__":
	main()
