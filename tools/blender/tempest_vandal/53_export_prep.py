# Tempest-Strike Vandal: export copy of the s07 master for tools/blender/export_skin_items_flat.py.
#  - every visible Tempest mesh gets its modifiers applied (the flat exporter reads base meshes)
#  - cutters hidden from render (the exporter skips hide_render objects)
#  - the role materials are renamed "TS <Role>" so visible stock parts count as skinned: they are exported
#    in the Storm Shadow colours and replace the stock parts in Studio (stock-named materials would leave them
#    on stock colours)
# Saves art-source/weapons/Skins/TempestStrike/Vandal/s07x/Vandal_TempestStrike_s07x.blend (one .blend only).
import bpy, os
ROOT = r"C:/Users/charl/Documents/GauntletGame/GlitchedGauntletGame/"
SRC = ROOT + "art-source/weapons/Skins/TempestStrike/Vandal/s07/Vandal_TempestStrike_s07.blend"
DST_DIR = ROOT + "art-source/weapons/Skins/TempestStrike/Vandal/s07x/"
os.makedirs(DST_DIR, exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=SRC)
for a in bpy.data.objects:
	if a.type == "ARMATURE":
		a.data.pose_position = "REST"
bpy.context.view_layer.update()
dg = bpy.context.evaluated_depsgraph_get()
applied = 0
for o in list(bpy.data.collections["Tempest"].all_objects):
	if o is None:
		continue
	if o.type != "MESH" or o.hide_render or o.get("ts_replaced"):
		continue
	if o.modifiers:
		ev = o.evaluated_get(dg)
		me = bpy.data.meshes.new_from_object(ev, preserve_all_data_layers=True, depsgraph=dg)
		old = o.data
		o.modifiers.clear()
		if len(me.materials) == 0 or all(m is None for m in me.materials):
			me.materials.clear()
			for m in old.materials:
				me.materials.append(m)
		o.data = me
		me.name = o.name
		applied += 1
	# every face must point at a real material (solidify rims / transferred cut faces can fall outside)
	me = o.data
	n = len(me.materials)
	if n:
		first = next((i for i, m in enumerate(me.materials) if m is not None), 0)
		for p in me.polygons:
			if p.material_index >= n or me.materials[p.material_index] is None:
				p.material_index = first
		fixed_faces = True
for o in bpy.data.collections["Tempest_Cutters"].all_objects:
	if o is not None:
		o.hide_render = True
renamed = []
for n in ("Body", "Panel", "Dark", "Grip", "Metal", "Accent", "Neon", "Brass", "Glass"):
	m = bpy.data.materials.get(n)
	if m:
		m.name = "TS " + n
		renamed.append(m.name)
for f in os.listdir(DST_DIR):
	if f.endswith(".blend") or f.endswith(".blend1"):
		os.remove(os.path.join(DST_DIR, f))
bpy.ops.wm.save_as_mainfile(filepath=DST_DIR + "Vandal_TempestStrike_s07x.blend", copy=True)
result = {"applied": applied, "renamed": renamed}
