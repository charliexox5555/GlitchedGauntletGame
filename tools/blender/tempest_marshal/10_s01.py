# Tempest-Strike Marshal s01: restyle the STOCK RemasterV2 Marshal v05 (lever-action scoped sniper). Same rig,
# bones, locators and footprint; the scope lens objects stay untouched. Save with tempest_line/30_sheet.py TAG s01.
import bpy
GUN = "Marshal"
bpy.ops.wm.open_mainfile(filepath=r"C:/Users/charl/Documents/GauntletGame/GlitchedGauntletGame/art-source/weapons/RemasterV2/Marshal/Marshal_RemasterV2_v05.blend")
exec(open(r"C:/Users/charl/Documents/GauntletGame/GlitchedGauntletGame/tools/blender/tempest_line/ts_lib.py").read())
palette()
BZ = 0.2046          # bore (barrel axis)
TZ = 0.1155          # magazine tube axis
SZ = 0.3333          # scope axis

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

# ---------------- receiver: navy body, dark inset kept, rail teeth removed ----------------
rec = dup("Marshal_Receiver", "TS_Receiver")
bm, _ = stock_bm(rec.name)
kill_f = [f for g in islands(bm) if min(v.co.z for f in g for v in f.verts) > 0.245 for f in g]
bmesh.ops.delete(bm, geom=kill_f, context="FACES")
write_bm(rec, bm)
mi = {m.name: i for i, m in enumerate(rec.data.materials)}
for p in rec.data.polygons:
	if p.material_index == mi["Panel"]:
		p.material_index = mi["Body"]
finish(rec)
for m in list(rec.modifiers):
	if m.type == "WEIGHTED_NORMAL":
		rec.modifiers.remove(m)
replaced("Marshal_Neon")
BL = [(0.200, 0.132), (0.262, 0.100), (0.700, 0.100), (0.792, 0.138), (0.700, 0.168), (0.262, 0.168)]
for s in (1, -1):
	surface_plate("TS_Receiver", "TS_RecBlade%+d" % s, BL, s, lift=0.0004, thick=0.0062, ymin=0.03)
	surface_plate("TS_Receiver", "TS_RecHydro%+d" % s, [(0.270, 0.0905), (0.640, 0.0905), (0.652, 0.0945), (0.270, 0.0945)], s, lift=0.0004, thick=0.0022, mat="Neon", ymin=0.03)
# right side loading-gate cover (moving piece: hinged at its front edge)
surface_plate("TS_Receiver", "TS_GateCover", [(0.330, 0.018), (0.452, 0.018), (0.474, 0.046), (0.452, 0.074), (0.330, 0.074), (0.318, 0.046)], -1, lift=0.0004, thick=0.0060, ymin=0.03)
bolt = dup("Marshal_Bolt", "TS_Bolt")
pi = list(bolt.data.materials).index(M("Panel"))
for p in bolt.data.polygons:
	p.material_index = pi
pins = dup("Marshal_Pins", "TS_Pins")
bm, _ = stock_bm(pins.name)
bmesh.ops.delete(bm, geom=[v for v in bm.verts if v.co.x > 1.9], context="VERTS")
write_bm(pins, bm)

# ---------------- barrel + magazine tube: near-square octagons, fluted barrel ----------------
replaced("Marshal_Barrel")
FL = {0: [(0.5, 0.012, 0.0045)], 2: [(0.5, 0.012, 0.0045)], 4: [(0.5, 0.012, 0.0045)]}
rings = []
for i, (x, hw) in enumerate(((0.880, 0.042), (1.990, 0.041), (2.010, 0.041), (2.940, 0.0385), (2.960, 0.0385), (3.130, 0.037))):
	d = 1.0 if i in (2, 3) else 0.0
	rings.append(ring_x(x, fluted(octo(hw, hw, 0.16, cz=BZ), {k: [(t, w, dd * d) for t, w, dd in v] for k, v in FL.items()})))
