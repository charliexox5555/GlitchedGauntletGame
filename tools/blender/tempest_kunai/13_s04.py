# Tempest-Strike Kunai-Katana s04 (on s03). Owner on s03: "looking a lot better; the kunai part should be bigger (the
# root), and the katana should come out of it like the reference; the connection is too thin". So:
#   - kunai blade bigger: wider shoulder (half-height 0.074 -> 0.088), longer (tip x 0.832 -> 0.935), thicker spine
#   - the water katana grows out of the kunai's body: it starts hugging the kunai's front half (its own kunai-shaped
#     section, a little fuller), stays as wide as the kunai shoulder where it leaves the point, then runs out to the
#     katana tip. Its root is as broad as the kunai, not a thin neck.
#   - review-only translucent water (hologram preview); the flat export still reads plain cyan (Studio makes the water)
import bpy
GUN = "Knife"
bpy.ops.wm.open_mainfile(filepath=r"C:/Users/charl/Documents/GauntletGame/GlitchedGauntletGame/art-source/weapons/Skins/TempestStrike/Knife/s03/Knife_TempestStrike_s03.blend")
exec(open(r"C:/Users/charl/Documents/GauntletGame/GlitchedGauntletGame/tools/blender/tempest_line/ts_lib.py").read())
LIKE = "Knife_Hilt"
for n in ("TS_KunaiBlade", "WaterKatana", "TS_CUT_Crack+1", "TS_CUT_Crack-1"):
	kill(n)

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

def loft_apex(rings, apex, cap0=True):
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

# ======================= kunai blade (bigger root) =======================
KX = [(0.330, 0.0240, 0.0150), (0.364, 0.0240, 0.0150), (0.398, 0.0700, 0.0178), (0.420, 0.0880, 0.0190), (0.446, 0.0875, 0.0188),
	(0.900, 0.0090, 0.0032)]
TIP = (0.935, 0.0, 0.0)
def ksec(x, h, t, hbr=0.76, tbr=0.32, c=0.0):
	hb, tb = hbr * h, tbr * t
	return [(x, 0.0, c + h), (x, tb, c + hb), (x, t, c), (x, tb, c - hb), (x, 0.0, c - h), (x, -tb, c - hb), (x, -t, c), (x, -tb, c + hb)]
bm = loft_apex([ksec(*k) for k in KX], TIP)
BEVEL_IDX = {0, 3, 4, 7}
bm.faces.ensure_lookup_table()
fi = 0
for s_ in range(len(KX)):
	for i in range(8):
		bm.faces[fi].material_index = 1 if i in BEVEL_IDX else 0
		fi += 1
kb = multi_obj("TS_KunaiBlade", bm, ["Dark", "Panel"])
def k_at(x):
	for (x0, h0, t0), (x1, h1, t1) in zip(KX[:-1], KX[1:]):
		if x0 <= x <= x1:
			u = (x - x0) / (x1 - x0)
			return h0 + (h1 - h0) * u, t0 + (t1 - t0) * u
	return KX[-1][1], KX[-1][2]
# etched lightning crack on the visible (solid) root of the blade
ZZ = [(0.430, 0.0), (0.480, 0.0100), (0.535, -0.0065), (0.590, 0.0080), (0.645, -0.0040), (0.695, 0.0025), (0.730, 0.0)]
for s in (1, -1):
	top = [(x, z + 0.0020 * (1 - (x - 0.43) / 0.4)) for x, z in ZZ]; bot = [(x, z - 0.0020 * (1 - (x - 0.43) / 0.4)) for x, z in ZZ[::-1]]
	bm = prism_xz(top + bot, 0.0, 1.0)
	for v in bm.verts:
		v.co.y = s * (k_at(v.co.x)[1] - 0.0024) if v.co.y < 0.5 else s * 0.06
	boolean(kb, cutter("TS_CUT_Crack%+d" % s, bm, "Neon"))
add_mat(kb, "Neon")

# ======================= water katana grows out of the kunai =======================
XJ = 0.760                                   # where the water sleeve starts: most of the kunai stays solid black
hj, tj = k_at(XJ)
WTIP_X = 2.330
def zc(x):
	u = max(0.0, (x - 0.95) / (WTIP_X - 0.95))
	return 0.055 * u * u
WX = [(XJ, hj + 0.0022, tj + 0.0018), (0.800, 0.0480, 0.0136), (0.860, 0.0580, 0.0156),           # bursts out wide from the kunai
	(0.935, 0.0610, 0.0162), (1.100, 0.0590, 0.0157), (1.350, 0.0548, 0.0147), (1.600, 0.0482, 0.0130), (1.850, 0.0392, 0.0106),
	(2.050, 0.0290, 0.0080), (2.200, 0.0180, 0.0052), (2.290, 0.0085, 0.0026)]
new_obj("WaterKatana", loft_apex([ksec(x, h, t, 0.70, 0.40, zc(x)) for x, h, t in WX], (WTIP_X, 0.0, zc(WTIP_X) + 0.004)), "Water", like=LIKE, bevel=0)

# review-only translucency (hologram preview); flat export ignores alpha
w = M("Water")
bsdf = w.node_tree.nodes.get("Principled BSDF")
bsdf.inputs["Alpha"].default_value = 0.55
for attr, val in (("surface_render_method", "BLENDED"), ("blend_method", "BLEND"), ("use_backface_culling", False), ("show_transparent_back", False)):
	try:
		setattr(w, attr, val)
	except (AttributeError, TypeError):
		pass

bpy.context.view_layer.update()
result = {"tris": tris(visible_model()), "parts": len(visible_model()), "junction": [XJ, round(hj, 4), round(tj, 4)]}
