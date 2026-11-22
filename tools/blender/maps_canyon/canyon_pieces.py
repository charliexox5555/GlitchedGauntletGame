"""CanyonOutpost kit (2026-11-21): a sun-baked mining outpost in a red canyon, RIVALS style
(vault/01 Design/Maps/CanyonOutpost.md).

RIVALS study (Westown, Museum, Docks): chunky timber with big flat chamfers, clean silhouettes, simple stepped details
(hoops, girts, braces, rims) instead of noise, flat colours that take the Parts' variants in Studio (Wood01a, Metal
2022, Concrete-01a). Every piece: a few big masses with 1-segment chamfers, round forms 12-16 flat facets, flat
shading (every facet a plane), details cut in or seated (never stuck on), no two faces in one plane.

    python tools/blender/lobby_v4/send.py tools/blender/maps_canyon/run_canyon.py --port 9897 --pid <pid>

Pieces (Map_<Piece>, export group Kit of map CanyonOutpost). Units: studs; +X right, +Y front (Roblox -Z), +Z up;
origin bottom centre unless noted.
  CNWaterTower  the landmark: four battered timber legs on concrete footings (14 apart at the ground, clear under
                the girts to +8 so the ore track runs through), girts and X braces, cap beams, joists, an octagonal
                deck, a 16-stave tank with iron hoops and a chime, a red conical roof with a finial, the swing spout
                (+X) over the track with its rope, two risers (+-Y) down to pipe pits. Tank floor +23, roof top +35.6.
  CNMinePortal  the mine entrance set into a cliff face (the face is the plane y = 0, the portal looks +Y): battered
                posts, a header with cut ends and a stepped second header, knee braces, plank lagging round the
                opening, two inner timber sets, lagged walls and ceiling, a black back (Neon in Studio, like RIVALS'
                tunnel), a lantern on a bracket. Opening 9.4 wide x 12 tall.
  CNOreCart     an ore cart for a 3.0 gauge track along Y; origin = rail top centre. Flared hopper body with ribs and
                a rim, an ore load, frame channels, timber buffer beams, couplers, four wheels. 3.6 tall over the rail.
  CNWagon       a freight wagon along Y (7.4 x 15 x 8): spoked wheels (rear r 2.4, front r 1.9) with iron tyres,
                axles and bolsters, a plank bed, two-board sides on stakes, a tarp over the load with ropes, the
                tongue resting on a block, a brake lever.
Our own designs. RIVALS meshes used in Studio (mesas, props) are listed in the map note.
"""
from math import atan2, cos, pi, sin

import bmesh
import bpy
from mathutils import Vector

import arena_kit as A
import foundry4_pieces as F
import greenhouse4_pieces as G
import snowcat_model as SC

cube, prism, bar, cyl, ngon2 = SC.cube, SC.prism, SC.bar, SC.cyl, SC.ngon2
loft, ring, cone, box_uv = G.loft, G.ring, G.cone, G.box_uv


def obj(name, bm, mats, coll, bev=0.03, ang=40):
	"""One solid per piece (owner 2026-11-21: parts must connect, nothing reads stuck on): the overlapping shells are
	unioned first (Boolean, exact, self-intersection, empty operand), THEN bevelled, so a join is a real merged corner
	with a small fillet instead of two chamfered blocks meeting in a groove."""
	o = SC.new_obj(name, bm, mats, coll)
	ec = bpy.data.collections.get("_EmptyUnion") or bpy.data.collections.new("_EmptyUnion")
	md = o.modifiers.new("Union", "BOOLEAN")
	md.operation = "UNION"
	md.solver = "EXACT"
	md.use_self = True
	md.operand_type = "COLLECTION"
	md.collection = ec
	if bev:
		SC.bevel(o, bev, 1, ang)
	return o
revolve, loop_prism, cham_sq, wheelset, ringx = F.revolve, F.loop_prism, F.cham_sq, F.wheelset, F.ringx

