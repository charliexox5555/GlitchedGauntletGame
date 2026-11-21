# Tempest-Strike Kunai-Katana s01 (melee) on the STOCK RemasterV2 Knife v05: same rig (Root), hand origin (RightGrip),
# BladeBase / BladeTip locators kept. Built to the owner's sheet (2026-11-22, pasted in chat): ring pommel with its hole
# facing the side, steel collar, leather grip with a row of dark diamond windows, round disc guard, matte-black
# diamond-section kunai blade with brushed-silver bevel edges and an etched lightning crack, and a separate long,
# thin water katana blade (TS Water) about three kunai lengths, slight curve, sharp faceted tip.
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
b.inputs["Emission Color"].default_value = lin("#40F5D4"); b.inputs["Emission Strength"].default_value = 0.4   # < 0.5: flat export stays SmoothPlastic
w.diffuse_color = lin("#40F5D4")

# ---------------- ring pommel: 12-sided square-section ring with flat chamfers, hole facing the side ----------------
RX = -0.385
def ring_y(cx, cz, r_in, r_out, hy, c, n=12):
	sec = [(r_in, -hy + c), (r_in, hy - c), (r_in + c, hy), (r_out - c, hy), (r_out, hy - c), (r_out, -hy + c), (r_out - c, -hy), (r_in + c, -hy)]
	bm = bmesh.new(); R = []
	for i in range(n):
		a = math.pi / n + 2 * math.pi * i / n
		R.append([bm.verts.new((cx + r * math.cos(a), y, cz + r * math.sin(a))) for r, y in sec])
	m = len(sec)
	for i in range(n):
		A, B = R[i], R[(i + 1) % n]
		for j in range(m):
			bm.faces.new((A[j], A[(j + 1) % m], B[(j + 1) % m], B[j]))
	return bm
new_obj("TS_Ring", ring_y(RX, 0.0, 0.066, 0.102, 0.022, 0.008), "Panel", like=LIKE, bevel=0)
# ---------------- collar ----------------
new_obj("TS_Collar", lathe([(-0.300, 0.0), (-0.300, 0.056), (-0.291, 0.068), (-0.245, 0.068), (-0.236, 0.059), (-0.236, 0.0)], 8, rot=math.pi / 8), "Metal", like=LIKE, bevel=0)
# ---------------- grip: leather shell, recessed dark diamond windows (the crossed wrap reads between them) ----------------
grip = new_obj("TS_Grip", loft([ring_x(-0.244, octo(0.058, 0.064, 0.18)), ring_x(0.298, octo(0.058, 0.064, 0.18))]), "Grip", like=LIKE, bevel=0)
for s in (1, -1):
	for i, x in enumerate((-0.172, -0.076, 0.020, 0.116, 0.212)):
		d = [(x - 0.040, 0.0), (x, 0.031), (x + 0.040, 0.0), (x, -0.031)]
		y0, y1 = (0.0525, 0.09) if s > 0 else (-0.09, -0.0525)
		boolean(grip, cutter("TS_CUT_Diamond%d%+d" % (i, s), prism_xz(d, y0, y1)))
for i, x in enumerate((-0.124, -0.028, 0.068, 0.164)):      # top and bottom: small diamonds between the side ones
	d = [(x - 0.030, 0.0), (x, 0.022), (x + 0.030, 0.0), (x, -0.022)]
	for s in (1, -1):
		bm = prism_xy(d, 0.059 if s > 0 else -0.09, 0.09 if s > 0 else -0.059)
		boolean(grip, cutter("TS_CUT_DiamondV%d%+d" % (i, s), bm))
add_mat(grip, "Dark")
# ---------------- disc guard: 12-sided steel disc with chamfered rims ----------------
new_obj("TS_Guard", lathe([(0.290, 0.0), (0.290, 0.118), (0.298, 0.134), (0.318, 0.134), (0.326, 0.118), (0.326, 0.0)], 12), "Metal", like=LIKE, bevel=0)
new_obj("TS_GuardFace", lathe([(0.3255, 0.0), (0.3255, 0.090), (0.3285, 0.090), (0.3285, 0.0)], 12), "Panel", like=LIKE, bevel=0)

# ---------------- kunai blade: diamond section (raised centre spine), silver bevel edges, lightning crack ----------------
KX = [(0.305, 0.028, 0.020), (0.330, 0.031, 0.021), (0.440, 0.060, 0.022), (0.620, 0.031, 0.013), (0.800, 0.0015, 0.0012)]
def dia(x, h, t):
	return [(x, 0.0, h), (x, t, 0.0), (x, 0.0, -h), (x, -t, 0.0)]
core = new_obj("TS_KunaiBlade", loft([dia(x, h * 0.80, t) for x, h, t in KX]), "Dark", like=LIKE, bevel=0)
EX = [(KX[0][0] + 0.003,) + KX[0][1:]] + KX[1:-1] + [(KX[-1][0] + 0.003,) + KX[-1][1:]]   # own base and tip planes (no shared cap faces)
new_obj("TS_KunaiEdge", loft([dia(x, h, t * 0.40) for x, h, t in EX]), "Panel", like=LIKE, bevel=0)
def t_at(x):
	for (x0, h0, t0), (x1, h1, t1) in zip(KX[:-1], KX[1:]):
		if x0 <= x <= x1:
			return t0 + (t1 - t0) * (x - x0) / (x1 - x0)
	return KX[-1][2]
ZZ = [(0.360, 0.000), (0.420, 0.009), (0.470, -0.006), (0.530, 0.008), (0.580, -0.004), (0.640, 0.004), (0.690, 0.000)]
for s in (1, -1):
	top = [(x, z + 0.0022) for x, z in ZZ]; bot = [(x, z - 0.0022) for x, z in ZZ[::-1]]
	bm = prism_xz(top + bot, 0.0, 1.0)
	for v in bm.verts:
		v.co.y = s * (t_at(v.co.x) - 0.0026) if v.co.y < 0.5 else s * 0.06
	boolean(core, cutter("TS_CUT_Crack%+d" % s, bm, "Neon"))
add_mat(core, "Neon")

# ---------------- water katana: separate long thin blade from the kunai tip, slight curve, faceted sharp tip ----------------
WX = [(0.660, 0.020, 0.0080), (0.800, 0.031, 0.0115), (0.960, 0.036, 0.0130), (1.300, 0.035, 0.0122), (1.650, 0.030, 0.0105),
	(1.950, 0.020, 0.0070), (2.110, 0.009, 0.0035), (2.165, 0.0008, 0.0006)]
def zc(x):
	u = max(0.0, (x - 0.80) / 1.365)
	return 0.048 * u * u
new_obj("WaterKatana", loft([[(x, y, z + zc(x)) for x, y, z in dia(x, h, t)] for x, h, t in WX]), "Water", like=LIKE, bevel=0)

bpy.context.view_layer.update()
result = {"tris": tris(visible_model()), "parts": len(visible_model())}
