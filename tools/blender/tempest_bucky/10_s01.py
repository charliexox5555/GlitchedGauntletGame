# Tempest-Strike Bucky s01: restyle the STOCK RemasterV2 Bucky v05 (pump shotgun, no ADS). Same rig, bones, locators
# and footprint. Save with tempest_line/30_sheet.py TAG s01.
import bpy
GUN = "Bucky"
bpy.ops.wm.open_mainfile(filepath=r"C:/Users/charl/Documents/GauntletGame/GlitchedGauntletGame/art-source/weapons/RemasterV2/Bucky/Bucky_RemasterV2_v05.blend")
exec(open(r"C:/Users/charl/Documents/GauntletGame/GlitchedGauntletGame/tools/blender/tempest_line/ts_lib.py").read())
palette()
BZ = 0.369      # bore
TZ = 0.216      # magazine tube / pump axis

def islands(bm):
	seen = set(); out = []
	for f in bm.faces:
		if f in seen:
			continue
		st = [f]; grp = []
		while st:
			a = st.pop()
			if a in seen:
				continue
			seen.add(a); grp.append(a)
			for e in a.edges:
				st += [g for g in e.link_faces if g not in seen]
		out.append(grp)
	return out

# ---------------- receiver: recessed blade plates (moving), hydro slots, top blade ----------------
rec = dup("Bucky_Receiver", "TS_Receiver")
mi = {m.name: i for i, m in enumerate(rec.data.materials)}
for p in rec.data.polygons:          # the stock two-tone silver upper panels become storm navy (blades carry the silver)
	if p.material_index == mi["Panel"]:
		p.material_index = mi["Body"]
finish(rec)
for m in list(rec.modifiers):
	if m.type == "WEIGHTED_NORMAL":
		rec.modifiers.remove(m)
BLADE = [(0.020, 0.196), (0.062, 0.166), (0.800, 0.166), (0.930, 0.199), (0.800, 0.227), (0.062, 0.227)]
for s in (1, -1):
	y0, y1 = (0.072, 0.095) if s > 0 else (-0.095, -0.072)
	boolean(rec, cutter("TS_CUT_Recess%+d" % s, prism_xz(poly_offset(BLADE, 0.003), y0, y1)))
	ys = (0.0755, 0.095) if s > 0 else (-0.095, -0.0755)
	boolean(rec, cutter("TS_CUT_Hydro%+d" % s, prism_xz([(0.100, 0.1495), (0.700, 0.1495), (0.716, 0.1535), (0.100, 0.1535)], *ys), "Neon"))
	y0, y1 = (0.0715, 0.0815) if s > 0 else (-0.0815, -0.0715)
	new_obj("TS_Plate%+d" % s, chamfer_prism_xz(BLADE, y0, y1, 0.0016), "Panel", bevel=0)
add_mat(rec, "Dark"); add_mat(rec, "Neon")
replaced("Bucky_Neon")
new_obj("TS_TopBlade", prism_xy([(0.420, -0.018), (0.860, -0.018), (0.940, 0.0), (0.860, 0.018), (0.420, 0.018), (0.400, 0.0)], 0.4175, 0.4225), "Panel", bevel=0)
# side-saddle shell carrier (left): silver plate, clip band, four brass-capped shells
new_obj("TS_CarrierPlate", chamfer_prism_xz([(0.122, 0.262), (0.420, 0.262), (0.452, 0.318), (0.420, 0.392), (0.122, 0.392), (0.110, 0.327)], 0.0715, 0.0790, 0.0015), "Panel", bevel=0)
for i in range(4):
	x = 0.170 + i * 0.076
	new_obj("TS_CarrierShell%d" % i, prism_xy(ngon(0.019, 8, x, 0.0975, math.pi / 8), 0.270, 0.372), "Accent")
	new_obj("TS_CarrierCap%d" % i, prism_xy(ngon(0.0205, 8, x, 0.0975, math.pi / 8), 0.372, 0.386), "Brass")
new_obj("TS_CarrierClip", chamfer_prism_xz([(0.130, 0.300), (0.414, 0.300), (0.414, 0.330), (0.130, 0.330)], 0.0780, 0.1235, 0.002), "Dark", bevel=0)
bolt = dup("Bucky_Bolt", "TS_Bolt")
pi = list(bolt.data.materials).index(M("Panel"))
for p in bolt.data.polygons:
	p.material_index = pi
pins = dup("Bucky_Pins", "TS_Pins")

# ---------------- crescent sight (cosmetic: the Bucky has no ADS) ----------------
replaced("Bucky_Sights")
new_obj("TS_Sight_RearBase", chamfer_prism_xz([(0.296, 0.414), (0.366, 0.414), (0.356, 0.432), (0.306, 0.432)], -0.032, 0.032, 0.004), "Body", bevel=0)
crescent_sight("TS", 0.331, 0.468, ro=0.048, ri=0.0415, off=0.0035, gap=36, depth=0.016)

