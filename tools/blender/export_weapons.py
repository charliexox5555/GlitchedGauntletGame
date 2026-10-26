# export_weapons.py: export guns from art-source/weapons/GunTest.blend for Roblox.
#
# Run it on a *background* copy of the file so nothing in the source changes:
#   blender --background art-source/weapons/GunTest.blend --python tools/blender/export_weapons.py -- [Gun ...]
# (No gun names = every collection with a `weapon_name` property.)
#
# Per gun it writes to art-source/weapons/Exports/:
#   <Id>.fbx   rig + meshes + locators, NLA strips baked to takes (Fire, Reload)
#   <Id>.json  rest-pose data the Studio build script needs: bones, locators,
#              parts (bone, material) and Bitrate-style att_positions
#
# Export-time changes (only in the background copy, never saved):
#   - `<Gun>_` prefixes stripped, rig renamed `Rig`
#   - multi-material meshes split into `<Part>_<Material>` (Body -> Body_Panel, Body_Dark...)
#   - FX_* preview meshes and *_Buddy instance empties skipped
#   - hidden option collections (attachments, skin geometry) included so Studio gets every part

import bpy, bmesh, json, os, sys
from mathutils import Matrix

ROOT = os.path.abspath(os.path.join(os.path.dirname(bpy.data.filepath), "..", ".."))
OUT_DIR = os.path.join(ROOT, "art-source", "weapons", "Exports")

# Material slot -> Roblox look (Art Direction palette).
MATERIALS = {
	"Body_Panel": {"material": "SmoothPlastic", "color": "56607C"},
	"Body_Dark": {"material": "SmoothPlastic", "color": "1C2030"},
	"Metal": {"material": "Metal", "color": "14161D"},
	"Neon": {"material": "Neon", "color": "00E5FF"},
	"Accent": {"material": "SmoothPlastic", "color": "FFC83D"},
	"Lens": {"material": "Neon", "color": "FF3DCB"},
}


def used_material(o):
	# The material the mesh's faces use (a part can carry unused slots; single-material after splitting).
	if not o.material_slots:
		return None
	idx = o.data.polygons[0].material_index if len(o.data.polygons) else 0
	return o.material_slots[min(idx, len(o.material_slots) - 1)].material


def look_of(o, mat):
	# A material's Roblox look: its own rbx_material / rbx_color properties (redesigned guns),
	# else the shared palette above.
	m = used_material(o)
	if m is not None and "rbx_material" in m:
		return {"material": m["rbx_material"], "color": m["rbx_color"]}
	return MATERIALS.get(mat)


def gun_id(name):
	return name.replace(" ", "")


def base_material(name):
	return name.split(".")[0]


def material_suffix(name):
	name = base_material(name)
	return name[len("Body_"):] if name.startswith("Body_") else name


def strip_prefix(obj_name, gun):
	for pre in (gun + "_", gun_id(gun) + "_"):
		if obj_name.startswith(pre):
			return obj_name[len(pre):]
	return obj_name


def skip(o, gun):
	short = strip_prefix(o.name, gun)
	return short.startswith("FX_") or short == "Buddy" or (o.type == "EMPTY" and o.instance_type == "COLLECTION")


def split_by_material(o):
	me = o.data
	used = sorted({p.material_index for p in me.polygons})
	if len(used) <= 1:
		return [o]
	pieces = []
	for idx in used:
		mat = o.material_slots[idx].material
		new = o.copy()
		new.data = me.copy()
		for col in o.users_collection:
			col.objects.link(new)
		bm = bmesh.new()
		bm.from_mesh(new.data)
		bmesh.ops.delete(bm, geom=[f for f in bm.faces if f.material_index != idx], context="FACES")
		for f in bm.faces:
			f.material_index = 0
		bm.to_mesh(new.data)
		bm.free()
		new.data.materials.clear()
		new.data.materials.append(mat)
		new.name = o.name + "_" + material_suffix(mat.name)
		pieces.append(new)
	bpy.data.objects.remove(o)
	return pieces


def unhide_tree(col):
	col.hide_viewport = False
	for ch in col.children:
		unhide_tree(ch)


def mat_list(m):
	return [[round(m[r][c], 5) for c in range(4)] for r in range(4)]


def option_of(o, g):
	# Which child collection (ATT_*, SKIN_*) an object belongs to, if any.
	for ch in g.children_recursive:
		if o.name in ch.objects:
			return ch.name
	return None


def sample_animations(rig):
	# Samples every NLA strip's action once per frame as each bone's local
	# transform relative to rest (pose_bone.matrix_basis): [x, y, z, qw, qx, qy, qz].
	# Bones that never move are left out.
	ad = rig.animation_data
	if not ad:
		return {}
	rig.data.pose_position = "POSE"
	saved = (ad.action, ad.use_nla)
	ad.use_nla = False
	out = {}
	for track in ad.nla_tracks:
		for strip in track.strips:
			act = strip.action
			if not act:
				continue
			ad.action = act
			if hasattr(ad, "action_slot") and ad.action_slot is None and len(act.slots) > 0:
				ad.action_slot = act.slots[0]
			f0, f1 = int(round(act.frame_range[0])), int(round(act.frame_range[1]))
			bones = {pb.name: [] for pb in rig.pose.bones}
			for f in range(f0, f1 + 1):
				bpy.context.scene.frame_set(f)
				for pb in rig.pose.bones:
					loc, rot, scl = pb.matrix_basis.decompose()
					bones[pb.name].append([round(loc.x, 4), round(loc.y, 4), round(loc.z, 4), round(rot.w, 4), round(rot.x, 4), round(rot.y, 4), round(rot.z, 4), round(scl.x, 3)])
			moving = {}
			for name, frames in bones.items():
				if any(abs(a - b) > 1e-4 for fr in frames for a, b in zip(fr, frames[0])) or any(abs(v) > 1e-4 for v in frames[0][:3]) or abs(frames[0][3] - 1) > 1e-4:
					moving[name] = frames
			out[track.name] = {"action": act.name, "start": f0, "end": f1, "fps": bpy.context.scene.render.fps, "bones": moving}
	ad.action, ad.use_nla = saved
	bpy.context.scene.frame_set(1)
	return out


