"""Rooftops4 kit (2026-11-21): the rooftop pieces Parts can't do well, for a city block at blue hour. Self-reviewed
concept (the owner is away; vault/01 Design/Maps/Rooftops4.md). Hard-surface helpers from
tools/blender/maps_snowpeak4/snowcat_model.py (bevel modifiers, baked; smooth faces with sharp edges). Every curve is
a run of flat plates (12-sided tank, octagon pipes), nothing round, nothing floating: every part overlaps the part
that carries it (0.03-0.05), never shares a plane with it.

    python tools/blender/lobby_v4/send.py tools/blender/maps_rooftops4/run_rooftops4.py --port 9897 --pid <pid>

Pieces (Map_<Piece>, export group Kit of map Rooftops4; names start with R4 so no other kit's collections clash):
  R4Tank       the landmark: a 12-sided timber stave water tank with four steel hoops and a faceted conical roof on a
               braced steel stand with a railed platform, two ladders and a downpipe. 15 wide, 26 tall.
  R4AC         packaged rooftop AC: casing on rails, louvre banks, two fan shrouds with guards, a pipe run. 10 x 5 x 3.5.
  R4Condenser  a small condenser: casing, louvres, one fan on top, on rails. 4 x 3.2 x 3.
  R4Skylight   a gabled glass skylight on a concrete curb, steel glazing bars, a warm lit room under it. 12 x 7 x 2.5.
  R4Lantern    a hipped glass roof lantern: curb, glazed walls, hip roof with bars, lit inside. 12 x 10 x 5.5.
  R4Vent       an octagonal mushroom vent on a flashing plate. R4Gooseneck: a bent vent pipe (angled segments).
  R4Dish       a faceted satellite dish on a mast with a feed arm and a base frame.
  R4Billboard  a 20 x 9.5 billboard: lattice legs, back girts, a framed face (*BillPaint* / *BillStripe* take the
               side's colours), a railed catwalk, three floodlights. Origin = foot, face to +Y.
  R4NeonStar / R4NeonBolt / R4NeonCup   neon icon signs (no text): square-section tubes (*NeonPaint*) on a dark
               backplate. ~7 tall. Origin = back centre, face to +Y.
  R4Stair8     a steel stair: rises 8 over a 16 run toward +Y, 5 wide, grating treads, stringers, two handrails.
  R4Catwalk8 / R4Catwalk6   steel alley bridges 12 long: grating deck (top at +0.12), I-beam girders, rails, kick plates.
  R4Plank6     a plank bridge 12 long: timber bearers, loose planks, a scaffold-pipe rail on one side.
  R4Window     a sash window for the brick facades: stone sill and lintel, painted frame, two sashes (*WinPane* is set
               lit or dark per window in Studio). 3 wide, 5 tall. Origin = bottom centre on the wall, out to +Y.
  R4Door       a steel service door: frame, leaf with a louvre and kick plate, a sloped canopy on brackets (the wall
               lamp beside it is built from Parts). Origin as R4Window.
  R4FireEsc    one storey of a facade fire escape: a railed grating landing on brackets with balusters and a stair
               flight down to the next storey (6 below). 8 wide. Origin = landing top, at the wall, out to +Y.
  R4TowerA/B/C city towers past the bounds: banded bodies (*TowerBody* recoloured per instance), lit and dark window
               panes, setback crowns, roof plant, a mast with an aviation light.
Units: studs; +X right, +Y front (Roblox -Z), +Z up; origin bottom centre unless noted. Our own designs.
"""
from math import cos, pi, sin, sqrt
import random

import bmesh
import bpy
from mathutils import Vector

import arena_kit as A
import snowcat_model as SC

cube, prism, bar, cyl, bevel, new_obj, ngon2 = SC.cube, SC.prism, SC.bar, SC.cyl, SC.bevel, SC.new_obj, SC.ngon2

ROOT = "Rooftops4Kit"
A.PAL.update(
	{
		"R4_Steel": ("#3D4450", 0.6),
		"R4_SteelLight": ("#7C8691", 0.6),
		"R4_Grate": ("#6A737D", 0.7),
		"R4_Galv": ("#AEB4BA", 0.55),
		"R4_GalvDark": ("#737B84", 0.6),
		"R4_Fan": ("#22262B", 0.7),
		"R4_Wood": ("#8B5D3A", 0.85),
		"R4_WoodDark": ("#5A3B26", 0.85),
		"R4_TankRoof": ("#4A4744", 0.85),
		"R4_Concrete": ("#9A968F", 0.9),
		"R4_Stone": ("#C9BFAE", 0.9),
		"R4_Glass": ("#3A5068", 0.15),
		"R4_RoomGlow": ("#E6A75C", 0.5),
		"R4_FramePaint": ("#E8E2D6", 0.6),
		"R4_DoorPaint": ("#58606B", 0.6),
		"R4_WinPane": ("#1F2B38", 0.2),
		"R4_Lamp": ("#FFE2B0", 0.4),
		"R4_BillPaint": ("#C8462E", 0.7),
		"R4_BillStripe": ("#F2C14E", 0.7),
		"R4_NeonPaint": ("#FFB347", 0.4),
		"R4_Backplate": ("#262A31", 0.8),
		"R4_Copper": ("#9A6A43", 0.6),
		"R4_TowerBody": ("#4C5566", 0.9),
		"R4_TowerBand": ("#3A414E", 0.9),
		"R4_TowerLit": ("#F3C77F", 0.5),
		"R4_TowerDark": ("#1C2430", 0.3),
		"R4_Beacon": ("#E0403A", 0.4),
	}
)
RBX = {
	"R4_Steel": "Metal",
	"R4_SteelLight": "Metal",
	"R4_Grate": "DiamondPlate",
	"R4_Galv": "Metal",
	"R4_GalvDark": "Metal",
	"R4_Wood": "WoodPlanks",
	"R4_WoodDark": "Wood",
	"R4_Concrete": "Concrete",
	"R4_Stone": "Limestone",
	"R4_Glass": "Glass",
	"R4_RoomGlow": "Neon",
	"R4_Lamp": "Neon",
	"R4_NeonPaint": "Neon",
	"R4_Copper": "Metal",
	"R4_TowerLit": "Neon",
	"R4_Beacon": "Neon",
	"R4_DoorPaint": "Metal",
}
TRANSPARENT = {"R4_Glass": 0.35}


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


def ring(bm, r_out, r_in, z0, z1, n, mi, rot=None, cx=0.0, cy=0.0):
	"""A closed n-sided ring of trapezoid prisms (vertex radii)."""
	rot = pi / n if rot is None else rot
	o, i = ngon2(cx, cy, r_out, n, rot), ngon2(cx, cy, r_in, n, rot)
	for k in range(n):
		prism(bm, [o[k], o[(k + 1) % n], i[(k + 1) % n], i[k]], "z", z0, z1, mi)


