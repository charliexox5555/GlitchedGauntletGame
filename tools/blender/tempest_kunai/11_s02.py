# Tempest-Strike Kunai-Katana s02 (on s01), matched closer to the owner's sheet: the kunai leaf broader than the grip
# (max half-height 0.060 -> 0.076, thicker spine), its crack re-cut on the new faces, and the water blade wider near
# the kunai (it sheathes the kunai's front third, like the sheet) tapering to the same sharp tip.
import bpy
GUN = "Knife"
bpy.ops.wm.open_mainfile(filepath=r"C:/Users/charl/Documents/GauntletGame/GlitchedGauntletGame/art-source/weapons/Skins/TempestStrike/Knife/s01/Knife_TempestStrike_s01.blend")
exec(open(r"C:/Users/charl/Documents/GauntletGame/GlitchedGauntletGame/tools/blender/tempest_line/ts_lib.py").read())
LIKE = "Knife_Hilt"
for n in ("TS_KunaiBlade", "TS_KunaiEdge", "WaterKatana", "TS_CUT_Crack+1", "TS_CUT_Crack-1"):
	kill(n)
KX = [(0.305, 0.030, 0.021), (0.330, 0.034, 0.022), (0.455, 0.076, 0.025), (0.640, 0.038, 0.015), (0.820, 0.0015, 0.0012)]
def dia(x, h, t):
	return [(x, 0.0, h), (x, t, 0.0), (x, 0.0, -h), (x, -t, 0.0)]
core = new_obj("TS_KunaiBlade", loft([dia(x, h * 0.80, t) for x, h, t in KX]), "Dark", like=LIKE, bevel=0)
EX = [(KX[0][0] + 0.003,) + KX[0][1:]] + KX[1:-1] + [(KX[-1][0] + 0.003,) + KX[-1][1:]]
new_obj("TS_KunaiEdge", loft([dia(x, h, t * 0.40) for x, h, t in EX]), "Panel", like=LIKE, bevel=0)
def t_at(x):
	for (x0, h0, t0), (x1, h1, t1) in zip(KX[:-1], KX[1:]):
		if x0 <= x <= x1:
			return t0 + (t1 - t0) * (x - x0) / (x1 - x0)
	return KX[-1][2]
ZZ = [(0.360, 0.000), (0.425, 0.010), (0.480, -0.007), (0.540, 0.009), (0.595, -0.005), (0.655, 0.004), (0.705, 0.000)]
for s in (1, -1):
	top = [(x, z + 0.0022) for x, z in ZZ]; bot = [(x, z - 0.0022) for x, z in ZZ[::-1]]
	bm = prism_xz(top + bot, 0.0, 1.0)
	for v in bm.verts:
		v.co.y = s * (t_at(v.co.x) - 0.0026) if v.co.y < 0.5 else s * 0.06
	boolean(core, cutter("TS_CUT_Crack%+d" % s, bm, "Neon"))
add_mat(core, "Neon")
WX = [(0.700, 0.024, 0.0090), (0.820, 0.040, 0.0125), (0.980, 0.046, 0.0140), (1.300, 0.042, 0.0128), (1.650, 0.034, 0.0110),
	(1.950, 0.022, 0.0075), (2.115, 0.010, 0.0038), (2.170, 0.0008, 0.0006)]
def zc(x):
	u = max(0.0, (x - 0.82) / 1.35)
	return 0.050 * u * u
new_obj("WaterKatana", loft([[(x, y, z + zc(x)) for x, y, z in dia(x, h, t)] for x, h, t in WX]), "Water", like=LIKE, bevel=0)
bpy.context.view_layer.update()
result = {"tris": tris(visible_model()), "parts": len(visible_model())}
