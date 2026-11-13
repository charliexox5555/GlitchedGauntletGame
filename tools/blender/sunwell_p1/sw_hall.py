"""Sunwell Works phase 1: the hall shell (floor, walls, roof with skylights, arrival alcove, ramp,
the SUNWELL WORKS frame, corbels and crossbeams) and its sealed collision core."""
from math import atan, cos, sin, sqrt
from mathutils import Matrix, Vector

import lv3_core as C
import sw_core as S
import sw_doors as DR

T = -1.5  # underside of floors and wall bases
HX, LEN, ZW, ZC = S.HX, S.LEN, S.ZW, S.ZC
SKY = ((22.9, 45.1), (48.1, 57.9), (60.9, 83.1), (86.1, 95.9))  # skylight openings (y ranges) between the beams, x -12..12
SOLID = ((-4.0, 22.9), (45.1, 48.1), (57.9, 60.9), (83.1, 86.1), (95.9, LEN + 4))  # roof between them
RAMP_A = atan(3.0 / 16.0)


def SD(sx):
	return "W" if sx < 0 else "E"


def WB(sx, y):
	"""The wall piece a point on a side wall belongs to: the bays between the pilasters (pieces in Studio)."""
	bay = "Entry" if y < 24 else "Duels" if y < 44 and sx < 0 else "Locker" if y < 44 else "Bench" if y < 62 else "Range" if sx < 0 and y < 82 else "Shop" if y < 82 else "Far"
	return S.grp(f"Wall_{SD(sx)}_{bay}", reuse=True)


def _pairs(v):
	return list(zip(v, v[1:]))


