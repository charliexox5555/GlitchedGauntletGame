"""Sunwell Works phase 1: the hall shell (floor, walls, roof with skylights, arrival alcove, ramp,
the SUNWELL WORKS frame, corbels and crossbeams) and its sealed collision core."""
from math import atan, cos, sin, sqrt
from mathutils import Matrix, Vector

import lv3_core as C
import sw_core as S

T = -1.5  # underside of floors and wall bases
HX, LEN, ZW, ZC = S.HX, S.LEN, S.ZW, S.ZC
SKY = ((22.9, 45.1), (48.1, 57.9), (60.9, 83.1), (86.1, 95.9))  # skylight openings (y ranges) between the beams, x -12..12
SOLID = ((-4.0, 22.9), (45.1, 48.1), (57.9, 60.9), (83.1, 86.1), (95.9, LEN + 4))  # roof between them
RAMP_A = atan(3.0 / 16.0)


def _pairs(v):
	return list(zip(v, v[1:]))


def floor(K):
	for sx in (-1, 1):
		for xa, xb in ((12, 23), (23, 34)):
			x0, x1 = sorted((sx * xa, sx * xb))
			for ya, yb, n in ((0, 24, 2), (44, 62, 2), (82, 112, 3)):
				for k in range(n):
					K["Floor"].box(x0, x1, ya + (yb - ya) * k / n, ya + (yb - ya) * (k + 1) / n, T, 0)
			for yc in (34, 72):  # the approach to each doorway reads as part of the walk
				K["Walk"].box(x0, x1, yc - 10, yc + 10, T, 0)
		x0, x1 = sorted((sx * 11, sx * 12))
		K["Stripe"].box(x0, x1, 20, 101, T, 0)
		x0, x1 = sorted((sx * 34, sx * 36))
		K["Floor"].box(x0, x1, 48, 58, T, 0)  # bench recess
	n = 7
	for k in range(n):
		y0, y1 = 20 + 81 * k / n, 20 + 81 * (k + 1) / n
		K["Walk"].box(-11, 0, y0, y1, T, 0)
		K["Walk"].box(0, 11, y0, y1, T, 0)
	K["Stripe"].box(-12, 12, 101, 102, T, 0)
	K["Floor"].box(-12, 0, 102, 112, T, 0)
	K["Floor"].box(0, 12, 102, 112, T, 0)
	K["Floor"].box(-12, 12, 4, 20, T, 0)  # under the ramp


