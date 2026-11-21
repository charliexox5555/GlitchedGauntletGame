# Tempest-Strike Marshal s02 (on s01): lever arm buried into the loop (and its z-fighting edge strip dropped), a raked
# skeleton window through the butt with a dark liner, a silver comb blade along the stock top.
import bpy
GUN = "Marshal"
bpy.ops.wm.open_mainfile(filepath=r"C:/Users/charl/Documents/GauntletGame/GlitchedGauntletGame/art-source/weapons/Skins/TempestStrike/Marshal/s01/Marshal_TempestStrike_s01.blend")
exec(open(r"C:/Users/charl/Documents/GauntletGame/GlitchedGauntletGame/tools/blender/tempest_line/ts_lib.py").read())
purge(("TS2_",))
kill("TS_LeverEdge"); kill("TS_LeverArm")
ARM = [(0.183, -0.126), (0.300, -0.140), (0.420, -0.136), (0.500, -0.100), (0.540, -0.030), (0.560, -0.002), (0.594, -0.018),
	(0.586, -0.078), (0.522, -0.130), (0.420, -0.162), (0.300, -0.166), (0.183, -0.157)]
new_obj("TS_LeverArm", prism_xz(ARM, -0.016, 0.016), "Metal", like="Marshal_Lever")
st = bpy.data.objects["TS_Stock"]
boolean(st, cutter("TS2_CUT_Window", prism_xz([(-1.060, -0.232), (-0.660, -0.232), (-0.590, -0.142), (-0.990, -0.142)], -0.2, 0.2)))
add_mat(st, "Dark")
TOP = [(0.176, 0.214), (0.100, 0.208), (0.000, 0.169), (-0.100, 0.130), (-0.200, 0.091), (-0.320, 0.072), (-1.180, 0.058), (-1.240, 0.066)]
def interp(pl, x):
	pl = sorted(pl)
	for (x0, z0), (x1, z1) in zip(pl[:-1], pl[1:]):
		if x0 <= x <= x1:
			return z0 + (z1 - z0) * (x - x0) / (x1 - x0)
	return pl[0][1] if x < pl[0][0] else pl[-1][1]
bm = prism_xy([(-0.400, -0.017), (-1.120, -0.017), (-1.180, 0.0), (-1.120, 0.017), (-0.400, 0.017), (-0.340, 0.0)], 0.0, 1.0)
for v in bm.verts:
	v.co.z = interp(TOP, v.co.x) + (0.0042 if v.co.z > 0.5 else -0.0015)
new_obj("TS2_CombBlade", bm, "Panel", like="Marshal_Stock", bevel=0)
# wrist conduits: regrown so their keel faces clear the stock surface (audit: 1 coplanar face each)
BOT = [(-1.240, -0.296), (-1.120, -0.292), (-0.400, -0.2645), (-0.200, -0.1517), (-0.100, -0.0998), (0.000, -0.0736), (0.100, -0.0593), (0.176, -0.049)]
def hw_at(x):
	return 0.052 + (0.066 - 0.052) * max(0.0, min(1.0, (-x - 0.20) / 0.30))
def wrist_sec(x, grow=0.0):
	zt, zb, hw = interp(TOP, x), interp(BOT, x), hw_at(x); k = 0.009
	return sec_grow([(hw, zb + k), (hw, zt - k), (hw - k, zt), (-hw + k, zt), (-hw, zt - k), (-hw, zb + k), (-hw + k, zb), (hw - k, zb)], grow)
for i, x0 in enumerate((-0.246, -0.172, -0.098)):
	kill("TS_WristHydro%d" % i)
	new_obj("TS_WristHydro%d" % i, loft([ring_tilt_x(wrist_sec, x0 + 0.063, -0.30, 0.0024, 0.05), ring_tilt_x(wrist_sec, x0 + 0.068, -0.30, 0.0024, 0.05)]), "Neon", like="Marshal_Stock", bevel=0)
bpy.context.view_layer.update()
result = {"tris": tris(visible_model()), "parts": len(visible_model())}
