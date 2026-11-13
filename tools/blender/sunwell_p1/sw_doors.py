"""Sunwell Works phase 1: the four doorway thresholds (Duels, Locker, Range, Shop).

Each is built in the elevation frame of its wall (X = the viewer's right, Y = up, Z = out of the wall):
a lined reveal 7.6 studs deep that ends in a temporary closure, an individual surround, a wordmark with real
depth and mounts, task lighting and a floor cue. Clear opening 16 x 11 studs.
"""
from math import cos, sin, pi, radians, sqrt
from mathutils import Matrix

import sw_core as S

HWS, HS = 10.0, 13.0  # structural opening (half width, height)
HW, H = 8.0, 11.0  # clear opening
ZB = -7.6  # face of the temporary closure
AMBER, COOL, WARM = "#FFB347", "#DCEBFF", "#FFE9CC"


def stub(F, lining, floor_mat="Rubber", opened=False):
	"""Lined reveal through the wall and 5.4 studs beyond it: sealed behind the closure, or open into a built wing."""
	b = F[lining]
	b.box(-HWS, -HW, -1.5, HS, -9.4, 0)
	b.box(HW, HWS, -1.5, HS, -9.4, 0)
	b.box(-HW, HW, H, HS, -9.4, 0)
	if not opened:
		F["Dark"].box(-HW, HW, -1.5, H, -9.4, -8.6)
	F[floor_mat].box(-HW, HW, -1.5, 0, -9.4 if opened else -8.6, 0)


def stub_colliders(M, opened=False):
	c = lambda *a, **k: S.collider("Doors", M, *a, **k)
	c(-9.85, -8.15, -1.5, 12.85, -9.25, -0.15)
	c(8.15, 9.85, -1.5, 12.85, -9.25, -0.15)
	c(-8.15, 8.15, 11.15, 12.85, -9.25, -0.15)
	if not opened:
		c(-8.15, 8.15, -1.5, 11.15, -9.25, -8.75)  # behind the closure (never seen through its seams)
	c(-8.15, 8.15, -1.5, -0.055, -9.4 if opened else -8.6, 0)  # reveal floor


def sconce(F, x, y, light=True, power=2.4, reach=13):
	"""Bulkhead wall light, modelled as a real fitting (reference: the station-kit lamp, industrial bulkhead lights):
	a mount plate with four fixings, a housing, a bezel with the opal lens set back inside it behind three louvre fins,
	a visor and a drip edge, and a conduit that enters through a gland and runs up to a junction box under a saddle clamp."""
	L = F.at(Matrix.Translation((x, y, 0)))
	with S.grp("Lamp", L.M, inst=True):
		cr = S.cham_rect
		L["PetrolDark"].prism(cr(-0.86, 0.86, -1.95, 1.95, 0.5), 0.0, 0.1)  # mount plate: an elongated octagon
		S.bolts(L["Steel"], [(sx * 0.72, sy * 1.2) for sx in (-1, 1) for sy in (-1, 1)], r=0.075, z0=0.1, h=0.05)
		L["Charcoal"].prism(cr(-0.64, 0.64, -1.52, 1.52, 0.38), 0.1, 0.5)  # housing
		S.ring_prism(L["Graphite"], cr(-0.56, 0.56, -1.4, 1.4, 0.34), cr(-0.4, 0.4, -1.22, 1.22, 0.26), 0.5, 0.66)  # bezel
		L["E_Amber"].prism(cr(-0.4, 0.4, -1.22, 1.22, 0.26), 0.5, 0.56)  # lens, set back in the bezel
		for yy in (-0.5, 0.0, 0.5):
			L["Graphite"].box(-0.4, 0.4, yy - 0.04, yy + 0.04, 0.56, 0.66)  # louvre fins, flush with the bezel
		L["Graphite"].ext_x([(1.2, 0.1), (1.66, 0.1), (1.66, 0.5), (1.38, 0.95), (1.2, 0.95)], -0.3, 0.3)  # visor block over the top facet
		L["Graphite"].box(-0.3, 0.3, -1.62, -1.52, 0.1, 0.6)  # drip edge
		L["Steel"].pipe((0, 1.66, 0.3), (0, 1.86, 0.3), 0.17, 10)  # gland
		L["SteelDark"].pipe((0, 1.86, 0.3), (0, 4.45, 0.3), 0.1, 10)  # conduit
		L["PetrolDark"].box(-0.3, 0.3, 3.0, 3.16, 0.0, 0.44)  # saddle clamp
		S.bolts(L["Steel"], [(-0.22, 3.08), (0.22, 3.08)], r=0.05, z0=0.44, h=0.04)
		L["PetrolDark"].prism(cr(-0.4, 0.4, 4.45, 5.15, 0.1), 0.0, 0.46)  # junction box
		L["Graphite"].prism(cr(-0.3, 0.3, 4.55, 5.05, 0.06), 0.46, 0.5)
		if light:
			S.light(L.M, 0, 0, 1.7, AMBER, power, reach)  # hub upgrade: brighter, tighter warm pools on the walls


