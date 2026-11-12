"""Lobby V3 hub: the Sunwell. Compact drum (R 38), big light well (R 20), four different gatehouses."""
from math import sin, cos, pi, radians, sqrt, atan2, asin
from mathutils import Matrix
import lv3_core as C

D = radians
R = 38.0  # inner wall radius
RO = 42.0  # outer wall radius (wall is 4 thick)
GH = 15.0  # gatehouse half width
GF = 34.5  # gatehouse face distance from centre
GB = 48.0  # gatehouse back (where a wing starts)
TOP = 30.0  # top of every roof slab
G_ANG = asin(GH / R)  # where a gatehouse corner meets the drum
PIER = D(27.0)  # pier offset from a wing axis
AXIS = {"Duels": D(90), "Market": D(180), "Range": D(270), "Vault": D(0)}
ROT = {"Duels": 0.0, "Market": D(90), "Range": D(180), "Vault": D(-90)}  # local north -> wing axis


def floors(K):
	f = K["FloorHub"]
	f.ring(27.3, 34.0, -3, 0)
	for ax in AXIS.values():  # outer band only between gatehouses
		f.ring(34.0, RO, -3, 0, ax + G_ANG, ax + pi / 2 - G_ANG)
	K["Brass"].ring(27.0, 27.3, -3, 0)
	K["ConcreteDark"].lathe([(25, -3), (27, -3), (27, -0.5), (26, -0.5), (26, -1.0), (25, -1.0)], n=128)
	s = K["SunStone"]
	s.ring(14.4, 25.0, -3, -1.5, n=128)
	s.ring(7.2, 14.0, -3, -1.5)
	K["Brass"].ring(14.0, 14.4, -3, -1.5)
	# centre plinth: the centrepiece stands here later
	d = K["ConcreteDark"]
	d.disc(7.2, -3, -1.5)
	d.disc(7.0, -1.5, -0.8, r1=6.6)
	K["Concrete"].disc(5.6, -0.8, -0.15, r1=5.3)
	K["Brass"].ring(4.5, 4.9, -0.15, 0.1)
	K["Steel"].disc(4.5, -0.15, 0.1)


def drum(K):
	nh = D(10.5)  # niche half angle
	for qi, ax in enumerate(AXIS.values()):
		a0, a1 = ax + G_ANG, ax + pi / 2 - G_ANG
		am = (a0 + a1) / 2
		K["ConcreteDark"].lathe([(37.2, 0), (RO, 0), (RO, 1.4), (37.75, 1.4)], a0, a1)
		c = K["ConcreteHub"]
		c.ring(R, RO, 1.4, 14, a0, am - nh)
		c.ring(R, RO, 1.4, 14, am + nh, a1)
		c.ring(R, RO, 1.4, 2.4, am - nh, am + nh)
		c.ring(39.6, RO, 2.4, 12.4, am - nh, am + nh)
		c.ring(R, RO, 12.4, 14, am - nh, am + nh)
		t = K["SteelBlue"]
		t.ring(37.7, 39.6, 2.4, 2.8, am - nh, am + nh)
		t.ring(37.7, 39.6, 12.0, 12.4, am - nh, am + nh)
		t.ring(37.7, 39.6, 2.8, 12.0, am - nh, am - nh + D(0.9))
		t.ring(37.7, 39.6, 2.8, 12.0, am + nh - D(0.9), am + nh)
		t.ring(37.5, RO, 14, 15, a0, a1)
		K["Screen"].ring(39.45, 39.6, 3.6, 11.2, am - D(8.6), am + D(8.6))
		# frieze with three louvred vents
		vents = [am - D(13), am, am + D(13)]
		vh = D(2.6)
		edges = [a0] + [v + sg * vh for v in vents for sg in (-1, 1)] + [a1]
		for i in range(0, len(edges), 2):
			c.ring(R, RO, 15, 18, edges[i], edges[i + 1])
		for v in vents:
			c.ring(R, RO, 15, 15.6, v - vh, v + vh)
			c.ring(R, RO, 17.3, 18, v - vh, v + vh)
			c.ring(38.9, RO, 15.6, 17.3, v - vh, v + vh)
			for j in range(4):
				K["Steel"].lathe([(38.0, 15.72 + 0.4 * j), (38.75, 15.9 + 0.4 * j), (38.75, 16.0 + 0.4 * j), (38.0, 15.82 + 0.4 * j)], v - vh, v + vh)
		for z in (5.6, 9.8):  # panel lines either side of the niche
			K["Seam"].ring(37.95, R, z, z + 0.1, a0 + D(0.4), am - nh - D(1.0))
			K["Seam"].ring(37.95, R, z, z + 0.1, am + nh + D(1.0), a1 - D(0.4))
		for av in (a0 + D(5.2), a1 - D(5.2)):
			K["Seam"].ring(37.95, R, 1.5, 13.9, av - D(0.08), av + D(0.08))
		# cove light hidden behind a steel valance under the ring beam
		K["SteelBlue"].ring(37.0, 37.25, 17.15, 18.05, a0, a1)
		K["E_Cove"].ring(37.5, 37.9, 17.8, 17.95, a0, a1)
		# service conduits on two of the four walls only
		if qi in (0, 2):
			for z in (13.0, 13.55):
				K["Steel"].ring(37.55, 37.98, z, z + 0.36, a0 + D(5.5), a1 - D(5.5))
			for k in range(6):
				a = a0 + D(7) + (a1 - a0 - D(14)) * k / 5
				K["Steel"].ring(37.45, 38.0, 12.85, 14.0, a - D(0.35), a + D(0.35))
			ad = a1 - D(8.5)
			K["Steel"].ring(37.55, 37.98, 5.2, 13.0, ad - D(0.3), ad + D(0.3))
			K["SteelBlue"].ring(37.3, 38.0, 3.6, 5.4, ad - D(1.4), ad + D(1.4))
	K["SteelBlue"].lathe([(36.4, 19.0), (37.5, 18.0), (RO, 18.0), (RO, 21.0), (36.4, 21.0)], n=160)


