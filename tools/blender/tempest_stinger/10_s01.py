# Tempest-Strike Stinger s01: restyle the STOCK RemasterV2 Stinger v05 (same rig, bones, locators, footprint).
# Opens the stock file fresh every run (stock file never saved), builds the Tempest parts, hides replaced stock
# parts (flag ts_replaced). Save with tempest_line/30_sheet.py (TAG s01).
import bpy
GUN = "Stinger"
bpy.ops.wm.open_mainfile(filepath=r"C:/Users/charl/Documents/GauntletGame/GlitchedGauntletGame/art-source/weapons/RemasterV2/Stinger/Stinger_RemasterV2_v05.blend")
exec(open(r"C:/Users/charl/Documents/GauntletGame/GlitchedGauntletGame/tools/blender/tempest_line/ts_lib.py").read())
palette()
BORE = 0.294
AIM = bpy.data.objects["Stinger_AimPoint"].matrix_world.translation.copy()   # (-0.408, 0, 0.4778)

# ---------------- receiver: stock body without its nose block ----------------
rec = dup("Stinger_Receiver", "TS_Receiver")
bm, _ = stock_bm(rec.name)
seen = set(); kill_f = []
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
	if min(v.co.x for g in grp for v in g.verts) > 0.775:
		kill_f += grp
bmesh.ops.delete(bm, geom=kill_f, context="FACES")
write_bm(rec, bm)
finish(rec, smooth=False)
for m in list(rec.modifiers):
	if m.type == "WEIGHTED_NORMAL":
		rec.modifiers.remove(m)

# blade recesses (dark floor) + hydro conduit slots, both sides
BLADE = [(-0.468, 0.252), (-0.420, 0.232), (0.440, 0.232), (0.762, 0.258), (0.700, 0.272), (-0.420, 0.272)]
FIN = [(-0.300, 0.286), (0.060, 0.286), (0.118, 0.296), (0.060, 0.303), (-0.282, 0.303)]
for s in (1, -1):
	y0, y1 = (0.074, 0.095) if s > 0 else (-0.095, -0.074)
	boolean(rec, cutter("TS_CUT_Recess%+d" % s, prism_xz(poly_offset(BLADE, 0.003), y0, y1)))
	ys = (0.0765, 0.095) if s > 0 else (-0.095, -0.0765)
	boolean(rec, cutter("TS_CUT_Hydro%+d" % s, prism_xz([(-0.400, 0.2115), (0.380, 0.2115), (0.395, 0.2155), (-0.400, 0.2155)], *ys), "Neon"))
boolean(rec, cutter("TS_CUT_FinRecess+1", prism_xz(poly_offset(FIN, 0.0025), 0.0745, 0.095)))
add_mat(rec, "Dark"); add_mat(rec, "Neon")

# receiver blade plates (moving vents later) + left upper fin, seated in the recesses (0.0035 proud)
for s in (1, -1):
	y0, y1 = (0.0735, 0.0835) if s > 0 else (-0.0835, -0.0735)
	new_obj("TS_VentBlade%+d" % s, chamfer_prism_xz(BLADE, y0, y1, 0.0015), "Panel", bevel=0)
new_obj("TS_SideFin+1", chamfer_prism_xz(FIN, 0.0740, 0.0830, 0.0012), "Panel", bevel=0)
replaced("Stinger_Neon")
# top blade on the rib, pointing forward
new_obj("TS_TopBlade", prism_xy([(-0.340, -0.016), (0.430, -0.016), (0.520, 0.0), (0.430, 0.016), (-0.340, 0.016), (-0.362, 0.0)], 0.4275, 0.4325), "Panel", bevel=0)

# ---------------- nose: raked taper from the receiver into the barrel collar ----------------
def kee(x, hw, top, side_hi, side_lo, bot, ktop=0.70, kbot=0.60):
	return ring_x(x, [(hw, side_lo), (hw, side_hi), (hw * ktop, top), (-hw * ktop, top), (-hw, side_hi), (-hw, side_lo),
		(-hw * kbot, bot), (hw * kbot, bot)])
