# Tempest-Strike Katana s05 (replaces the kunai; owner 2026-11-22: "it should look like a lightsaber with the blade over
# the whole thing ... more like a katana"). Built on the STOCK RemasterV2 Knife v05 (Root at origin, RightGrip = hand
# at the origin, BladeBase/BladeTip kept). Sheet: refs/style/Tempest-Strike Katana Reference.jpg.
# Axes: +X = point, +Z = spine side (edge faces -Z), +Y = the player-visible left side.
#   ring pommel (12 facets, chamfered section) + link + 4-point shuriken charm -> kashira collar -> diamond-wrapped tsuka
#   (dark core, crossing 45-degree leather bands) -> fuchi -> cupped crescent tsuba -> seppa -> habaki ->
#   curved single-edged blade from straight segments: silver mune and spine bevels, matte-black flats with a fuller
#   (Neon inlay, separate object), etched lightning on the bevels, and a separate TS Water cutting edge along the whole
#   edge, seated under the steel, forming the glowing point.
import bpy
GUN = "Knife"
bpy.ops.wm.open_mainfile(filepath=r"C:/Users/charl/Documents/GauntletGame/GlitchedGauntletGame/art-source/weapons/RemasterV2/Knife/Knife_RemasterV2_v05.blend")
exec(open(r"C:/Users/charl/Documents/GauntletGame/GlitchedGauntletGame/tools/blender/tempest_line/ts_lib.py").read())
palette()
for n in ("Knife_Blade", "Knife_Hilt", "Knife_Neon"):
	replaced(n)
LIKE = "Knife_Hilt"
EDGE = 0.0007
w = M("Water")
bsdf = w.node_tree.nodes.get("Principled BSDF")
bsdf.inputs["Base Color"].default_value = lin("#40F5D4"); bsdf.inputs["Roughness"].default_value = 0.08; bsdf.inputs["Metallic"].default_value = 0.0
bsdf.inputs["Emission Color"].default_value = lin("#40F5D4"); bsdf.inputs["Emission Strength"].default_value = 0.45   # < 0.5: flat export SmoothPlastic
bsdf.inputs["Alpha"].default_value = 0.86           # review-only translucency; the flat export ignores alpha
for attr, val in (("surface_render_method", "BLENDED"), ("blend_method", "BLEND"), ("show_transparent_back", False)):
	try:
		setattr(w, attr, val)
	except (AttributeError, TypeError):
		pass
w.diffuse_color = lin("#40F5D4")

def multi_obj(name, bm, mats, like=LIKE, bevel=0.0):
	bake_bm(bm)
	me = bpy.data.meshes.new(name); bm.to_mesh(me); bm.free()
	o = bpy.data.objects.new(name, me); TS.objects.link(o)
	ref = bpy.data.objects[like]
	o.parent = ref.parent; o.parent_type = ref.parent_type; o.parent_bone = ref.parent_bone
	o.matrix_world = Matrix.Identity(4)
	for m in mats:
		me.materials.append(M(m))
	return finish(o, bevel)

def loft_apex(rings, apex, cap0=True, mats=None):
	"""Loft closed rings to an apex. mats: per-section-edge material index list (applied to every band of faces)."""
	bm = bmesh.new()
	R = [[bm.verts.new(p) for p in r] for r in rings]
	n = len(rings[0])
	for a, c in zip(R[:-1], R[1:]):
		for i in range(n):
			f = bm.faces.new((a[i], a[(i + 1) % n], c[(i + 1) % n], c[i]))
			if mats:
				f.material_index = mats[i]
	ap = bm.verts.new(apex)
	for i in range(n):
		f = bm.faces.new((R[-1][i], R[-1][(i + 1) % n], ap))
		if mats:
			f.material_index = mats[i]
	if cap0:
		f = bm.faces.new(R[0][::-1])
		if mats:
			f.material_index = mats[0]
	return bm

