"""Wharf kit (map Wharf, 2026-11-20): the pieces Parts can't do well. Everything else on the map is Parts.

    python tools/blender/lobby_v4/send.py tools/blender/maps_wharf/run_wharf.py --port 9897 --pid <pid>

Pieces (each a Map_<Piece> collection at the origin, for tools/blender/export_lobby_kit.py --maps Wharf Kit):
  QuayCrane   the landmark: a ship-to-shore crane in crane yellow. Portal of four chamfered box legs on sill
              beams and bogies, portal ties and braces, a box-girder boom (backreach + outreach over the water),
              an A-frame apex with flat-bar stays, a machinery house, a trolley with a cab and a spreader.
  MountainA/B/C  faceted low-poly islands for the horizon (rock sides, grass tops, flat-shaded triangles).
  Ship        a container ship silhouette for the horizon (raked bow of angled plates, bridge, stacked boxes).
Rules (gauntlet-build-style): no round shapes (bars are chamfered boxes, nothing smooth), every member ends in
a joint or a carved cap, flat shading. Units: 1 = 1 stud; X across the quay (+X = seaward), Y along it, Z up;
origin = the base centre. Our own design, nothing from RIVALS.
"""
from math import cos, pi, radians, sin, sqrt
import random

import arena_kit as A
from mathutils import Vector

ROOT = "WharfKit"

A.PAL.update(
	{
		"Y_Crane": ("#D9A73E", 0.6),  # the map accent: crane yellow
		"Y_CraneDark": ("#A9802F", 0.6),
		"K_Steel": ("#4B5058", 0.6),  # stays, trolley, bogies
		"K_House": ("#B7B9BC", 0.7),  # machinery house, cab
		"K_Glass": ("#2E3440", 0.3),
		"R_Rock": ("#8A8C86", 0.9),
		"R_RockDark": ("#6E716C", 0.9),
		"R_Grass": ("#71875C", 0.9),
		"S_Hull": ("#3F4A57", 0.8),
		"S_HullRed": ("#8C4438", 0.8),
		"S_Deck": ("#C9C6BE", 0.8),
		"S_BoxA": ("#9AA0A8", 0.8),
		"S_BoxB": ("#B8873A", 0.8),
		"S_BoxC": ("#6E7F8F", 0.8),
	}
)


def frame_of(p0, p1, up=Vector((0, 0, 1))):
	d = (p1 - p0).normalized()
	if abs(d.dot(up)) > 0.95:
		up = Vector((1, 0, 0))
	s = d.cross(up).normalized()
	u = s.cross(d).normalized()
	return d, s, u


def bar(M, mat, p0, p1, w, h, c=None, up=Vector((0, 0, 1))):
	"""A chamfered rectangular bar from p0 to p1 (w across, h up), ends square (they sit in joints)."""
	p0, p1 = Vector(p0), Vector(p1)
	d, s, u = frame_of(p0, p1, up)
	c = min(w, h) * 0.18 if c is None else c
	sec = A.cham(-w / 2, w / 2, -h / 2, h / 2, c)
	ring = lambda p: [tuple(p + s * a + u * b) for a, b in sec]  # noqa: E731
	M.loft([ring(p0), ring(p1)], mat)


def box(M, mat, x0, x1, y0, y1, z0, z1, c=0.3):
	M.prism(A.cham(x0, x1, y0, y1, c), z0, z1, mat)


