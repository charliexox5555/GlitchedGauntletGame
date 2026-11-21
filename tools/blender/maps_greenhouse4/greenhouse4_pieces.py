"""Greenhouse4 kit (2026-11-21): the conservatory pieces Parts can't do well, for a Victorian iron-and-glass palm house
in a walled garden. Self-reviewed concept (the owner is away; vault/01 Design/Maps/Greenhouse4.md). Hard-surface
helpers from tools/blender/maps_snowpeak4/snowcat_model.py (flat 1-segment chamfers, baked). Every curve is a run of
flat plates (octagon columns, faceted urns and finials, a faceted lantern dome), nothing round; every part overlaps the
part that carries it (0.02-0.05) and never shares a plane with it.

    python tools/blender/lobby_v4/send.py tools/blender/maps_greenhouse4/run_greenhouse4.py --port 9897 --pid <pid>

Pieces (Map_<Piece>, export group Kit of map Greenhouse4):
  G4PalmRoof    the Palm House's hipped glass roof: four glass slopes from the 88.4 x 72.4 eaves (z 0) up 10 to a
                30 x 30 lead curb with an octagonal hole, iron rafters, purlins, hip ribs, eave bars.
  G4Lantern     the octagonal roof lantern on that curb: glazed drum (R 13), cornice, a three-tier faceted glass dome
                with iron ribs, a finial. Origin = drum base centre.
  G4FernRoof    the Fern House's gabled glass roof (18.8 x 48.4, ridge +5), rafters, purlin, ridge cresting, finials.
  G4Column      cast-iron column 9.03 tall: plinth, octagonal base moulding, shaft with a collar, flared capital,
                abacus, two brackets along +-Y.
  G4Rail4       a 4-long cast-iron balustrade (no posts): top rail, mid and bottom rails, balusters, a lattice band.
  G4Post        the rail post between G4Rail4 runs (square, capped with a pyramid finial). Rail top 3.29.
  G4Stair10     an iron stair rising 10 over 18 toward +Y, 5 wide: stringers, 14 treads, handrails with balusters.
  G4Pond        the lily pond (octagon, 26 across the flats): stone kerb + coping, basin lining, water, the island's
                kerb and soil. Origin = pond centre at ground level.
  G4LilyPad / G4Lily   a notched lily pad (r 1.4) and a water lily of angled petal plates.
  G4Tub         a 7 x 7 Versailles planter (painted panels in white frames, corner finials, soil) for the palms.
  G4Bench       a 6-long garden bench: cast-iron end frames, wood slats.
  G4Urn         a stone garden urn on a pedestal (faceted, 12 sides), planted in Studio.
  G4Sundial     a stone sundial on a baluster pedestal.
  G4LampPost    a garden lamp post (~10.6): octagonal shaft, crossarm, glazed lantern (*_G4_Lamp*), pyramid cap.
  G4PotStack    terracotta pots, stacked and loose.
  G4Barrow      a garden wheelbarrow.
  G4PottingBench  a potting bench with a back shelf, pots and a watering can.
  G4Gate        ornamental iron double gates (8 wide, faceted arch top, spear tips) between stone piers.
Units: studs; +X right, +Y front (Roblox -Z), +Z up; origin bottom centre unless noted. Our own designs.
"""
from math import atan2, cos, pi, radians, sin

import bmesh
import bpy
from mathutils import Vector

import arena_kit as A
import snowcat_model as SC

cube, prism, bar, cyl, bevel, new_obj, ngon2 = SC.cube, SC.prism, SC.bar, SC.cyl, SC.bevel, SC.new_obj, SC.ngon2

ROOT = "Greenhouse4Kit"
A.PAL.update(
	{
		"G4_Iron": ("#E2DED3", 0.6),
		"G4_IronDark": ("#33493D", 0.6),
		"G4_Glass": ("#CFE3D8", 0.1),
		"G4_Lead": ("#5D6264", 0.8),
		"G4_Stone": ("#D2C1A0", 0.9),
		"G4_StoneDark": ("#AE9B78", 0.9),
		"G4_Water": ("#3E6E62", 0.1),
		"G4_Soil": ("#4A3A2C", 0.95),
		"G4_Leaf": ("#4F7E3A", 0.7),
		"G4_Petal": ("#F2D7E3", 0.6),
		"G4_PetalCore": ("#F0C24A", 0.6),
		"G4_TubPaint": ("#3E5E4A", 0.7),
		"G4_Wood": ("#8C6845", 0.85),
		"G4_WoodDark": ("#5E4430", 0.85),
		"G4_Terracotta": ("#B4643F", 0.85),
		"G4_Galv": ("#9EA6A8", 0.55),
		"G4_Rubber": ("#2A2A2A", 0.9),
		"G4_Tread": ("#59645C", 0.7),
		"G4_Lamp": ("#FFE3B4", 0.4),
		"G4_Bronze": ("#7A6B4C", 0.6),
		"G4_Gilt": ("#C3A04E", 0.5),
	}
)
RBX = {
	"G4_Iron": "SmoothPlastic",
	"G4_IronDark": "Metal",
	"G4_Glass": "Glass",
	"G4_Lead": "Metal",
	"G4_Stone": "Limestone",
	"G4_StoneDark": "Limestone",
	"G4_Water": "Glass",
	"G4_Soil": "Ground",
	"G4_Wood": "Wood",
	"G4_WoodDark": "Wood",
	"G4_Galv": "Metal",
	"G4_Tread": "DiamondPlate",
	"G4_Lamp": "Neon",
	"G4_Bronze": "Metal",
	"G4_Gilt": "Metal",
}
TRANSPARENT = {"G4_Glass": 0.6, "G4_Water": 0.25}


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