# ============================== blade ==============================
XR, XT = 0.272, 3.100                          # blade root (buried in the tsuba, so the blade joins the hilt) and tip
def sz_at(x):                                   # spine line: rises toward the tip (sori), from straight segments
	u = max(0.0, (x - XR) / (XT - XR))
	return 0.066 + 0.150 * u ** 1.7
# stations: x, H (spine->edge), t (shinogi half-thickness), m (mune half-width), tb (steel bottom half-width),
#           W (water band height), fuller depth
ST = [(0.272, 0.136, 0.0215, 0.0105, 0.0100, 0.040, 0.0004), (0.400, 0.136, 0.0215, 0.0105, 0.0100, 0.040, 0.0030),
	(0.700, 0.133, 0.0205, 0.0100, 0.0096, 0.040, 0.0032), (1.050, 0.129, 0.0195, 0.0095, 0.0092, 0.039, 0.0032),
	(1.400, 0.125, 0.0185, 0.0090, 0.0088, 0.038, 0.0030), (1.750, 0.120, 0.0172, 0.0085, 0.0082, 0.036, 0.0028),
	(2.100, 0.115, 0.0160, 0.0080, 0.0077, 0.035, 0.0024), (2.420, 0.109, 0.0146, 0.0074, 0.0071, 0.034, 0.0012),
	(2.680, 0.102, 0.0134, 0.0068, 0.0065, 0.032, 0.0004), (2.860, 0.090, 0.0120, 0.0060, 0.0058, 0.029, 0.0004),
	(2.980, 0.064, 0.0098, 0.0050, 0.0047, 0.024, 0.0004), (3.050, 0.034, 0.0068, 0.0036, 0.0033, 0.016, 0.0004)]
F1, F2 = 0.16, 0.50                             # fuller from 16 % to 50 % down the flat
def frame(x, H, t, m, tb, W, d):
	sz = sz_at(x); ez = sz - H; zS = sz - 0.10 * H; zB = ez + W
	S = Vector((t, zS)); B = Vector((tb, zB))
	G1 = S + (B - S) * F1; G2 = S + (B - S) * F2
	dirv = (B - S).normalized(); nin = Vector((-dirv.y, dirv.x))    # in-plane normal of the flat, pointing inward (-y)
	if nin.x > 0:
		nin = -nin
	G1i = G1 + nin * d + dirv * d * 0.6; G2i = G2 + nin * d - dirv * d * 0.6
	return dict(sz=sz, ez=ez, zS=zS, zB=zB, S=S, B=B, G1=G1, G2=G2, G1i=G1i, G2i=G2i, m=m, t=t, tb=tb, W=W, d=d, nin=nin, dirv=dirv)
def steel_sec(x, *a):
	f = frame(x, *a)
	half = [(f["m"], f["sz"]), tuple(f["S"]), tuple(f["G1"]), tuple(f["G1i"]), tuple(f["G2i"]), tuple(f["G2"]), tuple(f["B"])]
	other = [(-y, z) for y, z in half[::-1]]
	return [(x, y, z) for y, z in half + other]
# section edge -> material (0 Dark recess, 1 Body matte black? use Dark for black, 2 Panel silver)
#   0:(m,sz)-S silver  1:S-G1 black  2,3,4 fuller  5:G2-B black  6:B-(-B) bottom  7:-B..-G2 black  8,9,10 fuller
#   11:-G1..-S black  12:-S..(-m,sz) silver  13:top mune silver
BLACK, FULL, SILV = 0, 1, 2
MATS = [SILV, BLACK, FULL, FULL, FULL, BLACK, FULL, BLACK, FULL, FULL, FULL, BLACK, SILV, SILV]
rings = [steel_sec(*s) for s in ST]
tipz = sz_at(XT) - 0.010
bm = loft_apex(rings, (XT - 0.012, 0.0, tipz + 0.004), mats=MATS)
blade = multi_obj("TS_Blade", bm, ["Dark", "Dark", "Metal"])   # sheet: matte black body, dark brushed-steel spine (not bright silver)
# etched lightning on the silver spine bevels (both sides), cyan floor
def st_at(x):
	for a, b in zip(ST[:-1], ST[1:]):
		if a[0] <= x <= b[0]:
			u = (x - a[0]) / (b[0] - a[0])
			return tuple(a[i] + (b[i] - a[i]) * u for i in range(1, 7))
	return ST[-1][1:]
