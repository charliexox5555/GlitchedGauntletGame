# Tempest-Strike Vandal: safe triangle reduction. Run LAST (after stages A-F).
#  - drop boolean modifiers whose cutter was deleted by a later rebuild (empty slots)
#  - bake the port / vent cuts into the brake and handguard, then merge coplanar triangles (1 degree)
#  - remove the hairline bevel on the fluted barrel sleeves (crisp edges either way)
import bpy, bmesh, math
before = {}
dg = bpy.context.evaluated_depsgraph_get()
def tris(o):
	ev = o.evaluated_get(bpy.context.evaluated_depsgraph_get()); me = ev.to_mesh()
	n = sum(len(p.vertices) - 2 for p in me.polygons); ev.to_mesh_clear(); return n
out = {}
for name in ("TSC_Brake", "TSE_Handguard"):
	o = bpy.data.objects.get(name)
	if not o:
		continue
	b0 = tris(o)
	for m in list(o.modifiers):
		if m.type == "BOOLEAN" and m.object is None:
			o.modifiers.remove(m)
	bpy.context.view_layer.objects.active = o
	for m in [m.name for m in o.modifiers if m.type == "BOOLEAN"]:
		with bpy.context.temp_override(object=o, active_object=o):
			bpy.ops.object.modifier_apply(modifier=m)
	bm = bmesh.new(); bm.from_mesh(o.data)
	bmesh.ops.dissolve_limit(bm, angle_limit=math.radians(1.0), verts=bm.verts[:], edges=bm.edges[:],
		delimit={"MATERIAL"})
	bm.to_mesh(o.data); bm.free()
	out[name] = (b0, tris(o))
for name in ("TSC_Shroud", "TSC_ShroudFwd"):
	o = bpy.data.objects.get(name)
	if o:
		b0 = tris(o)
		for m in list(o.modifiers):
			if m.type == "BEVEL":
				o.modifiers.remove(m)
		out[name] = (b0, tris(o))
bpy.ops.wm.save_mainfile()
result = out