def export_gun(g):
	gun = g.name
	gid = gun_id(gun)
	# Which option collections (attachments, skin geometry) are shown by default.
	options_visible = {ch.name: not ch.hide_viewport for ch in g.children_recursive}
	unhide_tree(g)
	rig = next(o for o in g.all_objects if o.type == "ARMATURE")

	meshes = [o for o in g.all_objects if o.type == "MESH" and not skip(o, gun)]
	split_report = {}
	for o in meshes:
		if len({p.material_index for p in o.data.polygons}) > 1:
			split_report[strip_prefix(o.name, gun)] = None
			pieces = split_by_material(o)
			split_report[strip_prefix(pieces[0].name.rsplit("_", 1)[0], gun)] = [strip_prefix(p.name, gun) for p in pieces]
	split_report = {k: v for k, v in split_report.items() if v}

	objs = [o for o in g.all_objects if not skip(o, gun)]

	# Rest pose for the data dump.
	rig.data.pose_position = "REST"
	bpy.context.scene.frame_set(1)
	bpy.context.view_layer.update()

	data = {
		"gun": gun,
		"id": gid,
		"axes": "blender (+X muzzle, +Z up, +Y gun-left), 1 unit = 1 stud target",
		"bones": [],
		"locators": [],
		"parts": [],
		"props": {k: (g[k] if isinstance(g[k], (int, float, str)) else str(g[k])) for k in g.keys()},
		"split": split_report,
		"options_visible": options_visible,
	}
	rw = rig.matrix_world
	for b in rig.data.bones:
		data["bones"].append({
			"name": b.name,
			"parent": b.parent.name if b.parent else None,
			"head": [round(v, 5) for v in (rw @ b.head_local)],
			"tail": [round(v, 5) for v in (rw @ b.tail_local)],
			"matrix": mat_list(rw @ b.matrix_local),
		})
	for o in objs:
		short = strip_prefix(o.name, gun)
		if o.type == "EMPTY":
			data["locators"].append({
				"name": short,
				"bone": o.parent_bone or None,
				"matrix": mat_list(o.matrix_world),
			})
		elif o.type == "MESH":
			o.data.calc_loop_triangles()
			used = used_material(o)
			mat = base_material(used.name) if used else None
			corners = [o.matrix_world @ v.co for v in o.data.vertices]
			lo = [min(c[i] for c in corners) for i in range(3)]
			hi = [max(c[i] for c in corners) for i in range(3)]
			data["parts"].append({
				"name": short,
				"bone": o.parent_bone or None,
				"material": mat,
				"look": look_of(o, mat),
				# Guns with a baked texture set (collection property `pbr`) get a SurfaceAppearance
				# on every part except the Neon ones.
				"pbr": bool(g.get("pbr")) and (look_of(o, mat) or {}).get("material") != "Neon",
				"tris": len(o.data.loop_triangles),
				"option": option_of(o, g),
				"center": [round((lo[i] + hi[i]) / 2, 5) for i in range(3)],
				"size": [round(hi[i] - lo[i], 5) for i in range(3)],
			})

	data["animations"] = sample_animations(rig)

	# Export (pose mode back on so NLA strips bake).
	rig.data.pose_position = "POSE"
	renamed = []
	for o in objs:
		short = strip_prefix(o.name, gun)
		if short != o.name:
			renamed.append((o, o.name))
	for o, _ in renamed:
		o.name = strip_prefix(o.name, gun)
	rig.name = "Rig"
	bpy.ops.object.select_all(action="DESELECT")
	for o in objs:
		o.hide_set(False)
		o.hide_viewport = False
		o.select_set(True)
	bpy.context.view_layer.objects.active = rig
	fbx_path = os.path.join(OUT_DIR, gid + ".fbx")
	bpy.ops.export_scene.fbx(
		filepath=fbx_path,
		use_selection=True,
		object_types={"ARMATURE", "MESH", "EMPTY"},
		apply_scale_options="FBX_SCALE_UNITS",
		add_leaf_bones=False,
		bake_anim=True,
		bake_anim_use_nla_strips=True,
		bake_anim_use_all_actions=False,
		bake_anim_force_startend_keying=True,
	)
	# Restore names so the next gun's short names don't collide (Blender would add .001).
	rig.name = gid + "_Rig"
	for o, original in renamed:
		o.name = original
	with open(os.path.join(OUT_DIR, gid + ".json"), "w") as f:
		json.dump(data, f, indent=1)
	return {"id": gid, "fbx": fbx_path, "parts": len(data["parts"]), "tris": sum(p["tris"] for p in data["parts"]), "split": split_report}


def main(only=None):
	os.makedirs(OUT_DIR, exist_ok=True)
	guns = [c for c in bpy.data.collections if "weapon_name" in c]
	if only:
		wanted = {gun_id(n) for n in only}
		guns = [c for c in guns if gun_id(c.name) in wanted]
	return [export_gun(g) for g in guns]


if __name__ == "__main__":
	args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
	print(json.dumps(main(args or None), indent=1))