def walls(K):
	z = S.COURSES
	low_a = [(0, 12), (12, 24), (44, 48), (58, 62), (82, 92), (92, 102), (102, 112)]
	low_b = [(0, 12), (12, 24), (44, 53), (53, 62), (82, 92), (92, 102), (102, 112)]
	up_c = _pairs([0, 12, 24, 34, 44, 53, 62, 72, 82, 92, 102, 112])
	up_d = _pairs([0, 6, 18, 29, 39, 48.5, 57.5, 67, 77, 87, 97, 107, 112])
	for sx in (-1, 1):
		xa, xb = sorted((sx * HX, sx * (HX + 4)))
		xo = sx * (HX + 4)
		for ya, yb in ((44, 48), (58, 62)):  # plain wall behind the piers that flank the bench recess
			K["Wall"].box(xa, xb, ya, yb, T, z[1])
		for ya, yb in ((0, 24), (82, 112)):  # battered base and wainscot, a sloped belt ledge
			K["WallBase"].ext_y([(sx * (HX - 1.0), T), (xo, T), (xo, z[0]), (sx * (HX - 0.78), z[0])], ya, yb)
			K["WallLow"].ext_y([(sx * (HX - 0.6), z[0]), (xo, z[0]), (xo, z[1]), (sx * HX, z[1])], ya, yb)
			K["Belt"].ext_y([(sx * HX, z[1] - 0.3), (sx * (HX - 0.45), z[1]), (sx * (HX - 0.45), z[1] + 0.2), (sx * HX, z[1] + 0.2)], ya, yb)
		K["Belt"].ext_y([(sx * HX, ZW - 0.8), (sx * (HX - 0.7), ZW), (sx * HX, ZW)], 0, LEN)  # crown: a facet that starts the haunch early
		for ya, yb in low_b:
			K["Wall"].box(xa, xb, ya, yb, z[1], z[2])
		for ya, yb in up_c:
			K["Wall"].box(xa, xb, ya, yb, z[2], z[3])
		for ya, yb in up_d:
			K["Wall"].box(xa, xb, ya, yb, z[3], z[4])
		ra, rb = sorted((sx * 36, sx * 38))
		K["Charcoal"].box(ra, rb, 48, 58, T, z[1])  # back of the bench recess
		for yb in S.BEAMS:  # pilasters frame each doorway and the bench bay: flared foot, straight shaft, flared head
			bay = {46.6: (44.9, 48.0), 59.4: (58.0, 61.1)}.get(yb)  # these two fill the strip between a door casing and the bench recess

			def r(a, grow, bay=bay, yb=yb):
				y0, y1 = bay if bay else (yb - 1.2 - grow, yb + 1.2 + grow)
				return (*sorted((sx * (HX - a), sx * HX)), y0, y1)

			K["WallBase"].taper(r(1.6, 0.8), 0, r(1.3, 0.5), z[0])
			K["CastTrim"].taper(r(1.15, 0.35), z[0], r(0.8, 0.0), 4.6)
			K["CastTrim"].box(*r(0.8, 0.0), 4.6, 16.2)
			K["CastTrim"].taper(r(0.8, 0.0), 16.2, r(1.25, 0.45), 17.9)
			K["PetrolDark"].taper(r(1.22, 0.42), z[0], r(1.14, 0.34), z[0] + 0.9)  # steel shoe
			S.collider("Hall", S.I4, *sorted((sx * (HX + 0.3), sx * (HX - 0.6))), yb - 1.0, yb + 1.0, 0, 17.7)
	# turbine wall
	# end-wall prisms stop 0.1 short of the outer faces and 0.04 above the underside: nothing coplanar with the side walls outside
	K["WallBase"].ext_x([(LEN - 1.0, T + 0.04), (LEN + 3.9, T + 0.04), (LEN + 3.9, z[0]), (LEN - 0.78, z[0])], -37.9, 37.9)
	K["WallLow"].ext_x([(LEN - 0.6, z[0]), (LEN + 3.9, z[0]), (LEN + 3.9, z[1]), (LEN, z[1])], -37.9, 37.9)
	for xa, xb in _pairs([-38, -26, -13.5, 0, 13.5, 26, 38]):
		K["Wall"].box(xa, xb, LEN, LEN + 4, z[1], z[2])
	for sx in (-1, 1):
		K["Belt"].box(*sorted((sx * 13.6, sx * HX)), LEN - 0.3, LEN, z[1] - 0.22, z[1] + 0.22)
		K["Belt"].box(*sorted((sx * 13.5, sx * HX)), -0.0, 0.3, z[1] - 0.22, z[1] + 0.22)
	K["Belt"].box(-HX, HX, LEN - 0.4, LEN, ZW - 0.6, ZW)
	K["Belt"].box(-HX, HX, 0, 0.4, ZW - 0.6, ZW)
	for xa, xb in _pairs([-38, -25, -12, 0, 12, 25, 38]):
		K["Wall"].box(xa, xb, LEN, LEN + 4, z[2], z[3])
		K["Wall"].box(xa, xb, LEN, LEN + 4, z[3], z[4])
		K["Wall"].box(xa, xb, -4, 0, z[3], z[4])  # entry wall, above the portal
	for xa, xb in _pairs([-38, -19, 0, 19, 38]):
		K["Wall"].box(xa, xb, LEN, LEN + 4, z[4], ZC)
		K["Wall"].box(xa, xb, -4, 0, z[4], ZC)
	# entry wall beside the portal (opening x -12..12, z 3..17.5)
	for sx in (-1, 1):
		K["WallBase"].ext_x([(1.0, T + 0.04), (-3.9, T + 0.04), (-3.9, z[0]), (0.78, z[0])], *sorted((sx * 12, sx * 37.9)))
		K["WallLow"].ext_x([(0.6, z[0]), (-3.9, z[0]), (-3.9, z[1]), (0, z[1])], *sorted((sx * 12, sx * 37.9)))
		for xa, xb in ((12, 25), (25, 38)):
			x0, x1 = sorted((sx * xa, sx * xb))
			for k in (1, 2):
				K["Wall"].box(x0, x1, -4, 0, z[k], z[k + 1])


