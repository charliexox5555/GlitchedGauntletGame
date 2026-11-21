"""Build the Rooftops4 kit and render close-ups (live Blender MCP, port 9897).

python tools/blender/lobby_v4/send.py tools/blender/maps_rooftops4/run_rooftops4.py --port 9897 --pid <pid>
Writes vault/02 Art/References/maps/rooftops4/kit-*.png. Export: run_rooftops4_export.py.
"""
import importlib
import sys

import bpy
from mathutils import Vector

REPO = r"C:\Users\charl\Documents\GauntletGame\GlitchedGauntletGame"
sys.path[:0] = [
	REPO + r"\tools\blender\maps_rooftops4",
	REPO + r"\tools\blender\maps_snowpeak4",
	REPO + r"\tools\blender\maps_metro4",
	REPO + r"\tools\blender\maps_arena",
]
import arena_kit as A
import snowcat_model as SC
import rooftops4_pieces as K

for m in (A, SC, K):
	importlib.reload(m)

for c in bpy.data.collections:
	if c.name in ("PortKit", "WharfKit", "Metro4Kit", "Snowpeak4Kit", "Port_Sheet", "Arena_Test", "Port_Test", "Collection", "OldTown4Kit"):
		c.hide_render = True
		c.hide_viewport = True
tris = K.build_all()
root = bpy.data.collections[K.ROOT]
root.hide_render = False
root.hide_viewport = False

scene = bpy.context.scene
scene.render.engine = "BLENDER_WORKBENCH"
scene.display.shading.light = "STUDIO"
scene.display.shading.color_type = "MATERIAL"
scene.display.shading.show_cavity = True
scene.render.resolution_x, scene.render.resolution_y = 1000, 700
cam = bpy.data.objects.get("KitCam")
if cam is None:
	cam = bpy.data.objects.new("KitCam", bpy.data.cameras.new("KitCam"))
	scene.collection.objects.link(cam)
scene.camera = cam
OUT = REPO + "/vault/02 Art/References/maps/rooftops4"


def frame(name, path, d=(0.75, 1.0, 0.55), k=3.0):
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


SHOTS = sys.argv[1:] if len(sys.argv) > 1 else None
for n in (SHOTS or K.PIECES):
	frame(n, OUT + "/kit-" + n.lower() + ".png")
for c in root.children:
	c.hide_render = False
result = {"tris": tris}
