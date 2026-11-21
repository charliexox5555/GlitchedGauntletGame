"""OldTown4 (Collina) kit (2026-11-21): the pieces Parts can't do well, modelled after the owner-approved concepts
(art-source/maps/OldTown4/concepts/: collina-overview, collina-player-view, old-town-props-sheet). Built with the
hard-surface helpers of tools/blender/maps_snowpeak4/snowcat_model.py (bevel modifiers, baked, smooth faces with sharp
edges) and noise-sculpted organics (no low-poly greenery).

    python tools/blender/lobby_v4/send.py tools/blender/maps_oldtown4/run_oldtown4.py --port 9897 --pid <pid>

Pieces (Map_<Piece>, export group Kit of map OldTown4):
  Fountain     octagonal two-step base, panelled basin with coping, water, pedestal with a faceted bowl, upper
               column and cup, finial (water jets are ParticleEmitters in Roblox). 12 x 12, 9.6 tall.
  Well         stone ring in two courses, timber posts and beam, tiled gable roof with a ridge, pulley, crank, rope,
               bucket. 6 x 6.
  MarketStall  timber frame, counter with a striped cloth, three crates of fruit, a scalloped striped awning, a
               barrel. 8 x 4 (front +Y).
  Cart         hand cart: plank bed with sides, two spoked wheels on an axle, shafts, a crate.
  CafeSet      a round (12-sided) table on a pedestal, two chairs, a parasol.
  PlanterBox / PotBush   terracotta planters with a relief band and LeafyGrass bushes (some flowering).
  WallLantern  a wall bracket and a glazed lantern (*LampGlow* = Neon). Origin = the wall point, sticks out +Y.
  WindowUnit   stone surround (jambs, lintel with keystone, sill on corbels), glazing with a mullion and transom,
               two open louvred shutters (*Paint* parts take each half's colour). Origin = bottom centre on the wall.
  DoorUnit     a stone arched surround and a studded plank door with a ring. Origin as WindowUnit.
  ArcadeBay    one 5-wide arcade bay: half piers, impost blocks, a voussoir arch with a keystone, spandrel. 8 tall.
  Balustrade5  a 5-long balustrade (plinth, six turned balusters, a moulded rail); BalPost: its end post.
  BelfryTop    the clock tower's top stage (10 x 10): cornice, belfry with two arched openings a side, a bell, upper
               cornice, a tiled pyramid roof and finial. ClockFace: rim, face, hour marks, hands (no numerals).
  Pavilion     the piazza's small pavilion (6 x 6): four piers, arches, an entablature, a tiled pyramid roof.
  CypressA/B   tall columnar cypresses (noise-sculpted, LeafyGrass). Bush: a round LeafyGrass shrub.
  HillA/B/C    Tuscan hills for the horizon (faceted far terrain: grass, gold fields, olive groves).
Units: studs; +X right, +Y front (Roblox -Z), +Z up. Our own designs after our own concepts.
"""
from math import cos, pi, radians, sin, sqrt
import random

import bmesh
import bpy
from mathutils import Matrix, Vector, noise

import arena_kit as A
import snowcat_model as SC

cube, prism, bar, cyl, bevel, new_obj, ngon2, finalize = SC.cube, SC.prism, SC.bar, SC.cyl, SC.bevel, SC.new_obj, SC.ngon2, SC.finalize

ROOT = "OldTown4Kit"
A.PAL.update(
	{
		"OT_Stone": ("#D8CBB0", 0.9),
		"OT_StoneDark": ("#B9A887", 0.9),
		"OT_Brick": ("#A9553B", 0.9),
		"OT_Terracotta": ("#B9582F", 0.8),
		"OT_TerraDark": ("#94442A", 0.8),
		"OT_Wood": ("#7A5233", 0.8),
		"OT_WoodDark": ("#553722", 0.8),
		"OT_Iron": ("#2E2B28", 0.5),
		"OT_Water": ("#5FA2B8", 0.1),
		"OT_Glass": ("#2E3742", 0.2),
		"OT_LampGlow": ("#E8B060", 0.4),
		"OT_ShutterPaint": ("#4F7A4E", 0.6),
		"OT_Cloth": ("#E9DFC8", 0.9),
		"OT_ClothStripe": ("#B8463A", 0.9),
		"OT_FruitA": ("#E08A2A", 0.5),
		"OT_FruitB": ("#C0382E", 0.5),
		"OT_FruitC": ("#E8C840", 0.5),
		"OT_FruitD": ("#6E3A6E", 0.5),
		"OT_Leaf": ("#56753E", 0.9),
		"OT_LeafDark": ("#3E5A30", 0.9),
		"OT_Bell": ("#8A6A2E", 0.4),
		"OT_ClockFace": ("#EDE4CC", 0.6),
		"OT_Pot": ("#B8643A", 0.8),
		"OT_Flower": ("#D86A8A", 0.7),
		"OT_FlowerW": ("#F0E8D0", 0.7),
		"OT_Grass": ("#859C58", 0.9),
		"OT_Field": ("#C8A75C", 0.9),
		"OT_Olive": ("#6E7E4A", 0.9),
		"OT_Rope": ("#B49A6A", 0.9),
	}
)
RBX = {
	"OT_Stone": "Limestone",
	"OT_StoneDark": "Limestone",
	"OT_Brick": "Brick",
	"OT_Terracotta": "ClayRoofTiles",
	"OT_TerraDark": "ClayRoofTiles",
	"OT_Wood": "WoodPlanks",
	"OT_WoodDark": "WoodPlanks",
	"OT_Leaf": "LeafyGrass",
	"OT_LeafDark": "LeafyGrass",
	"OT_LampGlow": "Neon",
	"OT_Glass": "Glass",
}
TRANSPARENT = {"OT_Water": 0.3, "OT_Glass": 0.25}


def box_uv(o, tile=6.0):
	me = o.data
	if not me.uv_layers:
		me.uv_layers.new(name="UVMap")
	uv = me.uv_layers.active.data
	for p in me.polygons:
		n = p.normal
		ax = max(range(3), key=lambda i: abs(n[i]))
		for li in p.loop_indices:
			co = me.vertices[me.loops[li].vertex_index].co
			a, b = [(co.y, co.z), (co.x, co.z), (co.x, co.y)][ax]
			uv[li].uv = (a / tile, b / tile)


def ring(bm, r_out, r_in, z0, z1, n, mi, rot=None):
	"""A closed n-sided ring (n trapezoid prisms)."""
	rot = pi / n if rot is None else rot
	o, i = ngon2(0, 0, r_out, n, rot), ngon2(0, 0, r_in, n, rot)
	for k in range(n):
		a0, a1, b0, b1 = o[k], o[(k + 1) % n], i[k], i[(k + 1) % n]
		prism(bm, [a0, a1, b1, b0], "z", z0, z1, mi)