ROOT = "CanyonKit"
A.PAL.update(
	{
		"CN_Wood": ("#8C6344", 0.85),
		"CN_WoodDark": ("#5A3A26", 0.85),
		"CN_WoodLight": ("#AB795C", 0.85),
		"CN_Iron": ("#3A3B3F", 0.7),
		"CN_Steel": ("#646870", 0.7),
		"CN_Paint": ("#B0532E", 0.6),
		"CN_Roof": ("#9C3B2A", 0.7),
		"CN_Ore": ("#5A443A", 0.9),
		"CN_OreLight": ("#8A6A55", 0.9),
		"CN_Concrete": ("#A39482", 0.9),
		"CN_Black": ("#111111", 0.9),
		"CN_Lamp": ("#F2C98A", 0.4),
		"CN_Canvas": ("#D2C3A0", 0.9),
		"CN_Rope": ("#9C8462", 0.9),
	}
)
RBX = {"CN_Black": "Neon", "CN_Lamp": "Neon", "CN_Concrete": "Concrete", "CN_Canvas": "Fabric"}
for _w in ("CN_Wood", "CN_WoodDark", "CN_WoodLight"):
	RBX[_w] = "Wood"
for _m in ("CN_Iron", "CN_Steel"):
	RBX[_m] = "Metal"


def sq(cx, cy, hw, z, c=0.0):
	"""A square loop (3-D, z const) of half-width hw round (cx, cy); c > 0 cuts the corners (8 points)."""
	if c <= 0:
		return [(cx - hw, cy - hw, z), (cx + hw, cy - hw, z), (cx + hw, cy + hw, z), (cx - hw, cy + hw, z)]
	return [(cx + u, cy + v, z) for u, v in cham_sq(0.0, 0.0, hw, hw, c)]


def rect(x0, x1, y0, y1, z):
	return [(x0, y0, z), (x1, y0, z), (x1, y1, z), (x0, y1, z)]


def frustum(b, lo, hi, mi):
	"""A solid between two matching loops (bottom `lo`, top `hi`)."""
	loop_prism(b, [Vector(p) for p in lo], [Vector(p) for p in hi], mi)


# ------------------------------------------------------------------------------------------------ the water tower
LEG0, LEG1, LEGZ = 7.0, 5.6, 22.0  # leg centre offset at the ground and at the cap, cap height


def leg_at(z):
	return LEG0 + (LEG1 - LEG0) * z / LEGZ