new_obj("TS_Nose", loft([kee(0.770, 0.072, 0.405, 0.392, 0.205, 0.190), kee(0.860, 0.068, 0.405, 0.392, 0.215, 0.204),
	kee(0.885, 0.064, 0.399, 0.386, 0.232, 0.222), kee(0.916, 0.054, 0.352, 0.340, 0.252, 0.244)]), "Body")
new_obj("TS_NoseBand", loft([kee(0.8635, 0.0688, 0.4055, 0.3925, 0.2155, 0.2045), kee(0.8735, 0.0675, 0.4040, 0.3905, 0.2215, 0.2105)]), "Panel", bevel=0)

# ---------------- barrel: collar, short fluted shroud, ported brake with a pointed crown ----------------
replaced("Stinger_Barrel")
new_obj("TS_Collar", loft([ring_x(0.904, octo(0.050, 0.050, 0.16, cz=BORE)), ring_x(0.936, octo(0.050, 0.050, 0.16, cz=BORE))]), "Metal")
FL = {0: [(0.5, 0.010, 0.004)], 2: [(0.5, 0.010, 0.004)], 4: [(0.5, 0.010, 0.004)], 6: [(0.5, 0.010, 0.0035)]}
rings = []
for i, x in enumerate((0.930, 0.944, 1.030, 1.044)):
	d = 0.0 if i in (0, 3) else 1.0
	rings.append(ring_x(x, fluted(octo(0.044, 0.044, 0.16, cz=BORE), {k: [(t, w, dd * d) for t, w, dd in v] for k, v in FL.items()})))
new_obj("TS_Shroud", loft(rings), "Body", bevel=0)
new_obj("TS_BrakeBand", loft([ring_x(1.040, octo(0.0495, 0.0515, 0.14, cz=BORE)), ring_x(1.054, octo(0.0495, 0.0515, 0.14, cz=BORE))]), "Panel")
brake = new_obj("TS_Brake", loft([ring_x(1.050, octo(0.047, 0.049, 0.14, cz=BORE)), ring_x(1.128, octo(0.047, 0.049, 0.14, cz=BORE)),
	ring_x(1.142, octo(0.043, 0.045, 0.14, cz=BORE))]), "Body")
for i in range(2):
	x = 1.072 + i * 0.030
	boolean(brake, cutter("TS_CUT_Port%d" % i, prism_xz([(x - 0.008, BORE - 0.026), (x + 0.003, BORE - 0.026), (x + 0.012, BORE + 0.026), (x + 0.001, BORE + 0.026)], -0.2, 0.2)))
	boolean(brake, cutter("TS_CUT_Top%d" % i, prism_xz([(x - 0.004, BORE + 0.02), (x + 0.004, BORE + 0.02), (x + 0.004, BORE + 0.08), (x - 0.004, BORE + 0.08)], -0.016, 0.016)))
for s in (1, -1):   # fang cuts: the crown comes to points at top and bottom
	c = cutter("TS_CUT_Fang%+d" % s, prism_xz([(1.118, BORE - 0.1), (1.18, BORE - 0.1), (1.18, BORE + 0.1), (1.118, BORE + 0.1)], -0.016, 0.016))
	c.matrix_world = Matrix.Translation((0, s * 0.047, 0)) @ Matrix.Translation((1.142, 0, 0)) @ Matrix.Rotation(math.radians(45), 4, "Z") @ Matrix.Translation((-1.142, 0, 0))
	boolean(brake, c)
star = []
for i in range(8):
	a = math.radians(90 + i * 45); r = 0.026 if i % 2 == 0 else 0.008
	star.append((r * math.cos(a), BORE + r * math.sin(a)))
boolean(brake, cutter("TS_CUT_Star", prism_yz(star, 1.134, 1.20)))
add_mat(brake, "Dark")
new_obj("TS_BrakeCore", loft([ring_x(1.056, octo(0.030, 0.030, 0.3, cz=BORE)), ring_x(1.126, octo(0.030, 0.030, 0.3, cz=BORE))]), "Metal", bevel=0)
new_obj("TS_BrakeStar", prism_yz([(y * 0.9, BORE + (z - BORE) * 0.9) for y, z in star], 1.1335, 1.1355), "Neon", bevel=0)

