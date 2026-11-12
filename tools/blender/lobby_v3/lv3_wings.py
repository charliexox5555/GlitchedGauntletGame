"""Lobby V3 wings: Market (west, round arches and timber), Vault (east, circles and steel), Range (south, sawtooth and raw concrete).
Each is written in a local frame whose +Y points away from the hub; the Kit rotates it into place."""
from math import sin, cos, pi, radians, sqrt, atan, atan2, asin, degrees
from mathutils import Matrix
import lv3_core as C

D = radians


def arcade(y0, y1, z0, H, ops, n=22):
	"""Wall outline (y, z) with round-arched openings (centre, width, spring) that reach the floor."""
	pts = [(y0, z0)]
	for yc, w, spring in ops:
		r = w / 2
		pts.append((yc - r, z0))
		for i in range(n + 1):
			a = pi - pi * i / n
			pts.append((yc + r * cos(a), z0 + spring + r * sin(a)))
		pts.append((yc + r, z0))
	return pts + [(y1, z0), (y1, H), (y0, H)]


def arch_trim_x(K, matname, x0, x1, yc, zs, r0, r1, n):
	b = K[matname]
	for i in range(n):
		p, q = pi * i / n, pi * (i + 1) / n
		b.ext_x([(yc + r0 * cos(p), zs + r0 * sin(p)), (yc + r1 * cos(p), zs + r1 * sin(p)),
			(yc + r1 * cos(q), zs + r1 * sin(q)), (yc + r0 * cos(q), zs + r0 * sin(q))], x0, x1)


def can_light(K, x, y, z, r=0.55):
	"""Small recessed downlight: steel trim ring and a diffuser."""
	K["Steel"].ring(r, r + 0.25, z - 0.12, z, n=16, cx=x, cy=y)
	K["E_Down"].disc(r, z - 0.06, z, n=16, cx=x, cy=y)