def water_tower(coll):
	b = bmesh.new()
	WD, WK, IR, CO, RF, ST, RP = range(7)
	corners = [(-1, -1), (1, -1), (1, 1), (-1, 1)]
	for sx, sy in corners:
		# footing: a frustum pad with a cut top; the leg stands 0.1 into it
		frustum(b, sq(sx * LEG0, sy * LEG0, 1.3, 0.0, 0.25), sq(sx * LEG0, sy * LEG0, 1.05, 0.7, 0.2), CO)
		frustum(
			b,
			sq(sx * leg_at(0.6), sy * leg_at(0.6), 0.68, 0.6, 0.16),
			sq(sx * leg_at(LEGZ - 0.6), sy * leg_at(LEGZ - 0.6), 0.6, LEGZ - 0.6, 0.14),
			WD,
		)
	# girts round all four faces (the track faces +-X stay open to +8)
	for z in (8.0, 15.0):
		o = leg_at(z)
		for s in (-1, 1):
			bar(b, (-o - 0.2, s * o, z), (o + 0.2, s * o, z), 0.7, 0.8, WK)
			bar(b, (s * o, -o - 0.2, z), (s * o, o + 0.2, z), 0.66, 0.84, WK)
	# X braces between the girts and up to the cap, one brace each side of the face plane (they never touch)
	for z0, z1 in ((8.0, 15.0), (15.0, LEGZ - 0.7)):
		o0, o1 = leg_at(z0), leg_at(z1)
		for s in (-1, 1):
			for k, off in ((1, 0.36), (-1, -0.36)):
				# faces at y = +-o (along X)
				y0, y1 = s * o0 + s * off, s * o1 + s * off
				bar(b, (-k * (o0 - 0.4), y0, z0 + 0.3), (k * (o1 - 0.4), y1, z1 - 0.3), 0.42, 0.62, WD)
				# faces at x = +-o (along Y)
				x0, x1 = s * o0 + s * off, s * o1 + s * off
				bar(b, (x0, -k * (o0 - 0.4), z0 + 0.3), (x1, k * (o1 - 0.4), z1 - 0.3), 0.42, 0.62, WD)
	# cap beams along X on the leg heads (cut ends), joists along Y, the octagonal deck
	for s in (-1, 1):
		prism(b, [(s * LEG1 - 0.6, 21.0), (s * LEG1 + 0.6, 21.0), (s * LEG1 + 0.6, 22.2), (s * LEG1 - 0.6, 22.2)], "x", -6.9, 6.9, WK)
		prism(b, [(-7.6, 21.6), (-7.2, 21.2), (7.2, 21.2), (7.6, 21.6), (7.6, 22.2), (-7.6, 22.2)], "y", s * LEG1 - 0.55, s * LEG1 + 0.55, WK)
	for x in (-6.0, -4.0, -2.0, 0.0, 2.0, 4.0, 6.0):
		cube(b, x - 0.3, x + 0.3, -7.45, 7.45, 22.15, 22.85, WD)
	frustum(b, sq(0, 0, 7.75, 22.8, 2.2), sq(0, 0, 7.75, 23.15, 2.2), WK)
	# the tank: 16 staves, a chime at the foot, four iron hoops (the same 16 facets, 0.14 proud), the roof
	n = 16
	loft(b, [(6.0, 23.1), (6.0, 31.5)], n, WD, rot=pi / n)
	revolve(b, [(5.7, 23.1), (6.32, 23.1), (6.32, 23.55), (5.7, 23.55)], n, WK, rot=pi / n)
	for z in (25.0, 27.0, 29.0, 30.9):
		revolve(b, [(5.8, z), (6.16, z), (6.16, z + 0.3), (5.8, z + 0.3)], n, IR, rot=pi / n)
	revolve(b, [(5.6, 31.35), (6.85, 31.35), (6.85, 31.75), (5.6, 31.75)], n, RF, rot=pi / n)
	loft(b, [(6.7, 31.7), (0.55, 35.0)], n, RF, rot=pi / n, cap_bot=True)
	loft(b, [(0.5, 34.8), (0.5, 35.25), (0.22, 35.6)], 8, IR)
	# the swing spout over the track (+X): a pivot block on the deck edge, the chute, its rope to the tank
	cube(b, 7.35, 8.25, -0.55, 0.55, 22.25, 23.35, IR)
	bar(b, (7.8, 0.0, 22.7), (11.6, 0.0, 17.2), 0.9, 0.9, WK)
	cube(b, 11.15, 12.15, -0.6, 0.6, 16.6, 17.6, IR)
	bar(b, (6.05, 0.0, 29.6), (11.55, 0.0, 17.55), 0.12, 0.12, RP)
	# risers to the pump houses (+-Y): flanged pipes from pipe pits to the deck
	for s in (-1, 1):
		y = s * 6.7
		frustum(b, sq(3.0, y, 0.85, 0.0, 0.2), sq(3.0, y, 0.72, 0.5, 0.15), CO)
		cyl(b, (3.0, y, 0.4), (3.0, y, 22.9), 0.42, 8, ST)
		for z in (1.0, 8.6, 15.6, 21.4):
			cyl(b, (3.0, y, z), (3.0, y, z + 0.3), 0.58, 8, IR)
	return [obj("CNWaterTower", b, ["CN_Wood", "CN_WoodDark", "CN_Iron", "CN_Concrete", "CN_Roof", "CN_Steel", "CN_Rope"], coll, 0.06)]