def cone(bm, r, z0, z1, n, mi, rot=None, cx=0.0, cy=0.0):
	"""A faceted cone (n flat plates) with a closed base."""
	rot = pi / n if rot is None else rot
	base = [bm.verts.new((cx + x, cy + y, z0)) for x, y in ngon2(0, 0, r, n, rot)]
	top = bm.verts.new((cx, cy, z1))
	bm.faces.new(list(reversed(base))).material_index = mi
	for k in range(n):
		bm.faces.new((base[k], base[(k + 1) % n], top)).material_index = mi


def xz_prism(bm, pts, y0, y1, mi):
	"""Extrude a polygon drawn in the XZ plane from y0 to y1."""
	return prism(bm, pts, "y", y0, y1, mi)


def poly_tubes(bm, pts, y, t, mi, closed=True):
	"""Square-section tubes along a polyline in the XZ plane at depth y (neon / pipe outlines)."""
	n = len(pts)
	segs = n if closed else n - 1
	for k in range(segs):
		(x0, z0), (x1, z1) = pts[k], pts[(k + 1) % n]
		d = Vector((x1 - x0, 0, z1 - z0)).normalized() * (t / 2)
		bar(bm, (x0 - d.x, y, z0 - d.z), (x1 + d.x, y, z1 + d.z), t, t, mi, up=Vector((0, 1, 0)))


def octpipe(bm, p0, p1, r, mi):
	return cyl(bm, p0, p1, r, 8, mi)


# ------------------------------------------------------------------------------------------------ the water tank
def tank(coll):
	bm = bmesh.new()
	ST, SL, GR, WD, WK, RF = 0, 1, 2, 3, 4, 5
	L = 4.6
	for sx in (-1, 1):
		for sy in (-1, 1):
			cube(bm, sx * L - 0.35, sx * L + 0.35, sy * L - 0.35, sy * L + 0.35, 0.05, 10.1, ST)
			cube(bm, sx * L - 0.65, sx * L + 0.65, sy * L - 0.65, sy * L + 0.65, -0.03, 0.22, SL)  # base plates
	for z in (0.9, 5.0, 9.4):
		for s in (-1, 1):
			bar(bm, (-L, s * L, z), (L, s * L, z), 0.3, 0.42, ST)
			bar(bm, (s * L, -L, z + 0.05), (s * L, L, z + 0.05), 0.3, 0.42, ST)
	# X bracing per side and bay; the second diagonal sits 0.12 further out so the two never share a plane
	for z0, z1 in ((0.9, 5.0), (5.0, 9.4)):
		for s in (-1, 1):
			bar(bm, (-L, s * L, z0), (L, s * L, z1), 0.2, 0.22, SL)
			bar(bm, (L, s * (L + 0.12), z0), (-L, s * (L + 0.12), z1), 0.2, 0.22, SL)
			bar(bm, (s * L, -L, z0), (s * L, L, z1), 0.2, 0.22, SL)
			bar(bm, (s * (L + 0.12), L, z0), (s * (L + 0.12), -L, z1), 0.2, 0.22, SL)
	# platform: octagonal grating deck on two cross beams, railed
	prism(bm, ngon2(0, 0, 7.4, 8, pi / 8), "z", 9.95, 10.35, GR)
	for a in (0, pi / 2):
		bar(bm, (-6.6 * cos(a), -6.6 * sin(a), 9.75), (6.6 * cos(a), 6.6 * sin(a), 9.75), 0.5, 0.45, ST)
	posts = ngon2(0, 0, 7.15, 8, pi / 8)
	for x, y in posts:
		cube(bm, x - 0.11, x + 0.11, y - 0.11, y + 0.11, 10.3, 13.55, ST)
	for z in (11.9, 13.45):
		poly = [(x, y) for x, y in posts]
		for k in range(8):
			(x0, y0), (x1, y1) = poly[k], poly[(k + 1) % 8]
			bar(bm, (x0, y0, z), (x1, y1, z), 0.16, 0.16, ST)
	# tank bearers on the platform
	for a in (pi / 4, 3 * pi / 4):
		bar(bm, (-5.6 * cos(a), -5.6 * sin(a), 10.6), (5.6 * cos(a), 5.6 * sin(a), 10.6), 0.6, 0.55, ST)
	# staves: 12 sides, two staves a side with a dark groove between them (the core shows through)
	Z0, Z1 = 10.82, 21.6
	ro, ri = 6.2, 5.7
	vo, vi = ngon2(0, 0, ro, 12, pi / 12), ngon2(0, 0, ri, 12, pi / 12)
	g = 0.035
	for k in range(12):
		o0, o1 = Vector((*vo[k], 0)), Vector((*vo[(k + 1) % 12], 0))
		i0, i1 = Vector((*vi[k], 0)), Vector((*vi[(k + 1) % 12], 0))
		om, im = (o0 + o1) / 2, (i0 + i1) / 2
		for a0, a1, b0, b1 in ((o0, om, i0, im), (om, o1, im, i1)):
			da, db = (a1 - a0).normalized() * g, (b1 - b0).normalized() * g
			pts = [a0 + da, a1 - da, b1 - db, b0 + db]
			prism(bm, [(p.x, p.y) for p in pts], "z", Z0, Z1, WD)
	prism(bm, ngon2(0, 0, 5.95, 12, pi / 12), "z", Z0 - 0.25, Z1 + 0.05, WK)  # core
	for z in (12.0, 14.9, 17.8, 20.6):
		ring(bm, 6.34, 6.0, z, z + 0.32, 12, ST, pi / 12)
	# roof: fascia, faceted cone with standing seams, finial, hatch
	ring(bm, 6.55, 5.9, Z1 - 0.05, Z1 + 0.32, 12, WK, pi / 12)
	cone(bm, 6.55, Z1 + 0.3, 25.0, 12, RF, pi / 12)
	for x, y in ngon2(0, 0, 6.55, 12, pi / 12):
		bar(bm, (x, y, Z1 + 0.36), (0, 0, 25.02), 0.14, 0.12, WK)
	prism(bm, ngon2(0, 0, 0.42, 8, pi / 8), "z", 24.6, 25.7, ST)
	cone(bm, 0.55, 25.65, 26.3, 8, ST, pi / 8)
	# ladders: stand (outside the platform) then up the tank side to the roof
	for y in (-0.55, 0.55):
		cube(bm, 7.0, 7.16, y - 0.08, y + 0.08, 0.05, 13.6, SL)
		cube(bm, 6.42, 6.56, y - 0.08, y + 0.08, 10.4, 22.9, SL)
	for z in [0.6 + 0.9 * k for k in range(14)]:
		cube(bm, 6.98, 7.18, -0.6, 0.6, z, z + 0.1, SL)
	for z in [11.1 + 0.9 * k for k in range(13)]:
		cube(bm, 6.4, 6.58, -0.6, 0.6, z, z + 0.1, SL)
	for z in (3.0, 7.5, 12.6):
		bar(bm, (6.95, 0, z), (5.0, 0, z), 0.16, 0.16, SL)  # ladder brackets back to the leg girts / platform
	for z in (13.0, 16.5, 20.9):
		bar(bm, (6.45, 0, z), (6.0, 0, z), 0.2, 0.16, SL)
	# downpipe and valve
	octpipe(bm, (0, 0, 0.0), (0, 0, 10.7), 0.45, ST)
	cube(bm, -0.7, 0.7, -0.7, 0.7, -0.03, 0.35, SL)
	octpipe(bm, (0, 0, 2.6), (1.0, 0, 2.6), 0.28, SL)
	o = new_obj("R4Tank", bm, ["R4_Steel", "R4_SteelLight", "R4_Grate", "R4_Wood", "R4_WoodDark", "R4_TankRoof"], coll)
	bevel(o, 0.03, 1, 40)
	return [o]