new_obj("TS_Barrel", loft(rings), "Metal", bevel=0)
new_obj("TS_Tube", loft([ring_x(0.880, octo(0.040, 0.040, 0.16, cz=TZ)), ring_x(3.020, octo(0.038, 0.038, 0.16, cz=TZ))]), "Body", bevel=0)
new_obj("TS_TubeCap", loft([ring_x(3.010, octo(0.042, 0.042, 0.16, cz=TZ)), ring_x(3.044, octo(0.042, 0.042, 0.16, cz=TZ)),
	ring_x(3.062, octo(0.020, 0.020, 0.16, cz=TZ - 0.006))]), "Metal")
# barrel bands: one faceted collar round barrel + tube
def band_sec(hw, top, bot, k=0.022):
	return [(hw, bot + k), (hw, top - k), (hw - k, top), (-hw + k, top), (-hw, top - k), (-hw, bot + k), (-hw + k, bot), (hw - k, bot)]
new_obj("TS_BandRear", loft([ring_x(1.896, band_sec(0.054, 0.256, 0.066)), ring_x(1.990, band_sec(0.054, 0.256, 0.066)),
	ring_x(2.014, band_sec(0.046, 0.250, 0.072))]), "Panel")
new_obj("TS_BandRearSeam", loft([ring_x(1.936, band_sec(0.0552, 0.2572, 0.0648)), ring_x(1.942, band_sec(0.0552, 0.2572, 0.0648))]), "Neon", bevel=0)
new_obj("TS_BandFront", loft([ring_x(2.950, band_sec(0.046, 0.250, 0.072)), ring_x(2.966, band_sec(0.052, 0.254, 0.068)),
	ring_x(3.026, band_sec(0.052, 0.254, 0.068))]), "Panel")
# muzzle crown: faceted, two raked ports per side, fang-cut pointed crown
crown = new_obj("TS_Crown", loft([ring_x(3.124, octo(0.042, 0.042, 0.16, cz=BZ)), ring_x(3.140, octo(0.046, 0.046, 0.16, cz=BZ)),
	ring_x(3.1977, octo(0.046, 0.046, 0.16, cz=BZ))]), "Body")
for i in range(2):
	x = 3.152 + i * 0.022
	boolean(crown, cutter("TS_CUT_Port%d" % i, prism_xz([(x - 0.006, BZ - 0.024), (x + 0.002, BZ - 0.024), (x + 0.009, BZ + 0.024), (x + 0.001, BZ + 0.024)], -0.2, 0.2)))
for s in (1, -1):
	c = cutter("TS_CUT_Fang%+d" % s, prism_xz([(3.185, BZ - 0.1), (3.25, BZ - 0.1), (3.25, BZ + 0.1), (3.185, BZ + 0.1)], -0.016, 0.016))
	c.matrix_world = Matrix.Translation((0, s * 0.046, 0)) @ Matrix.Translation((3.1977, 0, 0)) @ Matrix.Rotation(math.radians(45), 4, "Z") @ Matrix.Translation((-3.1977, 0, 0))
	boolean(crown, c)
add_mat(crown, "Dark")
new_obj("TS_CrownBand", loft([ring_x(3.140, octo(0.0475, 0.0475, 0.16, cz=BZ)), ring_x(3.148, octo(0.0475, 0.0475, 0.16, cz=BZ))]), "Panel", bevel=0)
# front sight blade (decorative iron on the front band)
post = [(3.004, 0.250), (3.024, 0.250), (3.040, 0.252), (3.050, 0.296), (3.044, 0.300), (3.030, 0.292)]
new_obj("TS_Sight_FrontPost", prism_xz(post, -0.006, 0.006), "Body")

# ---------------- fore-end: keeled core, tilted leather bands, silver cap and raked nose ----------------
replaced("Marshal_ForeEnd")
def fe_sec(x, grow=0.0):
	hw, top, bot = 0.066, 0.200, -0.012
	pts = [(hw, bot + 0.030), (hw, top - 0.016), (hw - 0.014, top), (-hw + 0.014, top), (-hw, top - 0.016), (-hw, bot + 0.030), (-hw * 0.55, bot), (hw * 0.55, bot)]
	return sec_grow(pts, grow)
