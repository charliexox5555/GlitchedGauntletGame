# Tempest-Strike Sheriff s01: restyle the STOCK RemasterV2 Sheriff v05 (revolver, held two-handed). Same rig, bones
# (Crane > Cylinder > EjectorRod/Rounds/Speedloader, Hammer, Trigger, CylinderRelease), locators and footprint.
import bpy
GUN = "Sheriff"
bpy.ops.wm.open_mainfile(filepath=r"C:/Users/charl/Documents/GauntletGame/GlitchedGauntletGame/art-source/weapons/RemasterV2/Sheriff/Sheriff_RemasterV2_v05.blend")
exec(open(r"C:/Users/charl/Documents/GauntletGame/GlitchedGauntletGame/tools/blender/tempest_line/ts_lib.py").read())
palette()
BZ = 0.2782      # bore
CZ = 0.1898      # cylinder axis
AIM = bpy.data.objects["Sheriff_AimPoint"].matrix_world.translation.copy()   # (0.26, 0, 0.418)

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

# ---------------- frame: stock frame without its trigger guard; recessed silver side plates; cyan strap slots ----------------
fr = dup("Sheriff_Frame", "TS_Frame")
bm, _ = stock_bm(fr.name)
bmesh.ops.delete(bm, geom=[f for g in islands(bm) if max(v.co.z for f in g for v in f.verts) < 0.0 for f in g], context="FACES")
write_bm(fr, bm)
finish(fr)
for m in list(fr.modifiers):
	if m.type == "WEIGHTED_NORMAL":
		fr.modifiers.remove(m)
PLATE = [(0.000, 0.198), (0.046, 0.148), (0.262, 0.148), (0.306, 0.190), (0.262, 0.238), (0.046, 0.238)]
for s in (1, -1):
	y0, y1 = (0.058, 0.080) if s > 0 else (-0.080, -0.058)
	boolean(fr, cutter("TS_CUT_Recess%+d" % s, prism_xz(poly_offset(PLATE, 0.003), y0, y1)))
	ys = (0.0615, 0.080) if s > 0 else (-0.080, -0.0615)
	boolean(fr, cutter("TS_CUT_Strap%+d" % s, prism_xz([(0.345, 0.3445), (0.600, 0.3445), (0.612, 0.3485), (0.345, 0.3485)], *ys), "Neon"))
	y0, y1 = (0.0575, 0.0675) if s > 0 else (-0.0675, -0.0575)
	new_obj("TS_SidePlate%+d" % s, chamfer_prism_xz(PLATE, y0, y1, 0.0014), "Panel", bevel=0)
add_mat(fr, "Dark"); add_mat(fr, "Neon")
replaced("Sheriff_Neon")
# angular blade trigger guard with a silver spur
new_obj("TS_GuardRear", bar((0.250, 0.010), (0.262, -0.205), 0.020, 0.012, 0.6), "Body")
new_obj("TS_GuardBottom", bar((0.252, -0.200), (0.566, -0.212), 0.020, 0.012, 0.6), "Body")
new_obj("TS_GuardFront", bar((0.556, -0.214), (0.592, 0.010), 0.020, 0.012, 0.6), "Body")
new_obj("TS_GuardSpur", prism_xz([(0.300, -0.2195), (0.540, -0.2245), (0.600, -0.2185), (0.540, -0.2175), (0.300, -0.2125)], -0.015, 0.015), "Panel", bevel=0)

# ---------------- barrel: near-square octagon, side flutes, top rib, underlug, pointed crown ----------------
replaced("Sheriff_Barrel")
FL = {0: [(0.36, 0.011, 0.0045), (0.64, 0.011, 0.0045)], 4: [(0.36, 0.011, 0.0045), (0.64, 0.011, 0.0045)]}
rings = []
for i, x in enumerate((0.752, 0.860, 0.880, 1.330, 1.350, 1.432)):
	d = 1.0 if i in (2, 3) else 0.0
	rings.append(ring_x(x, fluted(octo(0.052, 0.062, 0.16, cz=BZ), {k: [(t, w, dd * d) for t, w, dd in v] for k, v in FL.items()})))
