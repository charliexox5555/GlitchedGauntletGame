# v2build.py: shared build driver for RemasterV2 weapons (on top of v2kit). Blender MCP only.
#   import v2build as B; report = B.assemble(gun, build_parts, bones, locators, meta)
# Builds into the weapon's own scene <gun>_RemasterV2_Review / collection <gun>; never touches other scenes.

import bpy
from mathutils import Matrix
import v2kit as K


def assemble(gun, build_parts, bones, locators, meta):
	sc = K.new_scene(gun + "_RemasterV2_Review")
	win = bpy.context.window
	win.scene = sc
	if bpy.context.object and bpy.context.object.mode != "OBJECT":
		bpy.ops.object.mode_set(mode="OBJECT")
	col = bpy.data.collections.get(gun)
	if col is not None:
		if not col.get(K.TAG):
			raise RuntimeError("collection %s exists and is not ours" % gun)
		K.clear_collection(col)
	else:
		col = bpy.data.collections.new(gun)
		col[K.TAG] = True
		sc.collection.children.link(col)
	col["weapon_name"] = gun
	for k, v in meta.items():
		col[k] = v
	col["remaster"] = "RemasterV2 2026-11-07"
	scratch = bpy.data.collections.new("_rv2_scratch")
	sc.collection.children.link(scratch)
	mats = K.materials()
	K._SCRATCH["col"] = scratch
	K._SCRATCH["mats"] = mats
	try:
		parts = build_parts()
	finally:
		for o in list(scratch.objects):
			me = o.data
			bpy.data.objects.remove(o)
			if me and me.users == 0:
				bpy.data.meshes.remove(me)
		bpy.data.collections.remove(scratch)
	pre = gun + "_"
	rig = K.build_rig(col, pre, bones)
	report = {}
	static = [pc for p in parts.values() if p.bone == "Root" for pc in p.pieces]
	# Parts the game fades while aiming (Viewmodel.ADS_FADE_PREFIXES: "Stock") must not hide other parts' faces.
	occluders = [pc for p in parts.values() if p.bone == "Root" and not p.name.startswith("Stock") for pc in p.pieces]
	report["_hidden_faces_removed"] = K.remove_hidden(occluders, static)
	for p in parts.values():
		me = K.finish_mesh(p.merged(), pre + p.name, mats)
		ob = bpy.data.objects.new(pre + p.name, me)
		col.objects.link(ob)
		wn = ob.modifiers.new("WeightedNormal", "WEIGHTED_NORMAL")
		wn.keep_sharp = True
		wn.weight = 60
		K.parent_to_bone(ob, rig, p.bone, Matrix.Identity(4))
		report[p.name] = K.tri_count(me)
	for name, bone, pos, rot in locators:
		e = bpy.data.objects.new(pre + name, None)
		e.empty_display_type = "ARROWS" if rot is not None else "PLAIN_AXES"
		e.empty_display_size = 0.04
		col.objects.link(e)
		K.parent_to_bone(e, rig, bone, Matrix.Translation(pos) @ (rot if rot is not None else Matrix.Identity(4)))
	report["_total_tris"] = sum(v for k, v in report.items() if not k.startswith("_"))
	return report


def solid(side, sect, mat=K.BODY, edge=0.0):
	# Side profile (x, z) extruded across Y, intersected with a section (y, z) extruded along X.
	xs = [p[0] for p in side]
	a = K.prism(side, "Y", -0.5, 0.5, mat)
	b = K.prism(sect, "X", min(xs) - 0.05, max(xs) + 0.05, mat)
	out = K.intersect(a, b)
	return K.bevel(out, edge, 1, 50) if edge > 0 else out


def head(x, z, y_surface, r=0.008, h=0.004, segs=6, side=1, mat=K.METAL):
	# Screw/pin head on a side face (side=+1 left, -1 right); the buried cap is dropped.
	y0, y1 = (y_surface - 0.003, y_surface + h) if side > 0 else (-y_surface - h, -y_surface + 0.003)
	return K.drop(K.cyl_y(x, z, r, y0, y1, segs, mat, rot=0.0), 1, -side)


def both(bm):
	return K.mirror_y(bm)
