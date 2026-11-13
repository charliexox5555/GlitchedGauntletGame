"""Sunwell Works phase 1: the turbine landmark, the SUNWELL WORKS lintel signs, benches, vents and wall lights."""
from math import cos, sin, pi, radians, sqrt
from mathutils import Matrix, Vector

import lv3_core as C
import sw_core as S
import sw_doors as DR

TC = 12.5  # turbine centre height


def turbine(K):
	"""A still, chunky turbine mounted into the far wall: cast surround, petrol ring, seven blades, bronze crest, low rail."""
	F = S.FK(K, S.F_END)
	with S.grp("Turbine", S.F_END):
		Kf = C.Kit(K.col, prefix="AnimFan")  # the rotor: its own meshes, grouped in Studio and turned by the lobby ambience script
		Kf.nocol = True
		FF = S.FK(Kf, S.F_END)
		R = 10.6
		arc = [(R * cos(a), TC + R * sin(a)) for a in [pi / 2 - pi * k / 6 for k in range(1, 6)]]  # 12-gon: facets that read from the spawn
		right = [(0, TC - R), (0, 0), (13.5, 0), (13.5, 21), (9.5, 25), (0, 25), (0, TC + R)] + arc
		F["Cast"].prism(right, 0.0, 1.3)
		F["Cast"].prism([(-x, y) for x, y in right], 0.0, 1.3)
		F["WallBase"].box(-15, 15, 0, 1.15, 0, 3.4)  # plinth
		F["Dark"].disc(R, 0.02, 0.2, n=12, cy=TC)
		F["E_Intake"].disc(7.9, 0.2, 0.26, n=12, cy=TC)  # warm light from the intake behind the rotor (dimmed: white read as a hole)
		F["PetrolDark"].ring(7.9, 8.85, 0.2, 0.28, n=12, cy=TC)  # shadow band inside the ring
		F["Petrol"].lathe([(9.3, 0.2), (10.95, 0.2), (10.95, 1.9), (10.55, 2.3), (9.7, 2.3), (9.3, 1.9)], n=12, cy=TC)
		F["PetrolDark"].ring(8.85, 9.3, 0.2, 1.55, n=12, cy=TC)
		S.bolts(F["Steel"], [(10.13 * cos(2 * pi * k / 12), TC + 10.13 * sin(2 * pi * k / 12)) for k in range(12)], r=0.3, z0=2.3, h=0.2)  # one on each corner
		with S.grp("Rotor", S.F_END):
			for k in range(7):
				a = 2 * pi * k / 7 + radians(12)
				Bm = FF.at(Matrix.Translation((0, TC, 1.0)) @ Matrix.Rotation(a, 4, "Z") @ Matrix.Rotation(radians(13), 4, "X"))
				Bm["Blade"].prism([(2.0, -0.85), (8.7, -1.55), (8.7, 2.5), (2.0, 0.95)], -0.32, 0.32)  # thicker vanes
				Bm["PetrolDark"].prism([(2.6, -0.05), (8.4, 0.1), (8.4, 0.75), (2.6, 0.45)], 0.32, 0.46)  # a dark spine down each vane
			FF["Charcoal"].disc(2.75, 0.2, 2.25, n=8, cy=TC)
			FF["Petrol"].ring(2.75, 3.15, 0.2, 1.7, n=8, cy=TC)
		Kf.done()
		piv = S.F_END @ Vector((0, TC, 1.0))
		S.ANIM["Turbine/Rotor"] = {"pivot": [round(piv.x, 3), round(piv.y, 3), round(piv.z, 3)], "spin": 26, "axis": [0, 1, 0]}
		S.SOUNDS.append(["TurbineWhoosh", round(piv.x, 2), round(piv.y - 1.5, 2), round(piv.z, 2), 9125742262, 0.1, 0.72, 16, 95])
		F["Graphite"].disc(2.2, 2.25, 2.45, n=8, cy=TC)
		# bronze Gauntlet crest: a raised fist on its cuff
		c = lambda x0, x1, y0, y1, z0=2.45, z1=2.8: F["Bronze"].box(x0, x1, TC + y0, TC + y1, z0, z1)
		c(-0.95, 0.95, -0.7, 0.3)  # palm
		for i, top in enumerate((1.12, 1.25, 1.2, 1.05)):
			c(-0.95 + i * 0.49, -0.95 + i * 0.49 + 0.43, 0.34, top)
		c(-0.45, 0.72, -0.4, 0.06, 2.8, 2.95)  # thumb across the fingers
		c(-0.72, 0.72, -1.25, -0.74)  # wrist
		c(-0.98, 0.98, -1.62, -1.29)  # cuff band
		S.light(S.F_END, 0, TC + 6, 9.0, "#FFE9CC", 1.3, 30, angle=100)
		S.light(S.F_END, 0, 4.0, 6.0, "#FFE9CC", 0.7, 16)
		S.light(S.F_END, 0, TC, 4.5, "#FFD49A", 0.9, 16)  # a warm glow on the rotor face
		S.light(S.F_END, 0, 21.0, 15.0, "#FFD9A8", 2.6, 30, angle=70)  # a warm pool on the floor in front of the rail
		# low rail on the hall floor in front
		zf, zs, xr = 9.0, 3.4, 13.0
		for x in (-13, -6.5, 0, 6.5, 13):
			F["Petrol"].box(x - 0.25, x + 0.25, 0.1, 3.0, zf - 0.25, zf + 0.25)
			F["PetrolDark"].box(x - 0.5, x + 0.5, 0.0, 0.14, zf - 0.5, zf + 0.5)
		for y in (1.55, 2.8):
			F["Petrol"].box(-xr - 0.2, xr + 0.2, y, y + 0.42, zf - 0.2, zf + 0.2)
			for s in (-1, 1):
				F["Petrol"].box(s * xr - 0.2, s * xr + 0.2, y + 0.01, y + 0.41, zs, zf - 0.2)
		for s in (-1, 1):
			F["Petrol"].box(s * xr - 0.25, s * xr + 0.25, 1.15, 3.0, zs + 0.3, zs + 0.8)
			S.collider("Props", S.F_END, s * xr - 0.3, s * xr + 0.3, 0, 3.3, zs, zf + 0.3, kind="Y")
		S.collider("Props", S.F_END, -xr - 0.3, xr + 0.3, 0, 3.3, zf - 0.3, zf + 0.3, kind="Y")
		S.collider("Props", S.F_END, -14.8, 14.8, 0.1, 1.0, 0.1, 3.25)  # plinth
		S.collider("Props", S.F_END, -13.5, 13.5, 1.0, 25.0, 0.0, 2.4, kind="Y")  # keeps players out of the turbine (invisible: an opaque box would show between the blades)
		for s in (-1, 1):
			DR.sconce(F, s * 18.5, 10.4)


