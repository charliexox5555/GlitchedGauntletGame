"""Build the Snowpeak4 kit and render close-up review shots (live Blender MCP, port 9897).

python tools/blender/lobby_v4/send.py tools/blender/maps_snowpeak4/run_snowpeak4.py --port 9897 --pid <pid>
Writes vault/02 Art/References/maps/snowpeak4/kit-*.png. Export: run_snowpeak4_export.py.
"""
import importlib
import sys

import bpy
from mathutils import Vector

REPO = r"C:\Users\charl\Documents\GauntletGame\GlitchedGauntletGame"
sys.path[:0] = [REPO + r"\tools\blender\maps_snowpeak4", REPO + r"\tools\blender\maps_metro4", REPO + r"\tools\blender\maps_arena"]
import arena_kit as A
import metro4_pieces as K
import snowpeak4_pieces as S

for m in (A, K, S):
	importlib.reload(m)

for c in bpy.data.collections:
	if c.name in ("PortKit", "WharfKit", "Metro4Kit", "Port_Sheet", "Arena_Test", "Port_Test"):
		c.hide_render = True
		c.hide_viewport = True
tris = S.build_all()
root = bpy.data.collections[S.ROOT]
root.hide_render = False
root.hide_viewport = False

scene = bpy.context.scene
scene.render.engine = "BLENDER_WORKBENCH"
scene.display.shading.light = "STUDIO"
scene.display.shading.color_type = "MATERIAL"
scene.display.shading.show_cavity = True
scene.render.resolution_x, scene.render.resolution_y = 1200, 800
cam = bpy.data.objects.get("KitCam")
if cam is None:
	cam = bpy.data.objects.new("KitCam", bpy.data.cameras.new("KitCam"))
	scene.collection.objects.link(cam)
scene.camera = cam
OUT = REPO + "/vault/02 Art/References/maps/snowpeak4"


def frame(name, path, d=(0.75, 1.0, 0.5), k=3.2):
	for c in root.children:
		c.hide_render = c.name[4:] != name
	objs = list(bpy.data.collections["Map_" + name].objects)
	pts = [o.matrix_world @ Vector(c) for o in objs for c in o.bound_box]
	lo = Vector([min(p[i] for p in pts) for i in range(3)])
	hi = Vector([max(p[i] for p in pts) for i in range(3)])
	c = (lo + hi) / 2
	r = (hi - lo).length / 2
	cam.location = c + Vector(d).normalized() * r * k
	cam.rotation_euler = (c - cam.location).to_track_quat("-Z", "Y").to_euler()
	cam.data.lens = 50
	cam.data.clip_end = 5000
	scene.render.filepath = path
	bpy.ops.render.render(write_still=True)


for n in ("Snowcat", "PineA", "GondolaCabin", "Bullwheel", "Outcrop", "BoulderB"):
	frame(n, OUT + "/kit-" + n.lower() + ".png")
frame("Snowcat", OUT + "/kit-snowcat-side.png", d=(1.0, -0.2, 0.25))
frame("MountainA", OUT + "/kit-mountain-a.png", d=(0.2, 1.0, 0.25), k=2.2)
for c in root.children:
	c.hide_render = False
result = {"tris": tris}