def lathe(bm, profile, n, mi, cx=0.0, cy=0.0, rot=None):
	"""Revolve [(r, z), ...] (bottom to top) into a closed n-sided solid."""
	rot = pi / n if rot is None else rot
	rings = []
	for r, z in profile:
		rings.append([bm.verts.new((cx + max(r, 0.001) * cos(rot + 2 * pi * k / n), cy + max(r, 0.001) * sin(rot + 2 * pi * k / n), z)) for k in range(n)])
	fs = [bm.faces.new(list(reversed(rings[0]))), bm.faces.new(rings[-1])]
	for r0, r1 in zip(rings, rings[1:]):
		for k in range(n):
			fs.append(bm.faces.new((r0[k], r0[(k + 1) % n], r1[(k + 1) % n], r1[k])))
	for f in fs:
		f.material_index = mi


def arch_ring(bm, cx, y0, y1, spring, r_in, r_out, segs, mi, key_mi=None):
	"""A voussoir arch in the XZ plane (semicircle of `segs` straight stones), from y0 to y1 deep."""
	for k in range(segs):
		a0, a1 = pi - pi * k / segs, pi - pi * (k + 1) / segs
		pts = [
			(cx + r_in * cos(a0), spring + r_in * sin(a0)),
			(cx + r_out * cos(a0), spring + r_out * sin(a0)),
			(cx + r_out * cos(a1), spring + r_out * sin(a1)),
			(cx + r_in * cos(a1), spring + r_in * sin(a1)),
		]
		_xz_prism(bm, pts, y0, y1, key_mi if (key_mi is not None and k == segs // 2) else mi)


def _xz_prism(bm, pts, y0, y1, mi):
	r0 = [bm.verts.new((x, y0, z)) for x, z in pts]
	r1 = [bm.verts.new((x, y1, z)) for x, z in pts]
	n = len(pts)
	fs = [bm.faces.new(r0), bm.faces.new(list(reversed(r1)))]
	for k in range(n):
		fs.append(bm.faces.new((r0[k], r1[k], r1[(k + 1) % n], r0[(k + 1) % n])))
	for f in fs:
		f.material_index = mi
	return fs


def blob(bm, c, sx, sy, sz, seed, mi, subdiv=3, amp=0.18):
	"""A noise-sculpted round mass (foliage)."""
	off = Vector((seed * 3.7, seed * 1.3, seed * 2.1))
	res = bmesh.ops.create_icosphere(bm, subdivisions=subdiv, radius=1.0, matrix=Matrix.Translation(c) @ Matrix.Diagonal((sx, sy, sz, 1.0)))
	for v in res["verts"]:
		d = (v.co - c)
		n = d.normalized()
		v.co += n * amp * min(sx, sz) * noise.fractal(v.co * 1.6 + off, 0.55, 2.0, 3)
	for f in {f for v in res["verts"] for f in v.link_faces}:
		f.material_index = mi
	return res["verts"]


def tiled_pyramid(bm, half, z0, z1, mi, ridge_mi, over=0.4):
	"""A four-sided tiled roof: planes with tile courses (steps) and hip ridges."""
	h = half + over
	apex = Vector((0, 0, z1))
	courses = 6
	for side in range(4):
		ang = side * pi / 2
		c, s = cos(ang), sin(ang)

		def P(u, v, z):
			return Vector((u * c - v * s, u * s + v * c, z))

		for k in range(courses):
			t0, t1 = k / courses, (k + 1) / courses
			w0, w1 = h * (1 - t0), h * (1 - t1)
			za, zb = z0 + (z1 - z0) * t0, z0 + (z1 - z0) * t1
			# one tile course: a sloped band from the course below to the one above, lifted 0.08 at its lower edge
			q = [P(-w0, -w0, za - 0.08), P(w0, -w0, za - 0.08), P(w1, -w1, zb), P(-w1, -w1, zb)]
			qt = [p + Vector((0, 0, 0.18)) for p in q]
			vs = [bm.verts.new(p) for p in q] + [bm.verts.new(p) for p in qt]
			for f in ((0, 1, 2, 3), (7, 6, 5, 4), (0, 4, 5, 1), (1, 5, 6, 2), (2, 6, 7, 3), (3, 7, 4, 0)):
				bm.faces.new([vs[i] for i in f]).material_index = mi
		# hip ridge along the corner
		bar(bm, P(-h, -h, z0 + 0.1), apex + Vector((0, 0, 0.1)), 0.32, 0.26, ridge_mi)
	# a hidden core under the courses so the roof bears on its support (no floating tiles)
	core = [bm.verts.new((x, y, z0 - 0.1)) for x, y in ((-half, -half), (half, -half), (half, half), (-half, half))]
	top = bm.verts.new((0, 0, z1 - 0.25))
	bm.faces.new(list(reversed(core))).material_index = ridge_mi
	for i in range(4):
		bm.faces.new([core[i], core[(i + 1) % 4], top]).material_index = ridge_mi


# ------------------------------------------------------------------------------------------------ pieces
def fountain(coll):
	bm = bmesh.new()
	ST, SD, WA = 0, 1, 2
	prism(bm, ngon2(0, 0, 6.0, 8, pi / 8), "z", -0.1, 0.5, SD)
	prism(bm, ngon2(0, 0, 5.45, 8, pi / 8), "z", 0.5, 1.0, ST)
	ring(bm, 5.0, 4.2, 1.0, 2.9, 8, ST)
	ring(bm, 5.2, 4.05, 2.9, 3.25, 8, SD)
	# carved panels on the eight basin faces (proud plates with a raised border)
	oc = ngon2(0, 0, 5.0, 8, pi / 8)
	for k in range(8):
		a, b = Vector((*oc[k], 0)), Vector((*oc[(k + 1) % 8], 0))
		mid = (a + b) / 2
		t = (b - a).normalized()
		n = Vector((mid.x, mid.y, 0)).normalized()
		w = (b - a).length * 0.36
		for d0, d1, z0, z1, mi in ((0.0, 0.06, 1.35, 2.6, SD), (0.06, 0.1, 1.55, 2.4, ST)):
			c0 = mid + n * d0
			c1 = mid + n * d1
			pts = [c0 - t * w + Vector((0, 0, z0)), c0 + t * w + Vector((0, 0, z0)), c0 + t * w + Vector((0, 0, z1)), c0 - t * w + Vector((0, 0, z1))]
			pts2 = [p + (c1 - c0) for p in pts]
			vs = [bm.verts.new(p) for p in pts] + [bm.verts.new(p) for p in pts2]
			for f in ((3, 2, 1, 0), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)):
				bm.faces.new([vs[i] for i in f]).material_index = mi
			w *= 0.86
	prism(bm, ngon2(0, 0, 4.3, 8, pi / 8), "z", 1.0, 2.45, WA)  # water
	# pedestal, bowl, column, cup, finial
	lathe(bm, [(1.45, 2.4), (1.45, 2.8), (1.05, 2.95), (0.95, 4.4), (1.15, 4.55)], 12, ST)
	lathe(bm, [(1.0, 4.5), (2.5, 5.4), (2.75, 5.75), (2.55, 5.8), (0.6, 5.55)], 12, SD)
	lathe(bm, [(2.4, 5.5), (2.4, 5.62)], 12, WA)
	lathe(bm, [(0.5, 5.5), (0.42, 7.2), (0.6, 7.35)], 10, ST)
	lathe(bm, [(0.45, 7.3), (1.25, 7.85), (1.3, 8.05), (0.3, 7.95)], 10, SD)
	lathe(bm, [(0.3, 7.9), (0.42, 8.5), (0.22, 9.0), (0.3, 9.25), (0.05, 9.6)], 8, ST)
	o = new_obj("Fountain", bm, ["OT_Stone", "OT_StoneDark", "OT_Water"], coll)
	bevel(o, 0.04, 1, 40)
	return [o]


def well(coll):
	bm = bmesh.new()
	ST, SD, WD, WK, TR, TD, IR, RP = 0, 1, 2, 3, 4, 5, 6, 7
	ring(bm, 2.55, 1.95, -0.1, 1.3, 8, ST)
	ring(bm, 2.5, 1.95, 1.3, 2.4, 8, SD, rot=0)
	ring(bm, 2.7, 1.85, 2.4, 2.7, 8, ST)
	for x in (-2.35, 2.35):
		cube(bm, x - 0.22, x + 0.22, -0.22, 0.22, 0.0, 5.7, WD)
		cube(bm, x - 0.17, x + 0.17, -0.17, 0.17, 5.8, 7.9, WD)  # king post under the ridge
		for s in (-1, 1):
			bar(bm, (x, s * 3.05, 5.62), (x, 0, 7.72), 0.16, 0.14, WK)  # gable rafters under the tiles
		bar(bm, (x, 0, 4.2), (x * 0.55, 0, 5.4), 0.16, 0.16, WK)  # knee braces
	cube(bm, -2.7, 2.7, -0.2, 0.2, 5.5, 5.85, WD)  # beam
	cyl(bm, (-0.35, 0, 5.1), (0.35, 0, 5.1), 0.42, 12, WK)  # pulley drum
	cyl(bm, (2.57, 0, 4.4), (2.85, 0, 4.4), 0.1, 8, IR)
	bar(bm, (2.85, 0, 4.4), (2.85, 0, 3.75), 0.09, 0.09, IR)
	bar(bm, (2.85, 0, 3.75), (3.2, 0, 3.75), 0.09, 0.09, IR)
	cyl(bm, (0, 0, 4.68), (0, 0, 3.55), 0.04, 6, RP)  # rope
	lathe(bm, [(0.32, 2.75), (0.42, 3.55)], 8, WD)  # bucket
	ring(bm, 0.44, 0.38, 3.2, 3.32, 8, IR)
	# gable roof along X: two tiled planes (tile courses as steps) and a ridge
	for s in (-1, 1):
		for k in range(5):
			y0, y1 = s * (3.1 - k * 0.6), s * (3.1 - (k + 1) * 0.6)
			z0, z1 = 5.75 + k * 0.42, 5.75 + (k + 1) * 0.42
			pts = [(-3.2, y0, z0 - 0.06), (3.2, y0, z0 - 0.06), (3.2, y1, z1), (-3.2, y1, z1)]
			vs = [bm.verts.new(p) for p in pts] + [bm.verts.new((x, y, z + 0.16)) for x, y, z in pts]
			for f in ((0, 1, 2, 3), (7, 6, 5, 4), (0, 4, 5, 1), (1, 5, 6, 2), (2, 6, 7, 3), (3, 7, 4, 0)):
				bm.faces.new([vs[i] for i in f]).material_index = TR
	bar(bm, (-3.3, 0, 7.95), (3.3, 0, 7.95), 0.4, 0.3, TD)
	o = new_obj("Well", bm, ["OT_Stone", "OT_StoneDark", "OT_Wood", "OT_WoodDark", "OT_Terracotta", "OT_TerraDark", "OT_Iron", "OT_Rope"], coll)
	bevel(o, 0.03, 1, 40)
	return [o]


def fruit_pile(bm, x0, x1, y0, y1, z, mi_list, seed):
	rnd = random.Random(seed)
	x = x0 + 0.2
	while x < x1 - 0.15:
		y = y0 + 0.2
		while y < y1 - 0.15:
			mi = rnd.choice(mi_list)
			r = rnd.uniform(0.15, 0.19)
			res = bmesh.ops.create_icosphere(bm, subdivisions=1, radius=r, matrix=Matrix.Translation((x + rnd.uniform(-0.04, 0.04), y, z + r * 0.8)))
			for f in {f for v in res["verts"] for f in v.link_faces}:
				f.material_index = mi
			y += 0.34
		x += 0.34


def market_stall(coll):
	bm = bmesh.new()
	WD, WK, CL, CS, FA, FB, FC, FD, IR = 0, 1, 2, 3, 4, 5, 6, 7, 8
	for x in (-3.8, 3.8):
		for y, h in ((1.7, 4.0), (-1.7, 5.0)):
			cube(bm, x - 0.16, x + 0.16, y - 0.16, y + 0.16, 0.0, h, WK)
	cube(bm, -3.6, 3.6, -1.2, 1.4, 0.0, 2.4, WD)  # counter
	cube(bm, -3.7, 3.7, -1.3, 1.55, 2.4, 2.55, WK)
	# striped cloth over the counter front
	for k in range(8):
		x = -3.4 + k * 0.85
		cube(bm, x, x + 0.85, 1.55, 1.6, 0.9, 2.5, CS if k % 2 == 0 else CL)
	cube(bm, -3.42, 3.42, 1.6, 1.64, 0.9, 1.05, CS)
	# crates with fruit on the counter
	for i, x in enumerate((-2.4, 0.0, 2.4)):
		cube(bm, x - 1.0, x + 1.0, -0.6, 0.9, 2.55, 3.05, WD)
		for z in (2.62, 2.98):
			cube(bm, x - 1.03, x + 1.03, -0.63, 0.93, z, z + 0.06, WK)
		fruit_pile(bm, x - 0.9, x + 0.9, -0.5, 0.8, 3.0, [(FA, FB, FC)[i], (FA, FB, FC)[i], FD if i == 2 else (FA, FB, FC)[i]], i + 3)
	# the awning: striped slats on a slope (back 5.0 -> front 4.0, overhanging), scalloped valance at the front
	n = 9
	for k in range(n):
		x0, x1 = -4.1 + k * 8.2 / n, -4.1 + (k + 1) * 8.2 / n
		pts = [(x0, -1.9, 5.0), (x1, -1.9, 5.0), (x1, 2.2, 3.95), (x0, 2.2, 3.95)]
		vs = [bm.verts.new(p) for p in pts] + [bm.verts.new((x, y, z + 0.08)) for x, y, z in pts]
		for f in ((0, 1, 2, 3), (7, 6, 5, 4), (0, 4, 5, 1), (1, 5, 6, 2), (2, 6, 7, 3), (3, 7, 4, 0)):
			bm.faces.new([vs[i] for i in f]).material_index = CS if k % 2 == 0 else CL
		# valance tooth
		pts = [(x0, 2.2, 3.95), (x1, 2.2, 3.95), ((x0 + x1) / 2, 2.2, 3.45)]
		r0 = [bm.verts.new((x, y, z)) for x, y, z in pts]
		r1 = [bm.verts.new((x, y + 0.06, z)) for x, y, z in pts]
		for f in ((r0[0], r0[1], r0[2]), (r1[2], r1[1], r1[0]), (r0[0], r1[0], r1[1], r0[1]), (r0[1], r1[1], r1[2], r0[2]), (r0[2], r1[2], r1[0], r0[0])):
			bm.faces.new(f).material_index = CS if k % 2 == 0 else CL
	bar(bm, (-4.1, -1.9, 4.95), (4.1, -1.9, 4.95), 0.18, 0.18, WK)
	bar(bm, (-4.1, 2.2, 3.9), (4.1, 2.2, 3.9), 0.16, 0.16, WK)
	# a barrel at the side
	lathe(bm, [(0.55, 0.0), (0.68, 0.6), (0.7, 0.9), (0.68, 1.2), (0.55, 1.8)], 12, WD, cx=4.6, cy=1.0)
	for z in (0.35, 1.45):
		lathe(bm, [(0.64, z - 0.06), (0.66, z), (0.64, z + 0.06)], 12, IR, cx=4.6, cy=1.0)
	o = new_obj("MarketStall", bm, ["OT_Wood", "OT_WoodDark", "OT_Cloth", "OT_ClothStripe", "OT_FruitA", "OT_FruitB", "OT_FruitC", "OT_FruitD", "OT_Iron"], coll)
	bevel(o, 0.025, 1, 40)
	return [o]


def wheel(bm, x0, x1, cy, cz, r, mi_rim, mi_spoke):
	ring_pts_o = ngon2(cy, cz, r, 16, pi / 16)
	ring_pts_i = ngon2(cy, cz, r - 0.18, 16, pi / 16)
	for k in range(16):
		a0, a1, b0, b1 = ring_pts_o[k], ring_pts_o[(k + 1) % 16], ring_pts_i[k], ring_pts_i[(k + 1) % 16]
		prism(bm, [a0, a1, b1, b0], "x", x0, x1, mi_rim)
	for k in range(8):
		a = k * pi / 4
		bar(bm, (x0 + (x1 - x0) / 2, cy, cz), (x0 + (x1 - x0) / 2, cy + (r - 0.12) * cos(a), cz + (r - 0.12) * sin(a)), 0.07, 0.07, mi_spoke)
	prism(bm, ngon2(cy, cz, 0.22, 8), "x", x0 - 0.06, x1 + 0.06, mi_spoke)


def cart(coll):
	bm = bmesh.new()
	WD, WK, IR = 0, 1, 2
	cube(bm, -1.3, 1.3, -1.6, 1.6, 1.05, 1.25, WD)  # bed
	for x in (-1.3, 1.3):
		cube(bm, x - 0.06 if x < 0 else x - 0.06, x + 0.06, -1.6, 1.6, 1.25, 1.95, WD)
	cube(bm, -1.3, 1.3, -1.66, -1.54, 1.25, 1.95, WD)
	cube(bm, -1.3, 1.3, 1.54, 1.66, 1.25, 1.65, WD)
	for y in (-1.2, 0.0, 1.2):
		cube(bm, -1.4, 1.4, y - 0.1, y + 0.1, 0.85, 1.05, WK)
	for x in (-1.0, 1.0):
		bar(bm, (x, 1.6, 1.15), (x * 0.9, 3.6, 0.7), 0.16, 0.16, WK)  # shafts
	cyl(bm, (-1.55, 0.2, 0.75), (1.55, 0.2, 0.75), 0.09, 8, IR)  # axle
	for x0, x1 in ((-1.62, -1.42), (1.42, 1.62)):
		wheel(bm, x0, x1, 0.2, 0.75, 0.75, WK, WD)
	bar(bm, (-0.9, -1.55, 0.0), (-0.9, -1.55, 1.0), 0.14, 0.14, WK)  # prop leg at the back
	bar(bm, (0.9, -1.55, 0.0), (0.9, -1.55, 1.0), 0.14, 0.14, WK)
	cube(bm, -0.8, 0.6, -1.2, 0.3, 1.25, 2.05, WD)  # a crate on it
	cube(bm, -0.82, 0.62, -1.22, 0.32, 1.6, 1.68, WK)
	o = new_obj("Cart", bm, ["OT_Wood", "OT_WoodDark", "OT_Iron"], coll)
	bevel(o, 0.02, 1, 40)
	return [o]


def cafe_set(coll):
	bm = bmesh.new()
	IR, WD, CL, CS, ST = 0, 1, 2, 3, 4
	lathe(bm, [(0.65, 0.0), (0.2, 0.15), (0.09, 0.3), (0.09, 2.3), (0.3, 2.4)], 8, IR)
	prism(bm, ngon2(0, 0, 0.95, 12), "z", 2.4, 2.55, ST)
	for s in (-1, 1):  # chairs facing the table
		cy = s * 1.55
		cube(bm, -0.5, 0.5, cy - 0.45, cy + 0.45, 1.45, 1.6, WD)
		for dx in (-0.42, 0.42):
			for dy in (-0.38, 0.38):
				bar(bm, (dx, cy + dy, 0.0), (dx * 0.95, cy + dy * 0.95, 1.45), 0.07, 0.07, IR)
		by = cy + s * 0.42
		for dx in (-0.42, 0.42):
			bar(bm, (dx, by, 1.45), (dx, by + s * 0.12, 3.0), 0.07, 0.07, IR)
		for z in (2.2, 2.75):
			cube(bm, -0.45, 0.45, by + s * 0.03 - 0.05, by + s * 0.03 + 0.05, z - 0.14, z + 0.14, WD)
	# parasol: pole, an 8-sided canopy (cone, scalloped stripes), finial
	cyl(bm, (0, 0, 2.55), (0, 0, 6.4), 0.06, 8, WD)
	n = 8
	for k in range(n):
		a0, a1 = 2 * pi * k / n, 2 * pi * (k + 1) / n
		R = 2.2
		pts = [(0, 0, 6.55), (R * cos(a0), R * sin(a0), 5.4), (R * cos(a1), R * sin(a1), 5.4)]
		r0 = [bm.verts.new(p) for p in pts]
		r1 = [bm.verts.new((x, y, z + 0.05)) for x, y, z in pts]
		for f in ((r0[2], r0[1], r0[0]), (r1[0], r1[1], r1[2]), (r0[0], r0[1], r1[1], r1[0]), (r0[1], r0[2], r1[2], r1[1]), (r0[2], r0[0], r1[0], r1[2])):
			bm.faces.new(f).material_index = CS if k % 2 == 0 else CL
	lathe(bm, [(0.1, 6.55), (0.12, 6.75), (0.02, 6.9)], 6, WD)
	o = new_obj("CafeSet", bm, ["OT_Iron", "OT_Wood", "OT_Cloth", "OT_ClothStripe", "OT_Stone"], coll)
	bevel(o, 0.015, 1, 40)
	return [o]


def planter_box(coll):
	bm = bmesh.new()
	PT, LF, LD, FL = 0, 1, 2, 3
	cube(bm, -1.5, 1.5, -0.7, 0.7, 0.0, 1.2, PT)
	cube(bm, -1.6, 1.6, -0.8, 0.8, 1.15, 1.35, PT)
	cube(bm, -1.52, 1.52, -0.72, 0.72, 0.4, 0.65, PT)
	for i, x in enumerate((-0.8, 0.1, 0.9)):
		blob(bm, Vector((x, 0, 1.75)), 0.75, 0.6, 0.6, i + 2, LF if i != 1 else LD)
	rnd = random.Random(4)
	for _ in range(9):
		c = Vector((rnd.uniform(-1.2, 1.2), rnd.uniform(-0.4, 0.4), rnd.uniform(2.0, 2.35)))
		res = bmesh.ops.create_icosphere(bm, subdivisions=1, radius=0.14, matrix=Matrix.Translation(c))
		for f in {f for v in res["verts"] for f in v.link_faces}:
			f.material_index = FL
	o = new_obj("PlanterBox", bm, ["OT_Pot", "OT_Leaf", "OT_LeafDark", "OT_Flower"], coll)
	return [o]


def pot_bush(coll):
	bm = bmesh.new()
	PT, LF = 0, 1
	lathe(bm, [(0.55, 0.0), (0.75, 0.15), (0.9, 1.1), (1.0, 1.25), (0.95, 1.4)], 10, PT)
	blob(bm, Vector((0, 0, 2.3)), 1.1, 1.1, 1.05, 7, LF)
	o = new_obj("PotBush", bm, ["OT_Pot", "OT_Leaf"], coll)
	return [o]


def wall_lantern(coll):
	bm = bmesh.new()
	IR, GL = 0, 1
	cube(bm, -0.25, 0.25, 0.0, 0.08, -0.55, 0.55, IR)  # wall plate
	bar(bm, (0, 0.05, 0.25), (0, 1.0, 0.25), 0.1, 0.1, IR)  # arm
	bar(bm, (0, 0.05, -0.35), (0, 0.6, 0.2), 0.08, 0.08, IR)  # brace
	bar(bm, (0, 0.95, 0.25), (0, 0.95, 0.0), 0.06, 0.06, IR)  # hanger
	prism(bm, ngon2(0, 0.95, 0.32, 6), "z", -0.95, -0.85, IR)
	prism(bm, ngon2(0, 0.95, 0.26, 6), "z", -0.85, -0.15, GL)
	for k in range(6):
		a = k * pi / 3
		bar(bm, (0.3 * cos(a), 0.95 + 0.3 * sin(a), -0.86), (0.3 * cos(a), 0.95 + 0.3 * sin(a), -0.12), 0.05, 0.05, IR)
	lathe(bm, [(0.38, -0.15), (0.1, 0.05), (0.04, 0.1)], 6, IR, cy=0.95)
	o = new_obj("WallLantern", bm, ["OT_Iron", "OT_LampGlow"], coll)
	return [o]


def window_unit(coll):
	"""2.4 wide opening, 3.4 tall, on a wall (y = 0 the wall face, the unit stands out +Y)."""
	bm = bmesh.new()
	ST, SD, GL, WD, SP = 0, 1, 2, 3, 4
	W, H = 2.4, 3.4
	cube(bm, -W / 2, W / 2, 0.0, 0.06, 0.0, H, GL)  # glazing (dark), just proud of the wall
	for x in (-W / 2 - 0.32, W / 2):  # jambs
		cube(bm, x, x + 0.32, 0.0, 0.22, -0.05, H + 0.05, ST)
	cube(bm, -W / 2 - 0.45, W / 2 + 0.45, 0.0, 0.3, H, H + 0.42, ST)  # lintel
	_xz_prism(bm, [(-0.3, H + 0.02), (0.3, H + 0.02), (0.38, H + 0.5), (-0.38, H + 0.5)], 0.0, 0.36, SD)  # keystone
	cube(bm, -W / 2 - 0.42, W / 2 + 0.42, 0.0, 0.42, -0.3, -0.05, ST)  # sill
	for x in (-W / 2 + 0.05, W / 2 - 0.35):  # corbels under the sill
		cube(bm, x, x + 0.3, 0.0, 0.3, -0.62, -0.3, SD)
	cube(bm, -0.06, 0.06, 0.04, 0.14, 0.0, H, WD)  # mullion
	cube(bm, -W / 2, W / 2, 0.04, 0.14, H * 0.62 - 0.06, H * 0.62 + 0.06, WD)  # transom
	# open louvred shutters flat against the wall on both sides
	for s in (-1, 1):
		x0, x1 = sorted((s * (W / 2 + 0.34), s * (W / 2 + 0.34 + 1.15)))
		cube(bm, x0, x1, 0.0, 0.1, 0.05, H - 0.05, SP)
		for z in [0.3 + 0.28 * k for k in range(11)]:
			cube(bm, x0 + 0.12, x1 - 0.12, 0.1, 0.16, z, z + 0.12, SP)
	o = new_obj("WindowUnit", bm, ["OT_Stone", "OT_StoneDark", "OT_Glass", "OT_WoodDark", "OT_ShutterPaint"], coll)
	bevel(o, 0.02, 1, 40)
	return [o]


def door_unit(coll):
	bm = bmesh.new()
	ST, SD, WD, WK, IR = 0, 1, 2, 3, 4
	W, Hs = 2.6, 4.0  # opening width, spring height of the arch
	for x in (-W / 2 - 0.45, W / 2):
		cube(bm, x, x + 0.45, 0.0, 0.3, 0.0, Hs, ST)
	arch_ring(bm, 0.0, 0.0, 0.3, Hs, W / 2, W / 2 + 0.45, 7, ST, key_mi=SD)
	# the door: planks in the arch (an arched top made of a polygon), set back
	poly = [(-W / 2, 0.0), (W / 2, 0.0)] + [((W / 2) * cos(a), Hs + (W / 2) * sin(a)) for a in [pi * k / 8 for k in range(0, 9)]]
	_xz_prism(bm, poly, 0.0, 0.08, WD)
	for k in range(5):
		x = -W / 2 + (k + 0.5) * W / 5
		cube(bm, x - 0.02, x + 0.02, 0.08, 0.1, 0.1, Hs + 0.6, WK)
	for z in (0.8, Hs - 0.4):
		cube(bm, -W / 2 + 0.1, W / 2 - 0.1, 0.08, 0.14, z - 0.1, z + 0.1, IR)
		for k in range(5):
			x = -W / 2 + 0.3 + k * (W - 0.6) / 4
			cyl(bm, (x, 0.14, z), (x, 0.2, z), 0.05, 6, IR)
	cyl(bm, (0.75, 0.08, 2.2), (0.75, 0.2, 2.2), 0.08, 8, IR)  # ring boss
	ring_c = [(0.75 + 0.24 * cos(a), 2.2 + 0.24 * sin(a)) for a in [2 * pi * k / 8 for k in range(8)]]
	for k in range(8):
		bar(bm, (ring_c[k][0], 0.22, ring_c[k][1]), (ring_c[(k + 1) % 8][0], 0.22, ring_c[(k + 1) % 8][1]), 0.05, 0.05, IR)
	o = new_obj("DoorUnit", bm, ["OT_Stone", "OT_StoneDark", "OT_Wood", "OT_WoodDark", "OT_Iron"], coll)
	bevel(o, 0.02, 1, 40)
	return [o]


def arcade_bay(coll):
	"""One 5-wide bay (x -2.5..2.5), 8 tall, 1.2 deep (y -0.6..0.6): half piers both ends, imposts, arch, spandrel."""
	bm = bmesh.new()
	ST, SD = 0, 1
	D0, D1 = -0.6, 0.6
	for x0, x1 in ((-2.5, -1.85), (1.85, 2.5)):
		cube(bm, x0, x1, D0, D1, 0.0, 4.6, ST)
		cube(bm, x0 - (0.08 if x0 < 0 else 0), x1 + (0.08 if x1 > 0 else 0), D0 - 0.08, D1 + 0.08, 4.6, 4.95, SD)  # impost
		cube(bm, x0 - (0.06 if x0 < 0 else 0), x1 + (0.06 if x1 > 0 else 0), D0 - 0.06, D1 + 0.06, 0.0, 0.5, SD)  # base
	arch_ring(bm, 0.0, D0 - 0.04, D1 + 0.04, 4.95, 1.85, 2.45, 9, ST, key_mi=SD)
	# spandrels: fill between the arch and the bay's top at 8 (two polygons following the arch)
	for s in (-1, 1):
		pts = [(s * 2.5, 4.95)] + [(s * 2.45 * cos(a), 4.95 + 2.45 * sin(a)) for a in [pi * k / 18 for k in range(0, 10)]][:: 1]
		pts = [(s * 2.5, 4.95)] + [(s * 2.45 * cos(pi * k / 18), 4.95 + 2.45 * sin(pi * k / 18)) for k in range(0, 10)] + [(0.0, 8.0), (s * 2.5, 8.0)]
		if s < 0:
			pts = list(reversed(pts))
		_xz_prism(bm, pts, D0, D1, ST)
	cube(bm, -2.5, 2.5, D0 - 0.1, D1 + 0.1, 7.6, 8.0, SD)  # string course on top
	o = new_obj("ArcadeBay", bm, ["OT_Stone", "OT_StoneDark"], coll)
	bevel(o, 0.03, 1, 40)
	return [o]


def balustrade(coll):
	bm = bmesh.new()
	ST, SD = 0, 1
	cube(bm, -2.5, 2.5, -0.32, 0.32, 0.0, 0.42, SD)
	for k in range(6):
		x = -2.08 + k * 0.833
		lathe(bm, [(0.2, 0.42), (0.24, 0.6), (0.12, 0.9), (0.27, 1.55), (0.12, 2.25), (0.2, 2.45), (0.2, 2.6)], 8, ST, cx=x)
	cube(bm, -2.5, 2.5, -0.36, 0.36, 2.6, 2.9, SD)
	_xz_prism(bm, [(-2.5, 2.9), (2.5, 2.9), (2.5, 3.0), (-2.5, 3.0)], -0.3, 0.3, SD)
	o = new_obj("Balustrade5", bm, ["OT_Stone", "OT_StoneDark"], coll)
	bevel(o, 0.02, 1, 40)
	bm = bmesh.new()
	cube(bm, -0.5, 0.5, -0.5, 0.5, 0.0, 3.0, 0)
	cube(bm, -0.6, 0.6, -0.6, 0.6, 3.0, 3.3, 1)
	cube(bm, -0.58, 0.58, -0.58, 0.58, 0.0, 0.45, 1)
	lathe(bm, [(0.3, 3.3), (0.36, 3.5), (0.12, 3.75), (0.02, 3.85)], 8, 0)
	p = new_obj("BalPost", bm, ["OT_Stone", "OT_StoneDark"], coll)
	bevel(p, 0.03, 1, 40)
	return [o], [p]


def belfry_top(coll):
	"""Sits on the tower shaft's top (origin there), 10 x 10."""
	bm = bmesh.new()
	ST, SD, BR, TR, TD, BL, IR = 0, 1, 2, 3, 4, 5, 6
	cube(bm, -5.4, 5.4, -5.4, 5.4, 0.0, 0.5, SD)  # cornice
	cube(bm, -5.2, 5.2, -5.2, 5.2, 0.5, 0.9, ST)
	# belfry: corner piers (brick with stone quoins) and two arches a side
	for sx in (-1, 1):
		for sy in (-1, 1):
			cube(bm, sx * 5.0 - 1.1 * (sx > 0), sx * 5.0 + 1.1 * (sx < 0), sy * 5.0 - 1.1 * (sy > 0), sy * 5.0 + 1.1 * (sy < 0), 0.9, 6.4, BR)
	for side in range(4):
		ang = side * pi / 2
		M = Matrix.Rotation(ang, 4, "Z")
		sub = bmesh.new()
		cube(sub, -0.45, 0.45, 4.3, 5.0, 0.9, 4.2, ST)  # centre pier
		for cx in (-2.0, 2.0):
			arch_ring(sub, cx, 4.3, 5.0, 4.2, 1.45, 1.95, 7, ST, key_mi=SD)
		# spandrel infill above the arches up to 6.4
		_xz_prism(sub, [(-3.9, 6.15), (3.9, 6.15), (3.9, 6.4), (-3.9, 6.4)], 4.3, 5.0, BR)
		for cx in (-2.0, 2.0):
			for s in (-1, 1):
				pts = [(cx + s * 1.95, 4.2)] + [(cx + s * 1.95 * cos(pi * k / 14), 4.2 + 1.95 * sin(pi * k / 14)) for k in range(0, 8)] + [(cx, 6.15), (cx + s * 1.95, 6.15)]
				if s < 0:
					pts = list(reversed(pts))
				_xz_prism(sub, pts, 4.35, 4.95, BR)
		me = bpy.data.meshes.new("tmp")
		sub.to_mesh(me)
		sub.free()
		me.transform(M)
		bm.from_mesh(me)
		bpy.data.meshes.remove(me)
	cube(bm, -5.3, 5.3, -5.3, 5.3, 6.4, 6.85, SD)  # upper cornice
	cube(bm, -5.0, 5.0, -5.0, 5.0, 6.85, 7.1, ST)
	# the bell
	lathe(bm, [(1.6, 1.6), (1.45, 1.9), (1.0, 3.0), (0.95, 3.6), (0.55, 3.95), (0.12, 4.05)], 12, BL)
	cube(bm, -0.12, 0.12, -4.45, 4.45, 4.0, 4.3, IR)  # headstock beam, into the centre piers
	tiled_pyramid(bm, 5.0, 7.0, 11.2, TR, TD)
	lathe(bm, [(0.35, 11.1), (0.45, 11.5), (0.3, 11.8), (0.08, 12.6)], 8, IR)
	o = new_obj("BelfryTop", bm, ["OT_Stone", "OT_StoneDark", "OT_Brick", "OT_Terracotta", "OT_TerraDark", "OT_Bell", "OT_Iron"], coll)
	bevel(o, 0.03, 1, 40)
	return [o]


def clock_face(coll):
	bm = bmesh.new()
	ST, FC, IR = 0, 1, 2
	pts_o = ngon2(0, 0, 2.3, 16)
	pts_i = ngon2(0, 0, 1.95, 16)
	for k in range(16):
		a0, a1, b0, b1 = pts_o[k], pts_o[(k + 1) % 16], pts_i[k], pts_i[(k + 1) % 16]
		_xz_prism(bm, [(b0[0], b0[1] + 2.3), (b1[0], b1[1] + 2.3), (a1[0], a1[1] + 2.3), (a0[0], a0[1] + 2.3)], 0.0, 0.3, ST)
	_xz_prism(bm, [(x, y + 2.3) for x, y in pts_i], 0.0, 0.18, FC)
	for k in range(12):
		a = k * pi / 6
		r0, r1 = 1.55, 1.85
		w = 0.09 if k % 3 else 0.16
		c0 = Vector((r0 * cos(a), 0.18, 2.3 + r0 * sin(a)))
		c1 = Vector((r1 * cos(a), 0.18, 2.3 + r1 * sin(a)))
		bar(bm, c0, c1, w, 0.05, IR, up=Vector((0, 1, 0)))
	bar(bm, (0, 0.24, 2.3), (0.75, 0.24, 2.3 + 0.75), 0.14, 0.05, IR, up=Vector((0, 1, 0)))  # hour hand
	bar(bm, (0, 0.28, 2.3), (-0.2, 0.28, 2.3 + 1.45), 0.09, 0.05, IR, up=Vector((0, 1, 0)))  # minute hand
	cyl(bm, (0, 0.18, 2.3), (0, 0.34, 2.3), 0.14, 8, IR)
	o = new_obj("ClockFace", bm, ["OT_Stone", "OT_ClockFace", "OT_Iron"], coll)
	bevel(o, 0.02, 1, 40)
	return [o]


def pavilion(coll):
	bm = bmesh.new()
	ST, SD, TR, TD, IR = 0, 1, 2, 3, 4
	cube(bm, -3.2, 3.2, -3.2, 3.2, 0.0, 0.35, SD)
	for sx in (-1, 1):
		for sy in (-1, 1):
			cube(bm, sx * 3.0 - 0.75 * (sx > 0), sx * 3.0 + 0.75 * (sx < 0), sy * 3.0 - 0.75 * (sy > 0), sy * 3.0 + 0.75 * (sy < 0), 0.35, 5.6, ST)
	for side in range(4):
		M = Matrix.Rotation(side * pi / 2, 4, "Z")
		sub = bmesh.new()
		arch_ring(sub, 0.0, 2.4, 3.0, 4.6, 2.25, 2.7, 7, ST, key_mi=SD)
		for s in (-1, 1):
			pts = [(s * 2.7, 4.6)] + [(s * 2.7 * cos(pi * k / 14), 4.6 + 2.7 * sin(pi * k / 14)) for k in range(0, 8)] + [(0.0, 7.4), (s * 2.7, 7.4)]
			if s < 0:
				pts = list(reversed(pts))
			_xz_prism(sub, pts, 2.45, 2.95, ST)
		me = bpy.data.meshes.new("tmp")
		sub.to_mesh(me)
		sub.free()
		me.transform(M)
		bm.from_mesh(me)
		bpy.data.meshes.remove(me)
	cube(bm, -3.35, 3.35, -3.35, 3.35, 7.3, 7.75, SD)
	tiled_pyramid(bm, 3.2, 7.7, 10.2, TR, TD)
	lathe(bm, [(0.25, 10.1), (0.3, 10.4), (0.05, 10.9)], 8, IR)
	o = new_obj("Pavilion", bm, ["OT_Stone", "OT_StoneDark", "OT_Terracotta", "OT_TerraDark", "OT_Iron"], coll)
	bevel(o, 0.03, 1, 40)
	return [o]


def cypress(coll, name, H, seed):
	bm = bmesh.new()
	LF, LD, WD = 0, 1, 2
	cyl(bm, (0, 0, -0.5), (0, 0, 1.2), 0.3, 8, WD)
	rnd = random.Random(seed)
	# stacked noisy lobes, widest a third of the way up, a pointed top
	k = 0
	z = 1.0
	while z < H - 0.5:
		t = z / H
		r = 1.5 * (1.0 - abs(t - 0.32) * 1.25) + 0.25
		h = H * 0.16
		blob(bm, Vector((rnd.uniform(-0.12, 0.12), rnd.uniform(-0.12, 0.12), z + h * 0.5)), r, r, h * 0.75, seed * 10 + k, LF if k % 2 == 0 else LD, subdiv=3, amp=0.3)
		z += h * 0.62
		k += 1
	o = new_obj(name, bm, ["OT_Leaf", "OT_LeafDark", "OT_WoodDark"], coll)
	for p in o.data.polygons:
		p.use_smooth = True
	box_uv(o, 5.0)
	return [o]


def bush(coll):
	bm = bmesh.new()
	blob(bm, Vector((0, 0, 0.95)), 1.5, 1.4, 1.1, 21, 0, subdiv=3, amp=0.28)
	blob(bm, Vector((0.7, 0.3, 0.8)), 0.9, 0.9, 0.8, 22, 1, subdiv=3, amp=0.28)
	o = new_obj("Bush", bm, ["OT_Leaf", "OT_LeafDark"], coll)
	for p in o.data.polygons:
		p.use_smooth = True
	box_uv(o, 5.0)
	return [o]


def hill(coll, name, rx, ry, peak, seed, n=24):
	"""Far Tuscan hill: a heightfield (every face up, no loose vertices) in grass, gold fields and olive patches."""
	rnd = random.Random(seed)
	bm = bmesh.new()
	H = {}
	bumps = [(rnd.uniform(-0.6, 0.6), rnd.uniform(-0.6, 0.6), rnd.uniform(0.25, 0.5), rnd.uniform(0.1, 0.25)) for _ in range(5)]
	for i in range(n + 1):
		for j in range(n + 1):
			u, v = -1 + 2 * i / n, -1 + 2 * j / n
			r = sqrt(u * u + v * v)
			h = max(0.0, 1 - r) ** 1.4 * 0.9
			for bx, by, br, bh in bumps:
				d = sqrt((u - bx) ** 2 + (v - by) ** 2)
				h += bh * max(0.0, 1 - d / br)
			h = h * peak
			if r >= 1.0:
				h = -20.0
			else:
				h -= 20.0 * min(1.0, max(0.0, (r - 0.82) / 0.18)) ** 1.5
			H[(i, j)] = (u * rx, v * ry, h)
	vs = {k: bm.verts.new(p) for k, p in H.items()}
	faces = []
	for i in range(n):
		for j in range(n):
			a, b, c, d = vs[(i, j)], vs[(i + 1, j)], vs[(i + 1, j + 1)], vs[(i, j + 1)]
			for tri in ((a, b, c), (a, c, d)):
				if max(t.co.z for t in tri) <= -19.99:
					continue
				faces.append(bm.faces.new(tri))
	bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
	bm.normal_update()
	for f in faces:
		cc = f.calc_center_median()
		val = noise.noise(Vector((cc.x / 90.0, cc.y / 90.0, seed)))
		f.material_index = 1 if val > 0.18 else (2 if val < -0.25 else 0)
	me = bpy.data.meshes.new(name)
	bm.to_mesh(me)
	bm.free()
	for mn in ("OT_Grass", "OT_Field", "OT_Olive"):
		me.materials.append(A.mat(mn))
	o = bpy.data.objects.new(name, me)
	coll.objects.link(o)
	for p in me.polygons:
		if p.normal.z < 0:
			p.flip()
	me.update()
	return [o]


PIECES = (
	"Fountain", "Well", "MarketStall", "Cart", "CafeSet", "PlanterBox", "PotBush", "WallLantern", "WindowUnit",
	"DoorUnit", "ArcadeBay", "Balustrade5", "BalPost", "BelfryTop", "ClockFace", "Pavilion", "CypressA", "CypressB",
	"Bush", "HillA", "HillB", "HillC",
)


def build_all():
	for c in [c for c in bpy.data.collections if c.name.startswith("Map_") and c.name[4:] in PIECES]:
		for o in list(c.all_objects):
			me = o.data
			bpy.data.objects.remove(o, do_unlink=True)
			if me is not None and me.users == 0:
				bpy.data.meshes.remove(me)
		bpy.data.collections.remove(c)
	root = A.coll(ROOT)

	def C(n):
		return A.coll("Map_" + n, root)

	made = []

	def fin(objs, n):
		col = C(n)
		for o in objs:
			if o.name not in col.objects:
				for c in o.users_collection:
					c.objects.unlink(o)
				col.objects.link(o)
		return SC.finalize(objs, col)

	made += fin(fountain(C("Fountain")), "Fountain")
	made += fin(well(C("Well")), "Well")
	made += fin(market_stall(C("MarketStall")), "MarketStall")
	made += fin(cart(C("Cart")), "Cart")
	made += fin(cafe_set(C("CafeSet")), "CafeSet")
	made += fin(planter_box(C("PlanterBox")), "PlanterBox")
	made += fin(pot_bush(C("PotBush")), "PotBush")
	made += fin(wall_lantern(C("WallLantern")), "WallLantern")
	made += fin(window_unit(C("WindowUnit")), "WindowUnit")
	made += fin(door_unit(C("DoorUnit")), "DoorUnit")
	made += fin(arcade_bay(C("ArcadeBay")), "ArcadeBay")
	bal, post = balustrade(C("Balustrade5"))
	made += fin(bal, "Balustrade5")
	made += fin(post, "BalPost")
	made += fin(belfry_top(C("BelfryTop")), "BelfryTop")
	made += fin(clock_face(C("ClockFace")), "ClockFace")
	made += fin(pavilion(C("Pavilion")), "Pavilion")
	made += cypress(C("CypressA"), "CypressA", 16.0, 3)
	made += cypress(C("CypressB"), "CypressB", 11.0, 5)
	made += bush(C("Bush"))
	made += hill(C("HillA"), "HillA", 420, 300, 70, 11)
	made += hill(C("HillB"), "HillB", 520, 260, 55, 23)
	made += hill(C("HillC"), "HillC", 300, 240, 45, 37)
	# smooth foliage and planters (organic), UVs on everything textured
	for o in made:
		if not o.data.uv_layers:
			box_uv(o, 6.0)
		if o.name.startswith(("PlanterBox", "PotBush")):
			for p in o.data.polygons:
				if p.material_index > 0:
					p.use_smooth = True
	for nm, (hx, _r) in A.PAL.items():
		m = bpy.data.materials.get(nm)
		if m is not None and nm.startswith("OT_"):
			m["rbx_material"] = RBX.get(nm, "SmoothPlastic")
			m["rbx_color"] = hx.lstrip("#").upper()
			if nm in TRANSPARENT:
				m["rbx_transparency"] = TRANSPARENT[nm]
	return {o.name: sum(len(p.vertices) - 2 for p in o.data.polygons) for o in made}