# =============================================================== MARKET (west)
def market():
	ZM, HW, Y0, Y1, H = -1.2, 28.0, 52.0, 112.0, 17.0
	C.surface("Plaster", "#C9C2B4", 0.9, var=0.07, bump=0.14, streak=0.08, grime=(ZM, 2.5, 0.2))
	C.surface("FloorWarm", "#6F6558", 0.38, seams=dict(mode="floor", h=3, v=3, w=0.04, dark=0.35), bump=0.12)
	C.surface("OakApse", "#A0703F", 0.55, var=0.08, bump=0.2,
		seams=dict(mode="polar_slats", v=0.9, w=0.09, dark=0.75, rref=15.0, cx=-115.0, cy=0.0))
	C.emission("E_Lantern", "#FFD3A0", 20.0)
	C.emission("E_CoveSoft", C.ACCENT["Warm"], 40.0)
	C.BEVEL.update({"OakApse": 0.0, "FloorWarm": 0.08, "Plaster": 0.4})
	C.clear("Market")
	C.clear("Market_Ceil")
	col, cc = C.coll("Market", C.root()), C.coll("Market_Ceil", C.root())
	K, KC = C.Kit(col, D(90)), C.Kit(cc, D(90))

	# floor: landing, two steps down, then a darker runner with brass borders up to the shop
	fl = [(52, -5), (52, 0), (55, 0), (55, -0.6), (56.2, -0.6), (56.2, ZM), (Y1 + 3, ZM), (Y1 + 3, -5)]
	for x0, x1, m in ((-HW, -6.25, "FloorPale"), (-6.25, -6, "Brass"), (-6, 6, "FloorWarm"), (6, 6.25, "Brass"), (6.25, HW, "FloorPale")):
		K[m].ext_x(fl, x0, x1)
	K["FloorPale"].box(-32, 32, 48, 52, -5, 0)
	for sx in (-1, 1):
		K["FloorPale"].box(sx * HW, sx * (HW + 10), Y0, Y1, -5, ZM)
	K["Plaster"].ext_y(C.arch_opening(64, H, 16, 6, 28), 48, 52)

	sides = {1: [(64, 14, 7), (82, 14, 7), (100, 14, 7)], -1: [(82, 24, 3.3), (103.5, 9, 6)]}
	for sx, ops in sides.items():
		xa, xb = sx * HW, sx * (HW + 10)
		K["Plaster"].ext_x(arcade(Y0, Y1, ZM, H, ops), xa, xb)
		K["Plaster"].box(xb, sx * (HW + 13), Y0, Y1, -5, H)
		edges = [Y0]
		for yc, w, spring in ops:
			r = w / 2
			top = ZM + spring + r
			grand = w > 20
			tr = 1.2 if grand else 1.4
			edges += [yc - r - tr - 0.25, yc + r + tr + 0.25]
			K["Oak"].box(sx * (HW + 9.72), xb, yc - r - 1, yc + r + 1, ZM, top + 0.5)
			K["ConcreteLight"].box(sx * (HW + 0.9), sx * (HW + 9.72), yc - r + 0.6, yc + r - 0.6, ZM, ZM + 0.5)  # dais
			arch_trim_x(K, "ConcreteLight", sx * (HW - 0.55), xa, yc, ZM + spring, r, r + tr, 17 if grand else 11)
			for sy in (-1, 1):
				K["ConcreteLight"].box(sx * (HW - 0.55), xa, yc + sy * r, yc + sy * (r + tr), ZM + 1.0, ZM + spring)
				K["ConcreteDark"].box(sx * (HW - 0.8), xa, yc + sy * (r - 0.15), yc + sy * (r + tr + 0.2), ZM, ZM + 1.0)
			K["ConcreteLight"].box(sx * (HW - 0.85), xa, yc - 0.9, yc + 0.9, top - 0.3, top + tr + 0.15)  # keystone
			xm = sx * (HW + 5.2)
			if grand:  # Battle Pass: second step, big framed board, two brass posts
				K["ConcreteLight"].box(sx * (HW + 4.5), sx * (HW + 9.72), yc - r + 2.5, yc + r - 2.5, ZM + 0.5, ZM + 1.0)
				K["Steel"].box(sx * (HW + 9.3), sx * (HW + 9.72), yc - 8.6, yc + 8.6, ZM + 2.2, ZM + 11.6)
				K["Screen"].box(sx * (HW + 9.15), sx * (HW + 9.3), yc - 8.0, yc + 8.0, ZM + 2.8, ZM + 11.0)
				for sy in (-1, 1):
					K["Brass"].frame(0, sx * (HW + 5.4), yc + sy * 9.4, ZM + 0.5).disc(0.45, 0, 4.2, n=16, r1=0.32)
					K["E_Lantern"].frame(0, sx * (HW + 5.4), yc + sy * 9.4, ZM + 0.5).disc(0.55, 4.2, 5.0, n=16)
				for dy in (-6, 0, 6):
					can_light(K, sx * (HW + 5.0), yc + dy, ZM + spring + sqrt(r * r - dy * dy) - 0.02)
			else:  # shop alcove: stone counter along the back, oak shelves with a light under each
				K["ConcreteLight"].box(sx * (HW + 7.7), sx * (HW + 9.72), yc - r + 1.1, yc + r - 1.1, ZM + 0.5, ZM + 2.3)
				K["OakDark"].box(sx * (HW + 7.5), sx * (HW + 9.72), yc - r + 0.9, yc + r - 0.9, ZM + 2.3, ZM + 2.6)
				hw2 = r - 1.6 if w > 10 else r - 1.0
				for zs in ((ZM + 5.0, ZM + 7.4) if (sx < 0 or yc == 82) else ()):  # shelves only where goods sit on them
					K["OakDark"].box(sx * (HW + 8.5), sx * (HW + 9.72), yc - hw2, yc + hw2, zs, zs + 0.28)
					K["E_Lantern"].box(sx * (HW + 8.7), sx * (HW + 9.1), yc - hw2 + 0.4, yc + hw2 - 0.4, zs - 0.05, zs)
				can_light(K, xm, yc, top - 0.02)
		edges.append(Y1)
		for i in range(0, len(edges), 2):  # stone dado and an oak rail between the arches
			if edges[i + 1] - edges[i] > 0.6:
				K["ConcreteLight"].box(sx * (HW - 0.35), xa, edges[i], edges[i + 1], ZM, ZM + 3.2)
				K["OakDark"].box(sx * (HW - 0.5), xa, edges[i], edges[i + 1], ZM + 3.2, ZM + 3.55)
		# wall plate that carries the joists, with a soft uplight on top
		K["OakDark"].box(sx * (HW - 0.9), xa, Y0, Y1, 15.5, 16.1)
		K["E_CoveSoft"].box(sx * (HW - 0.7), sx * (HW - 0.3), Y0 + 1, Y1 - 1, 16.1, 16.15)

	# colonnade: stone piers carry the oak girders and split the hall into a nave and two aisles
	for x in (-19.0, 19.0):
		for y in (58, 73, 91, 109):
			K["ConcreteDark"].frame(0, x, y, ZM).box(-1.7, 1.7, -1.7, 1.7, 0, 1.0)
			K["ConcreteLight"].frame(0, x, y, ZM).taper((-1.3, 1.3, -1.3, 1.3), 1.0, (-1.1, 1.1, -1.1, 1.1), 14.4)
			K["ConcreteLight"].frame(0, x, y, ZM).box(-1.4, 1.4, -1.4, 1.4, 14.4, 15.0)
			K["ConcreteLight"].frame(0, x, y, ZM).box(-1.7, 1.7, -1.7, 1.7, 15.0, 15.9)
			K["OakDark"].frame(0, x, y, ZM).box(-1.9, 1.9, -1.9, 1.9, 3.2, 3.55)
		KC["OakDark"].box(x - 0.9, x + 0.9, Y0, Y1, 14.7, 16.1)
		for y in (65.5, 82, 100):
			KC["Steel"].pipe((x, y, 12.6), (x, y, 14.7), 0.1, 8)
			KC["Steel"].box(x - 0.8, x + 0.8, y - 0.8, y + 0.8, 12.3, 12.6)
			KC["E_Lantern"].box(x - 0.6, x + 0.6, y - 0.6, y + 0.6, 10.7, 12.3)
			KC["Steel"].box(x - 0.75, x + 0.75, y - 0.75, y + 0.75, 10.45, 10.7)

	# market island: an octagonal display plinth under a timber canopy
	iy = 82.0
	K["ConcreteLight"].frame(D(22.5), 0, iy).disc(5.4, ZM, ZM + 0.9, n=8, r1=5.1)
	K["OakDark"].frame(D(22.5), 0, iy).disc(4.9, ZM + 0.9, ZM + 1.2, n=8)
	K["Brass"].frame(D(22.5), 0, iy).ring(3.2, 3.45, ZM + 1.2, ZM + 1.24, n=8)
	for sx in (-1, 1):
		for sy in (-1, 1):
			K["OakDark"].frame(0, sx * 3.3, iy + sy * 3.3).box(-0.32, 0.32, -0.32, 0.32, ZM + 1.2, 9.2)
	K["OakDark"].frame(D(22.5), 0, iy).ring(4.1, 5.5, 9.2, 9.9, n=8)
	K["Oak"].frame(D(22.5), 0, iy).ring(4.3, 5.3, 9.9, 10.05, n=8)
	KC["Steel"].pipe((0, iy, 8.6), (0, iy, H), 0.1, 8)
	KC["Steel"].box(-0.9, 0.9, iy - 0.9, iy + 0.9, 8.3, 8.6)
	KC["E_Lantern"].box(-0.7, 0.7, iy - 0.7, iy + 0.7, 6.5, 8.3)
	KC["Steel"].box(-0.85, 0.85, iy - 0.85, iy + 0.85, 6.25, 6.5)

	# end wall, arch and the shop apse
	prof = [(x, z + ZM) for x, z in C.arch_opening(2 * (HW + 13), H - ZM, 24, 3.3, 30)]
	K["Plaster"].ext_y(prof, Y1, Y1 + 3)
	K["ConcreteLight"].band_y(0, ZM + 3.3, 12.0, 13.5, 0, pi, 17, Y1 - 0.6, Y1)
	for sx in (-1, 1):
		K["ConcreteLight"].box(sx * 12.0, sx * 13.5, Y1 - 0.6, Y1, ZM + 1.0, ZM + 3.3)
		K["ConcreteDark"].box(sx * 11.8, sx * 13.8, Y1 - 0.9, Y1, ZM, ZM + 1.0)
		K["ConcreteLight"].box(sx * 14.0, sx * (HW - 0.5), Y1 - 0.35, Y1, ZM, ZM + 3.2)
		K["OakDark"].box(sx * 14.0, sx * (HW - 0.5), Y1 - 0.5, Y1, ZM + 3.2, ZM + 3.55)
	K["ConcreteLight"].box(-1.1, 1.1, Y1 - 0.95, Y1, 13.7, 15.9)
	cy = Y1 + 3
	K["Plaster"].ring(15, 18, -5, H, 0, pi, cx=0, cy=cy)
	n = 40
	K["FloorPale"].prism([(15 * cos(pi * i / n), cy + 15 * sin(pi * i / n)) for i in range(n + 1)], -5, ZM)
	K["ConcreteLight"].prism([(14.4 * cos(pi * i / n), cy + 0.3 + 14.4 * sin(pi * i / n)) for i in range(n + 1)], ZM, ZM + 0.6)
	K["OakApse"].ring(14.72, 15, ZM + 0.6, 11.0, 0.05, pi - 0.05, cx=0, cy=cy)
	K["OakDark"].ring(14.2, 15, 11.0, 11.7, 0.03, pi - 0.03, cx=0, cy=cy)
	K["OakDark"].ring(14.2, 14.45, 11.7, 12.1, 0.03, pi - 0.03, cx=0, cy=cy)
	K["E_CoveSoft"].ring(14.55, 14.9, 11.7, 11.76, 0.1, pi - 0.1, cx=0, cy=cy)
	K["Steel"].ring(14.55, 15, 12.5, 16.3, D(68), D(112), cx=0, cy=cy)  # shop sign mount
	K["Screen"].ring(14.42, 14.55, 12.9, 15.9, D(70), D(110), cx=0, cy=cy)
	K["OakDark"].ring(7.6, 9.2, ZM + 0.6, 2.4, D(28), D(152), cx=0, cy=cy)  # shop counter stand-in
	K["ConcreteLight"].ring(7.35, 9.45, 2.4, 2.8, D(27), D(153), cx=0, cy=cy)
	for a in (D(55), D(90), D(125)):
		can_light(KC, 11.5 * cos(a), cy + 11.5 * sin(a), H)

	# ceiling: slab and close-set oak joists
	KC["ConcreteCeil"].box(-HW - 13, HW + 13, 48, cy + 19, H, 24)
	y = 54.5
	while y < Y1:
		KC["OakDark"].box(-HW, HW, y - 0.45, y + 0.45, 16.1, H)
		y += 4.5
	C.dummy(K, 3.0, 60, ZM, 0.2)
	C.dummy(K, 23.0, 80, ZM, -1.2)
	K.done()
	KC.done()


