# export_remaster.py: export one RemasterV2 weapon file with the standard exporter (export_weapons.export_gun).
#
#   blender --background art-source/weapons/RemasterV2/<Gun>/<Gun>_RemasterV2_vNN.blend --python tools/blender/export_remaster.py
#
# Runs on a background copy: the .blend is never saved, and no live Blender session is touched. Writes
# art-source/weapons/Exports/<Gun>.fbx and <Gun>.json exactly like export_weapons.py does for GunTest.blend
# (per-material split, NLA strips baked, modifiers applied). The collection's `pbr` flag is dropped: the
# remaster guns carry no baked texture maps (colour comes from each material's rbx_material / rbx_color).

import bpy, importlib.util, json, os, sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", ".."))
spec = importlib.util.spec_from_file_location("export_weapons", os.path.join(HERE, "export_weapons.py"))
ew = importlib.util.module_from_spec(spec)
spec.loader.exec_module(ew)
ew.OUT_DIR = os.path.join(REPO, "art-source", "weapons", "Exports")
os.makedirs(ew.OUT_DIR, exist_ok=True)

guns = [c for c in bpy.data.collections if "weapon_name" in c]
assert len(guns) == 1, "expected one weapon collection, found %s" % [c.name for c in guns]
g = guns[0]
if "pbr" in g.keys():
	del g["pbr"]
sc = next(s for s in bpy.data.scenes if g.name in [c.name for c in s.collection.children_recursive])
if bpy.context.window is not None:
	bpy.context.window.scene = sc
assert bpy.context.scene == sc, "the weapon's scene must be the active one"
rig = next(o for o in g.all_objects if o.type == "ARMATURE")
if rig.animation_data:
	rig.animation_data.action = None
for pb in rig.pose.bones:
	pb.location = (0, 0, 0)
	pb.rotation_euler = (0, 0, 0)
	pb.rotation_quaternion = (1, 0, 0, 0)
out = ew.export_gun(g)
print("EXPORT_RESULT " + json.dumps(out))