# ------------------------------------------------------------------------------------------------ helpers
def ring(bm, r_out, r_in, z0, z1, n, mi, rot=None, cx=0.0, cy=0.0):
	"""A closed n-sided ring of trapezoid prisms (vertex radii)."""
	rot = pi / n if rot is None else rot
	o, i = ngon2(cx, cy, r_out, n, rot), ngon2(cx, cy, r_in, n, rot)
	for k in range(n):
		prism(bm, [o[k], o[(k + 1) % n], i[(k + 1) % n], i[k]], "z", z0, z1, mi)


def cone(bm, r, z0, z1, n, mi, rot=None, cx=0.0, cy=0.0):
	rot = pi / n if rot is None else rot
	base = [bm.verts.new((cx + x, cy + y, z0)) for x, y in ngon2(0, 0, r, n, rot)]
	top = bm.verts.new((cx, cy, z1))
	bm.faces.new(list(reversed(base))).material_index = mi
	for k in range(n):
		bm.faces.new((base[k], base[(k + 1) % n], top)).material_index = mi


def loft(bm, prof, n, mi, rot=None, cx=0.0, cy=0.0, cz=0.0, sx=1.0, sy=1.0, mi_top=None, cap_bot=True):
	"""A faceted solid of revolution: rings of n flat facets through (r, z) profile points, capped."""
	rot = pi / n if rot is None else rot
	rings = []
	for r, z in prof:
		rings.append([bm.verts.new((cx + x * sx, cy + y * sy, cz + z)) for x, y in ngon2(0, 0, r, n, rot)])
	for a, b in zip(rings, rings[1:]):
		for k in range(n):
			bm.faces.new((a[k], a[(k + 1) % n], b[(k + 1) % n], b[k])).material_index = mi
	if cap_bot:
		bm.faces.new(list(reversed(rings[0]))).material_index = mi
	bm.faces.new(rings[-1]).material_index = mi if mi_top is None else mi_top


def slab(bm, pts, t, mi):
	"""A thin plate on a planar convex polygon (3-D points), thickness t below it (against its normal)."""
	P = [Vector(p) for p in pts]
	nrm = Vector((0, 0, 0))
	for k in range(len(P)):
		a, b = P[k], P[(k + 1) % len(P)]
		nrm += Vector(((a.y - b.y) * (a.z + b.z), (a.z - b.z) * (a.x + b.x), (a.x - b.x) * (a.y + b.y)))
	nrm.normalize()
	top = [bm.verts.new(p) for p in P]
	bot = [bm.verts.new(p - nrm * t) for p in P]
	n = len(P)
	bm.faces.new(top).material_index = mi
	bm.faces.new(list(reversed(bot))).material_index = mi
	for k in range(n):
		bm.faces.new((bot[k], bot[(k + 1) % n], top[(k + 1) % n], top[k])).material_index = mi
	return nrm


def obj(name, bm, mats, coll, bev=0.03, ang=40):
	o = new_obj(name, bm, mats, coll)
	if bev:
		bevel(o, bev, 1, ang)
	return o


# ------------------------------------------------------------------------------------------------ the palm house roof
EX, EY, CX, CY, RH = 44.2, 36.2, 15.0, 15.0, 10.0