fe = [ring_x(0.884, fe_sec(0)), ring_x(1.850, fe_sec(0))]
nose = [(0.060, 0.030), (0.060, 0.186), (0.048, 0.198), (-0.048, 0.198), (-0.060, 0.186), (-0.060, 0.030), (-0.032, 0.012), (0.032, 0.012)]
fe.append(ring_x(1.908, nose))
new_obj("TS_ForeEnd", loft(fe), "Body", like="Marshal_ForeEnd")
new_obj("TS_ForeCap", loft([ring_x(1.846, fe_sec(0, 0.0022)), ring_x(1.860, fe_sec(0, 0.0022))]), "Panel", like="Marshal_ForeEnd", bevel=0)
for i in range(6):
	x0 = 1.000 + i * 0.122
	new_obj("TS_ForeWrap%d" % i, loft([ring_tilt_x(fe_sec, x0, 0.32, 0.0034, 0.094), ring_tilt_x(fe_sec, x0 + 0.090, 0.32, 0.0050, 0.094)]), "Grip", like="Marshal_ForeEnd", bevel=0)
for i, x0 in enumerate((0.960, 1.744)):
	new_obj("TS_ForeHydro%d" % i, loft([ring_tilt_x(fe_sec, x0, 0.32, 0.0014, 0.094), ring_tilt_x(fe_sec, x0 + 0.006, 0.32, 0.0014, 0.094)]), "Neon", like="Marshal_ForeEnd", bevel=0)

# ---------------- scope: faceted 12-sided tube and bells, lenses untouched, crescent rings at both ends ----------------
replaced("Marshal_Scope")
SC_PROF = [(0.196, 0.0), (0.196, 0.0535), (0.1865, 0.0535), (0.1865, 0.0640), (0.268, 0.0665), (0.312, 0.0478), (0.900, 0.0478),
	(1.040, 0.0770), (1.158, 0.0795), (1.158, 0.0700), (1.140, 0.0700), (1.140, 0.0)]
new_obj("TS_ScopeTube", lathe(SC_PROF, 12, cz=SZ), "Body", like="Marshal_Scope", bevel=0)
new_obj("TS_ScopeBand", lathe([(0.312, 0.0), (0.312, 0.0492), (0.326, 0.0492), (0.326, 0.0)], 12, cz=SZ), "Panel", like="Marshal_Scope", bevel=0)
new_obj("TS_ScopeBandF", lathe([(0.886, 0.0), (0.886, 0.0492), (0.900, 0.0492), (0.900, 0.0)], 12, cz=SZ), "Panel", like="Marshal_Scope", bevel=0)
def crescent_ring(name, x0, x1, r_in, t_bot, gap_deg=45):
	n = 12; rot = math.pi / n
	angs = [a for a in (rot + 2 * math.pi * i / n for i in range(-n, 2 * n))]
	lo, hi = math.radians(90 + gap_deg), math.radians(90 - gap_deg + 360)
	sel = sorted({round(a, 6) for a in angs if lo - 1e-6 <= a <= hi + 1e-6})
	inner = [(r_in * 0.997 * math.cos(a), SZ + r_in * 0.997 * math.sin(a)) for a in sel]
	outer = []
	for j, a in enumerate(sel):
		t = 0.0018 + (t_bot - 0.0018) * (1 - math.sin(a)) / 2
		if j in (0, len(sel) - 1):
			t = 0.0012
		outer.append(((r_in + t) * math.cos(a), SZ + (r_in + t) * math.sin(a)))
	return new_obj(name, prism_yz(outer + inner[::-1], x0, x1), "Panel", like="Marshal_Scope", bevel=0)