def piers(K):
	"""Battered buttress with a corbel head and a half-round up/down wall light."""
	prof = [(38.5, 0), (33.3, 0), (33.3, 1.3), (34.0, 2.1), (34.9, 10.6), (34.9, 12.6), (33.7, 14.2), (33.7, 18.0), (38.5, 18.0)]
	for ax in AXIS.values():
		for sgn in (-1, 1):
			a = ax + sgn * PIER
			K["ConcreteHub"].frame(a).ext_y(prof, -2.6, 2.6)
			K["ConcreteDark"].frame(a).box(33.0, 38.5, -3.1, 3.1, 0, 1.2)
			st = K["SteelBlue"].frame(a)
			st.box(34.6, 38.5, -3.0, -2.6, 1.2, 18.0)  # steel cheeks
			st.box(34.6, 38.5, 2.6, 3.0, 1.2, 18.0)
			st.box(33.45, 38.5, -3.0, 3.0, 13.9, 14.5)
			K["Steel"].frame(a).lathe([(0.5, 6.5), (0.82, 6.5), (0.82, 8.3), (0.5, 8.3)], D(90), D(270), 12, cx=34.72, cy=0)
			K["E_Cove"].frame(a).lathe([(0.06, 8.24), (0.5, 8.24), (0.5, 8.3), (0.06, 8.3)], D(90), D(270), 10, cx=34.72, cy=0)
			K["E_Cove"].frame(a).lathe([(0.06, 6.5), (0.5, 6.5), (0.5, 6.56), (0.06, 6.56)], D(90), D(270), 10, cx=34.72, cy=0)


def ceiling(K):
	c = K["ConcreteCeil"]
	c.ring(30.0, RO, 21, TOP, n=128)
	c.ring(22.0, 30.0, 24.5, TOP, n=128)
	K["SteelBlue"].ring(29.3, 30.0, 21.0, 21.4, n=128)  # shelf and upstand hide the cove
	K["SteelBlue"].ring(29.0, 29.3, 21.0, 22.9, n=128)
	K["E_Cove"].ring(29.8, 30.0, 21.6, 22.6, n=128)
	st = K["Steel"]
	st.ring(20.0, 22.0, 23.4, TOP, n=128)  # oculus collar
	K["Rock"].ring(20.6, 25.0, TOP, 62.0, n=96)
	for z in (37.0, 46.0, 55.0):
		st.ring(19.9, 20.6, z, z + 0.8, n=96)
	st.ring(2.2, 3.4, 24.0, 26.2)
	for k in range(8):
		st.frame(D(22.5 + 45 * k)).box(3.2, 20.3, -0.55, 0.55, 24.4, 25.8)
	for k in range(16):  # recessed downlights over the ring walk, between the ribs
		a = D(22.5 * k)
		x, y = 33.4 * cos(a), 33.4 * sin(a)
		K["Steel"].ring(0.75, 1.05, 20.8, 21.0, n=20, cx=x, cy=y)
		K["E_Down"].disc(0.75, 20.9, 21.0, n=20, cx=x, cy=y)
	for k in range(16):
		r = K["SteelBlue"].frame(D(11.25 + 22.5 * k))
		r.ext_y([(30.0, 21.0), (36.6, 21.0), (36.6, 19.1), (34.6, 19.9), (30.0, 20.3)], -0.8, 0.8)
		r.ext_y([(22.3, 24.5), (29.0, 24.5), (29.0, 23.1), (22.3, 23.8)], -0.8, 0.8)