def palm_roof(coll):
	g = bmesh.new()
	GL = 0
	for s in (-1, 1):
		slab(g, [(-EX, s * EY, 0), (EX, s * EY, 0), (CX, s * CY, RH), (-CX, s * CY, RH)][:: s], 0.08, GL)
		slab(g, [(s * EX, -EY, 0), (s * EX, EY, 0), (s * CX, CY, RH), (s * CX, -CY, RH)][:: -s], 0.08, GL)
	glass = obj("G4PalmRoofGlass", g, ["G4_Glass"], coll, 0)

	b = bmesh.new()
	IR, LD = 0, 1
	lift = 0.1
	# long slopes (+-Y): rafters every 3, purlins at quarter heights
	for s in (-1, 1):
		n = Vector((0, s * RH, EY - CY)).normalized()
		x = -42.0
		while x <= 42.01:
			t = 1.0 if abs(x) <= CX else (EX - abs(x)) / (EX - CX)
			p0 = Vector((x, s * EY, 0)) + n * lift
			p1 = Vector((x, s * (EY - (EY - CY) * t), RH * t)) + n * lift
			bar(b, p0, p1, 0.14, 0.14, IR, up=n)
			x += 3.0
		for t in (0.25, 0.5, 0.75):
			hx = EX - (EX - CX) * t
			y = s * (EY - (EY - CY) * t)
			bar(b, Vector((-hx, y, RH * t)) + n * (lift + 0.02), Vector((hx, y, RH * t)) + n * (lift + 0.02), 0.12, 0.12, IR, up=n)
	# end slopes (+-X)
	for s in (-1, 1):
		n = Vector((s * RH, 0, EX - CX)).normalized()
		y = -33.0
		while y <= 33.01:
			t = 1.0 if abs(y) <= CY else (EY - abs(y)) / (EY - CY)
			p0 = Vector((s * EX, y, 0)) + n * lift
			p1 = Vector((s * (EX - (EX - CX) * t), y, RH * t)) + n * lift
			bar(b, p0, p1, 0.14, 0.14, IR, up=n)
			y += 3.0
		for t in (0.25, 0.5, 0.75):
			hy = EY - (EY - CY) * t
			x = s * (EX - (EX - CX) * t)
			bar(b, Vector((x, -hy, RH * t)) + n * (lift + 0.02), Vector((x, hy, RH * t)) + n * (lift + 0.02), 0.12, 0.12, IR, up=n)
	# hip ribs and eave bars
	for sx in (-1, 1):
		for sy in (-1, 1):
			d = Vector((sx * EX, sy * EY, 0))
			e = Vector((sx * CX, sy * CY, RH))
			up = Vector((sx * 0.6, sy * 0.6, 1.0)).normalized()
			bar(b, d + up * 0.14, e + up * 0.14, 0.32, 0.24, IR, up=up)
	for s in (-1, 1):
		bar(b, (-EX - 0.2, s * EY, 0.12), (EX + 0.2, s * EY, 0.12), 0.34, 0.3, IR)
		bar(b, (s * EX, -EY + 0.15, 0.13), (s * EX, EY - 0.15, 0.13), 0.34, 0.3, IR)
	# the lead curb round the lantern: a square flat with an octagonal hole
	R = 13.0
	oc = ngon2(0, 0, R, 8, pi / 8)
	sq = 15.5
	for k in range(8):
		a0 = atan2(oc[k][1], oc[k][0])
		a1 = atan2(oc[(k + 1) % 8][1], oc[(k + 1) % 8][0])

		def edge(a):
			c, s_ = cos(a), sin(a)
			m = sq / max(abs(c), abs(s_))
			return (c * m, s_ * m)

		pts = [oc[k], oc[(k + 1) % 8], edge(a1)]
		mid = (a0 + a1) / 2 if a1 > a0 else (a0 + a1 + 2 * pi) / 2
		cm = edge(mid)
		if abs(abs(cm[0]) - sq) < 1e-3 and abs(abs(cm[1]) - sq) < 1e-3:
			pts.append(cm)
		else:
			cx_, cy_ = (sq if cos(mid) > 0 else -sq), (sq if sin(mid) > 0 else -sq)
			if abs(cos(mid)) > 0.3 and abs(sin(mid)) > 0.3:
				pts.append((cx_, cy_))
		pts.append(edge(a0))
		prism(b, pts, "z", RH - 0.3, RH + 0.05, LD)
	ring(b, (sq + 0.3) * 1.41421, (sq - 0.1) * 1.41421, RH - 0.35, RH + 0.15, 4, IR, rot=pi / 4)
	bars = obj("G4PalmRoofIron", b, ["G4_Iron", "G4_Lead"], coll)
	return [glass, bars]


def lantern(coll):
	R = 13.0
	g = bmesh.new()
	GL = 0

	def V8(r, z, k):
		x, y = ngon2(0, 0, r, 8, pi / 8)[k % 8]
		return (x, y, z)

	for k in range(8):
		slab(g, [V8(R - 0.25, 0.3, k), V8(R - 0.25, 0.3, k + 1), V8(R - 0.25, 5.7, k + 1), V8(R - 0.25, 5.7, k)], 0.08, GL)
		for (r0, z0, r1, z1) in ((R - 0.2, 6.4, 9.0, 9.6), (8.8, 9.75, 4.6, 12.4), (4.5, 12.45, 1.7, 14.0)):
			slab(g, [V8(r0, z0, k + 1), V8(r0, z0, k), V8(r1, z1, k), V8(r1, z1, k + 1)], 0.08, GL)
	glass = obj("G4LanternGlass", g, ["G4_Glass"], coll, 0)
	b = bmesh.new()
	IR, GI = 0, 1
	ring(b, R + 0.35, R - 0.7, -0.03, 0.35, 8, IR, rot=pi / 8)
	ring(b, R + 0.05, R - 0.45, 2.95, 3.12, 8, IR, rot=pi / 8)
	ring(b, R + 0.6, R - 0.5, 5.6, 6.15, 8, IR, rot=pi / 8)
	ring(b, R + 0.3, R - 0.5, 6.12, 6.45, 8, IR, rot=pi / 8)
	ring(b, 9.25, 8.6, 9.5, 9.8, 8, IR, rot=pi / 8)
	ring(b, 4.85, 4.35, 12.3, 12.55, 8, IR, rot=pi / 8)
	for k in range(8):
		x, y, _ = V8(R - 0.15, 0, k)
		a = atan2(y, x)
		bar(b, (x, y, 0.3), (x, y, 5.65), 0.36, 0.3, IR, up=Vector((cos(a), sin(a), 0)))
		am = a + pi / 8
		for f in (1 / 3, 2 / 3):  # intermediate mullions
			p = Vector(V8(R - 0.2, 0, k)).lerp(Vector(V8(R - 0.2, 0, k + 1)), f)
			bar(b, (p.x, p.y, 0.3), (p.x, p.y, 5.65), 0.16, 0.16, IR, up=Vector((cos(am), sin(am), 0)))
		ud = Vector((cos(a), sin(a), 0.9)).normalized()
		pts = [Vector(V8(R - 0.05, 6.4, k)), Vector(V8(9.0, 9.7, k)), Vector(V8(4.6, 12.5, k)), Vector(V8(1.6, 14.1, k))]
		for p0, p1 in zip(pts, pts[1:]):
			bar(b, p0 + ud * 0.12, p1 + ud * 0.12, 0.3, 0.24, IR, up=ud)
	loft(b, [(1.9, 13.9), (1.9, 14.3), (1.1, 14.55), (0.55, 14.95), (0.5, 16.0), (0.95, 16.25), (0.95, 16.45), (0.4, 16.7)], 8, IR)
	loft(b, [(0.38, 16.65), (0.75, 17.05), (0.75, 17.3), (0.3, 17.7)], 8, GI)
	loft(b, [(0.28, 17.65), (0.2, 18.4)], 8, IR)
	cone(b, 0.2, 18.38, 19.3, 8, GI)
	iron = obj("G4LanternIron", b, ["G4_Iron", "G4_Gilt"], coll)
	return [glass, iron]


