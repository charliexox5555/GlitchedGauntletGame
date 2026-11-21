# Tempest-Strike Vandal: final polish. Run after stage F, before 51_optimize.
# Top cover: the stock rail's stepped front stop is cut off with a raked plane, so the cover ends in a blade.
import bpy, bmesh, math
from mathutils import Vector
tc = bpy.data.objects["TS_TopCover"]
if not tc.get("raked"):
	bm = bmesh.new(); bm.from_mesh(tc.data); mw = tc.matrix_world; bm.transform(mw)
	n = Vector((0.55, 0, 0.835)).normalized()
	bmesh.ops.bisect_plane(bm, geom=bm.verts[:] + bm.edges[:] + bm.faces[:], plane_co=(1.470, 0, 0.400), plane_no=n, clear_outer=True)
	bnd = [e for e in bm.edges if e.is_boundary]
	if bnd:
		bmesh.ops.holes_fill(bm, edges=bnd, sides=0)
	bnd = [e for e in bm.edges if e.is_boundary]
	if bnd:
		bmesh.ops.triangle_fill(bm, use_beauty=True, edges=bnd)
	bm.transform(mw.inverted()); bm.to_mesh(tc.data); bm.free()
	tc["raked"] = True
bpy.ops.wm.save_mainfile()
result = {"ok": True}
