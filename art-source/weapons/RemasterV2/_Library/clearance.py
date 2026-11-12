# clearance.py: per-frame clip check for RemasterV2 animations (Blender MCP only). For each frame of an action,
# poses the rig, takes the evaluated world meshes of the moving parts and tests them against the static parts with a
# BVH overlap. Returns the frames (and the part pairs) where geometry intersects.
#   check(gun, action, movers=["RoundUpper"], statics=["Receiver", "Scope"], step=1)

import bpy
from mathutils.bvhtree import BVHTree


def _bvh(ob, dg):
	ev = ob.evaluated_get(dg)
	me = ev.to_mesh()
	mw = ev.matrix_world
	verts = [mw @ v.co for v in me.vertices]
	polys = [tuple(p.vertices) for p in me.polygons]
	ev.to_mesh_clear()
	return BVHTree.FromPolygons(verts, polys, epsilon=0.0)


def check(gun, action, movers, statics, step=1, frames=None):
	rig = bpy.data.objects[gun + "_Rig"]
	sc = bpy.context.window.scene
	ad = rig.animation_data
	act = bpy.data.actions[action]
	ad.action = act
	try:
		ad.action_slot = act.slots[0]
	except Exception:
		pass
	f0, f1 = int(act.frame_range[0]), int(act.frame_range[1])
	hits = {}
	for f in (frames or range(f0, f1 + 1, step)):
		sc.frame_set(f)
		dg = bpy.context.evaluated_depsgraph_get()
		st = {n: _bvh(bpy.data.objects[gun + "_" + n], dg) for n in statics}
		for m in movers:
			mb = _bvh(bpy.data.objects[gun + "_" + m], dg)
			for n, sb in st.items():
				ov = mb.overlap(sb)
				if ov:
					hits.setdefault(f, []).append("%s/%s:%d" % (m, n, len(ov)))
	ad.action = None
	sc.frame_set(1)
	return hits