def throat_floor(K, matname, z1=0.0):
	n = 16
	g = asin(GH / 34.0)
	pts = [(34.0 * sin(-g + 2 * g * i / n), 34.0 * cos(-g + 2 * g * i / n)) for i in range(n + 1)]
	pts += [(GH, GB), (-GH, GB)]
	K[matname].prism(pts, -3, z1)


def sign_mount(K, z0, z1, hw=9.0, accent=None):
	"""A framed plate built into the gatehouse where that wing's sign will go."""
	K["Steel"].box(-hw - 0.5, hw + 0.5, GF - 0.35, GF, z0 - 0.5, z1 + 0.5)
	K["Screen"].box(-hw, hw, GF - 0.5, GF - 0.35, z0, z1)
	if accent:
		K[accent].box(-hw, hw, GF - 0.6, GF - 0.35, z0 - 0.45, z0 - 0.15)


def lintel(K, z, hw=12.0, matname="ConcreteDark"):
	K[matname].box(-hw, hw, GF - 1.3, GF, z, z + 1.1)
	for sx in (-1, 1):
		K[matname].ext_y([(sx * (hw - 0.3), z), (sx * (hw - 2.2), z), (sx * (hw - 2.2), z - 0.5), (sx * (hw - 0.3), z - 1.8)], GF - 1.0, GF)


def threshold(K, hw):
	K["Steel"].box(-hw, hw, GF - 2.0, GF - 0.9, 0.0, 0.05)
	for i in range(int(hw * 2 / 0.8)):
		x = -hw + 0.2 + 0.8 * i
		K["Screen"].box(x, x + 0.4, GF - 1.85, GF - 1.05, 0.05, 0.06)


def gate_duels(K):
	"""Blast gate: low, wide, chamfered. Compression before the Duels hall."""
	K["ConcreteHub"].ext_y(C.cham_opening(2 * GH, TOP, 14, 12, 3), GF, GB)
	outer = [(-8.6, 0), (-8.6, 9.66), (-4.66, 13.6), (4.66, 13.6), (8.6, 9.66), (8.6, 0)]
	inner = [(6.6, 0), (6.6, 8.83), (3.83, 11.6), (-3.83, 11.6), (-6.6, 8.83), (-6.6, 0)]
	K["Steel"].ext_y(outer + inner, GF - 0.8, GF + 1.2)
	for sx in (-1, 1):
		C.hazard(K, sx * 6.3, sx * 8.9, GF - 1.1, GF + 1.5, 0, 2.4)
		K["ConcreteDark"].box(sx * 9.5, sx * 12.1, GF - 1.0, GF, 1.3, 13.6)  # pilaster
		K["ConcreteDark"].box(sx * 9.2, sx * 12.4, GF - 1.35, GF, 0, 1.3)  # its plinth
		K["Steel"].box(sx * 10.45, sx * 11.15, GF - 1.12, GF - 1.0, 4.0, 10.6)  # slim lamp housing
		K["E_Duels"].box(sx * 10.62, sx * 10.98, GF - 1.17, GF - 1.12, 9.2, 10.4)  # signal lamp
	for y in (38.5, 43.5):  # recessed tunnel lights
		K["Steel"].box(-4.2, 4.2, y - 0.7, y + 0.7, 11.75, 12.0)
		K["E_Warm"].box(-3.8, 3.8, y - 0.4, y + 0.4, 11.68, 11.75)
	K["ConcreteDark"].box(-12.5, 12.5, GF - 1.4, GF, 13.6, 15.0)  # header on the pilasters and the frame
	threshold(K, 6.6)
	throat_floor(K, "FloorDark")