def display(F, u, yc, w, h, kind, title, sub=""):
	"""Framed wall display (owner 2026-11-12: the rail and cut corners round the board did not look good): one even
	gunmetal case with small chamfers, a bezel round the screen, a fixing at the middle of each side and a small status
	lamp in the lower bezel. The picture is a SurfaceGui screen built in Studio (S.screen)."""
	D = F.at(Matrix.Translation((u, yc, 0)))
	with S.grp("Display", D.M, inst=True):
		D["Petrol"].prism(S.cham_rect(-w / 2 - 0.55, w / 2 + 0.55, -h / 2 - 0.55, h / 2 + 0.55, 0.45), 0.0, 0.4)
		S.ring_prism(D["Graphite"], S.cham_rect(-w / 2 - 0.3, w / 2 + 0.3, -h / 2 - 0.3, h / 2 + 0.3, 0.32), S.cham_rect(-w / 2, w / 2, -h / 2, h / 2, 0.02), 0.4, 0.62)
		D["Dark"].box(-w / 2, w / 2, -h / 2, h / 2, 0.4, 0.44)
		D["E_Amber"].box(-0.5, 0.5, -h / 2 - 0.2, -h / 2 - 0.1, 0.62, 0.65)
		S.bolts(D["Steel"], [(-w / 2 - 0.42, 0.0), (w / 2 + 0.42, 0.0), (0.0, h / 2 + 0.42), (-2.0, -h / 2 - 0.42), (2.0, -h / 2 - 0.42)], r=0.1, z0=0.4, h=0.07)
		S.screen(kind, title, sub, D.M, 0.0, 0.0, 0.47, w - 0.06, h - 0.06)
		S.light(D.M, 0, 0, 2.4, "#FFE2B8", 0.5, 9)


def threshold_wash(M, color):
	"""Soft wing-coloured light inside a doorway's reveal and a pool on the hall floor in front of it."""
	S.light(M, 0, 6.0, -3.6, color, 1.1, 13)
	S.light(M, 0, 5.0, 3.2, color, 0.55, 9)


def task_light(F, glow, color, y=H, z=-2.8, hw=1.5, brightness=1.6):
	"""Recessed fitting in the reveal soffit, lighting the threshold."""
	F["Charcoal"].box(-hw - 0.3, hw + 0.3, y - 0.22, y, z - 0.6, z + 0.6)
	F[glow].box(-hw, hw, y - 0.3, y - 0.22, z - 0.38, z + 0.38)
	S.light(F.M, 0, y - 1.0, z, color, brightness, 20, angle=120)


