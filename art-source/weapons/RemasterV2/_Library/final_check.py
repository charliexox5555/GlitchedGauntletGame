# final_check.py: export-readiness audit of a saved RemasterV2 weapon file (Blender MCP only). Appends the gun's
# collection from <Gun>_RemasterV2_<ver>.blend into a temporary scene, checks every mesh for what breaks or degrades
# a Roblox MeshPart import or a clean Blender edit, then removes everything it appended.
#   audit(gun, ver="v03") -> {"ok": bool, "issues": [...], "stats": {...}}
# Mesh checks: triangulated (no quads/n-gons), no degenerate faces, no zero-length edges, no loose verts/edges, no
# edges shared by 3+ faces, no duplicate verts, closed islands wound outward (positive volume), UVs present and inside
# 0-1 with no zero-area UV tris, only the 8 shared material roles, unit object scale, no ".001" names, Roblox limits
# (<= 20k tris and <= 10k verts per mesh after the exporter's per-material split). Gun checks: rig bones, every mesh
# parented to the rig, NLA clip tracks, locators.

import bpy, bmesh, os
from mathutils import Vector
from mathutils.kdtree import KDTree

ROOT = r"C:/Users/charl/Documents/GauntletGame/GlitchedGauntletGame/art-source/weapons/RemasterV2"
ROLES = {"Body", "Panel", "Dark", "Metal", "Grip", "Accent", "Neon", "Brass", "Glass"}


def _mesh_checks(ob):
	me = ob.data
	bm = bmesh.new()
	bm.from_mesh(me)
	bm.verts.ensure_lookup_table()
	r = {}
	r["tris"] = sum(len(f.verts) - 2 for f in bm.faces)
	r["verts"] = len(bm.verts)
	r["ngons_quads"] = sum(1 for f in bm.faces if len(f.verts) > 3)
	r["degenerate"] = sum(1 for f in bm.faces if f.calc_area() < 1e-9)
	r["zero_edges"] = sum(1 for e in bm.edges if e.calc_length() < 1e-6)
	r["loose_verts"] = sum(1 for v in bm.verts if not v.link_faces)
	r["loose_edges"] = sum(1 for e in bm.edges if not e.link_faces)
	r["edges_3plus"] = sum(1 for e in bm.edges if len(e.link_faces) > 2)
	r["open_edges"] = sum(1 for e in bm.edges if len(e.link_faces) == 1)
	kd = KDTree(len(bm.verts))
	for v in bm.verts:
		kd.insert(v.co, v.index)
	kd.balance()
	r["dup_verts"] = sum(1 for v in bm.verts if len(kd.find_range(v.co, 1e-6)) > 1) // 2
	# closed islands must wind outward
	seen, inverted = set(), 0
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
		closed = all(len(e.link_faces) == 2 for fc in faces for e in fc.edges)
		if closed:
			vol = sum(fc.verts[0].co.dot(fc.verts[i].co.cross(fc.verts[i + 1].co)) for fc in faces for i in range(1, len(fc.verts) - 1)) / 6.0
			if vol < -1e-10:
				inverted += 1
	r["inverted_islands"] = inverted
	uv = bm.loops.layers.uv.active
	if uv is None:
		r["uv"] = "missing"
	else:
		out = 0
		zero = 0
		for f in bm.faces:
			cs = [l[uv].uv for l in f.loops]
			out += sum(1 for c in cs if c.x < -1e-4 or c.x > 1.0001 or c.y < -1e-4 or c.y > 1.0001)
			if len(cs) >= 3:
				a = abs((cs[1] - cs[0]).cross(cs[2] - cs[0])) * 0.5
				zero += a < 1e-10
		r["uv_outside"] = out
		r["uv_zero_area"] = zero
	used = {ob.material_slots[f.material_index].material.name.split(".")[0] for f in bm.faces if f.material_index < len(ob.material_slots) and ob.material_slots[f.material_index].material}
	r["materials"] = sorted(used)
	r["per_material_max_tris"] = max([sum(len(f.verts) - 2 for f in bm.faces if f.material_index == i) for i in range(max(1, len(ob.material_slots)))] or [0])
	bm.free()
	return r