# ------------------------------------------------------------------------------------------------ roof plant
def louvres(bm, x0, x1, z0, z1, y, out, mi_frame, mi_slat, axis="y"):
	"""A louvre bank on a face (y = face plane, out = +1 / -1): a frame and angled slats."""
	f = 0.18
	if axis == "y":
		yb, yf = y - out * 0.05, y + out * 0.12
		lo, hi = min(yb, yf), max(yb, yf)
		cube(bm, x0, x1, lo, hi, z0, z0 + f, mi_frame)
		cube(bm, x0, x1, lo, hi, z1 - f, z1, mi_frame)
		cube(bm, x0, x0 + f, lo, hi, z0 + f, z1 - f, mi_frame)
		cube(bm, x1 - f, x1, lo, hi, z0 + f, z1 - f, mi_frame)
		z = z0 + f + 0.15
		while z < z1 - f - 0.1:
			bar(bm, (x0 + f - 0.02, y + out * 0.02, z), (x1 - f + 0.02, y + out * 0.02, z), 0.32, 0.05, mi_slat, up=Vector((0, out * 0.6, 1)))
			z += 0.3
	else:
		xb, xf = y - out * 0.05, y + out * 0.12
		lo, hi = min(xb, xf), max(xb, xf)
		cube(bm, lo, hi, x0, x1, z0, z0 + f, mi_frame)
		cube(bm, lo, hi, x0, x1, z1 - f, z1, mi_frame)
		cube(bm, lo, hi, x0, x0 + f, z0 + f, z1 - f, mi_frame)
		cube(bm, lo, hi, x1 - f, x1, z0 + f, z1 - f, mi_frame)
		z = z0 + f + 0.15
		while z < z1 - f - 0.1:
			bar(bm, (y + out * 0.02, x0 + f - 0.02, z), (y + out * 0.02, x1 - f + 0.02, z), 0.32, 0.05, mi_slat, up=Vector((out * 0.6, 0, 1)))
			z += 0.3


def fan(bm, cx, cy, z, r, mi_shroud, mi_fan, mi_guard):
	ring(bm, r, r - 0.22, z - 0.05, z + 0.35, 8, mi_shroud, pi / 8, cx, cy)
	prism(bm, ngon2(cx, cy, 0.3, 8, pi / 8), "z", z - 0.3, z + 0.12, mi_fan)  # hub
	for k in range(4):
		a = k * pi / 2 + 0.3
		bar(bm, (cx, cy, z), (cx + (r - 0.28) * cos(a), cy + (r - 0.28) * sin(a), z - 0.02), 0.45, 0.06, mi_fan, up=Vector((0.3 * sin(a), -0.3 * cos(a), 1)))
	for k in (-2, -1, 0, 1, 2):
		w = sqrt(max(0.01, (r - 0.15) ** 2 - (k * 0.42) ** 2))
		bar(bm, (cx - w, cy + k * 0.42, z + 0.3), (cx + w, cy + k * 0.42, z + 0.3), 0.06, 0.06, mi_guard)


def ac_unit(coll):
	bm = bmesh.new()
	GV, GD, FN, ST = 0, 1, 2, 3
	for y in (-1.6, 1.6):
		cube(bm, -4.9, 4.9, y - 0.3, y + 0.3, -0.03, 0.38, ST)  # base rails
	cube(bm, -4.75, 4.75, -2.3, 2.3, 0.35, 3.25, GV)
	cube(bm, -4.85, 4.85, -2.4, 2.4, 3.2, 3.45, GD)  # top lid, overhangs
	for s in (-1, 1):
		louvres(bm, -4.3, -0.4, 0.75, 2.85, s * 2.3, s, GD, GD)
		louvres(bm, 0.4, 4.3, 0.75, 2.85, s * 2.3, s, GD, GD)
	# service panel on the end, a raised seam band, a pipe run off the end
	cube(bm, 4.7, 4.85, -1.7, 1.7, 0.7, 2.9, GD)
	for z in (1.2, 2.4):
		cube(bm, 4.8, 4.9, -1.2, 1.2, z, z + 0.06, GV)
	octpipe(bm, (-4.7, 1.2, 1.0), (-5.6, 1.2, 1.0), 0.2, ST)
	octpipe(bm, (-5.5, 1.2, 1.0), (-5.5, 1.2, -0.03), 0.2, ST)
	for x in (-2.3, 2.3):
		fan(bm, x, 0, 3.55, 1.6, GD, FN, ST)
	o = new_obj("R4AC", bm, ["R4_Galv", "R4_GalvDark", "R4_Fan", "R4_Steel"], coll)
	bevel(o, 0.04, 1, 40)
	return [o]


def condenser(coll):
	bm = bmesh.new()
	GV, GD, FN, ST = 0, 1, 2, 3
	for x in (-1.4, 1.4):
		cube(bm, x - 0.25, x + 0.25, -1.6, 1.6, -0.03, 0.3, ST)
	cube(bm, -1.9, 1.9, -1.5, 1.5, 0.28, 2.65, GV)
	cube(bm, -2.0, 2.0, -1.6, 1.6, 2.6, 2.8, GD)
	for s in (-1, 1):
		louvres(bm, -1.6, 1.6, 0.55, 2.35, s * 1.5, s, GD, GD)
	fan(bm, 0, 0, 2.9, 1.25, GD, FN, ST)
	o = new_obj("R4Condenser", bm, ["R4_Galv", "R4_GalvDark", "R4_Fan", "R4_Steel"], coll)
	bevel(o, 0.03, 1, 40)
	return [o]


def glazing_gable(bm, hx, hy, z_eave, z_ridge, GL, FR, step=2.0):
	"""Two glass planes meeting at a ridge along X, glass gable ends, steel glazing bars on top."""
	t = 0.06
	for s in (-1, 1):
		q = [(-hx, s * hy, z_eave), (hx, s * hy, z_eave), (hx, 0, z_ridge), (-hx, 0, z_ridge)]
		vs = [bm.verts.new(p) for p in q] + [bm.verts.new((p[0], p[1], p[2] - t)) for p in q]
		for f in ((0, 1, 2, 3), (7, 6, 5, 4), (0, 4, 5, 1), (1, 5, 6, 2), (2, 6, 7, 3), (3, 7, 4, 0)):
			bm.faces.new([vs[i] for i in (f if s > 0 else tuple(reversed(f)))]).material_index = GL
	for s in (-1, 1):  # gable ends
		pts = [(s * hx - 0.03, -hy + 0.02, z_eave - 0.04), (s * hx - 0.03, hy - 0.02, z_eave - 0.04), (s * hx - 0.03, 0, z_ridge - 0.08)]
		vs = [bm.verts.new(p) for p in pts] + [bm.verts.new((p[0] + 0.06, p[1], p[2])) for p in pts]
		for f in ((0, 1, 2), (5, 4, 3), (0, 3, 4, 1), (1, 4, 5, 2), (2, 5, 3, 0)):
			bm.faces.new([vs[i] for i in f]).material_index = GL
	# bars: ridge, eaves, rafters, gable rakes
	bar(bm, (-hx - 0.1, 0, z_ridge + 0.06), (hx + 0.1, 0, z_ridge + 0.06), 0.24, 0.2, FR)
	for s in (-1, 1):
		bar(bm, (-hx - 0.1, s * hy, z_eave + 0.04), (hx + 0.1, s * hy, z_eave + 0.04), 0.22, 0.2, FR)
		x = -hx
		while x <= hx + 0.01:
			bar(bm, (x, s * hy, z_eave + 0.08), (x, 0, z_ridge + 0.08), 0.12, 0.12, FR)
			x += step