# ---------------- barrel, tube, bands, wide pointed brake ----------------
replaced("Bucky_Barrel")
FL = {0: [(0.5, 0.013, 0.005)], 4: [(0.5, 0.013, 0.005)]}
rings = []
for i, x in enumerate((0.950, 1.100, 1.120, 2.420, 2.440, 2.600)):
	d = 1.0 if i in (2, 3) else 0.0
	rings.append(ring_x(x, fluted(octo(0.050, 0.050, 0.16, cz=BZ), {k: [(t, w, dd * d) for t, w, dd in v] for k, v in FL.items()})))
new_obj("TS_Barrel", loft(rings), "Metal", bevel=0)
new_obj("TS_Tube", loft([ring_x(0.950, octo(0.052, 0.052, 0.16, cz=TZ)), ring_x(2.700, octo(0.052, 0.052, 0.16, cz=TZ))]), "Body", bevel=0)
new_obj("TS_TubeCap", loft([ring_x(2.690, octo(0.056, 0.056, 0.16, cz=TZ)), ring_x(2.730, octo(0.056, 0.056, 0.16, cz=TZ)),
	ring_x(2.762, octo(0.024, 0.024, 0.16, cz=TZ - 0.010))]), "Metal")
def band_sec(hw, top, bot, k=0.024):
	return [(hw, bot + k), (hw, top - k), (hw - k, top), (-hw + k, top), (-hw, top - k), (-hw, bot + k), (-hw + k, bot), (hw - k, bot)]
new_obj("TS_Band", loft([ring_x(2.440, band_sec(0.056, 0.426, 0.158)), ring_x(2.452, band_sec(0.064, 0.434, 0.150)),
	ring_x(2.536, band_sec(0.064, 0.434, 0.150)), ring_x(2.548, band_sec(0.056, 0.426, 0.158))]), "Panel")
new_obj("TS_BandSeam", loft([ring_x(2.491, band_sec(0.0652, 0.4352, 0.1488)), ring_x(2.497, band_sec(0.0652, 0.4352, 0.1488))]), "Neon", bevel=0)
new_obj("TS_BrakeBand", loft([ring_x(2.594, octo(0.0695, 0.0645, 0.14, cz=BZ)), ring_x(2.610, octo(0.0695, 0.0645, 0.14, cz=BZ))]), "Panel")
brake = new_obj("TS_Brake", loft([ring_x(2.604, octo(0.067, 0.062, 0.14, cz=BZ)), ring_x(2.814, octo(0.067, 0.062, 0.14, cz=BZ)),
	ring_x(2.832, octo(0.062, 0.057, 0.14, cz=BZ))]), "Body")
for i in range(3):
	x = 2.640 + i * 0.054
	boolean(brake, cutter("TS_CUT_Port%d" % i, prism_xz([(x - 0.012, BZ - 0.034), (x + 0.004, BZ - 0.034), (x + 0.018, BZ + 0.034), (x + 0.002, BZ + 0.034)], -0.2, 0.2)))
	boolean(brake, cutter("TS_CUT_Top%d" % i, prism_xz([(x - 0.005, BZ + 0.03), (x + 0.007, BZ + 0.03), (x + 0.007, BZ + 0.09), (x - 0.005, BZ + 0.09)], -0.020, 0.020)))
for s in (1, -1):
	c = cutter("TS_CUT_Fang%+d" % s, prism_xz([(2.795, BZ - 0.12), (2.88, BZ - 0.12), (2.88, BZ + 0.12), (2.795, BZ + 0.12)], -0.02, 0.02))
	c.matrix_world = Matrix.Translation((0, s * 0.067, 0)) @ Matrix.Translation((2.832, 0, 0)) @ Matrix.Rotation(math.radians(45), 4, "Z") @ Matrix.Translation((-2.832, 0, 0))
	boolean(brake, c)
star = []
for i in range(8):
	a = math.radians(90 + i * 45); r = 0.040 if i % 2 == 0 else 0.012
	star.append((r * math.cos(a), BZ + r * math.sin(a)))
boolean(brake, cutter("TS_CUT_Star", prism_yz(star, 2.824, 2.90)))
add_mat(brake, "Dark")
new_obj("TS_BrakeCore", loft([ring_x(2.612, octo(0.046, 0.046, 0.3, cz=BZ)), ring_x(2.810, octo(0.046, 0.046, 0.3, cz=BZ))]), "Metal", bevel=0)
new_obj("TS_BrakeStar", prism_yz([(y * 0.9, BZ + (z - BZ) * 0.9) for y, z in star], 2.8235, 2.8255), "Neon", bevel=0)
post = [(2.640, 0.430), (2.700, 0.430), (2.690, 0.442), (2.676, 0.470), (2.672, 0.477), (2.666, 0.477), (2.660, 0.460), (2.648, 0.442)]
new_obj("TS_Sight_FrontPost", prism_xz(post, -0.006, 0.006), "Body")

