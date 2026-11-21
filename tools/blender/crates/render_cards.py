"""Shop card renders of the crate (tall cards, so a more end-on, higher view than the Backpack icons).
Run after render_icons.py in the same live Blender (it reuses its tier colours and camera).
Writes art-source/ui/shop/crates/crate_<tier>_card.png (transparent, cropped to the crate)."""
import os

import bpy
from mathutils import Vector

ICONS = r"C:\Users\charl\Documents\GauntletGame\GlitchedGauntletGame\tools\blender\crates\render_icons.py"
OUT = r"C:\Users\charl\Documents\GauntletGame\GlitchedGauntletGame\art-source\ui\shop\crates"
ns = {}
src = open(ICONS, encoding="utf-8").read()
# reuse the tier colours and render settings, then render from the card camera instead
exec(src.split("os.makedirs(OUT")[0], ns)
TIERS, srgb = ns["TIERS"], ns["srgb"]

sc = bpy.context.scene
cam = bpy.data.objects["CrateCam"]
cam.data.lens = 55
loc, tgt = Vector((-5.0, -3.3, 3.9)), Vector((-0.05, 0, 0.45))
cam.location = loc
cam.rotation_euler = (tgt - loc).to_track_quat("-Z", "Y").to_euler()
sc.render.resolution_x = sc.render.resolution_y = 640

paths = []
for tier, roles in TIERS.items():
	for role, hexv in roles.items():
		m = bpy.data.materials.get("Crate_" + role)
		if not m:
			continue
		col = srgb(hexv)
		m.diffuse_color = col
		bsdf = m.node_tree.nodes.get("Principled BSDF")
		bsdf.inputs["Base Color"].default_value = col
		if role in ("Light", "Gem"):
			bsdf.inputs["Emission Color"].default_value = col
	path = os.path.join(OUT, f"crate_{tier}_card_raw.png")
	sc.render.filepath = path
	bpy.ops.render.render(write_still=True)
	paths.append(path)
result = {"renders": paths}