def floor(K):
	with S.grp("HallFloor"):
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
		for k in range(n):  # laid slabs: a checker of two close shades (hub upgrade: the walk read as one plain sheet)
			y0, y1 = 20 + 81 * k / n, 20 + 81 * (k + 1) / n
			K["Walk" if k % 2 == 0 else "Walk2"].box(-11, 0, y0, y1, T, 0)
			K["Walk2" if k % 2 == 0 else "Walk"].box(0, 11, y0, y1, T, 0)
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
			with WB(sx, (ya + yb) / 2):
				K["Wall"].box(xa, xb, ya, yb, T, z[1])
		for ya, yb in ((0, 24), (82, 112)):  # battered base and wainscot, a sloped belt ledge
			with WB(sx, (ya + yb) / 2):
				K["WallBase"].ext_y([(sx * (HX - 1.0), T), (xo, T), (xo, z[0]), (sx * (HX - 0.78), z[0])], ya, yb)
				K["WallLow"].ext_y([(sx * (HX - 0.6), z[0]), (xo, z[0]), (xo, z[1]), (sx * HX, z[1])], ya, yb)
				K["Belt"].ext_y([(sx * HX, z[1] - 0.3), (sx * (HX - 0.45), z[1]), (sx * (HX - 0.45), z[1] + 0.2), (sx * HX, z[1] + 0.2)], ya, yb)
		with S.grp(f"Wall_{SD(sx)}_Crown"):
			K["Belt"].ext_y([(sx * HX, ZW - 0.8), (sx * (HX - 0.7), ZW), (sx * HX, ZW)], 0, LEN)  # crown: a facet that starts the haunch early
		for ya, yb in low_b:
			with WB(sx, (ya + yb) / 2):
				K["Wall"].box(xa, xb, ya, yb, z[1], z[2])
		for ya, yb in up_c:
			with WB(sx, (ya + yb) / 2):
				K["Wall"].box(xa, xb, ya, yb, z[2], z[3])
		for ya, yb in up_d:
			with WB(sx, (ya + yb) / 2):
				K["Wall"].box(xa, xb, ya, yb, z[3], z[4])
		ra, rb = sorted((sx * 36, sx * 38))
		with WB(sx, 53):
			K["Charcoal"].box(ra, rb, 48, 58, T, z[1])  # back of the bench recess
		for yb in S.BEAMS:  # pilasters frame each doorway and the bench bay: flared foot, straight shaft, flared head
			bay = {46.6: (44.9, 48.0), 59.4: (58.0, 61.1)}.get(yb)  # these two fill the strip between a door casing and the bench recess

			def shoe(bay, a, sx=sx):
				y0, y1 = bay
				y0, y1 = y0 + 0.06, y1 - 0.06  # inset inside the pier foot: no sliver, no shared plane
				return (*sorted((sx * (HX - a), sx * HX)), y0, y1)

			def r(a, grow, bay=bay, yb=yb):
				y0, y1 = bay if bay else (yb - 1.2 - grow, yb + 1.2 + grow)
				return (*sorted((sx * (HX - a), sx * HX)), y0, y1)

			with S.grp(f"Pilaster_{SD(sx)}_{yb:g}", Matrix.Translation((sx * HX, yb, 0))):
				K["WallBase"].taper(r(1.6, 0.8), 0, r(1.3, 0.5), z[0])
				K["CastTrim"].taper(r(1.15, 0.35), z[0], r(0.8, 0.0), 4.6)
				K["CastTrim"].box(*r(0.8, 0.0), 4.6, 16.2)
				K["CastTrim"].taper(r(0.8, 0.0), 16.2, r(1.25, 0.45), 17.9)
				if bay:  # a bay pier's shoe stands 0.06 proud on the recess side (no plane shared with the cast foot)
					K["PetrolDark"].taper(shoe(bay, 1.22), z[0], shoe(bay, 1.14), z[0] + 0.9)
				else:  # steel shoe
					K["PetrolDark"].taper(r(1.22, 0.42), z[0], r(1.14, 0.34), z[0] + 0.9)
				S.collider("Hall", S.I4, *sorted((sx * (HX + 0.3), sx * (HX - 0.6))), yb - 1.0, yb + 1.0, 0, 17.7)
	# turbine wall
	# end-wall prisms stop 0.1 short of the outer faces and 0.04 above the underside: nothing coplanar with the side walls outside
	with S.grp("Wall_Turbine", reuse=True):
		K["WallBase"].ext_x([(LEN - 1.0, T + 0.04), (LEN + 3.9, T + 0.04), (LEN + 3.9, z[0]), (LEN - 0.78, z[0])], -37.9, 37.9)
	with S.grp("Wall_Turbine", reuse=True):
		K["WallLow"].ext_x([(LEN - 0.6, z[0]), (LEN + 3.9, z[0]), (LEN + 3.9, z[1]), (LEN, z[1])], -37.9, 37.9)
	for xa, xb in _pairs([-38, -26, -13.5, 0, 13.5, 26, 38]):
		with S.grp("Wall_Turbine", reuse=True):
			K["Wall"].box(xa, xb, LEN, LEN + 4, z[1], z[2])
	for sx in (-1, 1):
		with S.grp("Wall_Turbine", reuse=True):
			K["Belt"].box(*sorted((sx * 13.6, sx * HX)), LEN - 0.3, LEN, z[1] - 0.22, z[1] + 0.22)
		with S.grp("Wall_Entry", reuse=True):
			K["Belt"].box(*sorted((sx * 13.5, sx * HX)), -0.0, 0.3, z[1] - 0.22, z[1] + 0.22)
	with S.grp("Wall_Turbine", reuse=True):
		K["Belt"].box(-HX, HX, LEN - 0.4, LEN, ZW - 0.6, ZW)
	with S.grp("Wall_Entry", reuse=True):
		K["Belt"].box(-HX, HX, 0, 0.4, ZW - 0.6, ZW)
	for xa, xb in _pairs([-38, -25, -12, 0, 12, 25, 38]):
		with S.grp("Wall_Turbine", reuse=True):
			K["Wall"].box(xa, xb, LEN, LEN + 4, z[2], z[3])
		with S.grp("Wall_Turbine", reuse=True):
			K["Wall"].box(xa, xb, LEN, LEN + 4, z[3], z[4])
		with S.grp("Wall_Entry", reuse=True):
			K["Wall"].box(xa, xb, -4, 0, z[3], z[4])  # entry wall, above the portal
	for xa, xb in _pairs([-38, -19, 0, 19, 38]):
		with S.grp("Wall_Turbine", reuse=True):
			K["Wall"].box(xa, xb, LEN, LEN + 4, z[4], ZC)
		with S.grp("Wall_Entry", reuse=True):
			K["Wall"].box(xa, xb, -4, 0, z[4], ZC)
	with S.grp("Wall_Entry", reuse=True):
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
	with S.grp("Alcove", reuse=True):
		K["Walk"].box(-14, 14, -14, -4, 1.5, S.LAND)
		for sx in (-1, 1):
			K["WallBase"].box(*sorted((sx * 13.65, sx * 18)), -14, -4, T, 4.5)
			for ya, yb in ((-14, -9), (-9, -4)):
				K["WallLow"].box(*sorted((sx * 14, sx * 18)), ya, yb, 4.5, 11)
				K["WallShade"].box(*sorted((sx * 14, sx * 18)), ya, yb, 11, 19.5)
		K["WallBase"].box(-17.95, 17.95, -17.95, -13.65, T + 0.04, 4.5)
		for xa, xb in _pairs([-18, -9, 0, 9, 18]):
			K["WallLow"].box(xa, xb, -18, -14, 4.5, 11)
			K["WallShade"].box(xa, xb, -18, -14, 11, 19.5)
		KC["Ceil"].box(-14, 14, -14, -4, 17.5, 19.5)
	# the arrival gate (staging art: where players came in)
	with S.grp("ArrivalGate", S.face((0, -14, S.LAND), (-1, 0, 0), (0, 1, 0))):
		A = S.FK(K, S.face((0, -14, S.LAND), (-1, 0, 0), (0, 1, 0)))
		S.u_frame(A["Petrol"], 9.6, 11.6, 8.0, 10.0, 0.0, 0.7, co=1.6, ci=1.2)
		A["Charcoal"].box(-8, 8, 0, 10, 0.0, 0.25)
		S.corner_fill(A["Charcoal"], 8, 10, 0.25, 0.45, cham=1.2)
		for s in (-1, 1):
			A["BlastDoor"].box(*sorted((s * 0.08, s * 7.6)), 0.25, 9.6, 0.25, 0.5)
			cx = s * 3.85
			A["Petrol"].prism(S.cham_rect(cx - 3.0, cx + 3.0, 1.0, 8.9, 0.5), 0.5, 0.6)  # raised panel with cut corners
			A["Graphite"].prism(S.cham_rect(cx - 2.4, cx + 2.4, 6.0, 8.3, 0.35), 0.6, 0.66)  # vision plate
			A["Graphite"].box(*sorted((s * 1.0, s * 6.6)), 4.3, 5.3, 0.6, 0.72)
		A["E_Opal"].box(-3.0, 3.0, 10.35, 10.75, 0.7, 0.78)
		for s in (-1, 1):  # lit jamb strips set in the frame
			A["E_Sun"].box(*sorted((s * 8.45, s * 8.75)), 0.6, 9.4, 0.7, 0.76)
		S.light(A.M, 0, 11.8, 3.0, "#FFE2B8", 0.8, 18, angle=100)
	for sx in (-1, 1):  # side walls beside the spawn: a recessed service panel and a wall lamp each side
		Fw = S.face((sx * 14, -9, S.LAND), (0, -sx, 0), (-sx, 0, 0))
		with S.grp(f"AlcovePanel_{SD(sx)}", Fw, inst=True):
			P = S.FK(K, Fw)
			P["PetrolDark"].prism(S.cut_rect(-3.4, 0.6, 1.6, 10.2, 0.7, 0.2), 0.0, 0.16)  # mount plate
			P["Petrol"].prism(S.cut_rect(-3.1, 0.3, 1.9, 9.9, 0.55, 0.15), 0.16, 0.34)  # panel
			for k in range(5):  # vent slots in the upper half
				y = 6.4 + k * 0.62
				P["Dark"].box(-2.5, -0.3, y, y + 0.26, 0.34, 0.37)
			P["Graphite"].box(-2.6, -0.2, 2.7, 4.9, 0.34, 0.46)  # access hatch
			P["Steel"].box(-1.7, -1.1, 3.6, 3.9, 0.46, 0.56)  # hatch pull
			P["E_Sun"].box(-0.75, -0.25, 5.3, 5.5, 0.34, 0.4)  # status lamp
			S.bolts(P["Steel"], [(-3.15, 2.1), (0.35, 2.1), (-3.15, 9.7), (0.35, 9.7)], r=0.1, z0=0.16, h=0.06)
		DR.sconce(S.FK(K, Fw), 2.6, 9.4, power=0.9, reach=9)  # dim: the alcove frames the bright hall
	for s in (-1, 1):  # opal ceiling panels
		with S.grp("AlcoveLight", Matrix.Translation((s * 7, -9, 17.5)), inst=True):
			KC["Charcoal"].box(s * 7 - 2.2, s * 7 + 2.2, -10.4, -7.6, 17.3, 17.5)
			KC["E_Opal"].box(s * 7 - 1.9, s * 7 + 1.9, -10.1, -7.9, 17.22, 17.3)
			S.light(S.I4, s * 7, -9, 16.6, "#FFF0DC", 0.55, 18)


