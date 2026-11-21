# Open a stock RemasterV2 gun (GUN, VER) read-only and report its contract: objects, bones, locators,
# materials, per-part bounds, triangle count. Optionally SAVE_AS a working master (stock file untouched).
import bpy, os
from mathutils import Vector
ROOT = r"C:/Users/charl/Documents/GauntletGame/GlitchedGauntletGame/"
GUN = globals().get("GUN", "Stinger"); VER = globals().get("VER", "v05")
bpy.ops.wm.open_mainfile(filepath=ROOT + "art-source/weapons/RemasterV2/%s/%s_RemasterV2_%s.blend" % (GUN, GUN, VER))
if globals().get("SAVE_AS"):
	os.makedirs(os.path.dirname(ROOT + SAVE_AS), exist_ok=True)
	bpy.ops.wm.save_as_mainfile(filepath=ROOT + SAVE_AS, copy=False)
dg = bpy.context.evaluated_depsgraph_get()
def bb(o):
	if o.type != "MESH":
		return None
	ws = [o.matrix_world @ v.co for v in o.data.vertices]
	if not ws:
		return None
	return [round(min(w[i] for w in ws), 3) for i in range(3)] + [round(max(w[i] for w in ws), 3) for i in range(3)]
objs = {}; tris = 0
for o in bpy.data.objects:
	d = {"t": o.type, "par": (o.parent.name if o.parent else None), "bone": o.parent_bone or None,
		"coll": [c.name for c in o.users_collection], "vis": not o.hide_render}
	if o.type == "MESH":
		me = o.evaluated_get(dg).to_mesh(); t = sum(len(p.vertices) - 2 for p in me.polygons); o.evaluated_get(dg).to_mesh_clear()
		d["tris"] = t; d["bb"] = bb(o); d["mats"] = [m.name for m in o.data.materials if m]
		d["mods"] = [m.type for m in o.modifiers]
		if not o.hide_render:
			tris += t
	elif o.type == "EMPTY":
		d["loc"] = [round(x, 4) for x in o.matrix_world.translation]
	objs[o.name] = d
rig = next((o for o in bpy.data.objects if o.type == "ARMATURE"), None)
bones = {}
if rig:
	for b in rig.data.bones:
		h = rig.matrix_world @ b.head_local
		bones[b.name] = {"head": [round(x, 4) for x in h], "parent": b.parent.name if b.parent else None}
result = {"file": bpy.data.filepath, "tris_visible": tris, "objects": objs, "rig": rig.name if rig else None, "bones": bones,
	"colls": {c.name: len(c.objects) for c in bpy.data.collections}, "mats": sorted(m.name for m in bpy.data.materials),
	"actions": [a.name for a in bpy.data.actions]}