# ------------------------------------------------------------------------------------------------ the mine portal
def lantern(b, x, y, z, mi_i, mi_l):
	"""One lantern design (hangs with its top at z): cap, frame posts, the lens, base."""
	frustum(b, sq(x, y, 0.42, z - 0.25), sq(x, y, 0.2, z), mi_i)
	cube(b, x - 0.38, x + 0.38, y - 0.38, y + 0.38, z - 0.36, z - 0.24, mi_i)
	for sx, sy in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
		cube(b, x + sx * 0.36 - 0.06, x + sx * 0.36 + 0.06, y + sy * 0.36 - 0.06, y + sy * 0.36 + 0.06, z - 1.1, z - 0.3, mi_i)
	cube(b, x - 0.27, x + 0.27, y - 0.27, y + 0.27, z - 1.05, z - 0.33, mi_l)
	cube(b, x - 0.42, x + 0.42, y - 0.42, y + 0.42, z - 1.25, z - 1.06, mi_i)


def mine_portal(coll):
	b = bmesh.new()
	WD, WK, WL, IR, BK, LP = range(6)
	# front posts, battered (wider at the foot), 1.6 square with cut corners
	for s in (-1, 1):
		frustum(b, sq(s * 5.9, 0.8, 0.8, 0.0, 0.2), sq(s * 5.5, 0.8, 0.75, 12.05, 0.2), WK)
	# the header with cut ends, the stepped second header (shallower) and the knee braces
	prism(b, [(-7.5, 12.0), (7.5, 12.0), (8.2, 12.7), (8.2, 13.8), (-8.2, 13.8), (-8.2, 12.7)], "y", -0.1, 1.85, WK)
	prism(b, [(-6.6, 13.75), (6.6, 13.75), (7.1, 14.25), (7.1, 15.0), (-7.1, 15.0), (-7.1, 14.25)], "y", -0.1, 1.4, WD)
	for s in (-1, 1):
		bar(b, (s * 5.35, 0.8, 9.2), (s * 3.6, 0.8, 12.2), 0.7, 0.9, WD)
	# lagging round the opening: plank rows alternately 0.06 deep, between the posts and the rock (y -0.5..0)
	z = 0.0
	k = 0
	while z < 16.9:
		h = min(1.9, 17.0 - z)
		d = 0.06 * (k % 2)
		if z + h <= 12.0:
			for s in (-1, 1):
				cube(b, min(s * 6.5, s * 10.5), max(s * 6.5, s * 10.5), -0.55 + d, -0.05 + d, z, z + h + 0.02, WL)
		else:
			cube(b, -10.5, 10.5, -0.55 + d, -0.05 + d, z, z + h + 0.02, WL)
		z += h
		k += 1
	# inside: two timber sets, lagged walls and ceiling, the black back
	for y in (-3.2, -6.4):
		for s in (-1, 1):
			cube(b, s * 4.55 - 0.55, s * 4.55 + 0.55, y - 0.55, y + 0.55, 0.0, 11.2, WD)
		prism(b, [(-5.1, 11.15), (5.1, 11.15), (5.1, 12.3), (-5.1, 12.3)], "y", y - 0.6, y + 0.6, WK)
	for s in (-1, 1):
		cube(b, min(s * 5.1, s * 5.6), max(s * 5.1, s * 5.6), -9.0, -0.4, 0.0, 12.6, WL)
	cube(b, -5.6, 5.6, -9.0, -0.4, 12.25, 12.7, WL)
	cube(b, -5.2, 5.2, -9.3, -8.7, 0.0, 12.4, BK)
	# a lantern on a bracket on the right post
	bar(b, (6.2, 1.6, 10.2), (6.2, 2.9, 10.2), 0.22, 0.22, IR)
	cube(b, 6.05, 6.35, 2.75, 3.05, 9.55, 10.3, IR)
	lantern(b, 6.2, 2.9, 9.6, IR, LP)
	return [obj("CNMinePortal", b, ["CN_Wood", "CN_WoodDark", "CN_WoodLight", "CN_Iron", "CN_Black", "CN_Lamp"], coll, 0.06)]