def fern_roof(coll):
	W, L, H = 9.4, 24.2, 5.0
	g = bmesh.new()
	for s in (-1, 1):
		slab(g, [(s * W, -L, 0), (s * W, L, 0), (0, L, H), (0, -L, H)][:: -s], 0.08, 0)
	for s in (-1, 1):  # gable ends, set in 0.12
		yy = s * (L - 0.12)
		slab(g, [(-W + 0.15, yy, 0.02), (W - 0.15, yy, 0.02), (0, yy, H - 0.15)][:: s], 0.08, 0)
	glass = obj("G4FernRoofGlass", g, ["G4_Glass"], coll, 0)
	b = bmesh.new()
	IR = 0
	for s in (-1, 1):
		n = Vector((s * H, 0, W)).normalized()
		y = -L + 0.1
		while y <= L - 0.09:
			bar(b, Vector((s * W, y, 0)) + n * 0.1, Vector((0, y, H)) + n * 0.1, 0.14, 0.14, IR, up=n)
			y += (2 * L - 0.2) / 20
		bar(b, Vector((s * W / 2, -L, H / 2)) + n * 0.12, Vector((s * W / 2, L, H / 2)) + n * 0.12, 0.12, 0.12, IR, up=n)
		bar(b, (s * W, -L - 0.2, 0.12), (s * W, L + 0.2, 0.12), 0.34, 0.3, IR)
		# gable rakes
		for sy in (-1, 1):
			bar(b, (s * W, sy * L, 0.1), (0, sy * L, H + 0.05), 0.26, 0.26, IR, up=Vector((s * H, 0, W)).normalized())
	bar(b, (0, -L - 0.25, H + 0.1), (0, L + 0.25, H + 0.1), 0.34, 0.3, IR)
	# ridge cresting: a zig-zag band
	y = -L + 0.3
	k = 0
	while y < L - 1.2:
		z0, z1 = (H + 0.22, H + 0.75) if k % 2 == 0 else (H + 0.75, H + 0.22)
		bar(b, (0, y, z0), (0, y + 1.2, z1), 0.06, 0.08, IR, up=Vector((1, 0, 0)))
		y += 1.2
		k += 1
	bar(b, (0, -L + 0.2, H + 0.78), (0, L - 0.2, H + 0.78), 0.1, 0.08, IR)
	for sy in (-1, 1):
		loft(b, [(0.28, H + 0.15), (0.28, H + 0.4), (0.14, H + 0.6), (0.2, H + 1.0), (0.08, H + 1.4)], 8, IR, cy=sy * L)
		cone(b, 0.08, H + 1.38, H + 1.8, 8, IR, cy=sy * L)
	iron = obj("G4FernRoofIron", b, ["G4_Iron"], coll)
	return [glass, iron]


# ------------------------------------------------------------------------------------------------ ironwork
def column(coll):
	b = bmesh.new()
	IR = 0
	cube(b, -0.62, 0.62, -0.62, 0.62, 0.0, 0.5, IR)
	loft(b, [(0.55, 0.48), (0.55, 0.7), (0.4, 0.9), (0.33, 1.05), (0.33, 8.2), (0.4, 8.35), (0.37, 8.45), (0.56, 8.7), (0.64, 8.86)], 8, IR, rot=pi / 8)
	loft(b, [(0.42, 3.9), (0.42, 4.12)], 8, IR, rot=pi / 8)
	cube(b, -0.7, 0.7, -0.7, 0.7, 8.83, 9.03, IR)
	for s in (-1, 1):
		bar(b, (0, s * 0.25, 7.0), (0, s * 1.55, 8.9), 0.14, 0.2, IR, up=Vector((1, 0, 0)))
		bar(b, (0, s * 0.3, 8.1), (0, s * 1.0, 8.9), 0.1, 0.12, IR, up=Vector((1, 0, 0)))
	return [obj("G4Column", b, ["G4_Iron"], coll)]


def rail4(coll):
	b = bmesh.new()
	IR = 0
	bar(b, (-2.05, 0, 3.21), (2.05, 0, 3.21), 0.24, 0.14, IR)
	bar(b, (-2.05, 0, 2.55), (2.05, 0, 2.55), 0.12, 0.1, IR)
	bar(b, (-2.05, 0, 0.34), (2.05, 0, 0.34), 0.14, 0.12, IR)
	x = -1.83
	while x <= 1.84:
		bar(b, (x, 0, 0.28), (x, 0, 3.16), 0.06, 0.06, IR)
		x += 0.366
	x = -1.95
	while x < 1.9:
		bar(b, (x, 0.02, 2.6), (x + 0.65, 0.02, 3.15), 0.05, 0.05, IR, up=Vector((0, 1, 0)))
		bar(b, (x, -0.02, 3.15), (x + 0.65, -0.02, 2.6), 0.05, 0.05, IR, up=Vector((0, 1, 0)))
		x += 0.65
	return [obj("G4Rail4", b, ["G4_Iron"], coll, 0.015)]


def post(coll):
	b = bmesh.new()
	IR = 0
	cube(b, -0.24, 0.24, -0.24, 0.24, 0.0, 0.16, IR)
	cube(b, -0.16, 0.16, -0.16, 0.16, 0.14, 3.3, IR)
	cube(b, -0.22, 0.22, -0.22, 0.22, 3.28, 3.4, IR)
	cone(b, 0.25, 3.38, 3.75, 4, IR, rot=pi / 4)
	return [obj("G4Post", b, ["G4_Iron"], coll, 0.02)]


