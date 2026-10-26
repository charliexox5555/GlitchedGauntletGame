# export_mods.py: export the Mod props (art-source/abilities/<Mod>/<Mod>.blend) for Roblox.
#
#   blender --background --factory-startup --python tools/blender/export_mods.py -- [Mod ...] [--out DIR]
# (No names = every built Mod, plus the ModVFX set.) Each .blend is opened in turn and never saved.
#
# Per Mod it writes to art-source/abilities/Exports/ (or DIR):
#   <Mod>.fbx   meshes (+ locator empties), `<Mod>_` prefixes stripped, same axes as the gun exports
#   <Mod>.json  what the Studio builder needs: parts (material, Roblox look, energy flag, tris, centre, size),
#               locators (Handle, Emitter, Fuse, Top, Center...) and the collection's props
#
# Export-time changes (in memory only): multi-material parts are split into <Part>_<Material> (Body -> Body_Shell,
# Body_Dark, Body_Trim) like the guns. Energy parts are single-material already and keep their names (*_Energy);
# the builder should give them Material = Neon (EnergyGlass / EnergyVFX: transparent) and tint them per viewer.
#
# Next (after the user approves the renders): python tools/opencloud/upload_models.py --abilities --group 11116787
# then build them into the Studio-owned ReplicatedStorage.Abilities with .rbxm backups in art-source/abilities/Studio/.

import bpy, json, os, sys

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
	sys.path.insert(0, HERE)
from export_weapons import mat_list, split_by_material, strip_prefix, used_material  # noqa: E402

ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
SRC = os.path.join(ROOT, "art-source", "abilities")
MODS = ["PatchUp", "Packet", "LaunchPad", "Firewall", "LagField", "ModVFX"]


def blend_of(mod):
	return os.path.join(SRC, "VFX" if mod == "ModVFX" else mod, mod + ".blend")


def look(o):
	m = used_material(o)
	if m is None or "rbx_material" not in m:
		return None
	out = {"material": m["rbx_material"], "color": m["rbx_color"]}
	if "rbx_transparency" in m:
		out["transparency"] = m["rbx_transparency"]
	return out


def export_mod(mod, out_dir):
	bpy.ops.wm.open_mainfile(filepath=blend_of(mod))
	col = bpy.data.collections[mod]
	for o in list(col.objects):
		if o.type == "MESH" and len({p.material_index for p in o.data.polygons}) > 1:
			split_by_material(o)
	objs = list(col.objects)
	bpy.context.view_layer.update()

	data = {
		"mod": mod,
		"axes": "blender (+X forward, +Z up, +Y left), 1 unit = 1 stud; same as the gun exports",
		"props": {k: (col[k] if isinstance(col[k], (int, float, str)) else str(col[k])) for k in col.keys()},
		"parts": [],
		"locators": [],
	}
	for o in objs:
		short = strip_prefix(o.name, mod)
		if o.type == "EMPTY":
			data["locators"].append({"name": short, "matrix": mat_list(o.matrix_world)})
		elif o.type == "MESH":
			o.data.calc_loop_triangles()
			pts = [o.matrix_world @ v.co for v in o.data.vertices]
			lo = [min(p[i] for p in pts) for i in range(3)]
			hi = [max(p[i] for p in pts) for i in range(3)]
			m = used_material(o)
			data["parts"].append({
				"name": short,
				"material": m.name.split(".")[0] if m else None,
				"look": look(o),
				"energy": short.endswith("_Energy"),
				"tris": len(o.data.loop_triangles),
				"center": [round((lo[i] + hi[i]) / 2, 5) for i in range(3)],
				"size": [round(hi[i] - lo[i], 5) for i in range(3)],
			})
	data["tris"] = sum(p["tris"] for p in data["parts"])

	for o in objs:
		o.name = strip_prefix(o.name, mod)
	bpy.ops.object.select_all(action="DESELECT")
	for o in objs:
		o.hide_set(False)
		o.select_set(True)
	bpy.context.view_layer.objects.active = next(o for o in objs if o.type == "MESH")
	fbx = os.path.join(out_dir, mod + ".fbx")
	bpy.ops.export_scene.fbx(
		filepath=fbx,
		use_selection=True,
		object_types={"MESH", "EMPTY"},
		apply_scale_options="FBX_SCALE_UNITS",
		use_mesh_modifiers=True,
		bake_anim=False,
	)
	with open(os.path.join(out_dir, mod + ".json"), "w") as f:
		json.dump(data, f, indent=1)
	return {"mod": mod, "fbx": fbx, "parts": len(data["parts"]), "tris": data["tris"]}


def main(argv):
	out_dir = os.path.join(SRC, "Exports")
	if "--out" in argv:
		i = argv.index("--out")
		out_dir = argv[i + 1]
		argv = argv[:i] + argv[i + 2:]
	os.makedirs(out_dir, exist_ok=True)
	mods = argv or [m for m in MODS if os.path.exists(blend_of(m))]
	return [export_mod(m, out_dir) for m in mods]


if __name__ == "__main__":
	args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
	print("EXPORT_MODS " + json.dumps(main(args), indent=1))