def lintel_sign(K, M):
	"""SUNWELL WORKS: cast-style block letters on a dark plate with two bolted mounts, set in the entrance lintel."""
	F = S.FK(K, M)
	with S.grp("SunwellSign", M):
		yc = 19.25
		F["Charcoal"].prism([(-17.6, yc - 1.0), (-16.6, yc - 2.0), (16.6, yc - 2.0), (17.6, yc - 1.0), (17.6, yc + 1.0), (16.6, yc + 2.0),
			(-16.6, yc + 2.0), (-17.6, yc + 1.0)], 0.0, 0.5)
		for s in (-1, 1):
			F["Graphite"].box(*sorted((s * 15.55, s * 16.95)), yc - 1.25, yc + 1.25, 0.5, 0.64)
			S.bolts(F["Steel"], [(s * 16.25, yc - 0.62), (s * 16.25, yc + 0.62)], r=0.26, z0=0.64, h=0.18)
		S.add_text(F["Cream"], "SUNWELL WORKS", 2.5, 0.5, y0=yc - 1.25, z0=0.45, s=0.235, c=0.13, ws=0.96, track=0.12, space=0.5)


def bench(K, M, name):
	"""One formed graphite seat-and-back shell, two inset olive pads, two steel sleds on rubber feet. 6.5 x 2.25, seat at 1.7."""
	F = S.FK(K, M)
	with S.grp(f"Bench_{name}", M, inst=True):
		t = 0.13
		th = radians(11.6)
		line = [(-0.98, 1.27), (-0.8, 1.40), (0.3, 1.40)]
		for k in range(1, 7):  # the bend from seat to back
			a = -pi / 2 + (pi / 2 - th) * k / 6
			line.append((0.3 + 0.45 * cos(a), 1.85 + 0.45 * sin(a)))
		e = line[-1]
		line.append((e[0] + 1.52 * sin(th), e[1] + 1.52 * cos(th)))
		up, dn = [], []
		for i, p in enumerate(line):
			a, b = Vector(line[max(i - 1, 0)]), Vector(line[min(i + 1, len(line) - 1)])
			d = (b - a).normalized()
			nrm = Vector((-d.y, d.x))
			up.append((p[0] + nrm.x * t, p[1] + nrm.y * t))
			dn.append((p[0] - nrm.x * t, p[1] - nrm.y * t))
		F["Graphite"].ext_x(up + dn[::-1], -3.25, 3.25)
		F["SeatPad"].prism(S.cham_rect(-3.0, 3.0, -0.78, 0.2, 0.12), 1.5, 1.72)  # seat pad
		F["Charcoal"].box(-0.04, 0.04, -0.78, 0.2, 1.72, 1.735)  # seam between the two cushions
		top = line[-1]
		mid = ((e[0] + top[0]) / 2, (e[1] + top[1]) / 2)
		Bk = F.at(Matrix.Translation((0, mid[0], mid[1])) @ Matrix.Rotation(-th, 4, "X"))
		Bk["SeatPad"].box(-3.0, 3.0, -0.36, -0.1, -0.56, 0.6)  # back pad
		out = S.fillet([(-1.0, 0.14, 0.24), (0.9, 0.14, 0.24), (0.56, 1.3, 0.24), (-0.66, 1.3, 0.24)], "cham", 2)
		inn = S.fillet([(-0.66, 0.38, 0.1), (0.6, 0.38, 0.1), (0.37, 1.06, 0.1), (-0.45, 1.06, 0.1)], "cham", 2)
		for s in (-1, 1):
			S.ring_prism(F["Petrol"], out, inn, s * 2.3 - 0.21, s * 2.3 + 0.21, plane="yz")
			for y in (-0.72, 0.62):
				F["Rubber"].box(s * 2.3 - 0.3, s * 2.3 + 0.3, y - 0.22, y + 0.22, 0.0, 0.16)
			S.bolts(F.at(Matrix.Translation((0, 0, 1.27)) @ Matrix.Rotation(pi, 4, "X"))["Steel"], [(s * 2.3 + u, -0.05) for u in (-0.5, 0.5)], r=0.1, z0=0.0, h=0.06)
		S.collider("Props", M, -3.25, 3.25, -1.1, 0.75, 0.0, 1.7, kind="Y")
		S.collider("Props", M, -3.25, 3.25, 0.55, 1.2, 1.7, 3.3, kind="Y")