def bevel_y(x, z):
	H, t, m, tb, W, d = st_at(x); f = frame(x, H, t, m, tb, W, d)
	k = (f["sz"] - z) / (f["sz"] - f["zS"])
	return m + (t - m) * max(0.0, min(1.0, k))
ZZ = [(0.46, 0.45), (0.60, 0.72), (0.74, 0.30), (0.90, 0.68), (1.06, 0.36), (1.22, 0.62), (1.36, 0.50)]   # (x, fraction down the bevel)
for s in (1, -1):
	pts = []
	for x, fr in ZZ:
		H, t, m, tb, W, d = st_at(x); f = frame(x, H, t, m, tb, W, d)
		pts.append((x, f["sz"] - fr * (f["sz"] - f["zS"])))
	half_w = 0.0016
	top = [(x, z + half_w) for x, z in pts]; bot = [(x, z - half_w) for x, z in pts[::-1]]
	bm = prism_xz(top + bot, 0.0, 1.0)
	for v in bm.verts:
		v.co.y = s * (bevel_y(v.co.x, v.co.z) - 0.0016) if v.co.y < 0.5 else s * 0.08
	boolean(blade, cutter("TS_CUT_Lightning%+d" % s, bm, "Neon"))
add_mat(blade, "Neon")

# fuller inlay (Neon), a thin strip on each fuller floor, recessed below the flats
def inlay_ring(x, a, s, w_=0.0062):
	f = frame(x, *a)
	G1i, G2i, nin, dirv = f["G1i"], f["G2i"], f["nin"], f["dirv"]
	F = (G1i + G2i) / 2
	nout = -nin
	pts = [F - dirv * w_ / 2 - nout * 0.0004, F + dirv * w_ / 2 - nout * 0.0004, F + dirv * w_ / 2 + nout * 0.0011, F - dirv * w_ / 2 + nout * 0.0011]
	return [(x, s * p.x, p.y) for p in pts]
INL = [s for s in ST if s[6] >= 0.0024]
bmi = bmesh.new()
for s in (1, -1):
	rings_i = [inlay_ring(st[0], st[1:], s) for st in INL]
	xe = INL[-1][0] + 0.10; ap = inlay_ring(xe, st_at(xe), s)
	apx = sum(p[0] for p in ap) / 4; apy = sum(p[1] for p in ap) / 4; apz = sum(p[2] for p in ap) / 4
	b2 = loft_apex(rings_i, (apx, apy * 0.97, apz))
	me_tmp = bpy.data.meshes.new("tmp"); b2.to_mesh(me_tmp); b2.free(); bmi.from_mesh(me_tmp); bpy.data.meshes.remove(me_tmp)
new_obj("TS_FullerInlay", bmi, "Neon", like=LIKE, bevel=0)

# water cutting edge: separate object along the whole edge, its top seated 0.006 up inside the steel, forming the point
def water_sec(x, H, t, m, tb, W, d):
	f = frame(x, H, t, m, tb, W, d)
	tw = 0.92 * tb; zt = f["zB"] + 0.006; ez = f["ez"]
	return [(x, tw, zt), (x, tw * 0.88, ez + 0.46 * W), (x, 0.0, ez), (x, -tw * 0.88, ez + 0.46 * W), (x, -tw, zt)]
wr = [water_sec(*s) for s in ST]
new_obj("WaterEdge", loft_apex(wr, (XT, 0.0, tipz)), "Water", like=LIKE, bevel=0)