# ---------------- handguard: keeled lower shroud, raked blade chin, vents, low silver blade ----------------
replaced("Stinger_Handguard")
hg = new_obj("TS_Handguard", loft([kee(0.452, 0.086, 0.222, 0.218, 0.150, 0.118, 0.97, 0.62), kee(0.470, 0.086, 0.222, 0.218, 0.150, 0.118, 0.97, 0.62),
	kee(0.760, 0.086, 0.222, 0.218, 0.142, 0.105, 0.97, 0.60), kee(0.840, 0.074, 0.222, 0.218, 0.175, 0.160, 0.97, 0.60),
	kee(0.880, 0.056, 0.224, 0.220, 0.208, 0.202, 0.97, 0.70)]), "Body", like="Stinger_Handguard")
for s in (1, -1):
	for i in range(3):
		x = 0.560 + i * 0.050
		c = cutter("TS_CUT_Vent%d%+d" % (i, s), prism_xz([(x - 0.012, 0.182), (x + 0.002, 0.182), (x + 0.014, 0.210), (x, 0.210)], 0, 0.03))
		c.matrix_world = Matrix.Translation((0, 0.072 if s > 0 else -0.102, 0))
		boolean(hg, c)
add_mat(hg, "Dark")
for s in (1, -1):
	surface_plate("TS_Handguard", "TS_GuardBlade%+d" % s, [(0.468, 0.170), (0.490, 0.152), (0.735, 0.152), (0.800, 0.163), (0.735, 0.174), (0.490, 0.174)],
		s, lift=0.0006, thick=0.004)
pins = dup("Stinger_Pins", "TS_Pins")
bm, _ = stock_bm(pins.name)
bmesh.ops.delete(bm, geom=[v for v in bm.verts if v.co.x > 0.45], context="VERTS")
write_bm(pins, bm)

# ---------------- sights: crescent rear on the AimPoint, swept blade post front ----------------
replaced("Stinger_Sights")
base = [(-0.436, 0.424), (-0.380, 0.424), (-0.388, 0.441), (-0.428, 0.441)]
new_obj("TS_Sight_RearBase", chamfer_prism_xz(base, -0.034, 0.034, 0.004), "Body", bevel=0)
crescent_sight("TS", AIM.x, AIM.z, ro=0.062, ri=0.0545, off=0.0045, gap=36, depth=0.016)
new_obj("TS_Sight_FrontBase", chamfer_prism_xz([(0.800, 0.400), (0.880, 0.400), (0.872, 0.414), (0.808, 0.414)], -0.030, 0.030, 0.004), "Body", bevel=0)
new_obj("TS_Sight_FrontBand", prism_xz([(0.818, 0.4135), (0.826, 0.4135), (0.826, 0.4165), (0.818, 0.4165)], -0.026, 0.026), "Panel", bevel=0)
post = [(0.812, 0.412), (0.866, 0.412), (0.852, 0.428), (0.842, 0.468), (0.838, 0.4778), (0.833, 0.4778), (0.828, 0.462), (0.820, 0.428)]
new_obj("TS_Sight_FrontPost", prism_xz(post, -0.0065, 0.0065), "Body")
new_obj("TS_Sight_FrontDot", prism_xz([(0.8335, 0.4655), (0.8395, 0.4655), (0.8395, 0.4715), (0.8335, 0.4715)], -0.0075, 0.0075), "Neon", bevel=0)

# ---------------- grip: faceted shell in the stock hand envelope, leather bands, cyan conduits ----------------
replaced("Stinger_Grip")
GS = [(-0.204, 0.052, -0.146, 0.055), (-0.180, 0.066, -0.159, 0.062), (-0.020, 0.104, -0.126, 0.062), (0.020, 0.133, -0.117, 0.062),
	(0.140, 0.132, -0.078, 0.060), (0.175, 0.128, -0.070, 0.056)]
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
	pts = [(fx, -hw * 0.34), (fx, hw * 0.34), (fx - 0.034, hw), (bx + 0.026, hw), (bx, hw * 0.58), (bx, -hw * 0.58), (bx + 0.026, -hw), (fx - 0.034, -hw)]
	return poly_offset(pts, grow) if grow else pts
def ring_z(secf, z0, tilt=0.0, grow=0.0, xc=0.0):
	n = len(secf(z0)); out = []
	for i in range(n):
		z = z0
		for _ in range(3):
			x = secf(z, grow)[i][0]; z = z0 + tilt * (x - xc)
		x, y = secf(z, grow)[i]
		out.append((x, y, z))
	return out
