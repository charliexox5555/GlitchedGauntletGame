# export_lobby_kit.py: export Lobby kit pieces (Lobby_<Piece> collections) for Roblox.
#
#   blender --background --factory-startup art-source/lobby/Kit_<Group>.blend --python tools/blender/export_lobby_kit.py -- <Group> [Piece ...]
#
# Every Lobby_<Piece> collection in the open file is a kit master built at the world origin (the piece origin, see
# vault/02 Art/Lobby Kit.md). One FBX per group holds every piece, so one upload covers the group:
#   art-source/lobby/Exports/<Group>.fbx   meshes; multi-material objects split into <Object>_<Material>
#   art-source/lobby/Exports/<Group>.json  per part: piece, name, look (rbx_material/rbx_variant/rbx_color/...),
#                                           glow flag, tris, centre and size (Blender axes, studs, piece origin = 0)
# Text stand-ins (FONT objects, `preview_only`) and objects with `kit_skip` are left out. The file is never saved.
# Next: python tools/opencloud/upload_models.py --lobby --group 11116787 <Group>
#       python tools/studio/lobby/kit_bundle.py <Group>  (then run the bundle in the Lobby place)

import bpy, json, os, sys

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
	sys.path.insert(0, HERE)
from export_weapons import split_by_material  # noqa: E402

ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
OUT = os.path.join(ROOT, "art-source", "lobby", "Exports")


def used_material(o):
	if not o.material_slots:
		return None
	idx = o.data.polygons[0].material_index if len(o.data.polygons) else 0
	return o.material_slots[min(idx, len(o.material_slots) - 1)].material


def look(o):
	m = used_material(o)
	if m is None or "rbx_material" not in m:
		return None
	out = {"material": m["rbx_material"], "color": m["rbx_color"]}
	for key in ("rbx_variant", "rbx_transparency", "rbx_reflectance"):
		if key in m and m[key] not in ("", None):
			out[key[4:]] = m[key]
	return out


def main(argv):
	group = argv[0]
	only = set(argv[1:])
	os.makedirs(OUT, exist_ok=True)
	pieces = [c for c in bpy.data.collections if c.name.startswith("Lobby_") and (not only or c.name[6:] in only)]
	assert pieces, "no Lobby_<Piece> collections in this file"
	data = {
		"group": group,
		"axes": "blender (+X east, +Y north, +Z up), 1 unit = 1 stud, piece origin at 0; Roblox = (x, z, -y)",
		"pieces": {},
		"parts": [],
	}
	export = []
	names = set()
	for col in pieces:
		piece = col.name[6:]
		objs = []
		for o in list(col.all_objects):
			if o.type != "MESH" or o.get("preview_only") or o.get("kit_skip"):
				continue
			if len(o.data.polygons) == 0:
				continue
			# Bake object transforms into the mesh so the FBX carries plain geometry at the piece origin.
			if o.parent:
				mw = o.matrix_world.copy()
				o.parent = None
				o.matrix_world = mw
			o.data = o.data.copy()
			o.data.transform(o.matrix_world)
			o.matrix_world.identity()
			if len({p.material_index for p in o.data.polygons}) > 1:
				objs += split_by_material(o)
			else:
				objs.append(o)
		props = {k: col[k] for k in col.keys() if isinstance(col[k], (int, float, str))}
		data["pieces"][piece] = {"props": props, "parts": []}
		for o in objs:
			assert o.name not in names, "duplicate object name " + o.name
			names.add(o.name)
			o.data.calc_loop_triangles()
			pts = [v.co for v in o.data.vertices]
			lo = [min(p[i] for p in pts) for i in range(3)]
			hi = [max(p[i] for p in pts) for i in range(3)]
			m = used_material(o)
			glow = bool(o.get("glow")) or o.name.endswith("_Glow")
			data["parts"].append({
				"piece": piece,
				"name": o.name,
				"material": m.name.split(".")[0] if m else None,
				"look": look(o),
				"glow": glow,
				"tris": len(o.data.loop_triangles),
				"center": [round((lo[i] + hi[i]) / 2, 5) for i in range(3)],
				"size": [round(hi[i] - lo[i], 5) for i in range(3)],
			})
			data["pieces"][piece]["parts"].append(o.name)
			export.append(o)
	data["tris"] = sum(p["tris"] for p in data["parts"])

	# Masters usually sit in collections excluded from the view layer; export through a temporary one.
	tmp = bpy.data.collections.new("_Export")
	bpy.context.scene.collection.children.link(tmp)
	for o in export:
		tmp.objects.link(o)
	bpy.context.view_layer.update()
	bpy.ops.object.select_all(action="DESELECT")
	for o in export:
		o.hide_set(False)
		o.hide_viewport = False
		o.select_set(True)
	bpy.context.view_layer.objects.active = export[0]
	fbx = os.path.join(OUT, group + ".fbx")
	bpy.ops.export_scene.fbx(
		filepath=fbx,
		use_selection=True,
		object_types={"MESH"},
		apply_scale_options="FBX_SCALE_UNITS",
		use_mesh_modifiers=True,
		bake_anim=False,
	)
	with open(os.path.join(OUT, group + ".json"), "w") as f:
		json.dump(data, f, indent=1)
	return {"group": group, "fbx": fbx, "pieces": len(data["pieces"]), "parts": len(data["parts"]), "tris": data["tris"]}


if __name__ == "__main__":
	args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
	print("EXPORT_LOBBY_KIT " + json.dumps(main(args)))
