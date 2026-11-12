# final_edit.py: in-place mesh edits for the final pass (2026-11-11). Blender MCP only; used with final_pass.py.
#   E = ns of this file, F = ns of final_pass.py:  E["bind"](F)
#   E["kit"](gun)                         v2kit ready for booleans in the gun's scene
#   E["edit_part"](gun, part, drop, add)  remove loose islands by predicate, add finished pieces
#   E["new_part"](gun, part, pieces, bone)
# Every part is parented to its bone with an identity world matrix, so mesh space = world space at rest.

import bpy, bmesh, math
from mathutils import Vector, Matrix
from mathutils.bvhtree import BVHTree
import v2kit as K

F = {}


def bind(final_pass_ns):
	F.update(final_pass_ns)


def kit(gun):
	sc = F["scene"](gun)
	bpy.context.window.scene = sc
	scr = bpy.data.collections.get("_rv2_scratch_" + gun)
	if scr is None:
		scr = bpy.data.collections.new("_rv2_scratch_" + gun)
		sc.collection.children.link(scr)
	K._SCRATCH["col"] = scr
	K._SCRATCH["mats"] = [bpy.data.materials[r] for r in K.ROLES]
	return K


def drop_scratch(gun):
	scr = bpy.data.collections.get("_rv2_scratch_" + gun)
	if scr is not None:
		for o in list(scr.objects):
			bpy.data.objects.remove(o)
		bpy.data.collections.remove(scr)


def dedupe_materials():
	# Each appended gun file brought its own copies of the 8 role materials (Dark.001 ...): fold them into one set.
	n = 0
	for role in K.ROLES:
		base = bpy.data.materials.get(role)
		if base is None:
			dup = [m for m in bpy.data.materials if m.name.split(".")[0] == role]
			if not dup:
				continue
			base = dup[0]
			base.name = role
		for m in [m for m in bpy.data.materials if m is not base and m.name.split(".")[0] == role]:
			m.user_remap(base)
			bpy.data.materials.remove(m)
			n += 1
	return n


def islands(bm):
	bm.faces.ensure_lookup_table()
	seen, out = set(), []
	for f in bm.faces:
		if f.index in seen:
			continue
		st, fs = [f], []
		seen.add(f.index)
		while st:
			c = st.pop()
			fs.append(c)
			for e in c.edges:
				for n in e.link_faces:
					if n.index not in seen:
						seen.add(n.index)
						st.append(n)
		vs = {v for x in fs for v in x.verts}
		lo = Vector([min(v.co[i] for v in vs) for i in range(3)])
		hi = Vector([max(v.co[i] for v in vs) for i in range(3)])
		out.append((fs, lo, hi))
	return out


def part_islands(gun, part):
	ob = F["obj"](gun, part)
	bm = bmesh.new()
	bm.from_mesh(ob.data)
	out = []
	for fs, lo, hi in islands(bm):
		out.append({"role": K.ROLES[fs[0].material_index], "lo": [round(v, 4) for v in lo], "hi": [round(v, 4) for v in hi], "tris": len(fs)})
	bm.free()
	return out


def finish_piece(bm):
	# Same cleanup as v2kit.finish_mesh, on a loose piece (stays a bmesh).
	bmesh.ops.remove_doubles(bm, verts=bm.verts[:], dist=4e-4)
	bmesh.ops.dissolve_degenerate(bm, dist=1e-6, edges=bm.edges[:])
	bmesh.ops.dissolve_limit(bm, angle_limit=math.radians(0.3), verts=bm.verts[:], edges=bm.edges[:], delimit={"MATERIAL", "SHARP"})
	bmesh.ops.triangulate(bm, faces=bm.faces[:], quad_method="BEAUTY", ngon_method="BEAUTY")
	for _ in range(6):
		sl = [f for f in bm.faces if f.calc_area() < 1e-9]
		if not sl:
			break
		ed = [e for e in {max(f.edges, key=lambda e: e.calc_length()) for f in sl} if len(e.link_faces) == 2]
		if not ed:
			break
		bmesh.ops.rotate_edges(bm, edges=ed, use_ccw=False)
	bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
	return bm


def _flat(pieces):
	out = []
	for p in pieces:
		if isinstance(p, (list, tuple)):
			out += _flat(p)
		elif p is not None:
			out.append(p)
	return out


def edit_part(gun, part, drop=None, add=(), sharp=34):
	# drop(lo, hi, role, tris) -> True removes that loose island. add: bmesh pieces (nested lists allowed).
	ob = F["obj"](gun, part)
	me = ob.data
	bm = bmesh.new()
	bm.from_mesh(me)
	removed = 0
	if drop is not None:
		kill = []
		for fs, lo, hi in islands(bm):
			if drop(lo, hi, K.ROLES[fs[0].material_index], len(fs)):
				kill += fs
				removed += 1
		if kill:
			bmesh.ops.delete(bm, geom=kill, context="FACES")
	for piece in _flat(add):
		K.merge(bm, finish_piece(piece))
	bm.to_mesh(me)
	bm.free()
	me.shade_smooth()
	me.set_sharp_from_angle(angle=math.radians(sharp))
	me.update()
	return removed


def take_islands(gun, part, pick):
	# Removes the islands pick(lo, hi, role, tris) selects from a part and returns them as one bmesh (to move them
	# into another part, e.g. sight neon out of the shared Neon mesh).
	ob = F["obj"](gun, part)
	me = ob.data
	bm = bmesh.new()
	bm.from_mesh(me)
	keep, take = [], []
	for fs, lo, hi in islands(bm):
		(take if pick(lo, hi, K.ROLES[fs[0].material_index], len(fs)) else keep).append(fs)
	if not take:
		bm.free()
		return None
	out = K.copy(bm)
	out.faces.ensure_lookup_table()
	idx_take = {f.index for fs in take for f in fs}
	bmesh.ops.delete(out, geom=[f for f in out.faces if f.index not in idx_take], context="FACES")
	bmesh.ops.delete(bm, geom=[f for fs in take for f in fs], context="FACES")
	bm.to_mesh(me)
	bm.free()
	me.update()
	return out


def new_part(gun, part, pieces, bone="Root"):
	kit(gun)
	bm = bmesh.new()
	for piece in _flat(pieces):
		K.merge(bm, finish_piece(piece))
	me = bpy.data.meshes.new(gun + "_" + part)
	bm.to_mesh(me)
	bm.free()
	for r in K.ROLES:
		me.materials.append(bpy.data.materials[r])
	me.shade_smooth()
	me.set_sharp_from_angle(angle=math.radians(34))
	ob = bpy.data.objects.new(gun + "_" + part, me)
	F["col"](gun).objects.link(ob)
	wn = ob.modifiers.new("WeightedNormal", "WEIGHTED_NORMAL")
	wn.keep_sharp = True
	wn.weight = 60
	K.parent_to_bone(ob, bpy.data.objects[gun + "_Rig"], bone, Matrix.Identity(4))
	return ob


def top_z(gun, x, y=0.0, skip=("Sight", "Neon"), bones=("Root",)):
	# Height of the surface under (x, y), ignoring sight and neon parts.
	best = None
	for o in F["meshes"](gun):
		if o.parent_bone not in bones or any(s in o.name for s in skip):
			continue
		co = [o.matrix_world @ v.co for v in o.data.vertices]
		t = BVHTree.FromPolygons(co, [list(p.vertices) for p in o.data.polygons])
		h = t.ray_cast(Vector((x, y, 3.0)), Vector((0, 0, -1)), 6.0)
		if h[0] is not None and (best is None or h[0].z > best):
			best = h[0].z
	return best