def audit(gun, ver="v03"):
	path = "%s/%s/%s_RemasterV2_%s.blend" % (ROOT, gun, gun, ver)
	if not os.path.exists(path):
		return {"ok": False, "issues": ["no file " + path]}
	before_obj = set(bpy.data.objects)
	before_col = set(bpy.data.collections)
	before_act = set(bpy.data.actions)
	with bpy.data.libraries.load(path, link=False) as (src, dst):
		dst.collections = [c for c in src.collections if c == gun]
	sc = bpy.data.scenes.new("_rv2_audit")
	col = [c for c in dst.collections if c is not None][0]
	sc.collection.children.link(col)
	issues, stats = [], {"tris": 0, "meshes": 0}
	rig = [o for o in col.objects if o.type == "ARMATURE"]
	if len(rig) != 1:
		issues.append("rig count %d" % len(rig))
	rig = rig[0] if rig else None
	if rig is not None:
		stats["bones"] = len(rig.data.bones)
		bad_rot = [pb.name for pb in rig.pose.bones if pb.rotation_mode != "XYZ"]
		if bad_rot:
			issues.append("bones not Euler XYZ: %s" % bad_rot)
		tracks = [t.name for t in (rig.animation_data.nla_tracks if rig.animation_data else [])]
		stats["clips"] = tracks
		if not tracks:
			issues.append("no NLA clip tracks")
	stats["locators"] = sorted(o.name[len(gun) + 1:] for o in col.objects if o.type == "EMPTY")
	for ob in col.objects:
		if "." in ob.name:
			issues.append("suffixed name " + ob.name)
		if ob.type != "MESH":
			continue
		stats["meshes"] += 1
		if rig is not None and ob.parent != rig:
			issues.append("%s not parented to the rig" % ob.name)
		s = ob.matrix_basis.to_scale()
		if max(abs(s.x - 1), abs(s.y - 1), abs(s.z - 1)) > 1e-4:
			issues.append("%s scale %s" % (ob.name, tuple(round(v, 4) for v in s)))
		r = _mesh_checks(ob)
		stats["tris"] += r["tris"]
		for k in ("ngons_quads", "degenerate", "zero_edges", "loose_verts", "loose_edges", "edges_3plus", "dup_verts", "inverted_islands", "uv_outside", "uv_zero_area"):
			if r.get(k):
				issues.append("%s %s=%d" % (ob.name[len(gun) + 1:], k, r[k]))
		if r.get("uv") == "missing":
			issues.append("%s has no UVs" % ob.name)
		extra = set(r["materials"]) - ROLES
		if extra:
			issues.append("%s non-role materials %s" % (ob.name, sorted(extra)))
		if r["per_material_max_tris"] > 20000 or r["verts"] > 10000:
			issues.append("%s over Roblox mesh limits" % ob.name)
		stats.setdefault("open_edges", {})[ob.name[len(gun) + 1:]] = r["open_edges"]
	# clean up everything this audit appended
	for o in set(bpy.data.objects) - before_obj:
		bpy.data.objects.remove(o)
	for c in set(bpy.data.collections) - before_col:
		bpy.data.collections.remove(c)
	for a in set(bpy.data.actions) - before_act:
		bpy.data.actions.remove(a)
	bpy.data.scenes.remove(sc)
	bpy.data.orphans_purge(do_local_ids=True, do_linked_ids=False, do_recursive=True)
	stats["open_edges"] = {k: v for k, v in stats.get("open_edges", {}).items() if v}
	return {"ok": not issues, "issues": issues[:40], "n_issues": len(issues), "stats": stats}