def skylight(coll):
	bm = bmesh.new()
	CO, GL, FR, GW = 0, 1, 2, 3
	hx, hy = 6.0, 3.5
	cube(bm, -hx, hx, -hy, -hy + 0.5, -0.03, 0.9, CO)
	cube(bm, -hx, hx, hy - 0.5, hy, -0.03, 0.9, CO)
	cube(bm, -hx - 0.05, -hx + 0.5, -hy + 0.45, hy - 0.45, -0.03, 0.88, CO)
	cube(bm, hx - 0.5, hx + 0.05, -hy + 0.45, hy - 0.45, -0.03, 0.88, CO)
	cube(bm, -hx + 0.45, hx - 0.45, -hy + 0.45, hy - 0.45, -0.03, 0.18, GW)  # the lit room below, seen through glass
	cube(bm, -hx - 0.1, hx + 0.1, -hy - 0.1, hy + 0.1, 0.86, 1.0, FR)  # flashing cap
	glazing_gable(bm, hx - 0.2, hy - 0.25, 1.0, 2.5, GL, FR)
	o = new_obj("R4Skylight", bm, ["R4_Concrete", "R4_Glass", "R4_Steel", "R4_RoomGlow"], coll)
	bevel(o, 0.03, 1, 40)
	return [o]


def lantern(coll):
	bm = bmesh.new()
	CO, GL, FR, GW = 0, 1, 2, 3
	hx, hy = 6.0, 5.0
	cube(bm, -hx, hx, -hy, -hy + 0.6, -0.03, 1.2, CO)
	cube(bm, -hx, hx, hy - 0.6, hy, -0.03, 1.2, CO)
	cube(bm, -hx - 0.05, -hx + 0.6, -hy + 0.55, hy - 0.55, -0.03, 1.18, CO)
	cube(bm, hx - 0.6, hx + 0.05, -hy + 0.55, hy - 0.55, -0.03, 1.18, CO)
	cube(bm, -hx + 0.55, hx - 0.55, -hy + 0.55, hy - 0.55, -0.03, 0.2, GW)
	# glazed walls: four glass panes and mullions
	w = 0.3
	cube(bm, -hx + w, hx - w, -hy + w, -hy + w + 0.06, 1.15, 3.25, GL)
	cube(bm, -hx + w, hx - w, hy - w - 0.06, hy - w, 1.15, 3.25, GL)
	cube(bm, -hx + w, -hx + w + 0.06, -hy + w + 0.04, hy - w - 0.04, 1.15, 3.25, GL)
	cube(bm, hx - w - 0.06, hx - w, -hy + w + 0.04, hy - w - 0.04, 1.15, 3.25, GL)
	for x in [-hx + w + 2.25 * k for k in range(6)]:
		for y in (-hy + w + 0.03, hy - w - 0.03):
			cube(bm, x - 0.1, x + 0.1, y - 0.12, y + 0.12, 1.15, 3.3, FR)
	for y in [-hy + w + 2.2 * k for k in range(5)]:
		for x in (-hx + w + 0.03, hx - w - 0.03):
			cube(bm, x - 0.13, x + 0.13, y - 0.1, y + 0.1, 1.15, 3.3, FR)
	cube(bm, -hx + 0.1, hx - 0.1, -hy + 0.1, hy - 0.1, 3.25, 3.45, FR)  # wall plate
	# hip roof in glass: ridge along X
	rx = hx - hy + 0.2
	zr = 5.5
	P = [(-hx + 0.15, -hy + 0.15, 3.45), (hx - 0.15, -hy + 0.15, 3.45), (hx - 0.15, hy - 0.15, 3.45), (-hx + 0.15, hy - 0.15, 3.45)]
	R = [(-rx, 0, zr), (rx, 0, zr)]
	faces = [(P[0], P[1], R[1], R[0]), (P[2], P[3], R[0], R[1]), (P[1], P[2], R[1]), (P[3], P[0], R[0])]
	for f in faces:
		vs = [bm.verts.new(p) for p in f]
		bm.faces.new(vs).material_index = GL
		vs2 = [bm.verts.new((p[0], p[1], p[2] - 0.06)) for p in f]
		bm.faces.new(list(reversed(vs2))).material_index = GL
	bar(bm, (-rx - 0.1, 0, zr + 0.06), (rx + 0.1, 0, zr + 0.06), 0.26, 0.2, FR)
	for p, r in ((P[0], R[0]), (P[1], R[1]), (P[2], R[1]), (P[3], R[0])):
		bar(bm, (p[0], p[1], p[2] + 0.07), (r[0], r[1], r[2] + 0.07), 0.2, 0.18, FR)
	for x in (-rx + 0.0, -rx / 2, 0.0, rx / 2, rx):
		for s in (-1, 1):
			bar(bm, (x, s * (hy - 0.15), 3.53), (x, 0, zr + 0.07), 0.12, 0.12, FR)
	o = new_obj("R4Lantern", bm, ["R4_Concrete", "R4_Glass", "R4_Steel", "R4_RoomGlow"], coll)
	bevel(o, 0.03, 1, 40)
	return [o]


def vent(coll):
	bm = bmesh.new()
	GV, GD = 0, 1
	cube(bm, -0.9, 0.9, -0.9, 0.9, -0.03, 0.12, GD)
	prism(bm, ngon2(0, 0, 0.62, 8, pi / 8), "z", 0.1, 0.55, GD)
	prism(bm, ngon2(0, 0, 0.48, 8, pi / 8), "z", 0.5, 2.2, GV)
	for z in (1.0, 1.7):
		ring(bm, 0.56, 0.44, z, z + 0.12, 8, GD)
	for k in range(4):
		a = k * pi / 2 + pi / 4
		bar(bm, (0.4 * cos(a), 0.4 * sin(a), 2.15), (0.75 * cos(a), 0.75 * sin(a), 2.45), 0.08, 0.08, GD)
	prism(bm, ngon2(0, 0, 0.95, 8, pi / 8), "z", 2.4, 2.5, GV)
	cone(bm, 0.95, 2.48, 2.95, 8, GV, pi / 8)
	o = new_obj("R4Vent", bm, ["R4_Galv", "R4_GalvDark"], coll)
	bevel(o, 0.02, 1, 40)
	return [o]