# ---------------- pump: fluted core, leather bands, silver end caps (Pump bone) ----------------
rails = dup("Bucky_Pump", "TS_PumpRails")
bm, _ = stock_bm(rails.name)
bmesh.ops.delete(bm, geom=[f for g in islands(bm) if max(v.co.x for f in g for v in f.verts) > 1.3 for f in g], context="FACES")
write_bm(rails, bm)
def pump_sec(x, grow=0.0):
	return sec_grow(octo(0.080, 0.108, 0.16, cz=0.2055), grow)
PF = {0: [(0.30, 0.012, 0.005), (0.70, 0.012, 0.005)], 4: [(0.30, 0.012, 0.005), (0.70, 0.012, 0.005)]}
rings = []
for i, x in enumerate((1.236, 1.270, 1.285, 2.040, 2.055, 2.094)):
	d = 1.0 if i in (2, 3) else 0.0
	rings.append(ring_x(x, fluted(pump_sec(x), {k: [(t, w, dd * d) for t, w, dd in v] for k, v in PF.items()})))
rings.append(ring_x(2.126, fluted(octo(0.060, 0.086, 0.16, cz=0.2055), {k: [(t, w, 0.0) for t, w, dd in v] for k, v in PF.items()})))
new_obj("TS_PumpCore", loft(rings), "Body", like="Bucky_Pump", bevel=0)
for i, x0 in enumerate((1.330, 1.505, 1.680, 1.855)):
	new_obj("TS_PumpWrap%d" % i, loft([ring_tilt_x(pump_sec, x0, 0.30, 0.0036, 0.2055), ring_tilt_x(pump_sec, x0 + 0.110, 0.30, 0.0054, 0.2055)]), "Grip", like="Bucky_Pump", bevel=0)
for nm, x0, x1 in (("TS_PumpCapRear", 1.236, 1.258), ("TS_PumpCapFront", 2.070, 2.094)):
	new_obj(nm, loft([ring_x(x0, pump_sec(0, 0.0024)), ring_x(x1, pump_sec(0, 0.0024))]), "Panel", like="Bucky_Pump", bevel=0)
replaced("Bucky_Pump")

# ---------------- grip: faceted shell, leather bands, conduits, silver pommel cap ----------------
replaced("Bucky_Grip")
GS = [(-0.262, 0.044, -0.200, 0.058), (-0.200, 0.060, -0.213, 0.062), (0.000, 0.132, -0.134, 0.062), (0.060, 0.140, -0.110, 0.062),
	(0.140, 0.124, -0.072, 0.056), (0.170, 0.118, -0.064, 0.054)]
def gs_at(z):
	if z <= GS[0][0]:
		return GS[0][1:]
	for a, b in zip(GS[:-1], GS[1:]):
		if a[0] <= z <= b[0]:
			t = (z - a[0]) / (b[0] - a[0])
			return tuple(a[i] + (b[i] - a[i]) * t for i in (1, 2, 3))
	return GS[-1][1:]
def grip_sec(z, grow=0.0):
	fx, bx, hw = gs_at(z)
	return sec_grow([(fx, -hw * 0.34), (fx, hw * 0.34), (fx - 0.034, hw), (bx + 0.026, hw), (bx, hw * 0.58), (bx, -hw * 0.58), (bx + 0.026, -hw), (fx - 0.034, -hw)], grow)
def ring_z(secf, z0, tilt=0.0, grow=0.0):
	n = len(secf(z0)); out = []
	for i in range(n):
		z = z0
		for _ in range(3):
			x = secf(z, grow)[i][0]; z = z0 + tilt * x
		x, y = secf(z, grow)[i]
		out.append((x, y, z))
	return out
new_obj("TS_GripCore", loft([ring_z(grip_sec, z) for z, *_ in GS]), "Body", like="Bucky_Grip")
for i, z0 in enumerate((0.070, 0.002, -0.066, -0.134)):
	z1 = z0 - 0.052
	new_obj("TS_GripWrap%d" % i, loft([ring_z(grip_sec, z1, 0.22, 0.0040), ring_z(grip_sec, z0, 0.22, 0.0058)]), "Grip", like="Bucky_Grip", bevel=0)
	if i < 3:
		new_obj("TS_GripHydro%d" % i, loft([ring_z(grip_sec, z1 - 0.0105, 0.22, 0.0018), ring_z(grip_sec, z1 - 0.0055, 0.22, 0.0018)]), "Neon", like="Bucky_Grip", bevel=0)