# =============================================================== VAULT (east)
BAY_ANGLES = (-45, 0, 45, 90, 135, 180, 225)  # display bays round the Locker wall, degrees in the room frame


def vault():
	"""The Locker: a clean round showroom. Seven recessed, lit display bays round the wall, a projector pedestal in the
	middle. No door inside the room (it is rolled aside in the hub gate)."""
	RV, CY, H = 26.0, 76.0, 19.0  # room radius, centre (local y), ceiling
	WR, RB, BH = 30.0, 28.3, 15.0  # outer wall, back of the bays, bay half angle (degrees)
	S = C.surface
	S("VaultPanel", "#56616D", 0.5, var=0.04, bump=0.03, ao=0.45)
	S("VaultPier", "#65717E", 0.5, var=0.04, bump=0.03, ao=0.45)
	S("VaultFloor", "#2B3138", 0.35, bump=0.06,
		seams=dict(mode="polar_floor", h=4.0, n=32, w=0.04, dark=0.35, cx=CY, cy=0.0))
	S("BayBack", "#A9B2BC", 0.6, var=0.03, bump=0.02, ao=0.5)
	S("Cabinet", "#353D46", 0.5, var=0.04, bump=0.03, ao=0.45)
	C.emission("E_VaultLamp", "#E6F4FF", 7.0)
	C.emission("E_Lens", "#45DCFF", 6.0)
	C.BEVEL.update({"VaultPanel": 0.3, "VaultPier": 0.3, "VaultFloor": 0.06, "BayBack": 0.0, "Cabinet": 0.25, "E_Lens": 0.0})
	C.clear("Vault")
	C.clear("Vault_Ceil")
	col, cc = C.coll("Vault", C.root()), C.coll("Vault_Ceil", C.root())
	K, KC = C.Kit(col, D(-90)), C.Kit(cc, D(-90))
	R = dict(cx=0.0, cy=CY)
	m0 = atan2(52 - CY, 10)  # where the wall meets the mouth block
	a0, a1 = m0, pi - m0  # wall runs the long way round

	# mouth block and the last tube rib
	K["Concrete"].ext_y(C.round_opening(34, 24, 10.0, 7.5, 48), 48, 52)
	K["Rubber"].box(-9.9, 9.9, 48, 52, -3, 0)
	foot = asin(-7.5 / 10.0)
	tilt = Matrix.Translation((0, 0, 7.5)) @ Matrix.Rotation(D(-90), 4, "X")
	K["Brushed"].framem(tilt).lathe([(9.45, 50.2), (10.2, 50.2), (10.2, 51.9), (9.45, 51.9)], -(pi - foot), -foot, 72)

	# floor with two inlay rings, the centre platform and the projector pedestal
	f = K["VaultFloor"]
	f.disc(11.8, -3, 0, n=96, **R)
	f.ring(12.2, 19.8, -3, 0, n=128, **R)
	f.ring(20.2, WR, -3, 0, a0, a1, **R)
	arc = [(20.2 * cos(a0 + (pi - 2 * a0 - 2 * pi) * i / 12), CY + 20.2 * sin(a0 + (pi - 2 * a0 - 2 * pi) * i / 12)) for i in range(13)]
	f.prism([(-10, 52), (10, 52)] + arc, -3, 0)
	K["Brushed"].ring(11.8, 12.2, -3, 0, n=128, **R)
	K["Brushed"].ring(19.8, 20.2, -3, 0, n=128, **R)
	K["Cabinet"].disc(8.0, 0, 0.6, n=64, r1=7.6, **R)
	K["Brushed"].ring(6.0, 6.4, 0.6, 1.2, n=64, **R)
	K["VaultFloor"].disc(6.0, 0.6, 1.2, n=64, **R)
	K["Cabinet"].disc(2.7, 1.2, 2.5, n=40, r1=2.35, **R)
	K["Brushed"].ring(1.9, 2.35, 2.5, 2.62, n=40, **R)
	K["E_Lens"].disc(1.9, 2.5, 2.56, n=40, **R)
	K["P_Vault"].box(-0.3, 0.3, 52.5, CY - 8.4, 0.0, 0.03)
	C.collider_cyl("Vault", CY, 0.0, 2.9, 2.5, 12.0, kind="X")  # keeps players out of the hologram (world coordinates)

	def wall(p0, p1):
		K["VaultPanel"].ring(RV, WR, 0, 13, D(p0), D(p1), **R)
		K["VaultPanel"].ring(RV, WR, 13.6, H, D(p0), D(p1), **R)

	# piers between the bays: a raised panel with a slim steel inlay, on a dark skirt
	piers = [(degrees(a0), BAY_ANGLES[0] - BH)] + [(m + BH, m + 45 - BH) for m in BAY_ANGLES[:-1]] + [(BAY_ANGLES[-1] + BH, degrees(a1))]
	for p0, p1 in piers:
		wall(p0, p1)
		K["Cabinet"].lathe([(RV - 0.5, 0), (RV, 0), (RV, 0.8), (RV - 0.3, 0.8)], D(p0), D(p1), **R)
		if p1 - p0 > 12:
			mid = (p0 + p1) / 2
			K["VaultPier"].ring(RV - 0.5, RV, 0.8, 12.6, D(mid - 4.5), D(mid + 4.5), **R)
			K["Brushed"].ring(RV - 0.58, RV - 0.5, 2.0, 11.4, D(mid - 0.45), D(mid + 0.45), **R)

	# display bays: recess, steel frame, slanted cabinet below, hood with a hidden light above
	for m in BAY_ANGLES:
		b0, b1 = D(m - BH), D(m + BH)
		K["VaultPanel"].ring(RV, WR, 0, 1.7, b0, b1, **R)
		K["BayBack"].ring(RB, WR, 1.7, 11.6, b0, b1, **R)
		K["VaultPanel"].ring(RV, WR, 11.6, 13, b0, b1, **R)
		K["VaultPanel"].ring(RV, WR, 13.6, H, b0, b1, **R)
		st = K["Steel"]
		st.ring(RV - 0.25, RV + 0.3, 1.7, 1.95, b0, b1, **R)
		st.ring(RV - 0.25, RV + 0.3, 11.35, 11.6, b0, b1, **R)
		st.ring(RV - 0.25, RB, 1.95, 11.35, b0, D(m - BH + 0.9), **R)
		st.ring(RV - 0.25, RB, 1.95, 11.35, D(m + BH - 0.9), b1, **R)
		K["Cabinet"].lathe([(RV - 1.5, 0), (RV, 0), (RV, 1.7), (RV - 1.1, 1.7), (RV - 1.5, 1.25)], D(m - BH + 1), D(m + BH - 1), **R)
		st.ring(RV - 1.3, RV, 11.6, 13.0, D(m - BH - 1), D(m + BH + 1), **R)  # header, joins the steel band above
		K["E_CoveCool"].ring(RV - 1.0, RV - 0.35, 11.54, 11.6, D(m - BH + 1.5), D(m + BH - 1.5), **R)
		K["Glass"].ring(RV - 0.1, RV + 0.2, 1.95, 11.35, D(m - BH + 0.9), D(m + BH - 0.9), **R)  # glass front: look, don't touch
		K["P_Vault"].ring(RV - 1.16, RV - 1.04, 1.7, 1.74, D(m - BH + 2.5), D(m + BH - 2.5), **R)  # thin accent line on the cabinet
	K["Steel"].ring(RV - 0.3, WR, 13, 13.6, a0, a1, **R)

	# ceiling: two rings and a big round lamp (an echo of the hub's light well)
	c = KC["ConcreteCeil"]
	c.ring(17.0, WR, H, 26, n=128, **R)
	c.ring(7.6, 17.0, H + 2.0, 26, n=96, **R)
	c.disc(7.6, H + 2.8, 26, n=64, **R)
	c.box(-17, 17, 48, 52, 24, 26)
	KC["Steel"].ring(6.4, 7.6, H + 1.2, H + 2.9, n=64, **R)
	KC["E_VaultLamp"].disc(6.4, H + 2.3, H + 2.4, n=64, **R)
	KC["Steel"].ring(16.4, 17.0, H, H + 0.5, n=128, **R)
	KC["Steel"].ring(16.1, 16.4, H, H + 1.6, n=128, **R)
	KC["E_CoveCool"].ring(16.75, 17.0, H + 0.6, H + 1.4, n=128, **R)
	for k in range(8):
		rb = KC["Brushed"].frame(D(22.5 + 45 * k), 0, CY, 0)
		rb.ext_y([(17.0, H), (RV, H), (RV, H - 1.7), (24.4, H - 1.0), (17.0, H - 0.6)], -0.7, 0.7)
	C.dummy(K, 2.0, 58, 0.0, 0.1)
	K.done()
	KC.done()


