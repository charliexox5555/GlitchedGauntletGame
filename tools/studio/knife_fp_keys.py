"""First-person knife attack keys (Config/Viewmodel TRACKS Slash1-3,
HeavyStab), solved from what should be seen on screen (2026-11-05, lane F).

    python -I tools/studio/knife_fp_keys.py            # Luau key lines to paste
    python -I tools/studio/knife_fp_keys.py --check    # blade tip on screen per key

Each key is written as: where the grip is (camera space, studs: x right,
y up, z back), which way the blade points, and which way the edge faces (it
leads the cut). The tracks are `screen` tracks: ViewmodelController turns
them about the grip in camera axes, so a key's offset is grip - REST_GRIP and
its rotation is the one taking the rest blade frame to the wanted one,
written as CFrame.Angles(x, y, z) degrees.

REST_* were measured in play (Studio, 2026-11-05, FOV 80) with the knife at
its hip hold: the RightGrip attachment, the blade direction (BladeBase ->
BladeTip) and the blade's edge axis (Blade_Metal Z).
"""

import math
import sys

import numpy as np

REST_GRIP = np.array([0.618, -0.696, -1.121])
REST_TIP = np.array([-0.010, -0.374, -2.179])
REST_EDGE = np.array([-0.484, -0.874, 0.044])
FOV = 80
ASPECT = 2179 / 964


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


def key(grip, blade, edge):
	r = frame(blade, edge) @ REST_FRAME.T
	pos = np.asarray(grip, float) - REST_GRIP
	return pos, angles_xyz(r)


REST = (REST_GRIP, REST_TIP - REST_GRIP, REST_EDGE)


def near(dx, dy, dz, yaw=0.0):
	"""The rest pose nudged (a settle past the hold)."""
	b = REST_TIP - REST_GRIP
	c, s = math.cos(math.radians(yaw)), math.sin(math.radians(yaw))
	b = np.array([b[0] * c + b[2] * s, b[1], -b[0] * s + b[2] * c])
	return (REST_GRIP + np.array([dx, dy, dz]), b, REST_EDGE)