def alcove(K, KC):
	"""Arrival alcove behind the entry portal: floor at +3, a sealed arrival gate on the back wall."""
	K["Walk"].box(-14, 14, -14, -4, 1.5, S.LAND)
	for sx in (-1, 1):
		K["WallBase"].box(*sorted((sx * 13.65, sx * 18)), -14, -4, T, 4.5)
		for ya, yb in ((-14, -9), (-9, -4)):
			K["Wall"].box(*sorted((sx * 14, sx * 18)), ya, yb, 4.5, 11)
			K["Wall"].box(*sorted((sx * 14, sx * 18)), ya, yb, 11, 19.5)
	K["WallBase"].box(-17.95, 17.95, -17.95, -13.65, T + 0.04, 4.5)
	for xa, xb in _pairs([-18, -9, 0, 9, 18]):
		K["Wall"].box(xa, xb, -18, -14, 4.5, 11)
		K["Wall"].box(xa, xb, -18, -14, 11, 19.5)
	KC["Ceil"].box(-14, 14, -14, -4, 17.5, 19.5)
	# the arrival gate (staging art: where players came in)
	A = S.FK(K, S.face((0, -14, S.LAND), (-1, 0, 0), (0, 1, 0)))
	S.u_frame(A["Petrol"], 9.6, 11.6, 8.0, 10.0, 0.0, 0.7, co=1.6, ci=1.2)
	A["Charcoal"].box(-8, 8, 0, 10, 0.0, 0.25)
	S.corner_fill(A["Charcoal"], 8, 10, 0.25, 0.45, cham=1.2)
	for s in (-1, 1):
		A["BlastDoor"].box(*sorted((s * 0.08, s * 7.6)), 0.25, 9.6, 0.25, 0.5)
		A["Graphite"].box(*sorted((s * 1.0, s * 6.6)), 4.3, 5.3, 0.5, 0.62)
	A["E_Opal"].box(-3.0, 3.0, 10.35, 10.75, 0.7, 0.78)
	for s in (-1, 1):  # opal ceiling panels
		KC["Charcoal"].box(s * 7 - 2.2, s * 7 + 2.2, -10.4, -7.6, 17.3, 17.5)
		KC["E_Opal"].box(s * 7 - 1.9, s * 7 + 1.9, -10.1, -7.9, 17.22, 17.3)
		S.light(S.I4, s * 7, -9, 16.6, "#FFF0DC", 0.9, 22)