def stair10(coll):
	b = bmesh.new()
	IR, TR = 0, 1
	k_ = 10.0 / 18.0
	for s in (-1, 1):
		prism(b, [(0.0, 0.0), (1.6, 0.0), (18.0, 9.11), (18.0, 10.0), (17.0, 10.0), (0.0, 0.55)], "x", s * 2.38, s * 2.62, IR)
	for k in range(1, 15):
		z = 10.0 * k / 15.0
		cube(b, -2.41, 2.41, (k - 1) * 1.2 - 0.06, k * 1.2 + 0.06, z - 0.12, z, TR)
	for s in (-1, 1):
		x = s * 2.5
		p0 = Vector((x, 0.3, 3.2 + k_ * 0.3))
		p1 = Vector((x, 18.0, 3.2 + 10.0))
		bar(b, p0, p1, 0.2, 0.14, IR, up=Vector((1, 0, 0)).cross(p1 - p0).normalized() * -1)
		bar(b, (x, 0.3, 1.7 + k_ * 0.3), (x, 18.0, 11.7), 0.1, 0.1, IR, up=Vector((0, -k_, 1)).normalized())
		y = 0.9
		while y < 17.8:
			zb = k_ * y + 0.5
			bar(b, (x, y, zb), (x, y, k_ * y + 3.15), 0.06, 0.06, IR)
			y += 0.6
		bar(b, (x, 0.25, 0.0), (x, 0.25, 3.6), 0.22, 0.22, IR)  # newel
		cone(b, 0.17, 3.58, 3.9, 4, IR, rot=pi / 4, cx=x, cy=0.25)
	return [obj("G4Stair10", b, ["G4_Iron", "G4_Tread"], coll, 0.02)]


def gate(coll):
	b = bmesh.new()
	IR, ST, SD = 0, 1, 2
	xs = [-4.0, -2.0, 0.0, 2.0, 4.0]
	zs = [8.2, 9.0, 9.4, 9.0, 8.2]

	def top(x):
		for i in range(4):
			if xs[i] <= x <= xs[i + 1]:
				f = (x - xs[i]) / (xs[i + 1] - xs[i])
				return zs[i] + (zs[i + 1] - zs[i]) * f
		return zs[0]

	x = -3.75
	while x <= 3.76:
		z = top(x)
		bar(b, (x, 0, 0.3), (x, 0, z + 0.05), 0.09, 0.09, IR)
		cone(b, 0.11, z + 0.03, z + 0.4, 4, IR, rot=pi / 4, cx=x)
		x += 0.5
	for z in (0.35, 1.3, 7.0):
		bar(b, (-4.05, 0, z), (4.05, 0, z), 0.14, 0.16, IR)
	for i in range(4):
		bar(b, (xs[i] - (0.05 if i == 0 else 0), 0, zs[i] - 0.3), (xs[i + 1] + (0.05 if i == 3 else 0), 0, zs[i + 1] - 0.3), 0.14, 0.16, IR)
	for s in (-1, 1):
		bar(b, (s * 0.1, 0, 0.2), (s * 0.1, 0, 9.2), 0.14, 0.14, IR)
		bar(b, (s * 3.95, 0, 0.2), (s * 3.95, 0, 8.3), 0.16, 0.16, IR)
		x = s * 0.3
		while abs(x) < 3.7:  # lattice band
			bar(b, (x, 0.03, 7.05), (x + s * 0.6, 0.03, 7.6), 0.05, 0.05, IR, up=Vector((0, 1, 0)))
			bar(b, (x, -0.03, 7.6), (x + s * 0.6, -0.03, 7.05), 0.05, 0.05, IR, up=Vector((0, 1, 0)))
			x += s * 0.6
		cube(b, s * 4.0, s * 5.6, -0.8, 0.8, 0.0, 10.0, ST)
		cube(b, s * 3.88, s * 5.72, -0.92, 0.92, 9.96, 10.4, SD)
		cube(b, s * 3.9, s * 5.7, -0.9, 0.9, 0.0, 0.7, SD)
		loft(b, [(0.45, 10.38), (0.8, 10.75), (0.8, 11.0), (0.45, 11.4)], 8, SD, cx=s * 4.8)
		cone(b, 0.45, 11.38, 11.75, 8, SD, cx=s * 4.8)
	return [obj("G4Gate", b, ["G4_IronDark", "G4_Stone", "G4_StoneDark"], coll, 0.02)]


# ------------------------------------------------------------------------------------------------ water and plants
def pond(coll):
	b = bmesh.new()
	ST, SD, SO = 0, 1, 2
	c8 = cos(pi / 8)
	R = 13.0 / c8
	ring(b, R, (13.0 - 1.2) / c8, -0.03, 0.72, 8, SD, rot=pi / 8)
	ring(b, R + 0.18, (13.0 - 1.32) / c8, 0.7, 0.95, 8, ST, rot=pi / 8)
	ring(b, (13.0 - 1.15) / c8, (13.0 - 1.45) / c8, -1.6, 0.05, 8, SD, rot=pi / 8)
	r_i = 3.5 / c8
	ring(b, r_i, (3.5 - 0.8) / c8, -1.6, 0.6, 8, SD, rot=pi / 8)
	ring(b, r_i + 0.15, (3.5 - 0.92) / c8, 0.58, 0.8, 8, ST, rot=pi / 8)
	prism(b, ngon2(0, 0, (3.5 - 0.75) / c8, 8, pi / 8), "z", -1.6, 0.5, SO)
	rim = obj("G4PondStone", b, ["G4_Stone", "G4_StoneDark", "G4_Soil"], coll)
	w = bmesh.new()
	outer = ngon2(0, 0, (13.0 - 1.18) / c8, 8, pi / 8)
	prism(w, outer, "z", -0.5, -0.35, 0)
	water = obj("G4PondWater", w, ["G4_Water"], coll, 0)
	return [rim, water]