new_obj("TS_GripCore", loft([ring_z(grip_sec, z) for z, *_ in GS]), "Body", like="Stinger_Grip")
TILT = 0.22
for i, z0 in enumerate((0.080, 0.012, -0.056, -0.124)):
	z1 = z0 - 0.052
	new_obj("TS_GripWrap%d" % i, loft([ring_z(grip_sec, z1, TILT, 0.0040), ring_z(grip_sec, z0, TILT, 0.0058)]), "Grip", like="Stinger_Grip", bevel=0)
	if i < 3:
		new_obj("TS_GripHydro%d" % i, loft([ring_z(grip_sec, z1 - 0.0105, TILT, 0.0016), ring_z(grip_sec, z1 - 0.0055, TILT, 0.0016)]), "Neon", like="Stinger_Grip", bevel=0)
# angular blade trigger guard with a forward spur (bars buried in grip and receiver)
new_obj("TS_GuardBottom", bar((0.100, 0.028), (0.318, 0.018), 0.016, 0.011, 0.6), "Body", like="Stinger_Grip")
new_obj("TS_GuardFront", bar((0.300, 0.010), (0.352, 0.168), 0.016, 0.011, 0.6), "Body", like="Stinger_Grip")
new_obj("TS_GuardPlate", prism_xz([(0.130, 0.0115), (0.300, 0.0035), (0.334, 0.008), (0.300, 0.0095), (0.130, 0.0165)], -0.0175, 0.0175), "Panel", like="Stinger_Grip", bevel=0)

# ---------------- magazine: leather bands + conduits on the exposed body, hydro ring over the baseplate ----------------
def mag_sec(z, grow=0.0):
	f = 0.0535 + 0.0456 * (z + 0.02); b = -0.1211 + 0.1103 * (z + 0.02); hw = 0.050; c = 0.007
	pts = [(f, -hw + c), (f, hw - c), (f - c, hw), (b + c, hw), (b, hw - c), (b, -hw + c), (b + c, -hw), (f - c, -hw)]
	return poly_offset(pts, grow) if grow else pts
for i, z0 in enumerate((-0.226, -0.296, -0.366)):
	z1 = z0 - 0.056
	new_obj("TS_MagWrap%d" % i, loft([ring_z(mag_sec, z1, -TILT, 0.0035), ring_z(mag_sec, z0, -TILT, 0.0052)]), "Grip", like="Stinger_Mag", bevel=0)
	new_obj("TS_MagHydro%d" % i, loft([ring_z(mag_sec, z1 - 0.0095, -TILT, 0.0014), ring_z(mag_sec, z1 - 0.0045, -TILT, 0.0014)]), "Neon", like="Stinger_Mag", bevel=0)

# ---------------- action: kunai charging knob on a steel slider, silver bolt with a hydro line ----------------
replaced("Stinger_ChargingHandle")
new_obj("TS_ChargeSlider", prism_xz([(0.150, 0.318), (0.258, 0.318), (0.266, 0.337), (0.258, 0.356), (0.150, 0.356), (0.142, 0.337)], 0.066, 0.080), "Metal", like="Stinger_ChargingHandle")
kc = Vector((0.205, 0, 0.337))
def dia(y, rx, rz, dx=0.0):
	return [(kc.x + dx + rx, y, kc.z), (kc.x + dx, y, kc.z + rz), (kc.x + dx - rx, y, kc.z), (kc.x + dx, y, kc.z - rz)]
new_obj("TS_ChargeKnob", loft([dia(0.078, 0.040, 0.016), dia(0.094, 0.044, 0.014, 0.004), dia(0.112, 0.010, 0.004, 0.022)]), "Panel", like="Stinger_ChargingHandle", bevel=0)
bolt = dup("Stinger_Bolt", "TS_Bolt")
pi = list(bolt.data.materials).index(M("Panel"))
for p in bolt.data.polygons:
	p.material_index = pi
new_obj("TS_BoltHydro", prism_xz([(-0.060, 0.2885), (0.120, 0.2885), (0.120, 0.2915), (-0.060, 0.2915)], -0.0772, -0.0755), "Neon", like="Stinger_Bolt", bevel=0)