def entry(K, KR):
	"""Landing, ramp into the hall, cheek walls with rails, and the ENTRY portal lining."""
	with S.grp("EntryRamp"):
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
		with S.grp(f"EntryRail_{SD(sx)}"):
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
	with S.grp("EntryPortal", S.F_ENTRY):
		E = S.FK(K, S.F_ENTRY)
		S.u_frame(E["Petrol"], 13.4, 19.0, 11.2, 16.7, 0.0, 0.8, co=1.8, ci=1.3, y0=S.LAND)
		S.u_frame(E["CastTrim"], 12.0, 17.5, 11.2, 16.7, -4.6, 0.0, ci=1.3, y0=S.LAND)  # concrete liner, with a lip on the alcove side
		S.bolts(E["PetrolDark"], [(sx * 12.3, yy) for sx in (-1, 1) for yy in (5.0, 10.0, 15.0)], r=0.22, z0=0.8)
		S.add_text(E["Cream"], "ENTRY", 1.35, 0.3, y0=17.2, z0=0.75, s=0.2, c=0.1, track=0.2)


def proscenium(K):
	with S.grp("SunwellFrame", S.F_PROS_S):
		prof = [(-34, 0), (-29, 0), (-29, 11.5), (-24, 16.5), (24, 16.5), (29, 11.5), (29, 0), (34, 0), (34, ZW), (28, ZC), (-28, ZC), (-34, ZW)]
		K["Cast"].ext_y(prof, S.PROS[0], S.PROS[1])
		for sx in (-1, 1):
			K["WallBase"].taper((*sorted((sx * 28.2, sx * 34.0)), S.PROS[0] - 0.8, S.PROS[1] + 0.8), 0,
				(*sorted((sx * 28.6, sx * 34.0)), S.PROS[0] - 0.4, S.PROS[1] + 0.4), 1.6)  # flared plinth
			K["Petrol"].ext_y([(sx * 29.0, 9.4), (sx * 29.0, 11.5), (sx * 24.0, 16.5), (sx * 21.9, 16.5), (sx * 21.9, 16.2), (sx * 23.85, 16.2),
				(sx * 28.7, 11.35), (sx * 28.7, 9.4)], S.PROS[0] - 0.12, S.PROS[1] + 0.12)  # steel liner under each shoulder