# ============================== habaki, seppa, tsuba ==============================
h0 = frame(*ST[0])
hab = [(0.296, -0.080), (0.344, -0.077), (0.358, -0.066), (0.358, 0.064), (0.344, 0.074), (0.296, 0.078)]
bm = chamfer_prism_xz(hab, -0.0270, 0.0270, 0.004)
for v in bm.verts:
	if v.co.x > 0.34:
		v.co.y *= 0.84
new_obj("TS_Habaki", bm, "Metal", like=LIKE, bevel=EDGE)
new_obj("TS_Seppa", lathe([(0.290, 0.0), (0.290, 0.090), (0.298, 0.090), (0.298, 0.0)], 16, rot=0.0), "Panel", like=LIKE, bevel=0)
# cupped crescent tsuba: a dish whose rim curls toward the blade (crescent in side and top views, a disc from behind)
TSUBA = [(0.262, 0.0), (0.262, 0.050), (0.266, 0.092), (0.278, 0.122), (0.300, 0.146), (0.322, 0.160), (0.326, 0.155),
	(0.306, 0.137), (0.288, 0.114), (0.279, 0.086), (0.276, 0.050), (0.276, 0.0)]
new_obj("TS_Tsuba", lathe(TSUBA, 16, rot=0.0), "Metal", like=LIKE, bevel=EDGE)
new_obj("TS_TsubaFace", lathe([(0.2595, 0.0), (0.2595, 0.068), (0.2625, 0.068), (0.2625, 0.0)], 16, rot=0.0), "Panel", like=LIKE, bevel=0)

# ============================== tsuka: dark core + crossing leather bands ==============================
GX0, GX1 = -0.612, 0.236
def gsec(x, grow=0.0):
	u = (x - GX0) / (GX1 - GX0)
	hw = 0.0500 + 0.0040 * u + grow
	hh = 0.0600 + 0.0050 * u + grow
	k = 0.30 * min(hw, hh)
	return [(hw, -hh + k), (hw, hh - k), (hw - k, hh), (-hw + k, hh), (-hw, hh - k), (-hw, -hh + k), (-hw + k, -hh), (hw - k, -hh)]
xs = [GX0 + (GX1 - GX0) * i / 8 for i in range(9)]
new_obj("TS_GripCore", loft([ring_x(x, gsec(x)) for x in xs]), "Dark", like=LIKE, bevel=0)
P, Wb, K = 0.1040, 0.0420, 1.00
CX = [GX0 + 0.082 + P * i for i in range(8)]
for i, cx in enumerate(CX):
	for nm, tilt, g in (("U", -K, 0.0036), ("O", K, 0.0058)):
		new_obj("TS_GripBand%s%d" % (nm, i), loft([ring_tilt_x(gsec, cx - Wb / 2, tilt, g, 0.0), ring_tilt_x(gsec, cx + Wb / 2, tilt, g, 0.0)]), "Grip", like=LIKE, bevel=0)
def ferrule(name, x0, x1, g0, g1, ch=0.004):
	return new_obj(name, loft([ring_x(x0, gsec(x0, g0 - ch)), ring_x(x0 + ch, gsec(x0, g0)), ring_x(x1 - ch, gsec(x1, g1)), ring_x(x1, gsec(x1, g1 - ch))]),
		"Metal", like=LIKE, bevel=EDGE)
ferrule("TS_Kashira", -0.668, -0.600, 0.0084, 0.0092)
new_obj("TS_KashiraBand", loft([ring_x(-0.630, gsec(-0.630, 0.0102)), ring_x(-0.622, gsec(-0.622, 0.0102))]), "Panel", like=LIKE, bevel=0)
ferrule("TS_Fuchi", 0.222, 0.264, 0.0088, 0.0096)

