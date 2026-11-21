# Export copy of a Tempest-Strike line item (adapted from tempest_vandal/53_export_prep.py + 70_moving_parts.py):
#  - opens <GUN>/<TAG>/<GUN>_TempestStrike_<TAG>.blend at rest pose
#  - applies the modifiers of every visible Tempest mesh (the flat exporter reads base meshes), fixes material indices
#  - hides cutters and the review rig; renames the role materials "TS <Role>" so visible stock parts export in
#    Storm Shadow colours and replace their stock parts in Studio
#  - adds a TS_Rig armature: one bone per moving piece (GROUPS = {bone: (pivot xyz, [object names])}), head at the
#    pivot, same orientation as the stock Root bone, pieces parented to it (pieces already on a stock bone stay)
#  - saves <GUN>/<TAG>x/<GUN>_TempestStrike_<TAG>x.blend (one .blend)
import bpy, os
from mathutils import Matrix, Vector
ROOT = r"C:/Users/charl/Documents/GauntletGame/GlitchedGauntletGame/"
GUN = globals().get("GUN"); TAG = globals().get("TAG"); GROUPS = globals().get("GROUPS", {})
D = ROOT + "art-source/weapons/Skins/TempestStrike/%s/" % GUN
bpy.ops.wm.open_mainfile(filepath=D + "%s/%s_TempestStrike_%s.blend" % (TAG, GUN, TAG))
for a in bpy.data.objects:
	if a.type == "ARMATURE":
		a.data.pose_position = "REST"
bpy.context.view_layer.update()
dg = bpy.context.evaluated_depsgraph_get()
applied = 0
for o in list(bpy.data.collections["Tempest"].all_objects):
	if o is None or o.type != "MESH" or o.hide_render or o.get("ts_replaced"):
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
		o.data = me; me.name = o.name; applied += 1
	me = o.data; n = len(me.materials)
	if n:
		first = next((i for i, m in enumerate(me.materials) if m is not None), 0)
		for p in me.polygons:
			if p.material_index >= n or me.materials[p.material_index] is None:
				p.material_index = first
for c in bpy.data.collections:
	if c.name.startswith("Tempest_Cutters"):
		for o in c.all_objects:
			o.hide_render = True
for n in ("COL_ReviewRig",):
	c = bpy.data.collections.get(n)
	if c:
		for o in list(c.all_objects):
			bpy.data.objects.remove(o, do_unlink=True)
		bpy.data.collections.remove(c)
renamed = []
for n in ("Body", "Panel", "Dark", "Grip", "Metal", "Accent", "Neon", "Brass", "Glass", "Water"):
	m = bpy.data.materials.get(n)
	if m:
		m.name = "TS " + n; renamed.append(m.name)
moved = {}
if GROUPS:
	stock = bpy.data.objects["%s_Rig" % GUN]
	root_local = stock.data.bones["Root"].matrix_local.copy()
	arm = bpy.data.armatures.new("TS_Rig"); rig = bpy.data.objects.new("TS_Rig", arm)
	bpy.data.collections["Tempest"].objects.link(rig)
	rig.matrix_world = stock.matrix_world.copy()
	for o in bpy.context.view_layer.objects:
		o.select_set(False)
	bpy.context.view_layer.objects.active = rig; rig.select_set(True)
	win = bpy.context.window_manager.windows[0]
	area = next(a for a in win.screen.areas if a.type == "VIEW_3D")
	ctx = {"window": win, "area": area, "region": next(r for r in area.regions if r.type == "WINDOW"), "active_object": rig, "object": rig}
	with bpy.context.temp_override(**ctx):
		bpy.ops.object.mode_set(mode="EDIT")
	inv = stock.matrix_world.inverted()
	for name, (pivot, _) in GROUPS.items():
		eb = arm.edit_bones.new(name); eb.head = (0, 0, 0); eb.tail = (0, 0.05, 0)
		eb.matrix = Matrix.Translation(inv @ Vector(pivot)) @ root_local.to_3x3().to_4x4()
	with bpy.context.temp_override(**ctx):
		bpy.ops.object.mode_set(mode="OBJECT")
	bpy.context.view_layer.update()
	for name, (_, objs) in GROUPS.items():
		for on in objs:
			o = bpy.data.objects[on]; mw = o.matrix_world.copy()
			o.parent = rig; o.parent_type = "BONE"; o.parent_bone = name; o.matrix_world = mw
			moved[on] = name
	bpy.context.view_layer.update()
dst = D + "%sx/" % TAG
os.makedirs(dst, exist_ok=True)
for f in os.listdir(dst):
	if f.endswith((".blend", ".blend1")):
		os.remove(os.path.join(dst, f))
bpy.ops.wm.save_as_mainfile(filepath=dst + "%s_TempestStrike_%sx.blend" % (GUN, TAG), copy=False)
result = {"applied": applied, "renamed": renamed, "moved": moved, "saved": bpy.data.filepath}