# ---------------- skeletal folding stock: yoke + hinge, faceted bars, thin butt with a pointed toe ----------------
replaced("Stinger_Stock")
YOKE = [(-0.490, 0.382), (-0.640, 0.374), (-0.708, 0.344), (-0.612, 0.322), (-0.592, 0.288), (-0.610, 0.248), (-0.700, 0.208),
	(-0.728, 0.164), (-0.490, 0.170)]
bm = prism_xz(YOKE, -0.066, 0.066)
for v in bm.verts:
	f = max(0.0, min(1.0, (-v.co.x - 0.50) / 0.23)); v.co.y *= 1.0 - 0.42 * f
new_obj("TS_StockYoke", bm, "Body", like="Stinger_Stock")
for s in (1, -1):
	surface_plate("TS_StockYoke", "TS_YokePlate%+d" % s, [(-0.508, 0.374), (-0.640, 0.368), (-0.676, 0.350), (-0.630, 0.340), (-0.508, 0.342)], s, lift=0.0006, thick=0.004)
new_obj("TS_StockHinge", prism_xz([(x, z) for x, z in ngon(0.020, 8, -0.548, 0.252, math.pi / 8)], -0.074, 0.074), "Metal", like="Stinger_Stock")
new_obj("TS_StockTopBar", bar((-0.660, 0.352), (-1.470, 0.270), 0.024, 0.020), "Body", like="Stinger_Stock")
new_obj("TS_StockStrut", bar((-0.660, 0.204), (-1.460, -0.028), 0.022, 0.018), "Body", like="Stinger_Stock")
butt = [(-1.530, 0.302), (-1.462, 0.302), (-1.440, 0.284), (-1.443, 0.226), (-1.456, -0.010), (-1.410, -0.104), (-1.530, -0.096)]
new_obj("TS_StockButt", chamfer_prism_xz(butt, -0.050, 0.050, 0.004), "Body", like="Stinger_Stock", bevel=0)
new_obj("TS_StockPad", prism_xz([(-1.543, 0.292), (-1.528, 0.292), (-1.528, -0.090), (-1.543, -0.086)], -0.045, 0.045), "Dark", like="Stinger_Stock")
for s in (1, -1):
	bp = [(-1.522, 0.294), (-1.470, 0.294), (-1.452, 0.278), (-1.464, -0.006), (-1.428, -0.094), (-1.522, -0.088)]
	y0 = s * 0.0490
	new_obj("TS_ButtPlate%+d" % s, chamfer_prism_xz(bp, min(y0, y0 + s * 0.0045), max(y0, y0 + s * 0.0045), 0.0012), "Panel", like="Stinger_Stock", bevel=0)
# silver blade riding the top bar
a, b = Vector((-0.660, 0, 0.352)), Vector((-1.470, 0, 0.270)); t = (b - a).normalized(); n = Vector((-t.z, 0, t.x))
if n.z < 0:
	n = -n
def tp(u, h):
	return a + t * u + n * h
L = (b - a).length
pts = [tp(0.06, 0.017), tp(L - 0.08, 0.017), tp(L - 0.04, 0.019), tp(L - 0.08, 0.0245), tp(0.06, 0.0245)]
new_obj("TS_StockTopBlade", prism_xz([(p.x, p.z) for p in pts], -0.0125, 0.0125), "Panel", like="Stinger_Stock", bevel=0)
c = tp(L - 0.20, 0.0)
new_obj("TS_StockHub", loft([ring_x(c.x + dx, octo(0.034, 0.030, 0.3, cz=c.z)) for dx in (0.012, 0.0, -0.016, -0.028)]), "Panel", like="Stinger_Stock")
new_obj("TS_StockHubLine", loft([ring_x(c.x - 0.006, octo(0.0352, 0.0312, 0.3, cz=c.z)), ring_x(c.x - 0.0085, octo(0.0352, 0.0312, 0.3, cz=c.z))]), "Neon", like="Stinger_Stock", bevel=0)

bpy.context.view_layer.update()
result = {"tris": tris(visible_model()), "parts": len(visible_model()), "ts": sorted(o.name for o in TS.objects)}