def lily_pad(coll):
	b = bmesh.new()
	r, n, notch = 1.4, 16, 0.32
	angs = [notch + (2 * pi - 2 * notch) * k / n for k in range(n + 1)]
	top = [b.verts.new((r * cos(a), r * sin(a), 0.05)) for a in angs]
	bot = [b.verts.new((r * cos(a), r * sin(a), 0.0)) for a in angs]
	ct, cb = b.verts.new((0, 0, 0.05)), b.verts.new((0, 0, 0.0))
	for k in range(n):
		b.faces.new((ct, top[k], top[k + 1]))
		b.faces.new((cb, bot[k + 1], bot[k]))
		b.faces.new((bot[k], bot[k + 1], top[k + 1], top[k]))
	b.faces.new((cb, bot[0], top[0], ct))
	b.faces.new((ct, top[n], bot[n], cb))
	return [obj("G4LilyPad", b, ["G4_Leaf"], coll, 0)]


def lily(coll):
	b = bmesh.new()
	PE, CO = 0, 1
	for ring_i, (cnt, tilt, size, off) in enumerate(((8, 28, 1.0, 0.0), (8, 55, 0.75, pi / 8))):
		for k in range(cnt):
			a = off + 2 * pi * k / cnt
			rr = Vector((cos(a), sin(a), 0))
			tt = Vector((-sin(a), cos(a), 0))
			dd = (rr * cos(radians(tilt)) + Vector((0, 0, 1)) * sin(radians(tilt))).normalized()
			z0 = Vector((0, 0, 0.04 + 0.03 * ring_i))
			pts = [z0 + rr * 0.1, z0 + rr * 0.1 + dd * 0.22 * size + tt * 0.13 * size, z0 + rr * 0.1 + dd * 0.55 * size, z0 + rr * 0.1 + dd * 0.22 * size - tt * 0.13 * size]
			slab(b, [tuple(p) for p in pts], 0.03, PE)
	loft(b, [(0.16, 0.0), (0.2, 0.12), (0.1, 0.24)], 8, CO)
	return [obj("G4Lily", b, ["G4_Petal", "G4_PetalCore"], coll, 0)]


def tub(coll):
	b = bmesh.new()
	IR, TP, SO = 0, 1, 2
	H = 3.6
	for sx in (-1, 1):
		for sy in (-1, 1):
			cube(b, sx * 3.5, sx * 2.85, sy * 3.5, sy * 2.85, 0.32, H, IR)
			cube(b, sx * 3.45, sx * 2.9, sy * 3.45, sy * 2.9, 0.0, 0.36, TP)
			loft(b, [(0.3, H - 0.02), (0.3, H + 0.12), (0.17, H + 0.24), (0.24, H + 0.46), (0.11, H + 0.66)], 8, IR, cx=sx * 3.175, cy=sy * 3.175)
			cone(b, 0.11, H + 0.64, H + 0.9, 8, IR, cx=sx * 3.175, cy=sy * 3.175)
	for s in (-1, 1):
		cube(b, -2.9, 2.9, s * 3.1, s * 3.28, 0.6, H - 0.35, TP)  # panels (set back 0.22)
		cube(b, s * 3.1, s * 3.28, -2.9, 2.9, 0.62, H - 0.37, TP)
		cube(b, -2.9, 2.9, s * 3.05, s * 3.42, H - 0.42, H - 0.1, IR)
		cube(b, s * 3.05, s * 3.42, -2.88, 2.88, H - 0.44, H - 0.12, IR)
		cube(b, -2.9, 2.9, s * 3.05, s * 3.42, 0.34, 0.68, IR)
		cube(b, s * 3.05, s * 3.42, -2.88, 2.88, 0.36, 0.66, IR)
		cube(b, -0.15, 0.15, s * 3.24, s * 3.34, 0.66, H - 0.4, IR)  # centre muntin
		cube(b, s * 3.24, s * 3.34, -0.15, 0.15, 0.68, H - 0.42, IR)
	cube(b, -2.95, 2.95, -2.95, 2.95, 0.3, H - 0.2, SO)
	return [obj("G4Tub", b, ["G4_Iron", "G4_TubPaint", "G4_Soil"], coll)]


