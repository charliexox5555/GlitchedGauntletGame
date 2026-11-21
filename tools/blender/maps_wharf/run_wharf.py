"""Build the Wharf kit and render a review sheet (live Blender MCP, port 9897).

python tools/blender/lobby_v4/send.py tools/blender/maps_wharf/run_wharf.py --port 9897 --pid <pid>
Writes vault/02 Art/References/maps/wharf/kit-crane.png and kit-world.png. Export: run_wharf_export.py.
"""
import importlib
import sys
from math import radians

import bpy
from mathutils import Vector

REPO = r"C:\Users\charl\Documents\GauntletGame\GlitchedGauntletGame"
sys.path[:0] = [REPO + r"\tools\blender\maps_wharf", REPO + r"\tools\blender\maps_arena"]
import arena_kit as A
import wharf_pieces as W

for m in (A, W):
	importlib.reload(m)

# hide other kits while rendering
for c in bpy.data.collections:
	if c.name in ("PortKit", "Port_Sheet", "Arena_Test", "Port_Test"):
		c.hide_render = True
		c.hide_viewport = True
tris = W.build_all()
root = bpy.data.collections["WharfKit"]
root.hide_render = False
root.hide_viewport = False

scene = bpy.context.scene
scene.render.engine = "BLENDER_WORKBENCH"
scene.display.shading.light = "STUDIO"
scene.display.shading.color_type = "MATERIAL"
scene.display.shading.show_cavity = True
scene.render.resolution_x, scene.render.resolution_y = 1400, 900
scene.render.film_transparent = False
cam = bpy.data.objects.get("WharfCam")
if cam is None:
	cam = bpy.data.objects.new("WharfCam", bpy.data.cameras.new("WharfCam"))
	scene.collection.objects.link(cam)
scene.camera = cam


def shoot(only, pos, target, path, lens=35):
	for c in root.children:
		c.hide_render = c.name[4:] not in only
	cam.location = Vector(pos)
	d = Vector(target) - cam.location
	cam.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()
	cam.data.lens = lens
	cam.data.clip_end = 5000
	scene.render.filepath = path
	bpy.ops.render.render(write_still=True)


OUT = REPO + r"\vault\02 Art\References\maps\wharf"
shoot({"QuayCrane"}, (95, -120, 45), (12, 0, 38), OUT + r"\kit-crane.png")
shoot({"MountainA"}, (0, -1100, 160), (0, 0, 60), OUT + r"\kit-mountain-a.png", lens=35)
shoot({"MountainB"}, (0, -1100, 160), (0, 0, 50), OUT + r"\kit-mountain-b.png", lens=35)
shoot({"Ship"}, (120, -260, 60), (0, 0, 10), OUT + r"\kit-ship.png", lens=35)
for c in root.children:
	c.hide_render = False
result = {"tris": tris}