new_obj("TS_Barrel", loft(rings), "Body", bevel=0)
rib = [(0.800, 0.336), (1.400, 0.336), (1.420, 0.344), (1.400, 0.350), (0.820, 0.350)]
new_obj("TS_Rib", chamfer_prism_xz(rib, -0.017, 0.017, 0.004), "Panel", bevel=0)
new_obj("TS_Underlug", loft([ring_x(0.752, octo(0.040, 0.060, 0.16, cz=0.172)), ring_x(1.170, octo(0.040, 0.060, 0.16, cz=0.172)),
	ring_x(1.262, octo(0.034, 0.018, 0.16, cz=0.228))]), "Body", bevel=0)
for s in (1, -1):
	surface_plate("TS_Underlug", "TS_LugHydro%+d" % s, [(0.790, 0.1665), (1.120, 0.1665), (1.134, 0.1705), (0.790, 0.1705)], s, lift=0.0004, thick=0.0018, mat="Neon", ymin=0.02)
crown = new_obj("TS_Crown", loft([ring_x(1.426, octo(0.056, 0.066, 0.16, cz=BZ)), ring_x(1.495, octo(0.056, 0.066, 0.16, cz=BZ))]), "Body")
for s in (1, -1):
	c = cutter("TS_CUT_Fang%+d" % s, prism_xz([(1.460, BZ - 0.12), (1.54, BZ - 0.12), (1.54, BZ + 0.12), (1.460, BZ + 0.12)], -0.016, 0.016))
	c.matrix_world = Matrix.Translation((0, s * 0.056, 0)) @ Matrix.Translation((1.495, 0, 0)) @ Matrix.Rotation(math.radians(45), 4, "Z") @ Matrix.Translation((-1.495, 0, 0))
	boolean(crown, c)
boolean(crown, cutter("TS_CUT_Bore", prism_yz(ngon(0.022, 8, 0.0, BZ, math.pi / 8), 1.470, 1.55)))
add_mat(crown, "Dark")
new_obj("TS_CrownBand", loft([ring_x(1.424, octo(0.0575, 0.0675, 0.16, cz=BZ)), ring_x(1.434, octo(0.0575, 0.0675, 0.16, cz=BZ))]), "Panel", bevel=0)

# ---------------- sights: small crescent rear on the AimPoint, swept blade front on the rib ----------------
replaced("Sheriff_Sights")
new_obj("TS_Sight_RearBase", chamfer_prism_xz([(0.232, 0.366), (0.296, 0.366), (0.288, 0.384), (0.240, 0.384)], -0.030, 0.030, 0.004), "Body", bevel=0)
crescent_sight("TS", AIM.x, AIM.z, ro=0.058, ri=0.051, off=0.0042, gap=36, depth=0.015)
post = [(1.330, 0.348), (1.420, 0.348), (1.408, 0.362), (1.390, 0.414), (1.386, 0.424), (1.380, 0.424), (1.374, 0.406), (1.344, 0.362)]
new_obj("TS_Sight_FrontPost", prism_xz(post, -0.0065, 0.0065), "Body")
new_obj("TS_Sight_FrontDot", prism_xz([(1.3795, 0.412), (1.3855, 0.412), (1.3855, 0.418), (1.3795, 0.418)], -0.0075, 0.0075), "Neon", bevel=0)

# ---------------- cylinder: 12-sided, chamfered ends, six through chambers, straight-cut flutes with cyan slots ----------------
replaced("Sheriff_Cylinder")
cyl = new_obj("TS_Cylinder", lathe([(0.319, 0.0), (0.319, 0.120), (0.331, 0.139), (0.615, 0.139), (0.627, 0.122), (0.627, 0.0)], 12, cz=CZ, rot=math.pi / 12),
	"Metal", like="Sheriff_Cylinder", bevel=0)