crescent_ring("TS_ScopeCrescentRear", 0.226, 0.244, 0.0650, 0.016)
crescent_ring("TS_ScopeCrescentFront", 1.098, 1.118, 0.0786, 0.018)
# mounts: blade bases on the rail + 12-sided clamp rings
for i, (x0, x1) in enumerate(((0.405, 0.453), (0.751, 0.799))):
	new_obj("TS_ScopeMount%d" % i, chamfer_prism_xz([(x0 - 0.012, 0.249), (x1 + 0.012, 0.249), (x1, 0.292), (x0, 0.292)], -0.024, 0.024, 0.004), "Metal", like="Marshal_Scope", bevel=0)
	new_obj("TS_ScopeRing%d" % i, lathe([(x0 + 0.004, 0.0), (x0 + 0.004, 0.0565), (x1 - 0.004, 0.0565), (x1 - 0.004, 0.0)], 12, cz=SZ), "Panel", like="Marshal_Scope", bevel=0)
# turrets: octagonal, top cap with a silver ring, side drum, small left knob
new_obj("TS_TurretSaddle", chamfer_prism_xz([(0.572, 0.360), (0.668, 0.360), (0.658, 0.386), (0.582, 0.386)], -0.040, 0.040, 0.006), "Body", like="Marshal_Scope", bevel=0)
bm = bmesh.new()
tt = [(x, y) for x, y in ngon(0.031, 8, 0.620, 0.0, math.pi / 8)]
new_obj("TS_TurretTop", prism_xy(tt, 0.384, 0.432), "Metal", like="Marshal_Scope")
new_obj("TS_TurretTopRing", prism_xy([(x, y) for x, y in ngon(0.0325, 8, 0.620, 0.0, math.pi / 8)], 0.432, 0.440), "Panel", like="Marshal_Scope", bevel=0)
new_obj("TS_TurretSide", prism_xz([(x, z) for x, z in ngon(0.027, 8, 0.620, SZ, math.pi / 8)], -0.098, -0.040), "Metal", like="Marshal_Scope")
new_obj("TS_TurretKnob", prism_xz([(x, z) for x, z in ngon(0.020, 8, 0.620, SZ, math.pi / 8)], 0.040, 0.082), "Metal", like="Marshal_Scope")

# ---------------- stock: faceted outline on the stock footprint, wrapped wrist, silver blades, pointed toe ----------------
replaced("Marshal_Stock")
TOP = [(0.176, 0.214), (0.100, 0.208), (0.000, 0.169), (-0.100, 0.130), (-0.200, 0.091), (-0.320, 0.072), (-1.180, 0.058), (-1.240, 0.066)]
BOT = [(-1.240, -0.296), (-1.120, -0.292), (-0.400, -0.2645), (-0.200, -0.1517), (-0.100, -0.0998), (0.000, -0.0736), (0.100, -0.0593), (0.176, -0.049)]
STK = TOP + BOT
def hw_at(x):
	return 0.052 + (0.066 - 0.052) * max(0.0, min(1.0, (-x - 0.20) / 0.30))
bm = chamfer_prism_xz(STK, -1.0, 1.0, 0.0)
bm.free()
bm = chamfer_prism_xz(STK, -0.066, 0.066, 0.009)
for v in bm.verts:
	v.co.y *= hw_at(v.co.x) / 0.066
new_obj("TS_Stock", bm, "Body", like="Marshal_Stock", bevel=0)
def interp(pl, x):
	pl = sorted(pl)
	if x <= pl[0][0]:
		return pl[0][1]
	for (x0, z0), (x1, z1) in zip(pl[:-1], pl[1:]):
		if x0 <= x <= x1:
			return z0 + (z1 - z0) * (x - x0) / (x1 - x0)
	return pl[-1][1]
def wrist_sec(x, grow=0.0):
	zt, zb, hw = interp(TOP, x), interp(BOT, x), hw_at(x); k = 0.009
	return sec_grow([(hw, zb + k), (hw, zt - k), (hw - k, zt), (-hw + k, zt), (-hw, zt - k), (-hw, zb + k), (-hw + k, zb), (hw - k, zb)], grow)
