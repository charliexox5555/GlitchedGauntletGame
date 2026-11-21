# Tempest-Strike Kunai-Katana s03: full rebuild on the STOCK RemasterV2 Knife v05 (owner on s02: "does not look good,
# unpolished, unprofessional; high quality, nice clean shapes"). Same rig (Root), hand origin, locators.
# Construction like a real kunai / tsuka:
#   ring (16 flat facets, chamfered section) -> neck -> kashira cap -> grip: dark core + crossing leather bands with
#   diamond windows between the crossings -> fuchi ferrule -> seppa washer / disc tsuba / seppa ->
#   habaki collar -> kunai blade (neck, shouldered leaf, centre spine, silver edge bevel faces, etched crack) and the
#   WaterKatana (curved, diamond section, many stations, true point).
import bpy
GUN = "Knife"
bpy.ops.wm.open_mainfile(filepath=r"C:/Users/charl/Documents/GauntletGame/GlitchedGauntletGame/art-source/weapons/RemasterV2/Knife/Knife_RemasterV2_v05.blend")
exec(open(r"C:/Users/charl/Documents/GauntletGame/GlitchedGauntletGame/tools/blender/tempest_line/ts_lib.py").read())
palette()
for n in ("Knife_Blade", "Knife_Hilt", "Knife_Neon"):
	replaced(n)
LIKE = "Knife_Hilt"
w = M("Water")
b = w.node_tree.nodes.get("Principled BSDF")
b.inputs["Base Color"].default_value = lin("#40F5D4"); b.inputs["Roughness"].default_value = 0.08; b.inputs["Metallic"].default_value = 0.0
b.inputs["Emission Color"].default_value = lin("#40F5D4"); b.inputs["Emission Strength"].default_value = 0.4
w.diffuse_color = lin("#40F5D4")
EDGE = 0.0007          # hairline flat chamfer on steel parts (edge highlight)

def multi_obj(name, bm, mats, like=LIKE, bevel=0.0):
	"""bmesh whose faces carry material_index into `mats` (list of role names)."""
	bake_bm(bm)
	me = bpy.data.meshes.new(name); bm.to_mesh(me); bm.free()
	o = bpy.data.objects.new(name, me); TS.objects.link(o)
	ref = bpy.data.objects[like]
	o.parent = ref.parent; o.parent_type = ref.parent_type; o.parent_bone = ref.parent_bone
	o.matrix_world = Matrix.Identity(4)
	for m in mats:
		me.materials.append(M(m))
	return finish(o, bevel)

def loft_apex(rings, apex, cap0=True):
	"""Loft closed rings, then close the last ring to a single apex vertex (a true point)."""
	bm = bmesh.new()
	R = [[bm.verts.new(p) for p in r] for r in rings]
	n = len(rings[0])
	for a, c in zip(R[:-1], R[1:]):
		for i in range(n):
			bm.faces.new((a[i], a[(i + 1) % n], c[(i + 1) % n], c[i]))
	ap = bm.verts.new(apex)
	for i in range(n):
		bm.faces.new((R[-1][i], R[-1][(i + 1) % n], ap))
	if cap0:
		bm.faces.new(R[0][::-1])
	return bm

# ======================= grip (tsuka): dark core + crossing leather bands =======================
GX0, GX1 = -0.246, 0.268
def gsec(x, grow=0.0):
	u = (x - GX0) / (GX1 - GX0)
	hw = 0.0500 + 0.0040 * u + grow          # widens a touch towards the guard
	hh = 0.0580 + 0.0040 * u + grow
	k = 0.30 * min(hw, hh)
	return [(hw, -hh + k), (hw, hh - k), (hw - k, hh), (-hw + k, hh), (-hw, hh - k), (-hw, -hh + k), (-hw + k, -hh), (hw - k, -hh)]
xs = [GX0 + (GX1 - GX0) * i / 6 for i in range(7)]
new_obj("TS_GripCore", loft([ring_x(x, gsec(x)) for x in xs]), "Dark", like=LIKE, bevel=0)
# tsuka-maki: alternating 45-degree bands (tilted sleeves of the grip section). Each pair crosses on the side faces;
# the gaps between neighbouring crossings are the diamond windows onto the dark core. "Over" bands stand proud of
# "under" bands, so every crossing is layered (no shared faces).
P, W, K = 0.1020, 0.0420, 1.00              # pitch, band width along x, tilt (45 degrees)
CX = [-0.180 + P * i for i in range(5)]
def band(name, x0, tilt, g0, g1):
	return new_obj(name, loft([ring_tilt_x(gsec, x0 - W / 2, tilt, g0, 0.0), ring_tilt_x(gsec, x0 + W / 2, tilt, g1, 0.0)]), "Grip", like=LIKE, bevel=0)