def gate_market(K):
	"""Round stone arch with a timber-ribbed vault."""
	K["ConcreteHub"].ext_y(C.arch_opening(2 * GH, TOP, 16, 6, 28), GF, GB)
	s = K["ConcreteLight"]
	s.band_y(0, 6, 8.0, 9.8, 0, pi, 13, GF - 0.7, GF)
	for sx in (-1, 1):
		s.box(sx * 8.0, sx * 9.8, GF - 0.7, GF, 1.2, 6.0)
		K["ConcreteDark"].box(sx * 7.8, sx * 10.2, GF - 1.0, GF, 0, 1.2)
		wall_lantern(K, sx * 11.9, 7.6)
	s.box(-1.1, 1.1, GF - 1.0, GF, 13.6, 15.95)  # keystone
	for y in (38.0, 42.0, 46.0):
		b = K["OakDark"]
		n = 14
		pts = [(7.4 * cos(pi * i / n), 6 + 7.4 * sin(pi * i / n)) for i in range(n + 1)]
		pts += [(8.0 * cos(pi - pi * i / n), 6 + 8.0 * sin(pi - pi * i / n)) for i in range(n + 1)]
		b.ext_y(pts, y - 0.5, y + 0.5)
		for sx in (-1, 1):
			b.box(sx * 7.4, sx * 8.0, y - 0.5, y + 0.5, 0, 6.0)
	threshold(K, 8.0)
	throat_floor(K, "FloorPale")


def gate_vault(K):
	"""Round vault mouth: steel collar, bolts, ribbed tube."""
	Rv, zc = 10.0, 7.5
	K["ConcreteHub"].ext_y(C.round_opening(2 * GH, TOP, Rv, zc, 48), GF, GB)
	foot = asin(-zc / Rv)
	t0, t1 = -(pi - foot), -foot  # lathe angles in the tilted frame
	tilt = Matrix.Translation((0, 0, zc)) @ Matrix.Rotation(D(-90), 4, "X")  # local z -> +y
	K["Brushed"].framem(tilt).lathe([(9.5, GF - 1.0), (12.6, GF - 1.0), (12.6, GF + 0.6), (9.5, GF + 0.6)], t0, t1, 72)
	K["Steel"].framem(tilt).lathe([(12.6, GF - 0.45), (13.3, GF - 0.45), (13.3, GF), (12.6, GF)], t0 + 0.12, t1 - 0.12, 72)
	for y in (38.5, 42.5, 46.5):
		K["Brushed"].framem(tilt).lathe([(9.45, y - 0.45), (10.2, y - 0.45), (10.2, y + 0.45), (9.45, y + 0.45)], t0, t1, 72)
	b = K["Steel"]
	for i in range(14):
		a = D(-25 + 230 * i / 13)
		if D(58) < a < D(122):
			continue  # the LOCKER letters sit here
		x, z = 11.05 * cos(a), zc + 11.05 * sin(a)
		b.reset().pipe((x, GF - 1.3, z), (x, GF - 0.9, z), 0.42, 8)
	for sx in (-1, 1):  # shoes where the collar meets the floor, so it reads as standing on it
		K["Steel"].box(sx * 6.2, sx * 10.4, GF - 1.35, GF + 0.9, 0, 1.1)
	K["Steel"].box(-6.2, 6.2, GF - 1.2, GF - 0.2, 0.0, 0.06)
	# two small status lamps, not a neon ring
	for sx in (-1, 1):
		K["Steel"].box(sx * 13.6, sx * 14.4, GF - 0.3, GF, 6.6, 8.4)
		K["E_Vault"].box(sx * 13.8, sx * 14.2, GF - 0.38, GF - 0.3, 6.9, 8.1)
	K["E_Warm"].framem(tilt).lathe([(9.9, 40.2), (10.02, 40.2), (10.02, 40.8), (9.9, 40.8)], D(-120), D(-60), 16)
	K["E_Warm"].framem(tilt).lathe([(9.9, 44.2), (10.02, 44.2), (10.02, 44.8), (9.9, 44.8)], D(-120), D(-60), 16)
	throat_floor(K, "Rubber")