for i, x0 in enumerate((-0.246, -0.172, -0.098, -0.024)):
	new_obj("TS_WristWrap%d" % i, loft([ring_tilt_x(wrist_sec, x0, -0.30, 0.0034, 0.05), ring_tilt_x(wrist_sec, x0 + 0.056, -0.30, 0.0050, 0.05)]), "Grip", like="Marshal_Stock", bevel=0)
	if i < 3:
		new_obj("TS_WristHydro%d" % i, loft([ring_tilt_x(wrist_sec, x0 + 0.063, -0.30, 0.0014, 0.05), ring_tilt_x(wrist_sec, x0 + 0.068, -0.30, 0.0014, 0.05)]), "Neon", like="Marshal_Stock", bevel=0)
for s in (1, -1):
	surface_plate("TS_Stock", "TS_StockBlade%+d" % s, [(-1.150, -0.030), (-1.100, -0.060), (-0.480, -0.060), (-0.360, -0.016), (-0.480, 0.000), (-1.100, 0.000)], s, lift=0.0004, thick=0.0050)
	surface_plate("TS_Stock", "TS_StockLine%+d" % s, [(-1.080, -0.0745), (-0.520, -0.0745), (-0.505, -0.0705), (-1.080, -0.0705)], s, lift=0.0004, thick=0.0018, mat="Accent")
butt = [(-1.262, 0.064), (-1.240, 0.064), (-1.240, -0.296), (-1.200, -0.330), (-1.262, -0.300)]
new_obj("TS_ButtPlate", chamfer_prism_xz(butt, -0.064, 0.064, 0.006), "Panel", like="Marshal_Stock", bevel=0)
new_obj("TS_ButtPad", prism_xz([(-1.276, 0.058), (-1.258, 0.058), (-1.258, -0.292), (-1.276, -0.286)], -0.058, 0.058), "Dark", like="Marshal_Stock")

# ---------------- lever: sharp blade loop + blade arm (Lever bone) ----------------
replaced("Marshal_Lever")
LOOP = [(0.200, -0.050), (0.100, -0.052), (0.000, -0.082), (-0.060, -0.118), (-0.118, -0.190), (-0.152, -0.266), (-0.100, -0.318),
	(-0.040, -0.338), (0.030, -0.334), (0.108, -0.280), (0.200, -0.172)]
inner = poly_offset(LOOP, -0.022)
bm = bmesh.new()
n = len(LOOP)
for y0, y1 in ((-0.020, 0.020),):
	O0 = [bm.verts.new((x, y0, z)) for x, z in LOOP]; O1 = [bm.verts.new((x, y1, z)) for x, z in LOOP]
	I0 = [bm.verts.new((x, y0, z)) for x, z in inner]; I1 = [bm.verts.new((x, y1, z)) for x, z in inner]
	for i in range(n):
		j = (i + 1) % n
		bm.faces.new((O0[i], O0[j], O1[j], O1[i]))
		bm.faces.new((I1[i], I1[j], I0[j], I0[i]))
		bm.faces.new((O0[j], O0[i], I0[i], I0[j]))
		bm.faces.new((O1[i], O1[j], I1[j], I1[i]))
new_obj("TS_LeverLoop", bm, "Panel", like="Marshal_Lever", bevel=0)
ARM = [(0.196, -0.128), (0.300, -0.140), (0.420, -0.136), (0.500, -0.100), (0.540, -0.030), (0.560, -0.002), (0.594, -0.018),
	(0.586, -0.078), (0.522, -0.130), (0.420, -0.162), (0.300, -0.166), (0.196, -0.154)]
new_obj("TS_LeverArm", prism_xz(ARM, -0.016, 0.016), "Metal", like="Marshal_Lever")
new_obj("TS_LeverEdge", prism_xz([(0.230, -0.1675), (0.420, -0.1635), (0.470, -0.150), (0.420, -0.158), (0.230, -0.161)], -0.0105, 0.0105), "Panel", like="Marshal_Lever", bevel=0)

bpy.context.view_layer.update()
result = {"tris": tris(visible_model()), "parts": len(visible_model())}
