# Open the stock RemasterV2 Vandal v05 and save it as the Tempest-Strike s01 working master (stock untouched).
import bpy, math
from mathutils import Vector
SRC = r"C:/Users/charl/Documents/GauntletGame/GlitchedGauntletGame/art-source/weapons/RemasterV2/Vandal/Vandal_RemasterV2_v05.blend"
DST = r"C:/Users/charl/Documents/GauntletGame/GlitchedGauntletGame/art-source/weapons/Skins/TempestStrike/Vandal/s01/Vandal_TempestStrike_s01.blend"
bpy.ops.wm.open_mainfile(filepath=SRC)
bpy.ops.wm.save_as_mainfile(filepath=DST, copy=False)
info = {}
for o in bpy.data.objects:
	d = {"type": o.type, "parent": o.parent.name if o.parent else None, "pbone": o.parent_bone or None,
		"coll": [c.name for c in o.users_collection]}
	if o.type == "MESH":
		d["faces"] = len(o.data.polygons)
		d["mods"] = [(m.type, getattr(m, "width", None), getattr(m, "segments", None)) for m in o.modifiers]
		d["mats"] = [m.name for m in o.data.materials if m]
		d["smooth"] = sum(p.use_smooth for p in o.data.polygons)
	info[o.name] = d
mats = {m.name: [round(c, 3) for c in m.diffuse_color] for m in bpy.data.materials}
result = {"file": bpy.data.filepath, "objects": info, "mats": mats, "scenes": [s.name for s in bpy.data.scenes],
	"bones": [b.name for b in bpy.data.objects["Vandal_Rig"].data.bones] if "Vandal_Rig" in bpy.data.objects else None,
	"actions": [a.name for a in bpy.data.actions]}