# ------------------------------------------------------------------------------------------------ the ore cart
def ore_cart(coll):
	"""Track along Y, gauge 3.0, origin = rail top centre."""
	b = bmesh.new()
	PA, IR, WD, OR, OR2 = range(5)
	wheelset(b, (-1.7, 1.7), 3.0, 0.55, IR, IR, IR)
	for s in (-1, 1):
		cube(b, s * 1.05 - 0.2, s * 1.05 + 0.2, -2.55, 2.55, 0.62, 1.1, IR)  # frame channels
		# timber buffer beams at the ends with cut outer corners, coupler blocks
		prism(b, [(-1.75, 0.55), (1.75, 0.55), (1.75, 0.95), (1.55, 1.12), (-1.55, 1.12), (-1.75, 0.95)], "y", min(s * 2.5, s * 3.15), max(s * 2.5, s * 3.15), WD)
		cube(b, -0.2, 0.2, min(s * 3.1, s * 3.55), max(s * 3.1, s * 3.55), 0.68, 0.94, IR)
	# the flared hopper body, its rim and the ore load (a low hipped heap inside the rim)
	frustum(b, rect(-1.6, 1.6, -2.45, 2.45, 1.05), rect(-2.0, 2.0, -2.95, 2.95, 2.6), PA)
	frustum(b, rect(-2.02, 2.02, -2.97, 2.97, 2.5), rect(-2.1, 2.1, -3.05, 3.05, 2.78), IR)
	frustum(b, rect(-1.85, 1.85, -2.8, 2.8, 2.74), rect(-0.9, 0.9, -1.9, 1.9, 3.12), OR)
	# a few ore lumps on the heap (low 6-facet chunks sunk 0.06 into it, unioned with the heap)
	for lx, ly, lr, lh, rt in ((-0.4, -1.0, 0.55, 0.36, 0.2), (0.45, 0.2, 0.62, 0.42, 0.7), (-0.3, 1.2, 0.5, 0.32, 1.1), (0.7, -1.5, 0.42, 0.26, 0.4)):
		loft(b, [(lr, 3.06), (lr * 0.95, 3.06 + lh * 0.55), (lr * 0.5, 3.06 + lh)], 6, OR2, rot=rt, cx=lx, cy=ly)
	# ribs on the sloped sides (0.1 proud of the body, stop under the rim)
	def side_x(z):
		return 1.6 + (2.0 - 1.6) * (z - 1.05) / (2.6 - 1.05)

	def side_y(z):
		return 2.45 + (2.95 - 2.45) * (z - 1.05) / (2.6 - 1.05)

	for s in (-1, 1):
		for y in (-1.7, 0.0, 1.7):
			lo = [(s * (side_x(1.12) - 0.02), y - 0.2, 1.12), (s * (side_x(1.12) + 0.1), y - 0.2, 1.12), (s * (side_x(1.12) + 0.1), y + 0.2, 1.12), (s * (side_x(1.12) - 0.02), y + 0.2, 1.12)]
			hi = [(s * (side_x(2.5) - 0.02), y - 0.2, 2.5), (s * (side_x(2.5) + 0.1), y - 0.2, 2.5), (s * (side_x(2.5) + 0.1), y + 0.2, 2.5), (s * (side_x(2.5) - 0.02), y + 0.2, 2.5)]
			frustum(b, lo if s > 0 else list(reversed(lo)), hi if s > 0 else list(reversed(hi)), IR)
		for x in (-0.9, 0.9):
			lo = [(x - 0.2, s * (side_y(1.12) - 0.02), 1.12), (x + 0.2, s * (side_y(1.12) - 0.02), 1.12), (x + 0.2, s * (side_y(1.12) + 0.1), 1.12), (x - 0.2, s * (side_y(1.12) + 0.1), 1.12)]
			hi = [(x - 0.2, s * (side_y(2.5) - 0.02), 2.5), (x + 0.2, s * (side_y(2.5) - 0.02), 2.5), (x + 0.2, s * (side_y(2.5) + 0.1), 2.5), (x - 0.2, s * (side_y(2.5) + 0.1), 2.5)]
			frustum(b, lo if s < 0 else list(reversed(lo)), hi if s < 0 else list(reversed(hi)), IR)
	return [obj("CNOreCart", b, ["CN_Paint", "CN_Iron", "CN_WoodDark", "CN_Ore", "CN_OreLight"], coll, 0.05)]