# ------------------------------------------------------------------------------------------------ garden props
def bench(coll):
	b = bmesh.new()
	IR, WD = 0, 1
	for x0 in (-2.6, 2.6):
		bar(b, (x0, -0.95, 0.0), (x0, -0.82, 1.55), 0.2, 0.22, IR)
		bar(b, (x0, 0.85, 0.0), (x0, 0.62, 1.55), 0.2, 0.22, IR)
		bar(b, (x0, 0.62, 1.5), (x0, 1.0, 3.3), 0.2, 0.2, IR)
		bar(b, (x0, -1.08, 1.48), (x0, 0.75, 1.48), 0.2, 0.18, IR)
		bar(b, (x0, 0.78, 2.45), (x0, -1.1, 2.35), 0.22, 0.14, IR)
		bar(b, (x0, -1.1, 2.4), (x0, -1.2, 2.05), 0.2, 0.14, IR)
		bar(b, (x0, -0.86, 1.55), (x0, -0.98, 2.36), 0.14, 0.14, IR)
		cube(b, x0 - 0.16, x0 + 0.16, -1.08, -0.78, 0.0, 0.08, IR)
		cube(b, x0 - 0.16, x0 + 0.16, 0.7, 1.0, 0.0, 0.08, IR)
	bar(b, (0, -0.95, 1.46), (0, 0.72, 1.46), 0.16, 0.14, IR)
	for k in range(5):
		y = -0.92 + k * 0.4
		cube(b, -2.98, 2.98, y - 0.16, y + 0.16, 1.55, 1.69, WD)
	up = Vector((0, -1.3, 0.3)).normalized()
	for f in (0.22, 0.55, 0.88):
		y, z = 0.66 + 0.3 * f, 1.85 + 1.3 * f
		bar(b, (-2.98, y, z), (2.98, y, z), 0.34, 0.1, WD, up=up)
	return [obj("G4Bench", b, ["G4_IronDark", "G4_Wood"], coll)]


def urn(coll):
	b = bmesh.new()
	ST, SD, SO = 0, 1, 2
	cube(b, -0.8, 0.8, -0.8, 0.8, 0.0, 0.24, SD)
	cube(b, -0.66, 0.66, -0.66, 0.66, 0.22, 1.55, ST)
	cube(b, -0.82, 0.82, -0.82, 0.82, 1.53, 1.76, SD)
	loft(b, [(0.46, 1.74), (0.46, 1.9), (0.29, 2.05), (0.25, 2.35), (0.5, 2.55), (0.78, 2.85), (0.9, 3.2), (0.84, 3.45), (0.98, 3.52), (0.98, 3.7), (0.86, 3.7), (0.86, 3.56)], 12, ST)
	loft(b, [(0.84, 3.52), (0.84, 3.62)], 12, SO)
	return [obj("G4Urn", b, ["G4_Stone", "G4_StoneDark", "G4_Soil"], coll)]


def sundial(coll):
	b = bmesh.new()
	ST, BR = 0, 1
	loft(b, [(0.72, 0.0), (0.72, 0.26), (0.52, 0.42), (0.32, 0.72), (0.27, 2.2), (0.44, 2.5), (0.64, 2.7), (0.64, 2.9)], 8, ST, rot=pi / 8)
	loft(b, [(0.56, 2.88), (0.56, 2.95)], 8, BR, rot=pi / 8)
	prism(b, [(-0.35, 2.93), (0.32, 2.93), (-0.35, 3.48)], "y", -0.03, 0.03, BR)
	for k in range(8):
		a = 2 * pi * k / 8
		bar(b, (0.36 * cos(a), 0.36 * sin(a), 2.96), (0.5 * cos(a), 0.5 * sin(a), 2.96), 0.04, 0.04, BR)
	return [obj("G4Sundial", b, ["G4_Stone", "G4_Bronze"], coll)]


def lamp_post(coll):
	b = bmesh.new()
	IR, LP = 0, 1
	cube(b, -0.56, 0.56, -0.56, 0.56, 0.0, 0.3, IR)
	loft(b, [(0.5, 0.28), (0.5, 0.6), (0.33, 0.9), (0.28, 1.6), (0.21, 1.9), (0.17, 7.6), (0.25, 7.8), (0.25, 8.0), (0.17, 8.1), (0.17, 8.42)], 8, IR, rot=pi / 8)
	bar(b, (-0.8, 0, 7.62), (0.8, 0, 7.62), 0.1, 0.1, IR)
	loft(b, [(0.3, 8.38), (0.44, 8.5), (0.44, 8.56)], 4, IR, rot=pi / 4)
	loft(b, [(0.34, 8.54), (0.52, 9.5)], 4, LP, rot=pi / 4)
	for k in range(4):
		a = pi / 4 + k * pi / 2
		bar(b, (0.36 * cos(a), 0.36 * sin(a), 8.52), (0.55 * cos(a), 0.55 * sin(a), 9.52), 0.07, 0.07, IR)
	loft(b, [(0.72, 9.48), (0.72, 9.58), (0.16, 10.02)], 4, IR, rot=pi / 4)
	loft(b, [(0.14, 10.0), (0.1, 10.3)], 8, IR)
	cone(b, 0.1, 10.28, 10.6, 4, IR, rot=pi / 4)
	return [obj("G4LampPost", b, ["G4_IronDark", "G4_Lamp"], coll, 0.02)]


def pot(b, x, y, z0, r, h, TC, SO, soil=True):
	loft(b, [(0.7 * r, z0), (0.95 * r, z0 + 0.78 * h), (1.08 * r, z0 + 0.78 * h), (1.08 * r, z0 + h), (0.9 * r, z0 + h), (0.84 * r, z0 + h - 0.12)], 10, TC, cx=x, cy=y, mi_top=SO if soil else TC)


def pot_stack(coll):
	b = bmesh.new()
	TC, SO = 0, 1
	for k in range(4):
		pot(b, 0, 0, k * 0.22, 0.55, 0.85, TC, TC, False)
	pot(b, 1.25, 0.2, 0.0, 0.7, 1.05, TC, SO)
	pot(b, 0.55, -1.05, 0.0, 0.42, 0.7, TC, SO)
	return [obj("G4PotStack", b, ["G4_Terracotta", "G4_Soil"], coll, 0.02)]