def slats(F, mat, n, z0=-8.6, z1=ZB, top=H - 0.15, hw=7.95, base=0.5):
	"""A closed shutter: n horizontal segments above a bottom bar."""
	hh = (top - base) / n
	for k in range(n):
		F[mat].box(-hw, hw, base + k * hh + 0.03, base + (k + 1) * hh - 0.03, z0, z1)
	return hh


# ---------------------------------------------------------------- DUELS: chamfered blast frame
def duels(K):
	side, yc = S.DOORS["Duels"]
	M = S.wall_face(side, yc)
	F = S.FK(K, M)
	with S.grp("Doorway_Duels", M):
		opened = "Duels" in S.OPEN
		stub(F, "Charcoal", opened=opened)
		stub_colliders(M, opened)
		S.u_frame(F["Petrol"], 10.7, 13.7, HW, H, 0.0, 0.9, co=3.2, ci=2.4)
		S.corner_fill(F["Charcoal"], HW, H, ZB, 0.0, cham=2.4)
		S.u_frame(F["Graphite"], HW, H, 7.55, 10.6, -3.3, -2.6, co=2.4, ci=2.2)  # mid rib
		S.u_frame(F["PetrolDark"], HW, H, 7.0, 10.15, ZB, -5.2, co=2.4, ci=2.05)  # inner blast frame
		S.bolts(F["Steel"], [(s * 9.4, y) for s in (-1, 1) for y in (2.0, 5.5, 9.0)], r=0.24, z0=0.9, h=0.16)
		# seamed blast door (temporary closure)
		for s in (() if opened else (-1, 1)):
			F["BlastDoor"].box(*sorted((s * 0.07, s * 7.95)), 0.0, H - 0.1, -8.6, ZB)
			cx = s * 3.6
			F["Graphite"].prism([(cx - 2.5, 2.9), (cx - 1.6, 2.0), (cx + 1.6, 2.0), (cx + 2.5, 2.9), (cx + 2.5, 8.1), (cx + 1.6, 9.0),
				(cx - 1.6, 9.0), (cx - 2.5, 8.1)], ZB, ZB + 0.22)
			S.bolts(F["Steel"], [(cx + u, v) for u in (-1.9, 1.9) for v in (2.7, 8.3)], r=0.17, z0=ZB + 0.22)
		if not opened:
			F["PetrolDark"].box(-1.15, 1.15, 4.85, 6.15, ZB, ZB + 0.34)  # lock block across the seam
			F["P_Orange"].box(-0.75, 0.75, 5.3, 5.7, ZB + 0.34, ZB + 0.4)
		task_light(F, "E_Orange", "#FF7A3A", brightness=0.9)
		threshold_wash(M, "#FFB27A")
		# two orange guide inlays, perpendicular to the sill, running into the opening
		for s in (-1, 1):
			F["P_Orange"].box(s * 3.6 - 0.28, s * 3.6 + 0.28, -0.15, 0.05, -3.4, 3.4)
		F["PetrolDark"].box(-HW, HW, -0.2, 0.06, -0.35, 0.35)  # steel sill
		# sign: a leaning charcoal plate clamped between two orange wedge brackets, italic athletic letters.
		# It sits clear above the casing (top 13.7) and nothing else shares its wall space.
		with S.grp("Sign", M):
			th = radians(10)
			yc = 15.9
			P = F.at(Matrix.Translation((0, yc, 0.55)) @ Matrix.Rotation(th, 4, "X"))
			P["Charcoal"].prism([(-7.8, -1.25), (-7.15, -1.9), (7.8, -1.9), (7.8, 1.25), (7.15, 1.9), (-7.8, 1.9)], 0, 0.6)
			P["Graphite"].prism([(-7.45, -1.2), (-7.0, -1.62), (7.45, -1.62), (7.45, 1.2), (7.0, 1.62), (-7.45, 1.62)], 0.6, 0.68)
			S.add_text(P["Cream"], "DUELS", 2.3, 0.42, y0=-1.15, z0=0.62, s=0.225, c=0.12, shear=0.2, track=0.12)
			S.slash(P["P_Orange"], -6.75, -1.0, 2.0, 0.42, 0.42, 0.62, 0.9)
			S.slash(P["P_Orange"], 5.95, -1.0, 2.0, 0.42, 0.42, 0.62, 0.9)
			zw = lambda y: 1.30 + (y - yc) * 0.1763  # bracket face: just proud of the plate face
			for s in (-1, 1):
				F["P_Orange"].ext_x([(13.95, 0), (13.95, zw(13.95)), (17.95, zw(17.95)), (17.95, 0)], *sorted((s * 7.8, s * 8.7)))
				for yb in (14.7, 17.2):
					S.bolts(F["Steel"], [(s * 8.25, yb)], r=0.17, z0=zw(yb) - 0.06, h=0.2)
			S.light(M, 0, 15.9, 4.0, "#FFE9CC", 0.7, 12)
		for s in (-1, 1):
			sconce(F.at(Matrix.Translation((0, 0, 0.8))), s * 12.6, 8.4)