# ------------------------------------------------------------------------------------------------ the freight wagon
def spoked_wheel(b, x, y, zc, R, w, mi_w, mi_t, mi_h):
	"""A spoked wheel in the YZ plane: iron tyre, wooden felloe (narrower), hub, 10 spokes."""
	n = 20
	ringx(b, R, R - 0.18, x - w / 2, x + w / 2, n, mi_t, cy=y, cz=zc)
	ringx(b, R - 0.12, R - 0.5, x - w / 2 + 0.05, x + w / 2 - 0.05, n, mi_w, cy=y, cz=zc)
	cyl(b, (x - 0.5, y, zc), (x + 0.5, y, zc), 0.5, 12, mi_h)
	cyl(b, (x - 0.64, y, zc), (x + 0.64, y, zc), 0.26, 12, mi_t)
	for k in range(10):
		a = 2 * pi * k / 10 + pi / 10
		p0 = (x, y + 0.3 * cos(a), zc + 0.3 * sin(a))
		p1 = (x, y + (R - 0.4) * cos(a), zc + (R - 0.4) * sin(a))
		bar(b, p0, p1, 0.22, 0.3, mi_w, up=Vector((1, 0, 0)))


def wagon(coll):
	b = bmesh.new()
	WD, WK, PA, IR, CV, RP = range(6)
	RR, RF = 2.4, 1.9  # rear / front wheel radius
	YR, YF = -4.0, 3.6
	for s in (-1, 1):
		spoked_wheel(b, s * 3.45, YR, RR, RR, 0.5, PA, IR, WK)
		spoked_wheel(b, s * 3.45, YF, RF, RF, 0.46, PA, IR, WK)
	# axles and bolsters up to the bed (bed underside at 3.0)
	bar(b, (-3.3, YR, RR), (3.3, YR, RR), 0.5, 0.5, IR)
	bar(b, (-3.3, YF, RF), (3.3, YF, RF), 0.46, 0.46, IR)
	cube(b, -2.6, 2.6, YR - 0.35, YR + 0.35, RR + 0.2, 3.05, WK)
	cube(b, -2.6, 2.6, YF - 0.35, YF + 0.35, RF + 0.18, 3.05, WK)
	# the bed: plank floor, two-board sides, end boards, stakes
	cube(b, -2.85, 2.85, -6.4, 5.2, 3.0, 3.4, WD)
	for s in (-1, 1):
		cube(b, min(s * 2.62, s * 2.9), max(s * 2.62, s * 2.9), -6.45, 5.25, 3.3, 5.35, WD)
		cube(b, min(s * 2.8, s * 2.98), max(s * 2.8, s * 2.98), -6.45, 5.25, 4.22, 4.48, WK)
		cube(b, min(s * 2.8, s * 2.98), max(s * 2.8, s * 2.98), -6.45, 5.25, 5.2, 5.45, WK)
		for y in (-5.9, -1.4, 1.4, 4.7):
			cube(b, min(s * 2.7, s * 3.1), max(s * 2.7, s * 3.1), y - 0.2, y + 0.2, 2.9, 5.6, WK)
	for y0, y1 in ((-6.45, -6.2), (5.0, 5.25)):
		cube(b, -2.62, 2.62, y0, y1, 3.3, 5.3, WD)
	# the tarp over the load (a hipped canvas shape inside the sides) and three ropes over it
	frustum(b, rect(-2.6, 2.6, -6.15, 4.95, 5.2), rect(-1.5, 1.5, -5.2, 4.0, 7.9), CV)
	for y in (-4.0, -0.6, 2.8):
		for s in (-1, 1):
			bar(b, (s * 3.0, y, 5.3), (s * 2.58, y, 5.3), 0.16, 0.16, RP)
			bar(b, (s * 2.6, y, 5.24), (s * 1.5, y, 7.94), 0.16, 0.16, RP)
		bar(b, (-1.55, y, 7.94), (1.55, y, 7.94), 0.16, 0.16, RP)
	# the tongue resting on a block, the doubletree, the brake lever
	bar(b, (0.0, 5.0, 2.4), (0.0, 8.6, 0.75), 0.4, 0.4, WK)
	cube(b, -0.6, 0.6, 8.2, 9.0, 0.0, 0.62, WD)
	bar(b, (-1.6, 6.3, 1.86), (1.6, 6.3, 1.86), 0.3, 0.3, WK)
	bar(b, (-3.12, -1.6, 3.1), (-3.14, -2.3, 6.2), 0.18, 0.24, IR)
	return [obj("CNWagon", b, ["CN_Wood", "CN_WoodDark", "CN_Paint", "CN_Iron", "CN_Canvas", "CN_Rope"], coll, 0.05)]