def crane(name, collection):
	M = A.Mesh(name, collection)
	Y, YD, St, Hs, Gl = A.mat("Y_Crane"), A.mat("Y_CraneDark"), A.mat("K_Steel"), A.mat("K_House"), A.mat("K_Glass")
	gx, gy = 15.0, 11.0  # leg centres at x +-gx, y +-gy
	lw = 2.6  # leg section
	top = 40.0  # portal top
	# bogies and sill beams along Y (on the rails), carved ends (tapered)
	for sx in (-1, 1):
		x = sx * gx
		M.loft(
			[
				[(x - 1.6, -gy - 4.5, 0.0), (x + 1.6, -gy - 4.5, 0.0), (x + 1.6, gy + 4.5, 0.0), (x - 1.6, gy + 4.5, 0.0)],
				[(x - 1.6, -gy - 3.5, 1.4), (x + 1.6, -gy - 3.5, 1.4), (x + 1.6, gy + 3.5, 1.4), (x - 1.6, gy + 3.5, 1.4)],
			],
			St,
		)
		box(M, YD, x - 1.8, x + 1.8, -gy - 3.5, gy + 3.5, 1.4, 3.6, 0.35)  # sill beam
		for sy in (-1, 1):
			y = sy * gy
			box(M, Y, x - lw / 2, x + lw / 2, y - lw / 2, y + lw / 2, 3.6, top - 2.5, 0.4)  # leg
			box(M, YD, x - 2.0, x + 2.0, y - 2.0, y + 2.0, 3.6, 5.0, 0.4)  # leg foot collar
	# portal ties across X (low and high) and along Y (top), braces in the X-Z planes
	for sy in (-1, 1):
		y = sy * gy
		bar(M, Y, (-gx, y, 14.0), (gx, y, 14.0), 1.6, 2.0)
		bar(M, YD, (-gx + 0.8, y, 5.2), (gx - 0.8, y, 13.2), 0.9, 1.0)
		bar(M, YD, (-gx + 0.8, y, 14.8), (gx - 0.8, y, 26.0), 0.9, 1.0)
		box(M, Y, -gx - 2.2, gx + 2.2, y - 2.0, y + 2.0, top - 2.5, top + 1.0, 0.45)  # portal beam
	for sx in (-1, 1):
		x = sx * gx
		bar(M, Y, (x, -gy, 26.0), (x, gy, 26.0), 1.4, 1.8)
		box(M, YD, x - 2.0, x + 2.0, -gy - 2.0, gy + 2.0, top + 1.0, top + 2.2, 0.4)  # boom saddle
	# boom: two box girders along X, backreach -38, outreach +72, at z 44..48.5
	b0, b1 = top + 2.2, top + 6.7
	for sy in (-1, 1):
		y = sy * 4.2
		M.loft(
			[
				[(-38.0, y - 1.3, b0 + 1.0), (-38.0, y + 1.3, b0 + 1.0), (-38.0, y + 1.3, b1), (-38.0, y - 1.3, b1)],
				[(-34.0, y - 1.3, b0), (-34.0, y + 1.3, b0), (-34.0, y + 1.3, b1), (-34.0, y - 1.3, b1)],
				[(60.0, y - 1.3, b0), (60.0, y + 1.3, b0), (60.0, y + 1.3, b1), (60.0, y - 1.3, b1)],
				[(72.0, y - 1.1, b1 - 1.6), (72.0, y + 1.1, b1 - 1.6), (72.0, y + 1.1, b1), (72.0, y - 1.1, b1)],  # tapered tip
			],
			Y,
		)
	x = -32.0
	while x < 70:
		bar(M, YD, (x, -3.0, b0 + 0.3), (x, 3.0, b0 + 0.3), 0.6, 0.6)  # boom cross ties
		x += 8.0
	# A-frame apex over the portal, stays (flat bars)
	apex = Vector((-6.0, 0.0, 78.0))
	for sy in (-1, 1):
		bar(M, Y, (-gx + 2.0, sy * 4.2, b1), apex + Vector((0, sy * 1.2, 0)), 1.8, 1.6, up=Vector((0, 1, 0)))
		bar(M, Y, (gx - 6.0, sy * 4.2, b1), apex + Vector((0, sy * 1.2, 0)), 1.6, 1.4, up=Vector((0, 1, 0)))
		bar(M, St, apex + Vector((1.0, sy * 1.0, -1.0)), (40.0, sy * 4.2, b1), 0.5, 0.5, up=Vector((0, 1, 0)))
		bar(M, St, apex + Vector((1.0, sy * 1.0, -2.0)), (70.0, sy * 4.2, b1), 0.5, 0.5, up=Vector((0, 1, 0)))
		bar(M, St, apex + Vector((-1.0, sy * 1.0, -1.0)), (-36.0, sy * 4.2, b1), 0.5, 0.5, up=Vector((0, 1, 0)))
	box(M, YD, apex.x - 2.0, apex.x + 2.0, -2.6, 2.6, apex.z - 1.0, apex.z + 1.6, 0.4)  # apex head
	# machinery house on the backreach (sloped roof plates)
	box(M, Hs, -36.0, -22.0, -5.5, 5.5, b1, b1 + 7.0, 0.4)
	M.loft(
		[
			[(-36.4, -5.9, b1 + 7.0), (-21.6, -5.9, b1 + 7.0), (-21.6, 5.9, b1 + 7.0), (-36.4, 5.9, b1 + 7.0)],
			[(-35.0, -3.0, b1 + 9.0), (-23.0, -3.0, b1 + 9.0), (-23.0, 3.0, b1 + 9.0), (-35.0, 3.0, b1 + 9.0)],
		],
		YD,
	)
	for yy in (-5.6, 5.6):
		M.prism(A.cham(-33.0, -25.0, yy - 0.08, yy + 0.08, 0.02), b1 + 2.5, b1 + 4.5, Gl)  # vents / windows
	# trolley + cab + spreader on cables (cables are thin square bars)
	tx = 34.0
	box(M, St, tx - 4.0, tx + 4.0, -5.4, 5.4, b1, b1 + 2.6, 0.4)
	box(M, Hs, tx - 2.2, tx + 2.6, 1.0, 5.0, b0 - 4.6, b0 - 0.2, 0.35)  # cab
	M.prism(A.cham(tx + 2.6, tx + 2.7, 1.5, 4.5, 0.02), b0 - 4.0, b0 - 1.2, Gl)
	for cx in (-2.5, 2.5):
		for cy in (-2.5, 2.5):
			bar(M, St, (tx + cx, cy, b0), (tx + cx, cy, 18.5), 0.2, 0.2)
	box(M, YD, tx - 8.0, tx + 8.0, -3.4, 3.4, 16.5, 18.5, 0.3)  # spreader
	return M.finish()