def gate_range(K):
	"""Roll-up shutter gate with guide rails and hazard jambs."""
	K["ConcreteHub"].ext_y(C.cham_opening(2 * GH, TOP, 18, 12, 0), GF, GB)
	K["SteelBlue"].box(-10.6, 10.6, GF - 1.3, GF + 1.0, 11.86, 14.6)  # shutter housing
	for i in range(5):
		K["Brushed"].box(-8.8, 8.8, GF + 0.4, GF + 0.75, 9.4 + 0.5 * i, 9.83 + 0.5 * i)
	C.hazard(K, -8.8, 8.8, GF + 0.3, GF + 0.85, 8.95, 9.36)
	for sx in (-1, 1):
		K["Steel"].box(sx * 8.75, sx * 9.9, GF - 0.9, GF + 1.2, 0, 11.86)  # guide rail
		C.hazard(K, sx * 9.9, sx * 11.2, GF - 0.3, GF, 0, 8.0)
		K["Steel"].box(sx * 11.8, sx * 12.6, GF - 0.5, GF, 9.6, 11.4)
		K["E_Range"].box(sx * 12.0, sx * 12.4, GF - 0.58, GF - 0.5, 9.9, 11.1)
	for y in (39.0, 44.0):
		K["Steel"].box(-5.0, 5.0, y - 0.7, y + 0.7, 11.75, 12.0)
		K["E_Cool"].box(-4.6, 4.6, y - 0.4, y + 0.4, 11.68, 11.75)
	threshold(K, 9.0)
	throat_floor(K, "Rubber")


def guide_lines(K):
	"""Floor markings moved to lv3_props.hub (stencilled wing names)."""
	return


def wall_lantern(K, x, z):
	"""Six-sided lantern hung from a braced bracket on the gatehouse face (y = GF)."""
	yc = GF - 1.5
	st = K["Steel"]
	st.box(x - 0.34, x + 0.34, GF - 0.2, GF, z + 1.0, z + 2.6)  # wall plate
	st.pipe((x, GF - 0.1, z + 2.25), (x, yc - 0.1, z + 2.25), 0.09, 8)  # arm
	st.pipe((x, GF - 0.1, z + 1.25), (x, GF - 1.05, z + 2.2), 0.07, 8)  # brace
	st.pipe((x, yc, z + 2.3), (x, yc, z + 1.7), 0.06, 8)  # hanger
	b = K["Steel"].frame(0, x, yc, z)
	b.disc(0.66, 1.52, 1.78, n=6, r1=0.16)  # cap
	b.disc(0.7, 1.42, 1.52, n=6)
	b.disc(0.52, 0.0, 0.14, n=6, r1=0.62)  # base
	for k in range(6):
		a = D(60 * k)
		b.pipe((0.56 * cos(a), 0.56 * sin(a), 0.1), (0.62 * cos(a), 0.62 * sin(a), 1.46), 0.045, 6)
	K["E_Warm"].frame(0, x, yc, z).disc(0.47, 0.14, 1.42, n=6)


def build():
	C.clear("Hub")
	C.clear("Hub_Ceil")
	col, cc = C.coll("Hub", C.root()), C.coll("Hub_Ceil", C.root())
	K = C.Kit(col)
	floors(K)
	drum(K)
	piers(K)
	guide_lines(K)
	K.done()
	for name, fn in (("Duels", gate_duels), ("Market", gate_market), ("Vault", gate_vault), ("Range", gate_range)):
		G = C.Kit(col, ROT[name], prefix="Gate" + name)
		fn(G)
		G.done()
	KC = C.Kit(cc)
	ceiling(KC)
	KC.done()
	# sun down the light well, a touch off vertical so the pool sits forward of centre
	C.light(cc, "Sun", "SUN", (0, 0, 80), "#FFE9C8", 3.0, size=1.2, rot=(9, -5, 0))


def shell():
	"""Render-only bedrock so no sky leaks in anywhere but the light well."""
	C.clear("RenderShell")
	col = C.coll("RenderShell", C.root())
	K = C.Kit(col)
	b = K["Bedrock"]
	b.ring(25.0, 460.0, 62, 66, n=64)
	b.box(-330, 330, -330, 330, -44, -40)
	b.box(-330, -326, -330, 330, -40, 62)
	b.box(326, 330, -330, 330, -40, 62)
	b.box(-330, 330, -330, -326, -40, 62)
	b.box(-330, 330, 326, 330, -40, 62)
	K.done()