def gooseneck(coll):
	bm = bmesh.new()
	GV, GD = 0, 1
	cube(bm, -0.8, 0.8, -0.8, 0.8, -0.03, 0.12, GD)
	pts = [(0, 0, 0.05), (0, 0, 2.4), (0, 0.35, 2.95), (0, 0.9, 3.15), (0, 1.45, 2.95), (0, 1.8, 2.4), (0, 1.8, 1.9)]
	for p0, p1 in zip(pts, pts[1:]):
		d = (Vector(p1) - Vector(p0)).normalized() * 0.18
		octpipe(bm, Vector(p0) - d, Vector(p1) + d, 0.36, GV)
	octpipe(bm, (0, 1.8, 2.0), (0, 1.8, 1.75), 0.44, GD)  # bird screen collar
	o = new_obj("R4Gooseneck", bm, ["R4_Galv", "R4_GalvDark"], coll)
	bevel(o, 0.02, 1, 40)
	return [o]


def dish(coll):
	bm = bmesh.new()
	ST, DS, GD = 0, 1, 2
	cube(bm, -1.0, 1.0, -0.15, 0.15, -0.03, 0.2, ST)
	cube(bm, -0.15, 0.15, -1.0, 1.0, -0.03, 0.2, ST)
	octpipe(bm, (0, 0, 0.1), (0, 0, 2.6), 0.16, ST)
	# the dish: a shallow faceted bowl (two rings of plates) tilted up and forward
	c = Vector((0, 0.25, 2.9))
	tilt = 0.7
	ax = Vector((0, cos(tilt), sin(tilt)))  # the dish looks along ax (forward and up)
	u = Vector((1, 0, 0))
	v = ax.cross(u).normalized()
	n = 10
	rings = []
	for r, d in ((0.12, 0.0), (0.75, 0.18), (1.35, 0.45)):
		rings.append([bm.verts.new(c + (u * cos(2 * pi * k / n) + v * sin(2 * pi * k / n)) * r + ax * d) for k in range(n)])
	back = [bm.verts.new(c + (u * cos(2 * pi * k / n) + v * sin(2 * pi * k / n)) * r - ax * 0.12) for k in range(n) for r in (1.3,)]
	for k in range(n):
		k1 = (k + 1) % n
		bm.faces.new((rings[0][k1], rings[0][k], rings[1][k], rings[1][k1])).material_index = DS
		bm.faces.new((rings[1][k1], rings[1][k], rings[2][k], rings[2][k1])).material_index = DS
		bm.faces.new((rings[2][k1], rings[2][k], back[k], back[k1])).material_index = DS
	bm.faces.new(rings[0]).material_index = DS
	bm.faces.new(list(reversed(back))).material_index = DS
	bar(bm, c - ax * 0.1, (0, 0, 2.6), 0.22, 0.22, ST)
	tip = c + ax * 1.55
	bar(bm, c + u * 0.0 - v * 1.2 + ax * 0.4, tip, 0.08, 0.08, ST)
	cube(bm, tip.x - 0.18, tip.x + 0.18, tip.y - 0.18, tip.y + 0.18, tip.z - 0.18, tip.z + 0.18, GD)
	o = new_obj("R4Dish", bm, ["R4_Steel", "R4_Galv", "R4_GalvDark"], coll)
	bevel(o, 0.02, 1, 40)
	return [o]


# ------------------------------------------------------------------------------------------------ billboard + neon
def billboard(coll):
	bm = bmesh.new()
	ST, SL, GR, PA, SP, LM = 0, 1, 2, 3, 4, 5
	HX, Z0, Z1 = 10.0, 2.75, 12.25
	# lattice legs (two per side, tied and braced in their own plane, braces offset so they never share it)
	for lx in (-6.5, 6.5):
		for y in (-0.3, -1.9):
			cube(bm, lx - 0.2, lx + 0.2, y - 0.2, y + 0.2, 0.0, 12.6, ST)
		cube(bm, lx - 0.4, lx + 0.4, -2.3, 0.1, -0.03, 0.2, SL)
		for z in (0.8, 4.0, 7.2, 10.4):
			bar(bm, (lx, -1.9, z), (lx, -0.3, z), 0.2, 0.2, SL)
		for z0, z1 in ((0.8, 4.0), (4.0, 7.2), (7.2, 10.4)):
			bar(bm, (lx + 0.08, -1.9, z0), (lx + 0.08, -0.3, z1), 0.14, 0.14, SL)
	# back girts and posts, the face, its frame
	for z in (1.7, 3.2, 7.5, 11.8):
		cube(bm, -HX, HX, -0.4, 0.04, z - 0.15, z + 0.15, ST)
	for x in (-9.6, -3.2, 3.2, 9.6):
		cube(bm, x - 0.15, x + 0.15, -0.3, 0.02, 1.7, 12.0, ST)
	cube(bm, -HX + 0.1, HX - 0.1, 0.0, 0.3, Z0, Z1, PA)
	stripe = [(-HX + 0.3, Z0 + 0.25), (-1.0, Z0 + 0.25), (-5.5, Z1 - 0.25), (-HX + 0.3, Z1 - 0.25)]
	xz_prism(bm, stripe, 0.28, 0.34, SP)
	cube(bm, -HX, HX, 0.25, 0.56, Z1 - 0.25, Z1 + 0.25, ST)
	cube(bm, -HX, HX, 0.25, 0.56, Z0 - 0.25, Z0 + 0.25, ST)
	cube(bm, -HX, -HX + 0.5, 0.25, 0.5, Z0 + 0.2, Z1 - 0.2, ST)
	cube(bm, HX - 0.5, HX, 0.25, 0.5, Z0 + 0.2, Z1 - 0.2, ST)
	# catwalk in front of the bottom edge, brackets, rail
	cube(bm, -HX, HX, -0.1, 2.3, 1.55, 1.75, GR)
	for x in (-9.0, -4.5, 0.0, 4.5, 9.0):
		bar(bm, (x, -0.1, 0.6), (x, 2.2, 1.58), 0.18, 0.18, SL)
		bar(bm, (x, -0.35, 0.6), (x, 0.05, 0.6), 0.2, 0.2, SL)
	for x in (-HX + 0.1, -5.0, 0.0, 5.0, HX - 0.1):
		cube(bm, x - 0.09, x + 0.09, 2.08, 2.26, 1.7, 4.65, SL)
	cube(bm, -HX, HX, 2.08, 2.26, 4.45, 4.62, SL)
	cube(bm, -HX + 0.02, HX - 0.02, 2.1, 2.24, 3.1, 3.24, SL)
	cube(bm, -HX + 0.02, HX - 0.02, 2.11, 2.23, 1.72, 2.0, SL)  # kick plate
	# floodlights on arms over the top
	for x in (-6.5, 0.0, 6.5):
		bar(bm, (x, -0.1, 12.1), (x, 2.6, 13.4), 0.18, 0.18, SL)
		cube(bm, x - 0.55, x + 0.55, 2.3, 3.1, 13.15, 13.75, ST)
		cube(bm, x - 0.45, x + 0.45, 2.4, 3.0, 13.1, 13.18, LM)
	o = new_obj("R4Billboard", bm, ["R4_Steel", "R4_SteelLight", "R4_Grate", "R4_BillPaint", "R4_BillStripe", "R4_Lamp"], coll)
	bevel(o, 0.03, 1, 40)
	return [o]