def roof(KC):
	with S.grp("Roof"):
		for ya, yb in ((0, S.PROS[0]), (S.PROS[1], LEN)):
			KC["Ceil"].ext_y([(34, ZW), (38, ZW), (38, ZC), (28, ZC)], ya, yb)
			KC["Ceil"].ext_y([(-34, ZW), (-28, ZC), (-38, ZC), (-38, ZW)], ya, yb)
		KC["Ceil"].box(12, 38, -4, LEN + 4, ZC, ZC + 2)
		KC["Ceil"].box(-38, -12, -4, LEN + 4, ZC, ZC + 2)
		for ya, yb in SOLID:
			KC["Ceil"].box(-12, 12, ya, yb, ZC, ZC + 2)
	for ya, yb in SKY:
		with S.grp("Skylight", Matrix.Translation((0, (ya + yb) / 2, ZC))):
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
			with S.grp("CeilingLight", Matrix.Translation((x, y, ZC)), inst=True):
				KC["Charcoal"].box(x - 3.2, x + 3.2, y - 0.95, y + 0.95, ZC - 0.32, ZC)
				KC["E_Opal"].box(x - 2.9, x + 2.9, y - 0.62, y + 0.62, ZC - 0.4, ZC - 0.32)
				S.light(S.I4, x, y, ZC - 2.0, "#EBF0FF", 0.22, 22)  # lighting pass: a cool, tight fill (the old range-36 fill flooded the hall flat)