cap0 = [(x, y, -0.252) for x, y in grip_sec(-0.252, 0.0030)]
cap1 = [(x, y, -0.282) for x, y in grip_sec(-0.262, 0.0010)]
_c = grip_sec(-0.262, 0.0); _cx = sum(p[0] for p in _c) / len(_c)
cap2 = [(_cx + (x - _cx) * 0.85 - (0.022 if x < _cx - 0.06 else 0.0), y * 0.74, -0.300) for x, y in _c]
new_obj("TS_GripCap", loft([cap0, cap1, cap2]), "Panel", like="Bucky_Grip")

# ---------------- skeletal stock: yoke + hinge, faceted bars, butt with pointed toe ----------------
replaced("Bucky_Stock")
YOKE = [(-0.080, 0.392), (-0.250, 0.384), (-0.322, 0.352), (-0.232, 0.322), (-0.212, 0.270), (-0.236, 0.216), (-0.318, 0.170),
	(-0.350, 0.122), (-0.080, 0.150)]
bm = prism_xz(YOKE, -0.072, 0.072)
for v in bm.verts:
	f = max(0.0, min(1.0, (-v.co.x - 0.10) / 0.25)); v.co.y *= 1.0 - 0.40 * f
new_obj("TS_StockYoke", bm, "Body", like="Bucky_Stock")
for s in (1, -1):
	surface_plate("TS_StockYoke", "TS_YokePlate%+d" % s, [(-0.100, 0.382), (-0.250, 0.376), (-0.290, 0.356), (-0.240, 0.344), (-0.100, 0.346)], s, lift=0.0006, thick=0.004)
new_obj("TS_StockHinge", prism_xz(ngon(0.022, 8, -0.160, 0.262, math.pi / 8), -0.080, 0.080), "Metal", like="Bucky_Stock")
TB0, TB1 = (-0.280, 0.356), (-0.900, 0.316)
new_obj("TS_StockTopBar", bar(TB0, TB1, 0.030, 0.024), "Body", like="Bucky_Stock")
new_obj("TS_StockStrut", bar((-0.300, 0.172), (-0.892, -0.250), 0.028, 0.021), "Body", like="Bucky_Stock")
butt = [(-0.951, 0.345), (-0.880, 0.345), (-0.858, 0.322), (-0.861, 0.262), (-0.874, -0.176), (-0.832, -0.292), (-0.951, -0.288)]
new_obj("TS_StockButt", chamfer_prism_xz(butt, -0.060, 0.060, 0.005), "Body", like="Bucky_Stock", bevel=0)
new_obj("TS_StockPad", prism_xz([(-0.966, 0.334), (-0.949, 0.334), (-0.949, -0.280), (-0.966, -0.274)], -0.055, 0.055), "Dark", like="Bucky_Stock")
for s in (1, -1):
	bp = [(-0.943, 0.336), (-0.888, 0.336), (-0.870, 0.318), (-0.884, -0.172), (-0.848, -0.280), (-0.943, -0.276)]
	y0 = s * 0.0590
	new_obj("TS_ButtPlate%+d" % s, chamfer_prism_xz(bp, min(y0, y0 + s * 0.0045), max(y0, y0 + s * 0.0045), 0.0012), "Panel", like="Bucky_Stock", bevel=0)
a, b = Vector((TB0[0], 0, TB0[1])), Vector((TB1[0], 0, TB1[1])); t = (b - a).normalized(); n = Vector((-t.z, 0, t.x))
if n.z < 0:
	n = -n
tp = lambda u, h: a + t * u + n * h
L = (b - a).length
pts = [tp(0.06, 0.021), tp(L - 0.08, 0.021), tp(L - 0.04, 0.023), tp(L - 0.08, 0.0285), tp(0.06, 0.0285)]
new_obj("TS_StockTopBlade", prism_xz([(p.x, p.z) for p in pts], -0.015, 0.015), "Panel", like="Bucky_Stock", bevel=0)
c = tp(L - 0.17, 0.0)
new_obj("TS_StockHub", loft([ring_x(c.x + dx, octo(0.040, 0.034, 0.3, cz=c.z)) for dx in (0.012, 0.0, -0.016, -0.028)]), "Panel", like="Bucky_Stock")
new_obj("TS_StockHubLine", loft([ring_x(c.x - 0.006, octo(0.0412, 0.0352, 0.3, cz=c.z)), ring_x(c.x - 0.0085, octo(0.0412, 0.0352, 0.3, cz=c.z))]), "Neon", like="Bucky_Stock", bevel=0)

bpy.context.view_layer.update()
result = {"tris": tris(visible_model()), "parts": len(visible_model())}