# ---------------------------------------------------------------- LOCKER: ribbed steel collar
def locker(K):
	side, yc = S.DOORS["Locker"]
	M = S.wall_face(side, yc)
	F = S.FK(K, M)
	with S.grp("Doorway_Locker", M):
		opened = "Locker" in S.OPEN
		stub(F, "Charcoal", opened=opened)
		stub_colliders(M, opened)
		R = 3.2
		S.u_frame(F["SteelDark"], HW, H, 7.8, 10.8, ZB, 0.0, ri=R - 0.2, n=2)  # sleeve (fills the square corners)
		for k in range(5):  # fitted ribs
			z1 = -0.35 - k * 1.42
			S.u_frame(F["Steel"], 7.8, 10.8, 7.42, 10.42, z1 - 0.95, z1, ro=R - 0.2, ri=R - 0.58, n=2)
		S.u_frame(F["Petrol"], 10.6, 13.4, 7.8, 10.8, 0.0, 0.9, ro=R + 2.6, ri=R - 0.2, n=2)
		S.u_frame(F["PetrolDark"], 9.2, 12.1, 7.8, 10.8, 0.9, 1.3, ro=R + 1.25, ri=R - 0.2, n=2)
		if not opened:
			slats(F, "LockerSlat", 6)
			F["Steel"].box(-7.95, 7.95, 0.0, 0.47, -8.6, ZB + 0.12)
			F["E_Blue"].box(-7.3, 7.3, 0.14, 0.3, ZB + 0.12, ZB + 0.17)
		F["E_Blue"].box(-7.4, 7.4, -0.1, 0.06, -0.5, -0.24)  # cool-blue sill line
		F["SteelDark"].box(-HW, HW, -0.2, 0.05, -0.2, 0.5)
		task_light(F, "E_Cool", "#CFE6FF", y=10.42, hw=1.4, brightness=0.5)
		S.light(M, 0, 0.6, -1.0, "#6FC4FF", 0.6, 9)
		threshold_wash(M, "#CFE2FF")
		with S.grp("Sign", M):
			# sign: upright squared letters on a gently arched plate held by two petrol blocks
			y0, hw, rise, he = 13.6, 7.6, 1.35, 2.5
			Rr = (hw * hw + rise * rise) / (2 * rise)
			cy = y0 + he + rise - Rr
			arc = [(hw - 2 * hw * k / 4, cy + sqrt(Rr * Rr - (hw - 2 * hw * k / 4) ** 2)) for k in range(5)]  # arched plate as four flat plates
			F["Charcoal"].prism([(-hw, y0), (hw, y0)] + arc, 0.3, 0.95)
			F["E_Blue"].prism(arc + [(x, y - 0.17) for x, y in arc[::-1]], 0.9, 1.02)
			S.add_text(F["Cream"], "LOCKER", 2.0, 0.42, y0=y0 + 0.35, z0=0.9, s=0.2, c=0.05, ci=0.02, ws=1.06, track=0.2)
			for s in (-1, 1):
				F["Petrol"].box(*sorted((s * 7.6, s * 9.0)), 13.45, 16.3, 0.0, 1.2)
				S.bolts(F["Steel"], [(s * 8.3, 14.2), (s * 8.3, 15.55)], r=0.22, z0=1.2, h=0.15)
			S.light(M, 0, 15.2, 4.0, "#E6F2FF", 0.7, 12)
		for s in (-1, 1):
			sconce(F.at(Matrix.Translation((0, 0, 0.8))), s * 12.6, 8.4)