def barrow(coll):
	b = bmesh.new()
	TP, WD, IR, RB = 0, 1, 2, 3
	loft(b, [(0.95, 1.05), (1.55, 1.95), (1.62, 1.95), (1.62, 2.06), (1.48, 2.06), (0.9, 1.18)], 4, TP, rot=pi / 4, sx=0.8, sy=1.0)
	for s in (-1, 1):
		bar(b, (s * 0.62, 1.25, 1.12), (s * 0.78, -2.6, 1.85), 0.14, 0.14, WD)
		bar(b, (s * 0.62, -0.9, 1.15), (s * 0.66, -1.1, 0.0), 0.1, 0.1, IR)
		bar(b, (s * 0.6, 1.25, 1.1), (s * 0.12, 1.9, 0.55), 0.08, 0.08, IR)
	cyl(b, (-0.16, 1.9, 0.55), (0.16, 1.9, 0.55), 0.55, 10, RB)
	cyl(b, (-0.22, 1.9, 0.55), (0.22, 1.9, 0.55), 0.17, 8, IR)
	return [obj("G4Barrow", b, ["G4_TubPaint", "G4_Wood", "G4_IronDark", "G4_Rubber"], coll, 0.02)]


def potting_bench(coll):
	b = bmesh.new()
	WD, WK, TC, SO, GV = 0, 1, 2, 3, 4
	for sx in (-1, 1):
		for sy in (-1, 1):
			cube(b, sx * 3.85, sx * 3.55, sy * 1.15, sy * 0.85, 0.0, 2.88, WK)
	for k in range(4):
		y = -1.3 + k * 0.65
		cube(b, -4.0, 4.0, y + 0.03, y + 0.62, 2.86, 3.04, WD)
	for k in range(3):
		y = -1.1 + k * 0.75
		cube(b, -3.6, 3.6, y + 0.03, y + 0.7, 0.8, 0.94, WD)
	cube(b, -4.0, 4.0, 1.08, 1.26, 3.0, 4.65, WK)
	cube(b, -4.05, 4.05, 0.55, 1.3, 4.45, 4.6, WD)
	for x in (-3.4, 3.4):
		bar(b, (x, 1.1, 3.75), (x, 0.62, 4.46), 0.12, 0.12, WK, up=Vector((1, 0, 0)))
	pot(b, -2.4, -0.3, 3.03, 0.5, 0.75, TC, SO)
	pot(b, -1.3, -0.4, 3.03, 0.38, 0.6, TC, SO)
	pot(b, 2.6, -0.2, 3.03, 0.45, 0.7, TC, SO)
	for x in (-2.8, -2.0, 1.6, 2.5):
		pot(b, x, 0.92, 4.58, 0.28, 0.45, TC, SO)
	# a watering can
	loft(b, [(0.36, 3.03), (0.36, 3.6), (0.24, 3.72)], 8, GV, cx=0.6, cy=-0.3)
	bar(b, (0.85, -0.3, 3.15), (1.6, -0.3, 3.85), 0.1, 0.1, GV)
	loft(b, [(0.06, 0.0), (0.11, 0.12)], 6, GV, cx=1.62, cy=-0.3, cz=3.8)
	bar(b, (0.3, -0.3, 3.55), (0.3, -0.3, 3.95), 0.07, 0.07, GV)
	bar(b, (0.3, -0.3, 3.95), (0.85, -0.3, 3.95), 0.07, 0.07, GV)
	bar(b, (0.85, -0.3, 3.95), (0.85, -0.3, 3.55), 0.07, 0.07, GV)
	return [obj("G4PottingBench", b, ["G4_Wood", "G4_WoodDark", "G4_Terracotta", "G4_Soil", "G4_Galv"], coll, 0.02)]


PIECES = (
	"G4PalmRoof", "G4Lantern", "G4FernRoof", "G4Column", "G4Rail4", "G4Post", "G4Stair10", "G4Gate", "G4Pond",
	"G4LilyPad", "G4Lily", "G4Tub", "G4Bench", "G4Urn", "G4Sundial", "G4LampPost", "G4PotStack", "G4Barrow",
	"G4PottingBench",
)
BUILD = {
	"G4PalmRoof": palm_roof, "G4Lantern": lantern, "G4FernRoof": fern_roof, "G4Column": column, "G4Rail4": rail4,
	"G4Post": post, "G4Stair10": stair10, "G4Gate": gate, "G4Pond": pond, "G4LilyPad": lily_pad, "G4Lily": lily,
	"G4Tub": tub, "G4Bench": bench, "G4Urn": urn, "G4Sundial": sundial, "G4LampPost": lamp_post,
	"G4PotStack": pot_stack, "G4Barrow": barrow, "G4PottingBench": potting_bench,
}


def build_all():
	for c in [c for c in bpy.data.collections if c.name.startswith("Map_") and c.name[4:] in PIECES]:
		for o in list(c.all_objects):
			me = o.data
			bpy.data.objects.remove(o, do_unlink=True)
			if me is not None and me.users == 0:
				bpy.data.meshes.remove(me)
		bpy.data.collections.remove(c)
	root = A.coll(ROOT)
	made = []
	for n in PIECES:
		col = A.coll("Map_" + n, root)
		made += SC.finalize(BUILD[n](col), col)
	for o in made:
		if not o.data.uv_layers:
			box_uv(o, 6.0)
	for nm, (hx, _r) in A.PAL.items():
		m = bpy.data.materials.get(nm)
		if m is not None and nm.startswith("G4_"):
			m["rbx_material"] = RBX.get(nm, "SmoothPlastic")
			m["rbx_color"] = hx.lstrip("#").upper()
			if nm in TRANSPARENT:
				m["rbx_transparency"] = TRANSPARENT[nm]
	return {o.name: sum(len(p.vertices) - 2 for p in o.data.polygons) for o in made}
