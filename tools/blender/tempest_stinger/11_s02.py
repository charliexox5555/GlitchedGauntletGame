# Tempest-Strike Stinger s02 (on s01): the stock flat top rib becomes a raked faceted spine (lean-in top planes,
# raked front and rear ends, storm-blue side inlays); the top blade rides the spine; the stock receiver's open
# front edges are closed. Save with tempest_line/30_sheet.py TAG s02.
import bpy
GUN = "Stinger"
bpy.ops.wm.open_mainfile(filepath=r"C:/Users/charl/Documents/GauntletGame/GlitchedGauntletGame/art-source/weapons/Skins/TempestStrike/Stinger/s01/Stinger_TempestStrike_s01.blend")
exec(open(r"C:/Users/charl/Documents/GauntletGame/GlitchedGauntletGame/tools/blender/tempest_line/ts_lib.py").read())
purge(("TS2_",))
rec = bpy.data.objects["TS_Receiver"]
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
	vs = {v for g in grp for v in g.verts}
	if min(v.co.z for v in vs) > 0.383 and max(v.co.x for v in vs) > 0.5:
		kill_f += grp
bmesh.ops.delete(bm, geom=kill_f, context="FACES")
bnd = [e for e in bm.edges if e.is_boundary]
if bnd:
	bmesh.ops.holes_fill(bm, edges=bnd, sides=0)
bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
write_bm(rec, bm)

def sp(x, hw, top, base=0.380, k=0.62):
	return ring_x(x, [(hw, base), (hw, top - 0.012), (hw * k, top), (-hw * k, top), (-hw, top - 0.012), (-hw, base)])
new_obj("TS2_Spine", loft([sp(-0.506, 0.046, 0.410), sp(-0.470, 0.052, 0.432), sp(0.460, 0.052, 0.432),
	sp(0.565, 0.044, 0.398), sp(0.585, 0.040, 0.390, 0.380)]), "Body", bevel=0)
for s in (1, -1):
	y0, y1 = (0.0515, 0.0532) if s > 0 else (-0.0532, -0.0515)
	new_obj("TS2_SpineInlay%+d" % s, prism_xz([(-0.420, 0.4045), (0.400, 0.4045), (0.440, 0.4075), (0.400, 0.4105), (-0.420, 0.4105), (-0.440, 0.4075)], y0, y1), "Accent", bevel=0)
kill("TS_TopBlade")
new_obj("TS2_TopBlade", prism_xy([(-0.340, -0.016), (0.400, -0.016), (0.490, 0.0), (0.400, 0.016), (-0.340, 0.016), (-0.362, 0.0)], 0.4305, 0.4355), "Panel", bevel=0)
bpy.context.view_layer.update()
result = {"tris": tris(visible_model()), "parts": len(visible_model()), "open": sum(1 for e in rec.data.edges if False)}