# ---------------------------------------------------------------- RANGE: shutter cassette
def range_(K):
	side, yc = S.DOORS["Range"]
	M = S.wall_face(side, yc)
	F = S.FK(K, M)
	with S.grp("Doorway_Range", M):
		stub(F, "RangeLining")
		stub_colliders(M)
		S.u_frame(F["Charcoal"], 9.4, 12.2, HW, H, 0.0, 0.7)
		S.u_frame(F["Graphite"], HW, H, 7.6, 10.6, ZB, -6.6)  # inner frame at the closure
		for s in (-1, 1):  # petrol posts carry the cassette
			F["Petrol"].box(*sorted((s * 9.4, s * 10.9)), 0.0, 16.85, 0.0, 1.15)
			S.taper_y(F["PetrolDark"], (*sorted((s * 9.1, s * 11.2)), 0.0, 1.55), 0.0, (*sorted((s * 9.3, s * 11.0)), 0.0, 1.25), 1.4)  # flared foot
			S.bolts(F["Steel"], [(s * 10.15, y) for y in (12.9, 14.45, 16.0)], r=0.22, z0=1.15, h=0.15)
		F["Charcoal"].box(-9.4, 9.4, 12.55, 16.5, 0.0, 1.9)  # the shutter head
		F["Graphite"].box(-9.4, 9.4, 16.5, 16.85, 0.0, 2.1)
		F["Graphite"].box(-9.4, 9.4, 12.2, 12.55, 0.7, 2.1)
		S.add_text(F["Cream"], "RANGE", 2.1, 0.4, y0=13.3, z0=1.85, s=0.215, c=0.1, track=0.14)  # solid (the stencil bridges read as a glitch)
		for s in (-1, 1):
			for k in range(3):
				x = s * (6.15 + k * 0.72) - (0.0 if s > 0 else 0.62)
				S.slash(F["P_Mint"], x, 13.5, 1.7, 0.3, 0.32, 1.85, 2.05)
		# closed shutter (temporary closure): ribbed slats running in two guides, a bottom bar with a pull, a mint status lamp
		F["Dark"].box(-7.95, 7.95, 0.0, H - 0.1, -8.6, -8.4)  # backing behind the slats
		slats(F, "RangePanel", 8, hw=7.3)
		for s in (-1, 1):
			F["Graphite"].box(*sorted((s * 7.3, s * 7.95)), 0.0, H - 0.1, -8.6, ZB + 0.16)  # guide channels
			S.bolts(F["Steel"], [(s * 7.62, v) for v in (2.0, 5.5, 9.0)], r=0.12, z0=ZB + 0.16, h=0.07)
		F["Graphite"].box(-7.3, 7.3, 0.0, 0.5, -8.6, ZB + 0.12)  # bottom bar
		F["Steel"].box(-1.2, 1.2, 0.62, 0.92, ZB, ZB + 0.3)  # pull
		F["E_Mint"].box(-0.5, 0.5, 9.6, 9.85, ZB + 0.02, ZB + 0.08)  # status lamp
		task_light(F, "E_Mint", "#CFF5E0", hw=2.2, brightness=1.5)
		threshold_wash(M, "#C8F2DA")
		# mint calibration ticks in the sill
		F["Graphite"].box(-HW, HW, -0.2, 0.05, -0.3, 0.4)
		for k in range(-3, 4):
			ln = 1.7 if k % 2 == 0 else 0.95
			F["P_Mint"].box(k * 2.0 - 0.17, k * 2.0 + 0.17, -0.15, 0.05, 0.75, 0.75 + ln)
		S.light(M, 0, 14.4, 4.5, "#E6F2FF", 0.7, 12)
		for s in (-1, 1):
			sconce(F.at(Matrix.Translation((0, 0, 0.8))), s * 12.6, 8.4)