def neon(coll, name, outlines, w, h):
	bm = bmesh.new()
	BP, NE, ST = 0, 1, 2
	cube(bm, -w / 2, w / 2, 0.0, 0.3, 0.0, h, BP)
	cube(bm, -w / 2 - 0.12, w / 2 + 0.12, -0.02, 0.24, -0.12, 0.12, ST)
	cube(bm, -w / 2 - 0.12, w / 2 + 0.12, -0.02, 0.24, h - 0.12, h + 0.12, ST)
	for pts, closed in outlines:
		poly_tubes(bm, [(x, z + h / 2) for x, z in pts], 0.44, 0.3, NE, closed)
		for x, z in pts[:: max(1, len(pts) // 4)]:
			cube(bm, x - 0.07, x + 0.07, 0.25, 0.4, z + h / 2 - 0.07, z + h / 2 + 0.07, ST)  # standoffs
	o = new_obj(name, bm, ["R4_Backplate", "R4_NeonPaint", "R4_Steel"], coll)
	bevel(o, 0.02, 1, 40)
	return [o]


def neon_star(coll):
	pts = []
	for k in range(10):
		r = 3.0 if k % 2 == 0 else 1.25
		a = pi / 2 + k * pi / 5
		pts.append((r * cos(a), r * sin(a) - 0.2))
	return neon(coll, "R4NeonStar", [(pts, True)], 7.0, 7.4)


def neon_bolt(coll):
	pts = [(0.9, 3.1), (-1.7, -0.1), (-0.1, -0.1), (-1.0, -3.1), (1.8, 0.5), (0.2, 0.5), (1.5, 3.1)]
	return neon(coll, "R4NeonBolt", [(pts, True)], 5.4, 7.4)


def neon_cup(coll):
	cup = [(-1.7, -1.9), (1.7, -1.9), (2.1, 1.0), (-2.1, 1.0)]
	handle = [(1.95, 0.4), (3.0, 0.2), (3.05, -0.9), (1.8, -1.3)]
	saucer = [(-2.7, -2.5), (2.7, -2.5)]
	steam1 = [(-0.9, 1.6), (-0.5, 2.25), (-0.9, 2.9), (-0.5, 3.4)]
	steam2 = [(0.5, 1.6), (0.9, 2.25), (0.5, 2.9), (0.9, 3.4)]
	return neon(coll, "R4NeonCup", [(cup, True), (handle, False), (saucer, False), (steam1, False), (steam2, False)], 7.0, 7.6)


# ------------------------------------------------------------------------------------------------ stairs, bridges
def stair8(coll):
	bm = bmesh.new()
	ST, GR, SL = 0, 1, 2
	run, rise, hw = 16.0, 8.0, 2.5
	slope = Vector((0, run, rise)).normalized()
	for s in (-1, 1):
		x = s * (hw - 0.15)
		bar(bm, (x, -0.35, 0.25), (x, run - 0.05, rise + 0.05), 0.28, 0.9, ST)
		cube(bm, x - 0.3, x + 0.3, -0.6, 0.4, -0.03, 0.3, SL)  # foot plate
	n = 10
	for k in range(1, n + 1):
		zt = rise * k / n
		y0, y1 = run * (k - 1) / n - 0.05, run * k / n + (0.0 if k == n else 0.05)
		cube(bm, -hw + 0.22, hw - 0.22, y0, y1 - (0.08 if k == n else 0), zt - 0.14, zt, GR)
		cube(bm, -hw + 0.22, hw - 0.22, y1 - 0.18 - (0.08 if k == n else 0), y1 - (0.08 if k == n else 0), zt - 0.32, zt - 0.1, ST)  # nosing
	for s in (-1, 1):
		x = s * (hw - 0.12)
		posts = [0.4, 4.4, 8.4, 12.4, run - 0.3]
		for y in posts:
			zb = rise * y / run
			cube(bm, x - 0.1, x + 0.1, y - 0.1, y + 0.1, zb + 0.2, zb + 3.35, SL)
		for dz in (1.8, 3.25):
			bar(bm, (x, 0.2, rise * 0.2 / run + dz), (x, run - 0.1, rise * (run - 0.1) / run + dz), 0.16, 0.16, SL)
	o = new_obj("R4Stair8", bm, ["R4_Steel", "R4_Grate", "R4_SteelLight"], coll)
	bevel(o, 0.03, 1, 40)
	return [o]


def catwalk(coll, name, w):
	bm = bmesh.new()
	ST, GR, SL = 0, 1, 2
	hl, hw = 6.0, w / 2
	cube(bm, -hw + 0.1, hw - 0.1, -hl, hl, -0.03, 0.12, GR)
	for s in (-1, 1):
		gx = s * (hw - 0.7)
		cube(bm, gx - 0.13, gx + 0.13, -hl, hl, -1.3, -0.02, ST)  # web
		cube(bm, gx - 0.42, gx + 0.42, -hl, hl, -1.45, -1.25, ST)  # bottom flange
		cube(bm, gx - 0.4, gx + 0.4, -hl + 0.02, hl - 0.02, -0.17, 0.0, SL)  # top flange (into the deck)
	y = -hl + 1.0
	while y < hl - 1.0:
		bar(bm, (-(hw - 0.7), y, -1.25), (hw - 0.7, y + 2.0, -0.2), 0.16, 0.16, SL)
		y += 2.0
	for s in (-1, 1):
		x = s * (hw - 0.12)
		for py in (-hl + 0.15, -hl / 2, 0.0, hl / 2, hl - 0.15):
			cube(bm, x - 0.1, x + 0.1, py - 0.1, py + 0.1, 0.1, 3.45, SL)
		cube(bm, x - 0.09, x + 0.09, -hl, hl, 3.25, 3.42, SL)
		cube(bm, x - 0.07, x + 0.07, -hl + 0.02, hl - 0.02, 1.7, 1.84, SL)
		cube(bm, x - 0.06, x + 0.06, -hl + 0.03, hl - 0.03, 0.1, 0.5, ST)  # kick plate
	o = new_obj(name, bm, ["R4_Steel", "R4_Grate", "R4_SteelLight"], coll)
	bevel(o, 0.03, 1, 40)
	return [o]


def plank_bridge(coll):
	rnd = random.Random(7)
	bm = bmesh.new()
	WD, WK, ST = 0, 1, 2
	hl, hw = 6.5, 3.0
	for x in (-2.0, 2.0):
		cube(bm, x - 0.35, x + 0.35, -hl, hl, -0.75, 0.0, WK)
	y = -hl + 0.05
	k = 0
	while y < hl - 0.3:
		wdt = 0.62 + rnd.random() * 0.12
		ex0, ex1 = rnd.uniform(-0.15, 0.1), rnd.uniform(-0.1, 0.15)
		zt = 0.15 + (k % 3) * 0.015
		cube(bm, -hw + ex0, hw + ex1, y, y + wdt, -0.04, zt, WD if k % 4 else WK)
		y += wdt + 0.06
		k += 1
	# a scaffold-pipe rail on one side: posts clamped to the bearer, two rails
	for py in (-5.5, 0.0, 5.5):
		octpipe(bm, (2.55, py, -0.6), (2.55, py, 3.4), 0.12, ST)
		cube(bm, 2.3, 2.8, py - 0.25, py + 0.25, -0.65, -0.2, ST)
	for z in (1.8, 3.3):
		octpipe(bm, (2.55, -6.0, z), (2.55, 6.0, z), 0.11, ST)
	o = new_obj("R4Plank6", bm, ["R4_Wood", "R4_WoodDark", "R4_Steel"], coll)
	bevel(o, 0.02, 1, 40)
	return [o]


# ------------------------------------------------------------------------------------------------ facades
def window(coll):
	bm = bmesh.new()
	SN, FP, WP, BR = 0, 1, 2, 3
	cube(bm, -1.85, 1.85, -0.03, 0.42, -0.4, 0.0, SN)  # sill
	cube(bm, -1.9, 1.9, -0.03, 0.22, 4.55, 5.15, SN)  # lintel
	cube(bm, -0.25, 0.25, 0.15, 0.27, 4.6, 5.25, SN)  # keystone
	cube(bm, -1.45, 1.45, 0.0, 0.08, 0.05, 4.5, WP)  # panes (lit or dark), edges buried in the frame
	cube(bm, -1.55, -1.3, -0.03, 0.22, 0.0, 4.55, FP)
	cube(bm, 1.3, 1.55, -0.03, 0.22, 0.0, 4.55, FP)
	cube(bm, -1.32, 1.32, -0.03, 0.2, 0.0, 0.22, FP)
	cube(bm, -1.32, 1.32, -0.03, 0.2, 4.33, 4.56, FP)
	cube(bm, -1.32, 1.32, -0.03, 0.24, 2.16, 2.36, FP)  # meeting rails
	cube(bm, -0.07, 0.07, -0.03, 0.17, 0.2, 4.35, FP)  # glazing bar
	cube(bm, -1.32, 1.32, 0.02, 0.15, 2.37, 2.45, BR)  # upper sash bottom shadow line
	o = new_obj("R4Window", bm, ["R4_Stone", "R4_FramePaint", "R4_WinPane", "R4_Steel"], coll)
	bevel(o, 0.02, 1, 40)
	return [o]


def door(coll):
	bm = bmesh.new()
	FR, DP, ST, LM, GD = 0, 1, 2, 3, 4
	cube(bm, -1.65, 1.65, -0.03, 0.25, 0.0, 7.2, FR)  # frame slab
	cube(bm, -1.35, 1.35, 0.2, 0.36, 0.05, 6.75, DP)  # leaf
	cube(bm, -1.0, 1.0, 0.33, 0.4, 0.3, 0.9, GD)  # kick plate
	cube(bm, -0.8, 0.8, 0.33, 0.4, 4.6, 5.6, GD)  # louvre frame
	for z in (4.75, 5.0, 5.25, 5.5):
		bar(bm, (-0.7, 0.42, z), (0.7, 0.42, z), 0.16, 0.04, ST, up=Vector((0, 0.6, 1)))
	cube(bm, 0.85, 1.15, 0.35, 0.55, 3.2, 3.35, ST)  # handle
	cube(bm, 0.95, 1.05, 0.35, 0.45, 2.9, 3.35, ST)
	# canopy: a sloped plate on two brackets
	q = [(-2.1, 0.0, 7.75), (2.1, 0.0, 7.75), (2.1, 1.8, 7.25), (-2.1, 1.8, 7.25)]
	vs = [bm.verts.new(p) for p in q] + [bm.verts.new((p[0], p[1], p[2] + 0.18)) for p in q]
	for f in ((3, 2, 1, 0), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)):
		bm.faces.new([vs[i] for i in f]).material_index = ST
	for x in (-1.8, 1.8):
		bar(bm, (x, -0.02, 6.6), (x, 1.6, 7.3), 0.14, 0.14, ST)
	cube(bm, -2.15, 2.15, -0.03, 0.15, 7.5, 7.95, ST)  # canopy wall strip
	# (the wall lamp is a Parts piece in the builder now, one design for every lamp on the map)
	o = new_obj("R4Door", bm, ["R4_FramePaint", "R4_DoorPaint", "R4_Steel", "R4_Lamp", "R4_GalvDark"], coll)  # R4_Lamp unused now
	bevel(o, 0.02, 1, 40)
	return [o]


def fire_escape(coll):
	bm = bmesh.new()
	ST, GR = 0, 1
	hw, d = 4.0, 2.6
	cube(bm, -hw, hw, 0.0, d, -0.12, 0.0, GR)
	cube(bm, -hw, hw, -0.03, 0.2, -0.35, 0.02, ST)  # wall angle
	cube(bm, -hw, hw, d - 0.15, d, -0.35, 0.02, ST)  # edge angle
	for x in (-3.5, 0.0, 3.5):
		bar(bm, (x, -0.02, -1.8), (x, d - 0.1, -0.3), 0.14, 0.14, ST)  # brackets
		cube(bm, x - 0.2, x + 0.2, -0.03, 0.1, -2.0, -1.6, ST)
	for x in (-hw + 0.05, -2.0, 0.0, 2.0, hw - 0.05):
		cube(bm, x - 0.06, x + 0.06, d - 0.12, d, 0.0, 3.2, ST)
	cube(bm, -hw, hw, d - 0.14, d + 0.02, 3.05, 3.2, ST)  # top rail
	x = -hw + 0.4
	while x < hw - 0.3:
		cube(bm, x - 0.025, x + 0.025, d - 0.1, d - 0.04, 0.0, 3.1, ST)  # balusters
		x += 0.5
	for s in (-1, 1):
		cube(bm, s * hw - 0.06, s * hw + 0.06, 0.0, d - 0.05, 3.05, 3.2, ST)
		cube(bm, s * hw - 0.06, s * hw + 0.06, 0.0, 0.12, 0.0, 3.2, ST)
	# a stair flight down to the next storey (6 below), inside the landing's depth
	y0, y1 = 0.55, 2.0
	for y in (y0, y1):
		bar(bm, (-3.4, y, -0.15), (3.4, y, -6.1), 0.12, 0.5, ST)
	n = 9
	for k in range(1, n):
		t = k / n
		x = -3.4 + 6.8 * t
		z = -0.15 - 5.95 * t
		cube(bm, x - 0.35, x + 0.35, y0 + 0.05, y1 - 0.05, z - 0.1, z, GR)
	bar(bm, (-3.0, y1 + 0.05, 2.4), (3.4, y1 + 0.05, -3.5), 0.08, 0.08, ST)
	o = new_obj("R4FireEsc", bm, ["R4_Steel", "R4_Grate"], coll)
	bevel(o, 0.015, 1, 40)
	return [o]


def tower(coll, name, w, d, h, seed, crown):
	rnd = random.Random(seed)
	bm = bmesh.new()
	BD, BA, LT, DK, ST, BC = 0, 1, 2, 3, 4, 5
	cube(bm, -w / 2, w / 2, -d / 2, d / 2, 0, h, BD)
	fl = 4.2
	z = 4.0
	while z < h - 3.0:
		ring_box(bm, w / 2, d / 2, z - 0.25, z + 0.25, 0.14, BA)
		z += fl
	# window panes: one quad each, a hair proud of the body, lit or dark
	for face in range(4):
		span = w if face in (0, 2) else d
		cols = int(span / 3.2)
		off = (span - cols * 3.2) / 2 + 1.6
		z = 4.0
		while z < h - 4.5:
			for c in range(cols):
				u = -span / 2 + off + c * 3.2
				lit = rnd.random() < 0.32
				quad(bm, face, w, d, u, z + 0.65, z + 3.45, 1.1, 0.025, LT if lit else DK)
			z += fl
	# crown: a setback, a parapet cap, roof plant and a mast with an aviation light
	cw, cd = w * crown, d * crown
	cube(bm, -w / 2 - 0.2, w / 2 + 0.2, -d / 2 - 0.2, d / 2 + 0.2, h - 0.05, h + 0.6, BA)
	cube(bm, -cw / 2, cw / 2, -cd / 2, cd / 2, h + 0.5, h + 9.0, BD)
	cube(bm, -cw / 2 - 0.2, cw / 2 + 0.2, -cd / 2 - 0.2, cd / 2 + 0.2, h + 8.95, h + 9.5, BA)
	for k in range(int(cw / 4)):
		u = -cw / 2 + 2.0 + k * 4.0
		quad(bm, 0, cw, cd, u, h + 3.0, h + 7.0, 1.2, 0.025, LT if rnd.random() < 0.5 else DK)
		quad(bm, 2, cw, cd, u, h + 3.0, h + 7.0, 1.2, 0.025, LT if rnd.random() < 0.5 else DK)
	cube(bm, -3, 3, -2, 2, h + 9.4, h + 13.0, ST)
	cube(bm, -0.25, 0.25, -0.25, 0.25, h + 12.9, h + 26.0, ST)
	cube(bm, -0.5, 0.5, -0.5, 0.5, h + 25.9, h + 26.7, BC)
	o = new_obj(name, bm, ["R4_TowerBody", "R4_TowerBand", "R4_TowerLit", "R4_TowerDark", "R4_Steel", "R4_Beacon"], coll)
	return [o]


def ring_box(bm, hx, hy, z0, z1, out, mi):
	cube(bm, -hx - out, hx + out, -hy - out, -hy + 0.1, z0, z1, mi)
	cube(bm, -hx - out, hx + out, hy - 0.1, hy + out, z0, z1, mi)
	cube(bm, -hx - out + 0.03, -hx + 0.1, -hy + 0.05, hy - 0.05, z0 + 0.02, z1 - 0.02, mi)
	cube(bm, hx - 0.1, hx + out - 0.03, -hy + 0.05, hy - 0.05, z0 + 0.02, z1 - 0.02, mi)


def quad(bm, face, w, d, u, z0, z1, hw, proud, mi):
	"""A single outward quad on a tower face (0 = -Y, 1 = +X, 2 = +Y, 3 = -X)."""
	if face == 0:
		pts = [(u - hw, -d / 2 - proud, z0), (u + hw, -d / 2 - proud, z0), (u + hw, -d / 2 - proud, z1), (u - hw, -d / 2 - proud, z1)]
	elif face == 2:
		pts = [(u + hw, d / 2 + proud, z0), (u - hw, d / 2 + proud, z0), (u - hw, d / 2 + proud, z1), (u + hw, d / 2 + proud, z1)]
	elif face == 1:
		pts = [(w / 2 + proud, u - hw, z0), (w / 2 + proud, u + hw, z0), (w / 2 + proud, u + hw, z1), (w / 2 + proud, u - hw, z1)]
	else:
		pts = [(-w / 2 - proud, u + hw, z0), (-w / 2 - proud, u - hw, z0), (-w / 2 - proud, u - hw, z1), (-w / 2 - proud, u + hw, z1)]
	bm.faces.new([bm.verts.new(p) for p in pts]).material_index = mi


PIECES = (
	"R4Tank", "R4AC", "R4Condenser", "R4Skylight", "R4Lantern", "R4Vent", "R4Gooseneck", "R4Dish",
	"R4Billboard", "R4NeonStar", "R4NeonBolt", "R4NeonCup", "R4Stair8", "R4Catwalk8", "R4Catwalk6", "R4Plank6",
	"R4Window", "R4Door", "R4FireEsc", "R4TowerA", "R4TowerB", "R4TowerC",
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
		return SC.finalize(objs, col)

	made += fin(tank(C("R4Tank")), "R4Tank")
	made += fin(ac_unit(C("R4AC")), "R4AC")
	made += fin(condenser(C("R4Condenser")), "R4Condenser")
	made += fin(skylight(C("R4Skylight")), "R4Skylight")
	made += fin(lantern(C("R4Lantern")), "R4Lantern")
	made += fin(vent(C("R4Vent")), "R4Vent")
	made += fin(gooseneck(C("R4Gooseneck")), "R4Gooseneck")
	made += fin(dish(C("R4Dish")), "R4Dish")
	made += fin(billboard(C("R4Billboard")), "R4Billboard")
	made += fin(neon_star(C("R4NeonStar")), "R4NeonStar")
	made += fin(neon_bolt(C("R4NeonBolt")), "R4NeonBolt")
	made += fin(neon_cup(C("R4NeonCup")), "R4NeonCup")
	made += fin(stair8(C("R4Stair8")), "R4Stair8")
	made += fin(catwalk(C("R4Catwalk8"), "R4Catwalk8", 8.0), "R4Catwalk8")
	made += fin(catwalk(C("R4Catwalk6"), "R4Catwalk6", 6.0), "R4Catwalk6")
	made += fin(plank_bridge(C("R4Plank6")), "R4Plank6")
	made += fin(window(C("R4Window")), "R4Window")
	made += fin(door(C("R4Door")), "R4Door")
	made += fin(fire_escape(C("R4FireEsc")), "R4FireEsc")
	made += fin(tower(C("R4TowerA"), "R4TowerA", 36, 24, 150, 11, 0.6), "R4TowerA")
	made += fin(tower(C("R4TowerB"), "R4TowerB", 30, 30, 118, 23, 0.7), "R4TowerB")
	made += fin(tower(C("R4TowerC"), "R4TowerC", 48, 28, 72, 37, 0.5), "R4TowerC")
	for o in made:
		if not o.data.uv_layers:
			box_uv(o, 6.0)
	for nm, (hx, _r) in A.PAL.items():
		m = bpy.data.materials.get(nm)
		if m is not None and nm.startswith("R4_"):
			m["rbx_material"] = RBX.get(nm, "SmoothPlastic")
			m["rbx_color"] = hx.lstrip("#").upper()
			if nm in TRANSPARENT:
				m["rbx_transparency"] = TRANSPARENT[nm]
	return {o.name: sum(len(p.vertices) - 2 for p in o.data.polygons) for o in made}