for i, cx in enumerate(CX):
	band("TS_GripBandU%d" % i, cx, -K, 0.0036, 0.0036)
	band("TS_GripBandO%d" % i, cx, K, 0.0058, 0.0058)

# ferrules: kashira cap (pommel end) and fuchi (guard end), from the grip section grown
def ferrule(name, x0, x1, g0, g1, ch=0.004):
	return new_obj(name, loft([ring_x(x0, gsec(x0, g0 - ch)), ring_x(x0 + ch, gsec(x0, g0)), ring_x(x1 - ch, gsec(x1, g1)), ring_x(x1, gsec(x1, g1 - ch))]),
		"Metal", like=LIKE, bevel=EDGE)
ferrule("TS_Kashira", -0.300, -0.238, 0.0082, 0.0090)   # proud of the bands (0.0058): band ends tuck under
new_obj("TS_KashiraBand", loft([ring_x(-0.262, gsec(-0.262, 0.0100)), ring_x(-0.255, gsec(-0.255, 0.0100))]), "Panel", like=LIKE, bevel=0)
ferrule("TS_Fuchi", 0.260, 0.288, 0.0086, 0.0092)

# ======================= ring pommel: 16 flat facets, chamfered section, neck =======================
RX = -0.392
def ring_y(cx, cz, r_in, r_out, hy, c, n=16):
	sec = [(r_in, -hy + c), (r_in, hy - c), (r_in + c, hy), (r_out - c, hy), (r_out, hy - c), (r_out, -hy + c), (r_out - c, -hy), (r_in + c, -hy)]
	bm = bmesh.new(); R = []
	for i in range(n):
		a = 2 * math.pi * i / n
		R.append([bm.verts.new((cx + r * math.cos(a), y, cz + r * math.sin(a))) for r, y in sec])
	m = len(sec)
	for i in range(n):
		P_, Q = R[i], R[(i + 1) % n]
		for j in range(m):
			bm.faces.new((P_[j], P_[(j + 1) % m], Q[(j + 1) % m], Q[j]))
	return bm
new_obj("TS_Ring", ring_y(RX, 0.0, 0.060, 0.090, 0.0150, 0.0055), "Metal", like=LIKE, bevel=EDGE)
new_obj("TS_RingNeck", chamfer_prism_xz([(-0.312, -0.022), (-0.296, -0.026), (-0.296, 0.026), (-0.312, 0.022)], -0.0125, 0.0125, 0.003), "Metal", like=LIKE, bevel=EDGE)

# ======================= guard stack: seppa, disc tsuba (16 facets, stepped rims), seppa, habaki =======================
new_obj("TS_SeppaRear", lathe([(0.286, 0.0), (0.286, 0.074), (0.293, 0.074), (0.293, 0.0)], 16, rot=0.0), "Panel", like=LIKE, bevel=0)
new_obj("TS_Tsuba", lathe([(0.292, 0.0), (0.292, 0.104), (0.297, 0.121), (0.311, 0.121), (0.316, 0.104), (0.316, 0.0)], 16, rot=0.0), "Metal", like=LIKE, bevel=EDGE)
new_obj("TS_TsubaRim", lathe([(0.2995, 0.0), (0.2995, 0.1222), (0.3085, 0.1222), (0.3085, 0.0)], 16, rot=0.0), "Panel", like=LIKE, bevel=0)
new_obj("TS_SeppaFront", lathe([(0.315, 0.0), (0.315, 0.066), (0.321, 0.066), (0.321, 0.0)], 16, rot=0.0), "Panel", like=LIKE, bevel=0)
hab = [(0.320, -0.034), (0.346, -0.031), (0.356, -0.024), (0.356, 0.024), (0.346, 0.031), (0.320, 0.034)]
bm = chamfer_prism_xz(hab, -0.0215, 0.0215, 0.004)
for v in bm.verts:
	if v.co.x > 0.35:
		v.co.y *= 0.82