for k in range(6):
	a = math.radians(90 + 60 * k)
	cy_, cz_ = 0.088 * math.cos(a), CZ + 0.088 * math.sin(a)
	boolean(cyl, cutter("TS_CUT_Chamber%d" % k, prism_yz(ngon(0.0335, 8, cy_, cz_, math.pi / 8), 0.30, 0.65)))
	f = math.radians(60 * k)          # flutes between the chambers
	for nm, w, d, mt in (("Flute", 0.030, 0.016, "Dark"), ("Slot", 0.006, 0.020, "Neon")):
		bm = prism_yz([(-w / 2, 0.0), (w / 2, 0.0), (w / 2, 0.06), (-w / 2, 0.06)], 0.352 if nm == "Flute" else 0.372, 0.594 if nm == "Flute" else 0.574)
		c = cutter("TS_CUT_%s%d" % (nm, k), bm, mt)
		c.matrix_world = Matrix.Translation((0, 0, CZ)) @ Matrix.Rotation(f - math.pi / 2, 4, "X") @ Matrix.Translation((0, 0, 0.1343 - d))
		boolean(cyl, c)
add_mat(cyl, "Dark"); add_mat(cyl, "Neon")

# ---------------- hammer: silver ----------------
ham = dup("Sheriff_Hammer", "TS_Hammer")
pi = list(ham.data.materials).index(M("Panel"))
for p in ham.data.polygons:
	p.material_index = pi

# ---------------- grip: faceted shell, leather bands, conduits, silver pommel cap ----------------
replaced("Sheriff_Grip")
GS = [(-0.392, 0.056, -0.236, 0.060), (-0.360, 0.079, -0.258, 0.066), (-0.200, 0.080, -0.234, 0.066), (0.000, 0.148, -0.174, 0.066),
	(0.090, 0.090, -0.150, 0.064), (0.175, 0.020, -0.100, 0.056)]
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
	return sec_grow([(fx, -hw * 0.40), (fx, hw * 0.40), (fx - 0.034, hw), (bx + 0.030, hw), (bx, hw * 0.55), (bx, -hw * 0.55), (bx + 0.030, -hw), (fx - 0.034, -hw)], grow)
def ring_z(secf, z0, tilt=0.0, grow=0.0):
	n = len(secf(z0)); out = []
	for i in range(n):
		z = z0
		for _ in range(3):
			x = secf(z, grow)[i][0]; z = z0 + tilt * x
		x, y = secf(z, grow)[i]
		out.append((x, y, z))
	return out
new_obj("TS_GripCore", loft([ring_z(grip_sec, z) for z, *_ in GS]), "Body", like="Sheriff_Grip")
for i, z0 in enumerate((-0.020, -0.092, -0.164, -0.236)):
	z1 = z0 - 0.056
	new_obj("TS_GripWrap%d" % i, loft([ring_z(grip_sec, z1, 0.22, 0.0040), ring_z(grip_sec, z0, 0.22, 0.0058)]), "Grip", like="Sheriff_Grip", bevel=0)
	if i < 3:
		new_obj("TS_GripHydro%d" % i, loft([ring_z(grip_sec, z1 - 0.0108, 0.22, 0.0020), ring_z(grip_sec, z1 - 0.0058, 0.22, 0.0020)]), "Neon", like="Sheriff_Grip", bevel=0)
cap0 = [(x, y, -0.350) for x, y in grip_sec(-0.350, 0.0030)]
cap1 = [(x, y, -0.392) for x, y in grip_sec(-0.392, 0.0020)]
_c = grip_sec(-0.392, 0.0); _cx = sum(p[0] for p in _c) / len(_c)
cap2 = [(_cx + (x - _cx) * 0.84 - (0.024 if x < _cx - 0.06 else 0.0), y * 0.74, -0.420) for x, y in _c]
new_obj("TS_GripCap", loft([cap0, cap1, cap2]), "Panel", like="Sheriff_Grip")

bpy.context.view_layer.update()
result = {"tris": tris(visible_model()), "parts": len(visible_model())}