def structure(K):
	"""Concrete corbels and petrol crossbeams, one pair over each doorway axis, the bench bay and the turbine apron."""
	for yb in S.BEAMS:
		with S.grp(f"Beam_{yb:g}", Matrix.Translation((0, yb, 0)), inst=True):
			K["CastTrim"].ext_y([(34, 17.9), (34, 22.4), (29.8, 22.4), (29.8, 20.9)], yb - 1.6, yb + 1.6)
			K["CastTrim"].ext_y([(-34, 17.9), (-29.8, 20.9), (-29.8, 22.4), (-34, 22.4)], yb - 1.6, yb + 1.6)
			K["Petrol"].prism(S.cham_rect(-30.2, 30.2, yb - 1.1, yb + 1.1, 0.45), 22.4, 22.8)  # flanges with cut ends (no blunt cutoffs)
			K["Petrol"].box(-30.2, 30.2, yb - 0.3, yb + 0.3, 22.8, 24.6)
			K["Petrol"].prism(S.cham_rect(-30.2, 30.2, yb - 1.1, yb + 1.1, 0.45), 24.6, 25.0)
			for sx in (-1, 1):  # knee braces: a gusset plate from the corbel's face up under the beam, with a flange on its edge
				xa, xb = sx * 29.8, sx * 26.4
				K["PetrolDark"].ext_y([(xa, 20.9), (xa, 22.4), (xb, 22.4)] if sx > 0 else [(xb, 22.4), (xa, 22.4), (xa, 20.9)], yb - 0.15, yb + 0.15)
				d = 0.32  # flange along the brace's sloped edge
				K["Petrol"].ext_y([(xa, 20.9), (xb, 22.4), (xb + sx * d * 0.4, 22.4 - d), (xa, 20.9 - d)] if sx > 0 else
					[(xa, 20.9 - d), (xb + sx * d * 0.4, 22.4 - d), (xb, 22.4), (xa, 20.9)], yb - 0.45, yb + 0.45)
			for x in (-12, 0, 12):
				K["PetrolDark"].box(x - 0.13, x + 0.13, yb - 1.0, yb + 1.0, 22.8, 24.6)
			for sx in (-1, 1):
				K["PetrolDark"].box(*sorted((sx * 29.7, sx * 30.45)), yb - 1.5, yb + 1.5, 22.15, 25.25)
				P = S.FK(K, S.face((sx * 29.7, yb, 0), (0, -sx, 0), (-sx, 0, 0)))
				S.bolts(P["Steel"], [(u, v) for u in (-1.15, 1.15) for v in (22.6, 24.8)], r=0.2)


