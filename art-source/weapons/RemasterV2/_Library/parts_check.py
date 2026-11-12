# parts_check.py: finds floating parts on a RemasterV2 weapon at rest (Blender MCP only). Every loose island of every
# mesh in the gun's collection must touch or sit inside another island (gap <= tol). An island whose nearest
# neighbour is further away is reported: it floats (or is misaligned off its seat).
#   check(gun, tol=0.0025) -> {"islands": n, "floating": [{"part", "center", "size", "gap"}]}

import bpy, bmesh
from mathutils import Vector
from mathutils.bvhtree import BVHTree


def _islands(ob, dg):
	ev = ob.evaluated_get(dg)
	me = ev.to_mesh()
	bm = bmesh.new()
	bm.from_mesh(me)
	ev.to_mesh_clear()
	bm.transform(ob.matrix_world)
	bm.faces.ensure_lookup_table()
	seen, out = set(), []
	for f in bm.faces:
		if f.index in seen:
			continue
		stack, faces = [f], []
		seen.add(f.index)
		while stack:
			c = stack.pop()
			faces.append(c)
			for e in c.edges:
				for n in e.link_faces:
					if n.index not in seen:
						seen.add(n.index)
						stack.append(n)
		verts = list({v for fc in faces for v in fc.verts})
		vi = {v: i for i, v in enumerate(verts)}
		co = [v.co.copy() for v in verts]
		polys = [[vi[v] for v in fc.verts] for fc in faces]
		out.append((co, polys))
	bm.free()
	return out


def check(gun, tol=0.0025):
	rig = bpy.data.objects.get(gun + "_Rig")
	if rig is not None and rig.animation_data:
		rig.animation_data.action = None
	if rig is not None:
		for pb in rig.pose.bones:
			pb.location = (0, 0, 0)
			pb.rotation_euler = (0, 0, 0)
	bpy.context.view_layer.update()
	dg = bpy.context.evaluated_depsgraph_get()
	isl = []
	for ob in bpy.data.collections[gun].objects:
		if ob.type != "MESH":
			continue
		for co, polys in _islands(ob, dg):
			isl.append((ob.name[len(gun) + 1:], co, BVHTree.FromPolygons(co, polys)))
	floating = []
	for i, (name, co, tree) in enumerate(isl):
		lo = Vector((min(c.x for c in co), min(c.y for c in co), min(c.z for c in co)))
		hi = Vector((max(c.x for c in co), max(c.y for c in co), max(c.z for c in co)))
		best = 9.0
		for j, (n2, co2, t2) in enumerate(isl):
			if j == i:
				continue
			if tree.overlap(t2):
				best = 0.0
				break
			for c in co[:: max(1, len(co) // 40)]:
				hit = t2.find_nearest(c)
				if hit[0] is not None and hit[3] < best:
					best = hit[3]
			if best <= tol:
				break
		if best > tol:
			floating.append({"part": name, "center": [round(v, 3) for v in (lo + hi) / 2], "size": [round(v, 3) for v in hi - lo], "gap": round(best, 4)})
	return {"islands": len(isl), "floating": floating}
