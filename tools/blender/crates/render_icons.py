"""Tier icons of the crate for the Backpack and Shop (transparent 512x512 PNGs), rendered from the
live CRATE collection (run build_crate.py first). Colours match src/shared/Config/Crates.luau.
Writes art-source/ui/backpack/crate_<tier>.png."""
import math
import os

import bpy
from mathutils import Vector

OUT = r"C:\Users\charl\Documents\GauntletGame\GlitchedGauntletGame\art-source\ui\backpack"

TIERS = {
	"standard": {"Body": "5E636C", "Frame": "37353D", "Hardware": "A7ABB1", "Light": "2FD3E6", "Gem": "3FC8DD", "Interior": "1A1C21"},
	"elite": {"Body": "5A3A8E", "Frame": "3A2452", "Hardware": "C9A04A", "Light": "F5B82E", "Gem": "E8AE34", "Interior": "1B1424"},
	"apex": {"Body": "2A2B2F", "Frame": "46474C", "Hardware": "8C9096", "Light": "E8401F", "Gem": "D8341E", "Interior": "140E0E"},
	"knife": {"Body": "26402A", "Frame": "172A1B", "Hardware": "C5CAD0", "Light": "5BE35A", "Gem": "4FD24E", "Interior": "0F1A11"},
}
# CRATE_TIERS=knife,apex renders only those (e.g. a new tier without touching the others)
if os.environ.get("CRATE_TIERS"):
	TIERS = {k: v for k, v in TIERS.items() if k in os.environ["CRATE_TIERS"].split(",")}


def srgb(h):
	c = [int(h[i : i + 2], 16) / 255 for i in (0, 2, 4)]
	return tuple(((x + 0.055) / 1.055) ** 2.4 if x > 0.04045 else x / 12.92 for x in c) + (1.0,)


sc = bpy.context.scene
sc.render.engine = "BLENDER_EEVEE"
sc.render.resolution_x = sc.render.resolution_y = 512
sc.render.film_transparent = True
sc.render.image_settings.file_format = "PNG"
sc.render.image_settings.color_mode = "RGBA"
sc.view_settings.view_transform = "Standard"

for ob in bpy.data.collections["CRATE"].objects:
	ob.rotation_euler = (0, 0, 0)
	if ob.get("group") == "Gem":
		ob.location = (0, 0, 1.02)

cam = bpy.data.objects["CrateCam"]
sc.camera = cam
cam.data.type = "PERSP"
cam.data.lens = 50
loc, tgt = Vector((-2.9, -4.4, 2.9)), Vector((-0.12, 0, 0.42))
cam.location = loc
cam.rotation_euler = (tgt - loc).to_track_quat("-Z", "Y").to_euler()

os.makedirs(OUT, exist_ok=True)
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
			bsdf.inputs["Emission Strength"].default_value = 3.0
		elif role == "Hardware":
			bsdf.inputs["Metallic"].default_value = 0.35
			bsdf.inputs["Roughness"].default_value = 0.45
	sc.render.filepath = os.path.join(OUT, f"crate_{tier}.png")
	bpy.ops.render.render(write_still=True)
	paths.append(sc.render.filepath)
result = {"icons": paths}
