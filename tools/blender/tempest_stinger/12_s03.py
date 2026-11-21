# Tempest-Strike Stinger s03 (on s02). Owner playtest 2026-11-22: "the action has a glitching part of it".
# Cause (tempest_line/50_action_audit.py over every stock action): TS_BoltHydro, a 0.0017-thick cyan strip glued to the
# OUTSIDE of the bolt face, rides the Bolt bone; on every shot (Stinger_Fire frames 2-4) the bolt slides back and the
# strip slides into the receiver wall at the ejection port -> a cyan sliver clipping/flickering through the receiver.
# Fix: the strip is gone; the hydro line is now a shallow groove cut INTO the bolt face (cyan floor), so it never leaves
# the bolt's own volume. Vent plates: the owner disliked them flaring and the runtime no longer animates them, so their
# recess shadow gap tightens 0.003 -> 0.0015 (they read as fixed inlays) and the TS_VentL/R bones are dropped at export.
import bpy
GUN = "Stinger"
bpy.ops.wm.open_mainfile(filepath=r"C:/Users/charl/Documents/GauntletGame/GlitchedGauntletGame/art-source/weapons/Skins/TempestStrike/Stinger/s02/Stinger_TempestStrike_s02.blend")
exec(open(r"C:/Users/charl/Documents/GauntletGame/GlitchedGauntletGame/tools/blender/tempest_line/ts_lib.py").read())
purge(("TS3_",))
kill("TS_BoltHydro")
bolt = bpy.data.objects["TS_Bolt"]
boolean(bolt, cutter("TS3_CUT_BoltLine", prism_xz([(-0.060, 0.2885), (0.120, 0.2885), (0.132, 0.2900), (0.120, 0.2915), (-0.060, 0.2915)], -0.090, -0.0746), "Neon"))
add_mat(bolt, "Neon")
# tighter recess round the (now fixed) receiver blade plates
BLADE = [(-0.468, 0.252), (-0.420, 0.232), (0.440, 0.232), (0.762, 0.258), (0.700, 0.272), (-0.420, 0.272)]
for s in (1, -1):
	c = bpy.data.objects["TS_CUT_Recess%+d" % s]
	y0, y1 = (0.074, 0.095) if s > 0 else (-0.095, -0.074)
	bm = prism_xz(poly_offset(BLADE, 0.0015), y0, y1)
	bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
	bm.to_mesh(c.data); bm.free(); c.data.update()
bpy.context.view_layer.update()
result = {"tris": tris(visible_model()), "parts": len(visible_model())}