# ---------------------------------------------------------------- SHOP: low ribbed valance
def shop(K):
	side, yc = S.DOORS["Shop"]
	M = S.wall_face(side, yc)
	F = S.FK(K, M)
	with S.grp("Doorway_Shop", M):
		opened = "Shop" in S.OPEN
		stub(F, "Charcoal", opened=opened)
		stub_colliders(M, opened)
		S.u_frame(F["Petrol"], 10.4, 12.6, HW, H, 0.0, 0.8, co=2.0, ci=1.5)
		S.corner_fill(F["Charcoal"], HW, H, ZB, 0.0, cham=1.5)
		S.u_frame(F["Graphite"], HW, H, 7.6, 10.6, ZB, -6.6, co=1.5, ci=1.35)
		# valance: a low ribbed head with vertical amber end caps and a warm wash under its front edge
		F["Charcoal"].box(-10.6, 10.6, 12.6, 16.0, 0.0, 2.0)
		for k in range(5):
			y = 12.78 + k * 0.64
			F["Graphite"].box(-10.3, 10.3, y, y + 0.4, 2.0, 2.2)
		for s in (-1, 1):
			F["Charcoal"].prism(S.fillet([(s * 10.6, 12.25, 0.2), (s * 11.2, 12.25, 0.2), (s * 11.2, 16.35, 0.2), (s * 10.6, 16.35, 0.2)]), 0.0, 2.35)
			F["E_Amber"].box(*sorted((s * 10.74, s * 11.06)), 12.85, 15.75, 2.35, 2.43)
			S.light(M, s * 10.9, 14.3, 3.4, AMBER, 0.7, 9)
		F["E_Amber"].box(-9.7, 9.7, 12.42, 12.6, 1.25, 1.75)
		S.add_text(F["Cream"], "SHOP", 2.25, 0.45, y0=13.15, z0=2.15, s=0.24, c=0.2, ci=0.07, ws=1.22, track=0.15, style="round")
		S.light(M, 0, 11.6, 3.2, "#FFC777", 0.9, 14)
		# warm horizontal shutter (temporary closure)
		if not opened:
			slats(F, "ShopSlat", 6)
			F["Bronze"].box(-7.95, 7.95, 0.0, 0.47, -8.6, ZB + 0.12)
			F["Graphite"].box(-1.2, 1.2, 0.6, 0.95, ZB, ZB + 0.3)  # pull handle
		task_light(F, "E_Opal", "#FFD9A0", hw=2.2, brightness=1.5)
		threshold_wash(M, "#FFB04A")
		S.light(M, 0, 6.0, -6.0, "#FFC070", 1.4, 12)  # deeper in the reveal: the Shop mouth never reads as a hole
		# short dark entry mat
		F["PetrolDark"].box(-HW, HW, -0.2, 0.05, -0.3, 0.4)
		F["Rubber"].box(-7.0, 7.0, -0.15, 0.07, 0.7, 5.5)
		for k in range(9):
			z = 1.15 + k * 0.47
			F["Graphite"].box(-6.4, 6.4, 0.07, 0.11, z, z + 0.22)
		for s in (-1, 1):
			sconce(F.at(Matrix.Translation((0, 0, 0.8))), s * 12.6, 8.4)


def build():
	K = S.kit("Doors")
	duels(K)
	locker(K)
	range_(K)
	shop(K)
	K.done()