# ============================== ring pommel (12 facets) + charm ==============================
RX, RIN, ROUT, RHY = -0.770, 0.066, 0.100, 0.0165
def ring_y(cx, cz, r_in, r_out, hy, c, n=12, rot=0.0):
	sec = [(r_in, -hy + c), (r_in, hy - c), (r_in + c, hy), (r_out - c, hy), (r_out, hy - c), (r_out, -hy + c), (r_out - c, -hy), (r_in + c, -hy)]
	bm = bmesh.new(); R = []
	for i in range(n):
		a = rot + 2 * math.pi * i / n
		R.append([bm.verts.new((cx + r * math.cos(a), y, cz + r * math.sin(a))) for r, y in sec])
	m_ = len(sec)
	for i in range(n):
		P_, Q = R[i], R[(i + 1) % n]
		for j in range(m_):
			bm.faces.new((P_[j], P_[(j + 1) % m_], Q[(j + 1) % m_], Q[j]))
	return bm
new_obj("TS_Ring", ring_y(RX, 0.0, RIN, ROUT, RHY, 0.0060, 12, math.pi / 12), "Metal", like=LIKE, bevel=EDGE)
new_obj("TS_RingNeck", chamfer_prism_xz([(-0.684, -0.024), (-0.664, -0.028), (-0.664, 0.028), (-0.684, 0.024)], -0.0135, 0.0135, 0.003), "Metal", like=LIKE, bevel=EDGE)
# charm: octagonal link resting on the ring's bottom band (its inner top touches the band), shuriken hanging below
band_top = -RIN * math.cos(math.pi / 12)          # ring flats: inner apothem at the bottom flat
LW, LH, LT = 0.0225, 0.0300, 0.0065               # link inner half-width (y), inner half-height (z), wire thickness
lcz = band_top - LH - 0.0008                      # the link wire rests on (and sinks 0.0008 into) the band top
def oct_loop(hw, hh, k):
	return [(hw, -hh + k), (hw, hh - k), (hw - k, hh), (-hw + k, hh), (-hw, hh - k), (-hw, -hh + k), (-hw + k, -hh), (hw - k, -hh)]
inner = [(y, lcz + z) for y, z in oct_loop(LW, LH, 0.010)]
outer = [(y, lcz + z) for y, z in oct_loop(LW + LT, LH + LT, 0.012)]
bm = bmesh.new()
for x0, x1 in ((RX - 0.0055, RX + 0.0055),):
	O0 = [bm.verts.new((x0, y, z)) for y, z in outer]; O1 = [bm.verts.new((x1, y, z)) for y, z in outer]
	I0 = [bm.verts.new((x0, y, z)) for y, z in inner]; I1 = [bm.verts.new((x1, y, z)) for y, z in inner]
	n_ = len(outer)
	for i in range(n_):
		j = (i + 1) % n_
		bm.faces.new((O0[i], O0[j], O1[j], O1[i])); bm.faces.new((I1[i], I1[j], I0[j], I0[i]))
		bm.faces.new((O0[j], O0[i], I0[i], I0[j])); bm.faces.new((O1[i], O1[j], I1[j], I1[i]))
new_obj("TS_CharmLink", bm, "Metal", like=LIKE, bevel=0)
link_bot = lcz - LH - LT
SR, SRI = 0.046, 0.013
scz = link_bot - SR + 0.004
star = []
for i in range(8):
	a = math.pi / 2 + i * math.pi / 4
	r = SR if i % 2 == 0 else SRI
	star.append((RX + r * math.cos(a), scz + r * math.sin(a)))
new_obj("TS_CharmShuriken", chamfer_prism_xz(star, -0.0040, 0.0040, 0.0016), "Panel", like=LIKE, bevel=0)
new_obj("TS_CharmHub", prism_xz(ngon(0.0085, 8, RX, scz, math.pi / 8), -0.0052, 0.0052), "Dark", like=LIKE, bevel=0)

bpy.context.view_layer.update()
rec = {"stations": [], "tip": [XT, round(tipz, 4)]}
for s in ST:
	f = frame(*s)
	rec["stations"].append([s[0], round(f["ez"], 4), round(f["sz"], 4), s[2]])
result = {"tris": tris(visible_model()), "parts": len(visible_model()), "charm_pivot": [RX, 0.0, round(band_top, 4)], "link_c": round(lcz, 4),
	"shuriken_c": round(scz, 4), "rec": rec}