def entry(K, KR):
	"""Landing, ramp into the hall, cheek walls with rails, and the ENTRY portal lining."""
	KR["Walk"].box(-12, 12, -4, 0.85, T, S.LAND)
	KR["Walk"].box(-10, 10, 0.85, 4, T, S.LAND)  # between the cheeks
	KR["Rubber"].ext_x([(4, 0), (20, 0), (4, S.LAND)], -10, 10)
	L = sqrt(16 * 16 + 9)
	slope = Matrix.Translation((0, 4, S.LAND)) @ Matrix.Rotation(-RAMP_A, 4, "X")
	R = S.FK(K, slope)
	y = 0.35
	while y < L - 0.3:
		if 5.0 < y < 11.2:  # clear window for the direction marks
			R["Graphite"].box(-9.6, -4.4, y, y + 0.16, 0, 0.05)
			R["Graphite"].box(4.4, 9.6, y, y + 0.16, 0, 0.05)
		else:
			R["Graphite"].box(-9.6, 9.6, y, y + 0.16, 0, 0.05)
		y += 0.62
	for a in (5.7, 8.0):  # two chevrons pointing into the hall
		R["P_Cream"].prism([(-3.0, a), (0, a + 1.5), (3.0, a), (3.0, a + 0.85), (0, a + 2.35), (-3.0, a + 0.85)], 0, 0.05)
	for sx in (-1, 1):
		x0, x1 = sorted((sx * 10, sx * 12))
		KR["CastTrim"].ext_x([(0.85, 0), (19.3, 0), (19.3, 1.38), (4, 4.25), (0.85, 4.25)], x0, x1)
		KR["CastTrim"].box(*sorted((sx * 9.8, sx * 12.2)), 19.3, 20.7, 0, 2.2)  # newel block
		xr = sx * 11
		K["Petrol"].box(xr - 0.28, xr + 0.28, 0.8, 4.2, 5.3, 5.75)  # level rail over the landing
		rail = S.FK(K, Matrix.Translation((xr, 4, 5.3)) @ Matrix.Rotation(-RAMP_A, 4, "X"))
		rail["Petrol"].box(-0.28, 0.28, 0, L - 1.1, 0, 0.45)
		for yp in (1.2, 4.0, 9.2, 14.4, 18.6):
			top = 4.25 - max(0.0, yp - 4) * 3 / 16
			K["Petrol"].box(xr - 0.24, xr + 0.24, yp - 0.24, yp + 0.24, top - 0.05, top + 1.1)
			if yp <= 4.0:  # flat seat only where the cheek top is level
				K["PetrolDark"].box(xr - 0.45, xr + 0.45, yp - 0.45, yp + 0.45, top, top + 0.12)
	# ENTRY portal lining through the wall (opening x -12..12, z 3..17.5), seen from the hall
	E = S.FK(K, S.F_ENTRY)
	S.u_frame(E["Petrol"], 13.4, 19.0, 11.2, 16.7, 0.0, 0.8, co=1.8, ci=1.3, y0=S.LAND)
	S.u_frame(E["CastTrim"], 12.0, 17.5, 11.2, 16.7, -4.6, 0.0, ci=1.3, y0=S.LAND)  # concrete liner, with a lip on the alcove side
	S.bolts(E["PetrolDark"], [(sx * 12.3, yy) for sx in (-1, 1) for yy in (5.0, 10.0, 15.0)], r=0.22, z0=0.8)
	S.add_text(E["Cream"], "ENTRY", 1.35, 0.3, y0=17.2, z0=0.75, s=0.2, c=0.1, track=0.2)


def proscenium(K):
	prof = [(-34, 0), (-29, 0), (-29, 11.5), (-24, 16.5), (24, 16.5), (29, 11.5), (29, 0), (34, 0), (34, ZW), (28, ZC), (-28, ZC), (-34, ZW)]
	K["Cast"].ext_y(prof, S.PROS[0], S.PROS[1])
	for sx in (-1, 1):
		K["WallBase"].taper((*sorted((sx * 28.2, sx * 34.0)), S.PROS[0] - 0.8, S.PROS[1] + 0.8), 0,
			(*sorted((sx * 28.6, sx * 34.0)), S.PROS[0] - 0.4, S.PROS[1] + 0.4), 1.6)  # flared plinth
		K["Petrol"].ext_y([(sx * 29.0, 9.4), (sx * 29.0, 11.5), (sx * 24.0, 16.5), (sx * 21.9, 16.5), (sx * 21.9, 16.2), (sx * 23.85, 16.2),
			(sx * 28.7, 11.35), (sx * 28.7, 9.4)], S.PROS[0] - 0.12, S.PROS[1] + 0.12)  # steel liner under each shoulder