def mountain(name, collection, rx, ry, peak, seed, n=22, ridge=0.0, sink=12.0):
	"""Faceted island: an n x n grid of triangles, height from a radial falloff with seeded bumps (and an
	optional ridge along X), sunk below the water at the rim. Faces get rock / grass by slope and height."""
	rnd = random.Random(seed)
	M = A.Mesh(name, collection)
	rock, rockd, grass = A.mat("R_Rock"), A.mat("R_RockDark"), A.mat("R_Grass")
	bumps = [(rnd.uniform(-0.6, 0.6), rnd.uniform(-0.6, 0.6), rnd.uniform(0.15, 0.35), rnd.uniform(0.2, 0.45)) for _ in range(6)]
	H = {}
	for i in range(n + 1):
		for j in range(n + 1):
			u, v = -1 + 2 * i / n, -1 + 2 * j / n
			r = sqrt(u * u + v * v)
			if ridge:
				r = sqrt((u * (1 - ridge)) ** 2 + v * v * (1 + ridge))
			h = max(0.0, 1 - r) ** 0.85 * 0.8
			for bx, by, br, bh in bumps:
				d = sqrt((u - bx) ** 2 + (v - by) ** 2)
				h += bh * max(0.0, 1 - d / br) * max(0.0, 1 - r) ** 0.5
			h = h * peak + rnd.uniform(-0.05, 0.05) * peak * max(0.0, 1 - r)
			# the shore dives under the water (no flat skirt at sea level to fight the ocean Part)
			h -= sink * min(1.0, max(0.0, (r - 0.7) / 0.3)) ** 1.5
			if r >= 1.0:
				h = -sink
			jx = rnd.uniform(-0.3, 0.3) * rx / n if 0 < i < n else 0
			jy = rnd.uniform(-0.3, 0.3) * ry / n if 0 < j < n else 0
			H[(i, j)] = (u * rx + jx, v * ry + jy, h)
	bm = M.bm
	vs = {k: bm.verts.new(p) for k, p in H.items()}
	tops = []
	for i in range(n):
		for j in range(n):
			a, b, c, d = vs[(i, j)], vs[(i + 1, j)], vs[(i + 1, j + 1)], vs[(i, j + 1)]
			for tri in ((a, b, c), (a, c, d)) if (i + j) % 2 == 0 else ((a, b, d), (b, c, d)):
				zs = [t.co.z for t in tri]
				if max(zs) <= -sink + 0.01:
					continue
				f = bm.faces.new(tri)
				tops.append(f)
	bm.normal_update()
	for f in tops:
		nz = f.normal.z if f.normal.z > 0 else -f.normal.z
		zc = sum(v.co.z for v in f.verts) / 3
		if nz > 0.82 and zc > peak * 0.12:
			f.material_index = M._slot(grass)
		elif zc < peak * 0.25 or rnd.random() < 0.35:
			f.material_index = M._slot(rockd)
		else:
			f.material_index = M._slot(rock)
	o = M.finish()
	# an open surface: make sure the faces point up (recalc can flip an open sheet)
	if sum(p.normal.z * p.area for p in o.data.polygons) < 0:
		for p in o.data.polygons:
			p.flip()
	return o