def bench_bay(K, side):
	"""Bench recess: the bench, a mounted opal light bar and a kick strip."""
	rot = pi / 2 if side < 0 else -pi / 2
	M = Matrix.Translation((side * 34.72, 53, 0)) @ Matrix.Rotation(rot, 4, "Z")
	bench(K, M, "L" if side < 0 else "R")
	W = S.FK(K, S.face((side * 36, 53, 0), (0, -side, 0), (-side, 0, 0)))  # back of the recess
	with S.grp("BenchRecess", W.M):  # a one-piece dark lining (sides and head), so the recess reads as a fitted niche
		S.u_frame(W["Charcoal"], 5.0, 7.25, 4.8, 7.05, 0.0, 2.0)
	with S.grp("BenchLight", W.M):
		W["Graphite"].box(-3.4, 3.4, 5.55, 6.35, 0.0, 0.45)
		W["E_Opal"].box(-3.1, 3.1, 5.72, 6.18, 0.45, 0.53)
		W["Graphite"].box(-4.8, 4.8, 0.0, 0.5, 0.0, 0.18)
		S.light(W.M, 0, 5.4, 1.4, "#FFE9CC", 0.9, 13)


def vent(F, x, y, w=3.4, h=2.1):
	with S.grp("Vent", F.M @ Matrix.Translation((x, y, 0)), inst=True):
		F["Charcoal"].box(x - w / 2, x + w / 2, y - h / 2, y + h / 2, 0.0, 0.28)
		F["Dark"].box(x - w / 2 + 0.25, x + w / 2 - 0.25, y - h / 2 + 0.25, y + h / 2 - 0.25, 0.28, 0.31)
		n = 4
		for k in range(n):
			yy = y - h / 2 + 0.36 + k * (h - 0.72) / (n - 1) - 0.1
			F["Graphite"].box(x - w / 2 + 0.3, x + w / 2 - 0.3, yy, yy + 0.2, 0.28, 0.42)


def build():
	K = S.kit("Props")
	turbine(K)
	lintel_sign(K, S.F_PROS_S)
	lintel_sign(K, S.F_PROS_N)
	for side in (-1, 1):
		bench_bay(K, side)
		for yc in (7.0, 53.0, 91.0):  # vents high on the walls, clear of the doorway signs and the beams
			vent(S.FK(K, S.wall_face(side, yc)), 0, 19.6)
	for side in (-1, 1):  # service hatches low on the walls of the entry and turbine bays
		for yc in (7.0, 104.5):
			A = S.FK(K, S.wall_face(side, yc))
			with S.grp("Hatch", A.M, inst=True):
				A["Petrol"].prism(S.cut_rect(-1.5, 1.5, 8.8, 10.8, 0.5, 0.15), 0.0, 0.14)
				A["PetrolDark"].prism(S.cut_rect(-1.2, 1.2, 9.1, 10.5, 0.35, 0.1), 0.14, 0.2)
				S.bolts(A["Steel"], [(-1.32, 8.98), (1.32, 10.62), (1.0, 8.98), (-1.0, 10.62)], r=0.08, z0=0.14, h=0.06)
				A["Steel"].box(-0.5, 0.5, 9.7, 9.9, 0.2, 0.36)
				A["Stripe"].box(0.3, 0.8, 10.2, 10.36, 0.2, 0.23)
	E = S.FK(K, S.F_ENTRY)
	for s in (-1, 1):
		DR.sconce(E, s * 16.2, 10.4)
		vent(E, s * 24, 19.6)
		vent(S.FK(K, S.F_END), s * 24, 19.6)
	K.done()