# =============================================================== RANGE (south)
def range_wing():
	ZR, HW, Y0, Y1, H = -2.0, 28.0, 52.0, 92.0, 18.0
	C.surface("ConcreteRange", "#8B8A86", 0.85, seams=dict(mode="wall", h=4.0, v=8.0, w=0.05, dark=0.4, z0=ZR),
		streak=0.22, grime=(ZR, 3.0, 0.35))
	C.surface("Baffle", "#39424A", 0.92, var=0.08, bump=0.3, grain=3.0, ao=0.5)
	C.surface("Target", "#D8D2C4", 0.7, var=0.06, bump=0.05, ao=0.3)
	C.emission("E_RangeBar", "#E4EEF8", 16.0)
	C.emission("E_RangeHall", "#EAF2FA", 34.0)
	C.BEVEL.update({"ConcreteRange": 0.4, "Target": 0.15, "Baffle": 0.2})
	C.clear("Range")
	C.clear("Range_Ceil")
	col, cc = C.coll("Range", C.root()), C.coll("Range_Ceil", C.root())
	K, KC = C.Kit(col, D(180)), C.Kit(cc, D(180))

	# floor and the ramp down from the shutter gate
	K["Rubber"].box(-HW, HW, Y0, Y1 + 4, -6, ZR)
	K["Rubber"].box(-9, 9, 48, 52, -6, 0)
	K["Rubber"].ext_x([(52, ZR), (52, 0), (64, ZR)], -9, 9)
	for sx in (-1, 1):
		K["ConcreteRange"].ext_x([(52, ZR), (52, 1.2), (64, -0.8), (65.2, -1.2), (65.2, ZR)], sx * 9, sx * 10.6)
		K["Hazard"].ext_x([(52, 1.2), (52, 1.5), (64, -0.5), (65.4, -0.95), (65.2, -1.2), (64, -0.8)], sx * 8.85, sx * 10.75)
	K["P_Range"].box(-0.3, 0.3, 65, Y1 - 3.4, ZR, ZR + 0.03)
	C.hazard(K, -HW + 0.8, HW - 0.8, Y1 - 3.2, Y1 - 2.2, ZR, ZR + 0.03)
	K["ConcreteRange"].ext_y([(-32, -6), (-9, -6), (-9, 12), (9, 12), (9, -6), (32, -6), (32, H), (-32, H)], 48, 52)

	# left wall: sawtooth fins with light on the faces that look down-range
	K["ConcreteRange"].box(-HW - 4, -HW, Y0, Y1, -6, H)
	for y in range(56, 88, 8):
		K["ConcreteRange"].prism([(-HW, y), (-HW, y + 6.5), (-HW + 3.0, y + 6.5)], ZR, 12.5)
		K["Steel"].box(-HW, -HW + 3.2, y + 6.5, y + 6.85, ZR, 12.5)
		K["E_RangeBar"].box(-HW + 0.6, -HW + 2.6, y + 6.85, y + 6.9, 3.4, 10.4)
	# right wall: a caged armoury recess (racks go in later)
	xr = HW
	K["ConcreteRange"].box(xr, xr + 4, Y0, 64, -6, H)
	K["ConcreteRange"].box(xr, xr + 4, 86, Y1, -6, H)
	K["ConcreteRange"].box(xr, xr + 4, 64, 86, -6, ZR + 1.6)
	K["ConcreteRange"].box(xr, xr + 4, 64, 86, 9.6, H)
	K["ConcreteDark"].box(xr + 3.2, xr + 4, 64, 86, ZR + 1.6, 9.6)
	K["Steel"].box(xr - 0.3, xr + 0.5, 63.6, 64.4, ZR, 10.0)
	K["Steel"].box(xr - 0.3, xr + 0.5, 85.6, 86.4, ZR, 10.0)
	K["Steel"].box(xr - 0.3, xr + 0.5, 64.4, 85.6, 9.4, 10.0)
	K["SteelBlue"].box(xr - 1.2, xr + 0.6, 64.4, 85.6, ZR + 1.6, ZR + 2.0)  # counter
	for y in (69.7, 75.0, 80.3):
		K["Steel"].box(xr - 0.1, xr + 0.2, y - 0.15, y + 0.15, ZR + 2.0, 9.4)
	for z in (3.2, 5.2, 7.2):
		K["Steel"].box(xr + 0.0, xr + 0.15, 64.4, 85.6, z, z + 0.14)
	for y in (68, 75, 82):
		can_light(K, xr + 1.8, y, 9.6, 0.5)
	# dado and the range stripe on both side walls
	for sx, y0, y1 in ((-1, 52, 56), (1, 52, 63.6), (1, 86.4, 92)):
		K["ConcreteDark"].ext_y([(sx * HW, ZR), (sx * (HW - 0.6), ZR), (sx * (HW - 0.3), ZR + 2.4), (sx * HW, ZR + 2.4)], y0, y1)
		K["P_Range"].box(sx * (HW - 0.06), sx * HW, y0, y1, ZR + 3.0, ZR + 3.6)

	# end wall: range gate in the middle, viewing windows each side
	ya, yb = Y1, Y1 + 4
	cw = K["ConcreteRange"]
	for sx in (-1, 1):
		cw.box(sx * 32, sx * 23, ya, yb, -6, H)
		cw.box(sx * 23, sx * 9, ya, yb, -6, -0.2)
		cw.box(sx * 23, sx * 9, ya, yb, 5.2, H)
		cw.box(sx * 9, sx * 6, ya, yb, -6, H)
		K["Glass"].box(sx * 23, sx * 9, ya + 1.85, ya + 2.15, -0.2, 5.2)
		K["Steel"].box(sx * 23.3, sx * 8.7, ya - 0.35, ya + 0.4, -0.75, -0.12)
		K["Steel"].box(sx * 23.3, sx * 8.7, ya - 0.35, ya + 0.4, 5.12, 5.75)
		for xm in (9.0, 16.0, 23.0):
			K["Steel"].box(sx * (xm - 0.3), sx * (xm + 0.3), ya - 0.3, ya + 0.35, -0.12, 5.12)
		K["SteelBlue"].box(sx * 23.3, sx * 8.7, ya - 1.7, ya - 0.35, -1.1, -0.75)  # ledge
		for xm in (11.0, 21.0):
			K["Steel"].ext_x([(ya, -1.1), (ya - 1.4, -1.1), (ya, -1.95)], sx * (xm - 0.15), sx * (xm + 0.15))
		K["Steel"].box(sx * 23.3, sx * 8.7, ya - 2.0, ya, 6.3, 6.9)  # light soffit over the window
		for xm in (11.5, 16.0, 20.5):
			can_light(K, sx * xm, ya - 1.0, 6.3, 0.45)
		K["ConcreteDark"].box(sx * 6.0, sx * 8.2, ya - 0.8, ya, ZR, 9.0)  # gate surround
		C.hazard(K, sx * 6.0, sx * 7.0, ya - 1.0, ya - 0.8, ZR, 6.0)
		K["Steel"].box(sx * 8.6, sx * 9.4, ya - 0.4, ya, 7.4, 9.0)
		K["E_Range"].box(sx * 8.8, sx * 9.2, ya - 0.48, ya - 0.4, 7.7, 8.7)
	cw.box(-6, 6, ya, yb, 9.0, H)
	K["ConcreteDark"].box(-8.2, 8.2, ya - 0.8, ya, 9.0, 10.6)
	K["Steel"].box(-6.0, 6.0, ya - 1.0, ya + 0.6, 8.6, 9.0)
	K["Steel"].box(-9.5, 9.5, ya - 0.35, ya, 11.4, 15.6)  # sign mount
	K["Screen"].box(-9.0, 9.0, ya - 0.5, ya - 0.35, 11.8, 15.2)

	# the range beyond the glass: lanes, targets, receding light bars
	L0, L1 = yb, yb + 70
	K["Rubber"].box(-32, 32, L0, L1, -6, ZR)
	K["ConcreteRange"].box(-36, -32, L0, L1, -6, 14)
	K["ConcreteRange"].box(32, 36, L0, L1, -6, 14)
	K["ConcreteDark"].box(-36, 36, L1, L1 + 4, -6, 14)
	for x in (-18, -6, 6, 18):
		K["P_White"].box(x - 0.1, x + 0.1, L0 + 2, L1 - 8, ZR, ZR + 0.03)
	for x, y in ((-24, 30), (-12, 48), (0, 22), (12, 58), (24, 38)):
		K["Target"].frame(0, x, L0 + y, ZR).ext_y(
			[(-1.3, 1.6), (1.3, 1.6), (1.3, 4.4), (0.7, 5.0), (0.7, 6.3), (-0.7, 6.3), (-0.7, 5.0), (-1.3, 4.4)], -0.12, 0.12)
		K["Steel"].frame(0, x, L0 + y, ZR).box(-0.15, 0.15, -0.1, 0.1, 0, 1.6)
		K["Steel"].frame(0, x, L0 + y, ZR).box(-0.9, 0.9, -0.5, 0.5, 0, 0.15)
		K["P_Range"].frame(0, x, L0 + y, ZR).box(-0.45, 0.45, -0.16, -0.12, 3.0, 3.9)
	C.hazard(K, -32, 32, L1 - 3, L1 - 2.4, ZR, ZR + 2.2)

	# ceiling: dark sawtooth baffles; the light sits on the faces that look down-range
	saw = [(52, 24), (52, 17.0)]
	for y in range(52, 84, 8):
		saw += [(y + 8, 12.6), (y + 8, 17.0)]
	saw += [(92, 17.0), (92, 24)]
	KC["Baffle"].ext_x(saw, -32, 32)
	for y in range(60, 92, 8):
		KC["Steel"].box(-HW, HW, y - 0.3, y + 0.1, 12.5, 12.9)
		KC["Steel"].box(-HW + 3, HW - 3, y, y + 0.12, 14.2, 15.8)
		KC["E_RangeBar"].box(-HW + 3.3, HW - 3.3, y + 0.12, y + 0.16, 14.4, 15.6)
	KC["ConcreteCeil"].box(-36, 36, 92, L1 + 4, H, 24)
	KC["ConcreteCeil"].box(-36, 36, yb, L1 + 4, 14, H)
	for y in range(int(L0) + 10, int(L1), 12):
		KC["Steel"].box(-30, 30, y - 0.4, y + 0.4, 13.3, 14)
		KC["E_RangeHall"].box(-29, 29, y - 0.25, y + 0.25, 13.24, 13.3)
	C.dummy(K, -3.0, 56, -0.4, 0.2)
	C.dummy(K, 14.0, 86, ZR, 0.1)
	K.done()
	KC.done()


def build():
	market()
	vault()
	range_wing()