def colliders():
	"""Sealed collision core: opaque boxes hidden inside the floor, walls and roof (players and the camera stop here)."""
	c = lambda *a, **k: S.collider("Hall", S.I4, *a, **k)
	with S.grp("HallFloor", reuse=True):
		c(-38, 38, -4, LEN + 4, T, -0.045)  # floor
	with S.grp("Alcove", reuse=True):
		c(-14, 14, -14, -4, 1.6, S.LAND - 0.045)  # alcove floor
	for sx in (-1, 1):
		a, b = sx * 34.25, sx * 37.75
		with WB(sx, 10):
			c(a, b, -4, 24, T, 27.8)
		with WB(sx, 34):
			c(a, b, 24, 44, 13.25, 27.8)
		with WB(sx, 46):
			c(a, b, 44, 48, T, 27.8)
		with WB(sx, 53):
			c(sx * 36.25, b, 48, 58, T, 7.0)
		with WB(sx, 53):
			c(a, b, 48, 58, 7.5, 27.8)
		with WB(sx, 60):
			c(a, b, 58, 62, T, 27.8)
		with WB(sx, 72):
			c(a, b, 62, 82, 13.25, 27.8)
		with WB(sx, 90):
			c(a, b, 82, LEN + 4, T, 27.8)
		with S.grp("Wall_Entry", reuse=True):
			c(sx * 12.25, sx * 37.75, -3.75, -0.25, T, 27.8)  # entry wall
		with S.grp("Alcove", reuse=True):
			c(sx * 14.25, sx * 17.75, -18, -4, T, 19.3)  # alcove sides
		with S.grp("SunwellFrame", reuse=True):
			c(sx * 29.3, sx * 34.2, 13.85, 16.15, 0.2, 11.3)  # SUNWELL frame legs
		with S.grp("Roof", reuse=True):
			c(sx * 12.3, sx * 37.8, -4, LEN + 4, ZC + 0.25, ZC + 1.75)  # roof
	with S.grp("Wall_Turbine", reuse=True):
		c(-38, 38, LEN + 0.25, LEN + 3.75, T, 27.8)  # turbine wall
	for sx in (-1, 1):  # base courses (they stand 0.35 proud of the walls)
		for ya, yb in ((0, 24), (44, 48), (58, 62), (82, LEN)):
			with WB(sx, (ya + yb) / 2):
				c(sx * 33.4, sx * 34.3, ya, yb, T, 1.4)
			with WB(sx, (ya + yb) / 2):
				if yb - ya > 6:
					c(sx * 32.95, sx * 33.15, ya, yb, 0, 7.0, kind="Y")  # stops players at the foot of the battered wall (no stepping up it)
		with S.grp("Wall_Entry", reuse=True):
			c(sx * 12.2, sx * 33.0, 0.85, 1.05, 0, 7.0, kind="Y")
		with S.grp("Wall_Entry", reuse=True):
			c(sx * 12.1, sx * 34, -0.3, 0.25, T, 1.4)
		with S.grp("Alcove", reuse=True):
			c(sx * 13.75, sx * 14.3, -14, -4, T, 4.4)
	with S.grp("Wall_Turbine", reuse=True):
		c(-34, 34, LEN - 0.25, LEN + 0.3, T, 1.4)
	with S.grp("Wall_Turbine", reuse=True):
		c(-33, 33, LEN - 1.05, LEN - 0.85, 0, 7.0, kind="Y")
	with S.grp("Alcove", reuse=True):
		c(-14, 14, -14.3, -13.75, T, 4.4)
	with S.grp("Wall_Entry", reuse=True):
		c(-12.25, 12.25, -3.75, -0.25, 17.75, 27.8)  # over the entry portal
	with S.grp("Alcove", reuse=True):
		c(-18, 18, -17.75, -14.25, T, 19.3)  # alcove back
	with S.grp("Alcove", reuse=True):
		c(-14, 14, -14, -4, 17.7, 19.3)  # alcove ceiling
	with S.grp("SunwellFrame", reuse=True):
		c(-33.8, 33.8, 13.85, 16.15, 16.8, 27.8)  # SUNWELL lintel
	for ya, yb in SOLID:
		with S.grp("Roof", reuse=True):
			c(-12.3, 12.3, ya + 0.2, yb - 0.2, ZC + 0.25, ZC + 1.75)
	for ya, yb in SKY:  # glass: invisible, keeps anything from leaving through the roof
		with S.grp("Roof", reuse=True):
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