# (t, (grip, blade, edge), easing of the segment ending here)
OUT, IN, INOUT = "Out", "In", "InOut"
ATTACKS = {
	# Forehand: cocked up over the right shoulder, the blade sweeps through
	# the crosshair edge-first, low left, follow-through, settle.
	"Slash1": (
		0.5,
		0.3,
		[
			(0.2, ((0.86, -0.36, -1.02), (0.45, 0.8, -0.4), (-1, 0, 0)), ("Quad", OUT)),
			(0.3, ((0.3, -0.38, -1.5), (-0.5, 0.25, -0.83), (-1, -0.2, 0)), ("Linear", None)),
			(0.42, ((-0.25, -0.85, -1.35), (-0.75, -0.2, -0.63), (-0.6, -0.8, 0)), ("Quad", OUT)),
			(0.56, ((-0.36, -0.96, -1.24), (-0.8, -0.3, -0.52), (-0.5, -0.85, 0)), ("Sine", OUT)),
			(0.86, near(0.02, -0.01, 0.01, -4), ("Quad", INOUT)),
		],
	),
	# Backhand: wound up across to the left, cuts back through the crosshair
	# to low right.
	"Slash2": (
		0.5,
		0.3,
		[
			(0.2, ((0.18, -0.34, -1.08), (-0.7, 0.55, -0.45), (0.2, -0.95, 0)), ("Quad", OUT)),
			(0.3, ((-0.05, -0.24, -1.45), (0.85, 0.12, -0.5), (0.5, -0.85, 0.3)), ("Linear", None)),
			(0.42, ((0.7, -0.8, -1.3), (0.8, -0.3, -0.5), (0.5, -0.85, 0)), ("Quad", OUT)),
			(0.56, ((0.85, -0.92, -1.2), (0.75, -0.38, -0.54), (0.5, -0.85, 0)), ("Sine", OUT)),
			(0.86, near(-0.01, -0.01, 0.01, 4), ("Quad", INOUT)),
		],
	),
	# The finisher: raised high with the blade up, chops down through the
	# crosshair, follows through low.
	"Slash3": (
		0.58,
		0.33,
		[
			(0.24, ((0.55, -0.18, -1.0), (0.1, 0.95, -0.25), (0, 0, -1)), ("Quad", OUT)),
			(0.33, ((0.4, -0.33, -1.55), (-0.15, 0.2, -0.97), (0, -1, 0)), ("Linear", None)),
			(0.45, ((0.35, -1.0, -1.35), (-0.15, -0.75, -0.65), (0, -0.65, 0.76)), ("Quad", OUT)),
			(0.58, ((0.33, -1.1, -1.25), (-0.12, -0.85, -0.5), (0, -0.5, 0.85)), ("Sine", OUT)),
			(0.87, near(0.0, 0.01, 0.0), ("Quad", INOUT)),
		],
	),
	# Heavy: pulled back low right with the point forward, the coil held,
	# a straight thrust to the crosshair, held, recovered.
	"HeavyStab": (
		0.9,
		0.44,
		[
			(0.1, near(0.03, -0.03, 0.08), ("Sine", IN)),
			(0.3, ((0.72, -0.72, -0.95), (-0.25, 0.15, -0.96), (0, -1, 0)), ("Quad", OUT)),
			(0.38, ((0.74, -0.73, -0.92), (-0.25, 0.15, -0.96), (0, -1, 0)), (None, None)),
			(0.44, ((0.42, -0.5, -1.75), (-0.3, 0.33, -0.9), (0, -1, 0)), ("Linear", None)),
			(0.5, ((0.4, -0.48, -1.86), (-0.3, 0.33, -0.9), (0, -1, 0)), ("Quad", OUT)),
			(0.62, ((0.41, -0.49, -1.82), (-0.3, 0.33, -0.9), (0, -1, 0)), (None, None)),
			(0.88, near(0.01, 0.0, 0.02), ("Quad", INOUT)),
		],
	),
}


def screen(p):
	t = math.tan(math.radians(FOV / 2))
	return (p[0] / -p[2] / (t * ASPECT), p[1] / -p[2] / t)


def luau_v(v):
	return "Vector3.new(" + ", ".join(f"{x:.3f}".rstrip("0").rstrip(".") if abs(x) > 5e-4 else "0" for x in v) + ")"


def main():
	check = "--check" in sys.argv
	for name, (length, hit, keys) in ATTACKS.items():
		if check:
			print(f"{name}: length {length}, hit {hit}")
		else:
			print(f"\t\t{name} = {{")
			print(f"\t\t\tlength = {length},\n\t\t\tpivot = \"Grip\",\n\t\t\town = true,\n\t\t\tscreen = true,\n\t\t\thit = {hit},")
			print("\t\t\tkeys = {\n\t\t\t\tkey(0, ZERO, ZERO),")
		for t, (grip, blade, edge), (style, d) in keys:
			pos, rot = key(grip, blade, edge)
			if check:
				tip = np.asarray(grip, float) + unit(blade) * np.linalg.norm(REST_TIP - REST_GRIP)
				gx, gy = screen(np.asarray(grip, float))
				tx, ty = screen(tip)
				print(f"  t={t:.2f} grip screen ({gx:+.2f},{gy:+.2f}) tip ({tx:+.2f},{ty:+.2f}) rot {rot[0]:.0f},{rot[1]:.0f},{rot[2]:.0f}")
				continue
			ease = ""
			if style == "Linear":
				ease = ", Enum.EasingStyle.Linear"
			elif style:
				ease = f", Enum.EasingStyle.{style}, {d.upper() if d != 'InOut' else 'INOUT'}"
			print(f"\t\t\t\tkey({t:g}, {luau_v(pos)}, {luau_v(rot)}{ease}),")
		if not check:
			print("\t\t\t\tkey(1, ZERO, ZERO, Enum.EasingStyle.Sine, INOUT),\n\t\t\t},\n\t\t},")


if __name__ == "__main__":
	main()