def roof(KC):
	for ya, yb in ((0, S.PROS[0]), (S.PROS[1], LEN)):
		KC["Ceil"].ext_y([(34, ZW), (38, ZW), (38, ZC), (28, ZC)], ya, yb)
		KC["Ceil"].ext_y([(-34, ZW), (-28, ZC), (-38, ZC), (-38, ZW)], ya, yb)
	KC["Ceil"].box(12, 38, -4, LEN + 4, ZC, ZC + 2)
	KC["Ceil"].box(-38, -12, -4, LEN + 4, ZC, ZC + 2)
	for ya, yb in SOLID:
		KC["Ceil"].box(-12, 12, ya, yb, ZC, ZC + 2)
	for ya, yb in SKY:
		S.ring_prism(KC["Petrol"], S.rect_loop(-12, 12, ya, yb), S.rect_loop(-11.45, 11.45, ya + 0.55, yb - 0.55), ZC + 0.25, ZC + 1.0)
		for x in (-4, 4):
			KC["Petrol"].box(x - 0.22, x + 0.22, ya + 0.55, yb - 0.55, ZC + 0.5, ZC + 1.0)
		n = max(2, round((yb - ya) / 5.5))
		for k in range(1, n):
			yy = ya + (yb - ya) * k / n
			KC["PetrolDark"].box(-11.45, 11.45, yy - 0.18, yy + 0.18, ZC + 0.56, ZC + 0.94)
		KC["Glass"].box(-11.9, 11.9, ya + 0.1, yb - 0.1, ZC + 1.0, ZC + 1.15)
		for xa, xb, y0, y1 in ((-13, 13, ya - 1, ya), (-13, 13, yb, yb + 1), (-13, -12, ya, yb), (12, 13, ya, yb)):  # upstand outside
			KC["Ceil"].box(xa, xb, y0, y1, ZC + 2, ZC + 2.8)


def ceiling_lights(KC):
	"""Mounted opal panels on the flat ceiling each side of the skylights (the hall's even fill)."""
	for y in (7.0, 34.0, 53.0, 72.0, 91.0, 106.5):
		for sx in (-1, 1):
			x = sx * 20.0
			KC["Charcoal"].box(x - 3.2, x + 3.2, y - 0.95, y + 0.95, ZC - 0.32, ZC)
			KC["E_Opal"].box(x - 2.9, x + 2.9, y - 0.62, y + 0.62, ZC - 0.4, ZC - 0.32)
			S.light(S.I4, x, y, ZC - 2.0, "#FFF1DE", 0.42, 36)


def structure(K):
	"""Concrete corbels and petrol crossbeams, one pair over each doorway axis, the bench bay and the turbine apron."""
	for yb in S.BEAMS:
		K["CastTrim"].ext_y([(34, 17.9), (34, 22.4), (29.8, 22.4), (29.8, 20.9)], yb - 1.6, yb + 1.6)
		K["CastTrim"].ext_y([(-34, 17.9), (-29.8, 20.9), (-29.8, 22.4), (-34, 22.4)], yb - 1.6, yb + 1.6)
		K["Petrol"].box(-30.2, 30.2, yb - 1.1, yb + 1.1, 22.4, 22.8)
		K["Petrol"].box(-30.2, 30.2, yb - 0.3, yb + 0.3, 22.8, 24.6)
		K["Petrol"].box(-30.2, 30.2, yb - 1.1, yb + 1.1, 24.6, 25.0)
		for x in (-12, 0, 12):
			K["PetrolDark"].box(x - 0.13, x + 0.13, yb - 1.0, yb + 1.0, 22.8, 24.6)
		for sx in (-1, 1):
			K["PetrolDark"].box(*sorted((sx * 29.7, sx * 30.45)), yb - 1.5, yb + 1.5, 22.15, 25.25)
			P = S.FK(K, S.face((sx * 29.7, yb, 0), (0, -sx, 0), (-sx, 0, 0)))
			S.bolts(P["Steel"], [(u, v) for u in (-1.15, 1.15) for v in (22.6, 24.8)], r=0.2)