def ship(name, collection):
	"""Container ship, 150 long, for the horizon. Raked bow and transom of angled plates; bridge aft."""
	M = A.Mesh(name, collection)
	hull, red, deck = A.mat("S_Hull"), A.mat("S_HullRed"), A.mat("S_Deck")
	L, W = 75.0, 11.0
	prof_top = [(-L, -W), (L - 22, -W), (L, 0.0), (L - 22, W), (-L, W)]
	prof_bot = [(-L + 4, -W + 1.5), (L - 26, -W + 1.5), (L - 8, 0.0), (L - 26, W - 1.5), (-L + 4, W - 1.5)]
	M.loft([[(x, y, -4.0) for x, y in prof_bot], [(x, y, 0.0) for x, y in prof_top]], red)
	M.loft([[(x, y, 0.0) for x, y in prof_top], [(x, y, 9.0) for x, y in prof_top]], hull)
	# bridge
	box(M, deck, -L + 4, -L + 16, -W + 1, W - 1, 9.0, 24.0, 0.6)
	box(M, deck, -L + 6, -L + 14, -W - 1.5, W + 1.5, 21.0, 23.0, 0.3)
	box(M, hull, -L + 8, -L + 12, -2, 2, 24.0, 30.0, 0.4)  # funnel (square, chamfered)
	mats = [A.mat("S_BoxA"), A.mat("S_BoxB"), A.mat("S_BoxC")]
	rnd = random.Random(7)
	x = -L + 20
	while x < L - 26:
		for y0 in (-W + 0.5, 0.5):
			h = rnd.choice((2, 3, 3, 4))
			for k in range(h):
				box(M, rnd.choice(mats), x, x + 6.4, y0, y0 + W - 1.0, 9.0 + k * 2.6, 9.0 + (k + 1) * 2.6 - 0.15, 0.15)
		x += 6.8
	return M.finish()


def build_all():
	import bpy

	for c in [c for c in bpy.data.collections if c.name.startswith("Map_") and c.name[4:] in PIECES]:
		for o in list(c.all_objects):
			me = o.data
			bpy.data.objects.remove(o, do_unlink=True)
			if me is not None and me.users == 0:
				bpy.data.meshes.remove(me)
		bpy.data.collections.remove(c)
	root = A.coll(ROOT)
	made = [
		crane("QuayCrane", A.coll("Map_QuayCrane", root)),
		mountain("MountainA", A.coll("Map_MountainA", root), 330, 300, 230, 11),
		mountain("MountainB", A.coll("Map_MountainB", root), 420, 200, 140, 23, ridge=0.45),
		mountain("MountainC", A.coll("Map_MountainC", root), 200, 180, 75, 37, n=16),
		ship("Ship", A.coll("Map_Ship", root)),
	]
	for name, (hx, _r) in A.PAL.items():
		m = bpy.data.materials.get(name)
		if m is not None:
			m["rbx_material"] = "SmoothPlastic"
			m["rbx_color"] = hx.lstrip("#").upper()
	return {o.name: sum(len(p.vertices) - 2 for p in o.data.polygons) for o in made}


PIECES = ("QuayCrane", "MountainA", "MountainB", "MountainC", "Ship")