new_obj("TS_Habaki", bm, "Metal", like=LIKE, bevel=EDGE)

# ======================= kunai blade: neck, shouldered leaf, spine, silver bevels (one mesh, two materials) ========
# kunai profile: narrow neck, sharp angled shoulder, then dead-straight edges to the point (no spindle bulge)
KX = [(0.330, 0.0215, 0.0135), (0.362, 0.0215, 0.0135), (0.392, 0.0600, 0.0158), (0.410, 0.0740, 0.0162), (0.430, 0.0735, 0.0160),
	(0.795, 0.0085, 0.0030)]
TIP = (0.832, 0.0, 0.0)
def ksec(x, h, t):
	hb, tb = 0.76 * h, 0.32 * t
	return [(x, 0.0, h), (x, tb, hb), (x, t, 0.0), (x, tb, -hb), (x, 0.0, -h), (x, -tb, -hb), (x, -t, 0.0), (x, -tb, hb)]
bm = loft_apex([ksec(*k) for k in KX], TIP)
BEVEL_IDX = {0, 3, 4, 7}        # faces from section edges 0-1, 3-4, 4-5, 7-0 are the edge bevels
for f in bm.faces:
	f.material_index = 0
bm.faces.ensure_lookup_table()
n = 8
fi = 0
for s_ in range(len(KX) - 1):
	for i in range(n):
		if i in BEVEL_IDX:
			bm.faces[fi].material_index = 1
		fi += 1
for i in range(n):
	if i in BEVEL_IDX:
		bm.faces[fi].material_index = 1
	fi += 1
kb = multi_obj("TS_KunaiBlade", bm, ["Dark", "Panel"])
# etched lightning crack along the spine (both faces), cyan floor
def t_at(x):
	for (x0, h0, t0), (x1, h1, t1) in zip(KX[:-1], KX[1:]):
		if x0 <= x <= x1:
			return t0 + (t1 - t0) * (x - x0) / (x1 - x0)
	return KX[-1][2]
ZZ = [(0.405, 0.0), (0.455, 0.0085), (0.505, -0.0055), (0.565, 0.0070), (0.625, -0.0035), (0.675, 0.0020), (0.705, 0.0)]
for s in (1, -1):
	top = [(x, z + 0.0019 * (1 - (x - 0.405) / 0.4)) for x, z in ZZ]; bot = [(x, z - 0.0019 * (1 - (x - 0.405) / 0.4)) for x, z in ZZ[::-1]]
	bm = prism_xz(top + bot, 0.0, 1.0)
	for v in bm.verts:
		v.co.y = s * (t_at(v.co.x) - 0.0022) if v.co.y < 0.5 else s * 0.06
	boolean(kb, cutter("TS_CUT_Crack%+d" % s, bm, "Neon"))
add_mat(kb, "Neon")

# ======================= water katana: curved, diamond section, many stations, true point =======================
# stays inside the kunai until its point, then flares out of the tip (no break-out through the kunai's flats)
WX = [(0.660, 0.0160, 0.0045), (0.760, 0.0110, 0.0036), (0.800, 0.0062, 0.0024), (0.840, 0.0170, 0.0050), (0.900, 0.0330, 0.0095),
	(1.000, 0.0440, 0.0127), (1.140, 0.0460, 0.0130), (1.340, 0.0440, 0.0124), (1.540, 0.0400, 0.0113), (1.730, 0.0340, 0.0097),
	(1.900, 0.0260, 0.0076), (2.030, 0.0170, 0.0052), (2.120, 0.0085, 0.0028)]
WTIP_X = 2.185
def zc(x):
	u = max(0.0, (x - 0.82) / (WTIP_X - 0.82))
	return 0.050 * u * u
def wsec(x, h, t):
	c = zc(x)
	return [(x, 0.0, c + h), (x, t, c), (x, 0.0, c - h), (x, -t, c)]
new_obj("WaterKatana", loft_apex([wsec(*k) for k in WX], (WTIP_X, 0.0, zc(WTIP_X) + 0.004)), "Water", like=LIKE, bevel=0)

bpy.context.view_layer.update()
result = {"tris": tris(visible_model()), "parts": len(visible_model())}