def colliders():
	"""Sealed collision core: opaque boxes hidden inside the floor, walls and roof (players and the camera stop here)."""
	c = lambda *a, **k: S.collider("Hall", S.I4, *a, **k)
	c(-38, 38, -4, LEN + 4, T, -0.045)  # floor
	c(-14, 14, -14, -4, 1.6, S.LAND - 0.045)  # alcove floor
	for sx in (-1, 1):
		a, b = sx * 34.25, sx * 37.75
		c(a, b, -4, 24, T, 27.8)
		c(a, b, 24, 44, 13.25, 27.8)
		c(a, b, 44, 48, T, 27.8)
		c(sx * 36.25, b, 48, 58, T, 7.0)
		c(a, b, 48, 58, 7.5, 27.8)
		c(a, b, 58, 62, T, 27.8)
		c(a, b, 62, 82, 13.25, 27.8)
		c(a, b, 82, LEN + 4, T, 27.8)
		c(sx * 12.25, sx * 37.75, -3.75, -0.25, T, 27.8)  # entry wall
		c(sx * 14.25, sx * 17.75, -18, -4, T, 19.3)  # alcove sides
		c(sx * 29.3, sx * 34.2, 13.85, 16.15, 0.2, 11.3)  # SUNWELL frame legs
		c(sx * 12.3, sx * 37.8, -4, LEN + 4, ZC + 0.25, ZC + 1.75)  # roof
	c(-38, 38, LEN + 0.25, LEN + 3.75, T, 27.8)  # turbine wall
	for sx in (-1, 1):  # base courses (they stand 0.35 proud of the walls)
		for ya, yb in ((0, 24), (44, 48), (58, 62), (82, LEN)):
			c(sx * 33.4, sx * 34.3, ya, yb, T, 1.4)
			if yb - ya > 6:
				c(sx * 32.95, sx * 33.15, ya, yb, 0, 7.0, kind="Y")  # stops players at the foot of the battered wall (no stepping up it)
		c(sx * 12.2, sx * 33.0, 0.85, 1.05, 0, 7.0, kind="Y")
		c(sx * 12.1, sx * 34, -0.3, 0.25, T, 1.4)
		c(sx * 13.75, sx * 14.3, -14, -4, T, 4.4)
	c(-34, 34, LEN - 0.25, LEN + 0.3, T, 1.4)
	c(-33, 33, LEN - 1.05, LEN - 0.85, 0, 7.0, kind="Y")
	c(-14, 14, -14.3, -13.75, T, 4.4)
	c(-12.25, 12.25, -3.75, -0.25, 17.75, 27.8)  # over the entry portal
	c(-18, 18, -17.75, -14.25, T, 19.3)  # alcove back
	c(-14, 14, -14, -4, 17.7, 19.3)  # alcove ceiling
	c(-33.8, 33.8, 13.85, 16.15, 16.8, 27.8)  # SUNWELL lintel
	for ya, yb in SOLID:
		c(-12.3, 12.3, ya + 0.2, yb - 0.2, ZC + 0.25, ZC + 1.75)
	for ya, yb in SKY:  # glass: invisible, keeps anything from leaving through the roof
		c(-12, 12, ya, yb, ZC + 1.0, ZC + 1.2, kind="Y")


def build():
	K = S.kit("Hall")
	KC = S.kit("Hall_Ceil")
	KR = C.Kit(K.col, prefix="HallWalk")  # pieces that record their own colliders (landing, ramp, cheeks)
	floor(K)
	walls(K)
	alcove(K, KC)
	entry(K, KR)
	proscenium(K)
	roof(KC)
	ceiling_lights(KC)
	structure(K)
	colliders()
	K.done()
	KC.done()
	KR.done()