# ------------------------------------------------------------------------------------------------ the barrel
BARREL = [(1.08, 0.12), (1.24, 0.9), (1.3, 1.7), (1.24, 2.5), (1.08, 3.22)]


def barrel_r(z):
	for (r0, z0), (r1, z1) in zip(BARREL, BARREL[1:]):
		if z0 <= z <= z1:
			return r0 + (r1 - r0) * (z - z0) / (z1 - z0)
	return BARREL[-1][0]


def barrel(coll):
	"""A standing barrel (2.6 across, 3.45 tall): 12 staves bulging to the middle, a chime ring at each end with the lid
	set 0.22 below it, four iron hoops on the same 12 facets (0.06 proud). Origin bottom centre."""
	b = bmesh.new()
	WD, WK, IR = range(3)
	n = 12
	loft(b, BARREL, n, WD, rot=pi / n)
	revolve(b, [(0.86, 0.0), (1.1, 0.0), (1.1, 0.2), (0.86, 0.2)], n, WK, rot=pi / n)
	revolve(b, [(0.86, 3.18), (1.1, 3.18), (1.1, 3.45), (0.86, 3.45)], n, WK, rot=pi / n)
	for z0, z1 in ((0.36, 0.56), (1.02, 1.2), (2.2, 2.38), (2.86, 3.06)):
		r = max(barrel_r(z0), barrel_r(z1))
		revolve(b, [(r - 0.2, z0), (r + 0.06, z0), (r + 0.06, z1), (r - 0.2, z1)], n, IR, rot=pi / n)
	return [obj("CNBarrel", b, ["CN_Wood", "CN_WoodDark", "CN_Iron"], coll, 0.03)]


PIECES = ("CNWaterTower", "CNMinePortal", "CNOreCart", "CNWagon", "CNBarrel")
BUILD = {"CNWaterTower": water_tower, "CNMinePortal": mine_portal, "CNOreCart": ore_cart, "CNWagon": wagon, "CNBarrel": barrel}


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
		for q in o.data.polygons:
			q.use_smooth = False
		if not o.data.uv_layers:
			box_uv(o, 6.0)
	for nm, (hx, _r) in A.PAL.items():
		m = bpy.data.materials.get(nm)
		if m is not None and nm.startswith("CN_"):
			m["rbx_material"] = RBX.get(nm, "SmoothPlastic")
			m["rbx_color"] = hx.lstrip("#").upper()
	return {o.name: sum(len(p.vertices) - 2 for p in o.data.polygons) for o in made}
